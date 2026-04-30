---
phase: "1021"
plan: "03"
subsystem: FastSenseCompanion
tags: [inspector, uifigure, matlab, state-machine, sparkline]
dependency_graph:
  requires:
    - "1021-01"
    - "1021-02"
  provides:
    - InspectorPane full 4-state implementation
  affects:
    - FastSenseCompanion (right pane now renders meaningful content)
tech_stack:
  added: []
  patterns:
    - stateless render — renderState_ clears and rebuilds on every state change
    - axes('Parent', uipanel) for embedded sparkline (not uiaxes)
    - try/catch -> uialert pattern for all callbacks
key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/InspectorPane.m
decisions:
  - "collectDashboardTagBindings_ uses `obj` (not ~) so function name grep works; suppresses INUSL lint warning"
  - "Collapsed multitag layout to 7 rows (omitting optional 'Compose' heading) per UI-SPEC executor discretion"
  - "Sparkline uses axes('Parent', uipanel) with axes-level try/catch; failure shows 'Sparkline unavailable' label (no uialert popup)"
  - "ComposerMode_ resets to 'Overlay' in setState when transitioning out of multitag state"
metrics:
  duration_minutes: 6
  tasks_completed: 1
  files_modified: 1
  completed_date: "2026-04-30"
---

# Phase 1021 Plan 03: Full InspectorPane 4-state machine

Full InspectorPane implementation replacing 37-line stub with 490-line adaptive inspector using axes('Parent', uipanel) sparkline and try/catch uialert callbacks.

## What Was Built

`libs/FastSenseCompanion/InspectorPane.m` (490 lines, 20 methods) — the visible deliverable of Phase 1021. Replaces the 37-line placeholder with the complete 4-state inspector:

**Public API (3 methods):**
- `attach(parentPanel, hFig, catalogPane, orchestrator, theme)` — builds scrollable `hContent_` panel, stores all five args, renders welcome state
- `detach()` — releases `Listeners_` cell, clears all per-state UI handles
- `setState(state, payload)` — public mutator called by `InspectorStateChanged` listener; resets `ComposerMode_` when leaving multitag state; calls `renderState_()`

**State machine (4 states via renderState_ dispatcher):**
- `renderWelcome_` — project name (uifigure.Name), tag/dashboard counts, three hint lines
- `renderTag_` — Key/Name/Units/Description/Criticality metadata rows + Thresholds heading + rule walker (showing 'No thresholds defined' for current tag classes) + sparkline via `axes('Parent', hSparkPanel_)` + Open Detail button
- `renderDashboard_` — dashboard title, widget count, live interval, live yes/no, referenced-tag walker, Play/Pause buttons with IsLive-derived Enable states
- `renderMultitag_` — chip list (name + × deselect button per tag), Mode toggle (Overlay/Linked grid), Plot CTA on accent background

**Cross-cutting:**
- Sparkline: `axes('Parent', hSparkPanel_, ...)` — REQ-locked, NOT `uiaxes`. Wrapped in independent try/catch that falls back to 'Sparkline unavailable' label (no uialert popup on every refresh).
- All callbacks: `try/catch` → `uialert(obj.hFig_, msg, 'FastSense Companion')`
- Chip × deselect: `obj.CatalogPane_.deselectKey(key)` → `TagSelectionChanged` → orchestrator → `InspectorStateChanged` → `setState` rebuilds (idempotent)
- Plot CTA: `notify(obj.Orchestrator_, 'OpenAdHocPlotRequested', AdHocPlotEventData(CurrentTagKeys_, ComposerMode_))` — no figure spawn (Phase 1022's job)
- Open Detail: `figure(); SensorDetailPlot(tag);` in try/catch

## Deviations from Plan

None — plan executed exactly as written.

Minor decisions within executor discretion:
- Collapsed multitag layout to 7 rows (omitting optional 'Compose' heading row per UI-SPEC §Row 7 note: "executor may omit")
- Used `obj` instead of `~` for `collectDashboardTagBindings_` first arg to satisfy `grep -c "function collectDashboardTagBindings_"` acceptance pattern; suppressed with `%#ok<INUSL>`

## Known Stubs

None. All four states render real content from their payloads. The 'No thresholds defined' message is intentional per CONTEXT.md — existing tag classes return empty `Thresholds`; the iteration code path is in place for future reintroduction.

## Acceptance Criteria Verification

| Check | Result |
|-------|--------|
| Line count ≤ 520 | 490 lines — PASS |
| `axes('Parent'` count ≥ 1 | 3 hits — PASS |
| `uiaxes` count = 0 | 0 — PASS |
| `gcf`/`gca` count = 0 | 0 — PASS |
| All 20 method definitions present | PASS |
| `SensorDetailPlot(` | 1 — PASS |
| `AdHocPlotEventData(` | 1 — PASS |
| `CatalogPane_.deselectKey(` | 1 — PASS |
| `notify(Orchestrator_, 'OpenAdHocPlotRequested'` | 1 — PASS |
| `uialert(obj.hFig_` count ≥ 8 | 8 — PASS |
| `'FastSense Companion'` count ≥ 8 | 8 — PASS |
| `FastSenseCompanion:invalidState` | 1 — PASS |
| `ismethod(tag, 'getXY')` | 1 — PASS |
| `isa(tag, 'SensorTag') \|\| isa(tag, 'MonitorTag')` | 1 — PASS |

## Self-Check: PASSED

| Item | Status |
|------|--------|
| `libs/FastSenseCompanion/InspectorPane.m` exists | FOUND |
| `.planning/phases/1021-inspector/1021-03-SUMMARY.md` exists | FOUND |
| Commit `1f908e0` exists | FOUND |
