classdef TestMexPrebuilt < matlab.unittest.TestCase
    %TESTMEXPREBUILT Regression tests for MEX stamp-check logic (Phase 1013 Plan 01).
    %
    % Covers:
    %   testStampIsStable                   -- mex_stamp() is deterministic
    %   testStampChangesWhenSourceTouched   -- content change alters stamp
    %   testSkipBuildEnvVarShortCircuits    -- FASTSENSE_SKIP_BUILD overrides everything
    %   testNeedsBuildReturnsFalseWhenStampMatches  -- binary + matching stamp -> skip
    %   testNeedsBuildReturnsTrueWhenStampMismatches -- binary + wrong stamp  -> rebuild
    %   testNeedsBuildReturnsTrueWhenBinaryMissing   -- stamp present but no binary -> rebuild
    %
    % See also: mex_stamp, install.

    properties (Access = private)
        Root        % repo root (char)
        MexDir      % libs/FastSense/private (char)
        StampFile   % .mex-version path (char)
        SentinelBin % binary_search_mex.<mexext()> path (char)
    end

    methods (TestClassSetup)
        function addPaths(testCase)
            %ADDPATHS Add project paths so mex_stamp and install shim are reachable.
            repo_root = fullfile(fileparts(mfilename('fullpath')), '..', '..');
            addpath(repo_root);
            install();
            % MATLAB R2025b+ silently rejects addpath() for private/ directories.
            % add_fastsense_private_path() handles this by copying to a temp proxy.
            add_fastsense_private_path();
            testCase.Root = repo_root;
            testCase.MexDir = fullfile(repo_root, 'libs', 'FastSense', 'private');
            testCase.StampFile = fullfile(testCase.MexDir, '.mex-version');
            testCase.SentinelBin = resolve_sentinel_(testCase.MexDir);
        end
    end

    methods (Test)

        % ------------------------------------------------------------------
        % 1. mex_stamp stability
        % ------------------------------------------------------------------

        function testStampIsStable(testCase)
            %TESTSTAMPISSTABLE Two calls on same tree return equal strings.
            h1 = mex_stamp(testCase.Root);
            h2 = mex_stamp(testCase.Root);
            testCase.assertNotEmpty(h1, 'mex_stamp must return non-empty char');
            testCase.assertClass(h1, 'char', 'mex_stamp must return char');
            testCase.assertEqual(h1, h2, ...
                'mex_stamp must return identical value on repeated calls');
        end

        % ------------------------------------------------------------------
        % 2. Stamp changes when source content is modified
        % ------------------------------------------------------------------

        function testStampChangesWhenSourceTouched(testCase)
            %TESTSTAMPCHANGESWHEN SOURCETOUCHED Adding a .c file changes the stamp.
            src_dir = fullfile(testCase.Root, 'libs', 'FastSense', 'private', 'mex_src');
            scratch  = fullfile(src_dir, 'zzz_testonly_scratch.c');
            cleanup  = onCleanup(@() delete_if_exists_(scratch));

            baseline = mex_stamp(testCase.Root);

            % Write a new .c file — content changes the fingerprint.
            fid = fopen(scratch, 'w');
            fprintf(fid, '// scratch file added by TestMexPrebuilt\n');
            fclose(fid);

            h_after = mex_stamp(testCase.Root);
            testCase.assertNotEqual(baseline, h_after, ...
                'mex_stamp must change when a new .c file is added to mex_src');
        end

        % ------------------------------------------------------------------
        % 3. FASTSENSE_SKIP_BUILD env var short-circuits needs_build
        % ------------------------------------------------------------------

        function testSkipBuildEnvVarShortCircuits(testCase)
            %TESTSKIPBUILDENVVARSHORTCIRCUITS FASTSENSE_SKIP_BUILD=1 -> false.
            old_val = getenv('FASTSENSE_SKIP_BUILD');
            setenv('FASTSENSE_SKIP_BUILD', '1');
            cleanup = onCleanup(@() setenv('FASTSENSE_SKIP_BUILD', old_val));

            result = install('__probe_needs_build__');
            testCase.assertFalse(result, ...
                'FASTSENSE_SKIP_BUILD=1 must make needs_build return false');
        end

        % ------------------------------------------------------------------
        % 4. needs_build returns false when binary + matching stamp present
        % ------------------------------------------------------------------

        function testNeedsBuildReturnsFalseWhenStampMatches(testCase)
            %TESTNEEDSBUILDRETURNSFALSEWHENSTAPMATCHS binary + fresh stamp -> false.
            old_env = getenv('FASTSENSE_SKIP_BUILD');
            setenv('FASTSENSE_SKIP_BUILD', '');
            restore_env = onCleanup(@() setenv('FASTSENSE_SKIP_BUILD', old_env));

            % Compute fresh stamp.
            fresh = mex_stamp(testCase.Root);

            % Write matching stamp file.
            [old_stamp, stamp_existed] = read_file_safe_(testCase.StampFile);
            write_file_(testCase.StampFile, fresh);
            restore_stamp = onCleanup(@() restore_file_( ...
                testCase.StampFile, old_stamp, stamp_existed));

            % Plan 1013-07: committed binaries are a prerequisite — no touch_binary_ fallback.
            testCase.assertTrue(exist(testCase.SentinelBin, 'file') == 3 || ...
                exist(testCase.SentinelBin, 'file') == 2, ...
                sprintf('Expected committed sentinel binary at %s', testCase.SentinelBin));

            % Plan 1013-07: exercise fresh-state path — private/ must NOT be
            % on path when the probe runs (mirrors end-user install() call).
            rmpath_silent_(testCase.MexDir);
            restore_path = onCleanup(@() add_fastsense_private_path());

            result = install('__probe_needs_build__');
            testCase.assertFalse(result, ...
                'needs_build must return false when binary exists and stamp matches');
        end

        % ------------------------------------------------------------------
        % 5. needs_build returns true when stamp mismatches
        % ------------------------------------------------------------------

        function testNeedsBuildReturnsTrueWhenStampMismatches(testCase)
            %TESTNEEDSBUILDRETSURNSTRUEWHENSTAPMISMATCHES wrong stamp -> true.
            old_env = getenv('FASTSENSE_SKIP_BUILD');
            setenv('FASTSENSE_SKIP_BUILD', '');
            restore_env = onCleanup(@() setenv('FASTSENSE_SKIP_BUILD', old_env));

            % Write a deliberately wrong stamp.
            [old_stamp, stamp_existed] = read_file_safe_(testCase.StampFile);
            write_file_(testCase.StampFile, 'sha256:0000000000000000000000000000000000000000000000000000000000000000');
            restore_stamp = onCleanup(@() restore_file_( ...
                testCase.StampFile, old_stamp, stamp_existed));

            % Plan 1013-07: committed binaries are a prerequisite — no touch_binary_ fallback.
            testCase.assertTrue(exist(testCase.SentinelBin, 'file') == 3 || ...
                exist(testCase.SentinelBin, 'file') == 2, ...
                sprintf('Expected committed sentinel binary at %s', testCase.SentinelBin));

            % Plan 1013-07: fresh-state path — private/ must NOT be on path.
            rmpath_silent_(testCase.MexDir);
            restore_path = onCleanup(@() add_fastsense_private_path());

            result = install('__probe_needs_build__');
            testCase.assertTrue(result, ...
                'needs_build must return true when stamp mismatches sources');
        end

        % ------------------------------------------------------------------
        % 6. needs_build returns true when binary is missing
        % ------------------------------------------------------------------

        function testOctaveSubdirProbeAcceptsBinary(testCase)
            %TESTOCTAVESUBDIRPROBEACCEPTSBINARY Subdir binary satisfies needs_build on Octave.
            %   Skipped on MATLAB (mexext disambiguates natively).
            if ~exist('OCTAVE_VERSION', 'builtin')
                testCase.log('testOctaveSubdirProbe: SKIPPED (MATLAB)');
                return;
            end

            tag = derive_octave_tag_();
            testCase.assumeNotEmpty(tag, 'Cannot derive Octave platform tag on this system');

            subdir = fullfile(testCase.MexDir, ['octave-' tag]);
            if ~isfolder(subdir)
                mkdir(subdir);
                rmSubdir = true;
            else
                rmSubdir = false;
            end
            cleanup_dir = onCleanup(@() maybe_rmdir_(subdir, rmSubdir));

            sentinel    = fullfile(subdir, 'binary_search_mex.mex');
            cleanup_bin = onCleanup(@() delete_if_exists_(sentinel));

            fid = fopen(sentinel, 'w');
            fprintf(fid, 'placeholder');
            fclose(fid);
            addpath(subdir);
            cleanup_path = onCleanup(@() rmpath(subdir));

            old_env = getenv('FASTSENSE_SKIP_BUILD');
            setenv('FASTSENSE_SKIP_BUILD', '');
            restore_env = onCleanup(@() setenv('FASTSENSE_SKIP_BUILD', old_env));

            fresh = mex_stamp(testCase.Root);
            [old_stamp, stamp_existed] = read_file_safe_(testCase.StampFile);
            write_file_(testCase.StampFile, fresh);
            restore_stamp = onCleanup(@() restore_file_( ...
                testCase.StampFile, old_stamp, stamp_existed));

            flat_bin     = fullfile(testCase.MexDir, 'binary_search_mex.mex');
            flat_existed = (exist(flat_bin, 'file') == 3);
            flat_backup  = [flat_bin '.bak_subdir_test'];
            if flat_existed
                movefile(flat_bin, flat_backup);
            end
            restore_flat = onCleanup(@() restore_binary_(flat_bin, flat_backup, flat_existed));

            result = install('__probe_needs_build__');
            testCase.assertFalse(result, ...
                'needs_build must return false when octave-<tag>/ binary is present');
        end

        function testNeedsBuildReturnsTrueWhenBinaryMissing(testCase)
            %TESTNEEDSBUILDRETSURNSTRUEWHENBINARYMISSING no binary -> true.
            %   Hides both the flat private/ sentinel AND the octave-<tag>/
            %   subdir binary (when on Octave) so needs_build has nothing.
            old_env = getenv('FASTSENSE_SKIP_BUILD');
            setenv('FASTSENSE_SKIP_BUILD', '');
            restore_env = onCleanup(@() setenv('FASTSENSE_SKIP_BUILD', old_env));

            % Write matching stamp.
            fresh = mex_stamp(testCase.Root);
            [old_stamp, stamp_existed] = read_file_safe_(testCase.StampFile);
            write_file_(testCase.StampFile, fresh);
            restore_stamp = onCleanup(@() restore_file_( ...
                testCase.StampFile, old_stamp, stamp_existed));

            % Temporarily rename flat sentinel binary if it exists.
            bin_existed = (exist(testCase.SentinelBin, 'file') == 3);
            hidden = [testCase.SentinelBin '.bak_test'];
            if bin_existed
                movefile(testCase.SentinelBin, hidden);
            end
            restore_bin = onCleanup(@() restore_binary_(testCase.SentinelBin, hidden, bin_existed));

            % On Octave also hide the octave-<tag>/ subdir binary.
            if exist('OCTAVE_VERSION', 'builtin')
                tag6 = derive_octave_tag_();
                if ~isempty(tag6)
                    octBin6 = fullfile(testCase.MexDir, ['octave-' tag6], ...
                        'binary_search_mex.mex');
                    octBak6 = [octBin6 '.bak_test6'];
                    oct6_existed = (exist(octBin6, 'file') ~= 0);
                    if oct6_existed; movefile(octBin6, octBak6); end
                    restore_oct6 = onCleanup( ...
                        @() restore_binary_(octBin6, octBak6, oct6_existed));
                end
            end

            result = install('__probe_needs_build__');
            testCase.assertTrue(result, ...
                'needs_build must return true when binary is missing');
        end

    end

