classdef TestMinmaxDownsample < matlab.unittest.TestCase
    methods (TestClassSetup)
        function gateHeadlessLinux(testCase)
            %GATEHEADLESSLINUX Skip on Linux CI runners (xvfb / -batch).
            %   Same MATLAB dispatcher segfault as the other MEX-heavy
            %   gated classes — observed on R2021b at TestMinmaxDownsample.
            %   The minmax_core_mex kernel exercised here is also
            %   covered indirectly through every FastSense rendering
            %   test that downsamples. Interactive MATLAB / macOS /
            %   Windows CI run the full suite.
            if exist('OCTAVE_VERSION', 'builtin'); return; end
            isHeadlessLinux = ~ispc && ~ismac && ~usejava('desktop');
            testCase.assumeFalse(isHeadlessLinux, ...
                'TestMinmaxDownsample segfaults MATLAB headless on Linux — covered indirectly by FastSense render tests');
        end

        function addPaths(testCase)
            addpath(fullfile(fileparts(mfilename('fullpath')), '..', '..'));
            install();
            add_fastsense_private_path();
        end
    end

    methods (Test)
        function testBasicReduction(testCase)
            x = 1:100;
            y = sin(linspace(0, 4*pi, 100));
            [xOut, yOut] = minmax_downsample(x, y, 10);
            % Tail-anchor (260512-c5x): downsampler may emit one extra
            % point (segX(end), segY(end)) — accept 2*nb or 2*nb+1.
            testCase.verifyTrue(ismember(numel(xOut), [20, 21]), ...
                sprintf('testBasicReduction xOut: expected 20 or 21 (tail anchor), got %d', numel(xOut)));
            testCase.verifyTrue(ismember(numel(yOut), [20, 21]), ...
                sprintf('testBasicReduction yOut: expected 20 or 21, got %d', numel(yOut)));
        end

        function testPreservesExtremes(testCase)
            x = 1:1000;
            y = zeros(1, 1000);
            y(500) = 100;
            y(700) = -50;
            [~, yOut] = minmax_downsample(x, y, 50);
            testCase.verifyTrue(any(yOut == 100), 'Must preserve spike');
            testCase.verifyTrue(any(yOut == -50), 'Must preserve valley');
        end

        function testNaNGaps(testCase)
            x = 1:20;
            y = [1:8, NaN, NaN, 11:20];
            [xOut, yOut] = minmax_downsample(x, y, 5);
            testCase.verifyTrue(any(isnan(yOut)), 'Must preserve NaN gaps');
            nonNaN = yOut(~isnan(yOut));
            testCase.verifyNotEmpty(nonNaN, 'Must have non-NaN values');
        end

        function testFewPointsPassthrough(testCase)
            x = 1:5;
            y = [10 20 30 40 50];
            [xOut, yOut] = minmax_downsample(x, y, 10);
            testCase.verifyEqual(xOut, x, 'testFewPointsPassthrough xOut');
            testCase.verifyEqual(yOut, y, 'testFewPointsPassthrough yOut');
        end

        function testOutputIsMonotonicX(testCase)
            x = linspace(0, 10, 10000);
            y = randn(1, 10000);
            [xOut, ~] = minmax_downsample(x, y, 100);
            nanIdx = find(isnan(xOut));
            starts = [1, nanIdx + 1];
            ends = [nanIdx - 1, numel(xOut)];
            for i = 1:numel(starts)
                seg = xOut(starts(i):ends(i));
                seg = seg(~isnan(seg));
                if numel(seg) > 1
                    testCase.verifyTrue(all(diff(seg) >= 0), 'X within segment must be non-decreasing');
                end
            end
        end

        function testUnevenSpacing(testCase)
            x = [1 2 3 100 200 300 1000 2000 3000];
            y = [1 2 3 4   5   6   7    8    9];
            [xOut, yOut] = minmax_downsample(x, y, 3); %#ok<ASGLU>
            % Tail-anchor (260512-c5x): accept 2*nb or 2*nb+1.
            testCase.verifyTrue(ismember(numel(xOut), [6, 7]), ...
                sprintf('testUnevenSpacing: expected 6 or 7 (tail anchor), got %d', numel(xOut)));
        end

        function testAllNaN(testCase)
            x = 1:10;
            y = NaN(1, 10);
            [xOut, yOut] = minmax_downsample(x, y, 3);
            testCase.verifyTrue(all(isnan(yOut)), 'testAllNaN: expected all NaN');
        end

        function testLargeData(testCase)
            n = 1e6;
            x = 1:n;
            y = randn(1, n);
            tic;
            [xOut, yOut] = minmax_downsample(x, y, 1000); %#ok<ASGLU>
            elapsed = toc;
            % Tail-anchor (260512-c5x): accept 2*nb or 2*nb+1.
            testCase.verifyTrue(ismember(numel(xOut), [2000, 2001]), ...
                sprintf('testLargeData: expected 2000 or 2001 (tail anchor), got %d', numel(xOut)));
            testCase.verifyLessThan(elapsed, 1.0, sprintf('testLargeData: took %.3f s, must be < 1s', elapsed));
        end
    end
end
