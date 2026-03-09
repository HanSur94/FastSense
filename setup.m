function setup()
%SETUP Add FastPlot and SensorThreshold libraries to the MATLAB path.
%   SETUP() locates the project root (the directory containing this
%   file), then adds the FastPlot and SensorThreshold library folders
%   to the MATLAB search path using addpath. This makes all library
%   classes, functions, and MEX binaries available for the current
%   session without requiring manual path configuration.
%
%   Run this once per MATLAB session, or add a call to your startup.m
%   for automatic initialization.
%
%   The following directories are added:
%     <project_root>/libs/FastPlot
%     <project_root>/libs/SensorThreshold
%
%   Example:
%     setup();   % adds libraries to path; prints confirmation
%
%   See also addpath, FastPlotDefaults, build_mex.

    % Determine the project root from this file's location
    root = fileparts(mfilename('fullpath'));

    % Add library directories to the MATLAB search path
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    fprintf('FastPlot + SensorThreshold libraries added to path.\n');
end
