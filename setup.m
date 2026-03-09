function setup()
%SETUP Add FastPlot and SensorThreshold libraries to the MATLAB path.
%   Run this once per session to make all library classes available.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'libs', 'FastPlot'));
    addpath(fullfile(root, 'libs', 'SensorThreshold'));
    fprintf('FastPlot + SensorThreshold libraries added to path.\n');
end
