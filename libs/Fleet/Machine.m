classdef Machine < handle
    %MACHINE Per-machine isolated tag catalog with pipeline and EventStore ownership.
    %   Machine is the core data-model unit that the Fleet layer composes.
    %   Each machine owns an isolated containers.Map tag catalog that mirrors
    %   the TagRegistry read API (get/find/findByKind/findByLabel/keys) as
    %   instance methods. Machine tags NEVER enter the global TagRegistry.
    %
    %   Usage:
    %     m = Machine('Id', 'M01', 'Name', 'Pump Station 1', ...
    %                 'DataRoot', '/data/m01', 'Group', 'pumps');
    %     t = SensorTag('temperature', 'Name', 'Motor Temp', 'Units', 'degC', ...
    %                   'RawSource', struct('file', '/raw/temp.csv', 'timeCol', 1, ...
    %                          'valueCol', 2, 'timeUnit', 's', 'delimiter', ','));
    %     m.addTag(t);
    %     m.ingestBatch();         % writes .mat files under DataRoot
    %     m.startLive(15);         % starts polling timer
    %     delete(m);               % stops and deletes the timer
    %
    %   Properties (public):
    %     Id          char; user-supplied, required (D-10); unique within Fleet
    %     Name        char; display name; defaults to Id when omitted
    %     DataRoot    char; output directory for pipelines and EventStore root
    %     Group       char; freeform group label (default '')
    %     Metadata    struct; arbitrary user metadata (default struct())
    %     Dashboards  cell; DashboardEngine handles for Phase 1044
    %
    %   Properties (SetAccess = private):
    %     EventStore  EventStore handle owned by this machine (empty when DataRoot empty)
    %
    %   Methods (public):
    %     addTag          - add a Tag to the isolated catalog (hard error on duplicate)
    %     get             - retrieve Tag by local key (Machine:unknownKey on miss)
    %     find            - cell of Tags matching a predicate function
    %     findByKind      - find tags by getKind() string
    %     findByLabel     - find tags carrying a label string
    %     keys            - return cell of local catalog keys
    %     ingestBatch     - run BatchTagPipeline scoped to DataRoot (FLEET-03)
    %     startLive       - start LiveTagPipeline scoped to DataRoot (FLEET-03)
    %     toConfigStruct  - serialize to a camelCase JSON-ready struct
    %     delete          - timer-safe teardown (stop before delete)
    %
    %   Static:
    %     fromConfigStruct - deserialize from config struct with D-07 path resolution
    %
    %   Errors (namespaced under Machine:*):
    %     Machine:missingId       -- Id not supplied or empty
    %     Machine:invalidOption   -- unknown NV key in constructor
    %     Machine:invalidType     -- addTag called with a non-Tag object
    %     Machine:duplicateKey    -- addTag called with a key already in catalog
    %     Machine:unknownKey      -- get called with a key not in catalog
    %     Machine:missingDataRoot -- ingestBatch/startLive called with empty DataRoot
    %
    %   Design notes:
    %     Pitfall 5: addTag stores a handle reference — do NOT share a single Tag
    %     object across multiple machines. Both machines would see each other's
    %     getXY() mutations. Enforce by constructing one Tag per machine.
    %     Pitfall 6: addTag does NOT call tag.getXY() — preserves lazy-load
    %     discipline (FLEET-05). X/Y arrays materialize only on explicit getXY().
    %
    %   See also Fleet, TagRegistry, CanonicalMapper, BatchTagPipeline, LiveTagPipeline.

    properties (Access = public)
        Id          % char; user-supplied, required, unique within Fleet (D-10)
        Name        % char; display name; defaults to Id when omitted
        DataRoot    % char; output dir for pipelines + EventStore root
        Group       % char; freeform group label (default '')
        Metadata    % struct; arbitrary user metadata
        Dashboards  % cell; DashboardEngine handles (Phase 1044)
    end

    properties (SetAccess = private)
        EventStore  % EventStore handle owned by this machine ([] when DataRoot empty)
    end

    properties (Access = private)
        Tags_        % containers.Map('KeyType','char','ValueType','any')
        LivePipeline_ = []   % LiveTagPipeline handle (set by startLive)
    end

    methods (Access = public)

        function obj = Machine(varargin)
            %MACHINE Construct a machine with NV pairs.
            %   m = Machine('Id', 'M01')
            %   m = Machine('Id', 'M01', 'Name', 'Pump 1', 'DataRoot', '/data/m01')
            %   m = Machine('Id', 'M01', 'DataRoot', '/data/m01', 'Group', 'pumps')
            %
            %   Required: 'Id' (non-empty char)
            %
            %   Errors:
            %     Machine:missingId     -- Id not supplied or empty
            %     Machine:invalidOption -- unknown NV key
            opts = struct('Id', '', 'Name', '', 'DataRoot', '', ...
                'Group', '', 'Metadata', struct());
            for k = 1:2:numel(varargin)
                key = varargin{k};
                if k + 1 > numel(varargin) || ~ischar(key)
                    error('Machine:invalidOption', ...
                        'Options must be name-value pairs with char keys.');
                end
                switch key
                    case 'Id'
                        opts.Id       = char(varargin{k+1});
                    case 'Name'
                        opts.Name     = char(varargin{k+1});
                    case 'DataRoot'
                        opts.DataRoot = char(varargin{k+1});
                    case 'Group'
                        opts.Group    = char(varargin{k+1});
                    case 'Metadata'
                        opts.Metadata = varargin{k+1};
                    otherwise
                        error('Machine:invalidOption', ...
                            'Unknown option ''%s''.', key);
                end
            end
            if isempty(opts.Id)
                error('Machine:missingId', 'Id is required (non-empty char).');
            end
            obj.Id       = opts.Id;
            obj.Name     = opts.Name;
            if isempty(obj.Name)
                obj.Name = obj.Id;
            end
            obj.DataRoot  = opts.DataRoot;
            obj.Group     = opts.Group;
            obj.Metadata  = opts.Metadata;
            obj.Tags_     = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Dashboards = {};
            if ~isempty(obj.DataRoot)
                obj.EventStore = EventStore(obj.DataRoot);
            end
        end

        function addTag(obj, tag)
            %ADDTAG Add a Tag to this machine's isolated catalog.
            %   addTag(tag) stores tag in the per-machine containers.Map.
            %   Tags are NOT registered in the global TagRegistry (FLEET-02).
            %   addTag does NOT call tag.getXY() — preserves lazy-load (FLEET-05).
            %
            %   Errors:
            %     Machine:invalidType   -- tag is not a Tag object
            %     Machine:duplicateKey  -- key already in this machine's catalog
            if ~isa(tag, 'Tag')
                error('Machine:invalidType', ...
                    'Value must be a Tag object, got %s.', class(tag));
            end
            key = char(tag.Key);
            if obj.Tags_.isKey(key)
                error('Machine:duplicateKey', ...
                    'Key ''%s'' already in machine ''%s''. Call machine.removeTag(key) first.', ...
                    key, obj.Id);
            end
            obj.Tags_(key) = tag;
        end

        function t = get(obj, localKey)
            %GET Retrieve a Tag by local catalog key.
            %   t = m.get(localKey) returns the Tag stored under localKey.
            %   Mirrors TagRegistry.get as an instance method (duck-type API).
            %
            %   Errors:
            %     Machine:unknownKey -- localKey not in catalog
            if ~obj.Tags_.isKey(localKey)
                error('Machine:unknownKey', ...
                    'No tag with key ''%s'' in machine ''%s''.', localKey, obj.Id);
            end
            t = obj.Tags_(localKey);
        end

        function ts = find(obj, predicateFn)
            %FIND Return cell of Tags matching predicateFn(tag) -> logical.
            %   Mirrors TagRegistry.find as an instance method (duck-type API).
            %
            %   Input:
            %     predicateFn -- function handle accepting a Tag, returning logical
            %
            %   Output:
            %     ts -- cell array of Tag handles (may be empty)
            ks = obj.Tags_.keys();
            ts = {};
            for i = 1:numel(ks)
                t = obj.Tags_(ks{i});
                if predicateFn(t)
                    ts{end+1} = t; %#ok<AGROW>
                end
            end
        end

        function ts = findByKind(obj, kind)
            %FINDBYKIND Return cell of Tags where getKind() == kind.
            %   Mirrors TagRegistry.findByKind as an instance method.
            %
            %   Input:
            %     kind -- char, e.g. 'sensor' | 'state' | 'monitor' | 'mock'
            ts = obj.find(@(t) strcmp(t.getKind(), kind));
        end

        function ts = findByLabel(obj, label)
            %FINDBYLABEL Return cell of Tags carrying the given label.
            %   Mirrors TagRegistry.findByLabel as an instance method (META-02).
            %
            %   Input:
            %     label -- char, label string to search for
            ts = obj.find(@(t) ~isempty(t.Labels) && any(strcmp(t.Labels, label)));
        end

        function ks = keys(obj)
            %KEYS Return cell of local catalog keys.
            %   Mirrors TagRegistry catalog keys as an instance method.
            ks = obj.Tags_.keys();
        end

        function report = ingestBatch(obj, varargin)
            %INGESTBATCH Run BatchTagPipeline scoped to this machine's catalog and DataRoot.
            %   report = m.ingestBatch()
            %   report = m.ingestBatch('SharedRoot', root)
            %
            %   Constructs BatchTagPipeline with OutputDir=DataRoot and
            %   TagSource scoped to this machine's find() method, then
            %   calls run(). Tag enumeration is scoped to this machine
            %   via the tagSource_ DI seam (FLEET-03/D-13).
            %
            %   Errors:
            %     Machine:missingDataRoot -- DataRoot is empty
            if isempty(obj.DataRoot)
                error('Machine:missingDataRoot', ...
                    'DataRoot must be set before calling ingestBatch.');
            end
            p = BatchTagPipeline('OutputDir', obj.DataRoot, ...
                'TagSource', @(pred) obj.find(pred), ...
                varargin{:});
            report = p.run();
        end

        function startLive(obj, interval, varargin)
            %STARTLIVE Start LiveTagPipeline scoped to this machine's catalog and DataRoot.
            %   m.startLive()             -- uses default interval 15 s
            %   m.startLive(interval)     -- custom interval in seconds
            %   m.startLive(interval, 'SharedRoot', root)  -- cluster machine
            %
            %   Constructs LiveTagPipeline with OutputDir=DataRoot and
            %   TagSource scoped to this machine's find() method, then
            %   calls start(). 'SharedRoot' passthrough keeps v4.0 cluster
            %   mode working for clustered machines (D-13).
            %
            %   Errors:
            %     Machine:missingDataRoot -- DataRoot is empty
            if isempty(obj.DataRoot)
                error('Machine:missingDataRoot', ...
                    'DataRoot must be set before calling startLive.');
            end
            if nargin < 2 || isempty(interval)
                interval = 15;
            end
            obj.LivePipeline_ = LiveTagPipeline('OutputDir', obj.DataRoot, ...
                'TagSource', @(pred) obj.find(pred), ...
                'Interval',  interval, ...
                varargin{:});
            obj.LivePipeline_.start();
        end

        function s = toConfigStruct(obj)
            %TOCONFIGSTRUCT Serialize machine definition to a camelCase JSON-ready struct.
            %   s = m.toConfigStruct()
            %
            %   Returns a scalar struct with camelCase fields:
            %     id, name, dataRoot, group (all char)
            %   plus metadata only when non-empty fieldnames (avoids Octave/MATLAB
            %   jsonencode divergence on empty structs).
            s = struct('id',       char(obj.Id), ...
                       'name',     char(obj.Name), ...
                       'dataRoot', char(obj.DataRoot), ...
                       'group',    char(obj.Group));
            if ~isempty(fieldnames(obj.Metadata))
                s.metadata = obj.Metadata;
            end
        end

        function delete(obj)
            %DELETE Timer-safe teardown: stop() then delete() LivePipeline_.
            %   Implements CLAUDE.md "stop(t); delete(t); always in that order"
            %   to prevent timer accumulation across machine lifecycles (T-1042-06).
            %   Idempotent: safe to call on a machine that never called startLive.
            if ~isempty(obj.LivePipeline_)
                if isvalid(obj.LivePipeline_)
                    obj.LivePipeline_.stop();
                    delete(obj.LivePipeline_);
                end
                obj.LivePipeline_ = [];
            end
        end

    end

    methods (Static)

        function obj = fromConfigStruct(s, fleetFilePath)
            %FROMCONFIGSTRUCT Deserialize a Machine from a config struct.
            %   obj = Machine.fromConfigStruct(s, fleetFilePath)
            %
            %   Implements D-07 DataRoot path resolution:
            %     leading ~  -> expanded via getenv('HOME') (Octave-safe; warns on Windows)
            %     relative   -> resolved against fileparts(fleetFilePath)
            %     absolute   -> used verbatim (starts with filesep or drive letter X:)
            %
            %   Input:
            %     s             -- scalar struct with fields id/name/dataRoot/group
            %     fleetFilePath -- char; absolute path to the fleet JSON file
            dataRoot = char(s.dataRoot);
            if numel(dataRoot) >= 1 && dataRoot(1) == '~'
                if ispc()
                    warning('Machine:tildeOnWindows', ...
                        'Leading ~ in DataRoot is not a standard Windows path prefix; left as-is.');
                else
                    home = getenv('HOME');
                    if ~isempty(home)
                        dataRoot = [home dataRoot(2:end)];
                    end
                end
            end
            % Resolve relative paths against the fleet config file directory.
            % An absolute path begins with filesep ('/') on Unix or a drive
            % letter followed by ':' on Windows (e.g. 'C:\data').
            isAbsolute = ~isempty(dataRoot) && ...
                (dataRoot(1) == filesep || ...
                 (numel(dataRoot) > 1 && dataRoot(2) == ':'));
            if ~isempty(dataRoot) && ~isAbsolute
                fleetDir = fileparts(fleetFilePath);
                dataRoot = fullfile(fleetDir, dataRoot);
            end
            nvArgs = {'Id',       char(s.id), ...
                      'Name',     char(s.name), ...
                      'DataRoot', dataRoot, ...
                      'Group',    char(s.group)};
            if isfield(s, 'metadata')
                nvArgs = [nvArgs, {'Metadata', s.metadata}];
            end
            obj = Machine(nvArgs{:});
        end

    end

end
