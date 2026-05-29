---
phase: 05-detachable-widgets
plan: 03
subsystem: ui
tags: [matlab, dashboard, detach, mirror, timer, handle]

# Dependency graph
requires:
  - phase: 05-02
    provides: DashboardLayout.DetachCallback wiring + addDetachButton injection
  - phase: 05-01
    provides: DetachedMirror class with cloneWidget, tick, isStale interface

provides:
  - DashboardEngine.DetachedMirrors registry (cell array of DetachedMirror)
  - DashboardEngine.detachWidget() public method
  - DashboardEngine.removeDetached() public method
  - DashboardEngine.removeDetachedByRef() private helper using containers.Map pattern
  - onLiveTick() mirror tick loop (DETACH-03, DETACH-04, DETACH-06)
  - rerenderWidgets() DetachCallback re-wire after page switch (Pitfall 3)
  - Complete DETACH-02 through DETACH-07 test coverage (7/7 passing)

affects: [06-serialization, future-phases]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "containers.Map as handle-class indirect reference for forward-reference closures in MATLAB"
    - "Mirror tick loop in onLiveTick() before LastUpdateTime for same-tick staleness cleanup"
    - "removeDetachedByRef() separates mirror-identity removal (close) from stale cleanup (tick)"

key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m

key-decisions:
  - "Used containers.Map (handle object) for removeCallback indirect reference — MATLAB closures capture value-class variables by value, so a plain cell {[]} would not reflect the post-construction mirror assignment; containers.Map is a handle class so the closure sees the live value"
  - "removeDetachedByRef() (private) handles close-triggered removal by mirror identity; removeDetached() (public) handles stale cleanup during tick loop — two methods with different matching strategies"
  - "Mirror tick loop placed before obj.LastUpdateTime = now in onLiveTick() so mirrors update in the same tick as active-page widgets"

patterns-established:
  - "Forward-reference closure pattern: use containers.Map when you need a callback to reference an object that doesn't exist yet at callback-creation time"
  - "Two-phase mirror cleanup: identity-based removal on figure close (removeDetachedByRef) + stale-scan cleanup on every tick (onLiveTick staleIdx loop)"

requirements-completed: [DETACH-02, DETACH-03, DETACH-04, DETACH-05, DETACH-06, DETACH-07]

# Metrics
duration: 25min
completed: 2026-04-01
---

# Phase 05 Plan 03: Detachable Widgets — DashboardEngine Integration Summary

**DashboardEngine gains DetachedMirrors registry + detachWidget/removeDetached methods + onLiveTick mirror loop, completing all 7 DETACH tests (DETACH-01 through DETACH-07)**

## Performance

- **Duration:** 25 min
- **Started:** 2026-04-01T06:10:00Z
- **Completed:** 2026-04-01T06:35:00Z
- **Tasks:** 2 (combined into 1 commit)
- **Files modified:** 1

## Accomplishments

- Added `DetachedMirrors = {}` property to `DashboardEngine.SetAccess=private` block
- Implemented `detachWidget()` creating `DetachedMirror` objects with correct `removeCallback` wiring using `containers.Map` forward-reference pattern
- Implemented `removeDetached()` (public, for API compatibility) and `removeDetachedByRef()` (private, for mirror-identity removal on close)
- Extended `onLiveTick()` with mirror tick loop that calls `m.tick()` on live mirrors and cleans stale handles
- Added `DetachCallback` re-wire in `rerenderWidgets()` after `createPanels()` (Pitfall 3 from RESEARCH.md)
- All 7 TestDashboardDetach tests pass; zero regressions in TestDashboardLayout (30 passing, 1 pre-existing flaky timer test)

## Task Commits

1. **Tasks 1+2: Add DetachedMirrors registry + detachWidget + removeDetached + onLiveTick mirror loop** - `d262fa3` (feat)

## Files Created/Modified

- `libs/Dashboard/DashboardEngine.m` — Added DetachedMirrors property, detachWidget(), removeDetached(), removeDetachedByRef() private helper, rerenderWidgets() DetachCallback re-wire, onLiveTick() mirror tick loop

## Decisions Made

**containers.Map as handle-class indirect reference for forward-reference closures:**
The `removeCallback` must be created and passed to `DetachedMirror` before the mirror object exists. MATLAB closures capture value-class variables (cells, structs) by value at creation time — `mirrorRef = {[]}; cb = @() removeByRef(mirrorRef)` followed by `mirrorRef{1} = mirror` would NOT update the captured copy. Using `containers.Map` (a handle class) as the container means the closure captures a reference to the Map object; subsequent mutations (`mirrorHolder('mirror') = mirror`) are visible through that reference.

**Two separate removal methods:**
`removeDetachedByRef()` (private) is called by `onFigureClose` — the figure is still valid at that point, so staleness cannot be used for matching; mirror identity (`obj.DetachedMirrors{i} == target`) is the correct criterion. `removeDetached()` (public) is the stale-cleanup path used in the tick loop and provides the named API from the plan spec.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Plan's removeDetached() matching strategy was incorrect**
- **Found during:** Task 1 (initial implementation + test run)
- **Issue:** The plan spec shows `removeDetached(obj, widget)` matching by `m.Widget == widget` (clone vs original — never equal) and `m.isStale()` (false during onFigureClose since figure not yet deleted). `testCloseRemovesFromRegistry` failed 6/7 after first implementation.
- **Fix:** Replaced cell-based indirect reference (which MATLAB closures snapshot by value) with `containers.Map`-based indirect reference (handle class, mutations visible through all references). Introduced `removeDetachedByRef()` private helper for mirror-identity matching. Kept `removeDetached()` public method for the API contract.
- **Files modified:** `libs/Dashboard/DashboardEngine.m`
- **Verification:** `testCloseRemovesFromRegistry` now passes; all 7/7 TestDashboardDetach tests green
- **Committed in:** `d262fa3`

---

**Total deviations:** 1 auto-fixed (Rule 1 — behavior bug in plan spec)
**Impact on plan:** Required fix for `testCloseRemovesFromRegistry` to pass. Pattern is well-established in MATLAB (containers.Map as handle-class mutable container in closures). No scope creep.

## Issues Encountered

- The `testTimerContinuesAfterError` test in `TestDashboardEngine` was already failing before this plan (verified by git stash + re-run). It is a pre-existing timing-sensitive flaky test unrelated to this plan's changes.

## Next Phase Readiness

- All 7 DETACH requirements (DETACH-01 through DETACH-07) are implemented and tested green
- Phase 05 is complete — detachable live-mirrored widgets fully operational
- Phase 06 (serialization) can proceed; DetachedMirrors are ephemeral (not serialized)

---
*Phase: 05-detachable-widgets*
*Completed: 2026-04-01*

## Self-Check: PASSED

- `/Users/hannessuhr/FastPlot/.planning/phases/05-detachable-widgets/05-03-SUMMARY.md` — FOUND (this file)
- `libs/Dashboard/DashboardEngine.m` — FOUND
- Commit `d262fa3` — FOUND (verified via git log)
- All 7 TestDashboardDetach tests — PASSED (confirmed in test run output above)
