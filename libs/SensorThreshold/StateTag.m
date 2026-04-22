classdef StateTag < Tag
    %STATETAG Concrete Tag subclass for discrete state signals with ZOH lookup.
    %   StateTag models a piecewise-constant ("zero-order hold") time
    %   series representing a discrete system state (e.g., machine mode,
    %   recipe phase).  valueAt(t) returns the most recent known state
    %   value using a right-biased binary search on X.  Supports BOTH
    %   numeric and cellstr Y — semantics are byte-for-byte equivalent to
    %   legacy StateChannel.valueAt.  Adds StateTag:emptyState guard so
    %   unloaded tags produce a clean error instead of a bounds crash.
    %
    %   Properties (public, in addition to Tag universals):
    %     X — 1xN sorted numeric: timestamps of state transitions
    %     Y — 1xN numeric OR 1xN cell of char: state values
    %
    %   Methods:
    %     StateTag     — constructor (key + 'X','Y' + Tag universals)
    %     getXY        — return [X, Y] (pass-through)
    %     valueAt(t)   — ZOH lookup; scalar or vector t; numeric or cellstr Y
    %     getTimeRange — [X(1), X(end)]; [NaN NaN] if empty
    %     getKind      — returns 'state'
    %     toStruct     — serialize X, Y, plus Tag universals
    %     fromStruct   — static factory rebuilding StateTag from toStruct
    %
    %   Error IDs:
    %     StateTag:emptyState     — valueAt on empty X/Y
    %     StateTag:unknownOption  — unknown constructor name-value key
    %     StateTag:dataMismatch   — fromStruct struct missing .key
    %
    %   Example:
    %     st = StateTag('mode', 'X', [1 5 10 20], 'Y', [0 1 2 3]);
    %     st.valueAt(7);             % -> 1
    %     st.valueAt([0 3 5 7 15]);  % -> [0 0 1 1 2]
    %
    %   See also Tag, TagRegistry, StateChannel, binary_search.

    properties
        X = []   % 1xN numeric: sorted transition timestamps
        Y = []   % 1xN numeric OR 1xN cell of char: state values
    end

    properties (Access = private)
        listeners_ = {}         % cell of handles implementing invalidate(); strong refs
        RawSource_ = struct()   % struct: {file (required), column (opt), format (opt)} — Phase 1012
    end

    properties (Dependent)
        RawSource   % read-only view of RawSource_ (Phase 1012 pipeline binding)
    end

    methods
        function obj = StateTag(key, varargin)
            %STATETAG Construct a StateTag; delegates universals to Tag + parses X/Y + RawSource.
            %   Valid name-value keys: 'X', 'Y', 'RawSource', plus Tag universals
            %   (Name, Units, Description, Labels, Metadata, Criticality, SourceRef).
            %   Raises StateTag:unknownOption for unrecognized or dangling keys.
            %   Raises TagPipeline:invalidRawSource if RawSource is malformed.
            [tagArgs, xVal, yVal, hasX, hasY, rsVal, hasRs] = ...
                StateTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});   % MUST be first — Pitfall 8
            if hasX,  obj.X = xVal; end
            if hasY,  obj.Y = yVal; end
            if hasRs, obj.RawSource_ = rsVal; end
        end

        function r = get.RawSource(obj)
            %GET.RAWSOURCE Return the raw-data source binding (read-only view).
            %   Populated only for StateTags whose 'RawSource' NV-pair was
            %   set at construction. Consumed by BatchTagPipeline /
            %   LiveTagPipeline to locate the raw file + column for this tag.
            r = obj.RawSource_;
        end

        function [X, Y] = getXY(obj)
            %GETXY Return [X, Y] data vectors (pass-through).
            X = obj.X;
            Y = obj.Y;
        end

        function val = valueAt(obj, t)
            %VALUEAT Return state value at t using zero-order hold.
            %   Right-biased binary search on X: largest idx with X(idx)<=t,
            %   clamped to [1, N].  Supports scalar and vector t for both
            %   numeric and cellstr Y.  Raises StateTag:emptyState if X or
            %   Y is empty.  Semantics match StateChannel.valueAt byte-for-byte.
            if isempty(obj.X) || isempty(obj.Y)
                error('StateTag:emptyState', ...
                    'StateTag ''%s'' has empty X or Y; cannot evaluate valueAt.', ...
                    obj.Key);
            end
            if isscalar(t)
                % --- Scalar path: single binary search lookup ---
                idx = obj.bsearchRight_(t);
                if iscell(obj.Y)
                    val = obj.Y{idx};
                else
                    val = obj.Y(idx);
                end
            else
                % --- Vector path: loop over each query time ---
                n = numel(t);
                if iscell(obj.Y)
                    val = cell(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight_(t(k));
                        val{k} = obj.Y{idx};
                    end
                else
                    val = zeros(1, n);
                    for k = 1:n
                        idx = obj.bsearchRight_(t(k));
                        val(k) = obj.Y(idx);
                    end
                end
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)]; [NaN NaN] if empty.
            if isempty(obj.X)
                tMin = NaN; tMax = NaN;
                return;
            end
            tMin = obj.X(1);
            tMax = obj.X(end);
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Return the kind identifier 'state'.
            k = 'state';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize StateTag to a plain struct.
            %   Wraps cellstr Labels and cellstr Y once via {...} to survive
            %   MATLAB's struct() cellstr-collapse.  fromStruct unwraps.
            s = struct();
            s.kind        = 'state';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.labels      = {obj.Labels};    % wrap — Pitfall 4
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.sourceref   = obj.SourceRef;
            s.x           = obj.X;
            if iscell(obj.Y)
                s.y = {obj.Y};               % cellstr-collapse defense
            else
                s.y = obj.Y;
            end
            if ~isempty(fieldnames(obj.RawSource_))
                s.rawsource = obj.RawSource_;
            end
        end

        % ---- Observer hook (Phase 1006 additive) ----

        function addListener(obj, m)
            %ADDLISTENER Register a listener notified on underlying data change.
            %   Listener must implement an invalidate() method. Strong
            %   reference — caller manages lifecycle.
            %
            %   Errors: StateTag:invalidListener if ~ismethod(m, 'invalidate').
            if ~ismethod(m, 'invalidate')
                error('StateTag:invalidListener', ...
                    'Listener must implement invalidate(); got %s.', class(m));
            end
            obj.listeners_{end+1} = m;
        end

        function updateData(obj, X, Y)
            %UPDATEDATA Replace public X/Y and fire listeners (MONITOR-04).
            %   Additive API — does NOT touch constructor or getXY paths.
            %   Any registered MonitorTag or other listener receives an
            %   invalidate() call after the new data is installed.
            obj.X = X;
            obj.Y = Y;
            obj.notifyListeners_();
        end
    end

    methods (Access = private)
        function idx = bsearchRight_(obj, val)
            %BSEARCHRIGHT_ Last index where X(idx) <= val; clamped to [1, N].
            idx = binary_search(obj.X, val, 'right');
        end

        function notifyListeners_(obj)
            %NOTIFYLISTENERS_ Iterate listeners_ and call invalidate() on each.
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Reconstruct StateTag from a toStruct output.
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('StateTag:dataMismatch', ...
                    'fromStruct requires a struct with non-empty .key');
            end
            % Unwrap labels (MockTag pattern)
            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}), L = L{1}; end
                if iscell(L), labels = L; end
            end
            metadata = struct();
            if isfield(s, 'metadata') && isstruct(s.metadata), metadata = s.metadata; end
            criticality = 'medium';
            if isfield(s, 'criticality') && ~isempty(s.criticality), criticality = s.criticality; end
            name = s.key;
            if isfield(s, 'name') && ~isempty(s.name), name = s.name; end
            units = '';
            if isfield(s, 'units') && ~isempty(s.units), units = s.units; end
            description = '';
            if isfield(s, 'description') && ~isempty(s.description), description = s.description; end
            sourceref = '';
            if isfield(s, 'sourceref') && ~isempty(s.sourceref), sourceref = s.sourceref; end
            xVal = [];
            if isfield(s, 'x'), xVal = s.x; end
            yVal = [];
            if isfield(s, 'y')
                Y = s.y;
                % Unwrap cellstr wrap from toStruct; numeric passes through
                if iscell(Y) && numel(Y) == 1 && iscell(Y{1}), Y = Y{1}; end
                yVal = Y;
            end
            rsArg = {};
            if isfield(s, 'rawsource') && isstruct(s.rawsource) && ...
                    ~isempty(fieldnames(s.rawsource))
                rsArg = {'RawSource', s.rawsource};
            end
            obj = StateTag(s.key, ...
                'Name', name, 'Units', units, 'Description', description, ...
                'Labels', labels, 'Metadata', metadata, ...
                'Criticality', criticality, 'SourceRef', sourceref, ...
                'X', xVal, 'Y', yVal, rsArg{:});
        end
    end

    methods (Static, Access = private)
        function [tagArgs, xVal, yVal, hasX, hasY, rsVal, hasRs] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag universals vs. X/Y vs. RawSource.
            %   Unknown or dangling keys raise StateTag:unknownOption.
            %   Malformed RawSource raises TagPipeline:invalidRawSource via
            %   StateTag's OWN inline validateRawSource_ (NOT a cross-class
            %   call — revision-1 Major-3 decision for Octave reliability).
            tagKeys = {'Name', 'Units', 'Description', 'Labels', ...
                       'Metadata', 'Criticality', 'SourceRef'};
            tagArgs = {};
            xVal = []; yVal = [];
            hasX = false; hasY = false;
            rsVal = struct(); hasRs = false;
            i = 1;
            while i <= numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('StateTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', char(k));
                end
                v = args{i+1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k; %#ok<AGROW>
                    tagArgs{end+1} = v; %#ok<AGROW>
                elseif strcmp(k, 'X')
                    xVal = v; hasX = true;
                elseif strcmp(k, 'Y')
                    yVal = v; hasY = true;
                elseif strcmp(k, 'RawSource')
                    rsVal = StateTag.validateRawSource_(v);
                    hasRs = true;
                else
                    error('StateTag:unknownOption', ...
                        'Unknown option ''%s''.', char(k));
                end
                i = i + 2;
            end
        end

        function rs = validateRawSource_(rs)
            %VALIDATERAWSOURCE_ Check + normalize a RawSource struct.
            %   Body duplicated verbatim from the equivalent helper on the
            %   sibling SensorTag class (see libs/SensorThreshold/SensorTag.m)
            %   to avoid cross-class static-private call fragility on Octave
            %   (Phase 1012-02 revision-1 / Major-3). Single source of truth
            %   for the contract is enforced by the shared behavior tests in
            %   TestSensorTag.m + TestStateTag.m — both classes must pass
            %   identical assertions on invalid RawSource inputs.
            %
            %   Errors:
            %     TagPipeline:invalidRawSource — not a struct, or missing/empty file
            if ~isstruct(rs) || ~isscalar(rs)
                error('TagPipeline:invalidRawSource', ...
                    'RawSource must be a scalar struct with field ''file''.');
            end
            if ~isfield(rs, 'file') || isempty(rs.file) || ~ischar(rs.file)
                error('TagPipeline:invalidRawSource', ...
                    'RawSource.file must be a non-empty char.');
            end
            if ~isfield(rs, 'column'),  rs.column = '';  end
            if ~isfield(rs, 'format'),  rs.format = '';  end
        end
    end
end
