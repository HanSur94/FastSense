<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure-MATLAB fallbacks — behavior is identical.

## Building MEX Files

The MEX compilation is fully automated. Running `install.m` checks a **stamp** (a fingerprint of all MEX source files and the build script) against a stored token; if the stamp matches, compilation is skipped entirely. When a rebuild is needed, `install.m` calls `build_mex()`.

```matlab
install;   % Checks stamp and compiles MEX if necessary
```

Alternatively, you can force a build manually:

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your architecture and compiles all MEX functions with appropriate SIMD optimizations. SQLite3 is bundled as an amalgamation (`sqlite3.c`) and compiled directly into the MEX files that need it — no system SQLite installation is required.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools (Clang) |
| Linux | GCC (preferred) or system default |
| Windows | MSVC (MATLAB default) |

On Linux, the script searches for real GCC (e.g., `gcc-10` through `gcc-15`) in `/opt/homebrew/bin` and `/usr/local/bin` for better auto‑vectorization.

## Architecture Support

All MEX functions include a common SIMD abstraction layer that adapts to your CPU:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON | – |
| Other | Scalar operations | – |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2 flags.

## Accelerated Functions

### Core Downsampling

**binary_search_mex** — O(log n) binary search for visible data range  
- **Speedup**: 10‑20× over MATLAB’s `find`  
- **Used by**: zoom/pan callbacks to locate visible indices  

**minmax_core_mex** — per‑pixel MinMax reduction with SIMD vectorisation  
- **Speedup**: 3‑10× over pure MATLAB  
- **SIMD**: processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle  
- **Used by**: default downsampling algorithm in [[FastPlot|API Reference: FastPlot]]

**lttb_core_mex** — Largest Triangle Three Buckets with SIMD triangle area computation  
- **Speedup**: 10‑50× over MATLAB implementation  
- **Used by**: LTTB downsampling method

### Threshold Processing

**violation_cull_mex** — fused threshold violation detection and pixel culling  
- **Speedup**: significant (single‑pass vs two‑pass MATLAB)  
- **Used by**: violation marker rendering during zoom/pan  

**compute_violations_mex** — batch threshold violation detection  
- **Speedup**: significant over per‑point MATLAB comparison  
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline  

**to_step_function_mex** — SIMD conversion of threshold data to step‑function format  
- **Speedup**: faster than MATLAB vectorised approach  
- **Used by**: threshold rendering

### Data Storage

**build_store_mex** — bulk SQLite writer for FastSenseDataStore initialisation  
- **Speedup**: 2‑3× (eliminates ~20 K MATLAB‑to‑MEX round‑trips)  
- **SIMD**: accelerated Y min/max computation per chunk  
- **Used by**: `FastSenseDataStore` construction  

**resolve_disk_mex** — SQLite disk‑based sensor resolution  
- **Used by**: `Sensor.resolve()` with disk‑backed storage  
- **Benefit**: reads chunks from the database without loading full datasets  

**mksqlite** — SQLite3 MEX interface with typed BLOB support  
- **Used by**: DataStore, disk‑backed sensor resolution  
- **Features**: serialises MATLAB arrays preserving type and shape  

### SensorThreshold Kernels

**delimited_parse_mex** — fast parsing of delimited text data  
- **Used by**: Tag parsing pipelines  

Additional kernels (monitor FSM, composite merge, aggregate matrix) are added as the library evolves.

### Concurrency Library

**build_concurrency_mex** — a best‑effort compilation of any MEX files in the Concurrency library; failure does **not** abort the main build.

## Fallback Behavior

When MEX files are unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/` (or the appropriate library’s `private/` folder).  
- Runtime auto‑detection switches between MEX and MATLAB seamlessly.  
- Identical numerical results and API.  
- Performance remains excellent for datasets under ~10 M points.

For example, `binary_search.m` checks once per session whether `binary_search_mex` exists and uses the MEX if found; otherwise it falls back to an iterative MATLAB binary search.

## Compilation Process

The `build_mex()` function performs the following steps:

1. **Detects architecture** — normalises platform strings (`maca64`, `aarch64`, `x86_64‑pc‑linux‑gnu`, etc.) into canonical labels (`arm64`, `x86_64`, `unknown`).  
2. **Selects compiler** — prefers GCC on Octave for better auto‑vectorisation; uses MATLAB’s default on MATLAB.  
3. **Sets SIMD flags** — chooses instruction sets based on the detected CPU:  
   - **x86_64**: `-mavx2 -mfma` (GCC/Clang) or `/arch:AVX2` (MSVC)  
   - **ARM64**: `-mcpu=apple-m3` on Octave/GCC; NEON enabled implicitly on Clang  
4. **Compiles all MEX sources** — builds each `.c` file in `private/mex_src/` together with the bundled `sqlite3.c` when required.  
   - If an AVX2 build fails on x86_64, it automatically retries with SSE2 flags.  
5. **Compiles `mksqlite.c`** — the SQLite3 MEX interface, compiled with `-DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION`.  
6. **Copies shared MEX files** — distributes binaries needed by `SensorThreshold` into its `private/` folder.  
7. **Compiles SensorThreshold MEX kernels** (if present) — e.g. `delimited_parse_mex`.  
8. **Attempts Concurrency MEX build** — non‑fatal; warnings are issued on failure.

### Stamp‑Based Skip

Before `build_mex()` is called, the installation script computes a **content‑based fingerprint** using `mex_stamp.m`. The fingerprint includes:

- All `.c` and `.h` files in `libs/FastSense/private/mex_src/`  
- `build_mex.m` itself  
- `mksqlite.c`  

The stamp is stored as a SHA‑256 hash (when available) or a fallback fingerprint of byte samples. If the stored stamp in `private/.mex-version` matches, the entire MEX compilation is **skipped**. This ensures you never rebuild unless source files have changed.

Within `build_mex()`, a secondary mtime check per file also prevents recompilation of individual sources that are already up to date.

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;          % Verify MEX matches MATLAB output
test_mex_edge_cases;      % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.

---

*See also:* [[Installation]], [[Performance]], `build_mex.m`, `mex_stamp.m`.
