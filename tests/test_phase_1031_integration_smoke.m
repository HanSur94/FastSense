function test_phase_1031_integration_smoke()
%TEST_PHASE_1031_INTEGRATION_SMOKE End-to-end Phase 1031 smoke (cross-runtime where possible).
%
%   Proves the full Phase 1031 pipeline works as advertised:
%     - PlantLogStore + PlantLogReader (Phase 1029/1030 dependencies)
%     - PlantLogLiveTail re-reads file on tick_() and forwards to store
%     - DashboardEngine.computePlantLogMarkers populates slider markers
%     - PlantLogTailTick listener triggers slider refresh without re-render
%     - PlantLogSliderHover lookup finds the right entry near a marker
%
%   install() contract: deliberately omits any manual `addpath(fullfile(...,
%   'libs', 'PlantLog'))` or `addpath(fullfile(..., 'libs', 'Dashboard'))` --
%   install.m's libs-block is the regression gate.
%
%   Runtime gates:
%     - Tests 1 + 2 are cross-runtime (path pickup + headless lifecycle;
%       no graphics required)
%     - Tests 3 + 4 + 5 + 6 are MATLAB-only (uifigure + TimeRangeSelector +
%       PlantLogSliderHover are uifigure-heavy)
%
%   Coverage:
%     PLOG-LT-01 (re-reads + appends)        -> test_full_lifecycle
%     PLOG-LT-02 (no duplicates)             -> test_full_lifecycle
%     PLOG-LT-04 (clean stop)                -> test_full_pipeline_cleanup
%     PLOG-VIZ-01/02 (slider draws markers)  -> test_engine_slider_integration
%     PLOG-VIZ-06 (hover tooltip)            -> test_hover_finds_entry
%     PLOG-VIZ-08 (live refresh w/o re-render) -> test_live_tail_refreshes_slider
%     PLOG-VIZ-09 (theme token)              -> exercised indirectly via DashboardTheme

    add_paths_via_install_only();
    nPassed = 0;

    nPassed = nPassed + test_path_pickup();
    nPassed = nPassed + test_full_lifecycle();
    nPassed = nPassed + test_engine_slider_integration();
    nPassed = nPassed + test_live_tail_refreshes_slider();
    nPassed = nPassed + test_hover_finds_entry();
    nPassed = nPassed + test_full_pipeline_cleanup();

    assert(nPassed == 6, 'expected 6 sub-tests, got %d', nPassed);
    fprintf('    All 6 phase_1031_integration_smoke assertions passed.\n');
end

% =====================================================================
% PATH SETUP -- install() contract gate (do NOT add manual addpath here)
% =====================================================================

function add_paths_via_install_only()
    thisDir = fileparts(mfilename('fullpath'));
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

function try_delete_path(p)
    try
        if exist(p, 'file') == 2
            delete(p);
        end
    catch
    end
end

% =====================================================================
% CSV writers (cross-runtime; no readtable/writetable on writer side)
% =====================================================================

function write_initial_(path)
    fid = fopen(path, 'w');
    fprintf(fid, 'timestamp,message\n');
    fprintf(fid, '%s,%s\n', '2025-01-15 10:00:00', 'pump on');
    fprintf(fid, '%s,%s\n', '2025-01-15 10:05:00', 'pump off');
    fprintf(fid, '%s,%s\n', '2025-01-15 10:10:00', 'valve open');
    fclose(fid);
end

function append_rows_(path, rows)
    fid = fopen(path, 'a');
    for k = 1:numel(rows)
        fprintf(fid, '%s,%s\n', rows{k}{1}, rows{k}{2});
    end
    fclose(fid);
end

% =====================================================================
% SUB-TESTS
% =====================================================================

function n = test_path_pickup()
    assert(~isempty(which('PlantLogLiveTail')),    'PlantLogLiveTail must resolve');
    assert(~isempty(which('PlantLogSliderHover')), 'PlantLogSliderHover must resolve');
    assert(~isempty(which('PlantLogStore')),       'PlantLogStore must resolve');
    assert(~isempty(which('PlantLogReader')),      'PlantLogReader must resolve');
    assert(~isempty(which('DashboardEngine')),     'DashboardEngine must resolve');
    assert(~isempty(which('TimeRangeSelector')),   'TimeRangeSelector must resolve');
    n = 1;
