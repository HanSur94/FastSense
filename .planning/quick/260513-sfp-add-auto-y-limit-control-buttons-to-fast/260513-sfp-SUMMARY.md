---
phase: 260513-sfp
plan: 01
subsystem: Dashboard
tags: [dashboard, fastsense-widget, widget-button-bar, y-axis, ui-chrome]
type: quick
status: verified
requirements:
  - SFP-01   # YLimitMode property on FastSenseWidget (auto-visible / auto-all / locked)
  - SFP-02   # 3 buttons rendered on the WidgetButtonBar for FastSenseWidget tiles
  - SFP-03   # Button clicks update YLimitMode and apply Y limits without full rerender
  - SFP-04   # Backward-compat: existing dashboards (no YLimitMode in JSON) behave as before
  - SFP-05   # Resize / SizeChangedFcn re-anchors the new buttons alongside Info/Detach
dependency_graph:
  requires:
    - "FastSenseWidget (YLimits pin, UserZoomedY latch, IsSettingYLim guard, autoScaleY_)"
    - "FastSense.LiveViewMode='follow' guard (260513-ovt — must remain authoritative)"
    - "DashboardLayout.realizeWidget / reflowChrome_ / getOrCreateButtonBar_ / addInfoIcon / addDetachButton"
    - "DashboardWidget.clearPanelControls protectedTags allow-list"
  provides:
    - "FastSenseWidget.YLimitMode public property + setYLimitMode public method"
    - "FastSenseWidget.autoScaleY_ mode dispatch (auto-visible / auto-all / locked) — public signature unchanged"
    - "DashboardLayout.addYLimitButtons_ (duck-typed via ismethod(widget,'setYLimitMode'))"
    - "DashboardLayout.{addYLimitButton_, onYLimitButtonClicked_, syncYLimitButtonsState_, chooseYLimitActiveBg_}"
    - "YLimitMode JSON round-trip in DashboardEngine save/load (default omitted to keep diffs invisible)"
  affects:
    - "Every FastSenseWidget tile inside DashboardEngine (visible 3-button cluster on the WidgetButtonBar)"
    - "DashboardWidget.clearPanelControls (extended protected-tag list)"
tech_stack:
  added: []
  patterns:
    - "Duck-typed widget chrome injection (ismethod check, not isa)"
    - "Mode-dispatching method with preserved public signature (autoScaleY_(obj, y))"
    - "Theme-field fallback chain (PressedBg / SelectedBg / AccentColor / brightened ToolbarBackground)"
    - "JSON-default omission to keep legacy dashboards diff-invisible"
key_files:
  created:
    - "tests/test_fastsense_widget_ylimit_modes.m"
  modified:
    - "libs/Dashboard/FastSenseWidget.m"
    - "libs/Dashboard/DashboardLayout.m"
    - "libs/Dashboard/DashboardWidget.m"
decisions:
  - "Mode dispatch lives inside autoScaleY_(obj, y) rather than at the caller — keeps public signature stable; render(), rebuildForTag_(), and refresh() callers do not change"
  - "Buttons inject via duck-typed ismethod(widget,'setYLimitMode') rather than isa(widget,'FastSenseWidget') — future widgets that expose Y-rescale modes (e.g., 2D heatmap with Z-clamp) get the chrome for free"
  - "ASCII glyphs V/A/L instead of Unicode — existing Info ('i') and Detach ('^') buttons are ASCII; Octave's font rendering on Linux for Unicode in uicontrol String is inconsistent across versions"
  - "Default YLimitMode='auto-visible' reproduces pre-260513-sfp behaviour exactly — old dashboards load with no behavioural change AND no JSON diff (toStruct omits the default)"
  - "LiveViewMode='follow' precedence preserved — autoScaleY_ still short-circuits on Follow regardless of YLimitMode, so 260513-ovt's Follow-toggle semantics are untouched"
  - "Explicit YLimits pin (non-empty) still wins over YLimitMode — back-compat with dashboards that pin Y limits explicitly"
  - "Click handler clears UserZoomedY so an explicit mode click re-engages autoscale (otherwise the user's prior mouse-zoom would latch the axis forever)"
  - "No new theme tokens — chooseYLimitActiveBg_ falls through PressedBg / SelectedBg / AccentColor / brightened ToolbarBackground. Leaves a clean follow-up if reviewers want a proper theme.PressedBg field"
  - "Click handler catches and warns ('DashboardLayout:yLimitClickFailed') rather than throws — never crash the refresh loop on a button click failure"
