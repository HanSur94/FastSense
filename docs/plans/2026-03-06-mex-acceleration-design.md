# FastSense MEX Acceleration — Design Document

**Date:** 2026-03-06
**Status:** Approved

---

## 1. Goal

Add C MEX implementations with SIMD intrinsics (AVX2 for x86_64, NEON for ARM64) for the three performance-critical functions in FastSense. Existing pure-MATLAB implementations remain as automatic fallbacks.

---

## 2. Functions to Accelerate

| Function | Current Bottleneck | Expected MEX Speedup |
|---|---|---|
| `minmax_core` | Reshape + vectorized min/max + temp allocation | 3-10x (SIMD min/max reduction) |
| `lttb_core` | Sequential for-loop with per-iteration dependency | 10-50x (C loop + SIMD inner area calc) |
| `binary_search` | MATLAB while-loop interpreter overhead | 10-20x (plain C, no SIMD needed) |

`compute_violations` is already a fast vectorized one-liner — not worth MEX.

---

## 3. Architecture

### File Layout

```
FastSense/
├── private/
│   ├── minmax_downsample.m      (modified: calls minmax_core_mex or minmax_core)
│   ├── lttb_downsample.m        (modified: calls lttb_core_mex or lttb_core)
│   ├── binary_search.m          (modified: tries binary_search_mex first)
│   └── mex_src/
│       ├── minmax_core_mex.c
│       ├── lttb_core_mex.c
│       ├── binary_search_mex.c
│       └── simd_utils.h         (compile-time SIMD abstraction)
├── build_mex.m                  (build script)
├── ...existing files unchanged...
```

### Fallback Mechanism

Each MATLAB wrapper uses a `persistent` flag to check MEX availability once:

```matlab
persistent useMex;
if isempty(useMex)
    useMex = exist('minmax_core_mex', 'file') == 3;
end
if useMex
    [xOut, yOut] = minmax_core_mex(segX, segY, nb);
else
    [xOut, yOut] = minmax_core(segX, segY, nb);
end
```

Zero behavior change when MEX is unavailable. Existing tests pass either way.

---

## 4. MEX Function Signatures

All match their MATLAB counterparts exactly:

- `[xOut, yOut] = minmax_core_mex(x, y, numBuckets)` — double row vectors in, `[2*numBuckets]` row vectors out
- `[xOut, yOut] = lttb_core_mex(x, y, numOut)` — double row vectors in, `[numOut]` row vectors out
- `idx = binary_search_mex(x, val, direction)` — double row vector + scalar + char in, 1-based scalar out

---

## 5. SIMD Strategy

### `simd_utils.h` — Compile-Time Abstraction

Detects architecture via preprocessor:
- `__AVX2__` → AVX2 intrinsics (4 doubles per op)
- `__SSE2__` → SSE2 intrinsics (2 doubles per op)
- `__ARM_NEON` → NEON intrinsics (2 doubles per op)
- None → scalar C fallback

Provides unified macros for: load, store, min, max, fabs, multiply, subtract operations on packed doubles.

### `minmax_core_mex.c` — Highest SIMD Benefit

- Iterate buckets, SIMD reduce min/max within each bucket
- Track min/max indices alongside values using scalar comparisons after SIMD reduction
- Scalar cleanup loop for remainder elements within each bucket
- Output ordering: min-first or max-first per bucket to preserve X monotonicity

### `lttb_core_mex.c` — Moderate SIMD Benefit

- Outer loop is sequential (each iteration depends on `prevSelectedIdx`)
- Inner triangle-area computation over bucket candidates is vectorized:
  `fabs((pX - avgX) * (y[i] - pY) - (pX - x[i]) * (avgY - pY))`
- SIMD computes areas for 2-4 candidates at a time, scalar max-reduction to find best

### `binary_search_mex.c` — No SIMD, Pure C

- O(log n) binary search, plain C
- Win is purely from eliminating MATLAB interpreter loop overhead
- Supports 'left' and 'right' direction modes
- Returns 1-based index (MATLAB convention)

---

## 6. Build Script (`build_mex.m`)

- Detects CPU architecture (`computer('arch')`)
- Sets appropriate compiler flags:
  - x86_64: `-mavx2 -mfma -O3` (with runtime check and `-msse2` fallback)
  - ARM64 (Apple Silicon): `-O3` (NEON is default)
- Compiles all 3 MEX files, outputs to `private/`
- Prints per-file success/failure
- Can be re-run safely (overwrites existing MEX binaries)

---

## 7. Testing

- **Existing tests unchanged** — they call MATLAB wrappers, which auto-select MEX or fallback
- **`tests/test_mex_parity.m`** — runs MEX and MATLAB implementations side-by-side for identical inputs, asserts outputs match within floating-point tolerance
- **`tests/test_mex_edge_cases.m`** — empty arrays, single element, very large arrays, exact boundary values

---

## 8. What Does NOT Change

- All existing `.m` files keep their pure-MATLAB fallback implementations
- Public FastSense API is unchanged
- Test suite passes with or without MEX compiled
- Octave compatibility preserved for pure-MATLAB path
- No new toolbox dependencies
