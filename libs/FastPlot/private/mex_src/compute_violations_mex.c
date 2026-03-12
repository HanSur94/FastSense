/*
 * compute_violations_mex.c — SIMD-accelerated batch violation detection.
 *
 * [batchViolX, batchViolY] = compute_violations_mex(sensorX, sensorY,
 *                                segLo, segHi, thresholdValues, directions)
 *
 *   sensorX         — 1xN double, full sensor X data (timestamps)
 *   sensorY         — 1xN double, full sensor Y data (values)
 *   segLo           — 1xS double, start indices of active segments (1-based)
 *   segHi           — 1xS double, end indices of active segments (1-based)
 *   thresholdValues — 1xT double, threshold value per rule
 *   directions      — 1xT double, 1=upper (y>th), 0=lower (y<th)
 *
 *   Returns:
 *     batchViolX — 1xT cell array of 1xK double violation X vectors
 *     batchViolY — 1xT cell array of 1xK double violation Y vectors
 *
 *   When called with 5 inputs (legacy mode, no sensorX), returns indices:
 *     batchViolIdx — 1xT cell array of 1xK double violation index vectors
 *
 * Algorithm:
 *   Phase 1: Single pass over segments collecting violation indices into
 *            compact uint32 buffers (4 bytes each).  Uses branchless
 *            conditional stores to eliminate branch misprediction at
 *            high violation rates (~50%).  SIMD early-exit skips chunks
 *            with zero violations entirely.
 *   Phase 2: Create correctly-sized output mxArrays and extract X/Y
 *            via sequential gather from the index buffers.
 */

#include "mex.h"
#include "simd_utils.h"
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    int xyMode;
    const double *sensorX;
    const double *sensorY;
    const double *segLoD, *segHiD, *thVals, *dirD;
    size_t N, nSegs, nTh;

    if (nrhs == 6) {
        xyMode = 1;
        sensorX = mxGetPr(prhs[0]);
        sensorY = mxGetPr(prhs[1]);
        N       = mxGetNumberOfElements(prhs[0]);
        segLoD  = mxGetPr(prhs[2]);
        segHiD  = mxGetPr(prhs[3]);
        nSegs   = mxGetNumberOfElements(prhs[2]);
        thVals  = mxGetPr(prhs[4]);
        dirD    = mxGetPr(prhs[5]);
        nTh     = mxGetNumberOfElements(prhs[4]);
    } else if (nrhs == 5) {
        xyMode = 0;
        sensorX = NULL;
        sensorY = mxGetPr(prhs[0]);
        N       = mxGetNumberOfElements(prhs[0]);
        segLoD  = mxGetPr(prhs[1]);
        segHiD  = mxGetPr(prhs[2]);
        nSegs   = mxGetNumberOfElements(prhs[1]);
        thVals  = mxGetPr(prhs[3]);
        dirD    = mxGetPr(prhs[4]);
        nTh     = mxGetNumberOfElements(prhs[3]);
    } else {
        mexErrMsgIdAndTxt("FastPlot:compute_violations_mex:nrhs",
            "Five or six inputs required.");
    }

    plhs[0] = mxCreateCellMatrix(1, nTh);
    if (xyMode && nlhs > 1) {
        plhs[1] = mxCreateCellMatrix(1, nTh);
    }

    if (nTh == 0 || nSegs == 0) {
        size_t t;
        for (t = 0; t < nTh; t++) {
            mxSetCell(plhs[0], t, mxCreateDoubleMatrix(1, 0, mxREAL));
            if (xyMode && nlhs > 1)
                mxSetCell(plhs[1], t, mxCreateDoubleMatrix(1, 0, mxREAL));
        }
        return;
    }

    /* Compute total active points */
    size_t totalPoints = 0;
    size_t s;
    for (s = 0; s < nSegs; s++) {
        totalPoints += (size_t)segHiD[s] - (size_t)segLoD[s] + 1;
    }

    int *isUpper = (int *)mxMalloc(nTh * sizeof(int));
    size_t t;
    for (t = 0; t < nTh; t++) {
        isUpper[t] = (dirD[t] != 0.0);
    }

    /*
     * Phase 1: Collect violation indices into compact uint32 buffers.
     * Branchless inner loop: always write index, advance count by 0 or 1.
     * This eliminates branch misprediction which dominates at ~50% violation
     * rates.  The unconditional write is harmless — it gets overwritten next
     * iteration if the condition was false.
     */
    uint32_t **idxBufs = (uint32_t **)mxMalloc(nTh * sizeof(uint32_t *));
    size_t *counts = (size_t *)mxCalloc(nTh, sizeof(size_t));

    for (t = 0; t < nTh; t++) {
        idxBufs[t] = (uint32_t *)mxMalloc(totalPoints * sizeof(uint32_t));
    }

    for (s = 0; s < nSegs; s++) {
        size_t lo = (size_t)segLoD[s] - 1;
        size_t hi = (size_t)segHiD[s] - 1;
        size_t chunkLen = hi - lo + 1;
        const double *chunkY = &sensorY[lo];

        for (t = 0; t < nTh; t++) {
            double thVal = thVals[t];
            int upper = isUpper[t];
            uint32_t *idxBuf = idxBufs[t];
            size_t cnt = counts[t];
            size_t i;

#if SIMD_WIDTH > 1
            simd_double vth = simd_set1(thVal);
            size_t simdEnd = (chunkLen / SIMD_WIDTH) * SIMD_WIDTH;

            if (upper) {
                for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
                    simd_double vy = simd_load(&chunkY[i]);
                    /* Early exit: skip SIMD lane if no violations */
                    if (simd_hmax(vy) > thVal) {
                        double yBuf[SIMD_WIDTH];
                        simd_store(yBuf, vy);
                        size_t j;
                        for (j = 0; j < SIMD_WIDTH; j++) {
                            /* Branchless: always write, conditionally advance */
                            idxBuf[cnt] = (uint32_t)(lo + i + j);
                            cnt += (yBuf[j] > thVal);
                        }
                    }
                }
                for (; i < chunkLen; i++) {
                    idxBuf[cnt] = (uint32_t)(lo + i);
                    cnt += (chunkY[i] > thVal);
                }
            } else {
                for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
                    simd_double vy = simd_load(&chunkY[i]);
                    if (simd_hmin(vy) < thVal) {
                        double yBuf[SIMD_WIDTH];
                        simd_store(yBuf, vy);
                        size_t j;
                        for (j = 0; j < SIMD_WIDTH; j++) {
                            idxBuf[cnt] = (uint32_t)(lo + i + j);
                            cnt += (yBuf[j] < thVal);
                        }
                    }
                }
                for (; i < chunkLen; i++) {
                    idxBuf[cnt] = (uint32_t)(lo + i);
                    cnt += (chunkY[i] < thVal);
                }
            }
