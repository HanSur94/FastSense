# Phase 1008: CompositeTag - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — aggregation derived-signal class)

<domain>
## Phase Boundary

Aggregate one or more MonitorTags / CompositeTags into a single derived signal via **merge-sort streaming** (NOT N×M union materialization per Pitfall 3), supporting AND / OR / MAJORITY / COUNT / WORST / SEVERITY / USER_FN aggregation modes.

**In scope:**
- `CompositeTag < Tag` class
- `AggregateMode` enum: `'and' | 'or' | 'majority' | 'count' | 'worst' | 'severity' | 'user_fn'`
- `addChild(tagOrKey, varargin)` — accepts Tag handle OR string key (resolved via TagRegistry); optional `'Weight'` name-value for SEVERITY mode
- Cycle detection on `addChild` (self-reference AND deeper cycles A→B→A) via DFS with `CompositeTag:cycleDetected`
- Valid children: MonitorTag or CompositeTag ONLY. Reject SensorTag and StateTag (`CompositeTag:invalidChildType`) — they have no inherent ok/alarm semantics
- `getXY()` — merge-sort streaming over child sample streams; NOT union-of-all-timestamps + per-child interp1
- `valueAt(t)` — fast path for current-state widgets; aggregates `child.valueAt(t)` without materializing full series
- `getKind() == 'composite'`
- Lazy memoization + parent-driven invalidation inherited from MonitorTag pattern (composite listens to children, invalidates when any child's data changes)
- ZOH-only alignment per ALIGN-01; drop pre-history grid points per ALIGN-03
- NaN handling per ALIGN-04:
  - AND-with-NaN → NaN
  - OR-with-NaN → other operand
  - MAX/WORST-with-NaN → ignore
  - COUNT ignores NaN
  - Document truth table in class header

**Out of scope:**
- Consumer migration (Phase 1009)
- Event binding rewrite (Phase 1010)
- Legacy deletion (Phase 1011)

**Verification gates (from ROADMAP):**
- Pitfall 3 (memory blowup): Bench 8 children × 100k samples — peak RAM <50MB, compute <200ms. NO `union(X_1,...,X_N)` followed by `interp1` per child.
- Pitfall 6 (semantics drift): Truth tables for every `AggregateMode × {0, 1, NaN}` documented in class header. `'majority'` rejects multi-state inputs at `addChild` time, not `getXY` time.
- Pitfall 8: 3-deep composite-of-composite-of-composite round-trip test GREEN (TagRegistry.loadFromStructs two-phase resolver).
- ALIGN-04: Test every NaN combination.

</domain>

<decisions>
## Implementation Decisions

### File Organization
- NEW: `libs/SensorThreshold/CompositeTag.m` (~280 SLOC)
- EDIT: `libs/SensorThreshold/TagRegistry.m` — `'composite'` case in `instantiateByKind`
- EDIT: `libs/FastSense/FastSense.m` — `'composite'` case in `addTag` switch (plot as 0/1 binary line; heuristic for severity mode: 0..1 line)
- NEW: `tests/suite/TestCompositeTag.m` (aggregation modes + truth tables + cycle detection + child-type guards)
- NEW: `tests/suite/TestCompositeTagAlign.m` (merge-sort + pre-history drop + NaN truth tables)
- NEW: `tests/test_compositetag.m` (Octave flat-style)
- NEW: `tests/test_compositetag_align.m` (Octave)
- NEW: `benchmarks/bench_compositetag_merge.m` (Pitfall 3 gate — 8 children × 100k, <50MB peak, <200ms)

Total: 8 files.

### CompositeTag Class Skeleton
```matlab
classdef CompositeTag < Tag
    properties
        AggregateMode char = 'and'  % 'and'|'or'|'majority'|'count'|'worst'|'severity'|'user_fn'
        UserFn function_handle      % required when AggregateMode == 'user_fn'
        Threshold double = 0.5      % for 'count' and 'severity' output thresholding to 0/1
    end

    properties (Access = private)
        children_ cell = {}         % cell of {tag, weight} pairs
        cache_ struct
        dirty_ logical = true
    end

    methods
        function obj = CompositeTag(key, aggregateMode, varargin)
            obj@Tag(key);
            obj.AggregateMode = lower(aggregateMode);
            % name-value: 'UserFn', 'Threshold', Tag props
            ...
        end

        function addChild(obj, tagOrKey, varargin)
            % Resolve string key via registry
            if ischar(tagOrKey) || isstring(tagOrKey)
                tag = TagRegistry.get(char(tagOrKey));
            else
                tag = tagOrKey;
            end
            % Validate type
            if ~isa(tag, 'MonitorTag') && ~isa(tag, 'CompositeTag')
                error('CompositeTag:invalidChildType', ...
                      'Only MonitorTag or CompositeTag allowed as children (got %s)', class(tag));
            end
            % Cycle detection
            if obj.wouldCreateCycle_(tag)
                error('CompositeTag:cycleDetected', ...
                      'Adding child %s would create a cycle', tag.Key);
            end
            % Parse weight
            weight = 1.0;  % default
            for i = 1:2:numel(varargin)
                if strcmpi(varargin{i}, 'Weight')
                    weight = varargin{i+1};
                end
            end
            obj.children_{end+1} = struct('tag', tag, 'weight', weight);
            obj.invalidate();
            % Register as listener on child (via MonitorTag.addListener pattern from Phase 1006)
            if ismethod(tag, 'addListener')
                tag.addListener(obj);  % composite invalidates when child changes
            end
        end

        function [x, y] = getXY(obj)
            if obj.dirty_ || isempty(obj.cache_)
                obj.mergeStream_();
            end
            x = obj.cache_.x;
            y = obj.cache_.y;
        end

        function v = valueAt(obj, t)
            % Fast path — aggregate child.valueAt(t) without materializing
            n = numel(obj.children_);
            vals = zeros(n, 1);
            weights = zeros(n, 1);
            for i = 1:n
                c = obj.children_{i};
                vals(i) = c.tag.valueAt(t);
                weights(i) = c.weight;
            end
            v = aggregateValues_(vals, weights, obj.AggregateMode, obj.UserFn, obj.Threshold);
        end

        function invalidate(obj)
            obj.dirty_ = true;
            obj.cache_ = struct([]);
        end

        function kind = getKind(~), kind = 'composite'; end
    end
end
```

### Merge-Sort Streaming Algorithm (Pitfall 3 critical)
**DO NOT** materialize `union(child1.X, child2.X, ..., childN.X)` then call `child_i.valueAt(all_x)` for each i. That's O(N × M) memory for N children × M combined samples.

**DO** use k-way merge:
- Maintain N pointers (one per child), all starting at index 1 of each child's X array
- At each step:
  - Find minimum X among N current pointers
  - For each child, get current state (either the current Y or last-known Y via ZOH)
  - Compute aggregate value from N state values
  - Emit (minX, aggValue) to output; advance the pointer(s) that were at minX
  - Drop if minX < max(child.X(1)) (ALIGN-03 pre-history drop)
- Peak memory: O(N + len(output)) = O(N + sum of unique timestamps). No N×M materialization.

### Truth Tables (document in class header per Pitfall 6)
**AND:**
| c1 | c2 | out |
|----|----|----|
| 0  | 0  | 0  |
| 0  | 1  | 0  |
| 1  | 0  | 0  |
| 1  | 1  | 1  |
| 0  | NaN| NaN |
| 1  | NaN| NaN |
| NaN| NaN| NaN |

**OR:**
| c1 | c2 | out |
|----|----|----|
| 0  | 0  | 0  |
| 0  | 1  | 1  |
| 1  | 0  | 1  |
| 1  | 1  | 1  |
| 0  | NaN| 0  | (other operand)
| 1  | NaN| 1  | (other operand)
| NaN| NaN| NaN |

**MAJORITY:** threshold at `numChildren/2` — output 1 if more than half children are 1; NaN handled by excluding from count and adjusting divisor.

**COUNT:** sum of children (NaN excluded). Thresholded by `obj.Threshold` to produce 0/1.

**WORST:** max(values) ignoring NaN.

**SEVERITY:** weighted average `sum(weights .* values) / sum(weights)` where weights come from addChild. NaN excluded with divisor adjustment. Output thresholded by `obj.Threshold`.

**USER_FN:** `obj.UserFn(values)` — user's responsibility; pass raw array including NaN.

### Cycle Detection DFS
```matlab
function cycle = wouldCreateCycle_(obj, newChild)
    % Would adding newChild to obj create a cycle?
    cycle = (newChild == obj);
    if cycle, return; end
    % DFS from newChild looking for obj
    visited = {newChild};
    stack = {newChild};
    while ~isempty(stack)
        cur = stack{end};
        stack(end) = [];
        if isa(cur, 'CompositeTag')
            for i = 1:numel(cur.children_)
                grandchild = cur.children_{i}.tag;
                if grandchild == obj
                    cycle = true;
                    return;
                end
                if ~any(cellfun(@(v) v == grandchild, visited))
                    visited{end+1} = grandchild;
                    stack{end+1} = grandchild;
                end
            end
        end
    end
end
```

### Error IDs
- `CompositeTag:cycleDetected`, `CompositeTag:invalidChildType`, `CompositeTag:invalidAggregateMode`, `CompositeTag:userFnRequired`, `CompositeTag:unknownOption`

### Serialization
- `toStruct()` emits `{kind: 'composite', key, name, aggregateMode, threshold, childKeys: {k1, k2, ...}, childWeights: [w1, w2, ...]}`
- `fromStruct(s)` stores `childKeys_` private and `childWeights_` private for Pass 2 resolution
- `resolveRefs(registry)` — iterate stored keys, look up via `registry.get(k)`, call `obj.addChild(tag, 'Weight', w)` on each
- 3-deep composite-of-composite round-trip test green (Pitfall 8)

### TagRegistry Extension
```matlab
case 'composite'
    tag = CompositeTag.fromStruct(s);
    % Pass 2 resolves child tag handles via resolveRefs(registry)
```

### FastSense Extension
```matlab
case 'composite'
    [x, y] = tag.getXY();
    obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
```
Simple line render — aggregated 0/1 or 0..1 severity is a numeric time series.

### Pitfall 3 Bench
`benchmarks/bench_compositetag_merge.m`:
- Setup: 8 MonitorTags with 100k points each, different timestamps (randomized jitter so union would be ~800k)
- CompositeTag('and') aggregates all 8
- Measure: peak memory (via `memory()` on Windows; elsewhere use `/proc/self/status` on Linux or simply document) AND wall time
- Assert: peak <50MB AND compute <200ms
- Fallback: if memory measurement isn't portable, assert that `numel(composite.getXY output X)` ≤ `sum(child samples) × 1.1` (i.e., no N×M blowup) — proxy for memory

### Claude's Discretion
- Exact SLOC per helper
- Whether aggregation helpers live in private/ subdirectory
- Bench memory measurement methodology (Octave may need workarounds)
- Weight defaulting semantics for non-SEVERITY modes (ignore weights? use them? default 1.0 + document)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 1006 `MonitorTag.addListener` pattern — CompositeTag reuses as composite child of children
- Phase 1006 `MonitorTag.invalidate` cascade — CompositeTag invalidates when child data changes
- Phase 1004 `TagRegistry.loadFromStructs` two-phase loader — CompositeTag's childKeys resolved in Pass 2
- Legacy `libs/SensorThreshold/CompositeThreshold.m` — UNTOUCHED. Reference for cycle-detection pattern.
- Phase 1005 `FastSense.addTag` switch — extend with 'composite' case

### Established Patterns
- throw-from-base abstract contract via Tag base
- Observer pattern: parent.addListener(child) → parent.notifyListeners_() → child.invalidate()
- Name-value constructor parsing
- Static fromStruct + resolveRefs(registry) two-phase deserialization

### Integration Points
- CompositeTag IS a Tag — plottable, registerable, round-trippable
- Children are MonitorTag or CompositeTag ONLY
- Valid parent (of composite's listener) is another CompositeTag (composite of composites)

</code_context>

<specifics>
## Specific Ideas

- Cycle detection MUST run on addChild, not on getXY (Pitfall 6 semantics timing)
- Composite-of-composite-of-composite (3-deep) round-trip is the critical serialization test
- SEVERITY mode uses weighted average before thresholding — document exact formula `(Σ wi × vi) / (Σ wi)` where NaN terms drop both numerator + denominator
- USER_FN escape hatch — if user returns non-0/1/NaN, CompositeTag accepts it (caller's responsibility)

</specifics>

<deferred>
## Deferred Ideas

- Per-child threshold override (user confirmed no preference; defer)
- Alignment caching keyed on (children, window) (premature optimization)
- Multi-state MAJORITY (explicitly binary 0/1 for v2.0)

</deferred>
