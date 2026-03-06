# MEX Acceleration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add C MEX implementations with SIMD intrinsics (AVX2 for x86_64, NEON for ARM64) for `minmax_core`, `lttb_core`, and `binary_search`, with automatic fallback to existing pure-MATLAB code.

**Architecture:** Three C MEX files in `private/mex_src/` share a `simd_utils.h` header that abstracts AVX2/SSE2/NEON behind unified macros. Each existing MATLAB wrapper gets a `persistent useMex` guard that auto-detects MEX availability. A `build_mex.m` script at the project root handles platform detection and compilation.

**Tech Stack:** C11, MATLAB MEX API (`mex.h`), AVX2/SSE2 intrinsics (`immintrin.h`), ARM NEON intrinsics (`arm_neon.h`), MATLAB R2020b+.

**Design doc:** `FastPlot/docs/plans/2026-03-06-mex-acceleration-design.md`

---

## Task 1: SIMD Abstraction Header

**Files:**
- Create: `FastPlot/private/mex_src/simd_utils.h`

**Step 1: Create directory and write simd_utils.h**

```bash
mkdir -p FastPlot/private/mex_src
```

Create `FastPlot/private/mex_src/simd_utils.h`:

```c
#ifndef SIMD_UTILS_H
#define SIMD_UTILS_H

#include <math.h>
#include <stddef.h>

/*
 * simd_utils.h — Compile-time SIMD abstraction for FastPlot MEX files.
 *
 * Provides unified operations on packed doubles:
 *   - AVX2:  4 doubles per vector  (__m256d)
 *   - SSE2:  2 doubles per vector  (__m128d)
 *   - NEON:  2 doubles per vector  (float64x2_t)
 *   - Scalar fallback if none detected
 */

/* ============================================================
 * AVX2 path (x86_64 with -mavx2)
 * ============================================================ */
#if defined(__AVX2__)

#include <immintrin.h>

#define SIMD_WIDTH 4
typedef __m256d simd_double;

static inline simd_double simd_load(const double *p) { return _mm256_loadu_pd(p); }
static inline void simd_store(double *p, simd_double v) { _mm256_storeu_pd(p, v); }
static inline simd_double simd_set1(double v) { return _mm256_set1_pd(v); }
static inline simd_double simd_min(simd_double a, simd_double b) { return _mm256_min_pd(a, b); }
static inline simd_double simd_max(simd_double a, simd_double b) { return _mm256_max_pd(a, b); }
static inline simd_double simd_sub(simd_double a, simd_double b) { return _mm256_sub_pd(a, b); }
static inline simd_double simd_mul(simd_double a, simd_double b) { return _mm256_mul_pd(a, b); }

/* Absolute value: clear sign bit */
static inline simd_double simd_abs(simd_double a) {
    __m256d sign_mask = _mm256_set1_pd(-0.0);
    return _mm256_andnot_pd(sign_mask, a);
}

/* Horizontal max of 4 doubles */
static inline double simd_hmax(simd_double v) {
    /* [a b c d] */
    __m128d lo = _mm256_castpd256_pd128(v);    /* [a b] */
    __m128d hi = _mm256_extractf128_pd(v, 1);  /* [c d] */
    __m128d m = _mm_max_pd(lo, hi);            /* [max(a,c) max(b,d)] */
    __m128d s = _mm_unpackhi_pd(m, m);         /* [max(b,d) max(b,d)] */
    __m128d r = _mm_max_pd(m, s);
    return _mm_cvtsd_f64(r);
}

/* Horizontal min of 4 doubles */
static inline double simd_hmin(simd_double v) {
    __m128d lo = _mm256_castpd256_pd128(v);
    __m128d hi = _mm256_extractf128_pd(v, 1);
    __m128d m = _mm_min_pd(lo, hi);
    __m128d s = _mm_unpackhi_pd(m, m);
    __m128d r = _mm_min_pd(m, s);
    return _mm_cvtsd_f64(r);
}

/* ============================================================
 * SSE2 path (x86_64 without AVX2)
 * ============================================================ */
#elif defined(__SSE2__)

#include <emmintrin.h>

#define SIMD_WIDTH 2
typedef __m128d simd_double;

static inline simd_double simd_load(const double *p) { return _mm_loadu_pd(p); }
static inline void simd_store(double *p, simd_double v) { _mm_storeu_pd(p, v); }
static inline simd_double simd_set1(double v) { return _mm_set1_pd(v); }
static inline simd_double simd_min(simd_double a, simd_double b) { return _mm_min_pd(a, b); }
static inline simd_double simd_max(simd_double a, simd_double b) { return _mm_max_pd(a, b); }
static inline simd_double simd_sub(simd_double a, simd_double b) { return _mm_sub_pd(a, b); }
static inline simd_double simd_mul(simd_double a, simd_double b) { return _mm_mul_pd(a, b); }

static inline simd_double simd_abs(simd_double a) {
    __m128d sign_mask = _mm_set1_pd(-0.0);
    return _mm_andnot_pd(sign_mask, a);
}

static inline double simd_hmax(simd_double v) {
    __m128d s = _mm_unpackhi_pd(v, v);
    __m128d r = _mm_max_pd(v, s);
    return _mm_cvtsd_f64(r);
}

static inline double simd_hmin(simd_double v) {
    __m128d s = _mm_unpackhi_pd(v, v);
    __m128d r = _mm_min_pd(v, s);
    return _mm_cvtsd_f64(r);
}

/* ============================================================
 * ARM NEON path (Apple Silicon, ARM64)
 * ============================================================ */
#elif defined(__ARM_NEON) || defined(__aarch64__)

#include <arm_neon.h>

#define SIMD_WIDTH 2
typedef float64x2_t simd_double;

static inline simd_double simd_load(const double *p) { return vld1q_f64(p); }
static inline void simd_store(double *p, simd_double v) { vst1q_f64(p, v); }
static inline simd_double simd_set1(double v) { return vdupq_n_f64(v); }
static inline simd_double simd_min(simd_double a, simd_double b) { return vminq_f64(a, b); }
static inline simd_double simd_max(simd_double a, simd_double b) { return vmaxq_f64(a, b); }
static inline simd_double simd_sub(simd_double a, simd_double b) { return vsubq_f64(a, b); }
static inline simd_double simd_mul(simd_double a, simd_double b) { return vmulq_f64(a, b); }
static inline simd_double simd_abs(simd_double a) { return vabsq_f64(a); }

static inline double simd_hmax(simd_double v) {
    return vmaxvq_f64(v);
}

static inline double simd_hmin(simd_double v) {
    return vminvq_f64(v);
}

/* ============================================================
 * Scalar fallback
 * ============================================================ */
#else

#define SIMD_WIDTH 1

typedef double simd_double;

static inline simd_double simd_load(const double *p) { return *p; }
static inline void simd_store(double *p, simd_double v) { *p = v; }
static inline simd_double simd_set1(double v) { return v; }
static inline simd_double simd_min(simd_double a, simd_double b) { return a < b ? a : b; }
static inline simd_double simd_max(simd_double a, simd_double b) { return a > b ? a : b; }
static inline simd_double simd_sub(simd_double a, simd_double b) { return a - b; }
static inline simd_double simd_mul(simd_double a, simd_double b) { return a * b; }
static inline simd_double simd_abs(simd_double a) { return fabs(a); }
static inline double simd_hmax(simd_double v) { return v; }
static inline double simd_hmin(simd_double v) { return v; }

#endif

#endif /* SIMD_UTILS_H */
```

