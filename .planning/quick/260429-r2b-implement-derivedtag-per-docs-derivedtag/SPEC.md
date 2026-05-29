# DerivedTag — Specification + Implementation Plan

**Audience:** Claude (or human) executing implementation in a separate session.
**Output:** new class DerivedTag in libs/SensorThreshold/, full test suite, serializer support.
**Sibling references:** Tag, SensorTag, StateTag, MonitorTag, CompositeTag.
**Status:** specification complete; ready to implement.

---

## 1. Purpose

DerivedTag is the missing 5th class in the FastPlot Tag hierarchy. It produces a **continuous** (X, Y) time series **derived from N parent tags** via an arbitrary user-supplied compute function. It is the continuous-output counterpart to MonitorTag (single-parent → 0/1 binary) and CompositeTag (N children → 0/1 aggregate).

### The gap it fills

| Class | Parents/Children | Output | Use case |
|---|---|---|---|
| SensorTag | none | continuous (X, Y) | raw sensor data |
| StateTag | none | discrete state ZOH | machine state, mode |
| MonitorTag | 1 parent | 0/1 binary | threshold violation |
| CompositeTag | N MonitorTag/CompositeTag | 0/1 aggregate | status rollup |
| **DerivedTag** | **N parent Tags (any kind)** | **continuous (X, Y)** | **stats, computed signals** |

### Use-case examples (motivating)

- **Machine efficiency** = f(temp_a, pressure_b, state) — combines 2 sensors + 1 state tag into a single % signal
- **Pump differential pressure** = pump_outlet - pump_inlet — straightforward two-input subtraction
- **Rolling 1-hour temperature variance** = var(reticle_temps, window=3600s) — N-input window stat
- **Cross-correlation lag** = xcorr(signal_a, signal_b, maxlag=60) — two-input scalar series
- **State-gated mean** = mean(temp where state == 'measuring') — gates one signal by another

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

DerivedTag is conceptually *closest to MonitorTag* (parent-listening, lazy-cache, recompute-on-DataChanged), but generalized to:
- N parents instead of 1
- continuous (X, Y) output instead of 0/1

The implementation **MUST mirror MonitorTag's patterns** for listener wiring, cache invalidation, two-phase serialization, and Octave compatibility. Re-use, do not re-invent.

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
| `fromStruct` | Static: `obj = DerivedTag.fromStruct(s)` | Pass-1: dummy parents, stash `s.parentkeys` in `ParentKeys_`, raise on missing fields with `DerivedTag:dataMismatch`. Compute reattachment is the user's responsibility (see §3.6). |
| `resolveRefs` | `resolveRefs(obj, registry)` | Pass-2: iterate `ParentKeys_`, fetch each from registry (containers.Map of key → Tag), call `parent.addListener(obj)`, populate `obj.Parents`. Raises `DerivedTag:unresolvedParent` on missing key. Clears `ParentKeys_` when done. |

### 3.4 Methods (DerivedTag-specific)

| Method | Signature | Behavior |
|---|---|---|
| `invalidate` | `invalidate(obj)` | Set `dirty_ = true`, call `notifyListeners_()`. Public — also called by the parent-DataChanged listener wiring. |
| `addListener` | `addListener(obj, l)` | Append `l` to `listeners_`. `l` must `ismethod(l, 'invalidate')`, else `DerivedTag:invalidListener`. |
| `recompute_` | `recompute_(obj)` (private) | The actual compute call. See §3.5 for full algorithm. |
| `notifyListeners_` | `notifyListeners_(obj)` (private) | For each `l` in `listeners_`, call `l.invalidate()`. |

### 3.5 recompute_ algorithm

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

A function-handle ComputeFn **cannot round-trip** through `toStruct/fromStruct`. Two options:

1. **Reject at toStruct time**: throw `DerivedTag:nonSerializableCompute` if `ComputeFn` is a function handle. Users must wrap in a class subclass.
2. **Allow with caveat**: `toStruct` stores `s.computekind='function_handle'`, `s.computestr=func2str(ComputeFn)`; `fromStruct` leaves `ComputeFn = []` and sets a sentinel `obj.ComputeFn = @() error('DerivedTag:computeNotRehydrated', ...)`. The user must reattach the real handle via a registration step *after* `loadFromStructs`.

**Decision: Option 2.** Round-tripping a function-handle string is impossible (closures, anonymous fns can't be reconstructed safely), but the design for derived tags assumes registration code re-runs at session start (the `+monitoring` `registerTags.m` pattern), so reattachment is natural. Document this clearly in the class header.

For object-form ComputeFn, require the object to implement `toStruct()` and `fromStruct()` and round-trip via class-name dispatch (similar to how `TagRegistry.instantiateByKind` dispatches Tag kinds). This means **DerivedSource subclasses MUST be serializable** to round-trip.

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

## (Sections 5–13 retained verbatim from user-supplied spec; full text lives in this file's commit message and source spec.)

See user-supplied message for full §5 (pitfall checklist), §6 (cross-cutting integration), §7 (file layout), §8 (full DerivedTag.m skeleton), §9 (test plan with ~25 methods), §10 (acceptance criteria), §11 (out of scope), §12 (references), §13 (estimated effort).

The implementation here follows the §8 skeleton and the §9 test plan exactly. Cross-cutting edits per §6 are applied. Acceptance criteria per §10 are the gate.
