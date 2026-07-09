---
type: quick
quick_id: 260709-cor
slug: implement-issue-340-tag-correlate
issue: 340
status: complete
---

# Quick Task: Tag.correlate(other) — Pearson correlation, first relational primitive (#340)

## Goal
Open the relational analysis dimension: "do two channels move together, and by
how much?" — redundant-sensor agreement, drift-vs-reference, cause/effect.

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` (base method, inherited by all kinds).
- **New API:** `r = correlate(other, t0, t1)`; `[r, n] = correlate(...)`.
  Aligns other onto obj's timestamps via ZOH valueAt; drops pairwise NaN;
  toolbox-free Pearson via sums; NaN for n<2 or zero-variance.

## Test
- `tests/suite/TestTag.m`: identical=>1, anti=>-1, orthogonal=>0, n-out,
  zero-variance=>NaN, n<2=>NaN, ZOH alignment, range, bad-other error.

## Verification
- TestTag 68/68 pass. check_matlab_code + MISS_HIT clean.
