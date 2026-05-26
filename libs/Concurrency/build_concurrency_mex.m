function build_concurrency_mex()
%BUILD_CONCURRENCY_MEX Compile lockfile_mex.c with platform branching.
%   BUILD_CONCURRENCY_MEX() compiles lockfile_mex.c from
%   libs/Concurrency/private/mex_src/ into the appropriate output directory:
%
%   Output directory:
%     MATLAB:  libs/Concurrency/           (root, so addpath('libs/Concurrency') finds it)
%     Octave:  libs/Concurrency/private/octave-<tag>/  (platform-tagged, Pitfall E)
%
%   NOTE: On MATLAB, the output goes to the Concurrency root (not private/)
%   so that users who addpath('libs/Concurrency') can call lockfile_mex directly.
%   MATLAB's private/ mechanism only exposes MEX to sibling M-files, not to
%   external callers.  This mirrors the mksqlite pattern in build_mex.m.
%
%   Platform flags:
%     Linux:   -O2 -D_GNU_SOURCE  (Pitfall A — ensures F_OFD_SETLK visible)
%     macOS:   -O2                 (F_SETLK fallback; dev-only caveat documented)
%     Windows: /O2                 (LockFileEx; kernel32.lib auto-linked by MSVC)
%
%   The build is skipped if the MEX binary already exists in the output
%   directory. Compilation errors are caught and reported as warnings so
%   that the FastSense build is not aborted when the C compiler is absent —
%   FileLock.m (Plan 03) falls back to pure-MATLAB sidecar mode.
%
%   Example:
%     build_concurrency_mex();   % compile lockfile_mex; prints status
%
%   See also build_mex, install, lockfile_mex.

    rootDir = fileparts(mfilename('fullpath'));
    srcDir  = fullfile(rootDir, 'private', 'mex_src');
    srcFile = fullfile(srcDir, 'lockfile_mex.c');
    outName = 'lockfile_mex';

    if ~isfile(srcFile)
        error('Concurrency:lockfileMexMissingSrc', ...
            'Source file not found: %s', srcFile);
    end

    isOctave = exist('OCTAVE_VERSION', 'builtin') == 5;
    if isOctave
        % Octave: route to platform-tagged subdirectory (Pitfall E)
        octTag = local_octave_tag_(computer('arch'));
        outDir = fullfile(rootDir, 'private', ['octave-' octTag]);
        if ~isfolder(outDir); mkdir(outDir); end
    else
        % MATLAB: output to the Concurrency root so addpath finds it
        % (mirrors mksqlite outDirMksql=rootDir pattern in build_mex.m)
        outDir = rootDir;
    end

    % Skip if already built (mirrors build_mex.m pattern)
    existsExt = exist(fullfile(outDir, [outName, '.', mexext()]), 'file') == 3;
    existsMex = exist(fullfile(outDir, [outName, '.mex']),        'file') == 3;
    if existsExt || existsMex
        fprintf('Compiling lockfile_mex.c ... SKIPPED (already exists)\n');
        return;
    end

    useMSVC = ispc && ~isOctave;
    if useMSVC
        % Windows MSVC: LockFileEx; kernel32.lib is auto-linked by MSVC linker
        opt_flags = {'/O2'};
    elseif ispc && isOctave
        % Windows Octave (mingw/w64)
        opt_flags = {'-O2'};
    elseif ismac
        % macOS (Xcode Clang or GCC): F_SETLK fallback (dev-only, documented)
        opt_flags = {'-O2'};
    else
        % Linux: -D_GNU_SOURCE exposes F_OFD_SETLK (Pitfall A prevention)
        opt_flags = {'-O2', '-D_GNU_SOURCE'};
    end

    fprintf('Compiling lockfile_mex.c ... ');
    try
        local_compile_(srcFile, outName, outDir, opt_flags, isOctave, useMSVC);
        fprintf('OK\n');
    catch err
        fprintf('FAILED\n');
        fprintf('  Error: %s\n', err.message);
        fprintf('  (FileLock will fall back to pure-MATLAB sidecar mode in Plan 03)\n');
        warning('Concurrency:lockfileMexCompileFailed', ...
            'lockfile_mex failed to compile: %s', err.message);
    end
end

function local_compile_(srcFile, outName, outDir, opt_flags, isOctave, useMSVC)
%LOCAL_COMPILE_ Invoke mkoctfile or mex to build lockfile_mex.
    if isOctave
        args = {'--mex'};
        args = [args, opt_flags];
        args = [args, {'-o', fullfile(outDir, outName), srcFile}];
        mkoctfile(args{:});
    else
        if useMSVC
            cflags = ['COMPFLAGS="$COMPFLAGS ' strjoin(opt_flags, ' ') '"'];
        else
            cflags = ['CFLAGS="$CFLAGS ' strjoin(opt_flags, ' ') '"'];
        end
        mex(cflags, '-outdir', outDir, '-output', outName, srcFile);
    end
end

function tag = local_octave_tag_(arch_raw)
%LOCAL_OCTAVE_TAG_ Derive Octave platform tag from computer('arch') string.
%   Returns the same tag as local_octave_tag_ in libs/FastSense/build_mex.m.
%
%   Rules (applied to lowercase arch string):
%     darwin  + aarch64/arm64  -> 'macos-arm64'
%     darwin  (other)          -> 'macos-x86_64'
%     linux                    -> 'linux-x86_64'
%     mingw / w64              -> 'windows-x86_64'
%     unrecognized             -> 'unknown'
    arch = lower(arch_raw);
    isDarwin = ~isempty(strfind(arch, 'darwin'));
    isLinux  = ~isempty(strfind(arch, 'linux'));
    isWin    = ~isempty(strfind(arch, 'mingw')) || ~isempty(strfind(arch, 'w64'));
    isArm    = ~isempty(strfind(arch, 'aarch64')) || ~isempty(strfind(arch, 'arm64'));
    if isDarwin && isArm
        tag = 'macos-arm64';
    elseif isDarwin
        tag = 'macos-x86_64';
    elseif isLinux
        tag = 'linux-x86_64';
    elseif isWin
        tag = 'windows-x86_64';
    else
        tag = 'unknown';
    end
end
