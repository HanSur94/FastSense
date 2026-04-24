# Phase 1006 — Requirements

**Goal:** Fix the 137 MATLAB test failures (155 failure events) surfaced when quick task 260416-j6e enabled MATLAB tests on every push/PR and removed `continue-on-error: true`. Pre-existing failures, now honest CI signal. Root-cause categorization lives in `.planning/debug/matlab-tests-failures-investigation.md`.

## Current state (as of 2026-04-16 post-quick-task-k23)

- MATLAB Tests job runs on every push/PR, no `continue-on-error` masking
- CI uses `matlab-actions/setup-matlab@v3` with no version pin — currently resolves to R2025b
- Project claims R2020b+ support per CLAUDE.md; tests written for older MATLAB behavior
- Octave Tests: 69/69 passing on the same codebase (dual-runtime split — tests/test_*.m vs tests/suite/Test*.m)
- CI run that exposed this: https://github.com/HanSur94/FastSense/actions/runs/24510852026 (job 71641840049)
- PR: https://github.com/HanSur94/FastSense/pull/44 (draft, test-only)

## Requirements

### MATLABFIX-G: Version pinning policy (infrastructure decision — consider first)
Planner should run `/gsd:discuss-phase 1006` with `discuss` scope on this requirement alone, BEFORE planning A-F. The outcome reshapes all other requirements:

**Option G1: Pin to R2020b** — matches project's documented support target. Likely eliminates Categories B (TestData removed post-R2020b), C (private access enforcement is newer), and D (all 4 API changes are post-R2020b). Tradeoff: validates the documented target but not what real MATLAB users have.

**Option G2: Pin to R2024b** — LTS-style midpoint. May eliminate some but not all of B/C/D.

**Option G3: Accept R2025b** — keep `setup-matlab@v3` default. Update CLAUDE.md to say "MATLAB R2020b+ supported, R2025b tested in CI". Forces fixing every category. Most honest.

**Option G4: Matrix** — run R2020b AND R2025b in CI. 2x cost, maximum coverage. Probably overkill for a solo project.

**Recommended:** Option G1 (pin R2020b) first. Saves ~71 tests worth of work (B+C+D). If the project genuinely wants R2025b support, revisit after shipping A + E + F.

### MATLABFIX-A: mksqlite MEX availability (~50 tests) — HIGHEST ROI
**Affected:** TestMksqliteEdgeCases (26), TestMksqliteTypes (24)
**Error:** `Undefined function 'mksqlite' for input arguments of type 'char'`

**Investigation needed:**
1. Does the `build-mex-matlab` job artifact actually contain `libs/FastSense/mksqlite.mexa64`? Add `ls libs/FastSense/mksqlite.*` to the CI before tests to confirm.
2. If present, why isn't MATLAB finding it on path? (install.m adds the parent, MEX should be auto-discovered.)
3. If absent, does `install.m` under MATLAB actually build mksqlite? Check `build_mex.m` path for the mksqlite branch.

**Fix options (pick based on investigation):**
- (A1) Ensure artifact contains the file; fix cache key if stale
- (A2) If mksqlite compilation is failing silently under R2025b, address that
- (A3) Add `skipUnless(exist('mksqlite') == 3)` guard to both suites mirroring `TestMexEdgeCases`

**Target:** 0 failures in TestMksqliteEdgeCases + TestMksqliteTypes.

### MATLABFIX-B: testCase.TestData migration (~41 tests) — only needed if G = G2 or G3
**Affected:** TestNavigatorOverlay (20), TestSensorDetailPlot (21)
**Error:** `Unrecognized method, property, or field 'TestData' for class 'TestNavigatorOverlay'`

**Root cause:** `testCase.TestData.xxx = ...` dynamic struct worked on `matlab.unittest.TestCase` in older MATLAB/Octave but is unavailable/removed in R2025b.

**Fix:** Replace with explicit `properties` block on the test class. Pattern:
```matlab
% Before:
methods (TestMethodSetup)
    function setup(testCase)
        testCase.TestData.sensor = mySensor();
    end
end

% After:
properties
    Sensor
end
methods (TestMethodSetup)
    function setup(testCase)
        testCase.Sensor = mySensor();
    end
end
```

**Target:** 0 failures in TestNavigatorOverlay + TestSensorDetailPlot.

### MATLABFIX-C: Private method access (~12 tests) — only needed if G = G2 or G3
**Affected:** TestDataStoreWAL (2), TestMultiStatusWidget (4), TestWebBridge (5), TestDashboardPerformance (1)
**Error:** `MATLAB:class:MethodRestricted — Cannot access method 'X'`

**Methods:**
- `FastSenseDataStore.ensureOpen`
- `MultiStatusWidget.expandSensors_`
- `DashboardEngine.onTimeSlidersChanged`
- `WebBridge.startTcp`

**Fix:** Apply test-friend access pattern:
```matlab
methods (Access = {?matlab.unittest.TestCase})
    function ... = ensureOpen(obj)
    ...
```
This preserves encapsulation from normal callers while allowing any TestCase subclass to invoke.

**Target:** 0 failures from private access errors in the 4 suites.

### MATLABFIX-D: R2025b API compatibility (~18 tests) — only needed if G = G3
**Affected:** TestLoadModuleMetadata (10), TestToolbar (3), TestDashboardSerializerRoundTrip (4), TestDatastoreEdgeCases (1)

