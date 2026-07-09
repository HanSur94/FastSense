---
type: quick
quick_id: 260709-lvl
slug: implement-issue-349-monitortag-level
issue: 349
status: complete
---

# Summary: MonitorTag.level() factory (#349)

## What was built
- `libs/SensorThreshold/MonitorTag.m`: static factory
  `m = MonitorTag.level(key, parentTag, tripLevel, ...)` — synthesizes the
  ConditionFn (@(x,y) y>trip for 'above', y<trip for 'below') and, when
  'Deadband' d>0, the AlarmOffConditionFn for hysteresis. Crucially the off
  handle is the CLEAR trigger (the FSM flips ON->OFF when it is true), so 'above'
  clears at y<trip-d and 'below' at y>trip+d. All other options (MinDuration,
  EventStore, callbacks, Persist, DataStore, Tag universals) forward verbatim to
  the constructor. No FSM/constructor/serialization change.
- `tests/suite/TestMonitorTag.m`: +6 tests (above default + no off-cond, below,
  deadband extends alarm through the band, option forwarding, 3 validation
  errors).

## Verification
- TestMonitorTag: 33 passed / 0 failed (was 27; +6).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no FSM/constructor/
serialization change · reuses existing AlarmOffConditionFn hysteresis machinery.
