---
type: quick
quick_id: 260709-rmv
slug: implement-issue-354-eventstore-remove
issue: 354
status: complete
---

# Quick Task: EventStore.removeEvent/removeEvents + EventBinding.detach (#354)

## Goal
Close the create-without-delete asymmetry: targeted event deletion, so a
mis-placed manual annotation / test event can be cleaned before export.

## Scope (additive only)
- `libs/EventDetection/EventStore.m`: removeEvent(id) [strict], removeEvents(ids)
  [lenient bulk] -> count removed; linear Id scan + element removal; no auto-save.
- `libs/EventDetection/EventBinding.m`: additive detach(eventId) (mirror of attach).
- Cascade: detach bindings + drop single-user ack records per removed id.

## Test
- `tests/suite/TestEventStoreRw.m`: drop-one, unknown-throws, bulk-skips-unknown,
  binding-detach cascade, save/reload reduced set.

## Verification
- TestEventStoreRw 14/14. check_matlab_code + MISS_HIT clean.
