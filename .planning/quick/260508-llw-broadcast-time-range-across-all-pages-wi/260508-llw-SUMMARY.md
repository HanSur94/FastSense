---
phase: quick-260508-llw
plan: 01
subsystem: Dashboard / DashboardEngine time-control
tags: [dashboard, multi-page, time-sync, regression-fix]
dependency_graph:
  requires:
    - libs/Dashboard/DashboardEngine.m (allPageWidgets accessor)
    - libs/Dashboard/FastSenseWidget.m (UseGlobalTime guard, setTimeRange)
    - libs/Dashboard/GroupWidget.m (recursive setTimeRange)
  provides:
    - broadcastTimeRange / resetGlobalTime that apply to every page
    - LastSyncedTimeRange_ cache + switchPage re-broadcast hook
    - tests/test_dashboard_time_sync_all_pages.m
  affects:
    - Multi-page dashboards using time slider drag, "Sync all" button, programmatic broadcastTimeRangeNow
    - Live mode (LiveTimeRange path still uses activePageWidgets — see "Notes" below)
tech-stack:
  added: []
  patterns: [private-cache-on-broadcast, lazy-realize-then-reapply]
key-files:
  created:
    - tests/test_dashboard_time_sync_all_pages.m
  modified:
    - libs/Dashboard/DashboardEngine.m
    - .planning/STATE.md
decisions:
  - "Always re-broadcast on tab-switch when LastSyncedTimeRange_ is set (don't gate on hasUnrealized) — call is cheap and idempotent thanks to FastSenseWidget.setTimeRange's existing handle guards."
  - "Empty-cache guard prevents re-broadcasting an unset range, which would clobber widgets' construction xlim with []."
  - "Per-tab slider preview / event-marker iteration (computePreviewEnvelope, computeEventMarkers) intentionally remains active-page only — the user model there (260508-kov / 260508-l2k) is per-tab visualisation, distinct from the dashboard-wide control state for time sync."
metrics:
  duration: ~25 min
  completed: 2026-05-08
requirements: [LLW-01, LLW-02, LLW-03]
---

# Quick 260508-llw: Broadcast Time Range Across All Pages Summary

One-liner: `broadcastTimeRange` and `resetGlobalTime` now iterate `allPageWidgets()`, the last broadcast range is cached in a new private `LastSyncedTimeRange_` field, and `switchPage` re-applies that cache after `realizeBatch` so widgets realized lazily on tab-switch inherit the dashboard-wide synced window.

## Problem

On a multi-page dashboard, dragging the time slider, clicking "Sync all", or calling `broadcastTimeRangeNow` only updated widgets on the **currently active** tab. Switching to any other page revealed widgets at their original construction default xlim — breaking the user's mental model that the time window is a dashboard-wide control. Same bug applied to `resetGlobalTime`: pressing "Reset" left widgets on inactive pages still detached from global time.

## Changes

Three surgical edits to `libs/Dashboard/DashboardEngine.m` plus a new regression test.

### 1. `libs/Dashboard/DashboardEngine.m`

| Change | Location | What |
| ------ | -------- | ---- |
| New private property `LastSyncedTimeRange_ = []` | `properties (SetAccess = private)` block, ~L71 | Caches the most recent `[tStart tEnd]` broadcast so `switchPage` can reapply it. |
| `broadcastTimeRange` body | ~L1378 | Switched `activePageWidgets()` → `allPageWidgets()`; assigns `obj.LastSyncedTimeRange_ = [tStart tEnd]` at the top. Header now says "across ALL pages, not just active". |
| `resetGlobalTime` body | ~L1399 | Same `activePageWidgets()` → `allPageWidgets()` swap. Header updated. |
| `switchPage` body | ~L218 (after `realizeBatch(5)`, before `computePreviewEnvelope`) | New guarded re-broadcast block: when `LastSyncedTimeRange_` is non-empty, calls `obj.broadcastTimeRange(rng(1), rng(2))` so newly-realized widgets inherit the synced window. |

### 2. `tests/test_dashboard_time_sync_all_pages.m` (new, 233 lines)

Five Octave-style function sub-tests covering:

- `case_active_and_inactive_pages_receive_broadcast` (LLW-01): both pages' axes show the broadcast xlim, plus `LastSyncedTimeRange_` is populated.
- `case_reset_global_time_reattaches_all_pages` (LLW-02): `UseGlobalTime` flips back to true on widgets across both pages.
- `case_unrealized_widget_on_tab_switch_inherits_synced_range` (LLW-03): page-2 widget starts unrealized; broadcast on page 1; `switchPage(2)` realizes it AND its xlim equals the synced window (not its sensor default).
- `case_manual_zoom_widget_opts_out_of_broadcast`: pre-realize page 2, set `UseGlobalTime=false` on its widget, broadcast — page-1 widget follows; page-2 widget keeps its prior xlim. Confirms the per-widget detach contract is preserved.
- `case_single_page_dashboard_unaffected`: no `addPage` calls, two widgets in `obj.Widgets` directly — `allPageWidgets()` falls through and both widgets still receive the broadcast.

