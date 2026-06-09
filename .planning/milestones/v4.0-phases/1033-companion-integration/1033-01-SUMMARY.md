---
phase: 1033-companion-integration
plan: 01
subsystem: FastSenseCompanion + EventDetection
tags: [cluster-mode, shared-root, companion, event-store, OPS-01]
dependency_graph:
  requires:
    - ClusterIdentity.resolve (Plan 1029-01)
    - ClusterConfig.resolve/checkSharedConfig (Plan 1029-01 + 1032-05)
    - EventStore 'SharedRoot' NV-pair (Plan 1031-04)
    - SharedPaths.eventsDir (Plan 1029-01)
  provides:
    - FastSenseCompanion('SharedRoot', root) constructor NV-pair
    - FastSenseCompanion.IsClusterMode / SharedRoot public read-only properties
    - FastSenseCompanion.IsClusterMode_ / SharedRoot_ / LastContentionNoticeText_ private state
    - companionDiscoverEventStore(sharedRoot, explicitOverride) two-arg signature
    - getSharedRoot() / getIsClusterMode() / getLastContentionNoticeText() test helpers
  affects:
    - Plan 1033-04 (UI surfacing): LastContentionNoticeText_ contract ready for polling
    - Any caller of FastSenseCompanion constructor (zero breaking changes in single-user mode)
tech_stack:
  added: []
  patterns:
    - IsClusterMode_ gate pattern (matches EventStore, LiveTagPipeline cluster-mode opt-in)
    - ClusterConfig.resolve + ClusterIdentity.resolve(Strict=true) fail-fast chain
    - NV-pair switch-case extension (matches existing Companion constructor pattern)
key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - libs/FastSenseCompanion/private/companionDiscoverEventStore.m
    - tests/suite/TestFastSenseCompanion.m
decisions:
  - "Companion calls ClusterConfig.resolve() (throws sharedRootUnreachable on bad folder) then ClusterIdentity.resolve('Strict', true) (IDENT-01 fail-fast on unresolvable identity) before EventStore discovery — same chain as EventStore cluster-mode init"
  - "companionDiscoverEventStore two-arg signature: (sharedRoot, explicitOverride). Zero-arg preserved byte-identically. Explicit override always wins unconditionally (step 1 beats everything). Registry discovery falls through to cluster construction when discovered store's SharedRoot_ mismatches."
  - "LastContentionNoticeText_ is empty at construction — Plan 04 wires the live polling that populates it from LockContentionEvents"
  - "Companion does NOT own LiveTagPipeline / LiveEventPipeline instances in Plan 01 — pipelines remain external (demo/industrial_plant/run_demo.m pattern). SharedRoot propagation is via EventStore handle only."
  - "accessField_() in companionDiscoverEventStore is a defensive private-property reader — falls back to [] when MATLAB blocks Access=private reads. Caller treats [] as 'mismatch: discard discovery, build fresh cluster store'."
metrics:
  duration_seconds: 620
  completed_date: "2026-05-14"
  tasks_completed: 3
  files_created: 0
  files_modified: 3
requirements:
  - OPS-01
---

# Phase 1033 Plan 01: Companion SharedRoot Summary

**One-liner:** FastSenseCompanion accepts a `'SharedRoot'` NV-pair that wires cluster-mode through `companionDiscoverEventStore` to construct a shared-SQLite `EventStore`; single-user construction is byte-identical with every cluster path structurally dormant.

## What Was Built

### `libs/FastSenseCompanion/private/companionDiscoverEventStore.m` (modified)

Extended from zero-arg to two-arg signature `(sharedRoot, explicitOverride)` while preserving full backward compat:

**Resolution order (highest to lowest precedence):**
1. `explicitOverride` — when non-empty, returned unchanged (constructor `'EventStore'` NV-pair always wins)
2. Registry auto-discovery — first `MonitorTag` with non-empty `EventStore`. In cluster mode, accepts only if discovered store's `SharedRoot_` matches (defensive `accessField_()` helper handles `Access=private` reads)
3. Cluster construction — `EventStore('', 'SharedRoot', sharedRoot)` when `sharedRoot` non-empty and steps 1-2 failed
4. Returns `[]` (unchanged from single-user behaviour when `sharedRoot` is empty)

