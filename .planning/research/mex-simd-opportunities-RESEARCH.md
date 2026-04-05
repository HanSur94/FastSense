# MEX + SIMD Acceleration Opportunities — Research

**Researched:** 2026-04-05
**Domain:** MATLAB FastSense + Dashboard compute hotspots — C MEX + AVX2/NEON candidates
**Confidence:** HIGH (all findings from direct source inspection)

---

## Summary

The FastSense/Dashboard codebase already has a mature MEX+SIMD infrastructure with eight compiled kernels
(minmax, lttb, violation_cull, to_step_function, binary_search, build_store, resolve_disk, compute_violations).
The v1.0 performance optimization phase (completed 2026-04-04) attacked MATLAB-level overhead: theme caching,
dispatch maps, single-pass live tick, and in-place panel repositioning. Those were the correct first-pass wins.

What remains is strictly computational: pure-MATLAB loops that process floating-point arrays on the hot path
and are not yet backed by a compiled kernel. Five concrete opportunities exist, ranked below by estimated
wall-clock impact. Two additional areas are surveyed and judged NOT worth MEX-ifying.

**Primary recommendation:** Implement `minmax_core_logx_mex` first (highest call frequency at
log-scale zoom), then `nan_segment_split_mex` (NaN-aware downsampling hotspot), then
`threshold_range_scan_mex` (updateViolations scalar-threshold SIMD path gap). The remaining two
are medium-priority stretch goals.

---

## Project Constraints (from CLAUDE.md)

- Pure MATLAB / C MEX only — no external dependencies
- Must provide pure-MATLAB scalar fallback for every MEX kernel (Octave / headless CI)
- MEX binaries compiled via `build_mex()` / `install()` at first run
- AVX2 on x86_64, NEON on ARM64, scalar fallback — follow `simd_utils.h` patterns exactly
- New .c files live in `libs/FastSense/private/mex_src/`
- MATLAB wrapper (`.m`) lives in `libs/FastSense/private/` next to the existing fallbacks
- `persistent useMex` pattern gates MEX vs fallback at runtime (see `minmax_downsample.m`)
- All public API remains in MATLAB — MEX is purely a compute backend

---

## Existing MEX Kernel Reference

Every existing kernel follows the same pattern. New kernels MUST match it exactly.

### File layout

```
libs/FastSense/private/
├── mex_src/
│   └── new_kernel_mex.c        ← C source with mexFunction entry point
├── new_kernel_mex.mex          ← compiled binary (Linux)
├── new_kernel_mex.mexmaca64    ← compiled binary (macOS ARM64)
└── new_kernel_wrapper.m        ← MATLAB wrapper with persistent useMex guard
```

### MATLAB wrapper boilerplate (from minmax_downsample.m lines 49-81)

```matlab
persistent useMex;
if isempty(useMex)
    useMex = (exist('new_kernel_mex', 'file') == 3);
end
% ... validation / fast-path check ...
if useMex
    [xOut, yOut] = new_kernel_mex(x, y, params);
    return;
end
% ... pure-MATLAB fallback ...
```

### SIMD boilerplate (from minmax_core_mex.c lines 63-96)

```c
#include "mex.h"
#include "simd_utils.h"

// SIMD_WIDTH, simd_double, simd_load, simd_set1, simd_min, simd_max,
// simd_hmin, simd_hmax are all defined in simd_utils.h.
// AVX2 path: SIMD_WIDTH=4 (256-bit / 64-bit doubles)
// NEON path:  SIMD_WIDTH=2 (128-bit / 64-bit doubles)
// Scalar:     SIMD_WIDTH=1

#if SIMD_WIDTH > 1
{
    simd_double acc = simd_set1(init_val);
    size_t simd_end = base + ((end - base) / SIMD_WIDTH) * SIMD_WIDTH;
    for (size_t j = base; j < simd_end; j += SIMD_WIDTH) {
        simd_double v = simd_load(&y[j]);
        acc = simd_op(acc, v);          // e.g. simd_min, simd_max, simd_add
    }
    double result = simd_hreduce(acc);  // horizontal reduction
    // scalar tail
    for (size_t j = simd_end; j < end; j++) {
        // scalar update
    }
}
#else
    // scalar-only path
#endif
```

