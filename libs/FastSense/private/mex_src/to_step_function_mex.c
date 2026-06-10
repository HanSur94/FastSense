/*
 * to_step_function_mex.c — SIMD-accelerated segment-to-step-function conversion.
 *
 * [stepX, stepY] = to_step_function_mex(segBounds, values, dataEnd)
 *
 *   segBounds — 1xS double, segment boundary timestamps
 *   values    — 1xS double, threshold value at each boundary (NaN = inactive)
 *   dataEnd   — scalar double, end-of-data timestamp (right edge of last seg)
 *
 *   Returns:
 *     stepX — 1xP double, X coordinates for step-function plotting
 *     stepY — 1xP double, Y coordinates for step-function plotting
 *
 * Algorithm:
 *   Phase 1: SIMD NaN scan — detect active segments in SIMD_WIDTH chunks
 *            via compare intrinsics (NaN lanes compare unequal to
 *            themselves).  Branchless conditional store builds the
 *            active index array.
 *
 *   FAST-MATH CONSTRAINT (260610-nwa): this kernel MUST be compiled with
 *   NaN semantics intact (-fno-finite-math-only after -ffast-math —
 *   build_mex.m sets this). Under plain -ffast-math the compiler assumes
 *   no NaNs and folds self-compares — including clang's IR lowering of
 *   the compare intrinsics — making every NaN segment scan as active.
 *   Scalar tails use mxIsNaN (an opaque libmx call) so they survive any
 *   fast-math mode, including MSVC /fp:fast.
 *   Phase 2: SIMD bulk copy to compute segEnds (shifted segBounds).
 *   Phase 3: SIMD gap detection — gather prevEnd/currStart pairs and
 *            compare in SIMD_WIDTH-wide batches.
 *   Phase 4: Single-pass output fill with branchless NaN insertion,
 *            then SIMD memcpy to trim output to exact size.
 *
 *   Pre-allocates output to worst-case size (3*nActive) and trims once.
 *   No dynamic allocation or reallocation inside the hot loops.
 */

#include "mex.h"
#include "simd_utils.h"
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

/* ================================================================
 * Phase 1: SIMD NaN scan — count active segments and collect indices.
 *
 * NaN detection: IEEE 754 guarantees NaN != NaN.  We compare each
 * value against itself; non-NaN lanes are true, NaN lanes are false.
 *
 * AVX2: _mm256_cmp_pd(v, v, _CMP_EQ_OQ) produces a bitmask we can
 *       extract with _mm256_movemask_pd.  Each bit = one lane.
 * SSE2: _mm_cmpeq_pd + _mm_movemask_pd, 2 lanes per vector.
 * NEON: vceqq_f64 + lane extraction, 2 lanes per vector.
 * Scalar: plain isnan().
 *
 * Branchless index collection: always write the index, advance the
 * count by the NaN-test result (0 or 1).  Eliminates branch
 * misprediction when active/inactive segments are interleaved.
 * ================================================================ */

#if defined(__AVX2__)

#include <immintrin.h>

/* Returns number of active segments found. activeIdx filled in. */
static size_t simd_nan_scan(const double *values, size_t nB,
                            uint32_t *activeIdx)
{
    size_t cnt = 0;
    size_t i = 0;
    size_t simdEnd = (nB / 4) * 4;

    for (; i < simdEnd; i += 4) {
        __m256d v = _mm256_loadu_pd(&values[i]);
        /* NaN != NaN, so v == v is true for non-NaN */
        __m256d cmp = _mm256_cmp_pd(v, v, _CMP_EQ_OQ);
        int mask = _mm256_movemask_pd(cmp);

        if (mask == 0) continue; /* All NaN — skip */

        /* Branchless: always write, conditionally advance */
        activeIdx[cnt] = (uint32_t)(i + 0); cnt += (mask >> 0) & 1;
        activeIdx[cnt] = (uint32_t)(i + 1); cnt += (mask >> 1) & 1;
        activeIdx[cnt] = (uint32_t)(i + 2); cnt += (mask >> 2) & 1;
        activeIdx[cnt] = (uint32_t)(i + 3); cnt += (mask >> 3) & 1;
    }
    /* Scalar tail */
    for (; i < nB; i++) {
        activeIdx[cnt] = (uint32_t)i;
        cnt += (size_t)(!mxIsNaN(values[i])); /* opaque call: survives fast-math */
    }
    return cnt;
}

