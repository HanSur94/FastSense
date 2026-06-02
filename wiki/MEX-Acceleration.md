<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure‑MATLAB fallbacks — behavior is identical.

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your architecture and compiles all MEX functions with appropriate SIMD optimizations.  It skips files that are already up‑to‑date (checked via `mex_stamp` and per‑file modification time) and automatically retries on failure with a more compatible instruction set.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools |
| Linux | GCC |
| Windows | MSVC |

SQLite3 is bundled as an amalgamation and compiled directly into MEX files that need it — no system installation required.

## Architecture Support

All MEX functions adapt to your CPU through compile‑time flags:

| Architecture | SIMD Instructions | Fallback |
|--------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON | – |
| Other | Scalar operations | – |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2.

## Accelerated Functions

### Core Downsampling

**binary_search_mex** — O(log n) binary search for visible data range  
- **Speedup**: 10‑20× over MATLAB’s `find`  
- **Used by**: Zoom/pan callbacks to locate visible indices  

**minmax_core_mex** — Per‑pixel MinMax reduction with SIMD vectorization  
- **Speedup**: 3‑10× over pure MATLAB  
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle  
- **Used by**: Default downsampling algorithm in [[FastPlot|API Reference: FastPlot]]

**lttb_core_mex** — Largest Triangle Three Buckets with SIMD triangle area computation  
- **Speedup**: 10‑50× over MATLAB implementation  
- **Used by**: LTTB downsampling method  

### Threshold Processing

**violation_cull_mex** — Fused threshold violation detection and pixel culling  
- **Speedup**: Significant (single‑pass vs two‑pass MATLAB)  
- **Used by**: Violation marker rendering during zoom/pan  

**compute_violations_mex** — Batch threshold violation detection  
- **Speedup**: Significant over per‑point MATLAB comparison  
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline  

**to_step_function_mex** — SIMD step‑function conversion for thresholds  
- **Used by**: SensorThreshold library (converts varying thresholds to efficient stair‑step format)

### Data Storage

**build_store_mex** — Bulk SQLite writer for `FastSenseDataStore` initialization  
- **Speedup**: 2‑3× (eliminates ~20 K MATLAB‑to‑MEX round‑trips)  
- **SIMD**: Accelerated Y min/max computation per chunk  
- **Used by**: `FastSenseDataStore` construction  

**resolve_disk_mex** — SQLite disk‑based sensor resolution  
- **Used by**: `Sensor.resolve()` with disk‑backed storage  
- **Benefit**: Reads chunks from database without loading full datasets into memory  

**mksqlite** — SQLite3 MEX interface with typed BLOB support  
- **Used by**: DataStore, disk‑backed sensor resolution  
- **Features**: Serializes MATLAB arrays preserving type and shape  

### SensorThreshold Kernels

**delimited_parse_mex** — SIMD‑accelerated delimited data parsing for the Tag / SensorThreshold pipeline  
- **Used by**: Tag classes (delimited text imports)

### Concurrency Library

When the optional `libs/Concurrency` directory is present, `build_mex` also compiles  
**build_concurrency_mex** — provides concurrency primitives for background data processing.

## Fallback Behavior

When MEX files are unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/`
- Runtime auto‑detection switches between MEX and MATLAB seamlessly
- Identical numerical results and API
- Performance remains excellent for datasets under ~10 M points

## Compilation Process

The `build_mex()` function:

1. **Detects architecture** — normalises platform strings (`maca64`, `aarch64`, …) into canonical labels (`x86_64`, `arm64`, `unknown`).
2. **Selects compiler** — prefers GCC on Octave for better auto‑vectorisation; uses MATLAB’s default on MATLAB.
3. **Sets SIMD flags** — chooses instruction sets based on the detected CPU.
4. **Skips unchanged files** — if the MEX binary already exists and a stale‑ness check (via `mex_stamp`) has already passed, the file is skipped.
5. **Compiles sources** — builds all MEX files, linking the bundled SQLite3 amalgamation where needed.
6. **Handles failures** — automatically retries x86_64 builds with SSE2 if AVX2 fails.
7. **Copies shared files** — distributes MEX binaries (`violation_cull_mex`, `compute_violations_mex`, `resolve_disk_mex`, `to_step_function_mex`) to the `SensorThreshold/private/` directory.
8. **Compiles SensorThreshold kernels** — additional kernels (e.g., `delimited_parse_mex`) found in `libs/SensorThreshold/private/mex_src/` are compiled in the same pass.
9. **Compiles Concurrency library (best‑effort)** — if `libs/Concurrency/` exists, `build_concurrency_mex` is attempted; a failure here does not abort the main build.

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.
