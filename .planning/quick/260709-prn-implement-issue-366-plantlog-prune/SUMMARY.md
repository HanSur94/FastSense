---
type: quick
quick_id: 260709-prn
slug: implement-issue-366-plantlog-prune
issue: 366
status: complete
---

# Summary: PlantLogStore.pruneEntriesBefore(t) (#366)

## What was built
- `libs/PlantLog/PlantLogStore.m`: `n = pruneEntriesBefore(t)` — age-based
  retention that drops entries with Timestamp < t (keeps >= t), returns the
  count removed; no-op when nothing is older, empties the store when t is past
  the newest entry. Numeric-scalar guard (PlantLogStore:invalidInput). Sibling
  of the EventStore age-prune (#293).
- `tests/suite/TestPlantLogStore.m`: +4 tests (prune-head, no-op,
  empties-past-newest, bad-input).

## Verification
- TestPlantLogStore: 30 passed / 0 failed (was 26; +4).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no state/serialization
change.
