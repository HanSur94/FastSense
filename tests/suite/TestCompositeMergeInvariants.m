classdef TestCompositeMergeInvariants < matlab.unittest.TestCase
    %TESTCOMPOSITEMERGEINVARIANTS Output-size + sortedness invariants for K3 (Wave 0 scaffold).
    %   Asserts:
    %     - length(X_out) <= sum(numel per child) (no duplicate emission)
    %     - X_out is strictly monotonically sorted
    %     - Random-sample equality vs the .m fallback at 8x100k
    %
    %   Wave 0: scaffold (assumeTrue gate skips until Wave 1 plan 04 lands).
    %
    %   See also: TestCompositeMergeParity, composite_merge_mex (Wave 1).

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testInvariantsAt8x100k(testCase)
            mexAvailable      = exist('composite_merge_mex', 'file') == 3;
            fallbackAvailable = exist('composite_merge_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'composite_merge_mex / composite_merge_ not yet built (Wave 1 plan 04 lands these).');

            nChildren = 8;
            nPer = 100000;
            rng(42);
            childX = cell(1, nChildren);
            childY = cell(1, nChildren);
            for c = 1:nChildren
                x = sort(rand(1, nPer) * 100 + (c - 1) * 10);
                childX{c} = x;
                childY{c} = sin(x);
            end

            [XmM, lastYM, ~] = composite_merge_mex(childX, childY, -inf); %#ok<ASGLU>

            % Invariant 1: output size <= sum of child sizes.
            totalChild = nChildren * nPer;
            testCase.verifyLessThanOrEqual(numel(XmM), totalChild, ...
                'X_out must not exceed sum(numel per child)');

            % Invariant 2: X_out is strictly monotonically sorted (no duplicates).
            if numel(XmM) > 1
                testCase.verifyGreaterThan(min(diff(XmM)), 0, ...
                    'X_out must be strictly monotonically sorted');
            end

            % Invariant 3: random-sample parity vs the fallback.
            [XmF, lastYF, ~] = composite_merge_(childX, childY, -inf); %#ok<ASGLU>
            sampleIdx = sort(randperm(numel(XmM), min(1000, numel(XmM))));
            testCase.verifyEqual(XmM(sampleIdx), XmF(sampleIdx), ...
                'Sampled X_out must be bit-exact vs fallback');
        end
    end
end
