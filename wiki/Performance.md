<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense delivers dramatic performance improvements over MATLAB’s built‑in `plot()` by combining intelligent downsampling, a multi‑level pyramid cache, and SIMD‑optimised MEX kernels. This guide explains what you can expect and how to achieve the best results on your hardware.

## Key Performance Metrics

Benchmarks on 10 M data points (Apple M4, GNU Octave 11) show:

| Metric | Value | Description |
|--------|-------|-------------|
| Zoom cycle time | 4.7 ms | Time to re-downsample and redraw on zoom/pan |
| Effective zoom FPS | 212 FPS | Interactive frames per second during zoom |
| Point reduction | 99.96 % | 10 M points → ~4 K rendered points |
| GPU memory usage | 0.06 MB | vs 153 MB for equivalent `plot()` |

The crucial advantage is not just initial render speed — it’s the fluid interactivity that remains even with 100 M points. With `plot()`, zoom and pan become unusable at such scales; FastSense maintains sub‑5 ms response times at 10 M and beyond.

## FastSense vs `plot()` Performance

| Points | `plot()` render | FastSense render | Speedup |
|--------|-----------------|------------------|---------|
| 10 K   | instant         | instant          | ~1×    |
| 100 K  | moderate lag    | instant          | ~5×    |
| 1 M    | slow            | fast             | ~10×    |
| 10 M   | very slow       | 0.19 s           | ~50×    |
| 100 M+ | often fails     | works            | ∞       |

At 100 M+ points, `plot()` frequently runs out of memory or becomes completely unresponsive, while FastSense handles it gracefully thanks to disk‑backed storage and per‑point downsampling.

## Dashboard Performance

When using [[FastSenseGrid]] to build multi‑tile dashboards, the advantage grows with tile count because each tile downsamples independently:

| Layout | `subplot()` | FastSenseGrid | Speedup |
|--------|------------|---------------|---------|
| 1×1    | 0.195 s    | 0.187 s       | 1.0×    |
| 2×2    | 0.451 s    | 0.377 s       | 1.2×    |
| 3×3    | 0.964 s    | 0.709 s       | 1.4×    |

Each tile’s render cost stays nearly flat — no matter how many raw points are behind it — because every tile limits its rendered points to screen resolution (default ~4 K). Traditional approaches scale linearly with total point count.

## MEX vs Pure MATLAB

Compiled MEX kernels provide substantial acceleration for the core operations:

| Operation (10 M points) | MATLAB | MEX | Speedup |
|--------------------------|--------|-----|---------|
| Binary search            | ~1 ms  | ~0.05 ms | 20×     |
| MinMax downsample        | ~25 ms | ~7 ms    | 3.5×    |
| LTTB downsample          | ~200 ms| ~4 ms    | 50×     |
| Violation detection      | ~50 ms | ~2 ms    | 25×     |

MEX kernels use SIMD instructions (AVX2 on x86‑64, NEON on ARM64) to process multiple doubles per CPU cycle. Building the MEX files is done once with `build_mex()`. See [[MEX Acceleration]] for details.

## Running Your Own Benchmarks

FastSense includes benchmark scripts in the `examples/` directory. From the `examples/` folder:

```matlab
% Stress test with 100M points
example_100M;

% Compare LTTB vs MinMax downsampling algorithms
example_lttb_vs_minmax;

% Multi-dashboard stress test: 5 tabs, 26 sensors, 104 thresholds
example_stress_test;
```

The stress test creates a realistic scenario with 5 tabbed dashboards (using [[FastSenseDock]]), 26 sensors, ~86 M total points, and 104 dynamic thresholds that change based on machine state.

## Why FastSense is Fast

### 1. Downsample to Screen Resolution
Only ~4 000 points are sent to the GPU regardless of dataset size. A 100 M‑point line uses the same GPU memory as a 4 K‑point line once downsampled.

### 2. Binary Search for Range Queries
O(log N) binary search locates the visible data range on every zoom/pan, instead of O(N) linear scanning:

```matlab
% binary_search (MEX or pure MATLAB)
idx = binary_search(x, xValue, 'left');   % first index where x >= xValue
idx = binary_search(x, xValue, 'right');  % last index where x <= xValue
```

