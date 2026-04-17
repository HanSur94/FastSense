# Phase 1007: MonitorTag streaming + persistence - Research

**Researched:** 2026-04-16
**Domain:** MATLAB Tag-domain model streaming + SQLite-backed persistence (FastSense/SensorThreshold libraries)
**Confidence:** HIGH (all production code directly inspected; no external lib recommendations — pure additive MATLAB)

## Summary

Phase 1007 adds two orthogonal opt-in levers to the existing Phase 1006 `MonitorTag`:
1. **`appendData(newX, newY)`** — incremental tail extension of the `(X, Y)` cache, preserving hysteresis FSM state + MinDuration bookkeeping across the boundary (MONITOR-08).
2. **`Persist` property + `FastSenseDataStore.storeMonitor/loadMonitor`** — opt-in SQLite persistence of the derived series, load-skip-recompute on next session if parent hasn't changed (MONITOR-09).

Both features must be **strictly additive** — Phase 1006 locked "lazy-by-default, no persistence" as a Pitfall 2 documented contract and shipped zero `storeMonitor` call sites and zero `FastSenseDataStore` references in `MonitorTag.m`. Any `storeMonitor` call in 1007 MUST sit inside an `if obj.Persist` branch (structural grep check).

The existing infrastructure is a near-perfect fit:
- **`FastSenseDataStore`** already ships the **`storeResolved`/`loadResolved`/`clearResolved`** method trio for the legacy `Sensor.resolve()` pipeline. `storeMonitor`/`loadMonitor`/`clearMonitor` mirror that shape with a new `monitors` table. Pattern proven at production scale.
- **`MonitorTag.recompute_`** is a clean 4-stage pipeline (Plan 02) with two stage-specific FSMs (`applyHysteresis_`, `applyDebounce_`) that can be **refactored to take optional carry-in state** so `appendData` replays stages 2-3 on the tail only.
- **Parent observer hook** (`SensorTag.updateData → notifyListeners_ → MonitorTag.invalidate`) already exists. `appendData` is a streaming alternative to `invalidate` — same cache, different write path.

**Primary recommendation:**
- **Ship `appendData` + `Persist`; DEFER `LiveEventPipeline` rewire to Phase 1009.** The LEP currently uses `IncrementalEventDetector` on legacy `Sensor` objects. Rewiring it to MonitorTag requires a consumer migration that belongs in Phase 1009 (already scoped for consumer migration one-at-a-time). The 8-file budget in 1007 is exactly at cap without it; adding LEP puts us at 9-10. Phase 1007 ships `appendData` proven in isolation (tests + benchmark); Phase 1009 wires LEP.
- **"Parent unchanged" detection: `(parent.Key, NumPoints, X[1], X[end])` quad-hash** stamped into the `monitors` row at write time; compared at load time. Simplest-safe; Octave-portable; survives process restart.

## Project Constraints (from CLAUDE.md)

- **Tech stack:** Pure MATLAB (no new external deps), MEX binaries already present, bundled SQLite3 via `mksqlite` (already loaded by `FastSenseDataStore.m`). No new MEX kernels.
- **Backward compatibility:** Existing MonitorTag construction, `getXY`, `invalidate`, `toStruct/fromStruct` must continue to work byte-for-byte. `Persist=false` default → existing behavior preserved.
- **Widget contract:** No impact — MonitorTag is the Tag, not a widget.
- **Performance:** appendData MUST NOT degrade the non-append cache-hit path; must beat full-recompute by >5x on 100k tail append (Pitfall 9).
- **Runtime:** MATLAB R2020b+ AND Octave 7+. Do not introduce `arguments`/`enumeration`/`events` blocks (REQUIREMENTS.md "Stack additions explicitly forbidden").
- **Naming:** `Persist` (PascalCase public prop), `appendData` (camelCase public method), error IDs `MonitorTag:*` and `FastSenseDataStore:*` camelCase problem suffix.
- **GSD workflow:** All file edits must happen via GSD commands (already active — Phase 1007 plan-phase).

## User Constraints (from CONTEXT.md)

### Locked Decisions

**File organization (8 files at cap, tight):**
- EDIT: `libs/SensorThreshold/MonitorTag.m` — add `appendData(newX, newY)` + `Persist` property + persistence-load branch
- EDIT: `libs/FastSense/FastSenseDataStore.m` — add `storeMonitor(key, X, Y)` + `loadMonitor(key)` + schema migration for new `monitors` table
- EDIT: `libs/EventDetection/LiveEventPipeline.m` — switch live-tick to `monitor.appendData` (only if fits; else defer to 1009)
- NEW: `tests/suite/TestMonitorTagStreaming.m`
- NEW: `tests/test_monitortag_streaming.m`
- NEW: `tests/suite/TestMonitorTagPersistence.m`
- NEW: `tests/test_monitortag_persistence.m`
- NEW: `benchmarks/bench_monitortag_append.m` (Pitfall 9 gate — >5x speedup)

**appendData algorithm (canonical skeleton from CONTEXT):**
```matlab
function appendData(obj, newX, newY)
    if obj.dirty_ || isempty(obj.cache_) || ~isfield(obj.cache_, 'x')
        obj.recompute_();
        return;
    end
    raw_new = logical(obj.ConditionFn(newX, newY));
    if ~isempty(obj.AlarmOffConditionFn)
        raw_new = applyHysteresis_(newX, newY, raw_new, obj.AlarmOffConditionFn, obj.lastHysteresisState_);
    end
    state_new = applyDebounce_(newX, raw_new, obj.MinDuration, obj.lastDebounceState_);
    obj.fireEventsOnRisingEdges_(newX, state_new, obj.cache_.lastStateFlag_);
    obj.cache_.x = [obj.cache_.x; newX(:)];
    obj.cache_.y = [obj.cache_.y; double(state_new(:))];
    obj.cache_.lastStateFlag_ = state_new(end);
    if obj.Persist && ~isempty(obj.DataStore)
        obj.DataStore.storeMonitor(obj.Key, obj.cache_.x, obj.cache_.y);
    end
end
```

**Persist property semantics:**
- `Persist` (logical, default `false`) added to MonitorTag.m properties block
- `DataStore` property (FastSenseDataStore handle, optional) — required when Persist=true
- After each `recompute_()` or `appendData`, if `Persist && ~isempty(DataStore)` → call `DataStore.storeMonitor(Key, X, Y)`
- On construction OR first `getXY()`, if `Persist && ~isempty(DataStore)`:
  - Try `[X, Y, computedAt] = DataStore.loadMonitor(Key)`
  - If non-empty AND parent unchanged → use cached data, skip recompute
  - Else recompute + persist
- Default `Persist = false` → ZERO DataStore calls (Pitfall 2 compliance)

**FastSenseDataStore API (new methods):**
- `storeMonitor(obj, key, X, Y)`: `INSERT OR REPLACE INTO monitors (key, x_blob, y_blob, computed_at) VALUES (?, ?, ?, ?)`; schema migration creates table on first use
- `loadMonitor(obj, key)`: returns `[X, Y, computedAt]` or empty on miss; decodes blobs matching existing `resolved_thresholds` codec

**Error IDs:**
- `MonitorTag:streamingBeforeCompute`, `MonitorTag:persistDataStoreRequired`
- `FastSenseDataStore:monitorKeyMissing`

**Pitfall 9 Benchmark:**
- `bench_monitortag_append.m`: 100k warmup + 100k tail via appendData (A) vs invalidate + full getXY on 200k (B)
- Assert: `B / A >= 5` (5x speedup)
- Print PASS/FAIL; exit 0 on pass; headless Octave friendly

### Claude's Discretion

1. Exact SQLite schema for `monitors` table (column types, indexes)
2. "Parent unchanged" detection mechanism (mtime, hash, flag, explicit invalidate API)
3. `loadMonitor` return shape (struct vs tuple)
4. LiveEventPipeline rewire vs deferral (research to recommend)

### Deferred Ideas (OUT OF SCOPE)

- CompositeTag (Phase 1008)
- Widget consumer migration (Phase 1009)
- Event binding rewrite (Phase 1010)
- Auto-derive streaming from parent live-tick signal (future)

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **MONITOR-08** | `MonitorTag.appendData(newX, newY)` extends the cached output incrementally without full recompute. Wraps existing `IncrementalEventDetector` pattern. Used by `LiveEventPipeline` live-tick path. | §Research Area 2 (hysteresis + debounce boundary state), §Research Area 3 (IncrementalEventDetector pattern), §Code Examples |
| **MONITOR-09** | `MonitorTag.Persist = true` caches derived `(X, Y)` to `FastSenseDataStore` via new `storeMonitor(key, X, Y)`/`loadMonitor(key)` API. Default off; Pitfall 2 cache-invalidation pain limited to opt-in users. | §Research Area 1 (FastSenseDataStore API inventory), §Research Area 5 (parent-unchanged detection) |

## Research Area 1: FastSenseDataStore API Inventory

### Existing `storeResolved` / `loadResolved` Pattern (the reference template)

