---
type: quick
quick_id: 260709-int
slug: implement-issue-351-tag-integral
issue: 351
status: complete
---

# Summary: Tag.integral(t0, t1) (#351)

## What was built
- `libs/SensorThreshold/Tag.m`: new base-class `v = integral(obj, t0, t1)`
  returning the scalar definite integral (area under the curve) over a window;
  `integral()` / `integral([],[])` integrate the full series. Implemented as a
  thin positional-arg wrapper over cumulativeIntegral (#327) — inheriting its
  toolbox-free gap-robust trapezoidal core, empty/single-sample=>0 policy,
  NaN-zeroing, and Tag:integralOnDiscrete warning. Inherited by Sensor/Derived/
  Composite/Monitor/State without per-kind code.
- `tests/suite/TestTag.m`: +7 tests (constant=>20, triangle=>8, window==Range,
  empty-bounds==full-series, empty-data=>0, NaN-robust, discrete-warns).

## Verification
- TestTag: 39 passed / 0 failed (was 32; +7).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean on both files.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no serialization
change · built on the base getXYRange/cumulativeIntegral contract.
