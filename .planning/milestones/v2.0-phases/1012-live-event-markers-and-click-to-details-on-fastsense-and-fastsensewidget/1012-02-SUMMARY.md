---
phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget
plan: "02"
subsystem: sensor-threshold
tags: [matlab, octave, monitortag, event-emission, running-stats, open-event, tdd, wave-1]

# Dependency graph
requires:
  - phase: 1012-01
    provides: Event.IsOpen property, Event.close() method, EventStore.closeEvent() method

provides:
  - "MonitorTag.appendData rising-edge emission: IsOpen=true Event appended to EventStore with Id cached in cache_.openEventId_"
  - "MonitorTag.appendData falling-edge close: EventStore.closeEvent(openEventId_, endT, finalStats) called on falling edge; cache_ reset"
  - "MonitorTag running-stats accumulator: cache_.openStats_ struct updated O(chunk-size) per appendData tick; never O(run-length)"
  - "MonitorTag.fireEventsOnRisingEdges_ trailing-run parity: recompute path also emits IsOpen=true for trailing open runs"
  - "TestMonitorTagOpenEvent MATLAB suite (7 tests) + test_monitortag_open_event Octave mirror — all passing"
  - "Same-chunk closed event inline stats via Event.setStats()"

affects:
  - 1012-03-plan

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "emptyOpenStats_() static private helper — single source of truth for zero-struct accumulator shape"
    - "O(chunk) running stats: nPoints/sumY/sumYSq/maxY/minY/peakAbs/firstT/lastT accumulated per tick"
    - "flushOpenStats_() derives PeakValue/Mean/RMS/Std/NumPoints at close time — never stores Y history"
    - "fireEventsInTail_ extended with case (a) within-chunk falling edge + case (b) chunk-boundary falling edge"
    - "recompute_ seeds openEventId_/openStats_ before calling fireEventsOnRisingEdges_ and preserves values in final cache_"
    - "appendData passes newY to fireEventsInTail_ for same-chunk inline stats"

key-files:
  created:
    - tests/suite/TestMonitorTagOpenEvent.m
    - tests/test_monitortag_open_event.m
  modified:
    - libs/SensorThreshold/MonitorTag.m
    - tests/suite/TestMonitorTagStreaming.m

key-decisions:
  - "cache_ openStats_/openEventId_ seeded via isfield guard BEFORE fireEventsOnRisingEdges_ in recompute_; preserved via savedOpenEventId/savedOpenStats after call to prevent cache_ struct overwrite losing emitter-set values"
  - "fireEventsInTail_ accepts optional newY param — enables inline stats for same-chunk events without requiring separate accumulator path"
  - "Falling edge case (b): bin_new(1)==0 with priorLastFlag==1 closes at cache_.x(end) — endT is last cached sample from prior chunk, not newX(1)"
  - "TestMonitorTagStreaming/testAppendOngoingRunExtendsIntoTail updated to Phase 1012 semantics: 1 event opened+closed vs. old 2-event double-emission"
  - "Octave test file avoids nested functions (SIGILL on handle-class cycle cleanup); all 7 tests inlined without mkFixture subfn"

requirements-completed: []

# Metrics
duration: 17min
completed: 2026-04-24
---

# Phase 1012 Plan 02: Open-Event Emission + Running Stats in MonitorTag Summary

**MonitorTag now emits IsOpen=true events on rising edge, accumulates running stats O(chunk-size) per tick, and closes events via EventStore.closeEvent on falling edge**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-04-24
- **Completed:** 2026-04-24
- **Tasks:** 3
- **Files modified:** 4 (1 source MonitorTag.m, 1 regression suite update TestMonitorTagStreaming.m, 2 new test files)

## Accomplishments

