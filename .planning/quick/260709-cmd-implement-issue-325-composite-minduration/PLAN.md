---
type: quick
quick_id: 260709-cmd
slug: implement-issue-325-composite-minduration
issue: 325
status: complete
---

# Quick Task: CompositeTag MinDuration debounce (#325)

## Goal
Complete MinDuration support across all boolean-producing tags (Monitor/Derived/
Composite): suppress aggregated 1-runs shorter than MinDuration.

## Scope (additive only)
- New shared helper `libs/SensorThreshold/private/minDurationFilter_.m` (run
  filter, NaN-preserving, strict-<).
- `CompositeTag.m`: MinDuration property (default 0), constructor + splitArgs_
  cmpKeys, applied in mergeStream_ before caching, toStruct (omit-when-zero) +
  fromStruct round-trip.

## Test
- `tests/suite/TestCompositeTag.m`: suppresses short run, zero keeps run,
  round-trip, omit-when-zero.

## Verification
- TestCompositeTag 35/35. check_matlab_code + MISS_HIT clean.
