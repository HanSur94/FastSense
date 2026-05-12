<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure-MATLAB fallbacks — behavior is identical.

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto-detects your architecture and compiles all MEX functions with appropriate SIMD optimizations.  
MEX binaries are placed in `libs/FastSense/private/` (MATLAB) or a platform‑specific subdirectory (Octave). Shared MEX files required by the SensorThreshold package are automatically copied to `libs/SensorThreshold/private/`.

### Requirements

| Platform | Compiler |
|----------|----------|
| macOS | Xcode Command Line Tools |
| Linux | GCC |
| Windows | MSVC |

SQLite3 is bundled as an amalgamation (`sqlite3.c` + `sqlite3.h`) and compiled directly into MEX files that need it — no system installation required. The amalgamation lives in `libs/FastSense/private/mex_src/`.

## Architecture Support

All MEX functions include a common SIMD abstraction layer that adapts to your CPU:

| Architecture | SIMD Instructions | Fallback |
|-------------|------------------|----------|
| x86_64 | AVX2 + FMA | SSE2 |
| ARM64 (Apple Silicon) | NEON | – |
| Other | Scalar operations | – |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2 flags.

## Stamp‑Based Freshness

To avoid rebuilding unchanged sources, `install.m` checks a fingerprint computed by `mex_stamp()`. The stamp includes every C source file, header, and the `build_mex.m` file itself. If the stamp matches the one saved in `libs/FastSense/private/.mex-version`, the whole `build_mex()` step is skipped. This makes repeated `install` calls very fast when nothing has changed.

Even if `build_mex()` is invoked directly, per‑file modification‑time checks prevent recompilation of up‑to‑date sources.

## Accelerated Functions

### Core Downsampling

**binary_search_mex** — O(log n) binary search for visible data range  
- **Speedup**: 10–20× over MATLAB’s `find`  
- **Used by**: Zoom/pan callbacks to locate visible indices  

**minmax_core_mex** — Per‑pixel MinMax reduction with SIMD vectorization  
- **Speedup**: 3–10× over pure MATLAB  
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle  
- **Used by**: Default downsampling algorithm in [[FastPlot|API Reference: FastPlot]]

**lttb_core_mex** — Largest Triangle Three Buckets with SIMD triangle area computation  
- **Speedup**: 10–50× over MATLAB implementation  
- **Used by**: LTTB downsampling method

### Threshold Processing

**violation_cull_mex** — Fused threshold violation detection and pixel culling  
- **Speedup**: Significant (single‑pass vs two‑pass MATLAB)  
- **Used by**: Violation marker rendering during zoom/pan

**compute_violations_mex** — Batch threshold violation detection  
- **Speedup**: Significant over per‑point MATLAB comparison  
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline

**to_step_function_mex** — SIMD conversion of floating‑point arrays to step‑function segments for time‑varying thresholds  
- **Used by**: Threshold resolution in `Sensor.resolve()`

### Data Storage & Monitoring

**build_store_mex** — Bulk SQLite writer for `FastSenseDataStore` initialization  
- **Speedup**: 2–3× (eliminates ~20K MATLAB‑to‑MEX round‑trips)  
- **SIMD**: Accelerated Y min/max computation per chunk  
- **Used by**: `FastSenseDataStore` construction

**resolve_disk_mex** — SQLite‑backed sensor resolution for `Sensor.resolve()`  
- **Used by**: Disk‑backed sensors (`StorageMode = 'disk'`)  
- **Benefit**: Reads chunks from database without loading full datasets

**mksqlite** — SQLite3 MEX interface with typed BLOB support  
- **Used by**: `FastSenseDataStore`, disk‑backed sensor resolution, and monitor cache  
- **Features**: Serializes MATLAB arrays preserving type and shape; supports WAL mode for concurrent access  