- `cache_.openStats_` accumulator (nPoints/sumY/sumYSq/maxY/minY/peakAbs/firstT/lastT) added to all 3 cache init paths in MonitorTag
- `emptyOpenStats_()` static private helper — single source of truth for zero-struct init
- `updateOpenStats_(xSlice, ySlice)` — O(chunk) incremental update, never O(run-length)
- `flushOpenStats_()` — derives finalStats struct for EventStore.closeEvent at close time
- `fireEventsInTail_` extended: Part 1 handles 2 falling-edge cases (within-chunk + chunk-boundary); Part 2 emits IsOpen=true for trailing open runs (was `continue` pre-phase)
- `fireEventsOnRisingEdges_` extended for recompute path parity: skips trailing run in closed-loop, emits IsOpen=true event and seeds openStats_ for trailing open run
- appendData wiring: updates openStats_ with raw sensor values (newY, NOT raw_new boolean) before fire call; backfills stats for newly-seeded open events post-fire
- Same-chunk closed events get inline stats via setStats() (new: fixes events where rise+fall in one chunk)
- `TestMonitorTagOpenEvent.m` (7 tests, MATLAB) + `test_monitortag_open_event.m` (7 tests, Octave) all pass
- Pre-existing regression suites (TestMonitorTag, TestMonitorTagStreaming, TestMonitorTagPersistence) all pass

## Task Commits

1. **Task 1: Extend cache_ with openStats_ + openEventId_** - `5f04d72` (feat)
2. **Task 2: Emit IsOpen=true at rising edge; close on falling edge; accumulate running stats** - `c1dbc68` (feat)
3. **Task 3: Rewrite Wave 0 TestMonitorTagOpenEvent stubs** - `a1a751f` (test)

## Dispatch Points

### Rising-edge open-event emission (tail branch)
`MonitorTag.fireEventsInTail_` — Part 2 loop, when `eI(k) == numel(bin_new)` and `cache_.openEventId_` is empty:
- Creates `Event(startT, NaN, ...) with ev.IsOpen=true`
- Appends to EventStore, attaches EventBinding, caches `ev.Id` in `cache_.openEventId_`

### Rising-edge open-event emission (recompute branch)
`MonitorTag.fireEventsOnRisingEdges_` — after closed-runs loop, when `lastOpenRun && isempty(cache_.openEventId_)`:
- Same Event creation with IsOpen=true
- Seeds openStats_ from parent grid data for the open run portion

### Running-stats accumulation
`MonitorTag.appendData` — between Stage 3 (debounce) and Stage 4 (fire):
- Pre-fire: `if ~isempty(openEventId_)`: update with `(raw_new==1)` masked slice of newY (raw sensor values)
- Post-fire: backfill if `openEventId_` was just set and `openStats_.nPoints==0`

### Falling-edge close (2 cases)
`MonitorTag.fireEventsInTail_` — Part 1:
- Case (a): `priorLastFlag==1 && sI(1)==1 && eI(1) < numel(bin_new)` — continuation run closes within chunk; `endT = newX(eI(1))`
- Case (b): `priorLastFlag==1 && ~bin_new(1)` — chunk starts with 0; `endT = cache_.x(end)` (last cached sample)
- Both cases: `flushOpenStats_()` → `EventStore.closeEvent(openEventId_, endT, fs)` → reset `openEventId_` + `openStats_`

### Same-chunk closed events
`MonitorTag.fireEventsInTail_` — closed-run path (Part 2): when `newY` is provided, calls `ev.setStats(...)` with slice stats before `EventStore.append`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] cache_ not seeded before fireEventsOnRisingEdges_ call in recompute_**
- **Found during:** Task 2 execution / regression test run
- **Issue:** `invalidate()` sets `cache_ = struct()` (empty); `recompute_()` calls `fireEventsOnRisingEdges_` before setting the final cache_ struct. The emitter accessed `obj.cache_.openEventId_` which didn't exist, causing `MATLAB:badsubscript`.
- **Fix:** Added `isfield` guard to seed `openEventId_` + `openStats_` before the emitter call; captured emitter-set values in `savedOpenEventId`/`savedOpenStats` locals and wrote them into the final `obj.cache_` struct assignment.
- **Files modified:** `libs/SensorThreshold/MonitorTag.m`
- **Commit:** c1dbc68

