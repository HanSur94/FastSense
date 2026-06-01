classdef MockEmailTransport < handle
    % MockEmailTransport  Test double for EmailTransport used in NotificationService unit tests.
    %
    %   Usage:
    %     mock = MockEmailTransport();
    %     ns   = NotificationService('Transport', mock, 'CooldownMinutes', 0);
    %     ns.notify(event, sensorData);
    %     assert(numel(mock.Calls) == 1);
    %     assert(strcmp(mock.Calls{1}.recipients{1}, 'a@b.com'));
    %
    %   Properties:
    %     Calls — cell array of structs; each struct has fields:
    %               recipients, subject, body, attachments
    %
    %   Methods:
    %     send(obj, r, s, b, a) — records the call in Calls
    %
    %   See also EmailTransport, NotificationService, test_notification_service.

    properties (Access = public)
        Calls = {}   % Cell array of call records; each entry is a struct with
                     % fields {recipients, subject, body, attachments}.
    end

    methods (Access = public)

        function send(obj, recipients, subject, body, attachments)
            %SEND Record a send call.  Appends a struct to Calls.
            rec.recipients  = recipients;
            rec.subject     = subject;
            rec.body        = body;
            rec.attachments = attachments;
            obj.Calls{end+1} = rec;
        end

    end

end
