% generate_readme_images.m — Generate README screenshots for FastPlot features
% Run from the FastPlot root directory:
%   octave --no-gui --eval "setup; run('docs/generate_readme_images.m')"

img_dir = fullfile(fileparts(mfilename('fullpath')), 'images');
if ~exist(img_dir, 'dir'); mkdir(img_dir); end

dpi = '-r150';

%% 1. Basic plot with thresholds
fprintf('Generating: basic_thresholds.png ...\n');
x = linspace(0, 100, 1e6);
y = sin(x * 2*pi / 10) + 0.5 * randn(1, numel(x));

fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Sensor1', 'Color', 'b');
fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'r');
fp.render();
title(fp.hAxes, 'Basic Plot with Thresholds');
print(fp.hFigure, fullfile(img_dir, 'basic_thresholds.png'), '-dpng', dpi);
close(fp.hFigure);
fprintf('  done.\n');

%% 2. Dashboard layout
fprintf('Generating: dashboard.png ...\n');
x = linspace(0, 100, 5e5);
y1 = sin(x * 2*pi / 15) * 40 + 50 + 5 * randn(1, numel(x));
y2 = cos(x * 2*pi / 20) * 20 + 60 + 3 * randn(1, numel(x));
y3 = sin(x * 2*pi / 8) * 15 + 30 + 4 * randn(1, numel(x));
y4 = cumsum(randn(1, numel(x))) / 100 + 10;

fig = FastPlotFigure(2, 2, 'Theme', 'dark');
fig.setTileSpan(1, [1 2]);

fp1 = fig.tile(1);
fp1.addLine(x, y1, 'DisplayName', 'Temperature');
fp1.addBand(85, 95, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15);
fp1.addThreshold(90, 'Direction', 'upper', 'ShowViolations', true);

fp3 = fig.tile(3);
fp3.addLine(x, y2, 'DisplayName', 'Pressure');
fp3.addThreshold(75, 'Direction', 'upper', 'ShowViolations', true);

fp4 = fig.tile(4);
fp4.addLine(x, y3, 'DisplayName', 'Vibration');

fig.renderAll();
fig.tileTitle(1, 'Temperature');
fig.tileTitle(3, 'Pressure');
fig.tileTitle(4, 'Vibration');
print(fig.hFigure, fullfile(img_dir, 'dashboard.png'), '-dpng', dpi);
close(fig.hFigure);
fprintf('  done.\n');

%% 3. Theme comparison
fprintf('Generating: themes.png ...\n');
themes = {'default', 'dark', 'light', 'industrial', 'scientific'};
x = linspace(0, 50, 2e5);
y1 = sin(x * 2*pi / 10) + 0.3 * randn(1, numel(x));
y2 = cos(x * 2*pi / 7) * 0.8 + 0.2 * randn(1, numel(x));

hFig = figure('Position', [50 50 1600 600], 'Color', [0.95 0.95 0.95]);
for i = 1:5
    ax = subplot(1, 5, i, 'Parent', hFig);
    fp = FastPlot('Parent', ax, 'Theme', themes{i});
    fp.addLine(x, y1, 'DisplayName', 'Sine');
    fp.addLine(x, y2, 'DisplayName', 'Cosine');
    fp.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
    fp.render();
    title(ax, themes{i});
end
print(hFig, fullfile(img_dir, 'themes.png'), '-dpng', dpi);
close(hFig);
fprintf('  done.\n');

%% 4. Linked axes
fprintf('Generating: linked_axes.png ...\n');
x = linspace(0, 100, 5e5);
y_pressure = sin(x * 2*pi / 15) * 30 + 100 + 5 * randn(1, numel(x));
y_temp = cos(x * 2*pi / 12) * 20 + 60 + 3 * randn(1, numel(x));
y_vibration = sin(x * 2*pi / 5) * 5 + 2 * randn(1, numel(x));

