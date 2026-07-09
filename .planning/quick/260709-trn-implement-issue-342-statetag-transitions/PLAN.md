---
type: quick
quick_id: 260709-trn
slug: implement-issue-342-statetag-transitions
issue: 342
status: complete
---

# Quick Task: StateTag.transitions() — change-point event list (#342)

## Goal
Answer "when did the state change, from what to what" directly — the categorical
analog of crossings (#328), change-point complement to stateDurations (#258).

## Scope (additive only)
- **File:** `libs/SensorThreshold/StateTag.m` (one public method).
- **New API:** `S = transitions()` -> struct array {Time,FromState,ToState},
  one per actual change; empty struct for constant/empty channel. Handles
  numeric + cellstr Y (strcmp/isequaln).

## Test
- `tests/suite/TestStateTag.m`: numeric changes, cellstr changes, constant=>empty,
  empty channel=>empty.

## Verification
- TestStateTag 22/22. check_matlab_code + MISS_HIT clean.
