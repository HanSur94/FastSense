# Performance

Benchmarks measured on Apple M4 with GNU Octave 11.

## Key Metrics

| Metric | Value |
|--------|-------|
| 10M point zoom cycle | 4.7 ms |
| Effective zoom FPS | 212 FPS |
| Point reduction | 99.96% (10M to ~4K) |
| GPU memory (10M points) | 0.06 MB vs 153 MB for plot() |

## FastPlot vs plot()

| Points | plot() render | FastPlot render | Speedup |
|--------|--------------|----------------|---------|
| 10K | instant | instant | - |
| 100K | moderate | instant | ~5x |
| 1M | slow | fast | ~10x |
| 10M | very slow | 0.19 s | ~50x |
| 100M | often fails | works | - |

The key advantage is not just initial render time but interactive performance — plot() with 10M points makes zoom/pan unusable, while FastPlot maintains sub-5ms response.

## Dashboard Performance

With 10M points per tile:

| Layout | subplot() | FastPlotFigure | Speedup |
|--------|-----------|---------------|---------|
| 1x1 | 0.195 s | 0.187 s | 1.0x |
| 2x2 | 0.451 s | 0.377 s | 1.2x |
| 3x3 | 0.964 s | 0.709 s | 1.4x |

Advantage grows with tile count — downsampled rendering cost stays flat while subplot() scales linearly with total points.

## MEX vs Pure MATLAB

| Operation (10M points) | MATLAB | MEX | Speedup |
|------------------------|--------|-----|---------|
| Binary search | ~1 ms | ~0.05 ms | 20x |
| MinMax downsample | ~25 ms | ~7 ms | 3.5x |
| LTTB downsample | ~200 ms | ~4 ms | 50x |

## Running Benchmarks

```matlab
setup;
cd examples

% FastPlot vs plot() comparison
benchmark;

% Per-frame zoom latency
benchmark_zoom;

% Feature-specific benchmarks
benchmark_features;

% Sensor.resolve() performance
benchmark_resolve;
```

## Why It's Fast

1. **Downsample to screen resolution**: Only ~4,000 points rendered regardless of dataset size
2. **Binary search**: O(log N) visible range lookup instead of scanning
3. **Lazy pyramid**: Pre-computed multi-resolution cache avoids touching raw data at zoom-out
4. **SIMD MEX**: Vectorized C code processes 4 doubles per CPU cycle
5. **Fused operations**: Violation detection + pixel culling in single pass
6. **Dot notation updates**: Direct XData/YData assignment (fastest MATLAB path)
7. **drawnow limitrate**: Caps display refresh at 20 FPS to prevent GPU thrashing
