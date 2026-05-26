# Phase 1029 Probe Results

Structured probe captures feeding downstream phase planning (esp. Phase 1032).

Format: each probe run appends one section. Phase 1032 plans read the latest section
to know which SQLite error-message strings to match in its retry wrapper.

## staleTimeout = 90s Rationale (for operator-facing tuning notes)

Source: 1029-RESEARCH.md §Unknown 4

The `staleTimeout = 90` default is derived from two independent constraints:

**Constraint A — SMB session timeout after process death:**
- MSDN `LockFileEx` Remarks: lock release "depends upon available system resources"
  after process death. Observed range: 30–60 s on default Windows Server SMB session
  timeout (documented Pitfall 3 calibration).
- Safety margin: 1.5× worst case → 60 × 1.5 = **90 s minimum**.

**Constraint B — mtime granularity (all filesystems safe):**
- The heartbeat rewrites the lockfile every 10 s; staleness fires after 90 s (9 missed
  beats). FAT32 has the coarsest mtime (2 s); 90 s / 2 s = 45× margin.

**Operator tuning note:** If the target LAN uses a Windows Server with a non-default
SMB session timeout > 60 s, increase `staleTimeout` proportionally (target = 1.5×
SMB session timeout). The default 90 s is conservative for typical office LAN configs.
The `staleTimeout` parameter is exposed as a `FileLock` constructor option:
```matlab
lock = FileLock('mykey', 'StaleTimeout', 120, 'LockDir', SharedPaths.locksDir(root));
```

## mksqlite Probe — captured 2026-05-14T09:53:41Z on MacBookPro

mksqlite_busy_string: "SQL execution error: database is locked"
mksqlite_busy_snapshot_string: "NOT_REPRODUCED_IN_PROBE — capture under multi-process stress in Phase 1032"
lockfile_mex_branch: fsetlk
lockfile_mex_os: darwin
lockfile_mex_pid_kind: int64 (pid=7585)
host_kernel: 25.4.0
probe_run_at: 2026-05-14T09:53:41Z
probe_run_by: hannessuhr@MacBookPro

