% example_live.m — Interactive live mode demo (GUI)
%
% Opens a dashboard with large data (500K+ points), starts timer-based
% live mode, and simulates 20 data updates so you can watch downsampling
% and live polling in action.
%
% Usage:
%   >> cd /path/to/FastPlot
%   >> run examples/example_live.m

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));

fprintf('\n=== FastPlot Live Mode Demo (Large Data) ===\n\n');

% --- Create initial data and save to .mat ---
tmpFile = fullfile(tempdir, 'fastplot_live_demo.mat');
nPoints = 500000;
x = linspace(0, 200, nPoints);
s.time = x;
s.pressure = sin(x * 2*pi/10) + 0.3*randn(1, nPoints);
s.temperature = 50 + 5*cos(x * 2*pi/20) + 0.5*randn(1, nPoints);
save(tmpFile, '-struct', 's');
fprintf('Initial data: %d points saved to %s\n', nPoints, tmpFile);

% --- Create dashboard ---
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
tb = FastPlotToolbar(fig);
drawnow;

fprintf('Dashboard open. Starting live mode with 20 updates (2s apart)...\n');
fprintf('Watch the plot update! Close the figure to stop early.\n\n');

% --- Start timer-based live mode ---
fig.startLive(tmpFile, @updateTiles, 'Interval', 1.5, 'ViewMode', 'follow');

nUpdates = 20;
for i = 1:nUpdates
    pause(2);
    if ~ishandle(fig.hFigure)
        fprintf('Figure closed.\n');
        break;
    end

    % Grow dataset: add 50K points per update, shift signals
    nNew = nPoints + i * 50000;
    s.time = linspace(0, 200 + i*20, nNew);
    s.pressure = sin(s.time * 2*pi/10) + 0.3*randn(1, nNew) + 0.1*i;
    s.temperature = 50 + 5*cos(s.time * 2*pi/20) + 0.5*randn(1, nNew) + 0.2*i;

    % Write updated data — the timer will pick it up automatically
    save(tmpFile, '-struct', 's');

    fprintf('  Update %2d/%d: %7d points, t=[0..%d], pressure +%.1f\n', ...
        i, nUpdates, nNew, 200 + i*20, 0.1*i);
end

% Wait for last timer tick to process
pause(3);
drawnow;

if ishandle(fig.hFigure)
    fig.stopLive();
end

fprintf('\nDemo complete. Figure stays open — zoom and pan to explore.\n');
fprintf('Temp file: %s\n', tmpFile);


%% --- Local functions ---

function updateTiles(f, d)
    f.tile(1).updateData(1, d.time, d.pressure);
    f.tile(2).updateData(1, d.time, d.temperature);
end
