---
type: quick
quick_id: 260709-eg0
slug: implement-issue-360-eventstore-getevent
issue: 360
status: complete
---

# Quick Task: EventStore.getEvent(id) — id-addressed point-read (#360)

## Goal
Add the missing READ of the id-addressed event CRUD surface: fetch one Event
by its `.Id` without hand-filtering `getEvents()`.

## Scope (additive only)
- **File:** `libs/EventDetection/EventStore.m`
- **New API:** `ev = getEvent(obj, eventId)` — searches the same set as
  `getEvents` (in-memory single-user; merged NDJSON in cluster mode), matches
  Id for Event-object and struct rows (mirrors acknowledgeEvent/closeEvent).
  Throws `EventStore:unknownEventId` when absent — uniform with the sibling
  id-addressed mutators.

## Test
- `tests/suite/TestEventStoreRw.m`: `testGetEventById`, `testGetEventUnknownIdThrows`.

## Verification
- `TestEventStoreRw`: 9/9 pass. check_matlab_code clean on added method.
  MISS_HIT style+lint clean.
