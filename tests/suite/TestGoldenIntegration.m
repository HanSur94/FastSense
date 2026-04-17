classdef TestGoldenIntegration < matlab.unittest.TestCase
% GOLDEN INTEGRATION TEST -- v2.0 Tag API (rewritten from legacy Sensor API in Phase 1011).
%
% Regression guard for the Tag-based domain model.  Exercises the full
% SensorTag -> MonitorTag -> CompositeTag -> EventStore -> FastSense
% pipeline with the same fixture data and equivalent assertion semantics
% as the original Phase 1003 legacy test.
%
% Assertion mapping (legacy -> Tag API):
%   1. s.countViolations() > 0    -> any(monitorBin == 1)
%   2. detectEventsFromSensor -> 2 events  -> EventStore: 2 events, same timing + peaks
%   3. debounced -> 1 event       -> MonitorTag MinDuration=3: 1 event
%   4. CompositeThreshold AND     -> CompositeTag 'and' valueAt: both active -> 1
%   5. fp.addSensor(s) -> 1 line  -> fp.addTag(st) -> 1 line
%
% See also SensorTag, MonitorTag, CompositeTag, EventStore, FastSense.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (TestMethodSetup)
        function clearRegistry(testCase) %#ok<MANU>
            TagRegistry.clear();
            EventBinding.clear();
        end
    end

    methods (TestMethodTeardown)
        function clearAfter(testCase) %#ok<MANU>
            TagRegistry.clear();
            EventBinding.clear();
        end
    end

    methods (Test)

        function testGoldenIntegration(testCase)
            % Fixture -- synthetic sensor crossing threshold twice
            % Same Y pattern as the legacy test; violations at indices 4-7
            % (Y=12,14,16,14) and 13-15 (Y=18,20,22).
            X = 1:20;
            Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];
            st = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar', ...
                'X', X, 'Y', Y);

            % MonitorTag: condition y > 10 (equivalent to legacy Threshold
            % 'press_hi' with Direction='upper', Value=10, machine=1).
            % Legacy StateChannel had machine=1 everywhere, so the condition
            % was always active -- MonitorTag conditionFn captures this
            % directly without needing a state channel.
            es = EventStore('');
            mon = MonitorTag('press_hi', st, @(x, y) y > 10, 'EventStore', es);

            % Assertion 1 -- violations exist (was: s.countViolations() > 0)
            [~, my] = mon.getXY();
            testCase.verifyTrue(any(my == 1), ...
                'golden: violations detected');

            % Assertion 2 -- event detection: 2 events with matching timing + peaks
            % (was: events = detectEventsFromSensor(s) -> 2 events)
            events = es.getEvents();
            testCase.verifyEqual(numel(events), 2, ...
                'golden: two events detected');
            testCase.verifyEqual(events(1).StartTime, 4, ...
                'golden: event1 start');
            testCase.verifyEqual(events(1).EndTime, 7, ...
                'golden: event1 end');
            % Peak values computed from raw sensor data within event windows
            % (MonitorTag events carry timing only; peak is max(Y) in window)
            [sx, sy] = st.getXY();
            mask1 = sx >= events(1).StartTime & sx <= events(1).EndTime;
            testCase.verifyEqual(max(sy(mask1)), 16, ...
                'golden: event1 peak');
            testCase.verifyEqual(events(2).StartTime, 13, ...
                'golden: event2 start');
            mask2 = sx >= events(2).StartTime & sx <= events(2).EndTime;
            testCase.verifyEqual(max(sy(mask2)), 22, ...
                'golden: event2 peak');

            % Assertion 3 -- debounced detection: MinDuration=3 keeps only
            % the longer event (duration 7-4=3 >= 3; second event 15-13=2 < 3).
            % (was: det = EventDetector('MinDuration', 3); detectEventsFromSensor -> 1 event)
            es2 = EventStore('');
            monLong = MonitorTag('press_hi_debounce', st, @(x, y) y > 10, ...
                'MinDuration', 3, 'EventStore', es2);
            monLong.getXY();  % trigger computation + event emission
            eventsLong = es2.getEvents();
            testCase.verifyEqual(numel(eventsLong), 1, ...
                'golden: debounce keeps only longer event');
            testCase.verifyEqual(eventsLong(1).StartTime, 4, ...
                'golden: debounce kept first event');

            % Assertion 4 -- CompositeTag AND aggregation
            % Legacy: CompositeThreshold AND with one alarm child (15 > 10)
            % and one ok child (50 < 80) returned 'alarm'.
            % Tag API: CompositeTag AND returns 1 only when ALL children are 1.
            % To preserve the 'alarm' assertion, both monitors must be active
            % at the evaluation point.  At t=4, Y(4)=12: 12>10 (mon active)
            % and 12>5 (mon2 active).  AND(1,1) = 1 = alarm.
            mon2 = MonitorTag('press_lo', st, @(x, y) y > 5);
            comp = CompositeTag('pump_a_health', 'and');
            comp.addChild(mon);
            comp.addChild(mon2);
            testCase.verifyEqual(comp.valueAt(4), 1, ...
                'golden: AND mode both active -> alarm');

            % Assertion 5 -- FastSense wiring
            % (was: fp.addSensor(s) -> 1 line)
            fp = FastSense();
            fp.addTag(st);
            testCase.verifyEqual(numel(fp.Lines), 1, ...
                'golden: one line after addTag');
        end

    end
end
