%% FastPlot 3x3 Dashboard — Industrial Monitoring Console
% 9 tiles with different signals, data sizes, and features.

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();

fprintf('3x3 Dashboard: 9 tiles, mixed data sizes, dark theme...\n');
tic;

fig = FastPlotFigure(3, 3, 'Theme', 'light', ...
    'Name', 'Industrial Monitoring Console', 'Position', [30 30 1800 1000]);

% =========================================================================
% Tile 1: Temperature — 5M points, 3 sensors, alarm bands, linked
% =========================================================================
fp1 = fig.tile(1);
n1 = 5e6;
x1 = linspace(0, 3600, n1);
y1a = 72 + 6*sin(x1*2*pi/600) + 1.5*randn(1,n1);
y1b = 68 + 5*sin(x1*2*pi/600 + 0.5) + 1.2*randn(1,n1);
y1c = 75 + 4*sin(x1*2*pi/600 - 0.3) + 1.0*randn(1,n1);
fp1.addBand(82, 90, 'FaceColor', [1 0.2 0.2], 'FaceAlpha', 0.12);
fp1.addBand(55, 60, 'FaceColor', [0.2 0.4 1], 'FaceAlpha', 0.12);
fp1.addLine(x1, y1a, 'DisplayName', 'Sensor A');
fp1.addLine(x1, y1b, 'DisplayName', 'Sensor B');
fp1.addLine(x1, y1c, 'DisplayName', 'Sensor C');

% =========================================================================
% Tile 2: Coolant Flow — 500K points, thresholds + violations, linked
% =========================================================================
fp2 = fig.tile(2);
n2 = 5e5;
x2 = linspace(0, 3600, n2);
y2 = 45 + 8*sin(x2*2*pi/900) + 3*randn(1,n2);
fp2.addLine(x2, y2, 'DisplayName', 'Flow Rate');
fp2.addThreshold(55, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.4 0.4], 'Label', 'High');
fp2.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.4 0.4 1], 'Label', 'Low');

% =========================================================================
% Tile 3: Reactor Pressure — 2M points, shaded confidence envelope
% =========================================================================
fp3 = fig.tile(3);
n3 = 2e6;
x3 = linspace(0, 3600, n3);
base3 = 101 + 12*sin(x3*2*pi/1200);
y3 = base3 + 3*randn(1,n3);
fp3.addShaded(x3, base3 + 8, base3 - 8, ...
    'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.12);
fp3.addLine(x3, y3, 'DisplayName', 'Pressure');

% =========================================================================
% Tile 4: Motor Current — 10M points, fill under curve
% =========================================================================
fp4 = fig.tile(4);
n4 = 10e6;
x4 = linspace(0, 3600, n4);
y4 = abs(3*sin(x4*2*pi/400) .* (1 + 0.2*randn(1,n4)));
fp4.addFill(x4, y4, 'FaceColor', [0.9 0.6 0.1], 'FaceAlpha', 0.25);
fp4.addLine(x4, y4, 'DisplayName', 'Motor Current');
fp4.addThreshold(4.0, 'Direction', 'upper', 'ShowViolations', true);

% =========================================================================
% Tile 5: Vibration — 1M points, fault markers + threshold
% =========================================================================
fp5 = fig.tile(5);
n5 = 1e6;
x5 = linspace(0, 3600, n5);
y5 = 0.4*randn(1,n5);
fault_t = [400 1100 2200 3000];
for ft = fault_t
    idx = max(1,round(ft*n5/3600)):min(round((ft+30)*n5/3600),n5);
    y5(idx) = y5(idx) + 2.5*randn(1, numel(idx));
end
fp5.addLine(x5, y5, 'DisplayName', 'Vibration');
fp5.addMarker(fault_t, 3.0*ones(size(fault_t)), ...
    'Marker', 'v', 'MarkerSize', 10, 'Color', [1 0.2 0.2]);
fp5.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true);