**Step 2: Commit**

```bash
cd FastPlot
git add private/mex_src/simd_utils.h
git commit -m "Add SIMD abstraction header for MEX acceleration

Compile-time detection of AVX2, SSE2, NEON, or scalar fallback.
Provides unified macros for packed-double min/max/mul/sub/abs."
```

---

## Task 2: binary_search_mex

**Files:**
- Create: `FastPlot/private/mex_src/binary_search_mex.c`

**Step 1: Write binary_search_mex.c**

Create `FastPlot/private/mex_src/binary_search_mex.c`:

```c
/*
 * binary_search_mex.c — MEX binary search on sorted double array.
 *
 * Usage from MATLAB:
 *   idx = binary_search_mex(x, val, direction)
 *
 *   x:         double row vector, sorted ascending
 *   val:       double scalar
 *   direction: char array, 'left' or 'right'
 *              'left'  -> first index where x(idx) >= val
 *              'right' -> last index where x(idx) <= val
 *
 *   Returns: 1-based index, clamped to [1, numel(x)]
 *
 * No SIMD — O(log n) with so few iterations that SIMD adds no value.
 * The win is eliminating MATLAB interpreter loop overhead.
 */

#include "mex.h"
#include <string.h>

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    /* Validate inputs */
    if (nrhs != 3) {
        mexErrMsgIdAndTxt("FastPlot:binary_search_mex:nrhs",
                          "Three inputs required: x, val, direction.");
    }
    if (!mxIsDouble(prhs[0]) || mxIsComplex(prhs[0])) {
        mexErrMsgIdAndTxt("FastPlot:binary_search_mex:notDouble",
                          "x must be a real double array.");
    }
    if (!mxIsDouble(prhs[1]) || mxGetNumberOfElements(prhs[1]) != 1) {
        mexErrMsgIdAndTxt("FastPlot:binary_search_mex:notScalar",
                          "val must be a scalar double.");
    }
    if (!mxIsChar(prhs[2])) {
        mexErrMsgIdAndTxt("FastPlot:binary_search_mex:notChar",
                          "direction must be a char array.");
    }

    const double *x = mxGetDoubles(prhs[0]);
    const double val = mxGetScalar(prhs[1]);
    const size_t n = mxGetNumberOfElements(prhs[0]);

    /* Get direction string */
    char dir[8];
    mxGetString(prhs[2], dir, sizeof(dir));
    int is_left = (strcmp(dir, "left") == 0);

    size_t lo = 0;
    size_t hi = n - 1;
    size_t idx;

    if (is_left) {
        /* First index where x[idx] >= val */
        idx = n - 1; /* default: last element if all < val */
        while (lo <= hi) {
            size_t mid = lo + (hi - lo) / 2;
            if (x[mid] >= val) {
                idx = mid;
                if (mid == 0) break;
                hi = mid - 1;
            } else {
                lo = mid + 1;
            }
        }
    } else {
        /* Last index where x[idx] <= val */
        idx = 0; /* default: first element if all > val */
        while (lo <= hi) {
            size_t mid = lo + (hi - lo) / 2;
            if (x[mid] <= val) {
                idx = mid;
                lo = mid + 1;
            } else {
                if (mid == 0) break;
                hi = mid - 1;
            }
        }
    }

    /* Return 1-based index */
    plhs[0] = mxCreateDoubleScalar((double)(idx + 1));
}
```

**Step 2: Commit**

```bash
cd FastPlot
git add private/mex_src/binary_search_mex.c
git commit -m "Add binary_search MEX implementation

Plain C binary search, no SIMD. Eliminates MATLAB interpreter
loop overhead for O(log n) search on sorted double arrays."
```

---

## Task 3: minmax_core_mex

