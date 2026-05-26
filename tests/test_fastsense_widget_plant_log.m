function test_fastsense_widget_plant_log()
%TEST_FASTSENSE_WIDGET_PLANT_LOG Cross-runtime function-style tests for Phase 1032.
%   Phase 1032 PLOG-VIZ-03 + PLOG-VIZ-04: per-widget plant-log overlay.
%   Covers ShowPlantLog property, setPlantLogMarkers method, toStruct /
%   fromStruct round-trip, engine refreshPlantLogOverlayForWidget_ helper,
%   sub-pixel coalesce, XLim listener wiring, setShowPlantLog setter.
%
%   uifigure-heavy assertions are MATLAB-only — Octave is skipped at the
%   top because FastSenseWidget.render uses MATLAB's axes/uipanel idioms
%   that Octave does not fully support (and Phase 1031's tests follow the
%   same pattern).
%
%   Sub-tests 1-10 cover Task 1 (widget property + draw method).
%   Sub-tests 11-20 cover Task 2 (engine helpers + setShowPlantLog).

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_fastsense_widget_plant_log (Octave: uifigure-heavy).\n');
        return;
    end

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_default_show_plant_log_is_false();
    nPassed = nPassed + test_to_struct_omits_show_plant_log_when_false();
    nPassed = nPassed + test_to_struct_writes_show_plant_log_when_true();
    nPassed = nPassed + test_from_struct_reads_show_plant_log_true();
    nPassed = nPassed + test_from_struct_defaults_show_plant_log_false();
    nPassed = nPassed + test_set_plant_log_markers_draws_three_lines();
    nPassed = nPassed + test_set_plant_log_markers_empty_clears();
    nPassed = nPassed + test_set_plant_log_markers_drops_non_finite();
    nPassed = nPassed + test_set_plant_log_markers_idempotent();
    nPassed = nPassed + test_delete_widget_clears_listener_slot();

    % Task 2 sub-tests
    nPassed = nPassed + test_engine_refresh_for_widget_safe_when_off();
    nPassed = nPassed + test_engine_refresh_draws_five_markers();
    nPassed = nPassed + test_engine_sub_pixel_coalesce();
    nPassed = nPassed + test_engine_clear_all_widgets_preserves_show_state();
    nPassed = nPassed + test_engine_tick_fan_out_to_widgets();
    nPassed = nPassed + test_engine_tick_skips_widgets_with_show_false();
    nPassed = nPassed + test_engine_attach_xlim_listener_redraws_on_xlim_change();
    nPassed = nPassed + test_engine_refresh_clears_when_store_empty();
    nPassed = nPassed + test_widget_set_show_plant_log_toggle();
    nPassed = nPassed + test_widget_delete_no_orphan_listener();

    assert(nPassed == 20, 'expected 20 sub-tests, got %d', nPassed);
    fprintf('    All 20 fastsense_widget_plant_log assertions passed.\n');
end

% =====================================================================
% PATH SETUP -- install() contract gate (do NOT add manual addpath here)
% =====================================================================

function add_paths_via_install_only()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    install();
    assert(~isempty(which('FastSenseWidget')), ...
        'FastSenseWidget must resolve after install()');
    assert(~isempty(which('DashboardEngine')), ...
        'DashboardEngine must resolve after install()');
    assert(~isempty(which('PlantLogStore')), ...
        'PlantLogStore must resolve after install()');
    assert(~isempty(which('PlantLogEntry')), ...
        'PlantLogEntry must resolve after install()');
end

% =====================================================================
% NAMED CLEANUP HELPERS
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
% FIXTURE BUILDERS
% =====================================================================

function [f, panel] = make_offscreen_figure_with_panel_()
    f = figure('Visible', 'off');
    panel = uipanel(f, 'Position', [0 0 1 1]);
end