---

## Opportunities (Ranked by Impact)

### Opportunity 1: `minmax_core_logx_mex` — Log-scale MinMax kernel [HIGH IMPACT]

**Location:** `libs/FastSense/private/minmax_downsample.m`, local function `minmax_core_logx` (lines 248–317)

**What the MATLAB code does:**
```matlab
% Per-bucket loop (nb iterations — typically 1920 on a 1920px screen):
for b = 1:nb
    mask = segX >= edges(b) & segX < edges(b+1);  % O(N) boolean array per bucket
    if ~any(mask), continue; end
    bx = segX(mask);   % allocation
    by = segY(mask);   % allocation
    [yMinVal, iMin] = min(by);
    [yMaxVal, iMax] = max(by);
    ...
end
```

**Problem:** `nb` per-iteration passes over `segX` to build boolean masks. For a 1M-point visible slice
with nb=1920, this is ~1920 × 1M = ~2 billion comparisons in MATLAB, each creating a temporary boolean
array. The existing `minmax_core_mex` (linear buckets) avoids this with a single O(N) pass — the log
variant was not given the same treatment.

**Why it is called:** Every zoom/pan event on a log-X axis triggers `updateLines()` → `minmax_downsample()`
→ `minmax_core_logx`. Log-scale is common for sensor data spanning multiple orders of magnitude (pressure,
frequency, attenuation).

**MEX design:**
- Single O(N) pass: compute `log_x = log10(x[i])` once per element, bucket via
  `b = (size_t)((log_x - logMin) / logStep)`, track per-bucket min/max/indices.
- SIMD inner loop: vectorize `log10` approximation (polynomial or `__builtin_ia32_log_ps`) or compute
  bucket index arithmetically from pre-computed log edges array — the min/max tracking is SIMD-identical
  to `minmax_core_mex`.
- Input: `(x, y, numBuckets)` — same signature as `minmax_core_mex`.
- Output: `(xOut, yOut)` — same as `minmax_core_mex`.

**Estimated speedup:** 10–50× over MATLAB inner loop at N=1M, nb=1920.
**Confidence:** HIGH — the MATLAB fallback is demonstrably O(N×nb); the MEX equivalent is O(N).

---

### Opportunity 2: `nan_segment_split_mex` — NaN boundary detection kernel [HIGH IMPACT]

**Location:** `libs/FastSense/private/minmax_downsample.m` lines 84–110;
`libs/FastSense/private/lttb_downsample.m` lines 51–78

**What the MATLAB code does (identical pattern in both files):**
```matlab
isNan = isnan(y);                          % O(N) scan
nanMask = [true, isNan, true];             % +2 element allocation
edges = diff(nanMask);                     % O(N) allocation
segStarts = find(edges == -1);             % O(N) find + allocation
segEnds   = find(edges == 1) - 1;         % O(N) find + allocation
```

**Problem:** Five O(N) allocations executed *before* any downsampling begins — for every call to
`minmax_downsample` and `lttb_downsample`, including the common NaN-free path (which does reach this
code via `hasNaN=true` branch). On a 10M-point dataset, this is ~240MB of temporary boolean/double
allocation before any real work.

**Called from:** `minmax_downsample` (every zoom/pan for NaN-bearing lines), `lttb_downsample`
(same), and every invocation in `updateShadings()`, `refineLines()`, `buildPyramidLevel()`.

**MEX design:**
```c
// [segStarts, segEnds, numSegs] = nan_segment_split_mex(y)
// Single O(N) pass: walk y, detect NaN transitions, write to pre-allocated output.
// Output: two int32 arrays (segStarts, segEnds) + scalar numSegs.
// SIMD: vectorized isnan check (compare y[i] != y[i]) for fast NaN detection.
```

