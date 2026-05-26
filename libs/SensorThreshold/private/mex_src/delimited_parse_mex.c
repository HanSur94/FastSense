/*
 * delimited_parse_mex.c — K1 SensorThreshold MEX kernel (Phase 1028 Wave 1).
 *
 *   out = delimited_parse_mex(path)
 *
 *     path — char vector; absolute or relative path to a delimited text file
 *
 *     out  — struct with fields (in this order):
 *              headers   — 1xN cellstr (column names) or {} when no header
 *              data      — MxN double matrix when every cell is numeric,
 *                          otherwise MxN cellstr (one char per cell)
 *              delimiter — char, the selected delimiter
 *              hasHeader — logical scalar
 *
 * Semantic contract (D-09): byte-equivalent output to libs/SensorThreshold/
 * private/readRawDelimited_.m. Asserted by tests/suite/TestDelimitedParseParity.
 *
 * Algorithm (mirrors the .m fallback step-for-step):
 *   1. Read the entire file into a heap buffer (mxMalloc).
 *   2. Sniff delimiter over the first <=5 non-empty lines:
 *        candidates {',', '\t', ';', ' '}, in that priority order;
 *        accept a candidate iff every sampled line splits to the SAME
 *        column count >=2; among the accepted ones, pick the candidate
 *        producing the LARGEST column count (ties -> earlier candidate).
 *        ' ' is whitespace mode: leading/trailing strip + run-collapse.
 *   3. Detect header: split first line; iff any non-empty trimmed token
 *      fails strtod-as-the-whole-cell, treat as header.
 *   4. First-pass numeric parse: try strtod each cell. If every non-empty
 *      cell parses, output a double matrix N×M, with empty cells -> NaN.
 *   5. If any cell fails numeric parse, do a second pass building a cell
 *      array of trimmed token strings (to mirror the .m %s textscan path).
 *   6. Empty-data validation: error TagPipeline:emptyFile when the data
 *      block has 0 rows (matches .m fallback errors at lines 78-85).
 *
 * Errors (namespace from CLAUDE.md §"Error Handling"):
 *   TagPipeline:fileNotReadable   — file missing or fopen failed
 *   TagPipeline:emptyFile         — 0 data rows after header skip
 *   TagPipeline:delimiterAmbiguous — no candidate delimiter passed sniff
 *
 * SIMD strategy: scalar byte loop. SIMD byte-scan via _mm256_cmpeq_epi8 /
 * vceqq_u8 is a deferred optimization — wired in only if profiling shows
 * the byte loop hot (RESEARCH.md §"Don't Hand-Roll" — keep the FSM small).
 *
 * Field order in the output struct MUST match the readRawDelimited_'s
 * struct() call at line 87 exactly: {'headers', 'data', 'delimiter',
 * 'hasHeader'} — this is asserted by the parity test via verifyEqual on
 * the structs as a whole.
 */

#include "mex.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <math.h>

/* TODO: SIMD byte-scan via _mm256_cmpeq_epi8 / vceqq_u8 if profile shows hot. */

/* ---------- Field-name table (must match .m struct() order) ---------- */
static const char *kFieldNames[4] = {"headers", "data", "delimiter", "hasHeader"};
static const int kNumFields = 4;

/* ---------- Helpers: file I/O ---------- */

static char *slurpFile_(const char *path, size_t *outLen)
{
    FILE *fp = fopen(path, "rb");
    if (!fp) {
        return NULL;
    }
    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return NULL;
    }
    long sz = ftell(fp);
    if (sz < 0) {
        fclose(fp);
        return NULL;
    }
    if (fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        return NULL;
    }
    char *buf = (char *)mxMalloc((size_t)sz + 1);
    if (!buf) {
        fclose(fp);
        return NULL;
    }
    size_t nread = fread(buf, 1, (size_t)sz, fp);
    fclose(fp);
    buf[nread] = '\0';
    *outLen = nread;
    return buf;
}

/* ---------- Helpers: line walking ---------- */

