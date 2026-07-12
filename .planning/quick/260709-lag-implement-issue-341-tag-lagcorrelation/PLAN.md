---
type: quick
quick_id: 260709-lag
slug: implement-issue-341-tag-lagcorrelation
issue: 341
status: complete
---

# Quick Task: Tag.lagCorrelation(other, MaxLag) — cross-correlation / time-lag (#341)

## Goal
Time-delay sibling of correlate (#340): best lag + r-vs-lag curve between two
tags — transport delay, propagation, control lead/lag.

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` (base method + static pearson_ helper).
- **New API:** `dt = lagCorrelation(other[,t0,t1][,'MaxLag',L])`;
  `[dt,r,lags,rr]` forms. ZOH-resample both onto a uniform grid (median A
  spacing), toolbox-free normalized cross-correlation, argmax lag. NaN guards.

## Test
- `tests/suite/TestTag.m`: recover +4 delay, identical=>lag0/r1, MaxLag clamp,
  full curve shape, n<2=>NaN, zero-variance=>NaN, bad-other error.

## Verification
- TestTag 75/75. check_matlab_code + MISS_HIT style/lint/metric clean.
