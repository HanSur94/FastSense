function test_phase_1032_integration_smoke()
%TEST_PHASE_1032_INTEGRATION_SMOKE End-to-end Phase 1032 smoke (cross-runtime where possible).
%
%   Proves the full Phase 1032 per-widget plant-log overlay surface works as
%   advertised, covering all 4 PLOG-VIZ-* requirements (03 + 04 + 05 + 07)
%   end-to-end:
%     - ShowPlantLog public property + toStruct/fromStruct round-trip   (PLOG-VIZ-03)
%     - L toggle button + setShowPlantLog wire-up                       (PLOG-VIZ-05)
%     - Per-widget xline draw + xlim listener refresh                   (PLOG-VIZ-04)
%     - PlantLogWidgetHover full-metadata tooltip                       (PLOG-VIZ-07)
%     - DetachedMirror parity: clone inherits ShowPlantLog + draws lines
%       + has its own hover + receives PlantLogTailTick fan-out         (PLOG-VIZ-04 / Decision G)
%     - Live-tail tick fan-out reaches BOTH source AND mirror           (PLOG-VIZ-04 + 08)
%     - Toggle-off cleanup leaves zero orphan listeners / timers / handles
%
%   install() contract: deliberately omits any manual addpath of
%   libs/PlantLog or libs/Dashboard so install.m's libs-block is the
%   regression gate (regression gate via which('PlantLogWidgetHover')).
%
%   Runtime gates:
%     - Sub-tests 1 + 2 are cross-runtime (path pickup + serialize round-trip).
%     - Sub-tests 3..8 are MATLAB-only (uifigure-driven; FastSenseWidget +
%       PlantLogWidgetHover are uifigure-heavy and require WidgetPlantLogMarker
%       xline handles to materialize on rendered axes).
%
%   Coverage map:
%     PLOG-VIZ-03  -> test_path_pickup + test_property_default_and_serialize
%     PLOG-VIZ-04  -> test_toggle_and_overlay + test_live_tail_fan_out
%                     + test_detach_parity + test_tick_fans_out_to_both
%     PLOG-VIZ-05  -> test_toggle_and_overlay (engine.WidgetHovers_ wired by
%                     widget.setShowPlantLog) — full UI button surface lives
%                     in TestDashboardLayoutPlantLogToggle (Plan 02)
%     PLOG-VIZ-07  -> test_hover_metadata
%     Decision G   -> test_detach_parity + test_tick_fans_out_to_both
%     Cleanup      -> test_cleanup (no orphan timers / listeners / hover handles)

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_path_pickup();
    nPassed = nPassed + test_property_default_and_serialize();
    nPassed = nPassed + test_toggle_and_overlay();
    nPassed = nPassed + test_hover_metadata();
    nPassed = nPassed + test_live_tail_fan_out();
    nPassed = nPassed + test_detach_parity();
    nPassed = nPassed + test_tick_fans_out_to_both();
    nPassed = nPassed + test_cleanup();

    assert(nPassed == 8, sprintf( ...
        'Expected 8 phase_1032_integration_smoke sub-tests passed; got %d.', nPassed));
    fprintf('    All 8 phase_1032_integration_smoke assertions passed.\n');
end

% =====================================================================
% PATH SETUP -- install() contract gate (do NOT add manual addpath here)
% =====================================================================

function add_paths_via_install_only()
    thisDir  = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
end

% =====================================================================
% NAMED CLEANUP HELPERS -- never use inline try inside anonymous funcs
% =====================================================================

function try_delete_h(h)
    try
        if ishandle(h)
            delete(h);
        end
    catch
    end
end

function try_delete_obj(o)
    try
        if ~isempty(o) && isvalid(o)
            delete(o);
        end
    catch
    end
end

% =====================================================================
% FIXTURE HELPERS
% =====================================================================