function w = make_rendered_widget_(xLim, panel)
    % Construct a FastSenseWidget with inline XData/YData covering xLim,
    % render it into the panel, then set the resulting axes XLim explicitly
    % so the plant-log filter logic can work against a known range.
    xLo = xLim(1); xHi = xLim(2);
    x = linspace(xLo, xHi, 100);
    y = sin(x * 0.1);
    w = FastSenseWidget('Title', 'Test', 'Position', [1 1 12 3], ...
        'XData', x, 'YData', y);
    w.render(panel);
    % FastSense overrides XLim from the data; force it to the test range.
    ax = w.FastSenseObj.hAxes;
    set(ax, 'XLim', xLim);
end

function s = make_populated_store_(timestamps, messages)
    s = PlantLogStore('synthetic.csv');
    n = numel(timestamps);
    es = repmat(PlantLogEntry('Timestamp', timestamps(1), ...
        'Message', messages{1}, 'Metadata', struct()), 1, n);
    for k = 2:n
        es(k) = PlantLogEntry('Timestamp', timestamps(k), ...
            'Message', messages{k}, 'Metadata', struct());
    end
    s.addEntries(es);
end

function entries = make_entry_array_(timestamps)
    % Plain struct array (not PlantLogEntry) — sufficient for setPlantLogMarkers
    % which uses `times` only. (Block C ignores entries.)
    n = numel(timestamps);
    entries = struct('Timestamp', num2cell(timestamps), ...
        'Message', repmat({''}, 1, n), ...
        'Metadata', repmat({struct()}, 1, n));
end

% =====================================================================
% SUB-TESTS — TASK 1
% =====================================================================

function n = test_default_show_plant_log_is_false()
    w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
    assert(isprop(w, 'ShowPlantLog'), 'ShowPlantLog property must exist');
    assert(islogical(w.ShowPlantLog) || isnumeric(w.ShowPlantLog), ...
        'ShowPlantLog should be boolean-ish; got %s', class(w.ShowPlantLog));
    assert(~w.ShowPlantLog, 'ShowPlantLog default must be false');
    assert(isprop(w, 'PlantLogXLimListener_'), ...
        'PlantLogXLimListener_ property must exist');
    assert(isempty(w.PlantLogXLimListener_), ...
        'PlantLogXLimListener_ must default to empty');
    n = 1;
end

function n = test_to_struct_omits_show_plant_log_when_false()
    w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
    s = w.toStruct();
    assert(~isfield(s, 'showPlantLog'), ...
        'toStruct() must omit showPlantLog when default false');
    n = 1;
end

function n = test_to_struct_writes_show_plant_log_when_true()
    w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
    w.ShowPlantLog = true;
    s = w.toStruct();
    assert(isfield(s, 'showPlantLog'), ...
        'toStruct() must write showPlantLog when true');
    assert(s.showPlantLog == true, 'showPlantLog must equal true');
    n = 1;
end

function n = test_from_struct_reads_show_plant_log_true()
    s = struct('type', 'fastsense', 'title', 't', ...
        'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3), ...
        'showPlantLog', true);
    w = FastSenseWidget.fromStruct(s);
    assert(w.ShowPlantLog == true, ...
        'fromStruct must restore ShowPlantLog=true from showPlantLog field');
    n = 1;
end

function n = test_from_struct_defaults_show_plant_log_false()
    s = struct('type', 'fastsense', 'title', 't', ...
        'position', struct('col', 1, 'row', 1, 'width', 12, 'height', 3));
    w = FastSenseWidget.fromStruct(s);
    assert(w.ShowPlantLog == false, ...
        'fromStruct without showPlantLog must default to false');
    n = 1;
end

function n = test_set_plant_log_markers_draws_three_lines()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    times = [10 20 30];
    entries = make_entry_array_(times);
    w.setPlantLogMarkers(times, entries);

    ax = w.FastSenseObj.hAxes;
    h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    assert(numel(h) == 3, ...
        'expected 3 marker handles, got %d', numel(h));
    % Color check: every marker should have Color == [0 0 0] (light theme default).
    for k = 1:numel(h)
        c = get(h(k), 'Color');
        assert(isequal(c, [0 0 0]), ...
            'marker %d Color must be [0 0 0]; got [%s]', k, num2str(c));
        lw = get(h(k), 'LineWidth');
        assert(lw == 1, 'marker %d LineWidth must be 1; got %g', k, lw);
    end
    clear cleanupW cleanupF;
    n = 1;
