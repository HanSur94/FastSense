# Phase 1007: MonitorTag streaming + persistence - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — additive opt-in features on MonitorTag)

<domain>
## Phase Boundary

Add two opt-in performance/persistence levers to MonitorTag without compromising the lazy-by-default contract from Phase 1006:
1. **Streaming `appendData(newX, newY)`** — extends cache incrementally, no full recompute
2. **Opt-in disk persistence `Persist = true`** — cache `(X, Y)` to FastSenseDataStore; loads on next session

**In scope:**
- `MonitorTag.appendData(newX, newY)` public method:
  - Appends new parent samples, extends internal cache by evaluating `ConditionFn(newX, newY)` only on new region
  - Preserves hysteresis state machine across appends (remember last-known state)
  - Preserves MinDuration bookkeeping (ongoing run may extend across append boundary)
  - Fires events on rising edges within appended region (with MinDuration enforcement)
  - Does NOT call `invalidate()` — cache stays fresh, is EXTENDED not rebuilt
- `MonitorTag.Persist` public property (logical, default `false`):
  - When `false`: behavior unchanged from Phase 1006 (lazy, in-memory)
  - When `true`: after each `recompute_()` or `appendData`, write derived `(X, Y)` to disk via new `FastSenseDataStore.storeMonitor(key, X, Y)`
  - On load / first `getXY`, check `FastSenseDataStore.loadMonitor(key)` — if cached data exists and parent hasn't changed, return cached data (skip recompute)
- `FastSenseDataStore.storeMonitor(key, X, Y)` — NEW method
  - Writes to SQLite with a new table `monitors` (key, x_blob, y_blob, computed_at)
  - Similar API to existing `storeSensor` or `store()` method (read existing DataStore.m to find pattern)
- `FastSenseDataStore.loadMonitor(key)` — NEW method
  - Returns `(X, Y, computedAt)` tuple or empty if no cached data
- `LiveEventPipeline` integration — update LiveEventPipeline to call `monitor.appendData(newX, newY)` instead of full recompute, so live-tick is incremental

**Out of scope:**
- CompositeTag (Phase 1008)
- Widget migration (Phase 1009)
- Event binding rewrite (Phase 1010)

**Verification gates (from ROADMAP):**
- Pitfall 2 (opt-in persistence): `Persist = false` is default. `storeMonitor` only invoked when `Persist == true`. grep count of `storeMonitor` in MonitorTag.m is ≥1 BUT ONLY inside `if obj.Persist` branch (structural check).
- Pitfall 5: ≤8 files touched. Mostly MonitorTag.m, FastSenseDataStore.m, plus tests.
- Pitfall 9: `appendData` benchmark vs full recompute shows >5x speedup for 100k-sample tail append.

</domain>

<decisions>
## Implementation Decisions

### File Organization
- EDIT: `libs/SensorThreshold/MonitorTag.m` — add `appendData(newX, newY)` public method + `Persist` property + persistence-load branch in `recompute_()`/`getXY()`
- EDIT: `libs/FastSense/FastSenseDataStore.m` — add `storeMonitor(key, X, Y)` + `loadMonitor(key)` methods + migration for new `monitors` SQLite table
- EDIT: `libs/EventDetection/LiveEventPipeline.m` — switch live-tick from full recompute to `monitor.appendData` (only if feasible within budget; if LiveEventPipeline rewire is >budget, defer to later phase and DO just a basic API demo in test)
- NEW: `tests/suite/TestMonitorTagStreaming.m`
- NEW: `tests/test_monitortag_streaming.m`
- NEW: `tests/suite/TestMonitorTagPersistence.m`
- NEW: `tests/test_monitortag_persistence.m`
- NEW: `benchmarks/bench_monitortag_append.m` (Pitfall 9 gate — >5x speedup)

Total: 8 files at cap. Tight.

### appendData Algorithm
```matlab
function appendData(obj, newX, newY)
    % Append mode: extend cache, preserve hysteresis + debounce state
    if obj.dirty_ || isempty(obj.cache_)
        % Cache not warm — fall back to full recompute
        obj.recompute_();
        return;
    end
    
    % Evaluate condition only on new region
    raw_new = logical(obj.ConditionFn(newX, newY));
    
    % Continue hysteresis FSM from last state
    if ~isempty(obj.AlarmOffConditionFn)
        raw_new = applyHysteresis_(newX, newY, raw_new, obj.AlarmOffConditionFn, obj.lastHysteresisState_);
    end
    
    % Handle MinDuration across boundary — if ongoing run extends into new region, may now satisfy
    % Otherwise same debounce logic
    state_new = applyDebounce_(newX, raw_new, obj.MinDuration, obj.lastDebounceState_);
    
    % Fire events on rising edges in new region only
    obj.fireEventsOnRisingEdges_(newX, state_new, obj.cache_.lastStateFlag_);
    
    % Extend cache
    obj.cache_.x = [obj.cache_.x; newX(:)];
    obj.cache_.y = [obj.cache_.y; double(state_new(:))];
    obj.cache_.lastStateFlag_ = state_new(end);
    
    % Persist if enabled
    if obj.Persist && ~isempty(obj.DataStore)
        obj.DataStore.storeMonitor(obj.Key, obj.cache_.x, obj.cache_.y);
    end
end
```

