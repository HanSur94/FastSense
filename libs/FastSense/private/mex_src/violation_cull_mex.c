/*
 * violation_cull_mex.c — Fused SIMD violation detection + pixel-density culling.
 *
 * [xOut, yOut] = violation_cull_mex(x, y, thX, thY, direction, pixelWidth, xmin)
 *
 *   x, y          — 1xN double data arrays
 *   thX, thY      — 1xK double threshold step-function knots (sorted)
 *   direction      — double: 1=upper (y > th), 0=lower (y < th)
 *   pixelWidth     — double: X-axis span per pixel
 *   xmin           — double: left edge of view (bucket anchor)
 *
 *   Returns xOut, yOut — culled violation points (at most 1 per pixel column).
 *
 * Algorithm:
 *   1. Walk data. For each x[i], find threshold via running cursor on thX.
 *   2. Test y[i] against threshold. If violation, compute pixel bucket.
 *   3. Track per-bucket best (max |y - th| deviation).
 *   4. Emit non-empty buckets.
 *
 * SIMD: vectorized comparison for scalar thresholds (K=1).
 */

#include "mex.h"
#include "simd_utils.h"
#include <math.h>
#include <string.h>
#include <stdlib.h>

/* Per-bucket tracking */
typedef struct {
    double bestX;
    double bestY;
    double bestDev;
    int    occupied;
} Bucket;

/* Step-function lookup: find rightmost thX[j] <= xVal.
 * Uses running cursor (cursor) for amortized O(1) on sorted data. */
