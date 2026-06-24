classdef MockBgPipeline < handle
    %MOCKBGPIPELINE Minimal LiveEventPipeline test double for the
    %   runBackgroundMonitoring error-exit path.
    %
    %   MATLAB-only: start() arms a one-shot timer that flips Status to
    %   'error' after ErrorAfterSec, mimicking a pipeline whose timer faults
    %   (LiveEventPipeline.timerError sets Status='error'). It deliberately
    %   does NOT call stop() when it faults, so StopCount stays 0 and the
    %   'error' status is preserved — letting the L2 sub-test assert that
    %   runBackgroundMonitoring's safeStop_ (guarded on Status=='running')
    %   does not force-stop a faulted pipeline.
    %
    %   Referenced only by the MATLAB-only L2 sub-test of
    %   test_run_background_monitoring, so it is never loaded under Octave.
    %
    %   See also runBackgroundMonitoring, test_run_background_monitoring.

    properties
        Status        = 'stopped'   % 'stopped' | 'running' | 'error'
        ErrorAfterSec = 0.15        % delay after start() before Status -> 'error'
        StartCount    = 0           % number of start() calls
        StopCount     = 0           % number of stop() calls
    end

    properties (Access = private)
        timer_ = []
    end

    methods
        function start(obj)
            %START Begin "running" and arm the fault timer.
            obj.Status     = 'running';
            obj.StartCount = obj.StartCount + 1;
            obj.timer_ = timer('StartDelay', obj.ErrorAfterSec, ...
                'ExecutionMode', 'singleShot', ...
                'TimerFcn', @(~, ~) obj.fault_());
            start(obj.timer_);
        end

        function stop(obj)
            %STOP Halt the fault timer and mark stopped.
            obj.cleanupTimer_();
            obj.Status    = 'stopped';
            obj.StopCount = obj.StopCount + 1;
        end

        function delete(obj)
            %DELETE Destructor -- ensure the fault timer is never leaked.
            obj.cleanupTimer_();
        end
    end

    methods (Access = private)
        function fault_(obj)
            %FAULT_ Drive Status to 'error', emulating a faulted pipeline timer.
            %   Does NOT call stop(): StopCount stays 0 and 'error' is kept.
            %   The one-shot timer auto-stops after firing; the leftover object
            %   is cleaned up by stop()/the destructor.
            obj.Status = 'error';
        end

        function cleanupTimer_(obj)
            %CLEANUPTIMER_ Best-effort stop + delete of the fault timer.
            if ~isempty(obj.timer_)
                try
                    if isvalid(obj.timer_)
                        stop(obj.timer_);
                        delete(obj.timer_);
                    end
                catch
                    % best-effort -- never throw from cleanup
                end
                obj.timer_ = [];
            end
        end
    end
end
