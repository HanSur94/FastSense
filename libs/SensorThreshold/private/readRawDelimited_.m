function out = readRawDelimited_(path)
    %READRAWDELIMITED_ Pure-MATLAB/Octave delimited-text parser for the Tag pipeline.
    %   out = readRawDelimited_(path) parses path using one of four candidate
    %   delimiters (comma, tab, semicolon, whitespace), auto-detects header
    %   presence, and returns:
    %
    %     out.headers   - 1xN cellstr of column names; {} if no header
    %     out.data      - MxN numeric matrix OR MxN cell of char (fallback)
    %     out.delimiter - char, the selected delimiter
    %     out.hasHeader - logical
    %
    %   Errors:
    %     TagPipeline:fileNotReadable   - file missing or fopen failed
    %     TagPipeline:emptyFile         - 0 data rows after header skip
    %     TagPipeline:delimiterAmbiguous - no candidate produced consistent column counts
    %
    %   Implementation notes (Phase 1012, D-01 + D-02 + D-19):
    %     - Uses ONLY textscan + fopen/fgetl/strsplit (Octave 7+ parity).
    %     - NEVER calls MATLAB-only high-level import APIs (Octave-incompatible).
    %     - Numeric parse is tried first; on textscan failure (or when the first
    %       row fails to coerce to %f) the parse falls back to '%s' format so
    %       cellstr Y (StateTag mode column) round-trips.
    %     - Internal helpers sniffDelimiter_ and detectHeader_ are local
    %       sub-functions in THIS file (merged per Pitfall 9 budget).
    %
    %   See also: selectTimeAndValue_, writeTagMat_, readRawDelimitedForTest_.

    if ~exist(path, 'file')
        error('TagPipeline:fileNotReadable', 'File not found: %s', path);
    end

    % Step 1: delimiter sniff over first 5 non-empty lines.
    delim = sniffDelimiter_(path);

    % Step 2: open file; read first two lines for header detection.
    fid = fopen(path, 'r');
    if fid == -1
        error('TagPipeline:fileNotReadable', 'Cannot open: %s', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    firstLine = fgetl(fid);
    if ~ischar(firstLine)
        error('TagPipeline:emptyFile', 'File is empty: %s', path);
    end
    secondLine = fgetl(fid);  % -1 if only a single line so far
    hasHeader = detectHeader_(firstLine, secondLine, delim);

    headers = {};
    if hasHeader
        headers = splitByDelim_(firstLine, delim);
    end

    nCols = numel(splitByDelim_(firstLine, delim));
    if nCols < 1
        error('TagPipeline:emptyFile', 'File has no columns: %s', path);
    end

    % Step 3: count expected data rows (non-empty lines after any header
    % row). This lets us detect silent numeric-parse truncation caused by
    % non-numeric cell content (e.g., a cellstr state column) without
    % relying on textscan raising an error.
    frewind(fid);
    expectedRows = countDataRows_(fid, hasHeader);
    frewind(fid);

    skipN = double(hasHeader);
    fmtSpec = repmat('%f', 1, nCols);

    [data, asText] = tryParse_(fid, fmtSpec, delim, skipN);

    % Fall back to text parse if numeric parse failed OR produced fewer
    % rows than the file contains (indicates a non-numeric column).
    if asText || isempty(data) || size(data, 1) < expectedRows
        frewind(fid);
        fmtSpec = repmat('%s', 1, nCols);
        [data, ~] = tryParse_(fid, fmtSpec, delim, skipN);
        if isempty(data) || size(data, 1) == 0
            error('TagPipeline:emptyFile', 'No data rows after header skip: %s', path);
        end
    end

    if isempty(data) || size(data, 1) == 0
        error('TagPipeline:emptyFile', 'No data rows after header skip: %s', path);
    end

    out = struct('headers', {headers}, 'data', {data}, ...
                 'delimiter', delim, 'hasHeader', hasHeader);
end

function n = countDataRows_(fid, hasHeader)
    %COUNTDATAROWS_ Count non-empty data rows (skipping a header if present).
    n = 0;
    first = true;
    while true
        L = fgetl(fid);
        if ~ischar(L), break; end
        if isempty(strtrim(L))
            first = false;
            continue;
        end
        if first && hasHeader
            first = false;
            continue;
        end
        first = false;
        n = n + 1;
    end
end

function [data, asText] = tryParse_(fid, fmtSpec, delim, skipN)
    %TRYPARSE_ Run textscan with the given format spec.
    %   Returns data as a matrix/cell and asText=true if the caller should
    %   retry with %s (numeric parse produced zero rows).
    data = [];
    asText = false;
    try
        C = textscan(fid, fmtSpec, 'Delimiter', delim, ...
            'HeaderLines', skipN, 'CollectOutput', true);
        if isempty(C) || isempty(C{1}) || size(C{1}, 1) == 0
            asText = true;
            return;
        end
        data = C{1};
    catch
        asText = true;
    end
end

function delim = sniffDelimiter_(path)
    %SNIFFDELIMITER_ Pick the delimiter that produces consistent column counts.
    %   Candidates (priority order): comma, tab, semicolon, whitespace.
    %   For the whitespace candidate, runs of whitespace are collapsed
    %   (strsplit default) and the column count reflects token count after
    %   trimming.
    candidates = {',', char(9), ';', ' '};
    maxLines = 5;

    fid = fopen(path, 'r');
    if fid == -1
        error('TagPipeline:fileNotReadable', 'Cannot open: %s', path);
    end
    cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

    lines = {};
    while numel(lines) < maxLines
        L = fgetl(fid);
        if ~ischar(L), break; end
        if isempty(strtrim(L)), continue; end
        lines{end+1} = L; %#ok<AGROW>
    end

    if isempty(lines)
        error('TagPipeline:emptyFile', 'File has no non-empty lines: %s', path);
    end

    bestDelim = '';
    bestScore = -1;
    for k = 1:numel(candidates)
        d = candidates{k};
        counts = zeros(1, numel(lines));
        for j = 1:numel(lines)
            parts = splitByDelim_(lines{j}, d);
            counts(j) = numel(parts);
        end
        if all(counts == counts(1)) && counts(1) >= 2
            % Prefer the delimiter that produces the MOST columns (breaks
            % tie between comma and whitespace on purely-numeric tall files).
            if counts(1) > bestScore
                bestScore = counts(1);
                bestDelim = d;
            end
        end
    end

    if isempty(bestDelim)
        error('TagPipeline:delimiterAmbiguous', ...
            'Could not determine delimiter for: %s', path);
    end
    delim = bestDelim;
end

function tf = detectHeader_(firstLine, secondLine, delim)
    %DETECTHEADER_ Heuristic: header if row 1 has ANY non-numeric token.
    %   If the second line exists and every token of row 1 is numeric,
    %   there is no header. Otherwise the file is treated as having a
    %   header row. Handles the header-only case (secondLine == -1) by
    %   still checking row 1's token types. %#ok<INUSD>
    parts1 = splitByDelim_(firstLine, delim);
    anyNonNumeric = false;
    for i = 1:numel(parts1)
        tok = strtrim(parts1{i});
        if isempty(tok)
            continue;
        end
        if isnan(str2double(tok))
            anyNonNumeric = true;
            break;
        end
    end
    if ~ischar(secondLine)
        tf = anyNonNumeric;
        return;
    end
    tf = anyNonNumeric;
end

function parts = splitByDelim_(line, delim)
    %SPLITBYDELIM_ Split line by delim. Collapses runs of whitespace when
    %   delim is a space, otherwise delegates to strsplit.
    if isequal(delim, ' ')
        parts = strsplit(strtrim(line));
    else
        parts = strsplit(line, delim);
    end
end