/*
 * findLineEnd_: scan from buf+start to first '\n' (or EOF).
 * Returns index of the '\n' or len when no terminator before EOF.
 * The line content is [start, lineEnd); CRLF is handled by stripCR_.
 */
static size_t findLineEnd_(const char *buf, size_t start, size_t len)
{
    size_t i = start;
    while (i < len && buf[i] != '\n') {
        i++;
    }
    return i;
}

/*
 * stripCR_: returns the effective line length excluding a trailing '\r'.
 */
static size_t stripCR_(const char *buf, size_t start, size_t end)
{
    if (end > start && buf[end - 1] == '\r') {
        return end - 1;
    }
    return end;
}

/*
 * isLineNonEmpty_: returns 1 if [start, end) contains any non-whitespace.
 * Mirrors strtrim(L) emptiness check from the .m fallback.
 */
static int isLineNonEmpty_(const char *buf, size_t start, size_t end)
{
    for (size_t i = start; i < end; i++) {
        unsigned char c = (unsigned char)buf[i];
        if (!isspace(c)) {
            return 1;
        }
    }
    return 0;
}

/* ---------- Helpers: token slicing ---------- */

/*
 * countTokens_ / writeTokens_: split [lineStart, lineEnd) by delim.
 * For delim==' ' the .m fallback uses strsplit(strtrim(line)) which
 * collapses runs of whitespace. We mirror that exactly: trim, then
 * split on any run of whitespace.
 *
 * For other delims, strsplit yields one token per delim hit (so two
 * adjacent delims -> one empty token between them, exactly as the .m
 * fallback observes).
 *
 * tokOff/tokLen point into the [lineStart, lineEnd) slice; tokens are
 * NOT null-terminated, callers must use the (off, len) tuple.
 *
 * Returns number of tokens.
 */
static size_t countAndSliceTokens_(const char *buf, size_t lineStart, size_t lineEnd,
                                   char delim,
                                   size_t *tokOff, size_t *tokLen, size_t maxTokens)
{
    if (lineStart >= lineEnd) {
        return 0;
    }

    if (delim == ' ') {
        /* Whitespace mode: trim leading + trailing, split on runs. */
        size_t s = lineStart, e = lineEnd;
        while (s < e && isspace((unsigned char)buf[s])) s++;
        while (e > s && isspace((unsigned char)buf[e - 1])) e--;
        if (s >= e) {
            return 0;
        }
        size_t cnt = 0;
        size_t i = s;
        while (i < e) {
            /* Skip ws */
            while (i < e && isspace((unsigned char)buf[i])) i++;
            if (i >= e) break;
            size_t tStart = i;
            while (i < e && !isspace((unsigned char)buf[i])) i++;
            if (cnt < maxTokens) {
                tokOff[cnt] = tStart;
                tokLen[cnt] = i - tStart;
            }
            cnt++;
        }
        return cnt;
    }

    /* Single-char delim mode: one token per delim, empties allowed. */
    size_t cnt = 0;
    size_t tStart = lineStart;
    for (size_t i = lineStart; i < lineEnd; i++) {
        if (buf[i] == delim) {
            if (cnt < maxTokens) {
                tokOff[cnt] = tStart;
                tokLen[cnt] = i - tStart;
            }
            cnt++;
            tStart = i + 1;
        }
    }
    /* Trailing token (the segment after the last delim, or whole line if no delim). */
    if (cnt < maxTokens) {
        tokOff[cnt] = tStart;
        tokLen[cnt] = lineEnd - tStart;
    }
    cnt++;
    return cnt;
}

/* Just count, used by the sniff phase when slot allocation isn't worth it. */
static size_t countTokens_(const char *buf, size_t lineStart, size_t lineEnd, char delim)
{
    if (lineStart >= lineEnd) {
        return 0;
    }
    if (delim == ' ') {
        size_t s = lineStart, e = lineEnd;
        while (s < e && isspace((unsigned char)buf[s])) s++;
        while (e > s && isspace((unsigned char)buf[e - 1])) e--;
        if (s >= e) return 0;
        size_t cnt = 0;
        size_t i = s;
        while (i < e) {
            while (i < e && isspace((unsigned char)buf[i])) i++;
            if (i >= e) break;
            while (i < e && !isspace((unsigned char)buf[i])) i++;
            cnt++;
        }
        return cnt;
    }
    size_t cnt = 1;
    for (size_t i = lineStart; i < lineEnd; i++) {
        if (buf[i] == delim) cnt++;
    }
    return cnt;
}

