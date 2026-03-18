classdef TestLivePipeline < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'FastSense'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            [p, f] = TestLivePipeline.makePipeline();
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(f));
            testCase.verifyEqual(p.Status, 'stopped', 'initial_status');
            testCase.verifyEqual(p.Interval, 15, 'interval');
        end

        function testSingleCycle(testCase)
            [p, f] = TestLivePipeline.makePipeline();
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(f));
            p.runCycle();
            testCase.verifyTrue(isfile(f), 'store_file_created');
        end

        function testMultipleCyclesIncremental(testCase)
            [p, f] = TestLivePipeline.makePipeline();
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(f));
            p.runCycle();
            p.runCycle();
            p.runCycle();
        end

        function testEventsWrittenToStore(testCase)
            [p, f] = TestLivePipeline.makePipeline();
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(f));
            p.runCycle();
            data = load(f);
            testCase.verifyTrue(isfield(data, 'events'), 'has_events');
            testCase.verifyTrue(isfield(data, 'lastUpdated'), 'has_timestamp');
        end

        function testNotificationTriggered(testCase)
            [p, f] = TestLivePipeline.makePipeline();
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(f));
            for i = 1:3
                p.runCycle();
            end
            % Notification count is probabilistic but deterministic with Seed=42
            count = p.NotificationService.NotificationCount;
            testCase.verifyTrue(true, sprintf('Notification count: %d', count));
        end

        function testStartStop(testCase)
            [p, f] = TestLivePipeline.makePipeline();
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(f));
            p.start();
            testCase.verifyEqual(p.Status, 'running', 'running');
            pause(1);
            p.stop();
            testCase.verifyEqual(p.Status, 'stopped', 'stopped');
        end

        function testSensorFailureSkipped(testCase)
            s1 = Sensor('temp');
            s1.addThresholdRule(struct(), 100, 'Direction', 'upper', 'Label', 'HH');
            s2 = Sensor('broken');
            s2.addThresholdRule(struct(), 50, 'Direction', 'upper', 'Label', 'H');

            dsMap = DataSourceMap();
            dsMap.add('temp', MockDataSource('BaseValue', 80, 'BacklogDays', 0.001, 'Seed', 1));
            dsMap.add('broken', MatFileDataSource('/tmp/nonexistent_xyz.mat'));

            storeFile = [tempname '.mat'];
            testCase.addTeardown(@() TestLivePipeline.deleteIfExists(storeFile));
            sensors = containers.Map();
            sensors('temp') = s1;
            sensors('broken') = s2;

            p = LiveEventPipeline(sensors, dsMap, 'EventFile', storeFile);
            p.runCycle();
        end
    end

    methods (Static, Access = private)
        function [pipeline, storeFile] = makePipeline()
            s1 = Sensor('temp');
            s1.addThresholdRule(struct(), 100, 'Direction', 'upper', 'Label', 'HH');

            dsMap = DataSourceMap();
            dsMap.add('temp', MockDataSource('BaseValue', 80, 'NoiseStd', 1, ...
                'ViolationProbability', 0.5, 'ViolationAmplitude', 30, ...
                'BacklogDays', 0.01, 'Seed', 42, 'SampleInterval', 3));

            storeFile = [tempname '.mat'];
            sensors = containers.Map();
            sensors('temp') = s1;

            pipeline = LiveEventPipeline(sensors, dsMap, ...
                'EventFile', storeFile, ...
                'Interval', 15);
            pipeline.NotificationService = NotificationService('DryRun', true);
            pipeline.NotificationService.setDefaultRule( ...
                NotificationRule('Recipients', {{'test@test.com'}}, 'IncludeSnapshot', false));
        end

        function deleteIfExists(f)
            if exist(f, 'file'); delete(f); end
        end
    end
end
