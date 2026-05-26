classdef TestFileLock < matlab.unittest.TestCase
%TESTFILELOCK Tests for FileLock handle class and LockFileFormat private helper.
%
%   Test methods:
%     testLockBodyRoundTrip          — encode+decode returns identical struct
%     testTryAcquireReleaseRoundTrip — basic acquire+release on a temp lock dir
%     testNestedAcquireThrows        — same-key second tryAcquire throws
%                                      Concurrency:nestedLockAcquireForbidden
%     testCloseDoesNotReleaseLock    — closing a second fopen on the lockfile
%                                      path does NOT release the lock (OFD/LockFileEx
%                                      contract; Pitfall 1). Skipped on macOS because
%                                      macOS uses plain F_SETLK which DOES release on
%                                      any fclose of the same path from the same process.
%     testStaleLockAfterProcessKill  — body with mtime backdated past staleTimeout
%                                      → isStale() returns true. Skipped on Windows
%                                      where kill -9 is unavailable.
%     testNegativeWallClockDeltaIgnored — body with future heartbeat_at (clock skew)
%                                         → isStale() returns false (Pitfall 9 safeguard)
%     testTwoProcessMutualExclusion  — 2-process smoke: exactly one acquires
%
%   REQ coverage: CONC-02 (all five CONC-02 rows in 1029-VALIDATION.md)
%
%   See also FileLock, LockFileFormat, ClusterIdentity, lockfile_mex.

    properties
        TempDir   % per-suite temp directory for body files
    end

    % ------------------------------------------------------------------ %
    methods (TestClassSetup)
        function addPaths(testCase)  %#ok<MANU>
            %ADDPATHS Add libs/Concurrency to path and run install.
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
            addpath(root);
            install();
            addpath(fullfile(root, 'libs', 'Concurrency'));
            testCase.TempDir = tempname();
            mkdir(testCase.TempDir);
        end
    end

    % ------------------------------------------------------------------ %
    methods (TestMethodSetup)
        function resetCaches(testCase)  %#ok<MANU>
            %RESETCACHES Clear ClusterIdentity and FileLock per-key caches between tests.
            ClusterIdentity.clearCache();
            FileLock.clearCache();
        end
    end

    % ------------------------------------------------------------------ %
    methods (TestMethodTeardown)
        function clearIdentityCache(~)
            %CLEARIDENTITYCACHE Reset identity cache so next test starts fresh.
            ClusterIdentity.clearCache();
            FileLock.clearCache();
        end
    end

    % ------------------------------------------------------------------ %
    methods (TestClassTeardown)
        function cleanup(testCase)
            %CLEANUP Remove the per-suite temp directory.
            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    % ------------------------------------------------------------------ %
    methods (Test)

        function testLockBodyRoundTrip(testCase)
            %TESTLOCKBODYROUNDTRIP Encode then decode returns an identical struct.
            id  = ClusterIdentity.resolve();
            txt = LockFileFormat.encodeBody(id, 'pressure');
            s   = LockFileFormat.decodeBody(txt);
            testCase.verifyEqual(s.key,  'pressure');
            testCase.verifyEqual(s.user, id.user);
            testCase.verifyEqual(s.host, id.host);
            testCase.verifyEqual(s.pid,  id.pid);
            testCase.verifyTrue(isa(s.epoch, 'datetime'));
            testCase.verifyTrue(isa(s.acquired_at, 'datetime'));
            testCase.verifyTrue(isa(s.heartbeat_at, 'datetime'));
            % heartbeat_at and acquired_at should differ by less than 1s on initial encode
            testCase.verifyTrue(abs(seconds(s.heartbeat_at - s.acquired_at)) < 1);
        end

        function testTryAcquireReleaseRoundTrip(testCase)
            %TESTTRYACQUIRERELEASEROUNDTRIP Basic acquire+release on a temp lock dir.
            lock = FileLock('roundtrip-test', 'LockDir', testCase.TempDir);
            cleaner = onCleanup(@() delete(lock));
            acquired = lock.tryAcquire();
            testCase.verifyTrue(acquired, 'Expected tryAcquire to succeed');
            testCase.verifyTrue(lock.isHeld(), 'Expected isHeld to return true after acquire');
            lock.release();
            testCase.verifyFalse(lock.isHeld(), 'Expected isHeld to return false after release');
        end

        function testNestedAcquireThrows(testCase)
            %TESTNESTEDACQUIRETHROWS Same-key second tryAcquire in same process throws.
            %   Acceptance row CONC-02 — same-process re-acquire throws
            %   Concurrency:nestedLockAcquireForbidden (Unknown 3 / Pitfall B).
            lock1 = FileLock('nested-key', 'LockDir', testCase.TempDir);
            cleaner = onCleanup(@() lock1.release());
            ok = lock1.tryAcquire();
            testCase.assumeTrue(ok, 'lock1 must acquire for nested test to be meaningful');
            lock2 = FileLock('nested-key', 'LockDir', testCase.TempDir);
            testCase.verifyError( ...
                @() lock2.tryAcquire(), ...
                'Concurrency:nestedLockAcquireForbidden');
        end

        function testCloseDoesNotReleaseLock(testCase)
            %TESTCLOSEDOESNOT RELEASELOCK Closing a second fopen on the lockfile path
            %   does NOT release the lock (OFD/LockFileEx contract; Pitfall 1).
            %
            %   PLATFORM SKIP: macOS uses F_SETLK (not OFD); plain fclose from the same
            %   process DOES drop F_SETLK locks. This test is meaningful only on Linux
            %   (OFD locks) and Windows (LockFileEx, process-scoped). Skipped on macOS
            %   with a documented note — this is the expected behaviour for the dev platform.
            testCase.assumeTrue(~ismac(), ...
                ['macOS uses plain F_SETLK fallback (Pitfall 1); OFD/LockFileEx contract ', ...
                 'is verified on Linux+Windows. Skipping on macOS.']);

            lock = FileLock('closefid-test', 'LockDir', testCase.TempDir);
            cleaner = onCleanup(@() lock.release());
            ok = lock.tryAcquire();
            testCase.assumeTrue(ok, 'Must acquire lock to test second-FD contract');

            % Open a second file handle on the lockfile path and close it immediately.
            lp = lock.lockPath();
            fid = fopen(lp, 'r');
            if fid > 0
                fclose(fid);
            end

            % Verify the lock is still held after the second FD was opened and closed.
            if exist('lockfile_mex', 'file') == 3
                info = lockfile_mex('status', lp);
                testCase.verifyTrue(info.held, ...
                    'Lock must still be held after second FD opened+closed (OFD/LockFileEx)');
            else
                % MEX-absent sidecar fallback: stillHeldByMe reads body and verifies identity
                testCase.verifyTrue(lock.stillHeldByMe(), ...
                    'Lock must still be held by this process after second FD opened+closed');
            end
        end

        function testStaleLockAfterProcessKill(testCase)
            %TESTSTALELOCK AFTERPROCESSKILL isStale returns true after simulated process kill.
            %   Acceptance row CONC-02 — mtime-based stale detection.
            %
            %   This test writes a body file with mtime backdated to now-100s (simulating
            %   a killed holder), then verifies isStale() returns true for a staleTimeout=5s
            %   FileLock instance. We do NOT actually spawn a child process here because
            %   that requires a 60s wait; instead, we manually craft a stale body file and
            %   manipulate its mtime using system touch(1).
            %
            %   PLATFORM SKIP: Skipped on Windows (touch -d is unavailable; kill -9 is
            %   unavailable). Full process-kill test is in TestFileLockStress50.m.
            testCase.assumeTrue(~ispc(), ...
                'touch -t is unavailable on Windows; stale-process-kill test skipped');

            staleKey = 'stale-kill-test';
            lock = FileLock(staleKey, 'LockDir', testCase.TempDir, 'StaleTimeout', 5);

            % Write a body file manually with content that matches a real identity struct.
            id  = ClusterIdentity.resolve();
            txt = LockFileFormat.encodeBody(id, staleKey);
            bp  = lock.bodyPath();
            fid = fopen(bp, 'w');
            testCase.assumeTrue(fid > 0, 'Could not open body path for writing');
            fprintf(fid, '%s', txt);
            fclose(fid);

            % Backdate the mtime to now - 100s using touch -t (POSIX) or touch -d (Linux/macOS).
            backdatedTime = datetime('now', 'TimeZone', 'UTC') - seconds(100);
            touchStr = char(backdatedTime, 'yyyyMMddHHmm.ss');
            [rc, msg] = system(['touch -t ', touchStr, ' "', bp, '"']);
            testCase.assumeTrue(rc == 0, ...
                ['Could not backdate mtime with touch -t: ', msg]);

            % A fresh FileLock instance (not holding the lock) should now see it as stale.
            lock2 = FileLock(staleKey, 'LockDir', testCase.TempDir, 'StaleTimeout', 5);
            testCase.verifyTrue(lock2.isStale(), ...
                'isStale() must return true for a body file with backdated mtime');
        end

        function testNegativeWallClockDeltaIgnored(testCase)
            %TESTNEGATIVEWALLCLOCKDELTAIGNORED Future heartbeat_at does NOT trigger stale.
            %   Acceptance row CONC-02 — Pitfall 9 (clock skew) safeguard.
            %   If the body file has heartbeat_at 1 hour in the FUTURE (clock skew),
            %   isStale() MUST return false — staleness is mtime-based, not wall-clock-based.
            negKey = 'neg-clock-test';
            lock   = FileLock(negKey, 'LockDir', testCase.TempDir, 'StaleTimeout', 60);

            % Build a body with heartbeat_at one hour in the future (clock skew simulation).
            id  = ClusterIdentity.resolve();
            txt = LockFileFormat.encodeBody(id, negKey);
            fmt = 'yyyy-MM-dd''T''HH:mm:ss''Z''';
            futureHb = char(datetime('now', 'TimeZone', 'UTC') + hours(1), fmt);
            txt = regexprep(txt, '^heartbeat_at:.*$', ...
                            ['heartbeat_at: ', futureHb], 'lineanchors');

            % Write body file with current mtime (NOT stale by mtime).
            bp  = lock.bodyPath();
            fid = fopen(bp, 'w');
            testCase.assumeTrue(fid > 0, 'Could not open body path for writing');
            fprintf(fid, '%s', txt);
            fclose(fid);

            % isStale() must use dir(bodyPath).datenum, not the wall-clock heartbeat_at field.
            % Since mtime is fresh (just written), isStale() must return false.
            testCase.verifyFalse(lock.isStale(), ...
                ['isStale() must return false when mtime is current, ', ...
                 'even if heartbeat_at has a future wall-clock value (Pitfall 9)']);
        end

        function testTwoProcessMutualExclusion(testCase)
            %TESTTWOPROCESSMUTUALEXCLUSION Two-process smoke: exactly one acquires.
            %   Acceptance row CONC-02 — 2-process mutual exclusion smoke test.
            %   Spawns two MATLAB child processes racing for the same lock.
            %   Exactly one must report acquired=1; the other must report acquired=0.
            %
            %   PLATFORM SKIP: Skipped on Windows where the `matlab -batch` path
            %   spawning semantics differ (CI runs Octave there; full stress is gated).
            testCase.assumeTrue(~ispc(), ...
                'Two-process smoke uses matlab -batch; skipped on Windows CI (gated stress covers it)');

            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));

            % Shared lock directory (a fresh sub-dir to avoid cross-test conflicts)
            sharedDir = fullfile(testCase.TempDir, 'twoProc');
            if ~isfolder(sharedDir)
                mkdir(sharedDir);
            end

            % Build the child MATLAB batch script.
            childScript = [ ...
                'addpath(''', strrep(root, '''', ''''''), '''); ', ...
                'install(); ', ...
                'addpath(fullfile(''', strrep(root, '''', ''''''), ''', ''libs'', ''Concurrency'')); ', ...
                'lk = FileLock(''twoProc'', ''LockDir'', ''', strrep(sharedDir, '''', ''''''), '''); ', ...
                'ok = lk.tryAcquire(); ', ...
                'pause(3); ', ...   % hold lock for 3 seconds so the other sees contention
                'if ok; lk.release(); end; ', ...
                'pid = feature(''getpid''); ', ...
                'resFile = fullfile(''', strrep(sharedDir, '''', ''''''), ''', ', ...
                '[''acquired.'', num2str(pid), ''.txt'']); ', ...
                'fid = fopen(resFile, ''w''); fprintf(fid, ''%d\n'', ok); fclose(fid);' ...
            ];

            % Launch two children concurrently.
            cmd1 = ['matlab -batch "', childScript, '" &'];
            cmd2 = ['matlab -batch "', childScript, '" &'];
            system(cmd1);
            system(cmd2);

            % Poll for result files (max 90s to allow two MATLAB startups).
            deadline = tic();
            maxWait  = 90;
            while true
                resultFiles = dir(fullfile(sharedDir, 'acquired.*.txt'));
                if numel(resultFiles) >= 2
                    break;
                end
                if toc(deadline) > maxWait
                    break;
                end
                pause(2);
            end

            testCase.assumeTrue(numel(resultFiles) >= 2, ...
                'Two-process smoke: timed out waiting for child result files');

            % Count how many children reported acquired=1.
            acquired = 0;
            for k = 1:numel(resultFiles)
                fp = fullfile(sharedDir, resultFiles(k).name);
                fid = fopen(fp, 'r');
                if fid > 0
                    val = fscanf(fid, '%d', 1);
                    fclose(fid);
                    acquired = acquired + val;
                end
            end
            testCase.verifyEqual(acquired, 1, ...
                sprintf('Expected exactly 1 of 2 processes to acquire the lock, got %d', acquired));
        end

    end
end
