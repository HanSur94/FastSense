<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions that leverage SIMD intrinsics for maximum performance. Every MEX function has a pure‑MATLAB fallback — behavior and results are identical whether the MEX is available or not.

Use MEX acceleration when you work with large datasets (millions of points) and need fluid zoom/pan in dashboards. On systems without a C compiler, the fallback still provides excellent performance for datasets under ~10M points.

## Building MEX Files

From the root of the FastSense library (the directory containing `install.m`), run:

```matlab
cd libs/FastSense
build_mex();
```

The build script auto-detects your CPU architecture and compiles all MEX source files with the appropriate SIMD flags.

### Requirements

| Platform   | Compiler                                   |
|------------|--------------------------------------------|
| macOS      | Xcode Command Line Tools (Clang)           |
| Linux      | GCC (real GCC, not Clang‑as‑gcc)           |
| Windows    | Microsoft Visual C++ (MSVC)                |

SQLite3 is bundled as the [amalgamation](https://www.sqlite.org/amalgamation.html) (`sqlite3.c` + `sqlite3.h`) in `private/mex_src/` and compiled directly into the MEX files that require it — no system `libsqlite3` installation is necessary.

## Architecture Support

All MEX functions share a common SIMD abstraction layer that adapts to the detected CPU:

| Architecture            | SIMD Instructions | Fallback       |
|-------------------------|-------------------|----------------|
| x86‑64 (Intel/AMD)     | AVX2 + FMA        | SSE2           |
| ARM64 (Apple Silicon)  | NEON (implicit)   | –              |
| Other                  | Scalar operations | –              |

If the initial AVX2 compilation fails on x86‑64 (e.g., on older hardware without AVX2 support), the build script automatically retries with SSE2 flags. On ARM64, NEON is enabled by default by both Clang (macOS) and GCC (Linux/Octave).

## Accelerated Functions

The following MEX files are compiled by `build_mex()`:

### Core Downsampling

- **`binary_search_mex`** — `O(log n)` binary search for the visible data range.  
  Speedup: 10–20× over MATLAB’s `find`.  
  Used in: zoom/pan callbacks to locate visible indices.  
  See [[FastPlot|API Reference: FastPlot]] render pipeline.

- **`minmax_core_mex`** — Per‑pixel MinMax reduction with SIMD vectorisation.  
  Speedup: 3–10× over pure MATLAB.  
  SIMD: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle.  
  Used by: default MinMax downsampling in [[FastPlot|API Reference: FastPlot]].

- **`lttb_core_mex`** — Largest‑Triangle‑Three‑Buckets kernel using SIMD triangle area computation.  
  Speedup: 10–50× over the MATLAB implementation.  
  Used by: LTTB downsampling method.

### Threshold Processing

- **`violation_cull_mex`** — Fused threshold violation detection and pixel culling in a single pass.  
  Speedup: Significant (single‑pass vs two‑pass MATLAB).  
  Used by: violation marker rendering during zoom/pan.

- **`compute_violations_mex`** — Batch threshold violation detection for all thresholds.  
  Speedup: Significant over per‑point MATLAB comparisons.  
  Used by: [[Sensors|API Reference: Sensors]] resolution pipeline.

### Data Storage (SQLite Backend)

- **`build_store_mex`** — Bulk SQLite writer for `FastSenseDataStore` initialisation.  
  Speedup: 2–3× (eliminates ~20K MATLAB‑to‑MEX round‑trips).  
  SIMD: Accelerated Y min/max computation per chunk.  
  Used by: `FastSenseDataStore` constructor.

- **`resolve_disk_mex`** — Disk‑based sensor resolution for large datasets.  
  Used by: `Sensor.resolve()` with disk‑backed storage.  
  Benefit: Reads chunks directly from the database without loading full arrays into memory.

- **`mksqlite`** — SQLite3 MEX interface with typed BLOB support.  
  Used by: `DataStore`, disk‑backed sensor resolution.  
  Features: Serialises MATLAB arrays while preserving type and shape; supports WAL mode for concurrent reads.

### Helpers

- **`to_step_function_mex`** — SIMD‑accelerated conversion of time‑varying thresholds into step functions.  
  Used by: threshold rendering.

All MEX functions have corresponding pure‑MATLAB implementations in `libs/FastSense/private/`. A runtime check selects MEX when available; otherwise the MATLAB fallback executes.

## Fallback Behavior

When MEX files are not available (compilation failed, platform without a C compiler, or MEX not on the path):

- Each function uses its pure‑MATLAB equivalent.
- The runtime auto‑detection is done once per session (e.g., `binary_search.m` checks `exist('binary_search_mex', 'file')` and caches the result in a persistent variable).
- Numerical results and API are **identical** to the MEX versions.
- Performance remains excellent for datasets under ~10 million points.

No user intervention is required; the library degrades gracefully.

## Compilation Process

The `build_mex()` function performs the following steps:

1. **Architecture detection** – normalises platform strings (`maca64`, `aarch64‑…`, `glnxa64`, etc.) into canonical labels: `x86_64`, `arm64`, or `unknown`.
2. **Compiler selection** –  
   - **Octave**: searches for a real GCC binary (preferring Homebrew `gcc‑15` down to `gcc‑10`) because GCC provides better auto‑vectorisation than Octave’s default Clang. Falls back to the system default if none is found.  
   - **MATLAB**: uses the configured default compiler (Xcode Clang on macOS, MSVC on Windows) because MATLAB passes compiler‑specific linker flags that GCC may reject.
3. **SIMD flag selection** – chooses instruction set flags based on the canonical architecture:
   - `x86_64` → `-mavx2 -mfma -O3 -ffast-math` (MSVC: `/arch:AVX2 /fp:fast`)  
   - `arm64` → NEON is enabled implicitly by Clang; GCC gets `-mcpu=apple-m3` on Apple Silicon.  
   - `unknown` → scalar‑only `-O3 -ffast-math`.
4. **Compilation of individual MEX files** – iterates through the list of source files, skipping any that already exist (based on timestamp, with a backup mtime‑based skip gate; see `build_mex.m` for details).  
   - Each MEX is linked with the required extra sources (e.g., `sqlite3.c` for database‑related MEX files).  
   - If a compilation fails on x86‑64 with AVX2 flags, it is automatically retried with SSE2 flags.
5. **Compilation of `mksqlite`** – builds the SQLite3 MEX interface using the same SIMD flags and the bundled sqlite3 amalgamation.
6. **Copy shared MEX files** – distributes `violation_cull_mex`, `compute_violations_mex`, `resolve_disk_mex`, and `to_step_function_mex` to the `SensorThreshold/private/` directory so they are usable by the sensor resolution subsystem.

The build system is self‑contained; it never relies on a system‑wide `libsqlite3`. Octave uses `mkoctfile` while MATLAB uses the `mex` command. Platform‑specific extensions (`.mexa64`, `.mexmaci64`, etc.) are handled automatically.

## Verifying Installation

After a successful build, you can run the built‑in tests to confirm that MEX functions produce identical results to the MATLAB fallbacks:

```matlab
install;                     % add FastSense to the path
addpath('tests');
test_mex_parity;             % numerical comparison
test_mex_edge_cases;         % empty arrays, NaN, single point, etc.
```

The test suite verifies numerical accuracy across all MEX functions and exercises edge cases like empty inputs, single‑element vectors, and NaN values to ensure the fallbacks are robust.

If any MEX file failed to compile, a warning is printed during `build_mex()` and the section “× failed” tells you which functions will fall back to MATLAB code.

## Related Pages

- [[Installation]] – initial setup and MEX compilation as part of `install.m`  
- [[FastPlot|API Reference: FastPlot]] – the plot class that benefits most from MEX acceleration  
- [[Sensors|API Reference: Sensors]] – uses `compute_violations_mex` and `resolve_disk_mex` for resolution  
- [[Performance]] – overall performance architecture and tuning
