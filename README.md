# FastSense

[![Tests](https://github.com/HanSur94/FastSense/actions/workflows/tests.yml/badge.svg)](https://github.com/HanSur94/FastSense/actions/workflows/tests.yml)
[![Benchmark](https://github.com/HanSur94/FastSense/actions/workflows/benchmark.yml/badge.svg)](https://hansur94.github.io/FastSense/dev/bench/)
[![codecov](https://codecov.io/gh/HanSur94/FastSense/graph/badge.svg)](https://codecov.io/gh/HanSur94/FastSense)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![MATLAB](https://img.shields.io/badge/MATLAB-R2020b%2B-orange.svg)](https://www.mathworks.com/products/matlab.html)
[![Octave](https://img.shields.io/badge/GNU%20Octave-7%2B-blue.svg)](https://octave.org)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20macOS%20%7C%20Windows-lightgrey.svg)](#installation)

**200+ FPS. 100M+ points. Zero toolbox dependencies.**

Sensor monitoring and dashboarding platform for MATLAB and GNU Octave. Plot massive time series with SIMD-accelerated downsampling, define state-dependent threshold rules, detect violations in real time, and compose interactive dashboards with 21 widget types — all in pure MATLAB.

<p align="center">
  <img src="docs/images/dashboard.png" alt="FastSense Dashboard" width="800">
</p>

## Quick Start

```matlab
install;  % adds libraries to path + compiles MEX (run once)

x = linspace(0, 100, 1e7);
y = sin(x) + 0.1 * randn(size(x));

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

Build a full dashboard in under 10 lines:

```matlab
d = DashboardEngine('Process Monitor');
d.addWidget('fastsense', 'Position', [1 1 16 8]);
d.addWidget('number',    'Position', [17 1 8 4], 'Label', 'Peak');
d.addWidget('gauge',     'Position', [17 5 8 4], 'Label', 'Pressure');
d.render();
d.save('my_dashboard.json');  % reload later with DashboardEngine.load()
```

---

## Table of Contents

- [Why FastSense?](#why-fastsense)
- [Performance](#performance)
- [Features at a Glance](#features-at-a-glance)
- [Installation](#installation)
- [The Five Pillars](#the-five-pillars)
- [Examples](#examples)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [Citation](#citation)
- [License](#license)

---

## Why FastSense?

MATLAB's built-in `plot()` loads every data point into GPU memory and redraws the entire figure on each zoom or pan. For sensor data at 10M+ points, this means multi-second lag, memory exhaustion, or a crash.

FastSense solves three problems that no existing MATLAB toolbox addresses together:

- **Scale** — render 100M+ point datasets without loading them fully into memory, using SIMD-accelerated MinMax and LTTB downsampling that keeps only the pixels you can actually see
- **Context** — model real industrial sensors where alarm limits change based on machine state (idle vs. running vs. fault), not just static threshold values
- **Organization** — compose multi-widget monitoring dashboards with tabbed pages, collapsible sections, and detachable pop-out windows — without writing layout code

All of this runs in pure MATLAB with no toolbox requirements. MEX C extensions with AVX2/NEON SIMD are optional accelerators; pure MATLAB fallbacks are used automatically.

---

## Performance

FastSense vs. MATLAB's built-in `plot()` on 10M data points:

|  | `plot()` | FastSense |
|---|---|---|
| Render time | ~3.2 s | **4.7 ms** |
| Memory usage | 153 MB | **0.06 MB** |
| Zoom/pan FPS | ~2 FPS | **212 FPS** |
| Points displayed | 10,000,000 | ~400 (perceptually identical) |

<sub>MacBook Pro M1 Pro, 16 GB, GNU Octave 11, MEX+NEON. Point reduction: 99.96%. Performance is tracked on every commit — regressions trigger alerts. <a href="https://hansur94.github.io/FastSense/dev/bench/">Live benchmark charts</a></sub>

---

## Features at a Glance

**Time Series Engine** — Render 10M+ points at 200+ FPS with automatic per-pixel downsampling. MinMax and LTTB algorithms, linked axes, datetime support, 6 built-in themes. Optional MEX C acceleration (AVX2/NEON) with pure-MATLAB fallback.

**Sensor Modeling** — State-dependent threshold rules where alarm limits change based on machine state. Automatic violation grouping, statistics, and a sensor registry for predefined catalogs.

**Dashboard Engine** — 21 widget types on a 24-column responsive grid. Multi-page navigation, collapsible sections, detachable pop-out widgets, per-widget info tooltips. JSON persistence and live mode with synchronized refresh.

**Event Detection** — Groups threshold violations into discrete events with debouncing. Peak, mean, RMS, duration statistics per event. Real-time file polling pipeline with interactive Gantt timeline viewer.

**Browser Visualization** — TCP bridge from MATLAB to a FastAPI + uPlot web frontend. Bidirectional callbacks between MATLAB and browser.

---

## Installation

```bash
git clone https://github.com/HanSur94/FastSense.git
cd FastSense
```

Then in MATLAB or Octave:

```matlab
install;  % adds paths + compiles MEX accelerators
```

No toolbox dependencies. No internet required. MEX compilation is optional — pure MATLAB fallbacks are used automatically if no C compiler is available.

**Requirements:** MATLAB R2020b+ or GNU Octave 7+ | Linux, macOS, or Windows

---

## The Five Pillars

### FastSense — Ultra-Fast Time Series Engine

The core plotting engine. Renders 10M+ data points with automatic downsampling (MinMax and LTTB), dynamic thresholds, and interactive zoom/pan — all at 200+ FPS. See [Performance](#performance) for benchmarks.

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Noisy Sine');
fp.addThreshold(2.0, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', 'r', 'Label', 'Alarm Hi');
fp.addThreshold(-2.0, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', 'r', 'Label', 'Alarm Lo');
fp.render();
```

- **Smart downsampling** — per-pixel MinMax and LTTB, auto-selected per zoom level
- **MEX acceleration** — optional C with SIMD (AVX2/NEON), auto-fallback to pure MATLAB
- **Linked axes** — synchronized zoom/pan across subplots
- **Datetime support** — datenum and MATLAB datetime with auto-formatting
- **6 built-in themes** — dark, light, industrial, scientific, ocean, colorblind
- **SQLite-backed storage** — disk-backed DataStore for 100M+ datasets exceeding memory

---

### SensorThreshold — State-Dependent Sensor Modeling

Bundles time-series data with discrete system states and condition-based threshold rules. A running machine has different alarm limits than an idle one — SensorThreshold models exactly that.

```matlab
s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101);
s.X = t;  s.Y = pressure_data;

sc = StateChannel('machine_state');
sc.X = [0 25 50 75];  sc.Y = [0 1 2 1];  % idle->running->error->running
s.addStateChannel(sc);

s.addThresholdRule(struct('machine_state', 1), 55, ...
    'Direction', 'upper', 'Label', 'HH (running)');
s.resolve();
```

- **State channels** — discrete system states (idle, running, error) as zero-order-hold lookups
- **Condition-based rules** — thresholds that activate only when conditions match
- **Automatic violation grouping** — pre-computed during `resolve()`
- **Sensor registry** — predefined sensor catalog for quick setup

---

### EventDetection — Violation Detection and Live Pipeline

Groups threshold violations into discrete events with statistics, live monitoring, and notifications. Detects when sensors exceed limits, how long, and how severe.

```matlab
cfg = EventConfig();
cfg.MinDuration = 0.5;
cfg.addSensor(sTemp);
cfg.addSensor(sPres);
cfg.setColor('temp warning', [1.0 0.8 0.0]);
events = cfg.runDetection();
```

- **Event grouping** — consecutive violations merged into events with debouncing
- **Statistics** — peak, mean, RMS, std, duration automatically computed per event
- **Live pipeline** — real-time file polling with streaming event detection
- **Gantt viewer** — interactive timeline UI for event exploration
- **Notifications** — event-triggered callbacks for alerting

---

### Dashboard — Widget-Based Dashboard Engine

Build monitoring dashboards from composable widgets on a 24-column grid. Supports live data, JSON persistence, multi-page navigation, collapsible sections, and 21 widget types.

```matlab
d = DashboardEngine('Process Monitoring');
d.Theme = 'light';
d.addWidget('fastsense', 'Position', [1 1 16 8], 'Sensor', sTemp);
d.addWidget('number',    'Position', [17 1 8 4], 'Sensor', sTemp, ...
    'Label', 'Temperature');
d.addWidget('gauge',     'Position', [17 5 8 4], 'Sensor', sPres, ...
    'Label', 'Pressure');
d.render();
d.save('dashboard.json');
```

**21 widget types:**
fastsense, number, status, gauge, table, text, barchart, heatmap, histogram, scatter, image, multistatus, eventtimeline, group, rawaxes, divider, markdown, iconcard, chipbar, sparklinecard, and collapsible group.

**Layout and organization features:**
- **24-column grid** — flexible positioning with `[col, row, width, height]` tuples
- **Multi-page navigation** — tabbed pages for organizing large dashboards
- **Collapsible sections** — fold/unfold grouped widgets with a single click
- **Detachable widgets** — pop any widget into its own independent figure window, live-mirrored from the dashboard
- **Info tooltips** — per-widget Markdown documentation shown on hover or click

**Data and persistence:**
- **JSON persistence** — save/load complete dashboard configurations
- **Live mode** — synchronized data refresh across all widgets on a configurable timer
- **Script export** — regenerate the dashboard as a `.m` script

---

### WebBridge — Browser-Based Visualization

Exposes dashboards to a web frontend over TCP. MATLAB stays the data engine; the browser handles rendering.

```matlab
bridge = WebBridge(dashboard);
bridge.serve();
bridge.registerAction('update_threshold', @myCallback);
```

- **TCP server** — bridges MATLAB dashboard to web/Electron frontend
- **Bidirectional callbacks** — actions and data-change notifications between MATLAB and browser
- **HTML5 charts** — uPlot-based rendering in the browser

---

## Examples

The [`examples/`](examples/) directory contains 40+ runnable scripts organized by topic:

| Category | Contents |
|---|---|
| [`01-basics/`](examples/01-basics/) | Core FastSense plotting, themes, linked axes, datetime |
| [`02-sensors/`](examples/02-sensors/) | Sensor modeling, state channels, threshold rules |
| [`03-dashboard/`](examples/03-dashboard/) | Dashboard layouts, live mode, multi-page, info tooltips |
| [`04-widgets/`](examples/04-widgets/) | One script per widget type (21 widget examples) |
| [`05-events/`](examples/05-events/) | Event detection, Gantt viewer, live pipeline |
| [`06-webbridge/`](examples/06-webbridge/) | Browser visualization setup |
| [`07-advanced/`](examples/07-advanced/) | Disk-backed DataStore, 100M+ point datasets |

A categorized guide is in the [wiki](https://github.com/HanSur94/FastSense/wiki/Examples).

---

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

---

## Contributing

Contributions are welcome! Here's how to get started:

1. **Report a bug** — open an [issue](https://github.com/HanSur94/FastSense/issues) with a minimal reproducer
2. **Suggest a feature** — open an issue to discuss before writing code
3. **Submit a fix** — fork, branch, and open a pull request

For architecture details and development setup, see the [Architecture wiki page](https://github.com/HanSur94/FastSense/wiki/Architecture). The test suite runs with `run_all_tests` in MATLAB/Octave.

---

## Citation

If you use FastSense in your research, please cite it:

```bibtex
@software{fastsense,
  author = {Suhr, Hannes},
  title = {FastSense: Sensor Monitoring and Dashboarding for MATLAB and GNU Octave},
  url = {https://github.com/HanSur94/FastSense},
  license = {MIT}
}
```

See [`CITATION.cff`](CITATION.cff) for the full citation metadata.

---

## License

[MIT](LICENSE) — Hannes Suhr
