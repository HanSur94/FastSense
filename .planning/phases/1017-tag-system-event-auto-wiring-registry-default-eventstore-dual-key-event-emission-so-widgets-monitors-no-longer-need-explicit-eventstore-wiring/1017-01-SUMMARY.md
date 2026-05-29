---
phase: 1017
plan: 01
subsystem: SensorThreshold/TagRegistry + tests
tags: [tag-system, event-store, registry, persistent-singleton, containers-map, tdd]
dependency_graph:
  requires: []
  provides: [TagRegistry.setEventStore, TagRegistry.getEventStore, TagRegistry.eventStoreRef_]
  affects: [libs/SensorThreshold/TagRegistry.m, tests/suite/TestDashboardEventsToggle.m, tests/test_dashboard_events_toggle.m]
tech_stack:
  added: []
  patterns: [persistent containers.Map handle singleton, setEventStore/getEventStore static API]
key_files:
  modified:
    - libs/SensorThreshold/TagRegistry.m
    - tests/suite/TestDashboardEventsToggle.m
    - tests/test_dashboard_events_toggle.m
decisions:
  - containers.Map handle used (not cell/struct persistent) so mutations via returned ref propagate — avoids Pitfall 1
  - clear() resets the EventStore slot via ref.remove('store') — avoids Pitfall 5 test-isolation contamination
  - Pass [] to setEventStore() clears the slot (no new error IDs per CONTEXT decision)
  - setEventStore / getEventStore placed in the existing methods(Static) block adjacent to clear() for discoverability
metrics:
  duration: ~8 minutes
  completed: "2026-04-28T11:57:13Z"
  tasks_completed: 2
  files_modified: 3
---

# Phase 1017 Plan 01: TagRegistry setEventStore/getEventStore + tests Summary

**One-liner:** Registry-default EventStore via `setEventStore`/`getEventStore` static methods backed by a persistent `containers.Map` handle singleton, with `clear()` reset for test isolation.

## What Was Built

`TagRegistry.m` gained:
- `setEventStore(store)` public static — stores an `EventStore` handle in the persistent `containers.Map`. Pass `[]` to clear the default.
- `getEventStore()` public static — returns the registered store, or `[]` if none set (safe to call before any `setEventStore` call).
- `eventStoreRef_()` private static helper — persistent `containers.Map('KeyType','char','ValueType','any')` so handle mutations propagate through returned references (avoids Pitfall 1: cell persistent copy-on-assign).
- `clear()` extended to reset the `'store'` key in `eventStoreRef_()` (avoids Pitfall 5: stale store across tests).

Tests added to both MATLAB suite and Octave flat test file:
1. `testTagRegistryEventStoreRoundTrip` — `setEventStore(s)` then `getEventStore()` returns `s`
2. `testTagRegistryEventStoreEmptyDefault` — `getEventStore()` returns `[]` before any set
3. `testTagRegistryEventStoreOverwrite` — second `setEventStore` overwrites first
4. `testTagRegistryClearResetsEventStore` — `clear()` wipes the store slot
5. `testTagRegistryEventStoreSetEmptyClears` — `setEventStore([])` clears the slot

## Commits

| Hash | Message |
|------|---------|
| 5bafcf4 | feat(1017-01): TagRegistry.setEventStore + getEventStore + eventStoreRef_() helper |
| 1ba91c6 | test(1017-01): Add TagRegistry EventStore round-trip + clear-resets + overwrite tests |

## Verification Results

- `grep -c "function setEventStore" TagRegistry.m` = 1 (PASS)
- `grep -c "function store = getEventStore" TagRegistry.m` = 1 (PASS)
- `grep -c "function m = eventStoreRef_" TagRegistry.m` = 1 (PASS)
- `grep -c "containers.Map('KeyType', 'char', 'ValueType', 'any')" TagRegistry.m` = 1 (PASS)
- `grep -c "ref.remove('store')" TagRegistry.m` = 2 (PASS — one in setEventStore, one in clear)
- `grep -c "ref('store') = store" TagRegistry.m` = 1 (PASS)
- Octave round-trip + clear-resets + setEmpty: all 13 tests green (8 existing + 5 new)
- `test_tag_registry`: all 14 tests pass (no regression)

## Deviations from Plan

None — plan executed exactly as written.

The plan's `<acceptance_criteria>` used `==` for handle equality in the Octave command (which fails because `EventStore` does not define `eq`). This was a documentation artifact — the actual test code in `<behavior>` and `<action>` correctly uses `isequal()`, which was applied throughout. No deviation from intended semantics.

## Known Stubs

None — all methods are fully implemented and wired. `getEventStore()` returns `[]` when unset by design (per CONTEXT "No new error IDs"), which is intentional and not a stub.

## Self-Check: PASSED
