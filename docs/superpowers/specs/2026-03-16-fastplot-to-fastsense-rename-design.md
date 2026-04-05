# FastPlot → FastSense Rename Design

**Date:** 2026-03-16
**Status:** Draft

## Motivation

The project has grown from a fast time-series plotter into a sensor monitoring and dashboarding platform. The name "FastPlot" only describes the plotting core and underrepresents the sensor system, event detection pipeline, dashboard engine, and live monitoring capabilities. "FastSense" preserves the speed identity while signaling the sensor/monitoring focus.

## Scope

### Classes Renamed

All classes with the `FastPlot` prefix get renamed to `FastSense`:

| Old Name | New Name | File |
|----------|----------|------|
| `FastPlot` | `FastSense` | `libs/FastSense/FastSense.m` |
| `FastPlotGrid` | `FastSenseGrid` | `libs/FastSense/FastSenseGrid.m` |
| `FastPlotDock` | `FastSenseDock` | `libs/FastSense/FastSenseDock.m` |
| `FastPlotToolbar` | `FastSenseToolbar` | `libs/FastSense/FastSenseToolbar.m` |
| `FastPlotTheme` | `FastSenseTheme` | `libs/FastSense/FastSenseTheme.m` |
| `FastPlotDataStore` | `FastSenseDataStore` | `libs/FastSense/FastSenseDataStore.m` |
| `FastPlotDefaults` | `FastSenseDefaults` | `libs/FastSense/FastSenseDefaults.m` |
| `FastPlotWidget` | `FastSenseWidget` | `libs/Dashboard/widgets/FastSenseWidget.m` |

### Test Classes Renamed

| Old Name | New Name | File |
|----------|----------|------|
| `TestFastPlotWidget` | `TestFastSenseWidget` | `tests/suite/TestFastSenseWidget.m` |

### Helper Functions Renamed

| Old Name | New Name | File |
|----------|----------|------|
| `add_fastplot_private_path` | `add_fastsense_private_path` | `tests/add_fastsense_private_path.m` |

Note: `add_fastplot_private_path()` is called by ~40 test files. All callers must be updated. MATLAB requires function name to match filename.

### Classes NOT Renamed

These keep their current names — they are independent subsystems with their own naming:

- **SensorThreshold:** `Sensor`, `StateChannel`, `ThresholdRule`, `SensorRegistry`
- **EventDetection:** `EventDetector`, `EventStore`, `EventViewer`, `EventConfig`, `Event`, `IncrementalEventDetector`, `LiveEventPipeline`, `NotificationService`, `NotificationRule`, `DataSource`, `MatFileDataSource`, `MockDataSource`
- **Dashboard:** `DashboardEngine`, `DashboardLayout`, `DashboardBuilder`, `DashboardSerializer`, `DashboardTheme`, `DashboardToolbar`, `DashboardWidget`, `NumberWidget`, `StatusWidget`, `GaugeWidget`, `TableWidget`, `TextWidget`, `EventTimelineWidget`, `RawAxesWidget`
- **WebBridge:** `WebBridge`, `WebBridgeProtocol`
- **Other:** `NavigatorOverlay`

### Folder Rename

- `libs/FastPlot/` → `libs/FastSense/`
- All other library folders (`libs/SensorThreshold/`, `libs/EventDetection/`, `libs/Dashboard/`, `libs/WebBridge/`) stay unchanged.

### Python Bridge Package Rename

The Python bridge package at `bridge/python/` must also be renamed:

- **Package directory:** `bridge/python/fastplot_bridge/` → `bridge/python/fastsense_bridge/`
- **`pyproject.toml`:** Package name `fastplot-bridge` → `fastsense-bridge`, entry-point `fastplot-bridge` → `fastsense-bridge`
- **All Python imports:** `from fastplot_bridge...` → `from fastsense_bridge...` in all test files under `bridge/python/tests/`
- **`WebBridge.m` line ~228:** Subprocess call `python -m fastplot_bridge` → `python -m fastsense_bridge`
- **`TestWebBridgeE2E.m`:** Import check `import fastplot_bridge` → `import fastsense_bridge`

### MEX C/H Source Files

All `.c` and `.h` files under `libs/FastPlot/private/mex_src/` contain `"FastPlot:..."` error identifiers in `mexErrMsgIdAndTxt` calls (e.g. `"FastPlot:build_store_mex:nrhs"`). These must be updated to `"FastSense:..."`.

After updating the C sources, a full MEX rebuild (`build_mex.m`) is required as part of the rename commit. Pre-built `.mex*` binaries in the repo will contain stale identifiers until rebuilt.

### Runtime String Keys

The following runtime string keys are stored on graphics handles and figure application data. They form internal contracts between files and must be updated atomically:

**UserData struct fields:**
- `ud.FastPlot` → `ud.FastSense` (set in `FastPlot.m`, read in `FastPlotToolbar.m`)
- `ud.FastPlotTheme` → `ud.FastSenseTheme` (set in `FastPlotGrid.m`, read in `SensorDetailPlot.m`)
- `ud.FastPlotInstance` → `ud.FastSenseInstance` (set/read across toolbar code)

**`setappdata`/`getappdata` keys:**
- `'FastPlotDock'` → `'FastSenseDock'` (written in `FastPlotDock.m`, read in `FastPlotToolbar.m`)
- `'FastPlotToolbar'` → `'FastSenseToolbar'` (written in `FastPlot.m`)
- `'FastPlotMetadataEnabled'` → `'FastSenseMetadataEnabled'` (written/read in `FastPlotToolbar.m`)

