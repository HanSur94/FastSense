classdef CompositeTag < Tag
    %COMPOSITETAG Aggregate MonitorTag/CompositeTag children into a 0/1 derived series.
    %
    %   CompositeTag < Tag -- a derived-signal Tag that aggregates 1..N
    %   MonitorTag/CompositeTag children into a single 0/1 (or 0..1
    %   severity-pre-threshold) time series via k-way merge-sort ZOH
    %   streaming (implemented in Plan 02; Plan 01 ships the core API only:
    %   constructor, addChild cycle-DFS + type-guard + listener hookup, and
    %   the 7-mode aggregator helper).
    %
    %   Truth Table (binary 0/1 inputs; NaN = unknown):
    %
    %     AND:
    %       | c1  | c2  | out  |
    %       |  0  |  0  |  0   |
    %       |  0  |  1  |  0   |
    %       |  1  |  1  |  1   |
    %       |  0  | NaN | NaN  |
    %       |  1  | NaN | NaN  |
    %       | NaN | NaN | NaN  |
    %
    %     OR:
    %       | c1  | c2  | out  |
    %       |  0  |  0  |  0   |
    %       |  0  |  1  |  1   |
    %       |  1  |  1  |  1   |
    %       |  0  | NaN |  0   |   (other operand wins)
    %       |  1  | NaN |  1   |   (other operand wins)
    %       | NaN | NaN | NaN  |
    %
    %     WORST:    max(vals) ignoring NaN; all-NaN -> NaN.  Matches
    %               MATLAB `max([...], 'omitnan')` semantics.
    %     COUNT:    sum of (vals >= 0.5) ignoring NaN; then thresholded
    %               by obj.Threshold to 0/1.
    %     MAJORITY: #ones > (#non-NaN)/2 -> 1; all-NaN -> NaN.  Strictly
    %               binary 0/1 inputs for v2.0 (multi-state deferred).
    %     SEVERITY: weighted avg (sum(w_i*v_i)/sum(w_i)) over non-NaN,
    %               then thresholded by obj.Threshold to 0/1.  All-NaN or
    %               zero-weight -> NaN.
    %     USER_FN:  obj.UserFn(vals) -- caller handles NaN semantics.
    %
    %   Properties (public):
    %     AggregateMode -- 'and'|'or'|'majority'|'count'|'worst'|'severity'|'user_fn'
    %     UserFn        -- function_handle; required when mode=='user_fn'
    %     Threshold     -- double; for COUNT/SEVERITY binarization (default 0.5)
    %
    %   Methods (public):
    %     addChild(tagOrKey, 'Weight', w) -- resolves string keys via TagRegistry;
    %                                        cycle DFS (Key-equality per RESEARCH §7);
    %                                        rejects SensorTag/StateTag
    %     invalidate() / addListener(m)   -- observer pattern (inherited shape)
    %     getChildCount / getChildKeys    -- read-only inspection probes
    %     getChildWeights / isDirty       -- read-only inspection probes
    %     getChildAt(i)                   -- i-th child Tag handle (3-deep descent)
    %     getKind()                       -- returns 'composite'
    %
    %   Methods (Tag contract -- Plan 02 merge-sort + serialization):
    %     getXY()         -- lazy-memoized union-of-timestamps grid via
    %                        RESEARCH §5 vectorized sort-based merge
    %                        (no set union, no linear interpolation; ALIGN-03)
    %     valueAt(t)      -- COMPOSITE-06 fast path; aggregates
    %                        child.valueAt(t) without materializing series
    %     getTimeRange()  -- [X(1), X(end)] of the aggregated grid
    %     toStruct()      -- serialize to {kind, key, ..., childkeys,
    %                        childweights, aggregatemode, threshold}
    %     fromStruct(s)   -- Static Pass-1 ctor; stashes ChildKeys_ for Pass-2
    %     resolveRefs(r)  -- Pass-2 wiring; iterates ChildKeys_ and calls
    %                        obj.addChild(registry(k), 'Weight', w) per child
    %
    %   Error IDs (locked):
    %     CompositeTag:cycleDetected        -- addChild would create cycle
    %                                          (self or deeper via Key-equality DFS)
    %     CompositeTag:invalidChildType     -- child is not MonitorTag/CompositeTag
    %     CompositeTag:invalidAggregateMode -- AggregateMode not in 7-mode list
    %     CompositeTag:userFnRequired       -- mode=='user_fn' but UserFn empty
    %     CompositeTag:unknownOption        -- constructor NV-pair unknown
    %     CompositeTag:invalidListener      -- addListener target lacks invalidate()
    %     CompositeTag:dataMismatch         -- fromStruct missing required .key
    %     CompositeTag:unresolvedChild      -- resolveRefs key not in registry
    %     CompositeTag:indexOutOfBounds     -- getChildAt index out of range
    %
    %   Cycle-detection note (RESEARCH §7 / Pitfall 3 Octave SIGILL):
    %     CompositeTag EXPLICITLY creates listener cycles (addChild wires
    %     composite as listener on child).  Octave's `isequal`/`==` on
    %     user-defined handles recurses through listener cells and hits
    %     SIGILL.  Use Key equality (`strcmp(a.Key, b.Key)`) for all handle
    %     identity checks -- TagRegistry enforces globally-unique keys so
    %     Key equality is semantically equivalent to handle equality within
    %     a registry session AND Octave-safe.
    %
    %   See also Tag, MonitorTag, TagRegistry, CompositeThreshold (legacy).

    properties
        AggregateMode = 'and'  % 'and'|'or'|'majority'|'count'|'worst'|'severity'|'user_fn'
        UserFn        = []     % function_handle; required for 'user_fn'
        Threshold     = 0.5    % for COUNT/SEVERITY binarization
    end

    properties (Access = private)
        children_     = {}         % cell of struct('tag', handle, 'weight', double)
        cache_        = struct()   % Plan 02 populates via mergeStream_
        dirty_        = true       % logical
        listeners_    = {}         % cell of CompositeTags wrapping this one
        ChildKeys_    = {}         % Pass-1 stash (Plan 02 resolveRefs consumes)
        ChildWeights_ = []         % Pass-1 stash
    end

    properties (SetAccess = private)
        recomputeCount_ = 0        % test probe (Plan 02 wires mergeStream_ to increment)
    end

    methods

        function obj = CompositeTag(key, aggregateMode, varargin)
            %COMPOSITETAG Construct a CompositeTag with aggregation mode + Tag NV pairs.
            %   c = CompositeTag(key)                       -- mode defaults to 'and'
            %   c = CompositeTag(key, mode)                 -- mode in the 7-mode set
            %   c = CompositeTag(key, mode, NV, NV, ...)    -- Tag + CompositeTag NV pairs
            %
            %   Accepts Tag universals (Name, Units, Description, Labels,
            %   Metadata, Criticality, SourceRef) AND CompositeTag-specific
            %   NV pairs (UserFn, Threshold).  Unknown keys raise
            %   CompositeTag:unknownOption.
            %
            %   Errors:
            %     Tag:invalidKey                    -- key empty / not char
            %     CompositeTag:invalidAggregateMode -- mode not in 7-mode set
            %     CompositeTag:userFnRequired       -- mode=='user_fn' and UserFn empty
            %     CompositeTag:unknownOption        -- unrecognized NV key
            [tagArgs, cmpArgs] = CompositeTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});  % MUST be first -- Octave ctor rule
            if nargin < 2 || isempty(aggregateMode)
                aggregateMode = 'and';
            end
            mode = lower(char(aggregateMode));
            CompositeTag.validateMode_(mode);
            obj.AggregateMode = mode;
            for i = 1:2:numel(cmpArgs)
                switch cmpArgs{i}
                    case 'UserFn'
                        obj.UserFn = cmpArgs{i+1};
                    case 'Threshold'
                        obj.Threshold = cmpArgs{i+1};
                end
            end
            if strcmp(obj.AggregateMode, 'user_fn') && isempty(obj.UserFn)
                error('CompositeTag:userFnRequired', ...
                    'AggregateMode ''user_fn'' requires UserFn function_handle.');
            end
        end

        % ---- Public child management ----

        function addChild(obj, tagOrKey, varargin)
            %ADDCHILD Attach a MonitorTag/CompositeTag child with optional Weight.
            %   addChild(tagHandle)               -- handle path
            %   addChild('keyString')             -- registry-resolved path
            %   addChild(tagOrKey, 'Weight', w)   -- SEVERITY-mode weight (default 1.0)
            %
            %   Cycle-detection runs BEFORE storing the child (Pitfall 6
            %   semantics timing) via Key-equality DFS (RESEARCH §7).
            %
            %   Errors:
            %     CompositeTag:invalidChildType -- tag is not MonitorTag/CompositeTag
            %     CompositeTag:cycleDetected    -- would close a cycle
            %     TagRegistry:unknownKey        -- string key not registered
            if ischar(tagOrKey) || isstring(tagOrKey)
                tag = TagRegistry.get(char(tagOrKey));
            else
                tag = tagOrKey;
            end
            if ~isa(tag, 'MonitorTag') && ~isa(tag, 'CompositeTag')
                error('CompositeTag:invalidChildType', ...
                    'Only MonitorTag or CompositeTag allowed as children (got %s).', ...
                    class(tag));
            end
            if obj.wouldCreateCycle_(tag)
                error('CompositeTag:cycleDetected', ...
                    'Adding child %s would create a cycle.', tag.Key);
            end
            weight = 1.0;
            for i = 1:2:numel(varargin)
                if strcmpi(varargin{i}, 'Weight')
                    weight = varargin{i+1};
                end
            end
            obj.children_{end+1} = struct('tag', tag, 'weight', weight);
            if ismethod(tag, 'addListener')
                tag.addListener(obj);
            end
            obj.invalidate();
        end

        % ---- Observer pattern (mirrors MonitorTag lines 295-318) ----

        function invalidate(obj)
            %INVALIDATE Clear cache + mark dirty; cascade to downstream listeners.
            obj.dirty_ = true;
            obj.cache_ = struct();
            obj.notifyListeners_();
        end

        function addListener(obj, m)
            %ADDLISTENER Register a listener notified when this composite invalidates.
            %   Errors: CompositeTag:invalidListener if ~ismethod(m, 'invalidate').
            if ~ismethod(m, 'invalidate')
                error('CompositeTag:invalidListener', ...
                    'Listener must implement invalidate(); got %s.', class(m));
            end
            obj.listeners_{end+1} = m;
        end

        % ---- Read-only inspection probes (test-affordance API) ----

        function n = getChildCount(obj)
            %GETCHILDCOUNT Return the number of attached children.
            n = numel(obj.children_);
        end

        function keys = getChildKeys(obj)
            %GETCHILDKEYS Return a cellstr of child Keys (order preserved).
            keys = cell(1, numel(obj.children_));
            for i = 1:numel(obj.children_)
                keys{i} = obj.children_{i}.tag.Key;
            end
        end

        function w = getChildWeights(obj)
            %GETCHILDWEIGHTS Return a numeric row vector of child weights.
            w = zeros(1, numel(obj.children_));
            for i = 1:numel(obj.children_)
                w(i) = obj.children_{i}.weight;
            end
        end

        function tf = isDirty(obj)
            %ISDIRTY Return whether the composite cache is stale.
            tf = obj.dirty_;
        end

        function k = getKind(~)
            %GETKIND Return the literal kind identifier 'composite'.
            k = 'composite';
        end

        % ---- Tag contract (merge-sort streaming, fast-path valueAt) ----

        function [x, y] = getXY(obj)
            %GETXY Lazy-memoized union-of-timestamps grid via merge-sort streaming.
            %   Aggregates every child's (X, Y) via the RESEARCH §5
            %   vectorized sort-based algorithm (no set-union, no linear
            %   interpolation).  Drops samples before `max(child.X(1))`
            %   per ALIGN-03.  Cache stays warm across calls; invalidate()
            %   (cascade from any child) clears it.
            if obj.dirty_ || ~isfield(obj.cache_, 'x')
                obj.mergeStream_();
            end
            x = obj.cache_.x;
            y = obj.cache_.y;
        end

        function v = valueAt(obj, t)
            %VALUEAT COMPOSITE-06 fast-path -- aggregate child.valueAt(t).
            %   Iterates children and aggregates their instantaneous
            %   scalar values; NEVER materializes the full series.  Does
            %   NOT increment recomputeCount_ and does NOT warm the cache.
            %   At N=8 children, depth 3, log(M)=17 -> ~400 ops per call
            %   (sub-microsecond vs. ~150ms for a full getXY).
            n = numel(obj.children_);
            if n == 0
                v = NaN;
                return;
            end
            vals    = zeros(1, n);
            weights = zeros(1, n);
            for i = 1:n
                c = obj.children_{i};
                vals(i)    = c.tag.valueAt(t);
                weights(i) = c.weight;
            end
            v = CompositeTag.aggregate_(vals, weights, ...
                obj.AggregateMode, obj.UserFn, obj.Threshold);
        end

        function [tMin, tMax] = getTimeRange(obj)
            %GETTIMERANGE Return [X(1), X(end)] of the aggregated grid.
            %   Warms the merge-sort cache if cold.  Returns [NaN NaN] when
            %   there are no children or any child has no data.
            [x, ~] = obj.getXY();
            if isempty(x)
                tMin = NaN;
                tMax = NaN;
                return;
            end
            tMin = x(1);
            tMax = x(end);
        end

        function s = toStruct(obj)
            %TOSTRUCT Serialize CompositeTag to a plain struct.
            %   Emits {kind='composite', key, name, labels, metadata,
            %   criticality, units, description, sourceref, aggregatemode,
            %   threshold, childkeys, childweights}.  UserFn is NOT
            %   serialized (function handles cannot round-trip); consumers
            %   must re-bind UserFn after loadFromStructs for 'user_fn' mode.
            %   childkeys is double-wrapped (cell-in-cell) to survive the
            %   MATLAB struct() cellstr-collapse idiom; fromStruct unwraps.
            s = struct();
            s.kind          = 'composite';
            s.key           = obj.Key;
            s.name          = obj.Name;
            s.labels        = {obj.Labels};   % double-wrap (Tag idiom)
            s.metadata      = obj.Metadata;
            s.criticality   = obj.Criticality;
            s.units         = obj.Units;
            s.description   = obj.Description;
            s.sourceref     = obj.SourceRef;
            s.aggregatemode = obj.AggregateMode;
            s.threshold     = obj.Threshold;

            nKids = numel(obj.children_);
            childKeys    = cell(1, nKids);
            childWeights = zeros(1, nKids);
            for i = 1:nKids
                childKeys{i}    = obj.children_{i}.tag.Key;
                childWeights(i) = obj.children_{i}.weight;
            end
            s.childkeys    = {childKeys};     % double-wrap (survives struct())
            s.childweights = childWeights;
        end

        function resolveRefs(obj, registry)
            %RESOLVEREFS Pass-2 hook -- wire stashed ChildKeys_ via addChild.
            %   Called by TagRegistry.loadFromStructs (and local two-pass
            %   loaders during Plan 02 tests).  Re-uses the validated
            %   addChild path so type guard + cycle DFS + listener hookup
            %   all run on deserialized children.
            %
            %   Errors: CompositeTag:unresolvedChild if a stashed key is
            %   missing from the registry.
            if isempty(obj.ChildKeys_)
                return;
            end
            for i = 1:numel(obj.ChildKeys_)
                key = obj.ChildKeys_{i};
                if ~registry.isKey(key)
                    error('CompositeTag:unresolvedChild', ...
                        'Child tag ''%s'' not registered.', key);
                end
                childHandle = registry(key);
                weight = 1.0;
                if i <= numel(obj.ChildWeights_)
                    weight = obj.ChildWeights_(i);
                end
                obj.addChild(childHandle, 'Weight', weight);
            end
            obj.ChildKeys_    = {};
            obj.ChildWeights_ = [];
            obj.invalidate();
        end

        function tag = getChildAt(obj, i)
            %GETCHILDAT Return the Tag handle of the i-th child (1-based).
            %   Test-affordance API for 3-deep descent assertions
            %   (Pitfall 8 round-trip).  Not a mutation path -- child
            %   insertion goes through addChild.
            %
            %   Errors: CompositeTag:indexOutOfBounds.
            if i < 1 || i > numel(obj.children_)
                error('CompositeTag:indexOutOfBounds', ...
                    'Child index %d out of bounds (have %d children).', ...
                    i, numel(obj.children_));
            end
            tag = obj.children_{i}.tag;
        end

    end

    methods (Access = private)

        function notifyListeners_(obj)
            %NOTIFYLISTENERS_ Iterate listeners_ and call invalidate() on each.
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
        end

        function mergeStream_(obj)
            %MERGESTREAM_ Vectorized sort-based k-way merge (RESEARCH §5).
            %   Concatenates every child's (X, Y, childIdx) triples,
            %   sorts once by X, then walks the sorted stream maintaining
            %   `lastY(childIdx) = Y` (ZOH).  Emits (X, aggregate) at each
            %   unique timestamp once `X >= first_x = max(child_first_x)`
            %   (ALIGN-03 pre-history drop).  Same-timestamp collisions
            %   coalesce -- aggregation runs once at the LAST sample of
            %   the cluster so every contributing child has registered.
            %
            %   Memory: O(Sum len_i) for concat + O(M) output preallocation.
            %   Time:   O(M log M) single sort + O(M) walk + O(numEmits)
            %           vectorized aggregate.
            %   NO set-union; NO linear interpolation (ZOH via lastY update).
            %
            %   Performance note (Plan 1008-03 calibration):
            %     Pre-Plan-03 drafts called aggregate_ inside the sorted-stream
            %     hot loop (scalar static-method dispatch per emit).  Octave's
            %     interpreter overhead on static-method calls (~50us / call)
            %     made the 8 children x 100k sample workload run ~5s (50x over
            %     the 200ms gate).  Fix: the hot loop now ONLY maintains the
            %     lastY state + captures a snapshot matrix at each emit index;
            %     aggregation runs ONCE vectorized over the captured matrix.
            obj.recomputeCount_ = obj.recomputeCount_ + 1;
            N = numel(obj.children_);
            if N == 0
                obj.cache_ = struct('x', [], 'y', []);
                obj.dirty_ = false;
                return;
            end
            % Pre-concatenate (X, Y, childIdx) per child.
            allX     = cell(1, N);
            allY     = cell(1, N);
            allChild = cell(1, N);
            weights  = zeros(1, N);
            for i = 1:N
                c = obj.children_{i};
                [xi, yi] = c.tag.getXY();
                allX{i}     = xi(:).';
                allY{i}     = yi(:).';
                allChild{i} = i * ones(1, numel(xi));
                weights(i)  = c.weight;
            end
            % Any-empty-child short-circuit -- produce empty output.
            if any(cellfun(@isempty, allX))
                obj.cache_ = struct('x', [], 'y', []);
                obj.dirty_ = false;
                return;
            end
            cat_X     = [allX{:}];
            cat_Y     = [allY{:}];
            cat_Child = [allChild{:}];
            [sortedX, order] = sort(cat_X);
            sortedY     = cat_Y(order);
            sortedChild = cat_Child(order);

            % ALIGN-03 pre-history drop: skip samples before all children
            % have started.  `first_x = max(child.X(1))`.
            first_x = max(cellfun(@(xx) xx(1), allX));

            M = numel(sortedX);
            % Vectorized emit-mask: emit at k iff (k == M) || (sortedX(k+1) ~= sortedX(k)) AND sortedX(k) >= first_x.
            emitMask = [sortedX(1:M-1) ~= sortedX(2:M), true] & (sortedX >= first_x);
            emitIdx  = find(emitMask);
            nOut     = numel(emitIdx);
            if nOut == 0
                obj.cache_ = struct('x', [], 'y', []);
                obj.dirty_ = false;
                return;
            end
            % Capture phase VECTORIZED (Plan 1008-03 perf fix):
            % For each child c, forward-fill its last-known value across the
            % sorted stream, then subsample at emitIdx.  No scalar loops over
            % M=800k; pure vector ops per child (cummax over index-of-last
            % non-NaN position).  Octave interpreter overhead eliminated.
            lastYMatrix = nan(nOut, N);
            posAll = 1:M;
            for c = 1:N
                cMask = (sortedChild == c);
                % Vectorized "index-of-most-recent-non-NaN-for-this-child":
                % at positions where cMask is true, carry the position index
                % forward; cummax fills gaps with the last true-position.
                idxAtPos = posAll;
                idxAtPos(~cMask) = 0;
                lastIdxAtPos = cummax(idxAtPos);
                % Subsample at emit rows.
                lastIdxAtEmit = lastIdxAtPos(emitIdx);
                hasHist = lastIdxAtEmit > 0;
                col = nan(nOut, 1);
                if any(hasHist)
                    col(hasHist) = sortedY(lastIdxAtEmit(hasHist));
                end
                lastYMatrix(:, c) = col;
            end
            % Vectorized aggregate over (nOut x N) matrix -- ONE dispatch total.
            Y_col = CompositeTag.aggregateMatrix_(lastYMatrix, weights, ...
                obj.AggregateMode, obj.UserFn, obj.Threshold);
            X_out = sortedX(emitIdx);
            if ~isrow(X_out), X_out = X_out(:).'; end
            Y_out = Y_col(:).';                      % row-shape for consistency
            obj.cache_ = struct( ...
                'x', X_out, ...
                'y', Y_out);
            obj.dirty_ = false;
        end

        function cycle = wouldCreateCycle_(obj, newChild)
            %WOULDCREATECYCLE_ Key-equality DFS cycle check (RESEARCH §7).
            %   Returns true iff `obj` is reachable from `newChild` via the
            %   children_ graph.  NEVER uses `isequal`/`==` on handles --
            %   Octave SIGILLs on handle-compare with listener cycles and
            %   CompositeTag always creates such cycles.
            cycle = false;
            % Self-reference (trivial cycle)
            if strcmp(newChild.Key, obj.Key)
                cycle = true;
                return;
            end
            % DFS from newChild looking for obj via Key equality.
            visitedKeys = {newChild.Key};
            stack       = {newChild};
            while ~isempty(stack)
                cur = stack{end};
                stack(end) = [];
                if isa(cur, 'CompositeTag')
                    for i = 1:numel(cur.children_)
                        gc = cur.children_{i}.tag;
                        if strcmp(gc.Key, obj.Key)
                            cycle = true;
                            return;
                        end
                        if ~any(cellfun(@(k) strcmp(k, gc.Key), visitedKeys))
                            visitedKeys{end+1} = gc.Key; %#ok<AGROW>
                            stack{end+1}       = gc;     %#ok<AGROW>
                        end
                    end
                end
            end
        end

    end

    methods (Static, Access = private)

        function validateMode_(mode)
            %VALIDATEMODE_ Gate AggregateMode against the 7-mode set.
            valid = {'and', 'or', 'majority', 'count', 'worst', ...
                     'severity', 'user_fn'};
            if ~any(strcmp(mode, valid))
                error('CompositeTag:invalidAggregateMode', ...
                    'AggregateMode must be one of: %s. Got ''%s''.', ...
                    strjoin(valid, ', '), mode);
            end
        end

        function out = aggregateMatrix_(M, weights, mode, userFn, threshold)
            %AGGREGATEMATRIX_ Vectorized per-row aggregate over (nRows x N) matrix.
            %   Produces byte-for-byte the same scalar result as row-by-row
            %   aggregate_ calls -- proven via testAggregateMatrixParityVsScalar
            %   in TestCompositeTagAlign.  Moves the mode dispatch OUT of the
            %   mergeStream_ hot loop (Plan 1008-03 perf fix).
            %
            %   Inputs:
            %     M         -- nRows x N matrix; rows are per-timestamp lastY
            %                  snapshots; columns are children.  NaN means
            %                  "child has not reported a value yet at this t".
            %     weights   -- 1 x N weights vector (SEVERITY only).
            %     mode      -- AggregateMode string (lowercase).
            %     userFn    -- function_handle (USER_FN only).
            %     threshold -- scalar for COUNT/SEVERITY binarization.
            %
            %   Output:
            %     out       -- nRows x 1 double column vector (0 / 1 / NaN for
            %                  built-in modes; whatever userFn returns for USER_FN).
            [nRows, N] = size(M);
            switch mode
                case 'and'
                    rowHasNan = any(isnan(M), 2);
                    allOnes   = all(M >= 0.5, 2);
                    out       = double(allOnes);
                    out(rowHasNan) = NaN;
                case 'or'
                    nonNanCount = sum(~isnan(M), 2);
                    anyOne      = any(M >= 0.5, 2);
                    out         = double(anyOne);
                    out(nonNanCount == 0) = NaN;
                case 'majority'
                    mask        = ~isnan(M);
                    nonNanCount = sum(mask, 2);
                    onesMatrix  = M >= 0.5;
                    onesMatrix(~mask) = false;  % exclude NaN positions
                    onesCount   = sum(onesMatrix, 2);
                    out         = double(onesCount > nonNanCount / 2);
                    out(nonNanCount == 0) = NaN;
                case 'count'
                    mask       = ~isnan(M);
                    onesMatrix = M >= 0.5;
                    onesMatrix(~mask) = false;
                    onesCount  = sum(onesMatrix, 2);
                    out        = double(onesCount >= threshold);
                case 'worst'
                    % max( ... , [], 2, 'omitnan') is MATLAB+Octave compatible.
                    allNan = all(isnan(M), 2);
                    tmp    = M;
                    tmp(isnan(tmp)) = -Inf;
                    out    = max(tmp, [], 2);
                    out(allNan) = NaN;
                case 'severity'
                    mask   = ~isnan(M);
                    Mzero  = M; Mzero(~mask) = 0;           % zero out NaN positions
                    wRow   = ones(nRows, 1) * weights;       % broadcast weights to rows
                    wMask  = wRow; wMask(~mask) = 0;
                    num    = sum(Mzero .* wMask, 2);
                    den    = sum(wMask, 2);
                    anyVal = any(mask, 2);
                    out    = double((num ./ den) >= threshold);
                    out(~anyVal | den == 0) = NaN;
                case 'user_fn'
                    % USER_FN runs scalar per row -- user fn may not vectorize.
                    out = nan(nRows, 1);
                    for r = 1:nRows
                        out(r) = userFn(M(r, :));
                    end
                otherwise
                    error('CompositeTag:invalidAggregateMode', ...
                        'Unknown aggregate mode ''%s''.', mode);
            end
            out = out(:);  % force column
        end

        function out = aggregate_(vals, weights, mode, userFn, threshold)
            %AGGREGATE_ Single-timestamp aggregation dispatch.
            %   Called row-by-row by mergeStream_ (Plan 02).  Returns a
            %   scalar double (0, 1, or NaN) per the Truth Tables in the
            %   class header.  USER_FN returns whatever the user's fn returns.
            switch mode
                case 'and'
                    if any(isnan(vals))
                        out = NaN;
                    else
                        out = double(all(vals >= 0.5));
                    end
                case 'or'
                    nonNan = vals(~isnan(vals));
                    if isempty(nonNan)
                        out = NaN;
                    else
                        out = double(any(nonNan >= 0.5));
                    end
                case 'majority'
                    nonNan = vals(~isnan(vals));
                    if isempty(nonNan)
                        out = NaN;
                    else
                        out = double(sum(nonNan >= 0.5) > numel(nonNan) / 2);
                    end
                case 'count'
                    nonNan = vals(~isnan(vals));
                    sOnes  = sum(nonNan >= 0.5);
                    out    = double(sOnes >= threshold);
                case 'worst'
                    nonNan = vals(~isnan(vals));
                    if isempty(nonNan)
                        out = NaN;
                    else
                        out = max(nonNan);
                    end
                case 'severity'
                    mask = ~isnan(vals);
                    if ~any(mask)
                        out = NaN;
                        return;
                    end
                    num = sum(weights(mask) .* vals(mask));
                    den = sum(weights(mask));
                    if den == 0
                        out = NaN;
                    else
                        out = double((num / den) >= threshold);
                    end
                case 'user_fn'
                    out = userFn(vals);
            end
        end

        function [tagArgs, cmpArgs] = splitArgs_(args)
            %SPLITARGS_ Partition varargin into Tag NV pairs vs CompositeTag NV pairs.
            %   Unknown and dangling keys both raise CompositeTag:unknownOption.
            tagKeys = {'Name', 'Units', 'Description', 'Labels', ...
                       'Metadata', 'Criticality', 'SourceRef'};
            cmpKeys = {'UserFn', 'Threshold'};
            tagArgs = {};
            cmpArgs = {};
            i = 1;
            while i <= numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('CompositeTag:unknownOption', ...
                        'Option ''%s'' has no matching value.', k);
                end
                v = args{i + 1};
                if any(strcmp(k, tagKeys))
                    tagArgs{end+1} = k; %#ok<AGROW>
                    tagArgs{end+1} = v; %#ok<AGROW>
                elseif any(strcmp(k, cmpKeys))
                    cmpArgs{end+1} = k; %#ok<AGROW>
                    cmpArgs{end+1} = v; %#ok<AGROW>
                else
                    error('CompositeTag:unknownOption', ...
                        'Unknown option ''%s''.', k);
                end
                i = i + 2;
            end
        end

        function v = fieldOr_(s, name, def)
            %FIELDOR_ Return s.(name) when present & non-empty; else default.
            if isfield(s, name) && ~isempty(s.(name))
                v = s.(name);
            else
                v = def;
            end
        end

    end

    methods (Static)

        function out = aggregateForTesting(vals, weights, mode, userFn, threshold)
            %AGGREGATEFORTESTING Public test-probe wrapper over private aggregate_.
            %   Exists SOLELY so suite/flat tests can exercise the truth
            %   tables without materializing a full CompositeTag + children
            %   graph.  Not part of the stable public API -- consumers
            %   should use getXY() / valueAt() instead (Plan 02).
            out = CompositeTag.aggregate_(vals, weights, mode, userFn, threshold);
        end

        function obj = fromStruct(s)
            %FROMSTRUCT Pass-1 reconstruction from a toStruct output.
            %   Constructs an empty-children CompositeTag and stashes
            %   `ChildKeys_` + `ChildWeights_` for Pass-2 `resolveRefs` to
            %   consume.  UserFn is NOT restored -- consumers re-bind it
            %   after loadFromStructs for 'user_fn' mode.
            %
            %   Errors: CompositeTag:dataMismatch if .key missing.
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('CompositeTag:dataMismatch', ...
                    'fromStruct requires struct with non-empty .key.');
            end
            % Unwrap the defensive double-wrap on Labels.
            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1})
                    L = L{1};
                end
                if iscell(L), labels = L; end
            end
            metadata = struct();
            if isfield(s, 'metadata') && isstruct(s.metadata)
                metadata = s.metadata;
            end
            % Unwrap childkeys double-wrap.
            childKeys = {};
            if isfield(s, 'childkeys') && ~isempty(s.childkeys)
                K = s.childkeys;
                if iscell(K) && numel(K) == 1 && iscell(K{1})
                    K = K{1};
                end
                if iscell(K), childKeys = K; end
            end
            childWeights = ones(1, numel(childKeys));
            if isfield(s, 'childweights') && ~isempty(s.childweights)
                w = s.childweights;
                if numel(w) == numel(childKeys)
                    childWeights = w(:).';
                end
            end
            aggMode = CompositeTag.fieldOr_(s, 'aggregatemode', 'and');
            thresh  = CompositeTag.fieldOr_(s, 'threshold',     0.5);
            nvArgs = { ...
                'Name',        CompositeTag.fieldOr_(s, 'name',        s.key), ...
                'Labels',      labels, ...
                'Metadata',    metadata, ...
                'Criticality', CompositeTag.fieldOr_(s, 'criticality', 'medium'), ...
                'Units',       CompositeTag.fieldOr_(s, 'units',       ''), ...
                'Description', CompositeTag.fieldOr_(s, 'description', ''), ...
                'SourceRef',   CompositeTag.fieldOr_(s, 'sourceref',   ''), ...
                'Threshold',   thresh};
            obj = CompositeTag(s.key, aggMode, nvArgs{:});
            obj.ChildKeys_    = childKeys;
            obj.ChildWeights_ = childWeights;
        end

    end

end
