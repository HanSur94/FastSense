---
type: quick
quick_id: 260709-vln
slug: implement-issue-357-fastsense-addvline
issue: 357
status: complete
---

# Summary: FastSense.addVLine(x, ...) (#357)

## What was built
- `libs/FastSense/FastSense.m`: new VLines config property + `addVLine(x, ...)`
  (the vertical partner of addThreshold). Options Color / LineStyle / LineWidth /
  Label; must be called pre-render (FastSense:alreadyRendered) and rejects a
  non-scalar x (FastSense:invalidVLine). Rendered after the axis Y-limits are
  finalised so each line spans the full Y range as a line object with
  XLimInclude/YLimInclude off (its extent excludes it from limit computation),
  tagged with UserData.FastSense.Type='vline', plus an optional top-anchored
  text label.
- `tests/test_add_vline.m`: 6 tests (config + custom options, defaults,
  multiple, non-scalar error, render smoke [hLine valid, XData=[x x], UserData
  type], reject-after-render).

## Verification
- test_add_vline: All 6 passed (render exercised in a real figure, closed after).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no serialization change ·
existing FastSense scripts/overlays untouched.
