---
phase: 1042-machine-fleet-pipeline-di-seam
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - tests/suite/TestMachine.m
  - tests/suite/TestFleet.m
  - tests/test_machine.m
  - tests/test_fleet.m
  - libs/Fleet/private/normalizeToCell_.m
autonomous: true
requirements: [FLEET-01, FLEET-02, FLEET-03, FLEET-04, FLEET-05, FLEET-06]
must_haves:
  truths:
    - "RED test suites exist for Machine and Fleet on MATLAB (class) and Octave (flat) before any production code"
    - "Fleet/private/ has its own normalizeToCell_ so libs/Fleet/ never reaches into libs/Dashboard/private/"
  artifacts:
    - path: "tests/suite/TestMachine.m"
      provides: "MATLAB class suite covering FLEET-01/02/03/05 Machine behavior"
      contains: "classdef TestMachine < matlab.unittest.TestCase"
    - path: "tests/suite/TestFleet.m"
      provides: "MATLAB class suite covering FLEET-01/04/06 Fleet behavior"
      contains: "classdef TestFleet < matlab.unittest.TestCase"
    - path: "tests/test_machine.m"
      provides: "Octave flat test for FLEET-02 isolation + FLEET-03 tagSource_ default"
      contains: "function test_machine"
    - path: "tests/test_fleet.m"
      provides: "Octave flat test for FLEET-04 JSON round-trip + filter composition"
      contains: "function test_fleet"
    - path: "libs/Fleet/private/normalizeToCell_.m"
      provides: "Fleet-private jsondecode struct-array -> cell normalization"
      contains: "function c = normalizeToCell_"
  key_links:
    - from: "tests/suite/TestMachine.m"
      to: "libs/Fleet/Machine.m"
      via: "Machine() construction in test methods (RED until Plan 03)"
      pattern: "Machine\\("
    - from: "tests/suite/TestFleet.m"
      to: "libs/Fleet/Fleet.m"
      via: "Fleet() construction in test methods (RED until Plan 04)"
      pattern: "Fleet\\("
    - from: "libs/Fleet/Fleet.m"
      to: "normalizeToCell_"
      via: "Fleet.load calls private helper (consumed in Plan 04)"
      pattern: "normalizeToCell_\\("
---

<objective>
Lay the Nyquist Wave 0 test scaffold and the one new infrastructure helper this phase needs before any production code is written. Create class-based MATLAB suites (`TestMachine.m`, `TestFleet.m`) and flat Octave companions (`test_machine.m`, `test_fleet.m`) that encode the expected FLEET-01..06 behavior as RED tests, plus the Fleet-private `normalizeToCell_.m` copy (the Dashboard original is private-unreachable from `libs/Fleet/`).

Purpose: Every implementation task in Plans 02-04 has an automated verification target the moment it lands. The Octave flat tests close the documented Octave-CI gap (class suites run on MATLAB only). The private helper removes the cross-library private-scope reach that would otherwise break `Fleet.load`.
Output: 4 test files (RED-by-design until later plans) + 1 private helper (GREEN immediately, verified against the Dashboard analog).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/ROADMAP.md
@.planning/STATE.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-CONTEXT.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-RESEARCH.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-PATTERNS.md
@.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-VALIDATION.md
</context>

<artifacts_this_phase_produces>
This section is shared by all four plans so the source-grounding/drift pass can exclude newly-created symbols.

**New classes:** `Machine` (libs/Fleet/Machine.m), `Fleet` (libs/Fleet/Fleet.m)
**Machine public methods:** `addTag`, `get`, `find`, `findByKind`, `findByLabel`, `keys`, `ingestBatch`, `startLive`, `toConfigStruct`; static `fromConfigStruct`; `delete` (timer cleanup)
**Machine public properties:** `Id`, `Name`, `DataRoot`, `Group`, `Metadata`, `Dashboards`; `SetAccess=private` `EventStore`; private `Tags_`, `LivePipeline_`
**Fleet public methods:** `addMachine`, `getMachine`, `machineCount`, `filterByName`, `filterByGroup`, `resolveLogical`, `save`; static `load`
**Fleet properties:** private `Machines_`, `MachineIds_`, `Mapper_`
**New NV option / property:** `'TagSource'` constructor NV-pair + `tagSource_` private property on BatchTagPipeline.m and LiveTagPipeline.m
**New config field:** `fleetConfigVersion` (top-level JSON key, value 1)
**New files:** libs/Fleet/Machine.m, libs/Fleet/Fleet.m, libs/Fleet/private/normalizeToCell_.m, tests/suite/TestMachine.m, tests/suite/TestFleet.m, tests/test_machine.m, tests/test_fleet.m
</artifacts_this_phase_produces>

<tasks>

