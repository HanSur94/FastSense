function install()
%INSTALL Set up the FastSense project: add paths and compile MEX files.
%   INSTALL() adds all project directories to the MATLAB path and, on first
%   run, compiles the MEX accelerators. Subsequent calls just add paths
%   (fast and silent) — safe to call from tests or examples.
%
%   Run once after cloning the repo. After that, all examples, benchmarks,
%   and tests work out of the box.
%
%   What it does:
%     1. Adds all library directories to the MATLAB path
%     2. Adds examples, benchmarks, and tests to the path
%     3. Compiles MEX accelerators if not yet built (first run only)
%     4. Verifies the installation (first run only)
%     5. JIT warmup — runs a tiny end-to-end workflow to force-compile
%        all hot code paths (once per MATLAB session)
%
%   Directories added:
%     libs/FastSense          — core plotting engine
%     libs/SensorThreshold    — state-dependent sensor modeling
%     libs/EventDetection     — violation detection & live pipeline
%     libs/Dashboard          — widget-based dashboard engine
%     libs/WebBridge          — browser-based visualization bridge
%     examples/               — runnable example scripts
%     benchmarks/             — performance benchmarks
%     tests/                  — test suites
%
%   MEX compilation (first run):
%     - Detects CPU architecture (x86_64 / ARM64) and compiler
%     - Compiles SIMD-optimized kernels (AVX2 / NEON) with fallback
%     - Bundles SQLite3 amalgamation (no system install required)
%
%   Environment variables:
%     FASTSENSE_SKIP_BUILD=1  — skip MEX compilation (CI with cache)
%
%   Example:
%     install;               % run once after cloning
%     example_basic;         % everything just works
%     benchmark;             % benchmarks too
%     run_all_tests;         % and tests
%
%   See also build_mex, FastSense.

    root = fileparts(mfilename('fullpath'));

    % --- Always: add all paths (fast, idempotent) ---
    addpath(fullfile(root, 'libs', 'FastSense'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    addpath(fullfile(root, 'libs', 'Dashboard'));
    addpath(fullfile(root, 'libs', 'WebBridge'));

    % Demo workspaces (Phase 1015+): add each demo dir so the entry-point
    % function (e.g. run_demo) is callable without manual addpath.
    demoRoot = fullfile(root, 'demo');
    if isfolder(demoRoot)
        addpath(fullfile(demoRoot, 'industrial_plant'));
    end

    dirs = {'examples', 'benchmarks', 'tests'};
    for i = 1:numel(dirs)
        d = fullfile(root, dirs{i});
        if isfolder(d)
            addpath(genpath(d));
        end
    end

    % --- First run only: compile MEX and verify ---
    if needs_build(root)
        first_run(root);
    end

    % --- Once per session: JIT warmup ---
    jit_warmup();
end

function yes = needs_build(root)
%NEEDS_BUILD Check whether MEX accelerators need to be compiled.
    if ~isempty(getenv('FASTSENSE_SKIP_BUILD'))
        yes = false;
        return;
    end
    mex_dir = fullfile(root, 'libs', 'FastSense', 'private');
    % Probe a representative MEX from the FastSense library -- if missing,
    % trigger build_mex() which will compile only the missing ones.
    probes = {
        fullfile(mex_dir, ['binary_search_mex.' mexext()])
        fullfile(mex_dir, 'binary_search_mex.mex')
    };
    core_ok = exist(probes{1}, 'file') == 3 || exist(probes{2}, 'file') == 3;
    yes = ~core_ok;
end

function first_run(root)
%FIRST_RUN Compile MEX files and verify the installation.
    fprintf('\n');
    fprintf('==============================================\n');
    fprintf('  FastSense Install\n');
    fprintf('==============================================\n\n');
    fprintf('  Libraries:  FastSense, SensorThreshold, EventDetection, Dashboard, WebBridge\n');
    fprintf('  Extras:     examples, benchmarks, tests\n\n');

    fprintf('--- Compiling MEX files ---\n');
    build_mex();

    fprintf('\n--- Verifying installation ---\n');
    verify_installation(root);

    fprintf('\n==============================================\n');
    fprintf('  Install complete! Try:  example_basic\n');
    fprintf('==============================================\n\n');
end

function verify_installation(root)
%VERIFY_INSTALLATION Check that core classes, MEX files, and directories are accessible.
    n_ok = 0;
    n_warn = 0;

    % Check core classes
    core_classes = {'FastSense', 'SensorTag', 'EventDetector', ...
                    'DashboardEngine', 'WebBridge'};
    for i = 1:numel(core_classes)
        if exist(core_classes{i}, 'class') == 8 || exist(core_classes{i}, 'file') == 2
            n_ok = n_ok + 1;
        else
            fprintf('  WARNING: %s not found on path\n', core_classes{i});
            n_warn = n_warn + 1;
        end
    end
    fprintf('  Core classes:      %d/%d found\n', n_ok, numel(core_classes));

    % Check MEX accelerators
    mex_dir = fullfile(root, 'libs', 'FastSense', 'private');
    mex_file = fullfile(mex_dir, ['binary_search_mex.' mexext()]);
    mex_file_oct = fullfile(mex_dir, 'binary_search_mex.mex');
    if exist(mex_file, 'file') == 3 || exist(mex_file_oct, 'file') == 3
        fprintf('  MEX accelerators:  available\n');
        n_ok = n_ok + 1;
    else
        fprintf('  MEX accelerators:  not compiled (MATLAB fallback active)\n');
        n_warn = n_warn + 1;
    end

    % Check examples
    if exist(fullfile(root, 'examples', '01-basics', 'example_basic.m'), 'file') == 2
        n_examples = numel(dir(fullfile(root, 'examples', '**', 'example_*.m')));
        fprintf('  Examples:          %d scripts\n', n_examples);
        n_ok = n_ok + 1;
    else
        fprintf('  WARNING: examples not found\n');
        n_warn = n_warn + 1;
    end

    % Check benchmarks
    if exist(fullfile(root, 'benchmarks', 'benchmark.m'), 'file') == 2
        fprintf('  Benchmarks:        ready\n');
        n_ok = n_ok + 1;
    else
        fprintf('  WARNING: benchmarks not found\n');
        n_warn = n_warn + 1;
    end

    % Check tests
    if exist(fullfile(root, 'tests', 'run_all_tests.m'), 'file') == 2
        fprintf('  Tests:             ready\n');
        n_ok = n_ok + 1;
    else
        fprintf('  WARNING: tests not found\n');
        n_warn = n_warn + 1;
    end

    total = n_ok + n_warn;
    if n_warn == 0
        fprintf('  All checks passed  (%d/%d)\n', n_ok, total);
    else
        fprintf('  %d/%d checks passed, %d warnings\n', n_ok, total, n_warn);
    end
end


function jit_warmup()
%JIT_WARMUP Force MATLAB's JIT to compile all hot code paths once per session.
%   Runs a tiny end-to-end workflow (Tag creation, MonitorTag evaluation,
%   downsampling, rendering setup) on trivial data.  Subsequent calls are
%   no-ops.  Adds ~0.1-0.3 s on first install() call but eliminates
%   multi-second JIT overhead on real workloads.
    persistent warmedUp;
    if ~isempty(warmedUp)
        return;
    end
    warmedUp = true;

    try
        % --- SensorTag + StateTag + MonitorTag pipeline ---
        st = SensorTag('__jit_warmup__', ...
            'X', [0 1 2 3 4 5], 'Y', [50 60 40 70 30 80]);

        stateT = StateTag('s1', 'X', [0 2 4], 'Y', [0 1 2]);

        mon = MonitorTag('upper_1', st, @(x, y) y > 65);
        [~, ~] = mon.getXY();

        % --- FastSense downsample + render setup (hidden figure) ---
        fig = figure('Visible', 'off');
        ax = axes('Parent', fig);
        fp = FastSense('Parent', ax);
        fp.addTag(st);
        fp.render();
        close(fig);
    catch
        % Warmup is best-effort -- never block install on failure
    end
end
