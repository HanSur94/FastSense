classdef TestToStepFunctionMex < matlab.unittest.TestCase
    methods (TestClassSetup)
        function gateHeadlessLinux(testCase)
            %GATEHEADLESSLINUX Skip on Linux CI runners — same MATLAB
            %   dispatcher segfault as the other MEX-heavy gated classes.
            %   to_step_function_mex is also exercised through StateTag
            %   resolve paths. Interactive MATLAB / macOS / Windows CI
            %   run the full suite.
            if exist('OCTAVE_VERSION', 'builtin'); return; end
            isHeadlessLinux = ~ispc && ~ismac && ~usejava('desktop');
            testCase.assumeFalse(isHeadlessLinux, ...
                'TestToStepFunctionMex: pre-emptive headless-Linux gate (MEX-heavy class, R2021b dispatcher bug)');
        end

        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();

            % Make SensorThreshold private functions accessible
            test_dir = fileparts(mfilename('fullpath'));
            repo_root = fullfile(test_dir, '..', '..');
            privDir = fullfile(repo_root, 'libs', 'SensorThreshold', 'private');

            w = warning('off', 'all');
            addpath(privDir);
            warning(w);

            dirs = strsplit(path, pathsep);
            if ~any(strcmp(dirs, privDir))
                tmpDir = fullfile(tempdir, 'sensor_threshold_private_proxy');
                if ~exist(tmpDir, 'dir')
                    mkdir(tmpDir);
                end
                exts = {'*.m', '*.mex', '*.mexmaci64', '*.mexmaca64', '*.mexa64'};
                for e = 1:numel(exts)
                    files = dir(fullfile(privDir, exts{e}));
                    for i = 1:numel(files)
                        src = fullfile(privDir, files(i).name);
                        dst = fullfile(tmpDir, files(i).name);
                        copyfile(src, dst);
                    end
                end
                addpath(tmpDir);
            end

            % Also make FastSense private accessible for direct MEX calls
            add_fastsense_private_path();
        end
    end

    methods (TestMethodSetup)
        function checkMex(testCase)
            testCase.assumeTrue(exist('to_step_function_mex', 'file') == 3, ...
                'to_step_function_mex not compiled');
        end
    end

    methods (Test)
        function testAllNaN(testCase)
            [stepX, stepY] = to_step_function_mex([1 5 10], [NaN NaN NaN], 20);
            testCase.verifyEmpty(stepX, 'allNaN: stepX');
            testCase.verifyEmpty(stepY, 'allNaN: stepY');
        end

        function testSingleActive(testCase)
            [stepX, stepY] = to_step_function_mex([1 5 10], [NaN 42 NaN], 20);
            testCase.verifyEqual(stepX, [5 10], 'singleActive: stepX');
            testCase.verifyEqual(stepY, [42 42], 'singleActive: stepY');
        end

        function testAllActiveContiguous(testCase)
            [stepX, stepY] = to_step_function_mex([0 10 20], [5 5 5], 30);
            testCase.verifyEqual(stepX, [0 10 10 20 20 30], 'contiguous: stepX');
            testCase.verifyEqual(stepY, [5 5 5 5 5 5], 'contiguous: stepY');
        end

        function testContiguousDifferentValues(testCase)
            [stepX, stepY] = to_step_function_mex([0 10 20], [5 10 15], 30);
            testCase.verifyEqual(stepX, [0 10 10 20 20 30], 'diffValues: stepX');
            testCase.verifyEqual(stepY, [5 5 10 10 15 15], 'diffValues: stepY');
        end

        function testNaNGap(testCase)
            [stepX, stepY] = to_step_function_mex([0 10 20 30], [5 NaN NaN 8], 40);
            testCase.verifyEqual(numel(stepX), 5, 'gap: length');
            testCase.verifyEqual(stepX(1:2), [0 10], 'gap: first X');
            testCase.verifyEqual(stepY(1:2), [5 5], 'gap: first Y');
            testCase.verifyTrue(isnan(stepX(3)) && isnan(stepY(3)), 'gap: NaN sep');
            testCase.verifyEqual(stepX(4:5), [30 40], 'gap: last X');
            testCase.verifyEqual(stepY(4:5), [8 8], 'gap: last Y');
        end

        function testMixedContiguousAndGap(testCase)
            [stepX, stepY] = to_step_function_mex([0 10 20 30 40], [5 10 NaN NaN 3], 50);
            testCase.verifyEqual(stepX(1:4), [0 10 10 20], 'mixed: contiguous X');
            testCase.verifyEqual(stepY(1:4), [5 5 10 10], 'mixed: contiguous Y');
            testCase.verifyTrue(isnan(stepX(5)) && isnan(stepY(5)), 'mixed: NaN sep');
            testCase.verifyEqual(stepX(6:7), [40 50], 'mixed: gap seg X');
            testCase.verifyEqual(stepY(6:7), [3 3], 'mixed: gap seg Y');
        end

        function testLastSegmentUsesDataEnd(testCase)
            [stepX, stepY] = to_step_function_mex([0 10], [NaN 7], 100);
            testCase.verifyEqual(stepX, [10 100], 'dataEnd: stepX');
            testCase.verifyEqual(stepY, [7 7], 'dataEnd: stepY');
        end

        function testSingleBoundary(testCase)
            [stepX, stepY] = to_step_function_mex([5], [42], 99);
            testCase.verifyEqual(stepX, [5 99], 'singleBound: stepX');
            testCase.verifyEqual(stepY, [42 42], 'singleBound: stepY');
        end

        function testParityRandomSmall(testCase)
            %   Compare MEX output to MATLAB reference for random inputs.
            rng(123);
            for trial = 1:20
                nB = randi([2 30]);
                segBounds = sort(randi(1000, 1, nB));
                segBounds = unique(segBounds);
                nB = numel(segBounds);
                values = randn(1, nB) * 10;
                % Randomly set ~40% to NaN
                nanMask = rand(1, nB) < 0.4;
                values(nanMask) = NaN;
                dataEnd = segBounds(end) + randi(100);

                [mxX, mxY] = to_step_function_mex(segBounds, values, dataEnd);
                [mlX, mlY] = TestToStepFunctionMex.toStepFunctionRef(segBounds, values, dataEnd);
                testCase.verifyTrue(isequaln(mxX, mlX), ...
                    sprintf('parity trial %d: stepX mismatch', trial));
                testCase.verifyTrue(isequaln(mxY, mlY), ...
                    sprintf('parity trial %d: stepY mismatch', trial));
            end
        end

        function testParityLarge(testCase)
            %   Stress test with large segment count to exercise SIMD paths.
            rng(42);
            nB = 100000;
            segBounds = cumsum(rand(1, nB) * 10);
            values = randn(1, nB) * 50;
            nanMask = rand(1, nB) < 0.3;
            values(nanMask) = NaN;
            dataEnd = segBounds(end) + 100;

            [mxX, mxY] = to_step_function_mex(segBounds, values, dataEnd);
            [mlX, mlY] = TestToStepFunctionMex.toStepFunctionRef(segBounds, values, dataEnd);
            testCase.verifyTrue(isequaln(mxX, mlX), 'parity large: stepX');
            testCase.verifyTrue(isequaln(mxY, mlY), 'parity large: stepY');
        end

        function testParityAllActive(testCase)
            %   All segments active — no NaN gaps, pure contiguous.
            nB = 50000;
            segBounds = cumsum(ones(1, nB));
            values = sin(segBounds);
            dataEnd = segBounds(end) + 1;

            [mxX, mxY] = to_step_function_mex(segBounds, values, dataEnd);
            [mlX, mlY] = TestToStepFunctionMex.toStepFunctionRef(segBounds, values, dataEnd);
            testCase.verifyTrue(isequaln(mxX, mlX), 'parity allActive: stepX');
            testCase.verifyTrue(isequaln(mxY, mlY), 'parity allActive: stepY');
        end

        function testParityAllNaNLarge(testCase)
            %   All NaN — empty output.
            nB = 10000;
            segBounds = cumsum(rand(1, nB) * 10);
            values = NaN(1, nB);
            dataEnd = segBounds(end) + 50;

            [mxX, mxY] = to_step_function_mex(segBounds, values, dataEnd);
            testCase.verifyEmpty(mxX, 'allNaN large: stepX');
            testCase.verifyEmpty(mxY, 'allNaN large: stepY');
        end

        function testParityAlternatingNaN(testCase)
            %   Worst case for gap detection: every other segment is NaN.
            nB = 10000;
            segBounds = cumsum(ones(1, nB) * 5);
            values = repmat([7 NaN], 1, nB / 2);
            dataEnd = segBounds(end) + 5;

            [mxX, mxY] = to_step_function_mex(segBounds, values, dataEnd);
            [mlX, mlY] = TestToStepFunctionMex.toStepFunctionRef(segBounds, values, dataEnd);
            testCase.verifyTrue(isequaln(mxX, mlX), 'parity alternating: stepX');
            testCase.verifyTrue(isequaln(mxY, mlY), 'parity alternating: stepY');
        end
    end

    methods (Static, Access = private)
        function [stepX, stepY] = toStepFunctionRef(segBounds, values, dataEnd)
        %TOSTEPFUNCTIONREF Pure MATLAB reference implementation.
            nB = numel(segBounds);
            active = ~isnan(values);
            if ~any(active)
                stepX = []; stepY = []; return;
            end
            segEnds = [segBounds(2:end), dataEnd];
            activeIdx = find(active);
            nActive = numel(activeIdx);
            if nActive == 1
                stepX = [segBounds(activeIdx), segEnds(activeIdx)];
                stepY = [values(activeIdx), values(activeIdx)];
                return;
            end
            maxLen = 4 * nActive;
            stepX = zeros(1, maxLen);
            stepY = zeros(1, maxLen);
            prevEnds = segEnds(activeIdx(1:end-1));
            currStarts = segBounds(activeIdx(2:end));
            isGap = (prevEnds ~= currStarts);
            pos = 0;
            k = activeIdx(1);
            pos = pos + 1; stepX(pos) = segBounds(k); stepY(pos) = values(k);
            pos = pos + 1; stepX(pos) = segEnds(k);   stepY(pos) = values(k);
            for a = 2:nActive
                k = activeIdx(a);
                if isGap(a - 1)
                    pos = pos + 1; stepX(pos) = NaN;           stepY(pos) = NaN;
                    pos = pos + 1; stepX(pos) = segBounds(k);  stepY(pos) = values(k);
                    pos = pos + 1; stepX(pos) = segEnds(k);    stepY(pos) = values(k);
                else
                    pos = pos + 1; stepX(pos) = segBounds(k);  stepY(pos) = values(k);
                    pos = pos + 1; stepX(pos) = segEnds(k);    stepY(pos) = values(k);
                end
            end
            stepX = stepX(1:pos);
            stepY = stepY(1:pos);
        end
    end
end
