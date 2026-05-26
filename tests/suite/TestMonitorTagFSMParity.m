classdef TestMonitorTagFSMParity < matlab.unittest.TestCase
    %TESTMONITORTAGFSMPARITY K2 monitor_fsm MEX-vs-fallback parity (Wave 0 scaffold).
    %   Asserts byte-exact parity between monitor_fsm_mex and monitor_fsm_
    %   over hysteresis + debounce + run-detection at 3 scales (10, 1000, 100000).
    %
    %   Wave 0: scaffold only — every method assumes mex/fallback availability,
    %   so the suite runs green when neither has been built yet (Wave 1 plan 03
    %   lands them). When both are present, this becomes a hard parity gate.
    %
    %   K2 signature (per phase 1028 RESEARCH §"K2 monitor_fsm_mex"):
    %     [bin, finalHystState, ongoingRunStart, startIdx, endIdx] = ...
    %         monitor_fsm_mex(px, rawOn, rawOff, initialState, minDuration, carryStartX)
    %
    %   Tolerance: bit-exact for the 0/1 bin, the integer index arrays, and
    %     the logical state. NaN handling via isequaln (RESEARCH §Acceptance).
    %
    %   See also: monitor_fsm_mex (Wave 1), monitor_fsm_, MonitorTag.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testFsmParityScale10(testCase)
            mexAvailable      = exist('monitor_fsm_mex', 'file') == 3;
            fallbackAvailable = exist('monitor_fsm_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'monitor_fsm_mex / monitor_fsm_ not yet built (Wave 1 plan 03 lands these).');
            assertParityAt_(testCase, 10);
        end

        function testFsmParityScale1k(testCase)
            mexAvailable      = exist('monitor_fsm_mex', 'file') == 3;
            fallbackAvailable = exist('monitor_fsm_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'monitor_fsm_mex / monitor_fsm_ not yet built (Wave 1 plan 03 lands these).');
            assertParityAt_(testCase, 1000);
        end

        function testFsmParityScale100k(testCase)
            mexAvailable      = exist('monitor_fsm_mex', 'file') == 3;
            fallbackAvailable = exist('monitor_fsm_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'monitor_fsm_mex / monitor_fsm_ not yet built (Wave 1 plan 03 lands these).');
            assertParityAt_(testCase, 100000);
        end
    end
end

function assertParityAt_(testCase, n)
    %ASSERTPARITYAT_ Random rawOn/rawOff/initialState; assert MEX vs fallback identical.
    rng(n);   % stable seed per scale
    px = linspace(0, 100, n);
    rawOn  = rand(1, n) > 0.7;
    rawOff = rand(1, n) > 0.5;
    initialState = false;
    minDuration = 0.1;
    carryStartX = nan;

    [binM, hystM, ongM, sIdxM, eIdxM] = monitor_fsm_mex( ...     %#ok<ASGLU>
        px, rawOn, rawOff, initialState, minDuration, carryStartX);
    [binF, hystF, ongF, sIdxF, eIdxF] = monitor_fsm_( ...        %#ok<ASGLU>
        px, rawOn, rawOff, initialState, minDuration, carryStartX);

    testCase.verifyTrue(isequaln(binM, binF),  'bin (0/1) must be bit-exact');
    testCase.verifyEqual(logical(hystM), logical(hystF), 'finalHystState must match');
    testCase.verifyTrue(isequaln(ongM, ongF), 'ongoingRunStart must match (NaN-aware)');
    testCase.verifyEqual(uint32(sIdxM), uint32(sIdxF), 'startIdx must be bit-exact');
    testCase.verifyEqual(uint32(eIdxM), uint32(eIdxF), 'endIdx must be bit-exact');
end
