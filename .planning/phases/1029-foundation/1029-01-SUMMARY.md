---
phase: 1029
plan: 01
subsystem: Concurrency
tags: [identity, cluster-mode, path-builders, octave-compat, IDENT-01]
dependency_graph:
  requires: []
  provides:
    - userIdentity()
    - ClusterIdentity.resolve()
    - ClusterIdentity.pid()
    - ClusterIdentity.clearCache()
    - ClusterConfig.resolve()
    - SharedPaths.isClusterMode()
    - SharedPaths.resolveRoot()
    - SharedPaths.tagsDir/locksDir/eventsDir()
  affects:
    - Plan 1029-03 (FileLock — uses ClusterIdentity.resolve() for stamping)
    - Plan 1029-04 (AtomicWriter — uses ClusterIdentity.resolve() for identity stamping)
    - Plan 1029-05 (install.m wiring — adds libs/Concurrency/ to project addpath chain)
tech_stack:
  added: []
  patterns:
    - persistent-singleton cache (TagRegistry pattern)
    - layered env-var fallback (getenv → system → Java)
    - static stateless helper class (SharedPaths)
key_files:
  created:
    - libs/Concurrency/userIdentity.m
    - libs/Concurrency/ClusterIdentity.m
    - libs/Concurrency/ClusterConfig.m
    - libs/Concurrency/SharedPaths.m
    - tests/suite/TestClusterIdentity.m
    - tests/suite/TestClusterConfig.m
    - tests/test_user_identity.m
  modified: []
decisions:
  - "Override detection uses hasOverrideUser/hasOverrideHost boolean flags instead of isempty(overrideUser) because isempty('') == true in MATLAB, causing empty-string overrides to be silently ignored (deviation Rule 1 auto-fix)"
  - "ClusterIdentity.pid() returns int64 (not double) to match plan spec; epoch stored as datetime object (not char string) as required by plan"
metrics:
  duration_seconds: 525
  completed_date: "2026-05-13"
  tasks_completed: 2
  files_created: 7
  files_modified: 0
---

# Phase 1029 Plan 01: Identity Paths Summary

**One-liner:** Pure-MATLAB identity primitives (`userIdentity` → `ClusterIdentity` → `ClusterConfig`/`SharedPaths`) with layered fallback chain, Octave-safe PID resolution, and cluster-mode gate dormant by default.

## What Was Built

Four pure-MATLAB files implementing the REQ IDENT-01 identity foundation for v4.0 cluster mode, plus three test files providing complete coverage.

### `libs/Concurrency/userIdentity.m`

Function with layered fallback chain (LOCKED ordering per CONTEXT.md + Pitfall D fix):
- **USERNAME:** `getenv('USERNAME')` (Windows) → `getenv('USER')`/`getenv('LOGNAME')` (POSIX) → `system('whoami')` → `''`
- **HOSTNAME:** `getenv('COMPUTERNAME')` (Windows) → `getenv('HOSTNAME')` (POSIX) → `system('hostname')` (SECONDARY, Pitfall D fix) → `usejava('jvm')` guarded `java.net.InetAddress` (TERTIARY) → `''`
- Returns empty on failure; callers decide whether to throw

### `libs/Concurrency/ClusterIdentity.m`

Static class with persistent cache following TagRegistry pattern:
- `resolve()` returns struct with `.user` (char), `.host` (char), `.pid` (int64), `.epoch` (datetime UTC)
- `resolve('Strict', true)` throws `Concurrency:identityResolutionFailed` on empty user or host
- `resolve('OverrideUser', u, 'OverrideHost', h)` for test injection (bypass cache)
- `pid()` centralises `feature('getpid')` (MATLAB) vs `getpid()` (Octave)
- `clearCache()` resets persistent cache for test isolation

### `libs/Concurrency/SharedPaths.m`

Stateless static class:
- `isClusterMode(opts)` — true iff `resolveRoot(opts)` returns non-empty
- `resolveRoot(opts)` — precedence: `opts.SharedRoot` > `FASTSENSE_SHARED_ROOT` env > `''`
- `tagsDir(root)`, `locksDir(root)`, `eventsDir(root)` — `fullfile()` builders

### `libs/Concurrency/ClusterConfig.m`

