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
    - Suppress-leave via deterministic IsMirrored_ flag (one-shot, no wall-clock window); onLeaveExternal hides directly to avoid leave recursion
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
  - D-04: Suppress-hide crux — broadcast hook + deterministic IsMirrored_ suppress flag; ZERO new figure WBM closures; onLeaveExternal hides directly (no leave recursion)
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

**One-liner:** Per-page crosshair-link broadcast with a deterministic IsMirrored_ suppress flag: hovering any linked FastSenseWidget mirrors its data-x to all OTHER linked widgets' crosshairs via BroadcastFcn_ without adding new figure WBM closures.

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

**Solution:** Zero new figure-WBM closures. The broadcast rides on EXISTING per-crosshair `onMove`/`onLeave` calls, gated by a **deterministic `IsMirrored_` boolean** (NOT a wall-clock window — see "Orchestrator Verification & Fixes" for why the original tic-window was replaced):

1. `BroadcastFcn_` callback on HoverCrosshair, fired at the END of `onMove(xQuery)` only when not in `InBroadcast_` mode. The engine sets this to `@(x) engine.broadcastCrosshairX_(thisHc, x)`.
2. `broadcastCrosshairX_` loops active-page linked crosshairs and calls `peer.onMoveExternal(xQuery)` for each peer != source.
3. `onMoveExternal(x)` sets `IsMirrored_ = true` then calls `onMove(x)` with `InBroadcast_=true`. `onLeave()` early-returns whenever `IsMirrored_` is true. So when peer B's own `onFigureMove_` fires `onLeave()` in the same motion dispatch (cursor not over B), the guard swallows it and B's mirrored crosshair stays visible — regardless of how long the dispatch takes.
4. A REAL hover (`onMove` with `InBroadcast_=false`) clears `IsMirrored_` — the widget under the cursor becomes the link **source**.
5. When the cursor leaves ALL linked axes: the source's `onFigureMove_` fires its own `onLeave()`. The source has `IsMirrored_=false`, so it hides and, via `BroadcastLeaveFcn_`, calls `broadcastCrosshairLeave_` → `peer.onLeaveExternal()` on all peers. `onLeaveExternal` sets `IsMirrored_=false` and hides **directly** (it does NOT call `onLeave`, so peers never re-broadcast — no leave ping-pong).

**Key invariant:** there is always exactly one source (the last widget whose real `onMove` ran, `IsMirrored_=false`); on cursor-exit the source's `onLeave` always fires and broadcasts leave, clearing every peer. A mirrored peer (`IsMirrored_=true`) never hides on its own self-leave. This is timing-independent, so it cannot race the synchronous motion dispatch.

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

## Orchestrator Verification & Fixes

Live MATLAB verification (R2025a) found three issues in the executor's commits, all fixed in commit `260602-mri-04` (HoverCrosshair.m + test):

1. **Flaky time-window suppress (replaced).** The original `SuppressLeaveUntil_ = tic` / `toc < SuppressWindow_ (0.075s)` guard depends on wall-clock elapsed time *inside a synchronous motion dispatch*. The crux test failed in the full suite run (the window expired before the self-leave) yet passed in isolation (6.7ms) — i.e. genuinely flaky. Replaced with a deterministic `IsMirrored_` boolean (set by `onMoveExternal`, cleared when the widget becomes the hover source or via `onLeaveExternal`). Timing-independent; correct under every chained-dispatch ordering (verified by trace + the now-passing render-guarded tests).
2. **Latent infinite-recursion in the leave path (fixed).** The original `onLeaveExternal` cleared the suppress then called `onLeave()`, which re-broadcast leave → peer `onLeaveExternal` → `onLeave` → re-broadcast … an unbounded ping-pong that would hang MATLAB with ≥2 linked widgets. (The committed tests never hit it: the crux test has no peers, and the integration test died earlier on bug #3.) Fixed by having `onLeaveExternal` hide **directly** via a new private `hideGraphics_` helper — never re-entering the broadcasting `onLeave`.
3. **Two test-construction bugs (fixed).** `test_collect_linked_crosshairs_pure_enumeration` and `test_two_widget_mirror_integration` set `eng.Widgets = {...}`, but `DashboardEngine.Widgets` is `SetAccess=private`. Fixed: the enumeration test passes the cell list straight to `collectLinkedCrosshairs_` (it takes the list as a parameter); the integration test uses `eng.addWidget(w)` (which accepts pre-built widget handles).

## Test Results — ALL GREEN (MATLAB R2025a, live MCP)

| Test | Result |
|------|--------|
| `tests/test_fastsense_crosshair_link.m` (NEW) | **11/11 pass** (incl. deterministic suppress-leave crux + 2-widget mirror integration) |
| `tests/test_hover_crosshair.m` (regression — standalone hover) | **11/11 pass** |
| `tests/test_fastsense_widget_ylimit_modes.m` (regression — V/A/L) | **11/11 pass** |
| `tests/test_time_range_selector_reinstall_after_rerender.m` (regression — chained-WBM/egv-eu2 guard) | **pass** |
| `tests/test_dashboard_time_sync_all_pages.m` (regression — multi-page) | **5/5 pass** |
| MISS_HIT `mh_style` + `mh_lint` (all 6 files) | **clean** (everything seems fine) |
| MATLAB Code Analyzer | no new findings (5 pre-existing `%#ok<TRYNC>` stale-pragma infos, present on `main` baseline) |

**Live UI smoke (real rendered 2-widget dashboard, figure on screen):** `CrosshairLinkButton` ('X', 24×24) renders on each FastSenseWidget's grey WidgetButtonBar; clicking it flips `CrosshairLinked` and wires the engine link set; hovering one linked widget mirrors the crosshair + per-series datatip onto the other at the same x; cursor-leave hides both; unlinking a widget stops it broadcasting/receiving; a still-linked solo widget keeps its own hover crosshair. Octave: pure cases run; render-guarded cases skip (HoverCrosshair is MATLAB-only) — consistent with `test_hover_crosshair.m`.

## Self-Check: PASSED

All 6 files exist on disk. All 4 commits exist in git log:
- a495cbc9 Task 1: CrosshairLinked property + HoverCrosshair broadcast hook
- 635632e2 Task 2: DashboardEngine active-page link coordination
- 8950abd5 Task 3: Crosshair-link toggle button on WidgetButtonBar
- (260602-mri-04) Orchestrator fixes: deterministic IsMirrored_ suppress + leave-recursion fix + test-construction fixes
