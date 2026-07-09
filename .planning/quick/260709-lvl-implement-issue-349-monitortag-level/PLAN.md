---
type: quick
quick_id: 260709-lvl
slug: implement-issue-349-monitortag-level
issue: 349
status: complete
---

# Quick Task: MonitorTag.level() factory — level alarm w/ Deadband hysteresis (#349)

## Goal
One-line scalar level alarm that synthesizes ConditionFn + AlarmOffConditionFn,
with built-in Deadband hysteresis.

## Scope (additive only)
- `libs/SensorThreshold/MonitorTag.m` (Static): level(key,parent,trip,...).
  Direction above|below, Deadband d (0=momentary). Forwards all other NV to ctor.
  offFn is the CLEAR trigger (FSM flips off when true).

## Test
- `tests/suite/TestMonitorTag.m`: above default, below, deadband extends alarm,
  option forwarding, validation errors.

## Verification
- TestMonitorTag 33/33. check_matlab_code + MISS_HIT clean.
