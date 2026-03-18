classdef TestAddLine < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testAddSingleLine(testCase)
            fp = FastSense();
            x = 1:100;
            y = rand(1, 100);
            fp.addLine(x, y);
            testCase.verifyEqual(numel(fp.Lines), 1, 'testAddSingleLine: expected 1 line');
            testCase.verifyEqual(fp.Lines(1).X, x, 'testAddSingleLine: X mismatch');
            testCase.verifyEqual(fp.Lines(1).Y, y, 'testAddSingleLine: Y mismatch');
        end

        function testAddMultipleLines(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.addLine(1:20, rand(1,20));
            fp.addLine(1:5, rand(1,5));
            testCase.verifyEqual(numel(fp.Lines), 3, 'testAddMultipleLines: expected 3 lines');
        end

        function testLineOptions(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10), 'Color', 'r', 'DisplayName', 'S1');
            testCase.verifyEqual(fp.Lines(1).Options.Color, 'r', 'testLineOptions: Color');
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'S1', 'testLineOptions: DisplayName');
        end

        function testDownsampleMethodDefault(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            testCase.verifyEqual(fp.Lines(1).DownsampleMethod, 'minmax', 'testDownsampleMethodDefault');
        end

        function testDownsampleMethodOverride(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10), 'DownsampleMethod', 'lttb');
            testCase.verifyEqual(fp.Lines(1).DownsampleMethod, 'lttb', 'testDownsampleMethodOverride');
        end

        function testRejectsNonMonotonicX(testCase)
            fp = FastSense();
            threw = false;
            try
                fp.addLine([1 3 2 4], rand(1,4));
            catch e
                threw = true;
                testCase.verifyNotEmpty(strfind(e.message, 'monotonically'), 'Wrong error message');
            end
            testCase.verifyTrue(threw, 'testRejectsNonMonotonicX: should have thrown');
        end

        function testRejectsMismatchedLengths(testCase)
            fp = FastSense();
            threw = false;
            try
                fp.addLine(1:10, rand(1,5));
            catch e
                threw = true;
                testCase.verifyNotEmpty(strfind(e.message, 'same number'), 'Wrong error message');
            end
            testCase.verifyTrue(threw, 'testRejectsMismatchedLengths: should have thrown');
        end

        function testColumnVectorsAccepted(testCase)
            fp = FastSense();
            fp.addLine((1:10)', rand(10,1));
            testCase.verifyEqual(numel(fp.Lines(1).X), 10, 'testColumnVectors: numel');
            testCase.verifyTrue(isrow(fp.Lines(1).X), 'testColumnVectors: must be row');
        end
    end
end
