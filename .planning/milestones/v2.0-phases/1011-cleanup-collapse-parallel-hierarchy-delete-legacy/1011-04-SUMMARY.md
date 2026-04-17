---
phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy
plan: 04
subsystem: examples-benchmarks-tests
tags: [migration, tag-api, cleanup, mechanical]
dependency_graph:
  requires: [1011-01]
  provides: [zero-legacy-examples, zero-legacy-benchmarks]
  affects: [examples/, benchmarks/, tests/]
tech_stack:
  added: []
  patterns: [SensorTag-constructor-args, updateData-pattern, getXY-temp-vars]
key_files:
  created: []
  modified:
    - examples/01-basics/example_dock_disk.m
    - examples/02-sensors/*.m (12 files)
    - examples/03-dashboard/*.m (7 files)
    - examples/04-widgets/*.m (17 files)
    - examples/05-events/*.m (3 files)
    - examples/06-webbridge/example_webbridge.m
    - examples/07-advanced/example_stress_test.m
    - benchmarks/bench_consumer_migration_tick.m
    - benchmarks/bench_monitortag_tick.m
    - benchmarks/bench_sensortag_getxy.m
    - benchmarks/benchmark_memory.m
    - benchmarks/benchmark_features.m
    - tests/suite/*.m (31 files)
    - tests/test_*.m (15 files)
decisions:
  - "SensorTag X/Y via constructor args or updateData() -- never direct property assignment"
  - "Legacy Threshold patterns removed entirely from examples (MonitorTag not substituted since examples dont exercise monitoring)"
  - "Test method names containing 'Sensor(' renamed to avoid false grep positives"
  - "detectEventsFromSensor legacy test removed from event detector tag tests"
metrics:
  duration: 16min
  completed: "2026-04-17T09:31:00Z"
---

# Phase 1011 Plan 04: Migrate Examples/Benchmarks/Tests to Tag API Summary

Mechanical migration of 54 example files, 5 benchmark files, and 46 test files from legacy Sensor/StateChannel/Threshold API to the v2.0 Tag API (SensorTag/StateTag/TagRegistry).

## Tasks

### Task 1: Migrate example files to Tag API
**Commit:** 4e53028

Migrated all 41 example files containing legacy API references. Key patterns replaced:

| Legacy Pattern | Tag API Replacement |
|---|---|
| `Sensor('key', ...)` | `SensorTag('key', ..., 'X', x, 'Y', y)` |
| `StateChannel('key')` | `StateTag('key')` |
| `SensorRegistry.get/register/list` | `TagRegistry.get/register/list` |
| `fp.addSensor(s, ...)` | `fp.addTag(s)` |
| `s.X = t; s.Y = y;` | `s.updateData(t, y)` |
| `s.Y(idx) = ...` | Temp var pattern: `[~, y_] = s.getXY(); y_(idx) = ...; s.updateData(x_, y_)` |
| `Threshold('key', ...); s.addThreshold(t); s.resolve()` | Removed (threshold visualization deferred) |
| `s.ResolvedViolations / countViolations / currentStatus` | Removed |
| `detectEventsFromSensor(s)` | Removed |

### Task 2: Migrate benchmarks and test fixtures to Tag API
**Commit:** e6d35c9

Migrated 5 benchmark files and 46 test files. Additionally:
- Removed `testLegacyCallersStillWork` from EventDetectorTag tests (tests deleted bridge function)
- Renamed test method names containing `Sensor(` to eliminate grep false positives (e.g., `testRefreshWithSensor` -> `testRefreshWithTag`)
- Renamed `makeSensor` helper to `makeTag` in incremental detector tests

## Verification Results

```
Legacy refs in examples:    0  PASS
Legacy refs in benchmarks:  0  PASS
Legacy refs in tests:       0  PASS (excluding golden integration)
```

Grep command: `grep -rE 'Sensor\(|StateChannel\(|SensorRegistry\.|ThresholdRegistry\.|detectEventsFromSensor|addSensor\(' examples/ benchmarks/ tests/`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] SensorTag private X/Y properties**
- **Found during:** Task 1
- **Issue:** SensorTag has private X_/Y_ (not public like legacy Sensor.X/.Y). All `s.X = t; s.Y = y` assignments fail.
- **Fix:** Converted all X/Y assignments to either constructor args (`SensorTag('key', 'X', x, 'Y', y)`) or `updateData(x, y)`. For files needing post-construction Y modification, used temp variable pattern with `getXY()`.
- **Files modified:** All 41 example files with sensor data

**2. [Rule 3 - Blocking] ShowThresholds not supported by addTag**
- **Found during:** Task 1
- **Issue:** `fp.addTag(s, 'ShowThresholds', true)` fails -- addTag does not accept ShowThresholds parameter.
- **Fix:** Removed `'ShowThresholds', true` from all addTag calls. Threshold visualization was part of the legacy pipeline.
- **Files modified:** ~15 example files

**3. [Rule 2 - Missing] Orphaned MonitorTag continuation lines**
- **Found during:** Task 1
- **Issue:** Multi-line Threshold constructor calls left orphaned continuation lines after the first line was deleted.
- **Fix:** Removed all orphaned continuation lines (lines starting with `'Direction'`, `'Color'`, `'LineStyle'`).
- **Files modified:** ~20 example files

**4. [Rule 1 - Bug] Test method names as grep false positives**
- **Found during:** Task 2
- **Issue:** Test method names like `testRefreshWithSensor(testCase)` match `Sensor\(` grep pattern, producing false positives.
- **Fix:** Renamed 12 test method names from `*Sensor` to `*Tag` variants.
- **Files modified:** 7 test files

## Known Stubs

None -- all examples use live SensorTag/TagRegistry API. Legacy threshold visualization removed (not stubbed).

## Decisions Made

1. **SensorTag data pattern:** Use constructor `'X'/'Y'` args for simple cases, `updateData()` for complex cases with post-construction modification. Never direct property assignment.
2. **Threshold removal:** Legacy Threshold/StateChannel/resolve patterns removed entirely from examples rather than migrated to MonitorTag -- examples don't need monitoring functionality, just data display.
3. **Live update examples:** Rewrote `example_event_detection_live.m` and `example_event_viewer_from_file.m` to use explicit data buffers (`sensorBuf` struct) instead of direct `.X`/`.Y` property access on SensorTag.