The MATLAB wrapper gains a third output path: if `numSegs == 1` and `segStarts[0] == 0`,
the data has no NaN, skip the NaN-aware code path entirely.

**Estimated speedup:** 3–8× reduction in NaN-handling overhead; eliminates 5 temporary allocations
per call. Impact compounds at large N: 10M-point live sensor → ~40MB saved per zoom event.
**Confidence:** HIGH — all five allocations are visible in source; each is avoidable with a single C pass.

---

### Opportunity 3: `threshold_range_scan_mex` — Scalar-threshold fast path for updateViolations [MEDIUM IMPACT]

**Location:** `libs/FastSense/private/violation_cull.m` (lines 66–76) and
`libs/FastSense/private/mex_src/violation_cull_mex.c` (comment at line 80: "Scalar threshold fast path")

**Current state:** `violation_cull_mex.c` has a comment `"=== Scalar threshold fast path (K=1): SIMD vectorized ==="` but the actual SIMD path was not fully implemented in the kernel (the comment references a planned section). The existing C file handles the *culling* side well but the *detection* side for scalar thresholds reads:

```c
// In violation_cull_mex.c — walk all N points scalar:
for (size_t i = 0; i < N; i++) {
    int violated = isUpper ? (y[i] > thY[0]) : (y[i] < thY[0]);
    ...
}
```

**What SIMD would do:** For scalar threshold (K=1, `thX` has 1 element), `N` comparison iterations
can be vectorized as:
```c
simd_double vTh = simd_set1(thY[0]);
for (j = 0; j < simd_end; j += SIMD_WIDTH) {
    simd_double vy = simd_load(&y[j]);
    // compare vy > vTh (upper) or vy < vTh (lower) — emit to candidate buffer
}
```

**Why it matters:** `updateViolations()` is called on every `updateData()`, `updateLines()`, and every
zoom/pan event. For a FastSense plot with thresholds and N=500K displayed points (after downsampling),
the comparison loop runs 500K iterations per threshold per zoom event.

**Estimated speedup:** 2–4× for the detection inner loop (SIMD_WIDTH=4 on AVX2).
**Confidence:** MEDIUM — the kernel already exists; this is a targeted enhancement to an inner loop.
The actual impact depends on how much time the detection loop takes vs. the bucket-scan culling loop,
which requires profiling to confirm.

---

### Opportunity 4: `minmax_shading_mex` — Dual-channel MinMax for shaded regions [MEDIUM IMPACT]

**Location:** `libs/FastSense/FastSense.m` `updateShadings()` (lines 2624–2680) and `render()` (lines 1054–1084)

**What the MATLAB code does:**
```matlab
[xd, y1d] = minmax_downsample(xVis, y1Vis, pw);   % first pass over xVis
[~, y2d]  = minmax_downsample(xVis, y2Vis, pw);   % second pass over xVis (same X!)
```

Two separate calls to `minmax_downsample` share the same `xVis` array. The bucket partitioning
(determining which X values fall in each bucket) is computed twice identically.

**MEX design:**
```c
// [xOut, y1Out, y2Out] = minmax_dual_mex(x, y1, y2, numBuckets)
// Single O(N) pass: compute bucket boundaries once; track min/max for BOTH y1 and y2
// simultaneously. X-monotonic interleaving of pairs.
// SIMD: process y1 and y2 in the same inner loop iteration (they share the same index).
```

**Called from:** `updateShadings()` (every zoom/pan when shaded regions exist) and `render()` (once at startup, less critical).

**Estimated speedup:** ~2× for the shading update path (halves the number of array scans).
**Confidence:** HIGH for correctness; MEDIUM for impact (shading is an optional feature; not every dashboard uses `addShaded`).

---

