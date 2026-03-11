%% Mixed Tile Types — FastPlot + raw MATLAB axes in one dashboard
% Demonstrates using fig.axes(n) alongside fig.tile(n) for plot types
% that FastPlot doesn't handle (bar, scatter, histogram, stem, etc.)

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

n = 500000;
x = linspace(0, 120, n);

fprintf('Mixed tile dashboard: 2x3 grid, FastPlot + raw axes...\n');
tic;

fig = FastPlotFigure(2, 3, 'Theme', 'light', ...
    'Name', 'Mixed Tile Types Demo', 'Position', [50 50 1500 800]);

% --- Tile 1: FastPlot time series (temperature) ---
fp1 = fig.tile(1);
y_temp = 70 + 10*sin(x*2*pi/30) + 2*randn(1,n);
fp1.addLine(x, y_temp, 'DisplayName', 'Temperature');
fp1.addThreshold(80, 'Direction', 'upper', 'ShowViolations', true);

% --- Tile 2: Raw axes — bar chart (daily summary) ---
ax2 = fig.axes(2);
days = categorical({'Mon','Tue','Wed','Thu','Fri','Sat','Sun'});
days = reordercats(days, {'Mon','Tue','Wed','Thu','Fri','Sat','Sun'});
counts = [12 8 15 6 20 3 1];
b = bar(ax2, days, counts, 'FaceColor', 'flat');
b.CData = repmat([0.3 0.7 1], 7, 1);
grid(ax2, 'on');

% --- Tile 3: Raw axes — scatter plot (correlation) ---
ax3 = fig.axes(3);
s_temp = 60 + 30*rand(1, 200);
s_press = 0.5*s_temp + 10*randn(1, 200) + 20;
scatter(ax3, s_temp, s_press, 25, s_temp, 'filled', 'MarkerFaceAlpha', 0.6);
colormap(ax3, 'parula');
grid(ax3, 'on');

% --- Tile 4: FastPlot time series (pressure, spans 2 cols) ---
fig.setTileSpan(4, [1 2]);
fp4 = fig.tile(4);
y_press = 100 + 15*sin(x*2*pi/60) + 3*randn(1,n);
y_upper = 100 + 15*sin(x*2*pi/60) + 8;
y_lower = 100 + 15*sin(x*2*pi/60) - 8;
fp4.addShaded(x, y_upper, y_lower, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.12);
fp4.addLine(x, y_press, 'DisplayName', 'Pressure');

% --- Tile 6: Raw axes — histogram (value distribution) ---
ax6 = fig.axes(6);
histogram(ax6, y_temp(1:10000), 40, 'FaceColor', [0.85 0.33 0.1], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.8);
grid(ax6, 'on');

% Render all tiles
fig.renderAll();

% Apply labels (works on both FastPlot and raw axes tiles)
fig.tileTitle(1, 'Temperature (C)');
fig.tileXLabel(1, 'Time (s)');
fig.tileTitle(2, 'Alarm Events / Day');
fig.tileYLabel(2, 'Count');
fig.tileTitle(3, 'Temp vs Pressure');
fig.tileXLabel(3, 'Temperature (C)');
fig.tileYLabel(3, 'Pressure (bar)');
fig.tileTitle(4, 'Pressure with Confidence Band');
fig.tileXLabel(4, 'Time (s)');
fig.tileTitle(6, 'Temperature Distribution');
fig.tileXLabel(6, 'Temperature (C)');
fig.tileYLabel(6, 'Frequency');

fprintf('Mixed tile dashboard rendered in %.3f seconds.\n', toc);
