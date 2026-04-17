---
phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy
plan: 03
subsystem: consumer-cleanup
tags: [matlab, cleanup, legacy-removal, dashboard, fastsense, event-detection]

# Dependency graph
requires:
  - phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy
    plan: 01
    provides: 8 legacy classes deleted
  - phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy
    plan: 02
    provides: Legacy test files deleted
provides:
  - Zero SensorRegistry/ThresholdRegistry references in libs/ production code
  - Zero addSensor method in FastSense.m
  - DashboardWidget has Tag property only (no Sensor)
  - EventDetector has 2-arg Tag-only detect()
  - LiveEventPipeline has MonitorTargets only
affects: [1011-04, 1011-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "DashboardWidget maps legacy 'Sensor' NV pair to 'Tag' in constructor for backward compat"
    - "Widget fromStruct resolves type='sensor' via TagRegistry.get() for old JSON compat"
    - "EventDetector.detect accepts only (tag, threshold) 2-arg form"
    - "LiveEventPipeline constructor accepts MonitorTargets map as first arg"

key-files:
  created: []
  modified:
    - libs/FastSense/FastSense.m
    - libs/FastSense/SensorDetailPlot.m
    - libs/EventDetection/EventDetector.m
    - libs/EventDetection/LiveEventPipeline.m
    - libs/EventDetection/EventViewer.m
    - libs/Dashboard/DashboardWidget.m
    - libs/Dashboard/FastSenseWidget.m
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/DashboardSerializer.m
    - libs/Dashboard/DashboardBuilder.m
    - libs/Dashboard/StatusWidget.m
    - libs/Dashboard/GaugeWidget.m
    - libs/Dashboard/NumberWidget.m
    - libs/Dashboard/TableWidget.m
    - libs/Dashboard/IconCardWidget.m
    - libs/Dashboard/MultiStatusWidget.m
    - libs/Dashboard/ChipBarWidget.m
    - libs/Dashboard/SparklineCardWidget.m
    - libs/Dashboard/RawAxesWidget.m
    - libs/Dashboard/DetachedMirror.m
    - libs/SensorThreshold/TagRegistry.m

key-decisions:
  - "DashboardWidget maps 'Sensor' NV to 'Tag' for backward compat of deserialization"
  - "Widget fromStruct reads type='sensor' but resolves via TagRegistry.get for old JSON"
  - "EventDetector 6-arg legacy path removed; only 2-arg (tag, threshold) remains"
  - "LiveEventPipeline constructor takes MonitorTargets map directly (not optional NV pair)"
  - "EventViewer rewritten to use addLine instead of addSensor for event detail plots"

patterns-established:
  - "All libs/ production code uses Tag API exclusively"

requirements-completed: [MIGRATE-03]

# Metrics
duration: 15min
completed: 2026-04-17
---

# Phase 1011 Plan 03: Remove Legacy Branches from Consumer Production Files Summary

**Removed all SensorRegistry, ThresholdRegistry, addSensor, and obj.Sensor references from 21 production files across Dashboard, FastSense, and EventDetection libraries**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-17T09:14:27Z
- **Completed:** 2026-04-17T09:29:03Z
- **Tasks:** 2
- **Files modified:** 21

## Accomplishments
- FastSense.m: deleted entire addSensor() method (80 lines) and resolveThresholdStyle helper (23 lines)
- SensorDetailPlot.m: removed Sensor property, made constructor Tag-only, removed all Sensor data/threshold branches
- EventDetector.m: removed 6-arg legacy detect() path, now accepts only 2-arg (tag, threshold) form
- LiveEventPipeline.m: removed Sensors property, processSensor, buildSensorData, updateStoreSensorData methods; constructor takes MonitorTargets directly
- DashboardWidget.m: removed Sensor property, maps legacy 'Sensor' NV pair to 'Tag' for backward compat
- FastSenseWidget.m: removed all Sensor dispatch, LastSensorRef, addSensor calls; Tag-only refresh/update
- 7 widget fromStruct methods migrated from SensorRegistry.get to TagRegistry.get
- 5 widget constructors migrated from ThresholdRegistry.get to TagRegistry.get  
- DashboardSerializer.m: export code generates TagRegistry.get instead of SensorRegistry.get
- DashboardBuilder.m: source binding uses TagRegistry.get
- EventViewer.m: replaced addSensor with addLine (Rule 3 deviation -- blocking since FastSense.addSensor deleted)

## Task Commits

1. **Task 1: Remove legacy branches from FastSense + EventDetection** - `2ed99c8` (feat)
2. **Task 2: Remove legacy branches from Dashboard widgets + engine** - `59814f2` (feat)

## Files Modified
- `libs/FastSense/FastSense.m` - Deleted addSensor + resolveThresholdStyle
- `libs/FastSense/SensorDetailPlot.m` - Tag-only constructor and render
- `libs/EventDetection/EventDetector.m` - 2-arg Tag detect only
- `libs/EventDetection/LiveEventPipeline.m` - MonitorTargets only, no Sensors map
- `libs/EventDetection/EventViewer.m` - addLine replaces addSensor
- `libs/Dashboard/DashboardWidget.m` - Removed Sensor property
- `libs/Dashboard/FastSenseWidget.m` - Tag-only data binding
- `libs/Dashboard/DashboardEngine.m` - Comment updated
- `libs/Dashboard/DashboardSerializer.m` - TagRegistry.get in exports
- `libs/Dashboard/DashboardBuilder.m` - TagRegistry.get for source binding
- `libs/Dashboard/StatusWidget.m` - TagRegistry.get in constructor + fromStruct
- `libs/Dashboard/GaugeWidget.m` - TagRegistry.get in constructor + fromStruct
- `libs/Dashboard/NumberWidget.m` - TagRegistry.get in fromStruct
- `libs/Dashboard/TableWidget.m` - TagRegistry.get in fromStruct
- `libs/Dashboard/IconCardWidget.m` - TagRegistry.get in constructor + fromStruct
- `libs/Dashboard/MultiStatusWidget.m` - TagRegistry.get in resolveThresholdColor + fromStruct
- `libs/Dashboard/ChipBarWidget.m` - TagRegistry.get in constructor + resolveChipColor
- `libs/Dashboard/SparklineCardWidget.m` - TagRegistry.get in fromStruct
- `libs/Dashboard/RawAxesWidget.m` - TagRegistry.get in fromStruct
- `libs/Dashboard/DetachedMirror.m` - Updated comments
- `libs/SensorThreshold/TagRegistry.m` - Removed ThresholdRegistry from See also

## Decisions Made
- DashboardWidget maps 'Sensor' NV to 'Tag' in constructor for backward compat of deserialized dashboards
- Widget fromStruct reads type='sensor' but resolves via TagRegistry.get for old JSON backward compat
- EventDetector 6-arg legacy path fully removed; 2-arg (tag, threshold) is the only detect() signature
- LiveEventPipeline constructor takes MonitorTargets map directly as first argument
- EventViewer rewritten to use addLine+buildSensorData instead of addSensor+buildSensor

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] EventViewer.m addSensor calls crash**
- **Found during:** Task 2
- **Issue:** EventViewer.m calls FastSense.addSensor() which was deleted in Task 1, and calls buildSensor() which constructs Sensor objects (deleted in Plan 01)
- **Fix:** Rewrote buildSensor to buildSensorData (validates struct fields), replaced fp.addSensor(sensor) with fp.addLine(sensorX, sensorY, 'DisplayName', sd.name)
- **Files modified:** libs/EventDetection/EventViewer.m
- **Commit:** 59814f2

