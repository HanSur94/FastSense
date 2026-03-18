# CI/CD Pipelines, README Overhaul & Wiki Refresh — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add GitHub Actions test + release pipelines, replace the 43KB README with a concise overview, update GitHub repo metadata, and refresh all 17 wiki pages.

**Architecture:** Two GitHub Actions workflow files for CI. README rewritten from scratch (~150 lines). Wiki pages updated in-place via the `wiki/` submodule directory (separate git repo). Repo metadata set via `gh repo edit`.

**Tech Stack:** GitHub Actions, GNU Octave, matlab-actions, softprops/action-gh-release, gh CLI

**Spec:** `docs/superpowers/specs/2026-03-16-ci-readme-wiki-design.md`

---

## Chunk 1: CI/CD Pipelines

### Task 1: Create Test Pipeline

**Files:**
- Create: `.github/workflows/tests.yml`

- [ ] **Step 1: Create the workflow directory and file**

Run: `mkdir -p .github/workflows`

```yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'  # Weekly Monday 6am UTC
  workflow_dispatch:

jobs:
  octave:
    name: Octave Tests
    if: github.event_name != 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Octave
        run: sudo apt-get update && sudo apt-get install -y octave

      - name: Run tests
        run: |
          octave --eval "cd('tests'); r = run_all_tests(); if r.failed > 0; exit(1); end"

  matlab:
    name: MATLAB Tests
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    continue-on-error: true
    steps:
      - uses: actions/checkout@v4

      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v2

      - name: Run tests
        uses: matlab-actions/run-command@v2
        with:
          command: "cd('tests'); r = run_all_tests(); assert(r.failed == 0, 'Tests failed');"
```

- [ ] **Step 2: Verify YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/tests.yml'))"`
Expected: No output (valid YAML)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/tests.yml
git commit -m "ci: add test pipeline with Octave (PR/push) and MATLAB (weekly)"
```

---

### Task 2: Create Release Pipeline

**Files:**
- Create: `.github/workflows/release.yml`

- [ ] **Step 1: Create the workflow file**

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: write

jobs:
  test:
    name: Gate Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Octave
        run: sudo apt-get update && sudo apt-get install -y octave

      - name: Run tests
        run: |
          octave --eval "cd('tests'); r = run_all_tests(); if r.failed > 0; exit(1); end"

  release:
    name: Create Release
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get version from tag
        id: version
        run: echo "VERSION=${GITHUB_REF_NAME}" >> "$GITHUB_OUTPUT"

      - name: Generate changelog
        id: changelog
        run: |
          PREV_TAG=$(git tag --sort=-v:refname | head -n 2 | tail -n 1)
          if [ -z "$PREV_TAG" ] || [ "$PREV_TAG" = "${GITHUB_REF_NAME}" ]; then
            CHANGELOG=$(git log --no-merges --pretty=format:"- %s (%h)" HEAD)
          else
            CHANGELOG=$(git log --no-merges --pretty=format:"- %s (%h)" "${PREV_TAG}..HEAD")
          fi
          echo "CHANGELOG<<EOF" >> "$GITHUB_OUTPUT"
          echo "$CHANGELOG" >> "$GITHUB_OUTPUT"
          echo "EOF" >> "$GITHUB_OUTPUT"

      - name: Package release
        run: |
          VERSION="${{ steps.version.outputs.VERSION }}"
          DIRNAME="FastSense-${VERSION}"
          mkdir -p "${DIRNAME}"

          # Copy release contents
          cp setup.m LICENSE README.md CITATION.cff "${DIRNAME}/"
          cp -r examples "${DIRNAME}/"

          # Copy libs, excluding compiled MEX binaries
          cp -r libs "${DIRNAME}/"
          find "${DIRNAME}/libs" -type f \( \
            -name "*.mexmaca64" -o -name "*.mexmaci64" \
            -o -name "*.mexa64" -o -name "*.mexw64" \
            -o -name "*.mex" \) -delete

          # Create archives
          tar czf "${DIRNAME}.tar.gz" "${DIRNAME}"
          zip -r "${DIRNAME}.zip" "${DIRNAME}"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          name: ${{ steps.version.outputs.VERSION }}
          body: |
            ## What's Changed

            ${{ steps.changelog.outputs.CHANGELOG }}

            ## Installation

            Download the archive, extract it, and run `setup` in MATLAB/Octave to add libraries to path and compile MEX accelerators.
          files: |
            FastSense-${{ steps.version.outputs.VERSION }}.tar.gz
            FastSense-${{ steps.version.outputs.VERSION }}.zip
```

