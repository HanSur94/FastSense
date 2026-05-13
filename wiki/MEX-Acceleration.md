<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure‑MATLAB fallbacks — behaviour is identical.

---

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your architecture and compiles all MEX functions with the best available SIMD optimisations. SQLite3 is bundled as an amalgamation and compiled directly into the MEX files that need it — no system `libsqlite3` installation is required.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS   | Xcode Command Line Tools (Clang) |
| Linux   | GCC |
| Windows | MSVC |

---

## Architecture Support

All MEX functions include a common SIMD abstraction layer that adapts to your CPU:

| Architecture        | SIMD Instructions | Fallback  |
|---------------------|-------------------|-----------|
| x86_64              | AVX2 + FMA        | SSE2      |
| ARM64 (Apple Silicon)| NEON              | –         |
| Other               | Scalar operations | –         |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2.

---

## Accelerated Functions

### Core Downsampling

- **`binary_search_mex`** – O(log n) binary search for the visible data range  
  **Speedup**: 10–20× over MATLAB’s `find`  
  **Used by**: Zoom/pan callbacks to locate visible indices  
  *Fallback*: MATLAB function `binary_search()` (iterative binary search)

- **`minmax_core_mex`** – Per‑pixel MinMax reduction with SIMD vectorisation  
  **Speedup**: 3–10× over pure MATLAB  
  **SIMD**: Processes 4 doubles per cycle (AVX2) or 2 doubles (NEON)  
  **Used by**: Default downsampling algorithm in [[FastPlot|API Reference: FastPlot]]

- **`lttb_core_mex`** – Largest‑Triangle‑Three‑Buckets with SIMD triangle‑area computation  
  **Speedup**: 10–50× over the MATLAB implementation  
  **Used by**: LTTB downsampling method

### Threshold Processing

- **`violation_cull_mex`** – Fused threshold‑violation detection and pixel culling  
  **Speedup**: Significant (single‑pass vs two‑pass MATLAB)  
  **Used by**: Violation marker rendering during zoom/pan

- **`compute_violations_mex`** – Batch threshold‑violation detection  
  **Speedup**: Significant over per‑point MATLAB comparison  
  **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline

- **`to_step_function_mex`** – SIMD‑accelerated conversion to step‑function form for time‑varying thresholds  
  **Used by**: Threshold series construction in `Sensor.resolve()`

### Data Storage

- **`build_store_mex`** – Bulk SQLite writer for `FastSenseDataStore` initialisation  
  **Speedup**: 2–3× (eliminates ~20 K MATLAB‑to‑MEX round‑trips)  
  **SIMD**: Accelerated Y‑min/max computation per chunk  
  **Used by**: `FastSenseDataStore` constructor

- **`resolve_disk_mex`** – SQLite disk‑based sensor resolution  
  **Used by**: `Sensor.resolve()` with disk‑backed storage  
  **Benefit**: Reads chunks from the database without loading the full dataset

- **`mksqlite`** – SQLite3 MEX interface with typed BLOB support  
  **Used by**: `FastSenseDataStore`, disk‑backed sensor resolution  
  **Features**: Serialises MATLAB arrays preserving type and shape

---

## Fallback Behaviour

When MEX files are unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/`.
- Runtime auto‑detection switches between MEX and MATLAB seamlessly.
- Numerical results and API are identical.
- Example: `binary_search()` checks for `binary_search_mex` once per session and falls back to an iterative O(log n) implementation.
- Performance remains excellent for datasets under ~10 M points.

---

## Compilation Process

The `build_mex()` function:

1. **Detects architecture** – normalises platform strings (`maca64`, `aarch64`, …) into canonical labels.
2. **Selects compiler** – prefers real GCC on Octave for better auto‑vectorisation; uses MATLAB’s default on MATLAB.
3. **Sets SIMD flags** – chooses instruction sets based on the detected CPU architecture.
4. **Compiles sources** – builds all MEX files with the bundled SQLite3 amalgamation.
5. **Handles failures** – automatically retries x86_64 builds with SSE2 if AVX2 fails.
6. **Copies shared files** – distributes MEX binaries to other library directories (e.g., `SensorThreshold/private/`).

Additionally, a **mex‑stamp** (`mex_stamp.m`) is used to determine whether recompilation is necessary — if the stamp matches the installed version, `build_mex()` is skipped during `install()`.

---

## Verifying Installation

After building, run the provided test suite to confirm that MEX functions produce identical results to their MATLAB fallbacks:

```matlab
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Edge‑case tests (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases such as empty arrays, single points, and `NaN` values.
