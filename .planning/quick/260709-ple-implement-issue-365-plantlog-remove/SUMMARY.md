---
type: quick
quick_id: 260709-ple
slug: implement-issue-365-plantlog-remove
issue: 365
status: complete
---

# Summary: PlantLogStore.removeEntries / removeEntriesInRange (#365)

## What was built
- `libs/PlantLog/PlantLogStore.m`:
  - `n = removeEntries(ids)` — targeted delete by Id (char/string/cell), skips
    unknown ids, preserves sorted-by-Timestamp order, returns count removed.
  - `n = removeEntriesInRange(t0, t1)` — delete entries with Timestamp in
    [t0,t1] (mirrors getEntriesInRange), returns count removed.
  Completes the store DELETE surface — sibling of EventStore.removeEvents (#354)
  and FastSenseDataStore.removeColumn (#364).
- `tests/suite/TestPlantLogStore.m`: +5 tests (by-id, bulk-skip-unknown,
  bad-input, in-range, bad-bounds).

## Verification
- TestPlantLogStore: 26 passed / 0 failed (was 21; +5).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no state/serialization
change · reuses existing id-addressing + sorted array representation.
