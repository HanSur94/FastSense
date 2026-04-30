---
phase: "1021"
plan: "02"
subsystem: FastSenseCompanion
tags: [inspector, events, orchestrator, wiring, tagcatalog]
dependency_graph:
  requires: [1021-01]
  provides: [InspectorStateChanged-event, OpenAdHocPlotRequested-event, TagCatalogPane-getSelectedKeys, TagCatalogPane-deselectKey, resolveInspectorState-wiring]
  affects: [FastSenseCompanion, TagCatalogPane, InspectorPane]
tech_stack:
  added: []
  patterns: [event-driven-state-machine, listener-wiring, boolean-mask-cellstr-ordering]
key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/TagCatalogPane.m
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - libs/FastSenseCompanion/InspectorPane.m
decisions:
  - Used boolean mask (~strcmp) for deselectKey instead of setdiff() to preserve cellstr ordering
  - InspectorPane.attach extended to accept 5 args with stub setState() to unblock Plan 03 implementation
  - removeDashboard wasSelected branch replaced detach+reattach with resolveInspectorState_() to avoid listener teardown mid-flow
metrics:
  duration_minutes: 10
  completed_date: "2026-04-30"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
requirements:
  - INSPECT-01
  - INSPECT-04
  - INSPECT-05
  - INSPECT-06
---

# Phase 1021 Plan 02: Orchestrator Wiring + TagCatalogPane Public API Summary

**One-liner:** Inspector state machine wiring — `InspectorStateChanged`/`OpenAdHocPlotRequested` events declared, `resolveInspectorState_()` added, `TagCatalogPane.getSelectedKeys`/`deselectKey` implemented, all selection events routed through single notify point.

## What Was Built

### Task 1: TagCatalogPane new public methods

Two new public methods added to `libs/FastSenseCompanion/TagCatalogPane.m` (additive, no existing behavior changed):

**`getSelectedKeys()`** — Returns `obj.SelectedKeys_` as a cellstr. Used by the orchestrator's `TagSelectionChanged` listener (the event itself carries no payload, so the orchestrator must query the pane).

**`deselectKey(key)`** — Removes a single key from `SelectedKeys_` using a boolean mask `(~strcmp(obj.SelectedKeys_, key))` (preserves ordering, avoids `setdiff` lexicographic sort side-effect), calls `applyFilter_()` to refresh the listbox value, then fires `TagSelectionChanged`. Wrapped in try/catch with uialert fallback; throws `FastSenseCompanion:invalidArgument` on non-char input.

Commit: `ea2ed5d`

### Task 2: FastSenseCompanion orchestrator — events, cache, wiring, extended attach

Changes applied to `libs/FastSenseCompanion/FastSenseCompanion.m`:

- **Events block** declared at class scope: `InspectorStateChanged` and `OpenAdHocPlotRequested`
- **`SelectedTagKeys_`** private property (`= {}`) added after `LastInteraction_`
- **Constructor** InspectorPane attach call extended to `attach(hRightPanel_, hFig_, CatalogPane_, obj, Theme_)` + two new listeners wired: `TagSelectionChanged` and `InspectorStateChanged`
- **`setProject`** mirrored the same attach extension, new listeners, and resets `SelectedTagKeys_ = {}`
- **`onDashboardSelected_`** updated to call `resolveInspectorState_()` after state update
- **`onOpenDashboardRequested_`** updated to call `resolveInspectorState_()` after state update
- **`onTagSelectionChanged_`** (new) — reads `CatalogPane_.getSelectedKeys()`, sets `LastInteraction_='tags'`, calls `resolveInspectorState_()`
- **`resolveInspectorState_`** (new) — delegates to `inspectorResolveState` helper (Plan 01), constructs `InspectorStateEventData`, fires `notify(obj, 'InspectorStateChanged', ed)`
- **`removeDashboard`** `wasSelected` branch replaced: no longer detaches/reattaches inspector — instead calls `resolveInspectorState_()` which fires `InspectorStateChanged` and lets the event-driven inspector update itself
- **Class header comment** updated with Events fired section

Changes applied to `libs/FastSenseCompanion/InspectorPane.m`:

- `attach` signature extended to `(obj, parentPanel, hFig, catalogPane, orchestrator, theme)` — extra args accepted but ignored (Plan 03 will fully implement)
- `setState(obj, state, payload)` stub added — empty method body, used by the `InspectorStateChanged` listener bound in Plan 02; Plan 03 implements the actual render dispatch

Commit: `f207f17`

## Verification Results

| Check | Result |
|-------|--------|
| `getSelectedKeys` in TagCatalogPane | 1 hit |
| `deselectKey` in TagCatalogPane | 1 hit |
| `notify(obj, 'TagSelectionChanged')` count | 2 (existing + new) |
| `events` block in FastSenseCompanion | 1 hit |
| `InspectorStateChanged` in events block | 1 hit |
| `OpenAdHocPlotRequested` in events block | 1 hit |
| `SelectedTagKeys_` occurrences | 4 |
| `onTagSelectionChanged_` function | 1 hit |
| `resolveInspectorState_` function | 1 hit |
| `getSelectedKeys()` call in orchestrator | 1 hit |
| `inspectorResolveState(` call | 1 hit |
| `InspectorStateEventData(` call (code) | 1 hit |
| `attach(hRightPanel_, hFig_, CatalogPane_, obj, Theme_)` | 2 hits (constructor + setProject) |
| `addlistener(CatalogPane_, 'TagSelectionChanged'` | 2 hits |
| `addlistener(obj, 'InspectorStateChanged'` | 2 hits |
| `obj.resolveInspectorState_()` calls | 4 (onDashboardSelected_, onOpenDashboardRequested_, onTagSelectionChanged_, removeDashboard) |
| gcf/gca/uiaxes hits | 0 |
| TagCatalogPane line count | 409 (≤520) |
| FastSenseCompanion line count | 416 (≤520) |

## Deviations from Plan

### Auto-added functionality

**1. [Rule 2 - Missing Critical] InspectorPane.attach signature + setState() stub**
- **Found during:** Task 2 — the plan instructs updating both attach call sites in the orchestrator to `attach(parentPanel, hFig, catalogPane, orchestrator, theme)`, but the existing `InspectorPane.m` only had `attach(obj, parentPanel)` with 1 arg.
- **Issue:** MATLAB would throw a "too many input arguments" error when the orchestrator called the extended attach signature against the old stub.
- **Fix:** Extended `InspectorPane.attach` to accept all 5 args (stored to stubs, Plan 03 wires them). Added `setState(obj, state, payload)` stub so the `InspectorStateChanged` listener bound in the constructor does not fail with "method not found" between Plan 02 and Plan 03.
- **Files modified:** `libs/FastSenseCompanion/InspectorPane.m`
- **Commit:** `f207f17`

## Known Stubs

- `InspectorPane.setState()` — empty body; Plan 03 will replace `InspectorPane` entirely with the four-state render implementation. Wired via listener in Plan 02; silently does nothing until Plan 03 ships.
- `InspectorPane.attach()` extra args (`hFig`, `catalogPane`, `orchestrator`, `theme`) — accepted but not stored; Plan 03 will store them in private properties and use them.

## Self-Check: PASSED

- FOUND: libs/FastSenseCompanion/TagCatalogPane.m
- FOUND: libs/FastSenseCompanion/FastSenseCompanion.m
- FOUND: libs/FastSenseCompanion/InspectorPane.m
- FOUND: .planning/phases/1021-inspector/1021-02-SUMMARY.md
- FOUND: commit ea2ed5d (Task 1)
- FOUND: commit f207f17 (Task 2)
