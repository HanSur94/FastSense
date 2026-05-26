---
phase: quick-260508-jyh
plan: 01
subsystem: Dashboard
tags: [bug-fix, dashboard, stale-banner, layout, reserved-strip]
requires:
  - DashboardEngine.applyChromeVisibility (already exists)
  - DashboardEngine.PageBarHeight, hPageBar (already exist)
  - DashboardEngine.Toolbar.Height (already exists)
provides:
  - DashboardEngine.BannerHeight public property (default 0.035)
  - Permanent reserved banner strip at the figure top
  - Toolbar / page-bar / content-area all shifted down by BannerHeight
affects:
  - DashboardEngine.render (content-area + hidden-pagebar Y)
  - DashboardEngine.applyVisibilityAndRelayout (content-area formula)
  - DashboardEngine.createStaleBanner (banner Y = 1 - BannerHeight)
  - DashboardEngine.repositionStaleBanner_ (simplified — constant Y)
  - DashboardEngine.renderPageBar (page-bar Y)
  - DashboardToolbar constructor (hPanel Y)
  - DashboardToolbar.getContentArea
tech-stack:
  added: []
  patterns:
    - "Single-source-of-truth public property for chrome geometry (BannerHeight mirrors PageBarHeight / TimePanelHeight)."
    - "Reserved-strip layout — banner is no longer an overlay; its space is permanently allocated regardless of Visible state."
    - "Chrome cross-reading via Engine handle (DashboardToolbar reads obj.Engine.BannerHeight in getContentArea, constructor reads engine.BannerHeight)."
key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/DashboardToolbar.m
    - tests/test_dashboard_stale_banner.m
decisions:
  - "BannerHeight = 0.035 lifted into a public property as the single source of truth; matches the literal previously hard-coded in createStaleBanner."
  - "Banner is no longer an overlay — Layout.ContentArea is shrunk by BannerHeight permanently. This guarantees the banner can never overlap toolbar, page tabs, or any widget."
  - "createStaleBanner keeps its (theme, toolbarH) signature for backward compatibility; toolbarH is now unused inside the body but tagged %#ok<INUSD> so the linter stays quiet."
  - "DashboardBuilder.m chrome-geometry calls (lines 323/368/551-558) are intentionally untouched per plan scope — the Builder does not host the stale banner. Recorded as out-of-scope; see Deferred Issues."
metrics:
  duration: "~6m"
  completed: "2026-05-08T11:35:00Z"
  tasks: 1
  files: 3
requirements:
  - JYH-01
---

# Phase quick-260508-jyh: Reserve permanent top strip for stale-data banner — Summary

One-liner: Stale-data banner now lives in a permanent reserved strip at the figure top (`y = 1 - BannerHeight`); `DashboardEngine.BannerHeight = 0.035` is the single source of truth, and toolbar / page-bar / content-area all shift down by `BannerHeight` so the banner is never an overlay and toggling visibility no longer shifts any other chrome.

## What Changed

### `libs/Dashboard/DashboardEngine.m`

- **`properties (Access = public)` (~L23-37)** — Added `BannerHeight = 0.035` with a header comment explaining it is the reserved top strip and that toolbar / page-bar / content-area all shift down by it. PascalCase per project convention; mirrors `PageBarHeight` and `TimePanelHeight`.
- **`render` (~L317-340)** — Hidden-PageBar placeholder Y is now `1 - obj.BannerHeight - toolbarH - obj.PageBarHeight`. Content area is `[0, effTimeH, 1, 1 - obj.BannerHeight - effToolbarH - effPageBarH - effTimeH]` so the reserved strip is allocated up front, regardless of banner visibility.
- **`applyVisibilityAndRelayout` (~L1019-1029)** — Content-area formula updated to match `render` (single shared formula). `obj.repositionStaleBanner_();` call retained as defence-in-depth even though the body is geometry-stable now.
- **`createStaleBanner` (~L1202-1248)** — Header rewritten to call out the reserved-strip model. Body computes `bannerH = obj.BannerHeight` and `bannerY = 1 - bannerH`; the `effPageBarH` calculation and the dependency on `toolbarH` were removed. The `toolbarH` parameter was kept for signature compatibility (tagged `%#ok<INUSD>`) so existing callers continue to work.
- **`repositionStaleBanner_` (~L1252-1262)** — Simplified to a single `set` writing `[0, 1 - obj.BannerHeight, 1, obj.BannerHeight]`. No more reads of `Toolbar.Height` or `numel(obj.Pages)`. Header comment updated.
- **`renderPageBar` (~L1735-1743)** — Page-bar Y now subtracts `obj.BannerHeight` so the page-tab strip sits directly below the toolbar rather than at the figure top.

### `libs/Dashboard/DashboardToolbar.m`

- **Constructor (`DashboardToolbar`, ~L36-42)** — `hPanel` Y is now `1 - engine.BannerHeight - obj.Height` so the toolbar sits directly below the reserved banner strip. Reads `BannerHeight` from the constructor's `engine` argument; no signature change.
- **`getContentArea` (~L296-307)** — Subtracts `obj.Engine.BannerHeight` from the height term so the content area calculation stays in lockstep with the engine's inline formula. Header expanded.

### `tests/test_dashboard_stale_banner.m`

Three scenario changes (1 renamed + updated, 2 new); the existing 6 scenarios are unmodified and still pass.