metrics:
  duration_minutes: ~22
  completed: "2026-05-13"
---

# Quick Task 260513-sfp: Auto Y-Limit Control Buttons (V/A/L) on FastSenseWidget — Summary

One-liner: Adds a 3-button mutually-exclusive Y-axis rescale cluster (auto-visible / auto-all / locked) to the WidgetButtonBar of every FastSenseWidget tile, exposing on-tile Y-limit control without forcing detach or YLimits pinning in the dashboard script.

## What Was Built

Three small uicontrol pushbuttons (`V`, `A`, `L`) on the per-widget grey chrome strip of every `FastSenseWidget` tile, left of the existing Info (`i`) and Detach (`^`) buttons:

- **V — auto-visible (default)** — rescale Y to cover data inside the current X window (the new mode-routed equivalent of the pre-260513-sfp `autoScaleY_` behaviour)
- **A — auto-all** — rescale Y to cover ALL Y data the underlying Tag exposes, regardless of current XLim — useful for putting a spike in global context
- **L — locked** — freeze the current YLim; live ticks no longer rescale Y

The active mode's button shows a distinct pressed/highlighted background; the other two stay at `theme.ToolbarBackground`. Resize re-anchors all three buttons via the existing `reflowChrome_` SizeChangedFcn handler. Existing dashboards (no `YLimitMode` in JSON) default to `auto-visible` and behave exactly as before.

## Final Commit Hashes

- `4db9138` — `test(260513-sfp-01)`: 11-case failing test file (RED phase) for `FastSenseWidget.YLimitMode`
- `cc18c7f` — `feat(260513-sfp-01)`: `YLimitMode` property + `setYLimitMode` method + mode dispatch on `FastSenseWidget` (GREEN — all 11 tests pass)
- `a9cc181` — `feat(260513-sfp-02)`: V/A/L button cluster on `WidgetButtonBar` (`DashboardLayout` + `DashboardWidget`)

## Files Changed

| File                                          | Change   | LOC delta              | Purpose                                                                                                  |
| --------------------------------------------- | -------- | ---------------------- | -------------------------------------------------------------------------------------------------------- |
| `libs/Dashboard/FastSenseWidget.m`            | Modified | +180 / -0              | `YLimitMode` property, `setYLimitMode`, dispatch in `autoScaleY_`, `getYFromTagOrInline_`, `getYInVisibleXWindow_`, `toStruct/fromStruct` round-trip |
| `libs/Dashboard/DashboardLayout.m`            | Modified | +195 / -3              | `addYLimitButtons_`, `addYLimitButton_`, `onYLimitButtonClicked_`, `syncYLimitButtonsState_`, `chooseYLimitActiveBg_`, `realizeWidget` duck-typed call, `needsBar` extended, `reflowChrome_` re-anchor |
| `libs/Dashboard/DashboardWidget.m`            | Modified | +5 / -2                | `clearPanelControls` protectedTags extended with `YLimitVisibleBtn / YLimitAllBtn / YLimitLockBtn`         |
| `tests/test_fastsense_widget_ylimit_modes.m`  | Created  | +303 (across 2 commits)| 11 function-style cases: default mode, validation, visible/all/locked dispatch, UserZoomedY clear-on-click, YLimits pin precedence, struct round-trip, legacy-struct back-compat, Follow-mode override |

Total: 4 files, ~383 net LOC added.

## Automated Test Results

Run via `mcp__matlab__run_matlab_test_file` (matlab -batch on macOS arm64, plus interactive desktop session):

| Test file                                                | Result                                                           |
| -------------------------------------------------------- | ---------------------------------------------------------------- |
| `tests/test_fastsense_widget_ylimit_modes.m` (new)       | **11/11 PASS**                                                   |
| `tests/test_fastsense_widget_tag.m` (regression)         | **7/7 PASS**                                                     |
| `tests/test_fastsense_follow_toggle.m` (260513-ovt guard)| **10/10 PASS**                                                   |
| `tests/test_dashboard_time_sync_all_pages.m` (regression)| **5/5 PASS**                                                     |
| `tests/test_dashboard_range_selector_integration.m`      | **Case 1 PASS, Case 2 pre-existing failure under -batch** (deferred — see `deferred-items.md`; reproduced via `git stash` on parent commit `9f46c92`, so NOT caused by 260513-sfp) |

