function test_mex_prebuilt()
%TEST_MEX_PREBUILT Octave function-based counterpart to TestMexPrebuilt.
%   Covers the same five test cases as the MATLAB class-based suite.
%
%   Cases:
%     1. testStampIsStable
%     2. testStampChangesWhenSourceTouched
%     3. testSkipBuildEnvVarShortCircuits
%     4. testNeedsBuildReturnsFalseWhenStampMatches
%     5. testNeedsBuildReturnsTrueWhenStampMismatches
%     6. testNeedsBuildReturnsTrueWhenBinaryMissing
%
%   See also: mex_stamp, install.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();
    add_fastsense_private_path();

    repo_root = fullfile(fileparts(mfilename('fullpath')), '..');
    mex_dir   = fullfile(repo_root, 'libs', 'FastSense', 'private');
    stamp_file = fullfile(mex_dir, '.mex-version');
    sentinel   = resolve_sentinel_(mex_dir);

    % ------------------------------------------------------------------
    % 1. Stamp stability
    % ------------------------------------------------------------------
    h1 = mex_stamp(repo_root);
    h2 = mex_stamp(repo_root);
    assert(~isempty(h1), 'testStampIsStable: stamp must be non-empty');
    assert(ischar(h1),   'testStampIsStable: stamp must be char');
    assert(strcmp(h1, h2), 'testStampIsStable: stamp must be stable across calls');

    % ------------------------------------------------------------------
    % 2. Stamp changes when source content touched
    % ------------------------------------------------------------------
    src_dir = fullfile(repo_root, 'libs', 'FastSense', 'private', 'mex_src');
    scratch  = fullfile(src_dir, 'zzz_testonly_scratch.c');
    baseline = mex_stamp(repo_root);

    fid = fopen(scratch, 'w');
    fprintf(fid, '// scratch added by test_mex_prebuilt\n');
    fclose(fid);

    h_after = mex_stamp(repo_root);
    delete_if_exists_(scratch);

    assert(~strcmp(baseline, h_after), ...
        'testStampChangesWhenSourceTouched: stamp must change after adding .c file');

    % ------------------------------------------------------------------
    % 3. FASTSENSE_SKIP_BUILD short-circuits needs_build
    % ------------------------------------------------------------------
    old_env = getenv('FASTSENSE_SKIP_BUILD');
    setenv('FASTSENSE_SKIP_BUILD', '1');
    result = install('__probe_needs_build__');
    setenv('FASTSENSE_SKIP_BUILD', old_env);
    assert(result == false, ...
        'testSkipBuildEnvVarShortCircuits: SKIP_BUILD=1 must return false');

    % ------------------------------------------------------------------
    % 4. needs_build returns false when binary + matching stamp present
    % ------------------------------------------------------------------
    old_env = getenv('FASTSENSE_SKIP_BUILD');
    setenv('FASTSENSE_SKIP_BUILD', '');

    fresh = mex_stamp(repo_root);
    [old_stamp, stamp_existed] = read_file_safe_(stamp_file);
    write_file_(stamp_file, fresh);

    % Plan 1013-07: committed binaries are a prerequisite — no SKIP fallback.
    assert(exist(sentinel, 'file') == 3, ...
        sprintf('testNeedsBuildFalseWhenMatch: committed sentinel missing at %s', sentinel));
    % Plan 1013-07: exercise fresh-state path — private/ must NOT be on path
    % when the probe runs (otherwise mex_stamp is reachable by accident and
    % the bug is masked).  Callers of install() in the wild only have the
    % repo root on path, not libs/FastSense/private/.
    rmpath_silent_(mex_dir);
    result = install('__probe_needs_build__');
    add_fastsense_private_path();
    restore_file_(stamp_file, old_stamp, stamp_existed);
    setenv('FASTSENSE_SKIP_BUILD', old_env);
    assert(result == false, ...
        'testNeedsBuildReturnsFalseWhenStampMatches: expected false when stamp matches');

    % ------------------------------------------------------------------
    % 5. needs_build returns true when stamp mismatches
    % ------------------------------------------------------------------
    old_env = getenv('FASTSENSE_SKIP_BUILD');
    setenv('FASTSENSE_SKIP_BUILD', '');

    [old_stamp, stamp_existed] = read_file_safe_(stamp_file);
    write_file_(stamp_file, 'sha256:0000000000000000000000000000000000000000000000000000000000000000');

    % Plan 1013-07: committed binaries are a prerequisite — no touch_binary_ fallback.
    assert(exist(sentinel, 'file') == 3, ...
        sprintf('testNeedsBuildTrueWhenMismatch: committed sentinel missing at %s', sentinel));

    % Plan 1013-07: fresh-state path — private/ must NOT be on path.
    rmpath_silent_(mex_dir);
    result = install('__probe_needs_build__');
    add_fastsense_private_path();

    restore_file_(stamp_file, old_stamp, stamp_existed);
    setenv('FASTSENSE_SKIP_BUILD', old_env);

    assert(result == true, ...
        'testNeedsBuildReturnsTrueWhenStampMismatches: expected true on bad stamp');

    % ------------------------------------------------------------------
    % 6. needs_build returns true when binary is missing
    %    Hide BOTH the flat private/ binary AND the octave-<tag>/ subdir
    %    binary (if present) so needs_build truly has no sentinel to find.
    % ------------------------------------------------------------------
    old_env = getenv('FASTSENSE_SKIP_BUILD');
    setenv('FASTSENSE_SKIP_BUILD', '');

    fresh = mex_stamp(repo_root);
    [old_stamp, stamp_existed] = read_file_safe_(stamp_file);
    write_file_(stamp_file, fresh);

    bin_existed = (exist(sentinel, 'file') == 3);
    backup = [sentinel '.bak_test'];
    if bin_existed
        movefile(sentinel, backup);
    end

    % Also hide the octave-<tag>/ subdir binary if running on Octave.
    oct_tag6 = '';
    oct_bin6 = '';
    oct_bin6_bak = '';
    oct_bin6_existed = false;
    if exist('OCTAVE_VERSION', 'builtin')
        oct_tag6 = derive_octave_tag_();
        if ~isempty(oct_tag6)
            oct_bin6 = fullfile(mex_dir, ['octave-' oct_tag6], 'binary_search_mex.mex');
            oct_bin6_existed = (exist(oct_bin6, 'file') ~= 0);
            oct_bin6_bak = [oct_bin6 '.bak_test6'];
            if oct_bin6_existed
                movefile(oct_bin6, oct_bin6_bak);
            end
        end
    end

    result = install('__probe_needs_build__');

    restore_file_(stamp_file, old_stamp, stamp_existed);
    if bin_existed && exist(backup, 'file') == 2
        movefile(backup, sentinel);
    end
    delete_if_exists_(backup);
    if oct_bin6_existed && exist(oct_bin6_bak, 'file') == 2
        movefile(oct_bin6_bak, oct_bin6);
    end
    delete_if_exists_(oct_bin6_bak);
    setenv('FASTSENSE_SKIP_BUILD', old_env);

    assert(result == true, ...
        'testNeedsBuildReturnsTrueWhenBinaryMissing: expected true when binary absent');

    % ------------------------------------------------------------------
    % 7. Octave subdir probe: binary in octave-<tag>/ satisfies needs_build
    %    when flat private/ location is empty.  Skipped on MATLAB.
    % ------------------------------------------------------------------
    if ~exist('OCTAVE_VERSION', 'builtin')
        fprintf('    testOctaveSubdirProbe: SKIPPED (MATLAB)\n');
    else
        run_octave_subdir_probe_test_(repo_root, mex_dir);
    end

    fprintf('    All 7 mex_prebuilt tests passed.\n');
