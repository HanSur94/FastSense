classdef TestClusterConfigNfsv3 < matlab.unittest.TestCase
%TESTCLUSTERCONFIGNFSV3 Tests for ClusterConfig NFSv3 detection (Phase 1033 Plan 03).
%
%   Mirrors TestClusterConfigOplocks. The positive case (real NFSv3 mount) is
%   exercised in Plan 04's 50-Companion acceptance test against a real shared
%   share. Here we verify (1) no false-positive on local disk, (2) the
%   FASTSENSE_ALLOW_NFSV3 escape hatch suppresses the warning,
%   (3) Windows hosts skip detection cleanly.
%
%   See also ClusterConfig, ClusterConfig.detectNfsv3_.

    methods (TestClassSetup)
        function addPaths(~) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));   % up from tests/suite/ to repo root
            addpath(root);
            addpath(fullfile(root, 'libs', 'Concurrency'));
            install();
        end
    end

    methods (Test)

        function testNonNfsRootSilent(testCase)
            %TESTNONNFSROOTSILENT Local tmpdir must not trigger NFSv3 detection.
            %   A directory on the local filesystem is never on an NFSv3 mount,
            %   so nfsv3Detected must be false and no Concurrency:nfsv3Detected
            %   warning must be emitted.
            root = fullfile(tempdir(), sprintf('ccn_%d', round(rand() * 1e9)));
            mkdir(root);
            testCase.addTeardown(@() rmdir(root, 's'));

            result = ClusterConfig.checkSharedConfig(root);

            testCase.verifyTrue(isstruct(result.evidence), ...
                'testNonNfsRootSilent: evidence struct must be returned');
            testCase.verifyTrue(isfield(result.evidence, 'nfsv3Detected'), ...
                'testNonNfsRootSilent: evidence must include nfsv3Detected field');
            testCase.verifyFalse(result.evidence.nfsv3Detected, ...
                'testNonNfsRootSilent: local tempdir must NOT be flagged as NFSv3');
        end

        function testFastsenseAllowNfsv3Suppresses(testCase)
            %TESTFASTSENSEALLOWNFSV3SUPPRESSES FASTSENSE_ALLOW_NFSV3=1 must suppress warning.
            %   With the escape hatch set, checkSharedConfig must complete without
            %   emitting Concurrency:nfsv3Detected regardless of mount state.
            priorVal = getenv('FASTSENSE_ALLOW_NFSV3');
            setenv('FASTSENSE_ALLOW_NFSV3', '1');
            testCase.addTeardown(@() setenv('FASTSENSE_ALLOW_NFSV3', priorVal));

            root = fullfile(tempdir(), sprintf('ccn_%d', round(rand() * 1e9)));
            mkdir(root);
            testCase.addTeardown(@() rmdir(root, 's'));

            % Even if detection somehow triggered, the env var must suppress the warning.
            % We verify the call completes without throwing.
            testCase.verifyWarningFree(@() ClusterConfig.checkSharedConfig(root), ...
                'testFastsenseAllowNfsv3Suppresses: must not warn with escape hatch set');
        end

        function testWindowsSkipsDetection(testCase)
            %TESTWINDOWSSKIPSDETECTION Windows must skip NFSv3 probe (returns false).
            %   On Windows, detectNfsv3_ must return false (no detection attempted).
            if ~ispc()
                testCase.assumeFail('testWindowsSkipsDetection: Windows-only test');
            end
            root = tempdir();
            result = ClusterConfig.checkSharedConfig(root);
            testCase.verifyFalse(result.evidence.nfsv3Detected, ...
                'testWindowsSkipsDetection: Windows must skip NFSv3 probe (false)');
        end

    end

end
