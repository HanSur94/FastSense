<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# MEX Acceleration

FastSense includes optional C MEX functions with SIMD intrinsics for maximum performance. All MEX functions have pure-MATLAB fallbacks — behavior is identical.

## Building MEX Files

```matlab
cd libs/FastSense
build_mex();
```

The build script auto-detects your architecture and compiles all MEX functions with appropriate SIMD optimizations.

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
| ARM64 (Apple Silicon) | NEON | - |
| Other | Scalar operations | - |

If AVX2 compilation fails on x86_64, the build script automatically retries with SSE2.

## Accelerated Functions

### Core Downsampling

**binary_search_mex** — O(log n) binary search for visible data range
- **Speedup**: 10-20x over MATLAB's `find`
- **Used by**: Zoom/pan callbacks to locate visible indices

**minmax_core_mex** — Per-pixel MinMax reduction with SIMD vectorization
- **Speedup**: 3-10x over pure MATLAB
- **SIMD**: Processes 4 doubles (AVX2) or 2 doubles (NEON) per cycle
- **Used by**: Default downsampling algorithm in [[FastPlot|API Reference: FastPlot]]

**lttb_core_mex** — Largest Triangle Three Buckets with SIMD triangle area computation
- **Speedup**: 10-50x over MATLAB implementation
- **Used by**: LTTB downsampling method

### Threshold Processing

**violation_cull_mex** — Fused threshold violation detection and pixel culling
- **Speedup**: Significant (single-pass vs two-pass MATLAB)
- **Used by**: Violation marker rendering during zoom/pan

**compute_violations_mex** — Batch threshold violation detection
- **Speedup**: Significant over per-point MATLAB comparison
- **Used by**: [[Sensors|API Reference: Sensors]] resolution pipeline

**to_step_function_mex** — SIMD step-function conversion for time-varying thresholds
- **Used by**: Threshold line preprocessing

### Data Storage

**build_store_mex** — Bulk SQLite writer for DataStore initialization
- **Speedup**: 2-3x (eliminates ~20K MATLAB-to-MEX round-trips)
- **SIMD**: Accelerated Y min/max computation per chunk
- **Used by**: `FastSenseDataStore` construction

**resolve_disk_mex** — SQLite disk-based sensor resolution
- **Used by**: `Sensor.resolve()` with disk-backed storage
- **Benefit**: Reads chunks from database without loading full datasets

**mksqlite** — SQLite3 MEX interface with typed BLOB support
- **Used by**: DataStore, disk-backed sensor resolution
- **Features**: Serializes MATLAB arrays preserving type and shape

## Fallback Behavior

When MEX files are unavailable:

- Each function has a pure-MATLAB equivalent in `libs/FastSense/private/`
- Runtime auto-detection switches between MEX and MATLAB seamlessly
- Identical numerical results and API
- Performance remains excellent for datasets under ~10M points

## Compilation Process

The `build_mex()` function:

1. **Detects architecture** — normalizes platform strings (`maca64`, `aarch64`, etc.) into canonical labels
2. **Selects compiler** — prefers GCC on Octave for better auto-vectorization; uses MATLAB's default on MATLAB
3. **Sets SIMD flags** — chooses instruction sets based on detected CPU architecture
4. **Compiles sources** — builds all MEX files with bundled SQLite3 amalgamation
5. **Handles failures** — automatically retries x86_64 builds with SSE2 if AVX2 fails
6. **Copies shared files** — distributes MEX binaries to other library directories

### Compiler Selection

- **Octave**: Prefers real GCC (searched via `find_gcc`) for superior auto-vectorization; falls back to system default
- **MATLAB**: Always uses the configured default compiler because MATLAB passes compiler-specific linker flags

### Smart Rebuilding

The build system uses fingerprinting to avoid unnecessary recompilation:

```matlab
h = mex_stamp(rootDir);  % SHA-256 hash of all source files
% Only rebuilds if source files changed
```

File change detection includes:
- All `.c` and `.h` files in `private/mex_src/`
- `build_mex.m` script itself
- `mksqlite.c` source file

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

The test suite validates numerical accuracy across all MEX functions and handles edge cases like empty arrays, single points, and NaN values.

## Platform-Specific Notes

### Octave Support

On Octave, MEX files are placed in platform-tagged subdirectories:
- `private/octave-macos-arm64/`
- `private/octave-linux-x86_64/`
- `private/octave-windows-x86_64/`

This prevents binary incompatibility when sharing code across different Octave installations.

### Apple Silicon (ARM64)

- NEON SIMD is enabled by default on Apple Clang
- GCC builds use explicit `-mcpu=apple-m3` targeting

### Windows (MSVC)

- Uses `/O2 /arch:AVX2 /fp:fast` optimization flags
- SQLite flags use `/D` prefix instead of `-D`
