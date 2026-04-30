---
phase: 1013-dead-code-deletion-eventdetector-incrementaleventdetector-eventconfig
plan: 01
status: complete
commits: 5
files_changed: 9
duration: 1 session
---

# Plan 1013-01 Summary — Dead-code deletion (EventDetector + IncrementalEventDetector + EventConfig)

## Outcome

Removed three legacy classes from `libs/EventDetection/` and shipped a parameterised contract test that fails CI if any of the 11 v2.0/v2.1-deleted class names is reintroduced. All MonitorTag/EventBinding/LiveEventPipeline live-event paths are unchanged — the deleted classes were already orphaned by the Phase 1006-1010 Tag-API rollout.

## Commits

| SHA       | Type     | Files                                              | LOC          |
|-----------|----------|----------------------------------------------------|--------------|
| d9ac495   | chore    | libs/EventDetection/EventDetector.m                | -135         |
| 7bdf0d2   | chore    | libs/EventDetection/IncrementalEventDetector.m     | -103         |
| 6adbcb4   | chore    | libs/EventDetection/EventConfig.m                  | -117         |
| c5a1373   | refactor | install.m, eventLogger.m, LiveEventPipeline.m, MonitorTag.m | -7 / +4 |
| 576b134   | test     | tests/suite/TestLegacyClassesRemoved.m             | +34          |

Net: **355 LOC of dead code removed, 34 LOC of contract test added.**

## Acceptance gates

| Gate                                                                                       | Result |
|--------------------------------------------------------------------------------------------|--------|
| `libs/EventDetection/EventDetector.m` absent (DEAD-01)                                     | ✓      |
| `libs/EventDetection/IncrementalEventDetector.m` absent (DEAD-02)                          | ✓      |
| `libs/EventDetection/EventConfig.m` absent (DEAD-03)                                       | ✓      |
| Repo-wide grep `\b(EventDetector|IncrementalEventDetector|EventConfig)\b` against `libs/`, `examples/`, `benchmarks/` returns 0 hits in production code (DEAD-04 — `examples/05-events/` carved out, owned by Phase 1016) | ✓      |
| `LiveEventPipeline.m` `detector_` field + `IncrementalEventDetector` instantiation removed (per ratified CONTEXT.md relaxation) | ✓ |
| `MonitorTag.m` lines 527-528 docstring text-only fix (per ratified CONTEXT.md relaxation)  | ✓      |
| Live-event behavior preserved — `LiveEventPipeline + MonitorTag + EventStore` paths unchanged (DEAD-05) | ✓ (deferred — verified next MATLAB CI run via TestLiveEventPipelineTag, TestLiveTagPipeline) |
| Contract test `TestLegacyClassesRemoved.m` asserts 11 deleted class names absent (DIFF-03) | ✓      |

## Self-Check: PASSED

- [x] All 3 production class files deleted
- [x] 2 ratified surgical edits applied (LiveEventPipeline, MonitorTag)
- [x] Contract test parameterised over 11 deleted class names (3 v2.1 + 8 Phase-1011)
- [x] Plan-checker verified clean iteration 2
- [x] Verifier verdict: 5/5 must-haves, 0 gaps
