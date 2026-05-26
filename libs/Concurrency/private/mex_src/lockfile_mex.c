/* lockfile_mex.c — Cross-platform advisory file locks for FastSense v4.0
 *
 * Commands:
 *   handle = lockfile_mex('acquire', lockPath, timeoutSec)
 *   ok     = lockfile_mex('release', handle)
 *   info   = lockfile_mex('status',  lockPath)
 *   info   = lockfile_mex('probe')
 *
 * Self-deadlock prevention (Unknown 3 / PITFALLS B):
 *   A static C-level table maps absolute lockPath -> open FD/HANDLE.
 *   Re-acquire of a path already in the table returns int64(-1) immediately.
 *
 * Branching:
 *   Windows (_WIN32): LockFileEx (LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY)
 *   Linux 3.15+ w/ F_OFD_SETLK: OFD locks (build with -D_GNU_SOURCE)
 *   macOS / older Linux: plain F_SETLK (DEV ONLY — Pitfall 1 caveat)
 */

#define _GNU_SOURCE   /* required for F_OFD_SETLK on glibc */
#include "mex.h"
#include <string.h>
#include <stdint.h>
#include <stdlib.h>

#ifdef _WIN32
    #include <windows.h>
    #include <io.h>
    #define LF_HANDLE  HANDLE
    #define LF_INVALID INVALID_HANDLE_VALUE
#else
    #include <fcntl.h>
    #include <unistd.h>
    #include <errno.h>
    #include <sys/stat.h>
    #include <sys/utsname.h>
    #include <time.h>
    #define LF_HANDLE  int
    #define LF_INVALID (-1)
#endif

/* Compile-time branch detection */
#if defined(__linux__) && defined(F_OFD_SETLK)
    #define LF_BRANCH "ofd"
    #define LF_OS "linux"
    #define LF_USE_OFD 1
#elif defined(_WIN32)
    #define LF_BRANCH "lockfileex"
    #define LF_OS "windows"
    #define LF_USE_WIN32 1
#else
    #define LF_BRANCH "fsetlk"
    #if defined(__APPLE__)
        #define LF_OS "darwin"
    #else
        #define LF_OS "linux"
    #endif
    #define LF_USE_FSETLK 1
#endif

/* Pitfall A defense: warn if on Linux without OFD locks */
#if defined(__linux__) && !defined(F_OFD_SETLK)
#warning "Building on Linux without F_OFD_SETLK -- falling back to F_SETLK. Build with -D_GNU_SOURCE for OFD locks."
#endif

/* ===========================================================================
 * Static FD table — in-process lock tracking (Unknown 3 self-deadlock fix)
 * =========================================================================== */

#define LF_TABLE_CAPACITY 64

typedef struct {
    char       path[1024];   /* absolute lock path */
    LF_HANDLE  handle;       /* OS file handle / fd */
    int64_t    token;        /* monotonic token (1-based; 0 = empty slot) */
} LfEntry;

static LfEntry   lf_fdTable[LF_TABLE_CAPACITY];
static int       lf_tableInit = 0;
static int64_t   lf_tokenCounter = 0;

static void lf_init_table(void)
{
    int i;
    if (lf_tableInit) return;
    for (i = 0; i < LF_TABLE_CAPACITY; i++) {
        lf_fdTable[i].path[0] = '\0';
#ifdef _WIN32
        lf_fdTable[i].handle = INVALID_HANDLE_VALUE;
#else
        lf_fdTable[i].handle = -1;
#endif
        lf_fdTable[i].token = 0;
    }
    lf_tableInit = 1;
}

/* Returns non-zero token if path is already in table, 0 if not found */
static int64_t lf_table_find(const char *path)
{
    int i;
    lf_init_table();
    for (i = 0; i < LF_TABLE_CAPACITY; i++) {
        if (lf_fdTable[i].token != 0 && strcmp(lf_fdTable[i].path, path) == 0) {
            return lf_fdTable[i].token;
        }
    }
    return 0;
}

