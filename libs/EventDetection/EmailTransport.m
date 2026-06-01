classdef EmailTransport < handle
    % EmailTransport  SMTP email send mechanics with configurable security modes.
    %
    %   EmailTransport owns all JavaMail property configuration and the sendmail
    %   call so that NotificationService can delegate real-send logic and be unit-
    %   tested without touching the network.
    %
    %   Usage:
    %     t = EmailTransport('Server', 'smtp.example.com', 'Port', 587, ...
    %                        'User', 'alerts@example.com', ...
    %                        'PasswordEnv', 'FASTSENSE_SMTP_PASSWORD', ...
    %                        'SecurityMode', 'starttls');
    %     t.send({'dest@example.com'}, 'Subject', 'Body', {});
    %
    %   Properties (all configurable via constructor name-value pairs):
    %     Server       — SMTP host (char, default '')
    %     Port         — TCP port (numeric, default 587)
    %     User         — SMTP auth username (char, default '')
    %     Password     — SMTP auth password (char, default '') — takes precedence over PasswordEnv
    %     PasswordEnv  — env-var NAME holding the password, e.g. 'FASTSENSE_SMTP_PASSWORD'
    %                    (char, default ''); resolved via getenv() at send time when Password is empty
    %     SecurityMode — 'none' | 'starttls' | 'ssl' (char, default 'starttls')
    %     From         — sender address used in the SMTP envelope (char, default 'fastsense@noreply.com')
    %
    %   Methods:
    %     EmailTransport(varargin)                    — Constructor; validates SecurityMode
    %     props = EmailTransport.buildMailProps(mode, port) — PURE static mapping; no side-effects
    %     send(obj, recipients, subject, body, attachments) — performs SMTP send; Octave-safe
    %
    %   Error IDs:
    %     EmailTransport:invalidSecurityMode
    %
    %   See also NotificationService, NotificationRule, generateEventSnapshot.

    properties (Access = public)
        Server       = ''                     % SMTP host name or IP address
        Port         = 587                    % TCP port (default 587 for STARTTLS)
        User         = ''                     % SMTP auth username
        Password     = ''                     % Explicit password (takes precedence over PasswordEnv)
        PasswordEnv  = ''                     % Env-var NAME for password resolution at send time
        SecurityMode = 'starttls'             % 'none' | 'starttls' | 'ssl'
        From         = 'fastsense@noreply.com' % Sender address for SMTP envelope
    end

    methods (Access = public)

        function obj = EmailTransport(varargin)
            %EMAILTRANSPORT Construct EmailTransport with optional name-value configuration.
            %   Accepts any subset of the public properties as name-value pairs.
            %   SecurityMode is validated case-insensitively; it is stored lower-cased.
            %   Throws EmailTransport:invalidSecurityMode on unrecognised mode.
            p = inputParser();
            p.addParameter('Server',       '',                      @ischar);
            p.addParameter('Port',         587,                     @isnumeric);
            p.addParameter('User',         '',                      @ischar);
            p.addParameter('Password',     '',                      @ischar);
            p.addParameter('PasswordEnv',  '',                      @ischar);
            p.addParameter('SecurityMode', 'starttls',              @ischar);
            p.addParameter('From',         'fastsense@noreply.com', @ischar);
            p.parse(varargin{:});
            r = p.Results;

            obj.Server       = r.Server;
            obj.Port         = r.Port;
            obj.User         = r.User;
            obj.Password     = r.Password;
            obj.PasswordEnv  = r.PasswordEnv;
            obj.From         = r.From;

            % Validate and normalise SecurityMode (case-insensitive, store lower-cased).
            mode = lower(r.SecurityMode);
            EmailTransport.validateSecurityMode_(mode);
            obj.SecurityMode = mode;
        end

        function send(obj, recipients, subject, body, attachments)
            %SEND Send an email to one or more recipients via SMTP.
            %   send(obj, recipients, subject, body, attachments)
            %
            %   Inputs:
            %     recipients  — char or cellstr of recipient addresses
            %     subject     — char subject line
            %     body        — char body text
            %     attachments — cellstr of file paths, or {} for no attachments
            %
            %   Octave guard: when sendmail is unavailable (Octave does not ship it),
            %   this method logs a message and returns cleanly without error.
            %   NotificationService already wraps sendEmail in try/catch; real SMTP
            %   errors from MATLAB's sendmail bubble up through that guard.

            % --- OCTAVE GUARD: sendmail is absent on Octave ---
            % exist('sendmail','file')==0 is true on Octave where sendmail.m is not
            % present.  We must NOT error in this case — log and return silently.
            if exist('sendmail', 'file') == 0
                % Robust recipient count that tolerates char or cellstr input.
                nRecip = numel(cellstr(recipients));
                fprintf('[EmailTransport] sendmail unavailable (Octave?) — skipping send to %d recipient(s)\n', ...
                    nRecip);
                return;
            end

            % --- Resolve effective password ---
            % Explicit Password property takes precedence; fall back to env-var.
            pw = obj.Password;
            if isempty(pw) && ~isempty(obj.PasswordEnv)
                pw = getenv(obj.PasswordEnv);
            end

            % --- Set MATLAB Internet preferences required by sendmail ---
            % Always set server + from-address so the envelope is correct.
            setpref('Internet', 'SMTP_Server', obj.Server);
            setpref('Internet', 'E_mail', obj.From);

            % For auth modes (starttls / ssl) also set username + password prefs.
            % 'none' mode does not authenticate and needs no username/password.
            if ~strcmp(obj.SecurityMode, 'none')
                setpref('Internet', 'SMTP_Username', obj.User);
                setpref('Internet', 'SMTP_Password', pw);
            end

            % --- Apply mail.smtp.* properties to the live JVM ---
            % MATLAB's sendmail creates a JavaMail Session; we write system
            % properties before the call so the Session picks them up.
            % This is the standard approach for configuring STARTTLS / SSL
            % auth without requiring a custom JavaMail wrapper.
            % We wrap this in a try so that a missing / odd JVM doesn't
            % hard-crash beyond MATLAB's own sendmail behaviour.
            try
                javaProps = java.lang.System.getProperties();
                propMap   = EmailTransport.buildMailProps(obj.SecurityMode, obj.Port);
                propKeys  = propMap.keys();
                for ki = 1:numel(propKeys)
                    javaProps.setProperty(propKeys{ki}, propMap(propKeys{ki}));
                end
            catch jvmEx
                % Best-effort; if JVM property setting fails, sendmail may still
                % work for simple unauthenticated servers.  Let sendmail decide.
                fprintf('[EmailTransport] JVM property set failed (%s); proceeding.\n', ...
                    jvmEx.message);
            end

            % --- Send ---
            if isempty(attachments)
                sendmail(recipients, subject, body);
            else
                sendmail(recipients, subject, body, attachments);
            end
        end

    end

    methods (Static, Access = public)

        function props = buildMailProps(securityMode, port)
            %BUILDMAILPROPS PURE static mapping of SecurityMode + port to mail.smtp.* properties.
            %   props = EmailTransport.buildMailProps(securityMode, port)
            %
            %   Returns a containers.Map('KeyType','char','ValueType','char') with the
            %   JavaMail mail.smtp.* property keys and values appropriate for the given
            %   security mode.  This method has NO side-effects (no setpref, no JVM
            %   interaction) — it exists purely as a testable mapping seam.
            %
            %   Mode definitions:
            %     'none'     — plain SMTP, no authentication.
            %                  Only 'mail.smtp.port' is set.
            %     'starttls' — upgrade plain SMTP connection to TLS via EHLO STARTTLS.
            %                  Adds mail.smtp.auth=true and mail.smtp.starttls.enable=true.
            %     'ssl'      — TLS-wrapped SMTP from the first byte (legacy smtps).
            %                  Adds mail.smtp.auth=true, socketFactory.class, and
            %                  socketFactory.port for javax.net.ssl.SSLSocketFactory.
            %
            %   Inputs:
            %     securityMode — char: 'none' | 'starttls' | 'ssl'
            %     port         — numeric port number
            %
            %   Output:
            %     props — containers.Map('KeyType','char','ValueType','char')
            %
            %   Throws:
            %     EmailTransport:invalidSecurityMode on unrecognised mode.

            % Validate and normalise (allows callers to pass any case).
            mode = lower(char(securityMode));
            EmailTransport.validateSecurityMode_(mode);

            portStr = num2str(double(port));

            props = containers.Map('KeyType', 'char', 'ValueType', 'char');

            % Common to every mode: set the SMTP port.
            props('mail.smtp.port') = portStr;

            switch mode
                case 'none'
                    % Plain SMTP — no auth keys added.

                case 'starttls'
                    % STARTTLS: server must support EHLO STARTTLS on plain-text port
                    % (typically 587).  JavaMail issues EHLO, server responds with
                    % STARTTLS capability, JavaMail upgrades the connection to TLS.
                    props('mail.smtp.auth')            = 'true';
                    props('mail.smtp.starttls.enable') = 'true';

                case 'ssl'
                    % SSL/TLS: TLS-wrapped from the first byte (legacy smtps, port 465).
                    % SSLSocketFactory wraps the connection; socketFactory.port matches
                    % the connection port so JSSE opens the right TLS socket.
                    props('mail.smtp.auth')                   = 'true';
                    props('mail.smtp.socketFactory.class')    = 'javax.net.ssl.SSLSocketFactory';
                    props('mail.smtp.socketFactory.port')     = portStr;
            end
        end

    end

    methods (Static, Access = private)

        function validateSecurityMode_(mode)
            %VALIDATESECURITYMODE_ Assert mode is one of the valid set.
            %   Throws EmailTransport:invalidSecurityMode with a descriptive
            %   message listing the valid modes when mode is not recognised.
            validModes = {'none', 'starttls', 'ssl'};
            if ~any(strcmp(mode, validModes))
                error('EmailTransport:invalidSecurityMode', ...
                    'Invalid SecurityMode ''%s''. Valid modes: %s.', ...
                    mode, strjoin(validModes, ', '));
            end
        end

    end

end
