classdef TestLockfileMex < matlab.unittest.TestCase
%TESTLOCKFILEMEX Unit tests for lockfile_mex MEX — platform-branch detection,
%   acquire/release round-trip, self-deadlock prevention (Unknown 3).
%
%   Requires lockfile_mex to be compiled by build_concurrency_mex() first.
%   All lockfiles are created under a temporary directory so the tests do
%   not depend on a shared filesystem or specific working directory.
%
%   Test methods:
%     testProbeReportsBranch        — probe returns valid branch tag + int64 pid
%     testAcquireReleaseRoundTrip   — acquire returns int64 > 0; release returns true
%     testSelfReacquireReturnsNegative — second acquire of same path returns int64(-1)
%     testHandleIsInt64             — handle type is int64
%
%   See also build_concurrency_mex, lockfile_mex.

    properties
        TempDir
    end

    methods (TestClassSetup)
        function addPaths(testCase)
        %ADDPATHS Add all required library paths and build MEX if needed.
            here = fileparts(mfilename('fullpath'));
            root = fileparts(fileparts(here));
            addpath(root);
            install();
            addpath(fullfile(root, 'libs', 'Concurrency'));

            % Octave platform-tag subdirectory (Pitfall E)
            % On Octave, MEX goes to private/octave-<tag>/ so add that path.
            % On MATLAB, MEX goes to libs/Concurrency/ root (already added above).
            try
                if exist('OCTAVE_VERSION', 'builtin') == 5
                    arch = lower(computer('arch'));
                    if ~isempty(strfind(arch, 'darwin')) && ...
                       (~isempty(strfind(arch, 'aarch64')) || ~isempty(strfind(arch, 'arm64')))
                        octTag = 'macos-arm64';
                    elseif ~isempty(strfind(arch, 'darwin'))
                        octTag = 'macos-x86_64';
                    elseif ~isempty(strfind(arch, 'linux'))
                        octTag = 'linux-x86_64';
                    else
                        octTag = 'windows-x86_64';
                    end
                    addpath(fullfile(root, 'libs', 'Concurrency', 'private', ['octave-' octTag]));
                end
            catch
            end

            % Build MEX if not yet compiled
            if exist('lockfile_mex', 'file') ~= 3
                build_concurrency_mex();
            end

            testCase.TempDir = tempname();
            mkdir(testCase.TempDir);
        end
    end

    methods (TestClassTeardown)
        function cleanup(testCase)
        %CLEANUP Remove temporary directory created during setup.
            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testProbeReportsBranch(testCase)
        %TESTPROBEREPORTSBRANCH probe returns a valid branch tag and int64 pid.
            testCase.assumeEqual(exist('lockfile_mex', 'file'), 3, ...
                'lockfile_mex MEX not compiled — run build_concurrency_mex() first.');
            info = lockfile_mex('probe');
            testCase.verifyTrue(ismember(info.branch, {'ofd', 'fsetlk', 'lockfileex'}), ...
                sprintf('Unexpected branch tag: %s', info.branch));
            testCase.verifyTrue(isa(info.pid, 'int64'), ...
                'probe.pid must be int64');
            testCase.verifyGreaterThan(info.pid, int64(0), ...
                'probe.pid must be a positive PID');
        end

        function testAcquireReleaseRoundTrip(testCase)
        %TESTACQUIRERELEASEROUNDTRIP acquire returns int64 > 0; release returns true.
            testCase.assumeEqual(exist('lockfile_mex', 'file'), 3, ...
                'lockfile_mex MEX not compiled.');
            p = fullfile(testCase.TempDir, 'a.lock');
            h = lockfile_mex('acquire', p, 0.0);
            testCase.verifyTrue(isa(h, 'int64'), 'handle must be int64');
            testCase.verifyGreaterThan(h, int64(0), ...
                'acquire must return positive handle on success');
            ok = lockfile_mex('release', h);
            testCase.verifyTrue(ok, 'release must return true for a valid handle');
        end

        function testSelfReacquireReturnsNegative(testCase)
        %TESTSELFREACQUIRERETURSNEGATIVE second acquire of same path returns int64(-1).
        %   This validates the Unknown 3 self-deadlock prevention via static FD table.
            testCase.assumeEqual(exist('lockfile_mex', 'file'), 3, ...
                'lockfile_mex MEX not compiled.');
            p = fullfile(testCase.TempDir, 'b.lock');
            h1 = lockfile_mex('acquire', p, 0.0);
            testCase.verifyGreaterThan(h1, int64(0), ...
                'First acquire must succeed');
            % Self-deadlock prevention: second acquire of same path must fail
            h2 = lockfile_mex('acquire', p, 0.0);
            testCase.verifyEqual(h2, int64(-1), ...
                'Second acquire of same path must return int64(-1) (Unknown 3)');
            % Release the first handle
            lockfile_mex('release', h1);
            % Re-acquire must now succeed
            h3 = lockfile_mex('acquire', p, 0.0);
            testCase.verifyGreaterThan(h3, int64(0), ...
                'Re-acquire after release must succeed');
            lockfile_mex('release', h3);
        end

        function testHandleIsInt64(testCase)
        %TESTHANDLEISINT64 verifies that the acquire return type is int64.
            testCase.assumeEqual(exist('lockfile_mex', 'file'), 3, ...
                'lockfile_mex MEX not compiled.');
            p = fullfile(testCase.TempDir, 'c.lock');
            h = lockfile_mex('acquire', p, 0.0);
            testCase.verifyClass(h, 'int64');
            lockfile_mex('release', h);
        end
    end
end
