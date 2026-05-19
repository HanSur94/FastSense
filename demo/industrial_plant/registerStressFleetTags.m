function tagKeys = registerStressFleetTags(rawDir, fleets)
%REGISTERSTRESSFLEETTAGS Register stress-test fleet tags into TagRegistry.
%   tagKeys = registerStressFleetTags(rawDir, fleets) registers one
%   SensorTag per (bank, slot) for each fleet, all reading from a shared
%   multi-column .dat file via RawSource.column = '<prefix>_<idx>'.
%
%   Returns a cellstr of all registered tag keys (so the writer can
%   iterate them).
%
%   This is what actually exercises PIPE-01 (K << N): for the 'large'
%   mode this registers 350 tags backed by 26 .dat files. After one
%   pipeline tick:
%     pipeline.LastFileStatCount   == 26 + (existing 10) = 36
%     pipeline.LastDispatchCount   == 350 + (existing 10) = 360
%     pipeline.LastTickDurationMs  -- shows real wall-clock cost
%
%   See also: stressFleets, run_demo, registerPlantTags.

    if nargin < 2 || isempty(fleets)
        tagKeys = {};
        return;
    end
    if ~ischar(rawDir) || isempty(rawDir)
        error('IndustrialPlant:invalidRawDir', ...
            'rawDir must be a non-empty char.');
    end

    tagKeys = {};
    for f = 1:numel(fleets)
        fleet = fleets(f);
        for b = 1:fleet.nBanks
            % Resolve filename: if filePat has a %d, format it; else use as-is.
            if any(fleet.filePat == '%')
                fname = sprintf(fleet.filePat, b - 1);
            else
                fname = fleet.filePat;
            end
            filePath = fullfile(rawDir, fname);

            for s = 1:fleet.nPerBank
                slotIdx = (b - 1) * fleet.nPerBank + (s - 1);
                key  = sprintf('%s.%03d', fleet.prefix, slotIdx);
                colName = sprintf('%s_%03d', fleet.prefix, slotIdx);
                colName = strrep(colName, '.', '_');

                rs = struct( ...
                    'file',   filePath, ...
                    'column', colName, ...
                    'format', '');

                tag = SensorTag(key, ...
                    'Name',      key, ...
                    'Units',     'unit', ...
                    'Labels',    {fleet.name}, ...
                    'RawSource', rs);
                TagRegistry.register(key, tag);
                tagKeys{end+1, 1} = key; %#ok<AGROW>
            end
        end
    end
end
