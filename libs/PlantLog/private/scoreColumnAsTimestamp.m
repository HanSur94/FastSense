function ratio = scoreColumnAsTimestamp(colValues)
%SCORECOLUMNASTIMESTAMP Return parse-success ratio for a column of values.
%   Samples first 50 rows of colValues (or all rows if fewer), runs
%   parseTimestampLadder, returns the resulting successRatio. Pure helper
%   for the timestamp-column auto-detect step.
%
%   Inputs:
%     colValues -- a table column (string array, cell of char, or numeric)
%
%   Outputs:
%     ratio -- scalar double in [0, 1]: parse-success ratio over the sample
%
%   This function is a private helper for PlantLog.
%
%   See also parseTimestampLadder, PlantLogReader.

    if isempty(colValues)
        ratio = 0;
        return;
    end
    sampleSize = min(50, numel(colValues));
    sample = colValues(1:sampleSize);
    [~, ratio] = parseTimestampLadder(sample);
end
