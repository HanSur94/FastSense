/*
 * resolve_disk_mex.c — Single-call disk-backed violation detection.
 *
 * [batchViolX, batchViolY] = resolve_disk_mex(dbPath, segLo, segHi,
 *                                              thresholdValues, directions)
 *
 *   dbPath          — char, path to the SQLite database file
 *   segLo           — 1xS double, start indices of active segments (1-based)
 *   segHi           — 1xS double, end indices of active segments (1-based)
 *   thresholdValues — 1xT double, threshold value per rule
 *   directions      — 1xT double, 1=upper (y>th), 0=lower (y<th)
 *
 *   Returns:
 *     batchViolX — 1xT cell array of 1xK double violation X vectors
 *     batchViolY — 1xT cell array of 1xK double violation Y vectors
 *
 * Opens the SQLite DB directly, queries chunks with y_min/y_max filtering,
 * reads raw doubles from typed BLOBs (skipping the 24-byte header), and
 * runs SIMD-accelerated violation detection — all in one MEX call.
 *
 * This replaces N mksqlite round-trips with a single C function call,
 * eliminating MATLAB<->MEX overhead and intermediate array allocations.
 */

#include "mex.h"
#include "simd_utils.h"
#include <sqlite3.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

/* mksqlite typed BLOB header — must match mksqlite.c */
#define TYPED_BLOB_MAGIC       0x4D4B5351  /* "MKSQ" */
#define TYPED_BLOB_HEADER_SIZE 24          /* 6 x uint32 */

/* Initial buffer capacity for violation results */
#define INIT_BUF_CAP 4096

/* ---- Dynamic double buffer ---- */
typedef struct {
    double *data;
    size_t  count;
    size_t  cap;
} DblBuf;

static void dblbuf_init(DblBuf *b) {
    b->cap = INIT_BUF_CAP;
    b->count = 0;
    b->data = (double *)mxMalloc(b->cap * sizeof(double));
}

static void dblbuf_ensure(DblBuf *b, size_t need) {
    if (b->count + need > b->cap) {
        while (b->count + need > b->cap)
            b->cap *= 2;
        b->data = (double *)mxRealloc(b->data, b->cap * sizeof(double));
    }
}

