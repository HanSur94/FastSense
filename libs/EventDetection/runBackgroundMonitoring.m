function status = runBackgroundMonitoring(pipeline, varargin)
%RUNBACKGROUNDMONITORING Run a LiveEventPipeline for a bounded time with heartbeats.
%   STATUS = RUNBACKGROUNDMONITORING(PIPELINE) starts PIPELINE (a
%   LiveEventPipeline, or any object exposing a public 'Status' property plus
%   start()/stop() methods), prints a periodic heartbeat while it runs, then
%   stops it cleanly and returns the pipeline's final Status string — normally
%   'stopped', or 'error' if the pipeline's timer faulted during the run.
%
%   STATUS = RUNBACKGROUNDMONITORING(PIPELINE, NAME, VALUE, ...) accepts:
%     'DurationSec'  — total wall-clock seconds to run before stopping. Must
%                      be a positive finite scalar. Default: 60.
%     'HeartbeatSec' — seconds between heartbeat log lines, and the cadence at
%                      which pipeline.Status is polled. Must be a positive
%                      finite scalar. Default: 5.
%
%   Lifecycle and exit guarantees:
%     - The pipeline is started exactly once and stopped exactly once on the
%       normal and interrupted paths. A trailing onCleanup acts as a safety
%       net so the pipeline is stopped even on Ctrl-C (which unwinds the stack
%       past any try/catch in MATLAB) or an unexpected error. The net is
%       idempotent: safeStop_ only stops while Status=='running'.
%     - The exit log line reports the TRUE post-stop status. The pipeline is
%       stopped BEFORE the line is printed (FIX, Phase 1039), so a normal run
%       logs 'status=stopped' instead of the stale 'status=running' that the
%       previous stop-on-return-via-onCleanup ordering printed. A faulted
%       pipeline keeps its 'error' status (safeStop_ does not overwrite it),
%       so the failure is surfaced in the exit line.
%
%   Heartbeat-loop exit paths — each stops the pipeline exactly once and logs
%   the correct final status:
%     1. Normal    — elapsed >= DurationSec: the loop falls through; safeStop_
%                    transitions 'running' -> 'stopped'; logs 'stopped'.
%     2. Error     — pipeline.Status becomes 'error' (its timer faulted): the
%                    loop breaks; safeStop_ is a no-op (status is not
%                    'running'); logs 'error'.
%     3. Ctrl-C /  — a genuine exception is caught, the pipeline is stopped,
%        exception    an interrupted exit line is logged, and the error is
%                    re-raised. Ctrl-C itself is handled by the onCleanup net.
%
%   This is a thin, console-only driver (no plotting) used by the Phase 1039
%   live demo and by background-monitoring scripts. Input validation is
%   Octave-safe; the timer-driven run itself relies on the MATLAB timers owned
%   by LiveEventPipeline.
%
%   Example:
%     pipeline = LiveEventPipeline(monitors, dsMap, 'Interval', 5);
%     status   = runBackgroundMonitoring(pipeline, 'DurationSec', 30, ...
%                                                  'HeartbeatSec', 5);
%
%   See also LiveEventPipeline, EventStore, NotificationService.

    % ----- Parse options -----
    defaults.DurationSec  = 60;
    defaults.HeartbeatSec = 5;
    opts = parseOpts(defaults, varargin);

    % ----- Validate inputs (runs before any timer is started; Octave-safe) -----
    if ~isValidPipeline_(pipeline)
        error('runBackgroundMonitoring:invalidPipeline', ...
            ['PIPELINE must be a LiveEventPipeline (or an object with a ' ...
             '''Status'' property and start()/stop() methods).']);
    end
    if ~isPositiveScalar_(opts.DurationSec)
        error('runBackgroundMonitoring:invalidDuration', ...
            'DurationSec must be a positive finite scalar; got %s.', ...
            describeValue_(opts.DurationSec));
    end
    if ~isPositiveScalar_(opts.HeartbeatSec)
        error('runBackgroundMonitoring:invalidHeartbeat', ...
            'HeartbeatSec must be a positive finite scalar; got %s.', ...
            describeValue_(opts.HeartbeatSec));
    end

    % ----- Start the pipeline; register the idempotent safety net -----
    tStart = tic();
    pipeline.start();
    % onCleanup fires on EVERY exit path, including Ctrl-C (which unwinds the
    % stack past the try/catch below). It is the backstop; the explicit
    % safeStop_ calls are what let the exit line read the true post-stop state.
    cleaner = onCleanup(@() safeStop_(pipeline)); %#ok<NASGU>

    % ----- Heartbeat loop -----
    try
        while toc(tStart) < opts.DurationSec
            if strcmp(pipeline.Status, 'error')
                fprintf('[BG] pipeline entered error state -- stopping early\n');
                break;
            end
            fprintf('[BG] heartbeat: status=%s, elapsed=%.1fs\n', ...
                pipeline.Status, toc(tStart));
            pause(opts.HeartbeatSec);
        end
    catch ME
        % Genuine exception (Ctrl-C is handled by the onCleanup net, not here).
        % Stop exactly once, log the post-stop status, then re-raise.
        safeStop_(pipeline);
        fprintf('[BG] runBackgroundMonitoring exit (interrupted): status=%s, runtime=%.1fs\n', ...
            pipeline.Status, toc(tStart));
        rethrow(ME);
    end

    % ----- Normal / error-detected exit -----
    % FIX (Phase 1039): stop the pipeline BEFORE reading Status for the log so
    % the exit line reflects the true post-stop state ('stopped') rather than
    % the stale 'running' produced when the stop was deferred to the
    % onCleanup-on-return. safeStop_ is a no-op for an already-'error' pipeline,
    % so a faulted run still logs 'error'. The onCleanup net (idempotent)
    % remains for early/exceptional exits.
    safeStop_(pipeline);
    status = pipeline.Status;
    fprintf('[BG] runBackgroundMonitoring exit: status=%s, runtime=%.1fs\n', ...
        status, toc(tStart));
end

% ========================================================================
%  Local helpers
% ========================================================================

function safeStop_(pipeline)
%SAFESTOP_ Idempotent, best-effort, Octave-portable pipeline stop.
%   Only stops a pipeline that is currently 'running', so it is safe to call
%   repeatedly (the explicit pre-log call plus the onCleanup safety net) and
%   it never overwrites a terminal 'error' status. isvalid() is MATLAB-only
%   for handle objects, so it is guarded behind exist('isvalid','builtin') for
%   Octave. The whole body is wrapped in try/catch so cleanup can never throw.
    if isempty(pipeline)
        return;
    end
    try
        if exist('isvalid', 'builtin') && ~isvalid(pipeline)
            return;  % handle already deleted -- nothing to stop
        end
        if strcmp(pipeline.Status, 'running')
            pipeline.stop();
        end
    catch
        % best-effort: cleanup must never throw
    end
end

function tf = isValidPipeline_(p)
%ISVALIDPIPELINE_ Duck-typed pipeline check: an object with a 'Status'
%   property and start()/stop() methods. Accepts LiveEventPipeline and any
%   conforming test double; rejects non-objects (numbers, char, struct, []).
    tf = false;
    if isempty(p) || ~isobject(p)
        return;
    end
    tf = isprop(p, 'Status') && ismethod(p, 'start') && ismethod(p, 'stop');
end

function tf = isPositiveScalar_(v)
%ISPOSITIVESCALAR_ True for a real, finite, positive numeric scalar.
    tf = isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v) && v > 0;
end

function s = describeValue_(v)
%DESCRIBEVALUE_ Short human-readable description of a rejected option value.
    if isnumeric(v) && isscalar(v)
        s = num2str(v);
    else
        s = sprintf('a %s', class(v));
    end
end
