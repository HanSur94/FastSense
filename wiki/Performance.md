<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Performance

FastSense achieves dramatic speed-ups over MATLAB’s built-in `plot()` by using intelligent downsampling, multi-level caching, and compiled MEX kernels. This page explains what to expect, how to measure performance on your own data, and how to tune the engine for maximum throughput.

## Key Performance Metrics

Based on benchmarks with 10M data points on modern CPUs (Apple M4, GNU Octave 11):

| Metric | Value | Description |
|--------|-------|-------------|
| Zoom cycle time | 4.7 ms | Time to re-downsample and redraw on zoom/pan |
| Effective zoom FPS | 212 FPS | Interactive frames per second during zoom |
| Point reduction | 99.96% | 10M points → ~4K rendered points |
| GPU memory usage | 0.06 MB | vs 153 MB for equivalent `plot()` |

The key advantage isn’t just initial render time — it’s maintaining fluid interactivity. With `plot()`, 10M points make zoom/pan unusable; FastSense maintains sub‑5 ms response times regardless of dataset size.

## FastSense vs plot()

| Points | `plot()` render | FastSense render | Speedup |
|--------|----------------|------------------|---------|
| 10K    | instant        | instant          | ~1×     |
| 100K   | moderate lag   | instant          | ~5×     |
| 1M     | slow           | fast             | ~10×    |
| 10M    | very slow      | 0.19 s           | ~50×    |
| 100M   | often fails    | works            | ∞       |

At 100M+ points, `plot()` frequently runs out of memory or becomes completely unresponsive, while FastSense handles it gracefully.

## Dashboard Performance

Multi‑tile dashboards show an increasing advantage as the grid grows:

| Layout | `subplot()` | `FastSenseGrid` | Speedup |
|--------|------------|-----------------|---------|
| 1×1    | 0.195 s    | 0.187 s         | 1.0×    |
| 2×2    | 0.451 s    | 0.377 s         | 1.2×    |
| 3×3    | 0.964 s    | 0.709 s         | 1.4×    |

Each [[FastSenseGrid]] tile downsamples independently to ~4K points regardless of the raw data size, so rendering cost stays nearly flat. Traditional approaches scale linearly with total point count.

## MEX Acceleration

Compiled MEX kernels provide substantial acceleration for core operations:

| Operation (10M points) | MATLAB    | MEX       | Speedup |
|------------------------|-----------|-----------|---------|
| Binary search          | ~1 ms     | ~0.05 ms  | 20×     |
| MinMax downsampling    | ~25 ms    | ~7 ms     | 3.5×    |
| LTTB downsampling      | ~200 ms   | ~4 ms     | 50×     |
| Violation detection    | ~50 ms    | ~2 ms     | 25×     |

MEX kernels use SIMD instructions (AVX2 on x86-64, NEON on ARM64) to process multiple doubles per CPU cycle. Build them with:

```matlab
build_mex();
```

This detects your platform, selects the best SIMD flags, and compiles all kernels into the `private/` folder. See [[MEX Acceleration]] for details.

## Measuring Your Own Data

You can benchmark FastSense on your system with a short script:

```matlab
% Create a large noisy signal
x = (1:1e7)';
y = cumsum(randn(1e7,1));

fp = FastSense();
fp.addLine(x, y);

tic;
fp.render();
fprintf('Render time: %.3f s\n', toc);
```

For stress‑testing, create a grid of tiles:

```matlab
fig = FastSenseGrid(2, 2);
fig.tile(1).addLine(x, y);
fig.tile(2).addLine(x, y);
fig.tile(3).addLine(x, y);
fig.tile(4).addLine(x, y);

tic;
fig.renderAll();
fprintf('Dashboard render: %.3f s\n', toc);
```

## Why FastSense is Fast

### 1. Downsample to Screen Resolution

