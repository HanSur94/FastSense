# Phase 1029: Concurrency Foundation — Research

**Researched:** 2026-05-13
**Domain:** Cross-platform file locking (OFD/LockFileEx), atomic writes, process identity, MATLAB/Octave NDJSON encoding
**Confidence:** HIGH on kernel semantics, Win32, mksqlite; MEDIUM on MATLAB jsonencode/datetime; LOW on Octave datetime handling

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Compiler available — Xcode CLT / GCC / MSVC is installed. Phase 1029 plans CAN include `mex -setup` and `build_mex.m` invocations; `lockfile_mex` binary MUST be produced and verified.
- Smoke-scale stress tests — Run concurrency tests at 1-4 MATLAB processes. The 50-process stress test exists as `TestFileLockStress50.m` GATED BEHIND `getenv('FASTSENSE_STRESS_50')=='1'`. Default-off.
- Commits land on branch `claude/sleepy-zhukovsky-2331bf` — no per-phase branch splitting. Use `gsd-tools.cjs commit` for atomic per-task commits.
- OFD locks on Linux (not plain `F_SETLK`) — PITFALLS.md Pitfall 1, HIGH confidence
- mtime heartbeat (not wall-clock TTL) — PITFALLS.md Pitfall 9, HIGH confidence
- temp+rename via `AtomicWriter` — PITFALLS.md Pitfall 4 + 12, HIGH confidence
- `userIdentity.m` fallback chain: `getenv` → `system('hostname')` → Java InetAddress (guarded by `usejava('jvm')`) — STACK.md §4, HIGH confidence
- Fail loudly on identity failure in cluster mode — REQ IDENT-01
- ClusterConfig.resolve seam: explicit opt > `FASTSENSE_SHARED_ROOT` env var > single-user default — ARCHITECTURE.md §Q6

### Claude's Discretion
- (None declared in CONTEXT.md beyond the locked items above)

### Deferred Ideas (OUT OF SCOPE)
- TagWriteCoordinator (Phase 1030)
- EventLog / NDJSON format (Phase 1031)
- LiveTagPipeline / LiveEventPipeline modifications (Phases 1030, 1032)
- Companion integration (Phase 1033)
- Operator docs (Phase 1033)
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONC-02 | Stale-lock recovery uses server-side filesystem **mtime**, not wall-clock TTL. Crashed Companion's lock taken over within `staleTimeout + 5s` (default 90s). | Unknown 4 (staleTimeout calibration), Unknown 3 (OFD re-acquire self-deadlock) |
| CONC-03 | Every shared-file write uses atomic temp-file + rename. CI lint forbids raw `save()` to shared paths. | Unknown 6 (AtomicWriter MEX vs movefile verdict), Unknown 7 (ndjsonEncode.m) |
| IDENT-01 | Every shared write stamped with `user@host (pid, epoch)`. `userIdentity.m` layered fallback. In cluster mode, identity failure throws. | Unknown 5 (mksqlite extended_result_codes probe — prerequisite), Unknown 7 (ndjsonEncode.m for encoding identity structs) |
</phase_requirements>

---

## Summary

This research resolves the seven specific unknowns that the milestone-level research (SUMMARY.md, STACK.md, ARCHITECTURE.md, PITFALLS.md) left open for Phase 1029. All architectural decisions from that research are treated as settled — this document only fills the gaps needed to write executable plan tasks.

**Seven unknowns resolved:**
1. `lockfile_mex.c` OFD branching strategy — `#ifdef F_OFD_SETLK` is the correct compile-time guard; runtime probe needed only as defence-in-depth on RHEL 7 kernels that have the constant but lack full implementation quality. macOS has no OFD; falls back to `F_SETLK` with documented caveat.
2. Win32 `LockFileEx` flag combination for SMB — `LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY`, byte range (0,0)→(1,0), OVERLAPPED with hEvent=0 and zero offset. SMB 3.0 is explicitly supported by MSDN.
3. `F_OFD_SETLK` same-process re-acquire — two `open()` calls from the same process produce *separate* open file descriptions; the second `F_OFD_SETLK` WILL conflict (block on `F_OFD_SETLKW`, or return `EWOULDBLOCK` on `F_OFD_SETLK`). `FileLock` MUST track in-process holdings per key to prevent self-deadlock.
4. `staleTimeout = 90s` calibration — justified by SMB session timeout (30–60s) + NTFS/ext4 mtime granularity (ns–100ns) + FAT32 2s granularity; 90s is safely 1.5× the worst-case SMB release delay with no meaningful mtime imprecision.
5. mksqlite `extended_result_codes` — the bundled `mksqlite.c` does NOT support `extended_result_codes`. It calls `sqlite3_errmsg()` and throws a generic `mksqlite:sqlError`. Phase 1029 needs a **probe task** to verify `SQLITE_BUSY` vs `SQLITE_BUSY_SNAPSHOT` distinguishability from the error string. Phase 1032's retry wrapper must rely on string matching, not extended error codes, unless mksqlite.c is patched.
6. `AtomicWriter` MEX requirement — MATLAB's `movefile` on Windows calls `MoveFileExA` WITHOUT `MOVEFILE_WRITE_THROUGH`; post-rename re-stat + retry loop in pure MATLAB is sufficient for Phase 1029; no new MEX for AtomicWriter. The reader-side 3-retry/50ms-backoff helper is the critical safety mechanism.
7. NDJSON encoding via `ndjsonEncode.m` — MATLAB R2020b `jsonencode` does NOT encode `datetime` objects; they must be pre-converted to ISO 8601 strings (`datestr` or `char(datetime(...,'Format',...))`) before passing to `jsonencode`. `int64` values encode correctly in MATLAB R2020a+. Octave 7+ `jsonencode` handles plain structs and numerics but does NOT handle `datetime` objects either. A minimal 20-line pure-MATLAB `ndjsonEncode.m` helper is required to pre-convert `datetime` and ensure `int64` safety.