### Opportunity 5: `trend_slope_mex` — Live trend detection in NumberWidget [LOW IMPACT]

**Location:** `libs/Dashboard/NumberWidget.m` `computeTrend()` (lines 200–220)

**What the MATLAB code does:**
```matlab
n = numel(obj.Sensor.Y);
nTrend = max(3, round(n * 0.1));
yRecent = obj.Sensor.Y(end-nTrend+1:end);         % slice allocation
slope = (yRecent(end) - yRecent(1)) / nTrend;
yRange = max(obj.Sensor.Y) - min(obj.Sensor.Y);   % full scan every refresh
```

**Problem:** `max(obj.Sensor.Y)` and `min(obj.Sensor.Y)` both scan the entire Y array on every live tick
for every NumberWidget. For a sensor with 1M points refreshed every 5s with 10 NumberWidgets, this is
20M comparisons per tick just for trend normalization.

**MEX design:**
```c
// [slope, yMin, yMax] = trend_scan_mex(y, nTrend)
// Single O(N) pass: compute yMin, yMax over full array AND the slope over tail[N-nTrend:N].
// SIMD: standard min/max reduction over full array, identical to minmax_core_mex inner loop.
```

**Estimated speedup:** 2–3× for the NumberWidget refresh path at large N.
**Confidence:** MEDIUM — the path is only hot when sensors have large Y arrays AND many NumberWidgets
coexist. In small dashboards this is irrelevant. Recommend profiling before implementing.

---

## Opportunities NOT Worth MEX-ifying

### DashboardLayout.computePosition — NOT a target

`computePosition()` (DashboardLayout.m lines 62–99) is called O(N_widgets) times on panel creation.
It performs 10–15 arithmetic operations per widget — no loop over data arrays. Total work is
negligible (microseconds for 20 widgets). MEX overhead would exceed the benefit.

### DashboardLayout.resolveOverlap — NOT a target

`resolveOverlap()` (lines 162–175) is a while loop over the widget list (O(N_widgets^2) worst case,
but N_widgets is always small, typically < 50). Called only during addWidget and layout reflow.
Total work is under 1ms even at N=100. Not a hot path.

### onLiveTick widget loop — NOT a target

The per-tick widget loop in `DashboardEngine.onLiveTick()` iterates over N_widgets (typically 10–30)
and calls `w.refresh()`. The loop overhead itself (MATLAB iteration) is negligible; the cost is
inside each widget's `refresh()`. The already-completed Phase 01 optimization collapsed this into a
single pass and eliminated redundant `activePageWidgets()` calls. Further savings require optimizing
inside individual widget refresh methods, not the loop itself.

### GaugeWidget arc rendering — NOT a target

`GaugeWidget.renderArc()` computes `cos(angles)` and `sin(angles)` over an 80-point angle array
(line 238: `nPts = 80`). This runs once at render time, not on the live tick. The 80-element
trigonometry is sub-microsecond. MEX would add zero measurable benefit.

---

## Architecture Patterns

### Recommended new file structure

```
libs/FastSense/private/
├── mex_src/
│   ├── minmax_core_logx_mex.c     ← Opportunity 1
│   ├── nan_segment_split_mex.c    ← Opportunity 2
│   ├── minmax_dual_mex.c          ← Opportunity 4
│   └── trend_scan_mex.c           ← Opportunity 5
├── minmax_core_logx_mex.mex       ← compiled
├── minmax_core_logx_mex.mexmaca64 ← compiled
├── nan_segment_split_mex.mex
├── nan_segment_split_mex.mexmaca64
└── (wrappers live inside minmax_downsample.m and lttb_downsample.m)
```

Opportunity 3 (`threshold_range_scan_mex`) modifies the existing `violation_cull_mex.c` — no new file.

### Integration pattern for Opportunity 1 (logx path)

