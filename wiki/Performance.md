<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense achieves dramatic performance improvements over MATLAB's built-in `plot()` function through intelligent downsampling, multi-level caching, and optimized MEX kernels. This page explains the performance characteristics, tuning options, and how to benchmark your own data.

## Key Performance Metrics

FastSense maintains fluid interactivity even with datasets that cripple traditional plotting. Typical figures for a 10M-point time series on modern hardware:

| Metric | Typical value | Description |
|--------|---------------|-------------|
| Zoom cycle time | ~5 ms | Time to re-downsample and redraw on zoom/pan |
| Effective zoom FPS | 200 FPS | Interactive frames per second during zoom |
| Point reduction | >99.9% | 10M points → ~4,000 rendered points |
| GPU memory usage | <1 MB | vs ~150 MB for equivalent `plot()` |

The key advantage isn't just initial render time — it's maintaining fluid interactivity. With `plot()`, 10M points make zoom/pan unusable, while FastSense maintains sub-5ms response times.

## Why FastSense is Fast

### 1. Downsample to Screen Resolution
Only ~4,000 points are rendered regardless of dataset size. A 100M-point dataset uses the same GPU memory as a 4K-point dataset once downsampled. FastSense supports both **MinMax** (preserves extremes) and **LTTB** (preserves visual shape) downsampling algorithms, settable per line or via `FastSenseDefaults.DownsampleFactor`.

```matlab
fp = FastSense();
fp.MinPointsForDownsample = 5000;      % below this, plot raw data
fp.DownsampleFactor = 2;               % target points per pixel
fp.DefaultDownsampleMethod = 'minmax';  % or 'lttb'
```

When the visible pixel count changes during zoom/pan, FastSense re-downsamples the raw data to the new resolution without any user intervention.

### 2. Binary Search for Range Queries
Uses O(log N) binary search instead of O(N) linear scanning to find the visible portion of the data when the viewport changes. The compiled MEX implementation (`binary_search_mex.c`) is 20× faster than the pure-MATLAB fallback.

```matlab
% Binary search is automatically used internally; you can also call it directly:
idx = binary_search(x, xValue, 'left');  % First index where x >= xValue
idx = binary_search(x, xValue, 'right');  % Last index where x <= xValue
```

### 3. Lazy Multi-Level Pyramid
Pre-computes downsampled levels (e.g., 100× and 10,000× reduction) so zooming out never touches raw data. The pyramid is built incrementally as needed — only the levels required for the current zoom state are computed.

```matlab
fp = FastSense();
fp.PyramidReduction = 100;  % compression factor per pyramid level
```

### 4. SIMD-Optimized MEX Kernels
C implementations use vectorized instructions to process multiple data points per CPU cycle:
- **AVX2 + FMA** on x86_64: processes 4 doubles simultaneously
- **NEON** on ARM64 (Apple Silicon): processes 2–4 elements per cycle

These kernels are compiled via `build_mex()` with architecture detection and automatic fallback:

```matlab
build_mex();  % Compiles all MEX kernels with platform-specific SIMD flags
```

If `build_mex()` fails, FastSense gracefully degrades to pure-MATLAB fallback implementations. For example, `binary_search` tries the compiled MEX first, then falls back to the iterative MATLAB algorithm.

### 5. Fused Operations
Combines multiple operations into single passes to minimize cache misses and CPU overhead:
- Violation detection + pixel coordinate culling
- Downsampling + threshold line intersection
- Range lookup + metadata forwarding

### 6. Direct Graphics Updates
When data changes (live mode), FastSense updates line graphics via direct `XData`/`YData` assignment — the fastest path through MATLAB's graphics system. It avoids object recreation or property listeners.

### 7. Frame Rate Limiting
Uses `drawnow limitrate` to cap display refresh at approximately 20 FPS, preventing GPU thrashing during rapid zoom/pan sequences. This is automatic; no configuration needed.

## Performance Tuning Options

Several FastSense properties control the performance vs. quality trade-off:

```matlab
fp = FastSense();

% Increase points per pixel for denser traces
fp.DownsampleFactor = 4;               % default: 2

% Adjust pyramid compression ratio
fp.PyramidReduction = 50;               % default: 100

% Switch downsampling algorithms
fp.DefaultDownsampleMethod = 'lttb';     % 'minmax' or 'lttb'

% Control when downsampling kicks in
fp.MinPointsForDownsample = 10000;       % default: 5000
```

## Memory Management

FastSense offloads large datasets to disk using SQLite when memory pressure exceeds the configured threshold. This is transparent — your plotting code doesn't change.

```matlab
fp = FastSense();

% Force storage mode
fp.StorageMode = 'memory';    % always RAM
fp.StorageMode = 'disk';      % always SQLite
fp.StorageMode = 'auto';      % automatic (default)

% Adjust memory threshold
fp.MemoryLimit = 1e9;         % 1 GB (default: 500 MB)
```

The `'auto'` mode uses [[FastSenseDataStore]] when a line's memory footprint exceeds `MemoryLimit`, providing disk-based storage without any performance degradation on zoom/pan.

## Monitoring Performance

Enable verbose output to see detailed timing information in the console:

```matlab
fp = FastSense('Verbose', true);
fp.addLine(x, y);
fp.render();

% Example console output:
% [FastSense] Line 1: 10000000 points → 3847 rendered (MinMax, 7.8 ms)
% [FastSense] Pyramid L1: 100000 points ready (2.1 ms)
% [FastSense] Render complete — 9.9 ms total
```

You can also monitor progress during batch operations using [[ConsoleProgressBar]]:

```matlab
pb = ConsoleProgressBar();
pb.start();
for k = 1:1000
    % your processing
    pb.update(k, 1000, 'Processing');
end
pb.finish();
```

## Batch Rendering

For headless or batch workflows, disable intermediate display updates to reduce overhead:

```matlab
fp = FastSense();
fp.DeferDraw = true;        % skip drawnow() during render
fp.ShowProgress = false;    % hide console progress bar
fp.addLine(x, y);
fp.render();
drawnow;                    % display when ready
```

See [[Installation]] for compiling MEX files and [[Getting Started]] for basic usage patterns. For live-mode performance considerations, see the [[Live Mode Guide]].
