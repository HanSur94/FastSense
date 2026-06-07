---
phase: 1042-machine-fleet-pipeline-di-seam
plan: "03"
subsystem: Fleet
tags: [Machine, Fleet, TagRegistry, isolated-catalog, DI, FLEET-01, FLEET-02, FLEET-03, FLEET-05]
dependency_graph:
  requires:
    - "1042-01: TestMachine.m RED spec + normalizeToCell_ helper"
    - "1042-02: BatchTagPipeline + LiveTagPipeline tagSource_ DI seam"
  provides:
    - "libs/Fleet/Machine.m: Machine handle class"
  affects:
    - "libs/SensorThreshold/SensorTag.m: set.RawSource setter added"
    - "libs/Fleet/Fleet.m: will addMachine(Machine) in Plan 04"
tech_stack:
  added: []
  patterns:
    - "Machine isolated containers.Map catalog mirroring TagRegistry duck-type API"
    - "tagSource_ DI seam wired via @(pred) obj.find(pred) closure"
    - "D-07 path resolution for DataRoot (tilde expansion, relative, absolute)"
    - "CLAUDE.md timer-safe delete: stop() before delete()"
key_files:
  created:
    - libs/Fleet/Machine.m
  modified:
    - libs/SensorThreshold/SensorTag.m
decisions:
  - "Machine owns isolated containers.Map — TagRegistry never touched (FLEET-02 invariant)"
  - "EventStore(obj.DataRoot) constructed eagerly when DataRoot non-empty; empty DataRoot leaves EventStore as [] (no construction)"
  - "fromConfigStruct uses getenv('HOME') for tilde expansion (Octave-safe); warns and leaves as-is on Windows (ispc())"
  - "toConfigStruct attaches metadata field only when obj.Metadata has non-empty fieldnames (avoids Octave jsonencode divergence on empty struct)"
  - "SensorTag.set.RawSource added as Rule 2 deviation — Dependent read-only property cannot be assigned without setter; test requires post-construction assignment"
  - "delete() guards with isvalid() before calling stop() to handle already-deleted pipeline handles gracefully"
metrics:
  duration_minutes: 25
  completed: "2026-06-07"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 1
---

# Phase 1042 Plan 03: Machine Catalog Class Summary

Machine handle class with isolated containers.Map tag catalog, TagRegistry duck-type read API, BatchTagPipeline/LiveTagPipeline ingest wrappers scoped via tagSource_ DI seam, per-machine EventStore, D-07 path-resolution config round-trip, and timer-safe delete.

## What Was Built

### libs/Fleet/Machine.m (344 lines, NEW)

Complete `Machine < handle` class implementing all FLEET-01/02/03/05 requirements:

**Constructor (NV-pair, Task 1):**
- Accepts Id/Name/DataRoot/Group/Metadata; `Machine:missingId` if Id empty; `Machine:invalidOption` on unknown key
- Name defaults to Id when omitted
- `Tags_ = containers.Map('KeyType','char','ValueType','any')` — isolated, never touches TagRegistry
- `EventStore(obj.DataRoot)` constructed only when DataRoot non-empty

**addTag (Task 1):**
- Validates `isa(tag,'Tag')` → `Machine:invalidType` on non-Tag
- Hard-errors `Machine:duplicateKey` on collision
- Stores handle under `char(tag.Key)` — does NOT call getXY() (FLEET-05 lazy-load discipline)
- Does NOT call TagRegistry.register (FLEET-02 invariant)

**Duck-type read API (Task 1):** Instance methods `get`/`find`/`findByKind`/`findByLabel`/`keys` mirroring TagRegistry static API — enables Phase 1044 panes to use a Machine as a drop-in registry.

**ingestBatch/startLive (Task 2):**
- `Machine:missingDataRoot` guard on both methods when DataRoot empty
- Both wrap `BatchTagPipeline`/`LiveTagPipeline` with `'OutputDir', obj.DataRoot` and `'TagSource', @(pred) obj.find(pred)`
- `varargin{:}` forwarded for SharedRoot passthrough (cluster machines, D-13)
- `startLive` defaults interval to 15; stores `LivePipeline_`; calls `.start()`

**toConfigStruct/fromConfigStruct (Task 2):**
- camelCase JSON fields: id/name/dataRoot/group; metadata only when non-empty fieldnames
- D-07 path resolution: `~` → `getenv('HOME')` on non-Windows; warns and passes-through on Windows (ispc()); relative → `fullfile(fileparts(fleetFilePath), dataRoot)`; absolute used verbatim

