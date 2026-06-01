classdef NotificationService < handle
    % NotificationService  Rule-based email notifications with event snapshots and cooldown.
    %
    %   Evaluates incoming events against a priority-ordered set of NotificationRule
    %   objects, generates optional FastSense PNG snapshots, and sends email via an
    %   injectable EmailTransport (defaults to a lazily-constructed real EmailTransport
    %   when none is provided).
    %
    %   Usage:
    %     % Dry-run (default) — logs to console, no real send:
    %     ns = NotificationService('DryRun', true);
    %     ns.setDefaultRule(NotificationRule('Recipients', {{'ops@example.com'}}, ...
    %         'IncludeSnapshot', false));
    %     ns.notify(event, sensorData);
    %
    %     % Real send with injected mock (unit tests):
    %     mock = MockEmailTransport();
    %     ns   = NotificationService('Transport', mock, 'CooldownMinutes', 0);
    %     ns.notify(event, sensorData);
    %     assert(numel(mock.Calls) == 1);
    %
    %     % Real send with SMTP config:
    %     ns = NotificationService('DryRun', false, ...
    %         'SmtpServer', 'smtp.example.com', 'SmtpPort', 587, ...
    %         'SmtpUser', 'alerts@example.com', 'PasswordEnv', 'FASTSENSE_SMTP_PASSWORD', ...
    %         'SecurityMode', 'starttls', 'CooldownMinutes', 5);
    %
    %   Public properties:
    %     Rules              — array of NotificationRule (priority-matched)
    %     DefaultRule        — fallback NotificationRule (score=1)
    %     Enabled            — logical; when false notify() returns immediately (default true)
    %     DryRun             — logical; when true logs instead of sending (default false)
    %     SnapshotDir        — char; directory for PNG snapshots (default: tempdir/fastsense_snapshots)
    %     SnapshotRetention  — numeric; days to keep old snapshot PNGs (default 7)
    %     SmtpServer         — char; SMTP host (default '')
    %     SmtpPort           — numeric; SMTP port (default 587)
    %     SmtpUser           — char; SMTP auth username (default '')
    %     SmtpPassword       — char; explicit password (default '')
    %     PasswordEnv        — char; env-var name for password resolution (default '')
    %     SecurityMode       — char; 'none'|'starttls'|'ssl' (default 'starttls')
    %     FromAddress        — char; sender address (default 'fastsense@noreply.com')
    %     CooldownMinutes    — numeric; per-(sensor,threshold) cooldown in minutes; 0=disabled (default 5)
    %     Transport          — injectable EmailTransport (or mock); lazily built when empty (default [])
    %     NotificationCount  — numeric; count of events that reached the send/dry-run path
    %     SuppressedCount    — numeric; count of events suppressed by the cooldown window
    %
    %   Methods:
    %     NotificationService(varargin)          — constructor; NV-pair config
    %     addRule(rule)                          — append a NotificationRule
    %     setDefaultRule(rule)                   — set the fallback rule
    %     rule = findBestRule(event)             — return the highest-scoring matching rule
    %     notify(event, sensorData)              — main notification entry point
    %     cleanupSnapshots()                     — delete PNGs older than SnapshotRetention days
    %
    %   Hidden test seams:
    %     setLastSentForTesting_(event, datenumVal) — back-dates the cooldown stamp for testing
    %
    %   Error IDs: (none emitted directly; errors bubble from EmailTransport / sendmail)
    %
    %   See also EmailTransport, NotificationRule, generateEventSnapshot.

    properties (Access = public)
        Rules              = []
        DefaultRule        = []
        Enabled            = true
        DryRun             = false
        SnapshotDir        = ''
        SnapshotRetention  = 7    % days
        SmtpServer         = ''
        SmtpPort           = 587
        SmtpUser           = ''
        SmtpPassword       = ''
        PasswordEnv        = ''   % env-var NAME for password resolution at send time
        SecurityMode       = 'starttls'
        FromAddress        = 'fastsense@noreply.com'
        CooldownMinutes    = 5    % per-(sensor,threshold) cooldown; 0 disables
        Transport          = []   % injectable EmailTransport or mock; lazily built when empty
        NotificationCount  = 0
        SuppressedCount    = 0    % events suppressed within the cooldown window
    end

    properties (Access = private)
        lastSentByKey_ = []  % containers.Map char->double; lazily initialised on first use
    end

    methods (Access = public)

        function obj = NotificationService(varargin)
            %NOTIFICATIONSERVICE Construct with optional name-value configuration.
            p = inputParser();
            p.addParameter('Enabled',          true,                      @islogical);
            p.addParameter('DryRun',           false,                     @islogical);
            p.addParameter('SnapshotDir',      '',                        @ischar);
            p.addParameter('SmtpServer',       '',                        @ischar);
            p.addParameter('SmtpPort',         587,                       @isnumeric);
            p.addParameter('SmtpUser',         '',                        @ischar);
            p.addParameter('SmtpPassword',     '',                        @ischar);
            p.addParameter('PasswordEnv',      '',                        @ischar);
            p.addParameter('SecurityMode',     'starttls',                @ischar);
            p.addParameter('FromAddress',      'fastsense@noreply.com',   @ischar);
            p.addParameter('CooldownMinutes',  5,                         @isnumeric);
            p.addParameter('Transport',        []);
            p.parse(varargin{:});
            r = p.Results;

            obj.Enabled         = r.Enabled;
            obj.DryRun          = r.DryRun;
            obj.SnapshotDir     = r.SnapshotDir;
            obj.SmtpServer      = r.SmtpServer;
            obj.SmtpPort        = r.SmtpPort;
            obj.SmtpUser        = r.SmtpUser;
            obj.SmtpPassword    = r.SmtpPassword;
            obj.PasswordEnv     = r.PasswordEnv;
            obj.SecurityMode    = r.SecurityMode;
            obj.FromAddress     = r.FromAddress;
            obj.CooldownMinutes = r.CooldownMinutes;
            obj.Transport       = r.Transport;

            if isempty(obj.SnapshotDir)
                obj.SnapshotDir = fullfile(tempdir, 'fastsense_snapshots');
            end

            % Lazily-initialised cooldown map (char -> double datenum).
            obj.lastSentByKey_ = containers.Map('KeyType', 'char', 'ValueType', 'double');
        end

        function addRule(obj, rule)
            %ADDRULE Append a NotificationRule to the priority-match list.
            if isempty(obj.Rules)
                obj.Rules = rule;
            else
                obj.Rules(end+1) = rule;
            end
        end

        function setDefaultRule(obj, rule)
            %SETDEFAULTRULE Set the fallback rule (score=1) used when no specific rule matches.
            obj.DefaultRule = rule;
        end

        function rule = findBestRule(obj, event)
            %FINDBESTRULE Return the highest-scoring NotificationRule that matches event.
            %   Returns [] when no rule matches (including no default rule).
            bestScore = 0;
            rule = [];
            for i = 1:numel(obj.Rules)
                score = obj.Rules(i).matches(event);
                if score > bestScore
                    bestScore = score;
                    rule = obj.Rules(i);
                end
            end
            if isempty(rule) && ~isempty(obj.DefaultRule)
                if obj.DefaultRule.matches(event) > 0
                    rule = obj.DefaultRule;
                end
            end
        end

        function notify(obj, event, sensorData)
            %NOTIFY Evaluate event against rules and send/log a notification.
            %   notify(obj, event, sensorData)
            %
            %   Control flow:
            %     1. Guard: ~Enabled -> return (no count, no cooldown stamp)
            %     2. Guard: no matching rule -> return (no count, no cooldown stamp)
            %     3. Cooldown check (when CooldownMinutes > 0):
            %          if within window -> SuppressedCount++, return (no email, no dry-run log)
            %     4. Generate snapshot PNGs when rule.IncludeSnapshot is true
            %     5. Send real email OR log dry-run line
            %     6. Stamp cooldown map with now (regardless of DryRun)
            %     7. NotificationCount++

            % Guard 1: disabled service.
            if ~obj.Enabled; return; end

            % Guard 2: no matching rule.
            rule = obj.findBestRule(event);
            if isempty(rule); return; end

            % Guard 3: per-(sensor, threshold) cooldown.
            % Cooldown suppresses BOTH real-send AND dry-run within the window.
            % Stamping happens AFTER a successful proceed (step 6) so disabled /
            % no-rule paths never stamp and never affect NotificationCount.
            nowDatenum = now(); %#ok<TNOW1>
            k = obj.cooldownKey_(event);
            if obj.CooldownMinutes > 0
                if isKey(obj.lastSentByKey_, k)
                    elapsedMin = (nowDatenum - obj.lastSentByKey_(k)) * 1440;
                    if elapsedMin < obj.CooldownMinutes
                        obj.SuppressedCount = obj.SuppressedCount + 1;
                        return;
                    end
                end
            end

            subject = rule.fillTemplate(rule.Subject, event);
            message = rule.fillTemplate(rule.Message, event);

            % Generate snapshots when requested by the rule.
            snapshotFiles = {};
            if rule.IncludeSnapshot
                try
                    snapshotFiles = generateEventSnapshot(event, sensorData, ...
                        'OutputDir',    obj.SnapshotDir, ...
                        'SnapshotSize', rule.SnapshotSize, ...
                        'Padding',      rule.SnapshotPadding, ...
                        'ContextHours', rule.ContextHours);
                catch ex
                    fprintf('[NOTIFY WARNING] Snapshot failed: %s\n', ex.message);
                end
            end

            % Send email (real or dry-run).
            if ~obj.DryRun
                try
                    obj.sendEmail_(rule.Recipients, subject, message, snapshotFiles);
                catch ex
                    fprintf('[NOTIFY ERROR] Email failed: %s\n', ex.message);
                end
            else
                recips = rule.Recipients;
                if iscell(recips) && ~isempty(recips) && iscell(recips{1})
                    recips = recips{1};
                end
                fprintf('[NOTIFY DRY-RUN] To: %s | Subject: %s\n', ...
                    strjoin(recips, ', '), subject);
            end

            % Stamp cooldown map AFTER a successful proceed (applies to both real + dry-run).
            if obj.CooldownMinutes > 0
                obj.lastSentByKey_(k) = nowDatenum;
            end

            obj.NotificationCount = obj.NotificationCount + 1;
        end

        function cleanupSnapshots(obj)
            %CLEANUPSNAPSHOTS Delete PNG snapshot files older than SnapshotRetention days.
            if ~isfolder(obj.SnapshotDir); return; end
            files  = dir(fullfile(obj.SnapshotDir, '*.png'));
            cutoff = now - obj.SnapshotRetention; %#ok<TNOW1>
            for i = 1:numel(files)
                if files(i).datenum < cutoff
                    delete(fullfile(obj.SnapshotDir, files(i).name));
                end
            end
        end

    end

    methods (Hidden, Access = public)

        function setLastSentForTesting_(obj, event, datenumVal)
            %SETLASTSENTFORTESTING_ Test seam: back-date the cooldown stamp for an event.
            %   Follows the DI-seam pattern from STATE.md ("1028 DI-seam pattern").
            %   Writes obj.lastSentByKey_(cooldownKey) = datenumVal so that tests can
            %   simulate cooldown expiry without sleeping.
            %
            %   Example:
            %     ns.setLastSentForTesting_(ev, now - 10/1440);  % 10 min ago (> 5 min window)
            k = obj.cooldownKey_(event);
            obj.lastSentByKey_(k) = datenumVal;
        end

    end

    methods (Access = private)

        function sendEmail_(obj, recipients, subject, message, attachments)
            %SENDEMAIL_ Delegate to Transport.send(), lazily constructing a real EmailTransport if needed.
            %   The injectable Transport property is the DI seam for unit tests
            %   (pass a MockEmailTransport via constructor 'Transport' NV-pair).
            %   When Transport is empty, a real EmailTransport is built from the
            %   service's current SMTP configuration properties.
            if isempty(obj.Transport)
                obj.Transport = EmailTransport( ...
                    'Server',      obj.SmtpServer, ...
                    'Port',        obj.SmtpPort, ...
                    'User',        obj.SmtpUser, ...
                    'Password',    obj.SmtpPassword, ...
                    'PasswordEnv', obj.PasswordEnv, ...
                    'SecurityMode', obj.SecurityMode, ...
                    'From',        obj.FromAddress);
            end
            obj.Transport.send(recipients, subject, message, attachments);
        end

        function k = cooldownKey_(~, event)
            %COOLDOWNKEY_ Return the per-(sensor,threshold) map key for cooldown tracking.
            k = sprintf('%s|%s', event.SensorName, event.ThresholdLabel);
        end

    end

end
