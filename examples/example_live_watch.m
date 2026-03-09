% example_live_watch.m — Watcher: opens dashboard, polls .mat file for changes.
%
% Usage:
%   1. Run this script first (opens the GUI dashboard)
%   2. In a second terminal, run: octave --no-gui examples/example_live_writer.m
%   3. Watch the plot update as the writer modifies the .mat file
%   4. Close the figure or press Ctrl+C to stop

addpath(fileparts(mfilename('fullpath')));  % examples/ dir (for updateDashboard.m)
run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'libs', 'FastPlot', 'private'));

dataFile = fullfile(tempdir, 'fastplot_live_data.mat');

fprintf('=== FastPlot Live Watcher ===\n\n');

% Wait for the data file to appear
if ~exist(dataFile, 'file')
    fprintf('Waiting for data file: %s\n', dataFile);
    fprintf('Run example_live_writer.m in another terminal to create it.\n\n');
    while ~exist(dataFile, 'file')
        pause(0.5);
    end
end
pause(0.5);  % let writer finish writing

% Load initial data and create dashboard
d = load(dataFile);
fprintf('Data file found. %d points.\n', numel(d.time));

fig = FastPlotFigure(2, 1, 'Theme', 'dark', 'Name', 'Live Dashboard');

fp1 = fig.tile(1);
fp1.addLine(d.time, d.pressure, 'DisplayName', 'Pressure', 'Color', [0.3 0.7 1]);
fp1.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);

fp2 = fig.tile(2);
fp2.addLine(d.time, d.temperature, 'DisplayName', 'Temperature', 'Color', [1 0.5 0.3]);
fp2.addThreshold(58, 'Direction', 'upper', 'ShowViolations', true);

fig.renderAll();
fig.tileTitle(1, 'Pressure');
fig.tileTitle(2, 'Temperature');
tb = FastPlotToolbar(fig);
drawnow;

% Start live mode — polls file and calls updateDashboard on changes
fig.startLive(dataFile, @updateDashboard, 'Interval', 1.5, 'ViewMode', 'preserve');

fprintf('Live mode active. Watching: %s\n', dataFile);
fprintf('Close figure or Ctrl+C to stop.\n\n');

% Block until figure closes (Octave: poll loop, MATLAB: no-op since timer runs)
fig.runLive();

fprintf('Watcher stopped.\n');
