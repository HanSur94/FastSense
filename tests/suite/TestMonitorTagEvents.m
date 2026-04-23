classdef TestMonitorTagEvents < matlab.unittest.TestCase
    %TESTMONITORTAGEVENTS Unit tests for MonitorTag debounce + hysteresis + event emission (Phase 1006-02).
    %   Covers:
    %     - MONITOR-05 Event emission with SensorName/ThresholdLabel carriers
    %       (Phase 1010 will migrate to Event.TagKeys; pre-Phase-1010 MUST NOT write TagKeys)
    %     - MONITOR-06 MinDuration debounce — strict less-than (matches EventDetector.m:52)
    %     - MONITOR-07 AlarmOffConditionFn hysteresis via two-state FSM
    %     - Native parent-X units for Event StartTime/EndTime
    %     - Multiple rising edges produce distinct events
    %     - Second (cache-hit) getXY does NOT re-emit events
    %     - Class header documents SensorName + ThresholdLabel carrier
    %     - Plan 01 regression grep gates still hold
    %     - Pitfall 5 carrier gate: no literal `.TagKeys` in MonitorTag.m
    %
    %   See also MonitorTag, Event, EventStore, TestMonitorTag.

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

        % ---- MONITOR-05 Event emission with carrier fields ----

        function testSingleRisingEdgeFiresEvent(testCase)
            parent = SensorTag('p', 'X', 1:10, 'Y', [0 0 0 0 10 10 10 0 0 0]);
            store  = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, 'EventStore', store);
            [~, ~] = m.getXY();
            events = store.getEvents();
            testCase.verifyNumElements(events, 1, 'Expected exactly 1 event');
            testCase.verifyEqual(events(1).SensorName, 'p', ...
                'SensorName carrier must equal parent.Key (MONITOR-05)');
            testCase.verifyEqual(events(1).ThresholdLabel, 'm', ...
                'ThresholdLabel carrier must equal monitor.Key (MONITOR-05)');
            testCase.verifyEqual(events(1).Direction, 'upper');
            testCase.verifyEqual(events(1).StartTime, 5, ...
                'StartTime must be native parent-X units');
            testCase.verifyEqual(events(1).EndTime, 7, ...
                'EndTime must be native parent-X units');
        end

        % ---- MONITOR-06 MinDuration debounce ----

        function testMinDurationFiltersShortPulse(testCase)
            x = 1:20;
            y = zeros(1, 20);
            y(10:11) = 10;
            parent = SensorTag('p', 'X', x, 'Y', y);
            store = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, ...
                           'MinDuration', 5, 'EventStore', store);
            [~, bin] = m.getXY();
            testCase.verifyEqual(sum(bin), 0, ...
                'MinDuration=5 must zero a 2-unit pulse in cached Y');
            testCase.verifyEmpty(store.getEvents(), ...
                'MinDuration=5 must filter short events');
        end

        function testMinDurationKeepsLongPulse(testCase)
            x = 1:20;
            y = zeros(1, 20);
            y(8:14) = 10;
            parent = SensorTag('p', 'X', x, 'Y', y);
            store = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, ...
                           'MinDuration', 5, 'EventStore', store);
            [~, bin] = m.getXY();
            testCase.verifyEqual(sum(bin), 7, 'Long pulse must survive debounce');
            events = store.getEvents();
            testCase.verifyNumElements(events, 1, ...
                'Exactly one event for a single long pulse');
            testCase.verifyEqual(events(1).StartTime, 8);
            testCase.verifyEqual(events(1).EndTime, 14);
        end

        function testMinDurationZero(testCase)
            % MinDuration = 0 (default) must preserve short pulse -> 1 event.
            x = 1:20;
            y = zeros(1, 20);
            y(10:11) = 10;
            parent = SensorTag('p', 'X', x, 'Y', y);
            store = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, 'EventStore', store);
            [~, bin] = m.getXY();
            testCase.verifyEqual(sum(bin), 2, 'MinDuration=0 preserves short pulse');
            testCase.verifyNumElements(store.getEvents(), 1, ...
                'MinDuration=0 must emit one event for a short pulse');
        end

        % ---- MONITOR-07 Hysteresis ----

        function testHysteresisSuppressesChatter(testCase)
            x = linspace(0, 10, 1001);
            y = 10 + 0.5 * sin(2 * pi * x);
            parent_raw = SensorTag('p_raw', 'X', x, 'Y', y);
            parent_hys = SensorTag('p_hys', 'X', x, 'Y', y);

            m_raw = MonitorTag('m_raw', parent_raw, @(xx, yy) yy > 10);
            [~, bin_raw] = m_raw.getXY();
            edges_raw = sum(diff([0 bin_raw 0]) == 1);

            m_hys = MonitorTag('m_hys', parent_hys, @(xx, yy) yy > 10, ...
                               'AlarmOffConditionFn', @(xx, yy) yy < 9.5);
            [~, bin_hys] = m_hys.getXY();
            edges_hys = sum(diff([0 bin_hys 0]) == 1);

            testCase.verifyGreaterThanOrEqual(edges_raw, 5, ...
                'Raw condition must chatter across the threshold');
            testCase.verifyEqual(edges_hys, 1, ...
                'Hysteresis must collapse chatter to a single rising edge');
        end

        function testHysteresisEmptyAlarmOffPreservesRaw(testCase)
            x = 1:10;
            y = [0 0 10 10 0 0 10 10 0 0];
            parent = SensorTag('p', 'X', x, 'Y', y);
            fn = @(xx, yy) yy > 5;
            m = MonitorTag('m', parent, fn);  % AlarmOffConditionFn default = []
            [~, bin] = m.getXY();
            expected = double(logical(fn(x, y)));
            testCase.verifyEqual(bin, expected, ...
                'Empty AlarmOffConditionFn must preserve raw condition output (Plan 01 behavior)');
        end

        % ---- Multiple rising edges ----

        function testMultipleRisingEdgesEmitDistinctEvents(testCase)
            x = 1:15;
            y = zeros(1, 15);
            y(3:5)   = 10;
            y(10:12) = 10;
            parent = SensorTag('p', 'X', x, 'Y', y);
            store = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, 'EventStore', store);
            [~, ~] = m.getXY();
            events = store.getEvents();
            testCase.verifyNumElements(events, 2, ...
                'Two separate pulses must emit two distinct events');
            testCase.verifyEqual(events(1).StartTime, 3);
            testCase.verifyEqual(events(1).EndTime, 5);
            testCase.verifyEqual(events(2).StartTime, 10);
            testCase.verifyEqual(events(2).EndTime, 12);
        end

        function testNoDuplicateEventsOnSecondGetXY(testCase)
            x = 1:10;
            y = [0 0 0 10 10 10 0 0 0 0];
            parent = SensorTag('p', 'X', x, 'Y', y);
            store = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, 'EventStore', store);
            [~, ~] = m.getXY();
            n1 = numel(store.getEvents());
            [~, ~] = m.getXY();  % cache hit, no recompute
            n2 = numel(store.getEvents());
            testCase.verifyEqual(n1, 1);
            testCase.verifyEqual(n2, n1, ...
                'Cache-hit getXY must NOT re-emit events');
        end

        % ---- Native parent-X units ----

        function testEventStartEndTimesUseNativeParentUnits(testCase)
            x = [100 200 300 400 500];
            y = [0 0 10 10 0];
            parent = SensorTag('p', 'X', x, 'Y', y);
            store = EventStore('');
            m = MonitorTag('m', parent, @(xx, yy) yy > 5, 'EventStore', store);
            [~, ~] = m.getXY();
            events = store.getEvents();
            testCase.verifyNumElements(events, 1);
            testCase.verifyEqual(events(1).StartTime, 300, ...
                'StartTime must be native parent-X units, not a sample index');
            testCase.verifyEqual(events(1).EndTime, 400, ...
                'EndTime must be native parent-X units, not a sample index');
        end

        % ---- Source-file gates ----

        % testCarrierPatternNoTagKeys removed 2026-04-23 (Phase 1014-07):
        % Phase 1010 (EVENT-01) legitimately added `ev.TagKeys = {...}`
        % writes to MonitorTag.m (see lines ~617 and ~727 -- "Phase 1010
        % (EVENT-01): TagKeys + EventBinding after append"). The Pitfall-5
        % pre-Phase-1010 invariant this test guarded is no longer a
        % product constraint. testClassHeaderDocumentsCarrier below still
        % enforces the SensorName+ThresholdLabel carrier fields for
        % backward compatibility.

        function testClassHeaderDocumentsCarrier(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            testCase.verifyNotEmpty(regexp(src, 'SensorName', 'once'), ...
                'Class header must document SensorName carrier.');
            testCase.verifyNotEmpty(regexp(src, 'ThresholdLabel', 'once'), ...
                'Class header must document ThresholdLabel carrier.');
        end

        function testRegressionPlan01Gates(testCase)
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            src  = fileread(fullfile(repo, 'libs', 'SensorThreshold', 'MonitorTag.m'));
            % Plan-01/1006 invariant "no storeMonitor references" was
            % relaxed in Phase 1007 Plan 02 (MONITOR-09). The relaxed
            % invariant is structural: every storeMonitor call site must
            % sit inside an `if obj.Persist` guard within 5 preceding lines.
            lines_mt = strsplit(src, char(10));
            nStore = 0; nGuarded = 0;
            for li = 1:numel(lines_mt)
                if ~isempty(regexp(lines_mt{li}, 'storeMonitor\s*\(', 'once'))
                    nStore = nStore + 1;
                    lo = max(1, li - 5);
                    window = strjoin(lines_mt(lo:li-1), char(10));
                    if ~isempty(regexp(window, 'if\s+.*obj\.Persist', 'once'))
                        nGuarded = nGuarded + 1;
                    end
                end
            end
            testCase.verifyEqual(nStore, nGuarded, sprintf( ...
                'Pitfall 2 (Plan 02 relaxed): %d storeMonitor calls, %d guarded by if obj.Persist', ...
                nStore, nGuarded));
            % The "lazy-by-default, no persistence" phrase was a Phase-1006
            % invariant. Phase 1007 Plan 02 introduces opt-in persistence
            % docs — retire the phrase check.
            testCase.verifyEmpty(regexp(src, 'PerSample|OnSample|onEachSample', 'match'), ...
                'MONITOR-10: no per-sample callback keywords.');
            testCase.verifyEmpty(regexp(src, 'interp1.*''linear''', 'match'), ...
                'ALIGN-01: no interp1 linear.');
            testCase.verifyEmpty(regexp(src, 'methods \(Abstract\)', 'match'), ...
                'Octave-safety: no methods (Abstract) block.');
        end

    end
end
