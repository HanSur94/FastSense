# FastPlot

Ultra-fast time series plotting for MATLAB and GNU Octave. Plot 100M+ data points with fluid zoom and pan.

FastPlot dynamically downsamples your data to screen resolution on every zoom/pan interaction. Instead of pushing millions of points to the GPU, it renders only ~4000 points — preserving visual fidelity while keeping the UI responsive.

## Why FastPlot?

| | Standard `plot()` | FastPlot |
|---|---|---|
| 10M points render | Pushes all 10M to GPU | Downsamples to ~4K points |
| GPU memory | 153 MB | 0.06 MB |
| Zoom interaction | Re-renders all points | Binary search + re-downsample visible range |
| Threshold markers | Manual implementation | Built-in with violation highlighting |
| Linked subplots | `linkaxes` (no re-downsample) | Synchronized zoom with per-subplot re-downsample |

## Performance

Benchmarked on Apple M4 with GNU Octave 11, 10M data points:

| Operation | Time |
|---|---|
| MinMax downsample (MEX) | 7.4 ms |
| Full zoom cycle (2 thresholds) | 4.7 ms |
| Effective zoom FPS | **212 FPS** |
| Point reduction | 99.96% |

## Quick Start

```matlab
addpath('FastPlot');

% Generate data
x = linspace(0, 100, 1e7);
y = sin(x * 2*pi / 10) + 0.5 * randn(1, numel(x));

% Plot with thresholds
fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Sensor1', 'Color', 'b');
fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'r');
fp.render();
```

Zoom and pan interactively — FastPlot re-downsamples automatically.

## Installation

```bash
git clone https://github.com/HanSur94/FastPlot.git
```

```matlab
addpath('FastPlot');
```

No toolbox dependencies. Works out of the box with pure MATLAB code.

### Optional: Build MEX Accelerators

For maximum performance, compile the C MEX files with SIMD intrinsics:

```matlab
cd FastPlot
build_mex()
```

```
Architecture: arm64 (darwin25.2.0-aarch64)
Compiler: gcc-15 (GCC — preferred for auto-vectorization)
SIMD target: ARM NEON

Compiling binary_search_mex.c ... OK
Compiling minmax_core_mex.c ... OK
Compiling lttb_core_mex.c ... OK

3/3 MEX files compiled successfully.
```

Requires a C compiler (Xcode on macOS, GCC on Linux, MSVC on Windows). The build script auto-detects GCC for better optimization and falls back to the system compiler. Uses AVX2 on x86_64 and NEON on ARM64.

If MEX files are not compiled, FastPlot automatically uses the pure-MATLAB implementations — no functionality is lost.

## Requirements

- MATLAB R2020b+ or GNU Octave 7+
- C compiler (optional, for MEX acceleration)

## API Reference

### `FastPlot()` — Constructor

```matlab
fp = FastPlot();
fp = FastPlot('Parent', axesHandle);
fp = FastPlot('LinkGroup', 'group1');
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `Parent` | axes handle | Embed in existing axes (for subplots) |
| `LinkGroup` | string | ID for synchronized zoom/pan across instances |

### `addLine(x, y, ...)` — Add a Data Line

```matlab
fp.addLine(x, y);
fp.addLine(x, y, 'DisplayName', 'Pressure', 'Color', [0 0.45 0.74], 'LineWidth', 1.5);
fp.addLine(x, y, 'DownsampleMethod', 'lttb');
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `x` | double vector | (required) | Monotonically increasing X data |
| `y` | double vector | (required) | Y data (same length as x, NaN allowed) |
| `DisplayName` | string | `''` | Legend label |
| `Color` | RGB triplet or char | auto | Line color |
| `LineWidth` | scalar | `0.5` | Line width |
| `DownsampleMethod` | `'minmax'` or `'lttb'` | `'minmax'` | Downsampling algorithm |

Any standard MATLAB line property can be passed as a name-value pair.