/* ---------- Helpers: trimmed-token utilities ---------- */

/*
 * trimToken_: produce trimmed bounds of token (off, len). Modifies in-place
 * via output params; does not mutate buf. Empty token after trim is allowed.
 */
static void trimToken_(const char *buf, size_t *off, size_t *len)
{
    size_t s = *off, e = *off + *len;
    while (s < e && isspace((unsigned char)buf[s])) s++;
    while (e > s && isspace((unsigned char)buf[e - 1])) e--;
    *off = s;
    *len = e - s;
}

/*
 * tryParseNumericToken_: returns 1 if the WHOLE trimmed token parses as
 * a finite or NaN double via strtod. Empty token returns 0 (mirror of
 * str2double('') -> NaN, but we capture that via NaN-on-empty in the
 * numeric pass — here we want "is this a numeric cell?" which the .m
 * uses to decide hasHeader).
 *
 * The .m fallback's detectHeader_ does:
 *   if isnan(str2double(tok)) -> non-numeric.
 * str2double('') returns NaN. So an empty trimmed token is treated as
 * non-numeric for the header-detect purpose. We mirror that here.
 *
 * On output, if outVal != NULL, write the parsed value (NaN for empty).
 */
static int tryParseNumericToken_(const char *buf, size_t off, size_t len, double *outVal)
{
    if (len == 0) {
        if (outVal) *outVal = mxGetNaN();
        return 0;  /* empty -> NaN -> "not numeric" for header detect */
    }
    /* strtod requires a null-terminated string; copy onto a small stack
     * buffer for short tokens, heap-fall back for long ones. */
    char small[64];
    char *cstr;
    int useHeap = 0;
    if (len < sizeof(small)) {
        cstr = small;
    } else {
        cstr = (char *)mxMalloc(len + 1);
        useHeap = 1;
    }
    memcpy(cstr, buf + off, len);
    cstr[len] = '\0';
    char *endp = NULL;
    double v = strtod(cstr, &endp);
    /* Whole-token consumption check: any trailing non-whitespace content
     * means the token isn't a clean number (matches str2double semantics
     * which returns NaN for "12abc" but accepts "12" and " 12 ").
     * Note: trimming was done by caller; endp must hit either '\0' or
     * pure trailing whitespace. */
    int allConsumed = 1;
    if (!endp || endp == cstr) {
        allConsumed = 0;
    } else {
        for (char *p = endp; *p != '\0'; p++) {
            if (!isspace((unsigned char)*p)) { allConsumed = 0; break; }
        }
    }
    if (useHeap) {
        mxFree(cstr);
    }
    if (allConsumed) {
        if (outVal) *outVal = v;
        return 1;
    }
    if (outVal) *outVal = mxGetNaN();
    return 0;
}

/* ---------- Sniff delimiter ---------- */

/*
 * sniffDelimiter_: returns 1 on success and writes the chosen delim;
 * returns 0 if no candidate produced consistent column counts >=2.
 */
