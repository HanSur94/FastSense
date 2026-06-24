function test_run_background_monitoring()
%TEST_RUN_BACKGROUND_MONITORING Tests for the runBackgroundMonitoring driver.
%   Verifies the bounded-run lifecycle and, in particular, the Phase 1039 fix
%   that the exit log line reports the TRUE post-stop status (the pipeline is
%   stopped BEFORE the line is printed) rather than the stale 'running'.
%
%   Coverage:
%     E1 — non-pipeline arg throws runBackgroundMonitoring:invalidPipeline   (Octave + MATLAB)
%     E2 — bad DurationSec throws runBackgroundMonitoring:invalidDuration    (Octave + MATLAB)
%     E3 — bad HeartbeatSec throws runBackgroundMonitoring:invalidHeartbeat  (Octave + MATLAB)
%     L1 — normal exit: a real pipeline runs briefly, returns 'stopped', the
%          logged exit status matches the post-return status, no timer leak    (MATLAB only)
%     L2 — error exit: a pipeline whose timer faults mid-run returns 'error',
%          the exit line logs 'status=error', and safeStop_ does NOT
%          force-stop the faulted pipeline (StopCount == 0)                    (MATLAB only)
%
%   The L1/L2 sub-tests are timer-driven and MATLAB-only; the E1-E3 error-ID
%   sub-tests also run on Octave because validation precedes any timer start.
%
%   See also runBackgroundMonitoring, LiveEventPipeline, MockBgPipeline.

    add_run_background_monitoring_path();

    nPassed = 0;

    % --- Error-ID sub-tests (Octave + MATLAB) ---
    nPassed = nPassed + e1_invalid_pipeline();
    nPassed = nPassed + e2_invalid_duration();
    nPassed = nPassed + e3_invalid_heartbeat();

    % --- Timer-driven lifecycle sub-tests (MATLAB only) ---
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    Skipped 2 timer-driven lifecycle sub-tests on Octave (MATLAB timers required).\n');
    else
        nPassed = nPassed + l1_normal_exit_logs_stopped();
        nPassed = nPassed + l2_error_exit_logs_error();
    end

    fprintf('    All %d run_background_monitoring tests passed.\n', nPassed);
end

% ========================================================================
%  Path setup
% ========================================================================

function add_run_background_monitoring_path()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests'));          % MockBgPipeline
    addpath(fullfile(repo, 'tests', 'suite'));
end

% ========================================================================
%  E1-E3 — error-ID validation (Octave + MATLAB)
% ========================================================================

function n = e1_invalid_pipeline()
%E1 Non-pipeline first arg must throw runBackgroundMonitoring:invalidPipeline.
    bad = {42, 'not a pipeline', struct('Status', 'running'), []};
    for i = 1:numel(bad)
        try
            runBackgroundMonitoring(bad{i});
            error('E1: invalid pipeline must throw');
        catch ME
            assert(strcmp(ME.identifier, 'runBackgroundMonitoring:invalidPipeline'), ...
                sprintf('E1: expected runBackgroundMonitoring:invalidPipeline, got ''%s''', ...
                    ME.identifier));
        end
    end
    n = 1;
end

function n = e2_invalid_duration()
%E2 Non-positive / non-scalar DurationSec must throw invalidDuration.
    p = makeEmptyPipeline_();   % valid pipeline so we reach the duration check
    bad = {0, -5, NaN, Inf, 'x', [1 2]};
    for i = 1:numel(bad)
        try
            runBackgroundMonitoring(p, 'DurationSec', bad{i}, 'HeartbeatSec', 1);
            error('E2: invalid DurationSec must throw');
        catch ME
            assert(strcmp(ME.identifier, 'runBackgroundMonitoring:invalidDuration'), ...
                sprintf('E2: expected runBackgroundMonitoring:invalidDuration, got ''%s''', ...
                    ME.identifier));
        end
    end
    n = 1;
end

function n = e3_invalid_heartbeat()
%E3 Non-positive / non-scalar HeartbeatSec must throw invalidHeartbeat.
    p = makeEmptyPipeline_();   % valid pipeline + valid duration so we reach the heartbeat check
    bad = {0, -1, NaN, Inf, 'x', [1 2]};
    for i = 1:numel(bad)
        try
            runBackgroundMonitoring(p, 'DurationSec', 10, 'HeartbeatSec', bad{i});
            error('E3: invalid HeartbeatSec must throw');
        catch ME
            assert(strcmp(ME.identifier, 'runBackgroundMonitoring:invalidHeartbeat'), ...
                sprintf('E3: expected runBackgroundMonitoring:invalidHeartbeat, got ''%s''', ...
                    ME.identifier));
        end
    end
    n = 1;