Static class wrapping `SharedPaths.resolveRoot()` with validation:
- `resolve(opts)` returns `{SharedRoot, IsClusterMode}` struct
- Throws `Concurrency:sharedRootUnreachable` if SharedRoot is set but folder doesn't exist
- Cluster mode is structurally dormant — `resolve()` with no opts returns `IsClusterMode=false`

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| `userIdentity.m` exists with correct signature | PASS |
| `system('hostname')` present as secondary fallback (Pitfall D) | PASS |
| `usejava('jvm')` guards Java tertiary fallback (Pitfall 8) | PASS |
| `mcp__matlab__check_matlab_code` on `userIdentity.m`: 0 errors | PASS |
| `TestClusterIdentity.m` exists as `TestClusterIdentity < matlab.unittest.TestCase` | PASS |
| `testIdentityTupleComplete` method defined | PASS |
| `testClusterModeThrowsOnFailure` method defined | PASS |
| `test_user_identity.m` exists | PASS |
| `test_user_identity.m` reports all-pass | PASS (2/2) |
| `ClusterIdentity.m` exists with `classdef ClusterIdentity` | PASS |
| `Concurrency:identityResolutionFailed` in `ClusterIdentity.m` | PASS |
| `feature('getpid')` present (MATLAB branch) | PASS |
| `getpid()` present (Octave branch) | PASS |
| `persistent cached` present (cache pattern) | PASS |
| `SharedPaths.m` exists with `isClusterMode` function | PASS |
| `FASTSENSE_SHARED_ROOT` in `SharedPaths.m` | PASS |
| `ClusterConfig.m` exists with `Concurrency:sharedRootUnreachable` | PASS |
| `checkcode` on all 3 new `libs/Concurrency/*.m` files: 0 errors | PASS |
| `TestClusterIdentity.testClusterModeThrowsOnFailure` uses `verifyError` for `Concurrency:identityResolutionFailed` | PASS |
| `TestClusterConfig.testResolutionPrecedence` and `testSharedPathsRoot` defined | PASS |
| `TestClusterIdentity.m` all-pass | PASS (2/2) |
| `TestClusterConfig.m` all-pass | PASS (2/2) |
| Regressions: `TestEventStore`, `TestTagRegistry` still pass | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed empty-string override detection in ClusterIdentity.resolve()**

- **Found during:** Task 2 test run (testClusterModeThrowsOnFailure failed)
- **Issue:** Original implementation used `isempty(overrideUser) && isempty(overrideHost)` to decide whether to use cache. In MATLAB, `isempty('')` returns `true`, so passing `'OverrideHost', ''` was incorrectly treated as "no override provided" and the cache was used — preventing the test from injecting empty host.
- **Fix:** Replaced `isempty()` checks with explicit boolean flags `hasOverrideUser` and `hasOverrideHost` set when the key is encountered in the NV-pair loop.
- **Files modified:** `libs/Concurrency/ClusterIdentity.m`
- **Commit:** 2c87f54 (included in Task 2 commit)

## Hand-off Notes

### For Plan 1029-03 (FileLock)

`ClusterIdentity.resolve()` is ready. Call it to stamp lockfile content with `user@host (pid, epoch)`. Use `ClusterIdentity.resolve('Strict', true)` in cluster mode to enforce identity before acquiring any lock. The `epoch` field is a MATLAB `datetime` with `TimeZone='UTC'`; convert to ISO 8601 char before JSON encoding (see `ndjsonEncode.m` in `libs/Concurrency/private/`).

### For Plan 1029-04 (AtomicWriter)

Same as above. `ClusterIdentity.resolve()` provides the identity struct for `atomicWriteMetadata`. Call `clearCache()` in tests if you need to inject test identities via `OverrideUser`/`OverrideHost`.

### For Plan 1029-05 (install.m wiring)

`libs/Concurrency/` is not yet in `install.m`. The test classes use a belt-and-suspenders `addpath(fullfile(root, 'libs', 'Concurrency'))` in their `TestClassSetup`. Plan 05 must add:
```matlab
addpath(fullfile(root, 'libs', 'Concurrency'));
```
to `install.m` (and handle the Octave platform-tagged MEX subdir once `lockfile_mex` is in play from Plan 02).

## Known Stubs

None. All plan goals achieved. Every cluster path is structurally dormant (returns `false`/`''`) when no `SharedRoot` is configured.

## Self-Check: PASSED
