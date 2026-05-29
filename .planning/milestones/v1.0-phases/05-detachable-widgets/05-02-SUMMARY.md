---
phase: 05-detachable-widgets
plan: "02"
subsystem: ui
tags: [matlab, dashboard, detach, widget, uicontrol]

# Dependency graph
requires:
  - phase: 05-01
    provides: DetachedMirror class and TestDashboardDetach scaffold with testDetachButtonInjected

provides:
  - DashboardLayout.DetachCallback public property (set by DashboardEngine)
  - DashboardLayout.addDetachButton() private method injecting '^' button at [0.82 0.90 0.08 0.08]
  - realizeWidget() extended to call addDetachButton() when DetachCallback is non-empty
  - DashboardEngine.render() sets Layout.DetachCallback = @(w) obj.detachWidget(w)

affects:
  - 05-03 (DashboardEngine.detachWidget() wiring — DetachCallback already set, just needs method implementation)

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "addDetachButton() mirrors addInfoIcon() structure exactly — theme fallback, uicontrol creation, normalized position"
    - "DetachCallback lambda injection pattern consistent with OnScrollCallback and ReflowCallback"

key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardLayout.m
    - libs/Dashboard/DashboardEngine.m

key-decisions:
  - "DashboardEngine.render() sets Layout.DetachCallback = @(w) obj.detachWidget(w) as a forward reference; detachWidget() stub not needed — callback is only invoked on button click"
  - "Detach button String='^' (ASCII caret) per RESEARCH.md open question 2 — safe cross-platform fallback"

patterns-established:
  - "Button injection pattern: unconditional guard on non-empty callback property, then private add*() helper"

requirements-completed:
  - DETACH-01

# Metrics
duration: 2min
completed: 2026-04-02
---

# Phase 5 Plan 02: Detach Button Injection Summary

**DetachCallback property + addDetachButton() added to DashboardLayout, injecting a '^' button at [0.82 0.90 0.08 0.08] in every widget panel when callback is wired — DETACH-01 satisfied**

## Performance

- **Duration:** 2 min
- **Started:** 2026-04-02T06:01:46Z
- **Completed:** 2026-04-02T06:04:42Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Added `DetachCallback = []` public property to DashboardLayout (after OnScrollCallback in public properties block)
- Added private `addDetachButton()` method mirroring addInfoIcon() structure: theme fallback, uicontrol with Tag='DetachButton', Position=[0.82 0.90 0.08 0.08], Callback=@(~,~) obj.DetachCallback(widget)
- Extended `realizeWidget()` to call addDetachButton() when DetachCallback is non-empty
- Set `Layout.DetachCallback = @(w) obj.detachWidget(w)` in DashboardEngine.render() so button is injected on every render
- testDetachButtonInjected now passes; 4/7 TestDashboardDetach tests pass total (3 wiring tests still expected-fail for plan 03)
- All 8 TestDashboardLayout tests continue to pass with no regression

## Task Commits

1. **Task 1: Add DetachCallback property and addDetachButton() to DashboardLayout** - `d3ce8f9` (feat)
2. **Task 2: Verify testDetachButtonInjected passes after DashboardLayout change** - `d3ce8f9` (included in same commit — DashboardEngine.render() wiring needed for test)

## Files Created/Modified

- `libs/Dashboard/DashboardLayout.m` - Added DetachCallback property, extended realizeWidget(), added addDetachButton() private method
- `libs/Dashboard/DashboardEngine.m` - Added Layout.DetachCallback wiring in render() before allocatePanels()

## Decisions Made

- DashboardEngine.render() sets `Layout.DetachCallback = @(w) obj.detachWidget(w)` as a forward reference. The lambda captures `obj` but `detachWidget` doesn't need to exist at assignment time in MATLAB — it's only invoked when user clicks the button. Plan 03 will implement the actual method. This approach means no test stub is needed.
- Used the same approach as Plan 03's expected final wiring — no temporary stub — keeping the diff minimal and the final state clean.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Added DashboardEngine.render() DetachCallback wiring**
- **Found during:** Task 2 (testDetachButtonInjected verification)
- **Issue:** Plan stated "DashboardEngine wiring happens in plan 03" but testDetachButtonInjected calls `d.render()` and expects button injection. Without DetachCallback being set, button would never appear.
- **Fix:** Added `obj.Layout.DetachCallback = @(w) obj.detachWidget(w)` in DashboardEngine.render() immediately before allocatePanels(). This is the exact wiring plan 03 would add anyway.
- **Files modified:** libs/Dashboard/DashboardEngine.m
- **Verification:** testDetachButtonInjected passes; 4/7 TestDashboardDetach pass
- **Committed in:** d3ce8f9 (Task 1+2 commit)

---

**Total deviations:** 1 auto-fixed (missing critical wiring for test to pass)
**Impact on plan:** Essential for testDetachButtonInjected to pass. Adds minimal code that plan 03 would add anyway — no scope creep.

## Issues Encountered

None — implementation was clean. The only issue was the test requiring DashboardEngine wiring that plan 03 was supposed to add, resolved via deviation Rule 2.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DETACH-01 is satisfied: every widget panel gets a DetachButton after realizeWidget() when DetachCallback is wired
- DashboardEngine.Layout.DetachCallback is already set to `@(w) obj.detachWidget(w)` — plan 03 only needs to implement `detachWidget()` and `DetachedMirrors` property
- 4/7 TestDashboardDetach pass; 3 remaining tests (testDetachOpensWindow, testMirrorTickedOnLive, testCloseRemovesFromRegistry) will pass after plan 03 implements DashboardEngine.detachWidget()

---
*Phase: 05-detachable-widgets*
*Completed: 2026-04-02*

## Self-Check: PASSED

- FOUND: .planning/phases/05-detachable-widgets/05-02-SUMMARY.md
- FOUND: libs/Dashboard/DashboardLayout.m
- FOUND: libs/Dashboard/DashboardEngine.m
- FOUND: commit d3ce8f9