<task type="auto">
  <name>Task 1: Create Fleet-private normalizeToCell_ helper</name>
  <files>libs/Fleet/private/normalizeToCell_.m</files>
  <read_first>
    - libs/Dashboard/private/normalizeToCell.m (the exact analog to copy — full file, ~26 lines)
    - libs/Fleet/CanonicalMapper.m lines 387-411, 547+ (CanonicalMapper already carries a private `normalizeToCell_`; match its name/behavior so Fleet's copy is consistent)
    - CLAUDE.md (private-helper trailing-underscore convention)
  </read_first>
  <action>
    Create `libs/Fleet/private/normalizeToCell_.m` as a verbatim copy of `libs/Dashboard/private/normalizeToCell.m` with the function renamed to `normalizeToCell_` (trailing underscore per the private-helper convention). The body MUST handle three cases: empty input returns `{}`; a struct array returns a 1xN cell with each scalar struct element; anything already a cell passes through unchanged. Add a header comment noting it is a Fleet-local copy because `libs/Dashboard/private/` is not on-path from `libs/Fleet/` (Pitfall 2). Do NOT add new behavior beyond the Dashboard original. This helper is consumed by `Fleet.load` in Plan 04.
  </action>
  <verify>
    <automated>grep -c "function c = normalizeToCell_" libs/Fleet/private/normalizeToCell_.m</automated>
  </verify>
  <acceptance_criteria>
    - `libs/Fleet/private/normalizeToCell_.m` exists and defines `function c = normalizeToCell_(x)`.
    - `grep -nE "isstruct|c = \{\}|c = x" libs/Fleet/private/normalizeToCell_.m` shows all three branches (empty -> `{}`, struct-array -> per-element cell, passthrough).
    - `mcp__matlab__check_matlab_code` on the file reports no errors.
    - Behavioral parity check via MATLAB MCP: `normalizeToCell_(struct('a',{1,2}))` returns a 1x2 cell; `normalizeToCell_([])` returns `{}`; `normalizeToCell_({1,2})` returns `{1,2}`.
  </acceptance_criteria>
  <done>The Fleet-private helper exists, passes static analysis, and returns cell output identical to the Dashboard original for empty / struct-array / cell inputs.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Author RED MATLAB class suites TestMachine.m + TestFleet.m</name>
  <files>tests/suite/TestMachine.m, tests/suite/TestFleet.m</files>
  <read_first>
    - tests/suite/TestCanonicalMapper.m lines 1-80 (class header, TestClassSetup addPaths, verifyError style — the exact analog)
    - tests/suite/MockTag.m (Tag duck — `getKind`->'mock', `getXY`->[], Labels, RawSource; use for catalog tests without real data)
    - libs/SensorThreshold/TagRegistry.m lines 47,90,154,174,194,109,214 (read API + duplicateKey + clear + list — the behavior Machine mirrors)
    - libs/Fleet/CanonicalMapper.m lines 337-426 (toStruct/fromStruct/save/load — what Fleet round-trip must reproduce)
    - 1042-PATTERNS.md "TestMachine.m + TestFleet.m" section (test-method naming + setup blocks)
  </read_first>
  <behavior>
    TestMachine.m (FLEET-01/02/03/05):
    - testConstructorRequiresId: `Machine()` throws `Machine:missingId`.
    - testNameDefaultsToId: `Machine('Id','M01').Name` equals `'M01'`.
    - testUnknownOptionErrors: `Machine('Id','M01','Bogus',1)` throws `Machine:invalidOption`.
    - testAddTagDuplicateKeyErrors: adding two tags with key `'temp'` throws `Machine:duplicateKey`.
    - testAddTagRejectsNonTag: `m.addTag(struct())` throws `Machine:invalidType`.
    - testGetUnknownKeyErrors: `m.get('nope')` throws `Machine:unknownKey`.
    - testGetFindKeysRoundTrip: after addTag, `get`/`keys`/`find(@(t)true)` return the tag.
    - testFindByKind / testFindByLabel return matching tags.
    - testTwoMachinesSameLocalKeyCoexist (FLEET-02): two Machines each addTag `'temperature'` with no error.
    - testTagRegistryUntouched (FLEET-02): after building a 2-machine catalog, `TagRegistry.find(@(t)true)` is empty (call `TagRegistry.clear()` in setup/teardown).
    - testIngestBatchScopesToDataRoot (FLEET-03): `m.ingestBatch()` runs with DataRoot=tempdir and only the machine's tags (use a SensorTag with a small RawSource csv written to tempdir; assert output `.mat` lands under DataRoot).
    - testStartLiveStopsTimerOnDelete (FLEET-03 + invariant): after `m.startLive(...)` then `delete(m)`, `timerfindall` count returns to its pre-start value.
    - testFiveMachineMetadataOnlyLoad (FLEET-05): construct 5 machines each with 10 SensorTags carrying RawSource pointers but never call getXY; assert wall time < 2 s (tic/toc) and that no X/Y arrays were materialized (tags report RawSource present, getXY not yet called — assert via a sentinel or by timing only).
    TestFleet.m (FLEET-01/04/06):
    - testAddMachineFactoryForm: `fleet.addMachine('Id','M01',...)` returns a Machine and `machineCount`==1.
    - testAddMachineHandleForm: `fleet.addMachine(Machine('Id','M02',...))` works.
    - testDuplicateMachineIdErrors (FLEET-01): second addMachine with Id `'M01'` throws `Fleet:duplicateMachineId`.
    - testSaveLoadRoundTrip (FLEET-04): save a 2-machine fleet, `Fleet.load`, assert machineCount==2 and Name/Group preserved.
    - testCanonicalMapEmbedded (FLEET-04): a fleet whose mapper has >=1 entry round-trips that entry through save/load (entries non-empty after load).
    - testFleetConfigVersionPresent (FLEET-04): saved JSON text contains `"fleetConfigVersion":1`.
    - testRelativeDataRootResolvedAgainstConfigDir (FLEET-04/D-07): a machine saved with a relative DataRoot loads with DataRoot under the config-file directory.
    - testFilterByName (FLEET-06): case-insensitive substring match returns the right machine subset.
    - testFilterByGroup (FLEET-06): group substring filter returns the right subset.
    - testFiltersComposable (FLEET-06): chaining filterByGroup then filterByName narrows further (AND).
  </behavior>
  <action>
    Author both class suites under `tests/suite/` modeled on `TestCanonicalMapper.m`. Each class extends `matlab.unittest.TestCase`, declares a `TestClassSetup` method named `addPaths` that does `addpath(repo); install();` (repo = two `fileparts` up from the suite file), and uses `verifyError` with the exact error identifiers listed in <behavior>. Add a `TestMethodSetup`/`TestMethodTeardown` that calls `TagRegistry.clear()` so the FLEET-02 isolation assertions are not polluted by other suites. Use `MockTag` for pure-catalog tests and real `SensorTag` (with a RawSource csv written to `tempname` dirs) only where ingest/lazy-load is exercised. Tests reference `Machine`/`Fleet` which do not yet exist — these suites are RED by design until Plans 03/04 land; that is expected and correct for Wave 0. Test-method names use the camelCase-verb convention. Do NOT stub Machine/Fleet; the tests drive their creation.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on tests/suite/TestMachine.m and tests/suite/TestFleet.m (must parse clean; runtime RED is expected pre-implementation)</automated>
  </verify>
  <acceptance_criteria>
    - `tests/suite/TestMachine.m` starts with `classdef TestMachine < matlab.unittest.TestCase` and has a `TestClassSetup` method named `addPaths`.
    - `tests/suite/TestFleet.m` starts with `classdef TestFleet < matlab.unittest.TestCase` with the same setup.
    - `grep -c "function test" tests/suite/TestMachine.m` >= 13 and `grep -c "function test" tests/suite/TestFleet.m` >= 10 (one per behavior listed).
    - Every error-id in <behavior> appears verbatim in a `verifyError` call (grep each: `Machine:missingId`, `Machine:invalidOption`, `Machine:duplicateKey`, `Machine:invalidType`, `Machine:unknownKey`, `Fleet:duplicateMachineId`).
    - Both files pass `mcp__matlab__check_matlab_code` (no syntax/parse errors).
    - Running `tests/suite/TestMachine.m` via MCP FAILS only with "Unrecognized ... Machine" / undefined-class style errors (RED-by-design), not parse errors — confirming the scaffold is well-formed and awaiting Plans 03/04.
  </acceptance_criteria>
  <done>Both class suites parse clean, contain the full RED behavior set with the exact error identifiers, clear TagRegistry between methods, and fail at runtime only because Machine/Fleet are not yet implemented.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Author RED Octave flat tests test_machine.m + test_fleet.m</name>
  <files>tests/test_machine.m, tests/test_fleet.m</files>
  <read_first>
    - tests/test_tag_registry.m lines 1-70 (flat function-based structure, local `add_*_path()` helper, assert + fprintf('    All N tests passed.\n') — the exact analog)
    - tests/run_all_tests.m around line 98 (Octave branch runs `dir('test_*.m')`; class suites in tests/suite/ do NOT run on Octave — this is why these flat files exist)
    - libs/SensorThreshold/SensorTag.m lines 32-115 (SensorTag is Octave-safe; use it as the Tag in flat tests since MockTag lives in tests/suite/ and is not on Octave's flat path)
    - 1042-PATTERNS.md "test_machine.m + test_fleet.m (Octave flat)" section
  </read_first>
  <behavior>
    test_machine.m (Octave-critical paths, FLEET-02 + FLEET-03):
    - Two machines each addTag `'temperature'` (SensorTag); assert no error and `TagRegistry.find(@(t)true)` empty after (TagRegistry.clear at start + end).
    - Duplicate key on one machine raises `Machine:duplicateKey` (catch + strfind on identifier).
    - tagSource_ default path (FLEET-03): construct `BatchTagPipeline('OutputDir', tmp)` with NO 'TagSource' arg and assert it constructs without error (proves single-machine default preserved on Octave).
    test_fleet.m (Octave-critical paths, FLEET-04 + FLEET-06):
    - save a 2-machine fleet to a tempname json, `Fleet.load` it, assert machineCount==2 and Names preserved (FLEET-04 round-trip ON OCTAVE).
    - assert saved JSON file text contains `"fleetConfigVersion":1`.
    - filterByName / filterByGroup return expected subsets (Octave strfind path, FLEET-06).
  </behavior>
  <action>
    Author `tests/test_machine.m` and `tests/test_fleet.m` as flat function-based tests modeled on `tests/test_tag_registry.m`. Each defines `function test_machine()` / `function test_fleet()` plus a local `add_fleet_path_()` helper (`addpath(repo); install();`, repo = one `fileparts` up). Use `assert(cond, msg)` for every check and end with `fprintf('    All N tests passed.\n')` with N the real count. Use real `SensorTag` objects (Octave-safe) for catalog content — do NOT reference `MockTag` (it is in tests/suite/, not on Octave's flat discovery path). Call `TagRegistry.clear()` at start and end. These tests are RED until Plans 03/04 land Machine/Fleet — expected for Wave 0. Keep each file under the MISS_HIT function-length limit; factor helpers if needed.
  </action>
  <verify>
    <automated>mcp__matlab__check_matlab_code on tests/test_machine.m and tests/test_fleet.m (must parse clean)</automated>
  </verify>
  <acceptance_criteria>
    - `tests/test_machine.m` defines `function test_machine` and a local `add_fleet_path_` helper; matches the `test_*.m` flat naming so `run_all_tests.m` Octave branch discovers it.
    - `tests/test_fleet.m` defines `function test_fleet` similarly.
    - Neither flat file references `MockTag` (grep returns 0) — they use `SensorTag`.
    - Both files contain `TagRegistry.clear()` at least twice (start + end) — `grep -c "TagRegistry.clear" tests/test_machine.m` >= 2.
    - `test_fleet.m` asserts the JSON text contains `"fleetConfigVersion":1` (grep shows the literal).
    - Both pass `mcp__matlab__check_matlab_code`.
    - Running `test_machine()` via MCP `evaluate_matlab_code` fails only with undefined-`Machine` style errors (RED-by-design), not parse errors.
  </acceptance_criteria>
  <done>Both flat Octave tests parse clean, use only Octave-safe primitives and real SensorTag, clear TagRegistry, and fail at runtime only because Machine/Fleet are not yet implemented.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| test harness -> filesystem | Tests write temp csv/json under `tempname`/`tempdir`; no untrusted external input |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1042-01 | Tampering | Test temp files left on disk | accept | Tests write under `tempname`/`tempdir`; OS reclaims; no security impact |
| T-1042-SC | Tampering | npm/pip/cargo installs | n/a | No package installs in this phase — pure MATLAB/Octave, toolbox-free (RESEARCH.md Package Legitimacy Audit: not applicable) |
</threat_model>

<verification>
- `mcp__matlab__check_matlab_code` passes on all 5 files (4 tests + 1 helper).
- `normalizeToCell_` behavioral parity confirmed against Dashboard original (empty/struct-array/cell).
- Class suites and flat tests are RED-by-design (undefined Machine/Fleet), proving the scaffold is well-formed and awaiting Plans 03/04 — Nyquist Wave 0 satisfied.
- No production `libs/Fleet/Machine.m` or `Fleet.m` created in this plan.
</verification>

<success_criteria>
- 4 RED test files created (2 MATLAB class suites + 2 Octave flat), each parsing clean and encoding the FLEET-01..06 behavior with exact error identifiers.
- `libs/Fleet/private/normalizeToCell_.m` created and GREEN (behavioral parity with Dashboard original).
- Octave-CI gap closed: `test_machine.m` + `test_fleet.m` discoverable by `run_all_tests.m` Octave branch.
- No cross-library private reach: Fleet has its own normalizeToCell_.
</success_criteria>

<output>
Create `.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-01-SUMMARY.md` when done.
</output>
