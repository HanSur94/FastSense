---
type: quick
quick_id: 260709-cwn
slug: implement-issue-358-tag-comparewindows
issue: 358
status: complete
---

# Quick Task: Tag.compareWindows(windows, ...) — phase-aligned overlay primitive (#358)

## Goal
Resolve a tag over N windows and re-zero each onto a shared relative-time axis
for shift-vs-shift / run-vs-run overlay.

## Scope (additive only)
- `libs/SensorThreshold/Tag.m` (base method): compareWindows({[t0 t1],...},
  'Anchor', start|end|scalar) -> struct array {RelT,Y,Window}. Delegates to
  getXYRange; Y passes through. Inherited by all kinds.

## Test
- `tests/suite/TestTag.m`: start anchor, end anchor, scalar anchor, Y carry,
  bad-args errors.

## Verification
- TestTag 96/96. check_matlab_code + MISS_HIT clean.
