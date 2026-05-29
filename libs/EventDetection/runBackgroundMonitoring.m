function pipeline = runBackgroundMonitoring(setupFcn, varargin)
%RUNBACKGROUNDMONITORING Headless entry point for unattended LiveEventPipeline monitoring.
%
%   pipeline = runBackgroundMonitoring(setupFcn) calls the user-supplied setupFcn
%   to obtain a configured LiveEventPipeline, starts it, prints heartbeats to
%   stdout, and blocks until interrupted or a runtime cap elapses.  Designed
%   for `matlab -batch "runBackgroundMonitoring(@my_setup_fcn)"` invocation
%   under launchd / systemd / cron supervision.
%
%   pipeline = runBackgroundMonitoring(setupFcn, 'Name', Value, ...) accepts
%   the following NV-pairs:
%
%     'PollSec'        — heartbeat interval in seconds (default 60).  Must be >= 1.
%     'MaxRuntimeSec'  — hard cap on total runtime in seconds (default 0 = infinite).
%                        Enables deterministic testing and bounded supervisor jobs.
%
%   The function:
%     1.  Calls pipeline = setupFcn() and validates the return is a LiveEventPipeline-shaped handle.
%     2.  Calls pipeline.start() (begins the pipeline's internal timer).
%     3.  Installs an onCleanup so pipeline.stop() runs on every exit path
%         (graceful timeout, Ctrl-C, uncaught exception, normal return).
%     4.  Loops: pause(PollSec), print a heartbeat line, check exit conditions.
%     5.  Exits when MaxRuntimeSec elapses (when > 0) or pipeline.Status becomes 'error'.
%     6.  Returns the pipeline handle (caller / test introspection).
%
%   Heartbeat format:
%     [BG] HH:MM:SS  events=N  emails=M  uptime=Ts
%
%   Errors:
%     EventDetection:invalidSetupFcn    — setupFcn is not a function_handle.
%     EventDetection:invalidOption      — PollSec < 1 or MaxRuntimeSec < 0.
%     EventDetection:setupFcnFailed     — setupFcn() threw; original error is wrapped.
%     EventDetection:setupFcnBadReturn  — setupFcn() returned something that lacks
%                                         start/stop methods and a Status property.
%
%   Example:
%     % my_setup.m -- user's setup function
%     function p = my_setup()
%         install();
%         dsMap = DataSourceMap(); % ...wire monitors + dsMap + notification service...
%         p = LiveEventPipeline(monitors, dsMap, ...
%             'EventFile', '/var/log/fastsense/events.mat', 'Interval', 30);
%         p.NotificationService = NotificationService('DryRun', false, ...
%             'SmtpServer', getenv('FASTSENSE_SMTP_SERVER'));
%     end
%
%     % Invocation under launchd / systemd:
%     %   matlab -batch "runBackgroundMonitoring(@my_setup, 'PollSec', 30)"
%
%   See also LiveEventPipeline, NotificationService.

    if ~isa(setupFcn, 'function_handle')
        error('EventDetection:invalidSetupFcn', ...
            'setupFcn must be a function_handle; got %s.', class(setupFcn));
    end

    defaults.PollSec       = 60;
    defaults.MaxRuntimeSec = 0;
    opts = parseOpts(defaults, varargin);

    if ~(isnumeric(opts.PollSec) && isscalar(opts.PollSec) && opts.PollSec >= 1)
        error('EventDetection:invalidOption', ...
            'PollSec must be a numeric scalar >= 1; got %s.', mat2str(opts.PollSec));
    end
    if ~(isnumeric(opts.MaxRuntimeSec) && isscalar(opts.MaxRuntimeSec) && opts.MaxRuntimeSec >= 0)
        error('EventDetection:invalidOption', ...
            'MaxRuntimeSec must be a numeric scalar >= 0; got %s.', mat2str(opts.MaxRuntimeSec));
    end

    % --- Call user setup function ---
    try
        pipeline = setupFcn();
    catch ME
        error('EventDetection:setupFcnFailed', ...
            'setupFcn threw: %s (id=%s).', ME.message, ME.identifier);
    end
    % Validate the returned handle is LiveEventPipeline-shaped (duck-typed:
    % start/stop methods + a Status property).
    %
    % Portability NB (Octave vs MATLAB): Octave's ismethod (a) rejects a
    % cell-array of names ("METHOD must be a string") and (b) errors on any
    % non-object argument such as [], a struct, or a numeric ("first argument
    % must be object or class name"), whereas MATLAB returns false.  We
    % therefore gate the per-name cellfun(ismethod) behind isobject() (true
    % for handle-class instances on both runtimes, false for []/struct/numeric)
    % so a bad setupFcn return is rejected cleanly with setupFcnBadReturn
    % instead of crashing the runner under Octave.
    hasLifecycle = isobject(pipeline) && ...
        all(cellfun(@(nm) ismethod(pipeline, nm), {'start', 'stop'}));
    if ~hasLifecycle || ~isprop(pipeline, 'Status')
        error('EventDetection:setupFcnBadReturn', ...
            'setupFcn must return a LiveEventPipeline-shaped handle (start/stop methods + Status property); got %s.', ...
            class(pipeline));
    end

    % --- Start pipeline + register universal cleanup ---
    pipeline.start();
    cleaner = onCleanup(@() safeStop_(pipeline)); %#ok<NASGU>

    fprintf('[BG] runBackgroundMonitoring started: PollSec=%g  MaxRuntimeSec=%g\n', ...
        opts.PollSec, opts.MaxRuntimeSec);

    tStart = tic();
    try
        while true
            pause(opts.PollSec);

            uptime = toc(tStart);
            nEvents = 0;
            nEmails = 0;
            if isprop(pipeline, 'EventStore') && ~isempty(pipeline.EventStore) && ...
                    ismethod(pipeline.EventStore, 'numEvents')
                try
                    nEvents = pipeline.EventStore.numEvents();
                catch
                    nEvents = 0;
                end
            end
            if isprop(pipeline, 'NotificationService') && ~isempty(pipeline.NotificationService) && ...
                    isprop(pipeline.NotificationService, 'NotificationCount')
                nEmails = pipeline.NotificationService.NotificationCount;
            end

            fprintf('[BG] %s  events=%d  emails=%d  uptime=%.1fs\n', ...
                datestr(now, 'HH:MM:SS'), nEvents, nEmails, uptime);

            if opts.MaxRuntimeSec > 0 && uptime >= opts.MaxRuntimeSec
                fprintf('[BG] MaxRuntimeSec reached -- exiting heartbeat loop.\n');
                break;
            end
            if strcmp(pipeline.Status, 'error')
                fprintf('[BG] Pipeline status=error -- exiting heartbeat loop.\n');
                break;
            end
        end
    catch ME
        % Any exit-path error (Ctrl-C, uncaught throw) — log once and fall
        % through; onCleanup runs next and stops the pipeline.
        fprintf('[BG] Heartbeat loop interrupted: %s (id=%s)\n', ME.message, ME.identifier);
    end

    fprintf('[BG] runBackgroundMonitoring exit: status=%s, runtime=%.1fs\n', ...
        pipeline.Status, toc(tStart));
end

function safeStop_(pipeline)
%SAFESTOP_ Best-effort pipeline.stop() — never throws.
%   Portability NB: isvalid() is a MATLAB builtin that protects against
%   calling .Status on a deleted handle, but it is NOT implemented in Octave.
%   We therefore call isvalid only when it exists (MATLAB) and fall back to
%   the isobject/ismethod duck-type on Octave — otherwise safeStop_ would
%   swallow an "isvalid undefined" error on Octave and never stop the pipeline.
    try
        if isempty(pipeline) || ~isobject(pipeline) || ~ismethod(pipeline, 'stop')
            return;
        end
        if exist('isvalid', 'builtin') == 5 && ~isvalid(pipeline)
            return;  % MATLAB: handle was deleted — nothing to stop.
        end
        % Stop on 'error' too: timerError() sets Status='error' but does NOT
        % stop/delete the timer, so the error-exit path must still call stop()
        % to release the timer handle (otherwise it leaks / can keep firing).
        if ismember(pipeline.Status, {'running', 'error'})
            pipeline.stop();
        end
    catch ME
        fprintf('[BG] safeStop_ swallowed: %s\n', ME.message);
    end
end