- **`testBannerInReservedStripAboveAllChrome`** (renamed from `testBannerBelowPageBarMultiPage`) — 2-page dashboard. Asserts:
  - `bannerPos(2) ≈ 1 - d.BannerHeight` (banner Y in the reserved strip).
  - banner top ≈ 1.0.
  - `bannerPos(2) >= toolbarTop` (banner ABOVE toolbar).
  - `toolbarTop ≈ 1 - d.BannerHeight` and `toolbarBot ≈ 1 - d.BannerHeight - d.Toolbar.Height`.
  - `pageBarTop <= toolbarBot` (page-bar below toolbar).
  - `ca(2) + ca(4) <= 1 - d.BannerHeight` (content area never extends into reserved strip).
  - `isequal(d.Layout.ContentArea, caBefore)` (banner visibility doesn't change content area).
  - Page bar still `Visible='on'`.
- **`testReservedStripStableWhenHidden`** (new) — single-page dashboard. Snapshots toolbar / page-bar / content-area positions while hidden; calls `showStaleBanner` then `hideStaleBanner`; asserts every snapshot is byte-identical (`isequal`) afterwards. Also asserts the hidden banner panel is parked at exactly `[0, 1 - d.BannerHeight, 1, d.BannerHeight]`.
- **`testBannerHeightProperty`** (new) — asserts `isprop(d, 'BannerHeight')`, default `0.035`, and bounds `(0, 0.1)`.

## API Surface

```matlab
% New public property:
DashboardEngine.BannerHeight  % default 0.035 (normalized units)
```

`DashboardToolbar` and `DashboardEngine` constructors are unchanged. `createStaleBanner(theme, toolbarH)` keeps its existing signature even though `toolbarH` is no longer consumed in the body.

## Test Results

```
$ octave --no-gui --eval "addpath(pwd); install(); test_dashboard_stale_banner();"
    9 passed, 0 failed.
```

Nine scenarios pass:

1. `testBannerCreatedHidden` (existing, unchanged)
2. `testShowListsStaleTitles` (existing, unchanged)
3. `testShowCollapsesLongList` (existing, unchanged)
4. `testDetectStaleWithFrozenSensor` (existing, unchanged)
5. `testCloseButtonDismisses` (existing, unchanged)
6. `testStopLiveHidesBannerAndClearsDismissal` (existing, unchanged)
7. `testBannerInReservedStripAboveAllChrome` (renamed + stronger assertions)
8. `testReservedStripStableWhenHidden` (new)
9. `testBannerHeightProperty` (new)

`grep -rn "1 - toolbarH\|hStaleBanner\|PageBarHeight\|Toolbar.Height" tests/` showed `test_dashboard_stale_banner.m` is the only test that reads chrome geometry; nothing else needed updating. `tests/suite/TestDashboardMultiPage.m`, `TestToolbar.m`, and `TestDashboardToolbarImageExport.m` do not pin chrome Y values and are contract-safe.

## Deviations from Plan

None of substance. The plan was executed as written. Two notes:

- **`createStaleBanner` parameter** — the unused `toolbarH` parameter was tagged `%#ok<INUSD>` so the Octave/MISS_HIT linters stay quiet about an unused arg. The plan said to keep the parameter; this annotation is a small implementation detail consistent with project conventions.
- **TDD execution** — the plan listed `tdd="true"`; I followed RED → GREEN. RED commit (`2e333cd`) added the three failing scenarios first; running the suite produced `6 passed, 3 failed` (`subsref: unknown method or property: BannerHeight`). GREEN commit (`bdf1dc5`) implemented the engine + toolbar changes; the same suite then produced `9 passed, 0 failed`.

## Deferred Issues

- **`libs/Dashboard/DashboardBuilder.m` (lines 323, 368, 551-558)** — The dashboard authoring tool computes its palette / canvas geometry from `obj.Engine.Toolbar.Height` without subtracting the new `BannerHeight`. The Builder does not host the stale-data banner (no `hStaleBanner` is ever created on a Builder figure), so this does not break the builder UI in practice — but for symmetry, a follow-up task could subtract `obj.Engine.BannerHeight` from those formulas. Out of scope for this plan per the explicit `files_modified` list and "DO NOT modify applyChromeVisibility" guidance.

## Commits

- `2e333cd` — `test(quick-260508-jyh): add failing tests for reserved banner strip` (RED)
- `bdf1dc5` — `feat(quick-260508-jyh): reserve permanent top strip for stale-data banner` (GREEN)

## Self-Check: PASSED

- `libs/Dashboard/DashboardEngine.m` modified — FOUND (`BannerHeight = 0.035` declared at L37; `obj.BannerHeight` referenced at content-area calcs, hidden-pagebar Y, banner Y, repositionStaleBanner_, renderPageBar).
- `libs/Dashboard/DashboardToolbar.m` modified — FOUND (`engine.BannerHeight` in constructor hPanel Y; `obj.Engine.BannerHeight` in `getContentArea`).
- `tests/test_dashboard_stale_banner.m` modified — FOUND (`testBannerInReservedStripAboveAllChrome`, `testReservedStripStableWhenHidden`, `testBannerHeightProperty` all present; final summary fprintf reports `9 passed, 0 failed.`).
- Commits `2e333cd` and `bdf1dc5` exist on `claude/happy-ramanujan-7d436a` — FOUND.
- Octave test run reports `9 passed, 0 failed.` — FOUND in run output above.
