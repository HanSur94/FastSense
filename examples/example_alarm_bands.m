%% FastPlot Alarm Bands — Industrial sensor with 4 thresholds
% Demonstrates warning + alarm thresholds in both directions

run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

n = 2e6;
x = linspace(0, 3600, n); % 1 hour of data at ~556 Hz

% Simulate a process variable that drifts and has occasional excursions
base = 50 + 5*sin(x * 2*pi / 600);          % slow 10-min cycle around 50
noise = 0.8 * randn(1, n);                    % measurement noise
spikes = zeros(1, n);
spikes(randi(n, 1, 200)) = 8 * randn(1, 200); % occasional spikes
y = base + noise + spikes;

fprintf('Alarm Bands: %d points, 4 thresholds...\n', n);
tic;

fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Process Variable', 'Color', [0.2 0.4 0.7]);

% Alarm limits (red, dashed) — hard limits
fp.addThreshold(62, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'HH Alarm');
fp.addThreshold(38, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'LL Alarm');

% Warning limits (orange, dotted) — soft limits
fp.addThreshold(58, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':', 'Label', 'H Warning');
fp.addThreshold(42, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [1 0.5 0], 'LineStyle', ':', 'Label', 'L Warning');

fp.render();

fprintf('Rendered in %.3f seconds.\n', toc);
title(fp.hAxes, 'Process Variable — Alarm Bands');
xlabel(fp.hAxes, 'Time (s)');
ylabel(fp.hAxes, 'Value');
legend(fp.hAxes, 'show');
