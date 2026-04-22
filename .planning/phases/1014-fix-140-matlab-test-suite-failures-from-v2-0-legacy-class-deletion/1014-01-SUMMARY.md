---
phase: 1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion
plan: 01
subsystem: tests-matlab-suite
tags: [category-c, category-e, test-migration, r2020b-compat, dashboard-builder]
requires:
  - .planning/phases/1014-.../1014-CONTEXT.md
  - .planning/phases/1014-.../1014-RESEARCH.md
provides:
  - "R2020b-compatible properties-block fixture pattern in TestNavigatorOverlay.m (canonical Category C reference for Wave 1)"
  - "TestSensorDetailPlot.m TestData.sensor migrated — Category C subset complete; Category A deferred to Plan 04"
  - "TestDashboardBugFixes/testSensorListenersMultiPage now fires PostSet via SensorTag.updateData"
  - "DashboardBuilder.exitEditMode guarded — safe against externally-deleted figure"
affects:
  - tests/suite/TestNavigatorOverlay.m
  - tests/suite/TestSensorDetailPlot.m
  - tests/suite/TestDashboardBugFixes.m
  - libs/Dashboard/DashboardBuilder.m
tech-stack:
  added: []
  patterns:
    - "properties (Access = private) + TestMethodSetup fixture (R2020b-native; replaces R2023a-only testCase.TestData)"
    - "Early ishandle guard before first set(hFig, ...) call in handle-cleanup methods"
key-files:
  created: []
  modified:
    - tests/suite/TestNavigatorOverlay.m
    - tests/suite/TestSensorDetailPlot.m
    - tests/suite/TestDashboardBugFixes.m
    - libs/Dashboard/DashboardBuilder.m
decisions:
  - "Task 2 migrated only testCase.TestData.sensor — Category A legacy-class methods (Sensor/Threshold/ThresholdRule calls) deliberately untouched (Plan 04 scope per D-02-A)"
  - "DashboardBuilder edit is strictly confined to exitEditMode — no other methods touched per D-05 library-cascade guard"
  - "The local variable [s_x_, s_y_] = s.getXY() in testSensorListenersMultiPage remains (pre-existing assignment above the fix site); it is no longer the mutation path but has no harmful side-effect"
metrics:
  duration: ~8 min
  completed-date: 2026-04-22
  tasks: 4
  files-modified: 4
  commits: 4
---

# Phase 1014 Plan 01: Wave 0 — Category C pilot + Category E fixes — Summary

Wave 0 unblocker for Phase 1014: seeded the canonical R2020b-compatible `properties (Access = private)` fixture pattern in `TestNavigatorOverlay.m` (the Category C reference for Wave 1), migrated the `TestData.sensor` subset of `TestSensorDetailPlot.m`, repaired the `testSensorListenersMultiPage` PostSet trigger by switching from local-variable assignment to `SensorTag.updateData`, and added an `ishandle(hFig)` guard at the top of `DashboardBuilder.exitEditMode` so the method no longer throws when the underlying figure was deleted externally.

## Tasks

1. **Task 1 — TestNavigatorOverlay.m migration** (commit `3c257b0`). Added `properties (Access = private)` block for `hFig`, `hAxes`. Replaced all 17 `testCase.TestData.{hFig,hAxes}` references with `testCase.{hFig,hAxes}` across `createFixture`, `destroyFixture`, and all 10 test methods. No behavioural change.

2. **Task 2 — TestSensorDetailPlot.m Category C subset** (commit `0690030`). Added `properties (Access = private) sensor end` block. Replaced all 16 `testCase.TestData.sensor` references with `testCase.sensor`. Category A methods (legacy `Sensor(...)`, `Threshold(...)`, `ThresholdRule(...)` calls + the `createTagWithThreshold` static helper) left intact — they are Plan 04's responsibility per D-02-A.

3. **Task 3 — testSensorListenersMultiPage fix** (commit `882160c`). Replaced the broken `s_y_ = rand(1, 10)` local-variable assignment at `TestDashboardBugFixes.m:264` with `s.updateData(1:10, rand(1, 10))`, which is the canonical SensorTag mutation path and fires the PostSet listener chain (SensorTag.m:265 — `notifyListeners_`).

4. **Task 4 — DashboardBuilder.exitEditMode guard** (commit `fef4c40`). In `libs/Dashboard/DashboardBuilder.m` at lines 123–131, wrapped the first two `set(hFig, 'WindowButtonMotionFcn', ...)` / `set(hFig, 'WindowButtonUpFcn', ...)` calls in a `if ~isempty(hFig) && ishandle(hFig)` guard. The pre-existing late guard at line ~147 is preserved. No other methods in DashboardBuilder.m were touched.

## Exact lines changed (libs edit)

- Before: `set(hFig, 'WindowButtonMotionFcn', obj.OldMotionFcn);` at line 124 (unguarded, would throw on deleted figure).
- After: the same two `set()` calls at lines 128–129, now wrapped in `if ~isempty(hFig) && ishandle(hFig)` (guard block spans lines 123–131).
- File touches: `exitEditMode` method only. `git diff libs/Dashboard/DashboardBuilder.m` shows a single additive hunk; `enterEditMode`, `onMouseMove`, `onMouseUp`, `applyProperties`, `addWidget`, `deleteWidget`, `selectWidget`, sidebar creators, drag/resize state, ghost/grid helpers, `populateSourceControls`, `applyDataSource`, etc. are byte-for-byte unchanged.

