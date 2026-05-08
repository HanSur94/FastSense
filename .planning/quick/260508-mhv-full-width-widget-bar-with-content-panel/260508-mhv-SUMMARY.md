---
phase: quick-260508-mhv
plan: 01
subsystem: Dashboard
tags: [dashboard-layout, widget-chrome, content-panel, regression-fix]
requires: []
provides:
  - "WidgetButtonBar restored as a full-width opaque header strip across the top of every chrome'd widget"
  - "WidgetContentPanel sub-panel hosts widget content BELOW the bar — titles/axes/status text never clipped"
  - "DashboardWidget.hCellPanel property exposes the outer grid-cell panel separately from hPanel"
  - "DashboardLayout.reflowChrome_ static handler resizes bar + content panel together on cell resize"
  - "DashboardLayout.createContentPanel_ private helper builds the content sub-panel"
  - "Backward-compat: DashboardLayout.reflowButtonBar_ kept as deprecated forwarding shim"
affects:
  - "Every chrome'd widget: TextWidget, NumberWidget, StatusWidget, MultiStatusWidget, ChipBarWidget, IconCardWidget, GaugeWidget, BarChartWidget, FastSenseWidget, TableWidget, HistogramWidget, ScatterWidget, HeatmapWidget, EventTimelineWidget, GroupWidget, RawAxesWidget"
  - "DividerWidget no-chrome path preserved (renders directly into cell, no bar, no content panel)"
  - "DetachedMirror lifecycle unchanged (renders cloned widget without chrome)"
  - "Multi-page tab visibility cascade — toggles hCellPanel so bar + content hide together"
  - "Edit-mode drag/resize math — reads outer cell position from hCellPanel"
tech-stack:
  added: []
  patterns:
    - "chrome-first realization: build bar + content sub-panel, THEN call widget.render(contentPanel)"
    - "outer-cell handle pattern: pin grid-cell panel as hCellPanel before render reassigns hPanel"
    - "hCellPanel-with-hPanel-fallback for visibility cascades and drag/resize coordinates"
key-files:
  modified:
    - libs/Dashboard/DashboardWidget.m
    - libs/Dashboard/DashboardLayout.m
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/DashboardBuilder.m
    - tests/test_dashboard_widget_button_bar.m
    - tests/test_dashboard_builder_interaction.m
  created:
    - .planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/260508-mhv-PLAN.md
    - .planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/260508-mhv-SUMMARY.md
    - .planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/deferred-items.md
decisions:
  - "Chrome built BEFORE widget.render (not after) so widget content renders into the visible area, not under the bar"
  - "Introduce hCellPanel as a sibling property to hPanel rather than overloading hPanel — keeps the widget-render contract (obj.hPanel = parentPanel) intact and avoids a breaking change for every concrete widget subclass"
  - "Visibility cascades, drag/resize math, and panel-deletion all use a hCellPanel-then-hPanel fallback so unrealized widgets and DetachedMirror's no-chrome path keep working unchanged"
  - "Reflow handler renamed reflowButtonBar_ -> reflowChrome_ because it now resizes BOTH the bar AND the content sub-panel; old name kept as deprecated forwarding shim for any external callers"
  - "DividerWidget (and any widget with no Description AND no DetachCallback) gets no chrome — renders directly into the outer cell as before"
metrics:
  duration: ~50min
  completed: 2026-05-08
requirements:
  - MHV-01
  - MHV-02
---

# Quick 260508-mhv: Restore Full-Width WidgetButtonBar with Content Sub-Panel

One-liner: Restore the full-width per-widget button bar that m52 had shrunk to a 64px right-anchored strip, and eliminate the underlying truncation bug by rendering all widget content into a dedicated `WidgetContentPanel` sub-panel positioned BELOW the bar.

## Problem

m52 fixed a visual regression (full-width bar overlaying widget titles) by shrinking the bar to 64px in the top-right corner — a side-step rather than a fix. The user explicitly asked for the full-width band restored ("nope.. it must be full widht..") while keeping all widget titles, axes, status text and group headers fully visible ("just make sure all widget info and displa si bwlow it and tehre is no truncation").

Root cause of the m52 truncation: `DashboardLayout.realizeWidget` called `widget.render(widget.hPanel)` first and THEN added the chrome on top — so the widget's own children (titles, axes, etc.) were drawn under the bar.

## Fix

Inverted the order: build the chrome **first**, render the widget into a content sub-panel **second**.

1. `DashboardLayout.realizeWidget` reordered:
   ```
   widget.hCellPanel = widget.hPanel        % pin the outer cell handle
   if needsBar:
       getOrCreateButtonBar_(widget)        % full-width bar lives on cell
       contentPanel = createContentPanel_(widget)
       widget.render(contentPanel)          % widget renders into sub-panel
       addInfoIcon / addDetachButton        % wire bar buttons
   else:
       widget.render(widget.hCellPanel)     % no-chrome path unchanged
   ```

