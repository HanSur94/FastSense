---
phase: 260709-ikg
plan: 01
subsystem: Dashboard
tags: [dashboard, chrome, overflow-menu, ui-refresh, redline-e]
dependency-graph:
  requires: []
  provides:
    - "DashboardLayout.addOverflowMenu_ (private) — overflow '...' button"
    - "DashboardLayout.showOverflowMenu_ (private) — fresh context menu builder"
    - "DashboardLayout.reflowChrome_ anchors OverflowMenuButton in the leftmost folded slot"
  affects:
    - "Every FastSenseWidget rendered on a dashboard (chrome strip)"
tech-stack:
  added: []
  patterns:
    - "Compatibility shim: hide-but-keep-alive (Visible='off') identical to the 260709-gp9 toolbar pattern"
key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardLayout.m
decisions:
  - "Overflow button folds X/V/A/L/+ behind a single ... button posting a fresh uicontextmenu on every click (per user-approved design, prototyped live prior session)"
  - "Folded uicontrols stay ALIVE (Visible='off' only) so all existing Tag/Position/Callback/UserData-based test assertions remain valid"
  - "Menu items route to the SAME existing action methods — no new behavior, only a new entry point"
metrics:
  duration: "~25 min"
  completed: 2026-07-09
status: complete
---

# Phase 260709-ikg Plan 01: Overflow Menu for Widget Chrome (redline e) Summary

Folded the five secondary per-widget chrome buttons (CrosshairLink 'X', YLimit-Visible 'V', YLimit-All 'A', PlantLog 'L', CreateEvent '+') behind a single overflow "..." button that posts a context menu, matching redline (e) of the Pencil light-mode design spec — while keeping every folded uicontrol alive so no existing test regresses.

## What Was Built

**Task 1 — Compatibility shim (Visible='off' only).** Added `'Visible', 'off'` to the four creation sites that build the five folded buttons:
1. `addPlantLogToggle` (~line 712-724, `libs/Dashboard/DashboardLayout.m`) — Tag `PlantLogToggleButton` ('L').
2. `addCrosshairLinkToggle` (~line 811-826) — Tag `CrosshairLinkButton` ('X').
3. `addYLimitButton_` (~line 1087-1100, shared helper) — constructs BOTH `YLimitVisibleBtn` ('V') and `YLimitAllBtn` ('A'); one edit folds both.
4. `addCreateEventButton` (~line 1131-1145) — Tag `CreateEventButton` ('+').

Nothing else about these five uicontrols changed — Tag, Units, Position, FontSize, FontWeight, ForegroundColor, BackgroundColor, Enable, Callback, TooltipString, and UserData-driven active-state sync are byte-identical to before. `addInfoIcon` (InfoIconButton) and `addDetachButton` (DetachButton) were left completely untouched — Info and Detach stay visible.

**Task 2 — Overflow button + menu.** Added two new private instance methods:
- `addOverflowMenu_(obj, widget)` — resolves the theme, gets/creates the button bar, idempotently clears any prior `OverflowMenuButton` + stale `OverflowContextMenu`, then guards on whether ANY of the five folded tags are present on the bar (non-fold widgets get no `...` button — `return` early otherwise). Creates one `uicontrol` (glyph `char(8230)`, theme tokens only) with `Callback @(~,~) obj.showOverflowMenu_(widget, bar)`, then self-anchors via a best-effort `reflowChrome_` call.
- `showOverflowMenu_(obj, widget, bar)` — entire body wrapped in try/catch → `warning('DashboardLayout:overflowMenuFailed', ...)`. Deletes any prior `OverflowContextMenu`, builds a FRESH `uicontextmenu`, and adds one `uimenu` item per PRESENT folded button:
  - CrosshairLink → label/Checked reflect `widget.CrosshairLinked`; routes to `onCrosshairLinkTogglePressed_`.
  - YLimit-Visible / YLimit-All → Checked reflects `widget.YLimitMode`; routes to `onYLimitButtonClicked_`.
  - PlantLog → only added when the hidden button's `Enable` is `'on'` (store attached); label reflects `widget.ShowPlantLog`; routes to `onPlantLogTogglePressed_`.
  - CreateEvent → routes to `invokeCreateEventCallback_`.
  Posts via `set(cm,'Position',get(fig,'CurrentPoint')); set(cm,'Visible','on')` (the confirmed classic-figure mechanism).

