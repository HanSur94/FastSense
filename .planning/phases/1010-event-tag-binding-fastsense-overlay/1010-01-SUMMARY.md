---
phase: 1010-event-tag-binding-fastsense-overlay
plan: 01
subsystem: event-detection
tags: [event-binding, tag-keys, singleton-registry, many-to-many]
dependency_graph:
  requires: []
  provides: [EventBinding singleton, Event.TagKeys, Event.Severity, Event.Category, Event.Id, EventStore auto-Id, EventBinding-based eventsForTag]
  affects: [EventTimelineWidget (transparent), MonitorTag emission]
tech_stack:
  added: []
  patterns: [persistent containers.Map singleton (EventBinding), forward+reverse index]
key_files:
  created:
    - libs/EventDetection/EventBinding.m
    - tests/test_event_binding.m
    - tests/test_event_tag_binding.m
  modified:
    - libs/EventDetection/Event.m
    - libs/EventDetection/EventStore.m
    - libs/SensorThreshold/MonitorTag.m
    - tests/test_monitortag_events.m
decisions:
  - Event.Id uses sequential counter in EventStore.append (sprintf('evt_%d', counter))
  - EventBinding.attach is idempotent (silent on duplicate)
  - getEventsForTag combines EventBinding lookup with carrier-field fallback (dedup by Id)
  - Octave handle == not supported; use Id string comparison for dedup
  - Pre-Phase-1010 Pitfall 5 grep gate inverted to Phase 1010 requirement gate
metrics:
  duration: 9m 16s
  completed: 2026-04-17
  tasks: 2
  files: 7
requirements_completed: [EVENT-01, EVENT-02, EVENT-03, EVENT-04, EVENT-05]
---

# Phase 1010 Plan 01: Event.TagKeys + EventBinding Singleton + EventStore Migration Summary

EventBinding singleton with forward+reverse persistent containers.Map indexes; Event gains TagKeys/Severity/Category/Id in separate public properties block; EventStore auto-assigns Id in append() and delegates eventsForTag to EventBinding with carrier fallback; MonitorTag both emission sites (fireEventsOnRisingEdges_ + fireEventsInTail_) set TagKeys and call EventBinding.attach after append.

## Changes Made

### Task 1: Event.m new properties + EventBinding singleton + EventStore auto-Id + tests

**Event.m** -- Added a second `properties` block (public access) with TagKeys (cell, default {}), Severity (numeric, default 1), Category (char, default ''), Id (char, default ''). Existing `SetAccess = private` block with 14 properties is completely untouched. 6-arg constructor signature preserved.

**EventBinding.m** (NEW) -- Static-methods-only classdef with persistent containers.Map singleton pattern (identical to TagRegistry). Forward index: eventId -> cell of tagKeys. Reverse index: tagKey -> cell of eventIds. Static methods: attach (idempotent), getTagKeysForEvent, getEventsForTag (O(1) reverse lookup + filter), clear. Error ID: EventBinding:emptyId.

**EventStore.m** -- Added nextId_ private property (counter). append() now auto-assigns ev.Id = sprintf('evt_%d', counter) before growing events_ array (Event < handle so caller sees mutation). getEventsForTag() migrated from pure carrier-grep to EventBinding-based lookup with carrier-field fallback for events not found by EventBinding (backward compat). Dedup uses Id string comparison (Octave lacks handle ==).

**Tests** -- test_event_binding.m (7 tests): attach, multi-tag, idempotent, unknown event, getEventsForTag, clear, emptyId guard. test_event_tag_binding.m (10 initial tests): default properties, settable TagKeys/Severity/Category, auto-Id, eventsForTag via EventBinding, carrier fallback, many-to-many, Pitfall 4 gate, constructor backward compat.

### Task 2: MonitorTag emission sites updated

**MonitorTag.m** -- Both fireEventsInTail_ (line ~616) and fireEventsOnRisingEdges_ (line ~726) now set ev.TagKeys = {char(obj.Key), char(obj.Parent.Key)} and call EventBinding.attach(ev.Id, char(obj.Key)) + EventBinding.attach(ev.Id, char(obj.Parent.Key)) AFTER EventStore.append (which assigns Id). Legacy carrier fields (SensorName = Parent.Key, ThresholdLabel = obj.Key) still populated via constructor args.

**test_monitortag_events.m** -- Pre-Phase-1010 Pitfall 5 grep gate inverted: .TagKeys MUST now appear in MonitorTag.m.

**test_event_tag_binding.m** -- Extended with 3 MonitorTag integration tests: recompute path produces TagKeys + EventBinding entries, streaming path (appendData) produces TagKeys + EventBinding entries, legacy carrier fields still populated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Octave handle == not supported for Event dedup**
- **Found during:** Task 1
- **Issue:** EventStore.getEventsForTag used handle == for dedup, but Octave throws "eq method not defined for Event class"
- **Fix:** Used Id string comparison (strcmp) instead of handle identity
- **Files modified:** libs/EventDetection/EventStore.m

**2. [Rule 1 - Bug] Pre-Phase-1010 grep gate in test_monitortag_events.m**
- **Found during:** Task 2
- **Issue:** test_monitortag_events.m had a Pitfall 5 gate asserting .TagKeys must NOT appear in MonitorTag.m -- this was correct pre-Phase-1010 but Phase 1010 IS the migration
- **Fix:** Inverted the assertion: .TagKeys MUST now appear (with updated comment explaining the gate evolution)
- **Files modified:** tests/test_monitortag_events.m

**3. [Rule 1 - Bug] Test variable name typo (e vs ev)**
- **Found during:** Task 1
- **Issue:** test_event_tag_binding.m line 101 referenced `e.StartTime` instead of `ev.StartTime`
- **Fix:** Corrected to `ev.StartTime`
- **Files modified:** tests/test_event_tag_binding.m

## Decisions Made

1. **Event.Id generation:** Sequential counter in EventStore.append (`evt_1`, `evt_2`, ...) -- simple, deterministic, Octave-portable. No UUID needed.
2. **EventBinding.attach idempotent:** Silent on duplicate (no error) -- simpler caller contract, matches the plan's design.
3. **Carrier fallback dedup:** Events found by EventBinding are excluded from carrier-field matching via Id comparison (not handle ==) to avoid Octave incompatibility.
4. **Grep gate evolution:** Pitfall 5 pre-Phase-1010 ban on TagKeys in MonitorTag.m inverted to a Phase-1010 requirement gate -- the grep test now asserts TagKeys MUST appear.

## Known Stubs

None -- all data paths are fully wired.

## Verification Results

- test_event: 4/4 passed
- test_event_binding: 7/7 passed
- test_event_tag_binding: 13/13 passed
- test_monitortag: all passed
- test_monitortag_events: all passed
- test_monitortag_streaming: 7/7 passed
- Full suite: 87/89 passed (2 pre-existing failures: test_to_step_function, test_toolbar)
- Pitfall 4 gate: `grep -cE "properties.*Tag\b" Event.m` = 0 (no Tag-typed properties)
- EVENT-02 gate: only EventBinding.attach calls in MonitorTag.m (single-write-side)

## Self-Check: PASSED

All 7 key files found on disk. All 4 commit hashes verified in git log.
