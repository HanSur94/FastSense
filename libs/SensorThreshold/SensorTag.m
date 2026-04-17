classdef SensorTag < Tag
    %SENSORTAG Concrete Tag subclass for sensor time-series data.
    %   SensorTag is the primary sensor data carrier in the Tag-based domain
    %   model.  It stores time-series data (X, Y) directly and satisfies the
    %   Tag contract (getXY, valueAt, getTimeRange, getKind='sensor',
    %   toStruct, fromStruct).  Data-role methods (load, toDisk, toMemory,
    %   isOnDisk) operate on the inlined private properties.
    %
    %   Properties (Dependent): DataStore -- read-only view of the disk store.
    %
    %   Constructor accepts Tag universals (Name, Units, Description,
    %   Labels, Metadata, Criticality, SourceRef), sensor extras (ID,
    %   Source, MatFile, KeyName), and inline 'X'/'Y' data arrays.
    %
    %   Example:
    %     st = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar');
    %     st.load('data/press_a.mat');  % populates X_, Y_ from file
    %     [x, y] = st.getXY();
    %     TagRegistry.register('press_a', st);
    %
    %   See also Tag, TagRegistry, StateTag.

    properties (Access = private)
        X_         = []    % double: timestamps
        Y_         = []    % double: values
        DataStore_ = []    % FastSenseDataStore
        ID_        = []    % numeric
        Source_    = ''    % char
        MatFile_   = ''    % char
        KeyName_   = ''    % char: defaults to Key
        listeners_ = {}    % cell of handles implementing invalidate(); strong refs
    end

    properties (Dependent)
        DataStore   % read-only view of DataStore_
    end

    methods
        function obj = SensorTag(key, varargin)
            %SENSORTAG Construct a SensorTag with inlined data storage.
            %   t = SensorTag(key) creates a SensorTag with the given key.
            %
            %   t = SensorTag(key, Name, Value, ...) accepts Tag universals
            %   (Name, Units, Description, Labels, Metadata, Criticality,
            %   SourceRef), sensor extras (ID, Source, MatFile, KeyName),
            %   and inline data payload (X, Y).
            %
            %   Errors:
            %     Tag:invalidKey           -- key empty / not char
            %     SensorTag:unknownOption  -- unrecognized NV key
            [tagArgs, sensorArgs, inlineX, inlineY] = SensorTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});              % MUST be first -- no obj access before

            % Store sensor extras directly
            obj.KeyName_ = key;  % default: same as Key
            for i = 1:2:numel(sensorArgs)
                switch sensorArgs{i}
                    case 'ID',       obj.ID_      = sensorArgs{i+1};
                    case 'Source',   obj.Source_   = sensorArgs{i+1};
                    case 'MatFile',  obj.MatFile_  = sensorArgs{i+1};
                    case 'KeyName',  obj.KeyName_  = sensorArgs{i+1};
                end
            end

            if ~isempty(inlineX) || ~isempty(inlineY)
                obj.X_ = inlineX;
                obj.Y_ = inlineY;
            end
        end

        function ds = get.DataStore(obj)
            %GET.DATASTORE Return the disk-backed DataStore (read-only view).
            ds = obj.DataStore_;
        end

        % ---- Tag contract ----

        function [X, Y] = getXY(obj)
            %GETXY Return X, Y by reference (zero-copy via COW).
            %   MATLAB copy-on-write guarantees no memory allocation until
            %   the caller mutates X or Y.
            X = obj.X_;
            Y = obj.Y_;
        end

        function v = valueAt(obj, t)
            %VALUEAT Return Y at the last index where X <= t (ZOH, clamped).
            %   Returns NaN on empty data.
            if isempty(obj.X_) || isempty(obj.Y_)
                v = NaN;
                return;
            end
            idx = binary_search(obj.X_, t, 'right');
            v = obj.Y_(idx);
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)].  [NaN NaN] if empty.
            if isempty(obj.X_)
                tMin = NaN;
                tMax = NaN;
                return;
            end
            tMin = obj.X_(1);
            tMax = obj.X_(end);
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Return the literal kind identifier 'sensor'.
            k = 'sensor';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize SensorTag state to a plain struct.
            %   Tag universals at the top level; sensor-specific extras
            %   nested under s.sensor (only when non-default) to keep the
            %   struct compact.  X/Y are INTENTIONALLY OMITTED -- runtime
            %   data, not serialization state.
            s = struct();
            s.kind        = 'sensor';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.labels      = {obj.Labels};    % MockTag cellstr-wrap pattern
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.sourceref   = obj.SourceRef;

            sensorExtras = struct();
            if ~isempty(obj.ID_)
                sensorExtras.id = obj.ID_;
            end
            if ~isempty(obj.Source_)
                sensorExtras.source = obj.Source_;
            end
            if ~isempty(obj.MatFile_)
                sensorExtras.matfile = obj.MatFile_;
            end
            if ~isempty(obj.KeyName_) && ~strcmp(obj.KeyName_, obj.Key)
                sensorExtras.keyname = obj.KeyName_;
            end
            if ~isempty(fieldnames(sensorExtras))
                s.sensor = sensorExtras;
            end
        end

        % ---- Data-role methods ----

        function load(obj, matFile)
            %LOAD Load sensor data from a .mat file.
            %   t.load() uses the already-configured MatFile.
            %   t.load(path) sets MatFile before loading.
            %
            %   Errors:
            %     SensorTag:noMatFile      -- MatFile not set
            %     SensorTag:fileNotFound   -- file does not exist
            %     SensorTag:fieldNotFound  -- KeyName not in file
            if nargin >= 2 && ~isempty(matFile)
                obj.MatFile_ = matFile;
            end
            if isempty(obj.MatFile_)
                error('SensorTag:noMatFile', 'MatFile property is not set.');
            end
            if ~exist(obj.MatFile_, 'file')
                error('SensorTag:fileNotFound', 'File not found: %s', obj.MatFile_);
            end
            data = builtin('load', obj.MatFile_);
            if ~isfield(data, obj.KeyName_)
                error('SensorTag:fieldNotFound', ...
                    'Field ''%s'' not found in %s. Available: %s', ...
                    obj.KeyName_, obj.MatFile_, strjoin(fieldnames(data), ', '));
            end
            entry = data.(obj.KeyName_);
            if isstruct(entry)
                if isfield(entry, 'x'), obj.X_ = entry.x; end
                if isfield(entry, 'X'), obj.X_ = entry.X; end
                if isfield(entry, 'y'), obj.Y_ = entry.y; end
                if isfield(entry, 'Y'), obj.Y_ = entry.Y; end
            else
                obj.Y_ = entry;
                obj.X_ = 1:numel(entry);
            end
        end

        function toDisk(obj)
            %TODISK Move X/Y data to disk-backed FastSenseDataStore.
            %   Clears X_ and Y_ from memory after transfer.
            if isempty(obj.X_) && ~isempty(obj.DataStore_), return; end
            if isempty(obj.X_)
                error('SensorTag:noData', 'No X/Y data to move to disk.');
            end
            obj.DataStore_ = FastSenseDataStore(obj.X_, obj.Y_);
            obj.X_ = []; obj.Y_ = [];
        end

        function toMemory(obj)
            %TOMEMORY Load disk-backed data back into memory.
            if isempty(obj.DataStore_), return; end
            [obj.X_, obj.Y_] = obj.DataStore_.readSlice(1, obj.DataStore_.NumPoints);
            obj.DataStore_.cleanup();
            obj.DataStore_ = [];
        end

        function tf = isOnDisk(obj)
            %ISONDISK True if sensor data is stored on disk.
            tf = ~isempty(obj.DataStore_);
        end

        % ---- Observer hook ----

        function addListener(obj, m)
            %ADDLISTENER Register a listener notified on underlying data change.
            %   Listener must implement an invalidate() method. Strong
            %   reference -- caller manages lifecycle.
            %
            %   Errors: SensorTag:invalidListener if ~ismethod(m, 'invalidate').
            if ~ismethod(m, 'invalidate')
                error('SensorTag:invalidListener', ...
                    'Listener must implement invalidate(); got %s.', class(m));
            end
            obj.listeners_{end+1} = m;
        end

        function updateData(obj, X, Y)
            %UPDATEDATA Replace X/Y data and fire listeners.
            obj.X_ = X;
            obj.Y_ = Y;
            obj.notifyListeners_();
        end
    end

    methods (Access = private)
        function notifyListeners_(obj)
            %NOTIFYLISTENERS_ Iterate listeners_ and call invalidate() on each.
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct SensorTag from a toStruct output.
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('SensorTag:invalidSource', ...
                    'fromStruct requires a struct with non-empty .key');
            end

            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}),  L = L{1};  end
                if iscell(L),  labels = L;  end
            end
            metadata = SensorTag.fieldOr_(s, 'metadata',    struct());
            if ~isstruct(metadata),  metadata = struct();  end

            nvArgs = { ...
                'Name',        SensorTag.fieldOr_(s, 'name',        s.key),  ...
                'Labels',      labels, ...
                'Metadata',    metadata, ...
                'Criticality', SensorTag.fieldOr_(s, 'criticality', 'medium'), ...
                'Units',       SensorTag.fieldOr_(s, 'units',       ''), ...
                'Description', SensorTag.fieldOr_(s, 'description', ''), ...
                'SourceRef',   SensorTag.fieldOr_(s, 'sourceref',   '')};

            if isfield(s, 'sensor') && isstruct(s.sensor)
                sensorKeyMap = {'id', 'ID'; 'source', 'Source'; ...
                                'matfile', 'MatFile'; 'keyname', 'KeyName'};
                for r = 1:size(sensorKeyMap, 1)
                    if isfield(s.sensor, sensorKeyMap{r, 1})
                        nvArgs(end+1:end+2) = ...
                            {sensorKeyMap{r, 2}, s.sensor.(sensorKeyMap{r, 1})}; %#ok<AGROW>
                    end
                end
            end

            obj = SensorTag(s.key, nvArgs{:});
        end
    end

    methods (Static, Access = private)
        function v = fieldOr_(s, fieldName, defaultVal)
            %FIELDOR_ Return s.(fieldName) if present and non-empty, else defaultVal.
            if isfield(s, fieldName) && ~isempty(s.(fieldName))
                v = s.(fieldName);
            else
                v = defaultVal;
            end
        end

        function [tagArgs, sensorArgs, inlineX, inlineY] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag NV / Sensor NV / inline X,Y.
            tagKeys    = {'Name', 'Units', 'Description', 'Labels', ...
                          'Metadata', 'Criticality', 'SourceRef'};
            sensorKeys = {'ID', 'Source', 'MatFile', 'KeyName'};
            tagArgs    = {};
            sensorArgs = {};
            inlineX    = [];
            inlineY    = [];
            for i = 1:2:numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('SensorTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', k);
                end
                v = args{i+1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k;    tagArgs{end+1} = v;    %#ok<AGROW>
                elseif any(strcmp(k, sensorKeys))
                    sensorArgs{end+1} = k; sensorArgs{end+1} = v; %#ok<AGROW>
                elseif strcmp(k, 'X')
                    inlineX = v;
                elseif strcmp(k, 'Y')
                    inlineY = v;
                else
                    error('SensorTag:unknownOption', ...
                        'Unknown option ''%s''.', k);
                end
            end
        end
    end
end
