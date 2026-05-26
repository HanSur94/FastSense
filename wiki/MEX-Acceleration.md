<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->
# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure‑MATLAB fallbacks that are automatically selected when a MEX binary is not available. This page explains how to build the MEX files, which operations are accelerated, and how the seamless fallback mechanism works.

## Building MEX Files

The build is triggered from the FastSense library directory:

```matlab
cd('libs/FastSense');
build_mex();
```

The script detects your CPU architecture, selects appropriate SIMD flags, compiles all C sources, and copies the resulting binaries to the necessary locations. It is also invoked automatically by the top‑level `install.m` when the source has changed.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS   | Xcode Command Line Tools  |
| Linux   | GCC (real GCC recommended, Homebrew `gcc‑14` etc.) |
| Windows | Microsoft Visual C++ (MSVC) |

SQLite3 is bundled as an amalgamation (`sqlite3.c` + `sqlite3.h`) and compiled directly into the MEX files that require it — no system installation is needed.

## Architecture Support

The build script maps your CPU to the best SIMD instruction set:

| Architecture              | SIMD Instructions     | Fallback |
|---------------------------|-----------------------|----------|
| x86_64                    | AVX2 + FMA            | SSE2     |
| ARM64 (Apple Silicon)     | NEON (implicit)       | –        |
| ARM64 (Linux, GCC)        | `-mcpu=apple-m3` / NEON | –       |
| Other / unknown           | scalar operations     | –        |

If AVX2 compilation fails on x86_64, the script automatically retries with SSE2 flags and continues building the remaining files.

## Accelerated Functions

All MEX functions are listed below. Each one is used internally by the library; you do not call them directly.

### Core Downsampling

**binary_search_mex** — O(log n) binary search for identifying visible data ranges.  
- **Speedup**: 10‑20× over MATLAB’s `find`  
- **Used by**: zoom/pan callbacks to locate which points are within the current X limits  

**minmax_core_mex** — Per‑pixel MinMax reduction with SIMD vectorization.  
- **Speedup**: 3‑10× over pure MATLAB  
- **SIMD**: processes 4 doubles (AVX2) or 2 doubles (NEON) per clock cycle  
- **Used by**: default (MinMax) downsampling in [[FastPlot|API Reference: FastPlot]]

**lttb_core_mex** — Largest‑Triangle‑Three‑Buckets downsampling with SIMD‑accelerated triangle area calculation.  
- **Speedup**: 10‑50× over MATLAB  
- **Used by**: LTTB downsampling mode

### Threshold Processing

**violation_cull_mex** — Fused threshold violation detection and pixel‑level culling in a single pass.  
- **Speedup**: substantial (single‑pass vs. two‑pass MATLAB)  
- **Used by**: violation marker rendering during zoom/pan

**compute_violations_mex** — Batch threshold violation detection suitable for `Sensor.resolve()`.  
- **Speedup**: significant over per‑point MATLAB comparisons  
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline

**to_step_function_mex** — SIMD conversion of time‑varying thresholds into step‑function form.  
- **Speedup**: 2‑5× over MATLAB for long arrays  
- **Used by**: `addThreshold` when you supply both X and Y vectors

### Data Storage

**build_store_mex** — Bulk SQLite writer for DataStore initialisation.  
- **Speedup**: 2‑3× (eliminates ~20K MATLAB‑to‑MEX round‑trips)  
- **SIMD**: accelerated computation of per‑chunk Y min/max  
- **Used by**: `FastSenseDataStore` constructor

**resolve_disk_mex** — Disk‑based sensor resolution reading directly from SQLite.  
- **Used by**: `Sensor.resolve()` when data is stored on disk  
- **Benefit**: reads only the chunks overlapping the requested range without loading the full dataset

**mksqlite** — General‑purpose SQLite3 MEX interface with typed BLOB support.  
- **Used by**: `DataStore`, disk‑based sensor resolution, and MonitorTag cache operations  
- **Features**: serialises MATLAB arrays preserving type and shape

> **October 2023 additional kernel**: `delimited_parse_mex` in the SensorThreshold private directory accelerates delimited string parsing used by the Tag pipeline. It is compiled during the same `build_mex()` run.

## Fallback Behavior

When a MEX file is not available (not yet built or not compatible), each function transparently falls back to a pure‑MATLAB implementation. The pattern used throughout the library is shown in `binary_search.m`:

```matlab
% Check once per session whether the compiled MEX is on the path
persistent useMex;
if isempty(useMex)
    useMex = (exist('binary_search_mex', 'file') == 3);
end

if useMex
    idx = binary_search_mex(x, val, char(direction));
else
    % Pure‑MATLAB iterative binary search …
end
```

All fallback implementations live in the `libs/FastSense/private/` directory. They produce identical numerical results — the test suite enforces this parity.

## Compilation Process (summary)

The `build_mex()` function performs these steps:

1. **Detect architecture** – normalises platform strings (`maca64`, `aarch64‑*`, `x86_64‑*`, etc.) into canonical labels `x86_64` or `arm64`.
2. **Select compiler** – on Octave, prefers real GCC for superior auto‑vectorisation; on MATLAB, uses the configured default (Clang on macOS, MSVC on Windows).
3. **Set SIMD flags** – applies flags like `-mavx2 -mfma` (x86_64) or `-mcpu=apple-m3` (ARM64 with GCC).
4. **Compile sources** – builds each MEX source together with the bundled SQLite3 amalgamation where needed.
5. **Handle failures** – on x86_64, if AVX2 compilation fails, it retries with `-msse2`.
6. **Copy shared files** – distributes required MEX binaries into `SensorThreshold/private/` and the `Concurrency` library.

## Verifying Installation

The test suite verifies that MEX functions produce the same results as their MATLAB fallbacks:

```matlab
install;                    % or manually build MEX
addpath('tests');
test_mex_parity;            % Verify MEX matches MATLAB output
test_mex_edge_cases;        % Edge cases: empty arrays, NaN, single point, etc.
```

These tests validate numerical accuracy across all MEX functions and confirm that the fallback logic is correctly wired.

## See Also

- [[Performance]] – overall performance tips and benchmarking
- [[Architecture]] – internal design and data flow
- [[Installation]] – `install.m` and dependency management
