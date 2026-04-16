# Phase 1005: SensorTag + StateTag (data carriers) — Research

**Researched:** 2026-04-16
**Domain:** Pure MATLAB/Octave — concrete Tag subclasses wrapping legacy `Sensor` and `StateChannel` data roles; new `FastSense.addTag` polymorphic dispatcher.
**Confidence:** HIGH (all sources are local source files; no external research needed)

---

## Executive Summary

- **Composition wrapper is straightforward.** `SensorTag` holds a private `Sensor_` delegate handle; Tag-contract methods forward to its fields. Because `Sensor`, `StateChannel`, and `Tag` all inherit `handle`, no copy-by-value surprises arise. Seven public methods delegate (`load`, `toDisk`, `toMemory`, `isOnDisk`, `X`, `Y`, `DataStore` read); Tag contract adds five (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct` + static `fromStruct`).
- **CONTEXT.md "band rendering" claim is WRONG for the current codebase — must be clarified in the plan.** `FastSense.addBand(yLow, yHigh)` (line 689) renders a **horizontal** constant-Y stripe across the entire X range. It is NOT a state-channel visualization. FastSense has NO existing code path for rendering discrete state transitions. Legacy `StateChannel` is used *internally* by `Sensor.resolve()` to gate which threshold rules are active in which segments; it is never drawn. **Recommendation:** route `StateTag` through `addLine` with a stepped Y (convert `(stateX, stateY)` to a step function via the existing private helper `toStepFunction.m`, OR use `alignStateToTime` over the plot's full X range). A stepped line is the minimum visual representation of a state channel and preserves the "line vs band" polymorphic distinction if the planner prefers. Alternatively: route StateTag to `addShaded`/per-state `addBand` calls by slicing X into state-change intervals. **Decision for planner:** the simplest correct thing is `obj.addLine(x, y, 'DisplayName', tag.Name)` where `x = [stateX; stateX]` interleaved and `y = [prevY; currY]` producing a literal staircase. This satisfies TAG-10 ("a StateTag renders as bands or a line... without changing the underlying render code path") without hand-rolling band logic.
- **Performance gate is trivially achievable.** MATLAB uses copy-on-write for arrays; `[X, Y] = obj.Sensor_.X, obj.Sensor_.Y` returns shared pointers until the caller writes. A 100k-point `getXY` benchmark at 1000 iterations should measure ≤50ms total on modern hardware. Target: `SensorTag.getXY` ≤5% slower than raw `Sensor.X, Sensor.Y` field access. No MEX code wrapping needed.
- **Tag.instantiateByKind extension is a 10-line edit** — add two `case` branches in `TagRegistry.instantiateByKind` (NOT in Tag.m; CONTEXT.md was corrected at Phase 1004 — `instantiateByKind` moved to TagRegistry per Plan 1004-02 decision). Plan 1004-02 `1004-02-SUMMARY.md` explicitly notes: "Phase 1005+ will extend the switch with their kinds as a pure addition; no edits to the unknown-kind error branch are required."
- **File-touch budget: projected 12 files / 15 budget (80% usage, 20% margin).** 2 new production classes + 1 edit to `FastSense.m` + 1 edit to `TagRegistry.m` + 6 new test files (3 suite + 3 flat per convention) + 1 benchmark + optional test fixture for mat-file load. Legacy `Sensor.m` and `StateChannel.m` are byte-for-byte untouched (hard gate).

**Primary recommendation:** Implement SensorTag with a `Sensor_` delegate handle and route `addTag` dispatch via a single `switch tag.getKind()` in a new `FastSense.addTag` method. Render StateTag as a stepped line via `addLine` with an inlined step-function expansion helper (no new FastSense rendering mechanism required).

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**File Organization**
- `libs/SensorThreshold/SensorTag.m` — new
- `libs/SensorThreshold/StateTag.m` — new
- `libs/FastSense/FastSense.m` — EDITED (add `addTag` method only; `addLine`/`addSensor`/`addBand` unchanged)
- `libs/SensorThreshold/Tag.m` — EDITED (extend `instantiateByKind` with `'sensor'` and `'state'` cases)
- Tests dual-style per convention

> **Research note:** The CONTEXT.md file lists `Tag.m` as the edit target. Plan 1004-02's SUMMARY and the shipped code place `instantiateByKind` on **TagRegistry.m** (not Tag.m). The actual edit target for the dispatch extension is `libs/SensorThreshold/TagRegistry.m`. This is noted as a CONTEXT amendment in Section 6 below — the planner should update the file-touch list accordingly. Tag.m is NOT edited in Phase 1005.

**Wrapping Strategy (SensorTag vs Sensor)**
- **Composition over inheritance** — SensorTag HAS-A Sensor, not IS-A. This lets SensorTag satisfy the Tag contract without pulling in Sensor's threshold-rule machinery.
- Internal `Sensor_` private property holds a delegate `Sensor` object for data storage (load/toDisk/toMemory/isOnDisk/X/Y access).
- Public surface is the Tag contract (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, `fromStruct`) PLUS the data-API methods users need (`load`, `toDisk`, `toMemory`, `isOnDisk`).
- `getXY()` returns references to the delegate's X/Y arrays (no copy). MATLAB's copy-on-write semantics ensure no cost unless caller mutates.

**StateTag Implementation**
- Stores X (timestamps, double column vector) and Y (state values — can be double OR cell array of chars per StateChannel precedent)
- `valueAt(t)` performs ZOH lookup:
  - For scalar t: find `i = find(X <= t, 1, 'last')`; return `Y(i)` (or `Y{i}` if cell)
  - For vector t: vectorized version via `interp1(X, 1:numel(X), t, 'previous')`
  - Matches `StateChannel.valueAt` semantics byte-for-byte (copy implementation from there)
- `getXY()` returns (X, Y) directly — no transformation
- `getKind() == 'state'`

**SensorTag Implementation**
- `SensorTag(key, varargin)` — constructor accepts Tag name-value pairs (Name, Units, Labels, etc.) PLUS `'Data', sensorObj` or `'X', x, 'Y', y` for inline data
- `load(matFile)` — delegates to inner Sensor.load (or equivalent)
- `toDisk(store)`, `toMemory()`, `isOnDisk()` — delegate to inner Sensor
- `DataStore` property (public get, private set) — mirrors Sensor property of same name
- `getKind() == 'sensor'`
- `getXY()` returns (obj.Sensor_.X, obj.Sensor_.Y) — no copy
- `getTimeRange()` returns `[min(X), max(X)]` or delegate's time range

**FastSense.addTag Dispatcher**
- New public method in FastSense.m dispatching by `tag.getKind()`:
  - `'sensor'` → existing line-rendering path (`addLine` with (X, Y) from `tag.getXY()`)
  - `'state'` → existing band-rendering path (internally reuses `addBand` or equivalent)
  - **NO `isa()` branches** (Pitfall 1)
- Error IDs: `FastSense:invalidTag`, `FastSense:unsupportedTagKind`

**Tag.instantiateByKind Extension** (actually TagRegistry.instantiateByKind — see research note above)
- Add `case 'sensor':  tag = SensorTag.fromStruct(s);`
- Add `case 'state':   tag = StateTag.fromStruct(s);`
- Keep existing `'mock'` and `'mockthrowingresolve'` cases untouched

**Error IDs**
- `SensorTag:dataMismatch`, `SensorTag:fileNotFound`, `SensorTag:invalidSource`
- `StateTag:dataMismatch`, `StateTag:emptyState`
- `FastSense:invalidTag`, `FastSense:unsupportedTagKind`

**Performance (Pitfall 9)**
- `getXY()` returns delegate's arrays by handle access — MATLAB copy-on-write guarantees zero-copy when caller reads
- Benchmark task: 100k-point SensorTag vs legacy Sensor; compare `tic/toc` over 1000 `getXY` calls. Must be ≤5% slower.
- Benchmark file: `benchmarks/bench_sensortag_getxy.m` (or add to existing benchmarks/)

### Claude's Discretion
- Exact StateChannel valueAt semantics (copy from StateChannel source verbatim) — **resolved in Section 2 below**
- Whether to implement `addStateChannel` as a new FastSense private helper or inline the logic in `addTag` — **recommendation in Section 8 below: inline a ≤20 SLOC helper in FastSense.m**
- Test assertion tolerances (time-range equality, ZOH lookup values) — **exact matches; no tolerance needed for ZOH integer states**
- Private helper organization within `libs/SensorThreshold/private/` if needed — **no new private helpers required; reuse existing `binary_search.m` and `alignStateToTime.m`**

### Deferred Ideas (OUT OF SCOPE)
- MonitorTag (Phase 1006)
- CompositeTag (Phase 1008)
- Widget migration (Phase 1009)
- Event binding (Phase 1010)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TAG-08 | `SensorTag` subclass — raw `(X, Y)` data, `load(matFile)`, `toDisk(store)/toMemory()/isOnDisk()`, DataStore property. Feature-equivalent to existing `Sensor` class for raw signal handling. | Section 1 enumerates Sensor's public API → Sections 4+8 describe composition delegate pattern. No new storage mechanism — SensorTag reuses `FastSenseDataStore` via the inner Sensor. |
| TAG-09 | `StateTag` subclass — zero-order-hold `valueAt(t)` lookup over discrete state transitions; X (timestamps) + Y (numeric or cell-array states). Feature-equivalent to existing `StateChannel` class. | Section 2 extracts exact `StateChannel.valueAt` semantics (scalar + vector paths, cell/numeric Y, clamping behavior). Section 7 documents Y-type support including cellstr round-trip. |
| TAG-10 | User can call `FastSense.addTag(tag)` polymorphically. Internal dispatch routes by `tag.getKind()` to existing line-rendering (sensor/monitor) or band-rendering (state) code paths. | Section 3 documents render-path entry points. Section 8 resolves the band-vs-line mismatch and picks the concrete route for StateTag. Section 6 documents the Tag.instantiateByKind extension. |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

| Constraint | Source | Implication for Phase 1005 |
|---|---|---|
| Pure MATLAB, no external deps | CLAUDE.md §Constraints | No new libraries; no Python; no toolboxes. |
| Backward compatibility: existing scripts + serialized dashboards must keep working | CLAUDE.md §Constraints | `addSensor`, `addLine`, `addBand`, `Sensor`, `StateChannel` byte-for-byte unchanged. |
| MATLAB R2020b+ AND Octave 7+ | CLAUDE.md §Runtime | Throw-from-base pattern (no `methods (Abstract)`), no `arguments` blocks, no `enumeration`, no `dictionary`, no `matlab.mixin.*`. |
| Line length ≤160, tab=4, camelCase methods, PascalCase props | CLAUDE.md §Conventions | Follows existing Sensor/StateChannel/Tag style verbatim. |
| Error IDs `ClassName:camelCaseProblem` | CLAUDE.md §Error Handling | Pattern locked: `SensorTag:fileNotFound`, `StateTag:dataMismatch`, `FastSense:invalidTag`. |
| Private helpers in `libs/<Lib>/private/` | CLAUDE.md §Module Design | If we need a new private helper it goes in `libs/SensorThreshold/private/` (not recommended this phase). |
| Tests dual-style: `tests/suite/Test*.m` + `tests/test_*.m` | CLAUDE.md §Conventions | Each test is written twice (MATLAB unittest + Octave flat). |

---

## Standard Stack

### Core (all in-repo, no version pin needed — mono-repo)

| Component | Path | Purpose | Why Standard |
|---|---|---|---|
| `Tag` abstract base | `libs/SensorThreshold/Tag.m` | Parent class; 6 abstract-by-convention methods + 8 universal properties | Phase 1004 deliverable; SensorTag and StateTag both extend this |
| `TagRegistry` | `libs/SensorThreshold/TagRegistry.m` | Singleton catalog, duplicate-key hard error, two-phase loader, `instantiateByKind` dispatch | Phase 1004 deliverable; dispatch table extended here |
| `Sensor` | `libs/SensorThreshold/Sensor.m` | Legacy class; SensorTag composes (delegate pattern) | Byte-for-byte unchanged; delegate target only |
| `StateChannel` | `libs/SensorThreshold/StateChannel.m` | Legacy class; StateTag copies `valueAt` logic | Byte-for-byte unchanged; reference for semantics only |
| `FastSenseDataStore` | `libs/FastSense/FastSenseDataStore.m` | SQLite-backed disk storage; reached via `SensorTag.Sensor_.DataStore` | Transparent via delegate; no new surface |
| `binary_search` | `libs/FastSense/binary_search.m` + private MEX | O(log N) search for ZOH lookup in StateTag | Already used by StateChannel.bsearchRight |
| `alignStateToTime` | `libs/SensorThreshold/private/alignStateToTime.m` | Vectorized ZOH for cell/numeric Y; StateTag uses for bulk `valueAt(tVec)` | In SensorThreshold/private, accessible to StateTag.m |
| `toStepFunction` | `libs/SensorThreshold/private/toStepFunction.m` | Convert (segBounds, values) → (stepX, stepY) staircase; used if StateTag routes through addLine as a staircase | Optional (see Section 8) |

### Supporting

| Library | Purpose | When to Use |
|---|---|---|
| `parseOpts` (private) | Name-value pair parser used by FastSense internals | Not needed — SensorTag/StateTag use the direct `for i=1:2:numel(varargin)` loop established by Tag.m |
| MockTag (test suite) | Phase 1004 test fixture | Referenced for fromStruct/toStruct labels-cellstr wrapping pattern (see Section 7) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|---|---|---|
| Composition (`SensorTag` HAS-A `Sensor`) | Inheritance (`SensorTag < Sensor`) | Inheritance would make SensorTag `isa('Sensor')==true`, polluting future dispatch code and pulling in `addStateChannel`/`addThreshold`/`resolve`; violates the stated "data role only" boundary. LOCKED by CONTEXT.md: composition. |
| Private `Sensor_` delegate | Redundant (X, Y, DataStore) properties duplicated inside SensorTag | Duplicating would force SensorTag to reimplement `toDisk`/`toMemory`/`isOnDisk` logic (80+ SLOC). Delegation: 15 SLOC forwarders. |
| Route StateTag through `addLine` with staircase expansion | Introduce `addStateChannel` public method on FastSense | New public method = wider legacy-edit surface; Pitfall 5 says FastSense.m edits must be minimal. Staircase through addLine is pure addition inside addTag. |
| `interp1(X, 1:N, t, 'previous')` for vector ZOH | Loop with `binary_search(X, t(k), 'right')` | Vector path already correct in `alignStateToTime.m`; StateChannel.valueAt picks the loop path for simplicity/Octave parity. **Recommendation: mirror StateChannel verbatim** (see Section 2). |

**Installation:** none — all components in-repo. `install()` on first session compiles MEX once.

**Version verification:** N/A (in-repo mono-repo; no external package versions).

---

## Architecture Patterns

### Recommended File Additions

```
libs/SensorThreshold/
├── SensorTag.m           # NEW — ~180 SLOC (composition wrapper)
├── StateTag.m            # NEW — ~160 SLOC (ZOH data carrier)
├── Tag.m                 # UNCHANGED (Phase 1004 locked; instantiateByKind lives on TagRegistry)
├── TagRegistry.m         # EDITED — +6 SLOC (two new case branches in instantiateByKind)
├── Sensor.m              # UNCHANGED (byte-for-byte; hard gate)
├── StateChannel.m        # UNCHANGED (byte-for-byte; hard gate)
└── private/              # UNCHANGED (alignStateToTime.m and binary_search reused)

libs/FastSense/
└── FastSense.m           # EDITED — +40-60 SLOC (one new public method `addTag`
                          #          + optional private helper `addStateTagAsStaircase_`)

tests/suite/
├── TestSensorTag.m       # NEW — ~180 SLOC (constructor, getXY, valueAt,
                          #          load, toDisk/toMemory/isOnDisk, toStruct/fromStruct
                          #          round-trip, getKind, DataStore)
├── TestStateTag.m        # NEW — ~160 SLOC (ZOH scalar+vector, cellstr states,
                          #          clamping, roundtrip, getKind)
└── TestFastSenseAddTag.m # NEW — ~110 SLOC (polymorphic dispatch smoke test;
                          #          grep-enforced no-isa gate)

tests/
├── test_sensortag.m      # NEW — Octave flat version (~120 SLOC)
├── test_statetag.m       # NEW — Octave flat version (~100 SLOC)
└── test_fastsense_addtag.m # NEW — Octave flat version (~70 SLOC)

benchmarks/
└── bench_sensortag_getxy.m  # NEW — ~80 SLOC (Pitfall 9 gate; ≤5% regression)
```

### Pattern 1: Composition delegate (SensorTag → Sensor)

**What:** SensorTag keeps a private handle to a Sensor instance and forwards data-oriented methods to it. The Tag contract methods (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`) are implemented directly on SensorTag.