**Files:**
- Create: `FastPlot/private/mex_src/minmax_core_mex.c`

**Step 1: Write minmax_core_mex.c**

Create `FastPlot/private/mex_src/minmax_core_mex.c`:

```c
/*
 * minmax_core_mex.c — SIMD-accelerated MinMax downsampling core.
 *
 * Usage from MATLAB:
 *   [xOut, yOut] = minmax_core_mex(x, y, numBuckets)
 *
 *   x, y:        double row vectors (contiguous, no NaN)
 *   numBuckets:  scalar integer
 *
 *   Returns: xOut, yOut — double row vectors of length 2*numBuckets
 *            Each bucket produces (min, max) or (max, min) pair,
 *            ordered to preserve X monotonicity.
 *
 * SIMD strategy: within each bucket, scan elements with SIMD min/max
 * reduction, then scalar pass to find indices. The index tracking
 * requires sequential comparison, but the min/max values are found
 * via SIMD vector reduction which is the hot path for large buckets.
 */

#include "mex.h"
#include "simd_utils.h"

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    /* Validate inputs */
    if (nrhs != 3) {
        mexErrMsgIdAndTxt("FastPlot:minmax_core_mex:nrhs",
                          "Three inputs required: x, y, numBuckets.");
    }
    if (!mxIsDouble(prhs[0]) || !mxIsDouble(prhs[1])) {
        mexErrMsgIdAndTxt("FastPlot:minmax_core_mex:notDouble",
                          "x and y must be real double arrays.");
    }

    const double *x = mxGetDoubles(prhs[0]);
    const double *y = mxGetDoubles(prhs[1]);
    const size_t n = mxGetNumberOfElements(prhs[0]);
    const size_t nb = (size_t)mxGetScalar(prhs[2]);

    const size_t bucketSize = n / nb;
    const size_t usable = bucketSize * nb;
    const size_t outLen = 2 * nb;

    /* Allocate output */
    plhs[0] = mxCreateDoubleMatrix(1, outLen, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, outLen, mxREAL);
    double *xOut = mxGetDoubles(plhs[0]);
    double *yOut = mxGetDoubles(plhs[1]);

    size_t b;
    for (b = 0; b < nb; b++) {
        const size_t base = b * bucketSize;
        size_t end = (b == nb - 1) ? n : base + bucketSize;

        double ymin_val = y[base];
        double ymax_val = y[base];
        size_t imin = base;
        size_t imax = base;

        size_t i = base + 1;

        /* SIMD pass: find min/max values (not indices) */
#if SIMD_WIDTH > 1
        {
            simd_double vmin = simd_set1(ymin_val);
            simd_double vmax = simd_set1(ymax_val);

            /* Align to SIMD_WIDTH boundary from current position */
            size_t simd_end = base + ((end - base) / SIMD_WIDTH) * SIMD_WIDTH;

            size_t j;
            for (j = base; j < simd_end; j += SIMD_WIDTH) {
                simd_double v = simd_load(&y[j]);
                vmin = simd_min(vmin, v);
                vmax = simd_max(vmax, v);
            }

            ymin_val = simd_hmin(vmin);
            ymax_val = simd_hmax(vmax);

            /* Now find the actual indices with a scalar pass */
            imin = base;
            imax = base;
            for (j = base; j < end; j++) {
                if (y[j] < y[imin]) imin = j;
                if (y[j] > y[imax]) imax = j;
            }
            ymin_val = y[imin];
            ymax_val = y[imax];
        }
#else
        /* Scalar path */
        for (; i < end; i++) {
            if (y[i] < ymin_val) {
                ymin_val = y[i];
                imin = i;
            }
            if (y[i] > ymax_val) {
                ymax_val = y[i];
                imax = i;
            }
        }
#endif

        /* Output in X-order (preserve monotonicity) */
        size_t out_base = b * 2;
        if (imin <= imax) {
            xOut[out_base]     = x[imin];
            yOut[out_base]     = ymin_val;
            xOut[out_base + 1] = x[imax];
            yOut[out_base + 1] = ymax_val;
        } else {
            xOut[out_base]     = x[imax];
            yOut[out_base]     = ymax_val;
            xOut[out_base + 1] = x[imin];
            yOut[out_base + 1] = ymin_val;
        }
    }
}
```

**Step 2: Commit**

```bash
cd FastPlot
git add private/mex_src/minmax_core_mex.c
git commit -m "Add minmax_core MEX implementation with SIMD

SIMD min/max reduction per bucket (AVX2/SSE2/NEON), with scalar
index-tracking pass. Handles remainder by extending last bucket."
```

---

## Task 4: lttb_core_mex

**Files:**
- Create: `FastPlot/private/mex_src/lttb_core_mex.c`

**Step 1: Write lttb_core_mex.c**

Create `FastPlot/private/mex_src/lttb_core_mex.c`:

