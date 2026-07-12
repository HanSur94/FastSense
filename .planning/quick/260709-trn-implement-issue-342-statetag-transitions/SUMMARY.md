---
type: quick
quick_id: 260709-trn
slug: implement-issue-342-statetag-transitions
issue: 342
status: complete
---

# Summary: StateTag.transitions() (#342)

## What was built
- `libs/SensorThreshold/StateTag.m`: new public `S = transitions()` — walks
  getXY and emits a struct-array record {Time, FromState, ToState} at each
  actual state change (repeated-value samples skipped), handling both numeric
  and cellstr Y via strcmp / isequaln (a NaN->NaN run is not a spurious change).
  Returns an empty struct with those fields for a constant or empty channel.
  Categorical analog of crossings (#328); change-point complement to the
  aggregate stateDurations (#258).
- `tests/suite/TestStateTag.m`: +4 tests (numeric, cellstr, constant=>empty,
  empty-channel=>empty).

## Verification
- TestStateTag: 22 passed / 0 failed (was 18; +4).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no property /
toStruct / fromStruct / contract change.