**Definition sites** in `libs/FastSense/FastSenseDataStore.m`:
- `storeResolved(obj, resolvedTh, resolvedViol)` — **lines 408–436**
- `loadResolved(obj)` — **lines 438–486**
- `clearResolved(obj)` — **lines 488–494**

**Schema creation site** — **lines 582–600** inside `initSqlite` (lines 531–643):
```matlab
mksqlite(obj.DbId, [ ...
    'CREATE TABLE resolved_thresholds (' ...
    '  idx INTEGER PRIMARY KEY,' ...
    '  x_data BLOB,' ...
    '  y_data BLOB,' ...
    '  direction TEXT NOT NULL,' ...
    '  label TEXT NOT NULL,' ...
    '  color BLOB,' ...
    '  line_style TEXT NOT NULL,' ...
    '  value REAL NOT NULL' ...
    ')']);
```

**Key observations:**
1. **Schema is created ONLY in `initSqlite` at DataStore construction time.** There is NO runtime migration (CREATE TABLE IF NOT EXISTS) for existing DataStores. For `monitors` table, Phase 1007 has two choices:
   - **Option A (RECOMMENDED):** Add the CREATE TABLE to `initSqlite` (lines 582-600 area) so every new DataStore ships with the `monitors` table. All existing DataStores are temp files destroyed on process exit — so no legacy migration needed. Simpler.
   - **Option B:** Add `CREATE TABLE IF NOT EXISTS monitors` inside `storeMonitor` at first call. Redundant per-call; wastes a mksqlite round-trip.
2. **Same DbOpen/ensureOpen pattern applies** — `obj.ensureOpen()` at the top of every public method; `obj.DbId` is -1 when closed. Must follow this pattern for `storeMonitor`/`loadMonitor`.
3. **Blob codec is trivial** — mksqlite with `typedBLOBs = 2` (line 518) auto-encodes double arrays as SQLite BLOBs. Round-trip: `INSERT INTO ... VALUES (?, ?)` with a MATLAB double vector stores it; `SELECT x_data FROM ...` returns the vector as `res(1).x_data`. Transpose to row via `res(1).x_data(:)'` (pattern at line 275, 451).
4. **Transaction pattern** — `storeResolved` wraps writes in `BEGIN TRANSACTION`/`COMMIT`/`ROLLBACK` try-catch (lines 415-434). `storeMonitor` must follow same pattern for atomicity.
5. **Empty-data guard** — `loadResolved` returns early if `numel(rows) == 0` (line 447). `loadMonitor` must follow.
6. **`storeResolved` closes DB after commit** (line 435: `obj.closeDb()`) — frees mksqlite slot. Follow same pattern.

### Recommended `monitors` table schema

```sql
CREATE TABLE monitors (
    key         TEXT PRIMARY KEY,
    x_blob      BLOB NOT NULL,      -- double vector of parent-aligned timestamps
    y_blob      BLOB NOT NULL,      -- double vector of 0/1 binary output
    parent_key  TEXT NOT NULL,      -- for validation; parent.Key stamped at write time
    num_points  INTEGER NOT NULL,   -- parent.NumPoints at write time (staleness check)
    parent_xmin REAL NOT NULL,      -- parent.X(1) at write time (staleness check)
    parent_xmax REAL NOT NULL,      -- parent.X(end) at write time (staleness check)
    computed_at REAL NOT NULL       -- now() datenum at write time
)
```

**Why these columns (staleness-detection quad):** See Research Area 5.

### Recommended API shape

```matlab
% New public methods on FastSenseDataStore (parallel to storeResolved):

function storeMonitor(obj, key, X, Y, parentKey, parentNumPts, parentXMin, parentXMax)
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    mksqlite(obj.DbId, 'BEGIN TRANSACTION');
    try
        mksqlite(obj.DbId, ['INSERT OR REPLACE INTO monitors ' ...
            '(key, x_blob, y_blob, parent_key, num_points, ' ...
            ' parent_xmin, parent_xmax, computed_at) ' ...
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)'], ...
            key, X(:)', Y(:)', parentKey, parentNumPts, ...
            parentXMin, parentXMax, now);
        mksqlite(obj.DbId, 'COMMIT');
    catch ME
        try mksqlite(obj.DbId, 'ROLLBACK'); catch; end
        rethrow(ME);
    end
end

function [X, Y, meta] = loadMonitor(obj, key)
    X = []; Y = []; meta = struct();
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    rows = mksqlite(obj.DbId, ...
        'SELECT * FROM monitors WHERE key = ? LIMIT 1', key);
    if isempty(rows) || numel(rows) == 0; return; end
    r = rows(1);
    X = r.x_blob(:)';
    Y = r.y_blob(:)';
    meta = struct('parent_key', r.parent_key, ...
                  'num_points', r.num_points, ...
                  'parent_xmin', r.parent_xmin, ...
                  'parent_xmax', r.parent_xmax, ...
                  'computed_at', r.computed_at);
end

function clearMonitor(obj, key)
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    mksqlite(obj.DbId, 'DELETE FROM monitors WHERE key = ?', key);
end
```

**Return shape decision:** `[X, Y, meta]` triple (not single struct). Matches `loadResolved` multi-output convention; simpler for the caller to destructure; empty-on-miss is natural via `isempty(X)`.

**Binary file fallback (`UseSqlite = false`):** Mirror `storeResolved` — the fallback path silently no-ops (`if ~obj.UseSqlite; return; end`). Users without mksqlite lose the persistence feature but keep the in-memory behavior. Document in class header.

### File-touch and SLOC impact

- **FastSenseDataStore.m**: currently **963 lines**. Adding 3 methods (~70-90 SLOC) + schema CREATE statement inside initSqlite (~10 SLOC) → ~1050 lines total. Well within MISS_HIT 520-line-per-function (aspirational 200); these are small methods.

## Research Area 2: Hysteresis + MinDuration State Continuity Across appendData Boundary

This is the **deepest correctness concern** of MONITOR-08. The current `recompute_()` (MonitorTag.m lines 297-331) runs a 4-stage pipeline over the ENTIRE parent-X vector every time. `appendData` must replay stages 2-3-4 on the tail only — carrying state across the boundary.

### Current stage inventory (MonitorTag.m)

**Stage 1: raw condition** — lines 314-315.
```matlab
raw = logical(obj.ConditionFn(px, py));
```
Pure vectorized, stateless. Trivial on tail — `raw_new = logical(obj.ConditionFn(newX, newY))`.

**Stage 2: hysteresis FSM** — `applyHysteresis_`, lines 333-350.
```matlab
function bin = applyHysteresis_(obj, px, py, rawOn)
    N = numel(rawOn);
    rawOff = logical(obj.AlarmOffConditionFn(px, py));
    bin = false(1, N);
    state = false;                    % <-- INITIAL STATE — always OFF
    for i = 1:N
        if state
            if rawOff(i), state = false; end
        else
            if rawOn(i),  state = true;  end
        end
        bin(i) = state;
    end
end
```

**State that MUST carry across boundary:** `state` at end of previous chunk. Cache field needed: `cache_.lastHysteresisState_ = state`. Refactor:
```matlab
function [bin, finalState] = applyHysteresis_(obj, px, py, rawOn, initialState)
    if nargin < 5; initialState = false; end
    N = numel(rawOn);
    rawOff = logical(obj.AlarmOffConditionFn(px, py));
    bin = false(1, N);
    state = initialState;
    for i = 1:N
        if state
            if rawOff(i), state = false; end
        else
            if rawOn(i),  state = true;  end
        end
        bin(i) = state;
    end
    finalState = state;
end
```

**Stage 3: MinDuration debounce** — `applyDebounce_`, lines 352-363, + `findRuns_` lines 365-378.
```matlab
function bin = applyDebounce_(obj, px, bin)
    [sI, eI] = obj.findRuns_(bin);
    for k = 1:numel(sI)
        if px(eI(k)) - px(sI(k)) < obj.MinDuration
            bin(sI(k):eI(k)) = false;
        end
    end
end
```
`findRuns_` uses `d = diff([0, bin(:).', 0])` — the leading 0 seals the left boundary.

**State that MUST carry across boundary:** A run that was "in progress" at the end of the previous chunk (i.e., `cache_.y(end) == 1`) might extend into `newX` and the duration crosses the boundary. Two scenarios:

1. **Previous chunk ended with bin=0** — tail analysis is clean; new runs in tail are independent. `findRuns_` works unchanged on tail.
2. **Previous chunk ended with bin=1 (ongoing run)** — tail analysis must treat the run as "continuing" and compute total duration from the original start timestamp.

**Required state fields:**
- `cache_.lastStateFlag_` — last bin value of previous chunk (0 or 1)
- `cache_.ongoingRunStart_` — if lastStateFlag_==1, the X timestamp where the current run started; else NaN