### 3. Lazy Multi‑Level Pyramid
A pyramid of pre‑computed downsampled versions (100∶1, 10 000∶1, …) is built incrementally when you first render with `render()`. Zooming out fetches a coarser level without touching the raw data. The compression factor is controlled by `PyramidReduction` (default 100).

### 4. SIMD‑Optimised MEX Kernels
C implementations compiled by `build_mex()` utilise vectorised instructions:
- **AVX2 + FMA** on x86‑64: processes 4 doubles per cycle
- **ARM NEON** on Apple Silicon: processes 2‑4 elements per cycle

The build automatically falls back to SSE2 or scalar code if advanced instructions are unavailable. See [[MEX Acceleration]] for the compilation process.

### 5. Fused Operations
Multiple operations are combined into single passes through the data:
- Violation detection + pixel‑coordinate culling
- Downsampling + threshold‑line intersection
- Range lookup + metadata forward‑fill

These fused kernels avoid redundant scans and leverage cache locality.

### 6. Direct Graphics Updates
After downsampling, line objects are updated by directly assigning `XData` and `YData` — the fastest path through MATLAB’s graphics system, avoiding object recreation or property listeners.

### 7. Frame Rate Limiting
Internal rendering uses `drawnow limitrate` to cap display refresh at 20 FPS, preventing GPU thrashing during rapid zoom/pan sequences.

## Performance Tuning Options

Several properties let you trade speed for visual quality:

```matlab
fp = FastSense();

% Increase density for smoother fine‑detail tracing
fp.DownsampleFactor = 4;          % default: 2 points per pixel

% Finer pyramid granularity (more levels, less data per level)
fp.PyramidReduction = 50;        % default: 100

% Choose the downsampling algorithm
fp.DefaultDownsampleMethod = 'lttb';   % 'minmax' or 'lttb'

% Raise the threshold below which raw data is plotted
fp.MinPointsForDownsample = 10000;   % default: 5000
```

These properties can be set per‑instance or changed globally in [[FastSenseDefaults]].

## Memory Management

For very large datasets (hundreds of millions of points), FastSense can store data in a SQLite database (`FastSenseDataStore`) instead of keeping everything in RAM:

```matlab
fp = FastSense();

% Force storage mode
fp.StorageMode = 'memory';   % always RAM
fp.StorageMode = 'disk';     % always SQLite-backed

% Automatic threshold (default: 'auto')
fp.StorageMode = 'auto';
fp.MemoryLimit = 1e9;        % 1 GB threshold (default: 500 MB)
```

In `'auto'` mode, lines exceeding `MemoryLimit` are automatically pushed to disk. The [[FastSenseDataStore]] works seamlessly with zoom/pan and metadata operations. It requires a working `mksqlite` MEX (compiled by `build_mex()`); if `mksqlite` is unavailable, a binary‑file fallback is used.

## Monitoring Performance

Enable verbose diagnostics to see timing details:

```matlab
fp = FastSense('Verbose', true);
fp.addLine(x, y);
fp.render();

% Console output:
% [FastSense] Line 1: 10000000 points → 3847 (MinMax, 23.4 ms)
% [FastSense] Pyramid L1: 100000 points (7.8 ms)
% [FastSense] Pyramid L2: 1000 points (0.3 ms)
% [FastSense] Total render: 187.2 ms
```

For custom batch operations, use the [[ConsoleProgressBar]] class:

```matlab
pb = ConsoleProgressBar();
pb.start();
for k = 1:1000
    % your processing
    pb.update(k, 1000, 'Processing');
end
pb.finish();
```

## Batch Rendering Options

When building dashboards or performing headless processing, defer the screen update to improve throughput:

```matlab
fp = FastSense();
fp.DeferDraw = true;        % skip drawnow during render
fp.ShowProgress = false;    % suppress console progress bar
fp.addLine(x, y);
fp.render();
drawnow;                    % manual drawnow when ready to display
```

This is particularly beneficial when rendering a multi‑tab [[FastSenseDock]] or large [[FastSenseGrid]] — rendering of other tabs can proceed without unnecessary screen refreshes.
