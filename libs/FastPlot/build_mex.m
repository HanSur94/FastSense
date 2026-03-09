function build_mex()
%BUILD_MEX Compile all FastPlot MEX files with platform-appropriate SIMD flags.
%   BUILD_MEX() detects the CPU architecture (x86_64 or ARM64) and the
%   best available C compiler, then compiles every MEX source file found
%   in private/mex_src/ into the private/ directory.
%
%   Architecture detection normalizes differences between MATLAB and
%   Octave (e.g., 'maca64' vs 'aarch64') into a canonical label used
%   to select SIMD instruction targets:
%     x86_64  — AVX2 + FMA (with SSE2 fallback on failure)
%     arm64   — ARM NEON (implicit on Apple Silicon / explicit on GCC)
%     unknown — scalar fallback (no SIMD)
%
%   Compiler selection:
%     Octave  — prefers real GCC (searched via find_gcc) for superior
%               auto-vectorization; falls back to system default
%     MATLAB  — always uses the configured default compiler (Xcode
%               Clang on macOS, MSVC on Windows) because MATLAB passes
%               compiler-specific linker flags that GCC may reject
%
%   On x86_64, if the initial AVX2 compilation fails (e.g., on older
%   hardware), the function automatically retries with SSE2 flags.
%
%   After compilation, shared MEX files needed by the SensorThreshold
%   library are copied into ../SensorThreshold/private/.
%
%   MEX source files compiled:
%     binary_search_mex.c   — binary search on sorted arrays
%     minmax_core_mex.c     — min/max downsampling kernel
%     lttb_core_mex.c       — Largest-Triangle-Three-Buckets kernel
%     violation_cull_mex.c  — threshold violation culling
%
%   Example:
%     build_mex();   % compile everything; prints per-file status
%
%   See also binary_search, setup.

    rootDir = fileparts(mfilename('fullpath'));
    srcDir  = fullfile(rootDir, 'private', 'mex_src');
    outDir  = fullfile(rootDir, 'private');

    % Detect architecture — normalize varying platform strings into a
    % canonical label.  Octave returns 'aarch64-...' or 'x86_64-...',
    % while MATLAB uses 'maca64', 'maci64', 'glnxa64', or 'win64'.
    arch_raw = computer('arch');
    if ~isempty(strfind(arch_raw, 'aarch64')) || ~isempty(strfind(arch_raw, 'arm64')) || strcmp(arch_raw, 'maca64')
        arch = 'arm64';
    elseif ~isempty(strfind(arch_raw, 'x86_64')) || ~isempty(strfind(arch_raw, '64')) && ...
           (strcmp(arch_raw, 'maci64') || strcmp(arch_raw, 'glnxa64') || strcmp(arch_raw, 'win64'))
        arch = 'x86_64';
    else
        arch = 'unknown';
    end
    fprintf('Architecture: %s (%s)\n', arch, arch_raw);

    % Detect compiler: use GCC for Octave (better auto-vectorization),
    % but always use MATLAB's configured Clang for MATLAB (it passes
    % Clang-specific linker flags like -weak-lmex that GCC rejects).
    isOctave = exist('OCTAVE_VERSION', 'builtin');
    if isOctave
        [gcc_path, gcc_name] = find_gcc();
        if ~isempty(gcc_path)
            compiler = gcc_path;
            fprintf('Compiler: %s (GCC — preferred for auto-vectorization)\n', gcc_name);
        else
            compiler = '';
            fprintf('Compiler: system default\n');
        end
    else
        compiler = '';
        if ispc
            fprintf('Compiler: MATLAB default (MSVC)\n');
        else
            fprintf('Compiler: MATLAB default (Xcode Clang)\n');
        end
    end

    % Set optimization and SIMD flags — MSVC uses /flags while GCC/Clang
    % use -flags.  The boolean useMSVC distinguishes the two conventions.
    useMSVC = ispc && ~isOctave;
    switch arch
        case 'x86_64'
            if useMSVC
                opt_flags = {'/O2', '/arch:AVX2', '/fp:fast'};
            else
                opt_flags = {'-O3', '-mavx2', '-mfma', '-ftree-vectorize', '-ffast-math'};
            end
            fprintf('SIMD target: AVX2 + FMA\n');
        case 'arm64'
            if useMSVC
                % MSVC on ARM64 Windows: NEON enabled by default
                opt_flags = {'/O2', '/fp:fast'};
            elseif isOctave && ~isempty(compiler)
                % GCC on ARM needs explicit CPU target
                opt_flags = {'-O3', '-mcpu=apple-m3', '-ftree-vectorize', '-ffast-math'};
            else
                % Clang on Apple Silicon: NEON enabled by default
                opt_flags = {'-O3', '-ffast-math'};
            end
            fprintf('SIMD target: ARM NEON\n');
        otherwise
            if useMSVC
                opt_flags = {'/O2', '/fp:fast'};
            else
                opt_flags = {'-O3', '-ffast-math'};
            end
            fprintf('SIMD target: scalar fallback\n');
    end

    % Common flags
    include_flag = ['-I' srcDir];

    % Files to compile: {source_name, output_name}
    mex_files = {
        'binary_search_mex.c',          'binary_search_mex'
        'minmax_core_mex.c',            'minmax_core_mex'
        'lttb_core_mex.c',              'lttb_core_mex'
        'violation_cull_mex.c',         'violation_cull_mex'
    };

    fprintf('\n');

    n_success = 0;
    n_fail = 0;

    for i = 1:size(mex_files, 1)
        src_file = fullfile(srcDir, mex_files{i, 1});
        out_name = mex_files{i, 2};

        fprintf('Compiling %s ... ', mex_files{i, 1});

        try
            compile_mex(src_file, out_name, outDir, include_flag, opt_flags, compiler);
            fprintf('OK\n');
            n_success = n_success + 1;
        catch e
            fprintf('FAILED\n');
            fprintf('  Error: %s\n', e.message);

            % If AVX2 failed on x86_64, retry with SSE2
            hasAVX2 = any(contains(opt_flags, 'mavx2')) || any(contains(opt_flags, 'AVX2'));
            if strcmp(arch, 'x86_64') && hasAVX2
                fprintf('  Retrying with SSE2 fallback ... ');
                try
                    if useMSVC
                        sse_flags = {'/O2', '/arch:SSE2', '/fp:fast'};
                    else
                        sse_flags = {'-O3', '-msse2', '-ftree-vectorize', '-ffast-math'};
                    end
                    compile_mex(src_file, out_name, outDir, include_flag, sse_flags, compiler);
                    fprintf('OK (SSE2)\n');
                    n_success = n_success + 1;
                catch e2
                    fprintf('FAILED\n');
                    fprintf('  Error: %s\n', e2.message);
                    n_fail = n_fail + 1;
                end
            else
                n_fail = n_fail + 1;
            end
        end
    end

    fprintf('\n%d/%d MEX files compiled successfully.\n', ...
        n_success, size(mex_files, 1));

    if n_fail > 0
        fprintf('(%d failed — MATLAB fallback will be used for those.)\n', n_fail);
    end

    % Copy shared MEX files to SensorThreshold/private so they're accessible there
    sensorPrivDir = fullfile(rootDir, '..', 'SensorThreshold', 'private');
    copy_mex_to(outDir, sensorPrivDir, 'violation_cull_mex');