static inline size_t step_lookup(const double *thX, size_t nKnots,
                                  double xVal, size_t cursor) {
    /* Advance cursor forward while next knot <= xVal */
    while (cursor + 1 < nKnots && thX[cursor + 1] <= xVal) {
        cursor++;
    }
    return cursor;
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    if (nrhs != 7) {
        mexErrMsgIdAndTxt("FastSense:violation_cull_mex:nrhs",
            "Seven inputs required: x, y, thX, thY, direction, pixelWidth, xmin.");
    }

    const double *x    = mxGetPr(prhs[0]);
    const double *y    = mxGetPr(prhs[1]);
    const size_t N     = mxGetNumberOfElements(prhs[0]);
    const double *thX  = mxGetPr(prhs[2]);
    const double *thY  = mxGetPr(prhs[3]);
    const size_t nKnots = mxGetNumberOfElements(prhs[2]);
    const int isUpper  = (mxGetScalar(prhs[4]) != 0.0);
    const double pw    = mxGetScalar(prhs[5]);
    const double xmin  = mxGetScalar(prhs[6]);

    if (N == 0 || pw <= 0.0) {
        plhs[0] = mxCreateDoubleMatrix(1, 0, mxREAL);
        plhs[1] = mxCreateDoubleMatrix(1, 0, mxREAL);
        return;
    }

    /* Allocate bucket array — upper bound on number of pixel columns */
    double xSpan = x[N-1] - xmin;
    size_t maxBuckets = (size_t)(xSpan / pw) + 2;
    if (maxBuckets > 8192) maxBuckets = 8192;  /* safety cap */

    Bucket *buckets = (Bucket *)mxCalloc(maxBuckets, sizeof(Bucket));
    size_t nOccupied = 0;

    /* === Scalar threshold fast path (K=1): SIMD vectorized === */
    if (nKnots == 1) {
        double th = thY[0];
        double invPw = 1.0 / pw;

#if SIMD_WIDTH > 1
        simd_double vth = simd_set1(th);
        simd_double vxmin = simd_set1(xmin);
        simd_double vinvpw = simd_set1(invPw);
        size_t simd_end = (N / SIMD_WIDTH) * SIMD_WIDTH;

        double xBuf[SIMD_WIDTH], yBuf[SIMD_WIDTH];
        size_t i;

        for (i = 0; i < simd_end; i += SIMD_WIDTH) {
            simd_double vy = simd_load(&y[i]);
            simd_double vx = simd_load(&x[i]);

            /* Store to buffers for scalar violation + bucket logic */
            simd_store(yBuf, vy);
            simd_store(xBuf, vx);

            size_t j;
            for (j = 0; j < SIMD_WIDTH; j++) {
                double yi = yBuf[j];
                double xi = xBuf[j];
                int violated;
                double dev;

                if (mxIsNaN(yi)) continue;  /* NaN check */

                if (isUpper) violated = (yi > th);
                else         violated = (yi < th);

                if (!violated) continue;

                dev = fabs(yi - th);
                long bIdx = (long)((xi - xmin) * invPw);
                if (bIdx < 0) bIdx = 0;
                if ((size_t)bIdx >= maxBuckets) bIdx = (long)(maxBuckets - 1);

                if (!buckets[bIdx].occupied) {
                    buckets[bIdx].bestX = xi;
                    buckets[bIdx].bestY = yi;
                    buckets[bIdx].bestDev = dev;
                    buckets[bIdx].occupied = 1;
                    nOccupied++;
                } else if (dev > buckets[bIdx].bestDev) {
                    buckets[bIdx].bestX = xi;
                    buckets[bIdx].bestY = yi;
                    buckets[bIdx].bestDev = dev;
                }
            }
        }

        /* Scalar tail */
        for (; i < N; i++) {
#else
        size_t i;
        for (i = 0; i < N; i++) {
#endif
            double yi = y[i];
            double xi = x[i];
            double dev;
            int violated;

            if (mxIsNaN(yi)) continue;

            if (isUpper) violated = (yi > th);
            else         violated = (yi < th);

            if (!violated) continue;

            dev = fabs(yi - th);
            long bIdx = (long)((xi - xmin) * invPw);
            if (bIdx < 0) bIdx = 0;
            if ((size_t)bIdx >= maxBuckets) bIdx = (long)(maxBuckets - 1);

            if (!buckets[bIdx].occupied) {
                buckets[bIdx].bestX = xi;
                buckets[bIdx].bestY = yi;
                buckets[bIdx].bestDev = dev;
                buckets[bIdx].occupied = 1;
                nOccupied++;
            } else if (dev > buckets[bIdx].bestDev) {
                buckets[bIdx].bestX = xi;
                buckets[bIdx].bestY = yi;
                buckets[bIdx].bestDev = dev;
            }
        }
#if SIMD_WIDTH > 1
        /* close the outer for-loop's else from scalar tail */
#endif

    } else {
        /* === Time-varying threshold: running cursor === */
        size_t cursor = 0;
        double invPw = 1.0 / pw;
        size_t i;

        for (i = 0; i < N; i++) {
            double xi = x[i];
            double yi = y[i];
            double dev;
            int violated;

            if (mxIsNaN(yi)) continue;  /* NaN */

            /* Advance cursor to find active threshold */
            cursor = step_lookup(thX, nKnots, xi, cursor);
            double th = thY[cursor];

            if (isUpper) violated = (yi > th);
            else         violated = (yi < th);

            if (!violated) continue;

            dev = fabs(yi - th);
            long bIdx = (long)((xi - xmin) * invPw);
            if (bIdx < 0) bIdx = 0;
            if ((size_t)bIdx >= maxBuckets) bIdx = (long)(maxBuckets - 1);

            if (!buckets[bIdx].occupied) {
                buckets[bIdx].bestX = xi;
                buckets[bIdx].bestY = yi;
                buckets[bIdx].bestDev = dev;
                buckets[bIdx].occupied = 1;
                nOccupied++;
            } else if (dev > buckets[bIdx].bestDev) {
                buckets[bIdx].bestX = xi;
                buckets[bIdx].bestY = yi;
                buckets[bIdx].bestDev = dev;
            }
        }
    }

    /* === Emit results === */
    plhs[0] = mxCreateDoubleMatrix(1, nOccupied, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, nOccupied, mxREAL);
    double *xOut = mxGetPr(plhs[0]);
    double *yOut = mxGetPr(plhs[1]);

    size_t outIdx = 0;
    size_t b;
    for (b = 0; b < maxBuckets; b++) {
        if (buckets[b].occupied) {
            xOut[outIdx] = buckets[b].bestX;
            yOut[outIdx] = buckets[b].bestY;
            outIdx++;
        }
    }

    mxFree(buckets);
}