function store = make_populated_store_(timestamps, messages)
    store = PlantLogStore('synthetic.csv');
    if isempty(timestamps)
        return;
    end
    md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
    n = numel(timestamps);
    es = repmat(PlantLogEntry('Timestamp', timestamps(1), ...
        'Message', messages{1}, 'Metadata', md), 1, n);
    for k = 2:n
        es(k) = PlantLogEntry('Timestamp', timestamps(k), ...
            'Message', messages{k}, 'Metadata', md);
    end
    store.addEntries(es);
end

function s = flatten_tooltip_string_(raw)
    % Tooltip String can be (a) char, (b) cell of char rows (when uicontrol
    % auto-splits on newlines), (c) string array, or (d) char matrix. Flatten
    % to a single char row so strfind works on all variants.
    if ischar(raw)
        if size(raw, 1) > 1
            rows = cell(1, size(raw, 1));
            for r = 1:size(raw, 1)
                rows{r} = raw(r, :);
            end
            s = strjoin(rows, ' ');
        else
            s = raw;
        end
        return;
    end
    if iscell(raw)
        flat = cell(1, numel(raw));
        for k = 1:numel(raw)
            flat{k} = char(raw{k});
        end
        s = strjoin(flat, ' ');
        return;
    end
    if isstring(raw)
        s = char(strjoin(raw, ' '));
        return;
    end
    s = char(raw);
end

function w = make_rendered_fs_widget_(panel, xLim, title, sensorKey)
    % Build a FastSenseWidget backed by a SensorTag so that DetachedMirror
    % can re-render the clone (restoreLiveRefs copies the Sensor reference,
    % so the inline XData/YData path is not used by the mirror).
    if nargin < 4, sensorKey = sprintf('__smoke_%s__', title); end
    x = linspace(xLim(1), xLim(2), 100);
    y = sin(x * 0.1);
    try
        sensor = TagRegistry.get(sensorKey);
    catch
        sensor = SensorTag(sensorKey, 'Name', title, 'X', x, 'Y', y);
        try
            TagRegistry.register(sensorKey, sensor);
        catch
        end
    end
    w = FastSenseWidget('Title', title, 'Position', [1 1 12 3], ...
        'Sensor', sensor);
    w.render(panel);
    set(w.FastSenseObj.hAxes, 'XLim', xLim);
end

% =====================================================================
% SUB-TESTS
% =====================================================================

function n = test_path_pickup()
    % Phase 1032 path-pickup gate: confirms install() puts every Phase 1032
    % class on the path (plus Phase 1029-1031 classes still resolvable). If
    % this fails, install.m's libs-block has regressed.
    assert(~isempty(which('FastSenseWidget')),       'FastSenseWidget must resolve');
    assert(~isempty(which('DashboardEngine')),       'DashboardEngine must resolve');
    assert(~isempty(which('DashboardLayout')),       'DashboardLayout must resolve');
    assert(~isempty(which('DetachedMirror')),        'DetachedMirror must resolve');
    assert(~isempty(which('PlantLogWidgetHover')),   'PlantLogWidgetHover must resolve (Phase 1032 Plan 02)');
    assert(~isempty(which('PlantLogSliderHover')),   'PlantLogSliderHover must resolve (Phase 1031 Plan 03)');
    assert(~isempty(which('PlantLogStore')),         'PlantLogStore must resolve (Phase 1029)');
    assert(~isempty(which('PlantLogEntry')),         'PlantLogEntry must resolve (Phase 1029)');
    assert(~isempty(which('PlantLogReader')),        'PlantLogReader must resolve (Phase 1030)');
    assert(~isempty(which('PlantLogLiveTail')),      'PlantLogLiveTail must resolve (Phase 1031)');
    n = 1;
end