- [ ] **Step 2: Verify YAML syntax**

Run: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))"`
Expected: No output (valid YAML)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/release.yml
git commit -m "ci: add release pipeline with test gate and auto-packaging"
```

---

## Chunk 2: README Overhaul

### Task 3: Replace README.md

**Files:**
- Modify: `README.md`

**Reference:** The current README is at `README.md` (~1000 lines). The wiki already has full API docs. The existing images are in `docs/images/`.

- [ ] **Step 1: Write the new README**

Replace the entire `README.md` with a concise version. Key content:

```markdown
# FastSense

[![Tests](https://github.com/HanSur94/FastSense/actions/workflows/tests.yml/badge.svg)](https://github.com/HanSur94/FastSense/actions/workflows/tests.yml)
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
```

- [ ] **Step 2: Review the new README renders correctly**

Run: `wc -l README.md`
Expected: ~120-150 lines (down from ~1000)

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: replace 43KB reference-manual README with concise overview

Full API documentation remains in the wiki. README now focuses on
quick start, feature highlights, and links to detailed docs."
```

---

## Chunk 3: GitHub Repo Metadata

### Task 4: Set Repository Description and Topics

- [ ] **Step 1: Set repo description**

Run:
```bash
gh repo edit HanSur94/FastSense \
  --description "Ultra-fast time series plotting for MATLAB & Octave — 10M+ points at 200+ FPS with interactive zoom/pan"
```

- [ ] **Step 2: Add topics**

Run:
```bash
gh repo edit HanSur94/FastSense \
  --add-topic matlab \
  --add-topic octave \
  --add-topic plotting \
  --add-topic time-series \
  --add-topic visualization \
  --add-topic high-performance \
  --add-topic data-visualization \
  --add-topic mex \
  --add-topic dashboard
```

- [ ] **Step 3: Verify**

Run: `gh repo view HanSur94/FastSense --json description,repositoryTopics`

---

## Chunk 4: Wiki Refresh

The wiki lives in `wiki/` as a separate git repo. All edits are made to files in that directory, then committed and pushed from within `wiki/`.

### Task 5: Update Wiki Home Page

**Files:**
- Modify: `wiki/Home.md`

- [ ] **Step 1: Update the libraries table**

Add the WebBridge row to the libraries table in `wiki/Home.md`. The current table lists 4 libraries (FastSense, SensorThreshold, EventDetection, Dashboard) — add a 5th row:

```markdown
| WebBridge | `libs/WebBridge/` | TCP server for web-based visualization |
```

- [ ] **Step 2: Update the "Libraries" count**

The text currently says "three libraries" but the table already has 4 rows. Change "three libraries" to "five libraries" in the text above the table.

- [ ] **Step 3: Update the examples count**

Change "30+ runnable examples" to "40+ runnable examples" on the Examples wiki link line.

- [ ] **Step 4: Add Dashboard Engine Guide to navigation**

Add under Guides section:
```markdown
- [[Dashboard Engine Guide]] — DashboardEngine + DashboardBuilder usage
```

---

### Task 6: Update Wiki Dashboard API Reference

**Files:**
- Modify: `wiki/API-Reference:-Dashboard.md`

This page needs the most updates. It must document the new Dashboard Engine subsystem.

- [ ] **Step 1: Read the current dashboard API reference page**

Read `wiki/API-Reference:-Dashboard.md` to understand current content.

- [ ] **Step 2: Read the Dashboard Engine source for accurate API**

Read the following files to extract current method signatures, properties, and constructor options:
- `libs/Dashboard/DashboardEngine.m`
- `libs/Dashboard/DashboardBuilder.m`
- `libs/Dashboard/DashboardWidget.m`
- `libs/Dashboard/GaugeWidget.m`
- `libs/Dashboard/NumberWidget.m`
- `libs/Dashboard/StatusWidget.m`
- `libs/Dashboard/TableWidget.m`
- `libs/Dashboard/TextWidget.m`
- `libs/Dashboard/RawAxesWidget.m`
- `libs/Dashboard/EventTimelineWidget.m`
- `libs/Dashboard/FastSenseWidget.m`
- `libs/Dashboard/DashboardLayout.m`
- `libs/Dashboard/DashboardSerializer.m`
- `libs/Dashboard/DashboardTheme.m`
- `libs/Dashboard/DashboardToolbar.m`

- [ ] **Step 3: Add DashboardEngine section**

Add comprehensive documentation covering:
- `DashboardEngine` constructor and key methods (`addWidget`, `removeWidget`, `render`, `save`, `load`)
- `DashboardBuilder` fluent API (`.plot()`, `.gauge()`, `.number()`, `.status()`, `.table()`, `.text()`, `.rawAxes()`, `.eventTimeline()`, `.build()`)
- All widget classes with constructor options and key properties
- `DashboardSerializer` for JSON save/load
- `DashboardLayout` for layout computation
- `DashboardTheme` and `DashboardToolbar`

Use the same documentation style as the existing API reference pages (method signature, description, options table, example code).

- [ ] **Step 4: Commit wiki changes so far**

```bash
cd wiki && git add -A && git commit -m "docs: update Dashboard API reference with Engine, Builder, and all widget types"
```

---

### Task 7: Update Wiki Sensors API Reference

**Files:**
- Modify: `wiki/API-Reference:-Sensors.md`

- [ ] **Step 1: Read current sensors page and source code**

Read `wiki/API-Reference:-Sensors.md` and `libs/SensorThreshold/SensorRegistry.m` to identify gaps.

- [ ] **Step 2: Add SensorRegistry documentation**

Add a section for `SensorRegistry` covering:
- Static method `SensorRegistry.get(key)` — returns a pre-configured Sensor
- `SensorRegistry.list()` — lists available sensor presets
- `SensorRegistry.register(key, sensor)` — adds a custom preset
- Example usage

- [ ] **Step 3: Verify ThresholdRule API matches code**

Read `libs/SensorThreshold/ThresholdRule.m` and compare constructor signature and properties to the wiki page. Fix any discrepancies.

- [ ] **Step 4: Commit**

```bash
cd wiki && git add -A && git commit -m "docs: add SensorRegistry, verify ThresholdRule API"
```

---

### Task 8: Update Wiki Event Detection API Reference

**Files:**
- Modify: `wiki/API-Reference:-Event-Detection.md`

- [ ] **Step 1: Read current page and source files**

Read `wiki/API-Reference:-Event-Detection.md` and check against:
- `libs/EventDetection/IncrementalEventDetector.m`
- `libs/EventDetection/DataSourceMap.m`
- `libs/EventDetection/NotificationRule.m`

- [ ] **Step 2: Add IncrementalEventDetector section**

Document the streaming event detection API: constructor, `processChunk()`, `finalize()`, properties.

- [ ] **Step 3: Add DataSourceMap section**

Document multi-source management: constructor, `add(key, ds)`, `get(key)`, `keys()`.

- [ ] **Step 4: Update NotificationRule / NotificationService**

Verify and update the notification API documentation to match current code.

- [ ] **Step 5: Commit**

```bash
cd wiki && git add -A && git commit -m "docs: add IncrementalEventDetector, DataSourceMap to event detection API"
```

---

### Task 9: Update Remaining Wiki Pages

**Files:**
- Modify: `wiki/Home.md` (final pass)
- Modify: `wiki/API-Reference:-Utilities.md`
- Modify: `wiki/Architecture.md`
- Modify: `wiki/Examples.md`
- Modify: `wiki/_Sidebar.md`
- Verify (read-only): `wiki/Installation.md`, `wiki/Getting-Started.md`, `wiki/API-Reference:-FastSense.md`, `wiki/API-Reference:-Themes.md`, `wiki/Live-Mode-Guide.md`, `wiki/Datetime-Guide.md`, `wiki/MEX-Acceleration.md`, `wiki/Performance.md`, `wiki/Use-Case:-Multi-Sensor-Shared-Threshold.md`

- [ ] **Step 1: Update Utilities API reference**

Read `wiki/API-Reference:-Utilities.md` and `libs/FastSense/ConsoleProgressBar.m`. Add documentation for hierarchical progress display features (nested bars, `addChild()`, etc.) if missing.

- [ ] **Step 2: Update Architecture page**

Read `wiki/Architecture.md`. Add sections for:
- Dashboard Engine architecture (DashboardEngine → DashboardLayout → Widgets pipeline)
- WebBridge protocol (TCP communication between MATLAB and Python/web)

Reference source files: `libs/Dashboard/DashboardEngine.m`, `libs/WebBridge/WebBridge.m`, `libs/WebBridge/WebBridgeProtocol.m`.

- [ ] **Step 3: Update Examples page**

Read `wiki/Examples.md`. Add entries for new examples:
- `example_dashboard_engine.m`
- `example_dashboard_all_widgets.m`
- `example_mixed_tiles.m`
- Any other examples added since the wiki was last updated

Cross-reference with actual files in `examples/` directory.

- [ ] **Step 4: Update sidebar**

Add to `wiki/_Sidebar.md` under Guides:
```markdown
- [[Dashboard Engine Guide]]
```

- [ ] **Step 5: Verify accuracy of remaining pages**

Read each of these pages and compare key details against current source code. Fix any discrepancies found:
- `wiki/Installation.md` — verify requirements, setup steps
- `wiki/Getting-Started.md` — verify example code runs
- `wiki/API-Reference:-FastSense.md` — verify method signatures
- `wiki/API-Reference:-Themes.md` — verify theme names and options
- `wiki/Live-Mode-Guide.md` — verify live mode API
- `wiki/Datetime-Guide.md` — verify datetime handling
- `wiki/MEX-Acceleration.md` — verify SIMD details
- `wiki/Performance.md` — verify benchmark numbers
- `wiki/Use-Case:-Multi-Sensor-Shared-Threshold.md` — verify API usage

- [ ] **Step 6: Commit all remaining wiki updates**

```bash
cd wiki && git add -A && git commit -m "docs: update utilities, architecture, examples, sidebar, verify all pages"
```

---

### Task 10: Create Dashboard Engine Guide Wiki Page

**Files:**
- Create: `wiki/Dashboard-Engine-Guide.md`

- [ ] **Step 1: Read Dashboard source and examples**

Read:
- `libs/Dashboard/DashboardEngine.m`
- `libs/Dashboard/DashboardBuilder.m`
- `examples/example_dashboard_engine.m`
- `examples/example_dashboard_all_widgets.m`
- `examples/example_dashboard_9tile.m`

- [ ] **Step 2: Write the guide**

Create `wiki/Dashboard-Engine-Guide.md` covering:
- Overview of DashboardEngine vs FastSenseFigure (when to use which)
- Building dashboards with DashboardBuilder (fluent API walkthrough)
- Widget types and their options (with small code examples)
- Saving and loading dashboards (JSON serialization)
- Theming dashboards
- Complete working example

Use the same style as `wiki/Live-Mode-Guide.md` for consistency.

- [ ] **Step 3: Commit**

```bash
cd wiki && git add -A && git commit -m "docs: add Dashboard Engine Guide wiki page"
```

---

### Task 11: Push Wiki Changes

- [ ] **Step 1: Review all wiki commits**

Run: `cd wiki && git log --oneline -10`

- [ ] **Step 2: Push wiki to GitHub**

Run: `cd wiki && git push origin master`
(GitHub wikis typically use `master` branch)

---

## Chunk 5: Final Verification

### Task 12: Push Main Repo and Verify

- [ ] **Step 1: Push main repo commits**

Run: `git push origin main`

- [ ] **Step 2: Verify test pipeline triggers**

Run: `gh run list --workflow tests.yml --limit 1`
Expected: A workflow run in progress or completed

- [ ] **Step 3: Verify repo metadata**

Run: `gh repo view HanSur94/FastSense --json description,repositoryTopics`
Expected: Description and topics are set correctly

- [ ] **Step 4: Verify README renders on GitHub**

Open `https://github.com/HanSur94/FastSense` and confirm the new README looks correct with badges, image, and formatting.
