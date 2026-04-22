---
phase: 1014-fix-140-matlab-test-suite-failures-from-v2-0-legacy-class-deletion
plan: 05
subsystem: tests/suite
tags: [test-suite, eventdetection, legacy-cleanup, v2.0]
requires:
  - Phase 1011 (legacy Sensor/Threshold pipeline deleted)
  - Phase 1009 (LiveEventPipeline rewired to MonitorTargets)
provides:
  - "EventDetection test suite collapsed to v2.0 API surface only"
  - "Zero legacy-class references in TestEventStore.m and TestEventConfig.m"
  - "TestEventDetector.m, TestIncrementalDetector.m, TestLivePipeline.m removed"
affects:
  - tests/suite/
tech-stack:
  added: []
  patterns:
    - "Per-method triage + whole-file deletion when every method hits deleted API"
key-files:
  created: []
  modified:
    - tests/suite/TestEventStore.m
    - tests/suite/TestEventConfig.m
  deleted:
    - tests/suite/TestEventDetector.m
    - tests/suite/TestIncrementalDetector.m
    - tests/suite/TestLivePipeline.m
decisions:
  - "TestLivePipeline.m deleted entirely: all 7 methods pass SensorTag+Threshold to LiveEventPipeline which now expects MonitorTargets (containers.Map of MonitorTag). No salvageable method."
  - "TestEventStore.m pruned to 1 method (testFromFileNotFound): pure EventViewer.fromFile negative path is the only legacy-free survivor."
  - "TestEventConfig.m pruned to 3 methods (testConstructorDefaults, testSetColor, testBuildDetector): property defaults + setColor map + buildDetector inspection are the only legacy-free survivors."
  - "TestEventDetector.m had to be deleted twice — Plan 03 commit b262faf restored it (out of Plan 03's scope); Plan 05 commit d2d1405 re-deleted it as owner."
metrics:
  duration: 3min
  completed: 2026-04-22
---

# Phase 1014 Plan 05: EventDetection Test-Suite Collapse Summary

EventDetection test suite collapsed to v2.0 API surface: deleted 3 whole files and pruned 2 to their non-legacy methods only — ~37 erroring methods eliminated.

## Objective Recap

Wave 1 EventDetection test-suite collapse. Research established that the legacy Sensor-centric detection pipeline is GONE:
- `EventDetector.detect` has only the 2-arg Tag overload
- `IncrementalEventDetector.process` is a stub that throws `legacyRemoved`
- `EventConfig.addSensor` throws `legacyRemoved`; `.addTag` never existed; `.runDetection` returns empty
- `LiveEventPipeline` rewired to `MonitorTargets` (containers.Map of key→MonitorTag) in Phase 1009

## File-by-File Outcome

| File | Status | Methods eliminated | Methods retained |
|------|--------|-------------------:|-----------------:|
| tests/suite/TestEventDetector.m | **DELETED** | 8 (testDetectSingleEvent, testStats, testPeakValueLow, testMultipleEvents, testDebounceFilter, testNoViolations, testCallback, testMaxCallsPerEvent) | 0 |
| tests/suite/TestIncrementalDetector.m | **DELETED** | 9 (testFirstBatchDetectsEvents, testIncrementalNewEventsOnly, testOpenEventCarriesOver, testOpenEventFinalizes, testNoDataNoEvents, testSeverityEscalation, testMultipleSensors, testSliceDetectionConsistency, makeTag helper) | 0 |
| tests/suite/TestLivePipeline.m | **DELETED** | 7 (testConstructor, testSingleCycle, testMultipleCyclesIncremental, testEventsWrittenToStore, testNotificationTriggered, testStartStop, testSensorFailureSkipped + makePipeline helper) | 0 |
| tests/suite/TestEventStore.m | **PRUNED** | 7 (testAutoSave, testFromFile, testFromFileColors, testNoEventFile, testBackupCreated, testMaxBackupsZero, testFromFileHasRefreshControls) | 1 (testFromFileNotFound) |
| tests/suite/TestEventConfig.m | **PRUNED** | 6 (testAddTag, testRunDetection, testEscalateSeverity, testEscalateDisabled, testEscalateLowDirection, testSaveViaEventStore) | 3 (testConstructorDefaults, testSetColor, testBuildDetector) |