end

% =========================================================================
% Local helpers (not test methods)
% =========================================================================

function [content, existed] = read_file_safe_(p)
%READ_FILE_SAFE_ Read file content; return '' and false if missing.
    if exist(p, 'file') == 2
        content = fileread(p);
        existed = true;
    else
        content = '';
        existed = false;
    end
end

function write_file_(p, content)
%WRITE_FILE_ Write char content to file p.
    fid = fopen(p, 'w');
    fprintf(fid, '%s', content);
    fclose(fid);
end

function restore_file_(p, old_content, existed)
%RESTORE_FILE_ Restore file to pre-test state.
    if existed
        fid = fopen(p, 'w');
        fprintf(fid, '%s', old_content);
        fclose(fid);
    else
        delete_if_exists_(p);
    end
end

function touch_binary_(p)
%TOUCH_BINARY_ Create a minimal placeholder binary file (type MEX = 3).
%   In Octave/MATLAB exist(...,'file')==3 means the path is a MEX file.
%   We cannot create a real MEX binary here, so we write a tiny file and
%   rename it with the .mexXXX extension.  exist() will report type 2 (M-file)
%   if the content is not a real MEX, but that is acceptable for the test.
%   The tests only rely on the binary being *absent* or *present*, and the
%   probe in needs_build uses exist(...,'file')==3.  To make the probe pass
%   we actually need a real binary — if it does not already exist then the
%   prebuilt path is not yet set up.  In that case we skip by leaving it
%   absent and accepting that needs_build returns true (binary missing).
%   This function writes a stub that may not be recognized as type 3;
%   callers must check bin_existed and adjust expectations accordingly.
    fid = fopen(p, 'w');
    fprintf(fid, 'placeholder');
    fclose(fid);
