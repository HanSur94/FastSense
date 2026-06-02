classdef CaptureNotificationService < NotificationService
    %CAPTURENOTIFICATIONSERVICE Test mock that stashes notify() arguments.
    %   Subclass of NotificationService used by test_live_event_pipeline_notif_sensor_data.m
    %   to assert that LiveEventPipeline.runCycle passes populated sensorData
    %   (Plan 01 D-02 bug fix).
    %
    %   Usage:
    %     cap = CaptureNotificationService('DryRun', true);  % Enabled=true by default
    %     cap.setDefaultRule(NotificationRule(...));         % needed -- notify() guards on isempty(rule)
    %     pipeline.NotificationService = cap;
    %     pipeline.runCycle();
    %     assert(~isempty(cap.LastEvent));
    %     assert(~isempty(cap.LastSensorData.X));
    %
    %   Phase 1039 Plan 04.

    properties
        CapturedEvents     = {}   % cell array of Event handles, in call order
        CapturedSensorData = {}   % cell array of sensorData structs, in call order
    end

    methods
        function obj = CaptureNotificationService(varargin)
            obj@NotificationService(varargin{:});
        end

        function notify(obj, event, sensorData)
            obj.CapturedEvents{end+1}     = event;
            obj.CapturedSensorData{end+1} = sensorData;
            % Do NOT call super -- skip rule resolution + snapshot generation +
            % sendmail; we only care about the arguments runCycle handed us.
            obj.NotificationCount = obj.NotificationCount + 1;
        end

        function ev = LastEvent(obj)
            if isempty(obj.CapturedEvents)
                ev = [];
            else
                ev = obj.CapturedEvents{end};
            end
        end

        function sd = LastSensorData(obj)
            if isempty(obj.CapturedSensorData)
                sd = struct();
            else
                sd = obj.CapturedSensorData{end};
            end
        end
    end
end
