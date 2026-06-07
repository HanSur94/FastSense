---
phase: 1042-machine-fleet-pipeline-di-seam
plan: "01"
subsystem: Fleet
tags: [tdd, fleet, machine, octave-ci, wave-0, normalizeToCell]
dependency_graph:
  requires: []
  provides:
    - tests/suite/TestMachine.m
    - tests/suite/TestFleet.m
    - tests/test_machine.m
    - tests/test_fleet.m
    - libs/Fleet/private/normalizeToCell_.m
  affects:
    - libs/Fleet/Machine.m     # RED target; Plans 03 implements
    - libs/Fleet/Fleet.m       # RED target; Plan 04 implements
tech_stack:
  added: []
  patterns:
    - MATLAB class-based test suite (matlab.unittest.TestCase)
    - Octave flat function-based test suite (test_*.m)
    - Fleet-private normalizeToCell_ helper (Dashboard private copy)
key_files:
  created:
    - tests/suite/TestMachine.m
    - tests/suite/TestFleet.m
    - tests/test_machine.m
    - tests/test_fleet.m
    - libs/Fleet/private/normalizeToCell_.m
  modified: []
decisions:
  - "normalizeToCell_ uses trailing-underscore per CLAUDE.md private-helper convention"
  - "Octave flat tests use SensorTag (not MockTag) to avoid suite-only mock dependency"
  - "TagRegistry.clear in TestMethodSetup + TestMethodTeardown for FLEET-02 isolation"
metrics:
  duration_minutes: 15
  completed: "2026-06-07"
  tasks_completed: 3
  tasks_total: 3
  files_created: 5
  files_modified: 0
---

# Phase 1042 Plan 01: Test Scaffold + normalizeToCell_ Helper Summary

Wave 0 test scaffold for Machine + Fleet + Pipeline DI Seam: 4 RED test files encoding FLEET-01..06 behavior with exact error identifiers, plus Fleet-private `normalizeToCell_` helper (GREEN immediately).

## What Was Built

### Task 1 — Fleet-private normalizeToCell_ helper (GREEN)

`libs/Fleet/private/normalizeToCell_.m` — verbatim copy of `libs/Dashboard/private/normalizeToCell.m` renamed with trailing underscore per CLAUDE.md private-helper convention. Handles three cases identically to Dashboard original: empty input returns `{}`; struct array returns 1xN cell; anything else passes through. Fleet-local because `libs/Dashboard/private/` is not callable from `libs/Fleet/` (MATLAB private-scope rules, RESEARCH Pitfall 2). Will be consumed by `Fleet.load` in Plan 04.

### Task 2 — RED MATLAB class suites (TestMachine.m + TestFleet.m)

Both suites extend `matlab.unittest.TestCase`, modeled on `tests/suite/TestCanonicalMapper.m`.

**TestMachine.m** (14 test methods, FLEET-01/02/03/05):
- `testConstructorRequiresId` — verifyError `Machine:missingId`
- `testNameDefaultsToId` — Name defaults to Id when omitted
- `testUnknownOptionErrors` — verifyError `Machine:invalidOption`
- `testAddTagDuplicateKeyErrors` — verifyError `Machine:duplicateKey`
- `testAddTagRejectsNonTag` — verifyError `Machine:invalidType`
- `testGetUnknownKeyErrors` — verifyError `Machine:unknownKey`
- `testGetFindKeysRoundTrip` — get/keys/find all return added tag
- `testFindByKind` / `testFindByLabel` — filtered catalog queries
- `testTwoMachinesSameLocalKeyCoexist` — FLEET-02: two machines, same local key, no error
- `testTagRegistryUntouched` — FLEET-02: TagRegistry.find returns empty after addTag
- `testIngestBatchScopesToDataRoot` — FLEET-03: .mat written under DataRoot
- `testStartLiveStopsTimerOnDelete` — FLEET-03: timer count restored after delete(m)
- `testFiveMachineMetadataOnlyLoad` — FLEET-05: 5 machines x 10 SensorTags < 2 s

