---
type: quick
quick_id: 260709-cwn
slug: implement-issue-358-tag-comparewindows
issue: 358
status: complete
---

# Summary: Tag.compareWindows(windows, ...) (#358)

## What was built
- `libs/SensorThreshold/Tag.m`: base-class `series = compareWindows(windows, ...)`
  — resolves the tag over each [t0 t1] window (via getXYRange) and re-zeroes the
  time onto a shared RELATIVE axis, returning a struct array {RelT, Y, Window}
  ready for the FastSense.addLine overlay path. 'Anchor' selects 'start'
  (default, re-zero at t0), 'end' (align on t1), or a numeric scalar offset. Y
  passes through unchanged, so a categorical StateTag also aligns on relative
  time. Inherited by every Tag kind.
- `tests/suite/TestTag.m`: +5 tests (start anchor, end anchor, scalar anchor,
  Y carry-through, bad-args errors).

## Verification
- TestTag: 96 passed / 0 failed (was 91; +5).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · read-only · returns
plain data (no rendering/serialization contract) · built on getXYRange.