end


function compile_mex(src_file, out_name, outDir, include_flag, opt_flags, compiler)
%COMPILE_MEX Compile a single C source file into a MEX binary.
%   compile_mex(src_file, out_name, outDir, include_flag, opt_flags, compiler)
%   dispatches to Octave's mkoctfile or MATLAB's mex depending on the
%   runtime environment. On Octave, the CC environment variable is
%   temporarily set to compiler (if non-empty) and restored afterwards.
%   On MATLAB/Windows, optimization flags are passed via COMPFLAGS; on
%   MATLAB/Unix they are passed via CFLAGS.
%
%   Inputs:
%     src_file     — char; absolute path to the .c source file
%     out_name     — char; desired output name (without extension)
%     outDir       — char; directory for the compiled MEX binary
%     include_flag — char; compiler include flag (e.g., '-I/path')
%     opt_flags    — cell array of char; optimization/SIMD flags
%     compiler     — char; path to compiler executable ('' for default)
    if exist('OCTAVE_VERSION', 'builtin')
        % Octave: use mkoctfile
        args = {'--mex', include_flag};
        args = [args, opt_flags];
        args = [args, {'-o', fullfile(outDir, out_name), src_file}];
        if ~isempty(compiler)
            setenv('CC', compiler);
        end
        mkoctfile(args{:});
        if ~isempty(compiler)
            setenv('CC', '');
        end
    else
        % MATLAB: use mex
        if ispc
            % Windows MSVC: use COMPFLAGS
            cflags = ['COMPFLAGS="$COMPFLAGS ' strjoin(opt_flags, ' ') '"'];
        else
            % macOS/Linux GCC/Clang: use CFLAGS
            cflags = ['CFLAGS="$CFLAGS ' strjoin(opt_flags, ' ') '"'];
        end
        mex_args = {cflags, include_flag, '-outdir', outDir, '-output', out_name, src_file};
        if ~isempty(compiler)
            mex_args = [['CC=' compiler], mex_args];
        end
        mex(mex_args{:});
    end
