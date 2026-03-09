/*
 * compute_violations_mex.c — SIMD-accelerated batch threshold violation detection.
 *
 * Usage from MATLAB:
 *   violIdx = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions)
 *
 *   sensorY:          1xN double — sensor Y data
 *   segLo, segHi:     1xS double — active segment ranges (1-based MATLAB indices)
 *   thresholdValues:   1xT double — threshold values to check
 *   directions:        1xT double — 1=upper (y>th), 0=lower (y<th)
 *
 *   Returns: 1xT cell array, each cell is a 1xK double of violation indices (1-based)
 *
 * SIMD strategy: for each segment, load SIMD_WIDTH doubles from sensorY,
 * compare against threshold, extract matching indices.
 */

#include "mex.h"
#include "simd_utils.h"
#include <string.h>
#include <stdlib.h>

/* Compare SIMD_WIDTH doubles against threshold, store matching 1-based indices */
static size_t scan_upper(const double *y, size_t lo, size_t hi,
                          double threshold, double *out) {
    size_t count = 0;
    size_t i = lo;

#if SIMD_WIDTH > 1
    simd_double vth = simd_set1(threshold);
    size_t simd_end = lo + ((hi - lo + 1) / SIMD_WIDTH) * SIMD_WIDTH;

    for (; i < simd_end; i += SIMD_WIDTH) {
        simd_double vy = simd_load(&y[i]);
        double buf[SIMD_WIDTH];
        simd_store(buf, vy);
        size_t j;
        for (j = 0; j < SIMD_WIDTH; j++) {
            if (buf[j] > threshold) {
                out[count++] = (double)(i + j + 1); /* 1-based */
            }
        }
    }
#endif

    /* Scalar tail */
    for (; i <= hi; i++) {
        if (y[i] > threshold) {
            out[count++] = (double)(i + 1); /* 1-based */
        }
    }
    return count;
}

static size_t scan_lower(const double *y, size_t lo, size_t hi,
                          double threshold, double *out) {
    size_t count = 0;
    size_t i = lo;

#if SIMD_WIDTH > 1
    simd_double vth = simd_set1(threshold);
    size_t simd_end = lo + ((hi - lo + 1) / SIMD_WIDTH) * SIMD_WIDTH;

    for (; i < simd_end; i += SIMD_WIDTH) {
        simd_double vy = simd_load(&y[i]);
        double buf[SIMD_WIDTH];
        simd_store(buf, vy);
        size_t j;
        for (j = 0; j < SIMD_WIDTH; j++) {
            if (buf[j] < threshold) {
                out[count++] = (double)(i + j + 1); /* 1-based */
            }
        }
    }
#endif

    for (; i <= hi; i++) {
        if (y[i] < threshold) {
            out[count++] = (double)(i + 1);
        }
    }
    return count;
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("FastPlot:compute_violations_mex:nrhs",
                          "Five inputs required: sensorY, segLo, segHi, thresholdValues, directions.");
    }

    const double *sensorY = mxGetPr(prhs[0]);
    const size_t N = mxGetNumberOfElements(prhs[0]);

    const double *segLoD = mxGetPr(prhs[1]);
    const double *segHiD = mxGetPr(prhs[2]);
    const size_t nSegs = mxGetNumberOfElements(prhs[1]);

    const double *thresholds = mxGetPr(prhs[3]);
    const double *dirs = mxGetPr(prhs[4]);
    const size_t nThresh = mxGetNumberOfElements(prhs[3]);

    /* Compute total points across all active segments (upper bound for output) */
    size_t totalPoints = 0;
    size_t s;
    for (s = 0; s < nSegs; s++) {
        size_t lo = (size_t)segLoD[s] - 1; /* convert to 0-based */
        size_t hi = (size_t)segHiD[s] - 1;
        if (hi >= lo) {
            totalPoints += (hi - lo + 1);
        }
    }

    /* Allocate output cell array */
    plhs[0] = mxCreateCellMatrix(1, nThresh);

    /* Temporary buffer for violation indices */
    double *buf = (double *)mxMalloc(totalPoints * sizeof(double));

    size_t t;
    for (t = 0; t < nThresh; t++) {
        double thVal = thresholds[t];
        int isUpper = (dirs[t] != 0.0);
        size_t count = 0;

        for (s = 0; s < nSegs; s++) {
            size_t lo = (size_t)segLoD[s] - 1;
            size_t hi = (size_t)segHiD[s] - 1;

            if (hi < lo || lo >= N) continue;
            if (hi >= N) hi = N - 1;

            size_t found;
            if (isUpper) {
                found = scan_upper(sensorY, lo, hi, thVal, buf + count);
            } else {
                found = scan_lower(sensorY, lo, hi, thVal, buf + count);
            }
            count += found;
        }

        /* Create output array for this threshold */
        mxArray *result = mxCreateDoubleMatrix(1, count, mxREAL);
        if (count > 0) {
            memcpy(mxGetPr(result), buf, count * sizeof(double));
        }
        mxSetCell(plhs[0], t, result);
    }

    mxFree(buf);
}
