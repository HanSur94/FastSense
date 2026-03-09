function build_mex()
%BUILD_MEX Compile FastPlot MEX files with platform-appropriate SIMD flags.
%   build_mex()
%
%   Compiles all C source files in private/mex_src/ into MEX binaries in
%   private/. FastPlot falls back to pure MATLAB when MEX files are not
%   available, so compilation is optional but recommended for performance.
%
%   Architecture detection:
%     x86_64  — AVX2 + FMA flags (SSE2 fallback if AVX2 unsupported)
%     arm64   — ARM NEON (default on Apple Silicon)
%     unknown — scalar fallback (-O3 only)
%
%   Compiler selection:
%     1. GCC (Homebrew) — preferred for auto-vectorization
%     2. System default (Clang) — fallback
%
%   MEX files compiled:
%     binary_search_mex  — fast binary search on sorted arrays
%     minmax_core_mex    — vectorized min/max downsampling kernel
%     lttb_core_mex      — LTTB triangle-area selection kernel
%
%   Safe to re-run — overwrites existing binaries. Reports success/failure
%   count. Failed compilations fall back to MATLAB implementations.
%
%   See also binary_search, minmax_downsample, lttb_downsample.

    rootDir = fileparts(mfilename('fullpath'));
    srcDir  = fullfile(rootDir, 'private', 'mex_src');
    outDir  = fullfile(rootDir, 'private');

    % Detect architecture (normalize Octave vs MATLAB differences)
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

    % Detect best available compiler
    % On MATLAB/macOS, always use system clang — MATLAB's mex injects
    % macOS-specific linker flags (-weak-lmx etc.) that GCC doesn't support.
    if exist('OCTAVE_VERSION', 'builtin')
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
        fprintf('Compiler: system default (clang — required for MATLAB mex on macOS)\n');
    end

    % Set optimization and SIMD flags
    switch arch
        case 'x86_64'
            % x86_64: try AVX2 first
            opt_flags = {'-O3', '-mavx2', '-mfma', '-ftree-vectorize', '-ffast-math'};
            fprintf('SIMD target: AVX2 + FMA\n');
        case 'arm64'
            % ARM64 (Apple Silicon / Linux ARM): NEON is default
            if ~isempty(compiler)
                opt_flags = {'-O3', '-mcpu=apple-m3', '-ftree-vectorize', '-ffast-math'};
            else
                opt_flags = {'-O3', '-ffast-math'};
            end
            fprintf('SIMD target: ARM NEON\n');
        otherwise
            opt_flags = {'-O3', '-ffast-math'};
            fprintf('SIMD target: scalar fallback\n');
    end

    % Common flags
    include_flag = ['-I' srcDir];

    % Files to compile: {source_name, output_name}
    mex_files = {
        'binary_search_mex.c',  'binary_search_mex'
        'minmax_core_mex.c',    'minmax_core_mex'
        'lttb_core_mex.c',      'lttb_core_mex'
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
            if strcmp(arch, 'x86_64') && ...
               any(contains(opt_flags, 'mavx2'))
                fprintf('  Retrying with SSE2 fallback ... ');
                try
                    sse_flags = {'-O3', '-msse2', '-ftree-vectorize', '-ffast-math'};
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
end


function compile_mex(src_file, out_name, outDir, include_flag, opt_flags, compiler)
%COMPILE_MEX Compile a single MEX file with the given flags.
%   compile_mex(src_file, out_name, outDir, include_flag, opt_flags, compiler)
%
%   Uses mkoctfile on Octave, mex on MATLAB. If compiler is non-empty,
%   overrides the default C compiler (CC environment variable on Octave,
%   CC= flag on MATLAB).
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
        cflags = ['CFLAGS="$CFLAGS ' strjoin(opt_flags, ' ') '"'];
        mex_args = {cflags, include_flag, '-outdir', outDir, '-output', out_name, src_file};
        if ~isempty(compiler)
            mex_args = [['CC=' compiler], mex_args];
        end
        mex(mex_args{:});
    end
end


function [gcc_path, gcc_name] = find_gcc()
%FIND_GCC Search for a real GCC installation (not Apple Clang).
%   [gcc_path, gcc_name] = find_gcc()
%
%   Checks Homebrew paths (/opt/homebrew/bin, /usr/local/bin) for
%   gcc-10 through gcc-15, then verifies the system gcc is from FSF.
%   Returns empty strings if no real GCC is found.
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