/* Insert path+handle; returns new token, or 0 on table full */
static int64_t lf_table_insert(const char *path, LF_HANDLE handle)
{
    int i;
    lf_init_table();
    for (i = 0; i < LF_TABLE_CAPACITY; i++) {
        if (lf_fdTable[i].token == 0) {
            lf_tokenCounter++;
            strncpy(lf_fdTable[i].path, path, sizeof(lf_fdTable[i].path) - 1);
            lf_fdTable[i].path[sizeof(lf_fdTable[i].path) - 1] = '\0';
            lf_fdTable[i].handle = handle;
            lf_fdTable[i].token = lf_tokenCounter;
            return lf_tokenCounter;
        }
    }
    return 0; /* table full */
}

/* Remove entry by token; returns the handle (or LF_INVALID if not found) */
static LF_HANDLE lf_table_remove_by_token(int64_t token)
{
    int i;
    lf_init_table();
    for (i = 0; i < LF_TABLE_CAPACITY; i++) {
        if (lf_fdTable[i].token == token) {
            LF_HANDLE h = lf_fdTable[i].handle;
            lf_fdTable[i].path[0] = '\0';
#ifdef _WIN32
            lf_fdTable[i].handle = INVALID_HANDLE_VALUE;
#else
            lf_fdTable[i].handle = -1;
#endif
            lf_fdTable[i].token = 0;
            return h;
        }
    }
    return LF_INVALID;
}

/* ===========================================================================
 * Platform helpers: absolute path resolution
 * =========================================================================== */

static int lf_resolve_path(const char *in, char *out, size_t outlen)
{
#ifdef _WIN32
    if (_fullpath(out, in, (int)outlen) == NULL) {
        strncpy(out, in, outlen - 1);
        out[outlen - 1] = '\0';
    }
    return 1;
#else
    /* realpath requires the file to exist; for new lockfiles fall back to input */
    if (realpath(in, out) == NULL) {
        strncpy(out, in, outlen - 1);
        out[outlen - 1] = '\0';
    }
    return 1;
#endif
}

/* ===========================================================================
 * Command: 'acquire'
 * handle = lockfile_mex('acquire', lockPath, timeoutSec)
 * Returns int64 token (>0) on success, int64(-1) on failure.
 * =========================================================================== */

