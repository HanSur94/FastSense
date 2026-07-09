---
type: quick
quick_id: 260709-lag
slug: implement-issue-341-tag-lagcorrelation
issue: 341
status: complete
---

# Summary: Tag.lagCorrelation(other, MaxLag) (#341)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class `varargout = lagCorrelation(other, ...)`
  — the time-delay sibling of correlate. Forms: `dt`, `[dt,r]`,
  `[dt,r,lags,rr]`; options positional `t0,t1` and name-value `'MaxLag'` (time).
  Both tags are ZOH-resampled (valueAt) onto a uniform grid over A's windowed
  span (spacing = median A sample spacing) so a lag index maps to a time delay;
  a toolbox-free normalized cross-correlation (NOT xcorr/finddelay) is scanned
  over +/-MaxLag samples and the argmax gives the best lag (positive dt => B lags
  A). NaN when overlap < 2 or a channel is constant. Added static private helper
  `pearson_`.
- `tests/suite/TestTag.m`: +7 tests (recover +4 delay, identical=>lag0/r1,
  MaxLag clamp, full-curve shape, n<2=>NaN, zero-variance=>NaN, bad-other error).

## Verification
- TestTag: 75 passed / 0 failed (was 68; +7).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint + mh_metric
  (--ci) clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · read-only · reuses
getXYRange + valueAt · no serialization/contract change.
