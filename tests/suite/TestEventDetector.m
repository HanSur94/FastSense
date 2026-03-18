classdef TestEventDetector < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDetectSingleEvent(testCase)
            det = EventDetector();
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [5 5 12 14 11 13 5 5 5 5];
            events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(numel(events), 1, 'singleEvent: count');
            testCase.verifyEqual(events(1).StartTime, 3, 'singleEvent: StartTime');
            testCase.verifyEqual(events(1).EndTime, 6, 'singleEvent: EndTime');
            testCase.verifyEqual(events(1).Duration, 3, 'singleEvent: Duration');
            testCase.verifyEqual(events(1).SensorName, 'temp', 'singleEvent: SensorName');
            testCase.verifyEqual(events(1).ThresholdLabel, 'warn', 'singleEvent: ThresholdLabel');
            testCase.verifyEqual(events(1).ThresholdValue, 10, 'singleEvent: ThresholdValue');
            testCase.verifyEqual(events(1).Direction, 'upper', 'singleEvent: Direction');
        end

        function testStats(testCase)
            det = EventDetector();
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [5 5 12 14 11 13 5 5 5 5];
            events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(events(1).PeakValue, 14, 'stats: PeakValue');
            testCase.verifyEqual(events(1).NumPoints, 4, 'stats: NumPoints');
            testCase.verifyEqual(events(1).MinValue, 11, 'stats: MinValue');
            testCase.verifyEqual(events(1).MaxValue, 14, 'stats: MaxValue');
            testCase.verifyLessThan(abs(events(1).MeanValue - 12.5), 1e-10, 'stats: MeanValue');
            expected_rms = sqrt(mean([12 14 11 13].^2));
            testCase.verifyLessThan(abs(events(1).RmsValue - expected_rms), 1e-10, 'stats: RmsValue');
            expected_std = std([12 14 11 13]);
            testCase.verifyLessThan(abs(events(1).StdValue - expected_std), 1e-10, 'stats: StdValue');
        end

        function testPeakValueLow(testCase)
            det = EventDetector();
            t      = [1 2 3 4 5];
            values = [50 3 2 4 50];
            events = det.detect(t, values, 10, 'lower', 'alarm', 'pressure');
            testCase.verifyEqual(events(1).PeakValue, 2, 'peakLow: PeakValue is min');
        end

        function testMultipleEvents(testCase)
            det = EventDetector();
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [12 13 5 5 5 14 15 5 5 5];
            events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(numel(events), 2, 'multipleEvents: count');
            testCase.verifyEqual(events(1).StartTime, 1, 'multipleEvents: e1 start');
            testCase.verifyEqual(events(2).StartTime, 6, 'multipleEvents: e2 start');
        end

        function testDebounceFilter(testCase)
            det = EventDetector('MinDuration', 2);
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [12 5 5 14 15 16 17 5 5 5];
            events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(numel(events), 1, 'debounce: count');
            testCase.verifyEqual(events(1).StartTime, 4, 'debounce: kept event');
        end

        function testNoViolations(testCase)
            det = EventDetector();
            t      = [1 2 3 4 5];
            values = [5 6 7 8 9];
            events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEmpty(events, 'noViolations: empty');
        end

        function testCallback(testCase)
            callCount = 0;
            lastEvent = [];
            function onEvent(ev)
                callCount = callCount + 1;
                lastEvent = ev;
            end
            det = EventDetector('OnEventStart', @onEvent);
            t      = [1 2 3 4 5 6 7 8 9 10];
            values = [12 13 5 5 5 14 15 5 5 5];
            det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(callCount, 2, 'callback: called twice');
            testCase.verifyEqual(lastEvent.StartTime, 6, 'callback: last event');
        end

        function testMaxCallsPerEvent(testCase)
            callCount = 0;
            function onEvent(ev)
                callCount = callCount + 1;
            end
            det = EventDetector('OnEventStart', @onEvent, 'MaxCallsPerEvent', 1);
            t      = [1 2 3 4 5];
            values = [12 13 14 15 16];
            det.detect(t, values, 10, 'upper', 'warn', 'temp');
            testCase.verifyEqual(callCount, 1, 'maxCalls: only called once for one event');
        end
    end
end
