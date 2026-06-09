%% Dashboard Live-Tick Benchmark — 8 Tag-bound FastSense widgets
% Measures onLiveTick() latency for idle ticks (no new samples) and active
% ticks (100 new samples per widget) over 10 ticks each.
%
% Why a separate bench: bench_dashboard.m uses inline XData widgets which
% short-circuit update() and never exercise the Tag-bound hot path that the
% 260609-v5p perf fixes target. This bench drives the Tag path exclusively.
%
% Run from the repo root or from the benchmarks/ directory:
%   octave --eval "addpath('benchmarks'); bench_dashboard_live"
%   % or in MATLAB:
%   bench_dashboard_live

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
install();

fprintf('=== Dashboard Live-Tick Benchmark (Tag-bound FastSense) ===\n');

N_PTS    = 50000;  % initial samples per tag
N_TAGS   = 8;      % number of Tag-bound FastSenseWidgets
N_TICKS  = 10;     % ticks per scenario
N_APPEND = 100;    % new points appended per tag per active tick
N_EVENTS = 200;    % events wired to computeEventMarkers (non-trivial work)

% ---- Build SensorTags (50 k pts each) ----
fprintf('\nBuilding %d SensorTags (%d pts each)...\n', N_TAGS, N_PTS);
tags = cell(1, N_TAGS);
for i = 1:N_TAGS
    xi = linspace(0, 1000, N_PTS);
    yi = sin(xi / 7) + 0.05 * randn(1, N_PTS);
    tags{i} = SensorTag(sprintf('bench-tag-%d', i), ...
        'X', xi, 'Y', yi);
end

% ---- Build DashboardEngine with 8 Tag-bound fastsense widgets ----
fprintf('Building DashboardEngine...\n');
d = DashboardEngine('BenchLive');

% 8 widgets in a 2-column grid, 4 rows
for i = 1:N_TAGS
    col = mod(i - 1, 2) * 12 + 1;
    row = ceil(i / 2);
    d.addWidget('fastsense', ...
        'Title', sprintf('Tag %d', i), ...
        'Position', [col, row, 12, 2], ...
        'Tag', tags{i});
end

% ---- Wire an in-memory EventStore with ~200 events ----
% Uses EventStore('') for in-memory operation (no file I/O in benchmark).
% Events are spread evenly over the X range so computeEventMarkers does
% non-trivial work across the marker accumulation + dedup pass.
fprintf('Wiring EventStore with %d events...\n', N_EVENTS);
evStore = EventStore('');
tSpan = linspace(0, 1000, N_EVENTS);
for k = 1:N_EVENTS
    ev = Event(tSpan(k), tSpan(k) + 0.5, 'bench-sensor', 'hi', 1.0, 'upper');
    ev.Severity = 1 + mod(k - 1, 3);  % cycle 1/2/3 for realistic dedup work
    evStore.append(ev);
end
% Wire the EventStore to the first widget so computeEventMarkers does real work.
ws = d.activePageWidgets();
if ~isempty(ws)
    ws{1}.EventStore  = evStore;
    ws{1}.ShowEventMarkers = true;
end

% ---- Render (off-screen if MATLAB supports it) ----
fprintf('Rendering...\n');
d.render();

% ---- SCENARIO A: idle ticks (no data change) ----
fprintf('\n--- Scenario A: idle onLiveTick (%d ticks, no data change) ---\n', N_TICKS);
t_idle = tic;
for k = 1:N_TICKS
    d.onLiveTick();
end
t_idle_ms = toc(t_idle) * 1000 / N_TICKS;
fprintf('avg idle  onLiveTick: %.2f ms\n', t_idle_ms);

% ---- SCENARIO B: active ticks (append N_APPEND pts per tag per tick) ----
fprintf('\n--- Scenario B: active onLiveTick (%d ticks, +%d pts/tag/tick) ---\n', ...
    N_TICKS, N_APPEND);
% Pre-build the extension arrays outside the timed loop to isolate tick cost.
extX = cell(1, N_TAGS);
extY = cell(1, N_TAGS);
for i = 1:N_TAGS
    lastX = tags{i}.X(end);
    extX{i} = lastX + (1:N_APPEND);
    extY{i} = sin(extX{i} / 7) + 0.05 * randn(1, N_APPEND);
end
t_active = tic;
for k = 1:N_TICKS
    for i = 1:N_TAGS
        newX = [tags{i}.X, extX{i} + (k - 1) * N_APPEND];
        newY = [tags{i}.Y, extY{i}];
        tags{i}.updateData(newX, newY);
    end
    d.onLiveTick();
end
t_active_ms = toc(t_active) * 1000 / N_TICKS;
fprintf('avg active onLiveTick: %.2f ms\n', t_active_ms);

% ---- Summary ----
fprintf('\n--- Summary ---\n');
fprintf('idle  tick avg: %.2f ms  (fast-path fires for unchanged tags)\n', t_idle_ms);
fprintf('active tick avg: %.2f ms  (full update path, %d pts appended per widget)\n', ...
    t_active_ms, N_APPEND);

% ---- Cleanup ----
try, close(d.hFigure); catch, end
fprintf('\nBenchmark complete.\n');