end

function maybe_delete_(p, was_present)
%MAYBE_DELETE_ Delete p unless it was already present before the test.
    if ~was_present
        delete_if_exists_(p);
    end
end

function restore_binary_(p, backup, was_present)
%RESTORE_BINARY_ Restore binary from backup if it was present before test.
    if was_present && exist(backup, 'file') == 2
        movefile(backup, p);
    end
    delete_if_exists_(backup);
end

function delete_if_exists_(p)
%DELETE_IF_EXISTS_ Delete a file silently.
    if exist(p, 'file') ~= 0
        delete(p);
    end
end

function rmpath_silent_(p)
%RMPATH_SILENT_ Remove p (and any canonical-equivalent) from path.  Silent on absence.
    canon = canon_path_(p);
    dirs = strsplit(path, pathsep);
    for i = 1:numel(dirs)
        if isempty(dirs{i}); continue; end
        if strcmp(dirs{i}, p) || strcmp(canon_path_(dirs{i}), canon)
            w = warning('off', 'all');
            rmpath(dirs{i});
            warning(w);
        end
    end
end

function c = canon_path_(p)
%CANON_PATH_ Canonicalize a path (resolve ./ and ..).  Returns input on failure.
    try
        info = what(p);
        if ~isempty(info) && ~isempty(info(1).path)
            c = info(1).path;
            return;
        end
    catch
    end
    c = p;
