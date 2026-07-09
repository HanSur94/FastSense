---
type: quick
quick_id: 260709-snm
slug: implement-issue-372-statetag-statenames
issue: 372
status: complete
---

# Quick Task: StateTag StateNames + nameAt (#372)

## Goal
Code->name legend for integer-coded state channels without losing the numeric
plot: render "Run" not bare 2.

## Scope (additive only)
- `libs/SensorThreshold/StateTag.m`: StateNames property (Nx2 {code,name}),
  'StateNames' NV in splitArgs_, nameAt(t) accessor (scalar->char / vector->cell,
  numeric-string fallback), static mapCode_ helper, toStruct omit-when-empty +
  fromStruct round-trip.

## Test
- `tests/suite/TestStateTag.m`: scalar, vector, unmapped fallback, no-legend
  fallback, round-trip, omit-when-empty.

## Verification
- TestStateTag 28/28; TestTagRegistry 29/29 (no serialization regression).
  check_matlab_code + MISS_HIT clean.