**2. [Rule 1 - Bug] Falling-edge case (b) missing: chunk-boundary falling edge not handled**
- **Found during:** Task 3 test `testClosingRunResetsOpenEventIdAndOpenStats`
- **Issue:** When `appendData` receives a chunk that starts with 0 (entire chunk below threshold) while `priorLastFlag==1` and `openEventId_` is set, `findRuns_` returns empty arrays. The original Part 1 condition `~isempty(sI) && sI(1)==1` evaluated false, so the open event was never closed.
- **Fix:** Added case (b) to Part 1 of `fireEventsInTail_`: `elseif priorLastFlag==1 && ~bin_new(1)` with `endT = obj.cache_.x(end)`.
- **Files modified:** `libs/SensorThreshold/MonitorTag.m`
- **Commit:** a1a751f

**3. [Rule 1 - Bug] Same-chunk closed events had no stats (NumPoints=0, PeakValue=[])**
- **Found during:** Task 3 test `testOpenRunStatsFinalizedOnClose`
- **Issue:** When a complete run (both rising and falling edge) occurs within a single `appendData` chunk, the closed-run path in `fireEventsInTail_` emitted the event without stats because the pre-fire openStats_ accumulation path only runs when `openEventId_` is already set.
- **Fix:** Extended `fireEventsInTail_` signature with optional `newY` parameter; added inline `ev.setStats(...)` in the closed-run path using the run's Y slice.
- **Files modified:** `libs/SensorThreshold/MonitorTag.m`
- **Commit:** a1a751f

**4. [Rule 1 - Bug] TestMonitorTagStreaming Scenario 2 tested pre-Phase-1012 double-event behavior**
- **Found during:** Task 2 regression run
- **Issue:** `testAppendOngoingRunExtendsIntoTail` expected 2 events (old behavior: premature close at parent end + continuation event). Phase 1012 produces 1 event (opened on rising edge, closed via closeEvent on falling edge).
- **Fix:** Updated test assertions to reflect Phase 1012 semantics: 1 event total, with IsOpen=false and EndTime=12 after the falling edge.
- **Files modified:** `tests/suite/TestMonitorTagStreaming.m`
- **Commit:** c1dbc68

**5. [Rule 3 - Blocking] Octave nested function caused SIGILL crash**
- **Found during:** Task 3 Octave test run
- **Issue:** `test_monitortag_open_event.m` originally defined `mkFixture` as a nested subfunction. Octave's handle-class garbage collection on function exit triggered a SIGILL (exit code 132) due to listener cycles on handle objects.
- **Fix:** Removed nested function; inlined fixture setup at the top of each test block.
- **Files modified:** `tests/test_monitortag_open_event.m`
- **Commit:** a1a751f

### Pre-existing Issue (Out of Scope)
- `TestMonitorTagEvents/testCarrierPatternNoTagKeys` was already failing BEFORE this plan. The test checks that MonitorTag.m does not reference `.TagKeys`, but Plan 01 added `ev.TagKeys = {...}` to `fireEventsInTail_` and `fireEventsOnRisingEdges_` as part of Phase 1010 migration. This is an out-of-scope pre-existing failure; deferred to `deferred-items.md`.

## Known Stubs

None — TestMonitorTagOpenEvent is fully wired. All 7 MATLAB + 7 Octave tests pass with real implementation.

## Self-Check: PASSED

- FOUND: .planning/phases/1012-.../1012-02-SUMMARY.md
- FOUND: 5f04d72 (feat cache_ extension)
- FOUND: c1dbc68 (feat rising/falling edge + running stats)
- FOUND: a1a751f (test Wave 0 rewrites)

---
*Phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget*
*Completed: 2026-04-24*
