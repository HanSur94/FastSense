/*
 * compute_violations_mex.c — SIMD-accelerated batch violation detection.
 *
 * batchViolIdx = compute_violations_mex(sensorY, segLo, segHi,
 *                                       thresholdValues, directions)
 *
 *   sensorY         — 1xN double, full sensor Y data
 *   segLo           — 1xS double, start indices of active segments (1-based)
 *   segHi           — 1xS double, end indices of active segments (1-based)
 *   thresholdValues — 1xT double, threshold value per rule
 *   directions      — 1xT double, 1=upper (y>th), 0=lower (y<th)
 *
 *   Returns: 1xT cell array of 1xK double violation index vectors (1-based).
 *
 * Algorithm:
 *   Single pass over segments.  For each segment chunk, check all thresholds.
 *   SIMD vectorization for the inner comparison loop on each chunk.
 *   Pre-allocates output buffers sized to total active points (upper bound).
 */

#include "mex.h"
#include "simd_utils.h"
#include <string.h>
#include <stdlib.h>

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("FastPlot:compute_violations_mex:nrhs",
            "Five inputs required: sensorY, segLo, segHi, thresholdValues, directions.");
    }

    const double *sensorY = mxGetPr(prhs[0]);
    const size_t  N       = mxGetNumberOfElements(prhs[0]);
    const double *segLoD  = mxGetPr(prhs[1]);
    const double *segHiD  = mxGetPr(prhs[2]);
    const size_t  nSegs   = mxGetNumberOfElements(prhs[1]);
    const double *thVals  = mxGetPr(prhs[3]);
    const double *dirD    = mxGetPr(prhs[4]);
    const size_t  nTh     = mxGetNumberOfElements(prhs[3]);

    /* Create output cell array */
    plhs[0] = mxCreateCellMatrix(1, nTh);

    if (nTh == 0 || nSegs == 0) {
        size_t t;
        for (t = 0; t < nTh; t++) {
            mxSetCell(plhs[0], t, mxCreateDoubleMatrix(1, 0, mxREAL));
        }
        return;
    }

    /* Compute total active points (upper bound for buffer allocation) */
    size_t totalPoints = 0;
    size_t s;
    for (s = 0; s < nSegs; s++) {
        size_t lo = (size_t)segLoD[s];
        size_t hi = (size_t)segHiD[s];
        totalPoints += (hi - lo + 1);
    }

    /* Allocate output buffers: one per threshold */
    double **buffers = (double **)mxMalloc(nTh * sizeof(double *));
    size_t *counts   = (size_t *)mxCalloc(nTh, sizeof(size_t));
    size_t t;
    for (t = 0; t < nTh; t++) {
        buffers[t] = (double *)mxMalloc(totalPoints * sizeof(double));
    }

    /* Parse directions into integer flags */
    int *isUpper = (int *)mxMalloc(nTh * sizeof(int));
    for (t = 0; t < nTh; t++) {
        isUpper[t] = (dirD[t] != 0.0);
    }

    /* === Main loop: iterate segments once, check all thresholds per chunk === */
    for (s = 0; s < nSegs; s++) {
        size_t lo = (size_t)segLoD[s] - 1;  /* Convert to 0-based */
        size_t hi = (size_t)segHiD[s] - 1;
        size_t chunkLen = hi - lo + 1;
        const double *chunk = &sensorY[lo];

        for (t = 0; t < nTh; t++) {
            double thVal = thVals[t];
            int upper = isUpper[t];
            double *buf = buffers[t];
            size_t cnt = counts[t];

#if SIMD_WIDTH > 1
            /* SIMD vectorized comparison */
            simd_double vth = simd_set1(thVal);
            size_t simdEnd = (chunkLen / SIMD_WIDTH) * SIMD_WIDTH;
            size_t i;

            if (upper) {
                for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
                    simd_double vy = simd_load(&chunk[i]);
                    /* Check if any element exceeds threshold.
                     * Use hmax to quickly skip SIMD blocks with no violations. */
                    double maxVal = simd_hmax(vy);
                    if (maxVal > thVal) {
                        /* At least one violation — check individually */
                        double yBuf[SIMD_WIDTH];
                        simd_store(yBuf, vy);
                        size_t j;
                        for (j = 0; j < SIMD_WIDTH; j++) {
                            if (yBuf[j] > thVal) {
                                buf[cnt++] = (double)(lo + i + j + 1); /* 1-based */
                            }
                        }
                    }
                }
                /* Scalar tail */
                for (; i < chunkLen; i++) {
                    if (chunk[i] > thVal) {
                        buf[cnt++] = (double)(lo + i + 1);
                    }
                }
            } else {
                for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
                    simd_double vy = simd_load(&chunk[i]);
                    double minVal = simd_hmin(vy);
                    if (minVal < thVal) {
                        double yBuf[SIMD_WIDTH];
                        simd_store(yBuf, vy);
                        size_t j;
                        for (j = 0; j < SIMD_WIDTH; j++) {
                            if (yBuf[j] < thVal) {
                                buf[cnt++] = (double)(lo + i + j + 1);
                            }
                        }
                    }
                }
                for (; i < chunkLen; i++) {
                    if (chunk[i] < thVal) {
                        buf[cnt++] = (double)(lo + i + 1);
                    }
                }
            }
#else
            /* Scalar fallback */
            size_t i;
            if (upper) {
                for (i = 0; i < chunkLen; i++) {
                    if (chunk[i] > thVal) {
                        buf[cnt++] = (double)(lo + i + 1);
                    }
                }
            } else {
                for (i = 0; i < chunkLen; i++) {
                    if (chunk[i] < thVal) {
                        buf[cnt++] = (double)(lo + i + 1);
                    }
                }
            }
#endif
            counts[t] = cnt;
        }
    }

    /* === Package results into cell array === */
    for (t = 0; t < nTh; t++) {
        mxArray *out = mxCreateDoubleMatrix(1, counts[t], mxREAL);
        if (counts[t] > 0) {
            memcpy(mxGetPr(out), buffers[t], counts[t] * sizeof(double));
        }
        mxSetCell(plhs[0], t, out);
        mxFree(buffers[t]);
    }

    mxFree(buffers);
    mxFree(counts);
    mxFree(isUpper);
}
