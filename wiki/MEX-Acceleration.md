<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure‑MATLAB fallbacks — behaviour is identical and transparent.

## Building MEX Files

```matlab
cd('libs/FastSense');
build_mex();
```

The script auto‑detects your architecture and compiles all MEX functions with the best available SIMD optimisations. The bundled SQLite3 amalgamation is compiled directly into MEX files that need it — no system installation is required.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS   | Xcode Command Line Tools (Clang) |
| Linux   | GCC (preferred for Octave) or system default |
| Windows | MSVC (MATLAB) or GCC (Octave via MinGW) |

## Architecture Support

`build_mex()` selects SIMD instruction sets based on the detected CPU:

| Architecture               | SIMD Instructions | Fallback  |
|----------------------------|------------------|-----------|
| x86\_64 (Intel/AMD)        | AVX2 + FMA       | SSE2      |
| ARM64 (Apple Silicon, etc.) | NEON             | –         |
| Other / unknown            | Scalar operations| –         |

If AVX2 compilation fails on x86\_64, the script automatically retries with SSE2 flags.

## Accelerated Functions

All C sources reside in `private/mex_src/` and are compiled into `private/` (or a platform‑tagged subdirectory on Octave).

### Core Downsampling

- **`binary_search_mex`** — O(log n) binary search on sorted arrays.
    - Replaces linear scans for visible data range lookup during zoom/pan.
    - Used internally by the axis limit change handlers [[FastPlot|API Reference: FastPlot]].

- **`minmax_core_mex`** — SIMD‑vectorised per‑pixel min/max reduction.
    - Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle.
    - Used by the `'minmax'` downsampling algorithm.

- **`lttb_core_mex`** — SIMD‑accelerated largest‑triangle‑three‑buckets.
    - Replaces the MATLAB triangle‑area loop with vectorised computation.
    - Used when downsampling is set to `'lttb'`.

- **`to_step_function_mex`** — SIMD step‑function conversion for time‑varying thresholds.
    - Expands (X,Y) threshold points into a staircase representation efficiently.

### Threshold Processing

- **`violation_cull_mex`** — Fused threshold violation detection and pixel culling.
    - Single‑pass algorithm replaces two‑pass MATLAB logic.
    - Used during violation marker rendering when zooming/panning.

- **`compute_violations_mex`** — Batch violation detection.
    - Processes many points at once, avoiding slow per‑point MATLAB comparisons.
    - Used by [[Sensors|API Reference: Sensors]]`Sensor.resolve()` pipeline.

### Data Storage

- **`build_store_mex`** — Bulk SQLite writer for initialising a `FastSenseDataStore`.
    - Uses SIMD to compute per‑chunk Y min/max while writing.
    - Eliminates ~20 K MATLAB‑to‑MEX round‑trips.

- **`resolve_disk_mex`** — SQLite‑backed sensor resolution.
    - Reads chunks from the database without loading full datasets.
    - Used by `Sensor.resolve()` when the store is on disk.

- **`mksqlite`** — SQLite3 MEX interface with typed BLOB support.
    - Serialises MATLAB arrays preserving type and shape.
    - Shared by `FastSenseDataStore`, the disk‑based sensor resolver, and the MonitorTag persistence cache.

## Fallback Behaviour

When a MEX file is absent:

- A pure‑MATLAB equivalent is used automatically. For some functions (e.g., `binary_search`) the fallback code is in the same `.m` file; for others a dedicated implementation lives in `libs/FastSense/private/`.
- Availability is checked **once per session** using `exist('function_name','file')` and cached in a persistent variable (see `binary_search.m`).
- Numerical results and API are identical.
- Performance remains excellent for datasets under ~10 M points.

## Compilation Process

The `build_mex()` function performs these steps:

1. **Detect architecture** — normalises platform strings (`'maca64'`, `'aarch64'`, etc.) into `'arm64'` or `'x86_64'`.
2. **Select compiler** — on Octave, prefers a real GCC installation (searched via Homebrew) for better auto‑vectorisation; on MATLAB uses the configured default compiler.
3. **Set SIMD flags** — chooses `-mavx2 -mfma` (GCC/Clang) or `/arch:AVX2` (MSVC) for x86\_64; for ARM64 uses NEON‑enabling flags (implicit on Apple Silicon).
4. **Compile sources** — builds each MEX source, linking the bundled SQLite3 amalgamation where needed.
5. **Handle failures** — if AVX2 compilation fails on x86\_64, retries with SSE2 flags.
6. **Copy shared files** — `violation_cull_mex`, `compute_violations_mex`, `resolve_disk_mex`, and `to_step_function_mex` are copied into `SensorThreshold/private/` for cross‑library availability.

A deterministic fingerprint (see `mex_stamp.m`) is computed from the source files and `build_mex.m` itself; if the fingerprint matches a stored token, compilation is skipped entirely.

## Verifying Installation

Test that MEX functions produce identical results to their MATLAB fallbacks:

```matlab
install;                    % ensures all paths are set
addpath('tests');
test_mex_parity;            % Verify MEX matches MATLAB output
test_mex_edge_cases;        % Test edge cases (empty, NaN, single point)
```

The test suite validates numerical accuracy across all MEX functions.
