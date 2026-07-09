---
type: quick
quick_id: 260709-spn
slug: implement-issue-377-fastsense-addspan
issue: 377
status: complete
---

# Summary: FastSense.addSpan(t0, t1, ...) (#377)

## What was built
- `libs/FastSense/FastSense.m`: new Spans config property + `addSpan(t0, t1, ...)`
  — the vertical time-window dual of addBand. Shades X in [t0,t1] across the full
  Y range. Options FaceColor / FaceAlpha / EdgeColor / Label; pre-render only
  (FastSense:alreadyRendered), non-scalar or inverted bounds rejected
  (FastSense:invalidSpan). Rendered after YLim finalises as a translucent patch
  with YLimInclude off, pushed behind the data lines via uistack (try/catch for
  environments without it), tagged UserData.FastSense.Type='span'.
- `tests/test_add_span.m`: 6 tests (config, defaults, multiple, inverted error,
  render smoke [hPatch valid, XData spans [t0,t1], UserData type],
  reject-after-render).

## Verification
- test_add_span: All 6 passed (render exercised in a real figure, closed after).
- check_matlab_code clean on new code; MISS_HIT mh_style + mh_lint clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · no serialization change ·
existing FastSense scripts/overlays untouched.