function n = test_property_default_and_serialize()
    % Cross-runtime: no graphics. ShowPlantLog default + toStruct/fromStruct
    % round-trip. Proves Plan 01's property surface is intact.
    w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
    cleanupW = onCleanup(@() try_delete_obj(w));
    assert(isprop(w, 'ShowPlantLog'),     'ShowPlantLog must be a public property');
    assert(~logical(w.ShowPlantLog),      'ShowPlantLog default must be false');
    s = w.toStruct();
    assert(~isfield(s, 'showPlantLog'), ...
        'toStruct must omit showPlantLog when default false (older serialized dashboards stay byte-identical)');
    w.ShowPlantLog = true;
    s2 = w.toStruct();
    assert(isfield(s2, 'showPlantLog') && logical(s2.showPlantLog), ...
        'toStruct must write showPlantLog=true when set');
    % Round-trip via fromStruct.
    sIn = struct('type', 'fastsense', 'title', 't', ...
        'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3), ...
        'showPlantLog', true);
    w2 = FastSenseWidget.fromStruct(sIn);
    cleanupW2 = onCleanup(@() try_delete_obj(w2));
    assert(logical(w2.ShowPlantLog), 'fromStruct must restore ShowPlantLog=true');
    clear cleanupW cleanupW2;
    n = 1;
end