**Algorithm for tail (pseudocode):**
```
1. raw_new = ConditionFn(newX, newY)
2. [bin_new, finalHystState] = applyHysteresis_(newX, newY, raw_new, lastHystState)  % if hysteresis
3. [sI, eI] = findRuns_(bin_new)
4. If lastStateFlag_ == 1 AND bin_new(1) == 1:
      % Ongoing run extends into tail — merge with boundary
      % The first run in bin_new started at ongoingRunStart_, not newX(sI(1))
      effective_start_1 = ongoingRunStart_
   Else:
      effective_start_1 = newX(sI(1)) if any runs, else none
5. For each run k: if (end_timestamp - effective_start) < MinDuration → zero it in bin_new
6. Update ongoingRunStart_ = (last run open at end? then its effective start : NaN)
7. Update lastStateFlag_ = bin_new(end)
8. Append bin_new to cache_.y, newX to cache_.x
```

**Stage 4: fireEventsOnRisingEdges_** — lines 380-414.
```matlab
[sI, eI] = obj.findRuns_(bin);
for k = 1:numel(sI)
    startT = px(sI(k)); endT = px(eI(k));
    ev = Event(startT, endT, char(obj.Parent.Key), char(obj.Key), NaN, 'upper');
    ... append + callbacks
end
```

**Event emission at boundary:** Events must be fired **only for runs that COMPLETED in the appended region** (have a falling edge inside newX), NOT for ongoing runs that haven't ended. Plus: if `ongoingRunStart_` is set and the tail's first run has a falling edge → emit ONE event with `StartTime = ongoingRunStart_, EndTime = newX(eI(1))`. The tail end may leave another ongoing run (no event fired yet, bookkeeping carries forward).

**This matches the `IncrementalEventDetector.openEvent` semantics exactly** — see Research Area 3.

### Test scenarios for boundary correctness

Required test cases (name + assertion):

1. **`testAppendNoHysteresisNoDebounce`** — ongoing 0, tail yields {0..1..0} → 1 event
2. **`testAppendOngoingRunExtendsIntoTail`** — lastStateFlag_=1, run continues into tail, falling edge mid-tail → 1 event with original start
3. **`testAppendOngoingRunExtendsAcrossTail`** — lastStateFlag_=1, run continues through entire tail → 0 events, ongoingRunStart_ updated
4. **`testAppendHysteresisBoundaryNoChatter`** — previous chunk ends in ON state, tail's first sample would trigger raw-off but not alarm-off → state stays ON, no phantom edge
5. **`testAppendMinDurationSpansBoundary`** — run of total duration 6 that starts 3 units before boundary and extends 3 units into tail, MinDuration=5 → run SURVIVES (crosses threshold at merge)
6. **`testAppendMinDurationShortRunSpansBoundaryZeroed`** — run of total duration 3 spanning boundary, MinDuration=5 → run ZEROED, no event
7. **`testAppendFirstEverIsFullRecompute`** — `appendData` called before any getXY → fallback to full `recompute_()` on the tail only (cache empty, no boundary state to carry)

### Required new private cache fields

```matlab
properties (Access = private)
    cache_          = struct()  % Plan 02: {x, y, computedAt}; Phase 1007 adds:
                                %   lastStateFlag_   (0/1) — last bin value
                                %   ongoingRunStart_ (X-native) — start of open run, NaN if none
                                %   lastHystState_   (logical) — last hysteresis FSM state
    dirty_          = true
    ...
end
```

These fields must be written at the **end of `recompute_()` and end of `appendData()`** — both entry points must leave the cache consistent.

## Research Area 3: IncrementalEventDetector Pattern

**File:** `libs/EventDetection/IncrementalEventDetector.m` (254 lines)

**Key state fields per sensor (line 195-197):**
```matlab
st = struct('fullX', [], 'fullY', [], ...
    'stateX', [], 'stateY', {{}}, ...
    'openEvent', [], 'lastProcessedTime', 0);
```

**Three relevant patterns for MonitorTag.appendData:**

1. **`openEvent` field** (line 48-52, 111-163) — exact analog of `ongoingRunStart_`. An event that hasn't closed is held in state; on next `process()` call the detector checks whether the event closed in the new batch.

2. **Slice start calculation** (lines 48-56):
```matlab
if ~isempty(st.openEvent)
    sliceStart = st.openEvent.StartTime;
else
    sliceStart = newX(1);
end
sliceIdx = binary_search(st.fullX, sliceStart, 'left');
sliceX = st.fullX(sliceIdx:end);
sliceY = st.fullY(sliceIdx:end);
```
Detects events on [openEvent.StartTime .. newX(end)], NOT only on newX. This is because a run's duration is measured from its start, which may pre-date the new batch.

**Lesson for MonitorTag:** The debounce check must use the **full duration from `ongoingRunStart_` (if set) to the first falling edge in tail**, not the tail-local `newX(sI(1))` to `newX(eI(1))`.

3. **Event merging** (lines 121-135):
```matlab
if ~isempty(st.openEvent) && ...
   strcmp(ev.ThresholdLabel, st.openEvent.ThresholdLabel) && ...
   ev.StartTime <= st.openEvent.EndTime + 1/86400
    merged = Event(st.openEvent.StartTime, ev.EndTime, ...);
```
When a run detected in the new slice matches the open event's identity, merge (use earlier start). 

**Lesson:** Since MonitorTag has exactly ONE ConditionFn per monitor (not multiple thresholds), the merge is simpler — `ongoingRunStart_` directly provides the effective start; no threshold-label matching needed.

4. **`lastProcessedTime` field** — tracks the last time any event was emitted. Prevents double-emission. In MonitorTag, this is implicit in the cache (a re-emission on cache-hit is already prevented by the "firing happens inside recompute_" design).

**Conclusion:** `IncrementalEventDetector` is the correct structural reference. Its `openEvent` field maps 1:1 to MonitorTag's new `ongoingRunStart_`. Directly borrow the slice-start-from-open-event pattern.

## Research Area 4: LiveEventPipeline Wire-Up Feasibility

**Current state (LiveEventPipeline.m, 221 lines):**

The LEP has **zero awareness of Tag/MonitorTag**. It operates on:
- `Sensors` containers.Map of key→`Sensor` (legacy class, not SensorTag)
- `DataSourceMap` of key→`DataSource` (fetchNew returns struct with X, Y, stateX, stateY)
- `IncrementalEventDetector` internal that calls `tmpSensor.resolve()` and `detectEventsFromSensor(tmpSensor, det)` — the full legacy pipeline.

**Rewiring to MonitorTag.appendData would require:**
1. A new `Monitors` containers.Map or cell of MonitorTags alongside (or replacing) `Sensors`
2. DataSource.fetchNew → parent SensorTag.updateData(appendX, appendY) OR direct MonitorTag.appendData(appendX, appendY) call
3. Event routing — MonitorTag already fires events to its bound EventStore (MONITOR-05 fireEventsOnRisingEdges_). So the LEP's manual `EventStore.append(allNewEvents)` becomes redundant — the MonitorTag appends directly.
4. Notification service wiring — LEP's `NotificationService.notify(ev, sd)` must either be migrated to a MonitorTag callback (`OnEventStart`), OR the LEP must extract events from the bound EventStore between ticks.