% =========================================================================
% Tile 6: Humidity — 200K points, multi-threshold warning/alarm
% =========================================================================
fp6 = fig.tile(6);
n6 = 2e5;
x6 = linspace(0, 3600, n6);
y6 = 55 + 15*sin(x6*2*pi/1800) + 5*randn(1,n6);
fp6.addBand(70, 75, 'FaceColor', [1 0.8 0.2], 'FaceAlpha', 0.15);
fp6.addBand(75, 85, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15);
fp6.addBand(35, 40, 'FaceColor', [0.2 0.7 1], 'FaceAlpha', 0.15);
fp6.addLine(x6, y6, 'DisplayName', 'Humidity');
fp6.addThreshold(75, 'Direction', 'upper', 'ShowViolations', true);
fp6.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true);

% =========================================================================
% Tile 7: RPM — 50K points (slow sampled), LTTB downsample
% =========================================================================
fp7 = fig.tile(7);
n7 = 5e4;
x7 = linspace(0, 3600, n7);
y7 = 1500 + 300*sin(x7*2*pi/900) + 50*sin(x7*2*pi/60) + 20*randn(1,n7);
fp7.addLine(x7, y7, 'DisplayName', 'RPM', 'DownsampleMethod', 'lttb');

% =========================================================================
% Tile 8: Sensor with NaN gaps — 800K points, dropout periods
% =========================================================================
fp8 = fig.tile(8);
n8 = 8e5;
x8 = linspace(0, 3600, n8);
y8 = 20 + 5*sin(x8*2*pi/300) + 1.5*randn(1,n8);
% Insert dropout gaps
gaps = [500 700; 1400 1600; 2500 2650];
for g = 1:size(gaps,1)
    mask = x8 >= gaps(g,1) & x8 <= gaps(g,2);
    y8(mask) = NaN;
end
fp8.addLine(x8, y8, 'DisplayName', 'Oxygen Level');
fp8.addThreshold(27, 'Direction', 'upper', 'ShowViolations', true);
recovery_x = gaps(:,2)' + 50;
recovery_y = interp1(x8(~isnan(y8)), y8(~isnan(y8)), recovery_x);
fp8.addMarker(recovery_x, recovery_y, 'Marker', '^', 'MarkerSize', 8, ...
    'Color', [0.2 0.9 0.4]);

% =========================================================================
% Tile 9: Power Spectrum — 3M points, two overlaid signals + shaded diff
% =========================================================================
fp9 = fig.tile(9);
n9 = 3e6;
x9 = linspace(0, 3600, n9);
y9a = 2*sin(x9*2*pi/200) + 0.8*sin(x9*2*pi/50) + 0.5*randn(1,n9);
y9b = 2*sin(x9*2*pi/200 + 1) + 0.6*sin(x9*2*pi/80) + 0.5*randn(1,n9);
fp9.addShaded(x9, y9a, y9b, 'FaceColor', [0.6 0.3 0.9], 'FaceAlpha', 0.15);
fp9.addLine(x9, y9a, 'DisplayName', 'Channel A');
fp9.addLine(x9, y9b, 'DisplayName', 'Channel B');

% =========================================================================
% Render all and add titles
% =========================================================================
fig.renderAll();

fig.tileTitle(1, 'Temperature (3 sensors, 5M pts)');
fig.tileTitle(2, 'Coolant Flow (500K pts)');
fig.tileTitle(3, 'Reactor Pressure (2M pts)');
fig.tileTitle(4, 'Motor Current (10M pts)');
fig.tileTitle(5, 'Vibration + Faults (1M pts)');
fig.tileTitle(6, 'Humidity Alarm Zones (200K pts)');
fig.tileTitle(7, 'RPM — LTTB (50K pts)');
fig.tileTitle(8, 'O2 with NaN Gaps (800K pts)');
fig.tileTitle(9, 'Dual Channel (3M pts)');

fig.tileYLabel(1, '\circC');
fig.tileYLabel(2, 'L/min');
fig.tileYLabel(3, 'kPa');
fig.tileYLabel(4, 'Amps');
fig.tileYLabel(5, 'mm/s');
fig.tileYLabel(6, '%RH');
fig.tileYLabel(7, 'RPM');
fig.tileYLabel(8, '%');
fig.tileYLabel(9, 'mV');

elapsed = toc;
total_pts = n1*3 + n2 + n3 + n4 + n5 + n6 + n7 + n8 + n9;
fprintf('Dashboard rendered: 9 tiles, %.1fM total points in %.2f seconds.\n', ...
    total_pts/1e6, elapsed);
