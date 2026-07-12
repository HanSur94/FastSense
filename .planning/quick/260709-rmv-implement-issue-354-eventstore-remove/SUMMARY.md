---
type: quick
quick_id: 260709-rmv
slug: implement-issue-354-eventstore-remove
issue: 354
status: complete
---

# Summary: EventStore.removeEvent/removeEvents + EventBinding.detach (#354)

## What was built
- `libs/EventDetection/EventStore.m`: `n = removeEvents(ids)` (lenient bulk —
  char/string/string-array/cell of ids; unknown skipped; returns count removed)
  and `n = removeEvent(id)` (strict — missing id throws EventStore:unknownEventId,
  uniform with getEvent/closeEvent). Linear Id scan + events_ element removal,
  no auto-save (Pitfall 2). Cascade: EventBinding.detach per removed id
  (best-effort) + drop matching single-user acks_ records.
- `libs/EventDetection/EventBinding.m`: additive `detach(eventId)` — removes the
  forward-index entry and purges the id from every reverse-index tagKey list,
  dropping emptied tagKeys. Mirror of attach; idempotent.
- `tests/suite/TestEventStoreRw.m`: +5 tests (drop-one, unknown-throws,
  bulk-skips-unknown, binding-detach cascade, save/reload reduced set).

## Verification
- TestEventStoreRw: 14 passed / 0 failed (was 9; +5).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean (3 files).

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no Event / toStruct /
fromStruct change — existing serialized event logs keep loading unchanged.