hFig = figure('Position', [100 100 1200 700]);
ax1 = subplot(3, 1, 1, 'Parent', hFig);
fp1 = FastPlot('Parent', ax1, 'LinkGroup', 'sensors');
fp1.addLine(x, y_pressure, 'DisplayName', 'Pressure', 'Color', [0 0.45 0.74]);
fp1.addThreshold(125, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
fp1.render();
title(ax1, 'Pressure (linked)');

ax2 = subplot(3, 1, 2, 'Parent', hFig);
fp2 = FastPlot('Parent', ax2, 'LinkGroup', 'sensors');
fp2.addLine(x, y_temp, 'DisplayName', 'Temperature', 'Color', [0.85 0.33 0.1]);
fp2.addThreshold(75, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
fp2.render();
title(ax2, 'Temperature (linked)');

ax3 = subplot(3, 1, 3, 'Parent', hFig);
fp3 = FastPlot('Parent', ax3, 'LinkGroup', 'sensors');
fp3.addLine(x, y_vibration, 'DisplayName', 'Vibration', 'Color', [0.47 0.67 0.19]);
fp3.render();
title(ax3, 'Vibration (linked)');
print(hFig, fullfile(img_dir, 'linked_axes.png'), '-dpng', dpi);
close(hFig);
fprintf('  done.\n');

%% 5. NaN gaps
fprintf('Generating: nan_gaps.png ...\n');
x = linspace(0, 100, 5e5);
y = sin(x * 2*pi / 10) + 0.3 * randn(1, numel(x));
y(100000:120000) = NaN;
y(250000:280000) = NaN;
y(400000:410000) = NaN;

fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Sensor (with dropouts)', 'Color', [0 0.45 0.74]);
fp.render();
title(fp.hAxes, 'NaN Gap Handling');
print(fp.hFigure, fullfile(img_dir, 'nan_gaps.png'), '-dpng', dpi);
close(fp.hFigure);
fprintf('  done.\n');

%% 6. Alarm bands
fprintf('Generating: alarm_bands.png ...\n');
x = linspace(0, 100, 5e5);
y = sin(x * 2*pi / 15) * 40 + 50 + 8 * randn(1, numel(x));

fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Process Value', 'Color', [0.3 0.75 0.93]);
fp.addBand(85, 95, 'FaceColor', [1 0 0], 'FaceAlpha', 0.12, 'Label', 'HH Alarm');
fp.addBand(75, 85, 'FaceColor', [1 0.6 0], 'FaceAlpha', 0.10, 'Label', 'H Alarm');
fp.addBand(15, 25, 'FaceColor', [1 0.6 0], 'FaceAlpha', 0.10, 'Label', 'L Alarm');
fp.addBand(5, 15, 'FaceColor', [1 0 0], 'FaceAlpha', 0.12, 'Label', 'LL Alarm');
fp.addThreshold(90, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.2 0.2], 'Label', 'HH');
fp.addThreshold(80, 'Direction', 'upper', 'ShowViolations', true, 'Color', [1 0.6 0], 'Label', 'H');
fp.addThreshold(20, 'Direction', 'lower', 'ShowViolations', true, 'Color', [1 0.6 0], 'Label', 'L');
fp.addThreshold(10, 'Direction', 'lower', 'ShowViolations', true, 'Color', [1 0.2 0.2], 'Label', 'LL');
fp.render();
title(fp.hAxes, 'Industrial Alarm Bands (HH/H/L/LL)');
print(fp.hFigure, fullfile(img_dir, 'alarm_bands.png'), '-dpng', dpi);
close(fp.hFigure);
fprintf('  done.\n');

%% 7. Sensor with state-dependent thresholds
fprintf('Generating: sensor_thresholds.png ...\n');
x = linspace(0, 100, 5e5);
y = randn(1, numel(x)) * 10 + 50;

s = Sensor('pressure', 'Name', 'Chamber Pressure');
s.X = x;
s.Y = y;

sc = StateChannel('machine');
sc.X = [0 30 60 80];
sc.Y = [0 1 2 1];
s.addStateChannel(sc);

s.addThresholdRule(struct('machine', 1), 70, 'Direction', 'upper', 'Label', 'Run HI');
s.addThresholdRule(struct('machine', 2), 55, 'Direction', 'upper', 'Label', 'Boost HI');
s.addThresholdRule(struct('machine', 1), 30, 'Direction', 'lower', 'Label', 'Run LO');
s.resolve();

fp = FastPlot('Theme', 'dark');
fp.addSensor(s);
fp.render();
title(fp.hAxes, 'Condition-Dependent Sensor Thresholds');
print(fp.hFigure, fullfile(img_dir, 'sensor_thresholds.png'), '-dpng', dpi);
close(fp.hFigure);
fprintf('  done.\n');

%% 8. Datetime axes
fprintf('Generating: datetime_axes.png ...\n');
x = datenum(2024,1,1) + (0:499999)/86400;
y = sin((1:500000) * 2*pi/3600) + 0.3 * randn(1, 500000);

fp = FastPlot();
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Sensor');
fp.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
fp.render();
title(fp.hAxes, 'Datetime Axis with Auto-Formatted Ticks');
print(fp.hFigure, fullfile(img_dir, 'datetime_axes.png'), '-dpng', dpi);
close(fp.hFigure);
fprintf('  done.\n');

fprintf('\nAll README images generated in: %s\n', img_dir);
