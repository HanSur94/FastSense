---
type: quick
quick_id: 260709-out
slug: implement-issue-343-tag-removeoutliers
issue: 343
status: complete
---

# Summary: Tag.removeOutliers() (#343)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class non-mutating
  `[cleanY,outlierIdx]` / `[cleanX,cleanY,outlierIdx] = removeOutliers(...)`.
  Robust outlier mask via Method hampel (rolling median+MAD, zero-spread spike
  handling), iqr (Tukey fence), or zscore (modified z-score); Window/Threshold
  knobs; Fill nan|linear|previous|remove. Toolbox-free (median/MAD + interp1;
  NOT isoutlier/filloutliers). Existing NaN inputs are never counted as
  outliers. numeric-Y only (StateTag categorical -> Tag:notNumeric). Inherited
  by every tag kind.
- `tests/suite/TestTag.m`: +9 tests (hampel spike, non-mutating, fill
  linear/previous/remove, iqr, zscore, non-numeric error, bad-option errors).

## Verification
- TestTag: 84 passed / 0 failed (was 75; +9).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint + mh_metric
  (--ci) clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · non-mutating (returns,
never changes the tag) · no serialization/contract change.
