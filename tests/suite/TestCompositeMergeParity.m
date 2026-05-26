classdef TestCompositeMergeParity < matlab.unittest.TestCase
    %TESTCOMPOSITEMERGEPARITY K3 composite_merge MEX-vs-fallback parity (Wave 0 scaffold).
    %   Asserts parity between composite_merge_mex and composite_merge_ for
    %   the k-way merge over N child time-series at 3 scales.
    %
    %   K3 signature (per phase 1028 RESEARCH §K3):
    %     [X_out, lastYMatrix, emitIdx] = composite_merge_mex(childX, childY, first_x)
    %
    %   Tolerance:
    %     - X_out: bit-exact (sort is stable; same input order in both)
    %     - lastYMatrix: eps(1) * 10 absolute, NaN-aware via isequaln
    %     - emitIdx: bit-exact uint32 indices
    %
    %   Wave 0: scaffold; assumeTrue gates skip until Wave 1 plan 04 lands.
    %
    %   See also: composite_merge_mex (Wave 1), composite_merge_, CompositeTag.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testMergeParityScale100(testCase)
            mexAvailable      = exist('composite_merge_mex', 'file') == 3;
            fallbackAvailable = exist('composite_merge_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'composite_merge_mex / composite_merge_ not yet built (Wave 1 plan 04 lands these).');
            assertMergeParityAt_(testCase, 8, 100);
        end

        function testMergeParityScale1k(testCase)
            mexAvailable      = exist('composite_merge_mex', 'file') == 3;
            fallbackAvailable = exist('composite_merge_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'composite_merge_mex / composite_merge_ not yet built (Wave 1 plan 04 lands these).');
            assertMergeParityAt_(testCase, 8, 1000);
        end

        function testMergeParityScale100k(testCase)
            mexAvailable      = exist('composite_merge_mex', 'file') == 3;
            fallbackAvailable = exist('composite_merge_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'composite_merge_mex / composite_merge_ not yet built (Wave 1 plan 04 lands these).');
            assertMergeParityAt_(testCase, 8, 100000);
        end
    end
end

function assertMergeParityAt_(testCase, nChildren, nPerChild)
    %ASSERTMERGEPARITYAT_ Build random sorted childX/childY; assert parity.
    rng(nChildren * 100000 + nPerChild);
    childX = cell(1, nChildren);
    childY = cell(1, nChildren);
    for c = 1:nChildren
        x = sort(rand(1, nPerChild) * 100 + (c - 1) * 10);
        childX{c} = x;
        childY{c} = sin(x) + 0.05 * randn(1, nPerChild);
    end
    first_x = -inf;

    [XmM, lastYM, emitIdxM] = composite_merge_mex(childX, childY, first_x);
    [XmF, lastYF, emitIdxF] = composite_merge_(childX, childY, first_x);

    testCase.verifyEqual(XmM, XmF, 'X_out must be exact (single sort)');
    testCase.verifyTrue( ...
        isequaln(lastYM, lastYF) || ...
        all(abs(lastYM(~isnan(lastYM) & ~isnan(lastYF)) - ...
                lastYF(~isnan(lastYM) & ~isnan(lastYF))) <= eps(1) * 10), ...
        'lastYMatrix must match within eps(1)*10 (NaN-aware)');
    testCase.verifyEqual(uint32(emitIdxM), uint32(emitIdxF), 'emitIdx parity');
end
