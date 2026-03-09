# Dashboard Performance Optimization — Design

## Problem

Dashboard scenarios (`FastPlotFigure` with many tiles) are slow because:

1. `renderAll()` calls `render()` per tile, and each `render()` calls `drawnow` + toggles figure visibility — resulting in N+1 GPU flushes instead of 1.
2. `addLine()` runs two O(n) scans per line (monotonicity check, NaN detection) that are redundant when the user knows their data is sorted and NaN-free.
3. Line options are applied one property at a time via `set()` in a loop, triggering repeated graphics updates.

## Changes

### 1. Defer `drawnow` to `renderAll()`

- Add private property `DeferDraw = false` to `FastPlot`.
- In `FastPlotFigure.renderAll()`, set `tile.DeferDraw = true` before calling `tile.render()`.
- In `FastPlot.render()`, skip `drawnow` and figure visibility toggle when `DeferDraw` is true.
- `renderAll()` handles visibility + single `drawnow` at the end (already does this).
- No public API change.

### 2. `'AssumeSorted', true` in `addLine()`

- New optional name-value pair for `addLine()`.
- When true, skips the chunked `diff()` monotonicity check (O(n) scan).
- Default: false (existing behavior preserved).
- If user passes unsorted X with this flag, binary search will silently produce wrong results.

### 3. `'HasNaN', false` in `addLine()`

- New optional name-value pair for `addLine()`.
- When provided, skips the `any(isnan(y))` scan (O(n)).
- Stored directly in the line struct.
- Default: auto-detect (existing behavior preserved).

### 4. Batch `set(h, opts)` in render loop

- Replace per-field `set()` loop with single `set(h, opts)` call.
- MATLAB's `set` accepts a struct, applying all properties at once.
- One-line change, no API impact.

## Files to modify

- `FastPlot.m` — all 4 changes
- `FastPlotFigure.m` — change 1 (set DeferDraw before render)

## Testing

- Existing tests must pass unchanged (default behavior preserved).
- Run `benchmark_dashboard.m` before/after to measure improvement.
