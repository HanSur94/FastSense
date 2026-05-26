---
phase: quick-260508-jf1
plan: 01
subsystem: Dashboard
tags: [bug-fix, dashboard, stale-banner, multi-page, layout]
requires:
  - DashboardEngine.applyChromeVisibility (already exists)
  - DashboardEngine.PageBarHeight, hPageBar (already exist)
  - DashboardEngine.Toolbar.Height (already exists)
provides:
  - DashboardEngine.repositionStaleBanner_ (new private helper)
  - Banner positioned below both toolbar and page-tab strip
affects:
  - DashboardEngine.createStaleBanner (geometry only)
  - DashboardEngine.applyVisibilityAndRelayout (added one call)
  - DashboardEngine.onResize (added one call)
tech-stack:
  added: []
  patterns:
    - "Trailing-underscore private helper convention (matches StaleBannerDismissed_, Listeners_)"
    - "Effective-height parity with applyChromeVisibility (single source of truth for chrome geometry)"
key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - tests/test_dashboard_stale_banner.m
decisions:
  - "Banner stays a passive overlay; Layout.ContentArea is NOT shrunk for it. Widgets keep their full bounds whether the banner is visible or hidden."
  - "Helper placed adjacent to createStaleBanner (in the existing public methods block) for locality; trailing-underscore name signals private-helper intent."
  - "repositionStaleBanner_ called BEFORE rerenderWidgets() in applyVisibilityAndRelayout so banner Y still tracks chrome heights when widget rerender throws."
metrics:
  duration: "2m 39s"
  completed: "2026-05-08T12:06:12Z"
  tasks: 1
  files: 2
requirements:
  - JF1-01
---

# Phase quick-260508-jf1: Fix orange stale-data banner overlapping dashboard top tab strip — Summary

One-liner: Stale-data banner now sits below the multi-page tab strip (`y = 1 - toolbarH - effPageBarH - bannerH`) via a new `repositionStaleBanner_` helper invoked from `applyVisibilityAndRelayout` and `onResize`; tabs stay fully visible and clickable while the banner is up.

## What Changed

### `libs/Dashboard/DashboardEngine.m`

- **`createStaleBanner` (lines 1199-1234)** — Computes `effPageBarH = obj.PageBarHeight` when `numel(obj.Pages) > 1`, else `0`, and positions the banner at `y = 1 - toolbarH - effPageBarH - bannerH`. Header comment updated to call out the multi-page case. Single-page geometry is unchanged (`effPageBarH == 0`).
- **`repositionStaleBanner_` (lines 1252-1273)** — New private helper. Reads current `Toolbar.Height` and `Pages` count, recomputes the banner Y, and `set`s the banner Position. No-ops when `hStaleBanner` is empty/invalid (safe before render and after teardown). Never touches `Layout.ContentArea`.
- **`applyVisibilityAndRelayout` (line 1024)** — Added `obj.repositionStaleBanner_();` after the `Layout.ContentArea = ...` assignment and BEFORE the `try/rerenderWidgets/catch` so banner repositioning is independent of widget rerender success.
- **`onResize` (line 1563)** — Added `obj.repositionStaleBanner_();` after `obj.repositionPanels();` so the banner Y tracks figure-resize chrome-height changes.

`showStaleBanner`, `hideStaleBanner`, `onStaleBannerClose`, `applyChromeVisibility`, and `renderPageBar` are untouched. The `uistack(obj.hStaleBanner, 'top')` call in `showStaleBanner` stays — still useful for raising the banner above any widget panels in its strip.

### `tests/test_dashboard_stale_banner.m`

- **New scenario `testBannerBelowPageBarMultiPage`** appended before the final summary `fprintf`. Builds a 2-page dashboard with one widget, calls `showStaleBanner`, then asserts:
  - `bannerPos(2) + bannerPos(4) <= pageBarPos(2) + 1e-6` (banner top at-or-below page-bar bottom — no overlap).
  - `get(d.hPageBar, 'Visible') == 'on'` (page bar still visible).
  - `d.Layout.ContentArea` is byte-identical to its pre-`showStaleBanner` snapshot (overlay-only contract).

## New Helper Signature

```matlab
function repositionStaleBanner_(obj)
%REPOSITIONSTALEBANNER_ Recompute banner Y from current chrome heights.
%   Safe to call before render or after teardown — no-ops when the
%   banner handle is empty/invalid. Banner stays an overlay; this
%   never touches Layout.ContentArea.
```

No arguments beyond `obj`; no return value; private (trailing-underscore convention).

## Test Results

```
$ octave --no-gui --eval "addpath(pwd); install(); test_dashboard_stale_banner();"
    7 passed, 0 failed.
```

All seven scenarios pass:

1. `testBannerCreatedHidden`
2. `testShowListsStaleTitles`
3. `testShowCollapsesLongList`
4. `testDetectStaleWithFrozenSensor`
5. `testCloseButtonDismisses`
6. `testStopLiveHidesBannerAndClearsDismissal`
7. `testBannerBelowPageBarMultiPage` (new — multi-page banner-vs-tab-strip regression)

`tests/suite/TestDashboardMultiPage.m` was inspected; it asserts `hPageBar` Visible state but no banner geometry, so the change is contract-safe for that suite. (Octave does not provide `runtests` for class-based suites — the suite is MATLAB-only by project convention.)

## Layout.ContentArea Math: Untouched

The new test snapshots `d.Layout.ContentArea` immediately before `showStaleBanner` and asserts `isequal(d.Layout.ContentArea, caBefore)` after. This passes — confirming the banner is purely a passive overlay and widget bounds are not affected by banner visibility.

## Deviations from Plan

None. Plan executed exactly as written:

- `createStaleBanner` body updated with the prescribed `effPageBarH` calculation and `bannerY` formula.
- `repositionStaleBanner_` helper created with the exact prescribed body and placed adjacent to `createStaleBanner`.
- Both `applyVisibilityAndRelayout` and `onResize` invocation sites added.
- `showStaleBanner`, `hideStaleBanner`, `onStaleBannerClose`, `applyChromeVisibility`, and `renderPageBar` are untouched as required.
- New test scenario added in the prescribed try/catch + `nPassed`/`nFailed` style.

## Commits

- `66fbfbc` — `fix(quick-260508-jf1): stale-data banner sits below page-tab strip`

## Self-Check: PASSED

- `libs/Dashboard/DashboardEngine.m` modified — FOUND (3 references to `repositionStaleBanner_` at lines 1024, 1252, 1563).
- `tests/test_dashboard_stale_banner.m` modified — FOUND (new `testBannerBelowPageBarMultiPage` scenario; Octave run reports `7 passed, 0 failed.`).
- Commit `66fbfbc` exists in `claude/happy-ramanujan-7d436a` — FOUND.
- New test scenario passes — FOUND in run output above.