#else
            /* Scalar branchless fallback */
            if (upper) {
                for (i = 0; i < chunkLen; i++) {
                    idxBuf[cnt] = (uint32_t)(lo + i);
                    cnt += (chunkY[i] > thVal);
                }
            } else {
                for (i = 0; i < chunkLen; i++) {
                    idxBuf[cnt] = (uint32_t)(lo + i);
                    cnt += (chunkY[i] < thVal);
                }
            }
#endif
            counts[t] = cnt;
        }
    }

    /*
     * Phase 2: Create correctly-sized output arrays and gather X/Y.
     * Indices are monotonically increasing (segments processed left-to-right),
     * so the gather is nearly sequential through sensorX/sensorY.
     */
    for (t = 0; t < nTh; t++) {
        size_t cnt = counts[t];
        uint32_t *idxBuf = idxBufs[t];

        if (xyMode) {
            mxArray *arrX = mxCreateDoubleMatrix(1, cnt, mxREAL);
            double *outX = mxGetPr(arrX);

            if (nlhs > 1) {
                mxArray *arrY = mxCreateDoubleMatrix(1, cnt, mxREAL);
                double *outY = mxGetPr(arrY);
                size_t k;
                for (k = 0; k < cnt; k++) {
                    uint32_t idx = idxBuf[k];
                    outX[k] = sensorX[idx];
                    outY[k] = sensorY[idx];
                }
                mxSetCell(plhs[1], t, arrY);
            } else {
                size_t k;
                for (k = 0; k < cnt; k++) {
                    outX[k] = sensorX[idxBuf[k]];
                }
            }
            mxSetCell(plhs[0], t, arrX);
        } else {
            mxArray *arrIdx = mxCreateDoubleMatrix(1, cnt, mxREAL);
            double *outIdx = mxGetPr(arrIdx);
            size_t k;
            for (k = 0; k < cnt; k++) {
                outIdx[k] = (double)(idxBuf[k] + 1);
            }
            mxSetCell(plhs[0], t, arrIdx);
        }

        mxFree(idxBuf);
    }

    mxFree(idxBufs);
    mxFree(counts);
    mxFree(isUpper);
}