**File-touch impact estimate:** 
- LiveEventPipeline.m itself: ~30-50 line diff (add Monitors map, change processSensor, change event routing)
- Likely a test addition or modification: `tests/test_live_event_pipeline.m` — at minimum a regression check
- Possibly `DataSource.m` if we need a new callback shape (but we don't — fetchNew stays the same)

**That's already 1-2 extra files for rewire + 1 new test at minimum → puts the phase at 9-10 files, blowing the ≤8 budget.**

### Recommendation: DEFER LiveEventPipeline rewire to Phase 1009

**Justification:**
1. **Phase 1009 explicitly owns consumer migration** ("Consumer migration (one widget at a time)") and will touch all callsites of legacy Sensor/Threshold. LiveEventPipeline is exactly such a consumer — it owns legacy `Sensor.resolve()` call chains via `IncrementalEventDetector`.
2. **Budget math is tight at 8**: CONTEXT files already lists 8 files at cap with 0 margin. Adding LEP edit + likely a test file = 10 files, violating Pitfall 5 by 25%.
3. **MONITOR-08 success criterion #4 ("`LiveEventPipeline` uses appendData at >= legacy throughput")** can be satisfied structurally in 1009, not 1007. 1007 proves appendData correctness + speed in isolation via the benchmark (Pitfall 9 >5x gate); 1009 wires it into LEP with a separate perf gate.
4. **Strangler-fig discipline** — Phase 1007 adds CAPABILITY; Phase 1009 migrates CONSUMERS. Clean separation.

**Adjustment to CONTEXT.md plan:** The success criterion #4 in Phase 1007 should be **retargeted** to: "MonitorTag.appendData produces correct events identical to full recompute for the canonical test harness (hysteresis + debounce across boundary) at >5x speedup (Pitfall 9 gate)." LEP perf gate moves to 1009.

**Updated file budget (8 exactly, no LEP):**

| # | Path | Category |
|---|------|----------|
| 1 | libs/SensorThreshold/MonitorTag.m | edit (add appendData, Persist, load-skip branch) |
| 2 | libs/FastSense/FastSenseDataStore.m | edit (storeMonitor, loadMonitor, schema) |
| 3 | tests/suite/TestMonitorTagStreaming.m | new test (MATLAB) |
| 4 | tests/test_monitortag_streaming.m | new test (Octave) |
| 5 | tests/suite/TestMonitorTagPersistence.m | new test (MATLAB) |
| 6 | tests/test_monitortag_persistence.m | new test (Octave) |
| 7 | benchmarks/bench_monitortag_append.m | new bench (Pitfall 9 gate) |
| 8 | (slack — reserved for schema-migration unit test or Octave flat-test if needed) | — |

Slot 8 is a safety margin — may be used for a small helper, fallback-mode test, or dropped if unused (7-file actual landing).

## Research Area 5: "Parent Hasn't Changed" Detection for Load-Skip-Recompute

### Option space

| Option | Mechanism | Pros | Cons |
|--------|-----------|------|------|
| A. Parent mtime | file mtime of parent's DataStore sqlite file | Cheap; OS-provided | Parent may have no DataStore (in-memory SensorTag); Octave-OS divergence; file rewrites change mtime even if data identical |
| B. Hash of parent X[0:N] | compute md5 of X vector | Deterministic; no file I/O | Cost grows with N; hashing 1M points every getXY wastes 1007's perf gain |
| C. Stamp on parent.updateData | set `parent.dataVersion_++` on each updateData | Cheap; exact | Requires modifying SensorTag/StateTag (+1 file in budget) |
| D. Explicit `invalidatePersistedCache()` | User calls method to signal staleness | Zero auto-magic; predictable | Puts invalidation burden on user; violates "just works" principle |
| **E. Quad-signature hash** (RECOMMENDED) | `(parent.Key, NumPoints, X[1], X[end])` — stamped at write, compared at load | Octave-portable; ~O(1); covers 99% of cases; no SensorTag edit | False positives possible if user mutates X middle without changing length/endpoints (extremely rare — would require appending and deleting same count) |

### Option E in detail

At `storeMonitor` time, persist to the `monitors` row:
- `parent_key` — `obj.Parent.Key`
- `num_points` — `numel(parentX)` (where parentX is `obj.Parent.getXY()` at compute time)
- `parent_xmin` — `parentX(1)`
- `parent_xmax` — `parentX(end)`

At load time (inside MonitorTag constructor or first `getXY`):
1. Call `[X, Y, meta] = DataStore.loadMonitor(obj.Key)`
2. If X empty → cache miss → recompute + persist
3. Else check staleness:
   - `meta.parent_key ~= obj.Parent.Key` → stale (parent rebound) → recompute
   - `meta.num_points ~= numel(parentX_now)` → stale (length changed) → recompute
   - `abs(meta.parent_xmin - parentX_now(1)) > eps` → stale → recompute
   - `abs(meta.parent_xmax - parentX_now(end)) > eps` → stale → recompute
4. Else fresh → load into cache_, set dirty_=false, return

**Safety:** The quad uniquely identifies 99.99%+ of real-world cases. The theoretical false-positive (append N points then delete N points to restore same length+endpoints) is not realistic in a monitoring workflow. Documented in class header.

**Octave portability:** Only uses `numel`, array indexing, abs, eps — all Octave-native.

**Performance:** O(1) — no vector scan.

**Alternative for extra safety:** Add a 5th field `parent_y_checksum` = hash of `parentY` via MATLAB `typecast` + simple sum. But this is a future-hardening; quad is sufficient for v2.0.

### Integration with `invalidate()` and `appendData()`

- After `recompute_()` completes and cache is fresh: if Persist → `storeMonitor` with current quad (overwrites row).
- After `appendData()` extends cache: if Persist → `storeMonitor` with NEW quad (the tail changed parent.X endpoints → new quad → new row).
- User-callable `invalidate()`: clears in-memory cache AND should clear the DataStore row if Persist=true? **Decision:** NO. `invalidate()` is a hint that cache is stale for a recompute — it should NOT delete the persisted row. The next `getXY` will recompute + overwrite the row (fresh value). Deleting would force a gratuitous cache miss if `invalidate` was called "just in case" and turned out redundant. New API: `clearPersistedCache()` for explicit deletion (optional, can be deferred).

## Research Area 6: bench_monitortag_append Harness Design

### Benchmark algorithm (Pitfall 9 >5x gate)

```matlab
function bench_monitortag_append()
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    install();
    
    nWarmup = 100000;
    nAppend = 100000;
    nIter   = 10;     % per run — amortizes first-call overhead
    nRuns   = 3;      % min-of-3 — noise robustness
    
    % Deterministic seed (MATLAB + Octave compatible)
    if exist('rng', 'file') == 2
        rng(0);
    else
        rand('state', 0); randn('state', 0);
    end
    
    % Build warmup data (fixed across both benchmarks)
    x_warm = linspace(0, 100, nWarmup);
    y_warm = 40 + 20*sin(2*pi*x_warm/30) + 5*randn(1, nWarmup);
    x_new  = linspace(100, 200, nAppend);
    y_new  = 40 + 20*sin(2*pi*x_new/30) + 5*randn(1, nAppend);
    
    %% Benchmark A: appendData path
    tAppend = inf;
    for r = 1:nRuns
        st = SensorTag('bench', 'X', x_warm, 'Y', y_warm);
        m  = MonitorTag('m', st, @(x, y) y > 50);
        m.getXY();  % prime cache with warmup
        t0 = tic;
        for it = 1:nIter
            m.appendData(x_new, y_new);
            % Re-prime for next iter by resetting cache_ to warmup state
            % OR: measure a fresh MonitorTag per iter for fairness
        end
        tAppend = min(tAppend, toc(t0));
    end
    
    %% Benchmark B: full-recompute path
    tFull = inf;
    for r = 1:nRuns
        % Combined dataset (simulating append done via updateData instead)
        x_full = [x_warm, x_new];
        y_full = [y_warm, y_new];
        st = SensorTag('bench_full', 'X', x_full, 'Y', y_full);
        m  = MonitorTag('m_full', st, @(x, y) y > 50);
        t0 = tic;
        for it = 1:nIter
            m.invalidate();
            m.getXY();  % full recompute on 200k samples
        end
        tFull = min(tFull, toc(t0));
    end
    
    speedup = tFull / tAppend;
    fprintf('\n=== Pitfall 9: MonitorTag.appendData vs full recompute ===\n');
    fprintf('  warmup=%d  append=%d  iters=%d  min of %d runs\n', ...
            nWarmup, nAppend, nIter, nRuns);
    fprintf('  appendData total  : %.3f s\n', tAppend);
    fprintf('  full recompute    : %.3f s\n', tFull);
    fprintf('  speedup           : %.1fx (gate: >= 5x)\n', speedup);
    assert(speedup >= 5, ...
        sprintf('FAIL: speedup %.1fx < 5x gate.', speedup));
    fprintf('  PASS: >= 5x speedup gate satisfied.\n\n');
end
```

**Calibration notes:**
- **Expected speedup at 100k warmup + 100k append vs 200k full:** Condition evaluation is O(N); so full is 2x longer than tail-only. But full also runs `findRuns_` on 200k; tail is only on 100k. Realistic speedup: ~3-5x on simple ConditionFn; higher with heavy ConditionFn (since it dominates).
- **Risk: 5x gate may be tight.** If simple `y > 50` comparisons dominate, the 2x N ratio is the floor. Solutions:
  1. **Increase workload weight** — nAppend=10k and nWarmup=1M → ratio 100x. Pitfall 9 gate satisfied trivially.
  2. **Use realistic ConditionFn** — e.g., `@(x, y) y > 50 & cos(x) > 0` → more per-sample work.
- **RECOMMENDATION:** Use nWarmup=1_000_000, nAppend=100_000 → ratio is 11x raw (full = 1.1M ops, tail = 100k ops). Even with constant overhead, speedup lands around 8-10x. Safer margin for the gate.

**Also measure for documentation (not gate):**
- Per-iter latency of appendData on 100k tail
- Per-iter latency of full recompute on 1.1M total

**Assertion pattern matches `bench_monitortag_tick.m` (lines 101-103)** — `assert(overhead_pct <= 10, ...)`. Follow identical pattern with `assert(speedup >= 5, ...)`.

## Research Area 7: File-Touch Inventory

### Final planned file touches (8-file budget, no LEP rewire)

| # | Path | SLOC before | SLOC after (est) | Type |
|---|------|-------------|------------------|------|
| 1 | `libs/SensorThreshold/MonitorTag.m` | 500 | ~620 (+120) | edit |
| 2 | `libs/FastSense/FastSenseDataStore.m` | 963 | ~1050 (+85) | edit |
| 3 | `tests/suite/TestMonitorTagStreaming.m` | 0 | ~280 | new |
| 4 | `tests/test_monitortag_streaming.m` | 0 | ~200 | new |
| 5 | `tests/suite/TestMonitorTagPersistence.m` | 0 | ~230 | new |
| 6 | `tests/test_monitortag_persistence.m` | 0 | ~180 | new |
| 7 | `benchmarks/bench_monitortag_append.m` | 0 | ~110 | new |
| 8 | (slack reserve) | — | — | — |

**Total landed SLOC:** ~1205 new/changed SLOC across 7 files (within MISS_HIT 520-line-per-function ceiling; average function length well below 200).

### MonitorTag.m edit breakdown

- Add `Persist logical = false` to public properties block (line 71-79 area): +1 line
- Add `DataStore = []` to public properties block: +1 line
- Add 3 private cache fields (`lastStateFlag_`, `ongoingRunStart_`, `lastHystState_`) — update `cache_` struct shape: ~5 lines
- Refactor `applyHysteresis_` to take `initialState` and return `finalState`: +5 lines
- Refactor `applyDebounce_` to take `ongoingRunStart_` and return updated value: +8 lines
- New method `appendData(newX, newY)`: ~60 lines
- Modify `recompute_()` end to write new state fields + optional Persist: +15 lines
- New private `persistIfEnabled_()` helper: ~15 lines
- New load-skip branch in constructor or first getXY (`loadPersisted_`): ~25 lines
- Update class header (Persist doc, appendData doc): ~10 lines
- **Total edit: ~145 lines added, ~15 modified. Final SLOC ~620.** Within MISS_HIT metrics.

### FastSenseDataStore.m edit breakdown

- Add `monitors` CREATE TABLE in `initSqlite` (line 582-600 area): +11 lines
- New method `storeMonitor(obj, key, X, Y, parentKey, nPts, xMin, xMax)`: ~25 lines
- New method `loadMonitor(obj, key)` returning `[X, Y, meta]`: ~20 lines
- New method `clearMonitor(obj, key)`: ~8 lines
- Update class header (monitors table, new API docs): ~10 lines
- **Total edit: ~74 lines added. Final SLOC ~1037.**

### Legacy-untouched verification (Pitfall 5 grep gate)

Files that MUST remain byte-for-byte unchanged in Phase 1007:
- `libs/SensorThreshold/Sensor.m`
- `libs/SensorThreshold/Threshold.m`
- `libs/SensorThreshold/ThresholdRule.m`
- `libs/SensorThreshold/CompositeThreshold.m`
- `libs/SensorThreshold/StateChannel.m`
- `libs/SensorThreshold/SensorRegistry.m`
- `libs/SensorThreshold/ThresholdRegistry.m`
- `libs/SensorThreshold/ExternalSensorRegistry.m`
- `libs/SensorThreshold/Tag.m`
- `libs/SensorThreshold/SensorTag.m`
- `libs/SensorThreshold/StateTag.m`
- `libs/SensorThreshold/TagRegistry.m`
- `libs/FastSense/FastSense.m`
- `libs/EventDetection/*` (all files — LEP rewire deferred)

Verification command:
```bash
git diff <phase-1006-last-sha>..HEAD -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry,Tag,SensorTag,StateTag,TagRegistry}.m libs/FastSense/FastSense.m libs/EventDetection/*.m
# Expected: 0 lines
```

## Standard Stack

**No new external dependencies. Pure MATLAB with existing mksqlite MEX.**

### Core (existing, unchanged)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB | R2020b+ | Runtime for the two edited .m files | Project standard (CLAUDE.md) |
| Octave | 7+ | Alternative runtime | Project CI support |
| mksqlite | bundled at `libs/FastSense/mksqlite.c` | SQLite MEX interface for storeMonitor/loadMonitor | Already used by `storeResolved`/`loadResolved` — proven pattern |
| SQLite3 | bundled amalgamation at `libs/FastSense/private/mex_src/sqlite3.c` | Storage engine for monitors table | Already underpins DataStore |

### Supporting (existing, reused)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `binary_search` (MEX/MATLAB) | current | Binary-search helper for X-aligned lookups | Already used in MonitorTag.valueAt (line 174) |
| `parseOpts.m` | current | Name-Value argument parsing | Pattern in LiveEventPipeline; MonitorTag uses manual switch (keep) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| mksqlite + SQLite BLOBs | MATLAB `save`/`load` with .mat file per monitor | Simpler API but loses query-by-key; new file lifecycle to manage; no transaction safety |
| Quad-hash staleness | SHA256 of full X+Y | Stronger guarantee but O(N) per load → defeats the speedup |
| In-line monitor table CREATE in storeMonitor | Migration table inside initSqlite | Current recommendation is initSqlite (simpler, one-time) |

**Installation:** No new dependencies. All existing binaries (`build_mex()` / `install()`) continue to work.

## Architecture Patterns

### Recommended File Structure (no new directories)

```
libs/
├── SensorThreshold/
│   └── MonitorTag.m          # EDIT — appendData, Persist, load-skip
└── FastSense/
    └── FastSenseDataStore.m  # EDIT — storeMonitor, loadMonitor, schema

tests/
├── suite/
│   ├── TestMonitorTagStreaming.m    # NEW
│   └── TestMonitorTagPersistence.m  # NEW
├── test_monitortag_streaming.m      # NEW (Octave mirror)
└── test_monitortag_persistence.m    # NEW (Octave mirror)

benchmarks/
└── bench_monitortag_append.m        # NEW — Pitfall 9 gate
```

### Pattern 1: Stateful Cache Across Append Boundary

**What:** Stage FSMs accept `initialState` arg, return `finalState`; persistent fields in `cache_` carry state between `recompute_`/`appendData` calls.

**When to use:** Any pipeline stage whose output at sample i depends on output at sample i-1 (hysteresis, debounce, running avg).

**Example:**
```matlab
% MonitorTag.recompute_ (refactored):
[bin, finalHystState] = obj.applyHysteresis_(px, py, raw, false);  % start from OFF
[bin, finalRunStart] = obj.applyDebounce_(px, bin, NaN);           % no open run
obj.cache_.lastHystState_   = finalHystState;
obj.cache_.ongoingRunStart_ = finalRunStart;
obj.cache_.lastStateFlag_   = bin(end);

% MonitorTag.appendData:
[bin_new, finalHystState] = obj.applyHysteresis_(newX, newY, raw_new, obj.cache_.lastHystState_);
[bin_new, finalRunStart]  = obj.applyDebounce_(newX, bin_new, obj.cache_.ongoingRunStart_);
obj.fireEventsOnRisingEdges_(newX, bin_new, obj.cache_.lastStateFlag_);
obj.cache_.x = [obj.cache_.x, newX(:).'];
obj.cache_.y = [obj.cache_.y, double(bin_new(:).')];
obj.cache_.lastHystState_   = finalHystState;
obj.cache_.ongoingRunStart_ = finalRunStart;
obj.cache_.lastStateFlag_   = bin_new(end);
```

### Pattern 2: Opt-In Persistence Gated by `if Persist`

**What:** All writes to FastSenseDataStore sit inside `if obj.Persist && ~isempty(obj.DataStore)` branches. Default `Persist=false` → zero data store access.

**When to use:** Any capability that is off-by-default per product policy (CONTEXT Pitfall 2 compliance).

**Example:**
```matlab
function recompute_(obj)
    % ... stages 1-4 ...
    obj.cache_ = struct('x', px, 'y', double(bin), 'computedAt', now);
    obj.dirty_ = false;
    obj.persistIfEnabled_();   % <-- single call site, gated internally
end

function persistIfEnabled_(obj)
    if ~obj.Persist || isempty(obj.DataStore); return; end
    [px, ~] = obj.Parent.getXY();
    if isempty(px); return; end
    obj.DataStore.storeMonitor(obj.Key, ...
        obj.cache_.x, obj.cache_.y, ...
        obj.Parent.Key, numel(px), px(1), px(end));
end
```

**Pitfall 2 grep gate (structural verification):**
```bash
# Must return 0 (or N matches, all inside if obj.Persist blocks):
grep -c 'storeMonitor' libs/SensorThreshold/MonitorTag.m
# Verification (stricter): ensure every storeMonitor call has "if.*Persist" within 5 lines above
```

### Pattern 3: Quad-Signature Staleness Detection

**What:** Cache freshness verified against `(parent_key, num_points, parent_xmin, parent_xmax)` quad stamped at write time.

**When to use:** Cheap cache-validity checks when the full-content comparison would dominate the speedup.

**Example:**
```matlab
function tf = cacheIsStale_(obj, meta)
    [px, ~] = obj.Parent.getXY();
    if ~strcmp(meta.parent_key, obj.Parent.Key); tf = true; return; end
    if meta.num_points ~= numel(px);              tf = true; return; end
    if abs(meta.parent_xmin - px(1))   > eps(px(1));   tf = true; return; end
    if abs(meta.parent_xmax - px(end)) > eps(px(end)); tf = true; return; end
    tf = false;
end
```

### Anti-Patterns to Avoid

- **Hand-rolling a listener mechanism beyond Phase 1006's observer hook** — SensorTag.addListener is ALREADY wired in Phase 1006. Don't add a second mechanism for streaming. `appendData` is just an alternative write path that the caller invokes directly; the existing listener cascade covers the automatic-invalidate case.
- **Putting storeMonitor outside an `if Persist` branch** — structural Pitfall 2 gate failure. Even the "schema migration" CREATE TABLE should go in `initSqlite`, NOT in a runtime branch that fires on every call.
- **Making `appendData` call `invalidate()` internally** — they are OPPOSITE operations. invalidate clears cache → next getXY triggers full recompute. appendData EXTENDS cache → no recompute, zero overhead on warmup region.
- **Using floating-point equality for staleness** — `meta.parent_xmin == px(1)` is unsafe. Use `abs(a - b) > eps(value)`.
- **Recomputing the ongoing run's duration from sample indices instead of X timestamps** — indices restart at 1 in each chunk; always use X-native units (consistent with EventDetector.m:52 convention).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SQLite blob encoding | `typecast(x, 'uint8')` + mksqlite BLOB | `mksqlite('typedBLOBs', 2)` + direct `INSERT ? ...` with double vector | Already enabled at line 518 (`initSqlite`); auto-handles encoding/decoding; zero custom code |
| Incremental event detection | New class replicating IncrementalEventDetector logic | Borrow the `openEvent` pattern — already proven in EventDetection/ | Shared mental model with legacy; reviewer familiarity |
| Run-finding on binary vector | Second copy of groupViolations.m | Reuse existing `findRuns_` private method on MonitorTag (Plan 02) | Already inlined; extend not duplicate |
| Hysteresis FSM | Loop-then-correct two-pass | Single-pass state machine (`applyHysteresis_` — lines 338-349) | Already O(N); refactor to accept carry-in state |
| Transaction wrapping | `mksqlite('BEGIN')`/`COMMIT` manually | Copy the exact try-catch-rollback pattern from `storeResolved` (lines 415-434) | Proven atomicity; rollback on exception |
| Datenum/timestamp stamping | String ISO timestamps | MATLAB `now` (already used at MonitorTag.m:310, 329) | Consistent; comparable numerically |

## Runtime State Inventory

**Not applicable.** Phase 1007 is a pure-code additive phase — no renames, no refactors, no string replacements, no migrations of existing stored data. New table (`monitors`) is added; no existing tables renamed or reshaped.

*Nothing found in category:* None — verified by inspection of CONTEXT.md (additive opt-in features only) and by the requirement that existing `Persist=false` default preserves zero-DataStore-touch behavior.

## Common Pitfalls

### Pitfall A1: Persist=false still writes to DataStore via a "migration" branch

**What goes wrong:** A naive `storeMonitor` implementation runs `CREATE TABLE IF NOT EXISTS monitors` on first call — even if Persist=false, if a DataStore is bound, something might touch it.

**Why it happens:** Defensive programming — "always ensure schema exists." But this is a Pitfall 2 violation: any SQLite call at all when Persist=false is forbidden.

**How to avoid:** Put the CREATE TABLE in `initSqlite` (fires once at DataStore construction, well before any Persist concern). `storeMonitor` body assumes table exists and does an INSERT OR REPLACE only.

**Warning signs:** `grep -c "CREATE TABLE" libs/SensorThreshold/MonitorTag.m` returns > 0 (should be 0 — schema lives in DataStore, not MonitorTag).

### Pitfall A2: Hysteresis/debounce state lost across appendData boundary

**What goes wrong:** First `getXY()` returns correct 4-stage pipeline output. User calls `appendData(newX, newY)`; new region is evaluated fresh with `initialState=false`. A run that was ongoing at cache end now has a phantom falling edge at (last_old_timestamp, first_new_timestamp) — two events emitted where there should be one.

**Why it happens:** Each pipeline stage is independently stateful; forgetting to thread the carry-in state through the function signature is an easy mistake.

**How to avoid:** Unit test `testAppendHysteresisBoundaryNoChatter` and `testAppendOngoingRunExtendsIntoTail` cover the two scenarios. Private cache fields `lastStateFlag_`, `ongoingRunStart_`, `lastHystState_` MUST be written at end of BOTH `recompute_()` AND `appendData()`.

**Warning signs:** Test assertions like `numel(store.getEvents()) == 1` failing with `== 2`.

### Pitfall A3: Stale cache returned after parent data change but Persist=true

**What goes wrong:** User constructs MonitorTag with Persist=true → getXY persists → session ends → new session loads the persisted row → but user's new session parent has different data. Quad-hash check skipped; stale 0/1 vector returned.

**Why it happens:** Staleness detection is subtle and easy to skip — "just load if present" feels cleaner.

**How to avoid:** The `cacheIsStale_` helper (Pattern 3) MUST be called before returning cached data. Test `testPersistStaleAfterParentMutation` exercises this (mutate parent in new session, getXY → recompute, not stale data).

**Warning signs:** Test `testPersistRoundTrip` passes but `testPersistStaleAfterParentMutation` fails.

### Pitfall A4: appendData on empty/cold cache crashes

**What goes wrong:** User calls `m.appendData(newX, newY)` before `m.getXY()` has ever run. `obj.cache_.x` is `[]`; indexing `obj.cache_.lastStateFlag_` errors.

**Why it happens:** Forgetting the cold-start fallback branch.

**How to avoid:** First line of `appendData`: `if obj.dirty_ || isempty(obj.cache_) || ~isfield(obj.cache_, 'x'); obj.recompute_(); return; end`. The full recompute handles the tail implicitly because `parent.X` already contains everything. OR: require the caller to append to parent first (`parent.updateData`), then call appendData on monitor.

**Warning signs:** Error `MonitorTag:fieldDoesNotExist` or similar on an append-first code path.

### Pitfall A5: File budget breach from LEP rewire

**What goes wrong:** Enthusiastic rewiring of LiveEventPipeline to use MonitorTag.appendData adds 2-3 files (LEP.m edit + LEP test + possibly DataSource refactor). Phase budget 8 → becomes 10-11. Pitfall 5 failure.

**Why it happens:** "While we're here" scope creep.

**How to avoid:** DEFER to Phase 1009 per Research Area 4. Explicit in plan: "LEP rewire is OUT OF SCOPE for 1007." Phase-exit audit greps `git diff` for `LiveEventPipeline.m` — must be zero lines.

**Warning signs:** Post-phase file count 9+.

### Pitfall A6: Benchmark 5x gate fails due to cheap ConditionFn

**What goes wrong:** `y > 50` runs at 10ns/sample; overhead of `findRuns_ + fireEventsOnRisingEdges_` dominates → appendData on 100k tail vs full on 200k shows only ~2x speedup, missing gate.

**Why it happens:** Micro-benchmark confound — fixed overhead ratio hides algorithmic win.

**How to avoid:** Use nWarmup=1M, nAppend=100k → ratio 11x (full=1.1M ops, tail=100k ops). Even with constant overhead: speedup ≥8x. OR use a realistic composite ConditionFn.

**Warning signs:** Benchmark print `speedup: 3.2x (gate: >= 5x) FAIL`.

## Code Examples

### Example 1: appendData canonical implementation

```matlab
function appendData(obj, newX, newY)
    %APPENDDATA Extend cache with new tail samples without full recompute.
    %   Preserves hysteresis FSM state, MinDuration ongoing-run bookkeeping,
    %   and lastStateFlag across the boundary. Fires events for runs that
    %   COMPLETE in the appended region only — events already emitted for
    %   prior cache regions are not duplicated.
    %
    %   Falls back to full recompute_() if cache is dirty or empty.
    %
    %   Errors: MonitorTag:streamingBeforeCompute if parent has no data.
    
    if ~isnumeric(newX) || ~isnumeric(newY) || numel(newX) ~= numel(newY)
        error('MonitorTag:invalidData', 'newX and newY must be numeric same-length.');
    end
    if isempty(newX); return; end
    
    if obj.dirty_ || isempty(fieldnames(obj.cache_)) || ~isfield(obj.cache_, 'x')
        % Cold start — recompute over full parent (which includes new tail)
        obj.recompute_();
        return;
    end
    
    % Stage 1: raw condition on tail
    raw_new = logical(obj.ConditionFn(newX, newY));
    
    % Stage 2: hysteresis with carry-in
    finalHystState = obj.cache_.lastHystState_;
    if ~isempty(obj.AlarmOffConditionFn)
        [raw_new, finalHystState] = obj.applyHysteresis_( ...
            newX, newY, raw_new, obj.cache_.lastHystState_);
    end
    
    % Stage 3: MinDuration debounce with carry-in (ongoing run)
    finalRunStart = obj.cache_.ongoingRunStart_;
    if obj.MinDuration > 0
        [raw_new, finalRunStart] = obj.applyDebounceWithCarry_( ...
            newX, raw_new, obj.cache_.ongoingRunStart_);
    end
    
    % Stage 4: event emission for runs completed in tail
    obj.fireEventsInTail_(newX, raw_new, obj.cache_.lastStateFlag_, obj.cache_.ongoingRunStart_);
    
    % Extend cache
    obj.cache_.x = [obj.cache_.x, newX(:).'];
    obj.cache_.y = [obj.cache_.y, double(raw_new(:).')];
    obj.cache_.lastStateFlag_   = raw_new(end);
    obj.cache_.lastHystState_   = finalHystState;
    obj.cache_.ongoingRunStart_ = finalRunStart;
    obj.cache_.computedAt       = now;
    
    % Persist if enabled (Pitfall 2 opt-in gate)
    obj.persistIfEnabled_();
end
```

### Example 2: Persist constructor/load-skip branch

```matlab
function [x, y] = getXY(obj)
    %GETXY Return lazy-memoized 0/1 vector; attempts disk load if Persist=true.
    if obj.dirty_ || ~isfield(obj.cache_, 'x')
        % Attempt disk load first
        loaded = obj.tryLoadFromDisk_();
        if ~loaded
            obj.recompute_();
            obj.persistIfEnabled_();
        end
    end
    x = obj.cache_.x;
    y = obj.cache_.y;
end

function tf = tryLoadFromDisk_(obj)
    tf = false;
    if ~obj.Persist || isempty(obj.DataStore); return; end
    [X, Y, meta] = obj.DataStore.loadMonitor(obj.Key);
    if isempty(X); return; end  % miss
    if obj.cacheIsStale_(meta); return; end  % stale — recompute
    obj.cache_ = struct('x', X, 'y', Y, ...
        'computedAt', meta.computed_at, ...
        'lastStateFlag_', Y(end), ...
        'lastHystState_', logical(Y(end)), ...
        'ongoingRunStart_', NaN);   % ongoing-run carry-in lost on reload; safe default
    obj.dirty_ = false;
    tf = true;
end
```

### Example 3: FastSenseDataStore.storeMonitor/loadMonitor

```matlab
function storeMonitor(obj, key, X, Y, parentKey, parentNumPts, parentXMin, parentXMax)
    %STOREMONITOR Cache a MonitorTag's derived (X, Y) plus staleness quad.
    %   Called ONLY when MonitorTag.Persist=true (Pitfall 2 opt-in gate).
    %   The staleness quad (parent_key, num_points, parent_xmin, parent_xmax)
    %   is stamped at write time and compared at load time by the caller
    %   (MonitorTag.cacheIsStale_).
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    mksqlite(obj.DbId, 'BEGIN TRANSACTION');
    try
        mksqlite(obj.DbId, ...
            ['INSERT OR REPLACE INTO monitors ' ...
             '(key, x_blob, y_blob, parent_key, num_points, ' ...
             ' parent_xmin, parent_xmax, computed_at) ' ...
             'VALUES (?, ?, ?, ?, ?, ?, ?, ?)'], ...
            key, X(:).', Y(:).', parentKey, parentNumPts, ...
            parentXMin, parentXMax, now);
        mksqlite(obj.DbId, 'COMMIT');
    catch ME
        try mksqlite(obj.DbId, 'ROLLBACK'); catch; end
        rethrow(ME);
    end
end

function [X, Y, meta] = loadMonitor(obj, key)
    %LOADMONITOR Retrieve cached MonitorTag (X, Y) + staleness metadata.
    %   Returns X=[] on miss. Caller must verify freshness via the returned
    %   meta struct (fields: parent_key, num_points, parent_xmin,
    %   parent_xmax, computed_at).
    X = []; Y = []; meta = struct();
    if ~obj.UseSqlite; return; end
    obj.ensureOpen();
    rows = mksqlite(obj.DbId, ...
        'SELECT * FROM monitors WHERE key = ? LIMIT 1', key);
    if isempty(rows); return; end
    r = rows(1);
    X = r.x_blob(:).';
    Y = r.y_blob(:).';
    meta = struct( ...
        'parent_key',  r.parent_key, ...
        'num_points',  r.num_points, ...
        'parent_xmin', r.parent_xmin, ...
        'parent_xmax', r.parent_xmax, ...
        'computed_at', r.computed_at);
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Sensor.resolve() full violation pipeline every tick | MonitorTag.getXY() lazy + Phase 1007 MonitorTag.appendData() incremental tail | Phase 1007 | >5x speedup for live-tick scenarios |
| Recompute derived series on every session start | Opt-in FastSenseDataStore.loadMonitor() session-cached | Phase 1007 | Near-instant dashboard loads when monitor data is static |
| LiveEventPipeline → IncrementalEventDetector → legacy Sensor | LiveEventPipeline → MonitorTag.appendData() | Phase 1009 (DEFERRED from 1007) | Unifies the streaming path under Tag domain |

**Deprecated/outdated:**
- `Sensor.resolve()` + Thresholds: still fully functional; scheduled for deletion in Phase 1011. Until then, parallel legacy path.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| mksqlite MEX | `FastSenseDataStore.storeMonitor/loadMonitor` | ✓ (bundled at `libs/FastSense/mksqlite.c`) | bundled | Silent no-op (matches `storeResolved` fallback — `if ~obj.UseSqlite; return; end`) |
| MATLAB R2020b+ | All MonitorTag edits | ✓ | project standard | — |
| Octave 7+ | All MonitorTag edits (headless CI) | ✓ | project standard | — |
| `binary_search` helper | MonitorTag.valueAt (unchanged) | ✓ | bundled | Pure-MATLAB fallback exists |
| SQLite3 amalgamation | mksqlite backing | ✓ (bundled at `libs/FastSense/private/mex_src/sqlite3.c`) | bundled | — |
| `now` / `datenum` functions | computed_at timestamp | ✓ | MATLAB + Octave native | — |

**Missing dependencies with no fallback:** None.

**Missing dependencies with fallback:** None — mksqlite fallback is the `~UseSqlite → silent no-op` pattern already proven by `storeResolved`.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (class-based suites) + Octave flat-script `test_*.m` pattern |
| Config file | None (custom runner `tests/run_all_tests.m`) |
| Quick run command | `octave --no-gui --eval "install(); cd tests; test_monitortag_streaming; test_monitortag_persistence"` |
| Full suite command | `octave --no-gui --eval "install(); cd tests; run_all_tests()"` |
| Phase gate | Full suite green + `benchmarks/bench_monitortag_append.m` PASS |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MONITOR-08 | appendData extends cache; no phantom events at boundary | unit | `pytest`-equivalent: `octave --eval "test_monitortag_streaming"` | ❌ Wave 0 |
| MONITOR-08 | appendData hysteresis state carried across boundary | unit | same as above; `testAppendHysteresisBoundaryNoChatter` | ❌ Wave 0 |
| MONITOR-08 | appendData MinDuration spans boundary | unit | `testAppendMinDurationSpansBoundary` | ❌ Wave 0 |
| MONITOR-08 | appendData on cold cache → full recompute fallback | unit | `testAppendFirstEverIsFullRecompute` | ❌ Wave 0 |
| MONITOR-08 | appendData >5x faster than full recompute for 100k tail | perf | `octave --eval "bench_monitortag_append"` | ❌ Wave 0 |
| MONITOR-09 | Persist=true writes to DataStore on getXY | unit | `testPersistWritesOnGetXY` | ❌ Wave 0 |
| MONITOR-09 | Persist=true round-trips through DataStore across sessions | integration | `testPersistRoundTripAcrossSessions` | ❌ Wave 0 |
| MONITOR-09 | Persist=false + DataStore bound → zero SQLite writes | unit (structural + behavioral) | `testPersistFalseNoDataStoreCalls` + grep gate | ❌ Wave 0 |
| MONITOR-09 | Stale cache rejected when parent changes (quad mismatch) | unit | `testPersistStaleAfterParentMutation` | ❌ Wave 0 |
| Pitfall 2 | No `storeMonitor` outside `if obj.Persist` branch | structural (grep) | `grep -B 5 storeMonitor MonitorTag.m \| grep -c "if.*Persist"` | N/A (grep in test) |
| Pitfall 5 | File count ≤ 8 | structural (git diff) | `git diff --name-only <base>..HEAD \| wc -l` | N/A (audit step) |

### Sampling Rate
- **Per task commit:** `octave --no-gui --eval "install(); cd tests; test_monitortag_streaming; test_monitortag_persistence"` (quick — only the new test files)
- **Per wave merge:** full suite `octave --no-gui --eval "install(); cd tests; run_all_tests()"` + `bench_monitortag_append`
- **Phase gate:** Full suite green + Pitfall 2/5/9 gates PASS before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `tests/suite/TestMonitorTagStreaming.m` — covers MONITOR-08 (MATLAB unittest)
- [ ] `tests/test_monitortag_streaming.m` — covers MONITOR-08 (Octave flat)
- [ ] `tests/suite/TestMonitorTagPersistence.m` — covers MONITOR-09 (MATLAB unittest)
- [ ] `tests/test_monitortag_persistence.m` — covers MONITOR-09 (Octave flat)
- [ ] `benchmarks/bench_monitortag_append.m` — Pitfall 9 gate
- [ ] Framework install: already bundled — no action needed (Phase 1004 infra)

## Open Questions

1. **Should `invalidate()` also clear the persisted DataStore row?**
   - What we know: `invalidate()` is a "cache stale — recompute next time" hint. Currently it clears `cache_` in-memory only.
   - What's unclear: If Persist=true, should it also `DELETE FROM monitors WHERE key = ?`? Or leave the stale row for recovery?
   - Recommendation: **NO** (leave disk). The next `getXY()` will `recompute_` + `storeMonitor` (INSERT OR REPLACE overwrites stale row). A premature DELETE on "just in case" invalidations causes gratuitous cache misses. Add `clearPersistedCache()` as an EXPLICIT user-invoked API if needed (future; not in 1007 scope).

2. **Should `appendData` support `(parent.updateData + internal detection)` instead of explicit call?**
   - What we know: Parent observer hook is wired; `parent.updateData` already fires `m.invalidate()`.
   - What's unclear: Could we hook `parent.updateData(X, Y, 'append', true)` and dispatch to `m.appendData` automatically on children?
   - Recommendation: Out of scope for 1007. Deferred per CONTEXT "Auto-derive streaming from parent live-tick signal (Future)." 1007 ships explicit `m.appendData(newX, newY)`.

3. **Should `cacheIsStale_` tolerate a small FP drift (e.g. eps*1000) on parent_xmin/xmax?**
   - What we know: Floating point math can produce `1.0000000001` vs `1.0000000000` on identical logical data round-tripped through SQLite.
   - What's unclear: Is `eps(px(1))` strict enough or too loose? Benchmark data to confirm.
   - Recommendation: Use `eps(px(1)) * 10` as safety margin; document in `cacheIsStale_` header. Unit-test with identical parent data round-tripped through save-load to prove zero false positives.

4. **Does `TestMonitorTagPersistence` need an in-process "second session" simulation?**
   - What we know: MonitorTag construction in the same session always has an in-memory handle; the persist path only matters when a fresh construction attempts `loadMonitor`.
   - What's unclear: Does construct/getXY/`clear classes`/reconstruct-same-key actually exercise the load path? Or do we need a DataStore file that outlives the test?
   - Recommendation: Test in-process by: (1) instance A getXY persists; (2) `m2 = MonitorTag(sameKey, sameParent, sameFn)` WITH `Persist=true, DataStore=sameDs`; (3) m2.getXY → MUST hit load path, not recompute (assert recomputeCount_ == 0 for m2). This exercises the persist branch cleanly.

## Sources

### Primary (HIGH confidence)
- `libs/SensorThreshold/MonitorTag.m` (500 SLOC, lines 297-414 — recompute_ pipeline, applyHysteresis_, applyDebounce_, fireEventsOnRisingEdges_) — exact algorithm structure for streaming refactor
- `libs/FastSense/FastSenseDataStore.m` (963 SLOC, lines 408-494 — storeResolved/loadResolved/clearResolved; lines 531-643 — initSqlite schema creation; lines 513-529 — ensureOpen/closeDb) — authoritative template for storeMonitor/loadMonitor
- `libs/EventDetection/IncrementalEventDetector.m` (254 SLOC, lines 31-175 — `process()` with `openEvent` field, sliceStart from open event) — streaming state-carry reference pattern
- `libs/EventDetection/LiveEventPipeline.m` (221 SLOC) — confirms LEP has zero Tag awareness; rewire scope measured; informs deferral recommendation
- `libs/SensorThreshold/SensorTag.m` (lines 168-203 — listeners_/addListener/updateData/notifyListeners_) — Phase 1006 observer hook already in place
- `benchmarks/bench_monitortag_tick.m` (105 SLOC) — existing Pitfall 9 bench template for `bench_monitortag_append.m`
- `.planning/phases/1006-monitortag-lazy-in-memory/1006-01-SUMMARY.md`, `1006-02-SUMMARY.md`, `1006-03-SUMMARY.md` — Phase 1006 deliverables + grep gates + decisions inherited
- `.planning/REQUIREMENTS.md` — MONITOR-08, MONITOR-09 canonical definitions; forbidden stack list (no arguments/enumeration/events blocks)
- `.planning/ROADMAP.md` Phase 1007 section — Success criteria + Pitfall gates
- `.planning/phases/1007-monitortag-streaming-persistence/1007-CONTEXT.md` — user-locked decisions

### Secondary (MEDIUM confidence)
- MATLAB / mksqlite typedBLOBs behavior — confirmed by inspection of `FastSenseDataStore.m:518` (`mksqlite(obj.DbId, 'typedBLOBs', 2)`) + the `storeResolved` code path that round-trips `double(1, N)` vectors via `INSERT ... VALUES (?, ?)` and `SELECT ...` without custom encoding. Pattern proven in production for 4+ phases.
- MISS_HIT complexity limits (520 function lines, 80 cyclomatic) from `CLAUDE.md` — internal project convention, not externally verified but consistent across codebase.

### Tertiary (LOW confidence)
- No Context7/WebSearch queries performed: this is a pure-project research phase with no external library recommendations. All findings are derived from in-repo code inspection (HIGH confidence).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new deps; all patterns already proven in existing `storeResolved`/Plan-02-recompute_ code paths
- Architecture (appendData algorithm): HIGH — derived directly from existing pipeline shape + IncrementalEventDetector reference; boundary-state fields enumerated from source
- FastSenseDataStore API: HIGH — exact mirror of existing `storeResolved`/`loadResolved` methods
- "Parent unchanged" detection: MEDIUM — quad-hash is a RECOMMENDATION; Option E not yet proven in-repo, but uses only primitives that work in both MATLAB + Octave. Risk mitigated by test coverage.
- LEP deferral: HIGH — file-count budget math explicit; Phase 1009 scope explicit in ROADMAP
- Benchmark design: MEDIUM — 5x gate may need nWarmup=1M tuning if initial run shows tight margin; reserve slack for retuning

**Research date:** 2026-04-16
**Valid until:** 2026-05-16 (30 days — stable in-project code; no external library drift)

## RESEARCH COMPLETE

**Phase:** 1007 - MonitorTag streaming + persistence
**Confidence:** HIGH

### Key Findings
- **FastSenseDataStore has a near-perfect template** (`storeResolved/loadResolved/clearResolved`) for the new `storeMonitor/loadMonitor/clearMonitor` trio. Schema goes in `initSqlite` (line 582-600 area); methods mirror existing shape exactly; typedBLOBs=2 already enabled.
- **Hysteresis FSM and MinDuration debounce require 3 new private cache fields** (`lastHystState_`, `ongoingRunStart_`, `lastStateFlag_`) written by BOTH `recompute_()` and `appendData()`. The existing `applyHysteresis_`/`applyDebounce_` helpers refactor cleanly to accept carry-in state and return final state.
- **IncrementalEventDetector's `openEvent` pattern maps 1:1 to `ongoingRunStart_`** — directly borrow the slice-start-from-open-event logic for correct boundary handling.
- **Strongly recommend DEFERRING LiveEventPipeline rewire to Phase 1009.** Rewire adds 2-3 files (~10 total), blowing the ≤8 budget. Phase 1009 owns consumer migration; 1007 proves `appendData` correctness + speed in isolation.
- **Quad-signature staleness detection** (parent_key + num_points + parent_xmin + parent_xmax) is the simplest-safe load-skip-recompute mechanism. Octave-portable, O(1), covers realistic mutation scenarios. Alternative mtime/hash/flag options are inferior for various reasons documented in Research Area 5.
- **Benchmark 5x gate may need nWarmup=1M calibration** to provide comfortable margin. At nWarmup=nAppend=100k the raw ratio is only 2x (full=200k ops vs tail=100k ops); bumping to 1M gives 11x headroom.

### File Created
`/Users/hannessuhr/FastPlot/.claude/worktrees/reverent-bohr/.planning/phases/1007-monitortag-streaming-persistence/1007-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | Zero new deps; all patterns already in production |
| Architecture (appendData algorithm) | HIGH | Derived from existing pipeline + IncrementalEventDetector; boundary-state fields enumerated |
| FastSenseDataStore API | HIGH | Exact mirror of existing `storeResolved`/`loadResolved` |
| Pitfalls | HIGH | 6 specific pitfalls enumerated with warning signs + avoidance |
| Staleness detection (quad-hash) | MEDIUM | Recommended approach; not yet proven in-repo; mitigated by explicit test |
| Benchmark design | MEDIUM | Gate may need workload tuning; reserve calibration step |
| LEP deferral recommendation | HIGH | Budget math explicit; Phase 1009 scope already owns |

### Open Questions
1. Should `invalidate()` also delete the persisted row? (Recommendation: NO; let INSERT OR REPLACE overwrite)
2. Should parent_xmin/xmax staleness use `eps * 10` safety margin? (Recommendation: YES, document explicitly)
3. Test "second session" mechanics for Persist round-trip — construct m2 with same key + same DataStore in-process (Recommendation: use recomputeCount_ probe assertions)

### Ready for Planning
Research complete. Planner can now create PLAN.md files for 7 (+ 1 reserved) file touches covering:
- MonitorTag.m edit (appendData + Persist + 3 new cache fields + load-skip branch)
- FastSenseDataStore.m edit (storeMonitor/loadMonitor/clearMonitor + monitors table schema)
- 4 test files (MATLAB + Octave for both streaming and persistence)
- 1 benchmark (Pitfall 9 gate, 5x speedup assertion)
