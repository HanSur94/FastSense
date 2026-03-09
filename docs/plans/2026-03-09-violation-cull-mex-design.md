# violation_cull_mex — Fused SIMD Violation Detection + Pixel Culling

## Goal

Replace the separate `compute_violations` / `compute_violations_dynamic` + `downsample_violations` pipeline with a single SIMD-accelerated MEX function that does step-function threshold lookup, violation detection, and pixel-density culling in one pass.

## API

```matlab
[xOut, yOut] = violation_cull_mex(x, y, thX, thY, direction, pixelWidth, xmin)
```

**Inputs:**
- `x, y` — 1xN double data arrays (already downsampled from display)
- `thX, thY` — 1xK double threshold step-function knots (sorted). Single element = scalar threshold.
- `direction` — double: 1 = upper (y > th), 0 = lower (y < th)
- `pixelWidth` — double: X span per pixel (`diff(xlim) / axesWidthPixels`)
- `xmin` — double: left edge of current view (bucket anchor)

**Outputs:**
- `xOut, yOut` — 1xM double culled violation points (at most 1 per pixel column, max-deviation winner)

## Algorithm

Single-pass over data array:

1. **Step-function lookup:** For each `x[i]`, find active threshold from `(thX, thY)`. For scalar (K=1), threshold is constant. For time-varying, binary search thX to find the rightmost knot <= x[i], yielding thY[j]. Since data is sorted and thX is sorted, maintain a running cursor to avoid repeated binary search (amortized O(1) per point).

2. **Violation test:** Compare `y[i]` against threshold. Skip NaN (IEEE 754: NaN comparisons are false). If no violation, continue.

3. **Pixel bucketing:** Compute `bucket = floor((x[i] - xmin) / pixelWidth)`. Track per-bucket best violation: if `|y[i] - th| > best_deviation[bucket]`, update with current point.

4. **Emit:** After scan, collect all non-empty buckets into output arrays.

## SIMD Strategy

- **Scalar threshold (K=1):** Broadcast threshold to SIMD register. Load SIMD_WIDTH y-values, compare vectorially. For violations, fall through to scalar bucketing (branch-heavy, but filtered to ~1-5% of points).
- **Time-varying threshold (K>1):** Step-function lookup is scalar (few knots, running cursor). Comparison and deviation computation can still use SIMD when consecutive points share the same threshold segment.
- **Bucket tracking:** Flat array indexed by bucket ID (bounded by ~4000 max pixel columns). Per-bucket: store bestX, bestY, bestDeviation.

## Memory

- Bucket array: `3 * maxBuckets * sizeof(double)` ≈ 96 KB for 4000-pixel display. Stack or mxMalloc.
- No intermediate violation array allocated — points go directly to bucket tracking.

## MATLAB Wrapper

`compute_violations.m` and `compute_violations_dynamic.m` gain MEX fast-paths. The render/updateViolations loops in `FastPlot.m` are updated to call a fused path that skips `downsample_violations` when MEX is available.

## Files Changed

- **Create:** `mex_src/violation_cull_mex.c`
- **Delete:** `mex_src/compute_violations_mex.c` and compiled outputs
- **Modify:** `build_mex.m` — swap old MEX for new
- **Modify:** `compute_violations.m` — add MEX fast-path
- **Modify:** `compute_violations_dynamic.m` — add MEX fast-path
- **Modify:** `downsample_violations.m` — no change (still used as MATLAB fallback)
- **Modify:** `FastPlot.m` render + updateViolations — fused call path
- **Create:** `tests/test_violation_cull_mex.m` — parity tests against MATLAB fallback

## Compatibility

- MATLAB: SIMD-accelerated via build_mex
- Octave: MEX compilation supported; same binary
- No MEX: transparent fallback to existing pure-MATLAB path (zero behavior change)
