classdef TestDetectEventsFromSensor < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testDefaultDetector(testCase)
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = [1 2 3 4 5 6 7 8 9 10];
            s.Y = [5 5 12 14 11 13 5 5 5 5];

            % Add a threshold (no state channels = always active)
            tw = Threshold('warn_high', 'Name', 'warn high', 'Direction', 'upper');
            tw.addCondition(struct(), 10);
            s.addThreshold(tw);
            s.resolve();

            events = detectEventsFromSensor(s);
            testCase.verifyTrue(numel(events) >= 1, 'default: at least one event');
            testCase.verifyEqual(events(1).SensorName, 'Temperature', 'default: SensorName from sensor.Name');
            testCase.verifyEqual(events(1).ThresholdLabel, 'warn high', 'default: ThresholdLabel');
            testCase.verifyEqual(events(1).Direction, 'upper', 'default: Direction');
        end

        function testCustomDetector(testCase)
            s = Sensor('temp', 'Name', 'Temperature');
            s.X = [1 2 3 4 5 6 7 8 9 10];
            s.Y = [5 5 12 14 11 13 5 5 5 5];

            tw = Threshold('warn_high', 'Name', 'warn high', 'Direction', 'upper');
            tw.addCondition(struct(), 10);
            s.addThreshold(tw);
            s.resolve();

            det = EventDetector('MinDuration', 5);
            events = detectEventsFromSensor(s, det);
            % Event duration is 3 (t=3 to t=6), so debounce should filter it
            testCase.verifyEmpty(events, 'customDetector: debounced');
        end

        function testMultipleThresholds(testCase)
            s2 = Sensor('temp', 'Name', 'Temperature');
            s2.X = [1 2 3 4 5 6 7 8 9 10];
            s2.Y = [5 5 12 14 11 13 5 5 5 5];
            tw = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
            tw.addCondition(struct(), 10);
            s2.addThreshold(tw);
            tc = Threshold('critical', 'Name', 'critical', 'Direction', 'upper');
            tc.addCondition(struct(), 13);
            s2.addThreshold(tc);
            s2.resolve();

            events = detectEventsFromSensor(s2);
            % warn: indices 3-6 (values 12,14,11,13 > 10)
            % critical: index 4 (value 14 > 13) and index 6 (value 13 == 13, NOT > 13)
            % So we expect at least 2 events (1 warn + 1 critical)
            labels = arrayfun(@(e) e.ThresholdLabel, events, 'UniformOutput', false);
            testCase.verifyTrue(any(strcmp(labels, 'warn')), 'multiThresh: has warn');
            testCase.verifyTrue(any(strcmp(labels, 'critical')), 'multiThresh: has critical');
        end
    end
end
