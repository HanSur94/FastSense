---
type: quick
quick_id: 260709-edt
slug: implement-issue-355-eventstore-edit
issue: 355
status: complete
---

# Quick Task: EventStore.editEvent(id, ...) + Event.editWindow (#355)

## Goal
Complete annotation CRUD (create+delete shipped) with an id-addressed,
validated, save-aware EDIT — including the locked time window.

## Scope (additive only)
- `libs/EventDetection/Event.m`: additive editWindow(newStart,newEnd) — works on
  a closed event (unlike close), recomputes Duration, reuses EndTime>=StartTime
  guard (Event:invalidTimeRange).
- `libs/EventDetection/EventStore.m`: editEvent(id, name-value...) for
  StartTime/EndTime/Notes/Severity/Category/Label; validates keys before any
  mutation, window guard first, no auto-save.

## Test
- `tests/suite/TestEventStoreRw.m`: editWindow recompute+reject, edit
  window+notes+severity, unknown-id, unknown-field-untouched, inverted-untouched,
  save/reload.

## Verification
- TestEventStoreRw 21/21. check_matlab_code + MISS_HIT clean.
