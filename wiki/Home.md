# FastPlot

Ultra-fast time series plotting for MATLAB and GNU Octave.

FastPlot enables fluid interactive visualization of massive datasets (1K to 100M+ points). It dynamically downsamples data to screen resolution on every zoom/pan interaction, rendering only ~4,000 points regardless of dataset size. This eliminates GPU memory bottlenecks and keeps the UI responsive at 200+ FPS.

## Key Metrics

| Metric | Value |
|--------|-------|
| 10M point zoom cycle | 4.7 ms (212 FPS) |
| Point reduction | 99.96% (10M to ~4K displayed) |
| GPU memory (10M pts) | 0.06 MB vs 153 MB for plot() |
| Implementation | Pure MATLAB + optional C MEX (AVX2/NEON SIMD) |

## Features

- **Smart downsampling** — per-pixel MinMax and LTTB algorithms, auto-selected per zoom level
- **Lazy pyramid cache** — multi-resolution pre-computation for instant zoom-out on 50M+ datasets
- **MEX acceleration** — optional C with SIMD (AVX2/NEON), auto-fallback to pure MATLAB
- **Dashboard layouts** — tiled grids (FastPlotFigure) and tabbed containers (FastPlotDock)
- **Interactive toolbar** — data cursor, crosshair, grid/legend toggle, autoscale, PNG export
- **6 built-in themes** — default, dark, light, industrial, scientific, ocean (with colorblind palette)
- **Linked axes** — synchronized zoom/pan across subplots
- **Datetime support** — datenum and MATLAB datetime with auto-formatting tick labels
- **NaN gap handling** — seamless visualization of missing data regions
- **Uneven sampling** — works with any monotonically increasing X (no uniform spacing required)
- **Sensor system** — state-dependent thresholds with condition-based rules and violation markers
- **Event detection** — group violations into events with statistics, Gantt viewer, click-to-plot
- **Live mode** — file polling with auto-refresh (preserve/follow/reset view modes)
- **Console progress bars** — hierarchical progress display during batch rendering
- **Disk-backed storage** — SQLite-backed chunked DataStore for 100M+ point datasets that exceed memory
- **Navigator overlay** — minimap zoom navigator for quick orientation
- **Sensor detail view** — specialized plot with state bands and threshold context

## Quick Start

```matlab
setup;

% Basic plot with 10M points
fp = FastPlot('Theme', 'dark');
x = linspace(0, 100, 1e7);
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.render();
```

```matlab
% Dashboard with tiled layout
fig = FastPlotFigure(2, 2, 'Theme', 'dark');
fig.setTileSpan(1, [1 2]);

fp1 = fig.tile(1);
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'Alarm');
fig.tileTitle(1, 'Pressure Monitor');

fp2 = fig.tile(2);
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fig.tileTitle(2, 'Temperature');

fig.renderAll();
```

```matlab
% Sensor with state-dependent thresholds
s = Sensor('pressure', 'Name', 'Chamber Pressure');
s.X = linspace(0, 100, 1e6);
s.Y = randn(1, 1e6) * 10 + 50;

sc = StateChannel('machine');
sc.X = [0 30 60 80]; sc.Y = [0 1 2 1];
s.addStateChannel(sc);
s.addThresholdRule(struct('machine', 1), 70, 'Direction', 'upper', 'Label', 'Run HI');
s.resolve();

fp = FastPlot('Theme', 'industrial');
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
```

## Requirements

- MATLAB R2020b+ or GNU Octave 7+
- C compiler (optional) for MEX acceleration
- No toolbox dependencies

## Libraries

FastPlot consists of five libraries:

| Library | Path | Description |
|---------|------|-------------|
| FastPlot | `libs/FastPlot/` | Core plotting engine, dashboard layouts, toolbar, themes, disk-backed storage |
| SensorThreshold | `libs/SensorThreshold/` | Sensor data containers, state channels, threshold rules |
| EventDetection | `libs/EventDetection/` | Event detection, viewer UI, live pipeline, notifications |
| Dashboard | `libs/Dashboard/` | Serializable dashboard engine with JSON persistence |
| WebBridge | `libs/WebBridge/` | TCP server for web-based visualization |

## Wiki Navigation

**Getting Started**
- [[Installation]] — setup, MEX compilation, verification
- [[Getting Started]] — tutorial with code examples

**API Reference**
- [[FastPlot|API Reference: FastPlot]] — core plotting class
- [[Dashboard|API Reference: Dashboard]] — FastPlotFigure, FastPlotDock, FastPlotToolbar
- [[Themes|API Reference: Themes]] — theme presets, customization, color palettes
- [[Sensors|API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule, SensorRegistry (with printTable and viewer)
- [[Event Detection|API Reference: Event Detection]] — EventDetector, Event, EventConfig, EventViewer (with Gantt hover tooltips)
- [[Utilities|API Reference: Utilities]] — ConsoleProgressBar, FastPlotDefaults

**Guides**
- [[Live Mode Guide]] — file polling, view modes, live dashboards
- [[Datetime Guide]] — working with time series data
- [[Dashboard Engine Guide]] — DashboardEngine + DashboardBuilder usage

**Internals**
- [[Architecture]] — render pipeline, zoom callback, data flow
- [[MEX Acceleration]] — SIMD details, build, fallback
- [[Performance]] — benchmarks and optimization tips
- [[Examples]] — categorized guide to 40+ runnable examples