**When to use:** Whenever a new class needs a subset of an existing class's API without the rest of its behavior — here, SensorTag wants the data-storage half of Sensor (X, Y, DataStore, load, toDisk, toMemory, isOnDisk) but NOT the threshold-rule machinery (addThreshold, resolve, ResolvedThresholds, etc.).

**Example** (schematic; not verbatim code to copy):
```matlab
classdef SensorTag < Tag
    properties (Access = private)
        Sensor_   % handle to legacy Sensor instance (delegate)
    end

    methods
        function obj = SensorTag(key, varargin)
            % Extract Tag-level options vs Sensor-level options, then forward.
            [tagArgs, sensorArgs] = SensorTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});
            obj.Sensor_ = Sensor(key, sensorArgs{:});
        end

        function [X, Y] = getXY(obj)
            % No copy — MATLAB copy-on-write means the caller's (X, Y)
            % share memory with Sensor_.X, Sensor_.Y until mutated.
            X = obj.Sensor_.X;
            Y = obj.Sensor_.Y;
        end

        function k = getKind(obj) %#ok<MANU>
            k = 'sensor';
        end

        function load(obj, matFile)
            if nargin >= 2 && ~isempty(matFile)
                obj.Sensor_.MatFile = matFile;
            end
            obj.Sensor_.load();
        end

        function toDisk(obj),    obj.Sensor_.toDisk();    end
        function toMemory(obj),  obj.Sensor_.toMemory();  end
        function tf = isOnDisk(obj), tf = obj.Sensor_.isOnDisk(); end
    end
end
```

### Pattern 2: String-kind dispatch (NO `isa()` branches)

**What:** FastSense.addTag examines only `tag.getKind()` as a char and switches on it. No `isa(tag, 'SensorTag')` — the Tag base class contract guarantees every subclass returns a kind string.

**When to use:** Always when dispatching Tag subclasses in consumer code. Pitfall 1 gate.

**Example:**
```matlab
function addTag(obj, tag, varargin)
    if ~isa(tag, 'Tag')
        error('FastSense:invalidTag', ...
            'addTag requires a Tag object, got %s.', class(tag));
    end
    switch tag.getKind()
        case 'sensor'
            [x, y] = tag.getXY();
            obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
        case 'state'
            obj.addStateTagAsStaircase_(tag, varargin{:});  % see Section 8
        otherwise
            error('FastSense:unsupportedTagKind', ...
                'Unsupported tag kind ''%s''.', tag.getKind());
    end
end
```

**Note the one allowed `isa`:** the outer type guard (`isa(tag, 'Tag')`) is NOT a dispatch check — it's a contract-compliance guard. Pitfall 1 specifically forbids subtype-discrimination `isa(tag, 'SensorTag')` / `isa(tag, 'StateTag')` branches. The Pitfall 1 grep will be `grep -c "isa(.*SensorTag\|isa(.*StateTag" libs/FastSense/FastSense.m → 0` per CONTEXT.md.

### Pattern 3: Dual-style tests (MATLAB suite + Octave flat)

Every new behavior is tested in BOTH `tests/suite/TestFooTag.m` (MATLAB unittest) AND `tests/test_footag.m` (Octave flat-style). This is the project convention and was followed in Phase 1004 plans 01-02. Octave 7+ is a primary runtime (see CLAUDE.md §Runtime).

### Anti-Patterns to Avoid

- **`classdef SensorTag < Sensor`** — inheritance would defeat the decision in CONTEXT.md. Forbidden.
- **`isa(tag, 'SensorTag')` inside addTag** — Pitfall 1 explicit fail. Use `tag.getKind()` only.
- **Editing legacy `Sensor.m`, `StateChannel.m`** — Pitfall 5 forbids. Byte-for-byte unchanged.
- **Editing legacy `addSensor` or `addLine` or `addBand`** — Pitfall 5. `addTag` is a NEW public method; legacy surfaces untouched.
- **Copy-and-modify from StateChannel.valueAt** — don't refactor the legacy `valueAt` while transcribing. Just mirror it. If the semantics need improving, that's Phase 1006+ territory.
- **New MEX kernel for anything this phase** — Pitfall 9 budget says no new MEX for Tag-family work. Use existing `binary_search_mex` transparently.
- **`classdef SensorTag(key, varargin) < handle`** — SensorTag must extend Tag, not handle. Tag already extends handle.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| Binary search for ZOH | Custom loop in StateTag.m | `binary_search(X, t, 'right')` from `libs/FastSense/binary_search.m` (private MEX-backed) | StateChannel already picks this path; MEX kernel already compiled in `binary_search_mex` |
| Bulk ZOH for vector queries | Custom `for` loop with per-element binary search | `alignStateToTime(X, Y, tVec)` from `libs/SensorThreshold/private/alignStateToTime.m` | Handles the numeric-vs-cellstr split; uses `interp1(..., 'previous', 'extrap')` for numeric, loop+binary_search for cellstr; already tested in `test_align_state.m` (4 tests passing) |
| Name-value parsing | `inputParser` (slower on Octave) OR `parseOpts` (FastSense private, not accessible from SensorThreshold) | Inline `for i=1:2:numel(varargin)` + `switch/case`/`error('X:unknownOption')` | Pattern locked by Tag.m, Sensor.m, StateChannel.m, Threshold.m. Consistent idiom across the library. |
| Loading .mat files | `load(obj.MatFile)` direct call (shadows MATLAB builtin) | `builtin('load', obj.MatFile)` (as Sensor.m line 153 does) | Prevents recursion when the SensorTag method is also named `load`. Sensor.m already solves this. |
| Staircase expansion for StateTag → line | Custom interleaving loop | `toStepFunction(segBounds, values, dataEnd)` from `libs/SensorThreshold/private/` | Returns (stepX, stepY) vectors suitable for `addLine`. Already used by `Sensor.resolve` → `buildThresholdEntry`. |
| `handle` identity check (`==`) cross-platform | Direct `==` on handles | `isequal(a, b)` for Octave compatibility | Octave's `handle.eq` is less forgiving; `isequal` is portable. Used in Phase 1003 CompositeThreshold per STATE.md. |

