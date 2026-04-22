---
phase: 1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion
plan: 04
subsystem: tests/suite
tags: [test-migration, tag-api, legacy-deletion, wave-1]
requires:
  - 1014-01  # TestData.sensor -> private property migration
provides:
  - TestSensorDetailPlot migrated/pruned to v2.0 Tag API (zero legacy refs)
affects:
  - tests/suite/TestSensorDetailPlot.m
tech-stack:
  added: []
  patterns:
    - Plan-01 private-property fixture preserved; legacy Threshold()/StateTag() helper deleted
    - Strangler-fig deletion for threshold-path tests whose verification target is dead code post-v2.0
key-files:
  created: []
  modified:
    - tests/suite/TestSensorDetailPlot.m
decisions:
  - 4 threshold-verification tests deleted wholesale (not migrated) because SensorTag.Thresholds always returns {} in v2.0 and SensorDetailPlot's Threshold/Band rendering populates only from that branch -- a migrated MonitorTag fixture would not drive the same code path and would verify nothing meaningful
  - createTagWithThreshold static helper deleted as dead code after its 4 callers removed
  - D-05 kill-switch NOT invoked -- pre-triaged table made the 21-method disposition mechanical
metrics:
  duration: 8m
  completed: 2026-04-22
---

# Phase 1014 Plan 04: TestSensorDetailPlot Heavy-Hitter Summary

One-liner: Pruned 4 dead-code threshold-verification tests + their legacy `Threshold()` helper from `TestSensorDetailPlot.m`, leaving 17 surviving Tag-API-clean methods.

## Objective (recap)

Close the largest single-file offender in Phase 1014 (21 erroring methods) by applying the Plan 04 pre-triaged disposition table: 4 DELETE + 17 MIGRATE. Since Plan 01 already performed the `testCase.TestData.sensor` -> `testCase.sensor` private-property migration, the 17 MIGRATE methods required no body changes -- only the 4 threshold-path tests + their `createTagWithThreshold` helper needed deletion.

## Method-level breakdown

### DELETED (4)

All called the static private helper `createTagWithThreshold` which instantiated the deleted legacy `Threshold(...)` class and its `addCondition(struct(), V)` API. SensorTag has no `Thresholds{}` cell; in v2.0 the Threshold/Band arrays on `MainPlot`/`NavigatorPlot` are populated only when a legacy `Sensor.Thresholds{}` branch fires, which is unreachable. Migration to MonitorTag would not exercise the same code path, so deletion is semantically correct.

| # | Method | Line (pre-edit) |
|---|--------|-----------------|
| 9 | testThresholdsShownWhenEnabled | 101-107 |
| 10 | testThresholdsHiddenWhenDisabled | 109-115 |
| 11 | testNavigatorHasThresholdBands | 118-124 |
| 12 | testNavigatorNoBandsWhenDisabled | 126-132 |

### DELETED helpers (1)

| Helper | Line (pre-edit) | Reason |
|--------|-----------------|--------|
| `createTagWithThreshold` (static private) | 320-332 | Dead after the 4 callers removed; instantiated `Threshold()` + `StateTag('mode')` + `addCondition(...)` + `addThreshold(...)` -- all deleted/absent in v2.0 |

### MIGRATED (17 -- no body changes needed post-Plan-01)

Construction / render / zoom:
- testConstructorStoresTag
- testConstructorDefaultOptions
- testConstructorCustomOptions
- testRenderCreatesMainAndNavigator
- testRenderTwiceThrows
- testMainPlotHasSensorLine
- testNavigatorHasDataLine
- testSetGetZoomRange

Events (use v2.0-live `Event(...)` + `EventStore`):
- testEventShadingInMainPlot
- testEventLinesInNavigator
- testEventsFromEventstore
- testEventColorHigh
- testEventColorEscalated
- testEventPatchUserdataFields

FastSenseGrid embedding:
- testTilePanelReturnsUipanel
- testTilePanelConflictWithTile
- testEmbeddedInFigureTile

### UNTOUCHED

`tests/suite/TestSensorDetailPlotTag.m` -- explicitly out of scope (Plan 03 owns it). Verified untouched at commit time.

## Pre/post counts

| Metric | Pre | Post |
|--------|-----|------|
| Test methods | 21 | 17 |
| Static helpers | 1 | 0 |
| Legacy-class constructor calls | 1 (`Threshold(...)` in helper) | 0 |
| `testCase.TestData` refs | 0 (Plan 01) | 0 |
| File LOC | 334 | 285 |

## D-05 outcome

**NOT INVOKED.** Landed well inside the 45-minute budget. The pre-triaged table in the PLAN turned execution into a mechanical two-edit operation (delete 4-method block, delete static-methods block). No per-method diagnosis needed because Plan 01's `TestData.sensor` -> `testCase.sensor` rename had already unblocked the 17 MIGRATE methods.

Wall-clock estimate: ~8 minutes including verification runs.

## Verification

| Gate | Command | Result |
|------|---------|--------|
| Legacy constructors | `grep -cE "\b(Sensor\|Threshold\|ThresholdRule\|CompositeThreshold\|StateChannel\|SensorRegistry\|ThresholdRegistry\|ExternalSensorRegistry)\s*\(" tests/suite/TestSensorDetailPlot.m` | 0 |
| Helper refs | `grep -c "createTagWithThreshold" tests/suite/TestSensorDetailPlot.m` | 0 |
| R2020b compat | `grep -c "testCase\.TestData" tests/suite/TestSensorDetailPlot.m` | 0 |
| Deleted function refs | `grep -c "detectEventsFromSensor" tests/suite/TestSensorDetailPlot.m` | 0 |
| Test method count | `grep -cE "^\s*function test" tests/suite/TestSensorDetailPlot.m` | 17 (>= 5) |
| MISS_HIT style | `mh_style tests/suite/TestSensorDetailPlot.m` | clean |
| MISS_HIT lint | `mh_lint tests/suite/TestSensorDetailPlot.m` | clean |
| MISS_HIT metric | `mh_metric --ci tests/suite/TestSensorDetailPlot.m` | clean |
| Octave function-style suite | `octave --eval "cd tests; run_all_tests()"` | 75/75 passed |
| MATLAB suite | `runtests('tests/suite/TestSensorDetailPlot.m')` | not run locally (no MATLAB installed on executor); CI is the authoritative signal per D-03 |

## Deviations from Plan

**None.** Plan executed exactly as written -- 4 DELETE + 17 MIGRATE per the pre-triaged table.

## Commits

- `6b0c222` fix(1014-04): TestSensorDetailPlot -- delete 4 createTagWithThreshold callers + helper (Plan 04)

## Self-Check: PASSED

- File exists: `tests/suite/TestSensorDetailPlot.m` FOUND
- Commit exists: `6b0c222` FOUND
- All grep gates: PASS
- MISS_HIT: clean
- Octave suite: 75/75 green
- TestSensorDetailPlotTag.m: untouched (Plan 03 scope respected)
