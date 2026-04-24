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
- **Fallback**: [[binary_search]] pure-MATLAB implementation

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

**to_step_function_mex** — SIMD step-function conversion for thresholds
- **Used by**: Time-varying threshold processing

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

The [[build_mex]] function:

1. **Detects architecture** — normalizes platform strings (`maca64`, `aarch64`, etc.) into canonical labels
2. **Selects compiler** — prefers GCC on Octave for better auto-vectorization; uses MATLAB's default on MATLAB
3. **Sets SIMD flags** — chooses instruction sets based on detected CPU architecture
4. **Compiles sources** — builds all MEX files with bundled SQLite3 amalgamation
5. **Handles failures** — automatically retries x86_64 builds with SSE2 if AVX2 fails
6. **Copies shared files** — distributes MEX binaries to other library directories

## Performance Impact

The MEX acceleration provides significant performance improvements:

```matlab
% Example: 1M point dataset downsampling
x = 1:1e6;
y = randn(1e6, 1);

% With MEX (typical timing)
tic; fp = FastSense.plot(x, y); toc
% Elapsed time: ~0.05 seconds

% Without MEX (pure MATLAB fallback)
% Elapsed time: ~0.3 seconds (6x slower)
```

For datasets under 5,000 points, the difference is negligible since no downsampling occurs.

## Memory Management

MEX functions are designed to work within MATLAB's memory model:

- **In-place operations** where possible to minimize allocations
- **Chunked processing** for large datasets to avoid memory spikes
- **Automatic cleanup** of temporary arrays within MEX scope

## Verifying Installation

Test that MEX functions produce identical results to MATLAB fallbacks:

```matlab
install;
addpath('tests');
test_mex_parity;      % Verify MEX matches MATLAB output
test_mex_edge_cases;  % Test edge cases (empty arrays, NaN, etc.)
```

## Troubleshooting

If MEX compilation fails:

1. **Check compiler installation**: Ensure Xcode (macOS), GCC (Linux), or MSVC (Windows) is installed
2. **Verify MATLAB/Octave configuration**: Run `mex -setup` to configure the compiler
3. **Check architecture detection**: `computer('arch')` should return a recognized string
4. **Review build output**: Look for specific compilation errors in the console

Common issues:

- **AVX2 not supported**: Build script automatically falls back to SSE2 on older CPUs
- **Missing compiler**: Install platform-appropriate development tools
- **Permission errors**: Ensure write access to `libs/FastSense/private/`

The system gracefully degrades to pure-MATLAB implementations if any MEX compilation fails.
