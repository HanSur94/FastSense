---
phase: 1042-machine-fleet-pipeline-di-seam
verified: 2026-06-07T00:00:00Z
status: passed
score: 13/13
overrides_applied: 0
re_verification: null
---

# Phase 1042: Machine + Fleet + Pipeline DI Seam — Verification Report

**Phase Goal:** Each Machine owns an isolated tag catalog and a DataRoot; a Fleet holds searchable machines; pipelines can be scoped to a machine; machine tags never enter the global TagRegistry.
**Verified:** 2026-06-07
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Machine owns an isolated tag catalog (containers.Map, never TagRegistry) | VERIFIED | `containers.Map('KeyType','char','ValueType','any')` in Machine.m:128; `grep TagRegistry.register libs/Fleet/ == 0`; 14/14 TestMachine tests green |
| 2 | Two machines can hold the same local sensor key with no error and no global registry entry | VERIFIED | `testTwoMachinesSameLocalKeyCoexist` + `testTagRegistryUntouched` pass; invariant grep gate 0 |
| 3 | A pipeline can be scoped to a machine via the tagSource_ DI seam | VERIFIED | `'TagSource', @(pred) obj.find(pred)` present in Machine.m:231 + 257; `tags = obj.tagSource_(...)` in both BatchTagPipeline.m:266 and LiveTagPipeline.m:807; 18/18 TestBatchTagPipeline + 11/11 TestLiveTagPipeline green |
| 4 | Single-machine pipeline callers are byte-for-byte unchanged (default @TagRegistry.find) | VERIFIED | `tagSource_ = @TagRegistry.find` property default in both pipeline files; no live static `TagRegistry.find(...)` call inside `eligibleTags_`; only `@TagRegistry.find` handle defaults remain |
| 5 | A Fleet holds searchable machines with duplicate-Id rejection | VERIFIED | `Fleet:duplicateMachineId` guard in Fleet.m:88; `testDuplicateMachineIdErrors` passes; 10/10 TestFleet green |
| 6 | Fleet can save and load a config file that round-trips identically on MATLAB and Octave | VERIFIED | `save`/`load` in Fleet.m; per-entry jsonencode+strjoin (2 sites); atomic movefile; `"fleetConfigVersion":1` in JSON; normalizeToCell_ in Fleet.m:287; 5/5 test_fleet Octave flat tests pass |
| 7 | Relative DataRoots resolve against the config-file directory on load | VERIFIED | `Machine.fromConfigStruct` implements D-07: relative path resolved via `fullfile(fleetDir, dataRoot)`; `testRelativeDataRootResolvedAgainstConfigDir` passes |
| 8 | Fleet filters by group and name (composable, Octave-safe) | VERIFIED | `strfind(lower(...))` used 4 times in Fleet.m; zero `contains(` calls; `testFilterByName`/`testFilterByGroup`/`testFiltersComposable` all pass |
| 9 | Machine metadata loads eagerly while X/Y data stays deferred (FLEET-05) | VERIFIED | `addTag` never calls `tag.getXY()`; `testFiveMachineMetadataOnlyLoad` passes with wall time < 2 s |
| 10 | Machine stops and deletes its live-pipeline timer on delete (no timer accumulation) | VERIFIED | `delete(obj)` in Machine.m:285-291: `stop()` then `delete(LivePipeline_)`; `testStartLiveStopsTimerOnDelete` passes |
| 11 | Machine tags never enter the global TagRegistry — critical invariant | VERIFIED | `grep -rn "TagRegistry.register" libs/Fleet/` == 0 (confirmed) |
| 12 | No UI code in Fleet library deliverables (Octave must run all) | VERIFIED | `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout\|uiprogressdlg" Machine.m Fleet.m normalizeToCell_.m` == 0 |
| 13 | Octave-CI gap closed: flat test_machine.m + test_fleet.m exist and pass | VERIFIED | Both files exist; define `function test_machine` / `function test_fleet`; use `SensorTag` (not MockTag); call `TagRegistry.clear()` at start+end; 3/3 and 5/5 pass |

