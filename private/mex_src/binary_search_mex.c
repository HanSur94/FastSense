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

    const double *x = mxGetPr(prhs[0]);
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
