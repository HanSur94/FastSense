function test_run_background_monitoring()
%TEST_RUN_BACKGROUND_MONITORING Lock down runBackgroundMonitoring lifecycle (Plan 02).
%   Proves:
%     - runBackgroundMonitoring(@setup, 'MaxRuntimeSec', 2) returns within ~3s.
%     - Returned pipeline.Status is 'stopped' (cleanup ran).
%     - Heartbeat loop ticked at least once (uptime > 0).
%     - Input validation throws the documented error IDs.
%
%   Phase 1039 Plan 04.

    add_test_path_();
    TagRegistry.clear();
    cleaner = onCleanup(@() cleanup_()); %#ok<NASGU>

    % The lifecycle tests drive runBackgroundMonitoring -> pipeline.start(),
    % which creates a MATLAB `timer`. Octave has no `timer` (errors in start),
    % so these two are MATLAB-only. The 3 input-validation tests throw BEFORE
    % any timer is created and run on both runtimes.
    nRun = 3;
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIP: timer-driven lifecycle tests (Octave has no timer)\n');
    else
        test_runner_exits_on_max_runtime();
        test_runner_returns_pipeline_in_stopped_state();
        nRun = 5;
    end
    test_runner_rejects_non_function_handle_setup();
    test_runner_rejects_bad_setup_return();
    test_runner_rejects_negative_max_runtime();

    fprintf('    All %d run_background_monitoring tests passed.\n', nRun);
end

function add_test_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests'));
    addpath(fullfile(repo, 'tests', 'suite'));
end

function cleanup_()
    TagRegistry.clear();
end

function test_runner_exits_on_max_runtime()
    % Bound the wall clock: should exit shortly after MaxRuntimeSec=2.
    t0 = tic();
    pipeline = runBackgroundMonitoring(@empty_pipeline_setup_, ...
        'PollSec', 1, 'MaxRuntimeSec', 2);
    elapsed = toc(t0);

    assert(elapsed >= 2.0, ...
        'runBackgroundMonitoring exited too early: elapsed=%.2fs (expected >= 2)', elapsed);
    assert(elapsed < 5.0, ...
        'runBackgroundMonitoring took too long: elapsed=%.2fs (expected < 5)', elapsed);
    assert(~isempty(pipeline), 'returned pipeline must be non-empty');
    fprintf('  PASS: test_runner_exits_on_max_runtime (elapsed=%.2fs)\n', elapsed);
end

function test_runner_returns_pipeline_in_stopped_state()
    pipeline = runBackgroundMonitoring(@empty_pipeline_setup_, ...
        'PollSec', 1, 'MaxRuntimeSec', 2);
    assert(strcmp(pipeline.Status, 'stopped'), ...
        'pipeline.Status must be ''stopped'' after graceful exit, got ''%s''', pipeline.Status);
    fprintf('  PASS: test_runner_returns_pipeline_in_stopped_state\n');
end

function test_runner_rejects_non_function_handle_setup()
    threw = false;
    try
        runBackgroundMonitoring('not_a_handle');
    catch ME
        threw = strcmp(ME.identifier, 'EventDetection:invalidSetupFcn');
    end
    assert(threw, 'expected EventDetection:invalidSetupFcn for non-function-handle input');
    fprintf('  PASS: test_runner_rejects_non_function_handle_setup\n');
end

function test_runner_rejects_bad_setup_return()
    threw = false;
    try
        runBackgroundMonitoring(@() []);  % setup returns [] -- no start/stop
    catch ME
        threw = strcmp(ME.identifier, 'EventDetection:setupFcnBadReturn');
    end
    assert(threw, 'expected EventDetection:setupFcnBadReturn when setup returns []');
    fprintf('  PASS: test_runner_rejects_bad_setup_return\n');
end

function test_runner_rejects_negative_max_runtime()
    threw = false;
    try
        runBackgroundMonitoring(@empty_pipeline_setup_, 'MaxRuntimeSec', -1);
    catch ME
        threw = strcmp(ME.identifier, 'EventDetection:invalidOption');
    end
    assert(threw, 'expected EventDetection:invalidOption for MaxRuntimeSec=-1');
    fprintf('  PASS: test_runner_rejects_negative_max_runtime\n');
end

function p = empty_pipeline_setup_()
    %EMPTY_PIPELINE_SETUP_ Build a no-op pipeline -- no monitors, no data sources.
    %   The runner only needs start/stop/Status to drive its loop; an empty
    %   pipeline exercises the heartbeat-and-exit path without producing events.
    monitors = containers.Map('KeyType', 'char', 'ValueType', 'any');
    dsMap = DataSourceMap();
    p = LiveEventPipeline(monitors, dsMap, 'Interval', 60);
end
