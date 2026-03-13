classdef TestDataStoreWAL < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
        end
    end
    methods (Test)
        function testEnableWAL(testCase)
            x = 1:1000; y = sin(x);
            ds = FastPlotDataStore(x, y);
            testCase.addTeardown(@() delete(ds));
            ds.enableWAL();
            ds.ensureOpen();
            result = mksqlite(ds.DbId, 'PRAGMA journal_mode');
            testCase.verifyEqual(lower(result.journal_mode), 'wal');
        end
        function testDisableWAL(testCase)
            x = 1:1000; y = sin(x);
            ds = FastPlotDataStore(x, y);
            testCase.addTeardown(@() delete(ds));
            ds.enableWAL();
            ds.disableWAL();
            ds.ensureOpen();
            result = mksqlite(ds.DbId, 'PRAGMA journal_mode');
            testCase.verifyEqual(lower(result.journal_mode), 'delete');
        end
        function testDataAccessAfterWAL(testCase)
            x = 1:1000; y = sin(x);
            ds = FastPlotDataStore(x, y);
            testCase.addTeardown(@() delete(ds));
            ds.enableWAL();
            [xOut, yOut] = ds.getRange(1, 1000);
            testCase.verifyGreaterThan(numel(xOut), 0);
            testCase.verifyGreaterThan(numel(yOut), 0);
        end
    end
end
