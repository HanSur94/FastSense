classdef TestBinarySearch < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testLeftBasic(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 4, 'left');
            testCase.verifyEqual(idx, 3, 'testLeftBasic: expected 3');
        end

        function testRightBasic(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 6, 'right');
            testCase.verifyEqual(idx, 3, 'testRightBasic: expected 3');
        end

        function testLeftExactMatch(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 5, 'left');
            testCase.verifyEqual(idx, 3, 'testLeftExactMatch: expected 3');
        end

        function testRightExactMatch(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 5, 'right');
            testCase.verifyEqual(idx, 3, 'testRightExactMatch: expected 3');
        end

        function testLeftBelowAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 0, 'left');
            testCase.verifyEqual(idx, 1, 'testLeftBelowAll: expected 1');
        end

        function testRightAboveAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 100, 'right');
            testCase.verifyEqual(idx, 5, 'testRightAboveAll: expected 5');
        end

        function testLeftAboveAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 100, 'left');
            testCase.verifyEqual(idx, 5, 'testLeftAboveAll: expected 5');
        end

        function testRightBelowAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 0, 'right');
            testCase.verifyEqual(idx, 1, 'testRightBelowAll: expected 1');
        end

        function testUnevenSpacing(testCase)
            x2 = [0.1 0.5 1.0 10.0 100.0 100.1];
            idx = binary_search(x2, 9.0, 'left');
            testCase.verifyEqual(idx, 4, 'testUnevenSpacing: expected 4');
        end

        function testLargeArray(testCase)
            x3 = 1:1e6;
            idx = binary_search(x3, 500000.5, 'left');
            testCase.verifyEqual(idx, 500001, 'testLargeArray: expected 500001');
        end

        function testSingleElement(testCase)
            x4 = [5];
            testCase.verifyEqual(binary_search(x4, 3, 'left'), 1, 'testSingleElement left');
            testCase.verifyEqual(binary_search(x4, 7, 'right'), 1, 'testSingleElement right');
        end
    end
end
