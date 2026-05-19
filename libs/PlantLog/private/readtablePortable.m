function T = readtablePortable(filePath)
%READTABLEPORTABLE Read a CSV or XLSX file into a table, with cross-runtime gating.
%   T = readtablePortable(filePath) returns a MATLAB table for the file.
%   Throws PlantLogReader:fileNotFound when the file does not exist,
%   PlantLogReader:unsupportedFormat for anything other than .csv/.xlsx,
%   and PlantLogReader:xlsxUnavailable when XLSX is requested on a runtime
%   that lacks the Excel reader.
%
%   CSV: readtable(filePath, 'TextType','string')  -- works on MATLAB and Octave.
%   XLSX: readtable(filePath)  -- gated on usejava('jvm') && exist('xlsread','file')
%         when running on Octave. MATLAB picks the engine automatically.
%
%   Inputs:
%     filePath -- char vector or string scalar (absolute or relative path)
%
%   Outputs:
%     T -- MATLAB table
%
%   Error namespace:
%     PlantLogReader:invalidInput       -- filePath is not char/string or empty
%     PlantLogReader:fileNotFound       -- file does not exist
%     PlantLogReader:unsupportedFormat  -- extension not .csv / .xlsx
%     PlantLogReader:xlsxUnavailable    -- Octave runtime without JVM + xlsread
%
%   This function is a private helper for PlantLog.
%
%   See also PlantLogReader, readtable.

    if isstring(filePath); filePath = char(filePath); end
    if ~ischar(filePath) || isempty(filePath)
        error('PlantLogReader:invalidInput', ...
            'filePath must be a non-empty char/string.');
    end
    if exist(filePath, 'file') ~= 2
        error('PlantLogReader:fileNotFound', ...
            'File not found: %s', filePath);
    end

    [~, ~, extRaw] = fileparts(filePath);
    ext = lower(extRaw);
    switch ext
        case '.csv'
            % readtable supports 'TextType' on MATLAB R2020b+ and recent Octave (>=8).
            % On older Octave, fall back to plain readtable.
            try
                T = readtable(filePath, 'TextType', 'string');
            catch
                T = readtable(filePath);
            end
        case '.xlsx'
            if exist('OCTAVE_VERSION', 'builtin')
                % Octave: gate on usejava('jvm') && exist('xlsread','file')
                jvmOK  = false;
                xlsOK  = false;
                try
                    jvmOK = usejava('jvm');
                catch
                end
                try
                    xlsOK = exist('xlsread', 'file') > 0;
                catch
                end
                if ~(jvmOK && xlsOK)
                    error('PlantLogReader:xlsxUnavailable', ...
                        'XLSX read not available on this Octave runtime (needs JVM + xlsread).');
                end
            end
            T = readtable(filePath);
        otherwise
            error('PlantLogReader:unsupportedFormat', ...
                'Unsupported file extension: %s (only .csv and .xlsx are supported).', extRaw);
    end
end
