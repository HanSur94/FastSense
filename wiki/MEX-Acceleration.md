<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure-MATLAB fallbacks — behavior is identical.

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto‑detects your architecture and compiles all MEX functions with appropriate SIMD optimizations. If the required compilers are present (see [Requirements](#Requirements)), the compiled binaries are placed in `libs/FastSense/private/` (MATLAB) or a platform‑tagged sub‑folder like `private/octave‑macos‑arm64/` (Octave).

The build is automatically invoked by `install.m` only when necessary — a content‑based stamp file (`.mex-version`) prevents re‑compilation when nothing has changed. You can safely run `build_mex()` at any time; it skips already‑compiled files and avoids redundant work.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools |
| Linux | GCC |
| Windows | MSVC |

SQLite3 is bundled as an amalgamation and compiled directly into MEX files that need it — no system installation required. The files `build_store_mex`, `resolve_disk_mex`, and `mksqlite` all embed the SQLite3 library.

## Architecture Support

All MEX functions include a common SIMD abstraction layer that adapts to your CPU:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64    | AVX2 + FMA  | SSE2 (automatically if AVX2 fails) |
| ARM64 (Apple Silicon) | NEON  | – |
| Other     | Scalar operations | – |

On **Octave** running on ARM64, the build script explicitly adds `-mcpu=apple-m3` when GCC is available to enable NEON auto‑vectorisation. On **MATLAB**, Clang’s default ARM flags already enable NEON.

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2 flags for that individual source file. No manual intervention is required.

## Accelerated Functions

All compiled MEX functions live in `private/mex_src/`. The table below lists each one, its purpose, and the approximate performance gain you can expect.

| MEX function | What it does | Speedup | Used by |
|---|---|---|---|
| `binary_search_mex` | O(log n) binary search for visible data range | 10‑20× vs MATLAB `find` | Zoom/pan callbacks to locate visible indices |
| `minmax_core_mex` | Per‑pixel MinMax reduction with SIMD vectorisation (processes 4 doubles/cycle with AVX2, 2 with NEON) | 3‑10× | Default downsampling algorithm in [[FastPlot|API Reference: FastPlot]] |
| `lttb_core_mex` | Largest Triangle Three Buckets with SIMD triangle area computation | 10‑50× | LTTB downsampling method |
| `violation_cull_mex` | Fused threshold violation detection and pixel culling (single‑pass) | Significant | Violation marker rendering during zoom/pan |
| `compute_violations_mex` | Batch threshold violation detection for the `resolve()` pipeline | Significant | [[Sensors|API Reference: Sensors]] resolution |
| `build_store_mex` | Bulk SQLite writer using `mksqlite` — writes chunks of X/Y data with accelerated Y min/max computation | 2‑3× | `FastSenseDataStore` construction |
| `resolve_disk_mex` | SQLite disk‑backed sensor resolution — reads chunks without loading full datasets | – | `Sensor.resolve()` with disk storage |
| `to_step_function_mex` | SIMD conversion of continuous threshold arrays to step‑function form | Significant | Threshold line step‑function rendering |
| `mksqlite` | Full SQLite3 MEX interface with typed BLOB support; serializes MATLAB arrays preserving type and shape | – | DataStore, disk‑backed sensor resolution |

Every MEX function checks for its own existence inside a persistent variable at first call, then delegates seamlessly to the pure‑MATLAB fallback if the MEX binary is unavailable (see [`binary_search.m`](#) for a typical pattern).

## Fallback Behavior

When any MEX file is absent:

- A functionally identical MATLAB implementation is present in `libs/FastSense/private/`.
- The entry‑point function detects the MEX presence once per session and switches automatically.
- Numerical results are identical — the test suite (`test_mex_parity`, `test_mex_edge_cases`) guarantees this.
- Performance remains excellent for datasets under ~10M points; large‑data users benefit most from MEX acceleration.

## Compilation Process

The `build_mex()` function (see `build_mex.m`) performs these steps:

1. **Architecture detection** — normalises platform strings (`maca64`, `aarch64‑…`, `x86_64‑…`) into canonical labels (`arm64`, `x86_64`, `unknown`).  
2. **Compiler selection** —  
   - *Octave*: prefers a real GCC installation (searches Homebrew paths `gcc‑15` … `gcc‑10`) for superior auto‑vectorisation; falls back to system default.  
   - *MATLAB*: always uses the configured default compiler (Xcode Clang on macOS, MSVC on Windows) to avoid linker‑flag incompatibilities.  
3. **SIMD flags** — sets optimisation and target instruction flags:  
   - x86_64: `-O3 -mavx2 -mfma -ftree-vectorize -ffast-math` (GCC/Clang) or `/O2 /arch:AVX2 /fp:fast` (MSVC).  
   - arm64: `-O3 -mcpu=apple-m3 -ftree-vectorize -ffast-math` (GCC on Octave) or simply `-O3 -ffast-math` (Clang).  
   - unknown: `-O3 -ffast-math` scalar.  
4. **Source compilation** — iterates over the list of MEX sources (see table above), compiling each with the chosen flags and the bundled `sqlite3.c` when needed.  
5. **Failure recovery** — if an AVX2 build fails on x86_64, the script immediately retries with SSE2 flags (`-msse2` or `/arch:SSE2`).  
6. **Stamp update** — after all files are compiled, a new `.mex-version` stamp file is written, preventing unnecessary rebuilds on future `install` calls.  
7. **Copy shared MEX files** — distributes `violation_cull_mex`, `compute_violations_mex`, `resolve_disk_mex`, and `to_step_function_mex` to `libs/SensorThreshold/private/` (with platform‑tagged sub‑folders on Octave).

### Caching and Stale Detection

To avoid forcing users through lengthy C compilations, `install.m` calls `mex_stamp()` on the repository root. This function computes a SHA‑256 hash (or a fallback size+byte‑sample fingerprint) of all C sources, headers, `build_mex.m`, and `mksqlite.c`. The hash is compared against the content of `private/.mex-version`. Only when they differ is `build_mex()` invoked. The per‑file mtime check inside `build_mex` then acts as a final backstop, so even a manual `build_mex()` invocation finishes quickly if nothing has changed.

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values. Passing these tests confirms that your MEX compilation is correct and that the fallback logic works seamlessly.
