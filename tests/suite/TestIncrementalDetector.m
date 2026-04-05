classdef TestIncrementalDetector < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testFirstBatchDetectsEvents(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            sensor = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            t = linspace(now-1, now, 100);
            y = 80 * ones(1,100); y(40:60) = 120;
            newEvents = det.process('temp', sensor, t, y, [], {});
            testCase.verifyGreaterThanOrEqual(numel(newEvents), 1, 'detected_event');
            testCase.verifyEqual(newEvents(1).SensorName, 'temp', 'sensor_name');
        end

        function testIncrementalNewEventsOnly(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            sensor = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            t1 = linspace(now-1, now-0.5, 50);
            y1 = 80 * ones(1,50); y1(20:30) = 120;
            det.process('temp', sensor, t1, y1, [], {});
            % Second batch — no violations
            t2 = linspace(now-0.5, now, 50);
            y2 = 80 * ones(1,50);
            ev2 = det.process('temp', sensor, t2, y2, [], {});
            testCase.verifyEqual(numel(ev2), 0, 'no_new_events');
        end

        function testOpenEventCarriesOver(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            sensor = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            t1 = linspace(now-1, now-0.5, 50);
            y1 = 80 * ones(1,50); y1(40:50) = 120;
            ev1 = det.process('temp', sensor, t1, y1, [], {});
            testCase.verifyEqual(numel(ev1), 0, 'no_finalized_yet');
            testCase.verifyTrue(det.hasOpenEvent('temp'), 'has_open_event');
        end

        function testOpenEventFinalizes(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            sensor = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            t1 = linspace(now-1, now-0.5, 50);
            y1 = 80*ones(1,50); y1(40:50) = 120;
            det.process('temp', sensor, t1, y1, [], {});
            t2 = linspace(now-0.5, now, 50);
            y2 = 80*ones(1,50); y2(1:5) = 120;
            ev2 = det.process('temp', sensor, t2, y2, [], {});
            testCase.verifyEqual(numel(ev2), 1, 'finalized_event');
            testCase.verifyLessThan(ev2(1).StartTime, now - 0.4, 'start_in_batch1');
            testCase.verifyGreaterThan(ev2(1).EndTime, now - 0.5, 'end_in_batch2');
        end

        function testNoDataNoEvents(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            sensor = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            ev = det.process('temp', sensor, [], [], [], {});
            testCase.verifyEmpty(ev, 'no_events_empty_data');
        end

        function testSeverityEscalation(testCase)
            det = IncrementalEventDetector('MinDuration', 0, 'EscalateSeverity', true);
            sensor = Sensor('temp');
            tH = Threshold('h', 'Name', 'H', 'Direction', 'upper');
            tH.addCondition(struct(), 100);
            sensor.addThreshold(tH);
            tHH = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
            tHH.addCondition(struct(), 150);
            sensor.addThreshold(tHH);
            t = linspace(now-1, now, 100);
            y = 80*ones(1,100); y(40:60) = 160;
            ev = det.process('temp', sensor, t, y, [], {});
            hhEvents = ev(strcmp({ev.ThresholdLabel}, 'HH'));
            testCase.verifyNotEmpty(hhEvents, 'escalated_to_HH');
        end

        function testMultipleSensors(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            s1 = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            s2 = TestIncrementalDetector.makeSensor('pres', 50, 'upper');
            t = linspace(now-1, now, 100);
            y1 = 80*ones(1,100); y1(30:40) = 120;
            y2 = 30*ones(1,100); y2(60:70) = 60;
            ev1 = det.process('temp', s1, t, y1, [], {});
            ev2 = det.process('pres', s2, t, y2, [], {});
            testCase.verifyTrue(~isempty(ev1) && strcmp(ev1(1).SensorName, 'temp'), 'sensor1');
            testCase.verifyTrue(~isempty(ev2) && strcmp(ev2(1).SensorName, 'pres'), 'sensor2');
        end

        function testSliceDetectionConsistency(testCase)
            det = IncrementalEventDetector('MinDuration', 0);
            sensor = TestIncrementalDetector.makeSensor('temp', 100, 'upper');
            t1 = linspace(now-10, now-5, 500);
            y1 = 80*ones(1,500); y1(100:150) = 120;
            ev1 = det.process('temp', sensor, t1, y1, [], {});
            n1 = numel(ev1);
            t2 = linspace(now-5, now, 500);
            y2 = 80*ones(1,500); y2(200:250) = 120;
            ev2 = det.process('temp', sensor, t2, y2, [], {});
            testCase.verifyGreaterThanOrEqual(n1, 1, 'batch1_event');
            testCase.verifyGreaterThanOrEqual(numel(ev2), 1, 'batch2_event');
            testCase.verifyGreaterThan(ev2(1).StartTime, now - 5.1, 'new_event_in_batch2');
        end
    end

    methods (Static, Access = private)
        function sensor = makeSensor(key, threshVal, dir)
            sensor = Sensor(key);
            t = Threshold('h', 'Name', 'H', 'Direction', dir);
            t.addCondition(struct(), threshVal);
            sensor.addThreshold(t);
        end
    end
end