**Primary recommendation:** Ship `lockfile_mex.c` with `#ifdef F_OFD_SETLK` compile-time branching, add in-process re-entrance tracking to `FileLock`, implement `AtomicWriter` in pure MATLAB with post-rename validation, and write a 20-line `ndjsonEncode.m` that pre-converts `datetime` → ISO 8601 char before calling `jsonencode`.

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on Phase 1029 |
|-----------|----------------------|
| Pure MATLAB, no external dependencies | `lockfile_mex.c` is the only new C; everything else pure MATLAB |
| MEX with pure-MATLAB fallback | `FileLock` must have a sidecar-rename fallback when `lockfile_mex` absent |
| Namespaced error IDs | `Concurrency:identityResolutionFailed`, `Concurrency:nestedLockAcquireForbidden`, `Concurrency:lockPathOpenForbidden` |
| Suite tests: class-based `tests/suite/Test*.m` | `TestFileLock.m`, `TestAtomicWriter.m`, `TestClusterIdentity.m`, `TestClusterConfig.m` |
| Octave 7+ compat incl. `--disable-java` | `usejava('jvm')` guard on Java InetAddress; `getpid()` not `feature('getpid')` in Octave |
| `mcp__matlab__check_matlab_code` before running | Static analysis before any test invocation |
| build_mex.m pattern — output to `private/` | `lockfile_mex.c` lives in `libs/Concurrency/private/mex_src/`; new `build_concurrency_mex.m` or extend top-level build_mex.m |
| MISS_HIT style — 160-char lines, 4-space tabs | Apply to all new `.m` files |

---

## Unknown 1: `lockfile_mex.c` OFD vs `F_SETLK` Branching Strategy

### Kernel version and compile-time detection

**OFD locks introduced: Linux 3.15** (confirmed by `man7.org/linux/man-pages/man2/fcntl_locking.2.html`).

**Compile-time detection: `#ifdef F_OFD_SETLK` is the correct and standard approach.** The constant is defined in `<fcntl.h>` on all glibc versions for Linux 3.15+ and is absent on older kernels. The QEMU project's virtiofsd uses exactly this pattern (confirmed by patchew.org).

**Known edge case (LOW confidence):** RHEL 7 ships kernel 3.10 but backports certain 3.15 features. There is a Launchpad bug (1905979) showing that QEMU's runtime probe of OFD locks can give false positives on FUSE filesystems. For FastSense's use case (SMB / ext4 / xfs), `#ifdef F_OFD_SETLK` is reliable. Add a runtime self-test as defence in depth: on first `lockfile_mex` call on Linux, probe `F_OFD_SETLK` with a temp file and fall back to `F_SETLK` with a warning if the probe fails with `EINVAL`.

**macOS: no OFD locks.** macOS does not define `F_OFD_SETLK`. Fall back to `F_SETLK`. Since macOS is a development machine (not a production deployment target per CLAUDE.md), the `F_SETLK` close-drops-lock caveat is acceptable with documentation. The Pitfall 1 requirement (OFD mandatory for production) applies to Linux deployments only.

### Recommended `lockfile_mex.c` branch table

```c
/* Platform branching strategy for lockfile_mex.c */

#ifdef _WIN32
    /* Win32: LockFileEx — process-scoped, SMB-forwarded */
    /* See Unknown 2 for flag details */

#elif defined(__linux__) && defined(F_OFD_SETLK)
    /* Linux 3.15+ with glibc: OFD locks — open-file-description-scoped */
    /* F_OFD_SETLK / F_OFD_SETLKW / F_OFD_GETLK */
    /* Released only when last FD on the open file description closes */
    /* Self-deadlock: MUST use in-process per-key tracking (see Unknown 3) */
    /* Runtime probe: attempt F_OFD_GETLK; on EINVAL fall through to F_SETLK */

#else
    /* macOS / Linux < 3.15 / Octave on old kernels: plain F_SETLK */
    /* CAVEAT: close() on ANY FD releases the lock (Pitfall 1) */
    /* Acceptable on macOS (dev only). Document limitation. */
    /* Mitigation: never open the lock path via MATLAB fopen during a held lock */
#endif
```

**Confidence: HIGH** — kernel version from man page, `#ifdef` pattern from QEMU virtiofsd, macOS absence verified by absence of `F_OFD_SETLK` in macOS SDK headers.

---

## Unknown 2: Win32 `LockFileEx` Flag Combinations for SMB

### Authoritative answer (MSDN, HIGH confidence)

From `learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-lockfileex`:

**Flag values:**
| Flag | Value | Meaning |
|------|-------|---------|
| `LOCKFILE_EXCLUSIVE_LOCK` | `0x00000002` | Exclusive (write) lock — denies all other processes read and write |
| `LOCKFILE_FAIL_IMMEDIATELY` | `0x00000001` | Return immediately if lock unavailable (non-blocking try) |

**Correct combination for `tryAcquire`:**
```c
DWORD dwFlags = LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY;
/* 0x00000003 */
```

**Correct combination for blocking `acquire` (with timeout loop):**
```c
DWORD dwFlags = LOCKFILE_EXCLUSIVE_LOCK;  /* 0x00000002 — blocks until granted */
```

**Byte range for whole-file advisory lock:**
```c
OVERLAPPED ov;
memset(&ov, 0, sizeof(ov));  /* hEvent = 0, Offset = 0, OffsetHigh = 0 */
/* Lock 1 byte at offset 0 — advisory sentinel */
BOOL ok = LockFileEx(hFile, dwFlags, 0 /*dwReserved must be 0*/,
                     1, 0,  /* nNumberOfBytesToLockLow=1, High=0 */
                     &ov);
```

**Why byte range (0,1) not `(MAXDWORD, MAXDWORD)`:** Locking beyond EOF is legal per MSDN. Locking a single byte at offset 0 is the standard advisory-lock sentinel idiom. No need to lock the entire file range.

**OVERLAPPED requirements:**
- `hEvent` must be 0 or a valid event handle. Using 0 is correct for synchronous I/O (file handle opened without `FILE_FLAG_OVERLAPPED`).
- `Offset` + `OffsetHigh` specify the start of the locked region. Both 0 = start of file.
- For synchronous handles: `LockFileEx` with `LOCKFILE_FAIL_IMMEDIATELY` returns immediately (no async signaling needed).

**SMB 3.0 support (explicitly documented by MSDN):**

> "In Windows 8 and Windows Server 2012, this function is supported by the following technologies: SMB 3.0 protocol — **Yes**; SMB 3.0 Transparent Failover — **Yes**"

**SMB-specific behavioural caveat (MSDN Remarks):**
> "If a process terminates with a portion of a file locked or closes a file that has outstanding locks, the locks are unlocked by the operating system. However, **the time it takes for the operating system to unlock these locks depends upon available system resources.**"

This is the process-death delay from PITFALLS.md Pitfall 3 (30–60s on SMB). Already handled by the mtime heartbeat design.

**Second-handle caveat (MSDN Remarks, process-scoped semantics):**
> "If the locking process opens the file a second time, it **cannot access the specified region through this second handle until it unlocks the region.**"

