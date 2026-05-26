function fn = sanitizeFieldName(raw)
%SANITIZEFIELDNAME Convert a column header to a valid MATLAB identifier.
%   On MATLAB R2020b+: uses matlab.lang.makeValidName.
%   On Octave: falls back to a regex-based scrub that achieves the same
%   contract (alphanumeric + underscore, leading letter or 'x' prefix).
%
%   Examples:
%     'Machine ID'   -> 'MachineID'
%     '1st Column'   -> 'x1stColumn'
%     'temp (degC)'  -> 'tempdegC'  (parens stripped)
%
%   Inputs:
%     raw -- char vector or string scalar (column header from a table)
%
%   Outputs:
%     fn -- char vector that is a legal MATLAB struct field name
%
%   This function is a private helper for PlantLog.
%
%   See also PlantLogReader.

    if isstring(raw); raw = char(raw); end
    if ~ischar(raw) || isempty(raw)
        fn = 'Column1';
        return;
    end

    % Prefer matlab.lang.makeValidName when available (MATLAB; some Octave builds).
    if exist('matlab.lang.makeValidName', 'file') == 2 || ...
            exist('matlab.lang.makeValidName', 'class') == 8
        try
            fn = matlab.lang.makeValidName(raw);
            return;
        catch
            % fall through to scrub
        end
    end

    % Pure-MATLAB / Octave fallback scrub
    scrubbed = regexprep(raw, '[^A-Za-z0-9_]', '');
    if isempty(scrubbed)
        fn = 'Column1';
        return;
    end
    % Prepend 'x' if the first char is a digit
    if scrubbed(1) >= '0' && scrubbed(1) <= '9'
        scrubbed = ['x' scrubbed];
    end
    fn = scrubbed;
end
