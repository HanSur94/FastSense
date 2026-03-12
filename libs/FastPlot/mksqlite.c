/*
 * mksqlite.c - Minimal mksqlite-compatible MEX for MATLAB and GNU Octave
 *
 * Supports:
 *   dbId = mksqlite('open', filepath)
 *   mksqlite(dbId, 'close')
 *   mksqlite(dbId, 'typedBLOBs', 2)
 *   mksqlite(dbId, 'SQL statement')
 *   mksqlite(dbId, 'SQL with ? placeholders', val1, val2, ...)
 *
 * Typed BLOBs: MATLAB/Octave arrays are serialized with a header for type
 * preservation. Supports numeric arrays, char, logical, cell arrays, and
 * struct-based categorical representation.
 *
 * Compile:
 *   mkoctfile --mex -o mksqlite.mex -lsqlite3 mksqlite.c    (Octave)
 *   mex -lsqlite3 mksqlite.c                                 (MATLAB)
 */

#include "mex.h"
#include <sqlite3.h>
#include <string.h>
#include <stdlib.h>

/* ---- Constants ---- */
#define MAX_DBS 16

/* Typed BLOB header magic */
#define TYPED_BLOB_MAGIC  0x4D4B5351  /* "MKSQ" */
#define TYPED_BLOB_VER    3           /* v3: added char, logical, cell support */
#define LEN_PREFIX_SIZE   4           /* uint32 length prefix for nested blobs */

/* Extended type tags (stored in class_id field) */
#define TAG_NUMERIC    0   /* class_id holds mxClassID directly */
#define TAG_CHAR       100 /* char array */
#define TAG_LOGICAL    101 /* logical array */
#define TAG_CELL       102 /* cell array (nested serialization) */
#define TAG_CATEGORICAL 103 /* categorical: codes(uint32) + category names */

/* ---- Typed BLOB header structure ---- */
typedef struct {
    uint32_t magic;       /* TYPED_BLOB_MAGIC */
    uint32_t version;     /* TYPED_BLOB_VER */
    uint32_t class_id;    /* mxClassID for numeric, or TAG_* for others */
    uint32_t ndims;       /* number of dimensions */
    uint32_t rows;        /* first dimension size */
    uint32_t cols;        /* second dimension size */
    /* raw data follows immediately after this header */
} TypedBlobHeader;

#define TYPED_BLOB_HEADER_SIZE sizeof(TypedBlobHeader)

/* ---- Module state ---- */
static sqlite3 *g_dbs[MAX_DBS] = {NULL};
static int g_typed_blobs[MAX_DBS] = {0};

/* ---- Forward declarations ---- */
static void *serialize_value(const mxArray *arr, size_t *out_size);
static mxArray *deserialize_value(const unsigned char *data, size_t nbytes,
                                  size_t *consumed);

/* ---- Helpers ---- */

static int find_free_slot(void) {
    int i;
    for (i = 0; i < MAX_DBS; i++) {
        if (g_dbs[i] == NULL) return i;
    }
    return -1;
}

static void check_db_id(int dbId) {
    if (dbId < 1 || dbId > MAX_DBS || g_dbs[dbId - 1] == NULL) {
        mexErrMsgIdAndTxt("mksqlite:badHandle",
                          "Invalid database handle: %d", dbId);
    }
}

/* Get element size for numeric mxClassID */
static size_t class_element_size(mxClassID cid) {
    switch (cid) {
        case mxDOUBLE_CLASS:  return 8;
        case mxSINGLE_CLASS:  return 4;
        case mxINT8_CLASS:    return 1;
        case mxUINT8_CLASS:   return 1;
        case mxINT16_CLASS:   return 2;
        case mxUINT16_CLASS:  return 2;
        case mxINT32_CLASS:   return 4;
        case mxUINT32_CLASS:  return 4;
        case mxINT64_CLASS:   return 8;
        case mxUINT64_CLASS:  return 8;
        default:              return 0;
    }
}

/* ================================================================
 *  SERIALIZATION
 * ================================================================ */

static TypedBlobHeader init_blob_header(uint32_t class_id, size_t rows, size_t cols) {
    TypedBlobHeader hdr;
    hdr.magic    = TYPED_BLOB_MAGIC;
    hdr.version  = TYPED_BLOB_VER;
    hdr.class_id = class_id;
    hdr.ndims    = 2;
    hdr.rows     = (uint32_t)rows;
    hdr.cols     = (uint32_t)cols;
    return hdr;
}

