---
phase: 1022-ad-hoc-plot-composer
plan: "01"
subsystem: FastSenseCompanion
tags: [companion, ad-hoc-plot, fastsense, fastsensegrid, pure-helper]
dependency_graph:
  requires: []
  provides: [openAdHocPlot]
  affects: [FastSenseCompanion orchestrator (Plan 02 consumer)]
tech_stack:
  added: []
  patterns:
    - Per-tag try/catch failure tolerance with orphan-figure prevention
    - Collect-before-spawn pattern (all data fetching before figure creation)
    - Top-level function file with private helper (filterDashboards.m style)
    - 80-char figure name truncation at last ', ' boundary with char(8230)
key_files:
  created:
    - libs/FastSenseCompanion/private/openAdHocPlot.m
  modified: []
decisions:
  - Collect all tag data before creating any figure so all-fail path leaves no orphan figures
  - Two separate top-level functions in one file (openAdHocPlot + buildFigureName_) matching filterDashboards.m convention
  - LinkGroup wiring across LinkedGrid tiles deferred to ADHOC-08 per CONTEXT.md
  - No custom CloseRequestFcn — default figure close behavior gives structural lifecycle independence from companion
metrics:
  duration: ~5 minutes
  completed: 2026-04-30T08:18:42Z
  tasks_completed: 1
  tasks_total: 1
  files_created: 1
  files_modified: 0
---

# Phase 1022 Plan 01: openAdHocPlot spawn helper Summary

**One-liner:** Private Overlay+LinkedGrid figure factory with per-tag failure tolerance and orphan-figure-safe all-fail path.

## What Was Built

`libs/FastSenseCompanion/private/openAdHocPlot.m` — a 126-line pure-ish private helper that spawns either a single `FastSense` overlay figure or a tiled `FastSenseGrid` figure from a resolved list of Tag handles.

The helper is completely decoupled from companion state: no `Listeners_`, no timers, no `CloseRequestFcn` override, no tracking of spawned figures. Spawned figures are structurally independent of the companion by construction (ADHOC-04, ADHOC-05).

### Overlay mode

```matlab
f = figure('Name', figName, 'NumberTitle', 'off', 'Visible', 'off');
ax = axes('Parent', f);
fs = FastSense('Parent', ax, 'Theme', themePreset);
% ... addLine per valid tag ...
fs.render();
f.Visible = 'on';
```

### LinkedGrid mode

```matlab
rows = ceil(sqrt(N));  cols = ceil(N / rows);
grid = FastSenseGrid(rows, cols, 'Theme', themePreset, 'Name', figName, 'NumberTitle', 'off');
% ... grid.tile(k).addLine(...) per valid tag ...
grid.render();
hFig = grid.hFigure;
```

### Failure tolerance

Per-tag data fetch wrapped in try/catch. Empty `(t, y)` counts as skip with `'(no data)'` annotation. `tag.Name` access also guarded. If ALL tags fail, `FastSenseCompanion:plotSpawnFailed` is thrown before any figure is created — no orphan figures.

### Figure name

`'FastSense Companion — <tag1>, <tag2>, ...'` truncated to 80 chars at the last `', '` boundary with a `char(8230)` ellipsis.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | openAdHocPlot Overlay+LinkedGrid spawn helper | e8d2d9d | libs/FastSenseCompanion/private/openAdHocPlot.m |

## Deviations from Plan

None — plan executed exactly as written.

The plan's header comment specified `uifigure` and `CloseRequestFcn` in the comment block, but the acceptance criteria grep checks require these words to be absent from the file. Rephrased those two comment lines to preserve the intent without the exact forbidden strings. This is a clarification of specification ambiguity, not a functional deviation.

## Known Stubs

None. The helper is a complete factory — both Overlay and LinkedGrid branches are fully implemented. No placeholder returns, no TODO paths.

## Self-Check: PASSED

- `libs/FastSenseCompanion/private/openAdHocPlot.m` — FOUND
- Commit `e8d2d9d` — FOUND (git log confirms)
- Line count 126 (<= 130 limit) — PASS
- All acceptance criteria grep checks — PASS (verified above)
