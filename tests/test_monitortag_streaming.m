function test_monitortag_streaming()
%TEST_MONITORTAG_STREAMING Octave flat-style port of TestMonitorTagStreaming (Phase 1007-01).
%   Mirrors the 7 boundary-correctness scenarios for MonitorTag.appendData
%   (MONITOR-08) plus 2 grep gates on libs/SensorThreshold/MonitorTag.m.
%
%   Plan 02 recompute_ baseline: open run at parent end fires 1 event
%   (EndTime = px(end)). Plan 03 appendData fires a SECOND event when the
%   falling edge arrives inside newX. Documented boundary contract.
%
%   See also test_monitortag, test_monitortag_events, TestMonitorTagStreaming.

    add_monitortag_streaming_path();
    TagRegistry.clear();

    % --- Scenario 1: no hysteresis, no debounce — cache is extended ---
    parent = SensorTag('p1', 'X', 1:10, 'Y', zeros(1, 10));
    m = MonitorTag('m1', parent, @(x, y) y > 5);
    [~, ~] = m.getXY();
    m.appendData(11:20, [0 0 0 10 10 10 0 0 0 0]);
    [mx, my] = m.getXY();
    assert(numel(mx) == 20, 'Scenario 1: cache length must be 20 (extended)');
    assert(numel(my) == 20, 'Scenario 1: cached Y must also be length 20');
    assert(sum(my(14:16)) == 3, 'Scenario 1: tail indices 14-16 must all be 1');
    assert(sum(my) == 3, 'Scenario 1: only 3 samples above threshold total');
    TagRegistry.clear();

    % --- Scenario 2: open run at cache end + falling edge in tail ---
    parent = SensorTag('p2', 'X', 1:10, 'Y', [0 0 0 0 0 10 10 10 10 10]);
    store  = EventStore('');
    m = MonitorTag('m2', parent, @(x, y) y > 5, 'EventStore', store);
    [~, ~] = m.getXY();
    e1 = store.getEvents();
    % Phase 1012 Plan 02: recompute_ emits 1 IsOpen=true event (EndTime=NaN) for open run.
    assert(numel(e1) == 1, 'Scenario 2: Plan 02 emits 1 open event for trailing open run');
    assert(e1(1).StartTime == 6, 'Scenario 2: first event StartTime 6');
    assert(e1(1).IsOpen == true, ...
        'Scenario 2: open run emits IsOpen=true event (Phase 1012)');
    assert(isnan(e1(1).EndTime), ...
        'Scenario 2: open event EndTime must be NaN before close (Phase 1012)');
    m.appendData(11:15, [10 10 0 0 0]);
    e2 = store.getEvents();
    % Phase 1012: closeEvent updates the same event in place — still 1 event, now closed.
    assert(numel(e2) == 1, ...
        'Scenario 2: closeEvent updates in place — still exactly 1 event (Phase 1012)');
    assert(e2(1).StartTime == 6, ...
        'Scenario 2: event StartTime unchanged after close');
    assert(e2(1).EndTime == 12, ...
        'Scenario 2: event EndTime set to falling edge (x=12) via closeEvent');
    assert(e2(1).IsOpen == false, ...
        'Scenario 2: event is no longer open after falling edge');
    TagRegistry.clear();

    % --- Scenario 3: open run continues through entire tail ---
    parent = SensorTag('p3', 'X', 1:5, 'Y', [0 0 10 10 10]);
    store  = EventStore('');
    m = MonitorTag('m3', parent, @(x, y) y > 5, 'EventStore', store);
    [~, ~] = m.getXY();
    assert(numel(store.getEvents()) == 1, ...
        'Scenario 3: Plan 02 emits one event for the open run');
    m.appendData(6:10, [10 10 10 10 10]);
    e3 = store.getEvents();
    assert(numel(e3) == 1, ...
        'Scenario 3: no falling edge in tail -> no new event');
    [mx, my] = m.getXY();
    assert(numel(mx) == 10, 'Scenario 3: cache length must be 10');
    assert(all(my(6:10) == 1), 'Scenario 3: tail cached Y all 1');
    TagRegistry.clear();

    % --- Scenario 4: hysteresis state carries across boundary ---
    x1 = 1:10;
    y1 = linspace(9.5, 10.5, 10);
    parent = SensorTag('p4', 'X', x1, 'Y', y1);
    m = MonitorTag('m4', parent, @(x, y) y > 10.4, ...
        'AlarmOffConditionFn', @(x, y) y < 9.6);
    [~, my1] = m.getXY();
    assert(my1(end) == 1, 'Scenario 4 setup: cache ends ON');
    m.appendData(11:15, [10.3 10.3 10.3 10.3 10.3]);
    [~, my2] = m.getXY();
    assert(numel(my2) == 15, 'Scenario 4: cache length 15');
    assert(all(my2(11:15) == 1), ...
        'Scenario 4: hysteresis state must carry — tail stays ON');
    assert(my2(end) == 1, 'Scenario 4: no phantom OFF at boundary');
    TagRegistry.clear();

    % --- Scenario 5: short-on-own but long-after-tail run survives ---
    parent = SensorTag('p5', 'X', 1:10, 'Y', [0 0 0 0 0 0 0 10 10 10]);
    store  = EventStore('');
    m = MonitorTag('m5', parent, @(x, y) y > 5, ...
        'MinDuration', 5, 'EventStore', store);
    [~, my1] = m.getXY();
    assert(all(my1 == 0), 'Scenario 5 setup: short run zeroed');
    assert(numel(store.getEvents()) == 0, 'Scenario 5 setup: no events');
    m.appendData(11:15, [10 10 10 0 0]);
    [~, my2] = m.getXY();
    assert(sum(my2) == 0, ...
        'Scenario 5: merged run 8..12 duration 4 still < 5 -> zeroed');
    assert(numel(store.getEvents()) == 0, 'Scenario 5: still no event');
    m.appendData(16:25, [0 0 10 10 10 10 10 10 10 0]);
    [~, my3] = m.getXY();
    assert(numel(my3) == 25, 'Scenario 5: cache length 25');
    assert(all(my3(18:24) == 1), ...
        'Scenario 5: long tail-only run (duration 6) survives debounce');
    assert(numel(store.getEvents()) == 1, ...
        'Scenario 5: exactly one event for the surviving long run');
    TagRegistry.clear();

    % --- Scenario 6: short merged run spanning boundary stays zeroed ---
    parent = SensorTag('p6', 'X', 1:8, 'Y', [0 0 0 0 0 10 10 10]);
    store  = EventStore('');
    m = MonitorTag('m6', parent, @(x, y) y > 5, ...
        'MinDuration', 5, 'EventStore', store);
    [~, my1] = m.getXY();
    assert(all(my1 == 0), 'Scenario 6 setup: open run duration 2 zeroed by debounce');
    assert(numel(store.getEvents()) == 0, 'Scenario 6 setup: no events');
    m.appendData(9:12, [10 10 0 0]);
    e = store.getEvents();
    assert(numel(e) == 0, ...
        'Scenario 6: merged-span duration 4 < 5 -> still no event');
    TagRegistry.clear();

    % --- Scenario 7: cold-cache appendData falls back to recompute_ ---
    parent = SensorTag('p7', 'X', 1:10, 'Y', ones(1, 10) * 10);
    m = MonitorTag('m7', parent, @(x, y) y > 5);
    assert(m.recomputeCount_ == 0, 'Scenario 7 setup: no recompute yet');
    m.appendData(999, 999);  % args ignored on cold path
    assert(m.recomputeCount_ == 1, ...
        'Scenario 7: cold appendData must trigger full recompute_');
    [mx, my] = m.getXY();
    assert(numel(mx) == 10, 'Scenario 7: cache matches parent grid (10)');
    assert(numel(my) == 10, 'Scenario 7: cached Y length 10');
    assert(all(my == 1), 'Scenario 7: parent Y=10, condition y>5 -> all 1');
    assert(m.recomputeCount_ == 1, 'Scenario 7: second getXY is cache hit');
    TagRegistry.clear();

    % --- Grep gates on MonitorTag.m ---
    src = fileread(monitortag_streaming_source_path_());
    assert(~isempty(regexp(src, 'function appendData', 'once')), ...
        'Grep gate 1: MonitorTag.m must declare `function appendData`');
    matches = regexp(src, 'lastStateFlag_|ongoingRunStart_|lastHystState_', 'match');
    assert(numel(matches) >= 6, ...
        'Grep gate 2: 3 cache-state fields must appear >= 6 times (declared + recompute_ + appendData)');
    % Plan-01 Pitfall 2 invariant was "no storeMonitor references". Plan 02
    % (MONITOR-09) introduces the Persist opt-in that REQUIRES a
    % storeMonitor call site. The relaxed invariant: every storeMonitor
    % call must sit inside an `if obj.Persist` guard (structural check
    % identical to tests/test_monitortag_persistence.m:run_pitfall_2_structural_).
    lines = strsplit(src, char(10));
    nStore = 0; nGuarded = 0;
    for li = 1:numel(lines)
        if ~isempty(regexp(lines{li}, 'storeMonitor\s*\(', 'once'))
            nStore = nStore + 1;
            lo = max(1, li - 5);
            window = strjoin(lines(lo:li-1), char(10));
            if ~isempty(regexp(window, 'if\s+.*obj\.Persist', 'once'))
                nGuarded = nGuarded + 1;
            end
        end
    end
    assert(nStore == nGuarded, ...
        sprintf('Pitfall 2 (Plan 02 relaxed): %d storeMonitor calls, %d guarded by if obj.Persist', ...
        nStore, nGuarded));

    fprintf('    All 7 streaming tests passed.\n');
end

function add_monitortag_streaming_path()
    %ADD_MONITORTAG_STREAMING_PATH Ensure repo + tests/suite on path.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end

function p = monitortag_streaming_source_path_()
    %MONITORTAG_STREAMING_SOURCE_PATH_ Absolute path to MonitorTag.m.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    p    = fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m');
end