static mxArray *cmd_acquire(int nrhs, const mxArray *prhs[])
{
    char   inPath[1024];
    char   absPath[1024];
    double timeoutSec;
    mxArray *out;
    int64_t *pOut;

    if (nrhs < 3) {
        mexErrMsgIdAndTxt("Concurrency:lockfileMexBadArgs",
            "acquire requires 3 args: lockfile_mex('acquire', path, timeoutSec).");
    }
    if (!mxIsChar(prhs[1])) {
        mexErrMsgIdAndTxt("Concurrency:lockfileMexBadArgs", "lockPath must be a char string.");
    }

    mxGetString(prhs[1], inPath, sizeof(inPath));
    timeoutSec = mxGetScalar(prhs[2]);

    lf_resolve_path(inPath, absPath, sizeof(absPath));

    /* Self-deadlock check (Unknown 3) */
    if (lf_table_find(absPath) != 0) {
        out = mxCreateNumericMatrix(1, 1, mxINT64_CLASS, mxREAL);
        pOut = (int64_t *)mxGetData(out);
        *pOut = (int64_t)(-1);
        return out;
    }

    {
        /* Platform-specific acquire loop */
        int acquired = 0;
        LF_HANDLE handle = LF_INVALID;
        double elapsed = 0.0;
        double pollInterval = 0.05; /* 50 ms */

#ifdef _WIN32
        OVERLAPPED ov;
        HANDLE hFile = CreateFileA(absPath,
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE,
            NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
        if (hFile == INVALID_HANDLE_VALUE) {
            out = mxCreateNumericMatrix(1, 1, mxINT64_CLASS, mxREAL);
            pOut = (int64_t *)mxGetData(out);
            *pOut = (int64_t)(-1);
            return out;
        }
        handle = hFile;
        while (1) {
            memset(&ov, 0, sizeof(ov));
            if (LockFileEx(hFile, LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
                           0, 1, 0, &ov)) {
                acquired = 1;
                break;
            }
            /* Failed */
            if (elapsed >= timeoutSec) break;
            Sleep((DWORD)(pollInterval * 1000.0));
            elapsed += pollInterval;
        }
        if (!acquired) {
            CloseHandle(hFile);
        }

#else
        struct flock fl;
        int fd = open(absPath, O_RDWR | O_CREAT, 0644);
        if (fd < 0) {
            out = mxCreateNumericMatrix(1, 1, mxINT64_CLASS, mxREAL);
            pOut = (int64_t *)mxGetData(out);
            *pOut = (int64_t)(-1);
            return out;
        }
        handle = fd;
        memset(&fl, 0, sizeof(fl));
        fl.l_type   = F_WRLCK;
        fl.l_whence = SEEK_SET;
        fl.l_start  = 0;
        fl.l_len    = 0;  /* whole file */

        while (1) {
#if defined(LF_USE_OFD)
            int ret = fcntl(fd, F_OFD_SETLK, &fl);
#else
            int ret = fcntl(fd, F_SETLK, &fl);
#endif
            if (ret == 0) {
                acquired = 1;
                break;
            }
            /* EWOULDBLOCK / EAGAIN = lock held by another */
            if (errno != EWOULDBLOCK && errno != EAGAIN) break; /* other error */
            if (elapsed >= timeoutSec) break;
            {
                struct timespec ts;
                ts.tv_sec  = 0;
                ts.tv_nsec = (long)(pollInterval * 1e9);
                nanosleep(&ts, NULL);
            }
            elapsed += pollInterval;
        }
        if (!acquired) {
            close(fd);
        }
#endif

        out = mxCreateNumericMatrix(1, 1, mxINT64_CLASS, mxREAL);
        pOut = (int64_t *)mxGetData(out);
        if (acquired) {
            int64_t token = lf_table_insert(absPath, handle);
            if (token == 0) {
                /* Table full — release and return -1 */
#ifdef _WIN32
                OVERLAPPED ov2;
                memset(&ov2, 0, sizeof(ov2));
                UnlockFileEx(hFile, 0, 1, 0, &ov2);
                CloseHandle(hFile);
#else
                struct flock fl2;
                memset(&fl2, 0, sizeof(fl2));
                fl2.l_type   = F_UNLCK;
                fl2.l_whence = SEEK_SET;
                fl2.l_start  = 0;
                fl2.l_len    = 0;
#if defined(LF_USE_OFD)
                fcntl(fd, F_OFD_SETLK, &fl2);
#else
                fcntl(fd, F_SETLK, &fl2);
#endif
                close(fd);
#endif
                *pOut = (int64_t)(-1);
            } else {
                *pOut = token;
            }
        } else {
            *pOut = (int64_t)(-1);
        }
        return out;
    }
}

/* ===========================================================================
 * Command: 'release'
 * ok = lockfile_mex('release', handle)
 * Returns logical true on success, false if handle unknown.
 * =========================================================================== */

static mxArray *cmd_release(int nrhs, const mxArray *prhs[])
{
    int64_t token;
    LF_HANDLE h;

    if (nrhs < 2) {
        mexErrMsgIdAndTxt("Concurrency:lockfileMexBadArgs",
            "release requires 2 args: lockfile_mex('release', handle).");
    }

    /* Handle can be int64 or double; coerce to int64 */
    if (mxIsInt64(prhs[1])) {
        token = *(int64_t *)mxGetData(prhs[1]);
    } else {
        token = (int64_t)mxGetScalar(prhs[1]);
    }

    h = lf_table_remove_by_token(token);
    if (h == LF_INVALID) {
        return mxCreateLogicalScalar(0);
    }

#ifdef _WIN32
    {
        OVERLAPPED ov;
        memset(&ov, 0, sizeof(ov));
        UnlockFileEx(h, 0, 1, 0, &ov);
        CloseHandle(h);
    }
#else
    {
        struct flock fl;
        memset(&fl, 0, sizeof(fl));
        fl.l_type   = F_UNLCK;
        fl.l_whence = SEEK_SET;
        fl.l_start  = 0;
        fl.l_len    = 0;
#if defined(LF_USE_OFD)
        fcntl(h, F_OFD_SETLK, &fl);
#else
        fcntl(h, F_SETLK, &fl);
#endif
        close(h);
    }
#endif

    return mxCreateLogicalScalar(1);
}

/* ===========================================================================
 * Command: 'status'
 * info = lockfile_mex('status', lockPath)
 * Returns struct with field 'held' (logical). Best-effort.
 * =========================================================================== */

static mxArray *cmd_status(int nrhs, const mxArray *prhs[])
{
    const char *fields[] = { "held" };
    mxArray *out = mxCreateStructMatrix(1, 1, 1, fields);
    mxArray *heldVal;
    char inPath[1024];
    char absPath[1024];

    if (nrhs < 2) {
        mexErrMsgIdAndTxt("Concurrency:lockfileMexBadArgs",
            "status requires 2 args: lockfile_mex('status', path).");
    }
    mxGetString(prhs[1], inPath, sizeof(inPath));
    lf_resolve_path(inPath, absPath, sizeof(absPath));

    /* Check if WE hold it via our table */
    if (lf_table_find(absPath) != 0) {
        mxSetField(out, 0, "held", mxCreateLogicalScalar(1));
        return out;
    }

#if defined(LF_USE_OFD)
    {
        /* Linux OFD: open read-only and use F_OFD_GETLK */
        int fd = open(absPath, O_RDONLY);
        if (fd < 0) {
            mxSetField(out, 0, "held", mxCreateLogicalScalar(0));
            return out;
        }
        {
            struct flock fl;
            memset(&fl, 0, sizeof(fl));
            fl.l_type   = F_RDLCK;
            fl.l_whence = SEEK_SET;
            fl.l_start  = 0;
            fl.l_len    = 0;
            if (fcntl(fd, F_OFD_GETLK, &fl) == 0 && fl.l_type != F_UNLCK) {
                heldVal = mxCreateLogicalScalar(1);
            } else {
                heldVal = mxCreateLogicalScalar(0);
            }
        }
        close(fd);
        mxSetField(out, 0, "held", heldVal);
    }
#else
    /* macOS / Windows: best-effort — return held=false (caller inspects lock body) */
    mxSetField(out, 0, "held", mxCreateLogicalScalar(0));
#endif

    return out;
}

/* ===========================================================================
 * Command: 'probe'
 * info = lockfile_mex('probe')
 * Returns struct with fields: branch, os, pid [, kernel on Linux]
 * =========================================================================== */

static mxArray *cmd_probe(void)
{
    mxArray *out;
    int64_t *pidPtr;
    mxArray *pidVal;

#if defined(LF_USE_OFD)
    const char *fields[] = { "branch", "os", "pid", "kernel" };
    out = mxCreateStructMatrix(1, 1, 4, fields);
#else
    const char *fields[] = { "branch", "os", "pid" };
    out = mxCreateStructMatrix(1, 1, 3, fields);
#endif

    mxSetField(out, 0, "branch", mxCreateString(LF_BRANCH));
    mxSetField(out, 0, "os",     mxCreateString(LF_OS));

    pidVal = mxCreateNumericMatrix(1, 1, mxINT64_CLASS, mxREAL);
    pidPtr = (int64_t *)mxGetData(pidVal);
#ifdef _WIN32
    *pidPtr = (int64_t)GetCurrentProcessId();
#else
    *pidPtr = (int64_t)getpid();
#endif
    mxSetField(out, 0, "pid", pidVal);

#if defined(LF_USE_OFD)
    {
        struct utsname u;
        if (uname(&u) == 0) {
            mxSetField(out, 0, "kernel", mxCreateString(u.release));
        } else {
            mxSetField(out, 0, "kernel", mxCreateString("unknown"));
        }
    }
#endif

    return out;
}

/* ===========================================================================
 * MEX entry point
 * =========================================================================== */

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    char cmd[32];

    if (nrhs < 1 || !mxIsChar(prhs[0])) {
        mexErrMsgIdAndTxt("Concurrency:lockfileMexBadArgs",
            "First argument must be a command string: 'acquire'|'release'|'status'|'probe'.");
    }

    mxGetString(prhs[0], cmd, sizeof(cmd));

    if (strcmp(cmd, "acquire") == 0) {
        plhs[0] = cmd_acquire(nrhs, prhs);
    } else if (strcmp(cmd, "release") == 0) {
        plhs[0] = cmd_release(nrhs, prhs);
    } else if (strcmp(cmd, "status") == 0) {
        plhs[0] = cmd_status(nrhs, prhs);
    } else if (strcmp(cmd, "probe") == 0) {
        plhs[0] = cmd_probe();
    } else {
        mexErrMsgIdAndTxt("Concurrency:lockfileMexBadCmd",
            "Unknown command '%s'. Valid commands: 'acquire', 'release', 'status', 'probe'.", cmd);
    }
}
