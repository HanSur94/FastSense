<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense delivers interactive plotting for datasets ranging from thousands to hundreds of millions of points.  It achieves this through intelligent downsampling, multi‑level caching, and SIMD‑optimised MEX kernels.  This guide explains what performance you can expect, how the system works under the hood, and how to tune and measure it yourself.

## Key Performance Metrics

FastSense aims to keep rendering and zoom/pan response below a few milliseconds, independent of the raw data size, by limiting the number of points sent to the graphics pipeline:

| Metric | Description |
|--------|-------------|
| **Rendered points** | ≈ screen‑width × `DownsampleFactor` (default 2) — typically ~4 000 points for a 2000‑pixel‑wide axes.  A 100 M‑point dataset uses the same GPU memory as a 4 K‑point dataset once downsampled. |
| **Range lookup** | O(log N) via binary search — locating the visible window across 10 M points takes microseconds with the MEX kernel. |
| **Pyramid levels** | Pre‑computed at compression ratios of `PyramidReduction` (default 100).  Zooming out never touches raw data. |
| **MEX kernels** | When compiled with `build_mex`, core operations run 20–50× faster than pure MATLAB by exploiting AVX2/NEON vector instructions. |

The main advantage is not just initial render time — it is maintaining fluid interactivity during zoom and pan, even when exploring massive time series.

## FastSense vs `plot()` Performance

Traditional `plot()` renders every point, which quickly saturates the renderer and slows interactions.  FastSense thresholds raw drawing at `MinPointsForDownsample` (default 5000) and scales continuously from there.

| Points | `plot()` behaviour | FastSense behaviour |
|--------|--------------------|---------------------|
| up to 5 K | instant | instant (raw draw) |
| 100 K | perceptible lag | instant |
| 1 M | slow | fast |
| 10 M | very slow | ~0.2 s initial render, subsequent zoom/pan < 10 ms |
| 100 M+ | often out‑of‑memory or unresponsive | works, disk‑backed if needed |

