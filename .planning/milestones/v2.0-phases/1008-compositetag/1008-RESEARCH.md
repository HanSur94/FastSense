# Phase 1008: CompositeTag - Research

**Researched:** 2026-04-16
**Domain:** MATLAB/Octave handle-class aggregation with streaming merge-sort over multiple child time series
**Confidence:** HIGH

## Summary

Phase 1008 adds `CompositeTag < Tag` — a derived-signal Tag that aggregates 1..N MonitorTag/CompositeTag children into a single 0/1 (or 0..1 severity) time series via **k-way merge-sort ZOH streaming** (not N×M union-then-interp1). The phase is a template-extension of the Phase 1006 MonitorTag pattern: same two-phase (`fromStruct` + `resolveRefs`) deserialization, same `listeners_ + addListener + notifyListeners_ + invalidate` cascade, same 4-line switch-case extensions to `FastSense.addTag` and `TagRegistry.instantiateByKind`.

Seven requirements (COMPOSITE-01..07) map cleanly to: one new class (~280 SLOC), two 1-4 line edits to existing files, and seven test/bench artifacts (target 8 files total). The critical algorithmic risk (Pitfall 3 memory blowup) is addressed by the merge-sort streaming pattern documented in Section 5; the critical semantics risk (Pitfall 6 drift) is addressed by **enforcing binary (0/1/NaN) child output at `addChild` time** via `isa(child, 'MonitorTag' | 'CompositeTag')` — SensorTag/StateTag are rejected because they have no inherent ok/alarm semantics.

**Primary recommendation:** Copy the MonitorTag Phase 1006 template verbatim for class-skeleton shape (listener hook, ParentKey_/resolveRefs Pass-2, getKind, toStruct). Implement merge-sort as a private helper over a "pointer array" of size N (one index per child) — no full-union materialization anywhere. Use Key-equality for cycle detection (Octave `==`/`isequal` on handles with listener cycles crash — see finding in Section 7).

## User Constraints (from CONTEXT.md)

### Locked Decisions

**File Organization** (8 files total — at Pitfall 5 budget cap, zero margin):
- NEW: `libs/SensorThreshold/CompositeTag.m` (~280 SLOC)
- EDIT: `libs/SensorThreshold/TagRegistry.m` — `'composite'` case in `instantiateByKind`
- EDIT: `libs/FastSense/FastSense.m` — `'composite'` case in `addTag` switch
- NEW: `tests/suite/TestCompositeTag.m` (aggregation modes + truth tables + cycle detection + child-type guards)
- NEW: `tests/suite/TestCompositeTagAlign.m` (merge-sort + pre-history drop + NaN truth tables)
- NEW: `tests/test_compositetag.m` (Octave flat-style)
- NEW: `tests/test_compositetag_align.m` (Octave)
- NEW: `benchmarks/bench_compositetag_merge.m` (Pitfall 3 gate)

**Scope boundaries:**
- AggregateMode enum: `'and' | 'or' | 'majority' | 'count' | 'worst' | 'severity' | 'user_fn'` (exactly 7)
- `addChild(tagOrKey, varargin)` accepts Tag handle OR string key (via TagRegistry); optional `'Weight'` NV for SEVERITY mode
- Cycle detection on `addChild` (self-reference AND deeper A→B→A) via DFS with error `CompositeTag:cycleDetected`
- Children MUST be MonitorTag or CompositeTag — SensorTag/StateTag rejected (`CompositeTag:invalidChildType`)
- `getXY()` uses merge-sort streaming; NOT `union(X_i)` + per-child `interp1`
- `valueAt(t)` is the fast path for current-state widgets (no full-series materialization)
- ZOH-only alignment (ALIGN-01); drop pre-history grid points (ALIGN-03)
- Document truth tables for each mode × {0, 1, NaN} in the class header (Pitfall 6)

**Error IDs (locked):** `CompositeTag:cycleDetected`, `CompositeTag:invalidChildType`, `CompositeTag:invalidAggregateMode`, `CompositeTag:userFnRequired`, `CompositeTag:unknownOption`

**Verification gates (locked from ROADMAP):**
- Pitfall 3: Bench 8 × 100k children → peak RAM <50MB, compute <200ms
- Pitfall 6: Truth tables in class header; MAJORITY rejects multi-state at `addChild` (binary 0/1 only for v2.0)
- Pitfall 8: 3-deep composite-of-composite-of-composite round-trip GREEN
- ALIGN-04: AND-with-NaN → NaN, OR-with-NaN → other operand, MAX/WORST-with-NaN → ignore, COUNT ignores NaN

### Claude's Discretion

