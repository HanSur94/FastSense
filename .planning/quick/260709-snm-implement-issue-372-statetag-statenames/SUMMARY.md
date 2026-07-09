---
type: quick
quick_id: 260709-snm
slug: implement-issue-372-statetag-statenames
issue: 372
status: complete
---

# Summary: StateTag StateNames + nameAt (#372)

## What was built
- `libs/SensorThreshold/StateTag.m`: optional public `StateNames` property (Nx2
  {code, name} legend; [] => numeric behaviour unchanged), accepted as a
  'StateNames' constructor NV (added to splitArgs_). New `nameAt(t)` accessor
  that looks up valueAt(t) and maps the code through the legend, mirroring
  valueAt's scalar->char / vector->cellstr shape, with a numeric-string fallback
  for unmapped codes (always safe to call). Legend mapping factored into a static
  private mapCode_. Serialized in toStruct (double-wrapped, omit-when-empty) and
  restored in fromStruct, so existing serialized StateTags round-trip untouched.
- `tests/suite/TestStateTag.m`: +6 tests (scalar name, vector names,
  unmapped->numeric string, no-legend fallback, struct round-trip, omit-when-empty).

## Verification
- TestStateTag: 28 passed / 0 failed (was 22; +6).
- TestTagRegistry: 29/29 (StateTag serialization change caused no regression).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free / Octave-safe (Nx2 cell, no containers.Map
requirement) · pure MATLAB/Octave · no Tag base-contract change · default empty
= numeric behaviour byte-for-byte unchanged.
