classdef TestEventIntegration < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testFullPipeline(testCase)
            s = Sensor('vibration', 'Name', 'Motor Vibration');
            s.X = 1:20;
            s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

            sc = StateChannel('machine');
            sc.X = [1 11]; sc.Y = [1 1];
            s.addStateChannel(sc);

            t_vibwarn = Threshold('vibration_warning', 'Name', 'vibration warning', 'Direction', 'upper');
            t_vibwarn.addCondition(struct('machine', 1), 10);
            s.addThreshold(t_vibwarn);
            s.resolve();

            events = detectEventsFromSensor(s);
            testCase.verifyEqual(numel(events), 2, 'integration: 2 events detected');
            testCase.verifyEqual(events(1).StartTime, 4, 'integration: e1 start');
            testCase.verifyEqual(events(1).EndTime, 7, 'integration: e1 end');
            testCase.verifyEqual(events(2).StartTime, 13, 'integration: e2 start');
            testCase.verifyEqual(events(2).EndTime, 15, 'integration: e2 end');
        end

        function testStats(testCase)
            s = Sensor('vibration', 'Name', 'Motor Vibration');
            s.X = 1:20;
            s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

            sc = StateChannel('machine');
            sc.X = [1 11]; sc.Y = [1 1];
            s.addStateChannel(sc);

            t_vibwarn = Threshold('vibration_warning', 'Name', 'vibration warning', 'Direction', 'upper');
            t_vibwarn.addCondition(struct('machine', 1), 10);
            s.addThreshold(t_vibwarn);
            s.resolve();

            events = detectEventsFromSensor(s);
            testCase.verifyEqual(events(1).NumPoints, 4, 'integration: e1 numpoints');
            testCase.verifyEqual(events(1).PeakValue, 16, 'integration: e1 peak');
            testCase.verifyEqual(events(2).PeakValue, 22, 'integration: e2 peak');
        end

        function testDebounce(testCase)
            s = Sensor('vibration', 'Name', 'Motor Vibration');
            s.X = 1:20;
            s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

            sc = StateChannel('machine');
            sc.X = [1 11]; sc.Y = [1 1];
            s.addStateChannel(sc);

            t_vibwarn = Threshold('vibration_warning', 'Name', 'vibration warning', 'Direction', 'upper');
            t_vibwarn.addCondition(struct('machine', 1), 10);
            s.addThreshold(t_vibwarn);
            s.resolve();

            det = EventDetector('MinDuration', 3);
            events = detectEventsFromSensor(s, det);
            testCase.verifyEqual(numel(events), 1, 'integration debounce: 1 event');
            testCase.verifyEqual(events(1).StartTime, 4, 'integration debounce: kept longer event');
        end

        function testCallback(testCase)
            s = Sensor('vibration', 'Name', 'Motor Vibration');
            s.X = 1:20;
            s.Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];

            sc = StateChannel('machine');
            sc.X = [1 11]; sc.Y = [1 1];
            s.addStateChannel(sc);

            t_vibwarn = Threshold('vibration_warning', 'Name', 'vibration warning', 'Direction', 'upper');
            t_vibwarn.addCondition(struct('machine', 1), 10);
            s.addThreshold(t_vibwarn);
            s.resolve();

            callCount = 0;
            function onEvent(ev)
                callCount = callCount + 1;
            end
            det = EventDetector('OnEventStart', @onEvent);
            detectEventsFromSensor(s, det);
            testCase.verifyEqual(callCount, 2, 'integration callback: 2 calls');
        end
    end
end
