---
type: quick
quick_id: 260709-cmd
slug: implement-issue-325-composite-minduration
issue: 325
status: complete
---

# Summary: CompositeTag MinDuration debounce (#325)

## What was built
- `libs/SensorThreshold/private/minDurationFilter_.m`: new shared helper that
  zeros contiguous resolved-1 runs whose X-span is strictly < minDur (the same
  debounce MonitorTag applies), preserving NaN "unknown" as run boundaries.
- `libs/SensorThreshold/CompositeTag.m`: opt-in `MinDuration` (public, default 0)
  parsed in the constructor (+ added to splitArgs_ cmpKeys), applied to the
  aggregated 0/1 series in mergeStream_ before caching, and round-tripped in
  toStruct (omit-when-zero) / fromStruct. Default 0 preserves current behavior
  exactly. Completes MinDuration across the boolean-tag trilogy.
- `tests/suite/TestCompositeTag.m`: +4 tests (suppresses short run, zero keeps
  short run, struct round-trip, omit-when-zero).

## Verification
- TestCompositeTag: 35 passed / 0 failed (was 31; +4).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean (3 files).

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · default 0 = no behavior
change · serialized composites without minduration load unchanged (fieldOr_ 0).
