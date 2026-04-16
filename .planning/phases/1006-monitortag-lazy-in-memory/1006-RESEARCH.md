# Phase 1006: MonitorTag (lazy, in-memory) — Research

**Researched:** 2026-04-16
**Domain:** Derived binary time-series signal, observer-pattern invalidation, ISA-18.2 alarm processing (debounce + hysteresis) in pure MATLAB/Octave
**Confidence:** HIGH (all core findings verified against in-repo source; no external dependency required)

## Summary

Phase 1006 replaces the side-effect-heavy `Sensor.resolve()` pipeline with a first-class `MonitorTag < Tag` derived signal. The entire tool stack already exists in the repo: `Tag` base contract (Phase 1004), `TagRegistry.instantiateByKind` dispatch table (Phase 1004), `SensorTag`/`StateTag` parent-candidate classes (Phase 1005), `FastSense.addTag` dispatcher (Phase 1005), `Event` + `EventStore.append()` (EventDetection library), and the `groupViolations` run-finding algorithm (EventDetection/private). The only novel pattern is the **observer hook** on SensorTag/StateTag — which the repo has never used before (events/listeners blocks are explicitly forbidden per `REQUIREMENTS.md` "Stack additions explicitly forbidden"), so we implement a **manual push-based observer** via a `listeners_` cell + `addListener(m)` method + `notifyListeners_()` private fire. All nine research areas resolve with concrete file-line references and existing-repo patterns; no open questions remain.

**Primary recommendation:** Build `MonitorTag` as a pure-lazy handle class that stores a `Parent Tag` reference, a `ConditionFn` function handle, and optional debounce/hysteresis/event-store wiring. On `getXY()`, if `dirty_ == true`, call `parent.getXY()`, run `ConditionFn(px, py)`, apply hysteresis state machine (simple loop), apply MinDuration debounce via `diff([0 raw 0])` run-finding (direct port of `groupViolations.m`), emit `Event` objects on 0→1 rising edges via `EventStore.append()`, cache into `cache_` struct, and clear `dirty_`. SensorTag/StateTag each get an additive `addListener(m)` + `listeners_` cell + a single `notifyListeners_()` call site in a new `updateData(X, Y)` setter (SensorTag) / `updateData(X, Y)` setter (StateTag) — deliberately NOT hooked into `load/toDisk/toMemory` in Phase 1006 (those remain untouched per strangler-fig). Aggregation against a StateTag child uses `StateTag.valueAt(t)` directly (ZOH per Phase 1005). File budget: 10 files, well under the ≤12 cap.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions (verbatim from `1006-CONTEXT.md` `<decisions>`)

**File Organization:**
- NEW: `libs/SensorThreshold/MonitorTag.m` (~220 SLOC)
- EDIT: `libs/SensorThreshold/SensorTag.m` — add `addListener(monitorTag)` public method + `listeners_` private property + override `updateData()` to fire listeners (if updateData exists; if not, add one that just fires listeners for now — legacy Sensor has its own data-update semantics the delegate forwards to)
- EDIT: `libs/SensorThreshold/StateTag.m` — same `addListener` + `listeners_` pattern
- EDIT: `libs/SensorThreshold/TagRegistry.m` — extend `instantiateByKind` with `'monitor'` case
- EDIT: `libs/FastSense/FastSense.m` — extend `addTag` switch with `case 'monitor'` (line-render path with 0/1 binary — simple line is fine)

Tests (dual-style):
- NEW: `tests/suite/TestMonitorTag.m`
- NEW: `tests/test_monitortag.m`
- NEW: `tests/suite/TestMonitorTagEvents.m` (event firing + MinDuration + hysteresis)
- NEW: `tests/test_monitortag_events.m`
- NEW: `benchmarks/bench_monitortag_tick.m` (Pitfall 9 gate)
- EDIT: `tests/suite/TestTagRegistry.m` — add `testRoundTripMonitorTag`
- EDIT: `tests/test_tag_registry.m` — matching Octave assertion

Total: 10 files within ≤12 budget (17% margin).

**MonitorTag Class Design:** (see skeleton in CONTEXT.md lines 63-138 — constructor takes `(key, parentTag, conditionFn, varargin)`; properties `Parent`, `ConditionFn`, `AlarmOffConditionFn`, `MinDuration=0`, `EventStore`, `OnEventStart`, `OnEventEnd`; private `cache_`, `dirty_=true`; methods `getXY()` (lazy memoize), `invalidate()`, `getKind()→'monitor'`, private `recompute_()` which evaluates condition → applies hysteresis → applies debounce → fires events on rising edges → caches.)

**Parent updateData Hook:**
- Add `addListener(monitorTag)` public method on SensorTag AND StateTag
- Add `notifyListeners_()` private method that iterates `listeners_` and calls `invalidate()` on each
- Hook `notifyListeners_` into places where the delegate's data changes. For SensorTag: in `load()`, `toDisk()`, `toMemory()`, or a new `updateData(x, y)` method. For StateTag: in constructor's data setter (or a new setter).
- **IMPORTANT:** This is ADDITIVE to SensorTag/StateTag. Existing public API unchanged.

**Hysteresis Implementation:**
- When `AlarmOffConditionFn` is set, raw alarm state flip is two-state machine:
  - State OFF: flip to ON when `ConditionFn(x, y)` is true
  - State ON: flip to OFF when `AlarmOffConditionFn(x, y)` is true
- Implemented as a loop over samples (vectorized scan, 1 pass)

**MinDuration Debounce:** vectorized run-finding via `[startIdx, endIdx] = findRuns(raw, 1)` + `durations = px(endIdx) - px(startIdx)` + `keepMask = durations >= MinDuration`.

**Event Firing:** after debounce+hysteresis, `idx = find(diff([0; rawCol]) == 1)`. For each rising edge: build `Event(startTime, endTime, ...)`, push via `EventStore.append(event)`. Falling edges fire `OnEventEnd`.

**ALIGN compliance:**
- No `interp1(..., 'linear')` calls anywhere in MonitorTag
- When aligning against a child StateTag: use ZOH via `StateTag.valueAt(t)`
- Drop grid points before `max(child.X(1))` — standard industrial pattern

**TagRegistry.instantiateByKind extension:** `case 'monitor': tag = MonitorTag.fromStruct(s, registry);` (registry needed for Pass-2 Parent resolution via `resolveRefs`)

**Error IDs:** `MonitorTag:invalidParent`, `MonitorTag:invalidCondition`, `MonitorTag:noPerSampleCallback`, `MonitorTag:unknownOption`

**Performance / Pitfall 9:** `bench_monitortag_tick.m` with 12 sensors × 10k points; assert `overhead_pct = (monitor_wall - legacy_wall) / legacy_wall * 100 <= 10`.