Only the [~4,000 pixels visible on‑screen](https://en.wikipedia.org/wiki/Retina_display) worth of points are drawn. A 100M‑point dataset uses the same GPU memory as a 4K dataset once downsampled.

```matlab
fp = FastSense('DownsampleFactor', 2);  % default: 2 pts per pixel
```

### 2. Binary Search for Range Queries

Panning and zooming trigger range lookups. The O(log N) [[binary_search]] function avoids scanning the full array:

```matlab
idx = binary_search(x, xValue, 'left');   % first index where x >= xValue
idx = binary_search(x, xValue, 'right');  % last  index where x <= xValue
```

### 3. Lazy Multi‑Level Pyramid

A pre‑computed pyramid of coarsened levels (100×, 10 000×, …) means that zooming out never touches the raw data. The pyramid is built incrementally as needed, not all at render time.

```matlab
fp = FastSense('PyramidReduction', 100);  % default compression per level
```

### 4. SIMD‑Optimized MEX Kernels

Compiled C implementations use vectorised instructions to process multiple data points per CPU cycle:
- **AVX2** on x86‑64: processes 4 doubles simultaneously
- **NEON** on ARM64: processes 2–4 elements per cycle

Always call `build_mex()` to compile the platform‑specific kernels.

### 5. Fused Operations

Multiple tasks are combined into single passes over the data:
- Violation detection + pixel coordinate culling
- Downsampling + threshold line intersection
- Range lookup + metadata forwarding

### 6. Direct Graphics Updates

Line data is updated via fast `XData`/`YData` assignment, avoiding object recreation or property listeners — the shortest path through MATLAB’s graphics system.

### 7. Frame Rate Limiting

`drawnow limitrate` caps display refresh at 20 fps, preventing GPU thrashing during rapid zoom/pan sequences.

## Performance Tuning Options

Several properties let you trade speed for quality:

```matlab
fp = FastSense();

% Increase points per pixel for denser traces (default: 2)
fp.DownsampleFactor = 4;

% Adjust pyramid granularity (default: 100)
fp.PyramidReduction = 50;

% Switch downsampling algorithm
fp.DefaultDownsampleMethod = 'lttb';   % preserves visual shape
fp.DefaultDownsampleMethod = 'minmax'; % preserves extremes

% Control when downsampling kicks in (default: 5000)
fp.MinPointsForDownsample = 10000;
```

Set these before calling `render()` — changes after rendering have no effect.

## Memory Management

FastSense can automatically switch between in‑memory and disk‑backed storage using [[FastSenseDataStore]]:

```matlab
fp = FastSense();

% Force storage mode (default: 'auto')
fp.StorageMode = 'memory';   % always keep data in RAM
fp.StorageMode = 'disk';     % always store in SQLite

% Adjust memory threshold for 'auto' mode (default: 500 MB)
fp.MemoryLimit = 1e9;        % 1 GB
```

In `'auto'` mode, any line exceeding `MemoryLimit` is transparently offloaded to disk. Zoom/pan still work because [[FastSenseDataStore]] reads only the chunks that overlap the view window.

## Monitoring Performance

Enable verbose output to see per‑line timing:

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

The internal [[ConsoleProgressBar]] can be used in your own batch operations:

```matlab
pb = ConsoleProgressBar();
pb.start();
for k = 1:1000
    % … processing …
    pb.update(k, 1000, 'Processing');
end
pb.finish();
```

## Batch Rendering

For headless or batch workflows, suppress intermediate draws and the progress bar:

```matlab
fp = FastSense();
fp.DeferDraw = true;      % skip drawnow during render
fp.ShowProgress = false;  % hide console bar
fp.addLine(x, y);
fp.render();
drawnow;                  % single drawnow when ready
```

This can measurably improve throughput for very large datasets.

## See Also

- [[FastSense]] — full API reference for the main plotting object
- [[FastSenseGrid]] — tiled dashboards with independent downsampling
- [[FastSenseDataStore]] — disk‑based storage for huge datasets
- [[ConsoleProgressBar]] — progress bar used internally
- [[MEX Acceleration]] — details on SIMD compilation and `build_mex`
- [[Architecture]] — internal design of the downsampling pipeline
- [[binary_search]] — the O(log N) search routine used throughout
