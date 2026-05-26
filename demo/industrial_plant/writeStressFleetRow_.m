function writeStressFleetRow_(rawDir, fleets, nowTime, tRel)
%WRITESTRESSFLEETROW_ Append one tick's worth of fleet data to shared .dat files.
%   writeStressFleetRow_(rawDir, fleets, nowTime, tRel) writes a single
%   timestamped row to each fleet bank file. Each row has the time
%   followed by nPerBank column values.
%
%   Header row (written on first append):
%     time,<prefix>_000,<prefix>_001,...,<prefix>_NNN
%
%   Data row format:
%     <datenum>,<v0>,<v1>,...,<vN>
%
%   This is what makes file-major dispatch testable: ONE stat + ONE parse
%   produces N values for N tags.
%
%   See also: stressFleets, registerStressFleetTags.

    if isempty(fleets)
        return;
    end

    for f = 1:numel(fleets)
        fleet = fleets(f);

        for b = 1:fleet.nBanks
            % Resolve filename
            if any(fleet.filePat == '%')
                fname = sprintf(fleet.filePat, b - 1);
            else
                fname = fleet.filePat;
            end
            path = fullfile(rawDir, fname);
            isNew = ~exist(path, 'file');

            fid = fopen(path, 'a');
            if fid == -1
                warning('IndustrialPlant:fopenFailed', ...
                    'Could not open %s for append.', path);
                continue;
            end
            cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>

            % Build header on first write so the wide-CSV path can resolve
            % column names.
            if isNew
                hdr = 'time';
                for s = 1:fleet.nPerBank
                    slotIdx = (b - 1) * fleet.nPerBank + (s - 1);
                    colName = sprintf('%s_%03d', fleet.prefix, slotIdx);
                    colName = strrep(colName, '.', '_');
                    hdr = [hdr ',' colName]; %#ok<AGROW>
                end
                fprintf(fid, '%s\n', hdr);
            end

            % Build data row: time + N column values.
            fprintf(fid, '%.9f', nowTime);
            for s = 1:fleet.nPerBank
                slotIdx = (b - 1) * fleet.nPerBank + (s - 1);
                phase   = 0.1 * slotIdx;
                y = fleet.baseMean + ...
                    fleet.baseAmp * sin(2*pi * fleet.baseFreq * tRel + phase) + ...
                    fleet.noiseStd * randn();
                fprintf(fid, ',%.6f', y);
            end
            fprintf(fid, '\n');
        end
    end
end
