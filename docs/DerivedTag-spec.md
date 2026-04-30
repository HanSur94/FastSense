# DerivedTag — Specification + Implementation Plan

**Audience:** Claude (or human) executing implementation in a separate session.
**Output:** new class `DerivedTag` in `libs/SensorThreshold/`, full test suite, serializer support.
**Sibling references:** `Tag`, `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`.
**Status:** specification complete; ready to implement.

---

## 1. Purpose

`DerivedTag` is the missing 5th class in the FastPlot Tag hierarchy. It produces a **continuous** `(X, Y)` time series **derived from N parent tags** via an arbitrary user-supplied compute function. It is the continuous-output counterpart to `MonitorTag` (single-parent → 0/1 binary) and `CompositeTag` (N children → 0/1 aggregate).

### The gap it fills

| Class | Parents/Children | Output | Use case |
|---|---|---|---|
| `SensorTag` | none | continuous `(X, Y)` | raw sensor data |
| `StateTag` | none | discrete state ZOH | machine state, mode |
| `MonitorTag` | 1 parent | 0/1 binary | threshold violation |
| `CompositeTag` | N MonitorTag/CompositeTag | 0/1 aggregate | status rollup |
| **`DerivedTag`** | **N parent Tags (any kind)** | **continuous `(X, Y)`** | **stats, computed signals** |

### Use-case examples (motivating)

- **Machine efficiency** = `f(temp_a, pressure_b, state)` — combines 2 sensors + 1 state tag into a single % signal
- **Pump differential pressure** = `pump_outlet - pump_inlet` — straightforward two-input subtraction
- **Rolling 1-hour temperature variance** = `var(reticle_temps, window=3600s)` — N-input window stat
- **Cross-correlation lag** = `xcorr(signal_a, signal_b, maxlag=60)` — two-input scalar series
- **State-gated mean** = `mean(temp where state == 'measuring')` — gates one signal by another

In every case the result is itself a continuous time series with thresholds, dashboards, and downstream MonitorTags — i.e. a first-class SensorTag-equivalent in every consumer's eyes.

---

## 2. Class hierarchy position

```
Tag (abstract)
├── SensorTag        — leaf, raw data
├── StateTag         — leaf, discrete ZOH
├── MonitorTag       — derived 0/1 from 1 parent
├── CompositeTag     — derived 0/1 from N MonitorTag/CompositeTag children
└── DerivedTag       — derived (X, Y) from N parent Tags          ← NEW
```

`DerivedTag` is conceptually *closest to MonitorTag* (parent-listening, lazy-cache, recompute-on-DataChanged), but generalized to:
- N parents instead of 1
- continuous (X, Y) output instead of 0/1

The implementation **MUST mirror `MonitorTag`'s patterns** for listener wiring, cache invalidation, two-phase serialization, and Octave compatibility. Re-use, do not re-invent.

---

## 3. Public API

### 3.1 Constructor

```matlab
obj = DerivedTag(key, parents, compute, varargin)
```

**Positional args:**
- `key` (char) — unique identifier; required. Empty / non-char raises `Tag:invalidKey`.
- `parents` (1×N cell of Tag handles) — required, must contain ≥1 element. Each element must be `isa(...,'Tag')`. Raises `DerivedTag:invalidParents` otherwise.
- `compute` — one of:
  - **function handle** with signature `[X, Y] = fn(parents)` where `parents` is the same cell array passed to the constructor.
  - **handle object** with method `[X, Y] = compute(obj, parents)`. Detected via `ismethod(compute, 'compute')`.
  - Required, non-empty. Raises `DerivedTag:invalidCompute` otherwise.

**Name-Value (Tag universals — delegated to base):**
`Name`, `Units`, `Description`, `Labels`, `Metadata`, `Criticality`, `SourceRef`.

**Name-Value (DerivedTag-specific):**
- `EventStore` (EventStore handle, default `[]`) — inherited from Tag base; if set, downstream consumers (e.g. dashboards) can attach event markers tied to this derived signal.
- `MinDuration` (numeric, default `0`) — reserved for future debouncing/hysteresis; unused in v1.

Unknown NV keys raise `DerivedTag:unknownOption`.

**Side effect:** the new tag registers itself as a listener on every parent (via `parents{k}.addListener(obj)` when `ismethod(parents{k}, 'addListener')`), so `parent.updateData(...)` triggers `obj.invalidate()`.

### 3.2 Properties

