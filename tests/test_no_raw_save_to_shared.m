function test_no_raw_save_to_shared()
%TEST_NO_RAW_SAVE_TO_SHARED CI grep guard for CONC-03.
%
%   Scans libs/ for raw save() calls to shared paths. Any match is a
%   violation of CONC-03 ("Every shared-file write goes through
%   AtomicWriter; CI lint forbids raw save() to shared paths").
%
%   Exempt: libs/Concurrency/* (these implement the safe writer).
%   Exempt: comment lines.
%   Exempt: save() calls inside an AtomicWriter.write callback.

    here     = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(here);
    libsDir  = fullfile(repoRoot, 'libs');

    if ~isfolder(libsDir)
        error('test_no_raw_save_to_shared:noLibs', 'libs/ not found at %s', libsDir);
    end

    files = local_walk_(libsDir);
    violations = {};

    % Patterns that indicate a save() targeted at a shared path
    patterns = { ...
        'save\s*\(\s*[^,)]*[Ss]haredRoot', ...
        'save\s*\(\s*[^,)]*sharedRoot', ...
        'save\s*\(\s*[^,)]*FASTSENSE_SHARED_ROOT' ...
    };

    for k = 1:numel(files)
        f = files{k};
        % Exempt: libs/Concurrency/* (AtomicWriter lives here)
        if ~isempty(strfind(f, fullfile('libs', 'Concurrency'))) %#ok<STREMP>
            continue;
        end
        try
            txt = fileread(f);
        catch
            continue;
        end
        lines = regexp(txt, '\r?\n', 'split');
        for li = 1:numel(lines)
            L = lines{li};
            Ltrim = strtrim(L);
            if isempty(Ltrim) || Ltrim(1) == '%'
                continue;
            end
            if ~isempty(strfind(L, 'AtomicWriter.write(')) %#ok<STREMP>
                continue;
            end
            for p = 1:numel(patterns)
                if ~isempty(regexp(L, patterns{p}, 'once'))
                    violations{end+1} = sprintf('%s:%d: %s', f, li, strtrim(L)); %#ok<AGROW>
                    break;
                end
            end
        end
    end

    nPassed = 0; nFailed = 0;
    if isempty(violations)
        nPassed = 1;
        fprintf('    1 file-scan test passed (zero raw save() to shared paths in libs/).\n');
    else
        nFailed = 1;
        fprintf(2, 'CONC-03 VIOLATION: %d raw save() call(s) to shared paths in libs/:\n', numel(violations));
        for v = 1:numel(violations)
            fprintf(2, '  %s\n', violations{v});
        end
        error('test_no_raw_save_to_shared:violations', ...
            '%d CONC-03 violation(s) — use AtomicWriter.write instead.', numel(violations));
    end
    fprintf('    %d/%d tests passed.\n', nPassed, nPassed + nFailed);
end

function out = local_walk_(rootDir)
%LOCAL_WALK_ Recursively collect all .m files under rootDir.
%   Uses regexp('\.m$') for file-extension match (not endsWith — endsWith
%   was introduced in Octave 7.1; this codebase targets Octave 7+ without
%   a minor-version pin and the regex form is the established pattern in
%   other tests/test_*.m files).
    out = {};
    d = dir(rootDir);
    for i = 1:numel(d)
        if strcmp(d(i).name, '.') || strcmp(d(i).name, '..')
            continue;
        end
        full = fullfile(d(i).folder, d(i).name);
        if d(i).isdir
            out = [out, local_walk_(full)]; %#ok<AGROW>
        elseif ~isempty(regexp(d(i).name, '\.m$', 'once'))
            out{end+1} = full; %#ok<AGROW>
        end
    end
end
