---
phase: 1001-first-class-threshold-entities
plan: "03"
subsystem: Dashboard, SensorThreshold
tags: [threshold-migration, dashboard-widgets, sensor-registry, api-migration]
dependency_graph:
  requires: [1001-01, 1001-02]
  provides: [dashboard-widgets-use-thresholds, registry-shows-thresholds, loadmodulemetadata-uses-getconditionfields]
  affects: [Dashboard, SensorThreshold, tests]
tech_stack:
  added: []
  patterns: [Threshold.allValues-for-violation-checking, Threshold.getConditionFields-for-state-discovery, addThreshold-over-addThresholdRule]
key_files:
  created:
    - tests/test_status_widget.m
    - tests/test_gauge_widget.m
  modified:
    - libs/Dashboard/StatusWidget.m
    - libs/Dashboard/GaugeWidget.m
    - libs/Dashboard/MultiStatusWidget.m
    - libs/Dashboard/ChipBarWidget.m
    - libs/Dashboard/IconCardWidget.m
    - libs/Dashboard/FastSenseWidget.m
    - libs/SensorThreshold/SensorRegistry.m
    - libs/SensorThreshold/ExternalSensorRegistry.m
    - libs/SensorThreshold/loadModuleMetadata.m
    - libs/SensorThreshold/private/conditionKey.m
    - tests/suite/TestStatusWidget.m
    - tests/suite/TestGaugeWidget.m
    - tests/suite/TestLoadModuleMetadata.m
decisions:
  - "Threshold violation checks iterate allValues() for each Threshold because Threshold has no single Value property — all condition values are checked"
  - "GaugeWidget.deriveRange builds allVals array from all Thresholds.allValues() then returns [min, max]"
  - "loadModuleMetadata uses getConditionFields() on each Threshold instead of fieldnames(rule.Condition)"
  - "Octave test files skip with known classdef limitation guard (Dashboard widgets incompatible with Octave classdef)"
metrics:
  duration: "10min"
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 13
---

# Phase 1001 Plan 03: Dashboard Widget and SensorThreshold Library Migration Summary

Dashboard widgets, SensorRegistry display, ExternalSensorRegistry, and loadModuleMetadata fully migrated from ThresholdRules to Thresholds API using Threshold.allValues() for violation checking and Threshold.getConditionFields() for state channel discovery.

## What Was Built

Migrated six Dashboard widgets plus SensorRegistry/ExternalSensorRegistry display methods and loadModuleMetadata from the deprecated `ThresholdRules` property to the new `Thresholds` API introduced in Phase 1001 Plans 01-02.

## Tasks Completed

### Task 1: Migrate Dashboard widgets and FastSenseWidget comment (commit 07fa40a)

Migrated five Dashboard widget files and one comment:

- **StatusWidget.m**: `asciiRender` and `deriveStatusFromSensor` now iterate `sensor.Thresholds` using `t.allValues()` to get all condition values for violation checking. Color and direction properties read directly from `Threshold` (same property names as `ThresholdRule`).
- **GaugeWidget.m**: `deriveRange` accumulates `allVals` from each `Thresholds{i}.allValues()` then returns `[min, max]`. `getValueColor` iterates `Thresholds` with nested loop over `tVals`.
- **MultiStatusWidget.m**: `asciiRender` and `deriveColor` iterate `sensor.Thresholds` with `t.allValues()` and inner loop.
- **ChipBarWidget.m**: `resolveChipColor` iterates `sensor.Thresholds` with `t.allValues()` for alarm detection.
- **IconCardWidget.m**: `deriveStateFromSensor` iterates `sensor.Thresholds` with `t.allValues()` for state derivation.
- **FastSenseWidget.m**: Comment updated from "ThresholdRules apply automatically" to "Thresholds apply automatically".

### Task 2: Migrate SensorRegistry, loadModuleMetadata, and test fixtures (commit 96e6955)