/* SIMD gap detection: compare prevEnds[i] != currStarts[i] */
static void simd_gap_detect(const double *prevEnds, const double *currStarts,
                            int *isGap, size_t n)
{
    size_t i = 0;
    size_t simdEnd = (n / 4) * 4;

    for (; i < simdEnd; i += 4) {
        __m256d vp = _mm256_loadu_pd(&prevEnds[i]);
        __m256d vc = _mm256_loadu_pd(&currStarts[i]);
        __m256d eq = _mm256_cmp_pd(vp, vc, _CMP_NEQ_OQ);
        int mask = _mm256_movemask_pd(eq);
        isGap[i + 0] = (mask >> 0) & 1;
        isGap[i + 1] = (mask >> 1) & 1;
        isGap[i + 2] = (mask >> 2) & 1;
        isGap[i + 3] = (mask >> 3) & 1;
    }
    for (; i < n; i++) {
        isGap[i] = (prevEnds[i] != currStarts[i]);
    }
}

/* SIMD bulk copy (used for segEnds shift and output trim) */
static void simd_copy(double *dst, const double *src, size_t n)
{
    size_t i = 0;
    size_t simdEnd = (n / 4) * 4;
    for (; i < simdEnd; i += 4) {
        _mm256_storeu_pd(&dst[i], _mm256_loadu_pd(&src[i]));
    }
    for (; i < n; i++) {
        dst[i] = src[i];
    }
}

#elif defined(__SSE2__) || defined(_M_AMD64) || defined(_M_X64)

#include <emmintrin.h>

static size_t simd_nan_scan(const double *values, size_t nB,
                            uint32_t *activeIdx)
{
    size_t cnt = 0;
    size_t i = 0;
    size_t simdEnd = (nB / 2) * 2;

    for (; i < simdEnd; i += 2) {
        __m128d v = _mm_loadu_pd(&values[i]);
        __m128d cmp = _mm_cmpeq_pd(v, v);
        int mask = _mm_movemask_pd(cmp);

        if (mask == 0) continue;

        activeIdx[cnt] = (uint32_t)(i + 0); cnt += (mask >> 0) & 1;
        activeIdx[cnt] = (uint32_t)(i + 1); cnt += (mask >> 1) & 1;
    }
    for (; i < nB; i++) {
        activeIdx[cnt] = (uint32_t)i;
        cnt += (size_t)(!mxIsNaN(values[i]));
    }
    return cnt;
}

static void simd_gap_detect(const double *prevEnds, const double *currStarts,
                            int *isGap, size_t n)
{
    size_t i = 0;
    size_t simdEnd = (n / 2) * 2;

    for (; i < simdEnd; i += 2) {
        __m128d vp = _mm_loadu_pd(&prevEnds[i]);
        __m128d vc = _mm_loadu_pd(&currStarts[i]);
        __m128d eq = _mm_cmpeq_pd(vp, vc);
        int mask = _mm_movemask_pd(eq);
        /* eq mask: bit=1 means EQUAL, we want isGap = NOT equal */
        isGap[i + 0] = !((mask >> 0) & 1);
        isGap[i + 1] = !((mask >> 1) & 1);
    }
    for (; i < n; i++) {
        isGap[i] = (prevEnds[i] != currStarts[i]);
    }
}

static void simd_copy(double *dst, const double *src, size_t n)
{
    size_t i = 0;
    size_t simdEnd = (n / 2) * 2;
    for (; i < simdEnd; i += 2) {
        _mm_storeu_pd(&dst[i], _mm_loadu_pd(&src[i]));
    }
    for (; i < n; i++) {
        dst[i] = src[i];
    }
}

#elif defined(__ARM_NEON) || defined(__aarch64__)

#include <arm_neon.h>