end


function copy_mex_to(srcDir, destDir, name)
%COPY_MEX_TO Copy a compiled MEX binary to another directory.
%   copy_mex_to(srcDir, destDir, name) finds all files matching
%   name.* in srcDir (to catch platform-specific MEX extensions like
%   .mexa64, .mexmaci64, .mex, etc.) and copies each one to destDir.
%   Prints a confirmation or warning for every file.
%
%   Inputs:
%     srcDir  — char; source directory containing the compiled MEX file
%     destDir — char; destination directory to copy into
%     name    — char; MEX file base name (without extension)
    d = dir(fullfile(srcDir, [name '.*']));
    for i = 1:numel(d)
        src = fullfile(srcDir, d(i).name);
        dst = fullfile(destDir, d(i).name);
        [ok, msg] = copyfile(src, dst);
        if ok
            fprintf('Copied %s → %s\n', d(i).name, destDir);
        else
            fprintf('Warning: failed to copy %s: %s\n', d(i).name, msg);
        end
    end
end


function [gcc_path, gcc_name] = find_gcc()
%FIND_GCC Search for a real GCC installation (not Apple Clang).
%   [gcc_path, gcc_name] = find_gcc() searches Homebrew paths for
%   versioned GCC binaries (gcc-15 down to gcc-10) in /opt/homebrew/bin
%   and /usr/local/bin, then checks whether the system 'gcc' is real
%   GCC (identified by the "Free Software Foundation" string in its
%   --version output) rather than Apple Clang masquerading as gcc.
%
%   Outputs:
%     gcc_path — char; full path to the GCC executable, or '' if none
%                found
%     gcc_name — char; short name of the compiler (e.g., 'gcc-14'),
%                or '' if none found
    gcc_path = '';
    gcc_name = '';

    % Check common Homebrew/system GCC paths in order of preference
    candidates = {};
    for ver = 15:-1:10
        candidates{end+1} = sprintf('/opt/homebrew/bin/gcc-%d', ver);
        candidates{end+1} = sprintf('/usr/local/bin/gcc-%d', ver);
    end

    for c = 1:numel(candidates)
        p = candidates{c};
        if exist(p, 'file')
            gcc_path = p;
            [~, gcc_name] = fileparts(p);
            return;
        end
    end

    % Check if system gcc is real GCC (not Apple Clang)
    [status, result] = system('gcc --version 2>&1');
    if status == 0 && ~isempty(strfind(result, 'Free Software Foundation'))
        gcc_path = 'gcc';
        gcc_name = 'gcc';
    end
end
