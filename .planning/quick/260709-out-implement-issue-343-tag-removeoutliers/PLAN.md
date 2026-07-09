---
type: quick
quick_id: 260709-out
slug: implement-issue-343-tag-removeoutliers
issue: 343
status: complete
---

# Quick Task: Tag.removeOutliers() — toolbox-free despike (#343)

## Goal
The missing data-cleaning axis of the Tag analysis family: robust amplitude
outlier rejection so every downstream primitive is trustworthy.

## Scope (additive only)
- **File:** `libs/SensorThreshold/Tag.m` (base method, inherited by all kinds).
- **New API:** `[cleanY,idx]` / `[cleanX,cleanY,idx] = removeOutliers(...)`.
  Non-mutating. Method hampel|iqr|zscore, Window, Threshold, Fill
  nan|linear|previous|remove. Toolbox-free (median/MAD + interp1). numeric-only
  (StateTag -> Tag:notNumeric).

## Test
- `tests/suite/TestTag.m`: hampel spike, non-mutating, fill linear/previous/
  remove, iqr, zscore, non-numeric error, bad-option errors.

## Verification
- TestTag 84/84. check_matlab_code + MISS_HIT style/lint/metric clean.