static int sniffDelimiter_(const char *buf, size_t len, char *outDelim)
{
    static const char candidates[4] = {',', '\t', ';', ' '};
    const int nCand = 4;
    const int maxLines = 5;

    /* Collect first <=5 non-empty lines as (start, end) ranges. */
    size_t lineStart[5], lineEnd[5];
    int nLines = 0;
    size_t pos = 0;
    while (pos < len && nLines < maxLines) {
        size_t le = findLineEnd_(buf, pos, len);
        size_t effEnd = stripCR_(buf, pos, le);
        if (isLineNonEmpty_(buf, pos, effEnd)) {
            lineStart[nLines] = pos;
            lineEnd[nLines]   = effEnd;
            nLines++;
        }
        pos = (le < len) ? le + 1 : le;
    }
    if (nLines == 0) {
        return 0;
    }

    int bestIdx = -1;
    size_t bestScore = 0;  /* Highest column count among accepted candidates. */
    for (int k = 0; k < nCand; k++) {
        char d = candidates[k];
        size_t firstCount = countTokens_(buf, lineStart[0], lineEnd[0], d);
        int consistent = 1;
        for (int j = 1; j < nLines; j++) {
            size_t c = countTokens_(buf, lineStart[j], lineEnd[j], d);
            if (c != firstCount) {
                consistent = 0;
                break;
            }
        }
        if (consistent && firstCount >= 2) {
            /* The .m fallback uses `>` for the score update — first
             * candidate wins ties. Match that exactly. */
            if (firstCount > bestScore) {
                bestScore = firstCount;
                bestIdx = k;
            }
        }
    }

    if (bestIdx < 0) {
        return 0;
    }
    *outDelim = candidates[bestIdx];
    return 1;
}

/* ---------- Detect header ---------- */

/*
 * detectHeader_: 1 if any trimmed non-empty token of the first line fails
 * strtod-as-whole-cell. Mirrors readRawDelimited_:detectHeader_ exactly.
 *
 * NOTE: matches the .m fallback's quirk: an empty token is SKIPPED (not
 * counted as non-numeric) inside the first-line scan — see lines 191-194
 * of readRawDelimited_.m.
 */
static int detectHeader_(const char *buf, size_t lineStart, size_t lineEnd, char delim)
{
    /* Allocate a generous token slot list — we only need (off,len). */
    size_t maxToks = 1 + countTokens_(buf, lineStart, lineEnd, delim);
    size_t *tokOff = (size_t *)mxMalloc(maxToks * sizeof(size_t));
    size_t *tokLen = (size_t *)mxMalloc(maxToks * sizeof(size_t));
    size_t n = countAndSliceTokens_(buf, lineStart, lineEnd, delim,
                                    tokOff, tokLen, maxToks);
    int anyNonNumeric = 0;
    for (size_t i = 0; i < n; i++) {
        size_t off = tokOff[i], ln = tokLen[i];
        trimToken_(buf, &off, &ln);
        if (ln == 0) {
            continue;  /* empty token: skipped, matches .m */
        }
        if (!tryParseNumericToken_(buf, off, ln, NULL)) {
            anyNonNumeric = 1;
            break;
        }
    }
    mxFree(tokOff);
    mxFree(tokLen);
    return anyNonNumeric;
}

/* ---------- Build output ---------- */

/*
 * buildHeadersCellstr_: from the first line, produce a 1xN cellstr.
 * Each cell contains the trimmed token text. Caller transfers ownership
 * to the struct via mxSetField.
 */
static mxArray *buildHeadersCellstr_(const char *buf, size_t lineStart, size_t lineEnd,
                                     char delim, size_t nCols)
{
    mxArray *cell = mxCreateCellMatrix(1, (mwSize)nCols);
    size_t maxToks = 1 + countTokens_(buf, lineStart, lineEnd, delim);
    size_t *tokOff = (size_t *)mxMalloc(maxToks * sizeof(size_t));
    size_t *tokLen = (size_t *)mxMalloc(maxToks * sizeof(size_t));
    size_t n = countAndSliceTokens_(buf, lineStart, lineEnd, delim,
                                    tokOff, tokLen, maxToks);
    if (n > nCols) n = nCols;

    char *tmp = (char *)mxMalloc(1);  /* grown lazily */
    size_t tmpCap = 1;

    for (size_t i = 0; i < n; i++) {
        size_t off = tokOff[i], ln = tokLen[i];
        /* strsplit does NOT trim cells in the .m fallback (only sniff &
         * detectHeader_ trim per-token). However, the headers are passed
         * through strsplit unchanged. So we keep raw token bytes here. */
        if (ln + 1 > tmpCap) {
            tmpCap = ln + 1;
            tmp = (char *)mxRealloc(tmp, tmpCap);
        }
        memcpy(tmp, buf + off, ln);
        tmp[ln] = '\0';
        mxSetCell(cell, (mwIndex)i, mxCreateString(tmp));
    }
    mxFree(tmp);
    mxFree(tokOff);
    mxFree(tokLen);
    return cell;
}

