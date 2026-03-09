function meta = loadMetaStruct(filepath, vars)
%LOADMETASTRUCT Load a metadata struct from a .mat file.
%   meta = LOADMETASTRUCT(filepath, vars) loads the specified .mat file,
%   extracts a timestamp vector (from a field named 'datenum' or
%   'datetime') and the requested variable names, and returns them in a
%   flat struct suitable for FastPlot metadata lookup and live-data feeds.
%
%   This function is a private helper for FastPlot.
%
%   Inputs:
%     filepath — char, path to a .mat file. The file must contain at least
%                one timestamp field named 'datenum' or 'datetime'.
%     vars     — cell array of char, additional variable names to extract
%                from the .mat file alongside the timestamp
%
%   Outputs:
%     meta — scalar struct with fields:
%              .datenum  — timestamp vector (from 'datenum' or 'datetime')
%              .<var_i>  — one field per found variable name in vars
%            Returns [] (empty double) if any of the following hold:
%              - filepath or vars is empty
%              - the file does not exist
%              - the file cannot be loaded (corrupt / permissions)
%              - neither 'datenum' nor 'datetime' field is present
%
%   Variables listed in vars that are absent from the file are silently
%   skipped (no error or warning).
%
%   See also FastPlot.lookupMetadata, FastPlot.startLive.

    meta = [];

    % Guard: nothing to do if inputs are empty
    if isempty(filepath) || isempty(vars)
        return;
    end

    % Guard: file must exist on disk
    if ~exist(filepath, 'file')
        return;
    end

    try
        data = load(filepath);
        m = struct();

        % Require a timestamp field — try 'datenum' first, then 'datetime'
        if isfield(data, 'datenum')
            m.datenum = data.datenum;
        elseif isfield(data, 'datetime')
            % Normalize: store under the canonical name 'datenum'
            m.datenum = data.datetime;
        else
            % No usable timestamp — cannot build a valid metadata struct
            return;
        end

        % Extract each requested variable if present in the file
        for i = 1:numel(vars)
            varName = vars{i};
            if isfield(data, varName)
                m.(varName) = data.(varName);
            end
        end

        meta = m;
    catch
        % File corrupt or unreadable — return []
    end
end
