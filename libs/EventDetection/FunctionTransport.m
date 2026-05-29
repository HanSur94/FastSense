classdef FunctionTransport < handle
    % FunctionTransport  Route NotificationService sends to an external function.
    %
    %   FunctionTransport adapts an existing email-sending function (for example
    %   a company-internal MATLAB mailer) into a NotificationService Transport.
    %   It owns no SMTP mechanics of its own — it simply forwards each send to a
    %   user-supplied function handle.  This lets you reuse external email code
    %   for background-monitoring alerts WITHOUT configuring SMTP in FastSense
    %   (no server, port, credentials, STARTTLS, or App Passwords), while still
    %   getting NotificationService's rule matching, templated subjects/bodies,
    %   per-(sensor,threshold) cooldown, and snapshot attachments.
    %
    %   It is a drop-in Transport: it exposes the same
    %   send(recipients, subject, body, attachments) signature as EmailTransport,
    %   so NotificationService delegates to it identically (duck-typed).
    %
    %   Usage (wrap a 4-arg company mailer companyMail(to, subject, body, attachments)):
    %     transport = FunctionTransport( ...
    %         @(to, subject, body, attachments) companyMail(to, subject, body, attachments));
    %     notif = NotificationService('DryRun', false, 'Transport', transport, ...
    %                                 'CooldownMinutes', 5);
    %     notif.setDefaultRule(NotificationRule('Recipients', {{'ops@yourco.com'}}));
    %     pipeline.NotificationService = notif;   % LiveEventPipeline now alerts via companyMail
    %
    %   The wrapping handle adapts ANY external signature.  Examples:
    %     % 3-arg mailer (no attachments):
    %     FunctionTransport(@(to, subject, body, attachments) companyMail(to, subject, body));
    %     % mailer wanting a single semicolon-joined recipient string:
    %     FunctionTransport(@(to, subject, body, attachments) companyMail(strjoin(to, ';'), subject, body));
    %
    %   Recipients passed to your function are normalised to a flat 1xN cellstr
    %   (e.g. {'a@co.com', 'b@co.com'}) regardless of how NotificationService
    %   nests them internally, so your function always receives a simple list.
    %
    %   Properties:
    %     Fn — the wrapped function handle (read-only; set via constructor)
    %
    %   Methods:
    %     FunctionTransport(fn)                              — Constructor; validates fn is a function_handle
    %     send(obj, recipients, subject, body, attachments) — normalises recipients and forwards to Fn
    %
    %   Error IDs:
    %     FunctionTransport:invalidHandle
    %
    %   See also EmailTransport, NotificationService, NotificationRule.

    properties (SetAccess = private)
        Fn   % function_handle invoked as Fn(recipients, subject, body, attachments)
    end

    methods (Access = public)

        function obj = FunctionTransport(fn)
            %FUNCTIONTRANSPORT Construct a FunctionTransport wrapping a send function.
            %   obj = FunctionTransport(fn) stores fn, which must be a
            %   function_handle invoked as fn(recipients, subject, body, attachments).
            %   Throws FunctionTransport:invalidHandle when fn is not a handle.
            if nargin < 1 || ~isa(fn, 'function_handle')
                error('FunctionTransport:invalidHandle', ...
                    'FunctionTransport requires a function_handle, got %s.', ...
                    class(fn));
            end
            obj.Fn = fn;
        end

        function send(obj, recipients, subject, body, attachments)
            %SEND Forward a send request to the wrapped function handle.
            %   send(obj, recipients, subject, body, attachments)
            %
            %   Inputs:
            %     recipients  — char or (possibly nested) cell of recipient addresses
            %     subject     — char subject line
            %     body        — char body text
            %     attachments — cellstr of file paths, or {} for no attachments (optional)
            %
            %   recipients is normalised to a flat 1xN cellstr before the call, and
            %   attachments defaults to {} when omitted.  The wrapped function is
            %   then invoked as Fn(recipients, subject, body, attachments).  Any
            %   error raised by the wrapped function propagates to the caller
            %   (NotificationService already wraps sendEmail in try/catch).
            if nargin < 5
                attachments = {};
            end
            recipients = FunctionTransport.normalizeRecipients_(recipients);
            obj.Fn(recipients, subject, body, attachments);
        end

    end

    methods (Static, Access = private)

        function out = normalizeRecipients_(recipients)
            %NORMALIZERECIPIENTS_ Flatten recipients to a 1xN cellstr.
            %   NotificationService forwards rule.Recipients, which is nested as
            %   {{'a@co.com', ...}} (a scalar cell whose only element is itself a
            %   cell).  Unwrap one such level, accept a plain char or cellstr, and
            %   always return a row cellstr so wrapped functions get a simple list.
            out = recipients;
            % Unwrap a single {{...}} nesting level.
            if iscell(out) && isscalar(out) && iscell(out{1})
                out = out{1};
            end
            % A bare char becomes a 1x1 cellstr.
            if ischar(out)
                out = {out};
            end
            % Guarantee a row cellstr (cellstr also validates element types).
            out = reshape(cellstr(out), 1, []);
        end

    end

end
