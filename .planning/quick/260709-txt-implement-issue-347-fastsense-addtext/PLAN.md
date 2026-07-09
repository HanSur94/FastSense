---
type: quick
quick_id: 260709-txt
slug: implement-issue-347-fastsense-addtext
issue: 347
status: complete
---

# Quick Task: FastSense.addText(x, y, str, ...) — on-plot text annotation (#347)

## Goal
The missing text member of the annotation family (addMarker/addThreshold/addBand):
a text callout at data coordinates.

## Scope (additive only)
- `libs/FastSense/FastSense.m`: Texts property, addText(x,y,str,...) (Color/
  FontSize/HorizontalAlignment/VerticalAlignment; pre-render), render block
  (text() at (x,y), front layer, UserData type 'text').

## Test
- `tests/test_add_text.m`: config, defaults, multiple, bad-args errors, render
  (hText valid, String, UserData type), reject-after-render.

## Verification
- test_add_text 6/6 (incl. render). check_matlab_code + MISS_HIT clean.