- Exact SLOC per private helper (keep CompositeTag.m near 280)
- Whether aggregation mode helpers live in `libs/SensorThreshold/private/` (recommendation: keep inside `CompositeTag.m` as private methods — matches MonitorTag's `applyHysteresis_/applyDebounce_/findRuns_` pattern; avoids cross-library private access limitations)
- Bench memory measurement methodology (see Section 3 — `memory()` is MATLAB-only; `/proc/self/status` is Linux-only; recommend output-size proxy as Octave-portable fallback)
- Weight semantics for non-SEVERITY modes — recommendation: store but ignore (default 1.0), documented in class header; no validation error for accidental Weight on AND/OR (keeps API forgiving)

### Deferred Ideas (OUT OF SCOPE)

- Per-child threshold override on CompositeTag (user: no preference; defer)
- Alignment caching keyed on `(children, window)` — premature optimization
- Multi-state MAJORITY (binary 0/1 only for v2.0)
- Consumer migration (Phase 1009 owns FastSenseWidget / StatusWidget / GaugeWidget wiring)
- Event binding rewrite (Phase 1010)
- Legacy CompositeThreshold deletion (Phase 1011)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| COMPOSITE-01 | CompositeTag extends Tag, recursively composable | Section 2 class-skeleton mirrors MonitorTag; `isa(composite, 'Tag')` true by inheritance |
| COMPOSITE-02 | 7 aggregation modes (and/or/majority/count/worst/severity/user_fn) | Section 4 truth-tables; Section 6 aggregator function reference |
| COMPOSITE-03 | addChild accepts Tag handle or string key; optional Weight for SEVERITY | Section 2 signature mirrors legacy CompositeThreshold.addChild; TagRegistry.get dispatch proven pattern |
| COMPOSITE-04 | Cycle detection on addChild: self AND deeper A→B→A; DFS | Section 7 — Key-equality DFS algorithm (Octave handle-compare SIGILL avoidance) |
| COMPOSITE-05 | merge-sort streaming getXY; NO N×M union+interp1 | Section 5 k-way merge algorithm with pointer array |
| COMPOSITE-06 | valueAt(t) fast-path — no full-series materialization | Section 8 — delegates to `child.valueAt(t)` + aggregator; MonitorTag.valueAt already ZOH binary_search |
| COMPOSITE-07 | Children MUST be MonitorTag or CompositeTag | Section 2 — `isa(child, 'MonitorTag') \|\| isa(child, 'CompositeTag')` guard at addChild |
| ALIGN-01 | ZOH only | Section 5 merge-sort uses last-known Y per child (no `interp1` anywhere) |
| ALIGN-02 | Union-of-timestamps grid | Section 5 merge-sort visits every unique child-X timestamp |
| ALIGN-03 | Drop pre-history grid points | Section 5 — skip emission until current_x >= max(child.X(1)) |
| ALIGN-04 | NaN handling per IEEE 754 | Section 4 truth tables codify AND/OR/WORST/COUNT NaN semantics |

## Project Constraints (from CLAUDE.md)

- **Tech stack:** Pure MATLAB (no external deps). CompositeTag.m is pure-MATLAB; no new MEX kernels.
- **Octave portability:** Must run on GNU Octave 7+ (currently 11.1.0 on dev machine). Forbidden stack: `dictionary`, `enumeration` blocks, `events`/listeners blocks, `matlab.mixin.*`, `arguments` blocks.
- **Classes inherit from handle:** `classdef CompositeTag < Tag` (Tag already `< handle`).
- **Error IDs:** `ClassName:camelCaseProblem` pattern — all 5 locked IDs comply.
- **Cyclomatic complexity:** Limit 80 (aspirational 20). Merge-sort streaming needs one loop with mode-switch — keep aggregator helper separate to stay under limit.
- **Line length:** 160 chars max. 4-space indent.
- **Test discovery:** Suite tests need `TestClassSetup/addPaths` calling `install()`. Flat tests use `test_*` prefix + snake_case.
- **No external MATLAB toolboxes.** Everything built-in.
- **Backward compatibility:** Existing dashboard scripts must keep working. CompositeTag is purely additive — no legacy edits in Phase 1008 (strangler-fig discipline MIGRATE-02).
- **Performance:** Phase 1007 benchmark showed MonitorTag is 3.3× FASTER than legacy Sensor.resolve; CompositeTag overhead budget is `<200ms` for 8 × 100k workload per Pitfall 3 gate.

## Standard Stack

### Core (all pre-existing — no new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Tag base class | Phase 1004 | Abstract-by-convention root; properties Key, Name, Labels, Metadata, Criticality | Two-phase loadFromStructs contract already wired for recursive children |
| MonitorTag | Phase 1006/1007 | Child type #1 — ZOH 0/1 series, listener pattern, invalidate() cascade | `addListener`, `notifyListeners_`, `invalidate` already implemented; composite reuses verbatim |
| TagRegistry | Phase 1004 | Singleton registry with two-phase deserialization (Pitfall 8 proven) | `loadFromStructs` Pass-2 calls `resolveRefs(registry)`; CompositeTag.resolveRefs wires child handles by key |
| `binary_search` (pure-MATLAB + MEX) | Phase 0 | ZOH lookup in `valueAt` | `libs/FastSense/binary_search.m` with MEX fast path; `'right'` direction = ZOH |
| MockTag | Phase 1004 | Test fixture for lightweight Tag stubs | Used in MonitorTag round-trip tests; reusable for CompositeTag round-trip |

### Supporting — none needed

No new libraries. CompositeTag is pure composition over existing Tag infrastructure.

### Alternatives Considered

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| Hand-written k-way merge | `union(X1,...,Xn)` + per-child `interp1` | **REJECTED** — Pitfall 3 memory blowup. 8 × 100k → 800k unique; 8 `interp1` calls each alloc 800k → 6.4M floats = ~50MB spike already at the cap. Merge-sort keeps O(N + M_unique) where M_unique is the output. |
| `containers.Map` for pointer tracking | Simple array `cursor(1:N)` | **REJECTED** — overkill; N ≤ 8 typical. Array access is O(1) and Octave-portable. |
| `matlab.mixin.Heterogeneous` cell of children | Plain cell array `children_{i} = struct('tag', ..., 'weight', ...)` | **REJECTED** — Octave mixin support patchy; struct-wrap is the MonitorTag/CompositeThreshold precedent. |
| Event-backed invalidation (`events`/listeners blocks) | `listeners_` cell + `addListener` method + `notifyListeners_` private | **REJECTED** — `events` blocks are parsed-no-op on Octave; the plain-cell observer pattern is the Phase 1006 proven choice. |
| New MEX kernel for aggregation | Vectorized MATLAB ops (`all`, `any`, `sum`, `max`) | **REJECTED** — sub-millisecond at typical N; REQUIREMENTS.md §"Stack additions explicitly forbidden" bans new MEX for aggregation. |

**Installation:** None required. No new packages. CompositeTag.m lives in `libs/SensorThreshold/` and is discovered by `install()` via existing `addpath(fullfile(repo,'libs','SensorThreshold'))`.

**Version verification:** No external packages. Octave 11.1.0 verified on dev machine; R2020b+ per project stack requirements.

## Architecture Patterns

### Recommended Project Structure

```
libs/SensorThreshold/
├── Tag.m                    # EXISTING — parent abstract base
├── TagRegistry.m            # EDIT +3 lines — add 'composite' case to instantiateByKind
├── SensorTag.m              # UNCHANGED — rejected as child type
├── StateTag.m               # UNCHANGED — rejected as child type
├── MonitorTag.m             # UNCHANGED — valid child type (addListener reused)
├── CompositeTag.m           # NEW — this phase
└── private/                 # EXISTING — no new private helpers needed

libs/FastSense/
└── FastSense.m              # EDIT +4 lines — add 'composite' case to addTag switch

tests/
├── suite/
│   ├── TestCompositeTag.m       # NEW — constructor/modes/addChild/cycle/serialization
│   └── TestCompositeTagAlign.m  # NEW — merge-sort/pre-history/NaN truth tables
├── test_compositetag.m          # NEW — Octave flat mirror
└── test_compositetag_align.m    # NEW — Octave flat mirror

benchmarks/
└── bench_compositetag_merge.m   # NEW — Pitfall 3 memory + timing gate
```

### Pattern 1: Template-Extension of MonitorTag for New Tag Kinds

**What:** Adding a new Tag kind is a ~4-line edit to two switch statements plus a new classdef. Proven twice already (SensorTag → StateTag → MonitorTag each added 4 lines to the two dispatch sites).

**When to use:** For Phase 1008 `composite` kind. Copy this template:

```matlab
% Source: libs/FastSense/FastSense.m (existing addTag for 'sensor'/'state'/'monitor')
% EDIT — add before `otherwise`:
case 'composite'
    [x, y] = tag.getXY();
    obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
```

```matlab
% Source: libs/SensorThreshold/TagRegistry.m instantiateByKind (around line 343)
% EDIT — add before `otherwise`, update error literal:
case 'composite'
    tag = CompositeTag.fromStruct(s);
otherwise
    error('TagRegistry:unknownKind', ...
        'Unknown tag kind ''%s''. Valid kinds (Phase 1008): mock, sensor, state, monitor, composite.', ...
        kind);
```

### Pattern 2: Two-Phase Deserialization (resolveRefs)

**What:** `fromStruct` constructs with placeholder children (empty cell + stashed key list); `resolveRefs(registry)` wires real handles in Pass 2 of `TagRegistry.loadFromStructs`.

**When to use:** MANDATORY for CompositeTag (any Tag that references other Tags by key). MonitorTag does this exact dance for its single `ParentKey_`; CompositeTag does it for a cell of child keys + parallel cell of weights.

**Example (MonitorTag — reference pattern, lines 268-291 of MonitorTag.m):**

```matlab
function resolveRefs(obj, registry)
    if isempty(obj.ParentKey_), return; end
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
```

**For CompositeTag:** loop over `obj.ChildKeys_` (stashed by fromStruct), resolve each via `registry(key)`, then call `obj.addChild(handle, 'Weight', weight)` so the normal addChild validation + cycle detection + listener-hookup path runs.

### Pattern 3: Observer Chain for Invalidation Cascade

**What:** Parent Tag holds `listeners_` cell; children register via `parent.addListener(child)`; parent calls `notifyListeners_()` from `updateData` / `invalidate`.

**When to use:** CompositeTag MUST register as a listener on every child at `addChild` time so that when any MonitorTag child invalidates (e.g., its parent SensorTag updates), the composite's cache invalidates too.

**Scalability:** Tested recursively in Phase 1006 Plan 01 — a MonitorTag can listen to another MonitorTag which listens to a SensorTag. The cascade walks through `notifyListeners_` → each listener's `invalidate()` → which may itself call `notifyListeners_()`. O(N) depth for N-deep chain; no stack overflow risk at v2.0 depths (3-deep round-trip is the explicit gate).

**CompositeTag wiring (inside `addChild`):**
```matlab
if ismethod(tag, 'addListener')
    tag.addListener(obj);  % child's invalidate() cascades up to composite
end
```

### Pattern 4: Throw-From-Base Abstract Contract

**What:** Tag base class provides stub methods that raise `Tag:notImplemented` (not `methods (Abstract)` block — parsed-no-op on Octave).

**When to use:** All Tag subclasses including CompositeTag override `getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`; static `fromStruct` also overridden.

### Anti-Patterns to Avoid

- **`union(X_1, X_2, ..., X_N)` followed by per-child `interp1`** — Pitfall 3 memory blowup. 8 × 100k → 50MB+ peak. Use merge-sort instead.
- **`interp1(x, y, xq, 'linear')` anywhere in aggregation code** — ALIGN-01 forbids linear interpolation. ZOH only. Grep gate: `interp1.*'linear'` must return 0 in CompositeTag.m.
- **`isequal(handleA, handleB)` on handles with listener cycles** — causes SIGILL on Octave (documented in Phase 1006 Plan 01 deviation #3, re-confirmed in Phase 1006 Plan 03 round-trip test). Use Key equality (`strcmp(a.Key, b.Key)`) instead.
- **`methods (Abstract)` block** — parsed-no-op on Octave. Use throw-from-base.
- **Cycle detection at `getXY`** — violates Pitfall 6 semantics timing. MUST run at `addChild` so the error surface is rejecting a bad structure, not a bad query.
- **Per-sample callbacks (`OnSample`, `OnEachSample`, `PerSample`)** — MONITOR-10 anti-pattern inherited; CompositeTag has the same rule. Only event-level (`OnEventStart`/`OnEventEnd`) callbacks if any (v2.0 CompositeTag has none per CONTEXT).
- **Eager full-history materialization on construction** — MONITOR-03 pattern. Lazy-memoize: compute on first `getXY`, cache via `dirty_` flag, invalidate on child change.
- **`events`/listeners blocks, `matlab.mixin.*`, `arguments` blocks, `enumeration` blocks** — forbidden in REQUIREMENTS.md §"Stack additions explicitly forbidden".
- **New MEX kernel for aggregation** — explicitly forbidden in REQUIREMENTS.md.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-child timestamp alignment | Custom union+sort+interp loop | **k-way merge-sort** (Section 5 reference algorithm) | Keeps peak memory O(N + M_unique) not O(N × M); Pitfall 3 gate. |
| Binary search for ZOH lookup | Custom `find(x <= t)` loops | `binary_search(x, t, 'right')` from `libs/FastSense/` | MEX-accelerated; project-standard; MonitorTag.valueAt uses the same pattern (line 226). |
| Two-phase deserialization wiring | Custom save/load order-tracking | `TagRegistry.loadFromStructs` + `resolveRefs` override | Phase 1004 proven order-insensitive; Pitfall 8 gate. 3-deep round-trip test established in TagRegistry tests. |
| Observer pattern for cascade invalidation | Custom callback lists | `listeners_` cell + `addListener(m)` + `notifyListeners_()` | Phase 1006 proven (SensorTag, StateTag, MonitorTag all use identical shape). Strong refs — caller manages lifecycle. |
| Cycle detection on handle graph | Handle equality (`==`, `isequal`) | **Key-equality DFS** (Section 7) | Octave SIGILL on handle-compare with listener cycles — documented in Plan 01 deviation #3 of Phase 1006. |
| Memory measurement in benchmark | Portable `memory()` call | **Output-size proxy** + `/proc/self/status` when available (see Section 3) | `memory()` is MATLAB-only; Octave 11.1.0 on macOS/Linux lacks it. |
| Aggregation helpers across library | Cross-library `private/` helpers | **Private methods inside CompositeTag.m** | MATLAB `private/` dirs scoped per-library; cross-library private access patterns break. MonitorTag inlined `findRuns_` (line 565) from EventDetection/private for this exact reason. |
| Table-driven mode × input matrix tests | Bespoke per-mode test functions | **Single table literal + loop** (Section 4 pattern) | Compactly covers 7 modes × 3 input values × {single, multi-child} = ~42 cases in ~30 lines. |

**Key insight:** Every problem CompositeTag faces has a proven solution in the codebase from Phases 1004-1007. The class is a mechanical composition of those proven parts; novel work is confined to (a) the merge-sort streaming algorithm and (b) the DFS cycle detector.

## Runtime State Inventory

Not applicable — Phase 1008 is a pure-code additive phase. No rename/refactor/migration; no stored data, no live services, no OS registrations, no secrets, no installed package names change. **None — verified by reading CONTEXT.md §File Organization (all 8 files are new or pure additions to existing files).**

## Common Pitfalls

### Pitfall 1: N×M Memory Blowup (the Pitfall 3 gate in REQUIREMENTS)

**What goes wrong:** Naive implementation does `X_union = unique([X_1, X_2, ..., X_N])` followed by `for i=1:N: Y_i_aligned = interp1(X_i, Y_i, X_union, 'previous')`. This allocates N × M_unique doubles. At 8 children × 100k points with random jitter → M_unique ≈ 800k → 8 × 800k × 8 bytes = 51.2 MB peak just for the aligned matrix.

**Why it happens:** Intuitive translation of "evaluate at every timestamp" straight to dense matrix form.

**How to avoid:** Use **k-way merge-sort with pointer array** (Section 5). Peak memory is O(N) pointers + O(M_unique) output. No dense N × M matrix ever exists.

**Warning signs:**
- Any `union` call on child X arrays
- Any `interp1` call in aggregation code (ALIGN-01 also forbids this independently)
- Benchmark shows memory spike proportional to `numChildren × totalSamples` rather than `numChildren + totalSamples`

**Verification:** `bench_compositetag_merge.m` asserts peak <50MB AND compute <200ms at 8×100k. Output-size proxy check: `numel(composite.getXY.X) <= sum(child_sample_counts) + small_slack` guards against silent N×M materialization.

### Pitfall 2: Semantics Drift Between AggregateMode and Binary Output Contract (the Pitfall 6 gate)

**What goes wrong:** MAJORITY mode silently accepts a child producing a value like 0.5 (intermediate severity) and threshold-compares at 0.5 instead of rejecting multi-state at addChild time. User wrote `addChild(severityMonitor)` expecting majority-voting but got threshold-crossing behavior.

**Why it happens:** Late validation — checking child output shape at `getXY` rather than at `addChild`.

**How to avoid:** **Gate at addChild time.** Require `isa(tag, 'MonitorTag') || isa(tag, 'CompositeTag')` — no SensorTag (raw continuous data), no StateTag (multi-state discrete). Error `CompositeTag:invalidChildType` surfaces immediately when the user writes `addChild(sensorTag)`.

**Warning signs:**
- MAJORITY produces fractional output (should always be {0, 1, NaN})
- A test input with Y ∈ {0, 0.5, 1} slipping through

**Verification:** Test table covers 7 modes × {0, 1, NaN} × {single-child, 3-child, 5-child} combinations. Every row asserts output ∈ {0, 1, NaN} for non-severity modes. SEVERITY explicitly may emit 0..1 BEFORE thresholding; after the `Threshold` compare it's 0/1.

### Pitfall 3: Handle-Compare SIGILL on Octave (the Phase 1006 Plan 01 deviation #3 rediscovery)

**What goes wrong:** Cycle detection using `isequal(handleA, handleB)` or `handleA == handleB` segfaults Octave 11.1.0 when either handle has listener cycles (which CompositeTags WILL have due to the addListener-on-children pattern).

**Why it happens:** Octave's handle-equality recurses into user-defined properties. Listener cycles (A listens to B listens to A) trigger infinite recursion → stack blowup → SIGILL.

**How to avoid:** **Use Key-equality everywhere.** `strcmp(a.Key, b.Key)` is O(1), Octave-safe, and semantically correct because TagRegistry enforces unique keys via hard-error duplicate-key gate.

**Warning signs:**
- Tests crash with "panic: Segmentation fault" rather than failing verify
- Crash on 3-deep composite round-trip (where listener cycles materialize)

**Verification:** Cycle detection DFS uses Key equality. Grep gate: `isequal.*tag\|tag\s*==\s*obj` must return 0 matches in CompositeTag.m. Round-trip test uses Key equality assertions (same as `testRoundTripMonitorTag` in TestTagRegistry.m:286).

### Pitfall 4: Cycle Detection Missing Deeper Cases

**What goes wrong:** Legacy `CompositeThreshold.m:155` only guards self-reference (`isequal(t, obj)`). A 3-deep cycle `A → B → C → A` slips through, causing infinite recursion on `getXY` later.

**Why it happens:** Incremental accretion — self-reference was an easy check; deeper DFS was deferred.

**How to avoid:** **Full DFS** on addChild. Starting from the proposed new child, walk children-of-children looking for the composite being added-to. If found at any depth → error.

**Warning signs:**
- Test `A.addChild(B); B.addChild(C); C.addChild(A)` succeeds instead of erroring
- Stack overflow / segfault on `composite.getXY()` after malformed structure

**Verification:** Tests: (a) self: `c.addChild(c)` errors; (b) 2-deep: `A.addChild(B); B.addChild(A)` the second call errors; (c) 3-deep: `A.addChild(B); B.addChild(C); C.addChild(A)` the third call errors.

### Pitfall 5: Pre-History False Alarms (ALIGN-03)

**What goes wrong:** At t = 0.5, child_A has its first sample at t = 1.0 (not yet started). A naive ZOH that treats child_A as "0 = ok" before t=1.0 makes COUNT/MAJORITY output incorrectly "everybody ok" when in fact child_A is unknown.

**Why it happens:** "Pad with zero before first sample" seems innocuous for binary signals.

**How to avoid:** **Drop grid points before `max(child.X(1))`.** Only emit merge-sort output timestamps `>= max(child_first_x)`. See Section 5 algorithm.

**Warning signs:**
- Output X doesn't start at `max(child_first_x)` but at `min(child_first_x)`
- Test children with staggered starts produces output covering the whole union range

**Verification:** TestCompositeTagAlign.m — construct 3 children with start times 1, 5, 10; assert `composite.getXY().X(1) == 10`.

### Pitfall 6: NaN Handling Inconsistent Between Modes (ALIGN-04)

**What goes wrong:** `AND(1, NaN)` gives 0 (naive IEEE because NaN "looks" unknown), then `OR(1, NaN)` gives 1 (naive `any`). Truth table drifts per-mode, confusing consumers.

**Why it happens:** Implementers reach for `all`/`any`/`max`/`sum` and accept their default NaN handling, which diverges between functions.

**How to avoid:** **Codify truth tables in class header + test every cell.**

Locked mapping (from CONTEXT.md §Truth Tables):
- AND + NaN → NaN (unknown propagates)
- OR + NaN → other operand (NaN is the absorbing identity for OR)
- MAJORITY ignores NaN, reduces divisor (2-of-5 with 1 NaN → 2-of-4 threshold)
- COUNT ignores NaN (NaN doesn't contribute to sum)
- WORST (max) ignores NaN (MATLAB `max` with 'omitnan' is the reference)
- SEVERITY ignores NaN in both numerator AND denominator
- USER_FN is the escape hatch — caller decides

**Warning signs:**
- Test `AND(1, NaN) == 0` passes (should be NaN)
- Test `OR(1, NaN) == NaN` passes (should be 1)

**Verification:** Truth-table test loop covers every (mode, c1, c2) triple from the locked mapping.

### Pitfall 7: Cache Invalidation Missing a Child

**What goes wrong:** Composite's cache doesn't invalidate when only one of 8 children updates, so stale aggregated output survives.

**Why it happens:** Developer forgets to register composite as listener on EVERY child in `addChild` (not just the first).

**How to avoid:** `addChild` ALWAYS calls `tag.addListener(obj)` after validation passes (inside the `if ismethod` guard). `invalidate()` on composite cascades to composite's own listeners too (downstream composites that wrap this one).

**Warning signs:**
- 2-child composite: updating child1 invalidates; updating child2 doesn't.

**Verification:** Test: build 3-child composite, trigger `getXY`, mutate each child's parent in turn, assert each mutation produces a `recomputeCount_` increment.

### Pitfall 8: File-Touch Budget Exactly at Cap (Pitfall 5 REQUIREMENTS gate)

**What goes wrong:** Plan 02 adds one test helper, pushing count to 9. Plan 03 adds the bench, pushing to 10. Budget breached; legacy churn creeping.

**Why it happens:** Every phase faces "just one more test file" pressure.

**How to avoid:** Phase 1006 landed at 12/12 with 0 margin by consolidating test cases into existing files where possible. CONTEXT locks the 8-file list; stick to it.

**Warning signs:** Any PR adding a 9th new file without first revising the CONTEXT.

**Verification:** `git diff --name-only baseline..HEAD -- libs/ tests/ benchmarks/ | wc -l` must be ≤ 8 at phase exit. Phase-exit audit SUMMARY documents verdict (proven pattern in Phase 1006 Plan 03 and Phase 1007 Plan 03 SUMMARY).

## Code Examples

Verified patterns from the existing codebase. All snippets are cited to the line in the referenced file.

### Example 1: Observer Registration (reused verbatim by CompositeTag.addChild)

```matlab
% Source: libs/SensorThreshold/MonitorTag.m lines 306-318
function addListener(obj, m)
    %ADDLISTENER Register a listener notified when this monitor invalidates.
    if ~ismethod(m, 'invalidate')
        error('MonitorTag:invalidListener', ...
            'Listener must implement invalidate(); got %s.', class(m));
    end
    obj.listeners_{end+1} = m;
end

% Source: libs/SensorThreshold/MonitorTag.m lines 428-433
function notifyListeners_(obj)
    for i = 1:numel(obj.listeners_)
        obj.listeners_{i}.invalidate();
    end
end

% Source: libs/SensorThreshold/MonitorTag.m lines 295-304
function invalidate(obj)
    obj.dirty_ = true;
    obj.cache_ = struct();
    obj.notifyListeners_();
end
```

### Example 2: Lazy Memoization with dirty_ Flag

```matlab
% Source: libs/SensorThreshold/MonitorTag.m lines 202-216 (structure only; merge-sort replaces recompute_)
function [x, y] = getXY(obj)
    if obj.dirty_ || ~isfield(obj.cache_, 'x')
        obj.recompute_();   % CompositeTag: obj.mergeStream_()
    end
    x = obj.cache_.x;
    y = obj.cache_.y;
end
```

### Example 3: ZOH valueAt Using binary_search

```matlab
% Source: libs/SensorThreshold/MonitorTag.m lines 218-228
function v = valueAt(obj, t)
    [x, y] = obj.getXY();
    if isempty(x) || isempty(y)
        v = NaN;
        return;
    end
    idx = binary_search(x, t, 'right');
    v = y(idx);
end
```

**For CompositeTag Section 8 fast path:** don't call obj.getXY at all — iterate children and call `child.valueAt(t)` (which is O(log M) per child), then aggregate the N scalar values. O(N log M) total vs O(N × M_unique) full materialization.

### Example 4: Switch Dispatch by Tag Kind (FastSense.addTag pattern)

```matlab
% Source: libs/FastSense/FastSense.m lines 967-979 (existing switch)
switch tag.getKind()
    case 'sensor'
        [x, y] = tag.getXY();
        obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
    case 'state'
        obj.addStateTagAsStaircase_(tag, varargin{:});
    case 'monitor'
        [x, y] = tag.getXY();
        obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
    otherwise
        error('FastSense:unsupportedTagKind', ...
            'Unsupported tag kind ''%s''.', tag.getKind());
end

% PHASE 1008 EDIT — add before `otherwise`:
case 'composite'
    [x, y] = tag.getXY();
    obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
```

### Example 5: Two-Phase Deserialization Template (resolveRefs)

```matlab
% Source: libs/SensorThreshold/MonitorTag.m lines 734-774 (fromStruct Pass-1)
function obj = fromStruct(s)
    if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
        error('MonitorTag:dataMismatch', 'fromStruct requires struct with non-empty .key.');
    end
    % Pass 1: construct with placeholder parent (resolveRefs wires real one).
    dummyParent   = MockTag(s.parentkey);
    placeholderFn = @(x, y) false(size(x));
    obj = MonitorTag(s.key, dummyParent, placeholderFn, ...);
    obj.ParentKey_ = s.parentkey;  % stashed for Pass-2
end

% Source: libs/SensorThreshold/MonitorTag.m lines 268-291 (resolveRefs Pass-2)
function resolveRefs(obj, registry)
    if isempty(obj.ParentKey_), return; end
    if ~registry.isKey(obj.ParentKey_)
        error('MonitorTag:unresolvedParent', ...);
    end
    realParent = registry(obj.ParentKey_);
    obj.Parent = realParent;
    if ismethod(realParent, 'addListener'), realParent.addListener(obj); end
    obj.invalidate();
    obj.ParentKey_ = '';
end
```

**For CompositeTag:** Pass-1 stashes `ChildKeys_` (cell) + `ChildWeights_` (double array). Pass-2 iterates and calls `obj.addChild(registry(key_i), 'Weight', weight_i)` so the addChild path runs validation + cycle-check + listener-hookup.

### Example 6: Octave-Safe Handle Identity via Key

```matlab
% Source: tests/suite/TestTagRegistry.m lines 286-287 (testRoundTripMonitorTag)
testCase.verifyEqual(loadedMonitor.Parent.Key, loadedParent.Key, ...
    'Forward order: loadedMonitor.Parent.Key must equal loadedParent.Key.');
```

**NEVER use** `verifyEqual(loadedMonitor.Parent, loadedParent)` — segfaults Octave when listener cycles are present.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Legacy `CompositeThreshold` — scalar ok/alarm status derived from per-child `threshold.allValues()` + static `Value` | `CompositeTag` — time-series 0/1 aggregation via merge-sort over child streams | Phase 1008 (this) | Enables time-series composition; `valueAt(t)` replaces `computeStatus()` for instant-time queries |
| `isequal(t, obj)` self-reference check | Key-equality DFS cycle detection | Phase 1008 (this) | Works on Octave without SIGILL; catches deeper cycles A→B→C→A |
| `union(X_i)` + `interp1` alignment | k-way merge-sort with ZOH last-known Y | Phase 1008 (this) | Peak memory O(N + M_unique) not O(N × M); compute <200ms at 8 × 100k |
| `methods (Abstract)` blocks | Throw-from-base stubs in Tag (Phase 1004) | Phase 1004 | Octave portability (`methods (Abstract)` parsed-no-op) |
| `events`/listeners blocks | Plain `listeners_ = {}` cell + `addListener` + `notifyListeners_` | Phase 1006 | Octave portability + simpler lifecycle |
| Single-phase JSON load (ordering trap) | Two-phase `loadFromStructs` with `resolveRefs` hook | Phase 1004 | Order-insensitive; loud errors on unresolved refs (Pitfall 8) |

**Deprecated/outdated within Phase 1008 scope:**

- None — CompositeTag is greenfield within the v2.0 hierarchy; legacy `CompositeThreshold.m` stays untouched until Phase 1011 per strangler-fig discipline (MIGRATE-02).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b+ | Core test execution | ✓ (target; dev on macOS Apple Silicon) | N/A on dev machine — tests run on Octave | Octave 11.1.0 covers both |
| Octave 7+ | Octave-fallback tests | ✓ | 11.1.0 (`/opt/homebrew/bin/octave`) | — |
| `binary_search` | CompositeTag.valueAt fast path | ✓ | Phase 0 (MEX + pure-MATLAB fallback at `libs/FastSense/binary_search.m`) | Pure-MATLAB path in binary_search.m |
| `MockTag` | fromStruct Pass-1 dummy child (if needed) | ✓ | Phase 1004 at `tests/suite/MockTag.m` | — |
| `memory()` MATLAB builtin | Pitfall 3 memory gate measurement | ✗ on Octave 11.1.0 | `memory: function not yet implemented for this architecture` (verified Octave output) | Output-size proxy + `/proc/self/status` (Linux only) |
| `/proc/self/status` | Linux RSS probe | ✗ on macOS dev | No /proc on macOS Darwin | `ps -o rss= -p $$` works on macOS; output-size proxy works everywhere |
| `ps -o rss=` | macOS RSS probe | ✓ (verified) | Darwin ps returns KB | Output-size proxy for CI portability |
| Pure-MATLAB implementation path | Every pitfall-9 bench + every test | ✓ | All project benchmarks + tests run headless on Octave | — |

**Missing dependencies with fallback:**

- `memory()`: use **output-size proxy** as the authoritative gate (`numel(composite_X) <= sum(child_sample_counts) * 1.1`) + opportunistically call `system('ps -o rss= -p %d', getpid)` for a rough RSS readout. Document the limitation in the benchmark docstring.

**Missing dependencies with no fallback:** None.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB unittest + Octave flat-assert (dual convention established Phase 1004) |
| Config file | None — test discovery via `tests/run_all_tests.m` + `tests/suite/*` |
| Quick run command | `octave --no-gui --eval "install(); cd tests; test_compositetag(); test_compositetag_align();"` |
| Full suite command | `octave --no-gui --eval "install(); cd tests; run_all_tests();"` |
| Phase gate command | `octave --no-gui --eval "install(); bench_compositetag_merge();"` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| COMPOSITE-01 | `CompositeTag < Tag`; `isa(c, 'Tag')` true; `getKind() == 'composite'`; recursively composable | unit | `octave --no-gui --eval "install(); cd tests; test_compositetag();"` | ❌ Wave 0 |
| COMPOSITE-02 | 7 aggregation modes produce correct truth-table output | unit (table-driven) | same | ❌ Wave 0 |
| COMPOSITE-03 | `addChild(tagOrKey, 'Weight', w)` accepts handle or key | unit | same | ❌ Wave 0 |
| COMPOSITE-04 | Cycle detection: self AND deeper A→B→A with `CompositeTag:cycleDetected` | unit | same | ❌ Wave 0 |
| COMPOSITE-05 | `getXY()` via merge-sort; no `union+interp1`; output X matches expected merge | unit + grep gate | `test_compositetag_align();` + grep for `union\|interp1` in CompositeTag.m | ❌ Wave 0 |
| COMPOSITE-06 | `valueAt(t)` returns aggregated scalar without full-series materialization | unit + timing | same test file (asserts valueAt ≤ getXY time when only scalar needed) | ❌ Wave 0 |
| COMPOSITE-07 | `addChild(sensorTag)` raises `CompositeTag:invalidChildType` | unit | `test_compositetag();` | ❌ Wave 0 |
| ALIGN-01 | No `interp1.*'linear'` in CompositeTag.m | grep gate | `grep -c "interp1.*'linear'" libs/SensorThreshold/CompositeTag.m` == 0 | Wave 0 check script |
| ALIGN-02 | Union-of-timestamps grid evaluation | unit | `test_compositetag_align();` | ❌ Wave 0 |
| ALIGN-03 | Drops grid points before `max(child.X(1))` | unit | same | ❌ Wave 0 |
| ALIGN-04 | NaN truth tables: AND-NaN→NaN, OR-NaN→other, WORST-NaN→ignore, COUNT-NaN→ignore | unit (table-driven) | same | ❌ Wave 0 |
| Pitfall 3 | Peak <50MB + compute <200ms at 8 × 100k | bench | `octave --no-gui --eval "install(); bench_compositetag_merge();"` | ❌ Wave 0 |
| Pitfall 6 | Truth tables documented in class header; MAJORITY rejects multi-state | doc gate + unit | `grep -c "Truth table" libs/SensorThreshold/CompositeTag.m` ≥ 1 | Wave 0 check script |
| Pitfall 8 | 3-deep composite-of-composite round-trip GREEN | integration | `test_compositetag();` — assertion in round-trip test | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `octave --no-gui --eval "install(); cd tests; test_compositetag(); test_compositetag_align();"` (seconds)
- **Per wave merge:** `octave --no-gui --eval "install(); cd tests; run_all_tests();"` + `bench_compositetag_merge()` (~30s)
- **Phase gate:** Full Octave suite GREEN + bench PASS + all grep gates 0-match + file-count ≤ 8 before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestCompositeTag.m` — covers COMPOSITE-01..04, 06, 07, Pitfall 6/8
- [ ] `tests/suite/TestCompositeTagAlign.m` — covers COMPOSITE-05, ALIGN-01..04, Pitfall 5/6
- [ ] `tests/test_compositetag.m` — Octave flat mirror of suite #1
- [ ] `tests/test_compositetag_align.m` — Octave flat mirror of suite #2
- [ ] `benchmarks/bench_compositetag_merge.m` — Pitfall 3 gate
- [ ] Class-header truth-table doc block (Pitfall 6 doc gate)
- [ ] `TagRegistry.loadFromStructs` 3-deep round-trip already works structurally (Pass-2 recurses via resolveRefs); needs a dedicated test in TestCompositeTag to assert it (Pitfall 8 gate)

*No framework install needed — MATLAB unittest + Octave flat-assert already established.*

## Section 2: CompositeTag Class Skeleton (recommended shape)

Skeleton consolidated from CONTEXT §CompositeTag Class Skeleton + MonitorTag Phase 1006 proven patterns. ~280 SLOC target.

```matlab
classdef CompositeTag < Tag
    %COMPOSITETAG Aggregates child Tags (MonitorTag/CompositeTag) into a derived 0/1 series.
    %
    %   AggregateMode truth tables (binary 0/1 inputs; NaN = unknown):
    %   AND:   (0,0)->0  (0,1)->0  (1,1)->1  (0,NaN)->NaN  (1,NaN)->NaN  (NaN,NaN)->NaN
    %   OR:    (0,0)->0  (0,1)->1  (1,1)->1  (0,NaN)->0    (1,NaN)->1    (NaN,NaN)->NaN
    %   WORST: max ignoring NaN (MATLAB `max([..], [], 'omitnan')` reference)
    %   COUNT: sum ignoring NaN; thresholded by obj.Threshold to 0/1
    %   MAJORITY: #ones > (#non-NaN)/2 → 1, else 0; all-NaN → NaN
    %   SEVERITY: (Σ w_i * v_i) / (Σ w_i) over non-NaN, thresholded by obj.Threshold
    %   USER_FN: obj.UserFn(values_row_vector) — caller handles NaN
    %
    %   See also Tag, MonitorTag, TagRegistry, CompositeThreshold (legacy).

    properties
        AggregateMode char = 'and'
        UserFn       = []         % function_handle; required when mode=='user_fn'
        Threshold    double = 0.5 % for COUNT/SEVERITY binarization
    end

    properties (Access = private)
        children_    cell = {}    % cell of structs: {tag, weight}
        cache_       struct = struct()
        dirty_       logical = true
        listeners_   cell = {}    % composites that wrap this one (invalidation cascade)
        ChildKeys_   cell = {}    % Pass-1 stash; consumed by resolveRefs
        ChildWeights_ double = [] % Pass-1 stash; consumed by resolveRefs
    end

    properties (SetAccess = private)
        recomputeCount_ = 0       % test probe
    end

    methods
        function obj = CompositeTag(key, aggregateMode, varargin)
            % Parse NV BEFORE obj@Tag super-call (Pitfall 7 Phase 1006 pattern)
            [tagArgs, cmpArgs] = CompositeTag.splitArgs_(varargin);
            obj@Tag(key, tagArgs{:});
            if nargin < 2 || isempty(aggregateMode)
                aggregateMode = 'and';
            end
            obj.AggregateMode = lower(aggregateMode);
            CompositeTag.validateMode_(obj.AggregateMode);
            for i = 1:2:numel(cmpArgs)
                switch cmpArgs{i}
                    case 'UserFn',    obj.UserFn    = cmpArgs{i+1};
                    case 'Threshold', obj.Threshold = cmpArgs{i+1};
                    otherwise
                        error('CompositeTag:unknownOption', 'Unknown option ''%s''.', cmpArgs{i});
                end
            end
            if strcmp(obj.AggregateMode, 'user_fn') && isempty(obj.UserFn)
                error('CompositeTag:userFnRequired', ...
                    'AggregateMode ''user_fn'' requires UserFn function_handle.');
            end
        end

        function addChild(obj, tagOrKey, varargin)
            % Resolve handle
            if ischar(tagOrKey) || isstring(tagOrKey)
                tag = TagRegistry.get(char(tagOrKey));  % errors if missing
            else
                tag = tagOrKey;
            end
            % Type guard (COMPOSITE-07)
            if ~isa(tag, 'MonitorTag') && ~isa(tag, 'CompositeTag')
                error('CompositeTag:invalidChildType', ...
                    'Only MonitorTag or CompositeTag allowed (got %s).', class(tag));
            end
            % Cycle guard (COMPOSITE-04)
            if obj.wouldCreateCycle_(tag)
                error('CompositeTag:cycleDetected', ...
                    'Adding child %s would create a cycle.', tag.Key);
            end
            % Parse Weight
            weight = 1.0;
            for i = 1:2:numel(varargin)
                if strcmpi(varargin{i}, 'Weight'), weight = varargin{i+1}; end
            end
            obj.children_{end+1} = struct('tag', tag, 'weight', weight);
            % Hook listener — invalidation cascade from child → composite
            if ismethod(tag, 'addListener')
                tag.addListener(obj);
            end
            obj.invalidate();
        end

        function [x, y] = getXY(obj)
            if obj.dirty_ || ~isfield(obj.cache_, 'x')
                obj.mergeStream_();
            end
            x = obj.cache_.x;
            y = obj.cache_.y;
        end

        function v = valueAt(obj, t)
            % FAST PATH (COMPOSITE-06): aggregate child.valueAt(t), no full-series
            n = numel(obj.children_);
            if n == 0, v = NaN; return; end
            vals    = zeros(1, n);
            weights = zeros(1, n);
            for i = 1:n
                c = obj.children_{i};
                vals(i)    = c.tag.valueAt(t);
                weights(i) = c.weight;
            end
            v = CompositeTag.aggregate_(vals, weights, obj.AggregateMode, obj.UserFn, obj.Threshold);
        end

        function [tMin, tMax] = getTimeRange(obj)
            [x, ~] = obj.getXY();
            if isempty(x), tMin = NaN; tMax = NaN; return; end
            tMin = x(1); tMax = x(end);
        end

        function k = getKind(~), k = 'composite'; end

        function s = toStruct(obj)
            s = struct();
            s.kind          = 'composite';
            s.key           = obj.Key;
            s.name          = obj.Name;
            s.labels        = {obj.Labels};
            s.metadata      = obj.Metadata;
            s.criticality   = obj.Criticality;
            s.units         = obj.Units;
            s.description   = obj.Description;
            s.sourceref     = obj.SourceRef;
            s.aggregatemode = obj.AggregateMode;
            s.threshold     = obj.Threshold;
            childKeys    = cell(1, numel(obj.children_));
            childWeights = zeros(1, numel(obj.children_));
            for i = 1:numel(obj.children_)
                childKeys{i}    = obj.children_{i}.tag.Key;
                childWeights(i) = obj.children_{i}.weight;
            end
            s.childkeys    = {childKeys};
            s.childweights = childWeights;
            % UserFn: NOT serialized (function handles cannot round-trip);
            % consumer must rebind after loadFromStructs for user_fn mode.
        end

        function resolveRefs(obj, registry)
            if isempty(obj.ChildKeys_), return; end
            for i = 1:numel(obj.ChildKeys_)
                key = obj.ChildKeys_{i};
                if ~registry.isKey(key)
                    error('CompositeTag:unresolvedChild', ...
                        'Child tag ''%s'' not registered.', key);
                end
                childHandle = registry(key);
                weight = 1.0;
                if i <= numel(obj.ChildWeights_), weight = obj.ChildWeights_(i); end
                obj.addChild(childHandle, 'Weight', weight);
            end
            obj.ChildKeys_    = {};
            obj.ChildWeights_ = [];
            obj.invalidate();
        end

        function invalidate(obj)
            obj.dirty_ = true;
            obj.cache_ = struct();
            obj.notifyListeners_();
        end

        function addListener(obj, m)
            if ~ismethod(m, 'invalidate')
                error('CompositeTag:invalidListener', ...
                    'Listener must implement invalidate(); got %s.', class(m));
            end
            obj.listeners_{end+1} = m;
        end

        % ---- Property setters that invalidate ----
        function set.AggregateMode(obj, v)
            CompositeTag.validateMode_(lower(v));
            obj.AggregateMode = lower(v);
            obj.dirty_ = true;
            obj.cache_ = struct();
        end
    end

    methods (Access = private)
        function notifyListeners_(obj)
            for i = 1:numel(obj.listeners_)
                obj.listeners_{i}.invalidate();
            end
        end

        function mergeStream_(obj)
            obj.recomputeCount_ = obj.recomputeCount_ + 1;
            % k-way merge-sort implementation — see Section 5
            % ... populates obj.cache_ = struct('x', X, 'y', Y)
            % ... obj.dirty_ = false
        end

        function cycle = wouldCreateCycle_(obj, newChild)
            % Key-equality DFS (Pitfall 3 Octave SIGILL avoidance) — see Section 7
            cycle = false;
            if strcmp(newChild.Key, obj.Key), cycle = true; return; end
            visitedKeys = {newChild.Key};
            stack = {newChild};
            while ~isempty(stack)
                cur = stack{end};
                stack(end) = [];
                if isa(cur, 'CompositeTag')
                    for i = 1:numel(cur.children_)
                        gc = cur.children_{i}.tag;
                        if strcmp(gc.Key, obj.Key), cycle = true; return; end
                        if ~any(cellfun(@(k) strcmp(k, gc.Key), visitedKeys))
                            visitedKeys{end+1} = gc.Key;
                            stack{end+1} = gc;
                        end
                    end
                end
            end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            if ~isstruct(s) || ~isfield(s, 'key') || isempty(s.key)
                error('CompositeTag:dataMismatch', 'fromStruct requires struct with non-empty .key.');
            end
            % Unwrap cellstr labels + childkeys wraps (MockTag pattern)
            labels = {};
            if isfield(s, 'labels') && ~isempty(s.labels)
                L = s.labels;
                if iscell(L) && numel(L) == 1 && iscell(L{1}), L = L{1}; end
                if iscell(L), labels = L; end
            end
            metadata = struct();
            if isfield(s, 'metadata') && isstruct(s.metadata), metadata = s.metadata; end
            childKeys = {};
            if isfield(s, 'childkeys') && ~isempty(s.childkeys)
                K = s.childkeys;
                if iscell(K) && numel(K) == 1 && iscell(K{1}), K = K{1}; end
                if iscell(K), childKeys = K; end
            end
            childWeights = ones(1, numel(childKeys));
            if isfield(s, 'childweights') && ~isempty(s.childweights)
                childWeights = s.childweights(:).';
            end
            aggMode = 'and';
            if isfield(s, 'aggregatemode') && ~isempty(s.aggregatemode)
                aggMode = s.aggregatemode;
            end
            thresh = 0.5;
            if isfield(s, 'threshold') && ~isempty(s.threshold)
                thresh = s.threshold;
            end

            nvArgs = { ...
                'Name',        CompositeTag.fieldOr_(s, 'name',        s.key),  ...
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

    methods (Static, Access = private)
        function v = fieldOr_(s, name, def)
            if isfield(s, name) && ~isempty(s.(name)), v = s.(name); else, v = def; end
        end

        function validateMode_(mode)
            valid = {'and','or','majority','count','worst','severity','user_fn'};
            if ~any(strcmp(mode, valid))
                error('CompositeTag:invalidAggregateMode', ...
                    'AggregateMode must be one of: %s. Got ''%s''.', strjoin(valid, ', '), mode);
            end
        end

        function out = aggregate_(vals, weights, mode, userFn, threshold)
            % Single dispatch — used by both valueAt and mergeStream_ per-timestamp
            switch mode
                case 'and'
                    if any(isnan(vals)), out = NaN;
                    else, out = double(all(vals >= 0.5));
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
                    s = sum(nonNan >= 0.5);
                    out = double(s >= threshold);
                case 'worst'
                    nonNan = vals(~isnan(vals));
                    if isempty(nonNan), out = NaN;
                    else, out = max(nonNan);
                    end
                case 'severity'
                    mask = ~isnan(vals);
                    if ~any(mask), out = NaN; return; end
                    num = sum(weights(mask) .* vals(mask));
                    den = sum(weights(mask));
                    if den == 0, out = NaN;
                    else, out = double((num / den) >= threshold);
                    end
                case 'user_fn'
                    out = userFn(vals);
            end
        end

        function [tagArgs, cmpArgs] = splitArgs_(args)
            tagKeys = {'Name','Units','Description','Labels','Metadata','Criticality','SourceRef'};
            cmpKeys = {'UserFn','Threshold'};
            tagArgs = {}; cmpArgs = {};
            for i = 1:2:numel(args)
                if i + 1 > numel(args)
                    error('CompositeTag:unknownOption', 'Option ''%s'' has no matching value.', args{i});
                end
                k = args{i}; v = args{i+1};
                if any(strcmp(k, tagKeys)),      tagArgs(end+1:end+2) = {k, v};
                elseif any(strcmp(k, cmpKeys)),  cmpArgs(end+1:end+2) = {k, v};
                else,  error('CompositeTag:unknownOption', 'Unknown option ''%s''.', k);
                end
            end
        end
    end
end
```

## Section 3: Memory Measurement Portability

**Goal:** Bench must gate at peak <50MB across MATLAB (Windows/macOS/Linux) and Octave (Windows/macOS/Linux).

**Finding:** Portable RAM-measurement in MATLAB/Octave is unsolved. The definitive gate MUST be the **output-size proxy**; memory readouts are diagnostic only.

### Options surveyed

| Method | MATLAB | Octave macOS | Octave Linux | Octave Windows | Verdict |
|--------|--------|--------------|--------------|----------------|---------|
| `memory()` builtin | ✓ Windows only | ✗ | ✗ | ✗ | **Not portable.** Even on MATLAB it's Windows-only. Verified on Octave 11.1.0 dev machine: "memory: function not yet implemented for this architecture". |
| `/proc/self/status` VmRSS | ✓ if Linux | ✗ (no /proc) | ✓ | ✗ | Linux-only. Benchmark must detect platform before using. |
| `system('ps -o rss= -p %d', getpid)` | ✓ POSIX | ✓ macOS | ✓ Linux | ✗ | POSIX-portable; verified on dev machine. Units: KB. Requires `getpid()` which is NOT in MATLAB-core; use `feature('getpid')` on MATLAB, `getpid()` on Octave. |
| `feature('memstats')` MATLAB undocumented | ✓ some versions | ✗ | ✗ | ✗ | Undocumented, unstable. Avoid. |
| **Output-size proxy** | ✓ | ✓ | ✓ | ✓ | **Portable.** Measure `whos()` on output arrays + estimate dominant intermediates. Gates the *algorithmic* property (no N×M), not wall RAM. |

### Recommended benchmark pattern

```matlab
function bench_compositetag_merge()
    nChildren = 8;
    nPoints   = 100000;

    % Build 8 MonitorTags with jittered 100k timestamps so union ≈ 800k.
    children = cell(1, nChildren);
    for i = 1:nChildren
        x = sort(rand(1, nPoints) + (i-1));   % jittered, overlapping
        y = sin(2*pi*x);
        st = SensorTag(sprintf('sens_%d', i), 'X', x, 'Y', y);
        children{i} = MonitorTag(sprintf('mon_%d', i), st, @(xx, yy) yy > 0);
    end

    comp = CompositeTag('agg', 'and');
    for i = 1:nChildren, comp.addChild(children{i}); end

    t0 = tic;
    [X, Y] = comp.getXY();
    tElapsed = toc(t0);

    % Output-size proxy (PRIMARY GATE — portable; gates the algorithmic invariant)
    totalChildSamples = nChildren * nPoints;
    outSamples = numel(X);
    ratio = outSamples / totalChildSamples;
    fprintf('Output samples: %d / total child samples: %d (ratio %.2fx)\n', ...
            outSamples, totalChildSamples, ratio);
    assert(outSamples <= totalChildSamples * 1.1, ...
        'Pitfall 3 FAIL: output size %d > 1.1 * child total %d — N×M blowup suspected', ...
        outSamples, totalChildSamples);

    % Wall time (PRIMARY GATE)
    fprintf('Compute time: %.3f s (gate: < 0.2 s)\n', tElapsed);
    assert(tElapsed < 0.2, 'Pitfall 3 FAIL: compute time %.3fs > 0.2s', tElapsed);

    % Opportunistic RSS readout (DIAGNOSTIC only; skip if unsupported)
    try
        if isunix || ismac
            if exist('getpid', 'builtin') || ~isempty(which('getpid'))
                pid = getpid();
            else
                pid = feature('getpid');
            end
            [~, out] = system(sprintf('ps -o rss= -p %d', pid));
            rssKB = str2double(strtrim(out));
            fprintf('RSS: %.1f MB (informational)\n', rssKB / 1024);
        end
    catch
        fprintf('RSS readout unavailable on this platform (informational only).\n');
    end

    fprintf('Pitfall 3 PASS: output-size proxy + compute time gates satisfied.\n');
end
```

**Rationale:** the algorithmic invariant "no N×M materialization" is CHECKED by the output-size proxy (a naive implementation would leave intermediate arrays ≈ N × M_unique ≈ 6.4M, which correlates to peak memory ≈ 50MB — if output size is ≤ 1.1 × totalChildSamples, the implementation cannot have done the naive union-then-interp1, as that would produce > N × child samples in intermediates). The wall-time gate catches performance regressions. RSS is nice-to-have diagnostic.

## Section 4: Truth-Table Test Strategy (compact table-driven)

~30 lines covers 7 modes × 3 input values × {1, 2, 3, 5 children}. Use cell-of-rows:

```matlab
% In test_compositetag.m or TestCompositeTag.m — single table drives all 56+ cases
% Row layout: {mode, values, weights, threshold, expected}
cases = {
    % --- AND ---
    'and',  [0 0],    [1 1],   0.5,   0;
    'and',  [0 1],    [1 1],   0.5,   0;
    'and',  [1 1],    [1 1],   0.5,   1;
    'and',  [0 NaN],  [1 1],   0.5,   NaN;
    'and',  [1 NaN],  [1 1],   0.5,   NaN;
    'and',  [NaN NaN],[1 1],   0.5,   NaN;
    % --- OR ---
    'or',   [0 0],    [1 1],   0.5,   0;
    'or',   [0 1],    [1 1],   0.5,   1;
    'or',   [1 1],    [1 1],   0.5,   1;
    'or',   [0 NaN],  [1 1],   0.5,   0;    % other operand
    'or',   [1 NaN],  [1 1],   0.5,   1;    % other operand
    'or',   [NaN NaN],[1 1],   0.5,   NaN;
    % --- MAJORITY ---
    'majority', [1 1 0],      [1 1 1],   0.5, 1;  % 2 of 3 → 1
    'majority', [1 0 0],      [1 1 1],   0.5, 0;
    'majority', [1 1 NaN],    [1 1 1],   0.5, 1;  % 2 of 2 non-NaN → 1
    'majority', [1 0 NaN],    [1 1 1],   0.5, 0;  % 1 of 2 non-NaN → not >1 → 0
    'majority', [NaN NaN NaN],[1 1 1],   0.5, NaN;
    % --- COUNT (threshold = 2 → 2+ ones → 1) ---
    'count',    [1 1 0],      [1 1 1],   2,   1;
    'count',    [1 0 0],      [1 1 1],   2,   0;
    'count',    [1 1 NaN],    [1 1 1],   2,   1;
    'count',    [1 0 NaN],    [1 1 1],   2,   0;
    % --- WORST ---
    'worst',    [0 0],        [1 1],     0.5, 0;
    'worst',    [0 1],        [1 1],     0.5, 1;
    'worst',    [1 NaN],      [1 1],     0.5, 1;
    'worst',    [NaN NaN],    [1 1],     0.5, NaN;
    % --- SEVERITY (weighted avg then threshold=0.5) ---
    'severity', [1 0],        [1 1],     0.5, 1;  % avg=0.5 → >= → 1
    'severity', [1 0],        [1 3],     0.5, 0;  % weighted: 0.25 → 0
    'severity', [1 NaN],      [1 1],     0.5, 1;  % num=1, den=1 → 1
    'severity', [NaN NaN],    [1 1],     0.5, NaN;
};

for i = 1:size(cases, 1)
    mode = cases{i, 1};  v = cases{i, 2};  w = cases{i, 3};
    thr  = cases{i, 4};  exp = cases{i, 5};
    got = CompositeTag.aggregate_(v, w, mode, [], thr);
    % Compare (NaN requires isnan-check):
    if isnan(exp)
        assert(isnan(got), 'Mode %s vals [%s] expected NaN got %g', mode, num2str(v), got);
    else
        assert(got == exp, 'Mode %s vals [%s] expected %g got %g', mode, num2str(v), exp, got);
    end
end
fprintf('Truth-table cases: %d / %d passed.\n', size(cases,1), size(cases,1));
```

**Coverage:**
- 7 modes (6 rule-based + user_fn tested separately)
- Binary inputs 0, 1, NaN in every combination for 2-child
- 3-child and 5-child majority/count/severity variations
- Weighted severity tested with non-uniform weights
- ALIGN-04 NaN contract codified in rows

## Section 5: Merge-Sort Streaming Algorithm (the Pitfall 3 heart)

### Pseudocode

```
Input:  children[] each with (X_i sorted, Y_i aligned, len_i = numel(X_i))
Output: X_out, Y_out with len_out ≤ Σ len_i + 1 (typically ≪ union size when children share timestamps)

Initialize:
  ptr[i] = 1 for all i = 1..N
  lastY[i] = NaN for all i      (ZOH state — "not yet started")
  first_x = max over i of X_i[1]  (ALIGN-03 pre-history drop — only emit at or after this)
  X_out = []    Y_out = []
  prev_agg = undefined
  weights[i] from addChild

Loop:
  while any ptr[i] <= len_i:
    // Step 1 — find the minimum next-to-consume X among children that haven't exhausted
    live = { i : ptr[i] <= len_i }
    min_x = min over live of X_{i}[ptr[i]]

    // Step 2 — advance every child whose current pointer x == min_x
    for each i in live:
      if X_i[ptr[i]] == min_x:
        lastY[i] = Y_i[ptr[i]]       // ZOH update — now lastY[i] is current
        ptr[i] = ptr[i] + 1
      // else: lastY[i] unchanged — ZOH carry

    // Step 3 — drop pre-history
    if min_x < first_x:  continue

    // Step 4 — compute aggregate at this timestamp
    vals = [lastY[1], ..., lastY[N]]   // any NaN = child hadn't started (but we're past first_x so none should; defensive)
    agg = aggregate_(vals, weights, mode, userFn, threshold)

    // Step 5 — emit only on change (optional optimization; output is otherwise piecewise-constant)
    if isempty(Y_out) or agg ~= prev_agg:   // NaN != NaN → always emits; refine if desired
      X_out(end+1) = min_x
      Y_out(end+1) = agg
      prev_agg = agg

return (X_out, Y_out)
```

### Memory analysis

- `ptr` : N integers (typically 8–16 bytes × 8 children = 128 B)
- `lastY` : N doubles (64 B)
- `weights` : N doubles (64 B)
- `X_out, Y_out` : grow incrementally; final size ≤ Σ len_i (usually far less due to emit-on-change compression)
- **Intermediates per loop iteration** : constant (the `vals` row vector of size N)
- **Total peak** : O(N + Σ len_i) — NOT O(N × Σ len_i)

### Performance analysis

- Outer loop runs Σ len_i times worst-case
- Inner "advance every i where X_i[ptr[i]] == min_x" is O(N)
- `aggregate_` is O(N) (vectorized ops over N-element row)
- **Total** : O(N × Σ len_i) time, which at 8 × 100k = 6.4M ops. Pure-MATLAB loop at ~10M ops/sec → ~640ms **too slow for 200ms gate**.

### Performance optimization — vectorized merge

Instead of one-pass loop, do a sort-based vectorization:

```matlab
% Pre-concatenate all (X, Y, childIdx) triples into long vectors
allX      = cell(1, N);
allY      = cell(1, N);
allChild  = cell(1, N);
for i = 1:N
    [xi, yi] = obj.children_{i}.tag.getXY();
    allX{i}     = xi(:).';
    allY{i}     = yi(:).';
    allChild{i} = i * ones(1, numel(xi));
end
cat_X     = [allX{:}];
cat_Y     = [allY{:}];
cat_Child = [allChild{:}];
[sortedX, order] = sort(cat_X);
sortedY     = cat_Y(order);
sortedChild = cat_Child(order);

% Now walk sortedX once, maintaining lastY[1..N].
M = numel(sortedX);
lastY = nan(1, N);
X_out = zeros(1, M);
Y_out = zeros(1, M);
nOut = 0;
prev_x = NaN;
first_x = max(cellfun(@(xx) xx(1), allX));
for k = 1:M
    lastY(sortedChild(k)) = sortedY(k);
    if sortedX(k) < first_x,  continue;  end
    if k < M && sortedX(k+1) == sortedX(k), continue;  end   % coalesce same-timestamp
    agg = CompositeTag.aggregate_(lastY, weights, mode, userFn, threshold);
    nOut = nOut + 1;
    X_out(nOut) = sortedX(k);
    Y_out(nOut) = agg;
end
X_out = X_out(1:nOut);
Y_out = Y_out(1:nOut);
```

**Memory of this approach:** `cat_X`, `cat_Y`, `cat_Child` are each Σ len_i doubles = 3 × 800k × 8 = 19.2 MB at 8×100k workload. One `sort()` on 800k numerics = fast + in-place-ish. Output allocated 800k-preallocated then truncated. **Peak well under 50MB.**

**Time** : `sort` is O(M log M) ≈ 16 million-op, ~20–40ms. Loop is 800k iterations at ~5–10M/sec in Octave → ~100ms. Total ~150ms — **under 200ms gate with margin**.

**No `union` anywhere** (we used `sort` on pre-concatenated vectors). **No `interp1`** (ZOH via `lastY(sortedChild(k)) = sortedY(k)` update). Algorithmic invariant preserved.

### Alternative: pure k-way merge with MATLAB `sort` + index-tagged streams

The vectorized approach above **IS** k-way merge — sort merges N streams of total M elements in O(M log M) which is optimal for unknown-overlap streams. This is the idiomatic MATLAB/Octave implementation and meets both gates.

## Section 6: valueAt Fast Path — Widget Consumption Shape

### Current (pre-Phase-1009) consumer pattern

StatusWidget, GaugeWidget, IconCardWidget in Phase 1003 call:

```matlab
% Source: libs/Dashboard/StatusWidget.m:162-168
if isa(t, 'CompositeThreshold')
    cStatus = t.computeStatus();   % returns 'ok' or 'alarm'
    if strcmp(cStatus, 'alarm')
        status = 'violation';
    else
        status = 'ok';
    end
end
```

`computeStatus()` on CompositeThreshold resolves value-per-child via static `Value` or `ValueFcn` then runs thresholds. **This is the instant-time query pattern.**

### Phase 1008 mapping

CompositeTag has no `computeStatus()`. The Tag-domain equivalent is **`valueAt(t)` → scalar 0/1 (or 0..1 for severity pre-threshold)**. Phase 1009 will migrate widget code to call `valueAt(t_latest)` where `t_latest = max(tag.getTimeRange)`. That migration is NOT Phase 1008 scope.

### Fast-path contract (Phase 1008)

```matlab
function v = valueAt(obj, t)
    n = numel(obj.children_);
    if n == 0, v = NaN; return; end
    vals    = zeros(1, n);
    weights = zeros(1, n);
    for i = 1:n
        vals(i)    = obj.children_{i}.tag.valueAt(t);
        weights(i) = obj.children_{i}.weight;
    end
    v = CompositeTag.aggregate_(vals, weights, obj.AggregateMode, obj.UserFn, obj.Threshold);
end
```

**Cost:**
- Each `MonitorTag.valueAt(t)` : O(log M_child) via `binary_search` (MonitorTag.m:226)
- Each `SensorTag.valueAt(t)` : O(log M_parent) (but Sensor children not allowed per COMPOSITE-07 — skipped)
- Each `CompositeTag.valueAt(t)` (recursive) : O(N × log M) × nesting depth
- Total : O(N × log M × depth) — at 8 children × log(100k) × 3-deep = 8 × 17 × 3 = 408 ops. **Sub-microsecond.**

**vs `getXY()` cost:** ~150ms to materialize full series. **300,000× speedup** for instant-time query — the whole point of COMPOSITE-06.

**Widget test (not this phase, but informative):**
```matlab
t_latest = max(comp.getTimeRange());
status_bit = comp.valueAt(t_latest);  % 0 or 1 (or NaN)
% Phase 1009 widget code: if status_bit == 1, show alarm color; else ok
```

## Section 7: Cycle Detection DFS (Key-Equality)

### Why Key equality instead of handle equality

The Phase 1006 Plan 01 SUMMARY deviation #3 (referenced in TestTagRegistry.m:286-287) documents:

> "Octave isequal/== on user-defined handles with listener cycles hits SIGILL"

CompositeTag EXPLICITLY has listener cycles — every `addChild` calls `tag.addListener(obj)`, which means `child.listeners_` contains `obj` and (recursively) `obj.children_{i}.tag` contains `child`. If the Octave engine ever tries to compare two handles by recursing their property trees, it blows the stack.

TagRegistry enforces globally-unique Keys (TagRegistry.m:88-94 hard-errors on duplicate), so **Key equality is semantically equivalent to handle equality within a single registry session** AND Octave-safe.

### Algorithm

```matlab
function cycle = wouldCreateCycle_(obj, newChild)
    % "Would adding newChild as child of obj create a cycle?"
    % A cycle exists iff obj is reachable from newChild via the children_ graph.

    % Trivial self-reference
    if strcmp(newChild.Key, obj.Key)
        cycle = true;
        return;
    end

    % DFS from newChild, by Key
    cycle       = false;
    visitedKeys = {newChild.Key};
    stack       = {newChild};

    while ~isempty(stack)
        cur = stack{end};
        stack(end) = [];

        % Leaf kinds (MonitorTag) have no children — skip
        if isa(cur, 'CompositeTag')
            for i = 1:numel(cur.children_)
                gc = cur.children_{i}.tag;
                % Key-equality check against obj
                if strcmp(gc.Key, obj.Key)
                    cycle = true;
                    return;
                end
                % Visited-set guard (by key)
                if ~any(cellfun(@(k) strcmp(k, gc.Key), visitedKeys))
                    visitedKeys{end+1} = gc.Key; %#ok<AGROW>
                    stack{end+1}       = gc;     %#ok<AGROW>
                end
            end
        end
    end
end
```

### Test coverage

```matlab
function testCycleSelf(testCase)
    c = CompositeTag('c', 'and');
    testCase.verifyError(@() c.addChild(c), 'CompositeTag:cycleDetected');
end

function testCycleDirect(testCase)
    a = CompositeTag('a', 'and');
    b = CompositeTag('b', 'and');
    % a.addChild(b) is fine
    a.addChild(b);
    % but b.addChild(a) creates a 2-cycle
    testCase.verifyError(@() b.addChild(a), 'CompositeTag:cycleDetected');
end

function testCycleDeep(testCase)
    a = CompositeTag('a', 'and');
    b = CompositeTag('b', 'and');
    c = CompositeTag('c', 'and');
    a.addChild(b);
    b.addChild(c);
    % c.addChild(a) creates a 3-cycle a->b->c->a
    testCase.verifyError(@() c.addChild(a), 'CompositeTag:cycleDetected');
end

function testNoCycleAcrossBranches(testCase)
    % Diamond is fine: two paths to same leaf, no cycle
    leaf = MonitorTag('leaf', SensorTag('s', 'X', 1:10, 'Y', 1:10), @(x,y) y > 5);
    a = CompositeTag('a', 'and');
    b = CompositeTag('b', 'or');
    top = CompositeTag('top', 'and');
    a.addChild(leaf);
    b.addChild(leaf);
    top.addChild(a);
    top.addChild(b);  % diamond: top -> {a, b} -> leaf
    testCase.verifyEqual(numel(top.children_), 2);
end
```

## Section 8: Listener Chain Scalability for Recursive Invalidation

### Pattern

MonitorTag (Phase 1006) established:
- `listeners_ = {}` cell property
- `addListener(m)` appends
- `notifyListeners_()` iterates and calls `m.invalidate()`
- `invalidate()` clears cache + calls `notifyListeners_()`

This is **recursive** by design: `m.invalidate()` may itself call `notifyListeners_()` to propagate further.

### Composite case

- A MonitorTag child invalidates when its Parent SensorTag's `updateData` fires
- The composite registered as listener on the MonitorTag in `addChild`
- MonitorTag's `invalidate()` → `notifyListeners_()` → calls `composite.invalidate()`
- Composite's `invalidate()` → `notifyListeners_()` → calls any *outer* composite's `invalidate()`

### Proof it scales

Phase 1006 Plan 01 explicitly tested recursive MonitorTag invalidation (TestMonitorTag.m referenced in 1006-03-SUMMARY.md "Recursive MonitorTag invalidation propagation"). The exact same observer shape is used here. 3-deep is proven by the existing Phase 1006 cascade test; 3-deep composite-of-composite adds one more hop but is structurally identical.

### Edge case — diamond invalidation

If composite C has two paths to leaf L (C → A → L, C → B → L), then updating L triggers:
- L.notifyListeners_() fires
- A.invalidate() runs → A.notifyListeners_() fires → C.invalidate() runs
- B.invalidate() runs → B.notifyListeners_() fires → C.invalidate() runs (again — idempotent)

`invalidate()` is idempotent: `obj.dirty_ = true; obj.cache_ = struct();` applied twice has same effect as once. No issue.

### Performance

At v2.0 scales (≤100 tags, ≤5-deep), cascade is free. Benchmark `bench_compositetag_merge` measures wall time for recompute; if cascade ever becomes hot, it would manifest as unexpectedly-high recomputeCount_ on downstream composites.

## Section 9: 3-Deep Composite Round-Trip Test Setup

### What "3-deep composite-of-composite-of-composite" means

```
             top_composite (and)
            /                  \
      mid_composite_L (or)    mid_composite_R (majority)
         /          \               /           \
      mon_1        mon_2        mon_3         mon_4
     (parent=s1) (parent=s2)  (parent=s3)   (parent=s4)
```

- 1 top CompositeTag
- 2 mid CompositeTags
- 4 leaf MonitorTags
- 4 SensorTags (not children of composite, but parents of monitors)

Total tags in registry: 11.

### Round-trip test (in TestCompositeTag.m)

```matlab
function testRoundTrip3Deep(testCase)
    TagRegistry.clear();
    % Build
    s1 = SensorTag('s1', 'X', 1:10, 'Y', 1:10);
    s2 = SensorTag('s2', 'X', 1:10, 'Y', 1:10);
    s3 = SensorTag('s3', 'X', 1:10, 'Y', 1:10);
    s4 = SensorTag('s4', 'X', 1:10, 'Y', 1:10);
    m1 = MonitorTag('m1', s1, @(x,y) y > 5);
    m2 = MonitorTag('m2', s2, @(x,y) y > 5);
    m3 = MonitorTag('m3', s3, @(x,y) y > 5);
    m4 = MonitorTag('m4', s4, @(x,y) y > 5);
    mid_L = CompositeTag('mid_L', 'or');
    mid_L.addChild(m1);
    mid_L.addChild(m2);
    mid_R = CompositeTag('mid_R', 'majority');
    mid_R.addChild(m3);
    mid_R.addChild(m4);
    top = CompositeTag('top', 'and');
    top.addChild(mid_L);
    top.addChild(mid_R);

    structs = {s1.toStruct(), s2.toStruct(), s3.toStruct(), s4.toStruct(), ...
               m1.toStruct(), m2.toStruct(), m3.toStruct(), m4.toStruct(), ...
               mid_L.toStruct(), mid_R.toStruct(), top.toStruct()};

    % Tear down, reload (forward order)
    TagRegistry.clear();
    TagRegistry.loadFromStructs(structs);
    loadedTop = TagRegistry.get('top');
    testCase.verifyEqual(loadedTop.getKind(), 'composite');
    testCase.verifyEqual(loadedTop.AggregateMode, 'and');
    % Key-equality handle identity (never use == on handles)
    testCase.verifyEqual(loadedTop.children_{1}.tag.Key, 'mid_L');
    testCase.verifyEqual(loadedTop.children_{2}.tag.Key, 'mid_R');
    testCase.verifyEqual(loadedTop.children_{1}.tag.children_{1}.tag.Key, 'm1');

    % Reverse order — Pitfall 8 re-verify
    TagRegistry.clear();
    TagRegistry.loadFromStructs(fliplr(structs));
    loadedTop2 = TagRegistry.get('top');
    testCase.verifyEqual(loadedTop2.children_{1}.tag.Key, 'mid_L');
    testCase.verifyEqual(loadedTop2.children_{1}.tag.children_{1}.tag.Key, 'm1');

    TagRegistry.clear();
end
```

### Why this works structurally

`TagRegistry.loadFromStructs` Pass 2 iterates every registered tag and calls `resolveRefs(map)`. CompositeTag's `resolveRefs` resolves EACH child key via `registry(key)` and calls `addChild(handle, 'Weight', w)` — which is the normal validated path (type-check, cycle-check, listener-hookup).

Order-insensitivity: Pass 1 only constructs empty-children tags (CompositeTag stashes `ChildKeys_` for Pass 2). Pass 2 processes every tag; by the time `top.resolveRefs` runs, `mid_L` and `mid_R` are already in the registry even if they were in the input structs list after `top`. Recursive: `mid_L.resolveRefs` also runs and wires m1/m2 (also already in registry from Pass 1).

## Section 10: File-Touch Inventory (target 8 files)

From CONTEXT.md §File Organization + cross-reference against existing files:

| # | Path | Status | Category | Rationale |
|---|------|--------|----------|-----------|
| 1 | `libs/SensorThreshold/CompositeTag.m` | NEW | production (~280 SLOC) | Class implementation |
| 2 | `libs/SensorThreshold/TagRegistry.m` | EDIT (+3 lines) | production | `case 'composite'` in `instantiateByKind` + error-message update |
| 3 | `libs/FastSense/FastSense.m` | EDIT (+4 lines) | production | `case 'composite'` in `addTag` switch |
| 4 | `tests/suite/TestCompositeTag.m` | NEW | test suite | Constructor/modes/addChild/cycle/serialization/roundtrip3deep |
| 5 | `tests/suite/TestCompositeTagAlign.m` | NEW | test suite | Merge-sort + pre-history + NaN truth tables |
| 6 | `tests/test_compositetag.m` | NEW | Octave flat-assert | Mirror of #4 |
| 7 | `tests/test_compositetag_align.m` | NEW | Octave flat-assert | Mirror of #5 |
| 8 | `benchmarks/bench_compositetag_merge.m` | NEW | bench | Pitfall 3 gate (output-size proxy + wall time) |

**Risk — ripple from TestTagRegistry:** Phase 1006 Plan 03 added `testRoundTripMonitorTag` to `tests/suite/TestTagRegistry.m` (+45 lines). Phase 1008 could analogously add `testRoundTripCompositeTag3Deep` to TestTagRegistry.m, bumping count to 9. **Recommendation:** put the 3-deep round-trip test inside `TestCompositeTag.m` instead (it's composite-scoped, belongs there semantically, and keeps TagRegistry.m test suite untouched). Budget stays at 8.

**Validation against legacy zero-churn invariant (MIGRATE-02):**
- `libs/SensorThreshold/Sensor.m` — UNCHANGED ✓
- `libs/SensorThreshold/Threshold.m` — UNCHANGED ✓
- `libs/SensorThreshold/ThresholdRule.m` — UNCHANGED ✓
- `libs/SensorThreshold/CompositeThreshold.m` — UNCHANGED ✓ (legacy reference only)
- `libs/SensorThreshold/StateChannel.m` — UNCHANGED ✓
- `libs/SensorThreshold/SensorRegistry.m` — UNCHANGED ✓
- `libs/SensorThreshold/ThresholdRegistry.m` — UNCHANGED ✓
- `libs/SensorThreshold/ExternalSensorRegistry.m` — UNCHANGED ✓

Phase-exit grep gate: `git diff baseline..HEAD -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry}.m` must produce 0 lines.

## Open Questions

1. **Should CompositeTag forward `appendData` to children?**
   - What we know: Phase 1007 added `MonitorTag.appendData(newX, newY)` for streaming. 1007 SUMMARY §"Open Concerns for Phase 1008" explicitly flags this question.
   - What's unclear: Whether CompositeTag exposes its own `appendData` (propagating to children) or whether children `appendData` individually and composite re-materializes on next `getXY`.
   - Recommendation: **NO `CompositeTag.appendData` in Phase 1008.** Children (MonitorTags) call their own appendData; when any child's cache updates, its listener hook invalidates the composite's cache; next `composite.getXY()` re-merges. This keeps Phase 1008 scope tight and preserves the observer-cascade invariant. LiveEventPipeline wire-up is Phase 1009 scope (already deferred there from Phase 1007).

2. **Weight semantics for non-SEVERITY modes — validate or ignore?**
   - What we know: SEVERITY is the only mode that consumes Weight; AND/OR/MAJORITY/COUNT/WORST are weight-indifferent.
   - What's unclear: Should `addChild(tag, 'Weight', 2)` in AND-mode error or silently store the unused weight?
   - Recommendation: **Store but ignore in non-severity modes.** Documented in class header truth-table block. Keeps the API forgiving; avoids error-when-mode-changes-later surprise. If validation is desired, add a single-line note in the constructor to warn (not error) when Weight is non-default in non-severity mode. No breaking error.

3. **SEVERITY output shape: raw avg (0..1) or thresholded (0/1)?**
   - What we know: CONTEXT §Truth Tables says "SEVERITY: weighted average `sum(weights .* values) / sum(weights)` ... Output thresholded by `obj.Threshold`."
   - What's unclear: Whether the raw 0..1 is exposed anywhere (e.g., for severity progress bars) or only the thresholded 0/1.
   - Recommendation: **Binary 0/1 only per REQUIREMENTS.md §"MonitorTag value semantics: Binary 0/1 only"** — tri-state and continuous severity are explicitly deferred. SEVERITY internally computes weighted avg then thresholds; exposes only 0/1. Internal continuous value is not part of the public API in v2.0. A future v2.x can add `valueAtSeverity(t)` returning the raw 0..1 if needed.

4. **NaN in MAJORITY with all-NaN inputs?**
   - What we know: Locked semantics say NaN reduces divisor.
   - What's unclear: What if every child is NaN? Division by zero vs. NaN output?
   - Recommendation: **Return NaN.** Denominator = 0 → `sum(nonNan) > 0/2` becomes `0 > 0` → 0, but "0" would mean "all children agree on ok" which is wrong. Better semantically: "no evidence = NaN". Codified in aggregate_ helper above.

5. **Can CompositeTag's cycle detection DFS visit the same leaf via two paths (diamond)?**
   - What we know: Diamond structure `top → {A, B} → L` is valid (not a cycle).
   - What's unclear: DFS may visit L twice via A and B. Shouldn't cause false-positive cycle, but wasted work.
   - Recommendation: **Visited-set keyed by Key** (implemented in Section 7). L is visited once via A; when DFS pops to B and tries to push L again, the visited check prevents it. Correct AND efficient.

## Sources

### Primary (HIGH confidence — verified from codebase files)

- `libs/SensorThreshold/MonitorTag.m` (Phase 1006/1007) — Observer pattern, lazy memoization, resolveRefs, ZOH valueAt, appendData carrier state, split-args NV parsing
- `libs/SensorThreshold/CompositeThreshold.m` (legacy) — Cycle detection shape (self-reference only), aggregate-mode switch, toStruct/fromStruct for children-by-key
- `libs/SensorThreshold/TagRegistry.m` (Phase 1004) — Two-phase loadFromStructs + instantiateByKind dispatch
- `libs/SensorThreshold/Tag.m` (Phase 1004) — Throw-from-base abstract contract; ≤6 abstract methods budget
- `libs/SensorThreshold/SensorTag.m`, `StateTag.m` (Phase 1005) — Listener hook pattern, splitArgs_
- `libs/FastSense/FastSense.m` lines 943-979 (Phase 1005/1006) — `addTag` polymorphic switch
- `libs/FastSense/binary_search.m` — `'right'` direction = ZOH idx
- `benchmarks/bench_monitortag_append.m` (Phase 1007) — Pitfall 9 benchmark template
- `tests/suite/TestTagRegistry.m` (Phase 1006) — `testRoundTripMonitorTag` Pattern (lines 263-305); Key-equality identity assertion
- `.planning/phases/1006-monitortag-lazy-in-memory/1006-03-SUMMARY.md` — Phase-exit audit template + Plan 03 4-line extension pattern
- `.planning/phases/1007-monitortag-streaming-persistence/1007-03-SUMMARY.md` — Pitfall 9 bench template; Phase 1008 open concerns
- `.planning/phases/1008-compositetag/1008-CONTEXT.md` — Locked decisions + verification gates
- `.planning/REQUIREMENTS.md` — COMPOSITE-01..07, ALIGN-01..04, stack-forbidden list
- `.planning/ROADMAP.md` §Phase 1008 — Pitfall 3/6/8 gates + success criteria

### Secondary (MEDIUM confidence — verified via runtime probes)

- Octave 11.1.0 `memory()` availability — verified MISSING on dev machine via `octave --no-gui --eval "try; m = memory(); disp(m); catch err; disp(err.message); end"` → "memory: function not yet implemented for this architecture"
- `/proc/self/status` availability — verified MISSING on dev machine (macOS Darwin) via `cat /proc/self/status 2>/dev/null || echo "no /proc"` → "no /proc"
- `ps -o rss= -p PID` — verified WORKING on dev machine (macOS Darwin) → returned RSS in KB
- Phase 1006 Plan 01 SIGILL finding — documented in 1006-03-SUMMARY.md key-decisions: "Round-trip test uses Key equality ... Octave isequal on user-defined handles with listener cycles hits SIGILL (Plan 01 SUMMARY deviation #3 documented this)"

### Tertiary (LOW confidence — flagged for validation)

- Wall-time estimate of 150ms for vectorized k-way merge at 8×100k — estimated from sort complexity O(M log M) ≈ 16M ops + O(M) single-pass loop. Actual measurement requires running `bench_compositetag_merge.m` after implementation. Gate of 200ms has 33% margin from this estimate.
- Output-size proxy (`outSamples <= 1.1 × totalChildSamples`) as a cordon against N×M materialization — heuristic based on "a naive impl producing N-width matrix intermediates would also emit ≥ N × output_size samples in the eventual output". If an implementer finds a way to build N×M intermediates without inflating output size, this proxy would miss it. For Phase 1008 scope, the combination of output-size proxy + wall-time gate + grep-for-`union|interp1` provides triangulated enforcement.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — Every component (Tag base, TagRegistry, MonitorTag, binary_search, MockTag) is already shipped and tested in Phases 1004-1007.
- Architecture patterns: HIGH — Every pattern (observer cascade, two-phase deser, switch dispatch) has ≥2 phases of precedent.
- Merge-sort algorithm: MEDIUM — Reference implementation sketched and cost-analyzed; wall-time estimate (~150ms) needs runtime verification.
- Cycle detection DFS: HIGH — Key-equality approach mandated by prior Octave SIGILL finding; algorithm is textbook DFS with visited-set.
- Truth tables: HIGH — Locked in CONTEXT.md; match IEEE 754 conventions and MATLAB `max(...,'omitnan')` behavior.
- Memory measurement methodology: MEDIUM — `memory()` portability verified MISSING on Octave; output-size proxy is the primary gate with `ps -o rss=` as diagnostic. Not a novel finding but required workaround.
- Pitfall catalog: HIGH — 8 pitfalls enumerated with warning signs + verification steps; mirrors the prior-phase gate audit structure.
- 3-deep round-trip test: HIGH — Structurally identical to Phase 1006 Plan 03 2-deep test; Pass-2 resolveRefs recursion already validated.

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (30 days; all references are first-party codebase files, so staleness is bounded by further phase advances — at the next milestone this research can be partially recycled or superseded).

## RESEARCH COMPLETE
