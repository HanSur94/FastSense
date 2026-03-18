# FastSense

[![Tests](https://github.com/HanSur94/FastSense/actions/workflows/tests.yml/badge.svg)](https://github.com/HanSur94/FastSense/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/HanSur94/FastSense/graph/badge.svg)](https://codecov.io/gh/HanSur94/FastSense)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b%2B-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![Octave](https://img.shields.io/badge/GNU%20Octave-7%2B-blue.svg)](https://octave.org)

Ultra-fast time series plotting for MATLAB and GNU Octave. Plot 100M+ data points with fluid zoom and pan — rendering only ~4,000 points at any zoom level.

<p align="center">
  <img src="docs/images/dashboard.png" alt="FastSense Dashboard" width="800">
</p>

## Performance

Benchmarked on Apple M4 with GNU Octave 11, 10M data points:

| Operation | Time |
|---|---|
| MinMax downsample (MEX) | 7.4 ms |
| Full zoom cycle (2 thresholds) | 4.7 ms |
| Effective zoom FPS | **212 FPS** |
| Point reduction | 99.96% |
| GPU memory (10M pts) | 0.06 MB vs 153 MB for `plot()` |

## Features

- **Smart downsampling** — per-pixel MinMax and LTTB, auto-selected per zoom level
- **MEX acceleration** — optional C with SIMD (AVX2/NEON), auto-fallback to pure MATLAB
- **Dashboard layouts** — tiled grids, tabbed containers, serializable dashboard engine
- **Sensor system** — state-dependent thresholds with condition-based rules
- **Event detection** — violation grouping, Gantt viewer, live pipeline, notifications
- **Disk-backed storage** — SQLite-backed DataStore for 100M+ datasets exceeding memory
- **6 built-in themes** — dark, light, industrial, scientific, ocean (colorblind palette)
- **Linked axes** — synchronized zoom/pan across subplots
- **Datetime support** — datenum and MATLAB datetime with auto-formatting
- **Live mode** — file polling with auto-refresh
- **Navigator overlay** — minimap for quick orientation
- **Interactive toolbar** — data cursor, crosshair, grid toggle, PNG export

## Quick Start

```matlab
setup;  % adds libraries to path + compiles MEX

x = linspace(0, 100, 1e7);
y = sin(x) + 0.1 * randn(size(x));

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
% → zoom and pan interactively at 200+ FPS
```

## Installation

```bash
git clone https://github.com/HanSur94/FastSense.git
cd FastSense
```

Then in MATLAB or Octave:

```matlab
setup;  % adds paths + compiles MEX accelerators (requires C compiler)
```

No toolbox dependencies. MEX compilation is optional — pure MATLAB fallbacks are used automatically if no C compiler is available.

**Requirements:** MATLAB R2020b+ or GNU Octave 7+

## Documentation

Full documentation is available in the [Wiki](https://github.com/HanSur94/FastSense/wiki):

- [Getting Started](https://github.com/HanSur94/FastSense/wiki/Getting-Started) — tutorial with examples
- [API Reference: FastSense](https://github.com/HanSur94/FastSense/wiki/API-Reference:-FastSense) — core plotting class
- [API Reference: Dashboard](https://github.com/HanSur94/FastSense/wiki/API-Reference:-Dashboard) — layouts, widgets, engine
- [API Reference: Sensors](https://github.com/HanSur94/FastSense/wiki/API-Reference:-Sensors) — sensor system
- [API Reference: Event Detection](https://github.com/HanSur94/FastSense/wiki/API-Reference:-Event-Detection) — event pipeline
- [Architecture](https://github.com/HanSur94/FastSense/wiki/Architecture) — render pipeline, data flow
- [MEX Acceleration](https://github.com/HanSur94/FastSense/wiki/MEX-Acceleration) — SIMD details
- [Performance](https://github.com/HanSur94/FastSense/wiki/Performance) — benchmarks

## Examples

See the [`examples/`](examples/) directory for 40+ runnable scripts covering basic plotting, dashboards, sensors, event detection, live mode, and disk-backed storage. A categorized guide is in the [wiki](https://github.com/HanSur94/FastSense/wiki/Examples).

## Libraries

| Library | Path | Description |
|---------|------|-------------|
| FastSense | `libs/FastSense/` | Core plotting engine, layouts, toolbar, themes, disk storage |
| SensorThreshold | `libs/SensorThreshold/` | Sensor containers, state channels, threshold rules |
| EventDetection | `libs/EventDetection/` | Event detection, viewer, live pipeline, notifications |
| Dashboard | `libs/Dashboard/` | Dashboard engine with widgets and JSON persistence |
| WebBridge | `libs/WebBridge/` | TCP server for web-based visualization |

## Contributing

Contributions are welcome! Please open an issue to discuss your idea before submitting a pull request. See the [wiki](https://github.com/HanSur94/FastSense/wiki) for architecture details and API references.

## Citation

If you use FastSense in your research, please cite it:

```bibtex
@software{fastsense,
  author = {Suhr, Hannes},
  title = {FastSense: Ultra-Fast Time Series Plotting for MATLAB and GNU Octave},
  url = {https://github.com/HanSur94/FastSense},
  license = {MIT}
}
```

See [`CITATION.cff`](CITATION.cff) for the full citation metadata.

## License

[MIT](LICENSE) — Hannes Suhr