static void *serialize_numeric(const mxArray *arr, size_t *out_size) {
    mxClassID cid = mxGetClassID(arr);
    size_t elem_sz = class_element_size(cid);
    size_t rows = mxGetM(arr), cols = mxGetN(arr);
    size_t data_bytes = rows * cols * elem_sz;
    size_t total = TYPED_BLOB_HEADER_SIZE + data_bytes;
    unsigned char *buf = (unsigned char *)mxMalloc(total);
    TypedBlobHeader hdr = init_blob_header((uint32_t)cid, rows, cols);

    memcpy(buf, &hdr, TYPED_BLOB_HEADER_SIZE);
    memcpy(buf + TYPED_BLOB_HEADER_SIZE, mxGetData(arr), data_bytes);
    *out_size = total;
    return buf;
}

static void *serialize_char(const mxArray *arr, size_t *out_size) {
    size_t rows = mxGetM(arr), cols = mxGetN(arr);
    size_t numel = rows * cols;
    size_t total = TYPED_BLOB_HEADER_SIZE + numel;
    unsigned char *buf = (unsigned char *)mxMalloc(total);
    TypedBlobHeader hdr = init_blob_header(TAG_CHAR, rows, cols);
    mxChar *data = mxGetChars(arr);
    size_t i;

    memcpy(buf, &hdr, TYPED_BLOB_HEADER_SIZE);
    for (i = 0; i < numel; i++)
        buf[TYPED_BLOB_HEADER_SIZE + i] = (unsigned char)data[i];
    *out_size = total;
    return buf;
}

static void *serialize_logical(const mxArray *arr, size_t *out_size) {
    size_t rows = mxGetM(arr), cols = mxGetN(arr);
    size_t numel = rows * cols;
    size_t total = TYPED_BLOB_HEADER_SIZE + numel;
    unsigned char *buf = (unsigned char *)mxMalloc(total);
    TypedBlobHeader hdr = init_blob_header(TAG_LOGICAL, rows, cols);
    mxLogical *data = mxGetLogicals(arr);
    size_t i;

    memcpy(buf, &hdr, TYPED_BLOB_HEADER_SIZE);
    for (i = 0; i < numel; i++)
        buf[TYPED_BLOB_HEADER_SIZE + i] = (unsigned char)(data[i] ? 1 : 0);
    *out_size = total;
    return buf;
}

/* Serialize a cell array — each element is recursively serialized with
 * a 4-byte length prefix:  [len_0][blob_0][len_1][blob_1]... */
static void *serialize_cell(const mxArray *arr, size_t *out_size) {
    size_t rows = mxGetM(arr), cols = mxGetN(arr);
    size_t numel = rows * cols;
    size_t i;

    void **elem_blobs = (void **)mxMalloc(numel * sizeof(void *));
    size_t *elem_sizes = (size_t *)mxMalloc(numel * sizeof(size_t));
    size_t payload_size = 0;

    for (i = 0; i < numel; i++) {
        mxArray *cell_elem = mxGetCell(arr, i);
        if (cell_elem == NULL) {
            elem_blobs[i] = NULL;
            elem_sizes[i] = 0;
        } else {
            elem_blobs[i] = serialize_value(cell_elem, &elem_sizes[i]);
        }
        payload_size += LEN_PREFIX_SIZE + elem_sizes[i];
    }

    size_t total = TYPED_BLOB_HEADER_SIZE + payload_size;
    unsigned char *buf = (unsigned char *)mxMalloc(total);
    TypedBlobHeader hdr = init_blob_header(TAG_CELL, rows, cols);
    memcpy(buf, &hdr, TYPED_BLOB_HEADER_SIZE);

    size_t offset = TYPED_BLOB_HEADER_SIZE;
    for (i = 0; i < numel; i++) {
        uint32_t len = (uint32_t)elem_sizes[i];
        memcpy(buf + offset, &len, LEN_PREFIX_SIZE);
        offset += LEN_PREFIX_SIZE;
        if (len > 0) {
            memcpy(buf + offset, elem_blobs[i], len);
            mxFree(elem_blobs[i]);
            offset += len;
        }
    }

    mxFree(elem_blobs);
    mxFree(elem_sizes);

    *out_size = total;
    return buf;
}

