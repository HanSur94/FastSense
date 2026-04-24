---
phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget
plan: "01"
subsystem: event-detection
tags: [matlab, octave, event, event-store, tdd, wave-0, schema]

# Dependency graph
requires:
  - phase: 1010-event-tag-binding-fastsense-overlay
    provides: Event handle class, EventStore .mat backend, EventBinding registry

provides:
  - "Event.IsOpen public logical property (default false) — open-event schema"
  - "Event.close(endTime, finalStats) instance method — single mutation path for private EndTime/Duration/stats fields (D1 SSOT)"
  - "NaN endTime accepted by Event constructor — open-event shape"
  - "EventStore.closeEvent(eventId, endTime, finalStats) — delegates to ev.close(); two distinct error IDs"
  - "TestEventIsOpen MATLAB suite (12 tests) + test_event_is_open Octave mirror"
  - "Wave 0 stub test files for Plans 02 and 03 (6 files, all discoverable)"
  - "bench_event_marker_regression.m — Pitfall-10 harness with 3 configurations, +/-5% gate"

affects:
  - 1012-02-plan
  - 1012-03-plan

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "IsOpen default-false on class definition enables MATLAB/Octave default-on-read for .mat backward compat (no migration script)"
    - "Event.close() as single write path for SetAccess=private fields (D1 SSOT)"
    - "EventStore error IDs: EventStore:unknownEventId (two call sites) + EventStore:alreadyClosed"
    - "Wave 0 stub discipline: assumeFail() in MATLAB suite, fprintf SKIP in Octave mirror"

key-files:
  created:
    - tests/suite/TestEventIsOpen.m
    - tests/test_event_is_open.m
    - tests/suite/TestMonitorTagOpenEvent.m
    - tests/test_monitortag_open_event.m
    - tests/suite/TestFastSenseEventClick.m
    - tests/test_fastsense_event_click.m
    - tests/suite/TestFastSenseWidgetEventMarkers.m
    - tests/test_fastsense_widget_event_markers.m
    - benchmarks/bench_event_marker_regression.m
  modified:
    - libs/EventDetection/Event.m
    - libs/EventDetection/EventStore.m

key-decisions:
  - "Event.close() instance method chosen over public EndTime setter — encapsulates all private field mutation in one method (D1 SSOT); EventStore.closeEvent delegates to it"
  - "NaN endTime guard relaxed to ~isnan(endTime) && endTime < startTime — documents intent explicitly rather than relying on NaN comparison semantics"
  - "EventStore:alreadyClosed is a distinct error from EventStore:unknownEventId — callers can distinguish 'not found' from 'found but already done'"
  - "Wave 0 assumeFail stubs: JVM-gated GUI tests have double assumeFail (JVM guard + main stub) producing 12 calls total in TestFastSenseEventClick.m vs. plan acceptance criteria of 8 — the plan template itself generates this pattern; functional correctness preserved"

requirements-completed: []

# Metrics
duration: 15min
completed: 2026-04-24
---

# Phase 1012 Plan 01: Schema + Wave 0 Scaffolding Summary

**Event.IsOpen + Event.close() + EventStore.closeEvent establish the open-event schema; 9 Wave 0 test/bench files scaffold all remaining phase contracts**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-24
- **Completed:** 2026-04-24
- **Tasks:** 4
- **Files modified:** 11 (2 source, 9 new test/bench)

## Accomplishments
- `Event.IsOpen` (default `false`) enables open-event flagging with zero backward-compatibility impact on existing `.mat` files
- `Event.close(endTime, finalStats)` is the single write path for `SetAccess=private` `EndTime`/`Duration`/stats fields — Plan 02 and 03 mutation goes through here
- `EventStore.closeEvent(eventId, endTime, finalStats)` delegates to `ev.close()`; raises `EventStore:unknownEventId` (2 call sites: empty store + not-found) and `EventStore:alreadyClosed` (found but not open)
- `TestEventIsOpen` (12 tests, MATLAB) + `test_event_is_open` (12 assertions, Octave) fully cover the schema, including backward-compat round-trip via `builtin('save'/'load')`
- 6 Wave 0 stub files provide the failing tests that Plans 02/03 will convert to green
- `bench_event_marker_regression.m` captures baseline Pitfall-10 medians for the 3-config gate that Plan 03 will validate

## Task Commits

