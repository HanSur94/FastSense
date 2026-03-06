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
