function pipeline = startLivePipeline(rawDir, tagsDir)
%STARTLIVEPIPELINE Construct and start the LiveTagPipeline for the demo.
%   pipeline = startLivePipeline(rawDir, tagsDir) wipes/recreates tagsDir,
%   constructs a LiveTagPipeline writing per-tag .mat files there, and
%   calls start().
%
%   The pipeline watches rawDir for advancing-mtime .dat files (written by
%   makeDataGenerator) and replays them into tagsDir/<key>.mat. This is the
%   same production LiveTagPipeline from Phase 1012 -- the demo doubles as
%   an integration smoke test.
%
%   Note (v2.0): Tag in-memory X/Y is driven directly by the data
%   generator via updateData() so the pipeline is a secondary persistence
%   path. Stopping the pipeline does not invalidate the in-memory tag
%   state.
%
%   See also: LiveTagPipeline, makeDataGenerator, registerPlantTags.

    if ~ischar(rawDir) || isempty(rawDir)
        error('IndustrialPlant:invalidRawDir', ...
            'rawDir must be a non-empty char.');
    end
    if ~ischar(tagsDir) || isempty(tagsDir)
        error('IndustrialPlant:invalidTagsDir', ...
            'tagsDir must be a non-empty char.');
    end

    if exist(tagsDir, 'dir')
        rmdir(tagsDir, 's');
    end
    mkdir(tagsDir);
    % rawDir existence is the data generator's responsibility; defensive
    % mkdir here just in case.
    if ~exist(rawDir, 'dir')
        mkdir(rawDir);
    end

    pipeline = LiveTagPipeline( ...
        'OutputDir', tagsDir, ...
        'Interval',  1.0);
    pipeline.start();
end
