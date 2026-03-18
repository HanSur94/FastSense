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
2. In MATLAB/Octave, navigate to the FastPlot directory
3. Run setup:
```matlab
setup;
```

This adds the library paths:
- `libs/FastPlot` — core plotting engine
- `libs/SensorThreshold` — sensor and threshold system
- `libs/EventDetection` — event detection and viewer
- `libs/Dashboard` — dashboard engine and widgets
- `libs/WebBridge` — TCP server for web-based visualization

## MEX Compilation (Optional)

For maximum performance, compile the C MEX accelerators:

```matlab
cd libs/FastPlot
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
setup;
addpath('tests');
run_all_tests();
```

Or run a quick example:
```matlab
setup;
example_basic;
```