Wired into 4 call sites, each guarded with its own try/catch → `DashboardLayout:overflowMenuFailed` warning, each placed AFTER all five folded buttons exist and BEFORE the enclosing `reflowChrome_` call:
- `realizeWidget` (after the `addCrosshairLinkToggle` block, before the final `reflowChrome_`).
- `addCrosshairLinkToggle` (before its closing reflow).
- `addPlantLogToggle` (before its closing reflow).
- `addYLimitButtons_` (after `syncYLimitButtonsState_`, at method end).

**Task 3 — Anchor in reflowChrome_.** Hoisted `xLink = xVisible - gap - bw` so it's computed unconditionally (previously only assigned inside the `CrosshairLinkButton`-present `if` block), reused by both the CrosshairLinkButton anchor and the new overflow anchor. Added `OverflowMenuButton` resolution + a `[xOverflow, 2, bw, bw]` position set, preferring `xLink` when CrosshairLinkButton is present, else `xVisible` (YLimitVisibleBtn), else `xAll` (YLimitAllBtn) — i.e. the leftmost folded slot. No other anchor logic (Detach/Create/Info/PlantLog/V/A/CrosshairLink) was changed.

## Verification (executor — no MATLAB available)

- `grep -c "'Visible', *'off'"` — baseline 0 (confirmed via `git show HEAD:libs/Dashboard/DashboardLayout.m` before this plan), now 4 — exactly the four folded creation sites. `addInfoIcon`/`addDetachButton` confirmed untouched (grep + manual inspection).
- `addOverflowMenu_` / `showOverflowMenu_` exist, wired into `realizeWidget` + the 3 rebuild methods; menu callbacks reference the four existing action methods (`onCrosshairLinkTogglePressed_`, `onYLimitButtonClicked_`, `onPlantLogTogglePressed_`, `invokeCreateEventCallback_` — 15 references total across the file); glyph confirmed as `char(8230)` (not a literal multibyte ellipsis).
- `reflowChrome_` resolves `OverflowMenuButton` and sets its position via `xOverflow`; `xLink` confirmed referenced by both the CrosshairLink anchor and the overflow fallback anchor (single hoisted assignment).
- `mh_style` and `mh_lint` (MISS_HIT, installed in this environment) report **"everything seems fine"** after each of the 3 task commits.
- No hardcoded hex/RGB colors introduced — all new uicontrol/uimenu styling uses `theme.ToolbarBackground` / `theme.ToolbarFontColor` only.
- `git diff --stat` across all 3 task commits confirms only `libs/Dashboard/DashboardLayout.m` changed (203 insertions, 3 deletions).

## Test flag (per plan requirement)

Grepped `tests/` for any assertion of a folded button's `Visible` property: **none found.** The single hit (`tests/test_create_event_dialog.m:8`) is an unrelated doc comment about a "hidden uipanel", not a `Visible` assertion on any of the five folded buttons. No test file was edited, per constraint.

## Deferred to the human orchestrator (no MATLAB tooling available to the executor)

- Live render of `example_dashboard_all_widgets` with `Theme='light'` — visual confirmation that the X/V/A/L/+ strip is gone, a single `...` sits left of Info/Detach, clicking `...` posts the menu, and each menu item performs its action correctly.
- The 7 must-pass suites: `tests/test_dashboard_widget_button_bar.m`, `tests/test_dashboard_layout_plant_log_toggle.m`, `tests/suite/TestDashboardDetach.m`, `tests/suite/TestDashboardWidget.m`, `tests/suite/TestInfoTooltip.m`, `tests/suite/TestDashboardLayoutPlantLogToggle.m`, `tests/suite/TestIndustrialPlantDemoCompanion.m`.

## Deviations from Plan

None — plan executed exactly as written. All three tasks implemented per spec; no Rule 1-4 deviations were needed.

## Known Stubs

None. The overflow menu is fully wired to real action methods (no placeholder/mock data paths).

## Threat Flags

None beyond what the plan's `<threat_model>` already covers (T-ikg-01/02/03 — all `mitigate`d via try/catch + idempotent cleanup, or explicitly `accept`ed as no new privilege).

## Self-Check

- [x] `libs/Dashboard/DashboardLayout.m` exists and contains all edits (confirmed via grep).
- [x] Commit `5345671a` (Task 1), `619ff9e3` (Task 2), `195637bc` (Task 3) all present in `git log`.
- [x] MISS_HIT clean after every task commit.

## Self-Check: PASSED