Smoke probe (`mcp__matlab__evaluate_matlab_code`): on a 1-widget demo dashboard the three buttons render with correct tags (`YLimitVisibleBtn`, `YLimitAllBtn`, `YLimitLockBtn`) on the `WidgetButtonBar`, the default `V` button is highlighted, and clicks update the active highlight and the chart's YLim.

## User Verification Result

**APPROVED** on the live `demo/industrial_plant/run_demo.m` dashboard. All 8 scenarios from the checkpoint pass:

1. Default state: `V` button pressed, Y auto-scales to visible window (back-compat regression OK)
2. Auto-fit visible (V): pan to narrow window, click V — Y snaps to that window's data + padding
3. Auto-fit all (A): click A — Y expands to cover the full tag Y range regardless of X zoom
4. Locked (L): set range via V/A, click L, run live ~30s — YLim does NOT rescale; click V to unlock
5. User mouse-zoom override: scroll-wheel zoom Y in V mode latches UserZoomedY; click V again clears the latch and re-engages autoscale
6. Resize: dragging the figure edge keeps `[V][A][L]` anchored right alongside `[i][^]` with no overlap (see Known Caveat below for the 0-px gap between L and `i`)
7. Detach: clicking `^` opens the detached mirror — the mirror does NOT show V/A/L (out-of-scope; figure-level `FastSenseToolbar` already provides standard MATLAB axes-toolbar zoom controls)
8. Backward compat: opening an existing v3.0 demo dashboard — all tiles default to V (auto-visible) and behave identically to pre-260513-sfp

## Known Caveat

**The V/A/L cluster's right edge butts against the Info (`i`) button with a 0-px gap rather than the intended 4-px gap.**

Root cause: `DashboardLayout.addInfoIcon` (untouched by this plan) uses `xInfo = barPos(3) - 28 - 28 - 4`, treating the button width as 28 px even though the actual button is 24 px. This is a pre-existing typo from earlier work, explicitly called out as out-of-scope in the plan's `<interfaces>` block (line ~170 of `260513-sfp-PLAN.md`):

> NOTE: addInfoIcon already uses `barW - 28 - 28 - 4` (a typo from earlier work that treats button width as 28). For this plan, use 24+24+4 spacing for the new buttons. Do NOT "fix" the Info button — that is OUT OF SCOPE.

`addYLimitButtons_` uses the correct 24+24+4 math relative to where Info SHOULD be, so the 0-px gap is inherited from the `addInfoIcon` typo. The user explicitly accepted this caveat at the checkpoint approval — the visual is acceptable and the buttons function correctly. Fixing it requires touching `addInfoIcon` (`bw - 24 - 24 - 4 - 4`), which would belong to a separate cleanup task.

Logged at: `.planning/quick/260513-sfp-add-auto-y-limit-control-buttons-to-fast/deferred-items.md` (alongside the pre-existing `test_dashboard_range_selector_integration.m` Case 2 -batch failure).

## Design Decisions