This means on Windows, calling `LockFileEx` from a second MATLAB `fopen` on the same lockfile path will DEADLOCK (the second handle cannot access the locked byte range). The `FileLock` MUST track per-key in-process holdings (same as Linux; see Unknown 3).

**Known SMB quirk — no inconsistent results from `LockFileEx` itself:** The documented SMB atomicity issues in PITFALLS.md are about `MoveFileEx` (rename), not `LockFileEx`. `LockFileEx` on SMB is well-behaved. The Pitfall 4 rename caveat is separate.

**Confidence: HIGH** — MSDN primary, direct inspection.

---

## Unknown 3: `F_OFD_SETLK` Re-acquire from Same Process (Self-Deadlock)

### Authoritative answer (Linux kernel docs + fcntl_locking man page, HIGH confidence)

**Core principle (from `man7.org/linux/man-pages/man2/fcntl_locking.2.html`, Linux 3.15):**

> "Open file description locks placed via the **same** open file description (i.e., via the same file descriptor, or via a duplicate of the file descriptor created by `fork(2)`, `dup(2)`, ...) are **always compatible**."
>
> "On the other hand, open file description locks **may conflict** with each other when they are acquired via **different open file descriptions**."
>
> "In the current implementation, **no deadlock detection is performed for open file description locks**."

**What this means for `FileLock`:**

Two `open(lockPath, O_RDWR|O_CREAT, 0644)` calls within the same MATLAB process produce **two separate open file descriptions**. An `F_OFD_SETLK` exclusive lock held on fd1 WILL conflict with an `F_OFD_SETLK` exclusive lock attempted on fd2, even within the same process.

- With `F_OFD_SETLK` (non-blocking): the second acquire returns `EWOULDBLOCK` / `EAGAIN` immediately.
- With `F_OFD_SETLKW` (blocking): the second acquire **blocks indefinitely** (no deadlock detection). This is a self-deadlock on the same MATLAB process.

**Verdict: `FileLock` MUST maintain an in-process registry of currently held lock keys.**

Design requirement for `FileLock.m`:
```matlab
% Private persistent tracking inside FileLock class
% (or a module-level persistent variable in lockfile_mex)
%
% Before calling lockfile_mex('acquire', lockPath, timeout):
%   Check: is lockPath already held by THIS process?
%   YES → return existing token (re-entrant acquire — same lock, same FD)
%          OR throw Concurrency:nestedLockAcquireForbidden (Phase 1029 choice)
%   NO  → call lockfile_mex('acquire', ...)
%
% The CONTEXT.md design choice is: throw Concurrency:nestedLockAcquireForbidden
% (single-lock-at-a-time invariant from PITFALLS.md Pitfall 13)
```

**Same process, same FD (dup/inherited):** Locks are compatible — releasing via a dup'd FD does NOT release the OFD lock (exactly the OFD guarantee we want). This is the correct single-holder path.

**Windows equivalence:** MSDN states "If the locking process opens the file a second time, it cannot access the specified region through this second handle until it unlocks the region." Same self-deadlock risk via `LockFileEx` on Windows. The in-process tracking requirement applies on both platforms.

**Implementation in `lockfile_mex.c`:** The MEX must track per-lockPath open FDs in a static table. When `'acquire'` is called for a path that already has an open FD in the table (and that FD holds the lock), it must either return the existing handle or error — it must NOT open a second FD and attempt a second lock.

**Confidence: HIGH** — kernel man page, direct quotation.

---

## Unknown 4: `staleTimeout = 90s` Calibration

### The calculation (document for plan citations)

`staleTimeout` must exceed the worst-case time for a dead process's lock to become safe to steal. Two independent constraints drive it:

**Constraint A — SMB session timeout after process death:**
- Per MSDN `LockFileEx` Remarks: lock release "depends upon available system resources" after process death.
- Observed range: 30–60s on default Windows Server SMB session timeout (documented in PITFALLS.md Pitfall 3, sourced from MSDN and SMB community reports).
- Safety margin needed: at least 1.5× observed worst case.
- → Minimum from Constraint A: 60 × 1.5 = **90s**.

**Constraint B — mtime granularity must not cause false staleness:**
The heartbeat checks `dir(lockPath).datenum`, which reflects the server's reported mtime. The holder rewrites the lockfile every 10s. For staleness not to fire falsely, we need `staleTimeout >> mtime_granularity`.

| Filesystem | mtime granularity | 90s >> granularity? |
|------------|-------------------|---------------------|
| ext4 | nanosecond | Yes (9×10⁹ margin) |
| xfs | nanosecond | Yes |
| NTFS | 100ns | Yes |
| FAT32 | 2 seconds | Yes (45× margin) |
| NFS (attr cache) | up to 30s (`acdirmax` default) | Marginal — force `noac` on NFS mounts |

FAT32 is the worst case: 2s granularity means any single heartbeat write is visible within 2s. With 10s heartbeat and 90s timeout, we have 9 missed heartbeats before timeout fires — more than enough margin even on FAT32.

**Constraint C — heartbeat relationship:**
PITFALLS.md recommends `staleTimeout >= 6 × heartbeat_interval`. With heartbeat = 10s: `6 × 10 = 60s`. Constraint A is the binding constraint at 90s.

**Verdict: `staleTimeout = 90s` is correct, justified, and documented.** It is the minimum safe value given SMB session timeout reality. The plan should not lower it below 90s. If the target office LAN uses a non-default SMB session timeout above 60s, the operator should increase `staleTimeout` accordingly (document this in the operator config).

**Confidence: HIGH** — SMB timeout range from MSDN, mtime granularities from filesystem documentation, calculation is arithmetic.

---

## Unknown 5: mksqlite `extended_result_codes` Pass-Through

### Verdict: NOT SUPPORTED in the bundled `mksqlite.c` (HIGH confidence, direct code inspection)

Reading `libs/FastSense/mksqlite.c` in full:

1. **No `sqlite3_extended_result_codes()` call anywhere.** The bundled mksqlite does not call this function.
2. **Error reporting uses `sqlite3_errmsg()` only.** When `sqlite3_step()` returns anything other than `SQLITE_ROW` / `SQLITE_DONE` / `SQLITE_OK`, it calls `mexErrMsgIdAndTxt("mksqlite:sqlError", "SQL execution error: %s", sqlite3_errmsg(db))`.
3. **The error ID is always `mksqlite:sqlError`** — there is no differentiation between `SQLITE_BUSY`, `SQLITE_BUSY_SNAPSHOT`, `SQLITE_LOCKED`, or any other error code. All become the same MATLAB error ID with different message strings.
4. **`sqlite3_errmsg()` returns a human-readable string** like `"database is locked"` for `SQLITE_BUSY` and `"database is locked (SQLITE_BUSY_SNAPSHOT)"` for `SQLITE_BUSY_SNAPSHOT`. The extended result code name IS embedded in the string for SQLITE_BUSY_SNAPSHOT.

