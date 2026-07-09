---
type: quick
quick_id: 260709-edt
slug: implement-issue-355-eventstore-edit
issue: 355
status: complete
---

# Summary: EventStore.editEvent + Event.editWindow (#355)

## What was built
- `libs/EventDetection/Event.m`: additive `editWindow(newStart, newEnd)` —
  in-place window correction that (unlike close) works on an already-closed
  event, recomputes Duration, and reuses the constructor's EndTime>=StartTime
  guard (Event:invalidTimeRange).
- `libs/EventDetection/EventStore.m`: `editEvent(id, 'Name', value, ...)` —
  id-addressed edit of StartTime/EndTime/Notes/Severity/Category/Label. Keys are
  validated before any mutation and the window guard runs first, so a bad key or
  inverted window leaves the event untouched. Legacy struct rows -> notEditable.
  No auto-save (Pitfall 2). Completes event CRUD (create+delete+edit).
- `tests/suite/TestEventStoreRw.m`: +7 tests (editWindow recompute + reject,
  edit window+notes+severity, unknown-id, unknown-field-untouched,
  inverted-window-untouched, save/reload).

## Verification
- TestEventStoreRw: 21 passed / 0 failed (was 14; +7).
- check_matlab_code clean; MISS_HIT mh_style + mh_lint clean (3 files).

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no toStruct/fromStruct
change — existing serialized event logs keep loading unchanged.