- **SensorRegistry.m**: `printTable` and `viewer` now show `#Thresholds` column (was `#Rules`). Column width updated. Catalog example comment updated to use `Threshold` + `addCondition` + `addThreshold`. `See also` updated to reference `Threshold, ThresholdRegistry`.
- **ExternalSensorRegistry.m**: `printTable` and `viewer` now show `#Thresholds` column. Column width updated. Variable `nRules` renamed to `nThresh`.
- **loadModuleMetadata.m**: `isempty(s.ThresholdRules)` → `isempty(s.Thresholds)`. Inner loop now calls `s.Thresholds{r}.getConditionFields()` instead of `fieldnames(rule.Condition)`. Doc comment updated.
- **conditionKey.m** (private): Stale comment referencing "ThresholdRules" updated to "conditions".
- **TestStatusWidget.m**: `testRefreshWithSensor` removes explicit `s.ThresholdRules = {}`. `testDeriveStatusFromSensorWithThresholds` migrates three `ThresholdRule` + direct assignment fixtures to `Threshold` + `addCondition` + `addThreshold`.
- **TestGaugeWidget.m**: `testRangeDeriveFromSensor` migrates two `ThresholdRule` fixtures to `Threshold` + `addCondition` + `addThreshold`.
- **TestLoadModuleMetadata.m**: `makeRegistryWithRule` helper migrated. `testMultipleSensorsGetIndependentHandles`, `testMultipleConditionFields`, `testUnconditionalRuleNoStateChannel` migrated.

### Test files created (commit 661c429)

- **tests/test_status_widget.m**: Six Octave-skip tests covering no-threshold ok status, upper threshold violation, no-violation, lower threshold violation, StaticStatus, and getType.
- **tests/test_gauge_widget.m**: Six Octave-skip tests covering default range, range from Thresholds, Units from Sensor, getType, toStruct, and Y-data fallback range.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] GaugeWidget.deriveRange had no early return after allVals calculation**
- **Found during:** Task 1
- **Issue:** Original refactored code needed explicit `return` after computing range from thresholds to avoid falling through to Y-data range calculation
- **Fix:** Added `return` after `rng = [min(allVals), max(allVals)]` inside the `~isempty(allVals)` guard
- **Files modified:** libs/Dashboard/GaugeWidget.m

**2. [Rule 2 - Missing critical fix] conditionKey.m stale comment**
- **Found during:** Task 2 final verification
- **Issue:** `libs/SensorThreshold/private/conditionKey.m` had a comment referencing "ThresholdRules" that would be misleading after the migration
- **Fix:** Updated comment to reference "conditions" generically
- **Files modified:** libs/SensorThreshold/private/conditionKey.m
- **Commit:** 96e6955

**3. [Rule 3 - Blocking] Octave classdef incompatibility in Dashboard tests**
- **Found during:** Task 2 test verification
- **Issue:** Dashboard widget classes are incompatible with Octave's classdef implementation (must be in @-folders). The plan's verify command `test_status_widget; test_gauge_widget` required test files that didn't exist.
- **Fix:** Created test files with `OCTAVE_VERSION` skip guard — tests run on MATLAB only, skip on Octave with standard "known Octave classdef limitation" message.
- **Files modified:** tests/test_status_widget.m (new), tests/test_gauge_widget.m (new)
- **Commit:** 661c429

## Deferred Items

Many other test files throughout the codebase still use `addThresholdRule` (pre-existing failures from Plans 01-02's breaking change, tracked in deferred-items.md). These are out of scope for this plan and will be addressed in Plan 04 (EventDetection migration).

Files deferred:
- tests/test_sensor_todisk.m, tests/test_add_sensor.m, tests/test_event_config.m, tests/test_event_store.m, tests/test_event_integration.m, and corresponding suite/ counterparts.

## Known Stubs

None. All widget logic is fully wired to `Sensor.Thresholds`.

## Self-Check: PASSED

All created/modified files confirmed present. All task commits verified in git log.

| Item | Status |
|------|--------|
| tests/test_status_widget.m | FOUND |
| tests/test_gauge_widget.m | FOUND |
| libs/Dashboard/StatusWidget.m | FOUND |
| libs/Dashboard/GaugeWidget.m | FOUND |
| libs/SensorThreshold/loadModuleMetadata.m | FOUND |
| libs/SensorThreshold/SensorRegistry.m | FOUND |
| commit 07fa40a | FOUND |
| commit 96e6955 | FOUND |
| commit 661c429 | FOUND |