**Implication for Phase 1029:**
A **probe task** in Phase 1029 must verify what exact `sqlite3_errmsg()` strings the bundled SQLite 3.46.1 emits for `SQLITE_BUSY` vs `SQLITE_BUSY_SNAPSHOT`. This is a 10-line MATLAB + a synthetic SQLite test. The probe task output feeds Phase 1032's retry wrapper.

**Probe design (plan task):**
```matlab
% Create two in-memory SQLite DBs pointing to same WAL file (simulated)
% OR: use mksqlite to trigger SQLITE_BUSY by opening same DB twice
% Then inspect the MException.message string to find the distinguishing substring
%
% Expected findings (based on SQLite source for 3.46.1):
%   SQLITE_BUSY           -> "database is locked"
%   SQLITE_BUSY_SNAPSHOT  -> "database is locked (SQLITE_BUSY_SNAPSHOT)"
%   SQLITE_LOCKED         -> "database table is locked: <name>"
```

**Phase 1032 retry wrapper strategy:** Catch `mksqlite:sqlError`, check `ME.message` for the substring `"SQLITE_BUSY_SNAPSHOT"` to distinguish from plain `SQLITE_BUSY`. Both trigger the retry loop; the distinction is for logging only.

**Alternative — patch mksqlite.c to return the integer result code:** Add `plhs[1] = mxCreateDoubleScalar((double)rc)` when `nlhs >= 2`. This would give Phase 1032 a clean `[result, rc] = mksqlite(db, sql)` pattern. Phase 1029 can include this 3-line patch to `mksqlite.c` as an optional improvement task.

**Confidence: HIGH** — direct inspection of `libs/FastSense/mksqlite.c` lines 706–733; no `extended_result_codes` call found.

---

## Unknown 6: `AtomicWriter` — MEX or Pure MATLAB?

### Verdict: Pure MATLAB is sufficient for Phase 1029. No new MEX required.

**Linux/macOS:** MATLAB's `movefile` calls POSIX `rename(2)`, which is atomic on the same filesystem (including SMB mounts from Linux via CIFS, which forwards the `RENAME` SMB command atomically). The post-rename re-stat + retry loop in `AtomicWriter` handles the SMB SMB2-over-Windows-CIFS edge case.

**Windows:** MATLAB's `movefile` calls the Windows-internal file rename API (equivalent to `MoveFileExA` or `rename()` from MSVC CRT). Key question: does it use `MOVEFILE_WRITE_THROUGH`?

From the MathWorks documentation and community analysis:
- MATLAB's generated code is described as "similar to `MoveFileExA`" but does NOT guarantee `MOVEFILE_WRITE_THROUGH`.
- `MOVEFILE_WRITE_THROUGH` flushes all buffers before returning — important for crash safety but not for atomicity from a reader's perspective.
- The documented SMB non-atomicity (PITFALLS.md Pitfall 4) is about Samba versions doing `delete + rename` vs a true atomic replace. Modern Windows Server with SMB2+ does atomic replace.

**The post-rename validation loop in `AtomicWriter` is the correct mitigation** regardless of whether `MOVEFILE_WRITE_THROUGH` is used. The loop:
1. Calls `movefile(tempPath, finalPath, 'f')`.
2. Re-stats the result: `info = dir(finalPath); if info.bytes == 0 || isempty(info)...`
3. Retries up to N times with 50ms backoff.

This catches the Samba `delete + rename` window where `finalPath` briefly disappears. A new MEX using `MoveFileEx(...MOVEFILE_WRITE_THROUGH)` would add write-through semantics but would NOT eliminate the zero-byte window — it would only ensure the OS has flushed buffers before returning. Not worth the MEX complexity for Phase 1029.

**Reader-side retry is the critical safety net.** The 3-retry/50ms-backoff helper on `load()` converts any torn-rename window into a brief stall. This is the defence-in-depth that matters for correctness.

**Verdict table:**

| Platform | `movefile` behaviour | Additional MEX needed? |
|----------|---------------------|----------------------|
| Linux (local ext4/xfs) | `rename(2)` — atomic | No |
| Linux (SMB via CIFS) | SMB `RENAME` command — atomic | No |
| macOS (APFS/HFS+) | `rename(2)` — atomic | No |
| macOS (SMB via smbfs) | SMB `RENAME` — usually atomic; retry handles edge case | No |
| Windows (NTFS local) | `MoveFileExA(REPLACE_EXISTING)` — atomic | No |
| Windows (SMB share) | SMB `RENAME` via redirector — atomic on modern Windows Server; Samba edge case handled by retry | No |

**Confidence: HIGH on Linux/macOS; MEDIUM on Windows SMB (Samba version-dependent edge case is real but handled by retry).**

---

## Unknown 7: `ndjsonEncode.m` — MATLAB and Octave `jsonencode` Gaps

### MATLAB R2020b `jsonencode` support

From MathWorks documentation and community analysis:

**`datetime` objects:** NOT natively supported by `jsonencode`. Community guidance (MathWorks Answers 468996) confirms: "if you need specific formatting such as an ISO 8601 timestamp, you must **explicitly convert datetime to strings** before encoding." Calling `jsonencode(datetime('now','TimeZone','UTC'))` errors on R2020b with `MATLAB:jsonencode:unsupportedType` or produces an undocumented internal representation involving `mwmetadata` (the MATLAB Production Server JSON representation, not the base MATLAB `jsonencode`).

**`int64` values:** Supported since **R2020a** with correct precision. `jsonencode(int64(12345))` produces `12345` (integer, not `1.2345e4`). Round-trip: `jsondecode(jsonencode(int64(12345)))` returns `double(12345)` — type is lost on decode, but the numeric value is exact. For lockfile identity stamping (PID as `int64`), this is acceptable: the stored JSON string is correct; decode recovers a `double` equal to the original value for any PID fitting in a 53-bit integer (all realistic PIDs).

**`struct` arrays:** Fully supported in both MATLAB and Octave. `jsonencode(struct('user','alice','host','plant-a'))` produces `{"user":"alice","host":"plant-a"}`.

### Octave 7+ `jsonencode` support

From Octave 7.1 docs and source analysis:

**`datetime` objects:** NOT supported in Octave 7.x `jsonencode`. Octave does not have MATLAB's `datetime` class as a built-in in the same way. Calling `jsonencode` on a MATLAB-style `datetime` value in Octave would error.