**Score:** 13/13 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `libs/Fleet/Machine.m` | Machine handle class: isolated catalog, duck-type read API, ingest wrappers, EventStore, config serialization | VERIFIED | 344 lines (min 120); `classdef Machine < handle`; all 6 error ids; containers.Map catalog; ingestBatch + startLive with tagSource_ wiring; fromConfigStruct with D-07 path resolution |
| `libs/Fleet/Fleet.m` | Fleet handle class: machine collection, duplicate-Id guard, composable filters, JSON save/load | VERIFIED | 301 lines (min 120); `classdef Fleet < handle`; normalizeToCell_(s.machines); Machine.fromConfigStruct; CanonicalMapper.fromStruct; strjoin x2; movefile; fleetConfigVersion |
| `libs/Fleet/private/normalizeToCell_.m` | Fleet-private jsondecode struct-array->cell normalization | VERIFIED | 29 lines; handles empty/struct-array/passthrough; no cross-library private reach; identical logic to Dashboard analog |
| `libs/SensorThreshold/BatchTagPipeline.m` | tagSource_ DI seam + TagSource NV-pair | VERIFIED | `tagSource_ = @TagRegistry.find` property; `case 'TagSource'` before `otherwise`; `tags = obj.tagSource_(...)` in eligibleTags_ |
| `libs/SensorThreshold/LiveTagPipeline.m` | Identical tagSource_ DI seam; SharedRoot/cluster path untouched | VERIFIED | Same pattern; predicate body byte-semantically identical to BatchTagPipeline; SharedRoot/cluster lines unchanged |
| `tests/suite/TestMachine.m` | MATLAB class suite covering FLEET-01/02/03/05 | VERIFIED | 14 test methods; `classdef TestMachine < matlab.unittest.TestCase`; all required error ids in verifyError calls; 14/14 pass |
| `tests/suite/TestFleet.m` | MATLAB class suite covering FLEET-01/04/06 | VERIFIED | 10 test methods; `classdef TestFleet < matlab.unittest.TestCase`; 10/10 pass; canonical-map round-trip strengthened to non-vacuous |
| `tests/test_machine.m` | Octave flat test for FLEET-02 isolation + FLEET-03 tagSource_ default | VERIFIED | `function test_machine`; `add_fleet_path_()` helper; uses SensorTag; TagRegistry.clear present; 3/3 pass |
| `tests/test_fleet.m` | Octave flat test for FLEET-04 JSON round-trip + filter composition | VERIFIED | `function test_fleet`; asserts `"fleetConfigVersion":1` in saved JSON; 5/5 pass |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `Machine.m` | `containers.Map` | `Tags_` catalog (never TagRegistry.register) | VERIFIED | `containers.Map('KeyType','char','ValueType','any')` at line 128; grep gate 0 |
| `Machine.m` | `BatchTagPipeline` / `LiveTagPipeline` | `'TagSource', @(pred) obj.find(pred)` in ingestBatch + startLive | VERIFIED | Both at Machine.m:231 and 257 |
| `Machine.m` | `EventStore` | `EventStore(obj.DataRoot)` at line 131 | VERIFIED | Conditional on non-empty DataRoot; grep count = 1 |
| `BatchTagPipeline.m` | `obj.tagSource_` | `eligibleTags_` predicate enumeration | VERIFIED | `tags = obj.tagSource_(...)` at line 266; count = 1 |
| `LiveTagPipeline.m` | `obj.tagSource_` | `eligibleTags_` predicate enumeration | VERIFIED | `tags = obj.tagSource_(...)` at line 807; count = 1 |
| `Fleet.m` | `Machine.toConfigStruct` / `Machine.fromConfigStruct` | per-entry jsonencode on save; reconstruct on load | VERIFIED | `Machine.fromConfigStruct(machines{i}, filepath)` at line 289 |
| `Fleet.m` | `normalizeToCell_` | post-jsondecode struct-array normalization | VERIFIED | `normalizeToCell_(s.machines)` at line 287 |
| `Fleet.m` | `CanonicalMapper.toStruct` / `CanonicalMapper.fromStruct` | embedded canonical map | VERIFIED | `CanonicalMapper.fromStruct(s.canonicalMap)` at line 295 |

---

### Data-Flow Trace (Level 4)

Not applicable — phase deliverables are pure data-model classes (no UI rendering, no live data display). All data flows are covered by the MATLAB test suite results (authoritative runtime evidence from the orchestrator).

---

### Behavioral Spot-Checks

| Behavior | Evidence Source | Result | Status |
|----------|----------------|--------|--------|
| Machine isolated catalog: 2 machines hold same key, TagRegistry empty | TestMachine 14/14 PASSED (orchestrator MATLAB MCP run) | Green | PASS |
| Pipeline DI seam: tagSource_ default preserved, custom TagSource accepted | TestBatchTagPipeline 18/18 + TestLiveTagPipeline 11/11 PASSED | Green | PASS |
| Fleet save/load round-trip on MATLAB + Octave | TestFleet 10/10 + test_fleet 5/5 PASSED | Green | PASS |
| Lazy load: 5-machine metadata-only startup < 2 s | testFiveMachineMetadataOnlyLoad PASSED | Green | PASS |
| Timer-safe delete: timerfindall count stable | testStartLiveStopsTimerOnDelete PASSED | Green | PASS |

Step 7b formal probe execution: SKIPPED — no conventional `scripts/*/tests/probe-*.sh` files declared or discovered for this phase; runtime behavior verified through the MATLAB test suites run by the orchestrator.

---

### Requirements Coverage

