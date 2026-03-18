classdef TestEventSnapshot < matlab.unittest.TestCase
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
        function testGeneratesTwoPngs(testCase)
            [ev, sd] = TestEventSnapshot.makeTestEvent();
            outDir = tempname; mkdir(outDir);
            testCase.addTeardown(@() rmdir(outDir, 's'));
            files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
            testCase.verifyEqual(numel(files), 2, 'two_files');
            testCase.verifyTrue(isfile(files{1}), 'detail_exists');
            testCase.verifyTrue(isfile(files{2}), 'context_exists');
            testCase.verifyTrue(contains(files{1}, 'detail'), 'detail_name');
            testCase.verifyTrue(contains(files{2}, 'context'), 'context_name');
        end

        function testDetailPlotBounds(testCase)
            [ev, sd] = TestEventSnapshot.makeTestEvent();
            outDir = tempname; mkdir(outDir);
            testCase.addTeardown(@() rmdir(outDir, 's'));
            files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
            testCase.verifyTrue(isfile(files{1}), 'detail_created');
        end

        function testContextPlotBounds(testCase)
            [ev, sd] = TestEventSnapshot.makeTestEvent();
            outDir = tempname; mkdir(outDir);
            testCase.addTeardown(@() rmdir(outDir, 's'));
            files = generateEventSnapshot(ev, sd, 'OutputDir', outDir, 'ContextHours', 2);
            testCase.verifyTrue(isfile(files{2}), 'context_created');
        end

        function testShadedRegionExists(testCase)
            [ev, sd] = TestEventSnapshot.makeTestEvent();
            outDir = tempname; mkdir(outDir);
            testCase.addTeardown(@() rmdir(outDir, 's'));
            files = generateEventSnapshot(ev, sd, 'OutputDir', outDir);
            d = dir(files{1});
            testCase.verifyTrue(d.bytes > 1000, 'detail_not_empty');
            d = dir(files{2});
            testCase.verifyTrue(d.bytes > 1000, 'context_not_empty');
        end

        function testCustomSize(testCase)
            [ev, sd] = TestEventSnapshot.makeTestEvent();
            outDir = tempname; mkdir(outDir);
            testCase.addTeardown(@() rmdir(outDir, 's'));
            files = generateEventSnapshot(ev, sd, 'OutputDir', outDir, 'SnapshotSize', [400, 200]);
            testCase.verifyTrue(isfile(files{1}), 'custom_size_ok');
        end
    end

    methods (Static, Access = private)
        function [ev, sensorData] = makeTestEvent()
            tStart = now - 1/24;
            tEnd = now - 0.5/24;
            ev = Event(tStart, tEnd, 'temperature', 'HH', 100, 'upper');
            ev = ev.setStats(115, 50, 90, 115, 105, 106, 5);
            rng(42);
            t = linspace(now - 3/24, now, 1000);
            y = 80 + 5*randn(1, 1000);
            idx = t >= tStart & t <= tEnd;
            y(idx) = 110 + 5*randn(1, sum(idx));
            sensorData = struct('X', t, 'Y', y, 'thresholdValue', 100, 'thresholdDirection', 'upper');
        end
    end
end