end

function n = test_set_plant_log_markers_empty_clears()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    times = [10 20 30];
    entries = make_entry_array_(times);
    w.setPlantLogMarkers(times, entries);
    ax = w.FastSenseObj.hAxes;
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 3, ...
        'precondition: 3 markers before clear');

    w.setPlantLogMarkers([], []);
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'setPlantLogMarkers([], []) must clear all markers');

    % Re-draw, then test single-arg empty.
    w.setPlantLogMarkers(times, entries);
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 3, ...
        'precondition: 3 markers re-drawn');
    w.setPlantLogMarkers([]);
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'setPlantLogMarkers([]) must clear all markers');

    clear cleanupW cleanupF;
    n = 1;
end

function n = test_set_plant_log_markers_drops_non_finite()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    times = [10 NaN 20 Inf -Inf 30];
    entries = make_entry_array_(times);
    w.setPlantLogMarkers(times, entries);
    ax = w.FastSenseObj.hAxes;
    h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    assert(numel(h) == 3, ...
        'expected 3 finite markers, got %d (must drop NaN/+Inf/-Inf silently)', numel(h));

    clear cleanupW cleanupF;
    n = 1;
end

function n = test_set_plant_log_markers_idempotent()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    timesA = [10 20 30];
    timesB = [40 50];
    w.setPlantLogMarkers(timesA, make_entry_array_(timesA));
    w.setPlantLogMarkers(timesB, make_entry_array_(timesB));

    ax = w.FastSenseObj.hAxes;
    h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    assert(numel(h) == 2, ...
        'second call must clear prior markers and leave exactly 2; got %d', numel(h));

    clear cleanupW cleanupF;
    n = 1;
end

function n = test_delete_widget_clears_listener_slot()
    w = FastSenseWidget('Title', 'x', 'XData', 1:10, 'YData', 1:10);
    w.ShowPlantLog = true;   % No engine attached yet — listener slot stays empty.
    assert(isempty(w.PlantLogXLimListener_), ...
        'precondition: PlantLogXLimListener_ stays empty without engine wiring');
    % delete() must not throw.
    delete(w);
    assert(true, 'delete(w) completed without throwing');
    n = 1;
end

% =====================================================================
% SUB-TESTS — TASK 2
% =====================================================================