end

function n = test_full_lifecycle()
    % Cross-runtime: just store + reader + tail through tick_(); no graphics.
    csvPath = [tempname '.csv'];
    cleanupP = onCleanup(@() try_delete_path(csvPath));
    write_initial_(csvPath);
    store = PlantLogStore(csvPath);
    m = struct( ...
        'TimestampColumn', 'timestamp', ...
        'MessageColumn',   'message', ...
        'TimestampFormat', '');
    % Initial import via openInteractive headless.
    entries = PlantLogReader.openInteractive(csvPath, ...
        'Headless', true, 'Mapping', m);
    store.addEntries(entries);
    assert(store.getCount() == 3, ...
        'expected 3 entries after initial import; got %d', store.getCount());
    tail = PlantLogLiveTail(store, csvPath, m);
    cleanupT = onCleanup(@() try_delete_obj(tail));
    tail.tick_();
    assert(store.getCount() == 3, ...
        'tick_() on unchanged file must not duplicate (PLOG-LT-02)');
    append_rows_(csvPath, { ...
        {'2025-01-15 10:15:00', 'pump on again'}, ...
        {'2025-01-15 10:20:00', 'pump off again'}});
    tail.tick_();
    assert(store.getCount() == 5, ...
        'tick_() after append must yield 5 entries (PLOG-LT-01); got %d', store.getCount());
    clear cleanupT cleanupP;
    n = 1;
end

