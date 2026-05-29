---
phase: 03-widget-info-tooltips
plan: "01"
subsystem: Dashboard
tags: [tdd, ui, tooltip, popup, matlab-uicontrol]
dependency_graph:
  requires: []
  provides: [InfoIconButton-injection, InfoPopupPanel, popup-dismiss-escape, popup-dismiss-click]
  affects: [libs/Dashboard/DashboardLayout.m]
tech_stack:
  added: []
  patterns: [uicontrol-pushbutton-icon, uipanel-popup-overlay, figure-callback-save-restore]
key_files:
  created:
    - tests/suite/TestInfoTooltip.m
  modified:
    - libs/Dashboard/DashboardLayout.m
decisions:
  - "Made openInfoPopup/closeInfoPopup/onKeyPressForDismiss/onFigureClickForDismiss public (not private) so tests can call them directly without workarounds"
  - "hFigure and hInfoPopup are public properties so tests can inject figure handle and read popup state"
  - "closeInfoPopup guards callback restore with wasOpen flag to prevent overwriting prior callbacks during the initial closeInfoPopup call inside openInfoPopup"
metrics:
  duration: "6 minutes"
  completed_date: "2026-04-01"
  tasks_completed: 2
  files_changed: 2
---

# Phase 03 Plan 01: Info Icon Injection + Popup (TDD RED/GREEN) Summary

**One-liner:** Per-widget info icon (uicontrol pushbutton tagged InfoIconButton) injected via realizeWidget() with click-to-open InfoPopupPanel showing Description text, dismissable via Escape key or click-outside.

## Tasks Completed

| # | Name | Commit | Files |
|---|------|--------|-------|
| 1 | Write TestInfoTooltip test scaffold (RED) | 4dd85bd | tests/suite/TestInfoTooltip.m |
| 2 | Implement DashboardLayout info icon + popup (GREEN) | 5e557f1 | libs/Dashboard/DashboardLayout.m |

## What Was Built

**TestInfoTooltip.m** — 11 test methods covering:
- INFO-01: icon appears when Description is non-empty
- INFO-02: icon absent when Description is empty
- INFO-03: popup panel created by openInfoPopup
- INFO-04: popup edit control shows Description text
- INFO-05: escape key dismissal, callback restore after close

**DashboardLayout.m additions:**
- 2 public properties: `hFigure` (figure handle for dismiss wiring), `hInfoPopup` (active popup handle)
- 2 private properties: `PrevButtonDownFcn`, `PrevKeyPressFcn` (saved callbacks)
- `allocatePanels()`: stores `obj.hFigure = hFigure` for later popup use
- `realizeWidget()`: calls `addInfoIcon(widget)` when `Description` is non-empty
- `addInfoIcon()` (private): creates pushbutton with Tag='InfoIconButton', callback to openInfoPopup
- `openInfoPopup()` (public): creates InfoPopupPanel with edit control + Close button, saves/wires figure callbacks
- `closeInfoPopup()` (public): deletes popup, restores prior figure callbacks (guarded by `wasOpen`)
- `onFigureClickForDismiss()` (public): walks ancestor chain to check click location
- `onKeyPressForDismiss()` (public): dismisses on 'escape' key

## Test Results

- TestInfoTooltip: 11/11 passed (GREEN)
- TestDashboardLayout: 8/8 passed (no regressions)
- TestDashboardEngine: 7/8 passed — 1 pre-existing failure (`testTimerContinuesAfterError` uses `isrunning()` which is undefined for timer in this MATLAB version; confirmed pre-existing before our changes)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] closeInfoPopup overwrote prior callbacks when called at start of openInfoPopup**
- **Found during:** Task 2 (GREEN testing)
- **Issue:** `openInfoPopup` calls `closeInfoPopup()` first as a guard. But `closeInfoPopup` was unconditionally restoring `PrevButtonDownFcn`/`PrevKeyPressFcn` (both `[]` initially), overwriting the sentinel callbacks already set on hFigure. The popup then saved the (now empty) callbacks as its "prior" state.
- **Fix:** Added `wasOpen` local variable: `wasOpen = ~isempty(obj.hInfoPopup) && ishandle(obj.hInfoPopup)`. Only restore figure callbacks when `wasOpen` is true.
- **Files modified:** libs/Dashboard/DashboardLayout.m
- **Commit:** 5e557f1

**2. [Rule 2 - Missing critical functionality] Info popup methods need public access for testability**
- **Found during:** Task 2 design
- **Issue:** Plan specified `methods (Access = private)` for all popup methods, but tests call `layout.openInfoPopup()`, `layout.onKeyPressForDismiss()` etc. directly.
- **Fix:** Moved `openInfoPopup`, `closeInfoPopup`, `onFigureClickForDismiss`, `onKeyPressForDismiss` to `methods (Access = public)`. Kept `addInfoIcon` and `onScrollWheel` private.
- **Files modified:** libs/Dashboard/DashboardLayout.m
- **Commit:** 5e557f1

## Known Stubs

None. All functionality is fully wired.

## Self-Check: PASSED
