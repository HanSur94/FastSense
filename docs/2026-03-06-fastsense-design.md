# FastSense — Ultra-Fast Time Series Plotting Library for MATLAB 2020b

## Design Document

**Date:** 2026-03-06
**Status:** Approved

---

## 1. Problem Statement

MATLAB's built-in `plot()` chokes on large time series data (10M-100M points). Zooming and panning become unusable. Existing community solutions (Plot(Big), DSPLOT, plotLDS) either assume evenly sampled data, lack a structured API, or miss features like threshold visualization.

**Goal:** A pure-MATLAB plotting library that renders 100M data points with fluid zoom/pan, supports unevenly sampled time series with NaN gaps, and provides a clean builder API for threshold lines and violation markers.

---

## 2. Requirements

### Functional
- Plot 1-30 lines per axes, each with 1K to 100M data points
- Monotonically increasing X (time), non-uniform spacing allowed
- NaN gaps in data handled natively
- Threshold lines (horizontal) with configurable direction (upper/lower)
- Threshold violation markers (scatter overlay at crossing points)
- Fluid zoom and pan interaction at all data scales
- Create new figure/axes or target existing axes
- Optional linked zoom/pan across axes (opt-in flag)
- UserData tagging on all graphics objects for programmatic identification
- MinMax downsampling (default), LTTB as optional alternative

### Non-Functional
- Pure MATLAB — no MEX, no toolbox dependencies
- Compatible with MATLAB 2020b
- Classic `figure()` with OpenGL renderer
- Copy-on-write data ownership (zero-copy when possible)
- Builder pattern API

---

## 3. Architecture

```
FastSense (handle class)
|
+-- Properties
|   +-- Lines[]        — array of line config structs
|   +-- Thresholds[]   — array of threshold config structs
|   +-- ParentAxes     — target axes handle (or empty = create new)
|   +-- LinkGroup      — string ID for linked axes synchronization
|   +-- IsRendered     — flag to prevent double-render
|
+-- Data Storage (per line)
|   +-- X, Y           — raw data vectors (copy-on-write)
|   +-- hLine          — graphics line handle (reused, never recreated)
|   +-- DownsampleMethod — 'minmax' (default) or 'lttb'
|
+-- Graphics Handles
|   +-- hFigure        — figure handle
|   +-- hAxes          — axes handle
|   +-- hThresholds    — single line object (NaN-batched)
|   +-- hViolations    — single scatter object (NaN-batched)
|
+-- Internal
    +-- Listeners[]    — XLim/resize PostSet listeners
    +-- PixelWidth     — cached axes width in pixels
    +-- DownsampleBuf  — pre-allocated output buffer
```

---

## 4. Performance Techniques

### 4.1 MinMax Downsampling

Reduces N data points to ~2 × pixel_width points. For a 1920px-wide axes with 100M points, only ~3840 points are plotted.

Algorithm per line:
1. Take the visible slice of data (from binary search)
2. Divide into `pixel_width` equal-index buckets
3. For each bucket, emit `min(Y)` and `max(Y)` with corresponding X values
4. Result: a polyline that visually matches the original at screen resolution

NaN handling: split data into contiguous non-NaN segments before bucketing. Rejoin with NaN separators in output.

### 4.2 Binary Search for Visible Range

X is monotonically increasing, so finding the visible range `[xmin, xmax]` is O(log n):
```matlab
idx_start = binary_search_left(X, xmin);
idx_end   = binary_search_right(X, xmax);
```
This avoids scanning the full array on every zoom/pan.

### 4.3 Graphics Update — No Object Recreation

On zoom/pan:
- Update `hLine.XData` and `hLine.YData` directly (dot notation, fastest)
- Never `delete` + `plot()` — reuse handles
- Violation markers: update single scatter object's `XData`/`YData`
- Threshold lines: static, no update needed on zoom

### 4.4 Frame Rate Control

- `drawnow limitrate` during rapid pan/zoom (caps at 20fps, skips redundant frames)
- Lazy recomputation: only downsample when XLim actually changes (compare to cached value)

### 4.5 NaN-Separator Batching

Inspired by Fast Primitive Shapes. Multiple threshold lines are combined into a single line object using NaN separators:
```matlab
% 3 threshold lines become 1 graphics object:
X = [xmin xmax NaN xmin xmax NaN xmin xmax];
Y = [t1   t1   NaN t2   t2   NaN t3   t3  ];
```
Same for violation markers — one scatter object for all violations across all thresholds.

### 4.6 Pre-Allocated Buffers

Downsample output buffers are allocated once at `render()` time based on axes pixel width. Reused on every zoom/pan callback without reallocation.

### 4.7 Static Axis Limits

During zoom/pan callbacks, axis limits are managed manually. Auto-limit recalculation (`XLimMode = 'auto'`) is disabled after initial render to avoid MATLAB internally scanning all data.

---

## 5. API

### 5.1 Construction and Configuration

```matlab
% Create with new figure (default)
fp = FastSense();

% Create targeting existing axes
fp = FastSense('Parent', ax);

% Linked axes (opt-in)
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'sensors');
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'sensors');
```

### 5.2 Adding Lines

```matlab
fp.addLine(x, y);
fp.addLine(x, y, 'DisplayName', 'Sensor1', 'Color', 'b', 'LineWidth', 1.5);
fp.addLine(x, y, 'DownsampleMethod', 'lttb');  % override default MinMax
```