/* Serialize a struct (used for categorical representation).
 * Format: header(TAG_CATEGORICAL) + nFields(uint32) +
 *         for each field: nameLen(uint32) + name + valueLen(uint32) + value_blob
 *
 * Categorical in MATLAB is: struct with 'codes' (uint32 array) and
 * 'categories' (cell array of char). We store structs generically. */
static void *serialize_struct(const mxArray *arr, size_t *out_size) {
    int nfields = mxGetNumberOfFields(arr);
    int f;

    if (mxGetNumberOfElements(arr) != 1) {
        mexErrMsgIdAndTxt("mksqlite:unsupportedStruct",
                          "Only scalar structs can be serialized as typed BLOBs.");
    }

    const char **field_names = (const char **)mxMalloc(nfields * sizeof(char *));
    void **field_blobs = (void **)mxMalloc(nfields * sizeof(void *));
    size_t *field_sizes = (size_t *)mxMalloc(nfields * sizeof(size_t));
    size_t payload_size = LEN_PREFIX_SIZE;  /* nFields */

    for (f = 0; f < nfields; f++) {
        field_names[f] = mxGetFieldNameByNumber(arr, f);
        mxArray *val = mxGetFieldByNumber(arr, 0, f);
        if (val == NULL) {
            field_blobs[f] = NULL;
            field_sizes[f] = 0;
        } else {
            field_blobs[f] = serialize_value(val, &field_sizes[f]);
        }
        payload_size += LEN_PREFIX_SIZE + strlen(field_names[f]);
        payload_size += LEN_PREFIX_SIZE + field_sizes[f];
    }

    size_t total = TYPED_BLOB_HEADER_SIZE + payload_size;
    unsigned char *buf = (unsigned char *)mxMalloc(total);
    TypedBlobHeader hdr = init_blob_header(TAG_CATEGORICAL, 1, 1);
    memcpy(buf, &hdr, TYPED_BLOB_HEADER_SIZE);

    size_t offset = TYPED_BLOB_HEADER_SIZE;
    uint32_t nf = (uint32_t)nfields;
    memcpy(buf + offset, &nf, LEN_PREFIX_SIZE); offset += LEN_PREFIX_SIZE;

    for (f = 0; f < nfields; f++) {
        uint32_t nlen = (uint32_t)strlen(field_names[f]);
        memcpy(buf + offset, &nlen, LEN_PREFIX_SIZE); offset += LEN_PREFIX_SIZE;
        memcpy(buf + offset, field_names[f], nlen); offset += nlen;

        uint32_t vlen = (uint32_t)field_sizes[f];
        memcpy(buf + offset, &vlen, LEN_PREFIX_SIZE); offset += LEN_PREFIX_SIZE;
        if (vlen > 0) {
            memcpy(buf + offset, field_blobs[f], vlen);
            mxFree(field_blobs[f]);
            offset += vlen;
        }
    }

    mxFree(field_names);
    mxFree(field_blobs);
    mxFree(field_sizes);

    *out_size = total;
    return buf;
}

/* Top-level serializer: dispatches based on type */
static void *serialize_value(const mxArray *arr, size_t *out_size) {
    if (mxIsChar(arr)) {
        return serialize_char(arr, out_size);
    }
    if (mxIsLogical(arr)) {
        return serialize_logical(arr, out_size);
    }
    if (mxIsCell(arr)) {
        return serialize_cell(arr, out_size);
    }
    if (mxIsStruct(arr)) {
        return serialize_struct(arr, out_size);
    }
    if (mxIsNumeric(arr)) {
        size_t elem_sz = class_element_size(mxGetClassID(arr));
        if (elem_sz == 0) {
            mexErrMsgIdAndTxt("mksqlite:unsupportedClass",
                              "Cannot serialize arrays of this numeric class.");
        }
        return serialize_numeric(arr, out_size);
    }
    mexErrMsgIdAndTxt("mksqlite:unsupportedClass",
                      "Cannot serialize this MATLAB type as a typed BLOB.");
    return NULL;  /* unreachable — satisfies compiler */
}

/* ================================================================
 *  DESERIALIZATION
 * ================================================================ */

