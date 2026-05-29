---
phase: 1017
plan: "02"
subsystem: SensorThreshold / Tests
tags: [tag-system, event-wiring, registry-default, dual-key, regression-tests]
dependency_graph:
  requires: [1017-01]
  provides: [MonitorTag-registry-default-fallback, dual-key-emission-regression-tests]
  affects: [libs/SensorThreshold/MonitorTag.m, tests/suite/TestDashboardEventsToggle.m, tests/test_dashboard_events_toggle.m]
tech_stack:
  added: []
  patterns: [registry-default-fallback, dual-key-event-emission, isempty-guard-chain]
key_files:
  created: []
  modified:
    - libs/SensorThreshold/MonitorTag.m
    - tests/suite/TestDashboardEventsToggle.m
    - tests/test_dashboard_events_toggle.m
decisions:
  - "Fallback inserted after NV-pair for-loop and before Persist validation — explicit NV-pair always wins, backward compat preserved"
  - "Dual-key stamping at 3 sites verified already correct (lines 738-741, 762-765, 877-879) — no modification needed, only regression test added"
  - "Octave tests mirror MATLAB suite test-for-test using try/catch + nPassed/nFailed accumulator pattern"
metrics:
  duration: "PT8M"
  completed: "2026-04-28T12:01:24Z"
  tasks_completed: 2
  files_modified: 3
---

# Phase 1017 Plan 02: MonitorTag Registry-Default Fallback + Dual-Key Emission Tests Summary

3-line constructor fallback wired into MonitorTag so `TagRegistry.setEventStore(es)` propagates automatically; dual-key emission at 3 sites regression-protected by 3 new test methods in both MATLAB suite and Octave flat file.

## What Was Built

### Task 1: MonitorTag constructor registry-default fallback

Added a 5-line block (3 logic lines + comment) to `libs/SensorThreshold/MonitorTag.m` between the NV-pair for-loop closing `end` (line 183) and the Persist+DataStore validation (line 198):

```matlab
% Phase 1017: registry-default fallback. If no explicit
% 'EventStore' NV-pair was provided, consult the registry
% default set via TagRegistry.setEventStore(store). Returns
% [] when no default has been set, preserving pre-1017
% behavior for users who never wired a registry default.
if isempty(obj.EventStore)
    obj.EventStore = TagRegistry.getEventStore();
end
```

This makes the existing dual-key stamp paths in `fireEventsOnRisingEdges_` and `appendData` fire automatically because those paths are gated on `~isempty(obj.EventStore)`.

### Task 2: MATLAB + Octave regression tests

Three test methods appended to `TestDashboardEventsToggle.m` (after Plan 01's 5 additions):
- `testMonitorTagRegistryDefaultFallback` — verifies constructor picks up registry default
- `testMonitorTagExplicitOverridesRegistry` — verifies explicit NV-pair beats registry default
- `testMonitorTagDualKeyEmission` — triggers a closed event via `appendData` and verifies both `getEventsForTag(parent.Key)` and `getEventsForTag(monitor.Key)` return non-empty

Identical three blocks appended to `test_dashboard_events_toggle.m` (Tests 14-16) using Octave-portable `assert()` + `~isempty()`.

All 16 Octave tests pass (0 failures).

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | `240fb48` | feat(1017-02): MonitorTag constructor falls back to TagRegistry.getEventStore() |
| 2 | `bfd3266` | test(1017-02): add MonitorTag registry-default fallback + dual-key emission tests |

## Deviations from Plan

None — plan executed exactly as written.

The plan's awk acceptance criterion for placement order uses the LAST occurrence of `MonitorTag:unknownOption` (line 1009 in a different method), which gives a false ordering result. The actual placement is correct: fallback at line 185-192 is between the NV-loop's unknownOption (line 180) and persistDataStoreRequired (line 199). This is a documentation issue in the plan's acceptance criteria, not a code issue. All functional tests pass.

## Known Stubs

None — all new functionality is fully wired and tested.

## Self-Check: PASSED

Files exist:
- FOUND: libs/SensorThreshold/MonitorTag.m
- FOUND: tests/suite/TestDashboardEventsToggle.m
- FOUND: tests/test_dashboard_events_toggle.m

Commits exist:
- 240fb48 feat(1017-02): MonitorTag constructor falls back to TagRegistry.getEventStore()
- bfd3266 test(1017-02): add MonitorTag registry-default fallback + dual-key emission tests
