---
type: quick
quick_id: 260709-pct
slug: implement-issue-339-tag-percentile
issue: 339
status: complete
---

# Quick Task: Tag.percentile()/median()/iqr() — order statistics (#339)

## Goal
Complete the Tag statistics surface with the order-statistic dimension #223
(getStats) deliberately left out: P50/P95/P99, median, IQR.

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` (base class, inherited by all kinds).
- **New API:** `percentile(levels, t0, t1)` (toolbox-free linear-interp,
  i = p/100*(n-1)+1), `median(t0,t1)` == P50, `iqr(t0,t1)` == P75-P25.
- Read-only; no property / serialization / contract change.

## Test
- `tests/suite/TestTag.m`: scalar level, vector shape, median==P50,
  IQR=4.5, window, NaN-robust, empty=>NaN, invalid-level errors.

## Verification
- TestTag 47/47 pass. check_matlab_code + MISS_HIT clean.