| Requirement | Source Plan(s) | Description | Status | Evidence |
|-------------|---------------|-------------|--------|---------|
| FLEET-01 | Plan 01/03/04 | Machine constructor + Fleet.addMachine factory + handle form; duplicate-Id guard | SATISFIED | Machine NV constructor with required Id; Fleet.addMachine factory + handle form; Fleet:duplicateMachineId guard; 14/14 TestMachine + 10/10 TestFleet pass |
| FLEET-02 | Plan 01/03 | Identical local keys coexist; machine tags never enter global TagRegistry | SATISFIED | `grep TagRegistry.register libs/Fleet/ == 0`; testTwoMachinesSameLocalKeyCoexist + testTagRegistryUntouched pass |
| FLEET-03 | Plan 01/02/03 | Machine ingests into own DataRoot via tagSource_ DI seam; single-machine path unchanged | SATISFIED | tagSource_ seam in both pipelines; Machine.ingestBatch/startLive wire TagSource; existing suites 18/18 + 11/11 pass |
| FLEET-04 | Plan 01/04 | Fleet config round-trips on MATLAB R2020b+ and Octave 7+; embedded canonical map; fleetConfigVersion | SATISFIED | Per-entry jsonencode+strjoin; normalizeToCell_; fleetConfigVersion:1; testSaveLoadRoundTrip + testCanonicalMapEmbedded + testFleetConfigVersionPresent + testRelativeDataRootResolvedAgainstConfigDir pass; test_fleet 5/5 pass on Octave path |
| FLEET-05 | Plan 01/03/04 | Lazy load: metadata eagerly, X/Y deferred; 5-machine startup under budget | SATISFIED | addTag never calls getXY; testFiveMachineMetadataOnlyLoad < 2 s; Fleet.load uses Machine.fromConfigStruct (metadata only) |
| FLEET-06 | Plan 01/04 | Machine.Group + Fleet.filterByGroup + Fleet.filterByName composable | SATISFIED | strfind(lower(...)) x4; no contains(); testFilterByName + testFilterByGroup + testFiltersComposable pass |

All 6 requirement IDs accounted for. No orphaned requirements detected.

---

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| None | — | — | — |

No TBD/FIXME/XXX markers in phase deliverables. No stub patterns (empty return null / return {} / placeholder strings). No UI tokens in Fleet library files. No `contains(` calls in Fleet library (Octave incompatibility). No live `TagRegistry.find(...)` static calls inside `eligibleTags_` in either pipeline.

The two non-comment `@TagRegistry.find` occurrences in each pipeline (property default + opts default) are function-handle references, not live calls — this is the correct DI-seam pattern.

---

### Human Verification Required

None. All must-haves are verifiable programmatically. The orchestrator ran the full MATLAB test suite with authoritative results. No visual, real-time, or external-service behavior is involved in this phase.

---

### Gaps Summary

No gaps. All 13 observable truths are VERIFIED. All 6 requirement IDs are SATISFIED. All 9 required artifacts pass three-level verification (exists, substantive, wired). All key links are WIRED. Critical invariant grep gates all pass (TagRegistry.register == 0, UI tokens == 0, contains( == 0 in deliverables, tagSource_ seam in both pipelines). MATLAB test results from the orchestrator are authoritative runtime evidence: 14/14 TestMachine, 10/10 TestFleet, 18/18 TestBatchTagPipeline, 11/11 TestLiveTagPipeline, 3/3 test_machine, 5/5 test_fleet — all green.

---

### Context.md Decision Coverage

All 14 decisions in 1042-CONTEXT.md are honored:

| Decision | Description | Evidence |
|----------|-------------|---------|
| D-01 | Tags populated programmatically via Machine.addTag | addTag present; no catalog file auto-discovery |
| D-02 | Lazy load reuses SensorTag.RawSource deferred-read; addTag never calls getXY | Code confirmed; testFiveMachineMetadataOnlyLoad passes |
| D-03 | Fleet config persists definitions + canonical map, NOT the tag catalog | save/load serializes id/name/dataRoot/group/metadata + embedded canonical map only |
| D-04 | No filesystem tag auto-discovery | Confirmed absent from Machine.m |
| D-05 | Canonical map embedded under `canonicalMap` key in fleet JSON | `cmJson` assembled and embedded in Fleet.save; CanonicalMapper.fromStruct on load |
| D-06 | CanonicalMapper standalone save/load unchanged | Not modified in this phase |
| D-07 | Paths stored as-given; relative resolved against config dir; ~ expanded | Machine.fromConfigStruct lines 311-331 |
| D-08 | Auto-relativize on save deferred | Confirmed not implemented (explicitly deferred) |
| D-09 | Fleet.addMachine factory NV form + pre-built handle form | Fleet.m:82-86 |
| D-10 | Id required + unique within Fleet (Fleet:duplicateMachineId) | Machine.m:117-118; Fleet.m:87-89 |
| D-11 | Group freeform char; filterByGroup/filterByName composable via strfind(lower) | Fleet.m:114-150 |
| D-12 | tagSource_ private property + TagSource NV pair in both pipelines; default @TagRegistry.find | BatchTagPipeline.m:74,90,102,123; LiveTagPipeline.m:164,184,204,227 |
| D-13 | Machine.ingestBatch/startLive wire TagSource + OutputDir = DataRoot; SharedRoot passthrough | Machine.m:230-233, 256-259 |
| D-14 | Machine owns EventStore(DataRoot); global TagRegistry.setEventStore untouched | Machine.m:131; no setEventStore call anywhere in Fleet library |

---

_Verified: 2026-06-07T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
