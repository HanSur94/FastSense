<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure‑MATLAB fallbacks — behaviour is identical.

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your architecture and compiles all MEX functions with appropriate SIMD optimisations.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools |
| Linux | GCC |
| Windows | MSVC |

SQLite3 is bundled as an amalgamation and compiled directly into MEX files that need it — no system installation required.

## Architecture Support

All MEX functions include a common SIMD abstraction layer that adapts to your CPU:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON | – |
| Other | Scalar operations | – |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2.

## Accelerated Functions

### Core Downsampling

**binary_search_mex** — O(log n) binary search for visible data range
- **Speedup**: 10–20× over MATLAB's `find`
- **Used by**: zoom/pan callbacks to locate visible indices

**minmax_core_mex** — per‑pixel MinMax reduction with SIMD vectorisation
- **Speedup**: 3–10× over pure MATLAB
- **SIMD**: processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle
- **Used by**: default downsampling algorithm in [[FastPlot]]

**lttb_core_mex** — Largest Triangle Three Buckets with SIMD triangle area computation
- **Speedup**: 10–50× over MATLAB implementation
- **Used by**: LTTB downsampling method

### Threshold Processing

**violation_cull_mex** — fused threshold violation detection and pixel culling
- **Speedup**: significant (single‑pass vs two‑pass MATLAB)
- **Used by**: violation marker rendering during zoom/pan

**compute_violations_mex** — batch threshold violation detection
- **Speedup**: significant over per‑point MATLAB comparison
- **Used by**: [[Sensors]] resolution pipeline

**to_step_function_mex** — SIMD conversion of threshold X/Y to step‑function form
- **Speedup**: ~5–10× over MATLAB expansion
- **Used by**: threshold line rendering in FastPlot

### Data Storage

**build_store_mex** — bulk SQLite writer for DataStore initialisation
- **Speedup**: 2–3× (eliminates ~20k MATLAB‑to‑MEX round‑trips)
- **SIMD**: accelerated Y min/max computation per chunk
- **Used by**: `FastSenseDataStore` construction

**resolve_disk_mex** — SQLite disk‑based sensor resolution
- **Used by**: `Sensor.resolve()` with disk‑backed storage
- **Benefit**: reads chunks from database without loading full datasets

**mksqlite** — SQLite3 MEX interface with typed BLOB support
- **Used by**: DataStore, disk‑backed sensor resolution
- **Features**: serialises MATLAB arrays preserving type and shape

## Fallback Behavior

When MEX files are unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/`.
- Runtime auto‑detection switches between MEX and MATLAB seamlessly.
- Identical numerical results and API.
- Performance remains excellent for datasets under ~10M points.

## Compilation Process

The `build_mex()` function:

1. **Detects architecture** — normalises platform strings (`maca64`, `aarch64`, …) into canonical labels.
2. **Selects compiler** — prefers GCC on Octave for better auto‑vectorisation; uses MATLAB’s default on MATLAB.
3. **Sets SIMD flags** — chooses instruction sets based on detected CPU architecture.
4. **Compiles FastSense MEX sources** — builds all core MEX files (binary_search, minmax, lttb, violation_cull, compute_violations, resolve_disk, build_store, to_step_function) with bundled SQLite3 amalgamation.
5. **Compiles `mksqlite`** — the SQLite3 MEX interface with the same bundled SQLite.
6. **Copies shared MEX files** — distributes MEX binaries to other library directories (e.g., SensorThreshold/private).
7. **Compiles SensorThreshold MEX kernels** — if the `libs/SensorThreshold/private/mex_src` directory exists, it builds additional MEX such as `delimited_parse_mex` and any future kernels.
8. **Compiles Concurrency MEX** — if the `libs/Concurrency` library is present, `build_concurrency_mex` is called (best‑effort, non‑fatal).

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.

## Rebuild Detection

`build_mex` checks whether the compiled MEX files already exist and skips recompilation when possible. A content‑based fingerprint (`mex_stamp`) is used by the install process to track changes in MEX sources, ensuring a rebuild is triggered only when necessary.
