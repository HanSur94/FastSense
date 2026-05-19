<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions that leverage SIMD intrinsics for maximum performance. Every MEX function has a pure‑MATLAB fallback — behaviour is identical regardless of whether the compiled version is available.

## Building MEX Files

Navigate to the FastSense library folder and run `build_mex`:

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your CPU architecture and selects the appropriate SIMD instruction set. It compiles all MEX source files found in `private/mex_src/` and places the resulting binaries into `private/` (MATLAB) or a platform‑tagged subdirectory (Octave).

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools (Clang) |
| Linux | GCC |
| Windows | MSVC (MATLAB) or MinGW (Octave) |

SQLite3 is bundled as an amalgamation (`sqlite3.c` + `sqlite3.h`) and compiled directly into the MEX files that need it — no system installation of `libsqlite3` is required.

## Architecture Support

All MEX functions share a common SIMD abstraction layer that adapts to your CPU:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON | — |
| Other | Scalar operations | — |

If AVX2 compilation fails on x86_64 (for example, on older hardware), the build script automatically retries with SSE2 flags.

## Accelerated Functions

### Core Downsampling

**`binary_search_mex`** – O(log n) binary search for visible data range.  
- **Speedup**: 10–20× over MATLAB’s `find`.  
- **Used by**: zoom/pan callbacks to locate visible indices.

**`minmax_core_mex`** – Per‑pixel MinMax reduction with SIMD vectorisation.  
- **Speedup**: 3–10× over pure MATLAB.  
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle.  
- **Used by**: default downsampling algorithm in [[FastPlot|API Reference: FastPlot]].

**`lttb_core_mex`** – Largest Triangle Three Buckets with SIMD triangle area computation.  
- **Speedup**: 10–50× over MATLAB.  
- **Used by**: LTTB downsampling method.

**`to_step_function_mex`** – SIMD conversion of point lists to step‑function edges.  
- **Speedup**: tangible for large threshold arrays.  
- **Used by**: time‑varying threshold rendering.

### Threshold Processing

**`violation_cull_mex`** – Fused threshold violation detection and pixel culling.  
- **Speedup**: significant (single‑pass vs two‑pass MATLAB).  
- **Used by**: violation marker rendering during zoom/pan.

**`compute_violations_mex`** – Batch threshold violation detection.  
- **Speedup**: significant over per‑point MATLAB comparison.  
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline.

### Data Storage

**`build_store_mex`** – Bulk SQLite writer for DataStore initialisation.  
- **Speedup**: 2–3× (eliminates ~20 K MATLAB‑to‑MEX round‑trips).  
- **SIMD**: accelerated Y min/max computation per chunk.  
- **Used by**: `FastSenseDataStore` construction.

**`resolve_disk_mex`** – SQLite disk‑based sensor resolution.  
- **Used by**: `Sensor.resolve()` with disk‑backed storage.  
- **Benefit**: reads chunks from the database without loading the full dataset into memory.

**`mksqlite`** – SQLite3 MEX interface with typed BLOB support.  
- **Used by**: DataStore, disk‑backed sensor resolution.  
- **Features**: serialises MATLAB arrays preserving type and shape.

## Fallback Behaviour

When MEX files are unavailable (for example, not yet compiled, or on an unsupported platform), each function automatically falls back to its pure‑MATLAB equivalent. The fallback files live in `libs/FastSense/private/`. Runtime detection uses `exist(... 'file')` and caches the result in a persistent variable so there is no per‑call overhead.

Identical numerical results and API are guaranteed. Performance remains excellent for datasets up to ~10 M points even without MEX.

*Example* – the fallback in `binary_search.m`:

```matlab
persistent useMex;
if isempty(useMex)
    useMex = (exist('binary_search_mex', 'file') == 3);
end
if useMex
    idx = binary_search_mex(x, val, direction);
    return;
end
% ... pure-MATLAB iterative binary search ...
```

## Compilation Process

The `build_mex()` function performs these steps:

1. **Detect architecture** – normalises `computer('arch')` strings (`maca64`, `aarch64`, etc.) into canonical labels `'x86_64'` or `'arm64'`.
2. **Select compiler** – on Octave it prefers real GCC (searched in common Homebrew paths) for better auto‑vectorisation; on MATLAB it uses the system default (Xcode Clang on macOS, MSVC on Windows).
3. **Set SIMD flags** – chooses instruction sets based on the detected architecture:
   - x86_64: `-O3 -mavx2 -mfma -ftree-vectorize -ffast-math` (GCC/Clang) or `/O2 /arch:AVX2 /fp:fast` (MSVC)
   - ARM64: NEON is enabled implicitly on Clang; on GCC an explicit `-mcpu=apple-m3` is added.
4. **Compile sources** – builds each MEX file with the bundled SQLite3 amalgamation where needed.
5. **Handle failures** – on x86_64, if AVX2 compilation fails, the file is retried with SSE2 flags (`-msse2` / `/arch:SSE2`).
6. **Compile mksqlite** – built with the same SQLite3 amalgamation; if it fails, a warning is issued and DataStore falls back to binary file storage.
7. **Copy shared files** – `violation_cull_mex`, `compute_violations_mex`, `resolve_disk_mex`, and `to_step_function_mex` are copied into `../SensorThreshold/private/` so they are available to the sensors library.

*Tip*: The `install.m` script uses a fingerprinting mechanism (`mex_stamp`) to detect whether the MEX sources have changed since the last build, avoiding unnecessary recompilation. `build_mex` itself also skips files that already exist, making it safe to call repeatedly.

## Verifying Installation

Run the parity and edge‑case tests to confirm that MEX functions produce identical results to the MATLAB fallbacks:

```matlab
install;                        % adds all required paths
addpath('tests');
test_mex_parity;                % verify MEX matches MATLAB output
test_mex_edge_cases;            % test empty arrays, NaN, single points, etc.
```

The test suite validates numerical accuracy and handles edge cases across all MEX functions. If any MEX file is missing, the tests still pass because the fallback is indistinguishable.

## Troubleshooting

- **`mksqlite` fails to compile** – This is non‑fatal. FastSense will fall back to a binary file format for DataStore. Extra data columns (`addColumn`) require `mksqlite`, however.
- **AVX2 compilation error on x86_64** – The build script retries with SSE2 automatically. If both fail, check your compiler installation and C compiler configuration (`mex -setup` on MATLAB).
- **Octave GCC not found** – The build script searches `/opt/homebrew/bin/gcc-*` (macOS) and `/usr/local/bin/gcc-*`. Install a versioned GCC via Homebrew (`brew install gcc`) or set the `CC` environment variable before calling `build_mex`:

  ```matlab
  setenv('CC', '/path/to/gcc-14');
  build_mex();
  ```

- **Performance still slow for very large data** – Ensure MEX files are actually loaded: `which binary_search_mex` should show a compiled file. Also confirm that `FastSense` is not running in pure‑MATLAB mode (check the `Verbose` flag to see which codepath is taken during rendering).
```
