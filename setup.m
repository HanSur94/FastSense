function setup()
%SETUP Add libraries to path and compile MEX files (including mksqlite/SQLite).
%   SETUP() locates the project root (the directory containing this
%   file), then adds the FastPlot, SensorThreshold, and EventDetection
%   library folders to the MATLAB search path using addpath. It then
%   compiles all MEX files, including mksqlite for SQLite-backed
%   DataStore support.
%
%   Run this once per MATLAB session, or add a call to your startup.m
%   for automatic initialization.
%
%   The following directories are added:
%     <project_root>/libs/FastPlot
%     <project_root>/libs/SensorThreshold
%     <project_root>/libs/EventDetection
%     <project_root>/libs/Dashboard
%
%   MEX compilation includes:
%     - SIMD-optimized downsampling kernels (AVX2/NEON)
%     - mksqlite (SQLite3 MEX interface for large-dataset disk storage)
%
%   SQLite3 is bundled as the amalgamation (sqlite3.c + sqlite3.h) in
%   libs/FastPlot/private/mex_src/, so no system SQLite installation is
%   required. It compiles directly into the MEX files on all platforms
%   (Linux, macOS, Windows).
%
%   Example:
%     setup();   % adds libraries to path, compiles MEX; prints status
%
%   See also addpath, FastPlotDefaults, build_mex, FastPlotDataStore.

    % Determine the project root from this file's location
    root = fileparts(mfilename('fullpath'));

    % Add library directories to the MATLAB search path
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    addpath(fullfile(root, 'libs', 'EventDetection'));
    addpath(fullfile(root, 'libs', 'Dashboard'));
    fprintf('FastPlot + SensorThreshold + EventDetection + Dashboard libraries added to path.\n');

    % Compile all MEX files (SIMD kernels + bundled SQLite3)
    fprintf('\n--- Compiling MEX files ---\n');
    build_mex();
end