static size_t simd_nan_scan(const double *values, size_t nB,
                            uint32_t *activeIdx)
{
    size_t cnt = 0;
    size_t i = 0;
    size_t simdEnd = (nB / 2) * 2;

    for (; i < simdEnd; i += 2) {
        float64x2_t v = vld1q_f64(&values[i]);
        /* NaN != NaN: vceqq_f64(v, v) gives 0xFFFF... for non-NaN */
        uint64x2_t cmp = vceqq_f64(v, v);
        uint64_t lane0 = vgetq_lane_u64(cmp, 0);
        uint64_t lane1 = vgetq_lane_u64(cmp, 1);

        if ((lane0 | lane1) == 0) continue;

        activeIdx[cnt] = (uint32_t)(i + 0); cnt += (lane0 != 0);
        activeIdx[cnt] = (uint32_t)(i + 1); cnt += (lane1 != 0);
    }
    for (; i < nB; i++) {
        activeIdx[cnt] = (uint32_t)i;
        cnt += (size_t)(!mxIsNaN(values[i]));
    }
    return cnt;
}

static void simd_gap_detect(const double *prevEnds, const double *currStarts,
                            int *isGap, size_t n)
{
    size_t i = 0;
    size_t simdEnd = (n / 2) * 2;

    for (; i < simdEnd; i += 2) {
        float64x2_t vp = vld1q_f64(&prevEnds[i]);
        float64x2_t vc = vld1q_f64(&currStarts[i]);
        uint64x2_t eq = vceqq_f64(vp, vc);
        /* isGap = NOT equal */
        isGap[i + 0] = (vgetq_lane_u64(eq, 0) == 0);
        isGap[i + 1] = (vgetq_lane_u64(eq, 1) == 0);
    }
    for (; i < n; i++) {
        isGap[i] = (prevEnds[i] != currStarts[i]);
    }
}

static void simd_copy(double *dst, const double *src, size_t n)
{
    size_t i = 0;
    size_t simdEnd = (n / 2) * 2;
    for (; i < simdEnd; i += 2) {
        vst1q_f64(&dst[i], vld1q_f64(&src[i]));
    }
    for (; i < n; i++) {
        dst[i] = src[i];
    }
}

#else
/* ============================================================
 * Scalar fallback
 * ============================================================ */

static size_t simd_nan_scan(const double *values, size_t nB,
                            uint32_t *activeIdx)
{
    size_t cnt = 0;
    size_t i;
    for (i = 0; i < nB; i++) {
        activeIdx[cnt] = (uint32_t)i;
        cnt += (size_t)(!mxIsNaN(values[i]));
    }
    return cnt;
}

static void simd_gap_detect(const double *prevEnds, const double *currStarts,
                            int *isGap, size_t n)
{
    size_t i;
    for (i = 0; i < n; i++) {
        isGap[i] = (prevEnds[i] != currStarts[i]);
    }
}

static void simd_copy(double *dst, const double *src, size_t n)
{
    memcpy(dst, src, n * sizeof(double));
}

#endif


