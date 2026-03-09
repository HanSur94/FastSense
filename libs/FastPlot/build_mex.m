function build_mex()
%BUILD_MEX Compile FastPlot MEX files with platform-appropriate SIMD flags.
%   build_mex()
%
%   Detects CPU architecture and best available compiler, sets flags for
%   AVX2/SSE2/NEON, and compiles all MEX source files from private/mex_src/
%   into private/.
%
%   Compiler priority: GCC (better auto-vectorization) > Clang > default.
%   Safe to re-run — overwrites existing MEX binaries.

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
        fprintf('Compiler: MATLAB default (Xcode Clang)\n');
    end

    % Set optimization and SIMD flags
    switch arch
        case 'x86_64'
            opt_flags = {'-O3', '-mavx2', '-mfma', '-ftree-vectorize', '-ffast-math'};
            fprintf('SIMD target: AVX2 + FMA\n');
        case 'arm64'
            if isOctave && ~isempty(compiler)
                % GCC on ARM needs explicit CPU target
                opt_flags = {'-O3', '-mcpu=apple-m3', '-ftree-vectorize', '-ffast-math'};
            else
                % Clang on Apple Silicon: NEON enabled by default
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
        'binary_search_mex.c',          'binary_search_mex'
        'minmax_core_mex.c',            'minmax_core_mex'
        'lttb_core_mex.c',              'lttb_core_mex'
        'compute_violations_mex.c',     'compute_violations_mex'
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

    % Copy shared MEX files to SensorThreshold/private so they're accessible there
    sensorPrivDir = fullfile(rootDir, '..', 'SensorThreshold', 'private');
    copy_mex_to(outDir, sensorPrivDir, 'compute_violations_mex');
end


function compile_mex(src_file, out_name, outDir, include_flag, opt_flags, compiler)
%COMPILE_MEX Compile a single MEX file, using Octave mkoctfile or MATLAB mex.
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


function copy_mex_to(srcDir, destDir, name)
%COPY_MEX_TO Copy a compiled MEX file to another directory.
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
%FIND_GCC Search for GCC (not Apple Clang disguised as gcc).
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
