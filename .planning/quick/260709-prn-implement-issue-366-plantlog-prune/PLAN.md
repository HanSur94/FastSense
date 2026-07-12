---
type: quick
quick_id: 260709-prn
slug: implement-issue-366-plantlog-prune
issue: 366
status: complete
---

# Quick Task: PlantLogStore.pruneEntriesBefore(t) — age-based retention (#366)

## Goal
Trim a long-running operator journal to a retention window — drop entries older
than t (keep Timestamp >= t). Sibling of the EventStore age-prune (#293).

## Scope (additive only)
- `libs/PlantLog/PlantLogStore.m`: pruneEntriesBefore(t) -> count removed; no-op
  when nothing older; empties when t past newest. numeric-scalar guard.

## Test
- `tests/suite/TestPlantLogStore.m`: prune-head, no-op, empties-past-newest,
  bad-input.

## Verification
- TestPlantLogStore 30/30. check_matlab_code + MISS_HIT clean.
