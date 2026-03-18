classdef TestMatFileDataSource < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'EventDetection'));
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'SensorThreshold'));
            install();
        end
    end

    methods (Test)
        function testConstructor(testCase)
            ds = MatFileDataSource('/tmp/test.mat', 'XVar', 't', 'YVar', 'y');
            testCase.verifyEqual(ds.FilePath, '/tmp/test.mat', 'filepath');
            testCase.verifyEqual(ds.XVar, 't', 'xvar');
            testCase.verifyEqual(ds.YVar, 'y', 'yvar');
        end

        function testFirstFetchReadsAll(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestMatFileDataSource.deleteIfExists(f));
            x = [1 2 3 4 5]; y = [10 20 30 40 50];
            save(f, 'x', 'y');
            ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
            result = ds.fetchNew();
            testCase.verifyTrue(result.changed, 'changed');
            testCase.verifyEqual(result.X, x, 'all_x');
            testCase.verifyEqual(result.Y, y, 'all_y');
        end

        function testIncrementalFetch(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestMatFileDataSource.deleteIfExists(f));
            x = [1 2 3]; y = [10 20 30];
            save(f, 'x', 'y');
            ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
            ds.fetchNew();
            pause(1.1);
            x = [1 2 3 4 5]; y = [10 20 30 40 50];
            save(f, 'x', 'y');
            result = ds.fetchNew();
            testCase.verifyTrue(result.changed, 'changed');
            testCase.verifyEqual(result.X, [4 5], 'only_new_x');
            testCase.verifyEqual(result.Y, [40 50], 'only_new_y');
        end

        function testUnchangedFile(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestMatFileDataSource.deleteIfExists(f));
            x = [1 2 3]; y = [10 20 30];
            save(f, 'x', 'y');
            ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y');
            ds.fetchNew();
            result = ds.fetchNew();
            testCase.verifyTrue(~result.changed, 'not_changed');
            testCase.verifyEmpty(result.X, 'empty_x');
        end

        function testStateData(testCase)
            f = [tempname '.mat'];
            testCase.addTeardown(@() TestMatFileDataSource.deleteIfExists(f));
            x = [1 2 3]; y = [10 20 30];
            stateX = [1 2.5]; stateY = {'idle', 'running'};
            save(f, 'x', 'y', 'stateX', 'stateY');
            ds = MatFileDataSource(f, 'XVar', 'x', 'YVar', 'y', ...
                'StateXVar', 'stateX', 'StateYVar', 'stateY');
            result = ds.fetchNew();
            testCase.verifyEqual(result.stateX, stateX, 'state_x');
            testCase.verifyEqual(result.stateY, stateY, 'state_y');
        end

        function testMissingFile(testCase)
            ds = MatFileDataSource('/tmp/nonexistent_abc123.mat', 'XVar', 'x', 'YVar', 'y');
            result = ds.fetchNew();
            testCase.verifyTrue(~result.changed, 'missing_not_changed');
            testCase.verifyEmpty(result.X, 'missing_empty');
        end
    end

    methods (Static, Access = private)
        function deleteIfExists(f)
            if exist(f, 'file'); delete(f); end
        end
    end
end
