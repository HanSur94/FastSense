function meta = loadMetaStruct(filepath, vars)
%LOADMETASTRUCT Load a metadata struct from a .mat file.
%   meta = loadMetaStruct(filepath, vars)
%
%   Loads a .mat file and extracts a timestamp field ('datenum' or
%   'datetime') plus the specified variable names into a flat struct
%   suitable for FastPlot metadata lookup.
%
%   Inputs:
%     filepath — path to .mat file (must contain 'datenum' or 'datetime')
%     vars     — cell array of additional variable names to extract
%
%   Output:
%     meta — struct with fields: datenum, plus each found var from vars
%            Returns [] if file missing, unreadable, or has no timestamp.
%
%   See also FastPlot.lookupMetadata, FastPlot.startLive.

    meta = [];
    if isempty(filepath) || isempty(vars)
        return;
    end
    if ~exist(filepath, 'file')
        return;
    end
    try
        data = load(filepath);
        m = struct();
        if isfield(data, 'datenum')
            m.datenum = data.datenum;
        elseif isfield(data, 'datetime')
            m.datenum = data.datetime;
        else
            return;
        end
        for i = 1:numel(vars)
            varName = vars{i};
            if isfield(data, varName)
                m.(varName) = data.(varName);
            end
        end
        meta = m;
    catch
    end
end