**TestFleet.m** (10 test methods, FLEET-01/04/06):
- `testAddMachineFactoryForm` / `testAddMachineHandleForm` — FLEET-01 both forms
- `testDuplicateMachineIdErrors` — verifyError `Fleet:duplicateMachineId`
- `testSaveLoadRoundTrip` — FLEET-04: machineCount==2, Name/Group preserved
- `testCanonicalMapEmbedded` — FLEET-04: mapper rehydrated after load
- `testFleetConfigVersionPresent` — FLEET-04: JSON contains `"fleetConfigVersion":1`
- `testRelativeDataRootResolvedAgainstConfigDir` — FLEET-04/D-07: relative path resolves
- `testFilterByName` / `testFilterByGroup` — FLEET-06: case-insensitive substring
- `testFiltersComposable` — FLEET-06: AND composition via cell narrowing

Both suites have `TestMethodSetup`/`TestMethodTeardown` calling `TagRegistry.clear()` for FLEET-02 isolation.

### Task 3 — RED Octave flat tests (test_machine.m + test_fleet.m)

Closes the Octave-CI gap (RESEARCH Pitfall 1): class-based suites do not run on Octave; `test_*.m` flat files do.

**test_machine.m** (3 tests, FLEET-02/03):
- Two machines with same local key; TagRegistry stays empty
- Duplicate key on one machine raises `Machine:duplicateKey`
- `BatchTagPipeline('OutputDir', tmp)` with no `TagSource` constructs ok (tagSource_ DI seam default preserved)

**test_fleet.m** (5 tests, FLEET-04/06):
- 2-machine save/load round-trip; machineCount==2, Names preserved
- Saved JSON contains `"fleetConfigVersion":1`
- `filterByName('pump')` returns 2 matches; `filterByGroup('MOTORS')` returns 1 match (case-insensitive)

Both use SensorTag (Octave-safe); no MockTag (suite-only mock, not on Octave flat path). `TagRegistry.clear()` at start and end.

## Deviations from Plan

None — plan executed exactly as written.

## MATLAB Test Execution

MATLAB test execution deferred to orchestrator (executor lacks matlab MCP tools). All 5 files were authored per plan spec and grep-based acceptance criteria verified via Bash. Runtime RED behavior (undefined Machine/Fleet until Plans 03/04) is expected and correct for Wave 0.

## Octave CI Gap

Closed by `tests/test_machine.m` and `tests/test_fleet.m` — both discoverable by `run_all_tests.m` Octave branch via `dir(fullfile(test_dir, 'test_*.m'))`. Class-based `TestMachine.m`/`TestFleet.m` run on MATLAB CI only (existing behavior in run_all_tests.m).

## Grep Gate Results (self-verified)

| Gate | Result |
|------|--------|
| `grep -c "function c = normalizeToCell_" libs/Fleet/private/normalizeToCell_.m` | 1 |
| `grep -nE "isstruct\|c = \{\}\|c = x" libs/Fleet/private/normalizeToCell_.m` | 3 branches found |
| `grep -c "function test" tests/suite/TestMachine.m` | 14 (>= 13 required) |
| `grep -c "function test" tests/suite/TestFleet.m` | 10 (>= 10 required) |
| All 6 error IDs in verifyError calls | PASS |
| `grep -c "MockTag" tests/test_machine.m` | 0 |
| `grep -c "MockTag" tests/test_fleet.m` | 0 |
| `grep -c "TagRegistry.clear" tests/test_machine.m` | 3 (>= 2 required) |
| `grep '"fleetConfigVersion":1' tests/test_fleet.m` | FOUND |

## Self-Check: PASSED

All 5 files confirmed present on disk. All 3 commits confirmed in git log.

| File | Status |
|------|--------|
| libs/Fleet/private/normalizeToCell_.m | FOUND |
| tests/suite/TestMachine.m | FOUND |
| tests/suite/TestFleet.m | FOUND |
| tests/test_machine.m | FOUND |
| tests/test_fleet.m | FOUND |

| Commit | Message |
|--------|---------|
| 4f2e3034 | feat(1042-01): add Fleet-private normalizeToCell_ helper |
| 071cd8c2 | test(1042-01): add RED MATLAB class suites TestMachine + TestFleet |
| c5ba1909 | test(1042-01): add RED Octave flat tests test_machine + test_fleet |
