---
quick_id: 260513-ovt
description: Preserve Y-axis limits when Follow toggle is engaged
date: 2026-05-13
status: complete
---

# Summary: Y limits stay untouched while Follow is on

## What changed

`libs/Dashboard/FastSenseWidget.m::autoScaleY_` now has a third early-return guard: when the underlying `FastSense.LiveViewMode == 'follow'`, autoScaleY_ returns immediately without touching YLim. Header doc was updated to list the new skip condition.

Before the change there were two early-returns:
1. `YLimits` pinned via NV-pair
2. `UserZoomedY == true` (user has manually zoomed Y)

The new condition adds:
3. `FastSenseObj.LiveViewMode == 'follow'` (Follow toggle engaged)

## Why

When the user clicked Follow:
- X axis correctly snapped to the data tail via `snapToTail()` (XLim only)
- Y axis was getting silently rescaled on every live tick by `autoScaleY_`, fighting the user's expectation that Follow is purely an X-side feature

The user's intent: "Follow is auto-pan-to-latest in X; leave my Y alone."

## Verification

- `mcp__matlab__check_matlab_code` on the modified file: no new warnings near the edited region.
- `rehash` succeeded and `which('FastSenseWidget')` resolves correctly.
- Source-string probe `contains(src, "strcmp(obj.FastSenseObj.LiveViewMode, 'follow')")` returns true.
- Industrial plant demo (`demo/industrial_plant/run_demo.m`) launched cleanly; user can now toggle Follow and confirm YLim is preserved.

## Files

- `libs/Dashboard/FastSenseWidget.m` — added third early-return + doc update

## Commits

- `498a5f3` fix(quick-260513-ovt): preserve Y-axis limits while Follow is engaged
- `4798dd6` docs(quick-260513-ovt): record commit hash in STATE.md