### Persist Property
- Added to MonitorTag.m properties block: `Persist logical = false`
- `DataStore` property (optional FastSenseDataStore handle) — required when Persist=true
- After each `recompute_()`, if `Persist && ~isempty(DataStore)`, call `DataStore.storeMonitor(Key, X, Y)`
- On construction OR first `getXY()`, if `Persist && ~isempty(DataStore)`:
  - Try `[X, Y, computedAt] = DataStore.loadMonitor(Key)`
  - If non-empty AND parent hasn't changed since computedAt (use parent's data timestamp / mtime if available; fallback: if parent.X is unchanged), use cached data, skip recompute
  - Else recompute + persist
- Default `Persist = false` means ZERO DataStore calls — Pitfall 2 compliance.

### FastSenseDataStore API
- NEW `storeMonitor(obj, key, X, Y)`:
  - SQL: `INSERT OR REPLACE INTO monitors (key, x_blob, y_blob, computed_at) VALUES (?, ?, ?, ?)`
  - Schema migration: create `monitors` table if not exists (run on DataStore open)
- NEW `loadMonitor(obj, key)`:
  - Returns `[X, Y, computedAt]` or empty on miss
  - Decodes x_blob/y_blob (match existing sensor-blob codec pattern)

### LiveEventPipeline Integration
- If feasible within 8-file budget: update LiveEventPipeline.m live-tick loop to call `monitor.appendData(new_x, new_y)` instead of full recompute
- If that stretches the budget: SKIP LiveEventPipeline edit in Phase 1007; plan demonstrates appendData in isolation and defer wire-up to Phase 1009 (widget migration). Document the deferral.
- Decision: **plan-phase should make the budget call.** Goal is to exit 1007 with green appendData + persistence gates.

### Error IDs
- `MonitorTag:streamingBeforeCompute`, `MonitorTag:persistDataStoreRequired`
- `FastSenseDataStore:monitorKeyMissing`

### Pitfall 9 Benchmark
- `bench_monitortag_append.m`:
  - Setup: MonitorTag with 100k points cached (warm recompute)
  - Benchmark A: append 100k new samples via `appendData` → measure wall time
  - Benchmark B: invalidate + full getXY (200k points) → measure wall time
  - Assert: `B / A >= 5` (5x speedup)
  - Print PASS/FAIL; exit 0 on pass; headless Octave friendly

### Claude's Discretion
- Exact SQLite schema for `monitors` table
- How to detect "parent hasn't changed" for load-skip-recompute decision (mtime on parent's DataStore? hash of parent X/Y? flag set on parent.updateData?)
- Whether `loadMonitor` returns a struct or tuple
- LiveEventPipeline wire-up vs deferral

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- Phase 1006 `libs/SensorThreshold/MonitorTag.m` — base for edits (appendData + Persist)
- `libs/FastSense/FastSenseDataStore.m` — existing SQLite-backed store; `storeMonitor`/`loadMonitor` mirror existing `storeSensor`/`store()` patterns
- `libs/EventDetection/IncrementalEventDetector.m` — streaming pattern reference (Phase 1006 research documented this)
- `libs/EventDetection/LiveEventPipeline.m` — live-tick consumer; benefits from streaming appendData

### Established Patterns
- Opt-in flags default to `false` (Pitfall 2)
- MEX-backed SQLite (mksqlite) for storage
- `DataStore` property on Tag handles to bind storage

### Integration Points
- MonitorTag extends its own class with Persist + appendData (pure additive)
- FastSenseDataStore gains two new methods + optional schema migration
- LiveEventPipeline (optional) consumes appendData

</code_context>

<specifics>
## Specific Ideas

- Hysteresis state continuity across appendData boundary: preserve `lastHysteresisState_` private field between recompute and appendData. Test: 2 appendData calls with hysteresis → no phantom edge at boundary.
- MinDuration bookkeeping across boundary: if ongoing run-of-1s extends into new region, its duration is (new falling edge - original start). Preserve `ongoingRunStart_` field.
- Persistence round-trip test:
  1. Construct MonitorTag with Persist=true + DataStore
  2. getXY → cache written to SQLite
  3. Construct NEW MonitorTag with same Key + same DataStore
  4. getXY → returns cached data from disk (recompute skipped)
  5. Modify parent data + mark parent timestamp dirty → new getXY should recompute (not use stale disk cache)
- Persistence opt-in test: Persist=false + DataStore bound → first getXY should NOT touch SQLite (grep sqlite log or check table count)

</specifics>

<deferred>
## Deferred Ideas

- CompositeTag aggregation (Phase 1008)
- Widget consumer migration (Phase 1009)
- Auto-derive streaming from parent live-tick signal (Future)

</deferred>
