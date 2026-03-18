# MEX Acceleration

FastPlot includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure-MATLAB fallbacks — behavior is identical.

## Building MEX Files

```matlab
cd libs/FastPlot
build_mex();
```

The build script auto-detects your architecture and compiles all MEX functions.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools |
| Linux | GCC |
| Windows | MSVC |

For SQLite-backed features (DataStore, disk-based resolve), `libsqlite3` is also needed:

| Platform | Install |
|----------|---------|
| macOS | `brew install sqlite3` (usually pre-installed) |
| Ubuntu/Debian | `sudo apt install libsqlite3-dev` |
| Windows | Download from [sqlite.org](https://sqlite.org/download.html) |

## Accelerated Functions

### binary_search_mex

O(log n) binary search for the visible data range within sorted X arrays.

- **Speedup**: 10-20x over MATLAB's `find`
- **Used by**: Zoom/pan callback to locate visible data indices

### minmax_core_mex

Per-pixel MinMax reduction with SIMD vectorization.

- **Speedup**: 3-10x
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle
- **Used by**: Default downsampling algorithm

### lttb_core_mex

Largest Triangle Three Buckets downsampling with SIMD-accelerated triangle area computation.

- **Speedup**: 10-50x
- **Used by**: LTTB downsampling method

### violation_cull_mex

Fused threshold violation detection and pixel-space culling in a single pass.

- **Speedup**: Significant (avoids two-pass MATLAB approach)
- **Used by**: Violation marker rendering on zoom/pan

### compute_violations_mex

Batch threshold violation detection for `Sensor.resolve()`.

- **Speedup**: Significant over per-point MATLAB comparison
- **Used by**: Sensor resolution pipeline

### resolve_disk_mex

SQLite disk-based sensor resolution — reads chunks from the database and computes violations without loading full datasets into memory.

- **Used by**: `Sensor.resolve()` with disk-backed storage

### build_store_mex

Bulk SQLite writer that creates the DataStore database in a single C call, replacing ~20K mksqlite round-trips.

- **Speedup**: 2-3x (eliminates MATLAB-to-MEX overhead per chunk)
- **SIMD**: Accelerated Y min/max computation per chunk
- **Used by**: `FastPlotDataStore` initialization

### mksqlite

SQLite3 MEX interface with typed BLOB support (serializes MATLAB arrays into SQLite BLOBs preserving type and shape).

- **Used by**: DataStore, disk-backed Sensor resolution
- **Requires**: `libsqlite3`

## SIMD Architecture

All MEX functions share a common `simd_utils.h` abstraction layer:

| Architecture | Instructions |
|-------------|-------------|
| x86_64 | AVX2 (with SSE2 fallback) |
| arm64 (Apple Silicon) | NEON |

The abstraction provides platform-independent load, store, min, max, and comparison operations.

## Fallback Behavior

If MEX files are not compiled:

- Each function has a pure-MATLAB equivalent in `libs/FastPlot/private/`
- The MATLAB code auto-detects MEX availability at runtime
- Zero behavior change — same numerical results, same API
- Performance is still excellent for datasets under ~10M points

## Verifying MEX Installation

```matlab
setup;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, single points, NaN)
```