/* Deserialize a typed BLOB. Returns consumed bytes via *consumed. */
static mxArray *deserialize_value(const unsigned char *data, size_t nbytes,
                                  size_t *consumed) {
    const TypedBlobHeader *hdr;
    size_t numel, offset;
    mxArray *arr;

    if (nbytes < TYPED_BLOB_HEADER_SIZE) { *consumed = 0; return NULL; }

    hdr = (const TypedBlobHeader *)data;
    if (hdr->magic != TYPED_BLOB_MAGIC) { *consumed = 0; return NULL; }
    /* Accept both v2 and v3 */
    if (hdr->version != TYPED_BLOB_VER && hdr->version != 2) {
        *consumed = 0; return NULL;
    }

    numel = (size_t)hdr->rows * hdr->cols;

    /* ---- Numeric types ---- */
    if (hdr->class_id < TAG_CHAR) {
        mxClassID cid = (mxClassID)hdr->class_id;
        size_t elem_sz = class_element_size(cid);
        size_t data_bytes;
        if (elem_sz == 0) { *consumed = 0; return NULL; }
        data_bytes = numel * elem_sz;
        if (nbytes < TYPED_BLOB_HEADER_SIZE + data_bytes) {
            *consumed = 0; return NULL;
        }
        if (cid == mxDOUBLE_CLASS) {
            arr = mxCreateDoubleMatrix(hdr->rows, hdr->cols, mxREAL);
        } else {
            arr = mxCreateNumericMatrix(hdr->rows, hdr->cols, cid, mxREAL);
        }
        memcpy(mxGetData(arr), data + TYPED_BLOB_HEADER_SIZE, data_bytes);
        *consumed = TYPED_BLOB_HEADER_SIZE + data_bytes;
        return arr;
    }

    /* ---- Char ---- */
    if (hdr->class_id == TAG_CHAR) {
        size_t data_bytes = numel;
        mxChar *dest;
        size_t i;
        if (nbytes < TYPED_BLOB_HEADER_SIZE + data_bytes) {
            *consumed = 0; return NULL;
        }
        arr = mxCreateCharMatrixFromStrings(1, (const char *[]){""});
        /* Resize: create proper char matrix */
        mxDestroyArray(arr);
        arr = mxCreateCharArray(2, (mwSize[]){hdr->rows, hdr->cols});
        dest = mxGetChars(arr);
        for (i = 0; i < numel; i++) {
            dest[i] = (mxChar)data[TYPED_BLOB_HEADER_SIZE + i];
        }
        *consumed = TYPED_BLOB_HEADER_SIZE + data_bytes;
        return arr;
    }

    /* ---- Logical ---- */
    if (hdr->class_id == TAG_LOGICAL) {
        mxLogical *dest;
        size_t i;
        if (nbytes < TYPED_BLOB_HEADER_SIZE + numel) {
            *consumed = 0; return NULL;
        }
        arr = mxCreateLogicalMatrix(hdr->rows, hdr->cols);
        dest = mxGetLogicals(arr);
        for (i = 0; i < numel; i++) {
            dest[i] = data[TYPED_BLOB_HEADER_SIZE + i] ? 1 : 0;
        }
        *consumed = TYPED_BLOB_HEADER_SIZE + numel;
        return arr;
    }

    /* ---- Cell array ---- */
    if (hdr->class_id == TAG_CELL) {
        size_t i;
        arr = mxCreateCellMatrix(hdr->rows, hdr->cols);
        offset = TYPED_BLOB_HEADER_SIZE;

        for (i = 0; i < numel; i++) {
            uint32_t elem_len;
            if (offset + LEN_PREFIX_SIZE > nbytes) break;
            memcpy(&elem_len, data + offset, LEN_PREFIX_SIZE);
            offset += LEN_PREFIX_SIZE;
            if (elem_len == 0) {
                mxSetCell(arr, i, mxCreateDoubleMatrix(0, 0, mxREAL));
            } else {
                size_t elem_consumed = 0;
                mxArray *elem = deserialize_value(data + offset,
                                                  elem_len, &elem_consumed);
                if (elem) {
                    mxSetCell(arr, i, elem);
                } else {
                    mxSetCell(arr, i, mxCreateDoubleMatrix(0, 0, mxREAL));
                }
                offset += elem_len;
            }
        }
        *consumed = offset;
        return arr;
    }

    /* ---- Categorical / Struct ---- */
    if (hdr->class_id == TAG_CATEGORICAL) {
        uint32_t nfields_raw, f;
        offset = TYPED_BLOB_HEADER_SIZE;

        if (offset + LEN_PREFIX_SIZE > nbytes) { *consumed = 0; return NULL; }
        memcpy(&nfields_raw, data + offset, LEN_PREFIX_SIZE); offset += LEN_PREFIX_SIZE;

        /* Gather field names and values */
        const char **fnames = (const char **)mxMalloc(nfields_raw * sizeof(char *));
        char **fname_bufs = (char **)mxMalloc(nfields_raw * sizeof(char *));
        mxArray **fvals = (mxArray **)mxMalloc(nfields_raw * sizeof(mxArray *));

        for (f = 0; f < nfields_raw; f++) {
            uint32_t nlen, vlen;
            size_t val_consumed;

            if (offset + LEN_PREFIX_SIZE > nbytes) break;
            memcpy(&nlen, data + offset, LEN_PREFIX_SIZE); offset += LEN_PREFIX_SIZE;

            fname_bufs[f] = (char *)mxMalloc(nlen + 1);
            memcpy(fname_bufs[f], data + offset, nlen);
            fname_bufs[f][nlen] = '\0';
            fnames[f] = fname_bufs[f];
            offset += nlen;

            if (offset + LEN_PREFIX_SIZE > nbytes) break;
            memcpy(&vlen, data + offset, LEN_PREFIX_SIZE); offset += LEN_PREFIX_SIZE;

            if (vlen > 0) {
                val_consumed = 0;
                fvals[f] = deserialize_value(data + offset, vlen, &val_consumed);
                if (!fvals[f]) {
                    fvals[f] = mxCreateDoubleMatrix(0, 0, mxREAL);
                }
                offset += vlen;
            } else {
                fvals[f] = mxCreateDoubleMatrix(0, 0, mxREAL);
            }
        }

        arr = mxCreateStructMatrix(1, 1, nfields_raw, fnames);
        for (f = 0; f < nfields_raw; f++) {
            mxSetFieldByNumber(arr, 0, f, fvals[f]);
            mxFree(fname_bufs[f]);
        }
        mxFree(fnames);
        mxFree(fname_bufs);
        mxFree(fvals);

        *consumed = offset;
        return arr;
    }

    *consumed = 0;
    return NULL;
}

