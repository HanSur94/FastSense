%% FastPlot Visual Features — Bands, Shading, Fill, and Markers
% Demonstrates all new visual enhancement methods in a 2x2 dashboard

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

n = 5e5;
x = linspace(0, 100, n);

fprintf('Visual features example: 4 tiles, %d points...\n', n);
tic;

fig = FastPlotFigure(2, 2, 'Theme', 'default', ...
    'Name', 'Visual Features Demo', 'Position', [50 50 1200 800]);

% --- Tile 1: addBand — Alarm bands with thresholds ---
fp1 = fig.tile(1);
y1 = 50 + 8*sin(x*2*pi/20) + 2*randn(1,n);
fp1.addBand(60, 65, 'FaceColor', [1 0.8 0.3], 'FaceAlpha', 0.2, 'Label', 'Warning');
fp1.addBand(65, 75, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.2, 'Label', 'Alarm');
fp1.addBand(35, 40, 'FaceColor', [1 0.8 0.3], 'FaceAlpha', 0.2, 'Label', 'Low Warning');
fp1.addBand(25, 35, 'FaceColor', [0.3 0.3 1], 'FaceAlpha', 0.2, 'Label', 'Low Alarm');
fp1.addLine(x, y1, 'DisplayName', 'Process Value');
fp1.addThreshold(65, 'Direction', 'upper', 'ShowViolations', true);
fp1.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true);

% --- Tile 2: addShaded — Confidence interval / envelope ---
fp2 = fig.tile(2);
signal = sin(x*2*pi/15);
y2 = signal + 0.3*randn(1,n);
envelope_hi = signal + 0.8;
envelope_lo = signal - 0.8;
fp2.addShaded(x, envelope_hi, envelope_lo, 'FaceColor', [0.2 0.5 0.9], 'FaceAlpha', 0.15);
fp2.addLine(x, y2, 'DisplayName', 'Measurement');

% --- Tile 3: addFill — Area under curve ---
fp3 = fig.tile(3);
y3 = abs(sin(x*2*pi/25)) .* (1 + 0.3*randn(1,n));
fp3.addFill(x, y3, 'FaceColor', [0.2 0.7 0.3], 'FaceAlpha', 0.3);
fp3.addLine(x, y3, 'DisplayName', 'Power Output');

% --- Tile 4: addMarker — Event annotations ---
fp4 = fig.tile(4);
y4 = cumsum(0.01*randn(1,n));
event_x = [10 25 42 58 73 90];
event_y = interp1(x, y4, event_x);
fp4.addLine(x, y4, 'DisplayName', 'Random Walk');
fp4.addMarker(event_x, event_y, 'Marker', 'v', 'MarkerSize', 10, ...
    'Color', [0.9 0.2 0.2], 'Label', 'Anomaly');
fp4.addMarker(event_x, event_y - 0.5, 'Marker', '^', 'MarkerSize', 8, ...
    'Color', [0.2 0.6 0.2], 'Label', 'Recovery');

fig.renderAll();

fig.tileTitle(1, 'addBand — Alarm Zones');
fig.tileTitle(2, 'addShaded — Confidence Envelope');
fig.tileTitle(3, 'addFill — Area Under Curve');
fig.tileTitle(4, 'addMarker — Event Annotations');

fprintf('Visual features rendered in %.3f seconds.\n', toc);