2. `DashboardLayout.getOrCreateButtonBar_` formula reverted to full-width:
   ```matlab
   barW = max(1, pp(3) - 2 * inset);   % full width
   x    = inset;                        % left-anchored
   ```
   Bar parented to `widget.hCellPanel` (the outer cell), not `widget.hPanel` (which is now the content sub-panel after `widget.render` reassigns it).

3. `DashboardLayout.createContentPanel_` (new private helper): bottom-anchored full-width `WidgetContentPanel` uipanel sized to `(cellW, cellH - 28 - 2)` with `WidgetBackground` color. Idempotent — returns existing panel on re-call.

4. `DashboardLayout.reflowChrome_` (renamed from `reflowButtonBar_`): on cell resize, re-anchors both the bar (full width minus 2*inset) and the content sub-panel (full width, height = cellH - barH - inset). Backward-compat shim `reflowButtonBar_` forwards to the new name.

5. `DashboardWidget.hCellPanel` (new public property): the outer grid-cell uipanel. Set by `realizeWidget` BEFORE `widget.render` reassigns `hPanel`. Layout helpers (`getOrCreateButtonBar_`, `addInfoIcon`, `addDetachButton`, `reflowChrome_`) and external consumers (visibility toggle, drag/resize math, panel deletion) read from `hCellPanel` with `hPanel` fallback.

6. Cascading sites updated to use `hCellPanel`-then-`hPanel`:
   - `DashboardEngine` page-switch visibility toggle (line 196 — cascades hide bar + content together)
   - `DashboardBuilder.relayoutWidgets` (delete cascades to the cell)
   - `DashboardBuilder.createOverlays` / `onDragStart` / `onResizeStart` / `onMouseUp` (drag/resize math reads canvas-normalized position from cell)
   - `DashboardWidget.delete` (deleting cell reaps bar + content + widget children together)

## Test Contract Change

m52: bar Position(3) <= 64 AND right-anchored.
mhv: bar Position(3) ≈ panelWidth - 2*inset AND left-anchored AND `WidgetContentPanel` sub-panel exists below it AND DividerWidget gets no chrome.

The 5 sub-tests in `tests/test_dashboard_widget_button_bar.m`:

1. Bar full-width left-anchored after first render.
2. `WidgetContentPanel` exists, bottom-anchored, full-width, top edge ≤ bar bottom edge (no overlap).
3. Info + detach buttons fit inside the bar (preserved m52 invariant).
4. `DashboardLayout.reflowChrome_` keeps full-width bar + resizes content sub-panel after a cell resize.
5. `DividerWidget` gets NO `WidgetButtonBar` AND NO `WidgetContentPanel` — render-directly-into-cell preserved.

## Files

- **Modified:** `libs/Dashboard/DashboardWidget.m`
  - Added `hCellPanel = []` to public-set property block alongside `hPanel`; documented the post-mhv contract on both
  - Updated `delete(obj)` to prefer `hCellPanel` over `hPanel` so the chrome cascade is reaped together
- **Modified:** `libs/Dashboard/DashboardLayout.m`
  - `realizeWidget` reordered for chrome-first rendering with content sub-panel
  - `getOrCreateButtonBar_` reverted to full-width left-anchored geometry; reparented to `hCellPanel`
  - `createContentPanel_` new private helper
  - `reflowChrome_` new public Static handler (resizes bar + content together); `reflowButtonBar_` deprecated alias retained
- **Modified:** `libs/Dashboard/DashboardEngine.m`
  - Page-switch visibility toggle cascades on `hCellPanel`-then-`hPanel`
  - Pre-allocated non-active page hide path documented as still-correct (allocatePanels assigns cell to hPanel; hCellPanel still empty until realize)
- **Modified:** `libs/Dashboard/DashboardBuilder.m`
  - `relayoutWidgets`, `createOverlays`, `onDragStart`, `onResizeStart`, `onMouseUp` all use `hCellPanel`-then-`hPanel` fallback for canvas-normalized cell position math
- **Modified:** `tests/test_dashboard_widget_button_bar.m`
  - Rewrote 3 m52 sub-tests as 5 mhv sub-tests; updated reflow call to `reflowChrome_`
- **Modified:** `tests/test_dashboard_builder_interaction.m`
  - Added `getCellPanel_` helper; replaced 18 `get(widget.hPanel, 'Position')` reads with `get(getCellPanel_(widget), 'Position')` so drag/resize coordinates stay in canvas-normalized space
- **Created:** `.planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/260508-mhv-PLAN.md` (provided)
- **Created:** `.planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/260508-mhv-SUMMARY.md` (this file)
- **Created:** `.planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/deferred-items.md`

