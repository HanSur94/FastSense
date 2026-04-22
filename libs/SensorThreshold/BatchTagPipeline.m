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
    end

    methods (Access = private)
        function tags = eligibleTags_(~)
            %ELIGIBLETAGS_ Filter TagRegistry to SensorTag/StateTag with non-empty RawSource.
            tags = TagRegistry.find(@BatchTagPipeline.isIngestable_);
        end
    end

    methods (Static, Access = private)
        function tf = isIngestable_(t)
            %ISINGESTABLE_ Predicate: true iff SensorTag/StateTag with non-empty RawSource.
            %   D-16 / Pitfall 10: POSITIVE isa-checks ONLY. Adding MonitorTag.RawSource
            %   in a future phase requires an explicit branch here -- never add a
            %   negative `~isa(t, 'MonitorTag')` check.
            tf = false;
            if ~(isa(t, 'SensorTag') || isa(t, 'StateTag'))
                return;
            end
            rs = t.RawSource;
            if ~isstruct(rs) || ~isfield(rs, 'file') || isempty(rs.file)
                return;
            end
            tf = true;
        end
    end
end