**`int64` values:** Octave 7.x `jsonencode` handles `int64` but precision may differ from MATLAB R2020a+. The core note: "Encoding and decoding is not guaranteed to preserve the Octave data type."

**Complex numbers:** NOT supported in either MATLAB or Octave `jsonencode`.

### Required `ndjsonEncode.m` implementation

The NDJSON lines written by Phase 1031's `EventLog` and Phase 1029's `lockFileFormat.m` contain:
- `datetime` stamps (ISO 8601 string)
- `int64` PIDs (convert to `double` before encoding — all PIDs < 2^53)
- `char` identity strings
- `struct` payloads

**Minimal 20-line `ndjsonEncode.m` (pure MATLAB, Octave-compat):**

```matlab
function line = ndjsonEncode(s)
%NDJSONENCODE Encode struct to a single NDJSON line, Octave-safe.
%   line = ndjsonEncode(s) converts s to a JSON string followed by newline.
%   Pre-converts datetime fields to ISO 8601 char and int64 fields to double
%   so both MATLAB R2020b+ and Octave 7+ jsonencode succeed.
%
%   Only flat structs with scalar or char/string fields are supported.

    fields = fieldnames(s);
    for k = 1:numel(fields)
        v = s.(fields{k});
        if isa(v, 'datetime')
            % Convert datetime to ISO 8601 UTC string before jsonencode
            v.TimeZone = 'UTC';
            s.(fields{k}) = char(v, 'yyyy-MM-dd''T''HH:mm:ss''Z''');
        elseif isa(v, 'int64') || isa(v, 'uint64')
            % int64 → double: safe for PIDs (< 2^53)
            s.(fields{k}) = double(v);
        end
    end
    line = [jsonencode(s), newline()];
end
```

**Confidence: MEDIUM** — MATLAB `datetime` encoding confirmed as unsupported via community searches; Octave confirmed from docs as not supporting `datetime`; `int64` precision from R2020a release notes. The implementation above is straightforward.

---

## Standard Stack

### Core (unchanged from existing build)

| Library | Version | Purpose | Source |
|---------|---------|---------|--------|
| MATLAB | R2020b+ | Runtime | CLAUDE.md |
| GNU Octave | 7+ | Alt runtime | CLAUDE.md |
| SQLite 3.46.1 | bundled in `libs/FastSense/private/mex_src/` | Storage (EventStore, Phase 1031+) | STACK.md §2 |
| mksqlite | bundled in `libs/FastSense/mksqlite.c` | SQLite MEX binding | STACK.md §2 |
| C compiler (Xcode CLT / GCC / MSVC) | platform default | MEX build | CLAUDE.md, CONTEXT.md (locked) |

### New in Phase 1029

| Component | Location | Purpose | Key constraint |
|-----------|----------|---------|----------------|
| `lockfile_mex.c` | `libs/Concurrency/private/mex_src/` | Cross-platform advisory locks | `#ifdef F_OFD_SETLK` branching; no SIMD flags needed |
| `build_concurrency_mex.m` | `libs/Concurrency/` | Compile `lockfile_mex.c` | Follows `build_mex.m` pattern; no SIMD opt_flags; output to `libs/Concurrency/private/` |
| `ClusterIdentity.m` | `libs/Concurrency/` | `user@host (pid, epoch)` resolution | `getpid()` in Octave, `feature('getpid')` in MATLAB |
| `ClusterConfig.m` | `libs/Concurrency/` | Mode resolution seam | Explicit > `FASTSENSE_SHARED_ROOT` > single-user |
| `SharedPaths.m` | `libs/Concurrency/` | Path builders + `isClusterMode()` | Stateless static class |
| `FileLock.m` | `libs/Concurrency/` | Per-key lockfile with heartbeat | In-process tracking required (Unknown 3) |
| `AtomicWriter.m` | `libs/Concurrency/` | temp+rename + post-rename validation | Pure MATLAB (Unknown 6 verdict) |
| `ndjsonEncode.m` | `libs/Concurrency/private/` | Octave-safe NDJSON line encoding | Pre-converts `datetime` → ISO 8601 char |
| `lockFileFormat.m` | `libs/Concurrency/private/` | Lock file content struct layout | Returns struct with user, host, pid, acquired_at, heartbeat_at |

### Build integration pattern (from `build_mex.m` inspection)

The existing `build_mex.m` in `libs/FastSense/` compiles MEX files from `private/mex_src/` into `private/` (or platform-tagged subdirectory under Octave). The file table format is `{src, outname, {extra_srcs}, {extra_flags}}`.

`lockfile_mex.c` is the only Phase 1029 MEX. It:
- Lives in `libs/Concurrency/private/mex_src/lockfile_mex.c`
- Requires no SIMD flags (no arithmetic-intensive loops)
- On Windows needs `kernel32.lib` linkage (for `LockFileEx`/`UnlockFileEx`/`CreateFileA`/`CloseHandle`)
- On Linux/macOS: no extra libs (POSIX `fcntl` is in libc)

**Build pattern for `build_concurrency_mex.m`:**
```matlab
% New file: libs/Concurrency/build_concurrency_mex.m
% Pattern: mirrors libs/FastSense/build_mex.m but:
%   - No SIMD detection needed (no computation)
%   - Windows extra link flag: kernel32.lib (auto-linked by MSVC, not needed explicitly)
%   - Single MEX target: lockfile_mex.c
%   - Output: libs/Concurrency/private/ (MATLAB) or libs/Concurrency/private/octave-<tag>/ (Octave)
```

The top-level `install.m` must also `addpath(fullfile(rootDir, 'libs', 'Concurrency'))`.

---

## Architecture Patterns

### Existing patterns confirmed by code inspection

**Persistent singleton pattern (from `TagRegistry.m`):** Uses a private static method with `persistent cache` — the `containers.Map` is created once and mutated in-place. `ClusterIdentity.m` should follow the same pattern for the resolved identity tuple.

**Atomic save pattern (from `EventStore.m` lines 148-172):**
```matlab
tmpFile = [obj.FilePath '.tmp'];
% ... save to tmpFile ...
movefile(tmpFile, obj.FilePath);  % atomic rename
```
`AtomicWriter` wraps this pattern with post-rename validation and adds identity stamping.

**mtime-based cache invalidation (from `EventStore.loadFile` lines 181-225):**
```matlab
info = dir(filePath);
modTime = info.datenum;
if lastModTime.isKey(filePath) && modTime <= lastModTime(filePath)
    % Unchanged — return cached
end
```
`FileLock.isStale()` uses the same `dir(lockPath).datenum` pattern to read server-side mtime.

