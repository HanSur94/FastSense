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
DerivedTag:cycleDetected           cyclic parent graph
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

If `DashboardSerializer.m` currently switches on tag kind for save/load (as `linesForWidget` and `save()` do for `'sensor'` and `'tag'` per recent commits), **add a `'derived'` case** that treats DerivedTag like SensorTag for plot purposes (it has `getXY()` returning continuous data). Likely just an alias — the widget layer doesn't need to know it's derived.

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

(see full skeleton in PR / previous spec versions; condensed below for brevity in this stash — implementer should consult the source spec they were handed)

```matlab
classdef DerivedTag < Tag
    properties
        Parents     = {}
        ComputeFn   = []
        MinDuration = 0
    end
    properties (Access = private)
        cache_      = struct()
        dirty_      = true
        ParentKeys_ = {}
        listeners_  = {}
    end
    methods
        function obj = DerivedTag(key, parents, compute, varargin)
            [tagArgs, ownArgs] = DerivedTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});
            % validate parents (non-empty cell of Tag)
            % validate compute (function_handle or object with compute())
            % cycle detection via DFS through DerivedTag descendants
            % apply ownArgs (MinDuration only)
            % store Parents, ComputeFn
            % register self as listener on each parent (addListener(obj))
        end
        function [X, Y] = getXY(obj)
            if obj.dirty_, obj.recompute_(); end
            X = obj.cache_.x; Y = obj.cache_.y;
        end
        function v = valueAt(obj, t)
            % ZOH right-biased lookup; mirror StateTag.valueAt
        end
        function [tMin, tMax] = getTimeRange(obj)
            [X, ~] = obj.getXY();
            if isempty(X), tMin = NaN; tMax = NaN;
            else, tMin = X(1); tMax = X(end); end
        end
        function k = getKind(~), k = 'derived'; end
        function s = toStruct(obj)
            % serialize tag universals + parentkeys + compute strategy
            % function_handle: store func2str (note: cannot reconstruct closure)
            % object: store computeclass + computestate (via obj.ComputeFn.toStruct())
        end
        function invalidate(obj)
            obj.dirty_ = true; obj.notifyListeners_();
        end
        function addListener(obj, l)
            if ~ismethod(l, 'invalidate')
                error('DerivedTag:invalidListener', 'listener must implement invalidate().');
            end
            obj.listeners_{end+1} = l;
        end
    end
    methods (Static)
        function obj = fromStruct(s)
            % Pass-1: build dummy parents, stash parentkeys, install sentinel ComputeFn for fn-handle case
            % object case: rehydrate via [class].fromStruct(s.computestate) if available
        end
    end
    methods (Access = private)
        function recompute_(obj)
            % invoke ComputeFn (handle or object.compute), validate shape, cache
        end
        function notifyListeners_(obj)
            for i = 1:numel(obj.listeners_), obj.listeners_{i}.invalidate(); end
        end
        function resolveRefs(obj, registry)
            % Pass-2: replace dummy parents with registry handles, register listeners
        end
    end
    methods (Static, Access = private)
        function [tagArgs, ownArgs] = splitArgs_(args)
            % partition by tagKeys = {Name,Units,Description,Labels,Metadata,Criticality,SourceRef,EventStore}
            % ownKeys = {MinDuration}
        end
        function checkCycles_(newKey, parents)
            % DFS over DerivedTag descendants; raise DerivedTag:cycleDetected
        end
    end
end
```

Pad to ~350 lines with full doc comments per project convention.

---

## 9. Test plan — `tests/suite/TestDerivedTag.m`

Mirror `TestMonitorTag.m` and `TestCompositeTag.m` shapes. Class-based suite (PascalCase methods). MATLAB + Octave.

### Required test methods (~25)

**Construction:** testConstructorBasic, testConstructorObjectCompute, testConstructorRejectsEmptyParents, testConstructorRejectsNonTagParent, testConstructorRejectsEmptyCompute, testConstructorRejectsBadCompute, testConstructorTagUniversals, testConstructorUnknownOption, testConstructorRejectsDirectCycle, testConstructorRejectsTransitiveCycle.

**Computation:** testGetXYBasicSum, testGetXYLazyEvaluation, testGetXYCachesResult, testGetXYRecomputesAfterParentUpdate, testValueAtZOHLookup, testGetTimeRange.

**Compute validation:** testRecomputeRejectsNonNumeric, testRecomputeRejectsShapeMismatch.

**Listener / observer:** testInvalidateClearsCache, testParentDataChangeInvalidates, testAddListenerDownstream, testAddListenerRejectsNoInvalidate.

**Serialization:** testToStructFunctionHandle, testToStructObject, testFromStructPass1, testFromStructResolveRefs, testFromStructRejectsMissingKey.

**Integration:** testFindByKindReturnsDerived, testMonitorTagAcceptsDerivedAsParent, testCompositeTagRejectsDerivedAsChild.

A small private helper class `ComputeAddStub` (handle, with `Scale`, `compute`, `toStruct`, static `fromStruct`) lives at the end of the test file for object-compute coverage.

---

## 10. Acceptance criteria

1. `DerivedTag.m` exists in `libs/SensorThreshold/` and matches §8 skeleton.
2. All 25+ tests in `TestDerivedTag.m` pass on MATLAB AND Octave.
3. `TagRegistry.instantiateByKind('derived', s)` dispatches to `DerivedTag.fromStruct(s)`.
4. `findByKind('derived')` returns DerivedTags.
5. `MonitorTag` accepts `DerivedTag` as parent; smoke test passes.
6. `CompositeTag` rejects `DerivedTag` as child; smoke test confirms `CompositeTag:invalidChildType`.
7. `DashboardSerializer` save/load round-trips a dashboard containing a DerivedTag-bound widget (function-handle compute caveat documented).
8. No new MISS_HIT lint failures; line-length ≤160; all error IDs documented in class header.
9. Class header docstring conforms to project convention.
10. No use of `try/catch` outside GUIs (per project convention) except for the sentinel-error path.

---

## 11. Out of scope (defer to v2)

- Persistence (DataStore caching). v1 is in-memory only.
- `appendData(newX, newY)` streaming-tail.
- `MinDuration` debouncing.
- `OnDataAvailable` callback.
- Multiple compute outputs.
- Per-sample t-aligned compute.

---

## 12. References (read these before implementing)

- `libs/SensorThreshold/Tag.m`
- `libs/SensorThreshold/MonitorTag.m`
- `libs/SensorThreshold/CompositeTag.m`
- `libs/SensorThreshold/StateTag.m`
- `libs/SensorThreshold/TagRegistry.m`
- `tests/suite/TestMonitorTag.m`
- `AGENTS.md`, `CLAUDE.md` — project coding-style + naming.