```matlab
% In minmax_downsample.m, the logX branch:
persistent useMexLogx;
if isempty(useMexLogx)
    useMexLogx = (exist('minmax_core_logx_mex', 'file') == 3);
end
if logX
    if useMexLogx
        [xOut, yOut] = minmax_core_logx_mex(x, y, numBuckets);
    else
        [xOut, yOut] = minmax_core_logx(x, y, numBuckets);  % existing MATLAB fallback
    end
    return;
end
```

### Integration pattern for Opportunity 2 (NaN split)

```matlab
% Replace the 5-line NaN boundary section in minmax_downsample.m and lttb_downsample.m:
persistent useMexNan;
if isempty(useMexNan)
    useMexNan = (exist('nan_segment_split_mex', 'file') == 3);
end
if useMexNan
    [segStarts, segEnds, numSegs] = nan_segment_split_mex(y);
else
    isNan = isnan(y);
    nanMask = [true, isNan, true];
    edges = diff(nanMask);
    segStarts = find(edges == -1);
    segEnds   = find(edges == 1) - 1;
    numSegs = numel(segStarts);
end
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Log approximation in SIMD | Custom polynomial log | SVML (Intel) or `__builtin_ia32_log_ps` via GCC — or pre-compute log-edges in MATLAB and pass as double array to MEX |
| Thread-parallel MEX | OpenMP in C | Not needed — dashboard is single-threaded MATLAB; SIMD width (4×) is sufficient |
| GPU acceleration | MATLAB GPU arrays | Out of scope (no toolbox requirement per CLAUDE.md) |
| Custom memory allocator in MEX | malloc pool | `mxCalloc`/`mxFree` already zero-initializes and integrates with MATLAB GC |

**Key insight:** The existing `simd_utils.h` already abstracts all platform differences (AVX2/NEON/scalar).
Every new kernel needs only to `#include "simd_utils.h"` and use `simd_load`, `simd_set1`, `simd_min`,
`simd_max`, `simd_add`, `simd_hmin`, `simd_hmax`. Do not re-implement SIMD intrinsics.

---

## Common Pitfalls

### Pitfall 1: MEX kernel signature mismatch with MATLAB wrapper

**What goes wrong:** MATLAB wrapper passes `double row vector` but C kernel assumes column-major
(MATLAB-native) storage. `mxGetPr` returns column-major data; row vs. column doesn't change the
pointer but changes `mxGetM` / `mxGetN` used for size validation.
**How to avoid:** Always use `mxGetNumberOfElements(prhs[k])` for size checks, not `mxGetM` or
`mxGetN`. Match the existing kernels exactly.

### Pitfall 2: Persistent useMex flag never resets in test isolation

**What goes wrong:** `persistent useMex` is set in the first call. If the MEX binary is compiled
during a test run, subsequent calls in the same MATLAB session still use the cached `useMex=false`
from before compilation.
**How to avoid:** Call `clear minmax_downsample` after building MEX in `build_mex()`. This resets
all persistent variables. Existing kernels use this pattern — new wrappers must do the same.

### Pitfall 3: Log-scale kernel receives zero or negative X

**What goes wrong:** `log10(0)` returns `-Inf`; `log10(-x)` returns `NaN`. The logx bucket index
computation would then write to bucket `-Inf` (crash or silent corruption).
**How to avoid:** Add a guard at the C level:
```c
if (x[i] <= 0.0) continue;  // skip non-positive values on log scale
```
The MATLAB fallback `minmax_core_logx` already handles this implicitly via the mask
`segX >= edges(b)` where `edges(1) > 0`.

### Pitfall 4: NaN split MEX returns 0-indexed vs 1-indexed

**What goes wrong:** MATLAB arrays are 1-indexed. If `nan_segment_split_mex` returns C-style
0-indexed segment boundaries, the MATLAB wrapper will silently access `y(0)` (returns empty) or
`y(segStart)` offset by 1.
**How to avoid:** Return 1-indexed int32 values from MEX. Use `(mwIndex)segStart + 1` when
writing output: `segStartsOut[k] = (double)(cStart + 1)`.

