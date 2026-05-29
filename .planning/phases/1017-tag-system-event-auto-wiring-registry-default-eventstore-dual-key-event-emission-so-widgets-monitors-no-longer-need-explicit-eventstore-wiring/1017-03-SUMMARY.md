---
phase: 1017-tag-system-event-auto-wiring-registry-default-eventstore-dual-key-event-emission-so-widgets-monitors-no-longer-need-explicit-eventstore-wiring
plan: 03
subsystem: dashboard
tags: [matlab, fastsense, dashboard, events, tagregistry, eventstore, fastsensewidget]

# Dependency graph
requires:
  - phase: 1017-01
    provides: TagRegistry.setEventStore / getEventStore API and persistent container
  - phase: 1017-02
    provides: MonitorTag constructor fallback to TagRegistry.getEventStore()
provides:
  - FastSense.renderEventLayer_ consults TagRegistry.getEventStore() as final fallback after bound-tag loop
  - FastSenseWidget.render forwards registry-default EventStore to inner FastSense via esForward local variable
  - Three new MATLAB suite tests (TestDashboardEventsToggle) + three Octave parity tests for Plan 03 behaviors
affects:
  - 1017-04
  - 1017-05
  - any consumer of FastSense or FastSenseWidget event-marker rendering

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "registry-default tail: check isempty(es), then es = TagRegistry.getEventStore() after bound-tag loop"
    - "esForward local variable pattern: resolve explicit vs registry default before forwarding to inner object, never mutate obj"

key-files:
  created: []
  modified:
    - libs/FastSense/FastSense.m
    - libs/Dashboard/FastSenseWidget.m
    - tests/suite/TestDashboardEventsToggle.m
    - tests/test_dashboard_events_toggle.m

key-decisions:
  - "Registry tail placed AFTER the bound-tag loop in renderEventLayer_ so tag-level explicit EventStore wins over registry default"
  - "esForward local variable used in FastSenseWidget to avoid mutating obj.EventStore (prevents re-entrancy and side-effects)"
  - "Both the main render() path and the rerender path in FastSenseWidget updated for consistency"
  - "Octave test uses 'Parent', axes() style instead of positional FastSense(axes(fig)) which fails in Octave"

patterns-established:
  - "esForward pattern: local variable resolves explicit-or-registry before forwarding to inner FastSense"
  - "Registry-default tail: always placed as last fallback after explicit and bound-object lookups"

requirements-completed: []

# Metrics
duration: 15min
completed: 2026-04-28
---

# Phase 1017 Plan 03: FastSense + FastSenseWidget Registry-Default Fallback Summary

**FastSense.renderEventLayer_ and FastSenseWidget.render both consult TagRegistry.getEventStore() as final fallback, completing the consumer side of Plan 01's registry API so dashboards built from addWidget('fastsense', 'Tag', s) auto-discover event markers when TagRegistry.setEventStore(es) was called once**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-04-28T00:00:00Z
- **Completed:** 2026-04-28T00:00:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Extended `FastSense.renderEventLayer_` with a 3-line registry-default tail after the bound-tag loop, so plots backed by tags with empty EventStore still render event markers when TagRegistry.setEventStore was called
- Extended `FastSenseWidget.render` (both the main render path and the rerender path) with the `esForward` local variable pattern, forwarding the registry-default EventStore to the inner FastSense without mutating widget state
- Added 3 MATLAB suite tests and 3 Octave parity tests verifying both fallback sites and the explicit-wins-over-registry contract

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend FastSense.renderEventLayer_ and FastSenseWidget.render with registry-default fallback** - `2007baa` (feat)
2. **Task 2: Add MATLAB + Octave tests covering FastSense and FastSenseWidget registry-default fallback + explicit override** - `064d0c2` (test)

## Files Created/Modified
- `libs/FastSense/FastSense.m` - Added 3-line registry-default tail to renderEventLayer_ after bound-tag loop
- `libs/Dashboard/FastSenseWidget.m` - Replaced 3-line forwarding guard with esForward local variable pattern (both render and rerender paths)
- `tests/suite/TestDashboardEventsToggle.m` - Added testRegistryDefaultFastSense, testRegistryDefaultFastSenseWidget, testFastSenseWidgetExplicitWinsOverRegistry + closeIfValid helper
- `tests/test_dashboard_events_toggle.m` - Added Tests 17-19 as Octave parity for the three new MATLAB test methods

## Decisions Made
- Registry tail placed AFTER the bound-tag loop so bound-tag's explicit EventStore (if present) still wins over the registry default, matching the "explicit-wins-silently" contract from CONTEXT.md
- `esForward` local variable pattern used in FastSenseWidget instead of temporarily mutating `obj.EventStore`, avoiding re-entrancy risk (RESEARCH Pitfall 6)
- Both render() and the rerender path in FastSenseWidget updated for consistency; refresh() intentionally not changed (RESEARCH Pitfall 2: fp.EventStore is set once at render time; canonical usage is set-store-before-render)
- Octave test fixed to use `axes('Parent', fig)` + `FastSense('Parent', ax)` instead of `FastSense(axes(fig))` which fails in Octave's argument parser

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed Octave-incompatible FastSense construction in test**
- **Found during:** Task 2 (Octave parity tests)
- **Issue:** `FastSense(axes(fig))` fails in Octave with "args(2): out of bound 1" - Octave's parseOpts rejects positional axes handle
- **Fix:** Changed to `ax = axes('Parent', fig); fp = FastSense('Parent', ax)` which works in both MATLAB and Octave
- **Files modified:** tests/test_dashboard_events_toggle.m
- **Verification:** All 19 Octave tests pass after fix
- **Committed in:** 064d0c2 (Task 2 commit)

**2. [Rule 2 - Missing] Updated second render path in FastSenseWidget**
- **Found during:** Task 1 (FastSenseWidget.render edit)
- **Issue:** FastSenseWidget has a rerender method (line ~732) with an identical forwarding guard that also needed the esForward update
- **Fix:** Applied same esForward pattern to the rerender path
- **Files modified:** libs/Dashboard/FastSenseWidget.m
- **Verification:** grep confirms zero remaining fp.EventStore = obj.EventStore direct assignments
- **Committed in:** 2007baa (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 bug, 1 missing critical)
**Impact on plan:** Both fixes essential for correctness. No scope creep.

## Issues Encountered
None beyond the two auto-fixed deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- FastSense and FastSenseWidget consumer paths complete; EventTimelineWidget and TableWidget registry fallbacks remain (Plans 04-05)
- All 19 Octave tests green; MATLAB suite extended with 3 new test methods

## Known Stubs
None - all registry fallback paths are fully wired.

---
*Phase: 1017-tag-system-event-auto-wiring-registry-default-eventstore-dual-key-event-emission-so-widgets-monitors-no-longer-need-explicit-eventstore-wiring*
*Completed: 2026-04-28*
