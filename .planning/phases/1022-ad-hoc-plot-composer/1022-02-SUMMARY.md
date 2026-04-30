---
phase: 1022-ad-hoc-plot-composer
plan: "02"
subsystem: FastSenseCompanion
tags: [matlab, uifigure, event-listener, ad-hoc-plot, lifecycle-independence]
dependency_graph:
  requires:
    - 1022-01   # openAdHocPlot helper (private/openAdHocPlot.m)
    - 1021      # OpenAdHocPlotRequested event declaration + AdHocPlotEventData
  provides:
    - FastSenseCompanion.onOpenAdHocPlotRequested_ method (resolves keys, delegates to helper)
    - Listener wired in constructor + setProject (end-to-end Plot CTA flow active)
  affects:
    - libs/FastSenseCompanion/FastSenseCompanion.m
tech_stack:
  added: []
  patterns:
    - MATLAB addlistener on self event (orchestrator subscribes to own event)
    - try/catch + uialert non-blocking error surface (Phase 1018 cross-cutting constraint)
    - Partial-success path: figure spawns + warning uialert lists skipped tags
    - Lifecycle independence: companion discards spawned figure handle (ADHOC-04)
key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m
decisions:
  - "TagRegistry.get(key) confirmed as the static lookup method (verified in TagRegistry.m line 47); called via obj.Registry_.get(key) (MATLAB allows static dispatch via instance)"
  - "Spawned figure handle discarded via [~, skipped] = openAdHocPlot(...) — intentional; companion never tracks spawned figures (ADHOC-04)"
  - "isvalid(obj.hFig_) guard inside catch block required — catch may fire during teardown after hFig_ is already deleted"
  - "Partial-success surfaced via uialert with Icon=warning while leaving figure visible; hard-failure surfaced via uialert with Icon=error"
metrics:
  duration: "< 5 minutes"
  completed_date: "2026-04-30"
  tasks_completed: 1
  tasks_total: 1
  files_modified: 1
requirements:
  - ADHOC-01
  - ADHOC-02
  - ADHOC-03
  - ADHOC-04
---

# Phase 1022 Plan 02: Wire OpenAdHocPlotRequested Listener Summary

**One-liner:** Wired `FastSenseCompanion.onOpenAdHocPlotRequested_` listener that resolves tag keys via `TagRegistry.get`, delegates to `openAdHocPlot(tags, mode, obj.Theme)`, and surfaces partial/full failures via non-blocking `uialert` while keeping spawned figures lifecycle-independent.

## Tasks Completed

| Task | Name | Commit | Files Modified |
|------|------|--------|----------------|
| 1 | Add onOpenAdHocPlotRequested_ private method to FastSenseCompanion | c1d3f25 | libs/FastSenseCompanion/FastSenseCompanion.m |

## What Was Built

Three additive edits to `libs/FastSenseCompanion/FastSenseCompanion.m` (38 lines added, none removed):

**Edit 1 — Constructor listener wiring (line 173-174):**
```matlab
obj.Listeners_{end+1} = addlistener(obj, 'OpenAdHocPlotRequested', ...
    @(s, e) obj.onOpenAdHocPlotRequested_(s, e));
```

**Edit 2 — setProject re-wire block (line 261-262):**
```matlab
obj.Listeners_{end+1} = addlistener(obj, 'OpenAdHocPlotRequested', ...
    @(s, e) obj.onOpenAdHocPlotRequested_(s, e));
```

**Edit 3 — New private method (lines 418-450):**
- Resolves `evt.TagKeys` cellstr to Tag handles via `obj.Registry_.get(k)` loop
- Calls `[~, skipped] = openAdHocPlot(tags, mode, obj.Theme)` discarding figure handle
- Partial-success: fires `uialert(..., 'Icon', 'warning')` listing skipped tag names
- Hard-failure: `catch ME` block fires `uialert(..., 'Icon', 'error')` with `isvalid(obj.hFig_)` guard
- Companion stays alive on every error path

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all delegation paths are fully wired. The spawned figure handle is intentionally discarded (ADHOC-04 lifecycle independence). No placeholder text or empty returns exist in the new code.

## Verification Results

All acceptance criteria passed:

| Check | Expected | Actual |
|-------|----------|--------|
| `function onOpenAdHocPlotRequested_(obj, ~, evt)` count | 1 | 1 |
| `addlistener(obj, 'OpenAdHocPlotRequested'` count | 2 | 2 |
| `openAdHocPlot(tags, mode, obj.Theme)` count | 1 | 1 |
| `obj.Registry_.get(keys{k})` count | 1 | 1 |
| `evt.TagKeys` count | ≥1 | 1 |
| `evt.Mode` count | ≥1 | 1 |
| `uialert(obj.hFig_` count | ≥6 | 6 |
| `isvalid(obj.hFig_)` count | ≥1 | 2 |
| `Plot opened, but some tags were skipped` | 1 | 1 |
| `Failed to open plot` | 1 | 1 |
| SpawnedFigures_/AdHocFigures_ references | 0 | 0 |
| `timer(` count | 0 | 0 |
| `gcf`/`gca`/`uiaxes` count | 0 | 0 |
| `uifigure(` count (pre-existing only) | 1 | 1 |
| File line count | ≤470 | 454 |
| All existing methods preserved (9 functions) | 1 each | 1 each |

## Self-Check: PASSED

- File exists: `libs/FastSenseCompanion/FastSenseCompanion.m` — FOUND
- Commit c1d3f25 exists — FOUND
- Line count 454 — within 470-line budget
- All 9 existing method signatures preserved verbatim