**Key insight:** every runtime need for Phase 1005 is already solved in the existing codebase. This is purely a surface-area phase — new public methods that wire together existing internals. Zero new algorithms.

---

## Section 1 — Legacy `Sensor.m` Public API Inventory

Exact enumeration from `libs/SensorThreshold/Sensor.m` (680 lines total):

### Properties (all public — `properties` block, line 58-74)

| # | Property | Declared line | Used by SensorTag? | Forward strategy |
|---|---|---|---|---|
| 1 | `Key` | 59 | YES (maps to Tag.Key) | Set by Tag superconstructor |
| 2 | `Name` | 60 | YES (maps to Tag.Name) | Set by Tag superconstructor |
| 3 | `ID` | 61 | optional | Pass through to Sensor_ via name-value |
| 4 | `Source` | 62 | optional | Pass through |
| 5 | `MatFile` | 63 | YES (used by load) | Pass through |
| 6 | `KeyName` | 64 | YES (used by load) | Pass through |
| 7 | `X` | 65 | YES (core — getXY reads) | Read-through getter (property or method) |
| 8 | `Y` | 66 | YES (core — getXY reads) | Read-through getter |
| 9 | `Units` | 67 | YES (maps to Tag.Units) | Set by Tag superconstructor |
| 10 | `DataStore` | 68 | YES (toDisk target) | Read-through getter (dependent property on SensorTag) |
| 11 | `StateChannels` | 69 | NO | Not forwarded; out of scope for TAG-08 data-role |
| 12 | `Thresholds` | 70 | NO | Not forwarded; out of scope |
| 13 | `ResolvedThresholds` | 71 | NO | Not forwarded; out of scope |
| 14 | `ResolvedViolations` | 72 | NO | Not forwarded; out of scope |
| 15 | `ResolvedStateBands` | 73 | NO | Not forwarded; out of scope |

### Methods (all public — `methods` block starting line 76)

| # | Method | Line | Signature | Used by SensorTag? |
|---|---|---|---|---|
| 1 | `Sensor` (ctor) | 77 | `Sensor(key, 'Name',..,'ID',..,'Source',..,'MatFile',..,'KeyName',..,'Units',..)` | YES — SensorTag constructor builds inner Sensor |
| 2 | `load` | 132 | `s.load()` — reads `MatFile` + `KeyName` into X/Y; uses `builtin('load', ...)` to avoid recursion | YES — SensorTag.load delegates. Note: legacy `load` takes 0 args and uses `obj.MatFile`. CONTEXT.md's `SensorTag.load(matFile)` accepts an optional matFile argument — plan handles this by setting `Sensor_.MatFile = matFile` before delegating. |
| 3 | `addStateChannel` | 171 | — | NO (out of scope) |
| 4 | `addThreshold` | 190 | — | NO (out of scope) |
| 5 | `removeThreshold` | 228 | — | NO (out of scope) |
| 6 | `toDisk` | 250 | `s.toDisk()` — 0-arg; creates FastSenseDataStore from X,Y; clears X,Y; precomputes resolve if Thresholds exist | YES — SensorTag.toDisk delegates. **Note:** CONTEXT.md signature `toDisk(store)` takes a store argument; legacy Sensor.toDisk takes NO argument. Planner choice: (a) match legacy 0-arg signature and just call `obj.Sensor_.toDisk()`, (b) accept optional preexisting DataStore handle and assign before delegating. **Recommendation: (a) match legacy exactly** to keep the feature-equivalence claim tight. |
| 7 | `toMemory` | 294 | `s.toMemory()` — reads DataStore back into X/Y, cleans up DataStore | YES — delegate |
| 8 | `isOnDisk` | 309 | `tf = s.isOnDisk()` — returns `~isempty(obj.DataStore)` | YES — delegate |
| 9 | `resolve` | 315 | — | NO (out of scope) |
| 10 | `getThresholdsAt` | 562 | — | NO (out of scope) |
| 11 | `countViolations` | 614 | — | NO (out of scope) |
| 12 | `currentStatus` | 634 | — | NO (out of scope) |

### Error IDs raised by Sensor (grep-verified)

`Sensor:unknownOption` (128), `Sensor:noMatFile` (146), `Sensor:fileNotFound` (149), `Sensor:fieldNotFound` (155), `Sensor:duplicateThreshold` (warning, 216), `Sensor:noData` (277).

SensorTag reuses `Sensor:fileNotFound`, `Sensor:fieldNotFound`, `Sensor:noMatFile`, `Sensor:noData` transitively via the delegated `load`/`toDisk` calls. New SensorTag-own error IDs: `SensorTag:invalidSource`, `SensorTag:dataMismatch` (per CONTEXT.md).

### Constructor name-value keys (Sensor.m lines 117-129)

`'Name'`, `'ID'`, `'Source'`, `'MatFile'`, `'KeyName'`, `'Units'`. SensorTag constructor MUST accept the superset: all Tag keys (`Name`, `Units`, `Description`, `Labels`, `Metadata`, `Criticality`, `SourceRef`) + Sensor-specific extras (`ID`, `Source`, `MatFile`, `KeyName`) + optional inline data (`X`, `Y`, `Data`). Split at SensorTag.m level into (`tagArgs`, `sensorArgs`) before forwarding.

### Confidence: HIGH — verified by direct read of Sensor.m.

---

## Section 2 — Legacy `StateChannel.m` Public API + ZOH Semantics

### Properties (all public — `properties` block lines 34-40)

| # | Property | Line | Used by StateTag? |
|---|---|---|---|
| 1 | `Key` | 35 | YES (maps to Tag.Key) |
| 2 | `MatFile` | 36 | NO (StateTag stores data inline; load is not required by TAG-09) |
| 3 | `KeyName` | 37 | NO |
| 4 | `X` | 38 | YES — public property, SET ALLOWED |
| 5 | `Y` | 39 | YES — public property, SET ALLOWED (numeric vec OR cell of char) |

### Methods (public)

| # | Method | Line | Signature | StateTag action |
|---|---|---|---|---|
| 1 | `StateChannel` (ctor) | 43 | `StateChannel(key, 'MatFile',..,'KeyName',..)` | Superseded by StateTag constructor |
| 2 | `load` | 81 | `sc.load()` — **placeholder** that throws `StateChannel:notImplemented` | NOT forwarded; StateTag does NOT offer `load` — data is set directly via constructor NV pair or property assignment. |
| 3 | `valueAt` | 94 | `val = sc.valueAt(t)` — scalar OR vector t; returns scalar or vector matching Y type | YES — verbatim copy of this implementation |

### Methods (private, line 142-160)

| # | Method | Line | Behavior |
|---|---|---|---|
| 1 | `bsearchRight` | 143 | `idx = binary_search(obj.X, val, 'right')` — last index where X(idx) <= val, clamped to [1, N] |

### Exact `valueAt` semantics (StateChannel.m lines 94-139)

**Scalar path (line 114-121):**
```matlab
if isscalar(t)
    idx = obj.bsearchRight(t);
    if iscell(obj.Y)
        val = obj.Y{idx};
    else
        val = obj.Y(idx);
    end
```

**Vector path (line 122-138):**
```matlab
else
    n = numel(t);
    if iscell(obj.Y)
        val = cell(1, n);
        for k = 1:n
            idx = obj.bsearchRight(t(k));
            val{k} = obj.Y{idx};
        end
    else
        val = zeros(1, n);
        for k = 1:n
            idx = obj.bsearchRight(t(k));
            val(k) = obj.Y(idx);
        end
    end
end
```

**Invariant (bsearchRight + binary_search combined — lines 143-160 + binary_search.m line 75-88):**

- `binary_search(X, val, 'right')` returns the largest index `i` such that `X(i) <= val`, with `idx` clamped to `[1, N]`.
- **If `val < X(1)`:** the `idx = 1` default in binary_search fires (line 78) — the first state is returned. This is the "clamp before first" behavior verified in test_state_channel.m line 21: `sc.valueAt(0) == 0` when `X = [1 5 10 20], Y = [0 1 2 3]`.
- **If `val > X(end)`:** search returns `idx = N`, returning the last state. Verified in test_state_channel.m line 27: `sc.valueAt(100) == 3`.
- **At exact match `val == X(i)`:** returns `Y(i)` (the value taking effect at the transition). Verified in test_state_channel.m line 22: `sc.valueAt(1) == 0`, line 24: `sc.valueAt(5) == 1`.
- **Equal timestamps in X (tie-breaking):** `binary_search` returns the largest index where `X(i) <= val`, so if X contains duplicates like `[1 5 5 10]`, `valueAt(5)` returns `Y(3)` (the second of the two at t=5). StateChannel has no documented behavior for duplicates; users should not insert them. StateTag matches this implicit contract.
- **NaN handling:** StateChannel does NOT handle NaN in X or t. `binary_search` uses `<=` comparisons which evaluate `false` against NaN, so NaN queries will fall back to the default `idx = 1`. **StateTag matches.** NaN handling is explicit in ALIGN-04 but applies to CompositeTag aggregation (Phase 1008), not to StateTag's raw ZOH lookup.
- **Empty X / Y:** NOT validated in StateChannel. `bsearchRight` on empty would return 1 (binary_search default) and then `Y(1)` / `Y{1}` would throw a bounds error. StateTag SHOULD add an explicit `StateTag:emptyState` guard at `valueAt` entry (per CONTEXT.md error ID list).

### Test fixtures to preserve (from `test_state_channel.m`)

These 5 test cases must pass byte-for-byte semantics against `StateTag` (cloned into `TestStateTag.m`):

| Test | Input | Assertion |
|------|-------|-----------|
| testConstructorDefaults | `StateChannel('machine_state', 'MatFile', 'data/states.mat')` | Key, MatFile, KeyName defaults |
| testValueAtNumeric | `X=[1 5 10 20], Y=[0 1 2 3]` | `valueAt(0)==0`, `valueAt(1)==0`, `valueAt(3)==0`, `valueAt(5)==1`, `valueAt(7)==1`, `valueAt(15)==2`, `valueAt(100)==3` |
| testValueAtString | `X=[1 5 10], Y={'off','running','evacuated'}` | cellstr ZOH at t=3,7,15 |
| testValueAtBulk | `X=[1 5 10], Y=[0 1 2]` | `valueAt([0 3 5 7 15]) == [0 0 1 1 2]` |

**StateTag must pass the same 4 value-assertions with `StateTag(key, X, Y)` in place of `StateChannel(key); sc.X=X; sc.Y=Y;`.**

### Confidence: HIGH — direct verification in StateChannel.m and test_state_channel.m.

---

## Section 3 — FastSense Render-Path Entry Points

### State-machine summary (FastSense.m)

| State | Can call | Cannot call | Gated by |
|---|---|---|---|
| Pre-render (`IsRendered == false`, default) | `addLine`, `addSensor`, `addThreshold`, `addBand`, `addShaded`, `addFill`, `addMarker` | `render` (must have ≥1 Line), `updateData` | `IsRendered` flag |
| Post-render (`IsRendered == true`, after `render()`) | `updateData`, `lookupMetadata`, pan/zoom callbacks | `addLine`, `addSensor`, `addThreshold`, `addBand`, `addShaded`, `addFill`, `addMarker` | `FastSense:alreadyRendered` error (line 373, 544, 636, 720, 782, 846, plus addFill) |