```c
/*
 * lttb_core_mex.c — SIMD-accelerated LTTB downsampling core.
 *
 * Usage from MATLAB:
 *   [xOut, yOut] = lttb_core_mex(x, y, numOut)
 *
 *   x, y:    double row vectors (contiguous, no NaN)
 *   numOut:  scalar integer >= 2
 *
 *   Returns: xOut, yOut — double row vectors of length numOut
 *
 * SIMD strategy: the outer loop is sequential (each bucket depends on
 * the previous selected point). The inner triangle-area computation
 * across bucket candidates is vectorized:
 *   area = |((pX - avgX) * (y[i] - pY) - (pX - x[i]) * (avgY - pY))|
 */

#include "mex.h"
#include "simd_utils.h"
#include <math.h>

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    /* Validate inputs */
    if (nrhs != 3) {
        mexErrMsgIdAndTxt("FastPlot:lttb_core_mex:nrhs",
                          "Three inputs required: x, y, numOut.");
    }
    if (!mxIsDouble(prhs[0]) || !mxIsDouble(prhs[1])) {
        mexErrMsgIdAndTxt("FastPlot:lttb_core_mex:notDouble",
                          "x and y must be real double arrays.");
    }

    const double *x = mxGetDoubles(prhs[0]);
    const double *y = mxGetDoubles(prhs[1]);
    const size_t n = mxGetNumberOfElements(prhs[0]);
    const size_t numOut = (size_t)mxGetScalar(prhs[2]);

    /* Allocate output */
    plhs[0] = mxCreateDoubleMatrix(1, numOut, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, numOut, mxREAL);
    double *xOut = mxGetDoubles(plhs[0]);
    double *yOut = mxGetDoubles(plhs[1]);

    /* First and last points are always selected */
    xOut[0] = x[0];
    yOut[0] = y[0];
    xOut[numOut - 1] = x[n - 1];
    yOut[numOut - 1] = y[n - 1];

    if (numOut <= 2) return;

    const double bucketSize = (double)(n - 2) / (double)(numOut - 2);

    size_t prevSelectedIdx = 0; /* 0-based */

    size_t i;
    for (i = 1; i < numOut - 1; i++) {
        /* Current bucket range */
        size_t bStart = (size_t)floor((double)(i - 1) * bucketSize) + 1;
        size_t bEnd = (size_t)floor((double)i * bucketSize);
        if (bEnd > n - 2) bEnd = n - 2;

        /* Next bucket range (for average point) */
        size_t nStart = (size_t)floor((double)i * bucketSize) + 1;
        size_t nEnd = (size_t)floor((double)(i + 1) * bucketSize);
        if (nEnd > n - 2) nEnd = n - 2;
        if (nEnd < nStart) nEnd = nStart;

        /* Compute average of next bucket */
        double avgX = 0.0, avgY = 0.0;
        size_t nCount = nEnd - nStart + 1;
        size_t j;
        for (j = nStart; j <= nEnd; j++) {
            avgX += x[j];
            avgY += y[j];
        }
        avgX /= (double)nCount;
        avgY /= (double)nCount;

        /* Previous selected point */
        double pX = x[prevSelectedIdx];
        double pY = y[prevSelectedIdx];

        /* Find candidate with maximum triangle area */
        double bestArea = -1.0;
        size_t bestIdx = bStart;

        /* Precompute constants for the area formula */
        double dx_pa = pX - avgX;   /* pX - avgX: constant across candidates */
        double dy_ap = avgY - pY;   /* avgY - pY: constant across candidates */

        size_t cand = bStart;

        /* SIMD inner loop over candidates */
#if SIMD_WIDTH > 1
        {
            simd_double v_dx_pa = simd_set1(dx_pa);
            simd_double v_dy_ap = simd_set1(dy_ap);
            simd_double v_pY = simd_set1(pY);
            simd_double v_pX = simd_set1(pX);
            simd_double v_bestArea = simd_set1(-1.0);

            size_t simd_end = bStart + ((bEnd - bStart + 1) / SIMD_WIDTH) * SIMD_WIDTH;

            for (cand = bStart; cand < simd_end; cand += SIMD_WIDTH) {
                simd_double vy = simd_load(&y[cand]);
                simd_double vx = simd_load(&x[cand]);

                /* area = |dx_pa * (y[cand] - pY) - (pX - x[cand]) * dy_ap| */
                simd_double term1 = simd_mul(v_dx_pa, simd_sub(vy, v_pY));
                simd_double term2 = simd_mul(simd_sub(v_pX, vx), v_dy_ap);
                simd_double area = simd_abs(simd_sub(term1, term2));

                /* Check if any lane beats current best — extract and compare */
                double lanes[SIMD_WIDTH];
                simd_store(lanes, area);

                size_t k;
                for (k = 0; k < SIMD_WIDTH; k++) {
                    if (lanes[k] > bestArea) {
                        bestArea = lanes[k];
                        bestIdx = cand + k;
                    }
                }
            }

            /* Scalar remainder */
            for (; cand <= bEnd; cand++) {
                double area = fabs(dx_pa * (y[cand] - pY) - (pX - x[cand]) * dy_ap);
                if (area > bestArea) {
                    bestArea = area;
                    bestIdx = cand;
                }
            }
        }
#else
        /* Scalar path */
        for (cand = bStart; cand <= bEnd; cand++) {
            double area = fabs(dx_pa * (y[cand] - pY) - (pX - x[cand]) * dy_ap);
            if (area > bestArea) {
                bestArea = area;
                bestIdx = cand;
            }
        }
#endif

        xOut[i] = x[bestIdx];
        yOut[i] = y[bestIdx];
        prevSelectedIdx = bestIdx;
    }
}
```

**Step 2: Commit**

```bash
cd FastPlot
git add private/mex_src/lttb_core_mex.c
git commit -m "Add lttb_core MEX implementation with SIMD

SIMD-vectorized triangle area computation across bucket candidates.
Sequential outer loop preserved (each bucket depends on previous)."
```

---

## Task 5: Build Script

**Files:**
- Create: `FastPlot/build_mex.m`

**Step 1: Write build_mex.m**

Create `FastPlot/build_mex.m`:

```matlab
function build_mex()
%BUILD_MEX Compile FastPlot MEX files with platform-appropriate SIMD flags.
%   build_mex()
%
%   Detects CPU architecture, sets compiler flags for AVX2/SSE2/NEON,
%   and compiles all MEX source files from private/mex_src/ into private/.
%
%   Safe to re-run — overwrites existing MEX binaries.

    rootDir = fileparts(mfilename('fullpath'));
    srcDir  = fullfile(rootDir, 'private', 'mex_src');
    outDir  = fullfile(rootDir, 'private');

    % Detect architecture
    arch = computer('arch');
    fprintf('Architecture: %s\n', arch);

    % Set SIMD compiler flags
    switch arch
        case {'maci64', 'glnxa64', 'win64'}
            % x86_64: try AVX2 first
            simd_flags = {'-mavx2', '-mfma', '-O3'};
            fprintf('SIMD target: AVX2 + FMA\n');
        case 'maca64'
            % Apple Silicon ARM64: NEON is default
            simd_flags = {'-O3'};
            fprintf('SIMD target: ARM NEON (default on aarch64)\n');
        otherwise
            simd_flags = {'-O3'};
            fprintf('SIMD target: scalar fallback\n');
    end

    % Common flags
    include_flag = ['-I' srcDir];

    % Files to compile: {source_name, output_name}
    mex_files = {
        'binary_search_mex.c',  'binary_search_mex'
        'minmax_core_mex.c',    'minmax_core_mex'
        'lttb_core_mex.c',      'lttb_core_mex'
    };

    fprintf('\n');

    n_success = 0;
    n_fail = 0;

    for i = 1:size(mex_files, 1)
        src_file = fullfile(srcDir, mex_files{i, 1});
        out_name = mex_files{i, 2};

        fprintf('Compiling %s ... ', mex_files{i, 1});

        try
            % Build CFLAGS string
            cflags = ['CFLAGS="$CFLAGS ' strjoin(simd_flags, ' ') '"'];

            mex(cflags, include_flag, ...
                '-outdir', outDir, ...
                '-output', out_name, ...
                src_file);

            fprintf('OK\n');
            n_success = n_success + 1;
        catch e
            fprintf('FAILED\n');
            fprintf('  Error: %s\n', e.message);

            % If AVX2 failed on x86_64, retry with SSE2
            if any(strcmp(arch, {'maci64', 'glnxa64', 'win64'})) && ...
               any(contains(simd_flags, 'mavx2'))
                fprintf('  Retrying with SSE2 fallback ... ');
                try
                    cflags_sse = 'CFLAGS="$CFLAGS -msse2 -O3"';
                    mex(cflags_sse, include_flag, ...
                        '-outdir', outDir, ...
                        '-output', out_name, ...
                        src_file);
                    fprintf('OK (SSE2)\n');
                    n_success = n_success + 1;
                catch e2
                    fprintf('FAILED\n');
                    fprintf('  Error: %s\n', e2.message);
                    n_fail = n_fail + 1;
                end
            else
                n_fail = n_fail + 1;
            end
        end
    end

    fprintf('\n%d/%d MEX files compiled successfully.\n', ...
        n_success, size(mex_files, 1));

    if n_fail > 0
        fprintf('(%d failed — MATLAB fallback will be used for those.)\n', n_fail);
    end
end
```

**Step 2: Commit**

```bash
cd FastPlot
git add build_mex.m
git commit -m "Add build_mex.m script for MEX compilation

Detects x86_64 (AVX2 with SSE2 fallback) vs ARM64 (NEON).
Compiles all 3 MEX files into private/. Safe to re-run."
```

---

## Task 6: Wire MEX Fallback into MATLAB Wrappers

**Files:**
- Modify: `FastPlot/private/binary_search.m` (lines 1-39)
- Modify: `FastPlot/private/minmax_downsample.m` (lines 21, 73)
- Modify: `FastPlot/private/lttb_downsample.m` (lines 59)

**Step 1: Modify binary_search.m — add MEX dispatch**

Replace the entire `binary_search.m` with:

```matlab
function idx = binary_search(x, val, direction)
%BINARY_SEARCH Find index in sorted array via binary search.
%   idx = binary_search(x, val, 'left')  — first index where x >= val
%   idx = binary_search(x, val, 'right') — last index where x <= val
%
%   Clamps to [1, numel(x)] — never returns out-of-bounds.
%   Uses MEX implementation if available, otherwise pure MATLAB.

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('binary_search_mex', 'file') == 3);
    end

    if useMex
        idx = binary_search_mex(x, val, direction);
        return;
    end

    n = numel(x);

    if strcmp(direction, 'left')
        % Find first index where x(idx) >= val
        lo = 1;
        hi = n;
        idx = n; % default if all < val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val
                idx = mid;
                hi = mid - 1;
            else
                lo = mid + 1;
            end
        end
    else
        % Find last index where x(idx) <= val
        lo = 1;
        hi = n;
        idx = 1; % default if all > val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val
                idx = mid;
                lo = mid + 1;
            else
                hi = mid - 1;
            end
        end
    end
end
```

**Step 2: Modify minmax_downsample.m — add MEX dispatch for minmax_core calls**

At the top of `minmax_downsample.m`, after line 9 (`%   If total non-NaN points <= 2*numBuckets, returns data unchanged.`), add:

```matlab
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('minmax_core_mex', 'file') == 3);
    end
```

Then replace the two `minmax_core` calls:

Line 21 — change:
```matlab
        [xOut, yOut] = minmax_core(x, y, numBuckets);
```
to:
```matlab
        if useMex
            [xOut, yOut] = minmax_core_mex(x, y, numBuckets);
        else
            [xOut, yOut] = minmax_core(x, y, numBuckets);
        end
```