void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    const double *segBounds, *values;
    double dataEnd;
    size_t nB, nActive;
    uint32_t *activeIdx;
    double *segEnds;
    double *prevEnds_buf, *currStarts_buf;
    int *isGap;
    double *outX, *outY, *stepX, *stepY;
    size_t pos, a, maxLen;
    uint32_t k;

    if (nrhs != 3) {
        mexErrMsgIdAndTxt("FastSense:to_step_function_mex:nrhs",
            "Three inputs required: segBounds, values, dataEnd.");
    }

    segBounds = mxGetPr(prhs[0]);
    values    = mxGetPr(prhs[1]);
    dataEnd   = mxGetScalar(prhs[2]);
    nB        = mxGetNumberOfElements(prhs[0]);

    /* --------------------------------------------------------
     * Phase 1: SIMD NaN scan — find active segment indices
     * -------------------------------------------------------- */
    activeIdx = (uint32_t *)mxMalloc(nB * sizeof(uint32_t));
    nActive = simd_nan_scan(values, nB, activeIdx);

    if (nActive == 0) {
        plhs[0] = mxCreateDoubleMatrix(1, 0, mxREAL);
        if (nlhs > 1) plhs[1] = mxCreateDoubleMatrix(1, 0, mxREAL);
        mxFree(activeIdx);
        return;
    }

    /* --------------------------------------------------------
     * Phase 2: SIMD bulk copy to build segEnds
     *   segEnds[i] = segBounds[i+1] for i < nB-1
     *   segEnds[nB-1] = dataEnd
     * -------------------------------------------------------- */
    segEnds = (double *)mxMalloc(nB * sizeof(double));
    if (nB > 1) {
        simd_copy(segEnds, &segBounds[1], nB - 1);
    }
    segEnds[nB - 1] = dataEnd;

    /* Fast path: single active segment */
    if (nActive == 1) {
        k = activeIdx[0];
        plhs[0] = mxCreateDoubleMatrix(1, 2, mxREAL);
        stepX = mxGetPr(plhs[0]);
        stepX[0] = segBounds[k];
        stepX[1] = segEnds[k];
        if (nlhs > 1) {
            plhs[1] = mxCreateDoubleMatrix(1, 2, mxREAL);
            stepY = mxGetPr(plhs[1]);
            stepY[0] = values[k];
            stepY[1] = values[k];
        }
        mxFree(activeIdx);
        mxFree(segEnds);
        return;
    }

    /* --------------------------------------------------------
     * Phase 3: SIMD gap detection
     *   Gather prevEnds and currStarts into contiguous buffers
     *   for SIMD-friendly comparison.
     * -------------------------------------------------------- */
    {
        size_t nGaps = nActive - 1;

        prevEnds_buf   = (double *)mxMalloc(nGaps * sizeof(double));
        currStarts_buf = (double *)mxMalloc(nGaps * sizeof(double));
        isGap          = (int *)mxMalloc(nGaps * sizeof(int));

        /* Gather: collect the values we need to compare into packed arrays */
        for (a = 0; a < nGaps; a++) {
            prevEnds_buf[a]   = segEnds[activeIdx[a]];
            currStarts_buf[a] = segBounds[activeIdx[a + 1]];
        }

        /* SIMD compare */
        simd_gap_detect(prevEnds_buf, currStarts_buf, isGap, nGaps);

        mxFree(prevEnds_buf);
        mxFree(currStarts_buf);
    }

    /* --------------------------------------------------------
     * Phase 4: Single-pass output fill
     *   Each active segment emits 2 points.
     *   Each gap emits 1 NaN separator (3 points total for that segment).
     *   Worst case: 3*nActive.
     * -------------------------------------------------------- */
    maxLen = 3 * nActive;
    outX = (double *)mxMalloc(maxLen * sizeof(double));
    outY = (double *)mxMalloc(maxLen * sizeof(double));

    pos = 0;

    /* First active segment */
    k = activeIdx[0];
    outX[pos] = segBounds[k]; outY[pos] = values[k]; pos++;
    outX[pos] = segEnds[k];   outY[pos] = values[k]; pos++;

    {
        double nanVal = mxGetNaN();
        for (a = 1; a < nActive; a++) {
            k = activeIdx[a];
            if (isGap[a - 1]) {
                outX[pos] = nanVal;       outY[pos] = nanVal;     pos++;
                outX[pos] = segBounds[k]; outY[pos] = values[k];  pos++;
                outX[pos] = segEnds[k];   outY[pos] = values[k];  pos++;
            } else {
                outX[pos] = segBounds[k]; outY[pos] = values[k];  pos++;
                outX[pos] = segEnds[k];   outY[pos] = values[k];  pos++;
            }
        }
    }

    /* --------------------------------------------------------
     * Phase 5: SIMD copy to exact-sized output arrays
     * -------------------------------------------------------- */
    plhs[0] = mxCreateDoubleMatrix(1, pos, mxREAL);
    stepX = mxGetPr(plhs[0]);
    simd_copy(stepX, outX, pos);

    if (nlhs > 1) {
        plhs[1] = mxCreateDoubleMatrix(1, pos, mxREAL);
        stepY = mxGetPr(plhs[1]);
        simd_copy(stepY, outY, pos);
    }

    mxFree(outX);
    mxFree(outY);
    mxFree(isGap);
    mxFree(activeIdx);
    mxFree(segEnds);
}