/* Convenience wrapper used by build_result (no consumed output needed) */
static mxArray *deserialize_blob(const void *data, int nbytes) {
    size_t consumed;
    return deserialize_value((const unsigned char *)data, (size_t)nbytes,
                             &consumed);
}

/* ================================================================
 *  PARAMETER BINDING
 * ================================================================ */

/* Serialize an mxArray, bind as BLOB, and free the buffer. */
static void bind_typed_blob(sqlite3_stmt *stmt, int idx,
                             void *(*serializer)(const mxArray *, size_t *),
                             const mxArray *param) {
    size_t blob_sz;
    void *blob = serializer(param, &blob_sz);
    sqlite3_bind_blob(stmt, idx, blob, (int)blob_sz, SQLITE_TRANSIENT);
    mxFree(blob);
}

static void bind_param(sqlite3_stmt *stmt, int idx, const mxArray *param,
                       int typed_blobs) {
    if (mxIsChar(param)) {
        if (typed_blobs && mxGetM(param) > 1) {
            bind_typed_blob(stmt, idx, serialize_char, param);
        } else {
            char *str = mxArrayToString(param);
            sqlite3_bind_text(stmt, idx, str, -1, SQLITE_TRANSIENT);
            mxFree(str);
        }
    } else if (mxIsEmpty(param)) {
        sqlite3_bind_null(stmt, idx);
    } else if (mxIsLogical(param)) {
        if (typed_blobs)
            bind_typed_blob(stmt, idx, serialize_logical, param);
        else
            sqlite3_bind_int(stmt, idx, mxIsLogicalScalarTrue(param) ? 1 : 0);
    } else if (mxIsCell(param) && typed_blobs) {
        bind_typed_blob(stmt, idx, serialize_cell, param);
    } else if (mxIsStruct(param) && typed_blobs) {
        bind_typed_blob(stmt, idx, serialize_struct, param);
    } else if (mxIsNumeric(param)) {
        if (typed_blobs && mxGetNumberOfElements(param) > 1)
            bind_typed_blob(stmt, idx, serialize_numeric, param);
        else
            sqlite3_bind_double(stmt, idx, mxGetScalar(param));
    } else {
        mexErrMsgIdAndTxt("mksqlite:unsupportedParam",
                          "Unsupported parameter type at position %d.", idx);
    }
}