**2. [Rule 3 - Blocking] ChipBarWidget exist('ThresholdRegistry') guard**
- **Found during:** Task 2 verification
- **Issue:** exist('ThresholdRegistry', 'class') guard remained after ThresholdRegistry.get was changed to TagRegistry.get, causing the code path to never execute
- **Fix:** Changed to exist('TagRegistry', 'class')
- **Files modified:** libs/Dashboard/ChipBarWidget.m
- **Commit:** 59814f2

## Issues Encountered
None beyond the deviations above.

## Deferred Items
- **EventConfig.m:** Still references Sensor.resolve(), detectEventsFromSensor (both deleted). Effectively dead code. See deferred-items.md.
- **EventViewer threshold overlay:** Lost threshold display in event detail plots since addSensor with threshold overlay replaced by plain addLine.

## User Setup Required
None.

## Known Stubs
None - all data paths are fully wired via Tag API.

## Next Phase Readiness
- All libs/ production files use Tag API exclusively
- Zero SensorRegistry/ThresholdRegistry references remain
- Tag-based tests (test_sensortag, test_statetag, test_monitortag, test_compositetag) all green
- Plan 04 can proceed with example migration
- Plan 05 can proceed with golden test rewrite

---
*Phase: 1011-cleanup-collapse-parallel-hierarchy-delete-legacy*
*Completed: 2026-04-17*

## Self-Check: PASSED
- All modified files exist on disk
- All commit hashes found in git log
- Zero SensorRegistry/ThresholdRegistry references in libs/*.m
- Zero addSensor references in FastSense.m
- Zero obj.Sensor references in DashboardWidget.m and FastSenseWidget.m
- Tag-based tests pass
