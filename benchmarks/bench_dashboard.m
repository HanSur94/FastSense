%% Dashboard Performance Benchmark — Mixed 20-widget dashboard
% Measures creation, render, and live-tick times for a representative
% 20-widget dashboard (6 fastsense, 4 number, 4 status, 3 group, 2 text, 1 barchart).
%
% Run from the repo root or from the benchmarks/ directory:
%   octave --eval "addpath('benchmarks'); bench_dashboard"
%   % or in MATLAB:
%   bench_dashboard

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
install();

fprintf('=== Dashboard Performance Benchmark ===\n');

% ---- Creation benchmark ----
t_create = tic;

d = DashboardEngine('BenchDash');

% 6x fastsense widgets — rows 1-3, 2 per row
for i = 1:6
    col = mod(i-1, 2) * 12 + 1;
    row = ceil(i / 2);
    xd = linspace(0, 10, 100);
    yd = sin(xd + i) + 0.1 * randn(1, 100);
    d.addWidget('fastsense', ...
        'Title', sprintf('Signal %d', i), ...
        'Position', [col, row, 12, 1], ...
        'XData', xd, 'YData', yd);
end

% 4x number widgets — row 4, 6 cols each
for i = 1:4
    col = (i-1) * 6 + 1;
    k = i; %#ok<FXSET>
    d.addWidget('number', ...
        'Title', sprintf('Count %d', i), ...
        'Position', [col, 4, 6, 1], ...
        'ValueFcn', @() rand());
end

% 4x status widgets — row 5, 6 cols each
for i = 1:4
    col = (i-1) * 6 + 1;
    d.addWidget('status', ...
        'Title', sprintf('Status %d', i), ...
        'Position', [col, 5, 6, 1], ...
        'ValueFcn', @() 'OK');
end

% 3x group widgets — row 6, 8 cols each
for i = 1:3
    col = (i-1) * 8 + 1;
    d.addWidget('group', ...
        'Label', sprintf('Group %d', i), ...
        'Position', [col, 6, 8, 1]);
end

% 2x text widgets — row 7, 12 cols each
d.addWidget('text', ...
    'Title', 'Info A', ...
    'Position', [1, 7, 12, 1], ...
    'Content', 'Dashboard performance benchmark — panel A');
d.addWidget('text', ...
    'Title', 'Info B', ...
    'Position', [13, 7, 12, 1], ...
    'Content', 'Dashboard performance benchmark — panel B');

% 1x barchart widget — row 8
d.addWidget('barchart', ...
    'Title', 'Metrics', ...
    'Position', [1, 8, 24, 1]);

t_create_ms = toc(t_create) * 1000;

% ---- Render benchmark ----
t_render = tic;
d.render();
drawnow;
t_render_ms = toc(t_render) * 1000;

% ---- Live tick benchmark ----
nTicks = 5;
t_tick = tic;
for i = 1:nTicks
    d.onLiveTick();
end
t_tick_ms = toc(t_tick) * 1000 / nTicks;

% ---- Print results ----
fprintf('Create:    %.1f ms\n', t_create_ms);
fprintf('Render:    %.1f ms\n', t_render_ms);
fprintf('Total:     %.1f ms\n', t_create_ms + t_render_ms);
fprintf('Live tick: %.1f ms (avg of %d ticks)\n', t_tick_ms, nTicks);

% ---- Cleanup ----
close(d.hFigure);
fprintf('Benchmark complete.\n');
