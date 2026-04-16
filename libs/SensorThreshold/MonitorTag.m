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
    %     Persist              — logical; when true, derived (X, Y) is
    %                            cached to DataStore via storeMonitor on
    %                            every recompute_()/appendData() and loaded
    %                            on first getXY() (staleness-checked via
    %                            quad-signature). Default false — the opt-in
    %                            default enforces Pitfall 2 cache-invalidation
    %                            discipline: consumers that do not opt in
    %                            pay zero disk cost.
    %     DataStore            — FastSenseDataStore handle; required when
    %                            Persist=true. Provides storeMonitor /
    %                            loadMonitor / clearMonitor back-end.
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
    %     appendData(newX,newY) — Phase 1007 (MONITOR-08) streaming tail.
    %                             Extends cache incrementally; preserves
    %                             hysteresis FSM state and MinDuration
    %                             bookkeeping across the append boundary.
    %                             Falls back to full recompute_() when
    %                             the cache is dirty/empty (cold start).
    %
    %   Error IDs:
    %     MonitorTag:invalidParent            — parentTag not a Tag
    %     MonitorTag:invalidCondition         — conditionFn not a function_handle
    %     MonitorTag:unknownOption            — unknown NV key or dangling key
    %     MonitorTag:dataMismatch             — fromStruct missing required fields
    %     MonitorTag:unresolvedParent         — Pass-2 parent key not in registry
    %     MonitorTag:invalidData              — appendData numeric/length mismatch
    %     MonitorTag:persistDataStoreRequired — Persist=true but DataStore empty
    %
    %   Persistence (Phase 1007 MONITOR-09):
    %     Opt-in via Persist=true + DataStore. Staleness detection uses a
    %     quad-signature (parent_key, num_points, parent_xmin, parent_xmax)
    %     stamped at write. Default-off preserves Pitfall 2 cache-invalidation
    %     safety — consumers that do not opt in pay zero disk cost.
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
        Persist             = false  % MONITOR-09 opt-in (Pitfall 2 default-off)
        DataStore           = []     % FastSenseDataStore handle; required when Persist=true
    end

    properties (Access = private)
        % cache_ fields (Phase 1007 adds the three streaming-state fields):
        %   x, y, computedAt   — Plan 02 baseline
        %   lastStateFlag_     — last bin value (0/1); used by fireEventsInTail_
        %   lastHystState_     — hysteresis FSM carry-in for appendData (logical)
        %   ongoingRunStart_   — X-native start of open run at cache end (NaN if none)
        cache_          = struct() % empty until first compute
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
                    case 'Persist'
                        obj.Persist = logical(monArgs{i+1});
                    case 'DataStore'
                        obj.DataStore = monArgs{i+1};
                    otherwise
                        error('MonitorTag:unknownOption', ...
                            'Unknown option ''%s''.', monArgs{i});
                end
            end

            % MONITOR-09 Persist-pairing validation: Persist=true requires
            % a DataStore handle, otherwise storeMonitor/loadMonitor have
            % nowhere to go. Fail fast at construction rather than at first
            % getXY for a clearer error path.
            if obj.Persist && isempty(obj.DataStore)
                error('MonitorTag:persistDataStoreRequired', ...
                    'Persist=true requires a DataStore handle.');
            end

            % Register for parent-driven invalidation (MONITOR-04).
            if ismethod(parentTag, 'addListener')
                parentTag.addListener(obj);
            end
        end

        % ---- Tag contract ----

        function [x, y] = getXY(obj)
            %GETXY Return lazy-memoized 0/1 vector aligned to parent's grid.
            %   When Persist=true + DataStore bound, first attempts a disk
            %   load via tryLoadFromDisk_ (quad-signature staleness check).
            %   On miss or stale cache, falls through to recompute_() and
            %   then persistIfEnabled_() writes the fresh row.
            if obj.dirty_ || ~isfield(obj.cache_, 'x')
                if ~obj.tryLoadFromDisk_()
                    obj.recompute_();
                    obj.persistIfEnabled_();
                end
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

        function appendData(obj, newX, newY)
            %APPENDDATA Extend cached (X, Y) with new tail samples — no full recompute.
            %   Preserves hysteresis FSM state and MinDuration bookkeeping
            %   across the append boundary (MONITOR-08). Events fire only
            %   for runs that COMPLETE (reach a falling edge) inside newX:
            %   a run still open at the tail end is carried as state for
            %   the next appendData call; a run that was already open at
            %   the cache end and closes inside newX fires ONE event with
            %   StartTime = the original (carried) start.
            %
            %   If the cache is dirty or empty (no prior getXY), falls
            %   back to a full recompute_() over the parent's current
            %   grid (parent.updateData is expected to have already
            %   absorbed newX/newY into the parent before this call — we
            %   do not duplicate-append on the cold path).
            %
            %   Errors:
            %     MonitorTag:invalidData — newX/newY not numeric or not
            %                              the same length.
            if ~isnumeric(newX) || ~isnumeric(newY) || numel(newX) ~= numel(newY)
                error('MonitorTag:invalidData', ...
                    'appendData requires numeric newX and newY of equal length.');
            end
            if isempty(newX), return; end
            if obj.dirty_ || isempty(fieldnames(obj.cache_)) ...
                    || ~isfield(obj.cache_, 'x') || isempty(obj.cache_.x)
                % Cold start — full recompute over whatever the parent holds.
                obj.recompute_();
                return;
            end

            newX = newX(:).';
            newY = newY(:).';

            % Snapshot prior boundary-state BEFORE mutation (read by fire + merge).
            priorLastFlag     = obj.cache_.lastStateFlag_;
            priorHystState    = obj.cache_.lastHystState_;
            priorOngoingStart = obj.cache_.ongoingRunStart_;

            % Stage 1: raw condition evaluation on tail only
            raw_new = logical(obj.ConditionFn(newX, newY));

            % Stage 2: hysteresis FSM with carry-in
            finalHyst = priorHystState;
            if ~isempty(obj.AlarmOffConditionFn)
                [raw_new, finalHyst] = obj.applyHysteresis_( ...
                    newX, newY, raw_new, priorHystState);
            end

            % Stage 3: MinDuration debounce with carry-in ongoingRunStart
            newOngoing = priorOngoingStart;
            if obj.MinDuration > 0
                [raw_new, newOngoing] = obj.applyDebounce_( ...
                    newX, raw_new, priorOngoingStart);
            elseif ~isempty(raw_new) && raw_new(end)
                % No debounce — still track the open-run start forward.
                [sI, eI] = obj.findRuns_(raw_new);
                if ~isempty(eI) && eI(end) == numel(raw_new)
                    if sI(end) == 1 && ~isnan(priorOngoingStart)
                        newOngoing = priorOngoingStart;
                    else
                        newOngoing = newX(sI(end));
                    end
                end
            elseif ~isempty(raw_new) && ~raw_new(end)
                % Tail ends OFF -> no open run carried.
                newOngoing = NaN;
            end

            % Stage 4: emit events for runs that CLOSE inside newX.
            obj.fireEventsInTail_(newX, raw_new, priorLastFlag, priorOngoingStart);

            % Extend cache and write new boundary-state fields.
            obj.cache_.x = [obj.cache_.x, newX];
            obj.cache_.y = [obj.cache_.y, double(raw_new)];
            obj.cache_.computedAt       = now;
            obj.cache_.lastHystState_   = finalHyst;
            obj.cache_.ongoingRunStart_ = newOngoing;
            if ~isempty(raw_new)
                obj.cache_.lastStateFlag_ = double(raw_new(end));
            end
            % MONITOR-09: persist extended cache (single call site routes
            % through persistIfEnabled_; Pitfall 2 gate lives inside it).
            obj.persistIfEnabled_();
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
            %
            %   Phase 1007 (MONITOR-08): writes three additional cache_
            %   fields (lastHystState_, ongoingRunStart_, lastStateFlag_)
            %   so that a subsequent appendData() call can continue the
            %   pipeline at the boundary without recomputing the prefix.
            obj.recomputeCount_ = obj.recomputeCount_ + 1;
            [px, py] = obj.Parent.getXY();
            if isempty(px)
                obj.cache_ = struct( ...
                    'x',               [], ...
                    'y',               [], ...
                    'computedAt',      now, ...
                    'lastStateFlag_',  0, ...
                    'lastHystState_',  false, ...
                    'ongoingRunStart_', NaN);
                obj.dirty_ = false;
                return;
            end
            % Stage 1: raw condition evaluation
            raw = logical(obj.ConditionFn(px, py));
            % Stage 2: hysteresis (only when AlarmOffConditionFn is non-empty)
            finalHyst = false;
            if ~isempty(obj.AlarmOffConditionFn)
                [raw, finalHyst] = obj.applyHysteresis_(px, py, raw, false);
            end
            % Stage 3: MinDuration debounce (no-op when MinDuration == 0)
            newOngoing = NaN;
            if obj.MinDuration > 0
                [raw, newOngoing] = obj.applyDebounce_(px, raw, NaN);
            elseif ~isempty(raw) && raw(end)
                % No debounce active, but an open run at cache end still
                % needs its X-native start tracked for a future appendData
                % call to merge correctly.
                [sI, eI] = obj.findRuns_(raw);
                if ~isempty(eI) && eI(end) == numel(raw)
                    newOngoing = px(sI(end));
                end
            end
            % Stage 4: event emission on rising edges
            obj.fireEventsOnRisingEdges_(px, raw);
            % Write cache + boundary-state fields (read by appendData).
            lastFlag = 0;
            if ~isempty(raw), lastFlag = double(raw(end)); end
            obj.cache_ = struct( ...
                'x',               px(:).', ...
                'y',               double(raw(:).'), ...
                'computedAt',      now, ...
                'lastStateFlag_',  lastFlag, ...
                'lastHystState_',  finalHyst, ...
                'ongoingRunStart_', newOngoing);
            obj.dirty_ = false;
        end

        function [bin, finalState] = applyHysteresis_(obj, px, py, rawOn, initialState)
            %APPLYHYSTERESIS_ Two-state FSM — stay ON until AlarmOffConditionFn triggers.
            %   State OFF: flip to ON when ConditionFn(x, y) is true
            %   State ON : flip to OFF when AlarmOffConditionFn(x, y) is true
            %   Single pass over the parent grid (O(N)).
            %
            %   Phase 1007 (MONITOR-08): accepts `initialState` so a
            %   streaming appendData call can continue the FSM across the
            %   chunk boundary; returns `finalState` (the end-of-chunk FSM
            %   state) so the caller can persist it for the next append.
            if nargin < 5, initialState = false; end
            N = numel(rawOn);
            rawOff = logical(obj.AlarmOffConditionFn(px, py));
            bin = false(1, N);
            state = initialState;
            for i = 1:N
                if state
                    if rawOff(i), state = false; end
                else
                    if rawOn(i),  state = true;  end
                end
                bin(i) = state;
            end
            finalState = state;
        end

        function [bin, ongoingRunStart] = applyDebounce_(obj, px, bin, carryStartX)
            %APPLYDEBOUNCE_ Zero out contiguous runs of 1s shorter than MinDuration.
            %   Durations are in native parent-X units (same convention as
            %   EventDetector.MinDuration). Uses strict less-than, matching
            %   EventDetector.m:52 convention.
            %
            %   Phase 1007 (MONITOR-08): accepts `carryStartX` — the
            %   X-native start timestamp of an open run that crosses into
            %   this chunk from a prior appendData/recompute boundary
            %   (NaN when none). When the first run in `bin` starts at
            %   index 1 AND a carry is present, the effective duration is
            %   measured from `carryStartX` instead of px(1). Returns the
            %   new `ongoingRunStart` — NaN if the (possibly-mutated) bin
            %   ends OFF; otherwise the X-native start of the final run.
            if nargin < 4, carryStartX = NaN; end
            [sI, eI] = obj.findRuns_(bin);
            for k = 1:numel(sI)
                if k == 1 && ~isnan(carryStartX) && sI(k) == 1 && bin(1)
                    effectiveStart = carryStartX;
                else
                    effectiveStart = px(sI(k));
                end
                if px(eI(k)) - effectiveStart < obj.MinDuration
                    bin(sI(k):eI(k)) = false;
                end
            end
            % Determine new ongoingRunStart: if bin ends with a 1-run,
            % carry its effective start forward.
            ongoingRunStart = NaN;
            if ~isempty(bin) && bin(end)
                [sI2, eI2] = obj.findRuns_(bin);
                if ~isempty(sI2) && eI2(end) == numel(bin)
                    if sI2(end) == 1 && ~isnan(carryStartX)
                        ongoingRunStart = carryStartX;
                    else
                        ongoingRunStart = px(sI2(end));
                    end
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

        function fireEventsInTail_(obj, newX, bin_new, priorLastFlag, priorOngoingStart)
            %FIREEVENTSINTAIL_ Emit events ONLY for runs that close inside newX.
            %
            %   Phase 1007 (MONITOR-08) streaming-event emission.
            %   If priorLastFlag == 1 AND bin_new(1) == 1 the first run in
            %   the tail is a continuation of the open run; use
            %   priorOngoingStart as its effective StartTime. Runs still
            %   open at the tail end are NOT emitted — they carry forward
            %   as state for the next appendData call.
            %
            %   MONITOR-05 carrier pattern unchanged from Plan 02:
            %     SensorName     = obj.Parent.Key
            %     ThresholdLabel = obj.Key
            %   (Phase 1010 will migrate to a per-Tag keys array on Event.)
            if isempty(bin_new), return; end
            if isempty(obj.EventStore) ...
                    && isempty(obj.OnEventStart) ...
                    && isempty(obj.OnEventEnd)
                return;
            end
            [sI, eI] = obj.findRuns_(bin_new);
            for k = 1:numel(sI)
                if eI(k) == numel(bin_new)
                    % Run still open at tail end — don't emit yet.
                    continue;
                end
                if k == 1 && priorLastFlag == 1 && sI(k) == 1 ...
                        && ~isnan(priorOngoingStart)
                    startT = priorOngoingStart;
                else
                    startT = newX(sI(k));
                end
                endT = newX(eI(k));
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

        % ---- MONITOR-09 persistence helpers (Phase 1007 Plan 02) ----

        function tf = tryLoadFromDisk_(obj)
            %TRYLOADFROMDISK_ Populate cache_ from DataStore row if fresh.
            %   Returns true on hit + not stale; false on miss / stale / opt-out.
            %   Quad-signature staleness is compared against the parent's
            %   current grid (parent_key + num_points + parent_xmin/xmax).
            %   On a fresh hit, cache_ is rebuilt with lastStateFlag_ seeded
            %   from Y(end); lastHystState_ mirrors it; ongoingRunStart_ is
            %   NaN (safe default — cold-reload cannot reconstruct the
            %   open-run start without re-evaluating ConditionFn).
            tf = false;
            if ~obj.Persist || isempty(obj.DataStore); return; end
            [X, Y, meta] = obj.DataStore.loadMonitor(char(obj.Key));
            if isempty(X); return; end
            if obj.cacheIsStale_(meta); return; end
            lastFlag = 0;
            if ~isempty(Y), lastFlag = double(Y(end)); end
            obj.cache_ = struct( ...
                'x',               X(:).', ...
                'y',               Y(:).', ...
                'computedAt',      meta.computed_at, ...
                'lastStateFlag_',  lastFlag, ...
                'lastHystState_',  logical(lastFlag), ...
                'ongoingRunStart_', NaN);
            obj.dirty_ = false;
            tf = true;
        end

        function tf = cacheIsStale_(obj, meta)
            %CACHEISSTALE_ Quad-signature parent mutation detector.
            %   Compares meta.{parent_key, num_points, parent_xmin,
            %   parent_xmax} against the parent's current grid. O(1);
            %   Octave-portable; eps(x)*10 tolerance on xmin/xmax absorbs
            %   FP drift through SQLite double round-trip (see RESEARCH
            %   Open Question #3).
            tf = true;
            if isempty(obj.Parent); return; end
            [px, ~] = obj.Parent.getXY();
            if isempty(px); return; end
            if ~strcmp(char(meta.parent_key), char(obj.Parent.Key)); return; end
            if double(meta.num_points) ~= numel(px); return; end
            tol_lo = eps(px(1))   * 10;
            tol_hi = eps(px(end)) * 10;
            if abs(meta.parent_xmin - px(1))   > tol_lo; return; end
            if abs(meta.parent_xmax - px(end)) > tol_hi; return; end
            tf = false;
        end

        function persistIfEnabled_(obj)
            %PERSISTIFENABLED_ Single call site that writes cache_ to DataStore.
            %   Pitfall 2 structural gate: the ONLY storeMonitor call in
            %   MonitorTag.m lives directly under an `if obj.Persist` block
            %   within 5 lines. With Persist=false a bound DataStore sees
            %   zero SQLite writes.
            if isempty(obj.DataStore); return; end
            if isempty(fieldnames(obj.cache_)) || ~isfield(obj.cache_, 'x') ...
                    || isempty(obj.cache_.x)
                return;
            end
            if isempty(obj.Parent); return; end
            [px, ~] = obj.Parent.getXY();
            if isempty(px); return; end
            if obj.Persist
                obj.DataStore.storeMonitor(char(obj.Key), ...
                    obj.cache_.x, obj.cache_.y, ...
                    char(obj.Parent.Key), numel(px), px(1), px(end));
            end
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
                       'EventStore', 'OnEventStart', 'OnEventEnd', ...
                       'Persist', 'DataStore'};
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
