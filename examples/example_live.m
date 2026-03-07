% example_live.m — Live mode demo
% Simulates a background process writing sensor data to a .mat file,
% while FastPlot watches and auto-refreshes.
%
% Usage: Run this script. It creates a temp .mat file, plots it,
% starts live mode, then simulates 10 file updates.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

fprintf('=== FastPlot Live Mode Demo ===\n\n');

% Create initial data
tmpFile = fullfile(tempdir, 'fastplot_live_demo.mat');
nPoints = 100000;
x = linspace(0, 100, nPoints);
y_pressure = sin(x * 2*pi/10) + 0.3*randn(1, nPoints);
y_temperature = 50 + 5*cos(x * 2*pi/20) + 0.5*randn(1, nPoints);

s.time = x;
s.pressure = y_pressure;
s.temperature = y_temperature;
save(tmpFile, '-struct', 's');
fprintf('Initial data saved to: %s\n', tmpFile);

% Create dashboard
fig = FastPlotFigure(2, 1, 'Theme', 'dark', 'Name', 'Live Dashboard');

fp1 = fig.tile(1);
fp1.addLine(s.time, s.pressure, 'DisplayName', 'Pressure', 'Color', [0.3 0.7 1]);
fp1.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true);

fp2 = fig.tile(2);
fp2.addLine(s.time, s.temperature, 'DisplayName', 'Temperature', 'Color', [1 0.5 0.3]);
fp2.addThreshold(58, 'Direction', 'upper', 'ShowViolations', true);

fig.renderAll();
fig.tileTitle(1, 'Pressure');
fig.tileTitle(2, 'Temperature');

% Start live mode
fig.startLive(tmpFile, @(fig, d) updateDashboard(fig, d), ...
    'Interval', 1.5, 'ViewMode', 'preserve');

tb = FastPlotToolbar(fig);
fprintf('Live mode active. Toolbar has Live and Refresh buttons.\n');
fprintf('Simulating %d data updates...\n\n', 10);

% In Octave: start blocking poll loop (keeps GUI responsive)
% In MATLAB: the timer is already running, runLive() is a no-op
fprintf('Starting live poll loop. Update the file externally to see changes.\n');
fprintf('Close the figure or press Ctrl+C to exit.\n\n');

% For demo purposes, write a few updates from a background process
% (In real use, another program writes the file)
try
    if exist('OCTAVE_VERSION', 'builtin')
        % Write updates in foreground with short pauses between poll cycles
        for i = 1:10
            pause(2);
            if ~ishandle(fig.hFigure); break; end
            nNew = nPoints + i * 10000;
            s.time = linspace(0, 100 + i*10, nNew);
            s.pressure = sin(s.time * 2*pi/10) + 0.3*randn(1, nNew) + 0.1*i;
            s.temperature = 50 + 5*cos(s.time * 2*pi/20) + 0.5*randn(1, nNew) + 0.2*i;
            save(tmpFile, '-struct', 's');
            fprintf('  Update %d: %d points written\n', i, nNew);
            fig.refresh();
            drawnow;
        end
    else
        fig.runLive();
    end
catch
end

fprintf('\nDemo complete. Close figure to exit.\n');
fprintf('Temp file: %s\n', tmpFile);

function updateDashboard(fig, d)
    fig.tile(1).updateData(1, d.time, d.pressure);
    fig.tile(2).updateData(1, d.time, d.temperature);
end
