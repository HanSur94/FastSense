classdef TestConcurrencyIntegration < matlab.unittest.TestCase
%TESTCONCURRENCYINTEGRATION End-to-end composition smoke for Phase 1029 Plans 01-04.
%
%   This test does NOT replace the per-primitive unit tests (TestFileLock,
%   TestAtomicWriter, TestClusterIdentity, TestClusterConfig, TestLockfileMex).
%   It asserts that the five primitives (ClusterIdentity, ClusterConfig,
%   SharedPaths, FileLock, AtomicWriter) compose correctly in a realistic
%   happy-path flow — proving Phase 1029 Foundation is ready for Phase 1030.
%
%   Test methods:
%     testFiveClassesAllOnPath         — all 8 Plan 01-04 symbols discoverable via which()
%     testLockfileMexBranchMatchesHost — lockfile_mex('probe').branch matches host platform
%     testHappyPathInProcess           — single-process composition: acquire + write + verify
%     testRoadmapSuccessCriteriaTraceability — meta-test: every VALIDATION.md test method exists
%
%   Note on testHappyPathInProcess: This is a single-process composition smoke.
%   Multi-process mutual exclusion scenarios are covered by
%   TestFileLock.testTwoProcessMutualExclusion and the gated
%   TestFileLockStress50.testFiftyProcessAcquireRelease.
%
%   See also TestFileLock, TestAtomicWriter, TestClusterIdentity, TestClusterConfig.

    properties
        TempRoot   % per-class temp directory
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            %ADDPATHS Add project root to MATLAB path and run install().
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
            addpath(root);
            install();
            testCase.TempRoot = tempname();
            mkdir(testCase.TempRoot);
        end
    end

    methods (TestClassTeardown)
        function cleanup(testCase)
            %CLEANUP Remove temp directory created for the test class.
            if isfolder(testCase.TempRoot)
                rmdir(testCase.TempRoot, 's');
            end
        end
    end

    methods (Test)

        function testFiveClassesAllOnPath(testCase)
            %TESTFIVECLASSESALLONPATH Assert all 8 Phase 1029 symbols are discoverable.
            %   Verifies that install() exposes ClusterIdentity, ClusterConfig,
            %   SharedPaths, FileLock, AtomicWriter, lockfile_mex, ndjsonEncode,
            %   and LockFileFormat on the MATLAB path.
            names = {'ClusterIdentity', 'ClusterConfig', 'SharedPaths', ...
                     'FileLock', 'AtomicWriter', 'lockfile_mex', ...
                     'ndjsonEncode', 'LockFileFormat'};
            for k = 1:numel(names)
                p = which(names{k});
                testCase.verifyNotEmpty(p, ...
                    sprintf('%s not on MATLAB path after install()', names{k}));
            end
        end

        function testLockfileMexBranchMatchesHost(testCase)
            %TESTLOCKFILEMEXBRANCHMATCHESHOST Verify lockfile_mex compiled for the host platform.
            %   On Linux: branch must be 'ofd' (kernel 3.15+); 'fsetlk' is a hard failure
            %             — rebuild with -D_GNU_SOURCE (Pitfall A in 1029-RESEARCH.md).
            %   On macOS: branch must be 'fsetlk' (no OFD locks on macOS).
            %   On Windows: branch must be 'lockfileex'.
            info = lockfile_mex('probe');
            testCase.verifyTrue(ismember(info.branch, {'ofd', 'lockfileex', 'fsetlk'}), ...
                sprintf('Unexpected lockfile_mex branch: %s', info.branch));
            if ispc
                testCase.verifyEqual(info.branch, 'lockfileex', ...
                    'Windows must compile lockfile_mex with the LockFileEx branch');
            elseif ismac
                testCase.verifyEqual(info.branch, 'fsetlk', ...
                    'macOS uses F_SETLK fallback (no OFD locks; dev-only per CONTEXT.md)');
            else
                % Linux: OFD is mandatory for production (PITFALLS.md Pitfall 1).
                % 'fsetlk' on Linux means -D_GNU_SOURCE was missing at compile time.
                testCase.verifyEqual(info.branch, 'ofd', ...
                    sprintf(['Linux build did NOT enable OFD locks (got branch=%s). ' ...
                             'Pitfall A: rebuild with -D_GNU_SOURCE (see 1029-RESEARCH.md).'], ...
                             info.branch));
            end
        end

        function testHappyPathInProcess(testCase)
            %TESTHAPPYPATHINPROCESS Single-process composition smoke: acquire + write + verify.
            %   Proves all five primitives (ClusterIdentity, ClusterConfig, SharedPaths,
            %   FileLock, AtomicWriter) compose correctly in a realistic happy-path scenario.
            %   Multi-process scenarios are covered by TestFileLock.testTwoProcessMutualExclusion
            %   and the gated TestFileLockStress50.testFiftyProcessAcquireRelease.

            tmpRoot = testCase.TempRoot;
            locksDir = fullfile(tmpRoot, 'locks');
            tagsDir  = fullfile(tmpRoot, 'tags');
            mkdir(locksDir);
            mkdir(tagsDir);

            % Acquire a per-key advisory lock
            lock = FileLock('happy-path', 'LockDir', locksDir);
            lockCleaner = onCleanup(@() lock.release()); %#ok<NASGU>

            [ok, reason] = lock.tryAcquire();
            testCase.verifyTrue(ok, ...
                sprintf('tryAcquire should succeed on a fresh lock; got: %s', reason));
            testCase.verifyTrue(lock.isHeld(), ...
                'isHeld() must return true after successful tryAcquire()');
            testCase.verifyTrue(lock.stillHeldByMe(), ...
                'stillHeldByMe() must confirm lock is held by this process identity');

            % Resolve cluster identity
            id = ClusterIdentity.resolve();
            testCase.verifyNotEmpty(id.user, 'ClusterIdentity.user must be non-empty');
            testCase.verifyNotEmpty(id.host, 'ClusterIdentity.host must be non-empty');
            testCase.verifyClass(id.pid, 'int64', 'ClusterIdentity.pid must be int64');

            % Write a .mat via AtomicWriter, stamped with identity sidecar
            dataPath = fullfile(tagsDir, 'happy.mat');
            AtomicWriter.write(dataPath, @local_save_payload_, id, ...
                struct('StampIdentity', true, 'StillHeldByMe', @() lock.stillHeldByMe()));

            % Verify data file exists
            testCase.verifyTrue(isfile(dataPath), ...
                'AtomicWriter.write must produce the final data file');

            % Verify identity sidecar exists
            sidecarPath = [dataPath, '.identity.json'];
            testCase.verifyTrue(isfile(sidecarPath), ...
                'AtomicWriter.write with StampIdentity=true must produce .identity.json sidecar');

            % Verify sidecar contains correct identity fields
            meta = jsondecode(fileread(sidecarPath));
            testCase.verifyEqual(meta.user, id.user, ...
                'Sidecar .user must match ClusterIdentity.resolve().user');
            testCase.verifyEqual(meta.host, id.host, ...
                'Sidecar .host must match ClusterIdentity.resolve().host');

            % Release the lock and verify
            lock.release();
            testCase.verifyFalse(lock.isHeld(), ...
                'isHeld() must return false after release()');
        end

        function testRoadmapSuccessCriteriaTraceability(testCase)
            %TESTROADMAPSUCCESSCRITERIATRACEABILITY Meta-test: every VALIDATION.md method exists.
            %   Parses 1029-VALIDATION.md for test-method references
            %   (pattern: TestClass.testMethod and test_*.m function files)
            %   and verifies each is implemented in the tests/ directory.
            here = fileparts(mfilename('fullpath'));
            repoRoot = fileparts(fileparts(here));
            validationPath = fullfile(repoRoot, '.planning', 'phases', ...
                '1029-foundation', '1029-VALIDATION.md');

            testCase.assumeTrue(exist(validationPath, 'file') == 2, ...
                '1029-VALIDATION.md not found; skipping traceability meta-test');

            txt = fileread(validationPath);

            % Extract 'TestClass.testMethod' tokens from backtick spans
            classMethods = regexp(txt, 'Test[A-Z][A-Za-z]+\.test[A-Z][A-Za-z]+', 'match');
            classMethods = unique(classMethods);

            % Extract 'test_*.m' function-test file tokens
            fileTokens = regexp(txt, 'test_[a-z_]+\.m', 'match');
            fileTokens = unique(fileTokens);

            missing = {};

            for k = 1:numel(classMethods)
                parts      = strsplit(classMethods{k}, '.');
                className  = parts{1};
                methodName = parts{2};
                classFile  = fullfile(repoRoot, 'tests', 'suite', [className '.m']);
                if exist(classFile, 'file') ~= 2
                    missing{end+1} = sprintf('class file missing: %s', classFile); %#ok<AGROW>
                    continue;
                end
                classText = fileread(classFile);
                pat = ['function\s+' methodName '\s*\('];
                if isempty(regexp(classText, pat, 'once'))
                    missing{end+1} = sprintf('%s.%s not implemented in %s', ...
                        className, methodName, classFile); %#ok<AGROW>
                end
            end

            for k = 1:numel(fileTokens)
                candidates = {
                    fullfile(repoRoot, 'tests', fileTokens{k})
                    fullfile(repoRoot, 'tests', 'suite', fileTokens{k})
                };
                found = any(cellfun(@(p) exist(p, 'file') == 2, candidates));
                if ~found
                    missing{end+1} = sprintf('function-test file missing: %s', fileTokens{k}); %#ok<AGROW>
                end
            end

            if ~isempty(missing)
                fprintf(2, 'TRACEABILITY GAP:\n');
                for k = 1:numel(missing)
                    fprintf(2, '  %s\n', missing{k});
                end
            end
            testCase.verifyEmpty(missing, ...
                'Some test methods named in 1029-VALIDATION.md are missing from tests/');
        end

    end

end

% ---------------------------------------------------------------------------
function local_save_payload_(p)
%LOCAL_SAVE_PAYLOAD_ Minimal MAT payload writer for happy-path test.
    x = magic(3); %#ok<NASGU>
    save(p, 'x');
end