**Total eliminated:** 37 test methods + 2 helper functions.
**Total retained across surviving files:** 4 test methods.

## Replacement Coverage (Untouched — Not in Plan 05 Scope)

| File | Role |
|------|------|
| tests/suite/TestEventDetectorTag.m | v2.0 2-arg `det.detect(tag, threshold)` path — Plan 03 scope |
| tests/suite/TestEventStoreRw.m | live EventStore append/save/load round-trip |
| tests/suite/TestLiveEventPipelineTag.m | v2.0 MonitorTargets-based LiveEventPipeline path |

Confirmed via `ls` post-execution: all three still present and unmodified by this plan.

## Commits Landed

| Commit | Subject |
|--------|---------|
| `938f70e` | fix(1014-05): delete TestIncrementalDetector.m (legacyRemoved stub) |
| `d36153e` | fix(1014-05): prune TestEventStore — delete legacy cfg.addTag/runDetection methods |
| `debf53e` | fix(1014-05): prune TestEventConfig — delete legacy addTag/runDetection methods |
| `680b11c` | fix(1014-05): delete TestLivePipeline.m (legacy SensorTag+Threshold pipeline) |
| `d2d1405` | fix(1014-05): delete TestEventDetector.m (legacy 6-arg detect signature) |

All 5 commits use `--no-verify` per parallel-wave directive; each commit is atomic (one file change per commit).

## Deviations from Plan

### [Rule 3 - Blocker] TestEventDetector.m restored by Plan 03 mid-execution

- **Found during:** Task 1 verification pass
- **Issue:** An earlier commit (`6734727` by parallel plan) had already deleted TestEventDetector.m. During Plan 05 Task 1, `git rm` reported removal but `git status` showed no staged change (file was not tracked). Between my Task 2 work and final verification, Plan 03 commit `b262faf` ("restore TestEventDetector.m — out-of-scope for Plan 03") re-added the file to the working tree.
- **Fix:** Re-ran `git rm tests/suite/TestEventDetector.m` and committed as `d2d1405`. Commit body notes the restore/re-delete chain for bisectability.
- **Files modified:** tests/suite/TestEventDetector.m (re-deleted)
- **Commit:** d2d1405

## Authentication Gates

None.

## Known Stubs

None introduced by this plan. Deleted tests previously exercised stubs (`IncrementalEventDetector.process` → throws `legacyRemoved`, `EventConfig.addSensor` → throws `legacyRemoved`, `EventConfig.runDetection` → returns empty) — those stubs remain in libs/ for backward-compat error surface but have no test coverage (intentional: they are dead-code error signals, not behavior under test).

## Success Criteria Verification

- [x] `TestEventDetector.m` deleted (confirmed: `[ -f ... ] && echo EXISTS || echo DELETED` → `DELETED`)
- [x] `TestIncrementalDetector.m` deleted (confirmed)
- [x] `TestLivePipeline.m` deleted (confirmed)
- [x] `TestEventStore.m` legacy-class regex count: **0**
- [x] `TestEventConfig.m` legacy-class regex count: **0**
- [x] `detectEventsFromSensor` active-call count in tests/suite/: **0** (one residual match is a comment in TestGoldenIntegration.m line 64 — Plan 04 scope)
- [x] Surviving files have ≥1 method each (TestEventStore: 1, TestEventConfig: 3)
- [x] `TestEventStoreRw.m` and `TestLiveEventPipelineTag.m` untouched (confirmed via `git log --oneline -- tests/suite/TestEventStoreRw.m tests/suite/TestLiveEventPipelineTag.m` — no Plan 05 commits)
- [ ] Octave green — not runnable in this executor environment; left to CI + phase-level verifier
- [ ] MISS_HIT clean — not runnable in this executor environment; surviving files are minimal idiomatic MATLAB (classdef + methods blocks; no new lint surface introduced)

## D-05 Kill-Switch Outcome

**Not invoked.** Aggregate duration ~3 minutes vs. 45-minute budget. Whole-file deletion (3 files) made the triage trivial; the 2 pruned files had tight legacy/pure method partitions.

## Self-Check: PASSED

- File existence checks: all 5 target files in correct state (3 deleted, 2 pruned+present).
- Commit hashes: all 5 commits present in `git log --grep="1014-05"`.
- Regex checks: zero legacy-class refs in surviving files.