### Pitfall 5: Octave incompatibility — MEX binary format differs

**What goes wrong:** MATLAB MEX binaries (`.mexmaca64`, `.mexa64`, `.mexw64`) are not loadable
by Octave. Octave uses `.mex` with a different entry-point convention on some platforms.
**How to avoid:** Follow the existing pattern — the `build_mex()` function in `install.m` already
handles Octave vs. MATLAB detection. The `persistent useMex = (exist(..., 'file') == 3)` guard
ensures Octave uses the pure-MATLAB fallback. No additional changes needed; maintain MATLAB-target
MEX only.

---

## Standard Stack

No new external dependencies. All new kernels use existing infrastructure:

| Component | Version | Purpose |
|-----------|---------|---------|
| `simd_utils.h` | (bundled) | SIMD abstraction layer — AVX2/NEON/scalar |
| MATLAB MEX API | R2020b+ | `mexFunction`, `mxGetPr`, `mxCreateDoubleMatrix` |
| `mxCalloc`/`mxFree` | R2020b+ | MEX-safe heap allocation (auto-freed on error) |

---

## Code Examples

### Example: O(N) log-bucket pass in C (Opportunity 1)

```c
// Source: minmax_core_mex.c pattern adapted for log-spaced buckets
// Pre-compute log edges in MATLAB, pass as additional input
const double *logEdges = mxGetPr(prhs[3]);  // nb+1 log10 edges
const size_t nb = mxGetNumberOfElements(prhs[3]) - 1;

// Single O(N) pass: assign each x[i] to a bucket via binary search on logEdges
for (size_t i = 0; i < N; i++) {
    if (x[i] <= 0.0) continue;
    double lx = log10(x[i]);
    // find bucket b such that logEdges[b] <= lx < logEdges[b+1]
    size_t b = (size_t)((lx - logEdges[0]) / (logEdges[nb] - logEdges[0]) * nb);
    b = (b < nb) ? b : nb - 1;  // clamp
    // update per-bucket min/max (same as minmax_core_mex)
}
```

### Example: SIMD NaN detection (Opportunity 2)

```c
// Source: violation_cull_mex.c SIMD pattern adapted for isnan scan
#if SIMD_WIDTH > 1
{
    size_t simd_end = ((N) / SIMD_WIDTH) * SIMD_WIDTH;
    for (size_t i = 0; i < simd_end; i += SIMD_WIDTH) {
        simd_double v = simd_load(&y[i]);
        // NaN test: v != v  (IEEE 754 guarantee)
        // Use platform-specific compare; scalar fallback below
        for (size_t k = 0; k < SIMD_WIDTH; k++) {
            double val = ((double*)&v)[k];
            isNanBuf[i + k] = (val != val);
        }
    }
    // scalar tail
    for (size_t i = simd_end; i < N; i++) {
        isNanBuf[i] = (y[i] != y[i]);
    }
}
```

---

## Already-Optimized Code (Do Not Duplicate Effort)

The following areas were addressed by prior phases and must NOT be re-implemented:

| What | Phase | Result |
|------|-------|--------|
| `minmax_core` (linear, NaN-free) | Pre-existing | `minmax_core_mex.c` — SIMD done |
| LTTB core | Pre-existing | `lttb_core_mex.c` — SIMD triangle-area loop done |
| Violation detection + cull | Pre-existing | `violation_cull_mex.c` — fused kernel done |
| Binary search | Pre-existing | `binary_search_mex.c` — done |
| Step-function conversion | Pre-existing | `to_step_function_mex.c` — done |
| Theme caching | Phase 01-perf-opt | `getCachedTheme()` — done |
| `addWidget` dispatch | Phase 01-perf-opt | `containers.Map` — done |
| `onLiveTick` single-pass | Phase 01-perf-opt | Single loop, single `activePageWidgets()` — done |
| `switchPage` visibility toggle | Phase 01-perf-opt | O(1) panel show/hide — done |
| Resize in-place reposition | Phase 01-perf-opt | `repositionPanels()` — done |

