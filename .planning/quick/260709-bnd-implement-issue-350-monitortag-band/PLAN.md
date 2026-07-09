---
type: quick
quick_id: 260709-bnd
slug: implement-issue-350-monitortag-band
issue: 350
status: complete
---

# Quick Task: MonitorTag.band() factory — range / out-of-band alarm (#350)

## Goal
Sibling of level() (#349): out-of-band alarm from plain scalars lo/hi, with
optional hysteresis.

## Scope (additive only)
- `libs/SensorThreshold/MonitorTag.m` (Static): band(key,parent,lo,hi,...).
  Direction outside(default)|inside, Deadband shrinks/widens band on clear.
  Forwards all other NV to ctor.

## Test
- `tests/suite/TestMonitorTag.m`: outside default, inside, deadband holds,
  validation errors.

## Verification
- TestMonitorTag 37/37. check_matlab_code + MISS_HIT clean.
