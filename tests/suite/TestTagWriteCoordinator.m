classdef TestTagWriteCoordinator < matlab.unittest.TestCase
%TESTTAGWRITECOORDINATOR Unit tests for Phase 1030 Plan 01 TagWriteCoordinator facade.
%
%   Covers:
%     - Constructor validation (sharedRoot type)
%     - acquireTag validation (tagKey type)
%     - LocksDir derivation (SharedPaths.locksDir(sharedRoot))
%     - Single-coordinator-multi-key parallel acquire
%     - Two-coordinator same-key contention (ok=false path)
%     - Different-key non-contention
%
%   Platform: all unit tests run in-process and use a temp directory as
%   sharedRoot — no real SMB share required.

    properties
        tempRoot_       % char; per-test fresh tempdir
    end

    methods (TestClassSetup)
        function addPaths(testCase) %#ok<MANU>
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
            addpath(root);
            addpath(fullfile(root, 'libs', 'Concurrency'));
            install();
        end
    end

    methods (TestMethodSetup)
        function resetCachesAndTempdir(testCase)
            try, ClusterIdentity.clearCache(); catch, end %#ok<TRYNC>
            try, FileLock.clearCache(); catch, end %#ok<TRYNC>
            testCase.tempRoot_ = tempname();
            mkdir(testCase.tempRoot_);
        end
    end

    methods (TestMethodTeardown)
        function cleanupTempdir(testCase)
            if isfolder(testCase.tempRoot_)
                try, rmdir(testCase.tempRoot_, 's'); catch, end %#ok<TRYNC>
            end
        end
    end

    methods (Test)

        function testConstructorRejectsEmptySharedRoot(testCase)
            testCase.verifyError(@() TagWriteCoordinator(''), ...
                'TagWriteCoordinator:invalidSharedRoot');
        end

        function testConstructorRejectsNonCharSharedRoot(testCase)
            testCase.verifyError(@() TagWriteCoordinator(42), ...
                'TagWriteCoordinator:invalidSharedRoot');
        end

        function testAcquireTagRejectsEmptyKey(testCase)
            coord = TagWriteCoordinator(testCase.tempRoot_);
            testCase.verifyError(@() coord.acquireTag(''), ...
                'TagWriteCoordinator:invalidTagKey');
        end

        function testAcquireTagReturnsFileLockAndLocksDirIsDerived(testCase)
            coord = TagWriteCoordinator(testCase.tempRoot_);
            [lock, ok] = coord.acquireTag('alpha');
            cleaner = onCleanup(@() lock.release()); %#ok<NASGU>

            testCase.verifyTrue(ok, 'acquireTag should succeed on empty share');
            testCase.verifyTrue(lock.isHeld(), 'lock should report held after acquire');
            expectedDir = SharedPaths.locksDir(testCase.tempRoot_);
            testCase.verifySubstring(lock.lockPath(), expectedDir);
            testCase.verifySubstring(lock.lockPath(), 'alpha.lock');
        end

        function testTwoCoordinatorsContendOnSameTagKey(testCase)
            coord1 = TagWriteCoordinator(testCase.tempRoot_);
            coord2 = TagWriteCoordinator(testCase.tempRoot_);

            [lock1, ok1] = coord1.acquireTag('shared_key');
            testCase.verifyTrue(ok1, 'coord1 should acquire successfully');

            % coord2 contends — same process so nested-acquire guard fires,
            % but FileLock's persistent registry is shared per-process and
            % keyed by absolute lockPath. Therefore coord2's tryAcquire
            % should throw Concurrency:nestedLockAcquireForbidden because
            % BOTH coordinators in the same MATLAB process target the
            % same lockPath. We test this contract: same-process double
            % acquire on the same key is structurally forbidden.
            testCase.verifyError(@() coord2.acquireTag('shared_key'), ...
                'Concurrency:nestedLockAcquireForbidden');

            lock1.release();

            % After release, coord2 should be able to acquire.
            [lock2, ok2] = coord2.acquireTag('shared_key');
            cleaner = onCleanup(@() lock2.release()); %#ok<NASGU>
            testCase.verifyTrue(ok2, 'coord2 should acquire after coord1 released');
        end

        function testDifferentTagKeysDoNotContend(testCase)
            coord = TagWriteCoordinator(testCase.tempRoot_);

            [lockA, okA] = coord.acquireTag('alpha');
            [lockB, okB] = coord.acquireTag('beta');
            cleaner = onCleanup(@() releaseBoth_(lockA, lockB)); %#ok<NASGU>

            testCase.verifyTrue(okA);
            testCase.verifyTrue(okB);
            testCase.verifyTrue(lockA.isHeld());
            testCase.verifyTrue(lockB.isHeld());
        end

    end

end

function releaseBoth_(lockA, lockB)
    try, lockA.release(); catch, end %#ok<TRYNC>
    try, lockB.release(); catch, end %#ok<TRYNC>
end
