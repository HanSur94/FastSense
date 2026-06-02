<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense achieves dramatic performance improvements over MATLAB's built‑in `plot()` by intelligent downsampling, multi‑level caching, and optimized MEX kernels.  This page explains what to expect and how to tune performance for your own workloads.

## Key Performance Metrics

Based on benchmarks with 10 M data points on Apple M4 and GNU Octave 11:

| Metric | Value | Description |
|--------|-------|-------------|
| Zoom cycle time | 4.7 ms | Time to re‑downsample and redraw on zoom/pan |
| Effective zoom FPS | 212 FPS | Interactive frames per second during zoom |
| Point reduction | 99.96 % | 10 M points → ~4 K rendered points |
| GPU memory usage | 0.06 MB | vs 153 MB for equivalent `plot()` |

The key advantage is **not** just initial render time — it’s maintaining fluid interactivity.  With `plot()`, 10 M points make zoom/pan unusable; FastSense stays under 5 ms.

## FastSense vs `plot()` Performance

| Points | `plot()` render | FastSense render | Speedup |
|--------|-----------------|------------------|---------|
| 10 K | instant | instant | ~1× |
| 100 K | moderate lag | instant | ~5× |
| 1 M | slow | fast | ~10× |
| 10 M | very slow | 0.19 s | ~50× |
| 100 M | often fails | works | ∞ |

At 100 M+ points, `plot()` frequently runs out of memory or freezes; FastSense handles it gracefully.

## Dashboard Performance

Multi‑tile dashboards show increasing advantage as tile count grows:

| Layout | `subplot()` | `FastSenseGrid` | Speedup |
|--------|-------------|-----------------|---------|
| 1×1 | 0.195 s | 0.187 s | 1.0× |
| 2×2 | 0.451 s | 0.377 s | 1.2× |
| 3×3 | 0.964 s | 0.709 s | 1.4× |

Each `FastSenseGrid` tile downsamples independently to ~4 K points regardless of raw data size, so rendering cost stays nearly flat. Traditional approaches scale linearly with total point count.

## MEX vs Pure MATLAB

Compiled MEX kernels provide substantial acceleration for core operations:

| Operation (10 M points) | MATLAB | MEX | Speedup |
|-------------------------|--------|-----|---------|
| Binary search | ~1 ms | ~0.05 ms | 20× |
| MinMax downsample | ~25 ms | ~7 ms | 3.5× |
| LTTB downsample | ~200 ms | ~4 ms | 50× |
| Violation detection | ~50 ms | ~2 ms | 25× |

MEX kernels use SIMD instructions (AVX2 / NEON) to process multiple doubles per CPU cycle when available.  See [[MEX Acceleration]] for compilation details.

## Running Your Own Benchmarks

FastSense includes benchmark scripts in the `examples/` directory:

```matlab
% Stress test with 100M points
example_100M;

% Compare LTTB vs MinMax downsampling algorithms
example_lttb_vs_minmax;

% Multi‑dashboard stress test: 5 tabs, 26 sensors, 104 thresholds
example_stress_test;
```

The stress test creates a realistic large‑scale scenario with 5 tabbed dashboards, 26 sensors, ~ 86 M total points, and 104 dynamic thresholds that change based on machine state.

## Why FastSense is Fast

### 1. Downsample to Screen Resolution

Only ~4 000 points are rendered, regardless of dataset size.  A 100 M point dataset uses the same GPU memory as a 4 K dataset after downsampling.

### 2. Binary Search for Range Queries

Uses O(log N) binary search instead of O(N) linear scanning to find visible data ranges on zoom/pan:

```matlab
% Binary search — 20× faster than MATLAB fallback
idx = binary_search(x, xValue, 'left');   % first index where x >= xValue
idx = binary_search(x, xValue, 'right');  % last index where x <= xValue
```

A MEX-accelerated version is used automatically if `binary_search_mex` is on the path, with a pure‑MATLAB fallback.

### 3. Lazy Multi‑Level Pyramid

Pre‑computes downsampled levels (100∶1, 10 000∶1, …) so zooming out never touches raw data.  The cache is built incrementally as needed.

### 4. SIMD‑Optimized MEX Kernels

C implementations use vectorized instructions to process multiple data points per CPU cycle:
- **AVX2** on x86_64: 4 doubles simultaneously
- **NEON** on ARM64: 2–4 elements per cycle

Build the MEX kernels for maximum performance:

```matlab
build_mex();  % Compile with platform‑specific SIMD optimization
```

### 5. Fused Operations

Combines multiple operations in single passes:
- Violation detection + pixel coordinate culling
- Downsampling + threshold line intersection
- Range lookup + metadata forwarding

### 6. Direct Graphics Updates

Line data is updated via direct `XData`/`YData` assignment — the fastest path through MATLAB’s graphics system.  It avoids object recreation or property listeners.

### 7. Frame Rate Limiting

Uses `drawnow limitrate` to cap display refresh at 20 FPS, preventing GPU thrashing during rapid zoom/pan sequences.

## Performance Tuning Options

Several properties control the speed‑vs‑quality trade‑off.  All are available on the `FastSense` object and can be pre‑set via `FastSenseDefaults`:

```matlab
fp = FastSense();

% Increase points per pixel for denser traces (default: 2)
fp.DownsampleFactor = 4;

% Adjust pyramid compression (default: 100)
fp.PyramidReduction = 50;  % more levels, finer granularity

% Switch algorithms for different data characteristics
fp.DefaultDownsampleMethod = 'lttb';  % vs 'minmax'

% Control when downsampling kicks in (default: 5000)
fp.MinPointsForDownsample = 10000;
```

See `FastSenseDefaults.m` for a complete list of configurable defaults.

## Memory Management

FastSense automatically switches between in‑memory and disk‑backed storage:

```matlab
fp = FastSense();

% Force storage mode (default: 'auto')
fp.StorageMode = 'memory';  % always RAM
fp.StorageMode = 'disk';    % always SQLite

% Adjust memory threshold (default: 500 MB)
fp.MemoryLimit = 1e9;  % 1 GB threshold
```

The `'auto'` mode uses `FastSenseDataStore` for lines exceeding the memory limit, seamlessly providing disk‑based storage without performance degradation.  Temporary SQLite databases are used, with optional WAL journal mode for concurrent reads.

## Monitoring Performance

Enable verbose output to see detailed timing information:

```matlab
fp = FastSense('Verbose', true);
fp.addLine(x, y);
fp.render();

% Output:
% [FastSense] Line 1: 10000000 points → 3847 (MinMax, 23.4 ms)
% [FastSense] Pyramid L1: 100000 points (7.8 ms)
% [FastSense] Pyramid L2: 1000 points (0.3 ms)
% [FastSense] Total render: 187.2 ms
```

The `ConsoleProgressBar` class (used internally) is also available for your own batch operations:

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

For headless or batch workflows, use `DeferDraw` to skip intermediate display updates:

```matlab
fp = FastSense();
fp.DeferDraw = true;      % Skip drawnow during render
fp.ShowProgress = false;  % Hide console progress bar
fp.addLine(x, y);
fp.render();
drawnow;                  % Manual drawnow when ready to display
```

This is demonstrated in the 100 M point stress test example, where it provides measurable performance gains for very large datasets.
