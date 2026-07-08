# Installation

## Requirements
- MATLAB R2020b+ or GNU Octave 7+
- C compiler (optional) for MEX acceleration:
  - macOS: Xcode Command Line Tools
  - Linux: GCC
  - Windows: MSVC
- No toolbox dependencies

## Setup

1. Clone or download the repository
2. In MATLAB/Octave, navigate to the FastSense directory
3. Run install:
```matlab
install;
```

This adds the library paths:
- `libs/FastSense` — core plotting engine
- `libs/SensorThreshold` — sensor, tag, and threshold system
- `libs/EventDetection` — event detection and viewer
- `libs/Dashboard` — dashboard engine and widgets
- `libs/WebBridge` — TCP server for web-based visualization
- `libs/FastSenseCompanion` — companion navigator app
- `libs/PlantLog` — plant-log entry storage
- `libs/Concurrency` — file-locking helpers for live/multi-process use
- `libs/Help` — in-app wiki browser

It also adds `examples/`, `benchmarks/`, and `tests/` to the path, so example and benchmark scripts can be run by name.

## MEX Compilation (Optional)

For maximum performance, compile the C MEX accelerators:

```matlab
cd libs/FastSense
build_mex();
```

This auto-detects your architecture and compiles:
- `binary_search_mex` — O(log n) visible range lookup (10-20x faster)
- `minmax_core_mex` — per-pixel MinMax with SIMD (3-10x faster)
- `lttb_core_mex` — LTTB downsampling with SIMD (10-50x faster)
- `violation_cull_mex` — fused violation detection + pixel culling

SIMD support:
- Apple Silicon (arm64): NEON intrinsics
- x86_64: AVX2 with SSE2 fallback

If MEX files are not compiled, pure-MATLAB fallbacks are used automatically with identical behavior.

## Verify Installation

```matlab
install;
addpath('tests');
run_all_tests();
```

Or run a quick example:
```matlab
install;
example_basic;
```
