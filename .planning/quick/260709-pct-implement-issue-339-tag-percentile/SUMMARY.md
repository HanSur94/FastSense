---
type: quick
quick_id: 260709-pct
slug: implement-issue-339-tag-percentile
issue: 339
status: complete
---

# Summary: Tag.percentile()/median()/iqr() (#339)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class order-statistics surface —
  `pv = percentile(levels, t0, t1)` (toolbox-free linear interpolation
  i = p/100*(n-1)+1 between sorted samples; output matches level shape;
  NaN-masked; empty=>NaN; validates levels in [0,100] -> Tag:invalidPercentile;
  non-numeric series -> Tag:notNumeric), plus convenience `median(t0,t1)` == P50
  and `iqr(t0,t1)` == P75-P25. Inherited by every Tag kind via getXYRange.
- `tests/suite/TestTag.m`: +8 tests (scalar, vector-shape, median==P50, IQR,
  window, NaN-robust, empty=>NaN, invalid-level errors).

## Verification
- TestTag: 47 passed / 0 failed (was 39; +8).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · read-only ·
no serialization / Tag / Widget contract change.