end

function p = resolve_sentinel_(mex_dir)
%RESOLVE_SENTINEL_ Return absolute path to a committed MEX sentinel binary.
%   Resolves per Plan 1013-03 subdir layout + Plan 1013-04 committed
%   macos-arm64 binaries (VERIFICATION.md gap fix 1013-07).
%   On MATLAB: flat private/binary_search_mex.<mexext()>.
%   On Octave: private/octave-<tag>/binary_search_mex.mex where tag comes
%   from derive_octave_tag_().  On Octave macOS ARM64 this is
%   octave-macos-arm64/binary_search_mex.mex (committed by Plan 1013-04).
    if exist('OCTAVE_VERSION', 'builtin')
        tag = derive_octave_tag_();
        if isempty(tag)
            p = fullfile(mex_dir, 'binary_search_mex.mex');
            return;
        end
        p = fullfile(mex_dir, ['octave-' tag], 'binary_search_mex.mex');
    else
        p = fullfile(mex_dir, ['binary_search_mex.' mexext()]);
    end
end

function tag = derive_octave_tag_()
%DERIVE_OCTAVE_TAG_ Mirror of get_octave_platform_tag from install.m.
    arch = lower(computer('arch'));
    isDarwin = ~isempty(strfind(arch, 'darwin'));
    isLinux  = ~isempty(strfind(arch, 'linux'));
    isWin    = ~isempty(strfind(arch, 'mingw')) || ~isempty(strfind(arch, 'w64'));
    isArm    = ~isempty(strfind(arch, 'aarch64')) || ~isempty(strfind(arch, 'arm64'));
    if isDarwin && isArm;      tag = 'macos-arm64';
    elseif isDarwin;           tag = 'macos-x86_64';
    elseif isLinux;            tag = 'linux-x86_64';
    elseif isWin;              tag = 'windows-x86_64';
    else;                      tag = '';
    end
end

function maybe_rmdir_(d, wasCreated)
%MAYBE_RMDIR_ Remove directory d if it was created by this test.
    if wasCreated && isfolder(d)
        try; rmdir(d); catch; end
    end
end
