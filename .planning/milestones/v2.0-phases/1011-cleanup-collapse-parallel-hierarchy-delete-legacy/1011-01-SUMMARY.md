---
phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy
plan: 01
subsystem: domain-model
tags: [matlab, sensortag, refactor, deletion, cleanup]

# Dependency graph
requires:
  - phase: 1009-monitortag-eventtag-compositetag
    provides: Tag-based domain model (SensorTag, StateTag, MonitorTag, CompositeTag, TagRegistry)
provides:
  - SensorTag with inlined data storage (no Sensor_ delegate)
  - 8 legacy classes deleted from libs/SensorThreshold/
  - 3 standalone functions deleted
  - 13 private helpers deleted (entire private/ directory)
  - install.m updated to reference Tag API only
affects: [1011-02, 1011-03, 1011-04, 1011-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SensorTag stores X_/Y_/DataStore_ directly instead of composing Sensor"
    - "Error IDs changed from Sensor:* to SensorTag:* for load/toDisk/toMemory"

key-files:
  created: []
  modified:
    - libs/SensorThreshold/SensorTag.m
    - install.m

key-decisions:
  - "Inlined all 7 Sensor data properties directly onto SensorTag (Option A from CONTEXT.md)"
  - "Simplified toDisk() by omitting threshold pre-compute steps (threshold machinery deleted)"
  - "Changed error IDs from Sensor:* to SensorTag:* for consistency with owning class"
  - "Rewrote jit_warmup to use SensorTag/StateTag/MonitorTag/addTag"

patterns-established:
  - "SensorTag is now a self-contained data carrier with no legacy dependencies"

requirements-completed: [MIGRATE-03]

# Metrics
duration: 3min
completed: 2026-04-17
---

# Phase 1011 Plan 01: Inline SensorTag Delegate + Delete Legacy Classes Summary

**Inlined Sensor_ delegate into SensorTag (7 private properties), deleted 8 legacy classes + 3 functions + 13 private helpers, updated install.m to Tag-only API**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-17T09:08:01Z
- **Completed:** 2026-04-17T09:11:22Z
- **Tasks:** 2
- **Files modified:** 2 (edited), 20 (deleted)

## Accomplishments
- SensorTag now stores X_, Y_, DataStore_, ID_, Source_, MatFile_, KeyName_ directly -- no Sensor_ composition delegate
- All data-role methods (load, toDisk, toMemory, isOnDisk, getXY, valueAt, getTimeRange, updateData) reimplemented to use inlined properties
- Deleted 8 legacy classes: Sensor, Threshold, ThresholdRule, CompositeThreshold, StateChannel, SensorRegistry, ThresholdRegistry, ExternalSensorRegistry
- Deleted 3 standalone functions: loadModuleData, loadModuleMetadata, detectEventsFromSensor
- Deleted entire libs/SensorThreshold/private/ directory (10 .m helpers + MEX binaries)
- install.m: needs_build() no longer probes SensorThreshold/private MEX, verify_installation checks SensorTag, jit_warmup uses Tag API

## Task Commits

Each task was committed atomically:

1. **Task 1: Inline SensorTag data storage + update install.m** - `955833b` (feat)
2. **Task 2: Delete 8 legacy classes + 3 standalone functions + 13 private helpers** - `4188a7f` (chore)

## Files Created/Modified
- `libs/SensorThreshold/SensorTag.m` - Inlined data storage, removed Sensor_ delegate
- `install.m` - Updated needs_build, verify_installation, jit_warmup for Tag API

## Files Deleted
- `libs/SensorThreshold/Sensor.m` - Legacy sensor class
- `libs/SensorThreshold/Threshold.m` - Legacy threshold class
- `libs/SensorThreshold/ThresholdRule.m` - Legacy threshold rule
- `libs/SensorThreshold/CompositeThreshold.m` - Legacy composite threshold
- `libs/SensorThreshold/StateChannel.m` - Legacy state channel
- `libs/SensorThreshold/SensorRegistry.m` - Legacy sensor registry
- `libs/SensorThreshold/ThresholdRegistry.m` - Legacy threshold registry
- `libs/SensorThreshold/ExternalSensorRegistry.m` - Legacy external registry
- `libs/SensorThreshold/loadModuleData.m` - Legacy data loader
- `libs/SensorThreshold/loadModuleMetadata.m` - Legacy metadata loader
- `libs/EventDetection/detectEventsFromSensor.m` - Legacy event bridge function
- `libs/SensorThreshold/private/` - All 13 files (10 .m + MEX binaries)

## Decisions Made
- Inlined all 7 data properties directly onto SensorTag (Option A from CONTEXT.md) -- Sensor has no surviving behavior SensorTag needs beyond data storage
- Simplified toDisk() to skip threshold pre-compute steps (lines 284-288 of old Sensor.toDisk) since all threshold machinery is deleted
- Error IDs changed from Sensor:* to SensorTag:* (noMatFile, fileNotFound, fieldNotFound, noData) since Sensor class no longer exists
- jit_warmup rewritten to SensorTag/StateTag/MonitorTag/addTag -- minimal warmup that exercises Tag pipeline

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all data paths are fully wired.

## Next Phase Readiness
- SensorTag is fully self-contained with inlined data storage
- Legacy classes are deleted from disk; many tests will fail (test subjects are gone)
- Plan 02 (parallel) deletes the legacy test files
- Plans 03-05 clean remaining consumer references (FastSenseWidget, EventDetector, etc.)

---
*Phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy*
*Completed: 2026-04-17*

## Self-Check: PASSED
- All created/modified files exist on disk
- All deleted files confirmed absent
- All commit hashes found in git log
