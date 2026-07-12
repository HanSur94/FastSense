---
type: quick
quick_id: 260709-ack
slug: implement-issue-310-eventstore-bulkack
issue: 310
status: complete
---

# Quick Task: EventStore.acknowledgeEvents/acknowledgeAll — bulk ack (#310)

## Goal
One-call acknowledgement of an alarm flood (Notification Center / Event Viewer),
preserving each event's {user,host,epoch,comment} audit stamp.

## Scope (additive only)
- `libs/EventDetection/EventStore.m`:
  - acknowledgeEvents(ids, opts) -> count; loops acknowledgeEvent per id;
    skips unknown + already-acked; no auto-save.
  - acknowledgeAll(opts) -> count; filters unacked (AckedAt empty), delegates.

## Test
- `tests/suite/TestEventStoreRw.m`: ack-list, skip-already-acked, skip-unknown,
  ack-all + idempotent, audit-comment preserved.

## Verification
- TestEventStoreRw 26/26. check_matlab_code + MISS_HIT clean.