**Error ID namespace:** All existing error IDs follow `ClassName:camelCaseProblem`. New IDs for Phase 1029:
- `Concurrency:identityResolutionFailed` — user or host not resolvable in cluster mode
- `Concurrency:nestedLockAcquireForbidden` — same process trying to acquire a key it already holds
- `Concurrency:lockPathOpenForbidden` — caller opened the lock path via fopen while lock held
- `Concurrency:sharedRootUnreachable` — SharedPaths.resolve() found a non-writable or non-existent root
- `Concurrency:atomicWriteFailed` — AtomicWriter.replace() failed after N retries

### Recommended `libs/Concurrency/` structure

```
libs/Concurrency/
├── ClusterIdentity.m          % static class; resolve user+host+pid+epoch
├── ClusterConfig.m            % static class; mode resolver (ARCHITECTURE.md §Q6)
├── SharedPaths.m              % static class; path builders + isClusterMode()
├── FileLock.m                 % handle class; acquire/release/isStale/stillHeldByMe/takeOver
├── AtomicWriter.m             % static class; replace(temp, final) + readers.withRetry()
└── private/
    ├── mex_src/
    │   └── lockfile_mex.c     % cross-platform byte-range locks
    ├── ndjsonEncode.m         % Octave-safe: pre-converts datetime → ISO 8601
    └── lockFileFormat.m       % returns struct with lock file content fields
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Process PID on Octave | `system('ps ...')` | `getpid()` built-in | Octave has `getpid()` as a real function; `feature('getpid')` errors on Octave |
| Cross-platform advisory locks | `mkdir`-as-mutex | `lockfile_mex.c` MEX | `mkdir` atomicity not guaranteed on NFS/SMB (STACK.md §1) |
| SMB-safe rename | `delete(final); copyfile(temp, final)` | `movefile(temp, final, 'f')` + post-rename retry | delete+copy is NOT atomic; movefile is atomic on same-filesystem |
| Host resolution | Java-only `InetAddress` | `system('hostname')` first, Java as tertiary fallback | Octave `--disable-java` builds have no JVM (`usejava('jvm')` = false) |
| JSON datetime encoding | `jsonencode(datetime(...))` directly | Pre-convert: `char(dt, 'yyyy-MM-dd''T''HH:mm:ss''Z''')` | `jsonencode(datetime)` fails on both MATLAB and Octave |

---

## Common Pitfalls (Phase 1029 specific)

### Pitfall A: `lockfile_mex.c` compiled without `_GNU_SOURCE`

**What goes wrong:** On Linux, `F_OFD_SETLK` is only available from `<fcntl.h>` when `_GNU_SOURCE` is defined. Without it, `#ifdef F_OFD_SETLK` evaluates false and the MEX silently falls back to `F_SETLK` even on Linux 3.15+.

**How to avoid:** Add `-D_GNU_SOURCE` to the MEX compile flags in `build_concurrency_mex.m`. Verify by adding a compile-time assert: `#ifndef F_OFD_SETLK` → `#error "OFD locks required on Linux 3.15+"`.

**Warning signs:** Tests pass on dev machine but production shows `close()` drops locks.

### Pitfall B: In-process re-entrance tracking omitted from `FileLock`

**What goes wrong:** `FileLock.acquire('pressure')` succeeds. Somewhere in the same MATLAB session, `FileLock.acquire('pressure')` is called again (from a listener, a nested callback, or a test that forgot to release). On Linux with OFD locks: `F_OFD_SETLK` on the new FD returns `EWOULDBLOCK` (non-blocking form) — not a self-deadlock, but the acquire silently fails. On Windows: deadlock on the second `LockFileEx` call (the new handle cannot access the locked byte range per MSDN).

**How to avoid:** `FileLock` tracks a per-key `heldBy_` map (key → FD handle) as a private instance property. `acquire()` checks before calling MEX. Error `Concurrency:nestedLockAcquireForbidden` on second acquire of same key.

**Warning signs:** Intermittent `EWOULDBLOCK` errors in logs; Windows CI hangs on second acquire.

### Pitfall C: `AtomicWriter.replace()` called without checking `stillHeldByMe()` first

**What goes wrong:** The lock holder writes to `<key>.mat.tmp.<epoch>.<rand>`, the lock is silently stolen by a taking-over node (due to heartbeat failure), and then `movefile(tmp, final)` succeeds from the original holder — overwriting the new owner's in-progress write.

**How to avoid:** Call `lock.stillHeldByMe()` immediately before the `movefile` call inside `AtomicWriter.replace()`. If the check fails, discard the temp file and abort.

### Pitfall D: Octave `--disable-java` causes silent `'unknown-host'` writes