/* ---------- mexFunction ---------- */

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    (void)nlhs;

    if (nrhs != 1) {
        mexErrMsgIdAndTxt("TagPipeline:invalidArgs",
            "delimited_parse_mex: expected one input (path).");
    }
    if (!mxIsChar(prhs[0])) {
        mexErrMsgIdAndTxt("TagPipeline:invalidArgs",
            "delimited_parse_mex: path must be char.");
    }

    char *path = mxArrayToString(prhs[0]);
    if (!path) {
        mexErrMsgIdAndTxt("TagPipeline:invalidArgs",
            "delimited_parse_mex: cannot convert path to string.");
    }

    size_t bufLen = 0;
    char *buf = slurpFile_(path, &bufLen);
    if (!buf) {
        mxFree(path);
        mexErrMsgIdAndTxt("TagPipeline:fileNotReadable",
            "Cannot open: %s", path ? path : "(null)");
    }

    /* ---------- Sniff delimiter ---------- */
    char delim = ',';
    if (!sniffDelimiter_(buf, bufLen, &delim)) {
        char savedPath[1024];
        strncpy(savedPath, path, sizeof(savedPath) - 1);
        savedPath[sizeof(savedPath) - 1] = '\0';
        mxFree(buf);
        mxFree(path);
        mexErrMsgIdAndTxt("TagPipeline:delimiterAmbiguous",
            "Could not determine delimiter for: %s", savedPath);
    }

    /* ---------- Find first non-empty line for header detection ---------- */
    size_t firstLineStart = 0, firstLineEnd = 0;
    int haveFirstLine = 0;
    {
        size_t pos = 0;
        while (pos < bufLen) {
            size_t le = findLineEnd_(buf, pos, bufLen);
            size_t effEnd = stripCR_(buf, pos, le);
            if (effEnd > pos) {
                /* The .m fallback keys the header detect on the FIRST
                 * call of fgetl which returns the raw first physical line
                 * (including trailing whitespace-only lines, where ischar
                 * still holds). It does NOT skip empty lines for
                 * detectHeader_. We mirror that — first PHYSICAL line. */
                firstLineStart = pos;
                firstLineEnd = effEnd;
                haveFirstLine = 1;
                break;
            }
            /* The .m fallback errors on the FIRST fgetl returning -1.
             * Empty lines (just '\n') would cause fgetl to return ''.
             * In that case ischar is true and emptyFile is NOT raised. */
            if (le > pos) {
                /* Empty physical line (e.g., bare '\n'). The .m fallback
                 * treats this as a valid first line == ''. detectHeader_
                 * on '' would split to one empty token -> skipped ->
                 * anyNonNumeric=false -> hasHeader=false. We replicate
                 * by selecting this empty line. */
                firstLineStart = pos;
                firstLineEnd = pos;  /* zero-length */
                haveFirstLine = 1;
                break;
            }
            pos = le + 1;
        }
    }

    if (!haveFirstLine) {
        char savedPath[1024];
        strncpy(savedPath, path, sizeof(savedPath) - 1);
        savedPath[sizeof(savedPath) - 1] = '\0';
        mxFree(buf);
        mxFree(path);
        mexErrMsgIdAndTxt("TagPipeline:emptyFile",
            "File is empty: %s", savedPath);
    }

    int hasHeader = detectHeader_(buf, firstLineStart, firstLineEnd, delim);

    /* nCols = column count of the first line under the chosen delim. */
    size_t nCols = countTokens_(buf, firstLineStart, firstLineEnd, delim);
    if (nCols < 1) {
        char savedPath[1024];
        strncpy(savedPath, path, sizeof(savedPath) - 1);
        savedPath[sizeof(savedPath) - 1] = '\0';
        mxFree(buf);
        mxFree(path);
        mexErrMsgIdAndTxt("TagPipeline:emptyFile",
            "File has no columns: %s", savedPath);
    }

    /* ---------- Walk all data rows ---------- */
    /* The .m fallback's countDataRows_ counts non-empty trimmed lines,
     * skipping the FIRST non-empty line if hasHeader. We mirror that
     * exactly. */

    /* First pass: count + capture line offsets so the second pass is
     * fast. We over-allocate then realloc on the realised count. */
    size_t cap = 64, nDataRows = 0;
    size_t *rowStart = (size_t *)mxMalloc(cap * sizeof(size_t));
    size_t *rowEnd   = (size_t *)mxMalloc(cap * sizeof(size_t));
    {
        size_t pos = 0;
        int seenFirstNonEmpty = 0;
        while (pos < bufLen) {
            size_t le = findLineEnd_(buf, pos, bufLen);
            size_t effEnd = stripCR_(buf, pos, le);
            if (isLineNonEmpty_(buf, pos, effEnd)) {
                if (!seenFirstNonEmpty && hasHeader) {
                    seenFirstNonEmpty = 1;
                } else {
                    seenFirstNonEmpty = 1;
                    if (nDataRows >= cap) {
                        cap *= 2;
                        rowStart = (size_t *)mxRealloc(rowStart, cap * sizeof(size_t));
                        rowEnd   = (size_t *)mxRealloc(rowEnd,   cap * sizeof(size_t));
                    }
                    rowStart[nDataRows] = pos;
                    rowEnd[nDataRows]   = effEnd;
                    nDataRows++;
                }
            }
            pos = (le < bufLen) ? le + 1 : le;
        }
    }

    /* Empty-data error (matches .m lines 78-85). */
    if (nDataRows == 0) {
        char savedPath[1024];
        strncpy(savedPath, path, sizeof(savedPath) - 1);
        savedPath[sizeof(savedPath) - 1] = '\0';
        mxFree(rowStart);
        mxFree(rowEnd);
        mxFree(buf);
        mxFree(path);
        mexErrMsgIdAndTxt("TagPipeline:emptyFile",
            "No data rows after header skip: %s", savedPath);
    }

    /* ---------- Numeric first-pass parse ---------- */
    /* We try numeric parse over every (row, col) pair. If ANY cell fails,
     * we fall back to the cellstr representation. The .m fallback path
     * activates the cellstr branch when textscan with %f produces fewer
     * rows than expectedRows; here we predicate on per-cell strtod
     * success which is functionally equivalent for well-formed inputs. */

    int allNumeric = 1;
    double *numericData = (double *)mxMalloc(nDataRows * nCols * sizeof(double));
    /* Pre-allocate token slots for the widest row we might see. */
    size_t maxToksPerRow = nCols + 4;
    size_t *tokOff = (size_t *)mxMalloc(maxToksPerRow * sizeof(size_t));
    size_t *tokLen = (size_t *)mxMalloc(maxToksPerRow * sizeof(size_t));

    for (size_t r = 0; r < nDataRows && allNumeric; r++) {
        size_t physTokens = countTokens_(buf, rowStart[r], rowEnd[r], delim);
        if (physTokens > maxToksPerRow) {
            maxToksPerRow = physTokens + 4;
            tokOff = (size_t *)mxRealloc(tokOff, maxToksPerRow * sizeof(size_t));
            tokLen = (size_t *)mxRealloc(tokLen, maxToksPerRow * sizeof(size_t));
        }
        size_t n = countAndSliceTokens_(buf, rowStart[r], rowEnd[r], delim,
                                        tokOff, tokLen, maxToksPerRow);
        for (size_t c = 0; c < nCols; c++) {
            double v;
            if (c < n) {
                size_t off = tokOff[c], ln = tokLen[c];
                trimToken_(buf, &off, &ln);
                if (ln == 0) {
                    /* textscan %f converts an empty token to NaN — keep
                     * "all numeric" but record NaN. */
                    v = mxGetNaN();
                } else {
                    if (!tryParseNumericToken_(buf, off, ln, &v)) {
                        allNumeric = 0;
                        break;
                    }
                }
            } else {
                /* Row had fewer tokens than nCols: textscan would treat
                 * as missing → but textscan with CollectOutput=true and
                 * a fixed format would actually fail / produce truncated
                 * output. Treat as non-numeric to fall back to cellstr,
                 * matching the .m fallback's "fewer rows than expected"
                 * branch. */
                allNumeric = 0;
                break;
            }
            /* MATLAB column-major: numericData[c * nDataRows + r] */
            numericData[c * nDataRows + r] = v;
        }
    }

    mxArray *headersCell;
    if (hasHeader) {
        headersCell = buildHeadersCellstr_(buf, firstLineStart, firstLineEnd,
                                           delim, nCols);
    } else {
        /* The .m fallback's `headers = {};` evaluates to a 0x0 cell, not
         * 1x0. Match that exactly so isequal(out.headers, {}) passes. */
        headersCell = mxCreateCellMatrix(0, 0);
    }

    mxArray *dataMx;
    if (allNumeric) {
        dataMx = mxCreateDoubleMatrix((mwSize)nDataRows, (mwSize)nCols, mxREAL);
        memcpy(mxGetPr(dataMx), numericData,
               nDataRows * nCols * sizeof(double));
    } else {
        /* Second pass: build a cellstr (one MxN cell of trimmed-token
         * char arrays). The .m fallback with %s passes through textscan
         * which yields trimmed cellstr — we mirror that. */
        dataMx = mxCreateCellMatrix((mwSize)nDataRows, (mwSize)nCols);
        char *tmp = (char *)mxMalloc(1);
        size_t tmpCap = 1;
        for (size_t r = 0; r < nDataRows; r++) {
            size_t physTokens = countTokens_(buf, rowStart[r], rowEnd[r], delim);
            if (physTokens > maxToksPerRow) {
                maxToksPerRow = physTokens + 4;
                tokOff = (size_t *)mxRealloc(tokOff, maxToksPerRow * sizeof(size_t));
                tokLen = (size_t *)mxRealloc(tokLen, maxToksPerRow * sizeof(size_t));
            }
            size_t n = countAndSliceTokens_(buf, rowStart[r], rowEnd[r], delim,
                                            tokOff, tokLen, maxToksPerRow);
            for (size_t c = 0; c < nCols; c++) {
                size_t off = 0, ln = 0;
                if (c < n) {
                    off = tokOff[c];
                    ln  = tokLen[c];
                    trimToken_(buf, &off, &ln);  /* %s textscan trims */
                }
                if (ln + 1 > tmpCap) {
                    tmpCap = ln + 1;
                    tmp = (char *)mxRealloc(tmp, tmpCap);
                }
                memcpy(tmp, buf + off, ln);
                tmp[ln] = '\0';
                /* MATLAB column-major linear index: c * nDataRows + r. */
                mxSetCell(dataMx, (mwIndex)(c * nDataRows + r),
                          mxCreateString(tmp));
            }
        }
        mxFree(tmp);
    }

    /* ---------- Build output struct ---------- */
    plhs[0] = mxCreateStructMatrix(1, 1, kNumFields, kFieldNames);
    mxSetField(plhs[0], 0, "headers",   headersCell);
    mxSetField(plhs[0], 0, "data",      dataMx);

    char delimStr[2] = {delim, '\0'};
    mxSetField(plhs[0], 0, "delimiter", mxCreateString(delimStr));
    mxSetField(plhs[0], 0, "hasHeader", mxCreateLogicalScalar(hasHeader != 0));

    /* ---------- Cleanup ---------- */
    mxFree(numericData);
    mxFree(tokOff);
    mxFree(tokLen);
    mxFree(rowStart);
    mxFree(rowEnd);
    mxFree(buf);
    mxFree(path);
}
