function varargout = install(varargin)
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
%   Test shim:
%     install('__probe_needs_build__') returns needs_build(root) as a
%     scalar logical.  Used exclusively by TestMexPrebuilt / test_mex_prebuilt.
%
%   Example:
%     install;               % run once after cloning
%     example_basic;         % everything just works
%     benchmark;             % benchmarks too
%     run_all_tests;         % and tests
%
%   See also build_mex, FastSense, mex_stamp.

    root = fileparts(mfilename('fullpath'));

    % --- Always: add all paths (fast, idempotent) ---
    addpath(fullfile(root, 'libs', 'FastSense'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    addpath(fullfile(root, 'libs', 'Dashboard'));
    addpath(fullfile(root, 'libs', 'WebBridge'));

    dirs = {'examples', 'benchmarks', 'tests'};
    for i = 1:numel(dirs)
        d = fullfile(root, dirs{i});
        if isfolder(d)
            addpath(genpath(d));
        end
    end

    % --- Octave: prepend platform-tagged MEX subdir to path (additive) ---
    % On Octave all platforms produce identically-named *.mex files, so
    % we store them in separate octave-<tag>/ subdirs and prepend the right
    % one.  This must happen BEFORE needs_build so the probe sees the binary.
    octTag = get_octave_platform_tag();
    if ~isempty(octTag)
        candidates = {
            fullfile(root, 'libs', 'FastSense', 'private',            ['octave-' octTag])
            fullfile(root, 'libs', 'FastSense',                        ['octave-' octTag])
            fullfile(root, 'libs', 'SensorThreshold', 'private',       ['octave-' octTag])
        };
        for k = 1:numel(candidates)
            if isfolder(candidates{k})
                addpath(candidates{k});
            end
        end
    end

    % --- Test shim: expose needs_build result for unit tests ---
    if nargin == 1 && ischar(varargin{1}) && strcmp(varargin{1}, '__probe_needs_build__')
        varargout{1} = needs_build(root);
        return;
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
%
%   Decision order (first matching rule wins):
%     1. FASTSENSE_SKIP_BUILD is non-empty -> false (force skip)
%     2. binary_search_mex.<mexext()> missing -> true  (must compile)
%     3. .mex-version stamp missing -> true  (cannot verify sources)
%     4. stamp content != mex_stamp(root) -> true  (sources changed)
%     5. Otherwise -> false  (trust shipped binary)

    if ~isempty(getenv('FASTSENSE_SKIP_BUILD'))
        yes = false;
        return;
    end
    mex_dir = fullfile(root, 'libs', 'FastSense', 'private');
    % Probe a representative MEX from the FastSense library.
    % On Octave we also accept the binary from the platform-tagged subdir
    % (libs/FastSense/private/octave-<tag>/) which install() adds to path
    % before calling needs_build.  The path-based exist() call picks it up
    % automatically when the subdir is on the path, so a third probe that
    % checks the absolute subdir path handles the case where the subdir was
    % NOT yet on path (e.g., when __probe_needs_build__ is called after a
    % fresh addpath in the shim but before the candidates loop would run).
    octTag = get_octave_platform_tag();
    probes = {
        fullfile(mex_dir, ['binary_search_mex.' mexext()])
        fullfile(mex_dir, 'binary_search_mex.mex')
    };
    if ~isempty(octTag)
        probes{end+1} = fullfile(mex_dir, ['octave-' octTag], 'binary_search_mex.mex');
    end
    core_ok = false;
    for pi = 1:numel(probes)
        if exist(probes{pi}, 'file') == 2 || exist(probes{pi}, 'file') == 3
            core_ok = true;
            break;
        end
    end
    if ~core_ok
        yes = true;
        return;
    end
    % Stamp check: if .mex-version matches current source hash, trust binary.
    if ~stamp_matches_(root, mex_dir)
        yes = true;
        return;
    end
    yes = false;
end

function ok = stamp_matches_(root, mex_dir)
%STAMP_MATCHES_ Return true iff .mex-version content matches mex_stamp(root).
%   Returns false on any I/O error or if stamp file is absent.
    stamp_file = fullfile(mex_dir, '.mex-version');
    if exist(stamp_file, 'file') ~= 2
        ok = false;
        return;
    end
    try
        stored = strtrim(fileread(stamp_file));
        current = mex_stamp(root);
        ok = strcmp(stored, current);
    catch
        ok = false;
    end
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


function tag = get_octave_platform_tag()
%GET_OCTAVE_PLATFORM_TAG Return platform tag string for Octave subdir layout.
%   Returns a char such as 'macos-arm64', 'linux-x86_64', etc., or '' when
%   called from MATLAB (where per-platform subdirs are not needed because
%   mexext() already disambiguates binaries by extension).
%
%   Tag derivation (from computer('arch') on Octave):
%     darwin  + aarch64/arm64  -> 'macos-arm64'
%     darwin  (other)          -> 'macos-x86_64'
%     linux   (any)            -> 'linux-x86_64'
%     mingw / w64 (any)        -> 'windows-x86_64'
%     unrecognized             -> ''

    if ~exist('OCTAVE_VERSION', 'builtin')
        tag = '';
        return;
    end
    arch     = lower(computer('arch'));
    isDarwin = ~isempty(strfind(arch, 'darwin'));
    isLinux  = ~isempty(strfind(arch, 'linux'));
    isWin    = ~isempty(strfind(arch, 'mingw')) || ~isempty(strfind(arch, 'w64'));
    isArm    = ~isempty(strfind(arch, 'aarch64')) || ~isempty(strfind(arch, 'arm64'));
    if isDarwin && isArm
        tag = 'macos-arm64';
    elseif isDarwin
        tag = 'macos-x86_64';
    elseif isLinux
        tag = 'linux-x86_64';
    elseif isWin
        tag = 'windows-x86_64';
    else
        tag = '';
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
