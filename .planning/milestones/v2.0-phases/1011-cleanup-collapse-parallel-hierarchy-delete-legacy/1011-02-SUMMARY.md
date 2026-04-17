---
phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy
plan: 02
subsystem: testing
tags: [cleanup, legacy-deletion, test-files, benchmarks]

requires:
  - phase: none
    provides: none
provides:
  - "37 legacy-only test and benchmark files removed (19 suite + 16 flat + 2 benchmarks)"
affects: [1011-03, 1011-04, 1011-05]

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified: []

key-decisions:
  - "TestAddThreshold + test_add_threshold KEPT -- tests FastSense.addThreshold (surviving API), not Sensor.addThreshold"
  - "TestGoldenIntegration + test_golden_integration PRESERVED for Plan 05 rewrite"
  - "run_all_tests.m unchanged -- uses auto-discovery (TestSuite.fromFolder / dir('test_*.m')), no explicit file lists"

patterns-established: []

requirements-completed: [MIGRATE-03]

duration: 1min
completed: 2026-04-17
---

# Phase 1011 Plan 02: Delete Legacy-Only Test + Benchmark Files Summary

**Deleted 37 legacy-only test files (19 suite + 16 flat) and 2 benchmark files that exclusively test the 8 deleted legacy classes**

## Performance

- **Duration:** 1 min
- **Started:** 2026-04-17T09:08:54Z
- **Completed:** 2026-04-17T09:09:52Z
- **Tasks:** 1
- **Files deleted:** 37

## Accomplishments
- Deleted 19 suite test files exclusively testing Sensor, Threshold, ThresholdRule, CompositeThreshold, StateChannel, SensorRegistry, ThresholdRegistry, ExternalSensorRegistry, and their helper functions
- Deleted 16 corresponding flat (Octave-style) test files
- Deleted 2 legacy benchmark files (benchmark_resolve.m, benchmark_resolve_stress.m) that benchmark Sensor.resolve()
- Verified TestAddThreshold tests FastSense.addThreshold (surviving API) -- correctly KEPT
- Preserved TestGoldenIntegration and test_golden_integration for Plan 05 rewrite
- Preserved all Tag-based test files (TestTag, TestTagRegistry, TestSensorTag, TestStateTag, TestMonitorTag, TestCompositeTag, etc.)

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete legacy-only test files (suite + flat pairs)** - `89cbd76` (chore)

## Files Deleted

### Suite test files (19)
- `tests/suite/TestSensor.m` - Tests Sensor class
- `tests/suite/TestThreshold.m` - Tests Threshold class
- `tests/suite/TestThresholdRule.m` - Tests ThresholdRule class
- `tests/suite/TestCompositeThreshold.m` - Tests CompositeThreshold class
- `tests/suite/TestStateChannel.m` - Tests StateChannel class
- `tests/suite/TestSensorRegistry.m` - Tests SensorRegistry class
- `tests/suite/TestThresholdRegistry.m` - Tests ThresholdRegistry class
- `tests/suite/TestExternalSensorRegistry.m` - Tests ExternalSensorRegistry class
- `tests/suite/TestSensorResolve.m` - Tests Sensor.resolve()
- `tests/suite/TestSensorTodisk.m` - Tests Sensor.toDisk()
- `tests/suite/TestAlignState.m` - Tests private alignStateToTime helper
- `tests/suite/TestDeclarativeCondition.m` - Tests ThresholdRule conditions
- `tests/suite/TestDetectEventsFromSensor.m` - Tests detectEventsFromSensor bridge function
- `tests/suite/TestResolveSegments.m` - Tests Sensor.resolve() segment logic
- `tests/suite/TestAddSensor.m` - Tests FastSense.addSensor()
- `tests/suite/TestLoadModuleData.m` - Tests loadModuleData.m
- `tests/suite/TestLoadModuleMetadata.m` - Tests loadModuleMetadata.m
- `tests/suite/TestGroupViolations.m` - Tests private groupViolations helper
- `tests/suite/TestEventIntegration.m` - Tests detectEventsFromSensor integration

### Flat test files (16)
- `tests/test_sensor.m`, `tests/test_threshold.m`, `tests/test_threshold_rule.m`
- `tests/test_composite_threshold.m`, `tests/test_state_channel.m`, `tests/test_sensor_registry.m`
- `tests/test_threshold_registry.m`, `tests/test_sensor_resolve.m`, `tests/test_sensor_todisk.m`
- `tests/test_align_state.m`, `tests/test_declarative_condition.m`, `tests/test_detect_events_from_sensor.m`
- `tests/test_resolve_segments.m`, `tests/test_add_sensor.m`, `tests/test_group_violations.m`
- `tests/test_event_integration.m`

### Benchmark files (2)
- `benchmarks/benchmark_resolve.m` - Benchmarks Sensor.resolve()
- `benchmarks/benchmark_resolve_stress.m` - Benchmarks Sensor.resolve() stress test

### Flat files confirmed non-existent (skipped gracefully)
- `tests/test_external_sensor_registry.m` - No flat counterpart existed
- `tests/test_load_module_data.m` - No flat counterpart existed
- `tests/test_load_module_metadata.m` - No flat counterpart existed

## Decisions Made
- TestAddThreshold.m and test_add_threshold.m KEPT after inspection: both exclusively test `FastSense.addThreshold()` (surviving API) with zero `Sensor.` references
- run_all_tests.m requires no update: uses auto-discovery via `TestSuite.fromFolder` (MATLAB) and `dir('test_*.m')` (Octave)

## Deviations from Plan

None - plan executed exactly as written. The plan listed TestAddThreshold as a "CHECK FIRST" candidate; inspection confirmed it tests surviving code, so it was correctly kept per plan instructions.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None

## Next Phase Readiness
- Legacy test files cleared; test runner will no longer attempt to load deleted classes
- Plan 03 (delete legacy classes), Plan 04 (remove legacy branches), and Plan 05 (rewrite golden integration test) can proceed
- TestGoldenIntegration.m preserved and ready for Plan 05 rewrite

---
*Phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy*
*Completed: 2026-04-17*
