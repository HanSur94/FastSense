classdef TestMockDataSource < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testConstructorDefaults(testCase)
            ds = MockDataSource();
            testCase.verifyEqual(ds.BaseValue, 100, 'default_base');
            testCase.verifyEqual(ds.NoiseStd, 1, 'default_noise');
            testCase.verifyEqual(ds.SampleInterval, 3, 'default_interval');
            testCase.verifyEqual(ds.BacklogDays, 3, 'default_backlog');
        end

        function testFirstFetchReturnsBacklog(testCase)
            ds = MockDataSource('BacklogDays', 1, 'SampleInterval', 3);
            result = ds.fetchNew();
            testCase.verifyTrue(result.changed, 'first_fetch_changed');
            expectedPoints = floor(1 * 86400 / 3);
            testCase.verifyLessThan(abs(numel(result.X) - expectedPoints), 10, 'backlog_point_count');
            testCase.verifyEqual(numel(result.Y), numel(result.X), 'xy_match');
            testCase.verifyTrue(all(diff(result.X) > 0), 'monotonic_time');
        end

        function testSubsequentFetchReturnsIncremental(testCase)
            ds = MockDataSource('BacklogDays', 0.001, 'SampleInterval', 3);
            ds.fetchNew();
            pause(0.01);
            ds.PipelineInterval = 15;
            result = ds.fetchNew();
            testCase.verifyTrue(result.changed, 'second_fetch_changed');
            testCase.verifyEqual(numel(result.X), 5, 'incremental_5pts');
        end

        function testUnchangedIfCalledTooFast(testCase)
            ds = MockDataSource('BacklogDays', 0.001, 'SampleInterval', 3);
            ds.fetchNew();
            ds.PipelineInterval = 15;
            ds.fetchNew();
            result = ds.fetchNew();
            testCase.verifyTrue(result.changed, 'mock_always_advances');
        end

        function testDeterministicSeed(testCase)
            ds1 = MockDataSource('Seed', 42, 'BacklogDays', 0.01);
            ds2 = MockDataSource('Seed', 42, 'BacklogDays', 0.01);
            r1 = ds1.fetchNew();
            r2 = ds2.fetchNew();
            testCase.verifyEqual(r1.Y, r2.Y, 'deterministic_values');
            testCase.verifyEqual(r1.X, r2.X, 'deterministic_times');
        end

        function testViolationEpisodes(testCase)
            ds = MockDataSource('BaseValue', 50, 'NoiseStd', 0.1, ...
                'ViolationProbability', 1.0, 'ViolationAmplitude', 30, ...
                'BacklogDays', 0.01, 'Seed', 99);
            result = ds.fetchNew();
            testCase.verifyTrue(any(result.Y > 60), 'violation_above_base');
        end

        function testSparseStateChanges(testCase)
            ds = MockDataSource('BacklogDays', 1, 'StateValues', {{'idle','running','cooldown'}}, ...
                'StateChangeProbability', 0.01, 'Seed', 7);
            result = ds.fetchNew();
            testCase.verifyNotEmpty(result.stateX, 'has_state_times');
            testCase.verifyNotEmpty(result.stateY, 'has_state_values');
            testCase.verifyLessThan(numel(result.stateX), numel(result.X) / 10, 'state_sparse');
            for i = 1:numel(result.stateY)
                testCase.verifyTrue(ismember(result.stateY{i}, {'idle','running','cooldown'}), 'valid_state');
            end
        end

        function testSampleInterval(testCase)
            ds = MockDataSource('BacklogDays', 0.01, 'SampleInterval', 5);
            result = ds.fetchNew();
            dt = diff(result.X) * 86400;
            testCase.verifyTrue(all(abs(dt - 5) < 0.01), 'sample_interval_5s');
        end
    end
end
