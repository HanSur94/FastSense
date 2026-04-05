%% FastSense Multi-Sensor Linked — 4 sensors with independent thresholds, synchronized zoom
% Simulates a real monitoring dashboard with different alarm levels per channel

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

n = 2e6;
x = linspace(0, 600, n); % 10 minutes

fig = figure('Name', 'Multi-Sensor Dashboard', 'Position', [50 50 1400 800]);

fprintf('Multi-Sensor Dashboard: 4 x %d points, linked zoom...\n', n);
tic;

% --- Channel 1: Temperature ---
ax1 = subplot(4,1,1, 'Parent', fig);
y_temp = 75 + 8*sin(x*2*pi/120) + 2*randn(1,n);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'dashboard');
fp1.addLine(x, y_temp, 'DisplayName', 'Temperature', 'Color', [0.8 0.2 0.1]);
fp1.addThreshold(90, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'HH');
fp1.addThreshold(85, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':',  'Label', 'H');
fp1.addThreshold(65, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':',  'Label', 'L');
fp1.addThreshold(60, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'LL');
fp1.render();
title(ax1, 'Temperature (C)');

% --- Channel 2: Pressure ---
ax2 = subplot(4,1,2, 'Parent', fig);
y_press = 100 + 15*sin(x*2*pi/200) + 5*randn(1,n);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'dashboard');
fp2.addLine(x, y_press, 'DisplayName', 'Pressure', 'Color', [0.1 0.4 0.8]);
fp2.addThreshold(130, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'HH');
fp2.addThreshold(120, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':');
fp2.addThreshold(80, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':');
fp2.addThreshold(70, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'LL');
fp2.render();
title(ax2, 'Pressure (bar)');

% --- Channel 3: Flow Rate ---
ax3 = subplot(4,1,3, 'Parent', fig);
y_flow = 50 + 10*sin(x*2*pi/90) + 3*randn(1,n);
% Add a ramp-up event
ramp_idx = round(n*0.6):round(n*0.65);
y_flow(ramp_idx) = y_flow(ramp_idx) + linspace(0, 25, numel(ramp_idx));
fp3 = FastSense('Parent', ax3, 'LinkGroup', 'dashboard');
fp3.addLine(x, y_flow, 'DisplayName', 'Flow Rate', 'Color', [0.2 0.6 0.2]);
fp3.addThreshold(75, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--');
fp3.addThreshold(65, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':');
fp3.addThreshold(35, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':');
fp3.render();
title(ax3, 'Flow Rate (L/min)');

% --- Channel 4: Vibration (only upper thresholds) ---
ax4 = subplot(4,1,4, 'Parent', fig);
y_vib = 0.5*randn(1,n);
% Add bearing fault bursts
for t_fault = [100 280 450]
    idx = round(t_fault*n/600):min(round((t_fault+5)*n/600), n);
    y_vib(idx) = y_vib(idx) + 3*randn(1, numel(idx));
end
fp4 = FastSense('Parent', ax4, 'LinkGroup', 'dashboard');
fp4.addLine(x, y_vib, 'DisplayName', 'Vibration', 'Color', [0.5 0.2 0.6]);
fp4.addThreshold(4.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'Danger');
fp4.addThreshold(2.5, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':', 'Label', 'Warning');
fp4.addThreshold(-2.5, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':');
fp4.addThreshold(-4.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--');
fp4.render();
title(ax4, 'Vibration (mm/s)');
xlabel(ax4, 'Time (s)');

fprintf('Rendered in %.3f seconds. Zoom any plot — all follow!\n', toc);
