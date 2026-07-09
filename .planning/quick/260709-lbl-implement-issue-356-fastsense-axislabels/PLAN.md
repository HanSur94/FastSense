---
type: quick
quick_id: 260709-lbl
slug: implement-issue-356-fastsense-axislabels
issue: 356
status: complete
---

# Quick Task: FastSense XLabel/YLabel + auto-derive Y units (#356)

## Goal
Give the core plot axis labels; auto-derive Y label from a single bound tag's
Units->Name->Key (ports FastSenseWidget derivation into the core).

## Scope (additive only)
- `libs/FastSense/FastSense.m`: XLabel/YLabel public options (default ''),
  drawn in render only when non-empty; addTag auto-derives YLabel for a single
  tag when unset, clears it when a 2nd tag is added; explicit label wins.

## Test
- `tests/test_axis_labels.m`: explicit drawn, default unlabeled, derive-from-Units,
  fallback-to-Name, explicit-wins, multi-tag-clears.

## Verification
- test_axis_labels 6/6 (incl. render). check_matlab_code + MISS_HIT clean.