## Verification

TDD flow followed:

1. **RED** (commit `1f72132`): `test_dashboard_widget_button_bar` rewritten — 4/5 sub-tests fail as expected (bar width 64 != 770; WidgetContentPanel uipanel not found; reflow uses old name; hCellPanel property missing on DividerWidget).
2. **GREEN** (commit `6860bad`): full implementation — all 5 sub-tests pass.

Required regression sweep (per execution constraints):

| Test | Result |
|---|---|
| `tests/test_dashboard_widget_button_bar.m` (mhv-rewrite) | 5/5 passed |
| `tests/test_dashboard_preview_overlay.m` | 10/10 passed |
| `tests/test_dashboard_engine_event_markers.m` | 9/9 passed |
| `tests/test_dashboard_time_sync_all_pages.m` | 5/5 passed |
| `tests/suite/TestDashboardEngineEventMarkers.m` | 8/8 passed |
| `tests/test_dashboard_toolbar_buttons.m` | 4/4 passed |
| `tests/test_dashboard_multipage_render.m` | 6/6 passed |

Static analysis (`checkcode`) on `libs/Dashboard/DashboardLayout.m`: only pre-existing warnings (lines 106, 107, 135, 146 — all unrelated to mhv-touched regions). No new lint introduced.

## Commits

- `1f72132` — `test(quick-260508-mhv): rewrite WidgetButtonBar test for full-width + content-panel contract` (RED)
- `6860bad` — `feat(quick-260508-mhv): restore full-width WidgetButtonBar with content sub-panel below` (GREEN)

## Deviations from Plan

**1. [Rule 1 - Bug] Visibility cascade in DashboardEngine.switchPage**

- **Found during:** Cross-cutting code review before commit
- **Issue:** `DashboardEngine.switchPage` toggled `Visible` on `widget.hPanel`. Post-mhv, that handle points at the WidgetContentPanel sub-panel — toggling its visibility hides only the content, leaving the bar visible on the inactive page.
- **Fix:** Read `hCellPanel` first, fall back to `hPanel` for unrealized widgets. Toggle on the cell so bar + content + widget content all cascade together.
- **Files modified:** `libs/Dashboard/DashboardEngine.m`
- **Commit:** `6860bad`

**2. [Rule 1 - Bug] DashboardBuilder drag/resize coordinates**

- **Found during:** `test_dashboard_builder_interaction` regression sweep
- **Issue:** DashboardBuilder reads `widget.hPanel` Position to learn the canvas-normalized cell coordinates for drag/resize math. Post-mhv, `widget.hPanel` is the WidgetContentPanel (pixel units relative to cell) — drag/resize math becomes meaningless.
- **Fix:** Read from `hCellPanel` with `hPanel` fallback in `relayoutWidgets`, `createOverlays`, `onDragStart`, `onResizeStart`, `onMouseUp`. Updated test helper `getCellPanel_` in `test_dashboard_builder_interaction.m` to mirror the same pattern (18 call-site replacements).
- **Files modified:** `libs/Dashboard/DashboardBuilder.m`, `tests/test_dashboard_builder_interaction.m`
- **Commit:** `6860bad`

**3. [Rule 1 - Bug] DashboardWidget.delete cascade**

- **Found during:** Pre-commit review of widget lifecycle
- **Issue:** Widget destructor deleted only `hPanel` (now the content sub-panel) — the outer cell + bar would be left as orphans on the canvas.
- **Fix:** Prefer `hCellPanel` (cascades to bar + content + widget children); fall back to `hPanel` for DetachedMirror / unrealized / no-chrome paths.
- **Files modified:** `libs/Dashboard/DashboardWidget.m`
- **Commit:** `6860bad`

## Pre-existing Failures (Out of Scope)

`tests/test_dashboard_builder_interaction.m` has 5 of 23 sub-tests failing **both before and after mhv** — verified via stash-then-rerun against the pre-mhv baseline. The same failure set with identical error messages exists on baseline. mhv neither introduces nor fixes them. Tracked in `deferred-items.md`.

## Self-Check: PASSED

- File `libs/Dashboard/DashboardWidget.m`: FOUND (modified)
- File `libs/Dashboard/DashboardLayout.m`: FOUND (modified)
- File `libs/Dashboard/DashboardEngine.m`: FOUND (modified)
- File `libs/Dashboard/DashboardBuilder.m`: FOUND (modified)
- File `tests/test_dashboard_widget_button_bar.m`: FOUND (modified)
- File `tests/test_dashboard_builder_interaction.m`: FOUND (modified)
- Commit `1f72132` (RED test): FOUND
- Commit `6860bad` (GREEN fix): FOUND
- Test result: 5/5 + 10/10 + 9/9 + 5/5 + 8/8 + 4/4 + 6/6 = 47/47 across required regression sweep
