<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes a set of optional C MEX functions that leverage SIMD instructions and compiled C code for maximum performance. All MEX functions have pure‑MATLAB fallbacks — the behavior, numerical results, and API are identical whether the MEX is available or not.

## Building MEX Files

To compile all MEX functions, run the build script from the FastSense library directory:

```matlab
cd libs/FastSense
build_mex();
```

The script auto‑detects your CPU architecture and compiler environment, selects the best SIMD instruction set, and compiles all MEX source files. SQLite3 is bundled as an amalgamation and compiled directly into the MEX files that need it — no system installation of SQLite is required.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools (Clang) or real GCC |
| Linux | GCC (auto‑detected) or system default |
| Windows | MSVC (MATLAB), GCC (Octave) |

On Octave the script prefers a versioned Homebrew GCC for better auto‑vectorisation; it falls back gracefully if none is found.

## Architecture Support

The build script normalises the platform‑specific output of `computer('arch')` into one of three canonical labels, then selects SIMD flags accordingly:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA (or SSE2 if AVX2 fails) | SSE2 |
| ARM64 (Apple Silicon) | NEON (implicit on Clang, explicit on GCC) | — |
| Other | Scalar operations | — |

If the initial AVX2 compile step fails (e.g., on older hardware), the script automatically retries with SSE2 and reports the status.

## Accelerated Functions

### Core Downsampling

**binary_search_mex** — O(log n) binary search on sorted arrays.
- Used internally for quickly locating visible data ranges.

**minmax_core_mex** — Per‑pixel MinMax reduction with SIMD vectorisation.
- Processes multiple doubles per cycle depending on architecture (4 for AVX2, 2 for NEON).
- The default downsampling algorithm in [[FastPlot|API Reference: FastPlot]] uses this kernel.

**lttb_core_mex** — Largest Triangle Three Buckets downsampling with SIMD‑accelerated triangle area computation.
- Provides a visually pleasing reduction that preserves the overall shape of the data.

### Threshold Processing

**violation_cull_mex** — Fused threshold violation detection and pixel culling.
- Combines violation search and rendering cull into a single pass, eliminating redundant loops.

**compute_violations_mex** — Batch threshold violation detection.
- Designed for the `Sensor.resolve()` pipeline in [[Sensors|API Reference: Sensors]].

**to_step_function_mex** — SIMD‑optimised conversion of raw (X,Y) pairs to a step‑function representation.
- Used internally for time‑varying thresholds.

### Data Storage

**build_store_mex** — Bulk SQLite writer for initialising a `FastSenseDataStore`.
- Accelerates the chunked insert of large X/Y datasets.

**resolve_disk_mex** — Disk‑based sensor resolution reading chunks from a SQLite database.
- Used by `Sensor.resolve()` when operating on disk‑backed data.

**mksqlite** — SQLite3 MEX interface with typed BLOB support.
- Serialises MATLAB arrays preserving type and shape.
- Bundled with the SQLite amalgamation; no external library needed.

## Fallback Behaviour

When a MEX file is unavailable (not compiled, removed, or on an unsupported platform), the corresponding pure‑MATLAB implementation is used automatically. For example, in `binary_search.m`, a persistent variable checks for `binary_search_mex` once per session:

```matlab
persistent useMex;
if isempty(useMex)
    useMex = (exist('binary_search_mex', 'file') == 3);
end
if useMex
    idx = binary_search_mex(x, val, direction);
else
    % iterative MATLAB binary search
end
```

This pattern ensures identical numerical results and zero configuration burden — the library runs correctly in any environment, with or without MEX acceleration.

## Compilation Process

`build_mex()` performs the following steps:

1. **Detects architecture** — normalises `computer('arch')` into `'x86_64'`, `'arm64'`, or `'unknown'`.
2. **Selects compiler** — on Octave searches for a real GCC; on MATLAB uses the configured default (Clang on macOS, MSVC on Windows).
3. **Sets SIMD flags** — chooses flags such as `-mavx2 -mfma` (x86_64) or `-mcpu=apple-m3` (ARM64 Octave).
4. **Compiles sources** — builds all listed `.c` files, several linked with the bundled `sqlite3.c`. Outputs go into `private/` (MATLAB) or a platform‑tagged subdirectory (Octave).
5. **Handles failures** — on x86_64, an AVX2 compilation failure triggers an automatic retry with SSE2.
6. **Copies shared files** — distributes commonly used MEX binaries (e.g., `violation_cull_mex`, `compute_violations_mex`) to the `SensorThreshold/private/` directory so that the [[Sensors|API Reference: Sensors]] library can also benefit.

## Verifying Installation

After building, the test suite verifies that MEX‑accelerated functions produce identical results to their MATLAB fallbacks. Run the standard install procedure to include the tests on the path, then execute the parity and edge‑case tests:

```matlab
install;
addpath('tests');
test_mex_parity;
test_mex_edge_cases;
```

The parity tests validate numerical accuracy across all MEX functions, and the edge‑case tests cover empty arrays, single‑point inputs, and NaN values.

## Performance

For most datasets under ~10M points the pure‑MATLAB fallbacks already provide excellent performance. The MEX acceleration becomes most valuable when working with very large datasets, frequent zoom/pan updates, or live‑streaming scenarios where the downsampling and violation detection kernels are called many times per second. See [[Performance]] for a broader discussion of FastSense’s speed characteristics.