## Test methods expected to move red → green

- `TestNavigatorOverlay.m` — all 10 test methods (previously errored at R2020b fixture setup due to `testCase.TestData`):
  - testConstructorCreatesOverlay, testSetRangeUpdatesPatches, testSetRangeClampsToAxesLimits, testSetRangeEnforcesMinimumWidth, testCallbackFiresOnSetRange, testDeleteRemovesGraphics, testDeleteRestoresFigureCallbacks, testPanPreservesWidthAtLeftBoundary, testPanPreservesWidthAtRightBoundary, testHoldStatePreserved
- `TestDashboardBugFixes.m` — 2 test methods:
  - testSensorListenersMultiPage (test-side fix — PostSet now fires via updateData)
  - testExitEditModeAfterFigureClose (library-side fix — guard stops throw)

**Total expected newly-passing methods: 12.**

## Remaining failures in touched files (expected — out of scope)

- `TestSensorDetailPlot.m` still has Category A failures (methods using `Sensor(...)`, `Threshold(...)`, `ThresholdRule(...)`, and the `createTagWithThreshold` static helper). These remain by design — they are the exclusive scope of Plan 1014-04 per D-02-A and the phase decomposition.

## Deviations from Plan

None. Plan executed exactly as written. No architectural surprises, no Rule 1/2/3 auto-fixes required.

## Libraries touched

- `libs/Dashboard/DashboardBuilder.m` — ONLY authorized library edit in Phase 1014 per D-02-E + D-05. No widget files, no SensorThreshold files, no EventDetection files, no FastSense files were modified. Confirmed by `git diff --stat` against base.

## Verification

- MISS_HIT: `mh_style` + `mh_lint` + `mh_metric --ci` on all 4 touched files → CLEAN (0 warnings, 0 errors).
- Octave function-style suite: **75/75 tests passed, 0 failed** (Pitfall 6 gate — the library fix does not regress `test_dashboard_builder_interaction.m` or any neighbour).
- Grep gates:
  - `grep -c "testCase\.TestData" tests/suite/TestNavigatorOverlay.m` → 0
  - `grep -c "testCase\.TestData" tests/suite/TestSensorDetailPlot.m` → 0
  - `grep -c "s_y_ = rand" tests/suite/TestDashboardBugFixes.m` → 0
  - `grep -c "s\.updateData(1:10, rand(1, 10))" tests/suite/TestDashboardBugFixes.m` → 1
  - `grep -cE "if ~isempty\(hFig\) && ishandle\(hFig\)" libs/Dashboard/DashboardBuilder.m` → 1
  - `grep -cE "if isempty\(hFig\) \|\| ~ishandle\(hFig\)" libs/Dashboard/DashboardBuilder.m` → 1 (late guard preserved)

**Authoritative MATLAB run deferred to CI** — the orchestrator's environment has no R2020b MATLAB. The `Tests → MATLAB Tests` CI job will confirm the 12 newly-passing methods when the branch is pushed.

## Commits

| Task | Hash      | Message                                                                                       |
| ---- | --------- | --------------------------------------------------------------------------------------------- |
| 1    | `3c257b0` | fix(1014-test): migrate TestNavigatorOverlay TestData→properties                              |
| 2    | `0690030` | fix(1014-test): migrate TestSensorDetailPlot TestData.sensor→property (Category C only)       |
| 3    | `882160c` | fix(1014-test): TestDashboardBugFixes/testSensorListenersMultiPage — fire PostSet via updateData |
| 4    | `fef4c40` | fix(1014-lib): DashboardBuilder.exitEditMode — guard set() with ishandle before cleanup       |

## Self-Check: PASSED

- tests/suite/TestNavigatorOverlay.m — FOUND (modified)
- tests/suite/TestSensorDetailPlot.m — FOUND (modified)
- tests/suite/TestDashboardBugFixes.m — FOUND (modified)
- libs/Dashboard/DashboardBuilder.m — FOUND (modified)
- Commit 3c257b0 — FOUND in git log
- Commit 0690030 — FOUND in git log
- Commit 882160c — FOUND in git log
- Commit fef4c40 — FOUND in git log
- MISS_HIT style/lint/metric — CLEAN on all 4 files
- Octave suite — 75/75 green (no regression from libs edit)

## Handoff to Wave 1

- **Category C pattern seeded** in `tests/suite/TestNavigatorOverlay.m` — Wave 1 plans (1014-02 through 1014-05) should copy the `properties (Access = private)` + `TestMethodSetup` shape when migrating any remaining `testCase.TestData.*` references they encounter.
- **Library fix live** — Plan 04 and any downstream consumer can rely on `DashboardBuilder.exitEditMode` being safe against deleted figures.
- **Category A in TestSensorDetailPlot.m is Plan 04's exclusive scope** — the `sensor` property now exists; Plan 04 can reuse it rather than re-introducing its own fixture.
