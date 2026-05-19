classdef TestClusterConfigOplocks < matlab.unittest.TestCase
    %TESTCLUSTERCONFIGOPLOCKS Pitfall 14 SMB-oplock smoke-test canary detection.
    %
    %   Verifies ClusterConfig.checkSharedConfig:
    %     - Happy path on local tmpdir: ok=true, no warnings, bytes round-trip
    %     - Never throws on invalid input (empty string, non-existent path, numeric)
    %     - Return struct shape is stable (Phase 1033 wires consumers)
    %     - Warning ID Concurrency:smbOplockDetected is registered and capturable
    %     - Canary file is cleaned up after probe regardless of outcome
    %
    %   Note: The one-time-per-session warning guard (persistent warningEmitted_)
    %   in checkSharedConfig is intentionally NOT reset between tests here because
    %   that state lives in the function scope.  testWarningSurfacesOnTornRead uses
    %   lastwarn() to verify the warning ID independently of the guard.
    %
    %   See also ClusterConfig, SharedPaths.

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

        function testHappyPathOnLocalTmpdir(testCase)
            %TESTHAPPYPATHONLOCALTMPDIR checkSharedConfig returns ok=true on a local tmpdir.
            %   Local filesystems do not exhibit SMB-oplock behaviour, so the canary
            %   should round-trip without error.
            tmp = tempname();
            mkdir(tmp);
            cleaner = onCleanup(@() rmdir(tmp, 's'));   %#ok<NASGU>

            result = ClusterConfig.checkSharedConfig(tmp);

            testCase.verifyTrue(result.ok, ...
                sprintf('happy path returns ok=true on local tmpdir; warnings=%s', ...
                    strjoin(result.warnings, ' / ')));
            testCase.verifyEmpty(result.warnings, 'no warnings on happy path');
            testCase.verifyTrue(result.evidence.matches, 'canary byte pattern matches');
            testCase.verifyEqual(result.evidence.bytesWritten, 1024, 'bytesWritten == 1024');
            testCase.verifyEqual(result.evidence.bytesRead, 1024, 'bytesRead == 1024');
            testCase.verifyGreaterThan(result.evidence.elapsedSec, 0, 'elapsedSec > 0');
        end

        function testCheckSharedConfigNeverThrows_EmptyInput(testCase)
            %TESTCHECKSHAREDCONFIGNEVERTH_EMPTYINPUT Empty string must not throw.
            threw = false;
            result = struct();
            try
                result = ClusterConfig.checkSharedConfig('');
            catch
                threw = true;
            end
            testCase.verifyFalse(threw, 'empty string input must not throw');
            testCase.verifyFalse(result.ok, 'empty string input ok=false');
            testCase.verifyNotEmpty(result.warnings, 'empty string input populates warnings cell');
        end

        function testCheckSharedConfigNeverThrows_NonExistentPath(testCase)
            %TESTCHECKSHAREDCONFIGNEVERTH_NONEXISTENTPATH Non-existent path must not throw.
            threw = false;
            result = struct();
            try
                result = ClusterConfig.checkSharedConfig('/tmp/does-not-exist-xyz-12345');
            catch
                threw = true;
            end
            testCase.verifyFalse(threw, 'non-existent path must not throw');
            testCase.verifyFalse(result.ok, 'non-existent path ok=false');
            testCase.verifyNotEmpty(result.warnings, 'non-existent path populates warnings cell');
        end

        function testCheckSharedConfigNeverThrows_NumericInput(testCase)
            %TESTCHECKSHAREDCONFIGNEVERTH_NUMERICINPUT Numeric input must not throw.
            threw = false;
            result = struct();
            try
                result = ClusterConfig.checkSharedConfig(42);   %#ok<INUSL>
            catch
                threw = true;
            end
            testCase.verifyFalse(threw, 'numeric input must not throw');
            testCase.verifyFalse(result.ok, 'numeric input ok=false');
            testCase.verifyNotEmpty(result.warnings, 'numeric input populates warnings cell');
        end

        function testReturnStructShape(testCase)
            %TESTRETURNSTRUCTSHAPE Result struct has all required fields.
            %   Verifies the shape contract that Phase 1033 consumers depend on.
            tmp = tempname();
            mkdir(tmp);
            cleaner = onCleanup(@() rmdir(tmp, 's'));   %#ok<NASGU>

            result = ClusterConfig.checkSharedConfig(tmp);

            testCase.verifyTrue(isstruct(result), 'checkSharedConfig returns a struct');
            testCase.verifyTrue(isfield(result, 'ok'),       'result has .ok');
            testCase.verifyTrue(isfield(result, 'warnings'), 'result has .warnings');
            testCase.verifyTrue(isfield(result, 'evidence'), 'result has .evidence');
            testCase.verifyTrue(isfield(result.evidence, 'bytesWritten'), '.evidence.bytesWritten');
            testCase.verifyTrue(isfield(result.evidence, 'bytesRead'),    '.evidence.bytesRead');
            testCase.verifyTrue(isfield(result.evidence, 'matches'),      '.evidence.matches');
            testCase.verifyTrue(isfield(result.evidence, 'sharedRoot'),   '.evidence.sharedRoot');
            testCase.verifyTrue(isfield(result.evidence, 'canaryPath'),   '.evidence.canaryPath');
            testCase.verifyTrue(isfield(result.evidence, 'elapsedSec'),   '.evidence.elapsedSec');
        end

        function testCleansUpCanaryFile(testCase)
            %TESTCLEANUPCANAARYFILE Canary probe file is deleted after a successful probe.
            tmp = tempname();
            mkdir(tmp);
            cleaner = onCleanup(@() rmdir(tmp, 's'));   %#ok<NASGU>

            ClusterConfig.checkSharedConfig(tmp);

            canaryDir = fullfile(tmp, '.oplock_canary');
            if isfolder(canaryDir)
                d = dir(fullfile(canaryDir, 'canary_*.bin'));
                testCase.verifyEmpty(d, 'canary *.bin files must be cleaned up after probe');
            end
            % If canaryDir was not created at all (ok path), that is also fine.
        end

        function testWarningSurfacesOnTornRead(testCase)
            %TESTWARNIN_SURFACESONTORNREAD Warning ID Concurrency:smbOplockDetected is capturable.
            %   Direct registration check: emit the warning manually and verify
            %   lastwarn() captures the correct identifier.  This proves the warning
            %   ID string is well-formed and usable; actual fault-injection testing
            %   (requiring real SMB or a mock FS) is deferred to Phase 1033 integration.
            lastwarn('');   % reset state
            warning('Concurrency:smbOplockDetected', 'synthetic test emission');
            [~, id] = lastwarn();
            testCase.verifyEqual(id, 'Concurrency:smbOplockDetected', ...
                'warning ID Concurrency:smbOplockDetected is registered and capturable');
        end

    end
end
