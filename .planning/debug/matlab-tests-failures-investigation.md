---
status: investigating
trigger: "Categorize 137 failing MATLAB tests from CI run 24510852026 (PR #44)"
created: 2026-04-16T00:00:00Z
updated: 2026-04-16T00:00:00Z
---

## Current Focus

hypothesis: Multiple independent root causes confirmed; categorization complete
test: Log analysis + source code reading complete
expecting: N/A - investigation done
next_action: Return PARTIAL CATEGORIZATION result

## Symptoms

expected: MATLAB test suite passes cleanly like the Octave suite
actual: 155 failure events across 24 test suites (137 unique tests per the prompt — some suites produce 2 events per test: setup + teardown)
errors: Mix of Verification failed and Error occurred. MATLAB R2025b (2025.2.999). 
reproduction: CI run 24510852026, job 71641840049
started: Exposed 2026-04-16 when continue-on-error removed; failures were pre-existing

## Eliminated

- hypothesis: Phase 1001 migration (addThresholdRule → addThreshold) broke MATLAB suites
  evidence: No reference to addThresholdRule or ThresholdRule anywhere in failing tests. All failures have completely different error signatures.
  timestamp: 2026-04-16

## Evidence

- timestamp: 2026-04-16
  checked: MATLAB version from CI log
  found: MATLAB 2025.2.999 (R2025b equivalent) via cache key
  implication: Newest possible MATLAB version; known to be stricter about several APIs

- timestamp: 2026-04-16
  checked: TestMksqliteEdgeCases, TestMksqliteTypes (26+24=50 failures)
  found: MATLAB:UndefinedFunction - mksqlite not on path. Both suites call install() + add_fastsense_private_path() in TestClassSetup. mksqlite.mexa64 should be at libs/FastSense/ on path.
  implication: mksqlite MEX binary is either not in the downloaded artifact OR the binary was compiled for a different MATLAB version and fails silently on load. The artifact download shows 2.3MB which may not include mksqlite.mexa64 if the cache key was stale.

- timestamp: 2026-04-16
  checked: TestNavigatorOverlay (20 failures), TestSensorDetailPlot (21 failures)
  found: MATLAB:noSuchMethodOrField - Unrecognized method/property 'TestData' for class. Both use testCase.TestData.xxx in TestMethodSetup/Teardown.
  implication: R2025b changed behavior of TestCase.TestData dynamic property. In earlier MATLAB, TestData was a free-form struct on TestCase. In R2025b it may require explicit property declaration or different access.

- timestamp: 2026-04-16
  checked: TestDataStoreWAL (2), TestMultiStatusWidget (4), TestDashboardPerformance (1), TestWebBridge (5) 
  found: MATLAB:class:MethodRestricted - Cannot access private method from test code. Methods: ensureOpen (FastSenseDataStore private), expandSensors_ (MultiStatusWidget private), onTimeSlidersChanged (DashboardEngine private), startTcp (WebBridge private).
  implication: MATLAB R2025b enforces private method access restrictions more strictly than Octave. Tests written to access private methods directly fail. Octave historically allowed this; MATLAB blocks it.

- timestamp: 2026-04-16
  checked: TestLoadModuleMetadata (10 failures)
  found: MATLAB:table:parseArgs:BadParamNamePossibleCharRowData - table('Date', datetime...) fails. makeMetadataTable() uses table(args{:}) where args begins with 'Date' (char), a datetime array as column. R2025b rejects char column names in table() constructor.
  implication: Breaking change in R2025b table() API: char column names are rejected when the value could be mistaken for row data. Must use table() with Name=Value syntax or cell2table.

- timestamp: 2026-04-16
  checked: TestDashboardEngine/testAddCollapsible* (3 failures)
  found: DashboardEngine:invalidOption - d = DashboardEngine('Name', 'Test') treats 'Name' as positional arg and 'Test' as an option name, which is not valid. Constructor signature is DashboardEngine(name, varargin).
  implication: Test written with wrong constructor call syntax. Should be DashboardEngine('Test') not DashboardEngine('Name', 'Test').

- timestamp: 2026-04-16
  checked: TestDashboardEngine/testTimerContinuesAfterError (1 failure)
  found: MATLAB:UndefinedFunction - isrunning(timer) not defined. isrunning() is not a standard MATLAB function for timers. Should be strcmp(t.Running, 'on').
  implication: Test uses non-existent MATLAB function. The property is timer.Running, not queried via isrunning().

- timestamp: 2026-04-16
  checked: TestDashboardToolbarImageExport (4 failures)
  found: DashboardEngine:imageWriteFailed - exportImage fails with "Running using -nodisplay... not supported." MATLAB runs with -nodisplay in CI (no xvfb-run like Octave job).
  implication: exportImage() uses print() or saveas() which requires a display. The MATLAB CI job doesn't use xvfb-run unlike the Octave job. Phase 1004 image export feature is incompatible with headless CI.

- timestamp: 2026-04-16
  checked: TestDashboardBugFixes/testKpiWidgetThemeOverrideMerge (1 failure)
  found: MATLAB:UndefinedFunction - KpiWidget not defined. KpiWidget class was removed/renamed; tests still reference it directly (not via addWidget('kpi')).
  implication: KpiWidget class was removed from codebase. Test needs to use NumberWidget directly.

