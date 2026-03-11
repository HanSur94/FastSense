# EventDetection Optimization Design

Date: 2026-03-11

## Context

The EventDetection library has four architectural issues identified during code review:

1. **Unbounded fullX/fullY growth** in `IncrementalEventDetector` — arrays grow indefinitely
2. **Full re-detection every cycle** — detection runs over all accumulated data each cycle
3. **onHover O(n) graphics-get** in `EventViewer` — calls `get()` on every bar handle per mouse-move
4. **Duplicate backup logic** — `EventConfig` and `EventStore` independently implement backup/prune

### Operating parameters

- Sample rate: ~0.33 Hz (one value every 3 seconds)
- Session duration: months
- Event duration: up to 1 month
- At 0.33 Hz, one month = ~864K samples per sensor (~7 MB double-precision X+Y)
- Memory is not the bottleneck; CPU from repeated full-array detection is

## Design

### 1. Incremental-only detection

**File:** `IncrementalEventDetector.m`

**Current behavior:** Each call to `process()` concatenates new data to `st.fullX`/`st.fullY`, builds a temporary sensor with the full accumulated history, and calls `detectEventsFromSensor()` over everything. Results are filtered to events touching the new data window.

**New behavior:** Detection runs over a **slice** of the accumulated data, not the full history.

- `st.fullX`/`st.fullY` still accumulate (EventViewer needs full history for click-to-plot)
- Slice start is determined by:
  - If an open event exists: `st.openEvent.StartTime` (need to re-detect from event start to handle merges correctly)
  - Otherwise: `newX(1)` (only new data)
- Slice indices found via `binary_search` on `st.fullX`
- `tmpSensor` is built with `st.fullX(sliceIdx:end)` / `st.fullY(sliceIdx:end)`
- Rest of logic (open event handling, merge, escalate) unchanged

**Edge case:** If threshold rules change mid-session, events from before the slice are missed. Acceptable — user should restart the pipeline or run batch re-detection.

### 2. Cache bar positions in EventViewer

**File:** `EventViewer.m`

**Current behavior:** `findBarUnderCursor()` calls `get(obj.BarRects(i), 'Position')` inside a loop for every bar on every mouse-move event. For N bars at 60 Hz mouse events, this is N graphics handle queries per frame.

**New behavior:**

- Add private property `BarPositions` (Nx4 double matrix: `[x, y, w, h]` per row)
- In `drawTimeline()`, after creating each rectangle, store its position in the matrix
- `findBarUnderCursor()` reads from `BarPositions` instead of calling `get()` on graphics handles
- No behavioral change — same hit-test math, just reads from a plain array

### 3. Unify backup logic — EventConfig delegates to EventStore

**Files:** `EventConfig.m`, `EventStore.m`

**Current behavior:** Both classes independently implement backup (timestamped copy) and prune (keep newest N). They use different naming patterns (`EventConfig`: `name_timestamp.mat`, `EventStore`: `name_backup_timestamp.mat`) and different glob patterns for pruning.

**New behavior:**

- `EventStore.save()` gains support for additional fields: `thresholdColors`, `timestamp`, and `sensorData` struct — fields that `EventConfig.saveEvents` currently writes but `EventStore` doesn't
- `EventConfig.saveEvents()` creates a temporary `EventStore` instance, populates it, and calls `store.save()`
- `EventConfig.createBackup()` and `EventConfig.pruneBackups()` are deleted
- Legacy backup files (old naming pattern without `_backup_`) are left in place; they won't match EventStore's glob and sit harmlessly until manually cleaned

## Files changed

| File | Change |
|------|--------|
| `IncrementalEventDetector.m` | Slice-based detection instead of full-array |
| `EventViewer.m` | Add `BarPositions` matrix, use in `findBarUnderCursor` |
| `EventConfig.m` | Delete backup/prune methods, delegate to `EventStore` |
| `EventStore.m` | Support additional save fields (`thresholdColors`, `timestamp`) |

## Test impact

- `test_incremental_detector`: validates first batch, incremental, open event carry-over, finalization, escalation, multi-sensor — covers the slice-based detection change
- `test_event_viewer`: validates viewer construction and behavior
- `test_event_store` / `test_event_store_rw`: validates store save/load/backup
- `test_event_config`: validates EventConfig save flow — will need update to reflect delegation to EventStore

All 52 existing tests must continue to pass.
