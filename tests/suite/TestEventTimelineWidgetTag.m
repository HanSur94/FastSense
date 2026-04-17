classdef TestEventTimelineWidgetTag < matlab.unittest.TestCase
    %TESTEVENTTIMELINEWIDGETTAG MATLAB unittest suite for EventTimelineWidget Tag migration.
    %   Phase 1009 Plan 02 — verifies the FilterTagKey property + the
    %   MONITOR-05 carrier-pattern filter (Event.SensorName OR
    %   Event.ThresholdLabel matches the tag key).  Also covers the
    %   sibling EventStore.getEventsForTag method directly.
    %
    %   See also EventTimelineWidget, EventStore, makePhase1009Fixtures.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
            addpath(fullfile(repo, 'tests', 'suite'));
        end
    end

    methods (Test)

        function testFilterTagKeyMatchesSensorName(testCase)
            store = buildStore_(testCase);
            % 3 events with SensorName='press_a' + 2 with SensorName='temp_b'
            % built by buildStore_.

            w = EventTimelineWidget('Title', 'T', 'EventStoreObj', store, ...
                'FilterTagKey', 'press_a');
            [tMin, tMax] = w.getTimeRange();
            testCase.verifyNotEqual(tMin, inf, ...
                'FilterTagKey=press_a must match events');
            % The 3 press_a events are at startTime 10, 20, 30.
            testCase.verifyEqual(tMin, 10);
            testCase.verifyEqual(tMax, 35);
        end

        function testFilterTagKeyMatchesThresholdLabel(testCase)
            store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
            ev = Event(100, 150, 'parent_x', 'mon_alarm', 5, 'upper');
            store.append(ev);

            w = EventTimelineWidget('Title', 'T', 'EventStoreObj', store, ...
                'FilterTagKey', 'mon_alarm');
            evts = w.getTimeRange();  %#ok<NASGU>
            % resolveEvents through getTimeRange triggers the filter.
            [tMin, tMax] = w.getTimeRange();
            testCase.verifyEqual(tMin, 100);
            testCase.verifyEqual(tMax, 150);
        end

        function testEmptyFilterTagKeyIsAllEvents(testCase)
            store = buildStore_(testCase);
            w = EventTimelineWidget('Title', 'T', 'EventStoreObj', store);
            [tMin, tMax] = w.getTimeRange();
            % 5 events: tMin=10 (press_a), tMax=85 (temp_b).
            testCase.verifyEqual(tMin, 10);
            testCase.verifyEqual(tMax, 85);
        end

        function testGetEventsForTagOnStore(testCase)
            store = buildStore_(testCase);
            got = store.getEventsForTag('press_a');
            testCase.verifyEqual(numel(got), 3);

            got2 = store.getEventsForTag('temp_b');
            testCase.verifyEqual(numel(got2), 2);

            gotMiss = store.getEventsForTag('nonexistent');
            testCase.verifyEmpty(gotMiss);
        end

        function testLegacyFilterSensorsStillWorks(testCase)
            % The existing FilterSensors substring filter path remains
            % unchanged (parallel filter, not replacement).
            evts = struct('startTime', {10, 20, 30}, ...
                          'endTime',   {15, 25, 35}, ...
                          'label',     {'Pump-101', 'Valve-202', 'Pump-101'}, ...
                          'color',     {[1 0 0], [0 1 0], [0 0 1]});
            w = EventTimelineWidget('Title', 'F', ...
                'Events', evts, 'FilterSensors', {{'Pump-101'}});
            [tMin, ~] = w.getTimeRange();
            testCase.verifyEqual(tMin, 10);
        end

        function testFilterTagKeyRoundTrip(testCase)
            w = EventTimelineWidget('Title', 'RT');
            w.FilterTagKey = 'alpha';
            s = w.toStruct();
            testCase.verifyTrue(isfield(s, 'filterTagKey'));
            testCase.verifyEqual(s.filterTagKey, 'alpha');

            w2 = EventTimelineWidget.fromStruct(s);
            testCase.verifyEqual(w2.FilterTagKey, 'alpha');
        end

    end
end

function store = buildStore_(testCase) %#ok<INUSD>
    store = EventStore(makePhase1009Fixtures.makeEventStoreTmp());
    % 3 events on 'press_a'
    store.append(Event(10, 15, 'press_a', 'hi',  50, 'upper'));
    store.append(Event(20, 25, 'press_a', 'hi',  50, 'upper'));
    store.append(Event(30, 35, 'press_a', 'alm', 80, 'upper'));
    % 2 events on 'temp_b'
    store.append(Event(60, 70, 'temp_b', 'hi',  100, 'upper'));
    store.append(Event(75, 85, 'temp_b', 'alm', 120, 'upper'));
end
