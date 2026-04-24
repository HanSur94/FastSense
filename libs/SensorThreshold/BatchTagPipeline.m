classdef BatchTagPipeline < handle
    %BATCHTAGPIPELINE Synchronous raw-data -> per-tag .mat pipeline.
    %   Enumerates TagRegistry for ingestable tags (SensorTag/StateTag
    %   with a non-empty RawSource), de-duplicates file reads, parses
    %   each raw file once, slices the requested column per tag, and
    %   writes <OutputDir>/<tag.Key>.mat in the SensorTag.load shape.
    %
    %   Batch semantics (D-12, D-15, D-18):
    %     - OutputDir required at construction; auto-created if missing.
    %     - run() returns a report struct; throws TagPipeline:ingestFailed
    %       at end-of-run if any tag failed.
    %     - Each tag's ingest is a try/catch boundary; one failing tag
    %       does NOT abort the batch.
    %
    %   Observability (Major-2 / revision-1):
    %     - LastFileParseCount: public SetAccess=private property
    %       recording the number of DISTINCT raw files parsed in the
    %       most recent run(). Captured BEFORE the end-of-run cache
    %       reset. Enables testFileCacheDedup to assert exact dedup
    %       without wrapping readRawDelimited_ (blocked by MATLAB's
    %       private-folder scoping).
    %
    %   Errors (namespaced under TagPipeline:*):
    %     TagPipeline:invalidOutputDir      -- OutputDir missing / empty
    %     TagPipeline:cannotCreateOutputDir -- mkdir failed
    %     TagPipeline:ingestFailed          -- 1+ tags failed (end-of-run throw)
    %     TagPipeline:unknownExtension      -- file ext not .csv/.txt/.dat
    %
    %   See also LiveTagPipeline, SensorTag, StateTag, TagRegistry.

    properties
        OutputDir = ''
        Verbose   = false
    end

    properties (SetAccess = private)
        LastReport         = struct('succeeded', {{}}, 'failed', struct([]))
        LastFileParseCount = 0    % Major-2 / revision-1 dedup observability
    end

    properties (Access = private)
        fileCache_         % containers.Map: absPath -> parsed struct (per-run)
    end

    methods
        function obj = BatchTagPipeline(varargin)
            %BATCHTAGPIPELINE Construct with required OutputDir NV-pair.
            %   p = BatchTagPipeline('OutputDir', dir)
            %   p = BatchTagPipeline('OutputDir', dir, 'Verbose', true)
            %
            %   Errors:
            %     TagPipeline:invalidOutputDir      -- OutputDir missing/empty/non-char
            %     TagPipeline:cannotCreateOutputDir -- mkdir failed
            opts = struct('OutputDir', '', 'Verbose', false);
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin) || ~ischar(key)
                    error('TagPipeline:invalidOutputDir', ...
                        'Options must be name-value pairs with char keys.');
                end
                switch key
                    case 'OutputDir'
                        opts.OutputDir = varargin{k+1};
                    case 'Verbose'
                        opts.Verbose = logical(varargin{k+1});
                    otherwise
                        error('TagPipeline:invalidOutputDir', ...
                            'Unknown option ''%s''.', key);
                end
            end

            if isempty(opts.OutputDir) || ~ischar(opts.OutputDir)
                error('TagPipeline:invalidOutputDir', ...
                    'OutputDir is required (non-empty char).');
            end
            if ~exist(opts.OutputDir, 'dir')
                [ok, msg] = mkdir(opts.OutputDir);
                if ~ok
                    error('TagPipeline:cannotCreateOutputDir', ...
                        'Cannot create OutputDir ''%s'': %s', opts.OutputDir, msg);
                end
            end
            obj.OutputDir = opts.OutputDir;
            obj.Verbose   = opts.Verbose;
        end

        function report = run(obj)
            %RUN Enumerate tags, ingest each, write per-tag .mat; throw at end if any failed.
            %   Returns a report struct with fields:
            %     succeeded - cellstr of tag keys that wrote OK
            %     failed    - struct array of failed tags (key, file, errorId, message)
            %
            %   Throws TagPipeline:ingestFailed at end if ANY tag failed.
            obj.fileCache_ = containers.Map('KeyType', 'char', 'ValueType', 'any');
            report = struct('succeeded', {{}}, 'failed', struct([]));

            tags = obj.eligibleTags_();
            if obj.Verbose
                fprintf('[BATCH-TAG-PIPELINE] %d ingestable tag(s)\n', numel(tags));
            end

            for i = 1:numel(tags)
                t = tags{i};
                try
                    [x, y] = obj.ingestTag_(t);
                    writeTagMat_(obj.OutputDir, t, x, y, 'overwrite');
                    report.succeeded{end+1} = char(t.Key); %#ok<AGROW>
                catch ex
                    if obj.Verbose
                        fprintf(2, '[BATCH-TAG-PIPELINE] %s failed: %s (%s)\n', ...
                            char(t.Key), ex.message, ex.identifier);
                    end
                    rsFile = '';
                    try
                        rsFile = t.RawSource.file;
                    catch
                        rsFile = '';
                    end
                    entry = struct( ...
                        'key',     char(t.Key), ...
                        'file',    rsFile, ...
                        'errorId', ex.identifier, ...
                        'message', ex.message);
                    if isempty(report.failed)
                        report.failed = entry;
                    else
                        report.failed(end+1) = entry; %#ok<AGROW>
                    end
                end
            end

            obj.LastReport = report;
            % MAJOR-2 / revision-1: capture parse count BEFORE clearing the cache.
            obj.LastFileParseCount = double(obj.fileCache_.Count);
            % Clean up the per-run cache so a second run() starts fresh.
            obj.fileCache_ = containers.Map('KeyType', 'char', 'ValueType', 'any');

            if ~isempty(report.failed)
                error('TagPipeline:ingestFailed', ...
                    '%d tag(s) failed during ingest (succeeded: %d). See LastReport.failed.', ...
                    numel(report.failed), numel(report.succeeded));
            end
        end
    end

    methods (Access = private)
        function tags = eligibleTags_(~)
            %ELIGIBLETAGS_ Filter TagRegistry to SensorTag/StateTag with non-empty RawSource.
            %   Uses an inline lambda rather than @BatchTagPipeline.isIngestable_ because
            %   Octave rejects cross-class private-method handles at the call site (see
            %   deferred-items.md). LiveTagPipeline.eligibleTags_ uses the same pattern.
            tags = TagRegistry.find(@(t) ...
                (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
                isstruct(t.RawSource) && ...
                isfield(t.RawSource, 'file') && ...
                ~isempty(t.RawSource.file));
        end

        function [x, y] = ingestTag_(obj, tag)
            %INGESTTAG_ Parse (with cache) + select columns for a single tag.
            rs = tag.RawSource;
            abspath = obj.absPath_(rs.file);
            parsed = obj.parseOrCache_(abspath);
            [x, y] = selectTimeAndValue_(parsed, rs);
        end

        function parsed = parseOrCache_(obj, abspath)
            %PARSEORCACHE_ Return cached parse if available; else parse and cache.
            if obj.fileCache_.isKey(abspath)
                parsed = obj.fileCache_(abspath);
                return;
            end
            parsed = obj.dispatchParse_(abspath);
            obj.fileCache_(abspath) = parsed;
        end

        function parsed = dispatchParse_(obj, abspath)  %#ok<INUSL>
            %DISPATCHPARSE_ Internal parser dispatch (D-02 forward-compat shape).
            [~, ~, ext] = fileparts(abspath);
            ext = lower(ext);
            switch ext
                case {'.csv', '.txt', '.dat'}
                    parsed = readRawDelimited_(abspath);
                otherwise
                    error('TagPipeline:unknownExtension', ...
                        'Unsupported extension ''%s''. Supported: .csv .txt .dat', ext);
            end
        end

        function ap = absPath_(~, path)
            %ABSPATH_ Resolve to an absolute path (pwd-relative fallback).
            if ~isempty(path) && (path(1) == filesep() || ...
                    (ispc() && numel(path) >= 2 && path(2) == ':'))
                ap = path;
            else
                ap = fullfile(pwd(), path);
            end
        end
    end

end