**`accessField_()` private helper:** Falls back to `[]` on any property-access error so private-field reads never crash discovery.

### `libs/FastSenseCompanion/FastSenseCompanion.m` (modified)

**New public read-only properties** (`SetAccess = private`):

| Property | Default | Purpose |
|----------|---------|---------|
| `SharedRoot` | `''` | Cluster shared filesystem root ('' in single-user mode) |
| `IsClusterMode` | `false` | logical; true iff SharedRoot is non-empty |

**New private properties**:

| Property | Default | Purpose |
|----------|---------|---------|
| `SharedRoot_` | `''` | Internal mirror for gate checks |
| `IsClusterMode_` | `false` | Internal cluster-mode gate |
| `LastContentionNoticeText_` | `''` | Plan 04 surfaces this in UI |

**Constructor changes (surgical — zero touch outside the cluster gate):**
- New `case 'SharedRoot'` branch: validates char/string, stores in `userSharedRoot`
- `otherwise` error message updated to include `SharedRoot` in valid-options list
- Cluster-mode wiring block: `ClusterConfig.resolve()` (throws `sharedRootUnreachable`), `ClusterIdentity.resolve('Strict', true)` (IDENT-01 fail-fast), `ClusterConfig.checkSharedConfig()` (best-effort oplock smoke, guarded in try/catch)
- EventStore resolution: replaced two-branch if/else with single two-arg call `companionDiscoverEventStore(obj.SharedRoot_, userEventStore)`

**New test helper methods:**
- `getSharedRoot()` — returns `SharedRoot_`
- `getIsClusterMode()` — returns `IsClusterMode_`
- `getLastContentionNoticeText()` — returns `LastContentionNoticeText_` (empty until Plan 04 wires polling)

### `tests/suite/TestFastSenseCompanion.m` (modified)

4 new test methods appended at end of `methods (Test)` block:

| Test | Coverage | mksqlite Required |
|------|----------|------------------|
| `testSingleUserModeUnchanged` | IsClusterMode=false, SharedRoot='', all getters, contention banner empty | No |
| `testSharedRootPropagation` | cluster EventStore constructed, getAckRecords() not-error in cluster mode | Yes (assumeFail if absent) |
| `testSharedRootValidation` | nonexistent SharedRoot throws `Concurrency:sharedRootUnreachable` | No |
| `testExplicitEventStoreWins` | explicit EventStore NV-pair wins over cluster discovery | Yes (assumeFail if absent) |

**Total test count:** 68 (64 pre-existing + 4 new). All 68 pass on macOS Apple Silicon with mksqlite available.

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| `FastSenseCompanion.m` modified, passes static analysis (0 errors) | PASS (10 pre-existing advisory msgs only) |
| `companionDiscoverEventStore.m` static analysis (0 items) | PASS |
| 4 new test methods present | PASS |
| All 68 tests pass (64 regression + 4 new) | PASS |
| `grep -nE 'SharedRoot' FastSenseCompanion.m` ≥2 hits | PASS (20 hits) |
| `grep -nE 'IsClusterMode_' FastSenseCompanion.m` ≥2 hits | PASS (5 hits) |
| `grep -n 'ClusterIdentity.resolve' FastSenseCompanion.m` ≥1 hit | PASS (1 hit) |
| `grep -nE 'sharedRoot\|explicitOverride' companionDiscoverEventStore.m` ≥4 hits | PASS (18 hits) |
| 4 new test method function names in TestFastSenseCompanion.m | PASS |
| `Concurrency:sharedRootUnreachable` in tests | PASS |
| Single-user mode byte-identical (no Concurrency paths exercised with no SharedRoot) | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] Added ClusterIdentity.resolve('Strict', true) to companion constructor**

