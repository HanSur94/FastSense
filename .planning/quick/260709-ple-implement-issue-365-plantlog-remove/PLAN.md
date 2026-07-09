---
type: quick
quick_id: 260709-ple
slug: implement-issue-365-plantlog-remove
issue: 365
status: complete
---

# Quick Task: PlantLogStore.removeEntries/removeEntriesInRange (#365)

## Goal
Targeted DELETE for the operator journal — the last of the three journal stores
still missing it (siblings EventStore #354, FastSenseDataStore #364).

## Scope (additive only)
- `libs/PlantLog/PlantLogStore.m`:
  - removeEntries(ids) -> count; char/string/cell ids; skip unknown; keep order.
  - removeEntriesInRange(t0,t1) -> count; mirrors getEntriesInRange.

## Test
- `tests/suite/TestPlantLogStore.m`: by-id, bulk-skip-unknown, bad-input,
  in-range, bad-bounds.

## Verification
- TestPlantLogStore 26/26. check_matlab_code + MISS_HIT clean.
