<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# FastPlot

Ultra‑fast time series plotting for MATLAB and GNU Octave with dynamic downsampling, sensor monitoring, and dashboard layouts.

## Key Metrics

| Metric | Value |
|--------|-------|
| 10M point zoom cycle | 4.7 ms (212 FPS) |
| Point reduction | 99.96% (10M to ~4K displayed) |
| GPU memory (10M pts) | 0.06 MB vs 153 MB for `plot()` |
| Implementation | Pure MATLAB + optional C MEX (AVX2 / NEON SIMD) |
| Minimum MATLAB version | R2020b+ (Octave 7+) |
| Toolbox dependencies | None |

## Library Components

FastPlot consists of five integrated libraries:

| Library | Description |
|---------|-------------|
| **FastSense** | Core plotting engine with dynamic MinMax / LTTB downsampling, pyramid cache, linked zoom, threshold lines, live mode, disk‑backed storage (`FastSenseDataStore`), and interactive toolbar. |
| **Dashboard** | Widget‑based dashboard engine (`DashboardEngine`) with 8+ widget types, 24‑column responsive grid, edit mode (`DashboardBuilder`), and JSON persistence. Includes `FastSenseGrid` for tiled FastSense layouts. |
| **SensorThreshold** | Tag‑based sensor data containers (`SensorTag`, `StateTag`), derived signals (`MonitorTag`, `CompositeTag`, `DerivedTag`), thresholding, `TagRegistry` catalog, and live/batch ingestion pipelines. |
| **EventDetection** | Event detection from threshold violations, `EventStore` with SQLite cluster support, `EventViewer` (Gantt timeline), live pipeline, email notifications, and snapshot generation. |
| **WebBridge** | TCP server + NDJSON protocol relay that exposes FastPlot data and actions to external web/API clients. |

## Quick Start

```matlab
install;          % add paths, compile MEX if needed

% ---- Basic plot with a sensor tag ----
st = SensorTag('pressure', ...
               'X', linspace(0, 100, 1e7), ...
               'Y', sin(linspace(0, 100, 1e7)) + 0.1*randn(1,1e7));
fp = FastSense('Theme', 'dark');
fp.addTag(st, 'DisplayName', 'Pressure');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'Hi');
fp.render();
```

## Requirements

- MATLAB R2020b or later, or GNU Octave 7+
- A C compiler (optional — enables MEX acceleration; pure‑MATLAB fallback always available)
- No additional toolboxes required

## Getting Started

Start with the [[Installation]] guide to set up FastPlot and compile MEX for your platform. Then follow the [[Getting Started]] tutorial for step‑by‑step examples covering core plotting, dashboards, sensor tags, and live mode.

## API Reference

**Core Classes**
- [[API Reference: FastPlot]] – main plotting engine: `FastSense`, `FastSenseGrid`, `FastSenseDock`, `FastSenseDataStore`, `FastSenseToolbar`
- [[API Reference: Dashboard]] – widget‑based dashboards: `DashboardEngine`, `DashboardLayout`, `DashboardBuilder`, widget types
- [[API Reference: Themes]] – theme presets, color palettes, and customization (`FastSenseTheme`, `DashboardTheme`)
- [[API Reference: Sensors]] – tag‑based sensors: `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `DerivedTag`, `TagRegistry`
- [[API Reference: Event Detection]] – events, storage, and viewer: `Event`, `EventStore`, `EventViewer`, `LiveEventPipeline`, `NotificationService`
- [[API Reference: Utilities]] – progress bars, defaults, binary search helpers

**Specialized Guides**
- [[Live Mode Guide]] – file polling, view modes, and live dashboards
- [[Datetime Guide]] – working with absolute time axes
- [[Dashboard Engine Guide]] – building and customising widget‑based dashboards
- [[Examples]] – 40+ runnable examples covering all library features