- timestamp: 2026-04-16
  checked: TestDashboardBugFixes/testAddWidgetDefaultTitle (1 failure)
  found: Expected 'New KPI', got 'New Widget'. kpi type is deprecated and maps to number; DashboardBuilder generates default title from type name.
  implication: Test expected old default title for kpi type. After deprecation the title is now "New Widget" not "New KPI".

- timestamp: 2026-04-16
  checked: TestDashboardBugFixes/testExitEditModeAfterFigureClose (1 failure)
  found: MATLAB:class:InvalidHandle - exitEditMode accesses deleted figure object. This appears to be a genuine logic bug or timing issue in DashboardBuilder.exitEditMode.
  implication: May be MATLAB vs Octave behavior difference in when figure handle becomes invalid.

- timestamp: 2026-04-16
  checked: TestDashboardBugFixes/testSensorListenersMultiPage (1 failure)
  found: Verification failed - need to check specific assertion
  implication: TBD

- timestamp: 2026-04-16
  checked: TestDashboardSerializerRoundTrip/testRoundTripPreservesWidgetSpecificProperties (4 failures)
  found: Size mismatch - actual [5x1] vs expected [1x5] column vector, same for GaugeWidget Range [2x1] vs [1x2] and TableWidget ColumnNames cell {2x1} vs {1x2}.
  implication: JSON deserialization returns column vectors but tests expect row vectors. R2025b jsonencode/jsondecode behavior may have changed, or the test was always wrong.

- timestamp: 2026-04-16
  checked: TestToolbar (5 failures)
  found: (1) button count 12 vs expected 11 - toolbar gained a button; (2) Classes do not match: actual matlab.lang.OnOffSwitchState vs expected char 'on'/'off'.
  implication: (1) A new button was added without updating the test. (2) R2025b returns OnOffSwitchState enum not char for Visible/Enable properties - MATLAB version incompatibility.

- timestamp: 2026-04-16
  checked: TestDataSource/testCannotInstantiate (1 failure)
  found: verifyTrue(false) - cannot instantiate abstract class DataSource. In MATLAB R2025b, trying to instantiate an abstract class may not throw an MException that can be caught; behavior changed.
  implication: R2025b tightened abstract class instantiation behavior.

- timestamp: 2026-04-16
  checked: TestDatastoreEdgeCases/testInvertedRange (1 failure)
  found: MATLAB:badsize_mx - fread(fid, [1, count], 'double') where count is negative (inverted range). R2025b errors where earlier versions returned empty.
  implication: R2025b changed fread behavior for negative sizes.

- timestamp: 2026-04-16
  checked: TestNotificationRule/testConstructor, TestNotificationService/testRuleMatchingPriority (1+3 failures)
  found: Classes do not match - actual class: cell, expected class: char. r.Recipients{1} returns {'a@b.com'} (1x1 cell) not 'a@b.com' (char). Test passes {{'a@b.com'}} which double-wraps.
  implication: Test bug: extra cell wrapping. Actual: r.Recipients{1} = {'a@b.com'}; expected: 'a@b.com'. Test should pass {'a@b.com'} not {{'a@b.com'}}, or access r.Recipients{1}{1}.

- timestamp: 2026-04-16
  checked: TestEventTimelineWidget/testToStruct, testFromStruct (2 failures)
  found: Classes do not match - actual {1x1 cell} containing {'Sensor-A'}, expected {'Sensor-A'} char. SensorKeys property is stored as cell and serialized that way.
  implication: Test expects char, gets cell wrapping. Related to same cell-vs-char issue pattern.

- timestamp: 2026-04-16
  checked: TestNumberWidget/testComputeTrend (1 failure)
  found: verifyTrue(false) - flat data should produce flat or empty trend.
  implication: Trend computation returns non-flat result for flat data. Logic bug or numerical precision issue.

- timestamp: 2026-04-16
  checked: TestCompositeThreshold/testFromStructMissingChildKeyWarns (1 failure)
  found: Actual warning ID 'CompositeThreshold:unknownChildKey', expected 'CompositeThreshold:loadChildFailed'.
  implication: Warning ID was renamed in the implementation. Test expects old ID.

- timestamp: 2026-04-16
  checked: TestDashboardBuilder (4 failures): testAddWidgetFromPalette, testToolbarEditToggle, testDragSnapsToGrid, testResizeSnapsToGrid
  found: (1) type 'number' vs 'kpi': palette returns number type but test expects kpi. (2) Button text 'Edit' vs 'Done'. (3+4) Grid snap position math wrong.
  implication: Mixed causes: (1) kpi→number rename propagated to palette; (2) toolbar label changed; (3+4) grid math differs under MATLAB R2025b figure layout.

- timestamp: 2026-04-16
  checked: TestDashboardBuilderInteraction (5 failures): positions
  found: Grid position column values wrong (1 vs 3, 3 vs 5, 0.02 vs 0.12, etc.) - drag/resize snap math produces different results.
  implication: DashboardBuilder drag/resize uses normalized figure coordinates or pixel math that behaves differently under MATLAB R2025b headless mode.

- timestamp: 2026-04-16
  checked: TestDashboardDirtyFlag/testResizeMarksDirty (1 failure)
  found: Dirty flag not set after resize - likely same position/snap issue.
  implication: Related to drag/resize math failure.

## Resolution

root_cause: Multiple independent root causes (6 major categories)
fix: N/A - investigation only
verification: N/A
files_changed: []
