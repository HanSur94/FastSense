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

    const double *x = mxGetPr(prhs[0]);
    const double *y = mxGetPr(prhs[1]);
    const size_t n = mxGetNumberOfElements(prhs[0]);
    const size_t nb = (size_t)mxGetScalar(prhs[2]);

    const size_t bucketSize = n / nb;
    const size_t usable = bucketSize * nb;
    const size_t outLen = 2 * nb;

    /* Allocate output */
    plhs[0] = mxCreateDoubleMatrix(1, outLen, mxREAL);
    plhs[1] = mxCreateDoubleMatrix(1, outLen, mxREAL);
    double *xOut = mxGetPr(plhs[0]);
    double *yOut = mxGetPr(plhs[1]);

    size_t b;
    for (b = 0; b < nb; b++) {
        const size_t base = b * bucketSize;
        size_t end = (b == nb - 1) ? n : base + bucketSize;

        double ymin_val = y[base];
        double ymax_val = y[base];
        size_t imin = base;
        size_t imax = base;

        size_t i = base + 1;

        /* SIMD pass: find min/max VALUES, then targeted scalar for indices */
#if SIMD_WIDTH > 1
        {
            simd_double vmin = simd_set1(ymin_val);
            simd_double vmax = simd_set1(ymax_val);

            size_t simd_end = base + ((end - base) / SIMD_WIDTH) * SIMD_WIDTH;

            size_t j;
            for (j = base; j < simd_end; j += SIMD_WIDTH) {
                simd_double v = simd_load(&y[j]);
                vmin = simd_min(vmin, v);
                vmax = simd_max(vmax, v);
            }

            ymin_val = simd_hmin(vmin);
            ymax_val = simd_hmax(vmax);

            /* Scalar remainder for values */
            for (j = simd_end; j < end; j++) {
                if (y[j] < ymin_val) ymin_val = y[j];
                if (y[j] > ymax_val) ymax_val = y[j];
            }

            /* Find first indices matching the known min/max (early exit) */
            imin = base;
            imax = base;
            int found_min = 0, found_max = 0;
            for (j = base; j < end; j++) {
                if (!found_min && y[j] == ymin_val) { imin = j; found_min = 1; }
                if (!found_max && y[j] == ymax_val) { imax = j; found_max = 1; }
                if (found_min && found_max) break;
            }
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
