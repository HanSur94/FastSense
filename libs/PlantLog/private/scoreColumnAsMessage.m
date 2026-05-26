function ratio = scoreColumnAsMessage(colValues)
%SCORECOLUMNASMESSAGE Return text-ness ratio for a column over first 50 rows.
%   A value is considered text-like when char/string non-empty AND not
%   parseable as a number. Returns #text-like / #sampled in [0, 1].
%
%   Inputs:
%     colValues -- a table column (string array, cell of char, or numeric)
%
%   Outputs:
%     ratio -- scalar double in [0, 1]: text-ness ratio over the sample.
%              Numeric columns short-circuit to ratio = 0.
%
%   This function is a private helper for PlantLog.
%
%   See also PlantLogReader, scoreColumnAsTimestamp.

    if isempty(colValues)
        ratio = 0;
        return;
    end
    sampleSize = min(50, numel(colValues));
    % Coerce sample to cellstr
    if isstring(colValues); colValues = cellstr(colValues); end
    if isnumeric(colValues)
        % Numeric columns are not text-like at all
        ratio = 0;
        return;
    end
    if ~iscell(colValues); colValues = cellstr(colValues); end
    sample = colValues(1:sampleSize);

    nText = 0;
    for k = 1:sampleSize
        v = strtrim(char(sample{k}));
        if isempty(v); continue; end
        % Treat numeric-looking strings as NOT text
        asNum = str2double(v);
        if ~isnan(asNum); continue; end
        nText = nText + 1;
    end
    ratio = nText / sampleSize;
end