**D1. `table()` char first-arg** — 10 tests. R2025b treats `table('Date', datetime(...))` as row-label + positional args rather than (name, value). Fix with `cell2table` or explicit `'VariableNames'`. Affects `loadModuleMetadata.m` (library code) AND the test's helper.

**D2. `OnOffSwitchState` vs char** — 3 tests. Replace `verifyEqual(btn.Enable, 'off')` with `verifyEqual(string(btn.Enable), 'off')` or explicit enum compare.

**D3. `jsondecode` orientation** — 4 tests. R2025b returns column vectors where tests expect row vectors. Either transpose after decode or relax assertions to accept both.

**D4. `fread` negative size guard** — 1 test. Add input validation in `FastSenseDataStore.getRangeBinary` before the `fread` call.

**D5. Abstract class try-catch** — 1 test. TestDataSource/testCannotInstantiate logic may need update.

**Target:** 0 failures from R2025b API changes.

### MATLABFIX-E: Stale test expectations (~21 tests) — needed regardless of G choice
These are real code-vs-test drift issues that would fail even on R2020b:

| # | Test | Issue | Fix location |
|---|------|-------|--------------|
| E1 | TestDashboardEngine/testAddCollapsible* (3) | `DashboardEngine('Name', 'Test')` — 'Test' treated as option key | Test: change to `DashboardEngine('Test')` |
| E2 | TestDashboardEngine/testTimerContinuesAfterError | Calls nonexistent `isrunning()` | Test: use `strcmp(t.Running, 'on')` |
| E3 | TestDashboardBugFixes/testKpiWidgetThemeOverrideMerge | `KpiWidget` class removed | Test: retarget to NumberWidget, OR delete test if obsolete |
| E4 | TestDashboardBugFixes/testAddWidgetDefaultTitle | Title `'New KPI'` → `'New Widget'` after rename | Test: update expected value |
| E5 | TestDashboardBuilder/testToolbarEditToggle | Button text expectation outdated | Test: update |
| E6 | TestDashboardBuilder/testAddWidgetFromPalette | Type stored as `'number'` not `'kpi'` after deprecation | Test: update expected type |
| E7 | TestCompositeThreshold/testFromStructMissingChildKeyWarns | Warning ID renamed `loadChildFailed` → `unknownChildKey` | Test: update warning ID |
| E8 | TestNotificationRule/testConstructor, TestNotificationService/testRuleMatchingPriority (4) | Double-wrap `Recipients` cell | Test: pass `{'a@b.com'}` not `{{'a@b.com'}}` |
| E9 | TestEventTimelineWidget/testToStruct, /testFromStruct (2) | SensorKeys cell-vs-char mismatch | Test or property: decide storage format and align |
| E10 | TestDashboardBuilder/testDragSnapsToGrid, /testResizeSnapsToGrid, TestDashboardBuilderInteraction/testDrag*/testResize*, TestDashboardDirtyFlag/testResizeMarksDirty (6) | Grid snap math off | Investigate: is `DashboardLayout.getColumnPosition()` calculation changed, or is test calibration wrong? |

**Note:** E10 is the largest uncertainty — may be substantive logic bug, not just test drift.

**Target:** 0 failures from stale expectations.

### MATLABFIX-F: Headless CI for image export (4 tests)
**Affected:** TestDashboardToolbarImageExport
**Error:** `DashboardEngine:imageWriteFailed — Running using -nodisplay... not supported`

**Fix options:**
- (F1) Add `xvfb-run` wrapper to the MATLAB CI `run-command` step (same pattern as Octave job)
- (F2) Use MATLAB's `exportgraphics()` with headless support in `DashboardEngine.exportImage`
- (F3) Tag tests with `TestTags = {'RequiresDisplay'}` and filter from headless CI

**Recommended:** F2 (fix the library to work headless) — most robust, benefits non-CI headless users too. F1 is the CI-only workaround. F3 is the "skip and forget" escape hatch.

**Target:** 0 failures in TestDashboardToolbarImageExport.

## Constraints

1. **No Octave regressions.** Every change must keep the 69/69 Octave test pass rate intact. Use `exist('OCTAVE_VERSION','builtin')` branches where MATLAB-only fixes would break Octave.
2. **ROI-ordered planning.** A + B + F together recovers ~95 tests (62%) with mechanical fixes. Plan those first. C/D/E are lower ROI per hour.
3. **G decides reshape.** Planner should run `/gsd:discuss-phase 1006` to resolve G before detailing A-F. If G1 (pin R2020b), categories B/C/D mostly vanish and the phase shrinks dramatically.
4. **No masking.** Do NOT re-add `continue-on-error: true` on the MATLAB job. Do NOT re-gate to `schedule || workflow_dispatch`. CI must remain honest.
5. **Progress metric:** failure count reduction from 137 → target per requirement.

## Related artifacts

- Debug investigation: `.planning/debug/matlab-tests-failures-investigation.md` — authoritative source for per-test error messages and source-file locations
- CI run with the failing logs: https://github.com/HanSur94/FastSense/actions/runs/24510852026
- PR #44 (draft, test-only): https://github.com/HanSur94/FastSense/pull/44
- Prerequisite quick tasks: 260416-j6e (MATLAB on push/PR), 260416-jfo (CI quick wins), 260416-jnp (DRY reusable workflow), 260416-k23 (Octave 11.1.0)
- Prerequisite phase: 1004 (Image Export — the feature whose tests appear in category F)

## Next step

`/gsd:discuss-phase 1006` to resolve MATLABFIX-G before planning A-F. Then `/gsd:plan-phase 1006`.
