<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense achieves dramatic performance improvements over MATLAB's built‑in `plot()` function through intelligent downsampling, multi‑level caching, and optimized C/MEX kernels. The result is fluid interactivity even with hundreds of millions of data points.

## Key Performance Metrics

Benchmarks with 10M data points on Apple M4, GNU Octave 11:

| Metric | Value | Description |
|--------|-------|-------------|
| Zoom cycle time | 4.7 ms | Time to re‑downsample and redraw on zoom/pan |
| Effective zoom FPS | 212 FPS | Interactive frames per second during zoom |
| Point reduction | 99.96% | 10M points → ~4K rendered points |
| GPU memory usage | 0.06 MB | vs 153 MB for equivalent `plot()` |

The critical advantage is not just initial render speed — it is maintaining sub‑5 ms response times during zoom and pan, where `plot()` becomes unusable.

## FastSense vs plot() Performance

| Points | plot() render | FastSense render | Speedup |
|--------|---------------|------------------|---------|
| 10K | instant | instant | ~1× |
| 100K | moderate lag | instant | ~5× |
| 1M | slow | fast | ~10× |
| 10M | very slow | 0.19 s | ~50× |
| 100M | often fails | works | ∞ |

At 100M+ points, `plot()` frequently exhausts memory or becomes unresponsive, while FastSense handles it gracefully.

## Dashboard Performance

Multi‑tile dashboards scale sub‑linearly with tile count:

| Layout | subplot() | FastSenseGrid | Speedup |
|--------|-----------|---------------|---------|
| 1×1 | 0.195 s | 0.187 s | 1.0× |
| 2×2 | 0.451 s | 0.377 s | 1.2× |
| 3×3 | 0.964 s | 0.709 s | 1.4× |

Each [[FastSenseGrid]] tile downsamples independently to ~4 K points, keeping rendering cost almost constant.

## MEX vs Pure MATLAB

Compiled MEX kernels provide significant acceleration for core operations:

| Operation (10M points) | MATLAB | MEX | Speedup |
|------------------------|--------|-----|---------|
| Binary search | ~1 ms | ~0.05 ms | 20× |
| MinMax downsample | ~25 ms | ~7 ms | 3.5× |
| LTTB downsample | ~200 ms | ~4 ms | 50× |
| Violation detection | ~50 ms | ~2 ms | 25× |

MEX kernels utilise SIMD instructions (AVX2 on x86‑64, NEON on ARM64) to process multiple doubles per CPU cycle.

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

The stress test creates a realistic large‑scale scenario with tabbed dashboards, dozens of sensors, and dynamic thresholds.

## Why FastSense is Fast

### 1. Downsample to Screen Resolution
Only about 4 000 points are rendered, regardless of the raw dataset size. The target points‑per‑pixel is controlled by `DownsampleFactor` (default 2).

### 2. Binary Search for Range Queries
O(log N) binary search replaces O(N) linear scanning to locate visible data on zoom/pan:

```matlab
% binary_search uses compiled MEX when available, MATLAB fallback otherwise
idx = binary_search(x, xValue, 'left' );   % first index where x >= xValue
idx = binary_search(x, xValue, 'right');   % last index where x <= xValue
```

### 3. Lazy Multi‑Level Pyramid
Pre‑computed levels downsampled by a factor of `PyramidReduction` (default 100) allow zooming out without touching raw data. The pyramid is built incrementally as levels are needed.

### 4. SIMD‑Optimised MEX Kernels
C implementations in `libs/FastSense/private/mex_src/` use platform‑specific vector instructions:
- **AVX2 + FMA** on x86‑64
- **NEON** on ARM64 (Apple Silicon, etc.)

Build the kernels with:

```matlab
build_mex();   % detects architecture and selects optimal SIMD flags
```

### 5. Fused Operations
Multiple operations are combined into single passes — e.g., violation detection + pixel‑coordinate culling, downsampling + threshold intersection, and range lookup + metadata forwarding.

### 6. Direct Graphics Updates
Line data is updated via direct `XData`/`YData` assignment, the fastest path through MATLAB’s graphics system.

### 7. Frame Rate Limiting
`drawnow limitrate` caps display refresh at 20 FPS, preventing GPU thrashing during rapid zoom/pan sequences.

## Performance Tuning Options

Several constructor properties control the speed‑vs‑quality trade‑off:

```matlab
fp = FastSense();

% Points per pixel (higher = denser trace, default: 2)
fp.DownsampleFactor = 4;

% Pyramid compression factor per level (default: 100)
fp.PyramidReduction = 50;   % more levels, finer zoom granularity

% Algorithm: 'minmax' (preserves extremes) or 'lttb' (preserves visual shape)
fp.DefaultDownsampleMethod = 'lttb';

% Minimum number of raw points before downsampling activates (default: 5000)
fp.MinPointsForDownsample = 10000;
```

These can also be set globally in `FastSenseDefaults.m`.

## Memory Management

FastSense can automatically switch between in‑memory and SQLite‑backed storage via [[FastSenseDataStore]] for datasets that exceed available RAM.

```matlab
fp = FastSense();

% Force storage mode (default: 'auto' decides based on MemoryLimit)
fp.StorageMode = 'memory';  % always keep in RAM
fp.StorageMode = 'disk';    % always use SQLite / binary fallback

% Threshold for auto mode (default: 500 MB)
fp.MemoryLimit = 1e9;  % 1 GB
```

In `'auto'` mode, lines larger than `MemoryLimit` are stored on disk without performance penalty for range queries.

## Monitoring Performance

Enable verbose output to see detailed timing information:

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

The `ConsoleProgressBar` class (used internally) is available for your own batch operations:

```matlab
pb = ConsoleProgressBar(4);  % 4‑space indent
pb.start();
for k = 1:numSteps
    pb.update(k, numSteps, 'Processing');
end
pb.finish();
```

## Batch Rendering Options

For headless or batch workflows, use `DeferDraw` to skip intermediate display updates:

```matlab
fp = FastSense();
fp.DeferDraw = true;      % suppress drawnow during render
fp.ShowProgress = false;  % hide console progress bar
fp.addLine(x, y);
fp.render();
drawnow;                  % manual draw when ready to display
```

This is demonstrated in the 100M‑point stress test example, where it measurably improves throughput.