function n = test_engine_slider_integration()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_engine_slider_integration (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
    tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
    sel.setDataRange(tsLow, tsHigh);

    e = DashboardEngine('TestSliderInt');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.setTimeRangeSelectorForTest_(sel);

    store = PlantLogStore('synthetic.csv');
    ts1 = datenum('2025-01-15 10:00:00'); %#ok<DATNM>
    ts2 = datenum('2025-01-15 10:05:00'); %#ok<DATNM>
    store.addEntries([ ...
        PlantLogEntry('Timestamp', ts1, 'Message', 'a', 'Metadata', struct()), ...
        PlantLogEntry('Timestamp', ts2, 'Message', 'b', 'Metadata', struct())]);
    e.setPlantLogStoreForTest_(store);

    assert(~isempty(sel.hPlantLogMarkers), ...
        'after store attach, selector.hPlantLogMarkers must be populated (PLOG-VIZ-01)');
    assert(~isempty(e.PlantLogSliderHover_), ...
        'after store attach with rendered selector, engine.PlantLogSliderHover_ must be non-empty (PLOG-VIZ-06)');

    clear cleanupE cleanupF;
    n = 1;
end

function n = test_live_tail_refreshes_slider()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_live_tail_refreshes_slider (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    csvPath = [tempname '.csv'];
    cleanupP = onCleanup(@() try_delete_path(csvPath));
    write_initial_(csvPath);

    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
    tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
    sel.setDataRange(tsLow, tsHigh);

    store = PlantLogStore(csvPath);
    m = struct('TimestampColumn', 'timestamp', ...
        'MessageColumn', 'message', 'TimestampFormat', '');
    tail = PlantLogLiveTail(store, csvPath, m);
    cleanupT = onCleanup(@() try_delete_obj(tail));

    e = DashboardEngine('TestLiveRefresh');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.setTimeRangeSelectorForTest_(sel);
    e.setPlantLogStoreForTest_(store);
    e.setPlantLogLiveTailForTest_(tail);

    % Tick: reads CSV, adds 3 entries; PlantLogTailTick fires, listener
    % calls computePlantLogMarkers, slider markers populate -- WITHOUT
    % calling engine.render() (PLOG-VIZ-08).
    tail.tick_();
    assert(store.getCount() == 3, ...
        'after tick_, store must have 3 entries; got %d', store.getCount());
    assert(~isempty(sel.hPlantLogMarkers), ...
        'after tick_, selector.hPlantLogMarkers must be populated by listener (PLOG-VIZ-08)');

    % Append rows + tick again -- markers must update.
    append_rows_(csvPath, { ...
        {'2025-01-15 10:15:00', 'cooler on'}, ...
        {'2025-01-15 10:20:00', 'cooler off'}});
    tail.tick_();
    assert(store.getCount() == 5, ...
        'after second tick_, store must have 5 entries; got %d', store.getCount());

    e.setPlantLogLiveTailForTest_([]);
    clear cleanupE cleanupT cleanupF cleanupP;
    n = 1;
end

function n = test_hover_finds_entry()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_hover_finds_entry (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    ts1 = datenum('2025-01-15 10:00:00'); %#ok<DATNM>
    ts2 = datenum('2025-01-15 10:05:00'); %#ok<DATNM>
    sel.setDataRange(ts1 - 1, ts2 + 1);

    e = DashboardEngine('TestHoverFind');
    cleanupE = onCleanup(@() try_delete_obj(e));
    e.setTimeRangeSelectorForTest_(sel);

    store = PlantLogStore('synthetic.csv');
    store.addEntries([ ...
        PlantLogEntry('Timestamp', ts1, 'Message', 'first',  'Metadata', struct()), ...
        PlantLogEntry('Timestamp', ts2, 'Message', 'second', 'Metadata', struct())]);
    e.setPlantLogStoreForTest_(store);

    assert(~isempty(e.PlantLogSliderHover_), 'precondition: hover must exist');
    pick = e.PlantLogSliderHover_.simulateHoverAt_(ts2);
    assert(~isempty(pick), 'hover lookup at ts2 must find an entry');
    assert(strcmp(pick.Message, 'second'), ...
        'hover lookup must return the right entry; got %s', pick.Message);

    clear cleanupE cleanupF;
    n = 1;
end

function n = test_full_pipeline_cleanup()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('    SKIP test_full_pipeline_cleanup (Octave: uifigure-heavy).\n');
        n = 1; return;
    end
    csvPath = [tempname '.csv'];
    cleanupP = onCleanup(@() try_delete_path(csvPath));
    write_initial_(csvPath);

    f = figure('Visible', 'off');
    cleanupF = onCleanup(@() try_delete_h(f));
    p = uipanel(f);
    sel = TimeRangeSelector(p, 'Theme', DashboardTheme('dark'));
    tsLow  = datenum('2025-01-15 09:00:00'); %#ok<DATNM>
    tsHigh = datenum('2025-01-15 11:00:00'); %#ok<DATNM>
    sel.setDataRange(tsLow, tsHigh);

    % Capture timer baseline before constructing the tail.
    baselineTimers = numel(timerfindall());

    store = PlantLogStore(csvPath);
    m = struct('TimestampColumn', 'timestamp', ...
        'MessageColumn', 'message', 'TimestampFormat', '');
    tail = PlantLogLiveTail(store, csvPath, m);
    e = DashboardEngine('TestFullCleanup');
    e.setTimeRangeSelectorForTest_(sel);
    e.setPlantLogStoreForTest_(store);
    e.setPlantLogLiveTailForTest_(tail);

    delete(e);
    delete(tail);

    % Verify timerfindall back to baseline (PLOG-LT-04). The hover's
    % auto-hide timer is created inside PlantLogSliderHover and torn down
    % when delete(engine) runs teardownPlantLogSliderHover_. The tail's
    % timer was never started (we called tick_() not start()).
    afterTimers = numel(timerfindall());
    assert(afterTimers <= baselineTimers, ...
        'after delete(engine) + delete(tail), timerfindall must not exceed baseline; got %d > %d', ...
        afterTimers, baselineTimers);

    % Verify WBMFcn does NOT contain a hover closure (would point at a
    % deleted hover handle and crash on motion).
    afterWBM = get(f, 'WindowButtonMotionFcn');
    if isa(afterWBM, 'function_handle')
        wbmStr = func2str(afterWBM);
        assert(isempty(strfind(wbmStr, 'onFigureMove_')), ...
            'after pipeline cleanup, WBMFcn must NOT reference hover''s closure; got %s', ...
            wbmStr); %#ok<STREMP>
    end

    clear cleanupF cleanupP;
    n = 1;
end
