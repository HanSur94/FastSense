# CI/CD Pipelines, README Overhaul & Wiki Refresh — Design Spec

**Date:** 2026-03-16
**Status:** Approved

## Overview

Add GitHub Actions CI/CD pipelines (test + release), replace the 43KB reference-manual README with a concise open-source-style README, and refresh the wiki and repo metadata to match the current project state.

---

## 1. Test Pipeline

**File:** `.github/workflows/tests.yml`

### CI Exit Code Handling

`run_all_tests.m` currently prints results and returns a struct but does not exit with a non-zero code on failure. The CI steps must wrap the call to ensure proper exit codes:

- **Octave:** `octave --eval "cd('tests'); r = run_all_tests(); if r.failed > 0; exit(1); end"`
- **MATLAB:** `matlab-actions/run-command@v2` with: `cd('tests'); r = run_all_tests(); assert(r.failed == 0, 'Tests failed');`

### Octave Job (every push/PR to `main`)

- **Runner:** `ubuntu-latest` (Ubuntu 24.04 ships Octave 8.x, satisfying the 7+ requirement)
- **Steps:**
  1. Checkout repository
  2. Install GNU Octave via `apt-get install octave`
  3. Run tests: `octave --eval "cd('tests'); r = run_all_tests(); if r.failed > 0; exit(1); end"`

### MATLAB Job (weekly schedule + `workflow_dispatch`)

- **Runner:** `ubuntu-latest`
- **Steps:**
  1. Checkout repository
  2. `matlab-actions/setup-matlab@v2` (latest MATLAB)
  3. `matlab-actions/run-command@v2` with `cd('tests'); r = run_all_tests(); assert(r.failed == 0, 'Tests failed');`
- **`continue-on-error: true`** — so license or runner issues don't mark the weekly check as failed

### Matrix

| Trigger | Octave | MATLAB |
|---------|--------|--------|
| Push to `main` | Yes | No |
| Pull request | Yes | No |
| Weekly (cron) | No | Yes |
| Manual dispatch | Yes | Yes |

---

## 2. Release Pipeline

**File:** `.github/workflows/release.yml`

### Trigger

- Push tag matching `v*` (e.g., `v1.5.0`)

### Steps

1. **Gate:** Run Octave tests (same as test pipeline Octave job)
2. **Package:** Create archive containing:
   - `libs/` (all 5 libraries: FastSense, SensorThreshold, EventDetection, Dashboard, WebBridge)
   - MEX C source files included, compiled `.mex*` binaries **excluded** (users compile via `setup.m`)
   - Must explicitly filter `*.mexmaca64`, `*.mexmaci64`, `*.mexa64`, `*.mexw64`, `*.mex` since some are tracked in git despite `.gitignore`
   - `setup.m`
   - `LICENSE`
   - `README.md`
   - `CITATION.cff`
   - `examples/`
3. **Changelog:** Auto-generate from commits since previous tag using `git log --no-merges --pretty=format:"- %s (%h)" <prev-tag>..HEAD`
4. **Release:** Create GitHub Release via `softprops/action-gh-release@v2`
   - Title: tag name (e.g., `v1.5.0`)
   - Body: auto-generated changelog
   - Assets: `FastSense-v1.5.0.zip` and `FastSense-v1.5.0.tar.gz` (version includes `v` prefix)

### Archive Structure

```
FastSense-v1.5.0/
├── setup.m
├── LICENSE
├── README.md
├── CITATION.cff
├── libs/
│   ├── FastSense/
│   ├── SensorThreshold/
│   ├── EventDetection/
│   ├── Dashboard/
│   └── WebBridge/
└── examples/
```

Excluded from archive: `tests/`, `benchmarks/`, `docs/`, `bridge/`, `private/` (root-level), `.git/`, compiled MEX binaries.

**Note:** `bridge/` (Python/web components) is excluded. `libs/WebBridge/` is the MATLAB-side TCP server and is self-contained — it does not depend on `bridge/` at runtime. Users who want the Python bridge can clone the full repo.

---

## 3. README.md Overhaul

Replace the current 43KB README with a concise (~150-200 lines) overview.

### Structure

1. **Title + tagline** — "FastSense — Ultra-fast time series plotting for MATLAB & Octave"
2. **Badges** — CI status (pointing to `tests.yml` on `main`), license (MIT), MATLAB R2020b+, Octave 7+
3. **One-paragraph description** — what it does, key performance claim
4. **Screenshot** — existing `docs/images/` hero image
5. **Key Features** — bullet list (~10 items), not full API
6. **Quick Start** — install steps + one minimal code example (5-10 lines)
7. **Documentation** — links to wiki pages (Getting Started, API Reference, Architecture, etc.)
8. **Examples** — link to `examples/` directory and wiki Examples page
9. **Performance** — brief benchmark table (from existing data), link to wiki Performance page
10. **Contributing** — brief section or link
11. **Citation** — reference to CITATION.cff
12. **License** — MIT, link to LICENSE file

### Content NOT in new README (moved to wiki)

- Full API reference (already in wiki)
- Detailed architecture (already in wiki)
- Event detection details (already in wiki)
- Sensor/threshold details (already in wiki)
- Live mode guide (already in wiki)

---

## 4. GitHub Repo Metadata

### Description

> Ultra-fast time series plotting for MATLAB & Octave — 10M+ points at 200+ FPS with interactive zoom/pan

### Topics

`matlab`, `octave`, `plotting`, `time-series`, `visualization`, `high-performance`, `data-visualization`, `mex`, `dashboard`

**Note:** These are set via `gh repo edit`, not files. The pipelines and README are committed; repo metadata is set via GitHub API.

---

## 5. Wiki Refresh

Update all 17 wiki pages to reflect the current project state.

### Pages Requiring Updates

| Page | Updates Needed |
|------|---------------|
| Home.md | Add Dashboard Engine v2, WebBridge, NumberWidget, new widget types |
| Installation.md | Verify requirements still accurate |
| Getting-Started.md | Ensure examples use current API |
| API-Reference: FastSense.md | Verify method signatures match current code |
| API-Reference: Dashboard.md | Add DashboardEngine, DashboardBuilder, new widgets (Gauge, Number, Status, Table, Text, RawAxes, EventTimeline) |
| API-Reference: Sensors.md | Add SensorRegistry, verify ThresholdRule API |
| API-Reference: Event-Detection.md | Add IncrementalEventDetector, DataSourceMap, NotificationRule updates |
| API-Reference: Themes.md | Verify theme list and customization API |
| API-Reference: Utilities.md | Add ConsoleProgressBar hierarchy features |
| Architecture.md | Add Dashboard Engine architecture, WebBridge protocol |
| Live-Mode-Guide.md | Verify accuracy |
| Datetime-Guide.md | Verify accuracy |
| MEX-Acceleration.md | Verify SIMD details match current implementation |
| Performance.md | Update benchmark numbers if changed |
| Examples.md | Add new examples (dashboard engine, mixed tiles, all-widgets) |
| Use-Case: Multi-Sensor-Shared-Threshold.md | Verify accuracy with current API |
| _Sidebar.md | Update navigation if new pages added |

### New Wiki Pages (if warranted)

- **Dashboard-Engine-Guide.md** — DashboardEngine + DashboardBuilder usage guide (significant new subsystem)

---

## Non-Goals

- No `.mltbx` toolbox packaging (future enhancement)
- No MATLAB File Exchange publishing
- No code coverage reporting (can be added later)
- No Docker-based test environments
- No Windows/macOS CI matrix (Octave on Ubuntu is sufficient for now)
- No automatic `CITATION.cff` version bumping (manual before tagging)
