classdef TestAggregateMatrixParity < matlab.unittest.TestCase
    %TESTAGGREGATEMATRIXPARITY K4 aggregate_matrix MEX-vs-fallback parity (Wave 0 scaffold).
    %   Tests all 6 structural modes (and, or, majority, count, worst, severity)
    %   at 3 scales (10, 1000, 100000 rows) with 3 or 8 children.
    %
    %   K4 signature (per phase 1028 RESEARCH §K4):
    %     out = aggregate_matrix_mex(M, weights, modeUint8, threshold)
    %     where modeUint8 maps 0=and 1=or 2=majority 3=count 4=worst 5=severity.
    %
    %   Tolerance (per RESEARCH §"Acceptance Thresholds"):
    %     - and / or / majority / count: bit-exact (binary reductions)
    %     - worst / severity: eps(1) * 10 absolute (FP reduction order)
    %     - NaN handling: isequaln (not isequal)
    %
    %   Wave 0: scaffold (assumeTrue gate skips until Wave 1 plan 04 lands).
    %
    %   See also: aggregate_matrix_mex (Wave 1), aggregate_matrix_, CompositeTag.

    properties (TestParameter)
        mode  = {'and', 'or', 'majority', 'count', 'worst', 'severity'};
        scale = struct('s10', 10, 's1k', 1000, 's100k', 100000);
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testAggregateParity(testCase, mode, scale)
            mexAvailable      = exist('aggregate_matrix_mex', 'file') == 3;
            fallbackAvailable = exist('aggregate_matrix_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'aggregate_matrix_mex / aggregate_matrix_ not yet built (Wave 1 plan 04 lands these).');

            nRows = scale;
            N = 8;
            rng(nRows + double(mode(1)));

            % Build random matrix with NaN sprinkles.
            M = rand(nRows, N);
            nanMask = rand(nRows, N) < 0.05;
            M(nanMask) = nan;
            weights = rand(1, N);
            threshold = 0.5;

            modeUint8 = encodeModeUint8_(mode);

            outMex      = aggregate_matrix_mex(M, weights, modeUint8, threshold);
            outFallback = aggregate_matrix_(M, weights, mode, threshold);

            switch mode
                case {'worst', 'severity'}
                    % FP-reduction tolerance per RESEARCH §"Acceptance Thresholds".
                    testCase.verifyTrue( ...
                        isequaln(outMex, outFallback) || ...
                        max(abs(outMex(~isnan(outMex)) - outFallback(~isnan(outFallback)))) <= eps(1) * 10, ...
                        sprintf('%s @ n=%d: tolerance eps(1)*10 violated', mode, nRows));
                otherwise
                    % Binary reductions: bit-exact (NaN-aware).
                    testCase.verifyTrue(isequaln(outMex, outFallback), ...
                        sprintf('%s @ n=%d: must be bit-exact', mode, nRows));
            end
        end
    end
end

function u = encodeModeUint8_(mode)
    %ENCODEMODEUINT8_ Map mode name to K4 enum.
    switch mode
        case 'and',      u = uint8(0);
        case 'or',       u = uint8(1);
        case 'majority', u = uint8(2);
        case 'count',    u = uint8(3);
        case 'worst',    u = uint8(4);
        case 'severity', u = uint8(5);
        otherwise
            error('TestAggregateMatrixParity:badMode', 'Unknown mode %s', mode);
    end
end
