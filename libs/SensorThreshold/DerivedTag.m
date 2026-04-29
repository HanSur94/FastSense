classdef DerivedTag < Tag
    %DERIVEDTAG Continuous (X, Y) signal derived from N parent Tags via compute fn.
    %
    %   DerivedTag is the 5th concrete Tag class in the FastPlot Tag
    %   hierarchy — the continuous-output counterpart to MonitorTag
    %   (1 parent → 0/1) and CompositeTag (N children → 0/1). It produces
    %   a full (X, Y) time series by applying a user-supplied compute
    %   function (or compute object) to its parents' data. Output is
    %   lazy-memoized on the first getXY() call and recomputed only when
    %   invalidate() fires (directly or via a parent's DataChanged
    %   listener notification — see addListener wiring in the constructor).
    %
    %   This Phase 1008-r2b implementation is lazy-by-default and in-memory
    %   only — no DataStore persistence, no streaming appendData, no
    %   debouncing. Future v2 features (Persist, appendData, MinDuration,
    %   OnDataAvailable, multi-output, alignParentsZOH) are documented in
    %   docs/DerivedTag-spec.md §11 (out of scope here).
    %
    %   Lifecycle / cycle note (Pitfall 3 — Octave SIGILL):
    %     Parents hold strong refs to DerivedTag via listeners_; DerivedTag
    %     holds strong refs to Parents. This is intentional but creates a
    %     handle cycle. ALL handle equality MUST use strcmp(a.Key, b.Key)
    %     (TagRegistry guarantees globally-unique keys, so Key equality is
    %     semantically equivalent to handle equality within a registry
    %     session). Never use isequal/== on Tag handles — Octave SIGILLs
    %     when recursing through listener cycles.
    %
    %   Properties (public):
    %     Parents     — 1×N cell of Tag handles (required at construction)
    %     ComputeFn   — function_handle @(parents)->[X,Y], OR a handle
    %                   object with a method [X,Y] = compute(obj, parents).
    %                   Detected via ismethod(compute, 'compute').
    %     MinDuration — scalar double; reserved for v2 debouncing (default 0)
    %     EventStore  — EventStore handle; inherited from Tag base
    %
    %   Tag-contract methods:
    %     getXY        — lazy-memoized; recomputes on dirty
    %     valueAt(t)   — ZOH lookup into the cached (X, Y) via binary_search
    %     getTimeRange — [X(1), X(end)] or [NaN NaN] if empty
    %     getKind      — returns 'derived'
    %     toStruct     — serialize state. Function-handle ComputeFn stores
    %                    a func2str string but cannot round-trip — see §3.6
    %                    of the spec; the user must reattach the real handle
    %                    after fromStruct or invocation raises
    %                    DerivedTag:computeNotRehydrated. Object-form
    %                    ComputeFn stores class name + (optional) toStruct
    %                    state and DOES round-trip.
    %     fromStruct   — Static Pass-1 reconstruction; stashes parentkeys
    %                    in ParentKeys_ for Pass-2 resolveRefs.
    %     resolveRefs  — Pass-2: bind real Parents from the registry and
    %                    register self as listener on each.
    %
    %   DerivedTag-specific methods:
    %     invalidate         — clear cache, mark dirty, cascade to listeners
    %     addListener(l)     — register a downstream listener
    %     notifyListeners_   — internal observer fan-out
    %
    %   Error IDs (locked — see SPEC §4):
    %     DerivedTag:invalidParents              parents empty or non-Tag
    %     DerivedTag:invalidCompute              compute not fn handle / no compute()
    %     DerivedTag:unknownOption               unrecognized NV key
    %     DerivedTag:invalidListener             addListener target lacks invalidate()
    %     DerivedTag:computeReturnedNonNumeric   compute result non-numeric
    %     DerivedTag:computeShapeMismatch        X, Y length mismatch
    %     DerivedTag:dataMismatch                fromStruct missing required fields
    %     DerivedTag:unresolvedParent            resolveRefs missing key in registry
    %     DerivedTag:cycleDetected               cyclic parent graph (direct or transitive)
    %     DerivedTag:nonSerializableCompute      toStruct on opaque non-fn / non-object compute
    %     DerivedTag:computeNotRehydrated        deserialized invoked without ComputeFn rehydration
    %
    %   Cycle detection:
    %     The constructor runs a depth-first traversal over the parents'
    %     ancestry chain. If newKey appears anywhere in any parent's
    %     parents (transitively), DerivedTag:cycleDetected is raised at
    %     construction time. The DFS uses strcmp(a.Key, b.Key) — never
    %     handle equality — for Octave compatibility (see Pitfall 3 above).
    %
    %   Compute strategy contract:
    %     1. Function handle: signature [X, Y] = fn(parents) where parents
    %        is the same 1×N cell array passed to the constructor.
    %     2. Object: handle class instance with method
    %        [X, Y] = compute(obj, parents). Detected at construction via
    %        ismethod(compute, 'compute'). For round-tripping through
    %        toStruct/fromStruct, the class SHOULD also implement a
    %        toStruct() instance method and a fromStruct(s) static method
    %        (mirrors the Tag pattern). Otherwise default-construction is
    %        attempted at deserialization time.
    %
    %   Recompute pipeline:
    %     1. Dispatch on isa(ComputeFn, 'function_handle') vs.
    %        isobject(ComputeFn) && ismethod(ComputeFn, 'compute').
    %     2. Validate result: numeric X and Y, equal length.
    %     3. Reshape both to row vectors and store in cache_.
    %     4. Clear dirty_ flag.
    %
    %   Listener / observer:
    %     The constructor calls parent.addListener(obj) for every parent
    %     that exposes addListener (SensorTag, StateTag, MonitorTag,
    %     CompositeTag, DerivedTag all qualify; MockTag does too in
    %     tests). Subsequent parent.updateData(...) → parent.invalidate
    %     fan-out → DerivedTag.invalidate → notifyListeners_ cascades to
    %     any downstream MonitorTag/DerivedTag wrapping this one. This
    %     mirrors MonitorTag's listener wiring exactly.
    %
    %   No DataChanged event in invalidate (Pitfall 5):
    %     Cache invalidation does NOT fire `notify(obj, 'DataChanged')` —
    %     only SensorTag.updateData and StateTag mutators do. DerivedTag
    %     fires events implicitly via downstream consumers pulling getXY.
    %     This avoids flap loops in deeply-chained derivation graphs.
    %
    %   Examples:
    %     % --- Function-handle compute (the common case) ---
    %     a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
    %     b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
    %     d = DerivedTag('a_plus_b', {a, b}, ...
    %                    @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
    %     [x, y] = d.getXY();        % y = [3 5 7 9 11 13 15 17 19 21]
    %     a.updateData(1:10, 100*(1:10));
    %     [x, y] = d.getXY();        % automatically recomputed
    %
    %     % --- Object compute (round-trippable through toStruct) ---
    %     stub = ComputeAddStub(2);  % Scale = 2 (test-helper class)
    %     d2   = DerivedTag('a_plus_b_x2', {a, b}, stub);
    %     [~, y2] = d2.getXY();      % y2 = (a.Y + b.Y) * 2
    %
    %     % --- Pass-2 deserialization round-trip ---
    %     s = d2.toStruct();
    %     d3 = DerivedTag.fromStruct(s);
    %     reg = containers.Map({a.Key, b.Key}, {a, b});
    %     d3.resolveRefs(reg);       % wires real parents + listener
    %     [~, y3] = d3.getXY();      % matches y2 byte-for-byte
    %
    %   See also Tag, SensorTag, StateTag, MonitorTag, CompositeTag,
    %   TagRegistry, ComputeAddStub (tests/suite).

    properties
        Parents     = {}    % 1×N cell of Tag handles (required at construction)
        ComputeFn   = []    % function_handle, OR object with compute() method
        MinDuration = 0     % reserved for v2 debouncing; unused in v1
    end

    properties (Access = private)
        cache_      = struct()   % populated by recompute_(); fields x, y
        dirty_      = true       % true ⇒ cache stale; recompute on next getXY
        ParentKeys_ = {}         % Pass-1 deserialization stash (Pass-2 consumes)
        listeners_  = {}         % cell of handles notified on invalidate()
    end

    properties (SetAccess = private)
        recomputeCount_ = 0      % test probe — incremented every recompute_
    end

    methods
        function obj = DerivedTag(key, parents, compute, varargin)
            %DERIVEDTAG Construct a DerivedTag with N parents and a compute strategy.
            %   d = DerivedTag(key, parents, compute) creates a DerivedTag
            %   whose output is compute(parents) lazy-evaluated on first
            %   getXY() and recomputed automatically when any parent's
            %   updateData fires.
            %
            %   d = DerivedTag(key, parents, compute, Name, Value, ...)
            %   accepts both Tag universals (Name, Units, Description,
            %   Labels, Metadata, Criticality, SourceRef, EventStore) and
            %   DerivedTag-specific NV pairs (MinDuration — reserved for v2).
            %
            %   The new tag registers itself as a listener on every parent
            %   so that parent.updateData(...) triggers automatic cache
            %   invalidation. Cycle detection runs at construction time —
            %   any direct or transitive cycle in the parents' ancestry
            %   graph raises DerivedTag:cycleDetected.
            %
            %   Errors:
            %     DerivedTag:invalidParents — parents arg empty or contains non-Tag
            %     DerivedTag:invalidCompute — compute not a function_handle and not
            %                                 an object with a compute() method
            %     DerivedTag:unknownOption  — unrecognized or dangling NV key
            %     DerivedTag:cycleDetected  — cyclic parent graph (direct or transitive)

            % Parse NV pairs BEFORE obj access — Pitfall 8 (super-call ordering).
            [tagArgs, ownArgs] = DerivedTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});           % MUST be first statement

            % --- Validate parents ---
            if ~iscell(parents) || isempty(parents)
                error('DerivedTag:invalidParents', ...
                    'parents must be a non-empty cell of Tag handles.');
            end
            for k = 1:numel(parents)
                if ~isa(parents{k}, 'Tag')
                    error('DerivedTag:invalidParents', ...
                        'parents{%d} must be a Tag; got %s.', ...
                        k, class(parents{k}));
                end
            end

            % --- Validate compute ---
            if isempty(compute)
                error('DerivedTag:invalidCompute', ...
                    'compute argument is required and must be non-empty.');
            end
            isFn  = isa(compute, 'function_handle');
            isObj = isobject(compute) && ismethod(compute, 'compute');
            if ~isFn && ~isObj
                error('DerivedTag:invalidCompute', ...
                    'compute must be a function_handle or an object with a compute() method; got %s.', ...
                    class(compute));
            end

            % --- Cycle detection (DFS over parents' ancestry; Key equality) ---
            DerivedTag.checkCycles_(key, parents);

            % --- Apply own NV pairs ---
            for i = 1:2:numel(ownArgs)
                switch ownArgs{i}
                    case 'MinDuration'
                        obj.MinDuration = ownArgs{i+1};
                    otherwise
                        error('DerivedTag:unknownOption', ...
                            'Unknown NV key ''%s''.', ownArgs{i});
                end
            end

            obj.Parents   = parents;
            obj.ComputeFn = compute;

            % --- Register self as listener on each parent (auto-invalidation) ---
            for k = 1:numel(parents)
                if ismethod(parents{k}, 'addListener')
                    parents{k}.addListener(obj);
                end
            end
        end

        % ---- Tag contract ----

        function [X, Y] = getXY(obj)
            %GETXY Return lazy-memoized (X, Y) — recomputes on dirty.
            if obj.dirty_ || ~isfield(obj.cache_, 'x')
                obj.recompute_();
            end
            X = obj.cache_.x;
            Y = obj.cache_.y;
        end

        function v = valueAt(obj, t)
            %VALUEAT Right-biased ZOH lookup into the cached (X, Y).
            %   Mirrors StateTag.valueAt structure exactly: scalar branch
            %   uses a single binary_search call; vector branch loops one
            %   binary_search per query. Returns NaN-filled output if the
            %   compute returned an empty series.
            [X, Y] = obj.getXY();
            if isempty(X) || isempty(Y)
                v = nan(size(t));
                return;
            end
            if isscalar(t)
                idx = binary_search(X, t, 'right');
                v = Y(idx);
            else
                n = numel(t);
                v = zeros(1, n);
                for k = 1:n
                    idx = binary_search(X, t(k), 'right');
                    v(k) = Y(idx);
                end
                if ~isrow(t)
                    v = reshape(v, size(t));
                end
            end
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)] from getXY; [NaN NaN] if empty.
            [X, ~] = obj.getXY();
            if isempty(X)
                tMin = NaN;
                tMax = NaN;
                return;
            end
            tMin = X(1);
            tMax = X(end);
        end

        function k = getKind(~)
            %GETKIND Return the literal kind identifier 'derived'.
            k = 'derived';
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize state to a plain struct.
            %   Function-handle ComputeFn cannot round-trip cleanly
            %   (closures, anonymous fns) — toStruct stores
            %   s.computekind = 'function_handle' and s.computestr =
            %   func2str(...). fromStruct leaves a sentinel that errors
            %   with DerivedTag:computeNotRehydrated until the user
            %   reattaches the real handle.
            %
            %   Object ComputeFn stores s.computeclass = class(...) and
            %   (if the object implements toStruct) s.computestate. The
            %   round-trip path uses class([cls '.fromStruct'], state)
            %   when the class has a static fromStruct, falling back to
            %   default construction otherwise.
            %
            %   Errors:
            %     DerivedTag:nonSerializableCompute — ComputeFn is neither
            %                                         function handle nor object
            s = struct();
            s.kind        = 'derived';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.labels      = {obj.Labels};   % cellstr-collapse defense (Tag idiom)
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.sourceref   = obj.SourceRef;
            s.minduration = obj.MinDuration;

            % Parent keys (resolveRefs reattaches real handles in Pass 2).
            s.parentkeys = cellfun(@(p) p.Key, obj.Parents, ...
                'UniformOutput', false);

            % Compute strategy.
            if isa(obj.ComputeFn, 'function_handle')
                s.computekind = 'function_handle';
                s.computestr  = func2str(obj.ComputeFn);
            elseif isobject(obj.ComputeFn)
                s.computekind  = 'object';
                s.computeclass = class(obj.ComputeFn);
                if ismethod(obj.ComputeFn, 'toStruct')
                    s.computestate = obj.ComputeFn.toStruct();
                else
                    s.computestate = struct();   % opaque
                end
            else
                error('DerivedTag:nonSerializableCompute', ...
                    'ComputeFn is neither function_handle nor object.');
            end
        end

        function resolveRefs(obj, registry)
            %RESOLVEREFS Pass-2 hook to bind Parents from registry by key.
            %   Iterates ParentKeys_ (stashed by fromStruct), fetches each
            %   real handle from the registry, registers self as a listener
            %   on each, and clears ParentKeys_. Forces dirty_ = true so
            %   the next getXY() recomputes against the real parent data.
            %
            %   Errors: DerivedTag:unresolvedParent if any stashed key is
            %   missing from the registry.
            if isempty(obj.ParentKeys_)
                return;   % already resolved
            end
            real = cell(1, numel(obj.ParentKeys_));
            for k = 1:numel(obj.ParentKeys_)
                pk = obj.ParentKeys_{k};
                if ~registry.isKey(pk)
                    error('DerivedTag:unresolvedParent', ...
                        'Parent tag ''%s'' not registered.', pk);
                end
                real{k} = registry(pk);
                if ismethod(real{k}, 'addListener')
                    real{k}.addListener(obj);
                end
            end
            obj.Parents     = real;
            obj.ParentKeys_ = {};   % consumed
            obj.dirty_      = true;
            obj.cache_      = struct();
        end

        % ---- Public observer API ----

        function invalidate(obj)
            %INVALIDATE Clear cache + mark dirty; cascade to downstream listeners.
            %   Called automatically when a parent's listener fan-out
            %   reaches this DerivedTag (parent.updateData →
            %   parent.notifyListeners_ → invalidate). Also called
            %   directly by user code when ComputeFn semantics change.
            obj.dirty_ = true;
            obj.cache_ = struct();
            obj.notifyListeners_();
        end

        function addListener(obj, l)
            %ADDLISTENER Register a downstream listener.
            %   l must implement an invalidate() method (any Tag in the
            %   FastPlot domain qualifies; struct/handle objects with a
            %   bespoke invalidate also work). Listeners are held by
            %   strong reference — caller manages lifecycle.
            %
            %   Errors: DerivedTag:invalidListener if l does not implement invalidate().
            % Octave-safety: ismethod() throws on non-object/class inputs
            % (e.g. plain structs) instead of returning false. Guard with
            % an explicit object/class check before calling ismethod.
            isCallable = (isobject(l) || (ischar(l) && exist(l, 'class') == 8)) && ...
                ismethod(l, 'invalidate');
            if ~isCallable
                error('DerivedTag:invalidListener', ...
                    'Listener must implement invalidate(); got %s.', ...
                    class(l));
            end
            obj.listeners_{end+1} = l;
        end
    end

    methods (Access = private)
        function recompute_(obj)
            %RECOMPUTE_ Dispatch to ComputeFn, validate result, populate cache.
            %   Pipeline:
            %     1. Dispatch on function_handle vs. object-with-compute()
            %     2. Validate isnumeric(X), isnumeric(Y), numel match
            %     3. Reshape to row vectors, store in cache_, clear dirty_
            %
            %   Errors:
            %     DerivedTag:invalidCompute             — dispatch failed
            %     DerivedTag:computeReturnedNonNumeric  — non-numeric X or Y
            %     DerivedTag:computeShapeMismatch       — numel(X) ~= numel(Y)
            obj.recomputeCount_ = obj.recomputeCount_ + 1;
            if isa(obj.ComputeFn, 'function_handle')
                [X, Y] = obj.ComputeFn(obj.Parents);
            elseif isobject(obj.ComputeFn) && ismethod(obj.ComputeFn, 'compute')
                [X, Y] = obj.ComputeFn.compute(obj.Parents);
            else
                error('DerivedTag:invalidCompute', ...
                    'ComputeFn must be a function_handle or object with compute() method.');
            end

            if ~isnumeric(X) || ~isnumeric(Y)
                error('DerivedTag:computeReturnedNonNumeric', ...
                    'ComputeFn must return numeric X and Y.');
            end
            if numel(X) ~= numel(Y)
                error('DerivedTag:computeShapeMismatch', ...
                    'ComputeFn returned X (n=%d) and Y (n=%d) of different lengths.', ...
                    numel(X), numel(Y));
            end

            obj.cache_ = struct();
            obj.cache_.x = X(:).';
            obj.cache_.y = Y(:).';
            obj.dirty_   = false;
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
            %FROMSTRUCT Pass-1 reconstruction with sentinel parents + stashed keys.
            %   Required fields: s.key (non-empty char), s.parentkeys
            %   (cellstr of length ≥ 1). Pass-2 resolveRefs(registry) is
            %   responsible for swapping in real Parent handles.
            %
            %   For function-handle compute, ComputeFn is left as a sentinel
            %   that raises DerivedTag:computeNotRehydrated when invoked —
            %   the user must reattach the real handle after fromStruct.
            %   For object-compute, fromStruct attempts to rehydrate the
            %   class via [class '.fromStruct'](computestate) when the
            %   class exists and exposes a static fromStruct method;
            %   otherwise default-construction is used.
            %
            %   Errors:
            %     DerivedTag:dataMismatch — missing required field (key, parentkeys)
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('DerivedTag:dataMismatch', ...
                    'fromStruct requires a struct with non-empty .key.');
            end
            if ~isfield(s, 'parentkeys') || isempty(s.parentkeys)
                error('DerivedTag:dataMismatch', ...
                    'fromStruct requires non-empty .parentkeys (Pass-2 resolves handles).');
            end

            % Unwrap parentkeys defensively (may have been double-wrapped
            % by JSON serializers; tolerate both shapes).
            pkeys = s.parentkeys;
            if iscell(pkeys) && numel(pkeys) == 1 && iscell(pkeys{1})
                pkeys = pkeys{1};
            end
            if ~iscell(pkeys) || isempty(pkeys)
                error('DerivedTag:dataMismatch', ...
                    '.parentkeys must be a non-empty cellstr.');
            end

            % Build placeholder parents (one dummy SensorTag per key,
            % replaced in resolveRefs Pass 2). The dummy keys are
            % deliberately namespaced so they never collide with real
            % keys in the registry.
            dummyParents = cell(1, numel(pkeys));
            for k = 1:numel(pkeys)
                dummyParents{k} = SensorTag( ...
                    ['__derived_pass1_dummy_' pkeys{k} '__']);
            end

            % Sentinel compute that errors if invoked before rehydration.
            sentinelCompute = @(~) DerivedTag.computeNotRehydratedError_(s.key);

            % Tag-universal NV pairs from struct.
            tagNV = {};
            if isfield(s, 'name'),        tagNV(end+1:end+2) = {'Name',        s.name};        end %#ok<AGROW>
            if isfield(s, 'units'),       tagNV(end+1:end+2) = {'Units',       s.units};       end %#ok<AGROW>
            if isfield(s, 'description'), tagNV(end+1:end+2) = {'Description', s.description}; end %#ok<AGROW>
            if isfield(s, 'labels')
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}), L = L{1}; end
                if iscell(L)
                    tagNV(end+1:end+2) = {'Labels', L}; %#ok<AGROW>
                end
            end
            if isfield(s, 'metadata') && isstruct(s.metadata)
                tagNV(end+1:end+2) = {'Metadata',    s.metadata};    %#ok<AGROW>
            end
            if isfield(s, 'criticality') && ~isempty(s.criticality)
                tagNV(end+1:end+2) = {'Criticality', s.criticality}; %#ok<AGROW>
            end
            if isfield(s, 'sourceref') && ~isempty(s.sourceref)
                tagNV(end+1:end+2) = {'SourceRef',   s.sourceref};   %#ok<AGROW>
            end

            ownNV = {};
            if isfield(s, 'minduration') && ~isempty(s.minduration)
                ownNV(end+1:end+2) = {'MinDuration', s.minduration}; %#ok<AGROW>
            end

            obj = DerivedTag(s.key, dummyParents, sentinelCompute, ...
                tagNV{:}, ownNV{:});
            obj.ParentKeys_ = pkeys;          % Pass-2 will consume
            obj.Parents     = {};             % cleared until resolveRefs

            % Object-compute rehydration (function-handle case keeps the sentinel).
            if isfield(s, 'computekind') && strcmp(s.computekind, 'object')
                if isfield(s, 'computeclass') && ~isempty(s.computeclass)
                    cls = s.computeclass;
                    if exist(cls, 'class') == 8
                        state = struct();
                        if isfield(s, 'computestate') && isstruct(s.computestate)
                            state = s.computestate;
                        end
                        % Octave does NOT accept feval('Class.method', ...);
                        % use str2func to grab the static method directly.
                        % Both MATLAB and Octave 7+ support str2func on the
                        % 'Class.method' form for static methods.
                        if ismethod(cls, 'fromStruct')
                            fh = str2func([cls '.fromStruct']);
                            obj.ComputeFn = fh(state);
                        else
                            obj.ComputeFn = feval(cls);   % default-construct
                        end
                    end
                end
            end
            % function_handle case: ComputeFn stays as sentinel; user rehydrates.
        end
    end

    methods (Static, Access = private)
        function [tagArgs, ownArgs] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag NV pairs vs DerivedTag NV pairs.
            %   Unknown and dangling keys both raise DerivedTag:unknownOption.
            tagKeys = {'Name', 'Units', 'Description', 'Labels', ...
                       'Metadata', 'Criticality', 'SourceRef', 'EventStore'};
            ownKeys = {'MinDuration'};
            tagArgs = {};
            ownArgs = {};
            i = 1;
            while i <= numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('DerivedTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', k);
                end
                v = args{i + 1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k; %#ok<AGROW>
                    tagArgs{end+1} = v; %#ok<AGROW>
                elseif any(strcmp(k, ownKeys))
                    ownArgs{end+1} = k; %#ok<AGROW>
                    ownArgs{end+1} = v; %#ok<AGROW>
                else
                    error('DerivedTag:unknownOption', ...
                        'Unknown NV key ''%s''.', k);
                end
                i = i + 2;
            end
        end

        function checkCycles_(newKey, parents)
            %CHECKCYCLES_ DFS through any DerivedTag descendants; raise on collision.
            %   Iterates each parent and (if the parent is itself a
            %   DerivedTag) recursively walks its parent chain looking for
            %   newKey. Self-reference (a parent whose Key == newKey) is
            %   caught at the top of the walk in dfs_.
            for k = 1:numel(parents)
                p = parents{k};
                DerivedTag.dfs_(newKey, p);
            end
        end

        function dfs_(targetKey, node)
            %DFS_ Depth-first search for targetKey in node's ancestry.
            %   Uses strcmp(node.Key, targetKey) — never handle equality —
            %   for Octave-safe traversal of the listener-cycle graph.
            if strcmp(node.Key, targetKey)
                error('DerivedTag:cycleDetected', ...
                    'Cycle: ''%s'' is its own ancestor via parent ''%s''.', ...
                    targetKey, node.Key);
            end
            if isa(node, 'DerivedTag')
                for k = 1:numel(node.Parents)
                    DerivedTag.dfs_(targetKey, node.Parents{k});
                end
            end
        end

        function [X, Y] = computeNotRehydratedError_(key)  %#ok<STOUT>
            %COMPUTENOTREHYDRATEDERROR_ Sentinel raised by deserialized DerivedTag.
            %   The function-handle ComputeFn cannot round-trip through
            %   toStruct/fromStruct (closures, anonymous fns can't be
            %   reconstructed safely). fromStruct installs this static
            %   method as the ComputeFn so that any getXY() before the
            %   user reattaches the real handle raises a clear,
            %   namespaced error rather than a cryptic eval failure.
            error('DerivedTag:computeNotRehydrated', ...
                'DerivedTag ''%s'' was deserialized without ComputeFn rehydration.', key);
        end
    end
end
