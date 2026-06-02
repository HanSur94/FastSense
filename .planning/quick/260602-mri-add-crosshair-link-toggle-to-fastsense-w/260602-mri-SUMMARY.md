---
phase: 260602-mri
plan: 01
subsystem: Dashboard / FastSense
tags: [crosshair, link, widget-button-bar, hover, broadcast]
dependency_graph:
  requires: []
  provides:
    - CrosshairLinked property on FastSenseWidget (MRI-01)
    - HoverCrosshair broadcast hook + suppress-leave guard (MRI-02)
    - DashboardEngine active-page link coordination (MRI-03)
    - Crosshair-link 'X' toggle on WidgetButtonBar (MRI-04)
    - Backward-compat: default OFF, legacy JSON unchanged (MRI-05)
  affects:
    - libs/FastSense/HoverCrosshair.m
    - libs/Dashboard/FastSenseWidget.m
    - libs/Dashboard/DashboardEngine.m
    - libs/Dashboard/DashboardLayout.m
    - libs/Dashboard/DashboardWidget.m
tech_stack:
  added: []
  patterns:
    - Suppress-leave tic-guard (SuppressLeaveUntil_ + SuppressWindow_)
    - InBroadcast_ re-entrancy flag prevents peer re-broadcasting
    - collectLinkedCrosshairs_ pure enumeration helper (no side effects)
    - Duck-type via ismethod(widget,'setCrosshairLink') for WidgetButtonBar injection
    - Re-establish-after-rerender pattern (260512-eu2) for BroadcastFcn_ hooks
key_files:
  created:
    - tests/test_fastsense_crosshair_link.m
  modified:
    - libs/FastSense/HoverCrosshair.m (+78 lines)
    - libs/Dashboard/FastSenseWidget.m (+40 lines)
    - libs/Dashboard/DashboardEngine.m (+152 lines)
    - libs/Dashboard/DashboardLayout.m (+101 lines, -2 lines)
    - libs/Dashboard/DashboardWidget.m (+3 lines, -1 line)
decisions:
  - D-01: Link model SHARED SET — any widget with toggle ON both broadcasts AND receives
  - D-02: X mapping RAW DATA-X — data-x broadcast; each peer computes its own Y via computeYAtX_
  - D-03: Coordination owner DashboardEngine + per-widget flag (no new class)
  - D-04: Suppress-hide crux — broadcast hook + suppress-leave tic-guard; ZERO new figure WBM closures
  - D-05: Lifecycle — per-active-page scope; unlink-on-detach; re-prime after rerender/switchPage
  - D-06: Backward compat — default OFF, toStruct omits field when false, legacy JSON byte-identical
  - D-07: Button glyph ASCII 'X' (Octave-safe; matches existing V/A/L/i/^ ASCII glyphs)
metrics:
  duration: "~75 min"
  completed: "2026-06-02"
  tasks: 3
  files: 6
  loc_added: 748
  loc_removed: 3
---

# Phase 260602-mri Plan 01: Add Crosshair-Link Toggle to FastSenseWidget Summary

**One-liner:** Per-page crosshair-link broadcast with suppress-leave tic-guard: hovering any linked FastSenseWidget mirrors its data-x to all OTHER linked widgets' crosshairs via BroadcastFcn_ without adding new figure WBM closures.

## Tasks Completed

| Task | Name | Commit |
|------|------|--------|
| 1 | CrosshairLinked property + HoverCrosshair broadcast hook | a495cbc9 |
| 2 | DashboardEngine active-page link coordination | 635632e2 |
| 3 | Crosshair-link toggle button on WidgetButtonBar | 8950abd5 |

## Files Changed

| File | LOC Delta | Summary |
|------|-----------|---------|
| `tests/test_fastsense_crosshair_link.m` | +377 | New test file: 11 cases (6 PURE + 1 pure-engine enumeration + 2 render-guarded suppress-leave/broadcast-reentry + 2 render-guarded 2-widget integration) |
| `libs/Dashboard/DashboardEngine.m` | +152 | collectLinkedCrosshairs_, rewireCrosshairLinks_, broadcastCrosshairX_, broadcastCrosshairLeave_, onCrosshairLinkToggle; lifecycle hooks in rerenderWidgets/switchPage/detachWidget |
| `libs/Dashboard/DashboardLayout.m` | +101, -2 | addCrosshairLinkToggle, onCrosshairLinkTogglePressed_, reflowChrome_ CrosshairLinkButton re-anchor, duck-type injection in realizeWidget |
| `libs/FastSense/HoverCrosshair.m` | +78 | setBroadcastFcn, onMoveExternal, onLeaveExternal; suppress-leave guard in onLeave; BroadcastFcn_ tail in onMove; delete() nulls callbacks first |
| `libs/Dashboard/FastSenseWidget.m` | +40 | CrosshairLinked=false public property; setCrosshairLink(tf) setter; toStruct omit-when-false; fromStruct pre-render restore |
| `libs/Dashboard/DashboardWidget.m` | +3, -1 | CrosshairLinkButton added to clearPanelControls protectedTags |

## Suppress-Leave Mechanism Explanation

