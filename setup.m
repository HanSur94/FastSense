function setup()
%SETUP Add libraries to path and compile MEX files (including mksqlite/SQLite).
%   SETUP() locates the project root (the directory containing this
%   file), then adds the FastSense, SensorThreshold, and EventDetection
%   library folders to the MATLAB search path using addpath. It then
%   compiles all MEX files, including mksqlite for SQLite-backed
%   DataStore support.
%
%   Run this once per MATLAB session, or add a call to your startup.m
%   for automatic initialization.
%
%   The following directories are added:
%     <project_root>/libs/FastSense
%     <project_root>/libs/SensorThreshold
%     <project_root>/libs/EventDetection
%     <project_root>/libs/Dashboard
%
%   MEX compilation includes:
%     - SIMD-optimized downsampling kernels (AVX2/NEON)
%     - mksqlite (SQLite3 MEX interface for large-dataset disk storage)
%
%   SQLite3 is bundled as the amalgamation (sqlite3.c + sqlite3.h) in
%   libs/FastSense/private/mex_src/, so no system SQLite installation is
%   required. It compiles directly into the MEX files on all platforms
%   (Linux, macOS, Windows).
%
%   Example:
%     setup();   % adds libraries to path, compiles MEX; prints status
%
%   See also addpath, FastSenseDefaults, build_mex, FastSenseDataStore.

    % Determine the project root from this file's location
    root = fileparts(mfilename('fullpath'));

    % Add library directories to the MATLAB search path
    addpath(fullfile(root, 'libs', 'FastSense'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    addpath(fullfile(root, 'libs', 'Dashboard'));
    addpath(fullfile(root, 'libs', 'WebBridge'));
    fprintf('FastSense + SensorThreshold + EventDetection + Dashboard + WebBridge libraries added to path.\n');

    % Compile all MEX files (SIMD kernels + bundled SQLite3)
    % Set FASTSENSE_SKIP_BUILD=1 to skip (e.g., CI with pre-cached MEX)
    if isempty(getenv('FASTSENSE_SKIP_BUILD'))
        fprintf('\n--- Compiling MEX files ---\n');
        build_mex();
    else
        fprintf('MEX compilation skipped (FASTSENSE_SKIP_BUILD set).\n');
    end
end