1. **Task 1: Extend Event with IsOpen + close() method** - `74ab198` (feat)
2. **Task 2: Add EventStore.closeEvent** - `32a1963` (feat)
3. **Task 3: Create TestEventIsOpen + test_event_is_open** - `48f688a` (test)
4. **Task 4: Wave 0 stubs + Pitfall-10 bench** - `d3b7e68` (test)

## Files Created/Modified
- `libs/EventDetection/Event.m` — Added `IsOpen = false` public property, `close(endTime, finalStats)` method, NaN-aware constructor guard
- `libs/EventDetection/EventStore.m` — Added `closeEvent(eventId, endTime, finalStats)` method after `getEvents()`
- `tests/suite/TestEventIsOpen.m` — 12-test MATLAB xUnit suite for schema + EventStore.closeEvent
- `tests/test_event_is_open.m` — Octave flat-style mirror with 12 try/catch assertions
- `tests/suite/TestMonitorTagOpenEvent.m` — 4 assumeFail stubs (Plan 02)
- `tests/test_monitortag_open_event.m` — Octave mirror with 4 SKIP lines
- `tests/suite/TestFastSenseEventClick.m` — 8 test methods with assumeFail stubs (Plan 03)
- `tests/test_fastsense_event_click.m` — Octave mirror with 8 SKIP lines
- `tests/suite/TestFastSenseWidgetEventMarkers.m` — 8 test methods with assumeFail stubs (Plan 03)
- `tests/test_fastsense_widget_event_markers.m` — Octave mirror with 8 SKIP lines
- `benchmarks/bench_event_marker_regression.m` — Pitfall-10 harness: 3 configs (none/empty/otherTags), 20-iteration median, +/-5% gate

## Decisions Made
- `Event.close()` instance method rather than a public `EndTime` setter — single mutation path aligns with D1 SSOT; `EventStore.closeEvent` calls `ev.close()` rather than mutating fields directly
- NaN guard made explicit (`~isnan(endTime) && endTime < startTime`) rather than relying on IEEE 754 `NaN < x == false` — documents intent for future maintainers
- Two distinct error IDs (`EventStore:unknownEventId` vs `EventStore:alreadyClosed`) rather than a single error ID — callers can differentiate "event not found" from "event found but already closed"

## Deviations from Plan

None — plan executed exactly as written. The acceptance criterion `grep -c "assumeFail" TestFastSenseEventClick.m` equals 12 (not 8 as stated) because the plan template itself generates double `assumeFail` calls for JVM-gated tests; this is consistent with the provided code template and does not affect functional correctness.

## Issues Encountered
None. All tasks executed successfully without requiring Rule 1/2/3 fixes.

## Known Stubs
- `tests/suite/TestMonitorTagOpenEvent.m` — all 4 tests are `assumeFail` stubs; will go green in Plan 1012-02
- `tests/suite/TestFastSenseEventClick.m` — all 8 tests are `assumeFail` stubs; will go green in Plan 1012-03
- `tests/suite/TestFastSenseWidgetEventMarkers.m` — all 8 tests are `assumeFail` stubs; will go green in Plan 1012-03
- Stubs are intentional Wave 0 scaffolding; their downstream plans are defined in the 1012 phase

## Next Phase Readiness
- Plan 1012-02 can now `EventStore.append(ev)` with `ev.IsOpen = true` and later `EventStore.closeEvent(id, t, stats)` — API surface is complete
- `TestMonitorTagOpenEvent.m` stub tests define the exact contract Plan 02 must satisfy
- Bench harness captures pre-phase baseline; Plan 03 will run the same bench and compare

---
*Phase: 1012-live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget*
*Completed: 2026-04-24*

## Self-Check: PASSED

Files verified:
- FOUND: libs/EventDetection/Event.m
- FOUND: libs/EventDetection/EventStore.m
- FOUND: tests/suite/TestEventIsOpen.m
- FOUND: tests/test_event_is_open.m
- FOUND: tests/suite/TestMonitorTagOpenEvent.m
- FOUND: tests/suite/TestFastSenseEventClick.m
- FOUND: tests/suite/TestFastSenseWidgetEventMarkers.m
- FOUND: tests/test_monitortag_open_event.m
- FOUND: tests/test_fastsense_event_click.m
- FOUND: tests/test_fastsense_widget_event_markers.m
- FOUND: benchmarks/bench_event_marker_regression.m

Commits verified:
- FOUND: 74ab198 (feat: Event.IsOpen + close())
- FOUND: 32a1963 (feat: EventStore.closeEvent)
- FOUND: 48f688a (test: TestEventIsOpen + Octave mirror)
- FOUND: d3b7e68 (test: Wave 0 stubs + bench)
