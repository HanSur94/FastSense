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
    %     getKind()                       -- returns 'composite'
    %
    %   Methods (Plan 02 -- stubbed with CompositeTag:notImplemented):
    %     getXY()         -- merge-sort streaming over child sample streams
    %     valueAt(t)      -- fast path aggregating child.valueAt(t)
    %     getTimeRange()  -- min/max across children
    %     toStruct()      -- serialization (fromStruct + resolveRefs in Plan 02)
    %
    %   Error IDs (locked):
    %     CompositeTag:cycleDetected        -- addChild would create cycle
    %                                          (self or deeper via Key-equality DFS)
    %     CompositeTag:invalidChildType     -- child is not MonitorTag/CompositeTag
    %     CompositeTag:invalidAggregateMode -- AggregateMode not in 7-mode list
    %     CompositeTag:userFnRequired       -- mode=='user_fn' but UserFn empty
    %     CompositeTag:unknownOption        -- constructor NV-pair unknown
    %     CompositeTag:invalidListener      -- addListener target lacks invalidate()
    %     CompositeTag:notImplemented       -- method deferred to Plan 02
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

        % ---- Plan-02 stubs (throw-from-base with CompositeTag:notImplemented) ----

        function [x, y] = getXY(obj) %#ok<STOUT,MANU>
            %GETXY Plan 02 -- merge-sort streaming over child sample streams.
            error('CompositeTag:notImplemented', ...
                'CompositeTag.getXY merge-sort is Plan 02 of Phase 1008.');
        end

        function v = valueAt(obj, t) %#ok<STOUT,INUSD>
            %VALUEAT Plan 02 -- fast-path aggregation of child.valueAt(t).
            error('CompositeTag:notImplemented', ...
                'CompositeTag.valueAt fast-path is Plan 02 of Phase 1008.');
        end

        function [tMin, tMax] = getTimeRange(obj) %#ok<STOUT,MANU>
            %GETTIMERANGE Plan 02 -- requires getXY to be implemented.
            error('CompositeTag:notImplemented', ...
                'CompositeTag.getTimeRange requires getXY (Plan 02).');
        end

        function s = toStruct(obj) %#ok<STOUT,MANU>
            %TOSTRUCT Plan 02 -- serialization with childKeys/childWeights.
            error('CompositeTag:notImplemented', ...
                'CompositeTag.toStruct is Plan 02 of Phase 1008.');
        end

    end

    methods (Access = private)

        function notifyListeners_(obj)
            %NOTIFYLISTENERS_ Iterate listeners_ and call invalidate() on each.
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
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

    end

end
