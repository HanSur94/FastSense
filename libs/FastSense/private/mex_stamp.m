function h = mex_stamp(root)
%MEX_STAMP Compute a deterministic fingerprint of all MEX source inputs.
%   H = MEX_STAMP(ROOT) returns a plain-text token that changes iff any
%   file under libs/FastSense/private/mex_src/**/*.c, any .h in that dir,
%   or libs/FastSense/build_mex.m or libs/FastSense/mksqlite.c has changed.
%
%   Format is one of:
%     'sha256:<64-hex>'   — computed via system sha256sum / shasum / certutil
%     'fprint:<tokens>'   — pure-MATLAB size+byte-sampling fallback
%
%   The stamp is reproducible across MATLAB and Octave on the same checkout.
%   Two calls on an identical source tree return equal strings.
%
%   Inputs:
%     ROOT  char — absolute path to the repository root (parent of install.m)
%
%   Output:
%     H     char row vector — non-empty fingerprint string

    src_dir   = fullfile(root, 'libs', 'FastSense', 'private', 'mex_src');
    build_mex = fullfile(root, 'libs', 'FastSense', 'build_mex.m');
    mksqlite  = fullfile(root, 'libs', 'FastSense', 'mksqlite.c');

    % Collect files: sorted *.c and *.h in mex_src/, then build_mex.m,
    % then mksqlite.c (if it exists).
    c_files = sort_names_(dir(fullfile(src_dir, '*.c')));
    h_files = sort_names_(dir(fullfile(src_dir, '*.h')));
    src_files = [c_files; h_files];

    extra = {};
    if exist(build_mex, 'file') == 2
        extra{end+1} = build_mex;
    end
    if exist(mksqlite, 'file') == 2
        extra{end+1} = mksqlite;
    end

    all_paths = cell(numel(src_files) + numel(extra), 1);
    for i = 1:numel(src_files)
        all_paths{i} = fullfile(src_files(i).folder, src_files(i).name);
    end
    for i = 1:numel(extra)
        all_paths{numel(src_files) + i} = extra{i};
    end

    % Try SHA-256 via system command first (deterministic, content-based).
    h = try_sha256_(all_paths);
    if ~isempty(h)
        return;
    end

    % Fallback: pure-MATLAB fingerprint using file sizes and byte sampling.
    h = fprint_fallback_(all_paths);
end

% -------------------------------------------------------------------------

function h = try_sha256_(paths)
%TRY_SHA256_ Attempt to hash file contents via system sha256sum/shasum.
%   Returns 'sha256:<hex>' on success, '' on failure.

    if isempty(paths)
        h = 'sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
        return;
    end

    % Build a concatenated temp file and hash it (cross-platform, avoids
    % quoting issues with long argument lists).
    tmp = [tempname(), '.bin'];
    cleanup = onCleanup(@() delete_if_exists_(tmp));

    try
        fid_out = fopen(tmp, 'w');
        if fid_out < 0
            h = '';
            return;
        end
        for i = 1:numel(paths)
            fid_in = fopen(paths{i}, 'r');
            if fid_in < 0
                fclose(fid_out);
                h = '';
                return;
            end
            data = fread(fid_in, inf, 'uint8=>uint8');
            fclose(fid_in);
            fwrite(fid_out, data, 'uint8');
        end
        fclose(fid_out);
    catch
        h = '';
        return;
    end

    % Try platform-appropriate sha256 command.
    if ispc()
        cmd = sprintf('certutil -hashfile "%s" SHA256 2>nul', tmp);
    elseif ismac()
        cmd = sprintf('shasum -a 256 "%s" 2>/dev/null', tmp);
    else
        cmd = sprintf('sha256sum "%s" 2>/dev/null', tmp);
    end

    try
        [status, out] = system(cmd);
    catch
        h = '';
        return;
    end

    if status ~= 0
        h = '';
        return;
    end

    % Extract 64-hex chars from output.
    tok = regexp(out, '[0-9a-fA-F]{64}', 'match', 'once');
    if isempty(tok)
        h = '';
        return;
    end

    h = ['sha256:' lower(tok)];
end

% -------------------------------------------------------------------------

function h = fprint_fallback_(paths)
%FPRINT_FALLBACK_ Pure-MATLAB fingerprint via size + byte sampling.
%   Reads first and last 64 bytes of each file in hex.
%   Prefix: 'fprint:'.  Does not depend on mtime.

    parts = cell(numel(paths), 1);
    for i = 1:numel(paths)
        [~, fname, fext] = fileparts(paths{i});
        name = [fname fext];
        info = dir(paths{i});
        if isempty(info)
            parts{i} = sprintf('%s:0::', name);
            continue;
        end
        nbytes = info(1).bytes;
        fid = fopen(paths{i}, 'r');
        if fid < 0
            parts{i} = sprintf('%s:%d::', name, nbytes);
            continue;
        end
        first64 = fread(fid, 64, 'uint8=>uint8');
        try
            fseek(fid, max(0, nbytes - 64), 'bof');
        catch
        end
        last64 = fread(fid, 64, 'uint8=>uint8');
        fclose(fid);
        parts{i} = sprintf('%s:%d:%s:%s', name, nbytes, ...
            bytes_to_hex_(first64), bytes_to_hex_(last64));
    end

    h = ['fprint:' strjoin(parts, '|')];
end

% -------------------------------------------------------------------------

function s = bytes_to_hex_(data)
%BYTES_TO_HEX_ Convert uint8 array to lowercase hex string.
    if isempty(data)
        s = '';
        return;
    end
    s = sprintf('%02x', data);
end

% -------------------------------------------------------------------------

function sorted = sort_names_(d)
%SORT_NAMES_ Sort a dir() struct array by name field.
    if isempty(d)
        sorted = d;
        return;
    end
    names = {d.name};
    [~, idx] = sort(names);
    sorted = d(idx);
end

% -------------------------------------------------------------------------

function delete_if_exists_(p)
%DELETE_IF_EXISTS_ Delete a file silently if it exists.
    if exist(p, 'file') == 2
        delete(p);
    end
end