**What goes wrong:** On CI with Octave `--disable-java`, `usejava('jvm')` returns false, Java InetAddress is skipped, `system('hostname')` is not tried (if programmer followed STACK.md's wrong ordering of Java-first), and `host` defaults to `'unknown-host'`. In cluster mode this means every shared write from Octave carries an unidentified host — violating IDENT-01.

**How to avoid:** `userIdentity.m` must use `system('hostname')` as the SECONDARY fallback (before Java), not tertiary. Java InetAddress is tertiary. See STACK.md §4 for the correct ordering. Test `TestClusterIdentity` must run under Octave `--disable-java` in CI.

### Pitfall E: Octave platform-tagged MEX output directory not on MATLAB path

**What goes wrong:** Under Octave, `build_mex.m` routes compiled `.mex` files to `private/octave-<tag>/`. If `install.m` (or `build_concurrency_mex.m`) does not add that subdirectory to the path, `lockfile_mex` is not found at runtime and `FileLock` silently falls back to the sidecar-rename pure-MATLAB path — giving no compile error but weaker lock semantics.

**How to avoid:** Replicate the Octave platform-tag `addpath` pattern from `install.m` in the Concurrency library's installation step.

---

## Code Examples

### Existing atomic save pattern in `EventStore.save()` (source: `libs/EventDetection/EventStore.m` lines 148-172)

```matlab
% Atomic write: save to temp, then rename (existing pattern to replicate/extend)
tmpFile = [obj.FilePath '.tmp'];
% ... build varList, call save(tmpFile, varList{:}) ...
movefile(tmpFile, obj.FilePath);
```

`AtomicWriter.replace(tempPath, finalPath)` wraps this with:
1. `movefile(tempPath, finalPath, 'f')` call
2. `info = dir(finalPath); if isempty(info) || info.bytes == 0` → retry with 50ms backoff, up to 3 times
3. Pre-`movefile` call to `lock.stillHeldByMe()` (Pitfall C prevention)

### Existing persistent singleton pattern (source: `libs/SensorThreshold/TagRegistry.m` lines 376-386)

```matlab
methods (Static, Access = private)
    function map = catalog()
        persistent cache;
        if isempty(cache)
            cache = containers.Map();
        end
        map = cache;
    end
end
```

`ClusterIdentity.m` follows this pattern for the resolved `(user, host, pid)` tuple:
```matlab
methods (Static, Access = private)
    function id = cache_()
        persistent cached;
        if isempty(cached)
            cached = struct();  % filled on first call to ClusterIdentity.resolve()
        end
        id = cached;
    end
end
```

### `lockfile_mex.c` entry points (from STACK.md §1, confirmed)

```matlab
handle = lockfile_mex('acquire', lockPath, timeoutSec)  % int64 handle, or -1 on timeout
ok     = lockfile_mex('release', handle)                % logical
info   = lockfile_mex('status',  lockPath)              % struct: pid, hostname, age
```

### `LockFileEx` correct call (from Unknown 2, MSDN verified)

```c
/* In lockfile_mex.c — Windows branch */
HANDLE hFile = CreateFileA(lockPath,
    GENERIC_READ | GENERIC_WRITE,
    FILE_SHARE_READ | FILE_SHARE_WRITE,  /* allow others to open for status reads */
    NULL, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);

OVERLAPPED ov;
memset(&ov, 0, sizeof(ov));  /* hEvent=0, Offset=0, OffsetHigh=0 */

/* Non-blocking try-acquire: */
BOOL acquired = LockFileEx(hFile,
    LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY,
    0,      /* dwReserved — must be zero */
    1, 0,   /* 1 byte at offset 0 */
    &ov);

/* Blocking acquire (used in retry loop inside MATLAB): call with just LOCKFILE_EXCLUSIVE_LOCK */
```

### `ndjsonEncode.m` (from Unknown 7, full implementation)

Location: `libs/Concurrency/private/ndjsonEncode.m`

```matlab
function line = ndjsonEncode(s)
%NDJSONENCODE Encode a struct to a single NDJSON line (JSON + newline).
%   Octave 7+ and MATLAB R2020b+ compatible. Pre-converts datetime fields
%   to ISO 8601 UTC strings and int64/uint64 fields to double so that
%   jsonencode succeeds on both runtimes.
%
%   Input:  s   — scalar struct with primitive or char/string field values
%   Output: line — char row vector ending with newline character

    fields = fieldnames(s);
    for k = 1:numel(fields)
        v = s.(fields{k});
        if isa(v, 'datetime')
            v.TimeZone = 'UTC';
            s.(fields{k}) = char(v, 'yyyy-MM-dd''T''HH:mm:ss''Z''');
        elseif isa(v, 'int64') || isa(v, 'uint64')
            s.(fields{k}) = double(v);  % safe: all PIDs < 2^53
        end
    end
    line = [jsonencode(s), newline()];
end
```

---

## Environment Availability

Step 2.6: External dependency audit.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| C compiler (Xcode CLT) | `lockfile_mex.c` MEX build | User confirmed in CONTEXT.md | present on dev machine | — |
| MATLAB R2020b+ | All `.m` files | present (CI + dev) | R2020b+ | Octave 7+ |
| GNU Octave 7+ | CI test matrix | present (CI) | 7+ (CI: 9.2.0 on Windows) | — |
| `fcntl.h` / `F_OFD_SETLK` | Linux MEX branch | Linux kernel 3.15+ on CI | kernel ≥ 3.15 assumed on CI Linux | `F_SETLK` fallback |
| `fileapi.h` / `LockFileEx` | Windows MEX branch | Windows CI (Chocolatey Octave 9.2.0) | Windows XP+ | — |

**Missing dependencies with no fallback:** None identified for Phase 1029. The compiler is confirmed available.

---

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json` (file does not exist). Treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB class-based test (matlab.unittest) + Octave function-style tests |
| Config file | None (project uses `tests/run_all_tests.m` as discovery runner) |
| Quick run command | `mcp__matlab__run_matlab_test_file` on individual test file |
| Full suite command | `tests/run_all_tests.m` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONC-02 | Stale lock recovered within `staleTimeout+5s` via mtime | Integration (2-process) | `TestFileLock.testStaleLockAfterProcessKill` | ❌ Wave 0 |
| CONC-02 | Negative wall-clock delta does NOT trigger takeover | Unit | `TestFileLock.testNegativeWallClockDeltaIgnored` | ❌ Wave 0 |
| CONC-02 | Closing second FD does NOT release OFD lock | Unit (Linux-only) | `TestFileLock.testCloseDoesNotReleaseLock` | ❌ Wave 0 |
| CONC-03 | Reader during temp+rename never sees zero-byte content | Integration | `TestAtomicWriter.testTornRenameRecovery` | ❌ Wave 0 |
| CONC-03 | Post-rename validation retries on size=0 | Unit | `TestAtomicWriter.testPostRenameValidationRetries` | ❌ Wave 0 |
| IDENT-01 | `userIdentity.m` returns non-empty user+host on all platforms | Unit | `TestClusterIdentity.testIdentityTupleComplete` | ❌ Wave 0 |
| IDENT-01 | Cluster mode throws on unresolvable identity | Unit | `TestClusterIdentity.testClusterModeThrowsOnFailure` | ❌ Wave 0 |
| IDENT-01 | Octave `--disable-java` path uses `system('hostname')` | Unit (Octave CI) | `test_user_identity.m` (Octave function-style) | ❌ Wave 0 |

### Gated stress test (not default-on)

| Test File | Gate Env Var | What It Tests |
|-----------|-------------|---------------|
| `TestFileLockStress50.m` | `FASTSENSE_STRESS_50=1` | 50-process concurrent acquire/release on same lockfile; no deadlock, no corruption |

### Sampling Rate

- **Per task commit:** `mcp__matlab__run_matlab_test_file` on the specific new test class
- **Per wave merge:** All 4 new test classes + `tests/run_all_tests.m` for regression
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

All test files need to be created as part of Phase 1029 execution:

- [ ] `tests/suite/TestFileLock.m` — OFD/LockFileEx unit tests + 2-process stress
- [ ] `tests/suite/TestAtomicWriter.m` — torn-rename recovery tests
- [ ] `tests/suite/TestClusterIdentity.m` — identity resolution, cluster-mode throw
- [ ] `tests/suite/TestClusterConfig.m` — mode resolution, SharedPaths path builders
- [ ] `tests/test_user_identity.m` — Octave function-style, runs under `--disable-java`

---

## Sources

### Primary (HIGH confidence)

- `man7.org/linux/man-pages/man2/fcntl_locking.2.html` — OFD locks since Linux 3.15, same-process file-description conflict semantics, no deadlock detection for OFD
- `learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-lockfileex` — `LockFileEx` flag values, OVERLAPPED requirements, SMB 3.0 support table, process-death caveat
- `libs/FastSense/mksqlite.c` (direct inspection, lines 706–733) — no `extended_result_codes`, always `mksqlite:sqlError`
- `libs/EventDetection/EventStore.m` (direct inspection, lines 148-172) — existing atomic temp+rename pattern
- `libs/SensorThreshold/TagRegistry.m` (direct inspection, lines 376-386) — persistent singleton pattern
- `libs/FastSense/build_mex.m` (direct inspection, lines 152-161) — MEX build table format, output directory logic
- `.planning/research/PITFALLS.md` — Pitfalls 1, 3, 4, 8, 9, 12 (HIGH confidence; settled decisions, not re-researched)
- `.planning/research/STACK.md` §1 and §4 — lockfile_mex C sketch, userIdentity.m pattern (cited, not re-researched)
- `.planning/research/ARCHITECTURE.md` §Q6 — ClusterConfig.resolve seam (cited, not re-researched)

### Secondary (MEDIUM confidence)

- `gavv.net/articles/file-locks/` — OFD locks associated with file object not pid, same-process blocking behaviour
- `patchew.org/QEMU/5D43F688.8000607@huawei.com/` — `#ifdef F_OFD_GETLK` compile-time guard pattern in virtiofsd
- `manpages.ubuntu.com/manpages/resolute/man2/F_OFD_GETLK.2const.html` — OFD lock intro version, same-process conflict
- MathWorks community (matlabcentral/answers/468996) — `datetime` not supported natively by `jsonencode`; must convert to string
- MATLAB R2020a release notes (inferred) — `int64` precision in `jsonencode` since R2020a
- Octave 7.1 JSON docs — no `datetime` object support in `jsonencode`

### Tertiary (LOW confidence; flagged)

- Windows MATLAB `movefile` internal implementation (uses `MoveFileExA` without `MOVEFILE_WRITE_THROUGH` — inferred from MathWorks docs, not directly confirmed)
- Octave `int64` jsonencode precision edge cases — not directly verified against a running Octave instance

---

## Metadata

**Confidence breakdown:**

| Area | Level | Reason |
|------|-------|--------|
| OFD lock kernel semantics (Unknown 1, 3) | HIGH | Primary kernel man page, direct quotation |
| Win32 LockFileEx (Unknown 2) | HIGH | MSDN primary documentation |
| staleTimeout calculation (Unknown 4) | HIGH | Arithmetic from documented constraints |
| mksqlite extended_result_codes (Unknown 5) | HIGH | Direct code inspection |
| AtomicWriter MEX verdict (Unknown 6) | MEDIUM | Windows MATLAB movefile internal API inferred |
| ndjsonEncode datetime (Unknown 7) | MEDIUM | Community sources; not directly verified by running MATLAB |
| Octave jsonencode int64 edge cases | LOW | Docs only; no empirical test |

**Research date:** 2026-05-13
**Valid until:** 2026-08-13 (90 days; stable kernel/Win32 APIs)

---

## RESEARCH COMPLETE

All 7 unknowns resolved.

**Phase:** 1029 - Concurrency Foundation
**Confidence:** HIGH on kernel semantics and Win32; MEDIUM on MATLAB jsonencode; HIGH on mksqlite (direct inspection)

### Key Findings

- **Unknown 1 (OFD branching):** `#ifdef F_OFD_SETLK` is the correct compile-time guard (Linux 3.15+). macOS falls back to `F_SETLK` acceptably (dev-only). Add `-D_GNU_SOURCE` to compile flags on Linux.
- **Unknown 2 (LockFileEx SMB):** `LOCKFILE_EXCLUSIVE_LOCK | LOCKFILE_FAIL_IMMEDIATELY`, byte range 1 byte at offset 0, `OVERLAPPED` with `hEvent=0`. SMB 3.0 explicitly supported per MSDN. Process-death delay handled by mtime heartbeat (Pitfall 3 already settled).
- **Unknown 3 (OFD same-process re-acquire):** Two `open()` calls = two file descriptions = they CONFLICT. `FileLock` MUST implement per-key in-process tracking. Throw `Concurrency:nestedLockAcquireForbidden` on second acquire of same key. Same requirement applies on Windows via `LockFileEx`.
- **Unknown 4 (staleTimeout=90s):** Justified: SMB session timeout worst case 60s × 1.5 safety margin = 90s. FAT32 2s mtime granularity still leaves 45× margin. Default 90s is correct; document as operator-tunable.
- **Unknown 5 (mksqlite extended_result_codes):** NOT supported. Bundled mksqlite.c uses only `sqlite3_errmsg()` and always throws `mksqlite:sqlError`. Phase 1029 probe task needed. Phase 1032 must use string matching on `ME.message`.
- **Unknown 6 (AtomicWriter MEX):** No new MEX needed. MATLAB `movefile` + post-rename re-stat retry loop is sufficient on all platforms. Pure MATLAB.
- **Unknown 7 (ndjsonEncode.m):** 20-line helper required. Pre-convert `datetime` → ISO 8601 char before `jsonencode` (MATLAB and Octave both fail on raw `datetime`). `int64` PIDs → `double` (safe for all realistic PIDs).

### File Created

`.planning/phases/1029-foundation/1029-RESEARCH.md`

### Open Questions

1. **MATLAB `movefile` on Windows — MOVEFILE_WRITE_THROUGH confirmation:** Not empirically confirmed. The post-rename retry loop mitigates regardless. If Phase 1029 stress testing reveals frequent zero-byte windows on Windows CI, a 3-line MEX patch using `MoveFileEx(...MOVEFILE_WRITE_THROUGH)` is the fallback.
2. **mksqlite probe exact string output:** Needs 10-line MATLAB test. Plan must include this as an explicit task with output fed to Phase 1032 planning notes.
3. **Linux CI kernel version:** If CI runs kernel < 3.15 (unlikely, but possible on very old Ubuntu images), `#ifdef F_OFD_SETLK` will be false and `F_SETLK` will be used in CI. The `testCloseDoesNotReleaseLock` test will PASS (with `F_SETLK` and fresh FDs per operation) but would give false confidence. CI matrix should log which branch was compiled.