**Downsampling methods:**
- **MinMax** (default) — Preserves exact min/max per pixel bucket. Best for detecting peaks, spikes, and threshold violations. Output is 2x the bucket count.
- **LTTB** (Largest Triangle Three Buckets) — Preserves visual shape by selecting points that maximize triangle area. Better for smooth signals where shape matters more than extremes.

### `addThreshold(value, ...)` — Add a Threshold Line

```matlab
fp.addThreshold(4.5);
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r');
fp.addThreshold(-2.0, 'Direction', 'lower', 'ShowViolations', true, 'Color', [1 0.5 0], 'LineStyle', ':');
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `value` | scalar | (required) | Threshold Y value |
| `Direction` | `'upper'` or `'lower'` | `'upper'` | Violation direction |
| `ShowViolations` | logical | `false` | Show circle markers at violations |
| `Color` | RGB triplet or char | `[0.8 0 0]` | Line and marker color |
| `LineStyle` | string | `'--'` | Line style |
| `Label` | string | `''` | Legend label |

### `render()` — Render the Plot

```matlab
fp.render();
```

Must be called after all lines and thresholds are added. Creates the figure, performs initial downsampling, installs zoom/pan listeners, and draws everything.

### Properties (read-only after render)

| Property | Description |
|----------|-------------|
| `fp.hFigure` | Handle to the figure window |
| `fp.hAxes` | Handle to the axes |
| `fp.Lines(i).hLine` | Handle to the i-th line graphics object |

## Linked Axes

Synchronize zoom and pan across multiple subplots:

```matlab
fig = figure('Position', [100 100 1200 800]);

% Top subplot
ax1 = subplot(2, 1, 1, 'Parent', fig);
fp1 = FastPlot('Parent', ax1, 'LinkGroup', 'sensors');
fp1.addLine(x, pressure, 'DisplayName', 'Pressure', 'Color', 'b');
fp1.render();

% Bottom subplot
ax2 = subplot(2, 1, 2, 'Parent', fig);
fp2 = FastPlot('Parent', ax2, 'LinkGroup', 'sensors');
fp2.addLine(x, temperature, 'DisplayName', 'Temperature', 'Color', 'r');
fp2.render();
```

Zooming on either subplot updates the other. Each subplot re-downsamples independently.

## Handling NaN Gaps

FastPlot handles missing data natively. NaN values in Y create visual gaps:

```matlab
y = sin(x);
y(1000:2000) = NaN;  % Sensor dropout
y(5000:5500) = NaN;  % Another gap

fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.render();
```

Each contiguous non-NaN segment is downsampled independently and rejoined with NaN separators.

## Uneven Sampling

No uniform spacing assumption. FastPlot works with any monotonically increasing X:

```matlab
% Event-driven acquisition: sparse monitoring + dense bursts
x_sparse = linspace(0, 100, 1000);      % 10 Hz
x_dense = linspace(30, 30.1, 10000);    % 100 kHz burst
x = sort([x_sparse, x_dense]);
y = interp1(x_sparse, randn(size(x_sparse)), x);

