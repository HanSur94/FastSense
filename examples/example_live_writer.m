% example_live_writer.m — Writer: simulates an external process updating a .mat file.
%
% Usage:
%   1. Run example_live_watch.m first (in another terminal)
%   2. Run this script: octave --no-gui examples/example_live_writer.m
%   3. Watch the dashboard update as this script writes new data

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

dataFile = fullfile(tempdir, 'fastplot_live_data.mat');
nUpdates = 20;
interval = 2;  % seconds between updates

fprintf('=== FastPlot Live Writer ===\n\n');
fprintf('Writing to: %s\n', dataFile);
fprintf('Sending %d updates, %ds apart.\n\n', nUpdates, interval);

% Write initial data
nPoints = 100000;
s.time = linspace(0, 100, nPoints);
s.pressure = sin(s.time * 2*pi/10) + 0.3*randn(1, nPoints);
s.temperature = 50 + 5*cos(s.time * 2*pi/20) + 0.5*randn(1, nPoints);
save(dataFile, '-struct', 's');
fprintf('  Initial: %d points, t=[0..100]\n', nPoints);

% Simulate data growing over time
for i = 1:nUpdates
    pause(interval);

    nNew = nPoints + i * 10000;
    s.time = linspace(0, 100 + i*10, nNew);
    s.pressure = sin(s.time * 2*pi/10) + 0.3*randn(1, nNew) + 0.15*i;
    s.temperature = 50 + 5*cos(s.time * 2*pi/20) + 0.5*randn(1, nNew) + 0.3*i;
    save(dataFile, '-struct', 's');

    fprintf('  Update %2d/%d: %d points, t=[0..%d], pressure +%.2f\n', ...
        i, nUpdates, nNew, 100 + i*10, 0.15*i);
end

fprintf('\nWriter finished. Data file: %s\n', dataFile);