## Test Evidence

All four time-sync-adjacent test files pass (32 tests total, 0 failures):

| File | Result |
| ---- | ------ |
| `tests/test_dashboard_time_sync_all_pages.m` (new) | `5/5 tests passed.` |
| `tests/test_dashboard_preview_overlay.m` | `All 10 tests passed.` (per-tab preview NOT regressed) |
| `tests/test_dashboard_engine_event_markers.m` | `All 9 tests passed.` |
| `tests/suite/TestDashboardEngineEventMarkers.m` | `8 Passed, 0 Failed, 0 Incomplete.` |

`mh_lint libs/Dashboard/DashboardEngine.m` — `everything seems fine`.
`mh_lint tests/test_dashboard_time_sync_all_pages.m` — `everything seems fine`.

## Success Criteria — All Met

- `grep -n "obj.activePageWidgets()" libs/Dashboard/DashboardEngine.m | grep -E "broadcastTimeRange|resetGlobalTime"` returns ZERO matches. ✓
- `grep -n "LastSyncedTimeRange_" libs/Dashboard/DashboardEngine.m` returns 4 matches (declaration + write in `broadcastTimeRange` + 2 reads in `switchPage`). ✓
- `test_dashboard_time_sync_all_pages` exits 0 with `5/5 tests passed.` ✓
- `test_dashboard_preview_overlay` exits 0 with `All 10 tests passed.` (no regression on 260508-kov per-tab preview). ✓
- `mh_lint` produces no new errors on either file. ✓
- Doc headers on `broadcastTimeRange` and `resetGlobalTime` explicitly mention "across ALL pages, not just active". ✓

## Commits

| Hash | Subject |
| ---- | ------- |
| `d3478d2` | `fix(quick-260508-llw): broadcast time range across all pages, not just active (LLW-01, LLW-02)` |
| `0a478f6` | `fix(quick-260508-llw): re-broadcast cached time range from switchPage (LLW-03)` |
| `ed66ec5` | `test(quick-260508-llw): regression coverage for cross-page time sync` |

## Deviations from Plan

None of substance. One small interpretation choice worth noting:

- **Pre-realize page 2 in two of the test cases.** `case_active_and_inactive_pages_receive_broadcast` and `case_reset_global_time_reattaches_all_pages` need to assert against `Pages{2}.Widgets{1}.FastSenseObj.hAxes` and `UseGlobalTime` *before* a tab-switch. The plan's Test 1.2 wording suggests the assertion happens *after* `switchPage(2)`, which would conflate LLW-01 with LLW-03. To keep cases independent, both LLW-01 and LLW-02 cases pre-realize page 2 (switchPage(2) → switchPage(1)) before broadcasting. LLW-03 is then verified separately by `case_unrealized_widget_on_tab_switch_inherits_synced_range`, which preserves the lazy-realize precondition (asserts `~Pages{2}.Widgets{1}.Realized` before the broadcast). Result: each test exercises exactly one rule, and the LLW-03 case proves the realized-on-switch path that the plan's Test 1.2 alternative would have covered indirectly.

## Notes / Out of Scope

- **Live mode `updateLiveTimeRange` is intentionally NOT touched.** It still uses `activePageWidgets()` (~L1185, L1396, L1434, L1450). That's a separate code path that runs every live tick and pushes a moving window; broadcasting it across all pages on every tick has different semantics (cost, notion of "current time" per page) and is out of scope here. If needed, a follow-up quick task can evaluate whether live mode should also become dashboard-wide.
- **Per-tab slider PREVIEW visualization remains active-page only.** `computePreviewEnvelope` and `computeEventMarkers` were intentionally left untouched — those drive the slider's preview shading + event markers, and per 260508-kov / 260508-l2k the user model is "this preview reflects the active tab's data". This summary's contract: only the broadcast/reset *control state* went dashboard-wide, not the preview *visualisation*.
- **`setEventMarkersVisible`** already used `allPageWidgets()` (~L143) — no change needed there. Confirms `allPageWidgets()` is the established accessor for dashboard-wide control fan-out.

## Self-Check: PASSED

Verified via `git log --oneline` and `[ -f path ]` checks:

- `d3478d2` present in branch history. ✓
- `0a478f6` present in branch history. ✓
- `ed66ec5` present in branch history. ✓
- `tests/test_dashboard_time_sync_all_pages.m` exists. ✓
- `libs/Dashboard/DashboardEngine.m` modified (per `git diff HEAD~3 --name-only`). ✓
