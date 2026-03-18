classdef TestEventViewer < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
        end
    end

    methods (Test)
        function testConstructorEventsOnly(testCase)
            [events, ~, ~] = TestEventViewer.makeTestData();
            viewer = EventViewer(events);
            testCase.addTeardown(@close, viewer.hFigure);
            testCase.verifyNotEmpty(viewer.hFigure, 'eventsOnly: figure created');
            testCase.verifyTrue(ishandle(viewer.hFigure), 'eventsOnly: valid handle');
        end

        function testConstructorWithSensorData(testCase)
            [events, sensorData, ~] = TestEventViewer.makeTestData();
            viewer = EventViewer(events, sensorData);
            testCase.addTeardown(@close, viewer.hFigure);
            testCase.verifyNotEmpty(viewer.SensorData, 'withData: SensorData stored');
        end

        function testConstructorWithColors(testCase)
            [events, sensorData, colors] = TestEventViewer.makeTestData();
            viewer = EventViewer(events, sensorData, colors);
            testCase.addTeardown(@close, viewer.hFigure);
            testCase.verifyNotEmpty(viewer.ThresholdColors, 'withColors: colors stored');
        end

        function testUpdate(testCase)
            [events, sensorData, ~] = TestEventViewer.makeTestData();
            viewer = EventViewer(events, sensorData);
            testCase.addTeardown(@close, viewer.hFigure);
            e4 = Event(70, 75, 'Temperature', 'warning high', 80, 'upper');
            e4.setStats(88, 50, 78, 88, 83, 84, 2.1);
            viewer.update([events, e4]);
        end

        function testFilterSensors(testCase)
            [events, ~, ~] = TestEventViewer.makeTestData();
            viewer = EventViewer(events);
            testCase.addTeardown(@close, viewer.hFigure);
            names = viewer.getSensorNames();
            testCase.verifyEqual(numel(names), 2, 'filterSensors: 2 unique sensors');
            testCase.verifyTrue(any(strcmp(names, 'Temperature')), 'filterSensors: has Temperature');
            testCase.verifyTrue(any(strcmp(names, 'Pressure')), 'filterSensors: has Pressure');
        end

        function testFilterLabels(testCase)
            [events, ~, ~] = TestEventViewer.makeTestData();
            viewer = EventViewer(events);
            testCase.addTeardown(@close, viewer.hFigure);
            labels = viewer.getThresholdLabels();
            testCase.verifyEqual(numel(labels), 3, 'filterLabels: 3 unique labels');
        end

        function testBarPositionsCached(testCase)
            e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
            e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
            e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
            e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
            events = [e1, e2];

            viewer = EventViewer(events);
            testCase.addTeardown(@close, viewer.hFigure);
            testCase.verifyNotEmpty(viewer.BarPositions, 'bar_positions_not_empty');
            testCase.verifyEqual(size(viewer.BarPositions, 1), numel(viewer.BarRects), 'bar_positions_count');
            testCase.verifyEqual(size(viewer.BarPositions, 2), 4, 'bar_positions_cols');
            testCase.verifyTrue(all(viewer.BarPositions(:,3) > 0), 'bar_widths_positive');
            testCase.verifyTrue(all(viewer.BarPositions(:,4) > 0), 'bar_heights_positive');
        end
    end

    methods (Static, Access = private)
        function [events, sensorData, colors] = makeTestData()
            e1 = Event(10, 25, 'Temperature', 'warning high', 80, 'upper');
            e1.setStats(95.2, 150, 72, 95.2, 87.3, 88.1, 4.21);
            e2 = Event(50, 55, 'Pressure', 'low alarm', 5, 'lower');
            e2.setStats(2.1, 50, 2.1, 6.8, 4.5, 4.7, 1.2);
            e3 = Event(30, 40, 'Temperature', 'critical high', 100, 'upper');
            e3.setStats(110, 80, 95, 110, 103, 104, 3.5);
            events = [e1, e2, e3];

            sensorData(1).name = 'Temperature';
            sensorData(1).t = 1:100;
            sensorData(1).y = 50 + 30*sin((1:100)/10);
            sensorData(2).name = 'Pressure';
            sensorData(2).t = 1:100;
            sensorData(2).y = 10 + 5*sin((1:100)/8);

            colors = containers.Map();
            colors('warning high') = [1 0.8 0];
            colors('critical high') = [1 0 0];
            colors('low alarm') = [0 0.5 1];
        end
    end
end
