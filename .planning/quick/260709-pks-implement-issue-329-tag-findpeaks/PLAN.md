---
type: quick
quick_id: 260709-pks
slug: implement-issue-329-tag-findpeaks
issue: 329
status: complete
---

# Quick Task: Tag.findPeaks() — toolbox-free local-extrema detection (#329)

## Goal
Close the last universal numeric-analysis gap in the Tag family: local
peak/trough detection with prominence, toolbox-free (NOT SP-Toolbox findpeaks).

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` (base method + static private helper).
- **New API:** `findPeaks('MinProminence','MinSeparation','Polarity','Range')`;
  struct out {times,values,prominences,polarity,count,intervals}; 2-out [t,v].
- Reuses getSeries_/parseRange_/isDiscreteKind_ seam. NaN-segmented, plateau
  aware, greedy separation merge. StateTag warns Tag:findPeaksOnDiscrete.

## Test
- `tests/suite/TestTag.m`: single, multi+intervals, prominence filter,
  separation merge, plateau, minima, both, NaN gap, range, 2-out, bad-option,
  discrete-warns.

## Verification
- TestTag pass. check_matlab_code + MISS_HIT style/lint/metric clean.