Line 73 — change:
```matlab
            [sx, sy] = minmax_core(segX, segY, nb);
```
to:
```matlab
            if useMex
                [sx, sy] = minmax_core_mex(segX, segY, nb);
            else
                [sx, sy] = minmax_core(segX, segY, nb);
            end
```

**Step 3: Modify lttb_downsample.m — add MEX dispatch for lttb_core call**

At the top of `lttb_downsample.m`, after line 9 (`%   proportionally, then rejoins with NaN separators.`), add:

```matlab
    persistent useMex;
    if isempty(useMex)
        useMex = (exist('lttb_core_mex', 'file') == 3);
    end
```

Then replace line 59:
```matlab
            [sx, sy] = lttb_core(segX, segY, nout);
```
with:
```matlab
            if useMex
                [sx, sy] = lttb_core_mex(segX, segY, nout);
            else
                [sx, sy] = lttb_core(segX, segY, nout);
            end
```

**Step 4: Run existing tests to verify fallback path still works**

```bash
cd FastPlot && matlab -batch "addpath('tests'); addpath('private'); run_all_tests()"
```

Expected: All existing tests pass (MEX not compiled yet, so fallback path runs).

**Step 5: Commit**

```bash
cd FastPlot
git add private/binary_search.m private/minmax_downsample.m private/lttb_downsample.m
git commit -m "Wire MEX fallback dispatch into MATLAB wrappers

Each wrapper uses persistent useMex flag to auto-detect MEX
availability. Falls back to existing pure-MATLAB code if not compiled."
```

---

## Task 7: MEX Parity Tests

**Files:**
- Create: `FastPlot/tests/test_mex_parity.m`

**Step 1: Write test_mex_parity.m**

Create `FastPlot/tests/test_mex_parity.m`:

```matlab
function test_mex_parity()
%TEST_MEX_PARITY Verify MEX functions produce identical results to MATLAB.
%   Runs both MEX and MATLAB implementations side-by-side and compares.
%   Skips if MEX files are not compiled.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    has_bs  = (exist('binary_search_mex', 'file') == 3);
    has_mm  = (exist('minmax_core_mex', 'file') == 3);
    has_lt  = (exist('lttb_core_mex', 'file') == 3);

    if ~has_bs && ~has_mm && ~has_lt
        fprintf('    SKIPPED: No MEX files compiled. Run build_mex() first.\n');
        return;
    end

    tol = 1e-12;
    n_passed = 0;

    % ---- binary_search parity ----
    if has_bs
        x = [1 3 5 7 9 11 13 15 17 19];

        test_cases = {
            4,   'left',  3;
            6,   'right', 3;
            5,   'left',  3;
            5,   'right', 3;
            0,   'left',  1;
            100, 'right', 10;
            100, 'left',  10;
            0,   'right', 1;
        };

        for t = 1:size(test_cases, 1)
            val = test_cases{t, 1};
            dir = test_cases{t, 2};
            expected = test_cases{t, 3};
            result = binary_search_mex(x, val, dir);
            assert(result == expected, ...
                'binary_search_mex(%g, ''%s''): expected %d, got %d', ...
                val, dir, expected, result);
        end

        % Large array parity
        x_large = linspace(0, 1000, 1e6);
        vals = [0.001, 50.5, 500, 999.999];
        for v = 1:numel(vals)
            idx_m = binary_search_matlab(x_large, vals(v), 'left');
            idx_c = binary_search_mex(x_large, vals(v), 'left');
            assert(idx_m == idx_c, ...
                'binary_search parity failed for left val=%g: matlab=%d mex=%d', ...
                vals(v), idx_m, idx_c);

            idx_m = binary_search_matlab(x_large, vals(v), 'right');
            idx_c = binary_search_mex(x_large, vals(v), 'right');
            assert(idx_m == idx_c, ...
                'binary_search parity failed for right val=%g: matlab=%d mex=%d', ...
                vals(v), idx_m, idx_c);
        end

        fprintf('    binary_search_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- minmax_core parity ----
    if has_mm
        sizes = [100, 1000, 10000, 100000];
        buckets_list = [5, 50, 100, 500];

        for s = 1:numel(sizes)
            n = sizes(s);
            nb = buckets_list(s);
            x = linspace(0, 100, n);
            y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

            [xm, ym] = minmax_core_matlab(x, y, nb);
            [xc, yc] = minmax_core_mex(x, y, nb);

            assert(numel(xm) == numel(xc), ...
                'minmax_core output size mismatch at n=%d', n);
            assert(max(abs(xm - xc)) < tol, ...
                'minmax_core X mismatch at n=%d, maxdiff=%g', n, max(abs(xm - xc)));
            assert(max(abs(ym - yc)) < tol, ...
                'minmax_core Y mismatch at n=%d, maxdiff=%g', n, max(abs(ym - yc)));
        end

        fprintf('    minmax_core_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- lttb_core parity ----
    if has_lt
        sizes = [100, 1000, 10000];
        outs_list = [10, 50, 200];

        for s = 1:numel(sizes)
            n = sizes(s);
            nout = outs_list(s);
            x = linspace(0, 100, n);
            y = sin(x * 2 * pi / 10) + 0.3 * randn(1, n);

            [xm, ym] = lttb_core_matlab(x, y, nout);
            [xc, yc] = lttb_core_mex(x, y, nout);

            assert(numel(xm) == numel(xc), ...
                'lttb_core output size mismatch at n=%d', n);
            assert(max(abs(xm - xc)) < tol, ...
                'lttb_core X mismatch at n=%d, maxdiff=%g', n, max(abs(xm - xc)));
            assert(max(abs(ym - yc)) < tol, ...
                'lttb_core Y mismatch at n=%d, maxdiff=%g', n, max(abs(ym - yc)));
        end

        fprintf('    lttb_core_mex parity: PASSED\n');
        n_passed = n_passed + 1;
    end

    fprintf('    All %d MEX parity tests passed.\n', n_passed);
end


% ---- Pure MATLAB reference implementations (copied from private/) ----

function idx = binary_search_matlab(x, val, direction)
    n = numel(x);
    if strcmp(direction, 'left')
        lo = 1; hi = n; idx = n;
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val; idx = mid; hi = mid - 1;
            else; lo = mid + 1; end
        end
    else
        lo = 1; hi = n; idx = 1;
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val; idx = mid; lo = mid + 1;
            else; hi = mid - 1; end
        end
    end
end

function [xOut, yOut] = minmax_core_matlab(segX, segY, nb)
    segLen = numel(segY);
    bucketSize = floor(segLen / nb);
    usable = bucketSize * nb;
    yMat = reshape(segY(1:usable), bucketSize, nb);
    [yMinVals, iMin] = min(yMat, [], 1);
    [yMaxVals, iMax] = max(yMat, [], 1);
    offsets = (0:nb-1) * bucketSize;
    gMin = iMin + offsets;
    gMax = iMax + offsets;
    if usable < segLen
        remY = segY(usable+1:end);
        [remMinVal, remMinIdx] = min(remY);
        [remMaxVal, remMaxIdx] = max(remY);
        if remMinVal < yMinVals(nb)
            yMinVals(nb) = remMinVal;
            gMin(nb) = remMinIdx + usable;
        end
        if remMaxVal > yMaxVals(nb)
            yMaxVals(nb) = remMaxVal;
            gMax(nb) = remMaxIdx + usable;
        end
    end
    xMinVals = segX(gMin);
    xMaxVals = segX(gMax);
    minFirst = gMin <= gMax;
    xOut = zeros(1, 2*nb);
    yOut = zeros(1, 2*nb);
    odd  = 1:2:2*nb;
    even = 2:2:2*nb;
    xOut(odd(minFirst))   = xMinVals(minFirst);
    yOut(odd(minFirst))   = yMinVals(minFirst);
    xOut(even(minFirst))  = xMaxVals(minFirst);
    yOut(even(minFirst))  = yMaxVals(minFirst);
    xOut(odd(~minFirst))  = xMaxVals(~minFirst);
    yOut(odd(~minFirst))  = yMaxVals(~minFirst);
    xOut(even(~minFirst)) = xMinVals(~minFirst);
    yOut(even(~minFirst)) = yMinVals(~minFirst);
end

function [xOut, yOut] = lttb_core_matlab(x, y, numOut)
    n = numel(x);
    xOut = zeros(1, numOut);
    yOut = zeros(1, numOut);
    xOut(1) = x(1); yOut(1) = y(1);
    xOut(numOut) = x(n); yOut(numOut) = y(n);
    bucketSize = (n - 2) / (numOut - 2);
    prevSelectedIdx = 1;
    for i = 2:numOut-1
        bStart = floor((i-2) * bucketSize) + 2;
        bEnd   = min(floor((i-1) * bucketSize) + 1, n-1);
        nStart = floor((i-1) * bucketSize) + 2;
        nEnd   = min(floor(i * bucketSize) + 1, n-1);
        if nEnd < nStart; nEnd = nStart; end
        avgX = mean(x(nStart:nEnd));
        avgY = mean(y(nStart:nEnd));
        pX = x(prevSelectedIdx);
        pY = y(prevSelectedIdx);
        candidates = bStart:bEnd;
        areas = abs((pX - avgX) .* (y(candidates) - pY) - (pX - x(candidates)) .* (avgY - pY));
        [~, bestLocal] = max(areas);
        bestIdx = candidates(bestLocal);
        xOut(i) = x(bestIdx);
        yOut(i) = y(bestIdx);
        prevSelectedIdx = bestIdx;
    end
end
```

