# Progressive Rendering Design

## Problem

First `render()` for large datasets (10M+ points) takes 100-500ms because `minmax_downsample` must scan the entire dataset before any graphics appear. Users see nothing until the full downsample completes.

## Solution

Two-phase rendering: show a fast stride-based preview immediately (<5ms), then refine with proper minmax downsample asynchronously via a one-shot timer.

## Phase 1 — Coarse Preview (in render(), <5ms)

Instead of calling `minmax_downsample(X, Y, pw)`, take every Kth point:

```matlab
K = max(1, floor(numel(X) / (2 * pw)));
xd = X(1:K:end);
yd = Y(1:K:end);
```

- Produces ~2×PixelWidth samples via simple indexing
- O(1) — no scanning, just array stride
- Misses peaks/valleys but shows correct overall shape
- Only for lines with `numel(X) > MinPointsForDownsample`
- Small datasets render directly (no stride, no timer)

## Phase 2 — Async Refinement (timer, ~100-200ms after render)

A one-shot timer fires after `render()` returns and `drawnow` completes:

```matlab
for each line (with numel(X) > MinPointsForDownsample):
    [xd, yd] = minmax_downsample(X, Y, pw, hasNaN);
    set(hLine, 'XData', xd, 'YData', yd);
end
drawnow;
```

- Proper minmax/LTTB downsample with peak preservation
- Swaps data on existing line handles (no new graphics objects)
- Single drawnow at end

## Phase 3 — Cancel on Interaction

If user zooms/pans before refinement completes:
- Stop and delete the refinement timer
- Set `IsRefined = true`
- The zoom/pan callback (`onXLimChanged`) already downsamples for the visible range

## New Properties on FastPlot

```matlab
properties (SetAccess = private)
    hRefineTimer = []     % timer handle for deferred refinement
    IsRefined = true      % false during coarse preview
end
```

## Changes

### 1. FastPlot.render() — stride preview

Replace the downsample block (lines 548-553) with stride-based preview for large datasets. After all rendering + drawnow, start a one-shot timer that calls `refineLines()`.

### 2. New FastPlot.refineLines() private method

Loops through lines with large datasets, does proper minmax/LTTB downsample, swaps XData/YData on existing line handles, single drawnow at end. Sets `IsRefined = true`, clears timer handle.

### 3. FastPlot.onXLimChanged() — cancel refinement

At the top of the callback, if `hRefineTimer` is running, stop and delete it. Set `IsRefined = true`.

### 4. FastPlot.delete() — cleanup timer

Stop and delete refinement timer if running.

### 5. startLive() — cancel refinement

If live mode starts while refinement is pending, stop the timer. Live mode takes over data management.

## Dashboard Integration

In `FastPlotFigure.renderAll()`:
1. Each tile renders with coarse preview (fast, DeferDraw=true)
2. Single `drawnow` — user sees all tiles immediately
3. Each tile's refinement timer fires and refines independently

## Edge Cases

- Small datasets (< MinPointsForDownsample): no stride, no timer, render directly
- LTTB downsample method: stride preview is the same, refinement uses LTTB
- Live mode starts before refinement: stop timer, live mode takes over
- render() called with DeferDraw=true: still start timer (dashboard flow)
- Octave: use timer if available, otherwise refine synchronously as fallback
- Shading regions: not progressive (already cached separately), unchanged

## Expected Impact

- Perceived render time: 100-500ms → <5ms (instant visual feedback)
- Actual refinement: same total cost, but async and non-blocking
- Trade-off: ~200ms of approximate peaks before refinement completes