1. **Y-mode dispatch lives inside `autoScaleY_(obj, y)`** rather than at the caller — keeps the method's public signature (`autoScaleY_(obj, y)`) byte-identical so `render`, `rebuildForTag_`, and any external callers keep working unchanged. The new dispatch is purely internal: after the existing precedence guards (`YLimits` pin / `UserZoomedY` / `FastSense.LiveViewMode == 'follow'` / not-rendered), the method branches on `obj.YLimitMode` — `locked` returns; `auto-all` swaps `y` for full tag data via `getYFromTagOrInline_`; `auto-visible` falls through to the existing min/max + threshold + padding code path.
2. **Duck-typed chrome injection** via `ismethod(widget, 'setYLimitMode')` rather than `isa(widget, 'FastSenseWidget')` — future widgets exposing a Y-rescale mode (e.g., a 2D heatmap with Z-clamp modes) opt in by simply implementing `setYLimitMode`, without touching `DashboardLayout`. Also extends `needsBar` so a duck-typed widget that omits `Description` and `DetachCallback` still gets a chrome strip to host its buttons.
3. **ASCII glyphs (`V`, `A`, `L`)** chosen to match existing Info (`i`) and Detach (`^`) buttons — Octave's font rendering on Linux for Unicode glyphs in `uicontrol String` is inconsistent across versions, and the existing WidgetButtonBar deliberately avoids Unicode.
4. **Default `YLimitMode = 'auto-visible'`** for backward compatibility — exactly reproduces pre-260513-sfp `autoScaleY_` behaviour. Existing dashboards load with no behavioural diff. `toStruct` omits `yLimitMode` when it equals the default, so JSON diffs of legacy dashboards stay invisible.
5. **`LiveViewMode='follow'` precedence preserved** — `autoScaleY_` short-circuits on `FastSense.LiveViewMode == 'follow'` BEFORE the new mode dispatch. This protects the 260513-ovt Follow-toggle semantics (Follow's explicit "freeze X+Y view, append only" intent still wins over any auto-rescale mode). Regression-guarded by `test_fastsense_follow_toggle.m` (10/10 pass).
6. **`UserZoomedY` cleared on explicit click** — without this, a user's prior mouse-zoom would latch `UserZoomedY = true` forever and silently defeat the V/A buttons. An explicit click on V or A is an explicit re-engage signal; clicking L while user-zoomed is also a clean freeze.
7. **`YLimits` numeric pin still wins** — explicit pinning via the `YLimits` property on the widget remains the highest-precedence mode (after the early-return guards). Old dashboards that pin Y explicitly keep their pinned range regardless of which V/A/L button is "active" visually.
8. **No new theme tokens** — `chooseYLimitActiveBg_` falls through `PressedBg` -> `SelectedBg` -> `AccentColor` -> brightened `ToolbarBackground`. Leaves a clean follow-up to add a proper `theme.PressedBg` field if reviewers prefer.

## Out-of-Scope Follow-ups (not done, deliberately)

- **Detached-mirror V/A/L cluster** — `DetachedMirror` uses its own figure-level `FastSenseToolbar` (not a `WidgetButtonBar`). Adding the cluster there would belong to a separate quick task that extends `FastSenseToolbar` rather than `DashboardLayout`. For v1 of this feature, the detached mirror retains the standard MATLAB axes-toolbar zoom controls plus `FastSenseToolbar`'s Follow/Live buttons, which is sufficient.
- **Symmetric-zero mode (a 4th button)** — explicit YAGNI for v1; trivial to add as a `'symmetric'` value in the `YLimitMode` validation switch.
- **`theme.PressedBg` field** — the `chooseYLimitActiveBg_` fallback chain works today; a proper theme token would be a clean follow-up.
- **`addInfoIcon` 28→24 px fix** — pre-existing typo, deliberately untouched per the plan's `<interfaces>` instruction; manifests as the 0-px gap between L and Info documented under Known Caveat.

## Deviations from Plan

- **Test file canRenderFigures_() guard** — the planned `usejava('desktop')` skip-on-headless guard was too strict for the rendered cases (they DO run under `matlab -batch` because they use offscreen `figure('Visible','off')`). Loosened to a `canRenderFigures_()` helper so the rendered cases execute under `-batch` / `-nodisplay` rather than skip. `test_fastsense_follow_toggle.m` keeps the stricter guard (it touches `uitoggletool`, which is genuinely incompatible with `-batch`).

Tracked as `[Rule 3 - Test infra]` adjustment, internal to the test file only; no production-code impact.

## Self-Check: PASSED

Verified all claimed artifacts exist:

- `libs/Dashboard/FastSenseWidget.m` (modified, contains `YLimitMode`, `setYLimitMode`, dispatch) — FOUND
- `libs/Dashboard/DashboardLayout.m` (modified, contains `addYLimitButtons_`) — FOUND
- `libs/Dashboard/DashboardWidget.m` (modified, contains extended `protectedTags`) — FOUND
- `tests/test_fastsense_widget_ylimit_modes.m` (created) — FOUND
- Commit `4db9138` in `git log --oneline` — FOUND
- Commit `cc18c7f` in `git log --oneline` — FOUND
- Commit `a9cc181` in `git log --oneline` — FOUND