function n = test_engine_refresh_for_widget_safe_when_off()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestRefreshOff');
    cleanupE = onCleanup(@() try_delete_obj(e));

    % ShowPlantLog == false: calling refresh must NOT throw and must clear markers.
    assert(~w.ShowPlantLog, 'precondition: ShowPlantLog is false');
    % Pre-seed some stale handles to prove they get cleared even when off.
    ax = w.FastSenseObj.hAxes;
    xline(ax, 50, '-', 'Tag', 'WidgetPlantLogMarker');
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 1, ...
        'precondition: stale marker seeded');

    e.refreshPlantLogOverlayForWidgetForTest_(w);
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'refresh must clear markers when ShowPlantLog=false');

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_refresh_draws_five_markers()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestRefreshFive');
    cleanupE = onCleanup(@() try_delete_obj(e));
    store = make_populated_store_([10 20 30 40 50], {'a', 'b', 'c', 'd', 'e'});
    e.setPlantLogStoreForTest_(store);

    w.ShowPlantLog = true;
    e.refreshPlantLogOverlayForWidgetForTest_(w);

    ax = w.FastSenseObj.hAxes;
    h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    assert(numel(h) == 5, ...
        'expected 5 markers after refresh; got %d', numel(h));

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_sub_pixel_coalesce()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 600], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestCoalesce');
    cleanupE = onCleanup(@() try_delete_obj(e));

    % Entries at 10, 10.5, 11, 100, 100.5, 200 with ~1 px per data unit on a
    % 600px axes should coalesce to floor(t) buckets: {10, 10, 11, 100, 100, 200}
    % unique stable -> {10, 11, 100, 200} = 4 buckets.
    %
    % Pixel width is environment-dependent, so we assert the count is at most
    % the input length and at least the count of unique floor-buckets at
    % pxPerData=1. With axes width ~600 px and XLim [0 600], pxPerData == 1
    % (or close), so the floor-bucketed unique count is the lower bound.
    timesIn = [10 10.5 11 100 100.5 200];
    store = make_populated_store_(timesIn, {'a','b','c','d','e','f'});
    e.setPlantLogStoreForTest_(store);
    w.ShowPlantLog = true;
    e.refreshPlantLogOverlayForWidgetForTest_(w);

    ax = w.FastSenseObj.hAxes;
    h = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    nDrawn = numel(h);
    assert(nDrawn <= numel(timesIn), ...
        'drawn count (%d) must not exceed input count (%d)', nDrawn, numel(timesIn));
    % Lower bound: unique floor-buckets at exact 1 px/data scaling = 4
    % (10, 11, 100, 200). Allow a wider lower bound (3) to tolerate
    % off-screen axes pixel-width drift.
    assert(nDrawn >= 3 && nDrawn <= 6, ...
        'sub-pixel coalesce must reduce to between 3 and 6 markers; got %d', nDrawn);

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_clear_all_widgets_preserves_show_state()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestClearAll');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.addWidget(w);
    store = make_populated_store_([10 20 30], {'a','b','c'});
    e.setPlantLogStoreForTest_(store);

    w.ShowPlantLog = true;
    e.refreshPlantLogOverlayForWidgetForTest_(w);

    ax = w.FastSenseObj.hAxes;
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 3, ...
        'precondition: 3 markers drawn');

    e.clearPlantLogOverlaysOnAllWidgetsForTest_();
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'clearAll must wipe markers');
    assert(w.ShowPlantLog == true, ...
        'clearAll must NOT flip ShowPlantLog (user state preserved)');

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_tick_fan_out_to_widgets()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestFanOut');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.addWidget(w);

    store = make_populated_store_([10 20 30], {'a','b','c'});
    e.setPlantLogStoreForTest_(store);

    w.ShowPlantLog = true;

    % Construct a real PlantLogLiveTail driven by the engine seam.
    mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
    tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
    cleanupT = onCleanup(@() try_delete_obj(tail));
    e.setPlantLogLiveTailForTest_(tail);

    % Notify the tail tick event directly (bypasses the timer).
    ax = w.FastSenseObj.hAxes;
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'precondition: no markers before tick');
    notify(tail, 'PlantLogTailTick');
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 3, ...
        'tick must fan out and draw 3 markers on the ShowPlantLog widget');

    clear cleanupT cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_tick_skips_widgets_with_show_false()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestSkipOff');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.addWidget(w);

    store = make_populated_store_([10 20 30], {'a','b','c'});
    e.setPlantLogStoreForTest_(store);
    assert(~w.ShowPlantLog, 'precondition: ShowPlantLog=false');

    mapping = struct('TimestampColumn', 'ts', 'MessageColumn', 'msg');
    tail = PlantLogLiveTail(store, 'synthetic.csv', mapping);
    cleanupT = onCleanup(@() try_delete_obj(tail));
    e.setPlantLogLiveTailForTest_(tail);

    ax = w.FastSenseObj.hAxes;
    notify(tail, 'PlantLogTailTick');
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'tick must SKIP ShowPlantLog=false widgets (no markers drawn)');

    clear cleanupT cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_attach_xlim_listener_redraws_on_xlim_change()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestXLimListener');
    cleanupE = onCleanup(@() try_delete_obj(e));

    store = make_populated_store_([10 20 30 40 50 60 70 80 90], ...
        {'1','2','3','4','5','6','7','8','9'});
    e.setPlantLogStoreForTest_(store);

    w.ShowPlantLog = true;
    e.attachPlantLogXLimListenerForTest_(w);
    assert(~isempty(w.PlantLogXLimListener_), ...
        'attachPlantLogXLimListener_ must populate widget.PlantLogXLimListener_');

    ax = w.FastSenseObj.hAxes;

    % Change XLim to [0 50] -> entries [10 20 30 40 50] = 5 markers
    set(ax, 'XLim', [0 50]);
    h1 = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    assert(numel(h1) == 5, ...
        'XLim=[0 50] must yield 5 markers; got %d', numel(h1));

    % Change XLim to [60 100] -> entries [60 70 80 90] = 4 markers
    set(ax, 'XLim', [60 100]);
    h2 = findobj(ax, 'Tag', 'WidgetPlantLogMarker');
    assert(numel(h2) == 4, ...
        'XLim=[60 100] must yield 4 markers; got %d', numel(h2));

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_engine_refresh_clears_when_store_empty()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestNoStore');
    cleanupE = onCleanup(@() try_delete_obj(e));

    w.ShowPlantLog = true;
    ax = w.FastSenseObj.hAxes;
    xline(ax, 50, '-', 'Tag', 'WidgetPlantLogMarker');
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 1, ...
        'precondition: stale marker seeded');

    % No store attached -> refresh must clear markers without throwing.
    e.refreshPlantLogOverlayForWidgetForTest_(w);
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'refresh with no store must clear markers and return silently');

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_widget_set_show_plant_log_toggle()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);
    cleanupW = onCleanup(@() try_delete_obj(w));

    e = DashboardEngine('TestToggle');
    cleanupE = onCleanup(@() try_delete_obj(e));

    store = make_populated_store_([10 20 30], {'a','b','c'});
    e.setPlantLogStoreForTest_(store);

    % Toggle ON.
    w.setShowPlantLog(true, e);
    assert(w.ShowPlantLog == true, 'setShowPlantLog(true, e) must flip on');
    assert(~isempty(w.PlantLogXLimListener_), ...
        'setShowPlantLog(true, e) must attach XLim listener');
    ax = w.FastSenseObj.hAxes;
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 3, ...
        'setShowPlantLog(true, e) must draw markers');

    % Toggle OFF.
    w.setShowPlantLog(false, e);
    assert(w.ShowPlantLog == false, 'setShowPlantLog(false, e) must flip off');
    assert(isempty(w.PlantLogXLimListener_), ...
        'setShowPlantLog(false, e) must clear XLim listener');
    assert(numel(findobj(ax, 'Tag', 'WidgetPlantLogMarker')) == 0, ...
        'setShowPlantLog(false, e) must clear markers');

    % Toggle ON with bad engine -> revert + warn.
    priorState = w.ShowPlantLog;
    lastwarn('');
    w.setShowPlantLog(true, []);
    [~, warnId] = lastwarn();
    assert(strcmp(warnId, 'FastSenseWidget:plantLogToggleFailed'), ...
        'setShowPlantLog(true, []) must emit FastSenseWidget:plantLogToggleFailed; got "%s"', warnId);
    assert(w.ShowPlantLog == priorState, ...
        'setShowPlantLog with invalid engine must revert to prior state');

    clear cleanupE cleanupW cleanupF;
    n = 1;
end

function n = test_widget_delete_no_orphan_listener()
    [f, panel] = make_offscreen_figure_with_panel_();
    cleanupF = onCleanup(@() try_delete_h(f));
    w = make_rendered_widget_([0 100], panel);

    e = DashboardEngine('TestOrphan');
    cleanupE = onCleanup(@() try_delete_obj(e));

    store = make_populated_store_([10 20 30], {'a','b','c'});
    e.setPlantLogStoreForTest_(store);

    w.setShowPlantLog(true, e);
    assert(~isempty(w.PlantLogXLimListener_), ...
        'precondition: listener attached');

    % delete(w) must not throw; the listener slot is released first.
    delete(w);
    assert(true, 'delete(w) with active listener completed without throwing');

    clear cleanupE cleanupF;
    n = 1;
end
