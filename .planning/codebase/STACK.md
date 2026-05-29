# Technology Stack

**Analysis Date:** 2026-04-01

## Languages

**Primary:**
- MATLAB - Core plotting engine, sensor modeling, dashboard, event detection, WebBridge server side
- C - MEX acceleration kernels (SIMD-optimized); SQLite3 bundled amalgamation

**Secondary:**
- Python 3.11+ - Web bridge server (`bridge/python/`)
- JavaScript (ES modules) - Browser dashboard frontend (`bridge/web/js/`)
- HTML/CSS - Browser dashboard UI (`bridge/web/`)

## Runtime

**Environment:**
- MATLAB R2020b+ (primary target)
- GNU Octave 7+ (fully supported alternative)

**Cross-platform support:**
- Linux (x86_64, CI primary)
- macOS (ARM64 / Apple Silicon primary dev machine)
- Windows (x86_64, tested in CI via Chocolatey Octave 9.2.0)

**Python Runtime:**
- Python 3.11+ (bridge server only)

**Package Manager (Python):**
- pip / pyproject.toml
- Lockfile: not present (no uv.lock or requirements.txt)

## Frameworks

**Core (MATLAB):**
- No external MATLAB toolboxes required — all functionality is toolbox-free
- MEX C extensions compiled via `build_mex()` / `install()` at first run

**Web Bridge Server (Python):**
- FastAPI >= 0.104 - REST API + WebSocket + static file serving
- Uvicorn >= 0.24 - ASGI server (standard extras for websockets)

**Browser Frontend:**
- uPlot (vendored) - High-performance time series charting library (`bridge/web/vendor/uPlot.min.js`, `bridge/web/vendor/uPlot.min.css`)
- Vanilla JS (no build step, no npm)

**Testing (Python):**
- pytest >= 7.0
- pytest-asyncio >= 0.21 (asyncio_mode = auto)
- httpx >= 0.25 (async HTTP test client)

**Testing (MATLAB/Octave):**
- Custom test runner (`tests/run_all_tests.m`)
- Both flat script tests (`tests/test_*.m`) and class-based suites (`tests/suite/Test*.m`)

**Build/Dev:**
- MISS_HIT (Python pip install) - MATLAB style checker, linter, and complexity metrics
  - Config: `miss_hit.cfg`
  - Commands: `mh_style`, `mh_lint`, `mh_metric --ci`

## Key Dependencies

**Critical (C/MEX):**
- SQLite3 amalgamation (bundled at `libs/FastSense/private/mex_src/sqlite3.c` + `sqlite3.h`) - disk-backed DataStore; no system install required
- mksqlite (bundled C source at `libs/FastSense/mksqlite.c`) - MATLAB MEX interface to SQLite3

**MEX kernels (compiled C, SIMD-optimized):**
- `binary_search_mex.c` - binary search on sorted time arrays
- `minmax_core_mex.c` - MinMax downsampling kernel (AVX2/NEON)
- `lttb_core_mex.c` - Largest-Triangle-Three-Buckets downsampling kernel
- `violation_cull_mex.c` - threshold violation culling
- `compute_violations_mex.c` - batch violation detection
- `to_step_function_mex.c` - SIMD step-function conversion
- `build_store_mex.c` - bulk SQLite writer for DataStore init
- `resolve_disk_mex.c` - disk-based resolve with SQLite

**Critical (Python bridge):**
- `fastapi >= 0.104`
- `uvicorn[standard] >= 0.24`
- `websockets >= 12.0`
- `numpy >= 1.24`
- `anthropic` (dev/scripts dependency, NOT in main dependencies — used only by `scripts/generate_wiki.py`)

**Infrastructure:**
- GitHub Actions - CI/CD (tests, MEX build, benchmarks, wiki generation, release)
- Codecov - test coverage reporting (MATLAB runs only; token via secret)

## Configuration

**Environment:**
- `FASTSENSE_SKIP_BUILD=1` - skip MEX compilation in CI when MEX binaries are cached
- `FASTSENSE_RESULTS_FILE` - path for Octave test result output in CI
- `ANTHROPIC_API_KEY` - required only for `scripts/generate_wiki.py` (wiki auto-generation)

**Build:**
- `miss_hit.cfg` - MISS_HIT linter/style/metric configuration (project root)
- `bridge/python/pyproject.toml` - Python bridge package config

**SIMD compilation flags (selected automatically by `build_mex.m`):**
- ARM64: `-O3 -ffast-math` (Clang/MATLAB) or `-O3 -mcpu=apple-m3 -ftree-vectorize -ffast-math` (GCC/Octave)
- x86_64: `-O3 -mavx2 -mfma -ftree-vectorize -ffast-math` (with SSE2 fallback)
- Windows MSVC: `/O2 /arch:AVX2 /fp:fast`

## Platform Requirements

**Development:**
- MATLAB R2020b+ or GNU Octave 7+
- C compiler accessible to `mex` or `mkoctfile` (Xcode CLT on macOS, GCC on Linux, MSVC on Windows)
- Optional: GCC via Homebrew (`/opt/homebrew/bin/gcc-{10..15}`) for Octave AVX2 builds
- Python 3.11+ (only if using the WebBridge feature)

**Production:**
- Self-contained MATLAB/Octave environment
- No internet access required; no toolbox licenses required
- MEX binaries must be compiled once per platform on install

---

*Stack analysis: 2026-04-01*
