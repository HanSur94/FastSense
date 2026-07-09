---
type: quick
quick_id: 260709-cor
slug: implement-issue-340-tag-correlate
issue: 340
status: complete
---

# Summary: Tag.correlate(other) (#340)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class `r = correlate(other, t0, t1)`
  (2-out `[r, n]`) — the first relational primitive of the Tag analysis family.
  Samples `other` onto obj's (windowed) timestamps by zero-order-hold valueAt
  (the DerivedTag ZOH convention), drops pairwise-NaN samples, and computes
  toolbox-free Pearson r via sums. Returns NaN for fewer than 2 aligned pairs or
  a constant (zero-variance) channel. Inherited by every Tag kind.
- `tests/suite/TestTag.m`: +9 tests (identical=>1, anti=>-1, orthogonal=>0,
  sample-count out, zero-variance=>NaN, n<2=>NaN, ZOH coarse-grid alignment
  (~0.885), range window, bad-other error).

## Verification
- TestTag: 68 passed / 0 failed (was 59; +9).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free (Pearson via sums, no Statistics Toolbox) ·
pure MATLAB/Octave · read-only · reuses getXYRange + valueAt · no
serialization/contract change. Unlocks the #341 lagCorrelation sibling.
