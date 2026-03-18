# Lazy Multi-Resolution Pyramid for FastSense

## Design Document

**Date:** 2026-03-06
**Status:** Approved

---

## 1. Problem

At full zoom-out with 50M+ points, `updateLines()` scans the entire dataset through MinMax downsampling on every frame. This is O(N) per line per frame — the last remaining bottleneck that scales with data size.

## 2. Solution

Build a lazy multi-resolution pyramid of pre-computed MinMax levels per line. On zoom/pan, pick the smallest level with enough resolution for the visible range, then downsample from that level instead of raw data.

## 3. Architecture

### 3.1 Pyramid Structure

Per line, a cell array of pre-computed MinMax levels:

```
Line.Pyramid = {
    level 1:  {x_500K, y_500K}    % minmax of 50M raw, ~100x reduction
    level 2:  {x_5K,   y_5K}      % minmax of level 1, ~100x reduction
}
```

- Level 0 = raw data (`Line.X`, `Line.Y`), not stored in pyramid
- Reduction factor: 100x per level
- Memory overhead: ~1-2% of raw data (geometric series converges)

### 3.2 Lazy Build

Levels are built on demand, not at `render()` time:

1. Zoom/pan triggers `updateLines()`
2. Level selection logic determines the best level
3. If that level doesn't exist yet, build it from the nearest available level
4. Cache in `Line.Pyramid{level}` for reuse

First zoom-out pays a one-time cost (~70ms for level 1 from 50M with MEX). All subsequent queries at that zoom level are instant.

### 3.3 Level Selection

```
visible_points = idxEnd - idxStart + 1
target = 2 * pixelWidth

For each level (highest first):
    level_total = numel(Pyramid{level}.x)
    level_visible ≈ level_total * (visible_range / total_range)
    if level_visible >= target → use this level

Fallback → raw data
```

### 3.4 Query Flow

Replaces the inner loop of `updateLines()`:

1. `binary_search` on RAW X → find visible index range
2. Pick best pyramid level based on visible point count
3. Map raw indices to pyramid level indices (proportional mapping)
4. `binary_search` on pyramid level X → exact visible slice
5. `minmax_downsample` or `lttb_downsample` on that slice → ~4K points
6. `set(hLine, 'XData', xd, 'YData', yd)`

### 3.5 Both Algorithms Benefit

- **MinMax**: Pyramid levels are MinMax — exact min/max preservation across levels
- **LTTB**: Reads from MinMax pyramid level instead of raw data, applies LTTB on the smaller slice. Not a separate pyramid — one shared MinMax pyramid serves both.

## 4. Changes

| Component | Change |
|---|---|
| `FastSense.m` Lines struct | Add `Pyramid` field (cell array) |
| `FastSense.m` `updateLines()` | Level selection + pyramid query |
| `FastSense.m` new private method | `buildPyramidLevel()`, `selectPyramidLevel()` |
| `private/minmax_downsample.m` | No change |
| Tests | New `test_pyramid.m` |

## 5. Example: 50M Points

| Level | Points | Memory | Build cost (MEX) |
|---|---|---|---|
| 0 (raw) | 50,000,000 | 800 MB | — |
| 1 | 500,000 | 8 MB | ~70ms |
| 2 | 5,000 | 80 KB | ~0.7ms |

Full zoom-out query: read level 2 (5K points) → downsample to ~4K → **<1ms** instead of scanning 50M.

## 6. Constraints

- Pyramid is invalidated if data changes (FastSense data is immutable after `addLine()`, so this is safe)
- NaN-aware: pyramid levels preserve NaN segment structure via `minmax_downsample`
- No render-time cost: zero overhead if user never zooms out far enough to trigger pyramid build