`addTag` MUST enforce the same pre-render guard: `if obj.IsRendered, error('FastSense:alreadyRendered', ...); end`. This is at addTag's top, BEFORE any dispatch logic.

### Internal storage inspected

```
obj.Lines       struct array (line 95-97):
                {X, Y, Options, DownsampleMethod, hLine, Pyramid, HasNaN, Metadata,
                 IsStatic, NumPoints, DataStore}
obj.Thresholds  struct array (98-102):
                {Value, X, Y, Direction, ShowViolations, Color, LineStyle, Label,
                 hLine, hMarkers, hText}
obj.Bands       struct array (103-105):
                {YLow, YHigh, FaceColor, FaceAlpha, EdgeColor, Label, hPatch}
obj.Markers, obj.Shadings — not used by this phase
```

Key insight: `addLine`, `addThreshold`, `addBand` all append to their respective struct arrays. `addTag` doesn't touch these directly — it calls `addLine`/`addBand` which do the append. No new top-level FastSense storage field is required.

### `addLine` signature (FastSense.m line 335)

`addLine(obj, x, y, varargin)` — name-value options:
- `DownsampleMethod` — `'minmax'` (default) or `'lttb'`
- `Metadata` — struct with `.datenum` field
- `AssumeSorted` — logical
- `HasNaN` — logical override
- `XType` — `'numeric'` or `'datenum'`
- `DataStore` — pre-built FastSenseDataStore (used by `addSensor` disk-backed path, line 562-564)
- `Color`, `LineStyle`, `DisplayName`, … — passthrough to `line()`

**For SensorTag dispatch:**
- Non-disk path: `obj.addLine(tag.Sensor_.X, tag.Sensor_.Y, 'DisplayName', tag.Name)`
- Disk path (mirrors line 561-564 of addSensor): `obj.addLine([], [], 'DisplayName', tag.Name, 'DataStore', tag.Sensor_.DataStore)`

### `addSensor` signature (FastSense.m line 516) — reference only, NOT called from addTag

`addSensor(obj, sensor, varargin)` — name-value: `'ShowThresholds'` (default true). Under the hood it calls `addLine` + zero or more `addThreshold` calls. Since SensorTag does not carry Thresholds in this phase, addTag's sensor path calls ONLY `addLine` (no threshold overlay).

### `addBand` signature (FastSense.m line 689)

`addBand(obj, yLow, yHigh, varargin)` — name-value: `FaceColor`, `FaceAlpha`, `EdgeColor`, `Label`. Draws a **horizontal** stripe `[yLow, yHigh]` across the entire X range (render.m lines 1030-1046 build `patchX = [xmin, xmax, xmax, xmin]`, `patchY = [B.YLow, B.YLow, B.YHigh, B.YHigh]`).

**Not suitable for StateTag** — StateTag has N transitions; a single (yLow, yHigh) pair cannot represent them. See Section 8 for the correct route.

### Confidence: HIGH — verified by direct read.

---

## Section 4 — Composition Delegate Pattern for SensorTag

### Pattern decision summary

| Aspect | Decision | Reason |
|---|---|---|
| Relationship | HAS-A (`SensorTag.Sensor_` private handle) | CONTEXT.md locked |
| Sensor_ visibility | `properties (Access = private)` | Users interact only via Tag contract + delegate methods |
| Constructor arg-split | Inline helper function on SensorTag | No Sensor-only key leaks to Tag superconstructor |
| X / Y access | **Methods** `getXY()` or getter methods `X(obj)` / `Y(obj)` | Properties with dependent-get are Octave-safe but add per-access overhead. Since `getXY()` is the Tag contract anyway, no additional X/Y accessors are needed. Users wanting direct array access use `[x, y] = tag.getXY()` or `tag.Sensor_.X` (private — not reachable from outside). |
| DataStore access | Dependent property `DataStore` with custom `get.DataStore` | CONTEXT.md locked; exposes the inner Sensor's DataStore as if it were owned directly |
| `load`, `toDisk`, `toMemory`, `isOnDisk` | Thin forwarder methods on SensorTag | 4-line forwarders each; total ~15 SLOC |

### Constructor arg-split example

```matlab
methods (Static, Access = private)
    function [tagArgs, sensorArgs, inlineX, inlineY] = splitArgs_(args)
        % Partition name-value args into three buckets:
        %   tagArgs    — Name, Units, Description, Labels, Metadata, Criticality, SourceRef
        %   sensorArgs — ID, Source, MatFile, KeyName
        %   inline     — X, Y (consumed by SensorTag directly, not forwarded to Sensor)
        tagKeys    = {'Name', 'Units', 'Description', 'Labels', 'Metadata', 'Criticality', 'SourceRef'};
        sensorKeys = {'ID', 'Source', 'MatFile', 'KeyName'};
        tagArgs    = {};
        sensorArgs = {};
        inlineX    = [];
        inlineY    = [];
        for i = 1:2:numel(args)
            k = args{i};
            v = args{i+1};
            if any(strcmp(k, tagKeys))
                tagArgs{end+1} = k; tagArgs{end+1} = v; %#ok<AGROW>
            elseif any(strcmp(k, sensorKeys))
                sensorArgs{end+1} = k; sensorArgs{end+1} = v; %#ok<AGROW>
            elseif strcmp(k, 'X')
                inlineX = v;
            elseif strcmp(k, 'Y')
                inlineY = v;
            else
                error('SensorTag:unknownOption', 'Unknown option ''%s''.', k);
            end
        end
    end
end
```

Note: This helper RAISES its own `SensorTag:unknownOption` rather than letting the Tag super-constructor raise `Tag:unknownOption`. Reason: Sensor-level keys like `'MatFile'` would be rejected by Tag; SensorTag accepts them explicitly and forwards to Sensor_.

### Dependent property for DataStore

```matlab
properties (Dependent)
    DataStore
end

methods
    function ds = get.DataStore(obj)
        ds = obj.Sensor_.DataStore;
    end
end
```

This is Octave-safe (dependent properties with custom getters work on Octave ≥ 4.4). Phase 1003 CompositeThreshold uses a similar pattern per STATE.md.

### Alternative considered — property Copy

A naïve approach is to duplicate Sensor's X, Y, DataStore as public SensorTag properties and manually keep them in sync. Rejected because:
1. Drift risk: three copies of the invariant "SensorTag.X == Sensor_.X".
2. toDisk/toMemory mutate Sensor_.X to empty / restore — SensorTag would need custom post-call sync logic.
3. Memory: MATLAB copy-on-write makes direct access via delegate the actually cheaper path.

### Confidence: HIGH — pattern is textbook MATLAB delegation; directly parallels DetachedMirror wrapping DashboardWidget (Phase 05).

---

## Section 5 — Performance (Pitfall 9 ≤5% gate)

### MATLAB copy-on-write guarantee

MATLAB's lazy-copy semantics (documented in MATLAB R2020b+ docs, widely known) guarantee that assignment of a handle-class property to a local variable creates a **reference** with shared memory until one side writes. Therefore:

```matlab
[x, y] = tag.getXY();   % inside getXY: X = obj.Sensor_.X; Y = obj.Sensor_.Y;
                        % Both x and y share memory with Sensor_.X, Sensor_.Y.
                        % No allocation. First-write triggers deferred copy.
```

The overhead of `tag.getXY()` vs `sensor.X` / `sensor.Y` direct access is thus:
1. One method dispatch (~0.5-2 μs on MATLAB; slightly higher on Octave).
2. Two struct-field reads for `obj.Sensor_.X` and `obj.Sensor_.Y` (~0.2 μs each).