The core design challenge (D-04): the single dashboard-figure `WindowButtonMotionFcn` dispatches through a chain of every widget's `HoverCrosshair.onFigureMove_`. When the cursor is over widget A, A's handler resolves "inside" and fires `onMove(xQuery)`; B's handler resolves "outside" and fires `onLeave()` (hide). Without intervention, mirroring A's x onto B would be immediately undone by B's own `onLeave()` in the same dispatch cycle.

**Solution:** Zero new figure-WBM closures. The broadcast rides on EXISTING per-crosshair `onMove`/`onLeave` calls:

1. `BroadcastFcn_` callback on HoverCrosshair, fired at the END of `onMove(xQuery)` only when not in `InBroadcast_` mode. The engine sets this to `@(x) engine.broadcastCrosshairX_(thisHc, x)`.
2. `broadcastCrosshairX_` loops active-page linked crosshairs and calls `peer.onMoveExternal(xQuery)` for each peer != source.
3. `onMoveExternal(x)` sets `SuppressLeaveUntil_ = tic` then calls `onMove(x)` with `InBroadcast_=true`. `onLeave()` checks `toc(SuppressLeaveUntil_) < SuppressWindow_` (~0.075s, ~3*ThrottleSeconds) and early-returns while within the window. So when peer B's own `onFigureMove_` fires `onLeave()` in the same motion dispatch (cursor not over B), the guard swallows it and B's mirrored crosshair stays visible.
4. When the cursor leaves ALL linked axes: the source's `onFigureMove_` fires its own `onLeave()` (no suppress on the source — it was the hovered one), which hides the source crosshair and, via `BroadcastLeaveFcn_`, calls `broadcastCrosshairLeave_`. This calls `peer.onLeaveExternal()` on all peers, which clears `SuppressLeaveUntil_` and calls `onLeave()` directly — hiding the mirrored crosshairs.

**Key invariant:** Source has `SuppressLeaveUntil_` empty (it is the hovered one), so its `onLeave` runs hide + leave-broadcast. A peer being mirrored has `SuppressLeaveUntil_` set, so its own `onLeave` (fired by its own `onFigureMove_` later in the same dispatch) early-returns.

## Design Decisions

**D-01 — Link model SHARED SET.** Any widget with toggle ON both broadcasts on hover AND receives mirrors. No master/source role distinction.

**D-02 — X mapping RAW DATA-X.** Sensor dashboards share a time axis. `HoverCrosshair.onMove(xQuery)` already computes each line's Y via `computeYAtX_` (binary_search), so each mirrored widget shows ITS OWN series values at the shared x for free. No Y is transmitted.

**D-03 — Coordination owner DashboardEngine + per-widget flag (NO new class).** The link set is derived on demand from `FastSenseWidget.CrosshairLinked` over the flattened active-page widgets (`collectLinkedCrosshairs_`).

**D-04 — Suppress-hide crux.** See "Suppress-Leave Mechanism Explanation" above. Zero new WBM closures — matches the 260512-egv/260512-eu2 design constraint.

**D-05 — Lifecycle per-active-page.** `collectLinkedCrosshairs_` only walks `activePageWidgets()` so page-switch automatically scopes the link set. `rewireCrosshairLinks_` is called after `rerenderWidgets`, `switchPage`, and `detachWidget` to re-prime fresh HoverCrosshair_ handles (260512-eu2 lesson).

**D-06 — Backward compat default OFF.** `CrosshairLinked = false` by default. `toStruct` omits `crosshairLinked` when false. `fromStruct` assigns the raw property (no setter call that would touch graphics) so pre-render load is safe. Legacy serialized dashboards load unchanged with identical JSON.

**D-07 — Button glyph ASCII 'X'.** Octave-safe (no Unicode). Matches existing ASCII Info ('i') / Detach ('^') / V / A / L glyphs.

## Deferred Items

**DetachedMirror crosshair-link parity — OUT OF SCOPE.** A detached widget opens in its own standalone figure with a `FastSenseToolbar` (figure-level crosshair toggle), not a `WidgetButtonBar`. This matches the 260513-sfp precedent where V/A/L buttons are also absent on detached widgets. Implementing crosshair-link on DetachedMirror would require wiring the detached figure's toolbar to the engine's active-page link set, which is a separate effort.

## Test Results

**PENDING — orchestrator live-MATLAB run.**

Tests to run:
- `mcp__matlab__run_matlab_test_file tests/test_fastsense_crosshair_link.m` (11 cases — expect all pass)
- Regression: `tests/test_fastsense_widget_ylimit_modes.m` (V/A/L unchanged)
- Regression: `tests/test_hover_crosshair.m` (standalone hover unchanged)
- Regression: `tests/test_time_range_selector_reinstall_after_rerender.m` (the 260512-egv/eu2 chained-WBM guard — proves no dangling-closure regression)
- Regression: `tests/test_dashboard_time_sync_all_pages.m` (multi-page sweep)
- MISS_HIT: `mh_style` + `mh_lint` on all 6 files + new test

## Self-Check: PASSED

All 6 files exist on disk. All 3 commits exist in git log:
- a495cbc9 Task 1: CrosshairLinked property + HoverCrosshair broadcast hook
- 635632e2 Task 2: DashboardEngine active-page link coordination
- 8950abd5 Task 3: Crosshair-link toggle button on WidgetButtonBar
