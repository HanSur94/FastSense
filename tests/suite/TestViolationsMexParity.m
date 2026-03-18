classdef TestViolationsMexParity < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            setup();
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..', 'libs', 'FastSense', 'private'));
        end
    end

    methods (TestMethodSetup)
        function checkMex(testCase)
            testCase.assumeTrue(exist('compute_violations_mex', 'file') == 3, 'compute_violations_mex not compiled');
        end
    end

    methods (Test)
        function testSingleThresholdUpper(testCase)
            rng(42);
            N = 100000;
            sensorY = randn(1, N) * 20 + 50;
            segLo = [1, 50001];
            segHi = [50000, N];
            thresholdValues = 60;
            directions = true;

            result_mex = compute_violations_mex(sensorY, double(segLo), double(segHi), double(thresholdValues), double(directions));
            result_mat = TestViolationsMexParity.compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
            testCase.verifyEqual(result_mex{1}, result_mat{1}, 'parity: single upper');
        end

        function testMultipleThresholdsMixedDirections(testCase)
            rng(42);
            N = 100000;
            sensorY = randn(1, N) * 20 + 50;
            segLo = [1, 50001];
            segHi = [50000, N];
            thresholdValues = [60, 40, 70, 30];
            directions = [true, false, true, false];

            result_mex = compute_violations_mex(sensorY, double(segLo), double(segHi), double(thresholdValues), double(directions));
            result_mat = TestViolationsMexParity.compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
            for t = 1:4
                testCase.verifyEqual(result_mex{t}, result_mat{t}, sprintf('parity: batch threshold %d', t));
            end
        end

        function testSingleElementSegments(testCase)
            sensorY = [1 2 3 4 5];
            segLo = [1 3 5];
            segHi = [1 3 5];
            thresholdValues = 3;
            directions = true;

            result_mex = compute_violations_mex(double(sensorY), double(segLo), double(segHi), double(thresholdValues), double(directions));
            result_mat = TestViolationsMexParity.compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
            testCase.verifyEqual(result_mex{1}, result_mat{1}, 'parity: single element');
        end

        function testNoViolations(testCase)
            sensorY = ones(1, 100);
            segLo = [1];
            segHi = [100];
            thresholdValues = 5;
            directions = true;

            result_mex = compute_violations_mex(double(sensorY), double(segLo), double(segHi), double(thresholdValues), double(directions));
            testCase.verifyEmpty(result_mex{1}, 'parity: no violations');
        end

        function testLargeDataset(testCase)
            N = 1000000;
            sensorY = randn(1, N) * 20 + 50;
            segLo = [1, 250001, 500001, 750001];
            segHi = [250000, 500000, 750000, N];
            thresholdValues = [60, 40];
            directions = [true, false];

            result_mex = compute_violations_mex(double(sensorY), double(segLo), double(segHi), double(thresholdValues), double(directions));
            result_mat = TestViolationsMexParity.compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
            testCase.verifyEqual(result_mex{1}, result_mat{1}, 'parity: 1M upper');
            testCase.verifyEqual(result_mex{2}, result_mat{2}, 'parity: 1M lower');
        end
    end

    methods (Static, Access = private)
        function batchViolIdx = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions)
            nThresholds = numel(thresholdValues);
            nSegs = numel(segLo);
            batchViolIdx = cell(1, nThresholds);
            totalPoints = sum(segHi - segLo + 1);
            for t = 1:nThresholds
                thVal = thresholdValues(t);
                isUpper = directions(t);
                idx = zeros(1, totalPoints);
                count = 0;
                for s = 1:nSegs
                    lo = segLo(s);
                    hi = segHi(s);
                    chunk = sensorY(lo:hi);
                    if isUpper
                        mask = chunk > thVal;
                    else
                        mask = chunk < thVal;
                    end
                    hits = find(mask) + lo - 1;
                    nHits = numel(hits);
                    idx(count+1:count+nHits) = hits;
                    count = count + nHits;
                end
                batchViolIdx{t} = idx(1:count);
            end
        end
    end
end