/* ---- Extract raw doubles from a typed BLOB ---- */
static const double *blob_to_doubles(const void *blob, int blobBytes,
                                     size_t *outCount)
{
    const unsigned char *raw = (const unsigned char *)blob;

    /* Check for typed BLOB header */
    if (blobBytes >= (int)TYPED_BLOB_HEADER_SIZE) {
        uint32_t magic;
        memcpy(&magic, raw, 4);
        if (magic == TYPED_BLOB_MAGIC) {
            uint32_t rows, cols;
            memcpy(&rows, raw + 16, 4);
            memcpy(&cols, raw + 20, 4);
            *outCount = (size_t)rows * (size_t)cols;
            return (const double *)(raw + TYPED_BLOB_HEADER_SIZE);
        }
    }

    /* Fallback: treat as raw doubles */
    *outCount = (size_t)blobBytes / sizeof(double);
    return (const double *)raw;
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    char *dbPath;
    const double *segLoD, *segHiD, *thVals, *dirD;
    size_t nSegs, nTh;
    sqlite3 *db = NULL;
    sqlite3_stmt *stmtUpper = NULL;
    sqlite3_stmt *stmtLower = NULL;
    int rc;
    size_t t, s;

    /* ---- Validate inputs ---- */
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("FastPlot:resolve_disk_mex:nrhs",
            "Five inputs required: dbPath, segLo, segHi, thresholdValues, directions.");
    }
    if (!mxIsChar(prhs[0])) {
        mexErrMsgIdAndTxt("FastPlot:resolve_disk_mex:badPath",
            "First input must be a char array (database path).");
    }

    dbPath = mxArrayToString(prhs[0]);
    segLoD = mxGetPr(prhs[1]);
    segHiD = mxGetPr(prhs[2]);
    nSegs  = mxGetNumberOfElements(prhs[1]);
    thVals = mxGetPr(prhs[3]);
    dirD   = mxGetPr(prhs[4]);
    nTh    = mxGetNumberOfElements(prhs[3]);

    /* ---- Prepare outputs ---- */
    plhs[0] = mxCreateCellMatrix(1, nTh);
    if (nlhs > 1)
        plhs[1] = mxCreateCellMatrix(1, nTh);

    if (nTh == 0 || nSegs == 0) {
        for (t = 0; t < nTh; t++) {
            mxSetCell(plhs[0], t, mxCreateDoubleMatrix(1, 0, mxREAL));
            if (nlhs > 1)
                mxSetCell(plhs[1], t, mxCreateDoubleMatrix(1, 0, mxREAL));
        }
        mxFree(dbPath);
        return;
    }

    /* ---- Parse directions ---- */
    int *isUpper = (int *)mxMalloc(nTh * sizeof(int));
    for (t = 0; t < nTh; t++)
        isUpper[t] = (dirD[t] != 0.0);

    /* ---- Allocate violation buffers per threshold ---- */
    DblBuf *violX = (DblBuf *)mxMalloc(nTh * sizeof(DblBuf));
    DblBuf *violY = (DblBuf *)mxMalloc(nTh * sizeof(DblBuf));
    for (t = 0; t < nTh; t++) {
        dblbuf_init(&violX[t]);
        dblbuf_init(&violY[t]);
    }

    /* ---- Open SQLite database ---- */
    rc = sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, NULL);
    if (rc != SQLITE_OK) {
        const char *errmsg = sqlite3_errmsg(db);
        sqlite3_close(db);
        mxFree(dbPath);
        mexErrMsgIdAndTxt("FastPlot:resolve_disk_mex:dbOpen",
            "Cannot open database: %s", errmsg);
    }

    /* Enable mmap for fast reads */
    sqlite3_exec(db, "PRAGMA mmap_size = 268435456;", NULL, NULL, NULL);

    /* ---- Prepare SQL statements ---- */
    const char *sqlUpper =
        "SELECT pt_offset, pt_count, x_data, y_data FROM chunks "
        "WHERE (pt_offset+pt_count-1) >= ? AND pt_offset <= ? "
        "AND y_max > ? ORDER BY chunk_id";

    const char *sqlLower =
        "SELECT pt_offset, pt_count, x_data, y_data FROM chunks "
        "WHERE (pt_offset+pt_count-1) >= ? AND pt_offset <= ? "
        "AND y_min < ? ORDER BY chunk_id";

    rc = sqlite3_prepare_v2(db, sqlUpper, -1, &stmtUpper, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_close(db);
        mxFree(dbPath);
        mexErrMsgIdAndTxt("FastPlot:resolve_disk_mex:prepare",
            "SQL prepare failed: %s", sqlite3_errmsg(db));
    }

    rc = sqlite3_prepare_v2(db, sqlLower, -1, &stmtLower, NULL);
    if (rc != SQLITE_OK) {
        sqlite3_finalize(stmtUpper);
        sqlite3_close(db);
        mxFree(dbPath);
        mexErrMsgIdAndTxt("FastPlot:resolve_disk_mex:prepare",
            "SQL prepare failed: %s", sqlite3_errmsg(db));
    }

    /* ---- Main loop: for each (threshold, segment) pair ---- */
    for (t = 0; t < nTh; t++) {
        double thVal = thVals[t];
        int upper = isUpper[t];
        sqlite3_stmt *stmt = upper ? stmtUpper : stmtLower;

        for (s = 0; s < nSegs; s++) {
            size_t startIdx = (size_t)segLoD[s];  /* 1-based */
            size_t endIdx   = (size_t)segHiD[s];  /* 1-based */

            sqlite3_reset(stmt);
            sqlite3_bind_int64(stmt, 1, (sqlite3_int64)startIdx);
            sqlite3_bind_int64(stmt, 2, (sqlite3_int64)endIdx);
            sqlite3_bind_double(stmt, 3, thVal);

            /* Process each matching chunk */
            while (sqlite3_step(stmt) == SQLITE_ROW) {
                size_t ptOffset = (size_t)sqlite3_column_int64(stmt, 0);

                /* Read X BLOB */
                const void *xBlob = sqlite3_column_blob(stmt, 2);
                int xBytes = sqlite3_column_bytes(stmt, 2);
                size_t xCount;
                const double *cx = blob_to_doubles(xBlob, xBytes, &xCount);

                /* Read Y BLOB */
                const void *yBlob = sqlite3_column_blob(stmt, 3);
                int yBytes = sqlite3_column_bytes(stmt, 3);
                size_t yCount;
                const double *cy = blob_to_doubles(yBlob, yBytes, &yCount);

                size_t chunkLen = (xCount < yCount) ? xCount : yCount;

                /* Trim to [startIdx, endIdx] within this chunk */
                size_t localStart = 0;
                size_t localEnd = chunkLen;
                if (ptOffset < startIdx)
                    localStart = startIdx - ptOffset;
                if (ptOffset + chunkLen > endIdx + 1)
                    localEnd = endIdx + 1 - ptOffset;

                if (localEnd <= localStart) continue;

                size_t trimLen = localEnd - localStart;
                const double *tx = cx + localStart;
                const double *ty = cy + localStart;

                /* Ensure buffer space */
                dblbuf_ensure(&violX[t], trimLen);
                dblbuf_ensure(&violY[t], trimLen);

                double *vxData = violX[t].data;
                double *vyData = violY[t].data;
                size_t cnt = violX[t].count;
                size_t i;

                /* SIMD-accelerated violation detection with early-exit */
#if SIMD_WIDTH > 1
                {
                    simd_double vth = simd_set1(thVal);
                    size_t simdEnd = (trimLen / SIMD_WIDTH) * SIMD_WIDTH;

                    if (upper) {
                        for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
                            simd_double vy = simd_load(&ty[i]);
                            if (simd_hmax(vy) > thVal) {
                                double yBuf[SIMD_WIDTH];
                                double xBuf[SIMD_WIDTH];
                                simd_store(yBuf, vy);
                                simd_store(xBuf, simd_load(&tx[i]));
                                size_t j;
                                for (j = 0; j < SIMD_WIDTH; j++) {
                                    if (yBuf[j] > thVal) {
                                        vxData[cnt] = xBuf[j];
                                        vyData[cnt] = yBuf[j];
                                        cnt++;
                                    }
                                }
                            }
                        }
                        for (; i < trimLen; i++) {
                            if (ty[i] > thVal) {
                                vxData[cnt] = tx[i];
                                vyData[cnt] = ty[i];
                                cnt++;
                            }
                        }
                    } else {
                        for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
                            simd_double vy = simd_load(&ty[i]);
                            if (simd_hmin(vy) < thVal) {
                                double yBuf[SIMD_WIDTH];
                                double xBuf[SIMD_WIDTH];
                                simd_store(yBuf, vy);
                                simd_store(xBuf, simd_load(&tx[i]));
                                size_t j;
                                for (j = 0; j < SIMD_WIDTH; j++) {
                                    if (yBuf[j] < thVal) {
                                        vxData[cnt] = xBuf[j];
                                        vyData[cnt] = yBuf[j];
                                        cnt++;
                                    }
                                }
                            }
                        }
                        for (; i < trimLen; i++) {
                            if (ty[i] < thVal) {
                                vxData[cnt] = tx[i];
                                vyData[cnt] = ty[i];
                                cnt++;
                            }
                        }
                    }
                }
#else
                /* Scalar fallback */
                if (upper) {
                    for (i = 0; i < trimLen; i++) {
                        if (ty[i] > thVal) {
                            vxData[cnt] = tx[i];
                            vyData[cnt] = ty[i];
                            cnt++;
                        }
                    }
                } else {
                    for (i = 0; i < trimLen; i++) {
                        if (ty[i] < thVal) {
                            vxData[cnt] = tx[i];
                            vyData[cnt] = ty[i];
                            cnt++;
                        }
                    }
                }
#endif
                violX[t].count = cnt;
                violY[t].count = cnt;
            } /* while sqlite3_step */
        } /* for each segment */
    } /* for each threshold */

    /* ---- Finalize SQLite ---- */
    sqlite3_finalize(stmtUpper);
    sqlite3_finalize(stmtLower);
    sqlite3_close(db);
    mxFree(dbPath);

    /* ---- Build output cell arrays ---- */
    for (t = 0; t < nTh; t++) {
        size_t cnt = violX[t].count;

        mxArray *arrX = mxCreateDoubleMatrix(1, cnt, mxREAL);
        mxArray *arrY = mxCreateDoubleMatrix(1, cnt, mxREAL);

        if (cnt > 0) {
            memcpy(mxGetPr(arrX), violX[t].data, cnt * sizeof(double));
            memcpy(mxGetPr(arrY), violY[t].data, cnt * sizeof(double));
        }

        mxSetCell(plhs[0], t, arrX);
        if (nlhs > 1)
            mxSetCell(plhs[1], t, arrY);

        mxFree(violX[t].data);
        mxFree(violY[t].data);
    }

    mxFree(violX);
    mxFree(violY);
    mxFree(isUpper);
}
