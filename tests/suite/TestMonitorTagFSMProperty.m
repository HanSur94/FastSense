classdef TestMonitorTagFSMProperty < matlab.unittest.TestCase
    %TESTMONITORTAGFSMPROPERTY Randomized property test for K2 monitor_fsm parity.
    %   Wave 0 scaffold (per phase 1028 plan 1028-01 Task 2). When MEX +
    %   fallback are absent (current state), the assumeTrue gate skips
    %   each test; the suite stays green. Wave 1 plan 03 lands the kernel
    %   and this suite immediately starts asserting parity over 100 random
    %   trials at 4 sizes.
    %
    %   See also: TestMonitorTagFSMParity (deterministic at 3 scales),
    %             monitor_fsm_mex (Wave 1).

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            repo = fileparts(fileparts(here));
            addpath(repo);
            install();
        end
    end

    methods (Test)
        function testFsmProperty(testCase)
            mexAvailable      = exist('monitor_fsm_mex', 'file') == 3;
            fallbackAvailable = exist('monitor_fsm_',     'file') == 2;
            testCase.assumeTrue(mexAvailable && fallbackAvailable, ...
                'monitor_fsm_mex / monitor_fsm_ not yet built (Wave 1 plan 03 lands these).');

            sizes = [50, 500, 5000, 50000];
            nTrials = 100;
            minDurations = [0, 0.05, 0.2];

            for s = 1:numel(sizes)
                n = sizes(s);
                for t = 1:nTrials
                    rng(s * 1000 + t);
                    px = linspace(0, 100, n);
                    rawOn  = rand(1, n) > 0.7;             % Bernoulli ~0.3
                    rawOff = rand(1, n) > 0.5;             % Bernoulli ~0.5
                    initialState = rand() > 0.5;
                    minDuration  = minDurations(mod(t - 1, numel(minDurations)) + 1);
                    carryStartX  = nan;

                    [binM, hystM, ongM, sIdxM, eIdxM] = monitor_fsm_mex( ...   %#ok<ASGLU>
                        px, rawOn, rawOff, initialState, minDuration, carryStartX);
                    [binF, hystF, ongF, sIdxF, eIdxF] = monitor_fsm_( ...      %#ok<ASGLU>
                        px, rawOn, rawOff, initialState, minDuration, carryStartX);

                    testCase.verifyTrue(isequaln(binM, binF), ...
                        sprintf('Trial %d at n=%d: bin parity', t, n));
                    testCase.verifyEqual(logical(hystM), logical(hystF));
                    testCase.verifyEqual(uint32(sIdxM), uint32(sIdxF));
                    testCase.verifyEqual(uint32(eIdxM), uint32(eIdxF));
                end
            end
        end
    end
end
