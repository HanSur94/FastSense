/*
 * build_store_mex.c — MEX-based bulk SQLite writer for FastSenseDataStore.
 *
 * numChunks = build_store_mex(dbPath, X, Y, chunkSize)
 *
 *   dbPath    — char, path for the new SQLite database file
 *   X         — 1xN double, sorted X data (time axis)
 *   Y         — 1xN double, Y data
 *   chunkSize — scalar double, number of points per chunk
 *
 *   Returns:
 *     numChunks — scalar double, number of chunks written
 *
 * Creates the SQLite database with chunks, resolved_thresholds, and
 * resolved_violations tables.  Writes all data as typed BLOBs (mksqlite-
 * compatible 24-byte header) with SIMD-accelerated Y min/max metadata.
 *
 * Replaces the MATLAB loop in FastSenseDataStore.initSqlite, eliminating
 * ~20K mksqlite round-trips and saving ~3-4s on 100M+ point datasets.
 */

#include "mex.h"
#include "simd_utils.h"
#include "sqlite3.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>

/* mksqlite typed BLOB header — must match mksqlite.c format */
#define TYPED_BLOB_MAGIC       0x4D4B5351  /* "MKSQ" */
#define TYPED_BLOB_VERSION     3
#define TYPED_BLOB_CLASS_DBL   6           /* mxDOUBLE_CLASS */
#define TYPED_BLOB_HEADER_SIZE 24          /* 6 x uint32 */

/* Runtime check in mexFunction verifies TYPED_BLOB_CLASS_DBL == mxDOUBLE_CLASS.
 * (Cannot use #if because mxDOUBLE_CLASS is an enum, not a macro.) */

/* ---- Build a typed BLOB in a pre-allocated buffer ---- */
static void build_typed_blob(unsigned char *buf,
                             const double *data, uint32_t count)
{
    uint32_t hdr[6];
    hdr[0] = TYPED_BLOB_MAGIC;
    hdr[1] = TYPED_BLOB_VERSION;
    hdr[2] = TYPED_BLOB_CLASS_DBL;
    hdr[3] = 2;       /* ndims */
    hdr[4] = 1;       /* rows  */
    hdr[5] = count;   /* cols  */
    memcpy(buf, hdr, TYPED_BLOB_HEADER_SIZE);
    memcpy(buf + TYPED_BLOB_HEADER_SIZE, data, count * sizeof(double));
}

