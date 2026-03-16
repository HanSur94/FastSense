%% FastPlot Dashboard — Tiled layout with themes and visual enhancements
% Demonstrates FastPlotFigure, theming, bands, shading, and markers.
%
% Choosing your dashboard approach:
%   FastPlotFigure — Lightweight tiled grid of FastPlot instances.
%       Best for: pure time-series dashboards with linked zoom, tile
%       spanning, and SensorDetailPlot embedding.  No widget types beyond
%       plots.  See also: example_dashboard_9tile, example_sensor_dashboard.
%
%   DashboardEngine — Full widget-based dashboard with toolbar, edit mode,
%       JSON save/load, and 8 widget types (fastplot, number, status,
%       gauge, text, table, rawaxes, timeline).  Uses a 24-column grid
%       with Position = [col row width height].
%       See also: example_dashboard_engine, example_dashboard_all_widgets.

close all force;
clear functions;
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

n = 1e6;
x = linspace(0, 300, n);

fprintf('Dashboard example: 4 tiles, %d points each, dark theme...\n', n);
tic;

fig = FastPlotFigure(2, 2, 'Theme', 'light', ...
    'Name', 'FastPlot Dashboard Demo', 'Position', [50 50 1400 800]);

% --- Tile 1: Temperature with alarm bands (spans 2 columns) ---
fig.setTileSpan(1, [1 2]);
fp1 = fig.tile(1);
y_temp = 75 + 8*sin(x*2*pi/60) + 2*randn(1,n);
fp1.addBand(85, 95, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'High Alarm');
fp1.addBand(55, 65, 'FaceColor', [0.3 0.3 1], 'FaceAlpha', 0.15, 'Label', 'Low Alarm');
fp1.addLine(x, y_temp, 'DisplayName', 'Temperature');
fp1.addThreshold(90, 'Direction', 'upper', 'ShowViolations', true);
fp1.addThreshold(60, 'Direction', 'lower', 'ShowViolations', true);

% --- Tile 3: Pressure with confidence band ---
fp3 = fig.tile(3);
y_press = 100 + 15*sin(x*2*pi/120) + 5*randn(1,n);
y_upper = 100 + 15*sin(x*2*pi/120) + 10;
y_lower = 100 + 15*sin(x*2*pi/120) - 10;
fp3.addShaded(x, y_upper, y_lower, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.15);
fp3.addLine(x, y_press, 'DisplayName', 'Pressure');

% --- Tile 4: Vibration with event markers ---
fp4 = fig.tile(4);
y_vib = 0.5*randn(1,n);
fault_times = [50 150 250];
for ft = fault_times
    idx = round(ft*n/300):min(round((ft+3)*n/300), n);
    y_vib(idx) = y_vib(idx) + 3*randn(1, numel(idx));
end
fp4.addLine(x, y_vib, 'DisplayName', 'Vibration');
fp4.addMarker(fault_times, [3 3 3], 'Marker', 'v', 'MarkerSize', 10, ...
    'Color', [1 0.3 0.3], 'Label', 'Fault');
fp4.addThreshold(2.5, 'Direction', 'upper', 'ShowViolations', true);

fig.renderAll();

fig.tileTitle(1, 'Temperature (C)');
fig.tileTitle(3, 'Pressure (bar)');
fig.tileTitle(4, 'Vibration (mm/s)');
fig.tileXLabel(3, 'Time (s)');
fig.tileXLabel(4, 'Time (s)');

fprintf('Dashboard rendered in %.3f seconds.\n', toc);