fp = FastPlot();
fp.addLine(x, y, 'DisplayName', 'Events');
fp.render();
```

## Examples

| Example | Description |
|---------|-------------|
| `example_basic.m` | 10M noisy sine wave with alarm thresholds |
| `example_100M.m` | 100M point stress test |
| `example_multi.m` | 5 sensor lines with shared threshold |
| `example_linked.m` | 3 linked subplots (pressure, temperature, vibration) |
| `example_nan_gaps.m` | Missing data with sensor dropouts |
| `example_alarm_bands.m` | Industrial 4-level alarm bands (HH/H/L/LL) |
| `example_lttb_vs_minmax.m` | Side-by-side downsampling comparison |
| `example_vibration.m` | 20M accelerometer data at 50 kHz |
| `example_ecg.m` | 5M ECG signal with arrhythmia detection |
| `example_multi_sensor_linked.m` | 4-channel linked monitoring dashboard |
| `example_uneven_sampling.m` | Variable-rate event-driven data |
| `benchmark.m` | FastPlot vs plot() performance comparison |
| `benchmark_zoom.m` | Per-frame zoom/pan latency analysis |

### Interactive demo

Opens all 10 example plots for interactive exploration. Zoom and pan on any figure as long as you want — press Enter to close all and exit:

```matlab
cd FastPlot/examples
demo_all
```

From the terminal (Octave):

```bash
cd FastPlot
octave --no-gui --eval "addpath('.'); addpath('private'); addpath('examples'); demo_all;"
```

### Run all examples (non-interactive)

```matlab
cd FastPlot/examples
run_all_examples
```

## Architecture

```
FastPlot.m                    Main class (constructor, addLine, addThreshold, render, zoom callbacks)
├── private/
│   ├── binary_search.m       O(log n) find visible range (MEX dispatch)
│   ├── minmax_downsample.m   NaN-aware MinMax downsampling (MEX dispatch)
│   ├── lttb_downsample.m     NaN-aware LTTB downsampling (MEX dispatch)
│   ├── compute_violations.m  Threshold violation detection
│   └── mex_src/
│       ├── simd_utils.h      SIMD abstraction (AVX2/SSE2/NEON/scalar)
│       ├── binary_search_mex.c
│       ├── minmax_core_mex.c
│       └── lttb_core_mex.c
├── build_mex.m               MEX compilation script
├── tests/                    12 test suites
└── examples/                 13 demos + benchmarks
```

**Zoom/pan pipeline:**

1. User zooms → XLim listener fires
2. `binary_search` finds visible data range — O(log n)
3. `minmax_downsample` reduces visible range to ~4000 points
4. `set(hLine, 'XData', xd, 'YData', yd)` updates the plot
5. Violation markers recomputed on downsampled data (~0.02ms)

## Running Tests

### All tests

From the MATLAB or Octave command window:

```matlab
cd FastPlot
addpath('tests'); addpath('private');
run_all_tests();
```

From the terminal (Octave):

```bash
cd FastPlot
octave --no-gui --eval "addpath('tests'); addpath('private'); run_all_tests();"
```

```
Running test_add_line...            PASSED
Running test_add_threshold...       PASSED
Running test_binary_search...       PASSED
Running test_compute_violations...  PASSED
Running test_linked_axes...         PASSED
Running test_lttb_downsample...     PASSED
Running test_mex_edge_cases...      PASSED
Running test_mex_parity...          PASSED
Running test_minmax_downsample...   PASSED
Running test_multi_threshold...     PASSED
Running test_render...              PASSED
Running test_zoom_pan...            PASSED

=== Results: 12/12 passed, 0 failed ===
```

### Single test

Run any individual test file directly:

```matlab
cd FastPlot
addpath('tests'); addpath('private');
test_zoom_pan;
```

From the terminal (Octave):

```bash
octave --no-gui --eval "addpath('tests'); addpath('private'); test_zoom_pan;"
```

Available test files: `test_add_line`, `test_add_threshold`, `test_binary_search`, `test_compute_violations`, `test_linked_axes`, `test_lttb_downsample`, `test_mex_edge_cases`, `test_mex_parity`, `test_minmax_downsample`, `test_multi_threshold`, `test_render`, `test_zoom_pan`.

## Benchmarks

### Render + zoom + memory benchmark

Compares FastPlot vs standard `plot()` across data sizes from 10K to 50M points:

```matlab
cd FastPlot/examples
benchmark;
```

From the terminal (Octave):

```bash
cd FastPlot
octave --no-gui --eval "addpath('.'); addpath('private'); addpath('examples'); benchmark;"
```

### Zoom/pan latency benchmark

Measures per-frame latency at multiple zoom levels with forced GPU flush:

```matlab
cd FastPlot/examples
benchmark_zoom;
```

From the terminal (Octave):

```bash
cd FastPlot
octave --no-gui --eval "addpath('.'); addpath('private'); addpath('examples'); benchmark_zoom;"
```

## License

MIT