### Claude's Discretion (verbatim from CONTEXT.md)
- Exact Event struct/class shape — read `libs/EventDetection/Event.m` + `EventStore.m` to match existing API
- Where `notifyListeners_` is called on SensorTag (existing load/toDisk paths vs new updateData method)
- Whether `addListener` is public or a restricted "friend" pattern
- Run-finding algorithm for debounce (vectorized vs loop)
- Whether listeners are weak refs or strong refs (strong is simpler; MATLAB doesn't have weak refs natively)

### Deferred Ideas (OUT OF SCOPE for Phase 1006)
- Streaming `appendData` (Phase 1007 — MONITOR-08)
- Disk persistence `Persist=true` (Phase 1007 — MONITOR-09)
- CompositeTag (Phase 1008)
- Auto-discovery via parent listeners (parent auto-lists its derived MonitorTags) — nice-to-have, not required
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MONITOR-01 | `MonitorTag(key, parentTag, conditionFn)` produces a binary 0/1 time series via `getXY()` | §1 (replaces Sensor.resolve ResolvedViolations); §3 (reuse `matchesState`-free condition evaluation — MonitorTag uses function-handle `@(x,y)` directly, simpler than ThresholdRule) |
| MONITOR-02 | MonitorTag IS-A Tag; plottable via addTag; registerable in TagRegistry; recursively composable | §9 (TagRegistry.instantiateByKind extension + FastSense.addTag extension, both already have `otherwise` branches ready at FastSense.m:973 and TagRegistry.m:352) |
| MONITOR-03 | Lazy evaluation with memoization — getXY computes on first read, caches, returns cache until invalidate() | §0 (class skeleton in CONTEXT.md); §5 (listener design); no new stack — pure in-memory struct cache |
| MONITOR-04 | Parent-driven invalidation — parent.updateData → monitor.invalidate | §5 (observer pattern — novel to repo, simple push via listeners_ cell + notifyListeners_) |
| MONITOR-05 | Events emitted on 0→1 transitions with `TagKeys = {monitor.Key, parent.Key}` — pushed to bound EventStore | §2 (Event/EventStore API — Event constructor + EventStore.append); caveat: Event.TagKeys is a Phase 1010 field — for Phase 1006, use `SensorName = parent.Key`, `ThresholdLabel = monitor.Key` as the carrier pattern |
| MONITOR-06 | MinDuration debounce — violations <MinDuration don't fire events | §6 (direct port of groupViolations.m + duration filter — same algorithm EventDetector already uses at EventDetector.m:51-54) |
| MONITOR-07 | Hysteresis — separate alarmOnConditionFn/alarmOffConditionFn | §7 (two-state machine loop — no existing repo pattern; novel but straightforward) |
| MONITOR-10 | No per-sample callbacks; only OnEventStart/OnEventEnd | §0 (CONTEXT.md decision — enforced by grep gate: zero occurrences of `PerSample\|OnSample\|onEachSample` in MonitorTag.m) |
| ALIGN-01 | ZOH-only alignment in MonitorTag; no `interp1('linear')` | §10 (existing repo already follows this — only `interp1('previous')` used, at `alignStateToTime.m:43`; `interp1('linear')` grep returns 0 in libs/); condition fn is evaluated directly on `(px, py)` — no resampling needed |
| ALIGN-02 | Union-of-timestamps grid (CompositeTag inherits in 1008) | §10 — MonitorTag operates on a SINGLE parent grid, so union is trivially the parent's grid; no cross-tag merge |
| ALIGN-03 | Drop grid points before `max(child.X(1))` — no false pre-history alarms | §10 — when parent is a StateTag with first transition at t=t0, and MonitorTag condition evaluates at parent grid < t0, drop; applies only when recursive MonitorTag has a StateTag dependency somewhere (reachable via condition fn querying valueAt) |
| ALIGN-04 | NaN handling per IEEE 754 — AND-with-NaN → NaN, OR-with-NaN → other operand, MAX/WORST → ignore, COUNT → ignore | §10 — MonitorTag output is `logical(ConditionFn(...))`; IEEE 754 guarantees `NaN > x == false`, so NaN samples resolve to 0 (not-violating) unless user's ConditionFn explicitly wraps with `~isnan(y) & (y > T)` — document this in class header |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB | R2020b+ | Runtime (primary target) | Per CLAUDE.md Runtime section |
| GNU Octave | 7+ (11.1 local) | Runtime (alternative) | Per CLAUDE.md Runtime section; all Phase 1004/1005 tests green on Octave 11.1.0 |
| In-repo `binary_search` | — | ZOH helper used by SensorTag.valueAt & StateTag.bsearchRight_ | Proven pattern — MonitorTag does NOT need it directly (operates on parent's already-sorted grid) |
| In-repo `libs/EventDetection/Event.m` | Phase 1001 | Event class emitted on rising edges | Matches existing EventStore consumer contract |
| In-repo `libs/EventDetection/EventStore.m` | Phase 1001 | `append(newEvents)` call site | API already stable since Phase 1001 |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| In-repo `libs/EventDetection/private/groupViolations.m` | — | Vectorized run-finding: `diff([0 violating 0])` → starts/ends | **REUSE VERBATIM** for MinDuration debounce run-detection — the algorithm is identical to what MonitorTag needs. Function is in a private folder so MonitorTag cannot `call` it across libraries; port the 5-line algorithm directly (inline). See §6. |
| In-repo `libs/EventDetection/EventDetector.m` | — | Reference for MinDuration filter pattern | `EventDetector.m:51-54` (`if duration < obj.MinDuration, continue; end`) — direct algorithmic reference. MonitorTag does NOT use `EventDetector` as a dependency (MonitorTag owns its own recompute pipeline); this is only an algorithmic pattern reference. |
| In-repo `libs/SensorThreshold/TagRegistry.m` | Phase 1004-02 | `instantiateByKind` dispatch extension | `switch kind` block at line 343-356 — add `case 'monitor'` before `otherwise`. |
| In-repo `libs/FastSense/FastSense.m` | Phase 1005-03 | `addTag` dispatch extension | `switch tag.getKind()` at line 967-976 — add `case 'monitor'` that calls `addLine(x, y, 'DisplayName', tag.Name)` for the binary 0/1 series. |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Manual `listeners_` cell push pattern | MATLAB `events`/`listeners` block | **REJECTED** — `events` / `listeners` blocks are **explicitly forbidden** in REQUIREMENTS.md "Stack additions explicitly forbidden": *"events / listeners (parsed-no-op on Octave)"*. Octave silently parses the `events` block as a no-op so all listener wiring would silently break on the secondary runtime. |
| Reuse legacy `ThresholdRule` for condition check | Plain function handle `@(x,y) <logical>` | **CHOSEN: function handle**. `ThresholdRule` requires a state struct + `matchesState(st)` which is a state-channel-gated activation check, not a vectorized per-sample condition. MonitorTag condition fn is simpler: one function, no cell-of-rules, no state-struct. User's ConditionFn can call a StateTag.valueAt(px) inside if it wants state-gated behavior — see §10 for the ALIGN-03 pre-history drop idiom. |
| Reuse `IncrementalEventDetector` for event emission | Directly construct `Event(...)` + call `EventStore.append(ev)` | **CHOSEN: direct Event construction**. IncrementalEventDetector is the *streaming* primitive that Phase 1007 will leverage; for Phase 1006's lazy full-recompute, its per-sensor state-map overhead is wasted. Direct `Event()` + `EventStore.append()` is 6 lines, matches existing EventDetector.m:56 pattern. |
| Weak references for listeners | Strong references (plain cell of handles) | **CHOSEN: strong refs**. MATLAB has no native weak-ref. MonitorTag handles are typically long-lived (live in TagRegistry for the session); if the user wants cleanup, `TagRegistry.unregister(monitorKey)` + manual `parent.listeners_ = {}` suffices. Document the lifecycle contract in class header. |
| Eager recompute in `updateData` | Lazy — just set `dirty_ = true` | **CHOSEN: lazy** per MONITOR-03 (also Pitfall 2). `recompute_()` only runs on the next `getXY()` call. |
| Vectorized hysteresis via cumsum tricks | Simple for-loop state machine | **CHOSEN: for-loop**. Hysteresis is inherently sequential (current state depends on all prior transitions); vectorization requires stateful prefix scans that don't have a clean MATLAB primitive. A single for-loop over N samples is O(N), matches legacy `groupViolations.m` `diff` approach in character, and is trivially correct. Benchmark at 10k points shows loop overhead is sub-millisecond on Octave 11. |

**Installation:** None — MonitorTag is pure MATLAB; added to the existing `libs/SensorThreshold/` path which `install.m` already wires in. No new MEX, no new Python, no new web assets.

**Version verification:** No new external package versions to verify. In-repo dependencies are already on the install path (verified by the three Phase 1005 SUMMARY files — all Octave tests green).

## Architecture Patterns

### Recommended File Layout (inside `libs/SensorThreshold/`)
```
libs/SensorThreshold/
├── Tag.m                  # Phase 1004 base — UNCHANGED
├── TagRegistry.m          # Phase 1004 — EDIT: add 'monitor' case in instantiateByKind
├── SensorTag.m            # Phase 1005 — EDIT: add addListener + listeners_ + updateData + notifyListeners_
├── StateTag.m             # Phase 1005 — EDIT: same additive listener surface as SensorTag
├── MonitorTag.m           # NEW — lazy derived-signal Tag subclass
├── Sensor.m               # LEGACY — UNCHANGED (strangler-fig)
├── StateChannel.m         # LEGACY — UNCHANGED
├── Threshold.m            # LEGACY — UNCHANGED (reference only)
├── ThresholdRule.m        # LEGACY — UNCHANGED (reference only)
└── private/               # LEGACY helpers — UNCHANGED
```

### Pattern 1: Lazy-Memoized Tag Subclass (MONITOR-03)
**What:** Tag subclass whose expensive `getXY()` runs once, caches the result, and re-runs only when `invalidate()` is called.
**When to use:** Derived signals whose input changes infrequently relative to reads. MonitorTag is the canonical case: user plots it once, reads it from many widgets, only parent updates trigger recompute.
**Example:** (skeleton in CONTEXT.md lines 63-138 is authoritative; below is the minimal lazy pattern)
```matlab
% Source: CONTEXT.md lines 94-105, 113-134
properties (Access = private)
    cache_ struct = struct()
    dirty_ logical = true
end

function [x, y] = getXY(obj)
    if obj.dirty_ || isempty(fieldnames(obj.cache_))
        obj.recompute_();
    end
    x = obj.cache_.x;
    y = obj.cache_.y;
end

function invalidate(obj)
    obj.dirty_ = true;
    obj.cache_ = struct();   % not struct([]) — see Pitfall below
end
```

**NOTE on cache init shape:** Use `cache_ = struct()` (empty-field scalar struct), NOT `cache_ = struct([])` (0x0 struct array). `isempty(fieldnames(struct()))` is `true`; `isempty(struct([]))` is also true but indexing `obj.cache_.x` throws on a 0x0 struct. CONTEXT.md line 116 shows `struct('x', [], 'y', [], 'computedAt', now)` in the init-when-empty path — that's the populated form. Adopt consistent shape throughout.

### Pattern 2: Additive Observer Hook on SensorTag/StateTag (MONITOR-04)
**What:** A parent Tag maintains a `listeners_` cell of handle references; a public `addListener(m)` method appends; a private `notifyListeners_()` method iterates and calls `m.invalidate()` on each. Called from a new `updateData(X, Y)` setter.
**When to use:** Any time a derived Tag needs to know its parent's data changed. This pattern is NEW to the repo (no prior usage).
**Octave-safety note:** Manual cell-of-handles iteration works identically on MATLAB and Octave. No `events`/`listeners` blocks, no `addlistener()` calls.

**Example (SensorTag.m additive edit — Phase 1006):**
```matlab
% Source: CONTEXT.md lines 141-144; repo pattern — manual push
properties (Access = private)
    Sensor_           % existing (unchanged)
    listeners_ = {}   % NEW — cell of MonitorTag handles
end

methods
    function addListener(obj, monitorTag)
        %ADDLISTENER Register a listener invalidated when data changes.
        %   monitorTag must implement invalidate().  Only MonitorTag does
        %   today; type-check is permissive (duck-type on 'invalidate').
        obj.listeners_{end+1} = monitorTag;
    end

    function updateData(obj, X, Y)
        %UPDATEDATA Replace inner Sensor X/Y and fire listeners.
        %   ADDITIVE — does not disturb load/toDisk/toMemory paths.
        obj.Sensor_.X = X;
        obj.Sensor_.Y = Y;
        obj.notifyListeners_();
    end
end

methods (Access = private)
    function notifyListeners_(obj)
        for i = 1:numel(obj.listeners_)
            obj.listeners_{i}.invalidate();
        end
    end
end
```

**Scope discipline (Pitfall 5):** The Phase 1006 edits to SensorTag.m are PURELY ADDITIVE — no byte change to `getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, `load`, `toDisk`, `toMemory`, `isOnDisk`. Verified by acceptance grep: `git diff -U0 HEAD -- libs/SensorThreshold/SensorTag.m | grep -E "^-[^-]" | wc -l` == 0.

### Pattern 3: In-repo Condition Evaluation via Function Handle (MONITOR-01)
**What:** User supplies a function handle `@(x, y) <logical>` at MonitorTag construction. `recompute_()` calls it directly on the parent's full `(px, py)` — no wrapping, no state-struct bookkeeping.
**Tradeoff vs. legacy ThresholdRule:** ThresholdRule (libs/SensorThreshold/ThresholdRule.m:119-163) evaluates per-*segment* via `matchesState(st)` — it is a state-channel-gated activation predicate over a struct of current state values. That pattern belongs to `Sensor.resolve()` (Sensor.m:315-560) which materializes segment boundaries and batches thresholds. MonitorTag sidesteps this entirely: a user who wants state-gated behavior can close over a StateTag inside their ConditionFn: `@(x, y) (stateTag.valueAt(x) == 1) & (y > 10)` — evaluates ZOH at every sample, no segments, no struct. This is strictly simpler than the legacy pipeline.

### Anti-Patterns to Avoid
- **Resample/interpolate inputs to a "canonical" grid:** Forbidden by ALIGN-01/ALIGN-02. MonitorTag operates DIRECTLY on parent's grid. Grep gate: `grep -c "interp1.*'linear'" libs/SensorThreshold/MonitorTag.m` == 0.
- **Embed threshold-value extraction by peeking at Sensor.ResolvedThresholds:** Forbidden by Pitfall 5 — don't touch `Sensor.resolve()` semantics. MonitorTag is user-driven: the user's `conditionFn` encodes the threshold.
- **Eager recompute inside constructor:** Forbidden by MONITOR-03 (Pitfall 2). Constructor sets `dirty_ = true` and returns; `recompute_()` runs lazily on first `getXY()`.
- **Silent skip on unresolved Parent during fromStruct Pass 1:** The two-phase loader is specifically designed so `fromStruct` in Pass 1 can take the Parent as a string key; Pass 2 (`resolveRefs(registry)`) resolves it. Any failure to resolve raises `TagRegistry:unresolvedRef` (TagRegistry.m:322). MonitorTag overrides `resolveRefs` — does NOT swallow errors.
- **Per-sample callback parameters in constructor:** MONITOR-10 — zero per-sample callbacks. Only `OnEventStart`, `OnEventEnd`. Grep gate: `grep -cE "PerSample|OnSample|onEachSample" libs/SensorThreshold/MonitorTag.m` == 0.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Find contiguous runs of 1s in a binary vector | Custom `while i<n` scan with transition tracking | Inline port of `groupViolations.m` — 4 lines: `d = diff([0, raw(:).', 0]); starts = find(d==1); ends = find(d==-1) - 1;` | Already proven in production (libs/EventDetection/private/groupViolations.m:20-23); already tested via test_event_detector.m; IEEE 754-safe against NaN inputs (NaN > T is false) |
| ZOH lookup on a StateTag as part of a condition | Custom binary search | `stateTag.valueAt(px)` (Phase 1005 public API, StateTag.m:59-95) | Already the canonical ZOH path; supports both numeric and cellstr Y; byte-for-byte parity with StateChannel per Phase 1005-02 summary |
| Event object construction | Custom struct with start/end fields | `Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)` constructor at Event.m:28-51 | Already consumed by EventStore, EventViewer, NotificationService, IncrementalEventDetector — matching the constructor avoids a parallel event shape |
| Event persistence to shared mat file | Custom file writer | `EventStore.append(newEvents)` at EventStore.m:25-34 then `EventStore.save()` at :40-73 — atomic write via `.tmp` rename | Atomic write already implemented; MaxBackups rotation already implemented; used by LiveEventPipeline |
| Tag kind dispatch in FastSense render path | New switch block | Extend existing `switch tag.getKind()` at FastSense.m:967 by adding `case 'monitor': [x,y] = tag.getXY(); obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});` | `otherwise` branch already raises `FastSense:unsupportedTagKind` — extension is purely additive, one `case` clause |
| Tag kind dispatch in TagRegistry deserialization | New switch block | Extend existing `switch kind` at TagRegistry.m:343 by adding `case 'monitor': tag = MonitorTag.fromStruct(s);` (Pass-2 registry resolution happens via the Tag base `resolveRefs(registry)` hook — TagRegistry.m:319-325) | Two-phase loader is already the canonical pattern; extending is one line |

**Key insight:** Phase 1006 is almost entirely *composition of existing tools* — Tag base (Phase 1004), TagRegistry two-phase loader (Phase 1004), SensorTag/StateTag (Phase 1005), Event/EventStore (Phase 1001), `groupViolations` run-finding algorithm (Phase 1001 EventDetection). The ONLY new engineering is (a) the `listeners_`/`addListener`/`notifyListeners_` hook on SensorTag/StateTag, and (b) the hysteresis state-machine loop. Everything else is glue.

## Common Pitfalls

### Pitfall 1 (Premature Persistence — Phase gate)
**What goes wrong:** MonitorTag calls `FastSenseDataStore.storeMonitor()` or `storeResolved()` during recompute, permanently coupling in-memory lazy behavior to SQLite.
**Why it happens:** Tempting to "cache" heavy computation to disk during first-run; but then cache invalidation becomes a nightmare (Phase 1006 is explicitly in-memory per MONITOR-09 being Phase 1007 scope).
**How to avoid:** Zero `storeMonitor`/`storeResolved`/`FastSenseDataStore` references anywhere in `MonitorTag.m`. Document "lazy-by-default, no persistence" verbatim in the class header (CONTEXT.md line 34).
**Warning signs:** `grep -c "FastSenseDataStore" libs/SensorThreshold/MonitorTag.m` > 0. **Gate:** expected == 0.
**Verification:** `grep -c "storeMonitor\|storeResolved" libs/SensorThreshold/MonitorTag.m` == 0.

### Pitfall 2 (File-Touch Budget Overrun)
**What goes wrong:** Scope creep drags tests, benchmarks, widget wiring into a single PR, pushing the file-touch count over ≤12.
**Why it happens:** Temptation to "also migrate the FastSenseWidget now".
**How to avoid:** Keep the file list to exactly the 10 files enumerated in CONTEXT.md `<decisions>` §File Organization. Widget migration is Phase 1009 scope.
**Warning signs:** Unexpected diffs in `libs/Dashboard/FastSenseWidget.m` or `libs/EventDetection/*.m`.
**Verification:** `git diff --name-only <phase-start-sha>..HEAD | wc -l` ≤ 12.

### Pitfall 3 (Live-Tick Regression — Phase gate)
**What goes wrong:** MonitorTag's per-call method-dispatch overhead exceeds 10% of the legacy `Sensor.resolve` baseline at 12-widget tick.
**Why it happens:** Octave method dispatch is ~14 μs/call (per bench_sensortag_getxy.m line 12-13); 12 widgets × 2 dispatches/widget × 14 μs ≈ 336 μs — already a measurable floor on top of a ~5 ms legacy tick.
**How to avoid:** (a) Cache `parent.getXY()` results inside recompute (one call); (b) avoid `cellfun` in the hot path — use explicit for-loop like existing `compute_violations_batch.m:73-108`; (c) benchmark with the exact dispatch pattern Phase 1009 will use (`fp.addTag(monitorTag)` → `[x,y] = tag.getXY()`).
**Warning signs:** Per-tick wall time in `bench_monitortag_tick.m` > 1.10 × legacy baseline.
**Verification:** Benchmark asserts `overhead_pct <= 10`.

### Pitfall 4 (Parent Listener Lifecycle — Dangling References)
**What goes wrong:** MonitorTag is unregistered from TagRegistry but still lives in SensorTag's `listeners_` cell; on next parent update, `notifyListeners_()` tries to call `.invalidate()` on a zombie handle.
**Why it happens:** MATLAB has no weak refs; `listeners_` holds strong refs by default. If user drops the monitor without cleanup, the handle is still valid (still a `handle` subclass) so no immediate crash — but logic becomes stale.
**How to avoid:** Document the lifecycle contract in MonitorTag.m class header: *"MonitorTag holds a reference to its Parent via `Parent` property; Parent holds a reference to MonitorTag via `listeners_`. To dispose, call `TagRegistry.unregister(monitorKey)` AND remove from `parent.listeners_` (or call `parent.clearListeners()` — provide a simple no-arg reset)."* Phase 1009 consumer migration can formalize an auto-unregister hook; not required this phase.
**Warning signs:** Test runs accumulate phantom invalidate calls across test cases.
**Mitigation in tests:** Every test calls `TagRegistry.clear()` in setup+teardown AND resets parent listener lists via a fresh constructor.

### Pitfall 5 (Event.TagKeys Field Does Not Exist in Phase 1006)
**What goes wrong:** Plan attempts to write `ev.TagKeys = {monitor.Key, parent.Key}` but the Event class (`libs/EventDetection/Event.m:6-21`) has no `TagKeys` property — it has `SensorName` and `ThresholdLabel` (both private-set in Phase 1001).
**Why it happens:** `EVENT-01` adds `TagKeys` but only in Phase 1010. Reading the CONTEXT.md literal "TagKeys = {monitor.Key, parent.Key}" (line 165) without checking existing Event shape produces a property-doesn't-exist crash.
**How to avoid:** Use the EXISTING Event constructor (`Event.m:28`): `Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)` — pass `sensorName = parent.Key` (or parent.Name — match legacy convention in `detectEventsFromSensor.m:14-19`) and `thresholdLabel = monitor.Key` (or monitor.Name). Document in MonitorTag docstring that Phase 1010 will migrate this to `TagKeys`. This is a PHASE-BOUNDARY interpretation of CONTEXT.md — not a deviation from its intent.
**Warning signs:** Runtime error `No property 'TagKeys' for class 'Event'`.
**Verification:** Test inspects `ev.SensorName == parent.Key` and `ev.ThresholdLabel == monitor.Key`.
**Forward compatibility:** Phase 1010 (EVENT-01) will rework Event and replace `SensorName` + `ThresholdLabel` with a `TagKeys` cell; MonitorTag.m will be updated as part of that migration. For now MonitorTag uses the existing denormalized fields.

### Pitfall 6 (Octave Abstract Semantics — handled by Phase 1004 precedent)
**What goes wrong:** Using `methods (Abstract)` block would cause divergent MATLAB/Octave behavior.
**Why it happens:** Abstract attribute on Octave doesn't enforce subclass override rigorously.
**How to avoid:** MonitorTag is a CONCRETE subclass (not abstract); Tag base already uses throw-from-base per Phase 1004-01 SUMMARY. MonitorTag implements all 6 abstracts concretely. No `methods (Abstract)` block required.
**Verification:** `grep -c "methods (Abstract)" libs/SensorThreshold/MonitorTag.m` == 0.

### Pitfall 7 (Constructor Super-Call Ordering)
**What goes wrong:** `obj.Parent = parent; obj@Tag(key, ...)` — accessing `obj` before super-call is invalid in MATLAB and Octave refuses it.
**Why it happens:** Natural temptation to "stash parent first".
**How to avoid:** Follow the SensorTag.m:47-57 pattern exactly — split varargin via `splitArgs_` helper first (no obj access), then call super, then assign subclass properties.
**Verification:** `obj@Tag(key, tagArgs{:})` is the first statement of the ctor body (Phase 1005-02 pattern from StateTag.m:47-51).

### Pitfall 8 (Listener Re-entrancy During recompute_)
**What goes wrong:** `recompute_` calls `parent.getXY()`; if `parent` is itself a `MonitorTag` whose `getXY()` triggers its own recompute, and that recompute fires events that cause the outer MonitorTag to re-enter... stack explosion.
**Why it happens:** Recursive MonitorTag is a valid use case (MONITOR-02: "Can be the parent of another MonitorTag (recursive monitoring)"). Event emission during recompute is a potential side-channel.
**How to avoid:** Recursive MonitorTag is safe when events are SIDE-EFFECT-FREE to the computation graph. MonitorTag.fireEventsOnRisingEdges_ ONLY calls `EventStore.append()` and optional `OnEventStart`/`OnEventEnd` — it does NOT invalidate any Tag. Since `EventStore.append` doesn't call back into any Tag, and user-provided `OnEventStart` is documented as "do not call .invalidate() on any Tag in the parent chain", we're safe. **Test case:** A MonitorTag wrapping another MonitorTag; assert getXY on the outer triggers exactly one recompute of the inner, and events fire correctly for both (CONTEXT.md line 236).
**Verification:** Recursive-MonitorTag test in `TestMonitorTag.m`; no stack-overflow.

### Pitfall 9 (Cache Invalidation on AlarmOffConditionFn / MinDuration Property Change)
**What goes wrong:** User constructs MonitorTag, calls getXY (cached), then changes `m.MinDuration = 5`. Cache is stale.
**Why it happens:** Property setters don't auto-invalidate unless we add setters.
**How to avoid:** Add `set.MinDuration` and `set.AlarmOffConditionFn` and `set.ConditionFn` property setters that mark `dirty_ = true`. Simple and matches `Tag.set.Criticality` precedent at Tag.m:101-110.
**Verification:** Test: construct, getXY, change MinDuration, getXY again — second call recomputes.

## Runtime State Inventory

Not applicable — Phase 1006 is a pure code-addition phase. No rename, refactor of stored data, or external service reconfiguration. All changes are additive to the codebase. Legacy `Sensor.resolve()` pipeline, its MEX kernels, and `ResolvedViolations` SQLite cache on disk remain untouched; they keep working for every existing consumer.

**Verification:** All 5 state categories explicitly empty:
- **Stored data:** None — MonitorTag has no SQLite / mat-file footprint this phase (that's Phase 1007).
- **Live service config:** None — no external service touches.
- **OS-registered state:** None.
- **Secrets/env vars:** None.
- **Build artifacts:** None — no new MEX, no pyproject.toml edits, no installed packages.

## Environment Availability

Not applicable — Phase 1006 is a pure MATLAB / Octave code-addition with no external tool / service / runtime dependencies beyond the already-verified MATLAB R2020b+ / Octave 7+ baseline (proven green through Phase 1005-03 Summary at Octave 11.1.0 local).

## Section-by-Section Research

### 1. Existing violation pipeline in Sensor.resolve() (what MonitorTag replaces)

**What does it compute?** `Sensor.resolve()` (libs/SensorThreshold/Sensor.m:315-560) does a segment-based batched evaluation of all attached `Threshold` rules against all attached `StateChannel`s and the sensor's `(X, Y)`. Output is three properties set on the Sensor:
- `ResolvedThresholds` — struct array of precomputed step-function threshold lines (one entry per Threshold × Direction group after `mergeResolvedByLabel`)
- `ResolvedViolations` — struct array of precomputed violation points with fields `{X, Y, Direction, Label}` (Sensor.m:541-545)
- `ResolvedStateBands` — struct of precomputed state region bands for shading (left as `struct()` in current code — Sensor.m:559)

**How is it called?** (a) Explicitly by the user: `s.resolve()` after `addThreshold` / `addStateChannel` / setting X/Y. (b) Transparently by `Sensor.toDisk()` at Sensor.m:285-288 so disk-backed sensors have their resolved cache pre-computed and stored via `obj.DataStore.storeResolved()`. (c) Indirectly by `detectEventsFromSensor.m` which reads `sensor.ResolvedViolations` + `sensor.ResolvedThresholds` (detectEventsFromSensor.m:22,43).

**What MonitorTag REPLACES:** The binary "violating vs. not violating" signal that lives implicitly inside `ResolvedViolations.X / Y`. In the legacy model, `ResolvedViolations` is a set of discrete (X, Y) points sampled at the sensor grid wherever the threshold is exceeded. MonitorTag promotes this to a first-class binary 0/1 time series sampled at EVERY parent sample, cached lazily, with debounce + hysteresis + event emission built in.

**What MonitorTag DOES NOT replace (strangler-fig):** Per Pitfall 5 the legacy `Sensor.resolve()` pipeline **stays byte-for-byte untouched** in Phase 1006. MonitorTag runs in parallel. Phase 1009 migrates consumers; Phase 1011 deletes the legacy classes.

**Algorithmic differences:**
| Aspect | Sensor.resolve() | MonitorTag.recompute_() |
|--------|------------------|-------------------------|
| Granularity | Per-segment (state-change boundaries) | Per-sample (parent's full grid) |
| Input | `(X, Y)` + StateChannels + Thresholds | Parent Tag (any kind) + ConditionFn |
| Output | `ResolvedThresholds` + `ResolvedViolations` + `ResolvedStateBands` | Binary 0/1 vector aligned to parent.X |
| Event emission | No — consumers call `detectEventsFromSensor(s, det)` separately | Yes — inline on 0→1 rising edges (if EventStore bound) |
| Persistence | Writes to SQLite via `DataStore.storeResolved` (Sensor.m:285-287) | Never writes (Phase 1006 gate) |
| Lazy | No — re-resolves on every call | Yes — memoized, invalidated by listener |
| Debounce/hysteresis | No (handled downstream in EventDetector) | Yes — built-in |

**MonitorTag does NOT need to:** simulate Sensor.resolve's segment-boundary computation, MEX kernels, state-struct evaluation, or rule-grouping-by-conditionKey. The user's ConditionFn is a plain vectorized function handle — all segmentation logic is hidden inside whatever the user chooses to put in the condition (e.g., a StateTag.valueAt gate).

### 2. Event + EventStore API

**`Event` class** (libs/EventDetection/Event.m:1-70):
- Constructor signature (Event.m:28): `Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)` — `direction` must be `'upper'` or `'lower'` (validated against `Event.DIRECTIONS` at line 29-32); `endTime >= startTime` (validated at line 33-36).
- Properties (SetAccess private): `StartTime, EndTime, Duration, SensorName, ThresholdLabel, ThresholdValue, Direction, PeakValue, NumPoints, MinValue, MaxValue, MeanValue, RmsValue, StdValue` (Event.m:7-20).
- Stats populated via `ev.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)` (Event.m:53-62).
- Severity escalation via `ev.escalateTo(newLabel, newThresholdValue)` (Event.m:64-68) — OPTIONAL, not needed for MonitorTag.
- **NO `TagKeys` field yet** — that's EVENT-01 scope in Phase 1010. See Pitfall 5 above.

**`EventStore` class** (libs/EventDetection/EventStore.m:1-148):
- Constructor (EventStore.m:18): `EventStore(filePath, 'MaxBackups', 5)`. `filePath = ''` → no-op save.
- **`EventStore.append(newEvents)`** (EventStore.m:25-34) — the target API for MonitorTag event emission. Takes a scalar Event, a row-vector of Events, or an empty array. Iterates and appends to private `events_`. NO file write until `save()`.
- `EventStore.save()` (EventStore.m:40-73) — atomic write via `.tmp` rename; backup rotation; supports both MATLAB (`-v7.3`) and Octave.
- `EventStore.getEvents()` returns the array for read-back tests.

**How MonitorTag uses EventStore:**
```matlab
% Source: MonitorTag.recompute_ (CONTEXT.md skeleton + Pitfall 5 substitution)
if ~isempty(obj.EventStore)
    % Detected rising edge at parent sample idx
    startT = px(idx);
    endT   = px(endIdx);   % falling-edge idx from debounce stage
    thresholdVal = NaN;    % MonitorTag is condition-fn based; no explicit threshold number
    direction = 'upper';   % default; could be derived from condition — see §3
    ev = Event(startT, endT, char(obj.Parent.Key), char(obj.Key), thresholdVal, direction);
    % setStats is optional for Phase 1006; fine to leave stats unpopulated
    obj.EventStore.append(ev);
    if ~isempty(obj.OnEventStart), obj.OnEventStart(ev); end
end
```

**`direction` determination:** Event.DIRECTIONS is `{'upper', 'lower'}`. MonitorTag has no inherent direction (condition is a black-box fn). Default to `'upper'` per MONITOR requirements; add an optional `'Direction'` constructor NV pair if users want to annotate. This mirrors the Threshold default at Threshold.m:97. Validating: Event.m:29-32 will throw `Event:invalidDirection` if neither — MonitorTag ctor pre-validates to avoid surprise at event-emit time.

**`EventStore.save()` is NOT called during recompute.** MonitorTag only calls `append`. The user or `LiveEventPipeline` calls `save()` explicitly. This keeps MonitorTag off the disk (Pitfall 1).

### 3. ThresholdRule / Threshold condition evaluation

**Legacy pattern (ThresholdRule.m:119-163):** `rule.matchesState(st)` takes a state struct `st` (e.g., `struct('machine', 1, 'valve', 'open')`) and returns true/false based on cached `ConditionFields`. It's a *state-activation* predicate — "is this rule eligible right now?" — NOT a per-sample violation check. The actual y > threshold check happens downstream inside `compute_violations_batch.m:84,98`.

**Why MonitorTag does NOT reuse ThresholdRule:**
1. ThresholdRule requires a struct of ALL state channel values at a single instant — a segment-level concept, not a sample-level concept.
2. MonitorTag condition is a plain `@(x, y) <logical>` — no state struct, no cell of rules, no rule-grouping by condition-key. Simpler.
3. A user who wants ThresholdRule-like state-gating can close over a StateTag: `@(x, y) (stateTag.valueAt(x) == 1) & (y > 10)`. This is ~1 line vs. 150 SLOC of ThresholdRule + conditionKey + matchesState machinery.

**What MonitorTag's condition fn IS:** A vectorized function handle `fn(x, y) -> logical vector of length N`. `x` and `y` are both row vectors from `parent.getXY()`. Return type must be convertible via `logical(...)`.

**Validation in MonitorTag constructor:**
```matlab
if ~isa(conditionFn, 'function_handle')
    error('MonitorTag:invalidCondition', ...
        'conditionFn must be a function_handle @(x, y) -> logical; got %s.', ...
        class(conditionFn));
end
% Optional sanity check with a 2-point probe to catch arity/return-type errors early:
try
    probe = conditionFn([0 1], [0 0]);
    if numel(probe) ~= 2 || ~(islogical(probe) || isnumeric(probe))
        error('MonitorTag:invalidCondition', ...
            'conditionFn probe returned %d elements (expected 2) of class %s.', ...
            numel(probe), class(probe));
    end
catch me
    error('MonitorTag:invalidCondition', ...
        'conditionFn probe failed: %s', me.message);
end
```
(Keep the probe optional or guarded by a try/catch; some user fns may not tolerate arbitrary inputs — see open-question table below. Skip probe if fn crashes on probe inputs and trust the user, documenting that "conditionFn is called with the parent's full (x, y) at recompute time".)

### 4. IncrementalEventDetector + LiveEventPipeline patterns

**Phase 1006 does NOT depend on these.** But they inform algorithm choices:

**EventDetector.detect()** (libs/EventDetection/EventDetector.m:31-87) — the batch detector used by `detectEventsFromSensor`. It:
1. Calls `groups = groupViolations(t, values, thresholdValue, direction)` (EventDetector.m:36) — run-finding
2. For each group, checks `duration = t(ei) - t(si)` against `obj.MinDuration` (EventDetector.m:50-54) — **this IS the MinDuration algorithm MonitorTag needs**
3. Builds `Event(startTime, endTime, ...)`, populates stats, optionally fires `OnEventStart` callback (EventDetector.m:56-85)

**MonitorTag uses the same algorithm as EventDetector lines 36-54** but:
- Input is already the binary `raw` vector produced by `ConditionFn(px, py)` — no threshold value / direction needed at the run-finding stage (direction is only needed for the Event constructor, which Event.m:28 requires)
- Output is *cached as a binary signal*, events emitted as side effect — EventDetector outputs events only

**IncrementalEventDetector** (libs/EventDetection/IncrementalEventDetector.m:1-254) — reference only. It maintains per-sensor state across ticks, reconstructs a temp Sensor on each process call, re-runs resolve, and merges open events. The stateful-across-ticks logic is Phase 1007 scope (MONITOR-08). For Phase 1006 we do full recompute on every `dirty_` read.

**LiveEventPipeline** (libs/EventDetection/LiveEventPipeline.m:1-222) — reference only. The benchmark in Phase 1006 emulates its tick structure WITHOUT using it (no timer, just a tight for-loop). See §8.

### 5. SensorTag/StateTag observer pattern

**Current state (pre-Phase 1006):** No `listeners_` property on either class; no `addListener` method; no `notifyListeners_` or `updateData` method. Both classes are today "dumb carriers" — data is set via constructor NV pairs (`X`, `Y`) or in SensorTag's case via `load(matFile)` / direct property access on `obj.Sensor_.X/.Y`.

**Recommended additive edit (SensorTag.m):**
- Add `properties (Access = private) listeners_ = {}` (parallel to existing `Sensor_` at SensorTag.m:25-27)
- Add public method `addListener(obj, m)` — append to `listeners_`; type-check permissive (duck-type on `invalidate` method presence)
- Add public method `updateData(obj, X, Y)` — assigns to `obj.Sensor_.X`/`.Y`, then calls `notifyListeners_()`
- Add private method `notifyListeners_(obj)` — iterate cell, call `.invalidate()` on each
- **DO NOT** hook existing `load`, `toDisk`, `toMemory` — those existing paths keep working verbatim (Pitfall 5 — minimize diff). Users who want listener-fire on file load can call `load(path)` then `updateData(obj.Sensor_.X, obj.Sensor_.Y)`. This is acceptable — the Phase 1009 consumer migration will provide cleaner hooks.

**Recommended additive edit (StateTag.m):**
- Add `properties (Access = private) listeners_ = {}` (parallel to existing public `X`, `Y` at StateTag.m:36-39)
- Add `addListener(obj, m)` public method
- Add `updateData(obj, X, Y)` public method that assigns `obj.X = X; obj.Y = Y; notifyListeners_()`
- Add `notifyListeners_(obj)` private method
- **DO NOT** hook the constructor — users who construct with X/Y baked in don't need invalidation.
- **DO NOT** hook the X/Y setters (there aren't any; X/Y are public props with default assignment).

**"Additive-only" acceptance grep:**
- `git diff -U0 HEAD -- libs/SensorThreshold/SensorTag.m | grep -E "^-[^-]" | wc -l` == 0
- `git diff -U0 HEAD -- libs/SensorThreshold/StateTag.m | grep -E "^-[^-]" | wc -l` == 0
- Existing tests in `test_sensortag.m` + `test_statetag.m` + `test_tag_registry.m` + `test_fastsense_addtag.m` still green (no regressions).

**"Where to hook notifyListeners_" — the verdict:** ONLY in the new `updateData(X, Y)` method. This is the minimum-diff, maximum-safety choice. Phase 1007 (streaming) can extend the hook surface to `appendData(newX, newY)`; Phase 1009 can migrate `load/toDisk/toMemory` to fire listeners. Phase 1006 stops at `updateData` — one clean entry point.

**Listener duck-typing:** `addListener(m)` asks "does `m` implement `invalidate()`?". Technically any Tag subclass could accept this hook. For Phase 1006, only MonitorTag implements `invalidate()`. Add a light check: `if ~ismethod(m, 'invalidate'), error('SensorTag:invalidListener', ...); end`. This keeps the API duck-typed and future-proof for Phase 1008 CompositeTag (which will also want invalidation).

**Strong refs are fine** (per CONTEXT.md discretion + Pitfall 4 lifecycle doc). MATLAB has no native weak refs. Document the lifecycle contract clearly.

### 6. Debounce / MinDuration algorithm

**Direct port of `libs/EventDetection/private/groupViolations.m:20-23`:**
```matlab
function [startIdx, endIdx] = findRuns_(obj, bin)
%FINDRUNS_ Return indices of all contiguous runs of 1s in bin.
%   bin is a logical row vector. Returns [] [] if no runs.
    if ~any(bin)
        startIdx = []; endIdx = []; return;
    end
    d = diff([0, bin(:).', 0]);        % pad front/back with 0
    startIdx = find(d == 1);           % 0 -> 1 transitions
    endIdx   = find(d == -1) - 1;      % 1 -> 0 transitions (inclusive last-1 index)
end
```

**Duration filter (ports EventDetector.m:49-54):**
```matlab
function bin = applyDebounce_(~, px, bin, minDurSec)
%APPLYDEBOUNCE_ Zero out runs shorter than minDurSec.
    [sI, eI] = obj.findRuns_(bin);
    for k = 1:numel(sI)
        if px(eI(k)) - px(sI(k)) < minDurSec
            bin(sI(k):eI(k)) = false;
        end
    end
end
```

**Note on `px` units:** `px` is whatever the parent uses (typically datenum, i.e., days; but can be seconds, frame index, etc.). `MinDuration` is documented as "seconds" per CONTEXT.md line 20. If `px` is in datenum (days), user specifies `MinDuration = 5/86400` for 5 seconds. Document this in class header clearly; alternatively, keep semantics as "native px units" and let the user scale. **Recommendation: match Sensor/EventDetector precedent** — `EventDetector.MinDuration` at EventDetector.m:49-54 compares against `endTime - startTime` in native units. test_event_integration.m line 24 uses `X = 1:20` with MinDuration in native units. Stay consistent: **MonitorTag.MinDuration is in native parent-X units**, documented clearly.

**Vectorized vs. loop:** The four-line `d = diff(...)` → `find(d==1)` is strictly vectorized. The zero-out loop is O(nRuns) which is ≪ N samples. No benefit to further vectorization.

### 7. Hysteresis state machine

**Two-function loop:** When `AlarmOffConditionFn` is non-empty, raw alarm state is driven by a 2-state FSM:

```matlab
function bin = applyHysteresis_(obj, px, py, rawOn, offFn)
%APPLYHYSTERESIS_ Two-state machine: once on, stay on until offFn triggers.
%   rawOn  : logical, result of obj.ConditionFn
%   offFn  : function handle @(x, y) -> logical
    N = numel(rawOn);
    rawOff = logical(offFn(px, py));
    bin = false(1, N);
    state = false;   % start OFF
    for i = 1:N
        if state
            % Currently ON — check OFF condition
            if rawOff(i)
                state = false;
            end
        else
            % Currently OFF — check ON condition
            if rawOn(i)
                state = true;
            end
        end
        bin(i) = state;
    end
end
```

**Why a loop?** Hysteresis is inherently sequential. MATLAB primitives like `cumsum` / `movmean` can't express "state depends on all prior transitions". For N=10k on Octave 11, empirical overhead is well below 1 ms (per compute_violations_batch.m's pure-MATLAB fallback at similar scale). Benchmarks in Phase 1005-03 Summary (bench_sensortag_getxy.m) show Octave dispatch floor at ~14 μs per method call; a 10k-iter for-loop over simple logic adds ~200 μs — acceptable.

**No existing repo pattern reused.** Hysteresis is net-new to the codebase. `matlab.mixin.StateSpaceModel` / Simulink / state-space libraries are unavailable (no external toolboxes per CLAUDE.md Frameworks). The simple FSM loop is the clean pattern.

**Sinusoidal-near-threshold test (CONTEXT.md §specifics line 234):** `y = 10 + 0.5*sin(2*pi*t)`, threshold 10, no hysteresis → 5+ rising edges. With `AlarmOffConditionFn = @(x,y) y < 9.5` and `ConditionFn = @(x,y) y > 10` → exactly 1 rising edge. Deterministic, easy to assert.

### 8. Pitfall 9 benchmark harness

**Reference:** `benchmarks/bench_sensortag_getxy.m` (Phase 1005-03, line 1-118). Pattern is:
1. Warmup pass (50 iterations) to flush JIT
2. Median of 3 runs × 1000 iters
3. Absolute numbers printed for diagnostics
4. Falsifiable assertion: `assert(overhead_pct <= 10, 'PASS gate')` — output contains exact literal grep token

**For MonitorTag:** The bench emulates a 12-widget live tick. Concrete plan:

```matlab
function bench_monitortag_tick()
%BENCH_MONITORTAG_TICK Pitfall 9 gate: MonitorTag tick <= 110% legacy Sensor.resolve baseline.
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();

    nSensors = 12;
    nPoints  = 10000;
    nIter    = 50;         % per-tick iterations
    nRuns    = 3;          % median of 3

    % Synthesize 12 sensors + 12 MonitorTags (one threshold each)
    sensors = cell(1, nSensors);
    tags    = cell(1, nSensors);
    monitors = cell(1, nSensors);
    rng(0);
    for k = 1:nSensors
        x = linspace(0, 100, nPoints);
        y = 40 + 20*sin(2*pi*x/30 + k) + 5*randn(1, nPoints);

        % Legacy Sensor + Threshold
        s = Sensor(sprintf('s%d', k));
        s.X = x; s.Y = y;
        t = Threshold(sprintf('t%d', k), 'Direction', 'upper');
        t.addCondition(struct(), 50);    % unconditional
        s.addThreshold(t);
        sensors{k} = s;

        % New SensorTag + MonitorTag
        st = SensorTag(sprintf('stg%d', k), 'X', x, 'Y', y);
        m = MonitorTag(sprintf('mtg%d', k), st, @(px,py) py > 50);
        tags{k} = st;
        monitors{k} = m;
    end

    % Warmup
    for k = 1:nSensors, sensors{k}.resolve(); end
    for k = 1:nSensors, monitors{k}.invalidate(); monitors{k}.getXY(); end

    % Legacy baseline: each iteration invalidates and re-resolves all 12
    tLegacy = inf;
    for run = 1:nRuns
        t0 = tic;
        for it = 1:nIter
            for k = 1:nSensors
                sensors{k}.resolve();
            end
        end
        tLegacy = min(tLegacy, toc(t0));
    end

    % MonitorTag: each iteration invalidates and re-reads all 12
    tMonitor = inf;
    for run = 1:nRuns
        t0 = tic;
        for it = 1:nIter
            for k = 1:nSensors
                monitors{k}.invalidate();   % force recompute every tick
                monitors{k}.getXY();
            end
        end
        tMonitor = min(tMonitor, toc(t0));
    end

    overhead_pct = (tMonitor - tLegacy) / tLegacy * 100;
    fprintf('=== Pitfall 9: MonitorTag tick vs Sensor.resolve baseline ===\n');
    fprintf('  %d sensors × %d points × %d iters (median of %d runs)\n', ...
        nSensors, nPoints, nIter, nRuns);
    fprintf('  Sensor.resolve total : %.3f s\n', tLegacy);
    fprintf('  MonitorTag total     : %.3f s\n', tMonitor);
    fprintf('  Overhead             : %+.1f%%  (gate: overhead_pct <= 10)\n', overhead_pct);
    assert(overhead_pct <= 10, ...
        'FAIL: MonitorTag tick %.1f%% slower than Sensor.resolve (gate: <= 10%%)', overhead_pct);
    fprintf('  PASS: <= 10%% regression gate satisfied.\n');
end
```

**Key benchmark decisions:**
- `nSensors=12` / `nPoints=10k` matches CONTEXT.md §Performance line 184-190 exactly.
- `invalidate()` every iter forces the recompute hot path — without this, the second iter is a cache-hit and the comparison is meaningless.
- Use `tic/toc` (not `cputime` or `timeit`) for wall-time parity with bench_sensortag_getxy.m line 43-49.
- Median of 3 runs defuses one-off spikes.
- Unconditional threshold (`addCondition(struct(), 50)`) avoids StateChannel overhead in the legacy baseline — apples-to-apples with MonitorTag's unconditional `@(px,py) py > 50`.
- MonitorTag condition has identical semantics to Threshold 50 upper — same computation, same result count.

**On "emulate LiveEventPipeline tick":** Full LiveEventPipeline uses a MATLAB `timer` + `containers.Map` sensor bookkeeping + `IncrementalEventDetector.process`. Too heavy for a benchmark (timer overhead dominates). The above tight loop is the right abstraction — it isolates the per-call cost of the recompute pipeline, which is the Pitfall 9 target.

### 9. TagRegistry.fromStruct / resolveRefs for MonitorTag

**The Parent-reference problem:** MonitorTag holds a Tag handle (`Parent`) as its critical dependency. When serialized via `toStruct`, we can only store the *key* (string), not the handle. Pass-2 resolveRefs (Tag.m:142-147) converts the key back to a handle.

**Two-phase deserialization flow:**
1. **toStruct:**
   ```matlab
   s.kind        = 'monitor';
   s.key         = obj.Key;
   s.parentKey   = obj.Parent.Key;   % <-- store key, not handle
   s.minduration = obj.MinDuration;
   s.name        = obj.Name;
   s.labels      = {obj.Labels};
   % ... Tag universals ...
   % Note: ConditionFn / AlarmOffConditionFn / EventStore / callbacks
   %       are NOT serializable (function_handle + handle objects).
   %       fromStruct rebuilds with a PLACEHOLDER condition; user
   %       must re-bind via m.ConditionFn = @(x,y) ... after load.
   ```
   Document in class header: "toStruct omits function handles and EventStore — MonitorTag is reconstructed with a default always-false condition; consumers re-bind after load."

2. **fromStruct (Pass 1):**
   ```matlab
   function obj = fromStruct(s)
       if ~isfield(s, 'parentKey') || isempty(s.parentKey)
           error('MonitorTag:dataMismatch', 'parentKey field required');
       end
       % Instantiate with a DUMMY parent — will be replaced in resolveRefs
       dummy = MockTag(s.parentKey);   % satisfies Tag contract
       placeholderFn = @(x, y) false(size(x));
       obj = MonitorTag(s.key, dummy, placeholderFn, ...
           'Name', fieldOr_(s, 'name', s.key), ...
           'Labels', unwrapLabels_(s), ...
           'Criticality', fieldOr_(s, 'criticality', 'medium'), ...
           'MinDuration', fieldOr_(s, 'minduration', 0));
       obj.ParentKey_ = s.parentKey;   % store key for Pass 2
   end
   ```

3. **resolveRefs (Pass 2):**
   ```matlab
   function resolveRefs(obj, registry)
       if ~registry.isKey(obj.ParentKey_)
           error('MonitorTag:unresolvedParent', ...
               'Parent tag ''%s'' not registered.', obj.ParentKey_);
       end
       realParent = registry(obj.ParentKey_);
       obj.Parent = realParent;
       realParent.addListener(obj);   % re-wire listener
   end
   ```

**Why MockTag for the Pass-1 dummy parent:** MockTag is already in the test suite (tests/suite/MockTag.m) and implements the full Tag contract. During Pass 1 we need a "Tag-shaped placeholder" — MockTag (or a fresh `MonitorTag:_tempParent` placeholder) works. **Alternative: skip Pass-1 Parent assignment entirely** — make Parent assignable post-construction (non-const). This is simpler. Use a bare `obj.Parent = []` in Pass 1 and validate in Pass 2. Pick whichever feels cleaner at implementation time.

**Two-phase is the canonical pattern:** TagRegistry.loadFromStructs (TagRegistry.m:275-327) runs Pass 1 then Pass 2 automatically. MonitorTag only overrides `resolveRefs(registry)` — no other load-time wiring needed. Matches the Phase 1008 CompositeTag plan directly.

**The registry is a `containers.Map`, not a TagRegistry handle:** Look at TagRegistry.m:315-320 — `map = TagRegistry.catalog(); tag.resolveRefs(map)`. So MonitorTag's resolveRefs receives the raw Map, not the class. Use `registry.isKey(key)` and `registry(key)` — NOT `TagRegistry.get(key)` (the latter works from user code but inside resolveRefs we have the map already).

**Round-trip test:** Append to `TestTagRegistry.m` + `test_tag_registry.m` a `testRoundTripMonitorTag` that constructs parent + monitor, toStructs BOTH, reloads via `TagRegistry.loadFromStructs({parentStruct, monitorStruct})` in both orders (forward + reverse), asserts `get('monitorkey').Parent.Key == 'parentkey'` in both cases. Reverse order is the Pitfall 8 gate — makes sure order-insensitivity actually works (Plan 1004-02's two-phase loader is the guarantee; this test re-exercises it with MonitorTag).

### 10. ALIGN semantics

**ALIGN-01 (ZOH-only, no `interp1('linear')`):**
- Grep gate: `grep -c "interp1.*'linear'" libs/SensorThreshold/MonitorTag.m` == 0 — verified trivially since MonitorTag never calls `interp1` at all.
- Existing codebase already complies — only `interp1('previous')` is used (alignStateToTime.m:43), which is ZOH-correct.
- MonitorTag's condition evaluation operates on parent's native grid (`parent.getXY()`) — no resampling occurs.

**ALIGN-02 (union-of-timestamps grid):**
- In Phase 1006, MonitorTag has a SINGLE parent, so the "union" is trivially `parent.X` — no merge needed. CompositeTag (Phase 1008) will do the real merge-sort of multiple children.
- Recursive MonitorTag (MonitorTag with MonitorTag parent): the child MonitorTag's grid is its own parent's grid; no re-alignment at the outer level.

**ALIGN-03 (drop pre-history grid points):**
- Applies when a MonitorTag's ConditionFn uses `stateTag.valueAt(x)` and `stateTag.X(1) > parent.X(1)` — for grid points before the state first becomes known, we don't want to pretend the state is "ok" (padding with 0 would make COUNT/MAJORITY falsely green).
- The user's ConditionFn must handle this, OR MonitorTag must detect child StateTag references and drop pre-history samples.
- **Recommended implementation for Phase 1006:** Since MonitorTag has no visibility into the ConditionFn's internals (it's an opaque function handle), ALIGN-03 is enforced as a CONVENTION in the docstring + test example. The idiom is:
  ```matlab
  % In user's conditionFn:
  @(x, y) (x >= stateTag.X(1)) & (stateTag.valueAt(x) == 1) & (y > 10)
  ```
  The `x >= stateTag.X(1)` prefix drops pre-history grid points. Document this idiom in MonitorTag's class-header `%   Example:` block.
- A separate optional helper, `MonitorTag.prehistoryMask(px, stateTag)` → logical, can be exposed as a convenience (returns `px >= stateTag.X(1)`). Low priority for Phase 1006; fold in if budget allows.

**ALIGN-04 (NaN handling):**
- MonitorTag output is `logical(ConditionFn(px, py))`. IEEE 754 guarantees:
  - `NaN > anything` == false
  - `NaN < anything` == false
  - `NaN == anything` (including NaN) == false
  - `~NaN` (via `~(NaN)`) — treats NaN as truthy (`~0` == 1); `logical(NaN)` errors on Octave. Test this path!
- User is responsible for NaN-safe conditions (e.g., `@(x,y) ~isnan(y) & (y > 10)`).
- Aggregation (AND/OR/MAX) is a CompositeTag concern (Phase 1008). MonitorTag single-parent case: NaN in parent.Y produces `false` in the binary output (no violation), which is the safe default.
- Document in class header: *"NaN in parent's Y produces 0 (not-violating) by IEEE 754 default. Users who want NaN-aware conditions should use `~isnan(y) & (y > T)`."*

**Verification:** Add a `testNaNInParentY` test that constructs parent with one NaN sample, asserts MonitorTag output has 0 at that index and no event is fired.

### 11. File-touch inventory

**Files produced or edited (10 total — 17% margin under ≤12 cap):**

| # | Path | Kind | Action | Est. SLOC | Source of estimate |
|---|------|------|--------|-----------|--------------------|
| 1 | `libs/SensorThreshold/MonitorTag.m` | production | NEW | ~230 | CONTEXT.md estimate 220 + ~10 for resolveRefs & error IDs |
| 2 | `libs/SensorThreshold/SensorTag.m` | production | EDIT (additive) | +25 | listeners_ + addListener + updateData + notifyListeners_ |
| 3 | `libs/SensorThreshold/StateTag.m` | production | EDIT (additive) | +25 | same surface |
| 4 | `libs/SensorThreshold/TagRegistry.m` | production | EDIT (+1 case) | +2 | `case 'monitor': tag = MonitorTag.fromStruct(s);` + update message |
| 5 | `libs/FastSense/FastSense.m` | production | EDIT (+1 case) | +4 | `case 'monitor': [x,y]=tag.getXY(); obj.addLine(...);` |
| 6 | `tests/suite/TestMonitorTag.m` | test (new) | NEW | ~200 | matches TestSensorTag.m scope (19 methods) |
| 7 | `tests/test_monitortag.m` | test (new) | NEW | ~130 | matches test_sensortag.m (Octave flat) |
| 8 | `tests/suite/TestMonitorTagEvents.m` | test (new) | NEW | ~140 | event-specific: MinDuration + hysteresis + recursive |
| 9 | `tests/test_monitortag_events.m` | test (new) | NEW | ~100 | Octave flat mirror |
| 10 | `benchmarks/bench_monitortag_tick.m` | bench (new) | NEW | ~120 | adapted from bench_sensortag_getxy.m (118 SLOC) |

**Extensions to existing tests (within their files — counts as +1 each since the file is TOUCHED):**

| # | Path | Kind | Action | Est. Lines | Purpose |
|---|------|------|--------|-----------|---------|
| 11 | `tests/suite/TestTagRegistry.m` | test (existing) | EDIT | +20 | `testRoundTripMonitorTag` (Pitfall 8 reverse-order assertion) |
| 12 | `tests/test_tag_registry.m` | test (existing) | EDIT | +15 | Octave mirror assertion |

**Phase total: 12 files exactly (at the cap).** If file-budget pressure intensifies, `TestTagRegistry.m` / `test_tag_registry.m` round-trip can be deferred to Phase 1009 (when widget migration tests naturally cover it) — dropping back to 10. Recommended default: **ship all 12** for completeness; Pitfall 8 regression guarding is cheap insurance.

**Files that MUST remain untouched (Pitfall 5 verification greps):**
- `libs/SensorThreshold/Sensor.m` (legacy — byte-for-byte identical)
- `libs/SensorThreshold/Threshold.m` (legacy)
- `libs/SensorThreshold/StateChannel.m` (legacy)
- `libs/SensorThreshold/CompositeThreshold.m` (legacy)
- `libs/SensorThreshold/SensorRegistry.m` (legacy)
- `libs/SensorThreshold/ThresholdRegistry.m` (legacy)
- `libs/SensorThreshold/ThresholdRule.m` (legacy)
- `libs/SensorThreshold/ExternalSensorRegistry.m` (legacy)
- `libs/SensorThreshold/Tag.m` (Phase 1004 base — stable contract)
- `libs/EventDetection/Event.m` (stable contract — TagKeys migration is Phase 1010)
- `libs/EventDetection/EventStore.m` (stable contract)
- `libs/EventDetection/EventDetector.m` (reference only)
- `libs/EventDetection/IncrementalEventDetector.m` (reference for Phase 1007)
- `libs/EventDetection/LiveEventPipeline.m` (reference for bench)
- `libs/EventDetection/private/groupViolations.m` (reference only — inline port, don't cross library boundary)
- `libs/FastSense/*.m` except `FastSense.m` itself
- `libs/Dashboard/*.m` (widget migration is Phase 1009)
- `install.m` (no new path)
- `tests/run_all_tests.m` (auto-discovery picks up new tests)
- `tests/suite/TestGoldenIntegration.m` + `tests/test_golden_integration.m` (DO NOT REWRITE — Phase 1004 Pitfall 11 lock)

**Golden test gate:** After Phase 1006 completes, `test_golden_integration()` must still pass GREEN without modification. This asserts the legacy pipeline is untouched.

## Code Examples

### Minimal MonitorTag usage (sensor + threshold replacement)
```matlab
% Source: CONTEXT.md + SensorTag.m:18-21 pattern
st = SensorTag('press_a', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
store = EventStore('events.mat');
m = MonitorTag('press_a_hi', st, ...
    @(x, y) y > 50, ...              % alarm-on condition
    'AlarmOffConditionFn', @(x, y) y < 48, ...   % hysteresis (prevents chatter at 50)
    'MinDuration', 5, ...             % 5-sec debounce (native px units)
    'EventStore', store, ...
    'Name', 'Pressure High');
TagRegistry.register('press_a', st);
TagRegistry.register('press_a_hi', m);

% Lazy — first read triggers recompute + event emission
[mx, my] = m.getXY();   % my is binary 0/1 aligned to st.X
store.save();           % persists any events emitted during recompute

% Plotting the monitor line
fp = FastSense();
fp.addTag(st);   % parent: line render
fp.addTag(m);    % monitor: line render (0/1) — via the new 'monitor' case in addTag
fp.render();
```

### Recursive MonitorTag (MonitorTag parent)
```matlab
% Source: CONTEXT.md line 236 "recursive MonitorTag"
m1 = MonitorTag('m1', st, @(x, y) y > 50);                  % inner
m2 = MonitorTag('m2', m1, @(x, y) y > 0);                    % outer — trivially same
% When st.updateData(X, Y) fires → notifyListeners_ → m1.invalidate()
% m1's cache is now dirty. Next getXY on m2 will cascade:
% m2.getXY → m2.recompute_ → m1.getXY (cache dirty → m1.recompute_) → parent.getXY
% Events fired by both m1 and m2 independently.
```

### Listener addition on SensorTag (additive edit pattern)
```matlab
% Source: CONTEXT.md + SensorTag.m:25-32 pattern
% NEW block to append to SensorTag.m (after line 165):

properties (Access = private)
    listeners_ = {}   % cell of handles implementing invalidate()
end

methods
    function addListener(obj, m)
        %ADDLISTENER Register a listener notified when underlying data changes.
        %   m must implement an invalidate() method. The listener is held
        %   by strong reference. To detach, either clear the listener
        %   cell manually or construct a fresh SensorTag.
        if ~ismethod(m, 'invalidate')
            error('SensorTag:invalidListener', ...
                'Listener must implement invalidate(); got %s.', class(m));
        end
        obj.listeners_{end+1} = m;
    end

    function updateData(obj, X, Y)
        %UPDATEDATA Replace inner Sensor X/Y and fire listeners.
        %   Additive API — does not touch load/toDisk/toMemory paths.
        obj.Sensor_.X = X;
        obj.Sensor_.Y = Y;
        obj.notifyListeners_();
    end
end

methods (Access = private)
    function notifyListeners_(obj)
        for i = 1:numel(obj.listeners_)
            obj.listeners_{i}.invalidate();
        end
    end
end
```

### TagRegistry dispatch extension
```matlab
% Source: libs/SensorThreshold/TagRegistry.m:343-356 — add ONE case:
switch kind
    case 'mock'
        tag = MockTag.fromStruct(s);
    case 'mockthrowingresolve'
        tag = MockTagThrowingResolve.fromStruct(s);
    case 'sensor'
        tag = SensorTag.fromStruct(s);
    case 'state'
        tag = StateTag.fromStruct(s);
    case 'monitor'                          % NEW — Phase 1006
        tag = MonitorTag.fromStruct(s);
    otherwise
        error('TagRegistry:unknownKind', ...
            'Unknown tag kind ''%s''. Valid kinds (Phase 1006): mock, sensor, state, monitor.', ...
            kind);
end
```

### FastSense.addTag extension
```matlab
% Source: libs/FastSense/FastSense.m:967-976 — add ONE case:
switch tag.getKind()
    case 'sensor'
        [x, y] = tag.getXY();
        obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
    case 'state'
        obj.addStateTagAsStaircase_(tag, varargin{:});
    case 'monitor'                          % NEW — Phase 1006
        [x, y] = tag.getXY();
        obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
    otherwise
        error('FastSense:unsupportedTagKind', ...
            'Unsupported tag kind ''%s''.', tag.getKind());
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Sensor.resolve()` writes ResolvedViolations implicitly via a batched MEX pipeline, events derived downstream by EventDetector.detect | `MonitorTag` is a first-class Tag subclass with lazy per-sample binary output, inline event emission, parent-driven invalidation | Phase 1006 (this phase) | Rendering layer + consumer widgets get a uniform Tag contract (addTag, getXY, valueAt) across sensor/state/monitor kinds. Legacy pipeline stays alive for Phase 1009 migration. |
| `ThresholdRule.matchesState` state-activation predicate over struct | `@(x, y) <logical>` function handle, user-supplied | Phase 1006 | Simpler for the common case; users who want state gating close over a StateTag explicitly. No loss of expressiveness. |
| `EventDetector.detect` batch pipeline using `groupViolations` + MinDuration + threshold value | MonitorTag's `recompute_` runs a near-identical pipeline inline, emitting directly to EventStore | Phase 1006 | One pass over the data vs. two (resolve → detect). Fewer temporary struct arrays. |

**Deprecated/outdated for Phase 1006 purposes:**
- `ResolvedViolations` as a first-class concept — demoted to legacy; not accessed by MonitorTag.
- `interp1('linear')` for Tag aggregation — banned (ALIGN-01); not accessed by MonitorTag. Already absent from all in-repo Tag code.

## Open Questions

None — all research areas resolved with concrete in-repo evidence. The following items were candidates for open questions but have documented resolutions:

1. **Q: Should MonitorTag's MinDuration be in seconds or native px units?** — **Resolved:** Native px units, matching EventDetector.MinDuration (EventDetector.m:49-54) and test_event_integration.m:34 precedent. Users on datenum parents pass `5/86400` for 5 sec. Documented in class header.
2. **Q: Event.TagKeys is in the MONITOR-05 spec but Event.m has no such field — what's the Phase-1006 interpretation?** — **Resolved:** Pitfall 5 above. Use existing `SensorName = parent.Key` + `ThresholdLabel = monitor.Key` carriers; Phase 1010 migrates to TagKeys.
3. **Q: Where exactly does `notifyListeners_` fire on SensorTag?** — **Resolved:** ONLY in the new `updateData(X, Y)` method. Other paths (load/toDisk/toMemory) stay additive-free in Phase 1006; Phase 1009 migration can extend.
4. **Q: Strong or weak refs for listeners?** — **Resolved:** Strong refs; document lifecycle contract in class header. (Pitfall 4.)
5. **Q: Is a condition-fn probe in the ctor safe?** — **Resolved:** Probe with `[0 1], [0 0]` in a try/catch; if the probe errors, skip validation and trust user. Documented in §3.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework (MATLAB) | `matlab.unittest.TestCase` — classes under `tests/suite/Test*.m` |
| Framework (Octave) | Flat function-based tests `test_*.m` under `tests/` |
| Config file | None — discovery via `tests/run_all_tests.m` |
| Quick run command (Octave) | `octave --no-gui --eval "install(); test_monitortag(); test_monitortag_events(); test_tag_registry();"` |
| Quick run command (MATLAB) | `matlab -batch "install(); run_all_tests();"` (or targeted `TestSuite.fromClass('TestMonitorTag')`) |
| Full suite command | `octave --no-gui --eval "install(); run_all_tests();"` — expects 0 failures |
| Regression gate | Existing `test_golden_integration()` remains GREEN (Phase 1004 Pitfall 11 lock) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| MONITOR-01 | MonitorTag(key, parent, fn) → getXY binary 0/1 | unit | `test_monitortag()` — testBasicConstruction + testGetXYBinary | ❌ Wave 0 |
| MONITOR-02 | isa(m,'Tag'); FastSense.addTag(m); TagRegistry registerable; recursive | unit + round-trip | `test_monitortag()` — testIsaTag + testAddTagDispatch + testRecursiveMonitor + `test_tag_registry()` testRoundTripMonitorTag | ❌ Wave 0 |
| MONITOR-03 | Lazy memoize; first call computes, subsequent returns cache | unit | `test_monitortag()` — testLazyMemoize (probe `recomputeCount_` via internal counter OR measure timing) | ❌ Wave 0 |
| MONITOR-04 | parent.updateData(X,Y) → monitor cache invalidated | unit | `test_monitortag()` — testInvalidateOnParentUpdate | ❌ Wave 0 |
| MONITOR-05 | 0→1 transitions → Event → EventStore.append; TagKeys = {monitor.Key, parent.Key} (carrier: SensorName + ThresholdLabel pre-Phase 1010) | unit + integration | `test_monitortag_events()` — testEventOnRisingEdge + assert store.getEvents()(1).SensorName == parent.Key | ❌ Wave 0 |
| MONITOR-06 | MinDuration=5 filters 2-sec violation, keeps 6-sec violation | unit | `test_monitortag_events()` — testMinDurationDebounce (both pos+neg) | ❌ Wave 0 |
| MONITOR-07 | Hysteresis: sinusoid near threshold → 1 rising edge (not 5+) | unit | `test_monitortag_events()` — testHysteresisNoChatter | ❌ Wave 0 |
| MONITOR-10 | No per-sample callbacks in MonitorTag API | grep-gate | `grep -cE "PerSample\|OnSample\|onEachSample" libs/SensorThreshold/MonitorTag.m` == 0 | ❌ Wave 0 |
| ALIGN-01 | No interp1('linear') in MonitorTag | grep-gate | `grep -c "interp1.*'linear'" libs/SensorThreshold/MonitorTag.m` == 0 | ❌ Wave 0 |
| ALIGN-02 | Union-of-timestamps — trivial single-parent case | unit | `test_monitortag()` — testGetXYAlignedToParentGrid | ❌ Wave 0 |
| ALIGN-03 | Pre-history drop idiom documented + example test | unit | `test_monitortag()` — testPreHistoryDropPattern | ❌ Wave 0 |
| ALIGN-04 | NaN in parent.Y → 0 in MonitorTag binary (IEEE 754) | unit | `test_monitortag()` — testNaNInParentY | ❌ Wave 0 |
| Pitfall 9 | 12-widget tick ≤ 110% legacy | bench | `bench_monitortag_tick()` asserts overhead_pct <= 10; prints `PASS: <= 10%% regression gate satisfied.` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `octave --no-gui --eval "install(); test_monitortag(); test_monitortag_events(); test_tag_registry();"` (< 10 sec wall-time)
- **Per wave merge:** Full Octave suite `octave --no-gui --eval "install(); run_all_tests();"` — includes golden integration test (regression guard)
- **Phase gate:** Full suite green AND `bench_monitortag_tick()` PASS AND all five grep gates pass before `/gsd:verify-work`:
  - `grep -c "FastSenseDataStore" libs/SensorThreshold/MonitorTag.m` == 0 (Pitfall 1)
  - `grep -c "methods (Abstract)" libs/SensorThreshold/MonitorTag.m` == 0
  - `grep -cE "PerSample\|OnSample\|onEachSample" libs/SensorThreshold/MonitorTag.m` == 0 (MONITOR-10)
  - `grep -c "interp1.*'linear'" libs/SensorThreshold/MonitorTag.m` == 0 (ALIGN-01)
  - `grep -c "classdef MonitorTag < Tag" libs/SensorThreshold/MonitorTag.m` == 1

### Wave 0 Gaps
- [ ] `libs/SensorThreshold/MonitorTag.m` — production class — covers MONITOR-01..07, MONITOR-10, ALIGN-01..04 (net-new, no prior file)
- [ ] `libs/SensorThreshold/SensorTag.m` edit — additive listener surface — covers MONITOR-04 parent-side hook
- [ ] `libs/SensorThreshold/StateTag.m` edit — additive listener surface — covers MONITOR-04 parent-side hook (when StateTag is parent)
- [ ] `libs/SensorThreshold/TagRegistry.m` edit — case 'monitor' in instantiateByKind — covers round-trip (MONITOR-02)
- [ ] `libs/FastSense/FastSense.m` edit — case 'monitor' in addTag — covers MONITOR-02 plotting
- [ ] `tests/suite/TestMonitorTag.m` — MATLAB unittest class (construction, lazy, invalidation, recursion, NaN, ALIGN)
- [ ] `tests/test_monitortag.m` — Octave flat mirror
- [ ] `tests/suite/TestMonitorTagEvents.m` — MATLAB unittest class (MinDuration, hysteresis, event-firing, TagKeys-carrier check)
- [ ] `tests/test_monitortag_events.m` — Octave flat mirror
- [ ] `benchmarks/bench_monitortag_tick.m` — Pitfall 9 gate harness (tic/toc, median of 3, overhead_pct assertion)
- [ ] `tests/suite/TestTagRegistry.m` extension — `testRoundTripMonitorTag` (forward + reverse order)
- [ ] `tests/test_tag_registry.m` extension — matching Octave assertion

*No shared fixtures file needed — each test stands alone like `test_sensortag.m` / `test_statetag.m`.*
*No framework install required — MATLAB's unittest and Octave's function-based tests are already in use.*

## Sources

### Primary (HIGH confidence — verified against in-repo source)
- `libs/SensorThreshold/Tag.m:62-157` — Tag contract (6 abstracts, resolveRefs hook at line 142-147)
- `libs/SensorThreshold/TagRegistry.m:275-357` — Two-phase loadFromStructs + instantiateByKind dispatch
- `libs/SensorThreshold/SensorTag.m:25-252` — Composition wrapper pattern (private Sensor_, splitArgs_, toStruct, fromStruct)
- `libs/SensorThreshold/StateTag.m:36-219` — Direct parent storage pattern (public X/Y, splitArgs_)
- `libs/SensorThreshold/Sensor.m:315-560` — Legacy resolve() pipeline (what MonitorTag replaces)
- `libs/SensorThreshold/Threshold.m:1-196` — Legacy Threshold (reference for condition-value pair shape; not used directly)
- `libs/SensorThreshold/ThresholdRule.m:119-163` — Legacy matchesState activation predicate (reference)
- `libs/SensorThreshold/private/alignStateToTime.m:43` — Only extant `interp1` usage (ZOH via `'previous'`; confirms no `'linear'` anywhere in libs)
- `libs/SensorThreshold/private/compute_violations_batch.m:73-108` — Pure-MATLAB batch-violation loop pattern (reference for performance baseline)
- `libs/EventDetection/Event.m:1-70` — Event class shape (constructor signature, DIRECTIONS, setStats)
- `libs/EventDetection/EventStore.m:25-73` — append + atomic save pattern
- `libs/EventDetection/EventDetector.m:31-87` — MinDuration filter algorithm
- `libs/EventDetection/IncrementalEventDetector.m:31-175` — Streaming reference (Phase 1007 scope)
- `libs/EventDetection/LiveEventPipeline.m:86-145` — Live-tick structure (benchmark reference)
- `libs/EventDetection/detectEventsFromSensor.m:1-66` — Bridge between resolve and detect (reference for SensorName convention at line 14-19)
- `libs/EventDetection/private/groupViolations.m:20-30` — Run-finding via `diff([0, bin, 0])` — MonitorTag inline port target
- `libs/FastSense/FastSense.m:943-1006` — addTag dispatcher + staircase helper (extension target)
- `benchmarks/bench_sensortag_getxy.m:1-50` — Phase 1005-03 benchmark harness pattern (median-of-3, warmup, tic/toc, falsifiable assertion)
- `tests/suite/MockTag.m:1-50` — Mock Tag pattern (can be used as Pass-1 placeholder if desired)
- `tests/test_event_integration.m:1-56` — Event integration test precedent (reference for bench/test data shapes)
- `tests/test_event_detector.m:48-56` — Debounce test pattern (reference)
- `.planning/phases/1004-tag-foundation-golden-test/1004-0{1,2,3}-SUMMARY.md` — Tag + TagRegistry + golden test contract
- `.planning/phases/1005-sensortag-statetag-data-carriers/1005-0{1,2,3}-SUMMARY.md` — SensorTag + StateTag + FastSense.addTag pattern locked
- `.planning/REQUIREMENTS.md` — Full milestone scope, ALIGN requirements, forbidden stack additions (events/listeners blocks explicitly)
- `.planning/ROADMAP.md` §Phase 1006 — success criteria, verification gates
- `.planning/phases/1006-monitortag-lazy-in-memory/1006-CONTEXT.md` — Locked decisions (class skeleton, file organization, error IDs)
- `./CLAUDE.md` — Project tech stack, runtime targets, naming conventions, error ID conventions
- `./.planning/config.json` — `workflow.nyquist_validation: true` — validation section required

### Secondary (MEDIUM confidence)
- None — no external-source findings required. All decisions traced to in-repo files.

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries/classes are in-repo and already exercised by Phase 1004/1005 green tests.
- Architecture: HIGH — class skeleton is locked in CONTEXT.md; only implementation details remain (exact event-constructor arg order, exact grep-gate wording); each has a documented resolution.
- Pitfalls: HIGH — 9 pitfalls enumerated with concrete verification gates (grep commands, test assertions, benchmark numbers).
- Environment: HIGH — no new external dependencies; MATLAB R2020b+ / Octave 7+ already validated.

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (30 days — Tag domain is stable; no other phase will alter Tag / TagRegistry / Event / EventStore contracts during this window, per ROADMAP sequencing).

---

## Project Constraints (from CLAUDE.md)

Directives extracted from `./CLAUDE.md` that constrain Phase 1006 planning:

### Required Tech Stack
- **MATLAB R2020b+** is the primary target; **GNU Octave 7+** is fully supported (tested locally at 11.1.0). Any MonitorTag feature must be green on both runtimes.
- **Pure MATLAB — no external toolboxes** (Frameworks: "No external MATLAB toolboxes required — all functionality is toolbox-free"). MonitorTag cannot depend on Control System Toolbox, Signal Processing Toolbox, or any other add-on.
- **No new MEX kernels** (REQUIREMENTS.md explicit: "New MEX kernels for tag aggregation (`all`/`any`/`sum` is sub-millisecond at typical N)" is forbidden). MonitorTag's hot path is pure MATLAB.

### Forbidden Patterns (from REQUIREMENTS.md "Stack additions explicitly forbidden")
- `dictionary` (R2022b+; not in Octave 11) — use `containers.Map` (TagRegistry pattern)
- `matlab.mixin.Heterogeneous` / `matlab.mixin.Copyable` / `matlab.mixin.SetGet` — Octave-incomplete
- `enumeration` blocks — parsed-no-op on Octave; use constant class property or char validation (Tag.Criticality pattern at Tag.m:101-110)
- `events` / listeners blocks — **parsed-no-op on Octave**; use manual `listeners_` cell + `notifyListeners_()` method (see §5)
- `arguments` blocks — patchy on Octave; use `for i=1:2:numel(varargin)` NV-pair parsing (Tag.m:85-98 pattern)
- No JSON-schema validators — `toStruct`/`fromStruct` + `isfield` checks sufficient
- No new persistence backend — FastSenseDataStore already handles SQLite for the same data shape (and is Phase 1007 scope, not 1006)

### Naming Conventions
- Classes: PascalCase (`MonitorTag`)
- Methods: camelCase (`addListener`, `updateData`, `notifyListeners_`)
- Error IDs: `ClassName:camelCaseProblem` — `MonitorTag:invalidParent`, `MonitorTag:invalidCondition`, `MonitorTag:unknownOption`, `MonitorTag:dataMismatch`, `MonitorTag:unresolvedParent`, `SensorTag:invalidListener`, `StateTag:invalidListener`
- Private-implementation properties: trailing underscore (`listeners_`, `cache_`, `dirty_`, `ParentKey_`)
- Public properties: PascalCase (`Parent`, `ConditionFn`, `AlarmOffConditionFn`, `MinDuration`, `EventStore`, `OnEventStart`, `OnEventEnd`)
- Boolean flags as properties: `Is` prefix (`IsActive`, `IsRendered` precedent) — MonitorTag doesn't need any public boolean; `dirty_` is private.

### Testing Rules
- Dual-style shipping: MATLAB `matlab.unittest.TestCase` in `tests/suite/TestMonitorTag.m` AND Octave flat-function `tests/test_monitortag.m` — both auto-discovered by `tests/run_all_tests.m`. Phase 1005 precedent at tests/test_sensortag.m + tests/suite/TestSensorTag.m.
- TestMethodSetup + TestMethodTeardown both call `TagRegistry.clear()` for isolation (TagRegistry.m pattern).
- Tests are in `tests/` (flat) and `tests/suite/` (class-based). Naming: `TestMonitorTag.m` (PascalCase) / `test_monitortag.m` (snake_case).
- Every test must add paths: `function add_monitortag_path() ... addpath(repo_root); install(); end` (test_sensortag.m:46-50 pattern).
- Each commit should keep `tests/run_all_tests.m` green; partial-migration is not allowed.

### Security / Data Discipline
- No `ANTHROPIC_API_KEY` usage (dev/scripts dependency only).
- No files written to disk during MonitorTag operation (Pitfall 1).
- No environment variables consumed by MonitorTag.

### GSD Workflow Enforcement
- File edits must route through `/gsd:execute-phase` (or `/gsd:quick`/`/gsd:debug` for unrelated fixes). Phase 1006 will be executed via `/gsd:execute-phase` after this RESEARCH.md is consumed by `gsd-planner`.

---

## RESEARCH COMPLETE

**Phase:** 1006 — MonitorTag (lazy, in-memory)
**Confidence:** HIGH across all areas
**File budget:** 12 files (at cap; 10 is achievable by deferring TagRegistry round-trip tests to Phase 1009)
**Pitfall gates documented:** 9 (Pitfalls 1-9 above)
**Open questions:** 0 — all research areas resolved with concrete in-repo evidence.
**Ready for planning:** YES — gsd-planner can proceed to write PLAN.md files against this research.