- `x` must be monotonically increasing (validated on add)
- `y` may contain NaN values (gaps)
- All standard MATLAB line properties (`Color`, `LineStyle`, `LineWidth`, `DisplayName`) are forwarded to the graphics object

### 5.3 Adding Thresholds

```matlab
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', 'r', 'LineStyle', '--', 'Label', 'UpperLimit');

fp.addThreshold(-2.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0.4 0], 'Label', 'LowerLimit');
```

- `Direction`: `'upper'` (violation when Y > threshold) or `'lower'` (violation when Y < threshold)
- `ShowViolations`: if `true`, scatter markers are placed where any data line crosses/exceeds the threshold
- Threshold lines span the full X range and do not update on zoom (they're always visible)

### 5.4 Rendering

```matlab
fp.render();
```

This:
1. Creates figure/axes if no parent specified
2. Validates all data
3. Allocates downsample buffers
4. Performs initial downsampling
5. Creates graphics objects (lines, thresholds, violation markers)
6. Tags all objects with UserData (see 5.5)
7. Installs zoom/pan listeners
8. Sets axis limits and disables auto-limits
9. Calls `drawnow`

### 5.5 UserData Tagging

Every graphics object created by FastSense carries identification metadata:

```matlab
h.UserData.FastSense = struct( ...
    'Type',           'data_line',  ...  % 'data_line' | 'threshold' | 'violation_marker'
    'Name',           'Sensor1',    ...  % DisplayName or threshold Label
    'LineIndex',      1,            ...  % index in FastSense's line array
    'ThresholdValue', []            ...  % populated for threshold/violation types
);
```

Usage example:
```matlab
% Find all threshold lines programmatically
lines = findobj(ax, '-function', ...
    @(h) isfield(h.UserData, 'FastSense') && strcmp(h.UserData.FastSense.Type, 'threshold'));
```

---

## 6. Zoom/Pan Flow

```
User zooms or pans
  |
  v
XLim PostSet listener fires
  |
  v
Compare new XLim to cached XLim — if unchanged, return (lazy)
  |
  v
For each data line:
  |-- binary_search: find visible index range [idx_start, idx_end]  O(log n)
  |-- minmax_downsample (or lttb): reduce to ~2 x pixel_width       O(n_visible / bucket)
  |-- update hLine.XData, hLine.YData (dot notation)
  |
  v
Recompute violation markers for visible range
  |-- update hViolations.XData, hViolations.YData
  |
  v
If LinkGroup active:
  |-- propagate XLim to all linked FastSense instances (skip self)
  |
  v
drawnow limitrate
```

---

## 7. File Structure

```
FastSense/
+-- FastSense.m                  — main handle class
+-- private/
|   +-- minmax_downsample.m     — MinMax per-pixel downsampling
|   +-- lttb_downsample.m       — Largest Triangle Three Buckets
|   +-- binary_search.m         — O(log n) index range lookup
|   +-- compute_violations.m    — threshold crossing detection
|   +-- batch_thresholds.m      — NaN-separator batching for threshold lines
+-- examples/
|   +-- example_basic.m         — single line, 10M points
|   +-- example_multi.m         — multiple lines + thresholds
|   +-- example_linked.m        — linked axes demo
|   +-- example_100M.m          — stress test with 100M points
+-- README.md
```

---

## 8. Constraints and Limitations

- **MATLAB 2020b only** — no uifigure, no web graphics
- **Pure MATLAB** — no MEX, no external toolbox dependencies
- **X must be monotonically increasing** — validated on `addLine()`
- **Copy-on-write data** — user should not modify passed arrays after `addLine()`; if they do, MATLAB will copy (doubling memory)
- **Not for scatter/XY plots** — time series only
- **MinMax downsampling is lossy for visual smoothness** — use LTTB option when presentation quality matters

---

## 9. Research Sources

- [plotBig_Matlab (Jim Hokanson)](https://github.com/JimHokanson/plotBig_Matlab) — MinMax per-pixel, C-MEX with OpenMP/SIMD, zoom/pan callbacks. Key inspiration for algorithm. Limitation: assumes evenly sampled data.
- [Fast Primitive Shapes (Austin Fite)](https://www.mathworks.com/matlabcentral/fileexchange/173545-fast-primitive-shapes) — NaN-separator batching to reduce graphics object count. Inspiration for threshold/marker batching.
- [LTTB Algorithm](https://dev.to/crate/advanced-downsampling-with-the-lttb-algorithm-3okh) — O(n) shape-preserving downsampling via triangle area maximization.
- [MathWorks: Improve Graphics Performance](https://www.mathworks.com/help/matlab/creating_plots/improve-graphics-update-performance.html) — drawnow limitrate, dot notation, static limits.
- [Undocumented Matlab: Plot Performance](https://undocumentedmatlab.com/articles/plot-performance) — XData/YData direct update, avoiding auto-limit recalculation.
- [Plot(Big) by Tucker McClure](https://www.mathworks.com/matlabcentral/fileexchange/40790-plot-big) — earlier pixel-reduction approach, monotonic X only.
- [DSPLOT](https://www.mathworks.com/matlabcentral/fileexchange/15850-dsplot-downsampled-plot) — basic downsampled plot with zoom/pan.
