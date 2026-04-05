%% FastSense Unevenly Sampled Data — Event-driven acquisition
% Demonstrates that FastSense handles non-uniform X spacing correctly

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% Simulate event-driven data: high rate during events, sparse between
fprintf('Generating unevenly sampled data...\n');

segments = {};
t_current = 0;

for i = 1:50
    % Sparse region: ~10 Hz for 20 seconds
    n_sparse = 200;
    dt_sparse = 20 / n_sparse;
    t_sparse = t_current + (0:n_sparse-1) * dt_sparse;
    y_sparse = 2 * sin(t_sparse * 2*pi / 30) + 0.3 * randn(1, n_sparse);
    segments{end+1} = struct('x', t_sparse, 'y', y_sparse);
    t_current = t_sparse(end) + dt_sparse;

    % Dense region: ~10 kHz for 0.5 seconds (event burst)
    n_dense = 5000;
    dt_dense = 0.5 / n_dense;
    t_dense = t_current + (0:n_dense-1) * dt_dense;
    y_dense = 5 * sin(t_dense * 2*pi * 50) + randn(1, n_dense);
    segments{end+1} = struct('x', t_dense, 'y', y_dense);
    t_current = t_dense(end) + dt_dense;
end

% Concatenate
x = []; y = [];
for i = 1:numel(segments)
    x = [x, segments{i}.x];
    y = [y, segments{i}.y];
end

fprintf('Uneven sampling: %d points, rate varies 10 Hz to 10 kHz...\n', numel(x));
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Event-Driven Sensor', 'Color', [0.2 0.5 0.7]);
fp.addThreshold(4.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'High');
fp.addThreshold(-4.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0 0], 'LineStyle', '--', 'Label', 'Low');
fp.render();

fprintf('Rendered in %.3f seconds. Zoom into dense bursts to see detail!\n', toc);
title(fp.hAxes, 'Unevenly Sampled Data — Event Bursts');
xlabel(fp.hAxes, 'Time (s)');
legend(fp.hAxes, 'show');