/* ================================================================
 *  RESULT BUILDING
 * ================================================================ */

static mxArray *build_result(sqlite3_stmt *stmt, int typed_blobs) {
    int ncols = sqlite3_column_count(stmt);
    int capacity = 64;
    int nrows = 0;
    int i, j, rc;
    const char **col_names;
    mxArray ***cell_data;
    mxArray *result;

    if (ncols == 0) return mxCreateDoubleMatrix(0, 0, mxREAL);

    col_names = (const char **)mxMalloc(ncols * sizeof(char *));
    for (i = 0; i < ncols; i++) {
        col_names[i] = sqlite3_column_name(stmt, i);
    }

    cell_data = (mxArray ***)mxMalloc(ncols * sizeof(mxArray **));
    for (i = 0; i < ncols; i++) {
        cell_data[i] = (mxArray **)mxCalloc(capacity, sizeof(mxArray *));
    }

    do {
        if (nrows >= capacity) {
            capacity *= 2;
            for (i = 0; i < ncols; i++) {
                cell_data[i] = (mxArray **)mxRealloc(cell_data[i],
                                capacity * sizeof(mxArray *));
            }
        }
        for (i = 0; i < ncols; i++) {
            int ctype = sqlite3_column_type(stmt, i);
            switch (ctype) {
                case SQLITE_INTEGER:
                    cell_data[i][nrows] = mxCreateDoubleScalar(
                        (double)sqlite3_column_int64(stmt, i));
                    break;
                case SQLITE_FLOAT:
                    cell_data[i][nrows] = mxCreateDoubleScalar(
                        sqlite3_column_double(stmt, i));
                    break;
                case SQLITE_TEXT:
                    cell_data[i][nrows] = mxCreateString(
                        (const char *)sqlite3_column_text(stmt, i));
                    break;
                case SQLITE_BLOB: {
                    const void *bdata = sqlite3_column_blob(stmt, i);
                    int bsize = sqlite3_column_bytes(stmt, i);
                    mxArray *deserialized = NULL;
                    if (typed_blobs) {
                        deserialized = deserialize_blob(bdata, bsize);
                    }
                    if (deserialized) {
                        cell_data[i][nrows] = deserialized;
                    } else {
                        mxArray *u8 = mxCreateNumericMatrix(1, bsize,
                                                            mxUINT8_CLASS, mxREAL);
                        memcpy(mxGetData(u8), bdata, bsize);
                        cell_data[i][nrows] = u8;
                    }
                    break;
                }
                case SQLITE_NULL:
                default:
                    cell_data[i][nrows] = mxCreateDoubleMatrix(0, 0, mxREAL);
                    break;
            }
        }
        nrows++;
        rc = sqlite3_step(stmt);
    } while (rc == SQLITE_ROW);

    if (nrows == 0) {
        mxFree(col_names);
        for (i = 0; i < ncols; i++) mxFree(cell_data[i]);
        mxFree(cell_data);
        return mxCreateDoubleMatrix(0, 0, mxREAL);
    }

    result = mxCreateStructMatrix(1, nrows, ncols, col_names);
    for (i = 0; i < ncols; i++) {
        for (j = 0; j < nrows; j++) {
            mxSetFieldByNumber(result, j, i, cell_data[i][j]);
        }
    }

    mxFree(col_names);
    for (i = 0; i < ncols; i++) mxFree(cell_data[i]);
    mxFree(cell_data);
    return result;
}

