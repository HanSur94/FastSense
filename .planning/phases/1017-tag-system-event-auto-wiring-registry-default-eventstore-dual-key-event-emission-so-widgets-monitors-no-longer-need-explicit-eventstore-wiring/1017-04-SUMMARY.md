---
phase: 1017
plan: "04"
subsystem: Dashboard
tags: [event-store, registry-default, EventTimelineWidget, TableWidget, fallback]
dependency_graph:
  requires: ["1017-01"]
  provides: ["registry-default EventStore auto-wiring for EventTimelineWidget and TableWidget"]
  affects: ["libs/Dashboard/EventTimelineWidget.m", "libs/Dashboard/TableWidget.m"]
tech_stack:
  added: []
  patterns:
    - "local esObj variable to prevent obj-mutation re-entrancy (RESEARCH Pitfall 6)"
    - "resolveEvents moved to public methods block to allow direct test assertion"
key_files:
  created: []
  modified:
    - "libs/Dashboard/EventTimelineWidget.m"
    - "libs/Dashboard/TableWidget.m"
    - "tests/suite/TestDashboardEventsToggle.m"
    - "tests/test_dashboard_events_toggle.m"
decisions:
  - "resolveEvents moved from private to public access to allow test assertions (plan calls w.resolveEvents() directly)"
  - "Pre-existing contains() Octave incompatibility in TableWidget fixed as Rule 1 bug (triggered by new test)"
  - "eventStoreToStructsFrom_ added as private helper — verbatim body of eventStoreToStructs with esObj arg instead of obj.EventStoreObj"
metrics:
  duration: "~15 minutes"
  completed: "2026-04-28"
  tasks: 2
  files: 4
---

# Phase 1017 Plan 04: EventTimelineWidget + TableWidget Registry-Default Fallback Summary

Registry-default EventStore auto-wiring added to EventTimelineWidget (resolveEvents) and TableWidget (events mode refresh) via local esObj pattern, closing the consumer-side read path for Phase 1017.

## What Was Built

### Task 1: EventTimelineWidget + TableWidget registry-default fallback (commit 7d02ca1)

**EventTimelineWidget.resolveEvents:**
- Moved from `methods (Access = private)` to `methods (Access = public)` to allow direct test assertions (plan calls `w.resolveEvents()`)
- Introduced local `esObj = obj.EventStoreObj; if isempty(esObj), esObj = TagRegistry.getEventStore(); end` — no temporary property mutation (RESEARCH Pitfall 6)
- Passes `esObj` to new private helper `eventStoreToStructsFrom_(obj, esObj)` instead of calling `eventStoreToStructs()` which reads `obj.EventStoreObj` directly
- New helper `eventStoreToStructsFrom_` is verbatim copy of `eventStoreToStructs` with `obj.EventStoreObj.getEvents()` replaced by `esObj.getEvents()`

**TableWidget.refresh events branch:**
- Condition changed from `elseif strcmp(obj.Mode, 'events') && ~isempty(obj.EventStoreObj)` to `elseif strcmp(obj.Mode, 'events')`
- Local `esObj` resolves explicit slot then registry default (same pattern)
- All event data reads use `esObj` not `obj.EventStoreObj`

### Task 2: Tests for both fallbacks + explicit override (commit fd0dfef)

Added 3 new MATLAB test methods to `tests/suite/TestDashboardEventsToggle.m`:
- `testRegistryDefaultEventTimeline` — verifies resolveEvents returns events from registry default when EventStoreObj not set
- `testRegistryDefaultTableWidget` — verifies refresh completes without error via registry fallback
- `testEventTimelineExplicitWinsOverRegistry` — verifies explicit EventStoreObj wins over registry default

Added 3 matching Octave blocks (Tests 20-22) to `tests/test_dashboard_events_toggle.m`.

Also fixed pre-existing Octave incompatibility: `contains()` in TableWidget replaced with `~isempty(strfind(...))` (Rule 1 — Bug, triggered by new test exercising the path in Octave).

## Verification Results

All 22 Octave tests pass (`22 passed, 0 failed`).

Acceptance criteria verified:
- `grep -c "esObj = TagRegistry.getEventStore" libs/Dashboard/EventTimelineWidget.m` returns 1
- `grep -c "esObj = TagRegistry.getEventStore" libs/Dashboard/TableWidget.m` returns 1
- `grep -c "function evts = eventStoreToStructsFrom_" libs/Dashboard/EventTimelineWidget.m` returns 1
- `grep -c "elseif strcmp(obj.Mode, 'events')$" libs/Dashboard/TableWidget.m` returns 1
- `grep -c "elseif strcmp(obj.Mode, 'events') && ~isempty(obj.EventStoreObj)" libs/Dashboard/TableWidget.m` returns 0
- All 3 new test methods present in both test files

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Octave-incompatible `contains()` in TableWidget**
- **Found during:** Task 2 test execution
- **Issue:** `mask = arrayfun(@(e) contains(e.SensorName, sName), evts)` at TableWidget.m line 97 uses `contains()` which is not available in Octave 7+. Pre-existing bug triggered by new Test 21 exercising the events branch for the first time in Octave.
- **Fix:** Replaced with `~isempty(strfind(e.SensorName, sName))` which works in both MATLAB and Octave
- **Files modified:** `libs/Dashboard/TableWidget.m`
- **Commit:** fd0dfef

**2. [Rule 2 - Visibility] resolveEvents moved from private to public access**
- **Found during:** Task 1 Octave verification
- **Issue:** Plan's `<verify>` block and Task 2 tests call `w.resolveEvents()` directly, but method was `Access = private`. MATLAB/Octave rejects external calls to private methods.
- **Fix:** Moved `resolveEvents` to its own `methods (Access = public)` block placed before the `methods (Access = private)` block
- **Files modified:** `libs/Dashboard/EventTimelineWidget.m`
- **Commit:** 7d02ca1

### Notes

- The acceptance criterion checking `grep -c "obj.EventStoreObj = " libs/Dashboard/EventTimelineWidget.m` returns `0` is not fully met: the pre-existing `fromStruct` deserializer has `obj.EventStoreObj = EventStore(s.source.path)` which is a legitimate property assignment during construction, not a re-entrancy-risk temporary mutation. The spirit of the criterion (no temporary mutation in resolveEvents) is fully met.

## Known Stubs

None — all data paths are wired.

## Self-Check

- [x] `libs/Dashboard/EventTimelineWidget.m` — modified, contains `esObj = TagRegistry.getEventStore()` and `eventStoreToStructsFrom_`
- [x] `libs/Dashboard/TableWidget.m` — modified, contains `esObj = TagRegistry.getEventStore()` and fixed `strfind`
- [x] `tests/suite/TestDashboardEventsToggle.m` — 3 new test methods added
- [x] `tests/test_dashboard_events_toggle.m` — 3 new Octave test blocks added (Tests 20-22)
- [x] Commit 7d02ca1 — Task 1
- [x] Commit fd0dfef — Task 2