- **Found during:** Verification of success criteria (grep gate `ClusterIdentity.resolve >=1 hit` returned 0)
- **Issue:** The plan's success criteria required `ClusterIdentity.resolve('Strict', true)` in the companion (IDENT-01 fail-fast pattern). The initial implementation used only `ClusterConfig.resolve()` (which validates folder existence but does not check identity).
- **Fix:** Added `ClusterIdentity.resolve('Strict', true)` call after `ClusterConfig.resolve()` in the cluster-mode init block. This mirrors the pattern used in `EventStore` and `LiveTagPipeline` cluster-mode construction.
- **Files modified:** `libs/FastSenseCompanion/FastSenseCompanion.m`
- **Commit:** `1f005ea`

None - plan executed as written otherwise.

## Hand-off Notes for Plan 04 (UI Surfacing)

### `LastContentionNoticeText_` Contract

- **Type:** `char`; always a valid string (never `[]`)
- **Empty meaning:** No contention has been observed since companion startup
- **Non-empty meaning:** Text of the most recent `LockContentionEvent` observed by any companion-owned pipeline observation. Format: `"Tag P-101 is being updated by alice@plant-a (5s ago)"` (Plan 04 populates this during live-tick polling)
- **Population:** Plan 04 adds a live polling path that watches for `LockContentionEvent` notifications and stores `LastContentionNoticeText_ = event.message`. The property is already on the class; Plan 04 only needs to add the listener + populate it.
- **Surface location:** Toolbar status banner (right side, non-blocking yellow/amber). Empty string = banner hidden; non-empty = banner visible.

### Cluster-Mode Gate Pattern

All cluster code in the Companion is behind `if obj.IsClusterMode_`. The same pattern is used in `EventStore`, `LiveTagPipeline`, and `BatchTagPipeline`. Plan 04's additions should follow the same gate.

### Companion Does Not Own Pipelines

`FastSenseCompanion` holds an `EventStore_` handle but does NOT own `LiveTagPipeline` or `LiveEventPipeline` instances. Pipeline lifecycle is the responsibility of the user/demo script (see `demo/industrial_plant/run_demo.m`). The SharedRoot propagation is via the EventStore handle only. Plan 04 additions for cluster-status surfacing should rely on the `EventStore_` handle + polling, not pipeline ownership.

## Known Stubs

None. The `LastContentionNoticeText_` property exists and returns `''` at construction — this is intentional (Plan 04 wires the polling). The property is not a data-flow stub; it is infrastructure for Plan 04 to populate.

## Self-Check

- `libs/FastSenseCompanion/FastSenseCompanion.m` modified: FOUND
- `libs/FastSenseCompanion/private/companionDiscoverEventStore.m` modified: FOUND
- `tests/suite/TestFastSenseCompanion.m` modified: FOUND
- Commit `59dd811` (feat - companionDiscoverEventStore): FOUND
- Commit `1ab3d79` (test - 4 SharedRoot tests): FOUND
- Commit `1f005ea` (fix - ClusterIdentity.resolve): FOUND
- `grep SharedRoot FastSenseCompanion.m` 20 hits (>=2): VERIFIED
- `grep IsClusterMode_ FastSenseCompanion.m` 5 hits (>=2): VERIFIED
- `grep ClusterIdentity.resolve FastSenseCompanion.m` 1 hit (>=1): VERIFIED
- `grep 'sharedRoot|explicitOverride' companionDiscoverEventStore.m` 18 hits (>=4): VERIFIED
- 4 new test methods in TestFastSenseCompanion.m: VERIFIED
- `Concurrency:sharedRootUnreachable` in tests: VERIFIED
- `companionDiscoverEventStore.m` checkcode: 0 items: VERIFIED
- `FastSenseCompanion.m` checkcode: 10 pre-existing advisory only: VERIFIED
- 68/68 tests pass (64 regression + 4 new): VERIFIED

## Self-Check: PASSED