**Graphics tag:**
- `'FastPlotAnchor'` → `'FastSenseAnchor'` (set in `FastPlot.m`)

**Widget type string:**
- `FastPlotWidget.getType()` returns `'fastplot'` → `'fastsense'`. This string is used as a dispatch key in `DashboardEngine`, `DashboardBuilder`, `DashboardSerializer`. Any saved `.json` dashboard files on disk with `"type": "fastplot"` will need manual migration.

### Infrastructure Updates

- **`setup.m`**: Update path from `libs/FastPlot` to `libs/FastSense`
- **README.md**: Update project title, description, badges, quick-start code, installation instructions
- **CITATION.cff**: Update title to "FastSense: Ultra-Fast Sensor Monitoring for MATLAB and GNU Octave"
- **CI workflows** (`.github/workflows/*.yml`): Update release artifact names (`FastSense-${VERSION}.tar.gz`, `FastSense-${VERSION}.zip`), badge URLs
- **`generate-docs.yml` line ~30**: Update wiki clone URL from `HanSur94/FastPlot.wiki.git` to `HanSur94/FastSense.wiki.git` (GitHub does NOT auto-redirect wiki URLs)
- **`scripts/generate_api_docs.py`**: Update hardcoded class names table (lines ~643–665), lib folder list (line ~781), and print statements. Critical — if not updated, CI will overwrite correctly renamed wiki pages with stale `FastPlot` content.
- **`docs/generate_readme_images.m`**: Update `FastPlot()` and `FastPlotGrid()` calls
- **Wiki pages** (`wiki/*.md`): Update all references, including stale `FastPlotFigure` references that predate the `FastPlotGrid` rename
- **Examples** (`examples/*.m`): Update all `FastPlot()` calls to `FastSense()`
- **Tests** (`tests/*.m`, `tests/suite/*.m`): Update all `FastPlot` references
- **Benchmarks** (`benchmarks/*.m`): Update all `FastPlot` references
- **Docs** (`docs/*.md`, `docs/**/*.md`): Update all references
- **MEX build script** (`build_mex.m`): Update path references
- **Bridge/web files** (`bridge/web/*`): Update any FastPlot references

### GitHub Repo Rename

Manual step: rename `HanSur94/FastPlot` → `HanSur94/FastSense` in GitHub Settings. GitHub auto-redirects main repo URLs but NOT wiki URLs — update `generate-docs.yml` accordingly.

## Migration Strategy

**Clean break — no backwards compatibility layer.**

- No deprecation period, no wrapper functions, no aliases
- All references updated in a single atomic commit
- Old class names (`FastPlot()`, `FastPlotGrid()`, etc.) stop working immediately
- All paired writer/reader string keys (UserData, appdata, widget types) must be updated together — partial updates cause silent runtime failures

**Rationale:** The project is early-stage without widespread downstream dependents. A clean break avoids maintenance burden of compatibility shims.

## Execution Order

1. Rename `libs/FastPlot/` directory to `libs/FastSense/`
2. Rename all `FastPlot*.m` files to `FastSense*.m` (including `FastPlotWidget.m` in Dashboard, `TestFastPlotWidget.m` in tests/suite, `add_fastplot_private_path.m` in tests)
3. Find-and-replace `FastPlot` → `FastSense` in all `.m` files (classes, tests, examples, benchmarks, setup, docs)
4. Find-and-replace `FastPlot` → `FastSense` in all `.c` and `.h` files under `libs/FastSense/private/mex_src/`
5. Find-and-replace `fastplot` → `fastsense` (lowercase) in Python bridge: rename `bridge/python/fastplot_bridge/` → `bridge/python/fastsense_bridge/`, update `pyproject.toml`, update all Python imports and test files
6. Update `scripts/generate_api_docs.py` (class name tables, lib folder list, print statements)
7. Update `setup.m` library path
8. Update `README.md` (title, description, badges, code examples)
9. Update `CITATION.cff`
10. Update CI workflows (`.github/workflows/*.yml`), especially wiki clone URL in `generate-docs.yml`
11. Update wiki pages (`wiki/*.md`), including stale `FastPlotFigure` references
12. Update docs (`docs/**/*.md`) and `docs/generate_readme_images.m`
13. Update bridge/web files
14. Rebuild MEX binaries (`build_mex.m`)
15. Grep audit: verify zero remaining `FastPlot` references (excluding `.git/`, `.worktrees/`, and this spec)
16. Also grep for lowercase `fastplot` to catch Python/web references
17. Run full test suite
18. Single commit + version tag

## Verification

1. **Grep audit** — `grep -ri "fastplot"` (case-insensitive) across the repo (excluding `.git/`, `.worktrees/`) must return zero hits (other than this design doc)
2. **Test suite** — `run_all_tests.m` passes with no failures
3. **Smoke test** — `setup.m` + `example_basic.m` runs successfully
4. **Python bridge test** — `python -m fastsense_bridge` imports successfully
5. **CI** — GitHub Actions test workflow passes on both MATLAB and Octave

## Out of Scope

- No functional changes — this is purely a rename operation
- No API changes beyond the class name prefix swap
- No folder restructuring beyond `libs/FastPlot/` → `libs/FastSense/`
- No namespace/package introduction
- Migration of existing on-disk `.json` dashboard save files (users must update `"type": "fastplot"` → `"type": "fastsense"` manually)

## Known Pre-existing Issue

`libs/EventDetection/private/parseOpts.m` line 61 uses warning ID `'FastPlot:unknownOption'` despite being in the EventDetection library. The global replace will change this to `'FastSense:unknownOption'`. This is acceptable — ideally it should be `'EventDetection:unknownOption'` but that is a separate cleanup.
