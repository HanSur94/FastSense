---
type: quick
quick_id: 260709-txt
slug: implement-issue-347-fastsense-addtext
issue: 347
status: complete
---

# Summary: FastSense.addText(x, y, str, ...) (#347)

## What was built
- `libs/FastSense/FastSense.m`: new Texts config property + `addText(x, y, str, ...)`
  — the text callout member of the annotation family. Places str at data
  coordinates (x,y). Options Color (default Theme.ForegroundColor) / FontSize /
  HorizontalAlignment / VerticalAlignment; pre-render only
  (FastSense:alreadyRendered), non-scalar coords or non-char str rejected
  (FastSense:invalidText). Rendered as a front-layer text object tagged
  UserData.FastSense.Type='text'.
- `tests/test_add_text.m`: 6 tests (config + custom options, defaults, multiple,
  bad-args errors, render smoke [hText valid, String, UserData type],
  reject-after-render).

## Verification
- test_add_text: All 6 passed (render exercised in a real figure, closed after).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no serialization change ·
existing FastSense scripts/overlays untouched.