These are typical figures on modern hardware; run the included benchmark scripts to measure your own system (see [Running Your Own Benchmarks](#running-your-own-benchmarks)).

## Dashboard Performance

In a tiled dashboard ([[FastSenseGrid]]), each tile downsamples independently to its own pixel budget.  Because the per‑tile cost is nearly constant, total rendering time grows much more slowly than the raw point count.

| Layout | Linear scaling (`subplot`) | FastSenseGrid | Advantage |
|--------|----------------------------|---------------|-----------|
| 1×1 | proportional to total points | ~constant after threshold | 1× for small, >>10× for large |
| 2×2 | 4× slowdown | ~1.2× slowdown | growing benefit |
| 3×3 | 9× slowdown | ~1.4× slowdown | |

The [[FastSenseDock]] tabbed container renders each dashboard lazily or with hierarchical progress bars ([[ConsoleProgressBar]]), keeping the UI responsive even when building multi‑dashboard scenes.

## MEX vs Pure MATLAB

Compiled C kernels, built with [[build_mex|MEX Acceleration]], accelerate the most intensive operations.  The function `build_mex` detects the CPU architecture (x86‑64 or ARM64) and compiles every kernel with the best SIMD flags available (AVX2 + FMA or NEON).

Approximate speedups observed on a 10 M‑point dataset:

| Operation | Pure MATLAB | MEX kernel | Speedup |
|-----------|------------|------------|---------|
| `binary_search` | ~1 ms | ~0.05 ms | 20× |
| MinMax downsample | ~25 ms | ~7 ms | 3.5× |
| LTTB downsample | ~200 ms | ~4 ms | 50× |
| Violation detection | ~50 ms | ~2 ms | 25× |

The MEX functions are used transparently when present; otherwise pure‑MATLAB fallbacks run.  Build the MEX files for your platform with:

```matlab
build_mex();
```

If a particular kernel fails to compile (e.g., due to lack of AVX2 support on older hardware), the build script automatically retries with SSE2 and continues.

## Running Your Own Benchmarks

FastSense ships with three stress‑test examples that you can run to measure performance on your system.  From the `examples/` directory:

```matlab
% Stress test with 100M points
example_100M;

% Compare LTTB vs MinMax downsampling algorithms
example_lttb_vs_minmax;

% Multi-dashboard stress test: 5 tabs, 26 sensors, 104 thresholds
example_stress_test;
```

The multi‑dashboard test creates a [[FastSenseDock]] with five tabbed grids, each holding several tiles and threshold lines.  It measures rendering time, memory usage, and zoom responsiveness.

## Why FastSense is Fast

The performance comes from a layered architecture that avoids redundant computation:

### 1. Downsampling to Screen Resolution
Before painting, every line is reduced to the number of pixels it will actually occupy.  The target point count is `plotbox_width(axes) * DownsampleFactor` — with the default factor of 2, a 2000‑pixel‑wide axes draws ≈4 000 points.  The downsampling algorithm ([[MinMax or LTTB|addLine]]) preserves either extreme values or the visual shape.

```matlab
fp = FastSense();
fp.addLine(x, y, 'DownsampleMethod', 'lttb');   % shape-preserving
fp.addLine(x, z, 'DownsampleMethod', 'minmax'); % extremes
```

### 2. Binary Search for Range Queries
On every zoom/pan, the visible X‑range must be mapped to array indices.  Instead of scanning, FastSense uses an O(log N) binary search ([[binary_search]]).  The MEX version probes memory in cache‑friendly strides and runs 20× faster than the MATLAB fallback.

```matlab
% Find the first index where x >= xValue
leftIdx = binary_search(x, xValue, 'left');
% Find the last index where x <= xValue
rightIdx = binary_search(x, xValue, 'right');
```

### 3. Lazy Multi‑Level Pyramid Cache
A pyramid of pre‑downsampled copies is built on demand.  Level 0 holds raw data; Level 1 is downsampled by a factor of `PyramidReduction` (default 100).  When the user zooms out, the renderer pulls from a higher pyramid level, never touching the full raw data.  This makes deep‑zoom responses nearly instantaneous.

### 4. SIMD‑Optimised MEX Kernels
All heavy numeric loops — downsample, violation culling, step‑function conversion — are implemented in C and compiled with platform‑specific SIMD instructions:
- **x86‑64**: AVX2 + FMA, processing 4 doubles per instruction.
- **ARM64**: NEON, processing 2–4 elements per cycle.

Build the kernels with `build_mex()`.  If compilation fails, the library falls back to pure‑MATLAB routines that still benefit from JIT acceleration.

### 5. Fused Operations
Wherever possible, multiple steps are combined into a single pass over the data:
- Violation detection and pixel‑coordinate culling are done together.
- Downsampling simultaneously identifies threshold crossings.
- Range lookups forward metadata without extra traversals.

### 6. Direct Graphics Updates
After the initial render, line objects are updated via direct `XData`/`YData` assignments — the fastest path through MATLAB’s graphics system.  No object recreation or property listeners are involved.

### 7. Frame Rate Limiting
`drawnow limitrate` caps the display refresh at ~20 FPS, preventing the GPU from being overwhelmed by rapid mouse events during zoom/pan.  The internal state tracks the exact visible range, so no visual data is lost.

## Performance Tuning Options

You can adjust the quality‑speed trade‑off via constructor options or by setting properties before calling `render()`:

```matlab
fp = FastSense();

% Increase points per pixel for denser traces (default 2)
fp.DownsampleFactor = 4;

% Adjust pyramid compression ratio (default 100)
fp.PyramidReduction = 50;   % finer granularity, more levels

% Choose default downsampling algorithm (default 'minmax')
fp.DefaultDownsampleMethod = 'lttb';

% Threshold below which raw data is plotted (default 5000)
fp.MinPointsForDownsample = 10000;
```

These defaults can also be set project‑wide in [[FastSenseDefaults|FastSenseDefaults.m]].

## Memory Management

For datasets that exceed available RAM, FastSense can switch to disk‑based storage via [[FastSenseDataStore]], a SQLite‑backed store that reads only the chunks overlapping the current view.

```matlab
fp = FastSense();

% Storage mode: 'auto' (default), 'memory', or 'disk'
fp.StorageMode = 'auto';     % uses disk if line > MemoryLimit
fp.MemoryLimit  = 500e6;     % 500 MB threshold (default)
```

In `'auto'` mode, lines whose memory footprint exceeds `MemoryLimit` are automatically stored on disk.  The disk layer uses chunked typed BLOBs and indexed X‑ranges so that only the few chunks intersecting the visible window are loaded.

## Monitoring Performance

Enable the `Verbose` flag to see timing details in the console:

```matlab
fp = FastSense('Verbose', true);
fp.addLine(x, y);
fp.render();

% Output:
% [FastSense] Line 1: 10000000 points → 3847 (MinMax, 23.4 ms)
% [FastSense] Pyramid L1: 100000 points (7.8 ms)
% [FastSense] Pyramid L2: 1000 points (0.3 ms)
% [FastSense] Total render: 187.2 ms
```

The [[ConsoleProgressBar]] class, used internally, is also available for your own batch operations:

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:1000
    % your processing
    pb.update(k, 1000, 'Processing');
end
pb.finish();
```

## Batch Rendering Options

When you are building a plot for non‑interactive use (e.g., saving to PNG or PDF), you can suppress intermediate display updates to save time:

```matlab
fp = FastSense();
fp.DeferDraw = true;      % skip drawnow during render
fp.ShowProgress = false;  % hide the console progress bar
fp.addLine(x, y);
fp.render();
drawnow;                  % manual drawnow when ready
```

This is used by the 100 M‑point stress test example and provides measurable speed‑ups for very large datasets.

---

*Related: [[FastSense]], [[FastSenseGrid]], [[FastSenseDataStore]], [[build_mex|MEX Acceleration]], [[ConsoleProgressBar]], [[FastSenseDefaults]]*
