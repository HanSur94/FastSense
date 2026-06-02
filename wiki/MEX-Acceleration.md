<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure‑MATLAB fallbacks — behavior is identical. The MEX layer accelerates the most compute‑intensive operations: downsampling, binary search, violation detection, SQLite bulk I/O, and step‑function conversion. Additional MEX files for SensorThreshold parsing and Concurrency thread pools are compiled on the same pass.

## Building MEX Files

The installation script (`install.m`) automatically compiles MEX files when they are missing or when the source tree has changed. If you need to force a manual rebuild, run:

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your platform, CPU architecture, and compiler, then selects the best SIMD flags. A lightweight fingerprint (`mex_stamp`) prevents unnecessary recompilation — the build is invoked only if sources have been modified.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools (Clang) |
| Linux | GCC |
| Windows | MSVC |

SQLite3 is bundled as an amalgamation in `private/mex_src/` and compiled directly into MEX files that need it — no system `libsqlite3` installation is required.

## Architecture Support

All MEX functions use a common SIMD abstraction layer that adapts to your CPU:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON (via Clang or GCC) | – |
| Other | Scalar operations | – |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2 flags.

## Accelerated Functions

### Core Downsampling

**`binary_search_mex`** — O(log n) binary search for visible data range  
- **Speedup**: 10–20× over MATLAB’s `find`  
- **Used by**: Zoom/pan callbacks to locate visible indices  

**`minmax_core_mex`** — Per‑pixel MinMax reduction with SIMD vectorization  
- **Speedup**: 3–10× over pure MATLAB  
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle  
- **Used by**: Default downsampling in [[FastPlot|API Reference: FastPlot]]

**`lttb_core_mex`** — Largest Triangle Three Buckets (LTTB) with SIMD triangle area computation  
- **Speedup**: 10–50× over MATLAB implementation  
- **Used by**: LTTB downsampling method

### Threshold Processing

**`violation_cull_mex`** — Fused threshold violation detection and pixel culling  
- **Speedup**: Significant (single‑pass vs two‑pass MATLAB)  
- **Used by**: Violation marker rendering during zoom/pan

**`compute_violations_mex`** — Batch threshold violation detection  
- **Speedup**: Significant over per‑point MATLAB comparison  
- **Used by**: [[Sensors|API Reference: Sensors]] `resolve()` pipeline

**`to_step_function_mex`** — SIMD conversion of threshold (X,Y) pairs to step‑function form  
- **Used by**: Sensor resolution when thresholds are time‑varying

### Data Storage

**`build_store_mex`** — Bulk SQLite writer for `FastSenseDataStore` construction  
- **Speedup**: 2–3× (eliminates ~20 K MATLAB‑to‑MEX round‑trips)  
- **SIMD**: Accelerated Y min/max computation per chunk  
- **Used by**: `FastSenseDataStore` initialization

**`resolve_disk_mex`** — SQLite disk‑based sensor resolution  
- **Used by**: `Sensor.resolve()` with disk‑backed storage  
- **Benefit**: Reads chunks from database without loading full datasets

**`mksqlite`** — SQLite3 MEX interface with typed BLOB support  
- **Used by**: DataStore, disk‑backed sensor resolution  
- **Features**: Serialises MATLAB arrays preserving type and shape

### SensorThreshold Parsing

**`delimited_parse_mex`** — Parses delimited text messages (e.g. CSV, TSV) with SIMD acceleration  
- **Compiled by**: `build_mex` alongside FastSense kernels  
- **Location**: `libs/SensorThreshold/private/`

### Concurrency Library

**`thread_pool_mex`** (compiled via `build_concurrency_mex`) — provides a native thread pool for parallel data operations.  
- **Best‑effort** compilation; failure does not block the main build.

## Fallback Behaviour

When a MEX file is unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/`.
- Runtime auto‑detection switches between MEX and MATLAB seamlessly.
- Numerical results and API are identical.
- Performance remains excellent for datasets under ~10 M points.

Example of auto‑detection in `binary_search`:

```matlab
function idx = binary_search(x, val, direction)
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('binary_search_mex', 'file') == 3);
    end
    if useMex
        idx = binary_search_mex(x, val, direction);
        return;
    end
    % ... pure‑MATLAB fallback follows
```

## Compilation Process

The `build_mex()` function performs the following steps:

1. **Architecture detection** — normalises platform strings (e.g. `maca64`, `aarch64`, `x86_64`) into canonical labels.
2. **Compiler selection** — prefers GCC on Octave for better auto‑vectorisation; uses MATLAB’s default (Clang or MSVC) on MATLAB.
3. **SIMD flag assignment** — chooses `-mavx2 -mfma` (x86_64) or NEON implicit (Apple Silicon).
4. **Source compilation** — builds all MEX files listed in the table above, including bundled `sqlite3.c`.
5. **AVX2 failure recovery** — on x86_64, if AVX2 fails the script automatically retries with SSE2 flags.
6. **File distribution** — copies shared MEX binaries into `SensorThreshold/private/` and (if applicable) `Concurrency/`.
7. **Sensor‑specific kernels** — additionally compiles `delimited_parse_mex` (and future kernels) from `SensorThreshold/private/mex_src/`.
8. **Concurrency MEX** — invokes `build_concurrency_mex()` if the Concurrency library is present.

The build is incremental thanks to the `mex_stamp` function: a SHA‑256 or size‑based fingerprint of all MEX source files and `build_mex.m` is stored in `private/.mex‑version`. If the stamp matches, `install.m` skips the compilation entirely.

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.
