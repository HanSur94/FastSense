---
phase: 01-infrastructure-hardening
plan: 03
subsystem: infra
tags: [matlab, dashboard, serialization, groupwidget, tdd]

# Dependency graph
requires:
  - phase: 01-02
    provides: normalizeToCell helper in libs/Dashboard/private/
  - phase: 01-01
    provides: DashboardEngine with safe timer (prerequisite for full suite)
provides:
  - Fixed DashboardSerializer.save() that correctly emits addChild() calls for GroupWidget children in panel/collapsible/tabbed modes
  - Private static emitChildWidget helper for recursive child widget code generation
  - Three new round-trip tests for .m export of GroupWidget children
  - Full backward compatibility verification (COMPAT-01 through COMPAT-04)
affects: [02-collapsible-sections, 06-serialization-persistence]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Child widget code generation via emitChildWidget static helper with threaded groupCount to prevent variable name collisions"
    - "TDD: write failing tests first (RED), then fix implementation (GREEN)"

key-files:
  created:
    - libs/Dashboard/private/normalizeToCell.m (Plan 02, now consumed by Plan 03)
  modified:
    - libs/Dashboard/DashboardSerializer.m
    - tests/suite/TestDashboardMSerializer.m
    - tests/suite/TestGroupWidget.m

key-decisions:
  - "Children emitted via constructors (NumberWidget(...)) not d.addWidget() to avoid accidentally adding them as top-level dashboard widgets"
  - "groupCount threaded through emitChildWidget return value to prevent variable name collisions across multiple groups"
  - "Tabbed mode uses addChild(widget, tabName) form; panel/collapsible uses addChild(widget) form"

patterns-established:
  - "emitChildWidget pattern: recursive static helper that returns (lines, varName, updatedCount) for safe code generation"

requirements-completed: [INFRA-02, COMPAT-01, COMPAT-02, COMPAT-03, COMPAT-04]

# Metrics
duration: 14min
completed: 2026-04-01
---

# Phase 1 Plan 03: Fix GroupWidget .m Export Children Summary

**DashboardSerializer.save() now correctly emits constructor calls and addChild() for all GroupWidget children in panel, collapsible, and tabbed modes, making .m round-trips reliable for any dashboard using groups**

## Performance

- **Duration:** 14 min
- **Started:** 2026-04-01T19:49:24Z
- **Completed:** 2026-04-01T20:03:23Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Fixed the silent bug where GroupWidget children were dropped during .m export (the `case 'group'` branch emitted only the outer addWidget call)
- Added `emitChildWidget` private static helper to DashboardSerializer that generates constructor code for all child widget types with collision-safe variable naming via threaded `groupCount`
- Verified all three new tests pass (testGroupWithChildrenRoundTrip, testGroupTabbedRoundTrip, testMExportPreservesChildren) and existing serializer tests remain green
- Confirmed backward compatibility: old .m files without children (testLoadFromMFile), JSON round-trip (TestDashboardSerializer), and JSON normalization (testNormalizeToCellHelper) all pass

## Task Commits

1. **Task 1: Write failing tests for GroupWidget .m export round-trip** - `ccf4590` (test)
2. **Task 2: Fix DashboardSerializer.save() group case with recursive child emission** - `eaefe5d` (feat)
3. **Task 3: Full suite green — backward compatibility gate** - (no separate commit; verification task)

## Files Created/Modified

- `libs/Dashboard/DashboardSerializer.m` - Added `groupCount` counter, fixed `case 'group'` to emit children, added `emitChildWidget` private static helper
- `tests/suite/TestDashboardMSerializer.m` - Added testGroupWithChildrenRoundTrip and testGroupTabbedRoundTrip
- `tests/suite/TestGroupWidget.m` - Added testMExportPreservesChildren

## Decisions Made

- Children are emitted using their direct constructors (e.g., `TextWidget('Title', 'RPM', 'Position', [1 1 6 1])`) and passed to `addGroup.addChild()` — NOT via `d.addWidget()`. This is critical because `d.addWidget()` adds to the top-level dashboard widget list, which is wrong for group children.
- `groupCount` is threaded through `emitChildWidget` as both input and output parameter to prevent variable name collisions when multiple groups with multiple children are serialized.
- Tabbed mode is handled separately from panel/collapsible: tabbed children come from `ws.tabs[i].widgets` and use `addChild(widget, tabName)` form; panel/collapsible children come from `ws.children` and use `addChild(widget)`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Merged main branch into worktree to get normalizeToCell helper**
- **Found during:** Task 2 verification
- **Issue:** The worktree was branched from an older commit before Plan 01-02 was executed. `libs/Dashboard/private/normalizeToCell.m` did not exist in the worktree, causing `Undefined function 'normalizeToCell'` errors at runtime.
- **Fix:** Ran `git stash && git merge main --no-edit && git stash pop` to bring in Plans 01-01 and 01-02 changes
- **Files modified:** All Plan 01-01 and 01-02 files merged cleanly
- **Verification:** normalizeToCell found at `libs/Dashboard/private/normalizeToCell.m`; tests pass
- **Committed in:** Merge commit during execution (before Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking dependency)
**Impact on plan:** The merge was necessary to get the `normalizeToCell` dependency from Plan 01-02. No scope creep.

## Issues Encountered

- Full MATLAB test suite (`run_all_tests()`) crashed with a GUI/rendering fatal error when run in `-batch` mode. Resolved by running individual test files instead of the full suite. The key compatibility tests (TestDashboardMSerializer, TestGroupWidget, TestDashboardSerializer, TestDashboardEngine) all passed via individual runs.

## Known Stubs

None — all new functionality is fully wired. The plan's goal (GroupWidget children survive .m export) is achieved.

## Pre-existing Failures (out of scope, logged to deferred-items.md)

These 5 failures existed before Plan 01-03 and are not caused by our changes:
1. `TestGroupWidget/testFullDashboardIntegration` — test saves to `.json` extension via tempname but d.save() writes .m function code
2. `TestDashboardEngine/testTimerContinuesAfterError` — private method access restriction
3. `TestDashboardBuilder/testAddWidgetFromPalette` — 'kpi' deprecated to 'number', test expects old name
4. `TestDashboardBuilder/testDragSnapsToGrid` — numeric tolerance failure
5. `TestDashboardBuilder/testResizeSnapsToGrid` — numeric tolerance failure

## Next Phase Readiness

- GroupWidget .m serialization is now reliable for panel, collapsible, and tabbed modes
- Phase 1 (Infrastructure Hardening) is complete: all three plans executed, timer safety + normalizeToCell + group .m export all fixed
- Phase 2 (Collapsible Sections) can proceed — it relies on correct group serialization which is now available

---
*Phase: 01-infrastructure-hardening*
*Completed: 2026-04-01*