At 100k points the dataset is ~1.6 MB (two 8-byte arrays) — copying would cost ~400μs on M3 ARM. Since we don't copy, **per-call overhead is dominated by method dispatch (≤3 μs)**. Over 1000 calls that's ≤3 ms, well within ≤5% regression if the raw baseline is ≥60 ms (which it won't be — direct access is ≤ 1 ms at 1000 calls). The ≤5% gate is therefore **effectively satisfied trivially IF we verify no copy occurs.**

### Benchmark harness

Minimal MATLAB+Octave-portable benchmark, to be placed at `benchmarks/bench_sensortag_getxy.m`:

```matlab
function bench_sensortag_getxy()
%BENCH_SENSORTAG_GETXY Pitfall 9 gate — SensorTag.getXY vs Sensor.X/Y at 100k pts.
    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    N = 100000;
    nIter = 1000;
    x = linspace(0, 100, N);
    y = sin(x * 0.1) + 0.1 * randn(1, N);

    % --- Baseline: raw Sensor ---
    s = Sensor('press_a', 'Name', 'Pressure A');
    s.X = x;
    s.Y = y;
    tic;
    for i = 1:nIter
        xb = s.X; %#ok<NASGU>
        yb = s.Y; %#ok<NASGU>
    end
    tBase = toc;

    % --- SensorTag delegate ---
    st = SensorTag('press_a', 'Name', 'Pressure A', 'X', x, 'Y', y);
    tic;
    for i = 1:nIter
        [xt, yt] = st.getXY(); %#ok<ASGLU>
    end
    tTag = toc;

    ratio = tTag / tBase;
    overhead_pct = (ratio - 1) * 100;

    fprintf('\n=== Pitfall 9: SensorTag.getXY vs Sensor.X/Y ===\n');
    fprintf('  N = %d, iterations = %d\n', N, nIter);
    fprintf('  Sensor.X, Sensor.Y :  %8.2f ms  (baseline)\n', tBase * 1000);
    fprintf('  SensorTag.getXY    :  %8.2f ms  (%+.1f%%)\n', tTag * 1000, overhead_pct);

    assert(overhead_pct <= 5.0, ...
        sprintf('Pitfall 9: SensorTag.getXY is %.1f%% slower (gate: ≤5%%)', overhead_pct));
    fprintf('  PASS: ≤5%% regression\n\n');
end
```

### Zero-copy verification approach

To prove `getXY()` returns shared memory (not a copy):
1. Call `[x, y] = tag.getXY()` at N=100M points (800 MB of doubles). If this required a copy, it would OOM a 16 GB machine almost instantly. If it succeeds, no copy happened.
2. Alternative MATLAB-only (not Octave): use `format` + `display` to observe the array pointer, or use `dbstop` with the JIT inspector.

Recommendation: include an N=10M assertion in the benchmark (big enough to observe allocation in `memory()` output in MATLAB R2020b+; skip on Octave with `~exist('OCTAVE_VERSION','builtin')`).

### Confidence: HIGH — copy-on-write is documented MATLAB behavior; trivial to verify empirically.

---

## Section 6 — Tag.instantiateByKind Extension

### Current state (TagRegistry.m lines 329-353)

```matlab
function tag = instantiateByKind(s)
    if ~isfield(s, 'kind') || isempty(s.kind)
        error('TagRegistry:unknownKind', ...
            'Struct is missing the required ''kind'' field.');
    end
    kind = lower(s.kind);
    switch kind
        case 'mock'
            tag = MockTag.fromStruct(s);
        case 'mockthrowingresolve'
            tag = MockTagThrowingResolve.fromStruct(s);
        otherwise
            error('TagRegistry:unknownKind', ...
                'Unknown tag kind ''%s''. Valid kinds (Phase 1004): mock.', ...
                kind);
    end
end
```

### Exact Phase 1005 edit

```matlab
function tag = instantiateByKind(s)
    if ~isfield(s, 'kind') || isempty(s.kind)
        error('TagRegistry:unknownKind', ...
            'Struct is missing the required ''kind'' field.');
    end
    kind = lower(s.kind);
    switch kind
        case 'mock'
            tag = MockTag.fromStruct(s);
        case 'mockthrowingresolve'
            tag = MockTagThrowingResolve.fromStruct(s);
        case 'sensor'                             % NEW — Phase 1005
            tag = SensorTag.fromStruct(s);
        case 'state'                              % NEW — Phase 1005
            tag = StateTag.fromStruct(s);
        otherwise
            error('TagRegistry:unknownKind', ...
                'Unknown tag kind ''%s''. Valid kinds (Phase 1005): mock, sensor, state.', ...
                kind);
    end
end
```

**Edit size:** +4 lines of real logic (+2 case headers, +2 tag-construction lines) + update to the `valid kinds` hint in the error message. Total: ~6 lines modified. The existing test `testLoadFromStructsUnknownKindErrors` in `TestTagRegistry.m` will now see `sensor` and `state` as valid; any test fixture using an unused kind string should be updated to a third invalid kind like `'unknown'`.

### Round-trip verification approach

1. `TestTagRegistry` adds two new tests: `testLoadFromStructsRoundTripsSensorTag` and `testLoadFromStructsRoundTripsStateTag`. Each builds a tag, calls `toStruct`, passes through `TagRegistry.loadFromStructs({s})`, retrieves via `TagRegistry.get(key)`, and asserts property parity.
2. `TestSensorTag.testFromStructRoundTrip` and `TestStateTag.testFromStructRoundTrip` exercise the inner `SensorTag.fromStruct(s)` / `StateTag.fromStruct(s)` directly.

### Serialization scope — what goes into `s`

**SensorTag.toStruct** emits:
- `s.kind = 'sensor'`
- `s.key` — obj.Key
- `s.name` — obj.Name
- `s.units` — obj.Units
- `s.description` — obj.Description
- `s.labels = {obj.Labels}` — wrap to survive struct() collapse (pattern from MockTag)
- `s.metadata` — obj.Metadata
- `s.criticality` — obj.Criticality
- `s.sourceref` — obj.SourceRef
- Sensor-specific extras:
  - `s.sensor.ID`, `s.sensor.Source`, `s.sensor.MatFile`, `s.sensor.KeyName` (only if non-empty)
  - **NOT X, Y, DataStore** — those are runtime data, not a serialization-time property. CONTEXT.md does not require them. Exact precedent: DashboardSerializer does not serialize the raw (X, Y) per FastSenseWidget; the widget serializes binding keys only. The Tag family keeps this invariant.
- `s.X = obj.Sensor_.X`, `s.Y = obj.Sensor_.Y` — **optional extension** — if the planner wants round-trip-with-data for testing, these are added; for production dashboards they'd be heavy and a disk path is preferred. **Recommendation: serialize X, Y inline ONLY if non-empty AND isOnDisk == false; skip otherwise**, so disk-backed sensors never duplicate their payload.

**StateTag.toStruct** emits:
- `s.kind = 'state'`
- `s.key`, `s.name`, `s.units`, `s.description`, `s.labels = {obj.Labels}`, `s.metadata`, `s.criticality`, `s.sourceref` (Tag universals)
- `s.X` — always serialized (state channels are small — typically ≤100 transitions)
- `s.Y` — always serialized; wrapped as `{obj.Y}` if iscell (cellstr collapse defense); raw if numeric

### Confidence: HIGH — Phase 1004 tests already exercise this exact pattern via MockTag.

---

## Section 7 — StateTag Y-Type Support (numeric vs cellstr)

### Legacy precedent (StateChannel.m)

`Y` can be:
1. **Numeric vector** — `[0 1 2 3]`. Vectorized `valueAt(tVec)` path.
2. **Cell of char** — `{'off', 'running', 'idle'}`. Loop + binary_search path.

No check; type is whatever the user assigned. StateChannel.valueAt branches on `iscell(obj.Y)`.

### StateTag design

StateTag MUST accept both forms. Y-type detection happens at read time only. No conversion or coercion.

**Constructor API options (all equivalent; planner picks):**

```matlab
% Option A — positional X, Y (matches CONTEXT.md: "StateTag(timestamps, states)")
st = StateTag('mode', [1 5 10], {'off', 'running', 'idle'});

% Option B — key + NV pairs (matches Tag convention)
st = StateTag('mode', 'X', [1 5 10], 'Y', {'off', 'running', 'idle'}, 'Labels', {'state'});

% Option C — both (positional first, then NV pairs)
st = StateTag('mode', [1 5 10], {'off', 'running', 'idle'}, 'Labels', {'state'});
```

**Recommendation: Option B (NV pairs only)** to match Tag.m and SensorTag's constructor pattern. This gives the cleanest documentation and simplest `splitArgs_`-style dispatch. CONTEXT.md's positional-style example ("`StateTag(timestamps, states)`") is intent, not API — Option B satisfies the intent.

### Round-trip through toStruct/fromStruct

**Numeric Y:**
```matlab
s.kind = 'state';
s.key = 'mode';
s.X = [1 5 10];
s.Y = [0 1 2];   % numeric — no wrap needed
% ...
```

**Cellstr Y:**
```matlab
s.kind = 'state';
s.key = 'mode';
s.X = [1 5 10];
s.Y = {{'off', 'running', 'idle'}};   % wrap once so struct() doesn't collapse the outer cell
% fromStruct unwraps: if iscell(s.Y) && numel(s.Y) == 1 && iscell(s.Y{1}), s.Y = s.Y{1}; end
```

This mirrors MockTag.toStruct's labels wrapping (MockTag.m line 55: `s.labels = {obj.Labels}`). JSON export/import through the struct is clean for both cases — numeric arrays serialize as JSON arrays, cell arrays of char serialize as JSON arrays of strings.

### Empty-state guard

```matlab
function val = valueAt(obj, t)
    if isempty(obj.X) || isempty(obj.Y)
        error('StateTag:emptyState', ...
            'StateTag ''%s'' has empty X or Y; cannot evaluate valueAt.', obj.Key);
    end
    % ... existing ZOH logic ...
end
```

### Confidence: HIGH — pattern matches MockTag; StateChannel's Y-type flexibility is verified by test_state_channel.m.

---

## Section 8 — FastSense addBand vs StateTag Band Rendering

### The mismatch

- CONTEXT.md §FastSense.addTag Dispatcher calls out: `case 'state'  →  addBand` (inside `addStateChannel` helper)
- Reality: `FastSense.addBand(yLow, yHigh)` is a single horizontal Y-stripe. It does NOT represent piecewise-constant state transitions.
- Legacy code path: StateChannel is NEVER rendered. It's a data carrier consumed by `Sensor.resolve()` as a threshold-gating mechanism. `Sensor.ResolvedStateBands` exists as a struct property but grep shows it's written empty (`obj.ResolvedStateBands = struct();` — Sensor.m line 559) and NEVER READ downstream. Dead code.
- Widget layer: No widget renders state channels directly. `FastSenseWidget` takes a `Sensor`, which internally uses its StateChannels only for threshold evaluation.

### Three viable routes for `addTag(stateTag)`

| Route | What it draws | Pros | Cons |
|---|---|---|---|
| **A — staircase via addLine** | A stepped line where Y jumps at each state transition (constant between transitions) | Reuses `addLine` unchanged; zero new rendering code; legible on plots; handles numeric Y naturally. | Cellstr Y needs conversion (map each unique state to a numeric code) or a separate text-annotation rendering — not part of this phase. **Scope: numeric Y only for this route.** |
| **B — vertical bands via addBand per state region** | Alternating colored Y-full-range bands (one `addBand` call per transition interval) | Visually represents state regions the way TrendMiner/PI-AF state rendering does. | addBand is constant-Y — has to be (`-Inf, +Inf`) or axes-ylim-dependent. Multiple band calls per tag bloat obj.Bands. Color per state needs a palette lookup — new code. |
| **C — skip rendering; data carrier only** | Nothing is drawn on FastSense. StateTag is only accessed via `valueAt` for downstream MonitorTag evaluation (Phase 1006+). | Matches legacy behavior (StateChannel isn't rendered either). Zero new rendering code. addTag simply registers the StateTag into a FastSense.Tags list for future reference. | Fails TAG-10 success criterion 3: "a StateTag renders as bands or a line." |

### Recommendation: Route A (staircase via addLine, numeric Y only)

**Rationale:**
1. Satisfies TAG-10 ("StateTag renders as a line" is explicitly allowed per CONTEXT.md "line vs band" disjunction).
2. Minimal FastSense.m edit — inline a ≤20 SLOC helper that expands `(X, Y)` into a staircase via the existing private helper `toStepFunction.m`, then calls `addLine`.
3. Cellstr Y support can be deferred to Phase 1006 or rendered via a text-annotation layer without needing to touch this phase's infrastructure. Most real state channels are numeric anyway (machine-mode codes, valve-state enums).
4. No new storage field on FastSense (Lines struct array handles it).

### Concrete implementation

Add one new public method + one private helper inside FastSense.m (total ~40 SLOC):

```matlab
function addTag(obj, tag, varargin)
    %ADDTAG Polymorphic dispatch — routes a Tag to the correct render path.
    %   fp.addTag(sensorTag)  — routes to addLine via tag.getXY
    %   fp.addTag(stateTag)   — routes to a staircase line
    %
    %   Dispatches by tag.getKind() — NO isa() subtype checks.
    %
    %   Error IDs:
    %     FastSense:invalidTag          — not a Tag object
    %     FastSense:unsupportedTagKind  — kind not handled
    %     FastSense:alreadyRendered     — render() already called
    if obj.IsRendered
        error('FastSense:alreadyRendered', ...
            'Cannot add tags after render() has been called.');
    end
    if ~isa(tag, 'Tag')
        error('FastSense:invalidTag', ...
            'addTag requires a Tag object, got %s.', class(tag));
    end
    switch tag.getKind()
        case 'sensor'
            [x, y] = tag.getXY();
            obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
        case 'state'
            obj.addStateTagAsStaircase_(tag, varargin{:});
        otherwise
            error('FastSense:unsupportedTagKind', ...
                'Unsupported tag kind ''%s''.', tag.getKind());
    end
end

function addStateTagAsStaircase_(obj, tag, varargin)
    %ADDSTATETAGASSTAIRCASE_ Render a StateTag as a stepped line.
    [x, y] = tag.getXY();
    if iscell(y)
        error('FastSense:unsupportedStateType', ...
            'StateTag with cellstr Y is not yet renderable (Phase 1005: numeric only).');
    end
    if isempty(x) || isempty(y)
        return;  % nothing to draw
    end
    % Build staircase: each (X(i) -> X(i+1)) holds Y(i), jump at X(i+1).
    % Interleave: xStep = [X(1), X(2), X(2), X(3), X(3), ...]
    %             yStep = [Y(1), Y(1), Y(2), Y(2), Y(3), ...]
    n = numel(x);
    xStep = zeros(1, 2*n - 1);
    yStep = zeros(1, 2*n - 1);
    xStep(1) = x(1);
    yStep(1) = y(1);
    for i = 2:n
        xStep(2*i - 2) = x(i);
        yStep(2*i - 2) = y(i-1);
        xStep(2*i - 1) = x(i);
        yStep(2*i - 1) = y(i);
    end
    obj.addLine(xStep, yStep, 'DisplayName', tag.Name, ...
        'AssumeSorted', true, varargin{:});
end
```

**Alternative — use existing private helper `toStepFunction`:**

`libs/SensorThreshold/private/toStepFunction.m` already converts `(segBounds, values, dataEnd)` to `(stepX, stepY)` for Sensor.resolve's threshold display. However, this is in SensorThreshold/private and NOT accessible from FastSense. Either:
- Inline the staircase logic as shown above (20 SLOC, self-contained — recommended), OR
- Move `toStepFunction.m` to a shared location like `libs/FastSense/private/` (edits a private-dir, minor Pitfall 5 concern but within budget).

**Recommendation: inline.** Keeps FastSense.m self-contained and the helper auditable.

### Open question for planner (LOW severity)

Does the user ever need cellstr-valued StateTag rendered? If YES in Phase 1005, route A needs an extension (map cellstr unique states to integer codes, render with tick-labels). Recommendation: **defer cellstr rendering to Phase 1006 or later**. The TAG-09 requirement says "feature-equivalent to StateChannel for data" — and `StateChannel.valueAt` handles cellstr for lookups, which StateTag.valueAt also supports. Rendering was never a StateChannel feature.

### Confidence: HIGH — grep-verified FastSense has no state-aware render code; staircase via addLine is the minimum viable visualization.

---

## Section 9 — Test Infrastructure

### Existing test conventions (from `tests/` directory)

- **Dual-style:** MATLAB unittest suite `tests/suite/Test*.m` + Octave flat `tests/test_*.m`.
- **Path bootstrap:** Each flat test has `add_*_path()` local function that calls `addpath(repo_root); install();`. Suite tests use `TestClassSetup.addPaths`.
- **Private-dir access:** `test_align_state.m` lines 44-68 show the Octave/MATLAB-R2025b workaround pattern (copy to temp, addpath temp) for private/ access. StateTag does NOT need this — `alignStateToTime` is used by StateTag internally, not by tests.
- **Test fixtures for load:** `test_sensor.m` does NOT test `Sensor.load()` — it tests state/threshold integration without file I/O. Phase 1005 SensorTag.load test will need a `.mat` fixture (either create a temp mat-file in the test setup via `save()`, or skip load() coverage in the Octave flat test and only cover it in the MATLAB unittest with proper setup/teardown).

### Benchmark conventions (from `benchmarks/` directory)

- Scripts (not functions) can be used (e.g., `benchmark.m`), but newer ones follow the `function benchmark_foo()` pattern (e.g., `benchmark_resolve.m`).
- Bootstrap: `addpath(fullfile(fileparts(mfilename('fullpath')), '..'));install();`.
- Output format: `fprintf` aligned tables with `%s\n', repmat('-', 1, N)` separators. See `benchmark_resolve.m` for the canonical format (line 35-37).
- CI: `benchmarks/` is NOT run automatically by `tests/run_all_tests.m`. Phase 1005's bench script should be runnable manually with `bench_sensortag_getxy()` — the Pitfall 9 ≤5% assertion is baked INTO the bench script via `assert()`, so CI can add a single line invoking it.

### Test files to ship

| File | Size est. | Covers |
|---|---|---|
| `tests/suite/TestSensorTag.m` | ~180 SLOC, ~16 tests | Constructor defaults + NV, getXY numeric+empty, valueAt (delegates via Y lookup at exact X), getTimeRange, getKind=='sensor', load with temp mat-file, toDisk/toMemory/isOnDisk round-trip, DataStore property exposure, toStruct/fromStruct round-trip, Tag contract: isa(tag, 'Tag') |
| `tests/suite/TestStateTag.m` | ~160 SLOC, ~14 tests | Constructor defaults + NV, empty-state error, valueAt scalar (before/at/between/after for numeric + cellstr), valueAt vector (numeric + cellstr), getXY passthrough, getTimeRange, getKind=='state', toStruct/fromStruct round-trip (numeric + cellstr), Labels/Criticality from Tag base |
| `tests/suite/TestFastSenseAddTag.m` | ~110 SLOC, ~8 tests | addTag(SensorTag) adds one line, addTag(StateTag) adds staircase line, addTag(mock kind 'mock') throws unsupportedTagKind, addTag(non-Tag) throws invalidTag, addTag after render throws alreadyRendered, mixed addSensor + addTag in same instance, grep-verification of no-`isa` pattern, polymorphic smoke test (one SensorTag + one StateTag + render → 2 lines in axes) |
| `tests/test_sensortag.m` | ~120 SLOC | Octave flat mirror of TestSensorTag |
| `tests/test_statetag.m` | ~100 SLOC | Octave flat mirror of TestStateTag |
| `tests/test_fastsense_addtag.m` | ~70 SLOC | Octave flat mirror of TestFastSenseAddTag |
| `benchmarks/bench_sensortag_getxy.m` | ~80 SLOC | Pitfall 9 gate — 100k-point getXY benchmark with `assert(overhead_pct <= 5.0)` |

### Pitfall-gate grep commands (to ship in a verification script or PLAN check)

```bash
# Pitfall 1 — no isa subtype dispatch in addTag
grep -c "isa(.*SensorTag\|isa(.*StateTag" libs/FastSense/FastSense.m
# expected: 0

# Pitfall 5 — legacy files byte-for-byte unchanged
git diff --stat HEAD -- libs/SensorThreshold/Sensor.m libs/SensorThreshold/StateChannel.m
# expected: no diff

# Pitfall 5 — addLine/addSensor/addBand unchanged in FastSense.m
# (the entire method bodies must remain byte-for-byte; a line-count check plus
# hash of each method body would be the cleanest enforcement)
```

### Confidence: HIGH — pattern fully follows Phase 1004 precedent.

---

## Runtime State Inventory

Phase 1005 is pure additive code. Not a rename/refactor/migration. No runtime state inventory required.

**Skip rationale:** CONTEXT.md specifies all NEW files (2 new production classes, 6 new test files, 1 new benchmark) plus ADDITIVE edits (2 existing files gain new methods/cases — no renames, no deletions, no schema changes). Nothing about the existing runtime (SQLite DataStore, live timers, stored test fixtures) is affected.

---

## Environment Availability

Phase 1005 has no new external dependencies. All needed components are in-repo and verified present:

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b+ | Primary runtime | Assumed (per CLAUDE.md) | R2020b+ | — |
| Octave 7+ | Secondary runtime | Assumed (per CLAUDE.md + Phase 1004 Octave 10/11 smoke notes) | 7+ | — |
| `Tag.m` | SensorTag, StateTag extend | ✓ | Phase 1004 | — |
| `TagRegistry.m` | instantiateByKind extension point | ✓ | Phase 1004 | — |
| `Sensor.m` | SensorTag delegate | ✓ | legacy | — |
| `StateChannel.m` | StateTag reference semantics | ✓ | legacy | — |
| `binary_search` / `binary_search_mex` | StateTag.valueAt ZOH | ✓ | MEX compiled | Pure-MATLAB fallback inside binary_search.m |
| `alignStateToTime` | Optional StateTag.valueAt vector path | ✓ | legacy helper | Inline loop |
| `FastSenseDataStore` | SensorTag.DataStore exposure | ✓ | legacy | — |
| `mksqlite` | DataStore disk backend (test_sensor_todisk only) | ✓ (bundled) | in-repo | Binary-file fallback |

**Missing dependencies with no fallback:** NONE

**Missing dependencies with fallback:** NONE — all mandatory components verified present.

---

## Common Pitfalls

### Pitfall 1: `isa(tag, 'SensorTag')` subtype checks inside addTag
**What goes wrong:** Future kind additions force edits to addTag's switch, violating OCP.
**Why it happens:** "Defensive" coding habit; MATLAB docs often show `isa` as the recommended test.
**How to avoid:** Use `tag.getKind()` string dispatch only. The one allowed `isa(tag, 'Tag')` is a contract guard, not a dispatch check.
**Warning signs:** CI grep `grep -c "isa(.*SensorTag\|isa(.*StateTag" libs/FastSense/FastSense.m` returning > 0.

### Pitfall 2: Accidentally rendering `isrow` on empty vectors
**What goes wrong:** `[]` passed to `addLine(x, y)` — `isrow([])` returns `false` on MATLAB but true on some Octave versions. `~isrow(x); x = x(:)'` flips empties into an incompatible shape.
**Why it happens:** StateTag with no data; SensorTag with pre-toDisk state where X is empty.
**How to avoid:** Early-return from `addStateTagAsStaircase_` when `isempty(x) || isempty(y)` (as shown in Section 8 helper).
**Warning signs:** `FastSense:sizeMismatch` on an empty StateTag.

### Pitfall 3: `SensorTag.load(matFile)` shadowing the MATLAB `load` builtin
**What goes wrong:** Inside SensorTag.load implementation, a naive `load(obj.Sensor_.MatFile)` call recurses infinitely.
**Why it happens:** Method name collision. Sensor.m solves this at line 153 with `builtin('load', obj.MatFile)`.
**How to avoid:** Delegate to `obj.Sensor_.load()` — the inner Sensor.load already uses `builtin`. SensorTag never calls `load()` directly.
**Warning signs:** Infinite recursion / stack overflow in the first `load` test.

### Pitfall 4: Labels cellstr collapse through struct()
**What goes wrong:** `s.labels = obj.Labels` with an empty cellstr `{}` collapses the entire struct() call to 0×0 when MATLAB is passed the empty-cell as a field value.
**Why it happens:** Native struct() behavior: empty cell fields with `{}` produce a 0×0 struct.
**How to avoid:** Wrap once: `s.labels = {obj.Labels}` (MockTag.m pattern line 55). Unwrap in fromStruct: `if iscell(s.labels) && numel(s.labels) == 1 && iscell(s.labels{1}), L = s.labels{1}; else, L = {}; end`.
**Warning signs:** Round-trip test fails with `Struct contents referenced with struct-element access but field is missing`.

### Pitfall 5: `SensorTag.toStruct` serializing megabyte-scale X/Y arrays into JSON
**What goes wrong:** A 10M-point SensorTag's `toStruct` emits `s.X = [...]` — JSON serialization then blows up to hundreds of MB.
**Why it happens:** Naive "serialize everything" mindset.
**How to avoid:** SensorTag.toStruct emits X/Y inline ONLY if `numel(X) ≤ some threshold` (e.g., 10k) AND `~isOnDisk()`. Above the threshold, toStruct emits `s.MatFile` and `s.KeyName` so the receiver can reload from disk. Matches CONTEXT.md intent ("SensorTag composes Sensor; delegates to its data storage").
**Warning signs:** `TestSensorTag.testFromStructRoundTrip` passing at N=100 but failing/slow at N=1M.

### Pitfall 6: CONTEXT.md says "edit Tag.m" but Plan 1004-02 moved `instantiateByKind` to TagRegistry.m
**What goes wrong:** Planner writes a task "edit Tag.m to add sensor/state cases" — the method doesn't exist on Tag.
**Why it happens:** CONTEXT.md was written before the 1004-02 architectural decision was finalized.
**How to avoid:** Plan uses TagRegistry.m as the edit target. Tag.m remains untouched in Phase 1005. See Section 6 above + Plan 1004-02 SUMMARY line 136 ("instantiateByKind lives on TagRegistry, not Tag base").
**Warning signs:** `No method 'instantiateByKind' in class 'Tag'` compile error.

### Pitfall 7: StateTag.valueAt on empty X fails silently
**What goes wrong:** `binary_search([], 5, 'right')` returns `idx=1` (the default); then `Y(1)` fails with out-of-bounds on an empty Y.
**Why it happens:** StateChannel has no empty-guard either; the bug is latent in legacy code.
**How to avoid:** StateTag adds an explicit empty-state guard in valueAt (per CONTEXT.md error ID `StateTag:emptyState`).
**Warning signs:** Cryptic `Index out of bounds` errors from user code that forgot to populate StateTag data.

### Pitfall 8: `Sensor_` delegate constructed before `Tag` superconstructor
**What goes wrong:** MATLAB requires `obj@Tag(key, ...)` to run BEFORE any `obj.` access. Setting `obj.Sensor_ = Sensor(key, ...)` before the super-call is a compile-time error on both runtimes.
**Why it happens:** Natural ordering "bottom-up" instinct.
**How to avoid:** Always `obj@Tag(key, tagArgs{:});` FIRST, then `obj.Sensor_ = Sensor(key, sensorArgs{:});`.
**Warning signs:** Error 'Parenthesized LHS references in constructors' or similar on first test.

### Pitfall 9: Benchmark shows inflated regression due to JIT warmup
**What goes wrong:** First tic/toc is dominated by JIT compilation; regression measured at 50% when reality is <1%.
**Why it happens:** Classic benchmarking hazard in MATLAB.
**How to avoid:** Run a warmup pass (10-100 iterations) before the measured loop. Benchmark_resolve.m does this implicitly via `nRuns=5` median. Use `median` not `mean` of multiple runs.
**Warning signs:** Test passes once then fails on CI rerun with vastly different percentages.

---

## Code Examples

Verified patterns from the actual codebase (not LLM-generated):

### ZOH scalar lookup (copy verbatim from StateChannel.m:114-121)

```matlab
function val = valueAt(obj, t)
    if isscalar(t)
        idx = obj.bsearchRight(t);
        if iscell(obj.Y)
            val = obj.Y{idx};
        else
            val = obj.Y(idx);
        end
    else
        n = numel(t);
        if iscell(obj.Y)
            val = cell(1, n);
            for k = 1:n
                idx = obj.bsearchRight(t(k));
                val{k} = obj.Y{idx};
            end
        else
            val = zeros(1, n);
            for k = 1:n
                idx = obj.bsearchRight(t(k));
                val(k) = obj.Y(idx);
            end
        end
    end
end

function idx = bsearchRight(obj, val)
    idx = binary_search(obj.X, val, 'right');
end
```

Source: `libs/SensorThreshold/StateChannel.m:94-160` (exact lines).

### Sensor constructor name-value loop (Sensor.m:117-129)

```matlab
for i = 1:2:numel(varargin)
    switch varargin{i}
        case 'Name',     obj.Name = varargin{i+1};
        case 'ID',       obj.ID = varargin{i+1};
        case 'Source',   obj.Source = varargin{i+1};
        case 'MatFile',  obj.MatFile = varargin{i+1};
        case 'KeyName',  obj.KeyName = varargin{i+1};
        case 'Units',    obj.Units = varargin{i+1};
        otherwise
            error('Sensor:unknownOption', ...
                'Unknown option ''%s''.', varargin{i});
    end
end
```

Source: `libs/SensorThreshold/Sensor.m:117-129`.

### Tag constructor name-value loop (Tag.m:85-98)

```matlab
for i = 1:2:numel(varargin)
    switch varargin{i}
        case 'Name',        obj.Name        = varargin{i+1};
        case 'Units',       obj.Units       = varargin{i+1};
        case 'Description', obj.Description = varargin{i+1};
        case 'Labels',      obj.Labels      = varargin{i+1};
        case 'Metadata',    obj.Metadata    = varargin{i+1};
        case 'Criticality', obj.Criticality = varargin{i+1};
        case 'SourceRef',   obj.SourceRef   = varargin{i+1};
        otherwise
            error('Tag:unknownOption', ...
                'Unknown option ''%s''.', varargin{i});
    end
end
```

Source: `libs/SensorThreshold/Tag.m:85-98`. SensorTag.m's `splitArgs_` helper mirrors this idiom.

### addSensor disk-aware line addition (FastSense.m:561-567) — the template for addTag's sensor case

```matlab
if ~isempty(sensor.DataStore)
    % Sensor is disk-backed — pass DataStore directly
    obj.addLine([], [], 'DisplayName', displayName, ...
        'DataStore', sensor.DataStore);
else
    obj.addLine(sensor.X, sensor.Y, 'DisplayName', displayName);
end
```

Source: `libs/FastSense/FastSense.m:561-567`. `addTag` sensor case mirrors this with `tag.Sensor_.DataStore` + `tag.getXY()`.

### MockTag fromStruct with labels unwrap (MockTag.m:62-89)

```matlab
function obj = fromStruct(s)
    labels = {};
    if isfield(s, 'labels') && ~isempty(s.labels)
        L = s.labels;
        if iscell(L) && numel(L) == 1 && iscell(L{1})
            L = L{1};  % unwrap the struct() wrap
        end
        if iscell(L)
            labels = L;
        end
    end
    metadata = struct();
    if isfield(s, 'metadata') && isstruct(s.metadata)
        metadata = s.metadata;
    end
    criticality = 'medium';
    if isfield(s, 'criticality') && ~isempty(s.criticality)
        criticality = s.criticality;
    end
    name = s.key;
    if isfield(s, 'name') && ~isempty(s.name)
        name = s.name;
    end
    obj = MockTag(s.key, 'Name', name, 'Labels', labels, ...
        'Metadata', metadata, 'Criticality', criticality);
end
```

Source: `tests/suite/MockTag.m:62-89`. SensorTag.fromStruct and StateTag.fromStruct mirror this structure.

### Copy-on-write verification (instrumental)

```matlab
x = linspace(0, 100, 100000000);  % 800 MB
s = Sensor('big', 'X', x, 'Y', x);  % Note: we can skip assignment to avoid doubling memory
st = SensorTag('big'); st.Sensor_.X = s.X; st.Sensor_.Y = s.Y;  % shared
[xr, yr] = st.getXY();  % still shared — reference copies
% Memory before write: ~1.6 GB (two × 800 MB)
% (If we had copied, it'd be ~3.2 GB and likely OOM on 16 GB RAM.)
yr(1) = 99;  % NOW MATLAB materializes a fresh yr; st.Sensor_.Y remains intact.
```

(Optional manual verification — not a CI test. Documents the copy-on-write invariant.)

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Pre-Phase-1004: Sensor + StateChannel as directly-referenced concrete types by widgets | Phase 1004-1011: Tag root + strangler-fig migration | 2026-04-16 (milestone v2.0) | Consumer code (widgets, FastSense.addSensor, EventDetection) will eventually consume Tag only — in Phase 1009 |
| Phase 1004 `instantiateByKind` on Tag | Phase 1004 final: `instantiateByKind` on TagRegistry | 2026-04-16 Plan 1004-02 | Architectural seam keeps Tag ignorant of its subclass catalog |
| Phase 1004: only `mock`/`mockthrowingresolve` kinds | Phase 1005: + `sensor`, `state` kinds | THIS PHASE | Round-trip works for production tag types |

**Deprecated/outdated:**
- `Sensor.ResolvedStateBands` struct property — written to empty in Sensor.resolve (Sensor.m line 559); NEVER consumed downstream. Legacy dead code, but DO NOT DELETE in Phase 1005 (byte-for-byte unchanged gate). Can be deleted in Phase 1011.

---

## Validation Architecture

> Nyquist validation is enabled (`workflow.nyquist_validation: true` implied — absent from config.json, defaults to enabled).

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB unittest (`matlab.unittest.TestCase`) + Octave flat-assert pattern |
| Config file | none — tests are discovered by `tests/run_all_tests.m` |
| Quick run command (per-test) | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestSensorTag')"` OR `octave --eval "install(); test_sensortag();"` |
| Full suite command | `matlab -batch "tests/run_all_tests()"` OR `octave --eval "tests/run_all_tests()"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| TAG-08 | SensorTag constructor with Tag + Sensor NV keys | unit | `matlab -batch "runtests('tests/suite/TestSensorTag')"` | ❌ Wave 0 |
| TAG-08 | SensorTag.getXY returns delegate arrays | unit | `TestSensorTag.testGetXYReturnsDelegate` | ❌ Wave 0 |
| TAG-08 | SensorTag.load delegates to inner Sensor | unit | `TestSensorTag.testLoadDelegates` | ❌ Wave 0 |
| TAG-08 | SensorTag.toDisk / toMemory / isOnDisk round-trip | unit | `TestSensorTag.testToDiskRoundTrip` | ❌ Wave 0 |
| TAG-08 | SensorTag.DataStore property reads inner Sensor | unit | `TestSensorTag.testDataStoreProperty` | ❌ Wave 0 |
| TAG-08 | SensorTag.toStruct/fromStruct round-trip | unit | `TestSensorTag.testRoundTrip` | ❌ Wave 0 |
| TAG-08 | SensorTag.getKind() == 'sensor' | unit | `TestSensorTag.testGetKind` | ❌ Wave 0 |
| TAG-09 | StateTag constructor + empty-state error | unit | `TestStateTag.testConstructor` | ❌ Wave 0 |
| TAG-09 | StateTag.valueAt scalar ZOH (numeric Y) — 7 cases | unit | `TestStateTag.testValueAtNumericScalar` | ❌ Wave 0 |
| TAG-09 | StateTag.valueAt scalar ZOH (cellstr Y) — 3 cases | unit | `TestStateTag.testValueAtStringScalar` | ❌ Wave 0 |
| TAG-09 | StateTag.valueAt vector ZOH — both Y types | unit | `TestStateTag.testValueAtVector` | ❌ Wave 0 |
| TAG-09 | StateTag.getKind() == 'state' | unit | `TestStateTag.testGetKind` | ❌ Wave 0 |
| TAG-09 | StateTag.toStruct/fromStruct round-trip (numeric + cellstr) | unit | `TestStateTag.testRoundTrip*` | ❌ Wave 0 |
| TAG-09 | StateTag.getTimeRange [min(X), max(X)] | unit | `TestStateTag.testGetTimeRange` | ❌ Wave 0 |
| TAG-10 | FastSense.addTag(SensorTag) → one line | integration | `TestFastSenseAddTag.testSensorTagRoute` | ❌ Wave 0 |
| TAG-10 | FastSense.addTag(StateTag) → one staircase line | integration | `TestFastSenseAddTag.testStateTagRoute` | ❌ Wave 0 |
| TAG-10 | FastSense.addTag(non-Tag) → invalidTag error | unit | `TestFastSenseAddTag.testInvalidTagErrors` | ❌ Wave 0 |
| TAG-10 | FastSense.addTag after render → alreadyRendered | unit | `TestFastSenseAddTag.testPostRenderErrors` | ❌ Wave 0 |
| TAG-10 | FastSense.addTag + FastSense.addSensor coexist | integration | `TestFastSenseAddTag.testCoexistWithAddSensor` | ❌ Wave 0 |
| TAG-10 | TagRegistry.loadFromStructs round-trips SensorTag | unit | extend `TestTagRegistry.testRoundTripSensorTag` | ❌ Wave 0 |
| TAG-10 | TagRegistry.loadFromStructs round-trips StateTag | unit | extend `TestTagRegistry.testRoundTripStateTag` | ❌ Wave 0 |
| **Pitfall 1 gate** | No isa(*SensorTag) or isa(*StateTag) inside FastSense.m | grep | `grep -c "isa(.*SensorTag\|isa(.*StateTag" libs/FastSense/FastSense.m` → 0 | runtime check |
| **Pitfall 5 gate** | Sensor.m, StateChannel.m unchanged | grep | `git diff --stat HEAD~N -- libs/SensorThreshold/Sensor.m libs/SensorThreshold/StateChannel.m` → empty | runtime check |
| **Pitfall 9 gate** | SensorTag.getXY ≤5% slower than Sensor.X/Y at 100k pts | benchmark | `octave --eval "bench_sensortag_getxy()"` — `assert(overhead_pct ≤ 5)` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `octave --eval "install(); test_sensortag(); test_statetag(); test_fastsense_addtag();"` (≤30 s total)
- **Per wave merge:** `octave --eval "install(); run_all_tests();"` + bench invocation (≤3 min)
- **Phase gate:** Full MATLAB + Octave suite green + `bench_sensortag_getxy` green + 3 pitfall greps green → `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestSensorTag.m` — covers TAG-08 (16 tests)
- [ ] `tests/suite/TestStateTag.m` — covers TAG-09 (14 tests)
- [ ] `tests/suite/TestFastSenseAddTag.m` — covers TAG-10 (8 tests)
- [ ] `tests/test_sensortag.m` — Octave flat mirror
- [ ] `tests/test_statetag.m` — Octave flat mirror
- [ ] `tests/test_fastsense_addtag.m` — Octave flat mirror
- [ ] `benchmarks/bench_sensortag_getxy.m` — Pitfall 9 gate
- [ ] Extend `tests/suite/TestTagRegistry.m` with 2 new round-trip tests for sensor + state kinds
- [ ] Extend `tests/test_tag_registry.m` with same 2 round-trip Octave assertions
- [ ] `.mat` fixture for SensorTag.load testing — generated on-the-fly via `save()` in TestMethodSetup; no committed fixture file

Framework is already installed (MATLAB unittest + Octave flat). No new install step.

---

## File-Touch Inventory

**Budget:** ≤15 files (CONTEXT.md + ROADMAP Phase 1005 verification gate)

| # | File | Operation | Est. SLOC | Notes |
|---|---|---|---|---|
| 1 | `libs/SensorThreshold/SensorTag.m` | NEW | ~180 | Composition wrapper; delegates to Sensor_ |
| 2 | `libs/SensorThreshold/StateTag.m` | NEW | ~160 | ZOH data carrier; valueAt copied verbatim from StateChannel |
| 3 | `libs/SensorThreshold/TagRegistry.m` | EDIT | +6 | Two new case branches in `instantiateByKind` + valid-kinds hint update |
| 4 | `libs/FastSense/FastSense.m` | EDIT | +40-60 | New public `addTag` method + private `addStateTagAsStaircase_` helper |
| 5 | `tests/suite/TestSensorTag.m` | NEW | ~180 | 16 unittest methods |
| 6 | `tests/suite/TestStateTag.m` | NEW | ~160 | 14 unittest methods |
| 7 | `tests/suite/TestFastSenseAddTag.m` | NEW | ~110 | 8 unittest methods + grep-gate test |
| 8 | `tests/test_sensortag.m` | NEW | ~120 | Octave flat mirror |
| 9 | `tests/test_statetag.m` | NEW | ~100 | Octave flat mirror |
| 10 | `tests/test_fastsense_addtag.m` | NEW | ~70 | Octave flat mirror |
| 11 | `benchmarks/bench_sensortag_getxy.m` | NEW | ~80 | Pitfall 9 gate |
| 12 | `tests/suite/TestTagRegistry.m` | EDIT | +30 | 2 new round-trip tests (sensor + state) |
| 13 | `tests/test_tag_registry.m` | EDIT | +20 | 2 new Octave round-trip assertions |

**Total: 13 files / 15 budget (87% usage, 13% margin).** Legacy files explicitly NOT touched:

- `libs/SensorThreshold/Sensor.m` — byte-for-byte unchanged (hard gate)
- `libs/SensorThreshold/StateChannel.m` — byte-for-byte unchanged (hard gate)
- `libs/SensorThreshold/Tag.m` — byte-for-byte unchanged (edit target was misstated in CONTEXT.md; correct target is TagRegistry.m — see Section 6)
- `libs/SensorThreshold/Threshold.m`, `CompositeThreshold.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`, `ThresholdRule.m` — all unchanged
- All existing `libs/SensorThreshold/private/*.m` — unchanged
- `FastSense.m` methods `addLine`, `addSensor`, `addBand`, `addThreshold`, `addShaded`, `addFill`, `addMarker`, `render`, `updateData` — method bodies byte-for-byte unchanged (new `addTag` method is purely additive at end of public methods block)

**Legacy-path grep verification commands** (for plan's verification task):

```bash
# Gate 1 — no edits to Sensor.m or StateChannel.m
git diff --stat HEAD~N -- libs/SensorThreshold/Sensor.m libs/SensorThreshold/StateChannel.m
# expected: empty

# Gate 2 — no edits to 8 legacy SensorThreshold classes or Tag.m
git diff --stat HEAD~N -- libs/SensorThreshold/Sensor.m libs/SensorThreshold/StateChannel.m libs/SensorThreshold/Threshold.m libs/SensorThreshold/CompositeThreshold.m libs/SensorThreshold/SensorRegistry.m libs/SensorThreshold/ThresholdRegistry.m libs/SensorThreshold/ExternalSensorRegistry.m libs/SensorThreshold/ThresholdRule.m libs/SensorThreshold/Tag.m
# expected: empty

# Gate 3 — no isa subtype dispatch in addTag
grep -c "isa(.*SensorTag\|isa(.*StateTag" libs/FastSense/FastSense.m
# expected: 0

# Gate 4 — addLine / addSensor / addBand method bodies unchanged
# (Implementation: hash the method body before and after; or grep for a unique
# phrase in each method and verify line count / content unchanged)
```

---

## Open Questions for Planner

### Q1 (LOW): CONTEXT.md error-path signature mismatch for `SensorTag.toDisk(store)`
**What:** CONTEXT.md §SensorTag Implementation lists `toDisk(store)` — legacy `Sensor.toDisk()` takes NO argument.
**Resolution:** Recommend planner adopt legacy 0-arg signature (`SensorTag.toDisk()`) for feature-equivalence. Remove `store` parameter from plan. If user specifically wants pre-built DataStore injection, that's a separate feature not required by TAG-08.

### Q2 (LOW): CONTEXT.md error-path signature mismatch for `SensorTag.load(matFile)`
**What:** CONTEXT.md lists `load(matFile)` accepting matFile; legacy `Sensor.load()` takes no arg, reads `obj.MatFile`.
**Resolution:** Recommend planner adopt the enriched signature — `SensorTag.load(matFile)` sets `obj.Sensor_.MatFile = matFile` first (if provided), then calls `obj.Sensor_.load()`. Backward compat: `load()` with no arg reads whatever MatFile was set at construction. Both paths work.

### Q3 (LOW): StateTag cellstr Y rendering
**What:** Section 8 recommendation routes StateTag to a staircase line via addLine, which requires numeric Y. Cellstr StateTag will error at render.
**Resolution:** Accept numeric-only rendering for Phase 1005. Document in the StateTag.m header. Add a TODO for future phases. CONTEXT.md does not require cellstr rendering (TAG-09 is about data + valueAt, not rendering).

### Q4 (RESOLVED — no action needed): CONTEXT.md says edit Tag.m for instantiateByKind
**What:** See Section 6. CONTEXT.md text was drafted before Plan 1004-02 moved `instantiateByKind` to TagRegistry.
**Resolution:** Plan's file-touch list uses TagRegistry.m. Tag.m stays at exactly 157 lines, byte-for-byte.

---

## Sources

### Primary (HIGH confidence)
- `libs/SensorThreshold/Tag.m` (Phase 1004) — Tag base contract, 6 abstracts, Criticality enum, constructor NV loop
- `libs/SensorThreshold/TagRegistry.m` (Phase 1004) — singleton catalog, instantiateByKind dispatch (edit target)
- `libs/SensorThreshold/Sensor.m` (legacy) — full public API inventory (Section 1)
- `libs/SensorThreshold/StateChannel.m` (legacy) — ZOH valueAt semantics (Section 2)
- `libs/SensorThreshold/private/alignStateToTime.m` (legacy helper) — vector ZOH reference
- `libs/FastSense/FastSense.m:335-744` — addLine/addSensor/addThreshold/addBand signatures and state machine
- `libs/FastSense/FastSense.m:943-1090` — render-path structure for state-machine verification
- `libs/FastSense/binary_search.m` — MEX-backed O(log N) search used by StateTag
- `libs/FastSense/FastSenseDataStore.m:1-40` — DataStore public API (reused transparently via delegate)
- `tests/suite/MockTag.m` — toStruct/fromStruct pattern with labels wrapping (Section 7)
- `tests/test_state_channel.m` — 4 ZOH regression assertions (Section 2)
- `tests/test_sensor.m`, `tests/test_add_sensor.m`, `tests/test_sensor_todisk.m` — reference patterns for test coverage
- `tests/test_golden_integration.m` — Phase 1004 untouchable regression guard (must still pass)
- `benchmarks/benchmark_resolve.m` — benchmark scaffolding template
- `.planning/phases/1004-tag-foundation-golden-test/1004-01-SUMMARY.md` — throw-from-base pattern, MockTag design
- `.planning/phases/1004-tag-foundation-golden-test/1004-02-SUMMARY.md` — instantiateByKind location decision (key Section 6 input)
- `.planning/ROADMAP.md §Phase 1005` — success criteria + verification gates
- `.planning/REQUIREMENTS.md` — TAG-08, TAG-09, TAG-10 definitions
- `.planning/codebase/CONVENTIONS.md` — naming patterns, error IDs, private dirs
- `.planning/codebase/ARCHITECTURE.md` — layer separation
- `CLAUDE.md` — project constraints (Octave parity, no external deps, 160-char line limit)

### Secondary (MEDIUM confidence)
- MATLAB copy-on-write behavior — widely documented but not verified against R2025b in this research pass (assumption: holds as in R2020b-R2024b)

### Tertiary (LOW confidence)
- None — all findings backed by local code verification.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — every component directly verified in repo
- Architecture (composition pattern, delegate, dispatch): HIGH — pattern directly mirrors DetachedMirror (Phase 05) and Phase 1003 CompositeThreshold
- Pitfalls: HIGH — 1, 4, 6 directly verified against Phase 1004 summaries; others inferred from idiomatic MATLAB
- FastSense band/state mismatch: HIGH — grep-verified zero StateChannel references in FastSense

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (stable — Phase 1004 Tag contract locked; legacy Sensor/StateChannel frozen through Phase 1011)

---

## RESEARCH COMPLETE