**delete (Task 2):**
- `obj.LivePipeline_.stop()` then `delete(obj.LivePipeline_)` — stop-before-delete per CLAUDE.md
- Guards with `isvalid(obj.LivePipeline_)` for idempotency

### libs/SensorThreshold/SensorTag.m (MODIFIED — Rule 2 deviation)

Added `set.RawSource(obj, rs)` public setter that validates via `validateRawSource_` and stores in `RawSource_`. Required because `RawSource` is a Dependent property with only a getter; `TestMachine.testIngestBatchScopesToDataRoot` assigns `t.RawSource = struct(...)` post-construction (the standard FLEET-05 lazy-load wiring pattern).

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| Rule 2 deviation | `7709e1c3` | fix(1042-03): add set.RawSource setter to SensorTag |
| Task 1 + 2 | `eec33edf` | feat(1042-03): implement Machine handle class — isolated catalog + ingest wrappers |

## Grep Gate Results (all passing)

| Gate | Command | Result |
|------|---------|--------|
| FLEET-02 invariant | `grep -c "TagRegistry.register" libs/Fleet/Machine.m` | 0 |
| No UI code | `grep -cE "uifigure\|uicontrol\|uitree\|uigridlayout" libs/Fleet/Machine.m` | 0 |
| Octave-safe strings | `grep -c "contains(" libs/Fleet/Machine.m` | 0 |
| containers.Map init | `grep -c "containers.Map('KeyType', 'char'" libs/Fleet/Machine.m` | 1 |
| TagSource wrappers | `grep -c "'TagSource', @(pred) obj.find(pred)" libs/Fleet/Machine.m` | 2 |
| EventStore init | `grep -c "EventStore(obj.DataRoot)" libs/Fleet/Machine.m` | 1 |
| DataRoot guard | `grep -c "Machine:missingDataRoot" libs/Fleet/Machine.m` | 5 |
| Tilde expansion | `grep -c "getenv('HOME')" libs/Fleet/Machine.m` | 2 |
| Min lines | `wc -l libs/Fleet/Machine.m` | 344 (>= 120) |
| All 6 error IDs | grep each | PASS |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical Functionality] Added set.RawSource setter to SensorTag.m**
- **Found during:** Task 1 (analysis of TestMachine.m spec)
- **Issue:** `SensorTag.RawSource` is a Dependent property with only a `get.` method; MATLAB throws when assigning to a Dependent property without a matching `set.` method. `TestMachine.testIngestBatchScopesToDataRoot` and `testStartLiveStopsTimerOnDelete` both assign `t.RawSource = struct(...)` post-construction to wire the lazy-load source before `addTag`.
- **Fix:** Added `set.RawSource(obj, rs)` method that validates via existing `validateRawSource_` and stores in `RawSource_`. This is purely additive and does not change any existing behavior since no code previously attempted to set RawSource post-construction.
- **Files modified:** `libs/SensorThreshold/SensorTag.m`
- **Commit:** `7709e1c3`

## MATLAB Test Execution

MATLAB test execution (turning TestMachine.m GREEN) is deferred to the orchestrator as stated in the critical runtime constraint. No `mcp__matlab__*` calls were made during this execution. Implementation was authored to the exact expectations of TestMachine.m:

- All 6 error IDs verified via grep (missingId, invalidOption, invalidType, duplicateKey, unknownKey, missingDataRoot)
- TagRegistry never touched — containers.Map owns the catalog
- addTag does not call getXY() — lazy-load discipline preserved
- delete() calls stop() before delete() per CLAUDE.md timer rule
- fromConfigStruct D-07 path resolution covers tilde/relative/absolute cases

## Known Stubs

None. Machine.m is fully implemented. Dashboards property is an empty cell (intentional — Phase 1044 populates it). Phase 1044 panes will call machine.find()/get() as registry duck-type.

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: path-traversal | libs/Fleet/Machine.m | DataRoot passed to EventStore and pipelines — treated as opaque char; never eval'd or system()'d; T-1042-04 mitigation implemented |

## Self-Check: PASSED

| File | Status |
|------|--------|
| libs/Fleet/Machine.m | FOUND (344 lines) |
| libs/SensorThreshold/SensorTag.m | FOUND (modified, set.RawSource present) |

| Commit | Status |
|--------|--------|
| 7709e1c3 | FOUND |
| eec33edf | FOUND |
