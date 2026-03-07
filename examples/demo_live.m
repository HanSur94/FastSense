% demo_live.m — Visual demo of live data updates.
%
% Creates a .mat file, plots it, then updates the file 5 times,
% showing how the plot adapts to new data.
% Output: demo_live_step0.png through demo_live_step5.png

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

outDir = fullfile(fileparts(mfilename('fullpath')), '..', 'demo_output');
if ~exist(outDir, 'dir'); mkdir(outDir); end

fprintf('=== FastPlot Live Mode Demo ===\n\n');

% --- Step 0: Create initial data and plot ---
tmpFile = fullfile(tempdir, 'fastplot_demo_live.mat');
nPoints = 50000;
x = linspace(0, 100, nPoints);
s.time = x;
s.pressure = sin(x * 2*pi/10) + 0.2*randn(1, nPoints);
s.temperature = 50 + 5*cos(x * 2*pi/20) + 0.3*randn(1, nPoints);
save(tmpFile, '-struct', 's');

fig = FastPlotFigure(2, 1, 'Theme', 'dark');
fp1 = fig.tile(1);
fp1.addLine(s.time, s.pressure, 'DisplayName', 'Pressure', 'Color', [0.3 0.7 1]);
fp1.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.3 0.3]);

fp2 = fig.tile(2);
fp2.addLine(s.time, s.temperature, 'DisplayName', 'Temperature', 'Color', [1 0.5 0.3]);
fp2.addThreshold(58, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.3 0.3]);

fig.renderAll();
fig.tileTitle(1, 'Pressure Sensor');
fig.tileTitle(2, 'Temperature Sensor');
drawnow;

outFile = fullfile(outDir, 'demo_live_step0.png');
print(fig.hFigure, outFile, '-dpng', '-r150');
fprintf('Step 0: Initial plot (%d points, t=[0..100]) -> %s\n', nPoints, outFile);

% --- Steps 1-5: Simulate live data updates ---
% In real use: startLive() watches the file and calls updateData via callback.
% Here we update the .mat file and call updateData directly to show the visual result.
for i = 1:5
    % Grow dataset and shift signals (simulates new data arriving)
    nNew = nPoints + i * 20000;
    s.time = linspace(0, 100 + i*20, nNew);
    s.pressure = sin(s.time * 2*pi/10) + 0.2*randn(1, nNew) + 0.3*i;
    s.temperature = 50 + 5*cos(s.time * 2*pi/20) + 0.3*randn(1, nNew) + i;
    save(tmpFile, '-struct', 's');

    % Update the plot (this is what the live mode callback does)
    fp1.updateData(1, s.time, s.pressure);
    fp2.updateData(1, s.time, s.temperature);
    drawnow;

    outFile = fullfile(outDir, sprintf('demo_live_step%d.png', i));
    print(fig.hFigure, outFile, '-dpng', '-r150');
    fprintf('Step %d: %d points, t=[0..%d], pressure +%.1f, temp +%d -> %s\n', ...
        i, nNew, 100 + i*20, 0.3*i, i, outFile);
end

close(fig.hFigure);
delete(tmpFile);
fprintf('\nDemo complete. %d PNGs saved to: %s\n', 6, outDir);
