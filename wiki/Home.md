<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# FastPlot

Ultra-fast time series plotting for MATLAB and GNU Octave with dynamic downsampling, sensor monitoring, and dashboard layouts.

## Key Metrics

| Metric | Value |
|--------|-------|
| 10M point zoom cycle | 4.7 ms (212 FPS) |
| Point reduction | 99.96% (10M to ~4K displayed) |
| GPU memory (10M pts) | 0.06 MB vs 153 MB for plot() |
| Implementation | Pure MATLAB + optional C MEX (AVX2/NEON SIMD) |

## Library Components

FastPlot consists of five integrated libraries:

| Library | Description |
|---------|-------------|
| **FastSense** | Core plotting engine with dynamic downsampling (MinMax/LTTB), dashboard layouts (FastSenseGrid, FastSenseDock), interactive toolbar, themes, and disk-backed storage via FastSenseDataStore |
| **Dashboard** | Widget-based dashboard engine with 8 widget types, 24-column responsive grid, edit mode, and JSON persistence |
| **SensorThreshold** | Tag-based sensor data containers (SensorTag, StateTag, MonitorTag, CompositeTag) with TagRegistry catalog and batch/live data pipelines |
| **EventDetection** | Event detection from threshold violations, EventViewer with Gantt timeline, live pipeline with notifications |
| **WebBridge** | TCP server for web-based visualization with NDJSON protocol |

## Features

- **Smart downsampling** — per-pixel MinMax and LTTB algorithms, auto-selected per zoom level
- **Pyramid cache** — multi-resolution pre-computation for instant zoom-out on 50M+ datasets  
- **MEX acceleration** — optional C with SIMD (AVX2/NEON), auto-fallback to pure MATLAB
- **Dashboard layouts** — tiled grids (FastSenseGrid) and tabbed containers (FastSenseDock)
- **Interactive toolbar** — data cursor, crosshair, grid/legend toggle, autoscale, PNG export
- **6 built-in themes** — default, dark, light, industrial, scientific, ocean
- **Linked axes** — synchronized zoom/pan across subplots
- **Tag system** — unified sensor/state/monitor/composite data model with TagRegistry
- **Event detection** — group violations into events with statistics, Gantt viewer, click-to-plot
- **Live mode** — file polling with auto-refresh (preserve/follow/reset view modes)
- **Disk-backed storage** — SQLite-backed chunked DataStore for 100M+ point datasets

## Quick Start

```matlab
% Basic plot with 10M points
fp = FastSense('Theme', 'dark');
x = linspace(0, 100, 1e7);
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.render();
```

```matlab
% Dashboard with tiled layout
fig = FastSenseGrid(2, 2, 'Theme', 'dark');
fig.setTileSpan(1, [1 2]);

fp1 = fig.tile(1);
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'Alarm');
fig.setTileTitle(1, 'Pressure Monitor');

fp2 = fig.tile(2);
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fig.renderAll();
```

```matlab
% Tag-based sensor with monitor
st = SensorTag('pressure', 'Name', 'Chamber Pressure');
st.updateData(linspace(0, 100, 1e6), randn(1, 1e6) * 10 + 50);
TagRegistry.register('pressure', st);

mt = MonitorTag('pressure_hi', st, @(x, y) y > 70, 'MinDuration', 5);
TagRegistry.register('pressure_hi', mt);

fp = FastSense('Theme', 'industrial');
fp.addTag(st);
fp.addTag(mt);
fp.render();
```

```matlab
% Widget-based dashboard
d = DashboardEngine('Process Monitor', 'Theme', 'dark');
d.addWidget('fastsense', 'Title', 'Temperature', 'Position', [1 1 12 4], 'Tag', tempTag);
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [13 1 6 2], 'Tag', pressTag, 'Range', [0 100]);
d.addWidget('status', 'Title', 'Pump Status', 'Position', [19 1 6 2], 'Tag', pumpTag);
d.render();
```

## Requirements

- MATLAB R2020b+ or GNU Octave 7+
- C compiler (optional) for MEX acceleration
- No toolbox dependencies

## Getting Started

Start with the [[Installation]] guide to set up FastPlot and compile MEX acceleration. Then follow the [[Getting Started]] tutorial for step-by-step examples covering basic plotting, dashboards, sensors, and live mode.

## API Reference

**Core Classes**
- [[API Reference: FastPlot]] — main plotting engine with dynamic downsampling
- [[API Reference: Dashboard]] — FastSenseGrid, FastSenseDock, FastSenseToolbar
- [[API Reference: Sensors]] — Tag, SensorTag, StateTag, MonitorTag, TagRegistry
- [[API Reference: Event Detection]] — EventDetector, EventViewer, LiveEventPipeline
- [[API Reference: Themes]] — theme presets, customization, color palettes
- [[API Reference: Utilities]] — ConsoleProgressBar, FastSenseDefaults

**Specialized Guides**
- [[Live Mode Guide]] — file polling, view modes, live dashboards
- [[Dashboard Engine Guide]] — DashboardEngine with widget-based dashboards
- [[Datetime Guide]] — working with time series data
- [[Examples]] — 40+ categorized runnable examples
