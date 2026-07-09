---
type: quick
quick_id: 260709-pks
slug: implement-issue-329-tag-findpeaks
issue: 329
status: complete
---

# Summary: Tag.findPeaks() (#329)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class `varargout = findPeaks(obj, ...)` —
  toolbox-free local maxima/minima with prominence. Options MinProminence,
  MinSeparation, Polarity (max|min|both), Range. Returns struct
  {times,values,prominences,polarity,count,intervals} or 2-out [times,values].
  Detection: strict rise/fall with flat-top plateau => one peak; prominence via
  descend-to-higher-ground; NaN-segmented; greedy MinSeparation keeps the most
  prominent. Minima = maxima of -Y. StateTag warns Tag:findPeaksOnDiscrete.
  Core in a static private helper detectExtrema_.
- `tests/suite/TestTag.m`: +12 tests covering single/multi/prominence/
  separation/plateau/minima/both/NaN-gap/range/2-out/bad-option/discrete-warn.

## Verification
- TestTag: 59 passed / 0 failed (was 47; +12).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint + mh_metric
  (--ci) clean — no complexity/length violation.

## Constraints
Strictly additive · toolbox-free (diff/indexing + baseline walk, NOT SP-Toolbox
findpeaks) · pure MATLAB/Octave · read-only · no serialization/contract change.