end

% =========================================================================
% Local helpers
% =========================================================================

function run_octave_subdir_probe_test_(repo_root, mex_dir)
%RUN_OCTAVE_SUBDIR_PROBE_TEST_ Verify needs_build accepts subdir binary.
%   Creates a temp octave-<tag>/binary_search_mex.mex sentinel,
%   adds it to path, and asserts needs_build returns false.
    tag = derive_octave_tag_();
    assert(~isempty(tag), 'testOctaveSubdirProbe: could not derive platform tag');

    subdir = fullfile(mex_dir, ['octave-' tag]);
    if ~isfolder(subdir)
        mkdir(subdir);
        rmSubdir = true;
    else
        rmSubdir = false;
    end

    sentinel   = fullfile(subdir, 'binary_search_mex.mex');
    stamp_file = fullfile(mex_dir, '.mex-version');
    [old_stamp, stamp_existed] = read_file_safe_(stamp_file);
    write_file_(stamp_file, mex_stamp(repo_root));

    fid = fopen(sentinel, 'w');
    fprintf(fid, 'placeholder');
    fclose(fid);
    addpath(subdir);

    old_env = getenv('FASTSENSE_SKIP_BUILD');
    setenv('FASTSENSE_SKIP_BUILD', '');

    flat_bin    = fullfile(mex_dir, 'binary_search_mex.mex');
    flat_existed = (exist(flat_bin, 'file') == 3);
    flat_backup  = [flat_bin '.bak_subdir_test'];
    if flat_existed
        movefile(flat_bin, flat_backup);
    end

    result = install('__probe_needs_build__');

    setenv('FASTSENSE_SKIP_BUILD', old_env);
    if flat_existed && exist(flat_backup, 'file') == 2
        movefile(flat_backup, flat_bin);
    end
    delete_if_exists_(sentinel);
    rmpath(subdir);
    if rmSubdir && isfolder(subdir)
        rmdir(subdir);
    end
    restore_file_(stamp_file, old_stamp, stamp_existed);

    assert(result == false, ...
        'testOctaveSubdirProbe: needs_build must return false when subdir binary is present');
end

function rmpath_silent_(p)
%RMPATH_SILENT_ Remove p (and any canonical-equivalent) from path.  Silent on absence.
%   Handles relative-vs-absolute differences by canonicalizing via what().
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
%   from derive_octave_tag_().
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

function [content, existed] = read_file_safe_(p)
%READ_FILE_SAFE_ Read file; return '' and false if missing.
    if exist(p, 'file') == 2
        content = fileread(p);
        existed = true;
    else
        content = '';
        existed = false;
    end
end

function write_file_(p, content)
%WRITE_FILE_ Write content to file p.
    fid = fopen(p, 'w');
    fprintf(fid, '%s', content);
    fclose(fid);
end

function restore_file_(p, old_content, existed)
%RESTORE_FILE_ Restore file to pre-test state.
    if existed
        write_file_(p, old_content);
    else
        delete_if_exists_(p);
    end
end

function touch_binary_(p)
%TOUCH_BINARY_ Write a placeholder file at p (may not be type==3).
    fid = fopen(p, 'w');
    fprintf(fid, 'placeholder');
    fclose(fid);
end

function delete_if_exists_(p)
%DELETE_IF_EXISTS_ Delete file p silently if present.
    if exist(p, 'file') ~= 0
        delete(p);
    end
end
