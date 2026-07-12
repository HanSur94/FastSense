---
type: quick
quick_id: 260709-vln
slug: implement-issue-357-fastsense-addvline
issue: 357
status: complete
---

# Quick Task: FastSense.addVLine(x, ...) — vertical reference line (#357)

## Goal
Vertical partner of addThreshold's horizontal line: mark an event instant /
setpoint change / shift boundary at a time value, spanning full Y.

## Scope (additive only)
- `libs/FastSense/FastSense.m`: VLines property, addVLine(x, ...) (Color/
  LineStyle/LineWidth/Label; pre-render), render block after YLim finalize
  (line spanning [yLimLow,yLimHigh], XLimInclude/YLimInclude off, optional label).

## Test
- `tests/test_add_vline.m`: config, defaults, multiple, non-scalar error,
  render (hLine valid, XData=[x x], UserData type), reject-after-render.

## Verification
- test_add_vline: 6/6 pass (incl. render). check_matlab_code + MISS_HIT clean.
