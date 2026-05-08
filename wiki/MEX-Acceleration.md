<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure-MATLAB fallbacks — behavior is identical. This guide covers building, architecture support, the accelerated functions, and verification.

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your CPU architecture and compiler, then compiles all MEX functions with the best available SIMD optimizations. If AVX2 fails on x86_64, it automatically retries with SSE2.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools |
| Linux | GCC |
| Windows | MSVC |

SQLite3 is bundled as an amalgamation and compiled directly into MEX files that need it — no system installation required.

Before building, an incremental check based on a **mex‑stamp** (computed by `mex_stamp()`) ensures that only changed sources are recompiled; if the stamp matches, `build_mex()` is skipped entirely.

## Architecture Support

All MEX functions share a common SIMD abstraction layer. The build process selects the best instruction set for your hardware:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON | — |
| Other | Scalar operations | — |

If AVX2 compilation fails on x86_64, the script automatically retries with `-msse2` so that MEX files still benefit from SSE2 vectorization.

## Accelerated Functions

### Core Downsampling

**`binary_search_mex`** — O(log n) binary search for visible data range.  
- **Speedup**: 10–20× over MATLAB's `find`.  
- **Used by**: Zoom/pan callbacks to locate visible indices.

**`minmax_core_mex`** — Per‑pixel Min‑Max reduction with SIMD vectorization.  
- **Speedup**: 3–10× over pure MATLAB.  
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle.  
- **Used by**: Default downsampling in [[FastPlot|API Reference: FastPlot]].

**`lttb_core_mex`** — Largest Triangle Three Buckets with SIMD triangle area computation.  
- **Speedup**: 10–50× over MATLAB implementation.  
- **Used by**: LTTB downsampling method.

### Threshold Processing

**`violation_cull_mex`** — Fused threshold violation detection and pixel culling.  
- **Speedup**: Significant (single‑pass vs two‑pass MATLAB).  
- **Used by**: Violation marker rendering during zoom/pan.

**`compute_violations_mex`** — Batch threshold violation detection.  
- **Speedup**: Significant over per‑point MATLAB comparison.  
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline.

**`to_step_function_mex`** — SIMD step‑function conversion for thresholds (converts threshold (X,Y) pairs into a staircase representation).  
- **Speedup**: Notable when resolutions involve many threshold segments.  
- **Used by**: Sensor resolution logic, especially with time‑varying thresholds.

### Data Storage

**`build_store_mex`** — Bulk SQLite writer for DataStore initialization.  
- **Speedup**: 2–3× (eliminates ~20K MATLAB‑to‑MEX round‑trips).  
- **SIMD**: Accelerated Y min/max computation per chunk.  
- **Used by**: `FastSenseDataStore` construction.

**`resolve_disk_mex`** — SQLite disk‑based sensor resolution.  
- **Speedup**: Reads chunks from database without loading full datasets.  
- **Used by**: `Sensor.resolve()` when data is stored on disk.

**`mksqlite`** — SQLite3 MEX interface with typed BLOB support.  
- **Used by**: DataStore, disk‑backed sensor resolution.  
- **Features**: Serializes MATLAB arrays preserving type and shape.

## Fallback Behavior

When MEX files are unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/`.  
- Runtime auto‑detection switches between MEX and MATLAB seamlessly.  
- Identical numerical results and API.  
- Performance remains excellent for datasets under ~10M points.

## Compilation Process

The `build_mex()` function:

1. **Detects architecture** — normalises platform strings (`maca64`, `aarch64`, `x86_64`, …)  
2. **Selects compiler** — on Octave prefers real GCC for better auto‑vectorisation; MATLAB uses its default (Clang on macOS, MSVC on Windows)  
3. **Sets SIMD flags** — selects instruction sets and optimisation flags  
4. **Checks stamp** — if `install.m` already verified the MEX stamp, no compilation runs; otherwise `build_mex()` compiles each missing file  
5. **Compiles sources** — builds all MEX files, including `mksqlite` with the bundled SQLite3 amalgamation  
6. **Handles failures** — automatically retries x86_64 builds with SSE2 if AVX2 fails  
7. **Copies shared files** — distributes MEX binaries (e.g., `violation_cull_mex`, `to_step_function_mex`) to `SensorThreshold/private/` for use by the Sensors library  

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.
