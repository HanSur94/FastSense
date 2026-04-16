---
phase: 1001-first-class-threshold-entities
plan: "05"
subsystem: tests
tags: [migration, threshold, gap-closure, test-files]
dependency_graph:
  requires: [1001-01, 1001-02, 1001-03, 1001-04]
  provides: [THR-06-closed]
  affects: [tests/test_add_sensor.m, tests/test_sensor_todisk.m, tests/test_SensorDetailPlot.m, tests/test_event_integration.m, tests/suite/TestAddSensor.m, tests/suite/TestSensorTodisk.m, tests/suite/TestSensorDetailPlot.m, tests/suite/TestExternalSensorRegistry.m, tests/suite/TestDashboardEngine.m, tests/suite/TestFastSenseWidget.m]
tech_stack:
  added: []
  patterns: [Threshold+addCondition+addThreshold three-line pattern]
key_files:
  created: []
  modified:
    - tests/test_add_sensor.m
    - tests/test_sensor_todisk.m
    - tests/test_SensorDetailPlot.m
    - tests/test_event_integration.m
    - tests/suite/TestAddSensor.m
    - tests/suite/TestSensorTodisk.m
    - tests/suite/TestSensorDetailPlot.m
    - tests/suite/TestExternalSensorRegistry.m
    - tests/suite/TestDashboardEngine.m
    - tests/suite/TestFastSenseWidget.m
decisions:
  - Threshold key derived from lowercased label with spaces replaced by underscores per plan conventions
  - No-label calls use 'upper_N' key format where N is the threshold value
metrics:
  duration: 10min
  completed: "2026-04-05"
  tasks_completed: 2
  files_modified: 10
---

# Phase 1001 Plan 05: Migrate 10 Test Files from addThresholdRule to Threshold API Summary

**One-liner:** Migrated all 10 core sensor and consumer widget test files from removed addThresholdRule API to the three-line Threshold+addCondition+addThreshold pattern, closing THR-06 gap.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | Migrate Octave function-based test files (4 files, 5 calls) | 18ddb49 | tests/test_add_sensor.m, tests/test_sensor_todisk.m, tests/test_SensorDetailPlot.m, tests/test_event_integration.m |
| 2 | Migrate MATLAB suite test files (6 files, 8 calls) | ce8d6e6 | tests/suite/TestAddSensor.m, tests/suite/TestSensorTodisk.m, tests/suite/TestSensorDetailPlot.m, tests/suite/TestExternalSensorRegistry.m, tests/suite/TestDashboardEngine.m, tests/suite/TestFastSenseWidget.m |

## Changes Made

### Task 1: Octave test files (4 files, 5 addThresholdRule calls replaced)

- **tests/test_add_sensor.m**: 2 calls — `HH` threshold and unlabeled `upper_5`
- **tests/test_sensor_todisk.m**: 1 call — `HH (running)` threshold on s2
- **tests/test_SensorDetailPlot.m**: 1 call — `H Warning` threshold in createSensorWithThreshold helper
- **tests/test_event_integration.m**: 1 call — `vibration warning` threshold

### Task 2: MATLAB suite files (6 files, 8 addThresholdRule calls replaced)

- **tests/suite/TestAddSensor.m**: 2 calls — mirrors test_add_sensor.m
- **tests/suite/TestSensorTodisk.m**: 2 calls — both in testResolveWithDiskData and testAddSensorWithDiskBacked
- **tests/suite/TestSensorDetailPlot.m**: 1 call — `H Warning` in createSensorWithThreshold helper
- **tests/suite/TestExternalSensorRegistry.m**: 1 call — `Warning` threshold in testLivePipelineCompatibility
- **tests/suite/TestDashboardEngine.m**: 1 call — `Hi` threshold in testAddWidgetWithSensor
- **tests/suite/TestFastSenseWidget.m**: 1 call — `Hi Alarm` threshold in testRenderWithThresholds

## Decisions Made

- Threshold key derived from lowercased label with spaces/special chars replaced by underscores (e.g., 'HH (running)' -> 'hh_running', 'H Warning' -> 'h_warning')
- No-label calls use 'upper_N' key format (e.g., `struct(), 5, 'Direction', 'upper'` -> key 'upper_5')
- Variable names use `t_keyname` convention (t_hh, t_upper, t_h_warning, etc.)

## Verification

Final check confirms zero addThresholdRule references in all 10 files:

```
tests/test_add_sensor.m:0
tests/test_sensor_todisk.m:0
tests/test_SensorDetailPlot.m:0
tests/test_event_integration.m:0
tests/suite/TestAddSensor.m:0
tests/suite/TestSensorTodisk.m:0
tests/suite/TestSensorDetailPlot.m:0
tests/suite/TestExternalSensorRegistry.m:0
tests/suite/TestDashboardEngine.m:0
tests/suite/TestFastSenseWidget.m:0
```

All 10 files confirmed to use addThreshold with counts >= 1.

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

Files created/modified exist and commits are present:
- SUMMARY.md: /Users/hannessuhr/FastPlot/.planning/phases/1001-first-class-threshold-entities/1001-05-SUMMARY.md
- Commit 18ddb49: Octave test files migration
- Commit ce8d6e6: MATLAB suite test files migration