| Property | Access | Type | Default | Notes |
|---|---|---|---|---|
| `Parents` | public | 1×N cell of Tag | `{}` | required at construction; immutable in practice (do not mutate post-construction) |
| `ComputeFn` | public | function_handle OR handle obj | `[]` | required; the compute strategy |
| `MinDuration` | public | scalar double | `0` | reserved (v1: unused) |
| `EventStore` | public | EventStore handle | `[]` | inherited from Tag |
| `cache_` | private | struct | `struct()` | populated by `recompute_()` |
| `dirty_` | private | logical | `true` | true ⇒ cache stale, recompute on next `getXY()` |
| `ParentKeys_` | private | 1×N cellstr | `{}` | Pass-1 deserialization stash; consumed by `resolveRefs` |
| `listeners_` | private | cell of handles | `{}` | downstream tags notified on `invalidate()` |

### 3.3 Methods (Tag contract — required)

| Method | Signature | Behavior |
|---|---|---|
| `getXY` | `[X, Y] = getXY(obj)` | Lazy: if `dirty_`, call `recompute_()`; return cached `cache_.x`, `cache_.y`. |
| `valueAt` | `v = valueAt(obj, t)` | Compute (or use cached) `getXY()`, then ZOH-lookup at `t`. Vector `t` returns vector `v`. Use `binary_search_mex` like `StateTag.valueAt` — re-use that helper. |
| `getTimeRange` | `[tMin, tMax] = getTimeRange(obj)` | Returns `[X(1), X(end)]` from `getXY()`; `[NaN NaN]` if empty. |
| `getKind` | `k = getKind(obj)` | Returns `'derived'` (NEW kind string — see §6 for downstream impact). |
| `toStruct` | `s = toStruct(obj)` | Returns serializable struct. **Function handles cannot be saved** — `s.computekind = 'function_handle'` or `'object'`; if object, store class name + properties via the object's own `toStruct()` if implemented, else error `DerivedTag:nonSerializableCompute`. |
| `fromStruct` | `Static: obj = DerivedTag.fromStruct(s)` | Pass-1: dummy parents, stash `s.parentkeys` in `ParentKeys_`, raise on missing fields with `DerivedTag:dataMismatch`. Compute reattachment is the user's responsibility (see §3.6). |
| `resolveRefs` | `resolveRefs(obj, registry)` | Pass-2: iterate `ParentKeys_`, fetch each from `registry` (containers.Map of key → Tag), call `parent.addListener(obj)`, populate `obj.Parents`. Raises `DerivedTag:unresolvedParent` on missing key. Clears `ParentKeys_` when done. |

### 3.4 Methods (DerivedTag-specific)

| Method | Signature | Behavior |
|---|---|---|
| `invalidate` | `invalidate(obj)` | Set `dirty_ = true`, call `notifyListeners_()`. Public — also called by the parent-DataChanged listener wiring. |
| `addListener` | `addListener(obj, l)` | Append `l` to `listeners_`. `l` must `ismethod(l, 'invalidate')`, else `DerivedTag:invalidListener`. |
| `recompute_` | `recompute_(obj)` (private) | The actual compute call. See §3.5 for full algorithm. |
| `notifyListeners_` | `notifyListeners_(obj)` (private) | For each `l` in `listeners_`, call `l.invalidate()`. |

### 3.5 `recompute_` algorithm

```matlab
function recompute_(obj)
    if isa(obj.ComputeFn, 'function_handle')
        [X, Y] = obj.ComputeFn(obj.Parents);
    elseif isobject(obj.ComputeFn) && ismethod(obj.ComputeFn, 'compute')
        [X, Y] = obj.ComputeFn.compute(obj.Parents);
    else
        error('DerivedTag:invalidCompute', ...
            'ComputeFn must be a function_handle or object with compute() method.');
    end

    % Validate result shape
    if ~isnumeric(X) || ~isnumeric(Y)
        error('DerivedTag:computeReturnedNonNumeric', ...
            'ComputeFn must return numeric X, Y vectors.');
    end
    if numel(X) ~= numel(Y)
        error('DerivedTag:computeShapeMismatch', ...
            'ComputeFn returned X (n=%d) and Y (n=%d) of different lengths.', ...
            numel(X), numel(Y));
    end

    obj.cache_.x = X(:).';
    obj.cache_.y = Y(:).';
    obj.dirty_   = false;
end
```

### 3.6 Serialization caveats

A function-handle `ComputeFn` **cannot round-trip** through `toStruct`/`fromStruct`. Two options:

1. **Reject at `toStruct` time**: throw `DerivedTag:nonSerializableCompute` if `ComputeFn` is a function handle. Users must wrap in a class subclass.
2. **Allow with caveat**: `toStruct` stores `s.computekind='function_handle'`, `s.computestr=func2str(ComputeFn)`; `fromStruct` leaves `ComputeFn = []` and sets a sentinel `obj.ComputeFn = @() error('DerivedTag:computeNotRehydrated', ...)`. The user must reattach the real handle via a registration step *after* `loadFromStructs`.

