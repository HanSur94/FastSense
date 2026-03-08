# Log-Scale Axis Support — Design Document

**Date**: 2026-03-08
**Branch**: feature/log-scale (from feature/lazy-tab-rendering)

## Overview

Add logarithmic axis support (X, Y, or both) to FastPlot with zero overhead for the most common case (minmax + log Y).

## Decisions

| Decision | Choice |
|----------|--------|
| Scope | Both X and Y, independently (`semilogx`, `semilogy`, `loglog`) |
| API | Constructor NV-pair + `setScale()` method |
| Downsampling | No change for minmax+logY (free); log-space bucketing for minmax+logX; log-transform for LTTB area calc |
| Pyramid invalidation | Per-line, only when scale change affects that line's algorithm |
| Linked axes | Scale not propagated, only XLim |
| Non-positive values | MATLAB clips silently; verbose-mode warning |
| Memory overhead | Zero |

## API Surface

### Constructor options

```matlab
fp = FastPlot('XScale', 'log', 'YScale', 'log');
```

Both default to `'linear'`. Accepted values: `'linear'` or `'log'`.

### Post-render method

```matlab
fp.setScale('XScale', 'log');
fp.setScale('YScale', 'log');
fp.setScale('XScale', 'log', 'YScale', 'linear');
```

Updates properties, applies MATLAB axis scale, invalidates pyramid caches where needed, and calls `updateLines()`/`updateShadings()`/`updateViolations()`.

### Properties

- `XScale` — char, `'linear'` or `'log'` (read-only, changed via `setScale`)
- `YScale` — char, `'linear'` or `'log'` (read-only, changed via `setScale`)

## Downsampling Logic

### MinMax + log Y — Free (no change)

Min/max are order-invariant under monotonic transforms. The min and max Y values in a linear bucket are the same points as in log-space. Zero overhead.

### MinMax + log X — Log-space bucket edges

Current bucketing divides X into equal-width linear bins. For log X, bucket edges must be log-spaced for visually uniform density. Transform is on bucket edges only (~pixelWidth values), not on raw data.

### LTTB + log scale — Log-transformed area computation

LTTB selects points by maximizing triangle area. On log axes, areas must be computed in log-space for visually optimal selection. Pass `log10(x)` and/or `log10(y)` to the area formula; use the resulting indices to pick from original (untransformed) data.

Transforms happen on the already-sliced visible range, not on full raw data.

### Performance summary

| Path | Transform | Cost |
|------|-----------|------|
| minmax + log Y | None | Free |
| minmax + log X | `log10` on bucket edges (~pixelWidth values) | Negligible |
| LTTB + log Y | `log10(Y)` on visible segment for area calc | One vectorized op |
| LTTB + log X | `log10(X)` on visible segment for area calc | One vectorized op |

## Pyramid Cache

Each pyramid level is tagged with the scale settings at build time. On scale change:

- **Log Y + minmax**: pyramid remains valid (no invalidation)
- **Log X or LTTB**: pyramid cleared (`Lines(i).Pyramid = {}`)

Invalidation is per-line based on that line's downsample method and what scale dimension changed.

## Integration Points

### `render()`

After creating axes, apply `set(hAxes, 'XScale', obj.XScale, 'YScale', obj.YScale)` before plotting lines. Initial downsampling follows the same scale-aware logic.

### `updateLines()` (hot path)

Passes current scale settings into downsample calls. No change for minmax + log Y. For log X, bucket edges computed in log-space. For LTTB, indices selected using log-transformed coordinates.

### `setScale()` (new method)

1. Validate inputs (`'linear'` or `'log'`)
2. Determine what changed
3. Update properties
4. `set(hAxes, 'XScale', ...)` / `set(hAxes, 'YScale', ...)`
5. Invalidate pyramids only if needed
6. Call `updateLines()`, `updateShadings()`, `updateViolations()`
7. If `Verbose`, warn about non-positive values

### `addLine()`

No changes — raw data storage is scale-independent.

### Thresholds, bands, shadings

No changes. Drawn in data coordinates; MATLAB handles log transformation visually. Shading downsampling follows the same rules as line downsampling.

### Linked axes

Scale is not propagated across LinkGroup. XLim sync continues unchanged.

### `updateData()` (live mode)

Clears pyramids as today. No additional changes needed.

## Error Handling

- **Non-positive values on log axis**: MATLAB clips silently. In `Verbose` mode, one warning per render with count of clipped points (`'FastPlot:logScale'`).
- **All-negative data on log Y**: Empty plot (MATLAB behavior). Verbose warning.
- **Mixed lines (minmax + LTTB)**: Pyramid invalidation is per-line based on method.
- **Scale change before render**: Just updates the property; no downsample work.
