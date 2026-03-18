%% FastSense NaN Gaps — Sensor dropout simulation
% Demonstrates how FastSense handles missing data (NaN gaps)

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

n = 1e6;
x = linspace(0, 300, n); % 5 minutes
y = sin(x * 2*pi / 20) + 0.3 * randn(1, n);

% Introduce NaN gaps simulating sensor dropouts
gap_starts = [50000 200000 500000 700000 850000];
gap_lengths = [5000  15000  8000   20000  3000];
for g = 1:numel(gap_starts)
    gi = gap_starts(g):min(gap_starts(g)+gap_lengths(g)-1, n);
    y(gi) = NaN;
end

fprintf('NaN Gaps: %d points with %d dropout regions...\n', n, numel(gap_starts));
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Sensor (with dropouts)', 'Color', [0 0.5 0.3]);
fp.addThreshold(1.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', [0.9 0 0], 'LineStyle', '--', 'Label', 'Upper Limit');
fp.addThreshold(-1.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.9 0 0], 'LineStyle', '--', 'Label', 'Lower Limit');
fp.render();

fprintf('Rendered in %.3f seconds. Zoom into the gaps!\n', toc);
title(fp.hAxes, 'Sensor Data with Dropout Gaps (NaN)');
xlabel(fp.hAxes, 'Time (s)');
legend(fp.hAxes, 'show');
