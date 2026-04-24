classdef TestMonitorTagStreaming < matlab.unittest.TestCase
    %TESTMONITORTAGSTREAMING MONITOR-08 boundary-correctness tests for MonitorTag.appendData (Phase 1007-01).
    %   Covers the 7 boundary scenarios from RESEARCH Area 2:
    %     1. testAppendNoHysteresisNoDebounce        — tail extends cache; events fire for completed run
    %     2. testAppendOngoingRunExtendsIntoTail     — open run at cache end + falling edge in tail -> second event
    %     3. testAppendOngoingRunExtendsAcrossTail   — open run continues through full tail -> no new event
    %     4. testAppendHysteresisBoundaryNoChatter   — hysteresis FSM state carries; no phantom OFF at boundary
    %     5. testAppendMinDurationSpansBoundary_Survives — run long enough only after merge survives debounce
    %     6. testAppendMinDurationShortRunSpansBoundary_Zeroed — short run spanning boundary gets zeroed
    %     7. testAppendFirstEverIsFullRecompute      — appendData on dirty/cold cache falls back to recompute_
    %
    %   Plus 2 grep gates on libs/SensorThreshold/MonitorTag.m:
    %     - Exactly one `function appendData` declaration
    %     - At least 6 mentions of the 3 new cache-state fields (declared + written in recompute_ + appendData)
    %
    %   Plan 02 (recompute_) baseline: an open run at parent-end is closed by
    %   findRuns_'s trailing-zero trick (d = diff([0, bin, 0])) and fires an
    %   event with EndTime = px(end). Plan 03 (appendData) emits an ADDITIONAL
    %   event when the falling edge of that open run arrives inside newX —
    %   this is the documented Phase 1007 boundary contract.
    %
    %   See also MonitorTag, TestMonitorTag, TestMonitorTagEvents.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (TestMethodSetup)
        function resetRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (TestMethodTeardown)
        function teardownRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
        end
    end

    methods (Test)

        % ---- Scenario 1: no hysteresis, no debounce ----

        function testAppendNoHysteresisNoDebounce(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', zeros(1, 10));
            m = MonitorTag('m', parent, @(x, y) y > 5);
            [~, ~] = m.getXY();  % prime cache

            m.appendData(11:20, [0 0 0 10 10 10 0 0 0 0]);
            [mx, my] = m.getXY();

            testCase.verifyEqual(numel(mx), 20, ...
                'Scenario 1: cache must be EXTENDED not rebuilt');
            testCase.verifyEqual(numel(my), 20, ...
                'Scenario 1: cached Y must also be length 20');
            testCase.verifyEqual(sum(my(14:16)), 3, ...
                'Scenario 1: tail indices 14-16 must equal 1 (y > 5 at x=14,15,16)');
            testCase.verifyEqual(sum(my), 3, ...
                'Scenario 1: only 3 samples above threshold in full cache');
        end

        % ---- Scenario 2: ongoing run extends into tail (falling edge in tail) ----

        function testAppendOngoingRunExtendsIntoTail(testCase)
            % Phase 1012 Plan 02 open-event semantics:
            % recompute_ emits 1 IsOpen=true event for the open run (StartTime=6, EndTime=NaN).
            % appendData calls EventStore.closeEvent when the falling edge arrives in tail —
            % resulting in exactly 1 event with StartTime=6 and EndTime=12.
            parent = SensorTag('p', 'X', 1:10, 'Y', [0 0 0 0 0 10 10 10 10 10]);
            store  = EventStore('');
            m = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', store);
            [~, ~] = m.getXY();
            events1 = store.getEvents();
            testCase.verifyNumElements(events1, 1, ...
                'Scenario 2: recompute_ emits 1 open event for trailing open run');
            testCase.verifyEqual(events1(1).StartTime, 6);
            testCase.verifyTrue(events1(1).IsOpen, ...
                'Scenario 2: open run emits IsOpen=true event (Phase 1012)');
            testCase.verifyTrue(isnan(events1(1).EndTime), ...
                'Scenario 2: open event EndTime must be NaN before close');

            m.appendData(11:15, [10 10 0 0 0]);

            events2 = store.getEvents();
            testCase.verifyNumElements(events2, 1, ...
                'Scenario 2: closeEvent updates in place — still exactly 1 event');
            testCase.verifyEqual(events2(1).StartTime, 6, ...
                'Scenario 2: event StartTime unchanged after close');
            testCase.verifyEqual(events2(1).EndTime, 12, ...
                'Scenario 2: event EndTime set to falling edge (x=12) via closeEvent');
            testCase.verifyFalse(events2(1).IsOpen, ...
                'Scenario 2: event is no longer open after falling edge');
        end

        % ---- Scenario 3: ongoing run extends ACROSS tail (no falling edge) ----

        function testAppendOngoingRunExtendsAcrossTail(testCase)
            parent = SensorTag('p', 'X', 1:5, 'Y', [0 0 10 10 10]);
            store  = EventStore('');
            m = MonitorTag('m', parent, @(x, y) y > 5, 'EventStore', store);
            [~, ~] = m.getXY();
            events1 = store.getEvents();
            testCase.verifyNumElements(events1, 1, ...
                'Scenario 3: Plan 02 emits one event for open run (ends at parent end)');

            m.appendData(6:10, [10 10 10 10 10]);
            events2 = store.getEvents();

            testCase.verifyNumElements(events2, 1, ...
                'Scenario 3: run still open at tail end -> no new event emitted');
            [mx, my] = m.getXY();
            testCase.verifyEqual(numel(mx), 10);
            testCase.verifyTrue(all(my(6:10) == 1), ...
                'Scenario 3: tail cached Y must all be 1');
        end

        % ---- Scenario 4: hysteresis state carries across boundary ----

        function testAppendHysteresisBoundaryNoChatter(testCase)
            x1 = 1:10;
            y1 = linspace(9.5, 10.5, 10);  % monotonic rise; enters ON mid-way
            parent = SensorTag('p', 'X', x1, 'Y', y1);
            m = MonitorTag('m', parent, @(x, y) y > 10.4, ...
                'AlarmOffConditionFn', @(x, y) y < 9.6);
            [~, my1] = m.getXY();
            testCase.verifyEqual(my1(end), 1, ...
                'Scenario 4 setup: cache must end in ON state');

            % Tail y-values: below raw-on (10.4) but above alarm-off (9.6)
            % -> hysteresis keeps state ON; no phantom OFF edge at boundary.
            m.appendData(11:15, [10.3 10.3 10.3 10.3 10.3]);
            [~, my2] = m.getXY();

            testCase.verifyEqual(numel(my2), 15);
            testCase.verifyTrue(all(my2(11:15) == 1), ...
                'Scenario 4: hysteresis state must carry -> tail must stay ON');
            testCase.verifyEqual(my2(end), 1, ...
                'Scenario 4: last cached Y must remain 1 (no phantom OFF)');
        end

        % ---- Scenario 5: MinDuration run survives when second chunk brings it over threshold ----

        function testAppendMinDurationSpansBoundary_Survives(testCase)
            % Pre-boundary: run starts at idx 8, duration 2 in first chunk.
            % After first appendData: combined run 8..12 has duration 4 < 5 -> ZEROED.
            % After second appendData: a NEW tail-only run at x=18..24 has duration 6 > 5 -> SURVIVES.
            parent = SensorTag('p', 'X', 1:10, 'Y', [0 0 0 0 0 0 0 10 10 10]);
            store  = EventStore('');
            m = MonitorTag('m', parent, @(x, y) y > 5, ...
                'MinDuration', 5, 'EventStore', store);
            [~, my1] = m.getXY();
            testCase.verifyTrue(all(my1 == 0), ...
                'Scenario 5 setup: pre-boundary run duration 2 < MinDuration 5 -> all zero');
            testCase.verifyEqual(numel(store.getEvents()), 0, ...
                'Scenario 5 setup: no events for short run');

            m.appendData(11:15, [10 10 10 0 0]);
            [~, my2] = m.getXY();
            testCase.verifyEqual(sum(my2), 0, ...
                'Scenario 5: merged run 8..12 duration 4 still < 5 -> all zero');
            testCase.verifyEqual(numel(store.getEvents()), 0, ...
                'Scenario 5: still no event (merged run too short)');

            % Second append — run x=18..24 has duration 6 > 5 -> survives.
            m.appendData(16:25, [0 0 10 10 10 10 10 10 10 0]);
            [~, my3] = m.getXY();
            testCase.verifyEqual(numel(my3), 25);
            % my3(18..24) corresponds to x=18..24; in a 1-based cached array
            % aligned to x=1..25, indices 18..24 are the long run.
            testCase.verifyTrue(all(my3(18:24) == 1), ...
                'Scenario 5: long tail-only run (duration 6) must survive debounce');
            testCase.verifyEqual(numel(store.getEvents()), 1, ...
                'Scenario 5: exactly 1 event for the surviving run');
        end

        % ---- Scenario 6: short run spanning boundary stays zeroed ----

        function testAppendMinDurationShortRunSpansBoundary_Zeroed(testCase)
            % Pre-boundary: open run at idx 6..8, duration 2 in cache.
            % MinDuration=5 -> recompute_ zeros it (px(8)-px(6)=2 < 5).
            % Tail: 10,10,0,0 -> run closes at x=10; total span 6..10 = 4 < 5 -> STILL ZEROED.
            parent = SensorTag('p', 'X', 1:8, 'Y', [0 0 0 0 0 10 10 10]);
            store  = EventStore('');
            m = MonitorTag('m', parent, @(x, y) y > 5, ...
                'MinDuration', 5, 'EventStore', store);
            [~, my1] = m.getXY();
            testCase.verifyTrue(all(my1 == 0), ...
                'Scenario 6 setup: short run duration 2 -> zeroed by debounce');
            testCase.verifyEqual(numel(store.getEvents()), 0, ...
                'Scenario 6 setup: no events');

            m.appendData(9:12, [10 10 0 0]);
            events = store.getEvents();
            testCase.verifyEqual(numel(events), 0, ...
                'Scenario 6: merged-span duration 4 < 5 -> still no event');
        end

        % ---- Scenario 7: cold-cache appendData falls back to recompute_ ----

        function testAppendFirstEverIsFullRecompute(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', ones(1, 10) * 10);
            m = MonitorTag('m', parent, @(x, y) y > 5);

            % No getXY called yet -> cache is dirty/cold.
            testCase.verifyEqual(m.recomputeCount_, 0, ...
                'Scenario 7 setup: no recompute has happened yet');

            % appendData on cold cache -> must fall back to recompute_()
            m.appendData(999, 999);  % args ignored on cold path
            testCase.verifyEqual(m.recomputeCount_, 1, ...
                'Scenario 7: cold appendData must trigger full recompute_');

            [mx, my] = m.getXY();
            testCase.verifyEqual(numel(mx), 10, ...
                'Scenario 7: cache must match parent grid (10), NOT args');
            testCase.verifyEqual(numel(my), 10);
            testCase.verifyTrue(all(my == 1), ...
                'Scenario 7: parent Y is all 10, condition y>5 -> all 1');
            testCase.verifyEqual(m.recomputeCount_, 1, ...
                'Scenario 7: subsequent getXY is cache hit (no extra recompute)');
        end

        % ---- Grep gates on MonitorTag.m source ----

        function testAppendDataMethodExists(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'function appendData', 'match');
            testCase.verifyNumElements(matches, 1, ...
                'MONITOR-08: exactly one `function appendData` declaration required');
        end

        function testBoundaryStateFieldsPresent(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            matches = regexp(src, 'lastStateFlag_|ongoingRunStart_|lastHystState_', 'match');
            testCase.verifyGreaterThanOrEqual(numel(matches), 6, ...
                'MONITOR-08: 3 cache-state fields must be declared + written in recompute_ + appendData (>= 6 references)');
        end

        function testPersistenceCallsAreGuarded(testCase)
            % Plan-01 invariant "no storeMonitor references" was relaxed in
            % Plan 02 (MONITOR-09). The relaxed invariant: every
            % storeMonitor call site must sit inside an `if obj.Persist`
            % guard within 5 preceding lines (Pitfall 2 structural gate).
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
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
            testCase.verifyEqual(nStore, nGuarded, sprintf( ...
                'Pitfall 2 (Plan 02 relaxed): %d storeMonitor calls, %d guarded by if obj.Persist', ...
                nStore, nGuarded));
        end

    end
end