end

% ========================================================================
%  L1-L2 — timer-driven lifecycle (MATLAB only)
% ========================================================================

function n = l1_normal_exit_logs_stopped()
%L1 Normal exit returns 'stopped'; the logged exit status matches the
%   post-return status; the run leaks no timer.
    nTimersBefore = numel(timerfindall);
    p = makeEmptyPipeline_();
    cleanup_ = onCleanup(@() safeKill_(p)); %#ok<NASGU>

    logged = evalc(['st = runBackgroundMonitoring(p, ''DurationSec'', 0.4, ' ...
                    '''HeartbeatSec'', 0.1);']);

    % Returned status and the pipeline's post-return status are both 'stopped'.
    assert(strcmp(st, 'stopped'), ...
        sprintf('L1: expected returned status ''stopped'', got ''%s''', st));
    assert(strcmp(p.Status, 'stopped'), ...
        sprintf('L1: pipeline must be ''stopped'' on return, got ''%s''', p.Status));

    % The logged exit status matches the post-return status (this is the fix:
    % the line is printed AFTER the stop, so it reads 'stopped', not 'running').
    loggedStatus = parseExitStatus_(logged);
    assert(strcmp(loggedStatus, 'stopped'), ...
        sprintf('L1: exit log must report ''stopped'', got ''%s''', loggedStatus));
    assert(strcmp(loggedStatus, st), ...
        'L1: logged exit status must match the returned (post-return) status');

    % No timer leaked by the run (the pipeline timer is deleted on stop).
    nTimersAfter = numel(timerfindall);
    assert(nTimersAfter <= nTimersBefore, ...
        sprintf('L1: runBackgroundMonitoring leaked %d timer(s)', ...
            nTimersAfter - nTimersBefore));
    n = 1;
end

function n = l2_error_exit_logs_error()
%L2 A pipeline that faults mid-run exits via the error branch: returns
%   'error', logs 'status=error', and is NOT force-stopped by safeStop_
%   (guard on Status=='running'), so StopCount stays 0.
    mock = MockBgPipeline();
    mock.ErrorAfterSec = 0.15;
    cleanup_ = onCleanup(@() delete(mock)); %#ok<NASGU>

    % DurationSec is a generous safety cap; the loop should break on 'error'
    % at ~0.15s, well before then.
    logged = evalc(['st = runBackgroundMonitoring(mock, ''DurationSec'', 3, ' ...
                    '''HeartbeatSec'', 0.05);']);

    assert(strcmp(st, 'error'), ...
        sprintf('L2: error-exit must return ''error'', got ''%s''', st));
    assert(strcmp(mock.Status, 'error'), ...
        sprintf('L2: pipeline must remain ''error'' on return, got ''%s''', mock.Status));

    loggedStatus = parseExitStatus_(logged);
    assert(strcmp(loggedStatus, 'error'), ...
        sprintf('L2: exit log must report ''error'', got ''%s''', loggedStatus));
    assert(strcmp(loggedStatus, st), ...
        'L2: logged exit status must match the returned status');

    % safeStop_ guards on 'running', so a faulted pipeline is never stopped...
    assert(mock.StopCount == 0, ...
        sprintf('L2: faulted pipeline must not be stopped via stop(); StopCount=%d', ...
            mock.StopCount));
    % ...and it was started exactly once.
    assert(mock.StartCount == 1, ...
        sprintf('L2: pipeline must be started exactly once; StartCount=%d', mock.StartCount));
    n = 1;
end

% ========================================================================
%  Fixtures and helpers
% ========================================================================

function p = makeEmptyPipeline_()
%MAKEEMPTYPIPELINE_ Real LiveEventPipeline with no monitors and no data
%   sources: runCycle is a cheap no-op, so the start/heartbeat/stop lifecycle
%   can be exercised without emitting events or touching disk.
    monitors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    p = LiveEventPipeline(monitors, DataSourceMap(), 'Interval', 1);
end

function s = parseExitStatus_(logged)
%PARSEEXITSTATUS_ Extract the status token from the runBackgroundMonitoring
%   exit line: "[BG] runBackgroundMonitoring exit: status=<S>, runtime=...".
    tok = regexp(logged, 'runBackgroundMonitoring exit:\s*status=(\w+)', ...
        'tokens', 'once');
    if isempty(tok)
        s = '<none>';
    else
        s = tok{1};
    end
end

function safeKill_(p)
%SAFEKILL_ Best-effort teardown: stop a still-running real pipeline.
    try
        if exist('isvalid', 'builtin') && ~isvalid(p)
            return;
        end
        if strcmp(p.Status, 'running')
            p.stop();
        end
    catch
        % best-effort
    end
end