/* ================================================================
 *  MEX ENTRY POINT
 * ================================================================ */

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[]) {
    char *cmd;
    int dbId, slot, rc, i;
    sqlite3 *db;
    sqlite3_stmt *stmt;
    const char *tail;

    if (nrhs < 1) {
        mexErrMsgIdAndTxt("mksqlite:nargs", "Not enough input arguments.");
    }

    /* ------ Case 1: mksqlite('open', filepath) ------ */
    if (mxIsChar(prhs[0])) {
        cmd = mxArrayToString(prhs[0]);

        if (strcmp(cmd, "open") == 0) {
            char *filepath;
            if (nrhs < 2 || !mxIsChar(prhs[1])) {
                mxFree(cmd);
                mexErrMsgIdAndTxt("mksqlite:args",
                                  "'open' requires a file path argument.");
            }
            filepath = mxArrayToString(prhs[1]);
            slot = find_free_slot();
            if (slot < 0) {
                mxFree(cmd);
                mxFree(filepath);
                mexErrMsgIdAndTxt("mksqlite:tooMany",
                                  "Maximum %d databases already open.", MAX_DBS);
            }
            rc = sqlite3_open(filepath, &g_dbs[slot]);
            if (rc != SQLITE_OK) {
                const char *msg = sqlite3_errmsg(g_dbs[slot]);
                sqlite3_close(g_dbs[slot]);
                g_dbs[slot] = NULL;
                mxFree(cmd);
                mxFree(filepath);
                mexErrMsgIdAndTxt("mksqlite:openFailed",
                                  "Cannot open database: %s", msg);
            }
            g_typed_blobs[slot] = 0;
            mxFree(filepath);
            mxFree(cmd);
            plhs[0] = mxCreateDoubleScalar((double)(slot + 1));
            return;
        }

        mxFree(cmd);
        mexErrMsgIdAndTxt("mksqlite:unknownCmd",
                          "Unknown command. First arg must be 'open' or a db handle.");
        return;
    }

    /* ------ Cases with dbId as first argument ------ */
    if (!mxIsNumeric(prhs[0]) || mxGetNumberOfElements(prhs[0]) != 1) {
        mexErrMsgIdAndTxt("mksqlite:badArg",
                          "First argument must be 'open' or a numeric db handle.");
    }

    dbId = (int)mxGetScalar(prhs[0]);
    check_db_id(dbId);
    slot = dbId - 1;
    db = g_dbs[slot];

    if (nrhs < 2 || !mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("mksqlite:args",
                          "Second argument must be a command string.");
    }

    cmd = mxArrayToString(prhs[1]);

    /* ------ Case 2: mksqlite(dbId, 'close') ------ */
    if (strcmp(cmd, "close") == 0) {
        sqlite3_close(g_dbs[slot]);
        g_dbs[slot] = NULL;
        g_typed_blobs[slot] = 0;
        mxFree(cmd);
        if (nlhs > 0) plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        return;
    }

    /* ------ Case 3: mksqlite(dbId, 'typedBLOBs', mode) ------ */
    if (strcmp(cmd, "typedBLOBs") == 0) {
        if (nrhs >= 3 && mxIsNumeric(prhs[2])) {
            g_typed_blobs[slot] = (int)mxGetScalar(prhs[2]);
        }
        mxFree(cmd);
        if (nlhs > 0) plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
        return;
    }

    /* ------ Cases 4 & 5: SQL execution ------ */
    rc = sqlite3_prepare_v2(db, cmd, -1, &stmt, &tail);
    if (rc != SQLITE_OK) {
        const char *msg = sqlite3_errmsg(db);
        mxFree(cmd);
        mexErrMsgIdAndTxt("mksqlite:sqlError", "SQL prepare error: %s", msg);
    }

    for (i = 2; i < nrhs; i++) {
        bind_param(stmt, i - 1, prhs[i], g_typed_blobs[slot]);
    }

    rc = sqlite3_step(stmt);

    if (rc == SQLITE_ROW) {
        mxArray *result = build_result(stmt, g_typed_blobs[slot]);
        sqlite3_finalize(stmt);
        mxFree(cmd);
        if (nlhs > 0) plhs[0] = result;
        else mxDestroyArray(result);
        return;
    }

    if (rc != SQLITE_DONE && rc != SQLITE_OK) {
        const char *msg = sqlite3_errmsg(db);
        sqlite3_finalize(stmt);
        mxFree(cmd);
        mexErrMsgIdAndTxt("mksqlite:sqlError", "SQL execution error: %s", msg);
    }

    sqlite3_finalize(stmt);
    mxFree(cmd);

    if (nlhs > 0) plhs[0] = mxCreateDoubleMatrix(0, 0, mxREAL);
}