**Step 2: Commit**

```bash
cd FastPlot
git add tests/test_mex_parity.m
git commit -m "Add MEX parity tests

Side-by-side comparison of MEX and MATLAB implementations.
Tests binary_search, minmax_core, and lttb_core at multiple sizes.
Skips gracefully if MEX not compiled."
```

---

## Task 8: MEX Edge Case Tests

**Files:**
- Create: `FastPlot/tests/test_mex_edge_cases.m`

**Step 1: Write test_mex_edge_cases.m**

Create `FastPlot/tests/test_mex_edge_cases.m`:

```matlab
function test_mex_edge_cases()
%TEST_MEX_EDGE_CASES Edge case tests for MEX functions.
%   Skips if MEX files are not compiled.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    has_bs  = (exist('binary_search_mex', 'file') == 3);
    has_mm  = (exist('minmax_core_mex', 'file') == 3);
    has_lt  = (exist('lttb_core_mex', 'file') == 3);

    if ~has_bs && ~has_mm && ~has_lt
        fprintf('    SKIPPED: No MEX files compiled. Run build_mex() first.\n');
        return;
    end

    n_passed = 0;

    % ---- binary_search edge cases ----
    if has_bs
        % Single element
        assert(binary_search_mex([5], 3, 'left') == 1);
        assert(binary_search_mex([5], 7, 'right') == 1);
        assert(binary_search_mex([5], 5, 'left') == 1);
        assert(binary_search_mex([5], 5, 'right') == 1);

        % Two elements
        assert(binary_search_mex([1 10], 5, 'left') == 2);
        assert(binary_search_mex([1 10], 5, 'right') == 1);

        % Exact boundary values
        x = [1 2 3 4 5];
        assert(binary_search_mex(x, 1, 'left') == 1);
        assert(binary_search_mex(x, 5, 'right') == 5);

        % Duplicates
        x = [1 1 1 3 3 3 5 5 5];
        assert(binary_search_mex(x, 1, 'left') == 1);
        assert(binary_search_mex(x, 3, 'left') == 4);
        assert(binary_search_mex(x, 1, 'right') == 3);
        assert(binary_search_mex(x, 3, 'right') == 6);

        fprintf('    binary_search_mex edge cases: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- minmax_core edge cases ----
    if has_mm
        % Minimum size: 2 elements, 1 bucket
        [xo, yo] = minmax_core_mex([1 2], [10 20], 1);
        assert(numel(xo) == 2 && numel(yo) == 2);
        assert(xo(1) == 1 && xo(2) == 2);
        assert(yo(1) == 10 && yo(2) == 20);

        % All same values
        x = 1:100;
        y = ones(1, 100) * 42;
        [~, yo] = minmax_core_mex(x, y, 10);
        assert(all(yo == 42), 'All-same values: expected all 42');

        % Negative values
        x = 1:100;
        y = -50 + (1:100) * 0.1;
        [~, yo] = minmax_core_mex(x, y, 10);
        assert(min(yo) >= -50 && max(yo) <= -40);

        % Large array: 10M points
        n = 1e7;
        x = linspace(0, 100, n);
        y = sin(x);
        [xo, yo] = minmax_core_mex(x, y, 1000);
        assert(numel(xo) == 2000, 'Large: expected 2000 points, got %d', numel(xo));
        assert(max(yo) <= 1.0 + 1e-10 && min(yo) >= -1.0 - 1e-10, ...
            'Large: y values out of sine range');

        % Remainder handling: n not divisible by numBuckets
        x = 1:17;
        y = [5 3 8 1 9 2 7 4 6 10 11 12 13 14 15 16 17];
        [~, yo] = minmax_core_mex(x, y, 3);
        assert(numel(yo) == 6);

        fprintf('    minmax_core_mex edge cases: PASSED\n');
        n_passed = n_passed + 1;
    end

    % ---- lttb_core edge cases ----
    if has_lt
        % Minimum: numOut == 2 (just endpoints)
        [xo, yo] = lttb_core_mex([1 2 3 4 5], [10 20 30 40 50], 2);
        assert(numel(xo) == 2);
        assert(xo(1) == 1 && xo(2) == 5);
        assert(yo(1) == 10 && yo(2) == 50);

        % numOut == 3
        x = 1:10;
        y = [0 0 0 0 10 0 0 0 0 0];
        [xo, yo] = lttb_core_mex(x, y, 3);
        assert(numel(xo) == 3);
        assert(xo(1) == 1 && xo(end) == 10);

        % Monotonic data
        x = 1:1000;
        y = (1:1000) * 0.001;
        [xo, ~] = lttb_core_mex(x, y, 50);
        assert(all(diff(xo) > 0), 'Monotonic X violated');

        % Large array
        n = 1e6;
        x = linspace(0, 100, n);
        y = sin(x);
        [xo, yo] = lttb_core_mex(x, y, 500);
        assert(numel(xo) == 500);
        assert(xo(1) == x(1) && xo(end) == x(end));

        fprintf('    lttb_core_mex edge cases: PASSED\n');
        n_passed = n_passed + 1;
    end

    fprintf('    All %d MEX edge case tests passed.\n', n_passed);
end
```

