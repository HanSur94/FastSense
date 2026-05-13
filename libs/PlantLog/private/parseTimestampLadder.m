function [tsOut, successRatio] = parseTimestampLadder(values, formatHint)
%PARSETIMESTAMPLADDER Parse a column of values to datenums via a format ladder.
%   [tsOut, successRatio] = parseTimestampLadder(values) tries each format
%   in the ladder against every element of `values`; the format with the
%   highest count of successful parses wins. NaN is returned for elements
%   that no format parses.
%
%   [tsOut, successRatio] = parseTimestampLadder(values, formatHint) uses
%   the given format exclusively (no ladder).
%
%   Inputs:
%     values     -- string array, cell of char, or numeric column (numeric
%                   passes through as-is when already datenum-like)
%     formatHint -- (optional) char/string; '' means use ladder
%
%   Outputs:
%     tsOut        -- Nx1 double (datenums; NaN for unparseable)
%     successRatio -- scalar double in [0, 1]: #parsed / #total
%
%   Format ladder (tried in order, first that parses everything wins;
%   otherwise the format with the highest success ratio wins):
%     1. 'yyyy-MM-dd HH:mm:ss'      ISO 8601 with space separator
%     2. 'yyyy-MM-dd''T''HH:mm:ss'  ISO 8601 with T separator
%     3. 'dd.MM.yyyy HH:mm:ss'      EU industrial
%     4. 'MM/dd/yyyy HH:mm'         US short
%     5. 'yyyy-MM-dd'               ISO date-only
%     6. 'dd.MM.yyyy'               EU date-only
%     7. 'MM/dd/yyyy'               US date-only
%
%   Implementation requirements:
%     - Convert input to a cell array of char (handle string array, cell,
%       numeric coerced via num2str row-by-row).
%     - Numeric input that already looks like datenum (finite, > 1e5)
%       passes through unchanged with ratio = (#non-NaN / total).
%     - For each format in the ladder, try datenum(val, format) inside
%       try/catch; success when no error AND result is finite.
%     - Return the FIRST format that achieves ratio == 1.0; otherwise
%       pick the format with max ratio (ties: earlier format wins).
%     - When formatHint is provided and non-empty, skip the ladder.
%
%   Error namespace: PlantLogReader:invalidInput (non-empty values arg
%   that is not string/cell/numeric).
%
%   This function is a private helper for PlantLog.
%
%   See also PlantLogReader, scoreColumnAsTimestamp.

    % Coerce input to cellstr
    if isnumeric(values)
        % Already datenum-like: validate finite, return mask
        tsOut = double(values(:));
        successRatio = sum(isfinite(tsOut)) / max(numel(tsOut), 1);
        tsOut(~isfinite(tsOut)) = NaN;
        return;
    end
    if isstring(values); values = cellstr(values); end
    if ischar(values);   values = cellstr(values); end
    if ~iscell(values)
        error('PlantLogReader:invalidInput', ...
            'parseTimestampLadder: values must be string/cell/numeric; got %s.', class(values));
    end
    nVals = numel(values);
    if nVals == 0
        tsOut = NaN(0, 1); successRatio = 0; return;  % preserve column shape for downstream
    end

    % Pre-clean: trim, treat empty strings as missing
    cleaned = cellfun(@(s) strtrim(char(s)), values(:), 'UniformOutput', false);
    isEmptyStr = cellfun(@isempty, cleaned);

    % Ladder
    ladder = {'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd''T''HH:mm:ss', ...
              'dd.MM.yyyy HH:mm:ss', 'MM/dd/yyyy HH:mm', ...
              'yyyy-MM-dd', 'dd.MM.yyyy', 'MM/dd/yyyy'};

    if nargin >= 2 && ~isempty(formatHint)
        if isstring(formatHint); formatHint = char(formatHint); end
        formats = {formatHint};
    else
        formats = ladder;
    end

    bestTs = NaN(nVals, 1);
    bestRatio = -1;
    for fi = 1:numel(formats)
        fmt = formats{fi};
        tsTry = NaN(nVals, 1);
        for k = 1:nVals
            if isEmptyStr(k); continue; end
            try
                v = datenum(cleaned{k}, fmt); %#ok<DATNM>
                if isfinite(v)
                    tsTry(k) = v;
                end
            catch
                % parse failed; leave NaN
            end
        end
        nOK = sum(isfinite(tsTry));
        ratio = nOK / nVals;
        if ratio > bestRatio
            bestTs = tsTry;
            bestRatio = ratio;
        end
        if ratio == 1.0
            break;  % perfect -- no need to try later ladder formats
        end
    end
    tsOut = bestTs;
    successRatio = bestRatio;
end
