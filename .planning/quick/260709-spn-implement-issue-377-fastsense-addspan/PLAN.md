---
type: quick
quick_id: 260709-spn
slug: implement-issue-377-fastsense-addspan
issue: 377
status: complete
---

# Quick Task: FastSense.addSpan(t0, t1, ...) — vertical time-window highlight (#377)

## Goal
The missing vertical dual of addBand: shade a time window [t0,t1] across full Y.

## Scope (additive only)
- `libs/FastSense/FastSense.m`: Spans property, addSpan(t0,t1,...) (FaceColor/
  FaceAlpha/EdgeColor/Label; t0<=t1; pre-render), render after YLim finalize
  (patch [t0,t1]x[yLo,yHi], YLimInclude off, uistack bottom).

## Test
- `tests/test_add_span.m`: config, defaults, multiple, inverted error, render
  (hPatch valid, XData spans [t0,t1], UserData type), reject-after-render.

## Verification
- test_add_span 6/6 (incl. render). check_matlab_code + MISS_HIT clean.