**Decision: Option 2.** Round-tripping a function-handle string is impossible (closures, anonymous fns can't be reconstructed safely), but the design for derived tags assumes registration code re-runs at session start (the +monitoring `registerTags.m` pattern), so reattachment is natural. Document this clearly in the class header.

For object-form `ComputeFn`, require the object to implement `toStruct()` and `fromStruct()` and round-trip via class-name dispatch (similar to how `TagRegistry.instantiateByKind` dispatches Tag kinds). This means **DerivedSource subclasses MUST be serializable** to round-trip.

---

## 4. Error IDs (locked)

```
DerivedTag:invalidParents          parents arg empty or contains non-Tag
DerivedTag:invalidCompute          compute arg not a function_handle and not an object with compute()
DerivedTag:unknownOption           unrecognized NV key
DerivedTag:invalidListener         addListener target lacks invalidate()
DerivedTag:computeReturnedNonNumeric  recompute_ result X or Y non-numeric
DerivedTag:computeShapeMismatch    recompute_ result X, Y differ in length
DerivedTag:dataMismatch            fromStruct missing required fields (key, parentkeys, …)
DerivedTag:unresolvedParent        resolveRefs cannot find a parent key in registry
DerivedTag:nonSerializableCompute  toStruct on a function-handle compute (if Option 1 ever chosen)
DerivedTag:computeNotRehydrated    deserialized DerivedTag invoked without ComputeFn reattachment (Option 2 sentinel)
```

All error IDs use the `DerivedTag:camelCase` pattern matching `MonitorTag:` and `CompositeTag:`.

---

## 5. Pitfall checklist (Octave-safe + project convention)

Adapted from `MonitorTag.m` and `CompositeTag.m` precedent. **Do not skip.**

1. **Constructor super-call ordering (Pitfall 8).** The `obj@Tag(key, tagArgs{:})` call MUST be the first statement. Use a `splitArgs_` static helper to partition `varargin` into Tag NV-pairs vs. DerivedTag NV-pairs *before* the super call.
2. **No Abstract methods block.** Use the "throw-from-base" pattern that `Tag.m` uses; do not declare `methods (Abstract)`. Octave/MATLAB semantics diverge for abstract.
3. **Listener cycle safety (Pitfall 3, Octave SIGILL).** Parents hold strong refs to derived (via `listeners_`); derived holds strong refs to parents (via `Parents`). This is intentional but creates a cycle. **For any handle equality check, use `strcmp(a.Key, b.Key)` not `==` or `isequal`.** TagRegistry enforces unique keys, so Key equality is semantically equivalent to handle equality in a registry session.
4. **Cycle detection in dependency graph.** A `DerivedTag` whose parent is itself (or transitively itself) is illegal. **Check at construction time** via DFS over `Parents`: walk each parent's parents (if `isa(parent,'DerivedTag')`), error `DerivedTag:cycleDetected` if `obj.Key` appears in any descendant's `Parents` chain. Mirror `CompositeTag`'s `addChild` cycle DFS.
5. **No `notify(obj, 'DataChanged')` in invalidate path.** `MonitorTag.invalidate` is silent re: `DataChanged`; same here. Only `SensorTag.updateData` and `StateTag` mutators fire `DataChanged`. Derived tags don't fire DataChanged on cache invalidation — they fire only when a downstream consumer pulls `getXY()` and the result is observable. (This avoids flap loops.)
6. **`getXY` MUST handle the empty-parents case gracefully.** If any `parents{k}` has empty X/Y, the compute function may throw or produce empty. `recompute_` should not silently swallow — let the user's `compute` handle it (their problem domain), but `DerivedTag:computeReturnedNonNumeric` catches malformed returns.
7. **Octave-compat for `ismethod` checks.** `ismethod(obj, 'compute')` works in both MATLAB and Octave — verified pattern in `MonitorTag.m` line 195.
8. **Property attribute compatibility.** `properties (Abstract, SetAccess = immutable)` works in MATLAB but NOT consistently in Octave for class-level Abstract. Stick with the project's `Abstract = true` flag at class declaration + concrete subclass overrides. Already proven by `Tag.m`.

---

## 6. Cross-cutting integration touchpoints

These touchpoints exist outside `DerivedTag.m` itself. **Audit and update each.** The implementation session should grep the codebase for these patterns.

### 6.1 `TagRegistry.instantiateByKind`

`TagRegistry.m` has a Pass-1 dispatch on `s.kind` for `'sensor'`, `'state'`, `'monitor'`, `'composite'`. **Add `'derived'` case** dispatching to `DerivedTag.fromStruct(s)`.

### 6.2 `DashboardSerializer`

If `DashboardSerializer.m` currently switches on tag kind for save/load (as `linesForWidget` and `save()` do for `'sensor'` and `'tag'` per recent commits `15be397`, `ee04f4e`, `0c24fed`), **add a `'derived'` case** that treats DerivedTag like SensorTag for plot purposes (it has `getXY()` returning continuous data). Likely just an alias — the widget layer doesn't need to know it's derived.

### 6.3 `FastSenseWidget` / `FastSense`

Both consume `Tag` handles via `getXY()`. They should already work transparently with `DerivedTag` since the contract is the same. **Verify** by grep for `getKind() ==` or `isa(...,'SensorTag')` checks; replace narrow `isa` with `ismethod(t,'getXY')` if any are found.

### 6.4 `SensorThreshold` registry coverage

`getAllSensors.m` and `getAllSensorSpecs.m` (in monitoring side) iterate the registry. They should already be tag-kind-agnostic, but **verify**: a `DerivedTag` should appear in `getAllSensors` and *not* be filtered out by a `SensorTag`-only check.

### 6.5 `findByKind`

`TagRegistry.findByKind('derived')` should return DerivedTags. Add a test for this.

### 6.6 `MonitorTag` and `CompositeTag` accepting `DerivedTag` as parent/child

A `DerivedTag` should be a valid `MonitorTag` parent (so you can put thresholds on a derived signal). Currently `MonitorTag` accepts any `Tag` — verify no `isa(...,'SensorTag')` narrowing exists. Add a test: `MonitorTag('m', derivedTag, @(x,y) y > 1)` works.

A `DerivedTag` should NOT be a valid `CompositeTag` child (CompositeTag children are limited to MonitorTag/CompositeTag for status semantics). Confirm the existing type-guard rejects DerivedTag with `CompositeTag:invalidChildType`.

---

## 7. Implementation file layout

```
libs/SensorThreshold/
├── DerivedTag.m                      ← NEW (~350 lines)
└── (existing files — minor edits to TagRegistry.m for instantiateByKind)

libs/Dashboard/
└── DashboardSerializer.m             ← edit: add 'derived' to kind dispatch
└── (FastSenseWidget.m — verify only, likely no change)

tests/suite/
├── TestDerivedTag.m                  ← NEW (~400 lines, ~25 test methods)
└── TestTagRegistry.m                 ← edit: 1 test method for findByKind('derived')
```

No new entries required in `install.m` (libs/SensorThreshold is already on path).

---

## 8. `DerivedTag.m` — full skeleton

This is mostly ready to commit. The implementer fills in the body of `recompute_`, `valueAt`, `toStruct`, `fromStruct`, `resolveRefs` from the patterns in `MonitorTag.m`.

```matlab
classdef DerivedTag < Tag
    %DERIVEDTAG Continuous (X, Y) signal derived from N parent Tags via compute fn.
    %   DerivedTag is the 5th concrete Tag class — the continuous-output
    %   counterpart to MonitorTag (1 parent → 0/1) and CompositeTag (N
    %   children → 0/1). It produces a full (X, Y) time series by applying
    %   a user-supplied compute function (or compute object) to its parents'
    %   data. Lazy-memoized; auto-invalidates on any parent's DataChanged.
    %
    %   DerivedTag Properties (public):
    %     Parents     — 1×N cell of Tag handles (required)
    %     ComputeFn   — function_handle @(parents)->[X,Y], or handle object
    %                   with method [X,Y]=compute(obj, parents) (required)
    %     MinDuration — scalar double; reserved for v2 debouncing (default 0)
    %     EventStore  — EventStore handle inherited from Tag
    %
    %   Tag-contract methods:
    %     getXY        — lazy-memoized; recomputes on dirty
    %     valueAt(t)   — ZOH lookup into the cached (X, Y)
    %     getTimeRange — [X(1), X(end)] or [NaN NaN] if empty
    %     getKind      — returns 'derived'
    %     toStruct     — serialize (function-handle ComputeFn ⇒ sentinel; see §3.6)
    %     fromStruct   — Static Pass-1 ctor; stashes parentkeys for Pass-2
    %     resolveRefs  — Pass-2: bind Parents from registry, register listeners
    %
    %   DerivedTag-specific methods:
    %     invalidate / addListener / notifyListeners_  — observer pattern
    %
    %   Error IDs (locked):
    %     DerivedTag:invalidParents              parents empty or non-Tag
    %     DerivedTag:invalidCompute              compute not fn handle / no compute()
    %     DerivedTag:unknownOption               unrecognized NV key
    %     DerivedTag:invalidListener             addListener target lacks invalidate()
    %     DerivedTag:computeReturnedNonNumeric   compute result non-numeric
    %     DerivedTag:computeShapeMismatch        X, Y length mismatch
    %     DerivedTag:dataMismatch                fromStruct missing required fields
    %     DerivedTag:unresolvedParent            resolveRefs missing key in registry
    %     DerivedTag:cycleDetected               cyclic parent graph
    %     DerivedTag:nonSerializableCompute      toStruct on opaque fn handle
    %     DerivedTag:computeNotRehydrated        deserialized invoked without rehydration
    %
    %   Listener cycle note (Pitfall 3 / Octave SIGILL):
    %     Parents hold strong refs to DerivedTag via listeners_; DerivedTag
    %     holds strong refs to Parents. Use strcmp(a.Key, b.Key) for any
    %     handle equality — TagRegistry guarantees globally-unique keys.
    %
    %   Example (function-handle compute):
    %     a = SensorTag('a', 'X', 1:10, 'Y', 1:10);
    %     b = SensorTag('b', 'X', 1:10, 'Y', 2:11);
    %     d = DerivedTag('a_plus_b', {a, b}, ...
    %                    @(p) deal(p{1}.X, p{1}.Y + p{2}.Y));
    %     [x, y] = d.getXY();   % y = [3 5 7 9 11 13 15 17 19 21]
    %     a.updateData(1:10, 100*(1:10));
    %     [x, y] = d.getXY();   % automatically recomputed
    %
    %   See also Tag, SensorTag, MonitorTag, CompositeTag, TagRegistry.

    properties
        Parents     = {}    % 1×N cell of Tag handles
        ComputeFn   = []    % function_handle or handle object with compute()
        MinDuration = 0     % reserved for v2
    end

    properties (Access = private)
        cache_      = struct()
        dirty_      = true
        ParentKeys_ = {}
        listeners_  = {}
    end

    methods
        function obj = DerivedTag(key, parents, compute, varargin)
            % Parse NV pairs BEFORE obj access.
            [tagArgs, ownArgs] = DerivedTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});                       % MUST be first

            % Validate parents
            if ~iscell(parents) || isempty(parents)
                error('DerivedTag:invalidParents', ...
                    'parents must be a non-empty cell of Tag handles.');
            end
            for k = 1:numel(parents)
                if ~isa(parents{k}, 'Tag')
                    error('DerivedTag:invalidParents', ...
                        'parents{%d} must be a Tag; got %s.', k, class(parents{k}));
                end
            end

            % Validate compute
            if isempty(compute)
                error('DerivedTag:invalidCompute', ...
                    'compute argument is required.');
            end
            isFn  = isa(compute, 'function_handle');
            isObj = isobject(compute) && ismethod(compute, 'compute');
            if ~isFn && ~isObj
                error('DerivedTag:invalidCompute', ...
                    'compute must be a function_handle or object with compute() method.');
            end

            % Cycle detection — DFS over parents' parents chains
            DerivedTag.checkCycles_(key, parents);

            % Apply own NV pairs
            for i = 1:2:numel(ownArgs)
                k = ownArgs{i}; v = ownArgs{i+1};
                switch k
                    case 'MinDuration'
                        obj.MinDuration = v;
                    otherwise
                        error('DerivedTag:unknownOption', ...
                            'Unknown NV key ''%s''.', k);
                end
            end

            obj.Parents   = parents;
            obj.ComputeFn = compute;

            % Register self as listener on each parent (auto-invalidation)
            for k = 1:numel(parents)
                if ismethod(parents{k}, 'addListener')
                    parents{k}.addListener(obj);
                end
            end
        end

        function [X, Y] = getXY(obj)
            if obj.dirty_
                obj.recompute_();
            end
            X = obj.cache_.x;
            Y = obj.cache_.y;
        end

        function v = valueAt(obj, t)
            [X, Y] = obj.getXY();
            if isempty(X)
                v = nan(size(t));
                return;
            end
            % ZOH right-biased binary search; mirror StateTag.valueAt
            v = nan(size(t));
            for i = 1:numel(t)
                idx = find(X <= t(i), 1, 'last');
                if ~isempty(idx)
                    v(i) = Y(idx);
                end
            end
            % TODO: replace with binary_search_mex for performance — see StateTag
        end

        function [tMin, tMax] = getTimeRange(obj)
            [X, ~] = obj.getXY();
            if isempty(X)
                tMin = NaN; tMax = NaN;
            else
                tMin = X(1); tMax = X(end);
            end
        end

        function k = getKind(~)
            k = 'derived';
        end

        function s = toStruct(obj)
            s = struct();
            s.kind        = 'derived';
            s.key         = obj.Key;
            s.name        = obj.Name;
            s.units       = obj.Units;
            s.description = obj.Description;
            s.labels      = obj.Labels;
            s.metadata    = obj.Metadata;
            s.criticality = obj.Criticality;
            s.sourceref   = obj.SourceRef;
            s.minduration = obj.MinDuration;

            % Parent keys (resolveRefs reattaches handles)
            s.parentkeys  = cellfun(@(p) p.Key, obj.Parents, 'UniformOutput', false);

            % Compute strategy
            if isa(obj.ComputeFn, 'function_handle')
                s.computekind = 'function_handle';
                s.computestr  = func2str(obj.ComputeFn);
                % Note: cannot reconstruct closure on load; user must rehydrate.
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

        function invalidate(obj)
            obj.dirty_ = true;
            obj.notifyListeners_();
        end

        function addListener(obj, l)
            if ~ismethod(l, 'invalidate')
                error('DerivedTag:invalidListener', ...
                    'listener must implement invalidate().');
            end
            obj.listeners_{end+1} = l;
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            % Pass-1 reconstruction with sentinel parents and stashed keys.
            if ~isstruct(s) || ~isfield(s, 'key')
                error('DerivedTag:dataMismatch', ...
                    'struct missing required field ''key''.');
            end
            if ~isfield(s, 'parentkeys')
                error('DerivedTag:dataMismatch', ...
                    'struct missing required field ''parentkeys''.');
            end

            % Build placeholder parents (one dummy SensorTag per key, replaced in resolveRefs)
            dummyParents = cell(1, numel(s.parentkeys));
            for k = 1:numel(s.parentkeys)
                dummyParents{k} = SensorTag(['__pass1_dummy_' s.parentkeys{k} '__']);
            end

            % Sentinel compute that errors if invoked before rehydration
            sentinelCompute = @(~) DerivedTag.computeNotRehydratedError_(s.key);

            % Tag-universal NV pairs from struct
            tagNV = {};
            if isfield(s, 'name'),        tagNV(end+1:end+2) = {'Name', s.name};               end
            if isfield(s, 'units'),       tagNV(end+1:end+2) = {'Units', s.units};             end
            if isfield(s, 'description'), tagNV(end+1:end+2) = {'Description', s.description}; end
            if isfield(s, 'labels'),      tagNV(end+1:end+2) = {'Labels', s.labels};           end
            if isfield(s, 'metadata'),    tagNV(end+1:end+2) = {'Metadata', s.metadata};       end
            if isfield(s, 'criticality'), tagNV(end+1:end+2) = {'Criticality', s.criticality}; end
            if isfield(s, 'sourceref'),   tagNV(end+1:end+2) = {'SourceRef', s.sourceref};     end

            obj = DerivedTag(s.key, dummyParents, sentinelCompute, tagNV{:});
            obj.ParentKeys_ = s.parentkeys;          % Pass-2 will consume
            obj.Parents     = {};                    % cleared until resolveRefs

            % Compute object rehydration (function_handle case = leave sentinel)
            if isfield(s, 'computekind') && strcmp(s.computekind, 'object')
                if isfield(s, 'computeclass')
                    cls = s.computeclass;
                    if exist(cls, 'class') == 8
                        if ismethod(cls, 'fromStruct')
                            obj.ComputeFn = feval([cls '.fromStruct'], s.computestate);
                        else
                            obj.ComputeFn = feval(cls);   % default-construct
                        end
                    end
                end
            end
            % function_handle case: ComputeFn stays as sentinel; user rehydrates.
        end
    end

    methods (Access = private)
        function recompute_(obj)
            if isa(obj.ComputeFn, 'function_handle')
                [X, Y] = obj.ComputeFn(obj.Parents);
            elseif isobject(obj.ComputeFn) && ismethod(obj.ComputeFn, 'compute')
                [X, Y] = obj.ComputeFn.compute(obj.Parents);
            else
                error('DerivedTag:invalidCompute', ...
                    'ComputeFn must be function_handle or object with compute().');
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

            obj.cache_.x = X(:).';
            obj.cache_.y = Y(:).';
            obj.dirty_   = false;
        end

        function notifyListeners_(obj)
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
        end

        function resolveRefs(obj, registry)
            % Pass-2: replace dummy parents with real handles, register as listener.
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
            obj.dirty_      = true; % force recompute on next getXY
        end
    end

    methods (Static, Access = private)
        function [tagArgs, ownArgs] = splitArgs_(args)
            tagKeys = {'Name','Units','Description','Labels', ...
                       'Metadata','Criticality','SourceRef','EventStore'};
            ownKeys = {'MinDuration'};
            tagArgs = {}; ownArgs = {};
            for i = 1:2:numel(args)
                k = args{i};
                if i + 1 > numel(args)
                    error('DerivedTag:unknownOption', ...
                        'Option ''%s'' has no value.', k);
                end
                v = args{i+1};
                if any(strcmp(k, tagKeys))
                    tagArgs(end+1:end+2) = {k, v};
                elseif any(strcmp(k, ownKeys))
                    ownArgs(end+1:end+2) = {k, v};
                else
                    error('DerivedTag:unknownOption', ...
                        'Unknown NV key ''%s''.', k);
                end
            end
        end

        function checkCycles_(newKey, parents)
            % DFS through any DerivedTag descendants; raise if newKey appears.
            for k = 1:numel(parents)
                p = parents{k};
                if isa(p, 'DerivedTag')
                    DerivedTag.dfs_(newKey, p);
                end
            end
        end

        function dfs_(targetKey, node)
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
            error('DerivedTag:computeNotRehydrated', ...
                'DerivedTag ''%s'' was deserialized without ComputeFn rehydration.', key);
        end
    end
end
```

**Implementer note:** the file above is ~250 lines of meaningful code; pad to ~350 with full doc comments per project convention. The `valueAt` ZOH lookup is naive (`find(...,'last')`) — replace with `binary_search_mex` if `StateTag.valueAt` already does so (mirror its pattern).

---

## 9. Test plan — `tests/suite/TestDerivedTag.m`

Mirror `TestMonitorTag.m` and `TestCompositeTag.m` shapes. **Class-based suite (PascalCase methods).** Run on both MATLAB and Octave (CI gate).

### Required test methods (~25)

#### Construction
- `testConstructorBasic` — 2 parents + function-handle compute, check `getKind()=='derived'`, `Parents` populated.
- `testConstructorObjectCompute` — compute is a stub class with `compute()` method; verify it gets called.
- `testConstructorRejectsEmptyParents` — `DerivedTag('k', {}, fn)` raises `DerivedTag:invalidParents`.
- `testConstructorRejectsNonTagParent` — `DerivedTag('k', {'string'}, fn)` raises `DerivedTag:invalidParents`.
- `testConstructorRejectsEmptyCompute` — `DerivedTag('k', {a}, [])` raises `DerivedTag:invalidCompute`.
- `testConstructorRejectsBadCompute` — `DerivedTag('k', {a}, 42)` raises `DerivedTag:invalidCompute`.
- `testConstructorTagUniversals` — `Name`, `Units`, `Labels` properly delegate to Tag base.
- `testConstructorUnknownOption` — `DerivedTag('k', {a}, fn, 'Bogus', 1)` raises `DerivedTag:unknownOption`.
- `testConstructorRejectsDirectCycle` — `DerivedTag('a', {a}, fn)` where `a` is `DerivedTag('a', ...)` raises `DerivedTag:cycleDetected`.
- `testConstructorRejectsTransitiveCycle` — a→b→c→a raises `DerivedTag:cycleDetected`.

#### Computation
- `testGetXYBasicSum` — `f(p) = deal(p{1}.X, p{1}.Y + p{2}.Y)`; verify result.
- `testGetXYLazyEvaluation` — `getXY` not called → compute fn not invoked. Use a counter in the compute fn closure.
- `testGetXYCachesResult` — second `getXY()` doesn't re-call compute fn.
- `testGetXYRecomputesAfterParentUpdate` — `parent.updateData(...)` triggers `dirty_=true`; next `getXY()` calls compute again.
- `testValueAtZOHLookup` — verify scalar and vector `t` arguments.
- `testGetTimeRange` — `[X(1), X(end)]` and `[NaN NaN]` for empty.

#### Compute validation
- `testRecomputeRejectsNonNumeric` — compute returns char ⇒ `DerivedTag:computeReturnedNonNumeric`.
- `testRecomputeRejectsShapeMismatch` — compute returns `X(n=10), Y(n=11)` ⇒ `DerivedTag:computeShapeMismatch`.

#### Listener / observer
- `testInvalidateClearsCache` — call `invalidate()` directly; next `getXY` recomputes.
- `testParentDataChangeInvalidates` — verify `parent.updateData(...)` cascades through listener.
- `testAddListenerDownstream` — chain a MonitorTag onto a DerivedTag; verify cascade.
- `testAddListenerRejectsNoInvalidate` — `addListener(struct())` raises `DerivedTag:invalidListener`.

#### Serialization
- `testToStructFunctionHandle` — `s.computekind=='function_handle'`, `s.computestr=func2str(...)`.
- `testToStructObject` — compute is `MyComputeStub` w/ `toStruct`; `s.computeclass`/`s.computestate` populated.
- `testFromStructPass1` — round-trip via `fromStruct`; `ParentKeys_` stashed; `getXY` errors with `computeNotRehydrated` (function-handle case).
- `testFromStructResolveRefs` — Pass-2 via `resolveRefs(registry)` populates `Parents`; sentinel ParentKeys_ cleared.
- `testFromStructRejectsMissingKey` — `DerivedTag.fromStruct(struct())` raises `DerivedTag:dataMismatch`.

#### Integration
- `testFindByKindReturnsDerived` — `TagRegistry.findByKind('derived')` includes the registered DerivedTag.
- `testMonitorTagAcceptsDerivedAsParent` — `MonitorTag('m', derivedTag, @(x,y) y > 0)` constructs, computes, fires events.
- `testCompositeTagRejectsDerivedAsChild` — `composite.addChild(derivedTag)` raises `CompositeTag:invalidChildType`.
- `testFastSenseRendersDerived` (optional, if FastSense path is testable headless) — plot and check `addLine` was called.

#### Object compute (full strategy demo)
A small private helper class in the test file:
```matlab
classdef ComputeAddStub < handle
    properties; Scale = 1; end
    methods
        function obj = ComputeAddStub(s), if nargin>=1, obj.Scale = s; end, end
        function [X, Y] = compute(obj, parents)
            X = parents{1}.X;
            Y = (parents{1}.Y + parents{2}.Y) * obj.Scale;
        end
        function s = toStruct(obj),  s.Scale = obj.Scale; end
        function obj2 = fromStruct(s)
            obj2 = ComputeAddStub();
            if isfield(s, 'Scale'), obj2.Scale = s.Scale; end
        end
    end
end
```

---

## 10. Acceptance criteria

1. `DerivedTag.m` exists in `libs/SensorThreshold/` and matches §8 skeleton.
2. All 25+ tests in `TestDerivedTag.m` pass on MATLAB AND Octave (CI green).
3. `TagRegistry.instantiateByKind('derived', s)` dispatches to `DerivedTag.fromStruct(s)`.
4. `findByKind('derived')` returns DerivedTags.
5. `MonitorTag` accepts `DerivedTag` as parent; smoke test passes.
6. `CompositeTag` rejects `DerivedTag` as child; smoke test confirms `CompositeTag:invalidChildType`.
7. `DashboardSerializer` save/load round-trips a dashboard containing a DerivedTag-bound widget (function-handle compute caveat documented in widget panel).
8. No new MISS_HIT lint failures; line-length ≤160; all error IDs documented in class header.
9. Class header docstring includes `Creator: hasuhr` (per project convention from `AGENTS.md`).
10. No use of `try/catch` outside GUIs (per project convention) except for the sentinel-error path.

---

## 11. Out of scope (defer to v2)

- **Persistence** (analogous to `MonitorTag.Persist` + `DataStore`). DerivedTag v1 is in-memory only; a v2 plan can opt-in to per-DerivedTag `.mat` caching with quad-signature staleness checks.
- **`appendData(newX, newY)` streaming-tail.** Full recompute only in v1.
- **`MinDuration` debouncing.** Property exists, ignored in v1.
- **`OnDataAvailable` callback.** Defer; the listener mechanism is sufficient for now.
- **Multiple compute outputs** (e.g., a derived tag emitting both `mean` and `std` series). v1 = single (X, Y). For two outputs, register two DerivedTags sharing parents.
- **Per-sample `t`-aligned compute.** v1 compute receives full parent X/Y vectors and decides its own grid. A v2 helper `alignParentsZOH(parents)` could project all parents onto a common grid before invoking compute.

---

## 12. References (read these before implementing)

- `libs/SensorThreshold/Tag.m` — base class, throw-from-base abstract pattern, listener mechanism conventions.
- `libs/SensorThreshold/MonitorTag.m` — closest sibling. **Especially:**
  - lines 158–230 (constructor — splitArgs_ + super-call ordering)
  - lines 290–310 (resolveRefs)
  - lines 440–460 (notifyListeners_, addListener, invalidate)
  - lines 920–950 (fromStruct)
- `libs/SensorThreshold/CompositeTag.m` — multi-parent + cycle detection patterns.
  - addChild cycle DFS for `DerivedTag.checkCycles_`
- `libs/SensorThreshold/StateTag.m` — `valueAt` ZOH binary search pattern.
- `libs/SensorThreshold/TagRegistry.m` — `instantiateByKind`, two-pass `loadFromStructs`.
- `tests/suite/TestMonitorTag.m` — test class layout to mirror.
- `AGENTS.md` and project `CLAUDE.md` — coding-style + naming rules (PascalCase classes, header docstrings, error-ID format).

---

## 13. Estimated effort

| Phase | Time |
|---|---|
| Read references (§12) | 30 min |
| Implement `DerivedTag.m` from §8 skeleton | 60 min |
| `TestDerivedTag.m` (25 methods) | 90 min |
| `TagRegistry.instantiateByKind` edit + 1 test | 15 min |
| `DashboardSerializer` `'derived'` case + smoke test | 30 min |
| Verify cross-cutting `isa(...,'SensorTag')` narrow checks (§6.3, §6.4) | 30 min |
| MISS_HIT lint pass | 15 min |
| Octave green-check via local `mkoctfile` runner | 15 min |
| **Total** | **~5 hours** |

A focused 1-session implementation should land all of §10 acceptance criteria.
