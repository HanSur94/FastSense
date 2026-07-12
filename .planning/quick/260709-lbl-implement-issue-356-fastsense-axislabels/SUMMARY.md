---
type: quick
quick_id: 260709-lbl
slug: implement-issue-356-fastsense-axislabels
issue: 356
status: complete
---

# Summary: FastSense XLabel/YLabel + auto-derive Y units (#356)

## What was built
- `libs/FastSense/FastSense.m`: public `XLabel`/`YLabel` options (name-value,
  default '') applied in render() only when non-empty — so the default is
  byte-for-byte identical to prior behaviour. addTag auto-derives YLabel from a
  single bound tag when unset (Units -> Name -> Key, matching FastSenseWidget),
  tracks it via a private YLabelAutoDerived_ flag, and clears the derived label
  once a second tag is added (multi-tag -> unlabeled). An explicit YLabel always
  wins over derivation.
- `tests/test_axis_labels.m`: 6 tests (explicit labels drawn, default unlabeled,
  derive-from-Units, fallback-to-Name, explicit-wins, multi-tag-clears).

## Verification
- test_axis_labels: All 6 passed (render exercised in a real figure, closed after).
- check_matlab_code + MISS_HIT mh_style/mh_lint: clean.

## Constraints
Strictly additive · toolbox-free · pure MATLAB/Octave · defaults reproduce
prior behaviour exactly · no serialization change.
