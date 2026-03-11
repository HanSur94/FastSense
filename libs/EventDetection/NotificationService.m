classdef NotificationService < handle
    % NotificationService  Rule-based email notifications with event snapshots.

    properties
        Rules           = NotificationRule.empty()
        DefaultRule     = []
        Enabled         = true
        DryRun          = false
        SnapshotDir     = ''
        SnapshotRetention = 7  % days
        SmtpServer      = ''
        SmtpPort        = 25
        SmtpUser        = ''
        SmtpPassword    = ''
        FromAddress     = 'fastplot@noreply.com'
        NotificationCount = 0
    end

    methods
        function obj = NotificationService(varargin)
            p = inputParser();
            p.addParameter('Enabled', true, @islogical);
            p.addParameter('DryRun', false, @islogical);
            p.addParameter('SnapshotDir', '', @ischar);
            p.addParameter('SmtpServer', '', @ischar);
            p.addParameter('FromAddress', 'fastplot@noreply.com', @ischar);
            p.parse(varargin{:});
            obj.Enabled     = p.Results.Enabled;
            obj.DryRun      = p.Results.DryRun;
            obj.SnapshotDir = p.Results.SnapshotDir;
            obj.SmtpServer  = p.Results.SmtpServer;
            obj.FromAddress = p.Results.FromAddress;
            if isempty(obj.SnapshotDir)
                obj.SnapshotDir = fullfile(tempdir, 'fastplot_snapshots');
            end
        end

        function addRule(obj, rule)
            if isempty(obj.Rules)
                obj.Rules = rule;
            else
                obj.Rules(end+1) = rule;
            end
        end

        function setDefaultRule(obj, rule)
            obj.DefaultRule = rule;
        end

        function rule = findBestRule(obj, event)
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
            if ~obj.Enabled; return; end

            rule = obj.findBestRule(event);
            if isempty(rule); return; end

            subject = rule.fillTemplate(rule.Subject, event);
            message = rule.fillTemplate(rule.Message, event);

            % Generate snapshots
            snapshotFiles = {};
            if rule.IncludeSnapshot
                try
                    snapshotFiles = generateEventSnapshot(event, sensorData, ...
                        'OutputDir', obj.SnapshotDir, ...
                        'SnapshotSize', rule.SnapshotSize, ...
                        'Padding', rule.SnapshotPadding, ...
                        'ContextHours', rule.ContextHours);
                catch ex
                    fprintf('[NOTIFY WARNING] Snapshot failed: %s\n', ex.message);
                end
            end

            % Send email
            if ~obj.DryRun
                try
                    obj.sendEmail(rule.Recipients, subject, message, snapshotFiles);
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

            obj.NotificationCount = obj.NotificationCount + 1;
        end

        function cleanupSnapshots(obj)
            if ~isfolder(obj.SnapshotDir); return; end
            files = dir(fullfile(obj.SnapshotDir, '*.png'));
            cutoff = now - obj.SnapshotRetention;
            for i = 1:numel(files)
                if files(i).datenum < cutoff
                    delete(fullfile(obj.SnapshotDir, files(i).name));
                end
            end
        end
    end

    properties (Access = private)
        smtpConfigured_ = false
    end

    methods (Access = private)
        function sendEmail(obj, recipients, subject, message, attachments)
            if ~obj.smtpConfigured_
                if ~isempty(obj.SmtpServer)
                    setpref('Internet', 'SMTP_Server', obj.SmtpServer);
                end
                if ~isempty(obj.FromAddress)
                    setpref('Internet', 'E_mail', obj.FromAddress);
                end
                obj.smtpConfigured_ = true;
            end
            if isempty(attachments)
                sendmail(recipients, subject, message);
            else
                sendmail(recipients, subject, message, attachments);
            end
        end
    end
end
