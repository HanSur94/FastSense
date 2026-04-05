---
phase: 1001-first-class-threshold-entities
plan: "02"
subsystem: SensorThreshold
tags: [sensor, threshold, refactor, api-migration, test-migration]
dependency_graph:
  requires: [1001-01]
  provides: [Sensor.addThreshold, Sensor.removeThreshold, Sensor.Thresholds, allRules-flattening]
  affects: [libs/SensorThreshold/Sensor.m, tests/suite/TestSensor.m, tests/suite/TestSensorResolve.m, tests/suite/TestResolveSegments.m, tests/test_sensor.m, tests/test_sensor_resolve.m, tests/test_resolve_segments.m]
tech_stack:
  added: []
  patterns: [Threshold-flattening via conditions_, ThresholdRegistry string-key lookup, duplicate-key warning guard]
key_files:
  created: []
  modified:
    - libs/SensorThreshold/Sensor.m
    - libs/SensorThreshold/private/buildThresholdEntry.m
    - tests/suite/TestSensor.m
    - tests/suite/TestSensorResolve.m
    - tests/suite/TestResolveSegments.m
    - tests/test_sensor.m
    - tests/test_sensor_resolve.m
    - tests/test_resolve_segments.m
decisions:
  - "allRules flattening: Sensor.resolve() builds allRules by iterating Thresholds then their conditions_ — same batch pipeline as before with zero MEX changes"
  - "addThreshold dual-input: accepts both Threshold handles and char/string keys via ThresholdRegistry.get()"
  - "Duplicate guard uses strcmp on Key: Sensor:duplicateThreshold warning fires and returns early without appending"
  - "buildThresholdEntry.m: no code change needed — rule argument is still ThresholdRule from Threshold.conditions_; only comment updated"
  - "TestDeclarativeCondition unchanged: tests ThresholdRule directly, contains no Sensor API usage"
metrics:
  duration: "6min"
  completed: "2026-04-05T18:12:24Z"
  tasks_completed: 2
  files_modified: 8
---

# Phase 1001 Plan 02: Sensor.m ThresholdRules-to-Thresholds Refactor Summary

**One-liner:** Sensor.m refactored to store Threshold handles in Thresholds property with addThreshold/removeThreshold API; resolve() flattens Thresholds->conditions_ into allRules for unchanged batch pipeline.

## What Was Built

### Task 1: Sensor.m Refactored

Replaced the `ThresholdRules` property and `addThresholdRule` method with a first-class `Thresholds` property and `addThreshold`/`removeThreshold` API.

**Key changes in `libs/SensorThreshold/Sensor.m`:**
- `ThresholdRules = {}` property removed; `Thresholds = {}` added (cell array of Threshold handles)
- `addThresholdRule(condition, value, varargin)` method removed entirely
- `addThreshold(thresholdOrKey)` added — accepts Threshold object or char string for ThresholdRegistry lookup; warns `Sensor:duplicateThreshold` on duplicate Key
- `removeThreshold(key)` added — detaches by Key string
- `resolve()` now opens with `allRules = {}` flattening loop: iterates `obj.Thresholds{i}.conditions_{j}` to build identical `allRules` cell array that feeds the existing batch pipeline unchanged
- `getThresholdsAt()` updated to flatten `Thresholds -> conditions_` for single-point query
- `currentStatus()` updated to guard on `isempty(obj.Thresholds)` instead of `ThresholdRules`
- `toDisk()` updated to check `~isempty(obj.Thresholds)` before pre-computing resolve

**`libs/SensorThreshold/private/buildThresholdEntry.m`:** Comment updated to note the `rule` argument is an internal ThresholdRule from `Threshold.conditions_`; no code change required.

### Task 2: 8 Sensor Test Files Migrated

All 8 in-scope test files migrated from `addThresholdRule` to `Threshold + addCondition + addThreshold` pattern:

| File | Changes |
|------|---------|
| `tests/suite/TestSensor.m` | Renamed `testAddThresholdRule` -> `testAddThreshold`; added `testAddThresholdDuplicate`, `testRemoveThreshold`, `testAddThresholdByKey` |
| `tests/suite/TestSensorResolve.m` | All 5 test fixtures migrated |
| `tests/suite/TestResolveSegments.m` | All 4 test fixtures migrated |
| `tests/test_sensor.m` | All fixtures migrated + 3 new test cases |
| `tests/test_sensor_resolve.m` | All fixtures migrated |
| `tests/test_resolve_segments.m` | All fixtures migrated |
| `tests/suite/TestDeclarativeCondition.m` | No change needed (tests ThresholdRule directly) |
| `tests/test_declarative_condition.m` | No change needed (tests ThresholdRule directly) |

All 24 assertions across the 4 Octave test files pass.

## Verification Results

```
All 8 sensor tests passed.
All 6 sensor_resolve tests passed.
All 4 resolve_segments tests passed.
All 6 declarative_condition tests passed.
All 13 threshold tests passed.
All 10 threshold_registry tests passed.
```

## Deviations from Plan

None — plan executed exactly as written.

**Note:** Other test files outside the 8 in-scope files (EventDetection, FastSense integration, Dashboard tests) still use the old `addThresholdRule` API. These are out-of-scope for this plan and documented in `deferred-items.md`. They will be migrated in plans 03/04 of this phase.

## Decisions Made

| Decision | Rationale |
|----------|-----------|
| allRules flattening in resolve() | Enables zero MEX/algorithm changes while supporting multi-condition Threshold objects |
| addThreshold dual-input (object or string) | Enables both direct handle attachment and registry-key convenience without separate methods |
| Duplicate guard by Key string comparison | Key is the canonical identity field for Threshold; prevents accidental double-attachment |
| buildThresholdEntry.m comment-only update | rule arg is still ThresholdRule from conditions_ — full backward compat, no code change |

## Known Stubs

None — all sensor resolve tests pass with real data; no placeholder stubs.

## Self-Check: PASSED

- libs/SensorThreshold/Sensor.m — FOUND
- libs/SensorThreshold/private/buildThresholdEntry.m — FOUND
- tests/suite/TestSensor.m — FOUND
- .planning/phases/1001-first-class-threshold-entities/1001-02-SUMMARY.md — FOUND
- Commit 28a27a7 (Task 1) — FOUND
- Commit ace694b (Task 2) — FOUND
