---
type: quick
quick_id: 260709-eg0
slug: implement-issue-360-eventstore-getevent
issue: 360
status: complete
---

# Summary: EventStore.getEvent(id) (#360)

## What was built
- `libs/EventDetection/EventStore.m`: new `ev = getEvent(obj, eventId)` — the
  id-addressed READ of the event CRUD surface. Searches `getEvents()` (so it
  works in both single-user and cluster/NDJSON modes), matches Id on both
  Event objects and struct rows, and throws `EventStore:unknownEventId` when
  no event matches (uniform with acknowledgeEvent / closeEvent).
- `tests/suite/TestEventStoreRw.m`: +2 tests (found-by-id, not-found-throws).

## Verification
- `TestEventStoreRw`: 9 passed / 0 failed (was 7; +2).
- check_matlab_code: no issues in the added method (pre-existing info-level
  `now`/`datestr`/stale-suppression notes elsewhere untouched).
- MISS_HIT mh_style + mh_lint: clean on both files.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no format change ·
no Tag/Widget contract change.
