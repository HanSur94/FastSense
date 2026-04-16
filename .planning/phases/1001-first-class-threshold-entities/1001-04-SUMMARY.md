---
phase: 1001-first-class-threshold-entities
plan: "04"
subsystem: event-detection
tags: [matlab, threshold, event-detection, migration, sensor]

# Dependency graph
requires:
  - phase: 1001-01
    provides: Threshold class with addCondition/allValues API
  - phase: 1001-02
    provides: Sensor.addThreshold/removeThreshold/Thresholds property

provides:
  - IncrementalEventDetector migrated to Thresholds/addThreshold API
  - LiveEventPipeline migrated to Thresholds/addThreshold API
  - EventViewer migrated to sd.thresholds (Threshold handles) instead of sd.thresholdRules structs
  - All EventDetection test fixtures migrated to Threshold+addCondition+addThreshold pattern

affects: [EventDetection consumers, event pipeline scripts]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "EventDetection consumers read sensor.Thresholds{i} instead of sensor.ThresholdRules{i}"
    - "sd struct field is now 'thresholds' (cell of Threshold handles) instead of 'thresholdRules' (plain structs)"
    - "EventViewer.buildSensor uses sensor.addThreshold(t) for each Threshold handle in sd.thresholds"

key-files:
  created: []
  modified:
    - libs/EventDetection/IncrementalEventDetector.m
    - libs/EventDetection/LiveEventPipeline.m
    - libs/EventDetection/EventViewer.m
    - tests/suite/TestIncrementalDetector.m
    - tests/suite/TestLivePipeline.m
    - tests/suite/TestDetectEventsFromSensor.m
    - tests/test_incremental_detector.m
    - tests/test_live_pipeline.m
    - tests/test_detect_events_from_sensor.m

key-decisions:
  - "EventViewer stores live Threshold handle references in sd.thresholds instead of rebuilding plain structs, enabling direct addThreshold(t) in buildSensor"
  - "IncrementalEventDetector.escalate iterates sensor.Thresholds{j}.allValues() to support multi-condition thresholds"
  - "ThresholdRule tests unchanged — ThresholdRule remains as internal implementation class"

patterns-established:
  - "Threshold migration pattern: sensor.addThresholdRule(struct(),val,'Direction',d,'Label',l) -> t=Threshold(k,'Name',l,'Direction',d); t.addCondition(struct(),val); sensor.addThreshold(t)"

requirements-completed: [THR-05, THR-06]

# Metrics
duration: 4min
completed: 2026-04-05
---

# Phase 1001 Plan 04: EventDetection Migration to Threshold API Summary

**IncrementalEventDetector, LiveEventPipeline, and EventViewer fully migrated from ThresholdRules/addThresholdRule to Thresholds/addThreshold, with zero ThresholdRules references remaining in EventDetection production code**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-04-05T18:55:53Z
- **Completed:** 2026-04-05T18:59:24Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- IncrementalEventDetector.process() copies Threshold handles via addThreshold instead of rebuilding via addThresholdRule
- IncrementalEventDetector.escalate() iterates sensor.Thresholds and uses t.allValues() for multi-condition support
- LiveEventPipeline.buildSensorData() and updateStoreSensorData() read sensor.Thresholds with allValues() for threshold values
- EventViewer stores Threshold handles in sd.thresholds; buildSensor() reconstructs via addThreshold(t); extractThresholdColors() reads t.Name/t.Color
- All 9 test files migrated to Threshold+addCondition+addThreshold fixture pattern
- All Octave tests pass; ThresholdRule internal class preserved and its tests unmodified

## Task Commits

1. **Task 1: Migrate IncrementalEventDetector and LiveEventPipeline** - `3f2f29e` (feat)
2. **Task 2: Migrate EventViewer and test fixtures** - `641e593` (feat)

## Files Created/Modified

- `libs/EventDetection/IncrementalEventDetector.m` - Thresholds loop in process() and escalate()
- `libs/EventDetection/LiveEventPipeline.m` - Thresholds in buildSensorData()/updateStoreSensorData()
- `libs/EventDetection/EventViewer.m` - sd.thresholds field; buildSensor/openEventPlot/extractThresholdColors updated
- `tests/suite/TestIncrementalDetector.m` - makeSensor and testSeverityEscalation migrated
- `tests/suite/TestLivePipeline.m` - makePipeline and testSensorFailureSkipped migrated
- `tests/suite/TestDetectEventsFromSensor.m` - all three tests migrated
- `tests/test_incremental_detector.m` - makeSensor and test_severity_escalation migrated
- `tests/test_live_pipeline.m` - makePipeline and test_sensor_failure_skipped migrated
- `tests/test_detect_events_from_sensor.m` - all threshold setup migrated

## Decisions Made

- EventViewer stores live Threshold handle references (not plain structs) in sd.thresholds so buildSensor can call addThreshold(t) directly without reconstruction
- IncrementalEventDetector.escalate iterates t.allValues() for each Threshold to support multi-condition thresholds, where a single Threshold may have different values per machine state
- ThresholdRule tests left unchanged — the internal class is preserved and its own tests are unaffected by this migration

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

None — migration was straightforward. The EventViewer "open question 3" from RESEARCH.md resolved cleanly: since LiveEventPipeline now stores Threshold handles directly in sd.thresholds, EventViewer.buildSensor() can simply call addThreshold(t) without any Threshold reconstruction from plain structs.

## Next Phase Readiness

- Zero ThresholdRules/addThresholdRule references remain in any EventDetection production code
- Combined with Plans 01-03, zero references remain across the entire codebase (excluding ThresholdRule.m class file)
- Phase 1001 is complete — Threshold is a first-class entity used consistently throughout SensorThreshold and EventDetection

---
*Phase: 1001-first-class-threshold-entities*
*Completed: 2026-04-05*