/* ---- SIMD-accelerated min/max of a double array ---- */
static void compute_yminmax(const double *data, size_t count,
                            double *out_min, double *out_max)
{
    size_t i;

    if (count == 0) {
        *out_min = 0.0;
        *out_max = 0.0;
        return;
    }

#if SIMD_WIDTH > 1
    {
        simd_double vmin = simd_set1(data[0]);
        simd_double vmax = simd_set1(data[0]);
        size_t simdEnd = (count / SIMD_WIDTH) * SIMD_WIDTH;

        for (i = 0; i < simdEnd; i += SIMD_WIDTH) {
            simd_double v = simd_load(&data[i]);
            vmin = simd_min(vmin, v);
            vmax = simd_max(vmax, v);
        }

        *out_min = simd_hmin(vmin);
        *out_max = simd_hmax(vmax);

        /* Scalar remainder */
        for (; i < count; i++) {
            if (data[i] < *out_min) *out_min = data[i];
            if (data[i] > *out_max) *out_max = data[i];
        }
    }
#else
    {
        double dmin = data[0], dmax = data[0];
        for (i = 1; i < count; i++) {
            if (data[i] < dmin) dmin = data[i];
            if (data[i] > dmax) dmax = data[i];
        }
        *out_min = dmin;
        *out_max = dmax;
    }
#endif

    /* NaN handling: SIMD min/max propagate NaN (unlike MATLAB's min/max
     * which skip NaN).  If result is NaN, rescan with NaN-skipping scalar
     * loop.  For all-NaN chunks, use Inf/-Inf sentinels so SQLite doesn't
     * convert NaN to NULL (which would violate NOT NULL constraints).
     * Note: isnan() is safe here — -ffast-math may break x!=x but the
     * C99 isnan macro is a type-generic builtin that compilers preserve. */
    if (isnan(*out_min) || isnan(*out_max)) {
        /* Use 1.0/0.0 instead of INFINITY macro to avoid -ffast-math warning */
        volatile double zero = 0.0;
        double dmin = 1.0 / zero, dmax = -1.0 / zero;
        for (i = 0; i < count; i++) {
            if (!isnan(data[i])) {
                if (data[i] < dmin) dmin = data[i];
                if (data[i] > dmax) dmax = data[i];
            }
        }
        *out_min = dmin;  /* stays INFINITY if all NaN */
        *out_max = dmax;  /* stays -INFINITY if all NaN */
    }
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    char *dbPath;
    const double *x, *y;
    size_t n, cs;
    sqlite3 *db = NULL;
    sqlite3_stmt *stmt = NULL;
    unsigned char *xBlobBuf, *yBlobBuf;
    size_t blobBufSize;
    size_t chunkId, s;
    int rc;

    /* Sanity check: typed BLOB class constant must match MATLAB's mxDOUBLE_CLASS */
    if (TYPED_BLOB_CLASS_DBL != mxDOUBLE_CLASS) {
        mexErrMsgIdAndTxt("FastSense:build_store_mex:classSync",
            "TYPED_BLOB_CLASS_DBL (%d) != mxDOUBLE_CLASS (%d)",
            TYPED_BLOB_CLASS_DBL, (int)mxDOUBLE_CLASS);
    }

    /* ---- Validate inputs ---- */
    if (nrhs != 4) {
        mexErrMsgIdAndTxt("FastSense:build_store_mex:nrhs",
            "Four inputs required: dbPath, X, Y, chunkSize.");
    }
    if (!mxIsChar(prhs[0])) {
        mexErrMsgIdAndTxt("FastSense:build_store_mex:badPath",
            "First input must be a char array (database path).");
    }
    if (!mxIsDouble(prhs[1]) || mxIsComplex(prhs[1])) {
        mexErrMsgIdAndTxt("FastSense:build_store_mex:notDouble",
            "X must be a real double array.");
    }
    if (!mxIsDouble(prhs[2]) || mxIsComplex(prhs[2])) {
        mexErrMsgIdAndTxt("FastSense:build_store_mex:notDouble",
            "Y must be a real double array.");
    }

    dbPath = mxArrayToString(prhs[0]);
    x = mxGetPr(prhs[1]);
    y = mxGetPr(prhs[2]);
    n = mxGetNumberOfElements(prhs[1]);
    cs = (size_t)mxGetScalar(prhs[3]);

    /* Empty data: nothing to do */
    if (n == 0) {
        plhs[0] = mxCreateDoubleScalar(0.0);
        mxFree(dbPath);
        return;
    }

    /* ---- Open SQLite database ---- */
    rc = sqlite3_open_v2(dbPath, &db,
                         SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, NULL);
    if (rc != SQLITE_OK) {
        char errbuf[256];
        snprintf(errbuf, sizeof(errbuf), "%s", sqlite3_errmsg(db));
        sqlite3_close(db);
        mxFree(dbPath);
        mexErrMsgIdAndTxt("FastSense:build_store_mex:dbOpen",
            "Cannot open database: %s", errbuf);
    }

    /* ---- Performance PRAGMAs for bulk write ---- */
    sqlite3_exec(db, "PRAGMA journal_mode = OFF",       NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA synchronous = OFF",        NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA cache_size = -50000",      NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA temp_store = MEMORY",      NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA locking_mode = EXCLUSIVE",  NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA page_size = 65536",        NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA mmap_size = 268435456",    NULL, NULL, NULL);

    /* ---- Create tables ---- */
    /* KEEP IN SYNC with FastSenseDataStore.initSqlite MATLAB fallback */
    rc = sqlite3_exec(db,
        "CREATE TABLE chunks ("
        "  chunk_id INTEGER PRIMARY KEY,"
        "  x_min REAL NOT NULL,"
        "  x_max REAL NOT NULL,"
        "  y_min REAL NOT NULL,"
        "  y_max REAL NOT NULL,"
        "  pt_offset INTEGER NOT NULL,"
        "  pt_count INTEGER NOT NULL,"
        "  x_data BLOB NOT NULL,"
        "  y_data BLOB NOT NULL"
        ")", NULL, NULL, NULL);
    if (rc != SQLITE_OK) {
        char errbuf[256];
        snprintf(errbuf, sizeof(errbuf), "%s", sqlite3_errmsg(db));
        sqlite3_close(db);
        mxFree(dbPath);
        mexErrMsgIdAndTxt("FastSense:build_store_mex:createTable",
            "CREATE TABLE chunks failed: %s", errbuf);
    }

    /* KEEP IN SYNC with FastSenseDataStore.initSqlite MATLAB fallback */
    sqlite3_exec(db,
        "CREATE TABLE resolved_thresholds ("
        "  idx INTEGER PRIMARY KEY,"
        "  x_data BLOB,"
        "  y_data BLOB,"
        "  direction TEXT NOT NULL,"
        "  label TEXT NOT NULL,"
        "  color BLOB,"
        "  line_style TEXT NOT NULL,"
        "  value REAL NOT NULL"
        ")", NULL, NULL, NULL);

    /* KEEP IN SYNC with FastSenseDataStore.initSqlite MATLAB fallback */
    sqlite3_exec(db,
        "CREATE TABLE resolved_violations ("
        "  idx INTEGER PRIMARY KEY,"
        "  x_data BLOB,"
        "  y_data BLOB,"
        "  direction TEXT NOT NULL,"
        "  label TEXT NOT NULL"
        ")", NULL, NULL, NULL);

    /* MONITOR-09: MonitorTag.Persist=true cache.
       KEEP IN SYNC with FastSenseDataStore.initSqlite MATLAB fallback. */
    sqlite3_exec(db,
        "CREATE TABLE monitors ("
        "  key         TEXT PRIMARY KEY,"
        "  x_blob      BLOB NOT NULL,"
        "  y_blob      BLOB NOT NULL,"
        "  parent_key  TEXT NOT NULL,"
        "  num_points  INTEGER NOT NULL,"
        "  parent_xmin REAL NOT NULL,"
        "  parent_xmax REAL NOT NULL,"
        "  computed_at REAL NOT NULL"
        ")", NULL, NULL, NULL);

    /* ---- Prepare INSERT statement ---- */
    rc = sqlite3_prepare_v2(db,
        "INSERT INTO chunks VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        -1, &stmt, NULL);
    if (rc != SQLITE_OK) {
        char errbuf[256];
        snprintf(errbuf, sizeof(errbuf), "%s", sqlite3_errmsg(db));
        sqlite3_close(db);
        mxFree(dbPath);
        mexErrMsgIdAndTxt("FastSense:build_store_mex:prepare",
            "Prepare failed: %s", errbuf);
    }

    /* ---- Allocate typed BLOB buffers (one for X, one for Y) ---- */
    /* Cap to actual data length for the case where n < cs */
    {
        size_t maxChunkPts = (cs < n) ? cs : n;
        blobBufSize = TYPED_BLOB_HEADER_SIZE + maxChunkPts * sizeof(double);
    }
    xBlobBuf = (unsigned char *)mxMalloc(blobBufSize);
    yBlobBuf = (unsigned char *)mxMalloc(blobBufSize);

    /* ---- Begin transaction and insert all chunks ---- */
    sqlite3_exec(db, "BEGIN TRANSACTION", NULL, NULL, NULL);

    chunkId = 0;
    for (s = 0; s < n; s += cs) {
        size_t e = s + cs;
        size_t count;
        const double *cx, *cy;
        double yMin, yMax;
        int blobSize;

        if (e > n) e = n;
        count = e - s;
        cx = x + s;
        cy = y + s;

        chunkId++;

        /* SIMD-accelerated Y min/max */
        compute_yminmax(cy, count, &yMin, &yMax);

        /* Build typed BLOBs */
        blobSize = (int)(TYPED_BLOB_HEADER_SIZE + count * sizeof(double));
        build_typed_blob(xBlobBuf, cx, (uint32_t)count);
        build_typed_blob(yBlobBuf, cy, (uint32_t)count);

        /* Bind parameters */
        sqlite3_reset(stmt);
        sqlite3_bind_int64(stmt, 1, (sqlite3_int64)chunkId);
        sqlite3_bind_double(stmt, 2, cx[0]);           /* x_min */
        sqlite3_bind_double(stmt, 3, cx[count - 1]);   /* x_max */
        sqlite3_bind_double(stmt, 4, yMin);             /* y_min */
        sqlite3_bind_double(stmt, 5, yMax);             /* y_max */
        sqlite3_bind_int64(stmt, 6, (sqlite3_int64)(s + 1));  /* pt_offset, 1-based */
        sqlite3_bind_int64(stmt, 7, (sqlite3_int64)count);    /* pt_count */
        sqlite3_bind_blob(stmt, 8, xBlobBuf, blobSize, SQLITE_STATIC);
        sqlite3_bind_blob(stmt, 9, yBlobBuf, blobSize, SQLITE_STATIC);

        rc = sqlite3_step(stmt);
        if (rc != SQLITE_DONE) {
            char errbuf[256];
            snprintf(errbuf, sizeof(errbuf), "%s", sqlite3_errmsg(db));
            sqlite3_finalize(stmt);
            sqlite3_exec(db, "ROLLBACK", NULL, NULL, NULL);
            sqlite3_close(db);
            mxFree(xBlobBuf);
            mxFree(yBlobBuf);
            mxFree(dbPath);
            mexErrMsgIdAndTxt("FastSense:build_store_mex:insert",
                "Insert failed at chunk %d: %s", (int)chunkId, errbuf);
        }
    }

    sqlite3_finalize(stmt);

    /* ---- Create indexes inside the transaction ---- */
    sqlite3_exec(db, "CREATE INDEX idx_xrange ON chunks (x_min, x_max)",
                 NULL, NULL, NULL);
    sqlite3_exec(db, "CREATE INDEX idx_ptoffset ON chunks (pt_offset)",
                 NULL, NULL, NULL);

    /* ---- Commit ---- */
    sqlite3_exec(db, "COMMIT", NULL, NULL, NULL);

    /* ---- Post-insert: ANALYZE and reset PRAGMAs ---- */
    sqlite3_exec(db, "ANALYZE",                        NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA journal_mode = DELETE",   NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA synchronous = NORMAL",    NULL, NULL, NULL);
    sqlite3_exec(db, "PRAGMA locking_mode = NORMAL",   NULL, NULL, NULL);
    /* A read must occur to release the EXCLUSIVE lock */
    sqlite3_exec(db, "SELECT 1 FROM chunks LIMIT 1",  NULL, NULL, NULL);

    /* ---- Cleanup ---- */
    sqlite3_close(db);
    mxFree(xBlobBuf);
    mxFree(yBlobBuf);
    mxFree(dbPath);

    /* Return number of chunks written */
    plhs[0] = mxCreateDoubleScalar((double)chunkId);
}
