%% Dashboard Load Benchmark — Tag-bound populated dashboard (Create + Render)
% Measures CREATE and RENDER time for a populated Tag-bound dashboard.
% Complements bench_dashboard.m (inline XData, no Tag path) and
% bench_dashboard_live.m (live ticks). This bench isolates the LOAD path:
% the repeated Tag.getXY / getXYRange calls that 260610-ov3 optimizes via
% a per-render data cache (RenderDataCache_) in FastSenseWidget.
%
% Includes ~1/3 disk-backed SensorTags (toDisk()) to exercise the SQLite
% getRange path that benefits most from the cache — disk-backed sensors
% perform a full SQLite query on each getXYRange call, so eliminating the
% 3-4 redundant calls per render() has the largest absolute impact here.
%
% Run from the repo root or from the benchmarks/ directory:
%   octave --eval "addpath('benchmarks'); bench_dashboard_load"
%   % or in MATLAB:
%   bench_dashboard_load

addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
install();

fprintf('=== Dashboard Load Benchmark (Tag-bound, Create + Render) ===\n');

N_TAGS   = 12;    % Tag-bound FastSenseWidgets
N_PTS    = 50000; % initial samples per tag
N_EVENTS = 200;   % events wired to first widget (exercises preview/marker pass)

% ---- Build SensorTags (N_PTS pts each) ----
fprintf('\nBuilding %d SensorTags (%d pts each)...\n', N_TAGS, N_PTS);
tags = cell(1, N_TAGS);
for i = 1:N_TAGS
    xi = linspace(0, 1000, N_PTS);
    yi = sin(xi / 7 + i) + 0.05 * randn(1, N_PTS);
    tags{i} = SensorTag(sprintf('bench-load-tag-%d', i), 'X', xi, 'Y', yi);
end

% ---- Convert ~1/3 of tags to disk-backed via toDisk() ----
% Disk-backed SensorTags return empty X_ from getXY(); the render probe
% calls getXYRange(getTimeRange()) -> SQLite getRange. Eliminating the
% 3-4 redundant SQLite calls per render is the primary win of 260610-ov3.
nDisk = max(1, floor(N_TAGS / 3));
diskOk = false;
for i = 1:nDisk
    try
        tags{i}.toDisk();
        diskOk = true;
    catch ME
        if i == 1
            fprintf('  [note] toDisk() unavailable (%s) — bench runs without disk-backed tags.\n', ...
                ME.message);
        end
        break;
    end
end
if diskOk
    fprintf('  %d/%d tags moved to disk-backed storage.\n', nDisk, N_TAGS);
end

% ---- BUILD benchmark: DashboardEngine + addWidget loop ----
t_create = tic;

d = DashboardEngine('BenchLoad');

for i = 1:N_TAGS
    col = mod(i - 1, 2) * 12 + 1;
    row = ceil(i / 2);
    d.addWidget('fastsense', ...
        'Title', sprintf('Tag %d', i), ...
        'Position', [col, row, 12, 2], ...
        'Tag', tags{i});
end

t_create_ms = toc(t_create) * 1000;

% ---- Wire an in-memory EventStore with ~N_EVENTS events ----
% Uses EventStore('') for in-memory operation. Events spread evenly so the
% preview/marker pass does non-trivial work (mirrors bench_dashboard_live).
fprintf('Wiring EventStore with %d events...\n', N_EVENTS);
evStore = EventStore('');
tSpan = linspace(0, 1000, N_EVENTS);
for k = 1:N_EVENTS
    ev = Event(tSpan(k), tSpan(k) + 0.5, 'bench-load-sensor', 'hi', 1.0, 'upper');
    ev.Severity = 1 + mod(k - 1, 3);
    evStore.append(ev);
end
ws = d.activePageWidgets();
if ~isempty(ws)
    ws{1}.EventStore       = evStore;
    ws{1}.ShowEventMarkers = true;
end

% ---- RENDER benchmark ----
t_render = tic;
d.render();
drawnow;
t_render_ms = toc(t_render) * 1000;

% ---- Print results (matching bench_dashboard.m label style) ----
fprintf('\n');
fprintf('Create:    %.1f ms\n', t_create_ms);
fprintf('Render:    %.1f ms\n', t_render_ms);
fprintf('Total:     %.1f ms\n', t_create_ms + t_render_ms);

% ---- Cleanup ----
try, close(d.hFigure); catch, end
fprintf('Benchmark complete.\n');