---

## Environment Availability

Step 2.6: SKIPPED — this is a pure code/config change. No external tools, databases, or services
are needed to implement C MEX kernels. The MEX build infrastructure (Xcode CLT on macOS,
`mex` / `mkoctfile` commands) is already in use and confirmed working by the existing 8 kernels.

---

## Open Questions

1. **Log approximation precision in SIMD**
   - What we know: `__builtin_ia32_log_ps` / SVML is available on Intel but not via standard C headers.
   - What's unclear: Whether pre-computing log-edges in MATLAB and passing them to MEX (avoiding
     `log10` in C) is accurate enough for visual bucketing.
   - Recommendation: Pre-compute `logEdges = 10.^linspace(log10(xMin), log10(xMax), nb+1)` in
     MATLAB and pass as a 5th input to `minmax_core_logx_mex`. This avoids all `log10` in C entirely
     and is 100% portable.

2. **`nan_segment_split_mex` output type — double or int32?**
   - What we know: `find()` returns double in MATLAB; int32 is more memory-efficient and faster
     for indexing in C.
   - What's unclear: Whether passing int32 arrays back to MATLAB (for use as indices) causes
     any Octave compatibility issues.
   - Recommendation: Return `double` arrays (matching `find()` semantics) to avoid any int32
     casting issues in the MATLAB caller. Memory cost is negligible — segment counts are small.

3. **Whether Opportunity 3 (violation_cull inner loop) is actually the bottleneck**
   - What we know: The inner detection loop is scalar; SIMD would give 4× per-element.
   - What's unclear: What fraction of `updateViolations()` time is spent in detection vs. bucket
     management vs. output concatenation.
   - Recommendation: Profile with `tic/toc` inside `violation_cull.m` before investing in kernel
     modification. If detection is <20% of call time, skip.

---

## Sources

### Primary (HIGH confidence)

- Direct source inspection of `libs/FastSense/FastSense.m` (all hotspot functions)
- Direct source inspection of `libs/FastSense/private/minmax_downsample.m`
- Direct source inspection of `libs/FastSense/private/lttb_downsample.m`
- Direct source inspection of `libs/FastSense/private/violation_cull.m`
- Direct source inspection of `libs/FastSense/private/mex_src/minmax_core_mex.c`
- Direct source inspection of `libs/FastSense/private/mex_src/violation_cull_mex.c`
- Direct source inspection of `libs/FastSense/private/mex_src/lttb_core_mex.c`
- Direct source inspection of `libs/FastSense/private/mex_src/simd_utils.h` (pattern reference)
- Direct source inspection of `libs/Dashboard/DashboardEngine.m` (post Phase-01 state)
- Direct source inspection of `libs/Dashboard/NumberWidget.m` (computeTrend)
- Direct source inspection of `libs/Dashboard/GaugeWidget.m` (renderArc / updateDisplay)
- Phase 01-dashboard-performance-optimization SUMMARY files (already-completed work)

### Secondary (MEDIUM confidence)

- `CLAUDE.md` technology stack and constraint sections — project conventions verified

---

## Metadata

**Confidence breakdown:**
- Opportunities 1, 2, 4: HIGH — MATLAB loops with clear O(N) or O(N×nb) complexity, direct MEX equivalent is O(N), fallback structure identical to existing kernels
- Opportunity 3: MEDIUM — inner loop identified as scalar, but total impact requires profiling to confirm fraction of call time
- Opportunity 5: MEDIUM — path is real but hot only under specific conditions (large sensor arrays + many NumberWidgets)
- Not-worth-it analysis: HIGH — verified call counts and operand sizes are too small to benefit

**Research date:** 2026-04-05
**Valid until:** 2026-07-05 (stable architecture; opportunities will not change unless new widget types
or downsampling paths are added)
