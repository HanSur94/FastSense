---
type: quick
quick_id: 260709-ack
slug: implement-issue-310-eventstore-bulkack
issue: 310
status: complete
---

# Summary: EventStore.acknowledgeEvents / acknowledgeAll (#310)

## What was built
- `libs/EventDetection/EventStore.m`:
  - `n = acknowledgeEvents(ids, opts)` — bulk ack of a specific set (char/string/
    string-array/cell). Loops the existing acknowledgeEvent per id so each ack
    keeps the full IDENT-02 audit stamp; skips unknown + already-acknowledged
    ids; returns count acknowledged; no auto-save.
  - `n = acknowledgeAll(opts)` — thin convenience over the unacknowledged set
    (AckedAt empty), delegating to acknowledgeEvents.
- `tests/suite/TestEventStoreRw.m`: +5 tests (ack-list, skip-already-acked,
  skip-unknown, ack-all + idempotent, audit-comment preserved through bulk path).

## Verification
- TestEventStoreRw: 26 passed / 0 failed (was 21; +5).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · acknowledgeEvent and the
on-disk ack format unchanged — existing scripts/serialized logs unaffected.
