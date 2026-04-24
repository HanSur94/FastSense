function [x, y] = selectTimeAndValue_(parsed, rawSource)
    %SELECTTIMEANDVALUE_ Dispatch wide vs tall and return (X, Y) vectors.
    %   [x, y] = selectTimeAndValue_(parsed, rawSource)
    %
    %   parsed    - struct from readRawDelimited_ with fields:
    %                 headers (1xN cellstr or {}), data (MxN numeric or cell)
    %   rawSource - struct with fields file (unused here), column, format
    %
    %   Returns column vectors x, y sliced from parsed.data. If parsed.data
    %   is a cell (StateTag mode column), the value column is returned as a
    %   cellstr; otherwise as numeric.
    %
    %   Errors (Phase 1012, D-04 + D-06 + D-19):
    %     TagPipeline:insufficientColumns     - <2 columns in parsed
    %     TagPipeline:missingColumn           - wide dispatch, named column not found
    %                                            (emitted in 2 sites: no-column-provided
    %                                            and column-not-in-headers)
    %     TagPipeline:noHeadersForNamedColumn - wide dispatch, file has no header row
    %
    %   Time-column resolution (order):
    %     1. Header name matches any of {time, t, timestamp, datenum, datetime}
    %        (case-insensitive)
    %     2. Fallback: column 1
    %
    %   See also: readRawDelimited_, writeTagMat_.

    nCols = size(parsed.data, 2);

    if nCols < 2
        error('TagPipeline:insufficientColumns', ...
            'Need >=2 columns, got %d', nCols);
    end

    col = '';
    if isfield(rawSource, 'column')
        col = rawSource.column;
    end

    % Tall path: exactly 2 cols AND no named column -> col1=time, col2=value.
    if nCols == 2 && isempty(col)
        x = getCol_(parsed.data, 1);
        y = getCol_(parsed.data, 2);
        return;
    end

    % Wide path: column name is required.
    if isempty(col)
        error('TagPipeline:missingColumn', ...
            'Wide raw file (%d cols) requires RawSource.column', nCols);
    end
    if isempty(parsed.headers)
        error('TagPipeline:noHeadersForNamedColumn', ...
            'Cannot resolve column ''%s'' - file has no header row', col);
    end

    vIdx = find(strcmpi(parsed.headers, col), 1);
    if isempty(vIdx)
        error('TagPipeline:missingColumn', ...
            'Column ''%s'' not found. Available: %s', ...
            col, strjoin(parsed.headers, ', '));
    end

    % Time column: match by name, else column 1.
    timeNames = {'time', 't', 'timestamp', 'datenum', 'datetime'};
    tIdx = [];
    for k = 1:numel(timeNames)
        m = find(strcmpi(parsed.headers, timeNames{k}), 1);
        if ~isempty(m)
            tIdx = m;
            break;
        end
    end
    if isempty(tIdx)
        tIdx = 1;
    end

    x = getCol_(parsed.data, tIdx);
    y = getCol_(parsed.data, vIdx);
end

function v = getCol_(data, idx)
    %GETCOL_ Return column idx as a column vector (numeric or cellstr).
    %   Numeric matrices slice directly. Cell matrices attempt str2double;
    %   if that yields non-empty NaNs (non-numeric content), the raw
    %   cellstr is returned to preserve StateTag mode-column semantics.
    if iscell(data)
        raw = data(:, idx);
        nums = str2double(raw);
        % Any NaN that came from a non-empty string means the column is
        % text; keep as cellstr.
        nonEmptyMask = ~cellfun(@isempty, raw);
        if all(~isnan(nums) | ~nonEmptyMask)
            v = nums;
        else
            v = raw;
        end
    else
        v = data(:, idx);
    end
end