The `FastSenseDataStore` class exposes several methods that rely on these MEX accelerated paths:
- `getRange` / `readSlice` – use the chunked SQLite storage built by `build_store_mex`
- `findViolations` – chunk‑level Y filtering (backed by the same underlying MEX)
- `storeResolved` / `loadResolved` – caches pre‑computed `Sensor.resolve()` outputs
- `storeMonitor` / `loadMonitor` – persistence for `MonitorTag` derived data (stored as typed BLOBs via `mksqlite`)

## Fallback Behavior

When MEX files are unavailable:

- Each function has a pure‑MATLAB equivalent in `libs/FastSense/private/`
- Runtime auto‑detection switches between MEX and MATLAB seamlessly
- Identical numerical results and API
- Performance remains excellent for datasets under ~10M points

## Compilation Process

The `build_mex()` function:

1. **Detects architecture** — normalizes platform strings (`maca64`, `aarch64`, etc.) into canonical labels
2. **Selects compiler** — prefers GCC on Octave for better auto‑vectorization; uses MATLAB’s default on MATLAB
3. **Sets SIMD flags** — chooses instruction sets based on detected CPU architecture
4. **Compiles sources** — builds all MEX files with bundled SQLite3 amalgamation; skips files whose modification time is older than the last compilation
5. **Handles failures** — automatically retries x86_64 builds with SSE2 if AVX2 fails
6. **Copies shared files** — distributes MEX binaries to the `SensorThreshold` private directory

MEX source files are located in `libs/FastSense/private/mex_src/`. The complete list of compiled files:

| Source file | Output MEX |
|------------|------------|
| `binary_search_mex.c` | binary_search_mex |
| `minmax_core_mex.c` | minmax_core_mex |
| `lttb_core_mex.c` | lttb_core_mex |
| `violation_cull_mex.c` | violation_cull_mex |
| `compute_violations_mex.c` | compute_violations_mex |
| `to_step_function_mex.c` | to_step_function_mex |
| `build_store_mex.c` + `sqlite3.c` | build_store_mex |
| `resolve_disk_mex.c` + `sqlite3.c` | resolve_disk_mex |
| `mksqlite.c` + `sqlite3.c` | mksqlite |

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.

## Troubleshooting

- **MEX compilation fails** – The build script prints detailed error messages and automatically falls back to SSE2 on x86_64. If the error persists, check that your compiler is installed correctly (see requirements). Without MEX files, FastSense will gracefully use the pure‑MATLAB implementations – performance may degrade on datasets larger than ~10M points.
- **Out of memory during `FastSenseDataStore` construction** – The store uses chunked writes to avoid memory peaks, but if the raw `x, y` arrays exceed available memory, consider using disk‑backed storage from the start (set `StorageMode` to `'disk'` in [[FastPlot|API Reference: FastPlot]] or in `FastSenseDefaults`).
- **“mksqlite not found” warning** – If mksqlite fails to compile, `FastSenseDataStore` falls back to a binary file format. This is sufficient for most use cases but may not support extra data columns (cell, string, categorical, etc.).
- **Verifying MEX stamp** – To force re‑compilation after modifying C sources or `build_mex.m`, delete `libs/FastSense/private/.mex-version` and run `install` again. The stamp will be recalculated and rebuilt.

## Performance Tips

- **Prefer `'minmax'` downsampling** for most real‑world signals – it retains extremes and catches spikes. Use `'lttb'` only when preserving the visual shape of smooth curves is critical.
- **Keep `DownsampleFactor` at 2** (default) unless you have extremely high‑resolution displays; higher values increase rendering load with little visual gain.
- **Enable WAL mode** in `FastSenseDataStore` when using disk‑backed storage in multi‑figure or live‑mode scenarios:
  ```matlab
  ds = FastSenseDataStore(x, y);
  ds.enableWAL();
  ```
  This allows concurrent reads while the store is being updated.
- **For live mode** that continuously appends data, consider a `FastSenseDataStore` with the monitor cache (`storeMonitor` / `loadMonitor`) to avoid recalculating derived signals.

---

*See also:* [[Installation]], [[Architecture]], [[Performance]], [[FastPlot|API Reference: FastPlot]], [[Sensors|API Reference: Sensors]]
