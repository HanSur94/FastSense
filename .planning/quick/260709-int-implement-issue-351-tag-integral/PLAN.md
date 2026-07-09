---
type: quick
quick_id: 260709-int
slug: implement-issue-351-tag-integral
issue: 351
status: complete
---

# Quick Task: Tag.integral(t0, t1) — scalar definite integral (#351)

## Goal
One number a sensor engineer reports (energy/dose/volume/throughput):
scalar area under Y over a window, replacing hand-rolled trapezoids.

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` — base method, inherited by all kinds.
- **New API:** `v = integral(obj, t0, t1)`; `integral()` / `integral([],[])`
  integrate the full series.
- Thin wrapper over the already-tested `cumulativeIntegral` (#327): reuses its
  toolbox-free, gap-robust trapezoidal core + empty/degenerate/NaN policy and
  Tag:integralOnDiscrete warning for state channels.

## Test
- `tests/suite/TestTag.m`: constant=>20, triangle=>8, window==Range,
  empty-bounds==full, empty-data=>0, NaN-robust, discrete-warns.

## Verification
- TestTag 39/39 pass. check_matlab_code + MISS_HIT clean.