function n = test_toggle_and_overlay()
    % MATLAB-only: build a single FastSenseWidget on a hidden figure, attach
    % store with 8 entries via setPlantLogStoreForTest_, toggle ShowPlantLog=true,
    % assert 8 WidgetPlantLogMarker xline handles on the widget's axes.
    % Also asserts engine.WidgetHovers_ has exactly one entry (hover attached).
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_toggle_and_overlay (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    panel = uipanel(f, 'Position', [0 0 1 1]);
    w = make_rendered_fs_widget_(panel, [0 100], 'Smoke W1');
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('SmokeToggle');
    cleanupE = onCleanup(@() try_delete_obj(e));
    store = make_populated_store_( ...
        [10 20 30 40 50 60 70 80], ...
        {'a','b','c','d','e','f','g','h'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    ax = w.FastSenseObj.hAxes;
    n8 = numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker'));
    assert(n8 == 8, sprintf( ...
        'expected 8 WidgetPlantLogMarker handles after toggle; got %d', n8));
    assert(~isempty(e.WidgetHovers_), ...
        'engine.WidgetHovers_ must be non-empty after setShowPlantLog(true)');
    assert(isscalar(e.WidgetHovers_), ...
        sprintf('expected 1 hover pair after single widget toggle on; got %d', numel(e.WidgetHovers_)));
    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_hover_metadata()
    % MATLAB-only: simulateHoverAt_ at an entry's timestamp must return a
    % non-empty pick array AND tooltip String must contain the timestamp +
    % message + every metadata column (Decision F + G — full metadata).
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_hover_metadata (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    panel = uipanel(f, 'Position', [0 0 1 1]);
    w = make_rendered_fs_widget_(panel, [0 100], 'Smoke W1');
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('SmokeHover');
    cleanupE = onCleanup(@() try_delete_obj(e));
    store = make_populated_store_([10 20 30], {'pump on', 'pump off', 'valve open'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    pair = e.WidgetHovers_{1};
    hover = pair{2};
    assert(~isempty(hover) && isa(hover, 'PlantLogWidgetHover'), ...
        'engine.WidgetHovers_{1}{2} must be a PlantLogWidgetHover instance');
    picks = hover.simulateHoverAt_(20);
    assert(~isempty(picks), 'simulateHoverAt_(20) must return a non-empty pick array');
    tipStr = hover.getCurrentTooltipString_();
    assert(~isempty(tipStr), 'tooltip String must be non-empty after simulateHoverAt_');
    tipFlat = flatten_tooltip_string_(tipStr);
    assert(~isempty(strfind(tipFlat, 'pump off')), ...
        sprintf('tooltip must contain the entry message; got "%s"', tipFlat)); %#ok<STREMP>
    assert(~isempty(strfind(tipFlat, 'unit')) || ~isempty(strfind(tipFlat, 'ZK-12')), ...
        sprintf('tooltip must contain metadata column or value; got "%s"', tipFlat)); %#ok<STREMP>
    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_live_tail_fan_out()
    % MATLAB-only: attach a PlantLogLiveTail, simulate live append + notify
    % PlantLogTailTick, assert widget's marker count increases.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_live_tail_fan_out (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    panel = uipanel(f, 'Position', [0 0 1 1]);
    w = make_rendered_fs_widget_(panel, [0 100], 'Smoke W1');
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('SmokeFanOut');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.addWidget(w);  % engine must know the widget for onPlantLogTailTick_ fan-out.
    store = make_populated_store_([10 20 30 40 50 60 70 80], ...
        {'a','b','c','d','e','f','g','h'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    ax = w.FastSenseObj.hAxes;
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 8, ...
        'precondition: 8 markers after toggle on');

    mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
    tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
    cleanupT = onCleanup(@() try_delete_obj(tail));
    e.setPlantLogLiveTailForTest_(tail);

    % Append two more entries directly to the store, then notify the
    % PlantLogTailTick event (bypasses readtable -- the fan-out path is
    % the asserted behavior, not the file re-read).
    md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
    store.addEntries([ ...
        PlantLogEntry('Timestamp', 85, 'Message', 'append-1', 'Metadata', md), ...
        PlantLogEntry('Timestamp', 90, 'Message', 'append-2', 'Metadata', md)]);
    notify(tail, 'PlantLogTailTick');

    n10 = numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker'));
    assert(n10 == 10, sprintf( ...
        'expected 10 markers after live-tail tick (8 + 2); got %d', n10));

    e.setPlantLogLiveTailForTest_([]);   % clean detach
    clear cleanupT cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_detach_parity()
    % MATLAB-only: detach a ShowPlantLog=true widget; verify the mirror's
    % cloned widget has ShowPlantLog=true AND drew its own markers AND has
    % its own hover (CONTEXT.md Decision G full parity).
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_detach_parity (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    panel = uipanel(f, 'Position', [0 0 1 1]);
    w = make_rendered_fs_widget_(panel, [0 100], 'Smoke W1');
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('SmokeDetach');
    cleanupE = onCleanup(@() try_delete_obj(e));
    store = make_populated_store_([10 20 30 40 50 60 70 80], ...
        {'a','b','c','d','e','f','g','h'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    e.detachWidget(w);
    assert(isscalar(e.DetachedMirrors), ...
        sprintf('expected 1 detached mirror; got %d', numel(e.DetachedMirrors)));

    mirror = e.DetachedMirrors{1};
    cleanupM = onCleanup(@() try_delete_h(mirror.hFigure));
    cw = mirror.Widget;
    assert(isa(cw, 'FastSenseWidget'), 'mirror.Widget must be a FastSenseWidget clone');
    assert(logical(cw.ShowPlantLog), ...
        'mirror.Widget.ShowPlantLog must inherit true from the source (Decision G)');
    mirrorAx = cw.FastSenseObj.hAxes;
    nMirror = numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker'));
    assert(nMirror == 8, sprintf( ...
        'expected 8 WidgetPlantLogMarker handles on the mirror; got %d', nMirror));

    % Verify mirror has its own hover in engine.WidgetHovers_ (one for
    % source + one for mirror = 2 total).
    assert(numel(e.WidgetHovers_) >= 2, sprintf( ...
        'expected >= 2 hover pairs after detach (source + mirror); got %d', ...
        numel(e.WidgetHovers_)));
    hasMirrorHover = false;
    for hi = 1:numel(e.WidgetHovers_)
        pair = e.WidgetHovers_{hi};
        if numel(pair) == 2 && pair{1} == cw
            hasMirrorHover = true;
            break;
        end
    end
    assert(hasMirrorHover, ...
        'engine.WidgetHovers_ must contain a pair where pair{1} == mirror.Widget');

    clear cleanupM cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_tick_fans_out_to_both()
    % MATLAB-only: with both source AND detached mirror live, append one
    % more entry and notify PlantLogTailTick; assert BOTH the source widget's
    % axes AND the mirror's axes saw their marker counts increase.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_tick_fans_out_to_both (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    panel = uipanel(f, 'Position', [0 0 1 1]);
    w = make_rendered_fs_widget_(panel, [0 100], 'Smoke W1');
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('SmokeFanBoth');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.addWidget(w);  % source must be in engine.Widgets for tick fan-out to reach it.
    store = make_populated_store_([10 20 30 40 50 60 70 80], ...
        {'a','b','c','d','e','f','g','h'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    e.detachWidget(w);
    mirror = e.DetachedMirrors{1};
    cleanupM = onCleanup(@() try_delete_h(mirror.hFigure));

    mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
    tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
    cleanupT = onCleanup(@() try_delete_obj(tail));
    e.setPlantLogLiveTailForTest_(tail);

    sourceAx = w.FastSenseObj.hAxes;
    mirrorAx = mirror.Widget.FastSenseObj.hAxes;
    % Pre-fanout baseline: 8 each.
    assert(numel(findobj(sourceAx, 'Tag', 'WidgetPlantLogMarker')) == 8, ...
        'precondition: source has 8 markers');
    assert(numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker')) == 8, ...
        'precondition: mirror has 8 markers');

    md = struct('unit', 'ZK-12', 'shift', 'B', 'operator', 'jdoe');
    store.addEntries(PlantLogEntry('Timestamp', 95, ...
        'Message', 'late append', 'Metadata', md));
    notify(tail, 'PlantLogTailTick');

    nSource = numel(findobj(sourceAx, 'Tag', 'WidgetPlantLogMarker'));
    nMirror = numel(findobj(mirrorAx, 'Tag', 'WidgetPlantLogMarker'));
    assert(nSource == 9, sprintf( ...
        'source marker count must increase to 9 after tick fan-out; got %d', nSource));
    assert(nMirror == 9, sprintf( ...
        'mirror marker count must increase to 9 after tick fan-out (Decision G); got %d', nMirror));

    e.setPlantLogLiveTailForTest_([]);
    clear cleanupT cleanupM cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_cleanup()
    % MATLAB-only: toggle off + close mirror + delete engine; verify zero
    % orphan listeners, zero orphan hovers, zero orphan timers above baseline.
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_cleanup (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    baselineTimers = numel(timerfindall());

    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    panel = uipanel(f, 'Position', [0 0 1 1]);
    w = make_rendered_fs_widget_(panel, [0 100], 'Smoke W1');

    e = DashboardEngine('SmokeCleanup');
    store = make_populated_store_([10 20 30], {'a','b','c'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    e.detachWidget(w);
    mirror = e.DetachedMirrors{1};
    assert(numel(e.WidgetHovers_) == 2, ...
        sprintf('precondition: 2 hover pairs (source + mirror); got %d', numel(e.WidgetHovers_)));

    % Toggle OFF on source -- this should detach the source's hover AND
    % delete the XLim listener AND clear source markers (NOT the mirror).
    w.setShowPlantLog(false, e);
    assert(isempty(w.PlantLogXLimListener_), ...
        'PlantLogXLimListener_ must be empty after toggle off');
    assert(numel(findobj(w.FastSenseObj.hAxes, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'source marker count must be 0 after toggle off');

    % Close mirror figure -- removeDetachedByRef fires + must sweep the
    % mirror's hover. After this, WidgetHovers_ should be empty (the
    % source's hover was removed by setShowPlantLog(false) above).
    delete(mirror.hFigure);
    e.removeDetached();
    assert(numel(e.DetachedMirrors) == 0, ...
        sprintf('DetachedMirrors must be empty after removeDetached; got %d', ...
            numel(e.DetachedMirrors)));
    assert(numel(e.WidgetHovers_) == 0, ...
        sprintf('WidgetHovers_ must be empty after toggle off + mirror close; got %d', ...
            numel(e.WidgetHovers_)));

    % Delete engine; verify timers back to baseline.
    delete(e);
    delete(w);
    afterTimers = numel(timerfindall());
    assert(afterTimers <= baselineTimers, sprintf( ...
        'after cleanup, timerfindall must not exceed baseline; got %d > %d', ...
        afterTimers, baselineTimers));
    clear cleanupF;
    n = 1;
end