**Step 2: Commit**

```bash
cd FastPlot
git add tests/test_mex_edge_cases.m
git commit -m "Add MEX edge case tests

Tests single element, minimum size, duplicates, large arrays,
negative values, and remainder handling for all 3 MEX functions."
```

---

## Task 9: Compile, Run All Tests, Update README

**Step 1: Compile MEX files**

```matlab
cd FastPlot
build_mex()
```

Expected: `3/3 MEX files compiled successfully.`

**Step 2: Run full test suite**

```matlab
cd FastPlot
addpath('tests'); addpath('private');
run_all_tests()
```

Expected: All tests pass including new parity and edge case tests.

**Step 3: Update README.md**

Add a "Building MEX (optional)" section after "Requirements" in `README.md`:

```markdown
## Building MEX (optional)

For maximum performance, compile the C MEX accelerators:

```matlab
cd FastPlot
build_mex()
```

Requires a C compiler (Xcode on macOS, GCC on Linux, MSVC on Windows). Uses AVX2/NEON SIMD intrinsics when available.

If MEX files are not compiled, FastPlot automatically uses the pure-MATLAB implementations — no functionality is lost.
```

**Step 4: Add `*.mex*` to .gitignore**

Create or update `FastPlot/.gitignore`:

```
*.mexmaci64
*.mexmaca64
*.mexa64
*.mexw64
.DS_Store
```

**Step 5: Commit**

```bash
cd FastPlot
git add README.md .gitignore
git commit -m "Update README with MEX build instructions, add .gitignore

Documents optional MEX compilation step. Ignores compiled MEX
binaries and .DS_Store files."
```

---

## Task 10: Benchmark MEX vs MATLAB

**Step 1: Run existing benchmark to compare**

```matlab
cd FastPlot/examples
benchmark()
```

Expected: With MEX compiled, FastPlot zoom/downsample times should be noticeably faster, especially for LTTB at large data sizes.

**Step 2: Verify benchmark_zoom still works**

```matlab
cd FastPlot/examples
benchmark_zoom()
```

Expected: Per-frame latencies should improve with MEX. No regressions.

**Step 3: Commit any benchmark adjustments if needed**

No new files expected — this is a validation step.
