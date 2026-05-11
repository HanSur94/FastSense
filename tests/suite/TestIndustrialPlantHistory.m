classdef TestIndustrialPlantHistory < matlab.unittest.TestCase
    %TESTINDUSTRIALPLANTHISTORY Suite for the demo's 1-week seed step.
    %   Each test that depends on a live ctx uses TestMethodSetup /
    %   TestMethodTeardown to keep test isolation. The pure-helper tests
    %   (Tasks 1–3) need no ctx and run instantly.

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '..'));
            install();
            addpath(fullfile(here, '..', '..', 'demo', 'industrial_plant'));
        end
    end

    methods (Test)
        function testStateHistoryHasSevenReactorCycles(testCase)
            cfg     = plantConfig();
            tStart  = now() - 7;
            nDays   = 7;
            [~, ~, xMode, yMode] = buildStateHistory(cfg, tStart, nDays);
            testCase.assertEqual(numel(xMode), numel(yMode), ...
                'mode X/Y length mismatch');
            testCase.assertGreaterThan(numel(xMode), 0, 'mode history empty');

            % Count `running` -> `cooldown` transitions; one per day = 7.
            nTransitions = 0;
            for k = 2:numel(yMode)
                if strcmp(yMode{k-1}, 'running') && strcmp(yMode{k}, 'cooldown')
                    nTransitions = nTransitions + 1;
                end
            end
            testCase.assertEqual(nTransitions, 7, ...
                sprintf('expected 7 running->cooldown transitions, got %d', nTransitions));
        end

        function testStateHistoryHasSevenValveCycles(testCase)
            cfg     = plantConfig();
            tStart  = now() - 7;
            nDays   = 7;
            [xValve, yValve, ~, ~] = buildStateHistory(cfg, tStart, nDays);
            testCase.assertEqual(numel(xValve), numel(yValve), ...
                'valve X/Y length mismatch');
            testCase.assertGreaterThan(numel(xValve), 0, 'valve history empty');

            % Count `closing` -> `closed` transitions; one per day = 7.
            nClose = 0;
            for k = 2:numel(yValve)
                if strcmp(yValve{k-1}, 'closing') && strcmp(yValve{k}, 'closed')
                    nClose = nClose + 1;
                end
            end
            testCase.assertEqual(nClose, 7, ...
                sprintf('expected 7 closing->closed transitions, got %d', nClose));
        end
    end
end
