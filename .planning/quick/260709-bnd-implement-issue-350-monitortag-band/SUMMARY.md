---
type: quick
quick_id: 260709-bnd
slug: implement-issue-350-monitortag-band
issue: 350
status: complete
---

# Summary: MonitorTag.band() factory (#350)

## What was built
- `libs/SensorThreshold/MonitorTag.m`: static factory
  `m = MonitorTag.band(key, parentTag, lo, hi, ...)` — sibling of level() (#349).
  'outside' (default) trips when y<lo|y>hi; 'inside' trips when lo<=y<=hi. A
  Deadband d>0 synthesizes the AlarmOffConditionFn (clear trigger): outside
  clears back inside the shrunk band [lo+d,hi-d]; inside clears once outside the
  widened band [lo-d,hi+d]. lo>hi and non-finite bounds -> MonitorTag:invalidBand.
  All other options forward verbatim to the constructor.
- `tests/suite/TestMonitorTag.m`: +4 tests (outside default + no off-cond,
  inside, deadband holds alarm in the band zone, validation errors).

## Verification
- TestMonitorTag: 37 passed / 0 failed (was 33; +4).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no FSM/constructor/
serialization change · reuses AlarmOffConditionFn hysteresis machinery.
