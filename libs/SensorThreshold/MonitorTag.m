classdef MonitorTag < Tag
    %MONITORTAG Derived 0/1 binary time-series Tag — lazy-by-default, no persistence.
    %
    %   MonitorTag produces a binary alarm/ok signal by evaluating a
    %   user-supplied ConditionFn against its Parent tag's (X, Y). Output
    %   is cached on first read and recomputed only when invalidate() is
    %   called (directly or via parent.updateData listener notification).
    %
    %   This Phase 1006 implementation is lazy-by-default, no persistence —
    %   no FastSense data store writes, no disk footprint. Opt-in persistence
    %   arrives in Phase 1007 (MONITOR-09).
    %
    %   MONITOR-05 note: Phase 1006 (later plans) uses the existing Event
    %   carrier fields SensorName = Parent.Key and ThresholdLabel = obj.Key.
    %   Phase 1010 (EVENT-01) will migrate to a per-Tag keys field on Event.
    %   Do NOT write a TagKeys field in this class — it does not exist on
    %   Event yet (the carrier pattern uses SensorName + ThresholdLabel).
    %
    %   MONITOR-10: Only event-level callbacks (OnEventStart, OnEventEnd)
    %   are supported. Per-sample callbacks are a documented anti-pattern
    %   (PI-AF side-effect pitfall). This class MUST NOT expose keywords
    %   whose shape is a per-sample callback.
    %
    %   ALIGN: operates directly on parent's native grid via parent.getXY().
    %   No interp1 linear ever — ZOH is the only legal alignment when
    %   aggregating across parents (CompositeTag in a later phase will
    %   re-assert this contract via valueAt-on-common-grid).
    %
    %   Lifecycle: MonitorTag holds a Parent handle; Parent holds a strong
    %   reference to MonitorTag via its listeners_ cell. To dispose,
    %   unregister the monitor via TagRegistry.unregister AND reset the
    %   parent's listener cell (or construct a fresh parent).
    %
    %   Properties (public):
    %     Parent               — Tag handle (required at construction)
    %     ConditionFn          — function_handle @(x,y)->logical (required)
    %     AlarmOffConditionFn  — function_handle; [] means no hysteresis
    %     MinDuration          — native parent-X units; 0 disables debounce
    %     EventStore           — EventStore handle; [] disables event emission
    %     OnEventStart         — function_handle @(event); [] disables
    %     OnEventEnd           — function_handle @(event); [] disables
    %
    %   Methods (Tag contract):
    %     getXY                — lazy-memoized 0/1 vector on parent's grid
    %     valueAt(t)           — ZOH lookup into getXY cache
    %     getTimeRange         — [X(1), X(end)]; [NaN NaN] if empty
    %     getKind              — returns 'monitor'
    %     toStruct             — serialize (no function handles, no data)
    %     fromStruct (Static)  — Pass-1 reconstruction (dummy parent)
    %     resolveRefs(registry)— Pass-2 wire Parent + register listener
    %
    %   Methods (additional):
    %     invalidate           — clear cache + mark dirty
    %
    %   Error IDs:
    %     MonitorTag:invalidParent     — parentTag not a Tag
    %     MonitorTag:invalidCondition  — conditionFn not a function_handle
    %     MonitorTag:unknownOption     — unknown NV key or dangling key
    %     MonitorTag:dataMismatch      — fromStruct missing required fields
    %     MonitorTag:unresolvedParent  — Pass-2 parent key not in registry
    %
    %   Example:
    %     st = SensorTag('press_a', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
    %     m  = MonitorTag('press_hi', st, @(x, y) y > 50);
    %     [mx, my] = m.getXY();    % my is 0/1 aligned to st.X
    %     st.updateData(x2, y2);   % automatically invalidates m's cache
    %     [mx, my] = m.getXY();    % recomputes on new parent data
    %
    %   See also Tag, SensorTag, StateTag, TagRegistry.

    properties
        Parent                   % Tag handle (required)
        ConditionFn              % function_handle @(x,y) -> logical (required)
        AlarmOffConditionFn = [] % function_handle; [] means no hysteresis
        MinDuration         = 0  % native parent-X units; 0 disables debounce
        EventStore          = [] % EventStore handle; [] disables event emission
        OnEventStart        = [] % function_handle @(event); [] disables callback
        OnEventEnd          = [] % function_handle @(event); [] disables callback
    end

    properties (Access = private)
        cache_          = struct() % {x, y, computedAt}; empty until first compute
        dirty_          = true     % true when cache needs rebuilding
        ParentKey_      = ''       % set in Pass-1 fromStruct; consumed by resolveRefs
        listeners_      = {}       % cell of listeners notified on invalidate()
    end

    properties (SetAccess = private)
        recomputeCount_ = 0        % test probe — incremented every recompute_
    end

    methods
        function obj = MonitorTag(key, parentTag, conditionFn, varargin)
            %MONITORTAG Construct a MonitorTag.
            %   m = MonitorTag(key, parentTag, conditionFn) creates a lazy
            %   binary monitor whose output is conditionFn(parentTag.X,
            %   parentTag.Y) aligned to parent's native grid.
            %
            %   m = MonitorTag(key, parentTag, conditionFn, Name, Value, ...)
            %   accepts both Tag universals (Name, Units, Description,
            %   Labels, Metadata, Criticality, SourceRef) and MonitorTag
            %   extras (AlarmOffConditionFn, MinDuration, EventStore,
            %   OnEventStart, OnEventEnd).
            %
            %   The new monitor registers itself as a listener on parentTag
            %   so that parent.updateData triggers automatic cache
            %   invalidation (MONITOR-04).
            %
            %   Errors:
            %     MonitorTag:invalidParent    — parentTag not a Tag
            %     MonitorTag:invalidCondition — conditionFn not a function_handle
            %     MonitorTag:unknownOption    — unrecognized or dangling NV key

            % Parse NV pairs BEFORE obj access (Pitfall 7 — super-call ordering).
            [tagArgs, monArgs] = MonitorTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});           % MUST be first statement

            if ~isa(parentTag, 'Tag')
                error('MonitorTag:invalidParent', ...
                    'parentTag must be a Tag; got %s.', class(parentTag));
            end
            if ~isa(conditionFn, 'function_handle')
                error('MonitorTag:invalidCondition', ...
                    'conditionFn must be a function_handle @(x,y); got %s.', ...
                    class(conditionFn));
            end

            obj.Parent      = parentTag;
            obj.ConditionFn = conditionFn;

            for i = 1:2:numel(monArgs)
                switch monArgs{i}
                    case 'AlarmOffConditionFn'
                        obj.AlarmOffConditionFn = monArgs{i+1};
                    case 'MinDuration'
                        obj.MinDuration = monArgs{i+1};
                    case 'EventStore'
                        obj.EventStore = monArgs{i+1};
                    case 'OnEventStart'
                        obj.OnEventStart = monArgs{i+1};
                    case 'OnEventEnd'
                        obj.OnEventEnd = monArgs{i+1};
                    otherwise
                        error('MonitorTag:unknownOption', ...
                            'Unknown option ''%s''.', monArgs{i});
                end
            end

            % Register for parent-driven invalidation (MONITOR-04).
            if ismethod(parentTag, 'addListener')
                parentTag.addListener(obj);
            end
        end

        % ---- Tag contract ----

        function [x, y] = getXY(obj)
            %GETXY Return lazy-memoized 0/1 vector aligned to parent's grid.
            if obj.dirty_ || ~isfield(obj.cache_, 'x')
                obj.recompute_();
            end
            x = obj.cache_.x;
            y = obj.cache_.y;
        end

        function v = valueAt(obj, t)
            %VALUEAT ZOH lookup into the cached 0/1 series.
            %   Returns NaN if parent has no data.
            [x, y] = obj.getXY();
            if isempty(x) || isempty(y)
                v = NaN;
                return;
            end
            idx = binary_search(x, t, 'right');
            v = y(idx);
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)]; [NaN NaN] if empty.
            [x, ~] = obj.getXY();
            if isempty(x)
                tMin = NaN;
                tMax = NaN;
                return;
            end
            tMin = x(1);
            tMax = x(end);
        end

        function k = getKind(obj) %#ok<MANU>
            %GETKIND Return the kind identifier 'monitor'.
            k = 'monitor';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize MonitorTag state to a plain struct.
            %   Function handles are NOT serialized — consumers re-bind
            %   ConditionFn / AlarmOffConditionFn / EventStore / callbacks
            %   after loadFromStructs. The Parent handle is stored as its
            %   Key string (parentkey); resolveRefs wires the real handle
            %   in Pass 2 of the two-phase loader.
            s = struct();
            s.kind        = 'monitor';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.labels      = {obj.Labels};
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.sourceref   = obj.SourceRef;
            s.parentkey   = obj.Parent.Key;
            s.minduration = obj.MinDuration;
        end

        function resolveRefs(obj, registry)
            %RESOLVEREFS Pass-2 hook to wire Parent from registry by key.
            %   Called by TagRegistry.loadFromStructs. On success:
            %     - obj.Parent is swapped to the real registry entry
            %     - obj registers itself as a listener on the real parent
            %     - obj.invalidate() clears any stale cache
            %     - obj.ParentKey_ is cleared (consumed)
            %
            %   Errors: MonitorTag:unresolvedParent if key missing.
            if isempty(obj.ParentKey_)
                return;
            end
            if ~registry.isKey(obj.ParentKey_)
                error('MonitorTag:unresolvedParent', ...
                    'Parent tag ''%s'' not registered.', obj.ParentKey_);
            end
            realParent = registry(obj.ParentKey_);
            obj.Parent = realParent;
            if ismethod(realParent, 'addListener')
                realParent.addListener(obj);
            end
            obj.invalidate();
            obj.ParentKey_ = '';  % consumed
        end

        % ---- Public cache control ----

        function invalidate(obj)
            %INVALIDATE Clear cache + mark dirty; cascade to downstream listeners.
            %   MonitorTag itself is observable: downstream MonitorTags
            %   (recursive chains) register as listeners and are invalidated
            %   here so that a root-parent update propagates through the
            %   full derivation chain.
            obj.dirty_ = true;
            obj.cache_ = struct();
            obj.notifyListeners_();
        end

        function addListener(obj, m)
            %ADDLISTENER Register a listener notified when this monitor invalidates.
            %   Enables recursive MonitorTag chains — an outer MonitorTag
            %   that wraps an inner MonitorTag registers as the inner's
            %   listener so that root-parent updates cascade through.
            %
            %   Errors: MonitorTag:invalidListener if ~ismethod(m, 'invalidate').
            if ~ismethod(m, 'invalidate')
                error('MonitorTag:invalidListener', ...
                    'Listener must implement invalidate(); got %s.', class(m));
            end
            obj.listeners_{end+1} = m;
        end

        % ---- Property setters that invalidate (Pitfall 9) ----

        function set.ConditionFn(obj, v)
            obj.ConditionFn = v;
            obj.dirty_ = true;
            obj.cache_ = struct();
        end

        function set.AlarmOffConditionFn(obj, v)
            obj.AlarmOffConditionFn = v;
            obj.dirty_ = true;
            obj.cache_ = struct();
        end

        function set.MinDuration(obj, v)
            obj.MinDuration = v;
            obj.dirty_ = true;
            obj.cache_ = struct();
        end
    end

    methods (Access = private)
        function notifyListeners_(obj)
            %NOTIFYLISTENERS_ Iterate listeners_ and call invalidate() on each.
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
        end

        function recompute_(obj)
            %RECOMPUTE_ Evaluate ConditionFn on parent's grid and cache.
            %   Four-stage pipeline (Plan 02):
            %     1. Raw condition evaluation (logical, parent-aligned)
            %     2. Hysteresis FSM (only when AlarmOffConditionFn is set)
            %     3. MinDuration debounce (no-op when MinDuration == 0)
            %     4. Event emission on rising edges of the debounced signal
            %   The cached (x, y) reflects the final debounced+hysteresed
            %   binary vector — consumers reading getXY see the same signal
            %   that drove event emission.
            obj.recomputeCount_ = obj.recomputeCount_ + 1;
            [px, py] = obj.Parent.getXY();
            if isempty(px)
                obj.cache_ = struct('x', [], 'y', [], 'computedAt', now);
                obj.dirty_ = false;
                return;
            end
            % Stage 1: raw condition evaluation
            raw = logical(obj.ConditionFn(px, py));
            % Stage 2: hysteresis (only when AlarmOffConditionFn is non-empty)
            if ~isempty(obj.AlarmOffConditionFn)
                raw = obj.applyHysteresis_(px, py, raw);
            end
            % Stage 3: MinDuration debounce (no-op when MinDuration == 0)
            if obj.MinDuration > 0
                raw = obj.applyDebounce_(px, raw);
            end
            % Stage 4: event emission on rising edges
            obj.fireEventsOnRisingEdges_(px, raw);
            obj.cache_ = struct( ...
                'x',          px(:).', ...
                'y',          double(raw(:).'), ...
                'computedAt', now);
            obj.dirty_ = false;
        end

        function bin = applyHysteresis_(obj, px, py, rawOn)
            %APPLYHYSTERESIS_ Two-state FSM — stay ON until AlarmOffConditionFn triggers.
            %   State OFF: flip to ON when ConditionFn(x, y) is true
            %   State ON : flip to OFF when AlarmOffConditionFn(x, y) is true
            %   Single pass over the parent grid (O(N)).
            N = numel(rawOn);
            rawOff = logical(obj.AlarmOffConditionFn(px, py));
            bin = false(1, N);
            state = false;
            for i = 1:N
                if state
                    if rawOff(i), state = false; end
                else
                    if rawOn(i),  state = true;  end
                end
                bin(i) = state;
            end
        end

        function bin = applyDebounce_(obj, px, bin)
            %APPLYDEBOUNCE_ Zero out contiguous runs of 1s shorter than MinDuration.
            %   Durations are in native parent-X units (same convention as
            %   EventDetector.MinDuration). Uses strict less-than, matching
            %   EventDetector.m:52 convention.
            [sI, eI] = obj.findRuns_(bin);
            for k = 1:numel(sI)
                if px(eI(k)) - px(sI(k)) < obj.MinDuration
                    bin(sI(k):eI(k)) = false;
                end
            end
        end

        function [startIdx, endIdx] = findRuns_(~, bin)
            %FINDRUNS_ Return indices of every contiguous run of 1s.
            %   Inline port of libs/EventDetection/private/groupViolations.m
            %   (across-library private helpers are not callable; 4-line
            %   algorithm copied).
            if ~any(bin)
                startIdx = [];
                endIdx   = [];
                return;
            end
            d = diff([0, bin(:).', 0]);
            startIdx = find(d == 1);
            endIdx   = find(d == -1) - 1;
        end

        function fireEventsOnRisingEdges_(obj, px, bin)
            %FIREEVENTSONRISINGEDGES_ Emit Events on 0-to-1 transitions after debounce+hysteresis.
            %
            %   MONITOR-05 CARRIER PATTERN (Phase 1006 pre-Phase-1010):
            %     A per-Tag keys field on Event does NOT exist yet. Use the
            %     existing Event.m constructor with SensorName = obj.Parent.Key
            %     and ThresholdLabel = obj.Key as carriers. Phase 1010
            %     (EVENT-01) will migrate to a keys array at that time.
            %
            %   MONITOR-10: Event-level callbacks only — OnEventStart fires
            %   at the rising edge, OnEventEnd fires at the falling edge.
            %   No per-sample callbacks are exposed.
            %
            %   Persistence policy: NEVER calls EventStore.save (Pitfall 2).
            %   Only EventStore.append — consumers choose when to persist.
            if isempty(bin), return; end
            if isempty(obj.EventStore) && isempty(obj.OnEventStart) && isempty(obj.OnEventEnd)
                return;
            end
            [sI, eI] = obj.findRuns_(bin);
            for k = 1:numel(sI)
                startT = px(sI(k));
                endT   = px(eI(k));
                ev = Event(startT, endT, char(obj.Parent.Key), char(obj.Key), NaN, 'upper');
                if ~isempty(obj.EventStore)
                    obj.EventStore.append(ev);
                end
                if ~isempty(obj.OnEventStart)
                    obj.OnEventStart(ev);
                end
                if ~isempty(obj.OnEventEnd)
                    obj.OnEventEnd(ev);
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            %FROMSTRUCT Pass-1 reconstruction from a toStruct output.
            %   The real Parent handle is wired in Pass 2 via resolveRefs.
            %   ConditionFn / AlarmOffConditionFn / EventStore / callbacks
            %   are NOT restored — consumers must re-bind these after load.
            %
            %   Errors: MonitorTag:dataMismatch if required fields missing.
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('MonitorTag:dataMismatch', ...
                    'fromStruct requires a struct with non-empty .key.');
            end
            if ~isfield(s, 'parentkey') || isempty(s.parentkey)
                error('MonitorTag:dataMismatch', ...
                    'fromStruct requires a non-empty .parentkey (Pass-2 resolves the handle).');
            end
            % Pass 1: construct with a dummy parent + placeholder condition.
            dummyParent   = MockTag(s.parentkey);
            placeholderFn = @(x, y) false(size(x));

            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}), L = L{1}; end
                if iscell(L), labels = L; end
            end
            metadata = struct();
            if isfield(s, 'metadata') && isstruct(s.metadata)
                metadata = s.metadata;
            end

            obj = MonitorTag(s.key, dummyParent, placeholderFn, ...
                'MinDuration', MonitorTag.fieldOr_(s, 'minduration', 0), ...
                'Name',        MonitorTag.fieldOr_(s, 'name',        s.key), ...
                'Labels',      labels, ...
                'Metadata',    metadata, ...
                'Criticality', MonitorTag.fieldOr_(s, 'criticality', 'medium'), ...
                'Units',       MonitorTag.fieldOr_(s, 'units',       ''), ...
                'Description', MonitorTag.fieldOr_(s, 'description', ''), ...
                'SourceRef',   MonitorTag.fieldOr_(s, 'sourceref',   ''));
            obj.ParentKey_ = s.parentkey;
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

        function [tagArgs, monArgs] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag NV pairs vs MonitorTag NV pairs.
            %   Unknown and dangling keys both raise MonitorTag:unknownOption.
            tagKeys = {'Name', 'Units', 'Description', 'Labels', ...
                       'Metadata', 'Criticality', 'SourceRef'};
            monKeys = {'AlarmOffConditionFn', 'MinDuration', ...
                       'EventStore', 'OnEventStart', 'OnEventEnd'};
            tagArgs = {};
            monArgs = {};
            for i = 1:2:numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('MonitorTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', k);
                end
                v = args{i+1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k; %#ok<AGROW>
                    tagArgs{end+1} = v; %#ok<AGROW>
                elseif any(strcmp(k, monKeys))
                    monArgs{end+1} = k; %#ok<AGROW>
                    monArgs{end+1} = v; %#ok<AGROW>
                else
                    error('MonitorTag:unknownOption', ...
                        'Unknown option ''%s''.', k);
                end
            end
        end
    end
end
