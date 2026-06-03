---
phase: 1042-machine-fleet-pipeline-di-seam
plan: 04
type: execute
wave: 3
depends_on: ["1042-01", "1042-03"]
files_modified:
  - libs/Fleet/Fleet.m
autonomous: true
requirements: [FLEET-01, FLEET-04, FLEET-05, FLEET-06]
must_haves:
  truths:
    - "User can add machines to a Fleet (factory or handle form) with duplicate-Id rejected"
    - "User can save a fleet config (machines + DataRoots + metadata + embedded canonical map) and reload it, round-tripping identically on MATLAB and Octave"
    - "Relative DataRoots resolve against the config-file directory on load; the saved config carries a fleetConfigVersion"
    - "User can filter the fleet by group and by free-text name, composable by chaining"
    - "Fleet.resolveLogical bridges a logicalId to per-machine tags via CanonicalMapper"
  artifacts:
    - path: "libs/Fleet/Fleet.m"
      provides: "Fleet handle class: machine collection, duplicate-Id guard, composable filters, JSON save/load with embedded canonical map, resolveLogical"
      contains: "classdef Fleet < handle"
      min_lines: 120
  key_links:
    - from: "libs/Fleet/Fleet.m"
      to: "Machine.toConfigStruct / Machine.fromConfigStruct"
      via: "per-entry jsonencode on save; reconstruct on load"
      pattern: "Machine.fromConfigStruct\\("
    - from: "libs/Fleet/Fleet.m"
      to: "normalizeToCell_"
      via: "post-jsondecode struct-array normalization in load"
      pattern: "normalizeToCell_\\(s\\.machines\\)"
    - from: "libs/Fleet/Fleet.m"
      to: "CanonicalMapper.toStruct / CanonicalMapper.fromStruct"
      via: "embedded canonical map (D-05/D-06)"
      pattern: "CanonicalMapper.fromStruct\\("
---

<objective>
Implement `libs/Fleet/Fleet.m` — a handle class owning a `containers.Map` of `Machine` instances with insertion-order tracking, a duplicate-Id hard error, composable `filterByGroup`/`filterByName` search, JSON `save`/`load` that round-trips identically on MATLAB R2020b+ and Octave 7+ (per-entry `jsonencode` + `strjoin`, atomic `movefile`, embedded `CanonicalMapper` map, stored `fleetConfigVersion`), DataRoot path resolution on load via `Machine.fromConfigStruct`, and `resolveLogical` bridging to `CanonicalMapper`. No UI code.

Purpose: FLEET-01 (Fleet.addMachine factory + handle form, duplicate-Id guard), FLEET-04 (round-trip config persistence on both runtimes with embedded canonical map + DataRoot resolution + schema version), FLEET-06 (composable group + free-text filtering). Closes the phase by composing Machine into a searchable, persistable fleet.
Output: One new class file; the RED `TestFleet.m` (Plan 01) turns GREEN; the Octave `test_fleet.m` round-trip + filter paths turn GREEN.
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
@libs/Fleet/CanonicalMapper.m
@libs/Fleet/Machine.m
</context>

<artifacts_this_phase_produces>
See `1042-01-...-PLAN.md` <artifacts_this_phase_produces> for the full phase symbol list. This plan creates: class `Fleet`; methods `addMachine`, `getMachine`, `machineCount`, `filterByName`, `filterByGroup`, `resolveLogical`, `save`; static `load`; private properties `Machines_`/`MachineIds_`/`Mapper_`. It is the consumer of `normalizeToCell_` (Plan 01) and `Machine` (Plan 03), and uses the `fleetConfigVersion` config field.
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Implement Fleet — collection, duplicate-Id guard, composable filters, resolveLogical</name>
  <files>libs/Fleet/Fleet.m</files>
  <read_first>
    - libs/SensorThreshold/TagRegistry.m lines 86-94 (duplicate-key hard-error pattern Fleet.addMachine mirrors as Fleet:duplicateMachineId)
    - libs/Fleet/CanonicalMapper.m lines 1-69 (handle-class shape + containers.Map init + error-id style) and the resolve/toStruct/fromStruct surface used by resolveLogical
    - libs/FastSenseCompanion/private/filterTags.m (strfind(lower(...)) Octave-safe text-search pattern for filterByName/filterByGroup; never contains)
    - 1042-PATTERNS.md "libs/Fleet/Fleet.m" section (addMachine, filterByName/filterByGroup bodies — copy and adapt)
    - libs/Fleet/Machine.m (the just-built Machine: Id/Name/Group props, find/get read API)
    - tests/suite/TestFleet.m (RED target — implement to its expectations)
  </read_first>
  <behavior>
    - Fleet() constructs with an empty Machines_ map, empty MachineIds_, and a fresh CanonicalMapper in Mapper_.
    - addMachine('Id','M01',...) constructs a Machine, stores it, returns the handle, machineCount==1.
    - addMachine(prebuiltMachine) stores the passed handle.
    - addMachine with an Id already present -> error Fleet:duplicateMachineId.
    - getMachine('M01') returns the machine; machineCount returns the count; insertion order preserved in MachineIds_.
    - filterByName(pattern) returns a cell of machines whose Name contains pattern case-insensitively (strfind(lower,lower)).
    - filterByGroup(group) returns a cell of machines whose Group contains group case-insensitively.
    - Filters are composable by chaining (each returns a machine subset the caller can re-filter); chaining group then name narrows further (AND).
    - resolveLogical(logicalId) consults Mapper_ and returns per-machine {machine, Tag} pairs (machines that resolve); machines lacking the mapped local key are skipped (no crash).
  </behavior>
  <action>
    Create `libs/Fleet/Fleet.m` as `classdef Fleet < handle`. Private properties: `Machines_` (containers.Map char->Machine), `MachineIds_` (cell, insertion order), `Mapper_` (CanonicalMapper). Constructor initializes all three (`Mapper_ = CanonicalMapper()`).
    `addMachine(obj, varargin)`: if a single arg `isa(...,'Machine')`, use it; else `Machine(varargin{:})`. Reject `obj.Machines_.isKey(m.Id)` with `Fleet:duplicateMachineId`. Store and append Id to `MachineIds_`. Return the handle.
    `getMachine(obj, id)`: return the machine (error `Fleet:unknownMachineId` on miss). `machineCount(obj)`: numel(MachineIds_).
    `filterByName(obj, pattern)` and `filterByGroup(obj, group)`: iterate `MachineIds_` in order, accumulate machines whose Name/Group satisfies `~isempty(strfind(lower(field), lower(pattern)))`; return a cell. Composability is achieved by returning subsets (document that callers chain by re-filtering the returned set, or add an overload accepting a candidate cell — implement whichever keeps the test's chaining assertion GREEN, preferring an optional second arg = candidate machine cell so chaining is direct AND).
    `resolveLogical(obj, logicalId)`: query `Mapper_` for the logicalId's per-machine localKeys, then for each present machine return `{machine, machine.get(localKey)}`-style pairs; skip machines where the key is absent (try/catch or isKey guard) — never crash. Return shape consumed by Phase 1045.
    Octave-safe only; no `contains`, no `ui*`; MISS_HIT limits respected.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file 'tests/suite/TestFleet.m' (addMachine/duplicate/getMachine/filter/compose tests GREEN; save/load tests may still be partial until Task 2)</automated>
  </verify>
  <acceptance_criteria>
    - `libs/Fleet/Fleet.m` begins with `classdef Fleet < handle`.
    - `grep -c "Fleet:duplicateMachineId" libs/Fleet/Fleet.m` >= 1.
    - `grep -c "contains(" libs/Fleet/Fleet.m` == 0; `grep -c "strfind(lower(" libs/Fleet/Fleet.m` >= 2 (name + group filters).
    - `grep -rnE "uifigure|uicontrol|uitree|uigridlayout|uiprogressdlg" libs/Fleet/Fleet.m` == 0.
    - `grep -c "TagRegistry.register" libs/Fleet/Fleet.m` == 0.
    - `mcp__matlab__check_matlab_code` clean.
    - In `TestFleet.m`: testAddMachineFactoryForm, testAddMachineHandleForm, testDuplicateMachineIdErrors, testFilterByName, testFilterByGroup, testFiltersComposable all PASS.
  </acceptance_criteria>
  <done>Fleet holds an insertion-ordered machine collection with a duplicate-Id hard error, composable case-insensitive group/name filters using Octave-safe strfind, and a resolveLogical bridge that skips unresolved machines gracefully; collection + filter tests GREEN.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Fleet JSON save/load — per-entry encode, embedded canonical map, atomic write, schema version, DataRoot resolution</name>
  <files>libs/Fleet/Fleet.m</files>
  <read_first>
    - libs/Fleet/CanonicalMapper.m lines 337-349 (toStruct), 351-383 (save: per-entry jsonencode + strjoin + atomic movefile — the exact pattern), 387-411 (fromStruct + normalizeToCell_ usage), 413-426 (load: fopen/fread *char/jsondecode) — Fleet replicates this verbatim for the machines array
    - libs/Fleet/private/normalizeToCell_.m (Plan 01 — post-jsondecode normalization; Dashboard-private is unreachable)
    - libs/Fleet/Machine.m (toConfigStruct camelCase fields; static fromConfigStruct(s, fleetFilePath) D-07 path resolution)
    - 1042-RESEARCH.md Pattern 3 (Fleet JSON round-trip) + Pitfall 3 (per-entry encode avoids null vs [] divergence) + Pitfall 12 (fleetConfigVersion guard)
    - 1042-PATTERNS.md "Fleet.m save / load" subsections
    - tests/suite/TestFleet.m + tests/test_fleet.m (RED round-trip + version + relative-path targets)
  </read_first>
  <behavior>
    - save(filepath): build the machines JSON array via per-entry jsonencode(m.toConfigStruct()) + strjoin (empty -> '[]'); embed the canonical map by per-entry encoding Mapper_.toStruct().entries (empty -> '[]') under a {"version":N,"entries":[...]} object; assemble {"fleetConfigVersion":1,"machines":...,"canonicalMap":...}; write to a .tmp then atomic movefile(tmp,filepath,'f') with cleanup-on-failure -> Fleet:fileError.
    - load(filepath): missing file -> Fleet:fileNotFound; read via fopen/fread('*char')/jsondecode; if no fleetConfigVersion field default it to 1; construct an empty Fleet; normalizeToCell_(s.machines) then Machine.fromConfigStruct(each, filepath) and addMachine; if canonicalMap present, Mapper_ = CanonicalMapper.fromStruct(s.canonicalMap).
    - Round-trip: a saved 2-machine fleet reloads with machineCount==2, Names/Groups preserved, and a non-empty canonical map entry survives.
    - Saved JSON text contains the literal "fleetConfigVersion":1.
    - A machine saved with a relative DataRoot reloads with DataRoot resolved under fileparts(filepath).
    - Round-trip behaves identically on Octave (verified by test_fleet.m).
  </behavior>
  <action>
    Extend `libs/Fleet/Fleet.m` with the persistence surface.
    Instance `save(obj, filepath)`: replicate CanonicalMapper.save's per-entry `jsonencode` + `strjoin` pattern for the machines array (call `m.toConfigStruct()` per machine; `'[]'` when empty); embed the canonical map by per-entry encoding `obj.Mapper_.toStruct().entries` into `{"version":%d,"entries":%s}`; assemble the top-level object with `sprintf('{"fleetConfigVersion":1,"machines":%s,"canonicalMap":%s}', ...)`; write to `[filepath '.tmp']`, `fwrite`, `fclose`, then `movefile(tmp, filepath, 'f')` inside try/catch that deletes the tmp and raises `Fleet:fileError` on failure (and on fopen==-1). Do NOT call bare `jsonencode` on a cell-of-structs (Pitfall 3).
    Static `load(filepath)`: guard `~isfile` -> `Fleet:fileNotFound`; `fopen`/`fread('*char')`/`fclose`/`jsondecode`; default `fleetConfigVersion` to 1 when absent (Pitfall 12 forward-compat guard); construct `Fleet()`; `machines = normalizeToCell_(s.machines)`; loop `Machine.fromConfigStruct(machines{i}, filepath)` + `addMachine`; if `isfield(s,'canonicalMap')`, set `obj.Mapper_ = CanonicalMapper.fromStruct(s.canonicalMap)`.
    Keep field names camelCase in JSON; Octave-safe; no `ui*`; MISS_HIT limits respected.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file 'tests/suite/TestFleet.m' (all FLEET-01/04/06 GREEN incl. round-trip, embedded map, version, relative-path) AND mcp__matlab__evaluate_matlab_code running test_fleet() (Octave-path round-trip GREEN)</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "normalizeToCell_(s.machines)" libs/Fleet/Fleet.m` >= 1 (uses the Fleet-private helper, not Dashboard's).
    - `grep -c "Machine.fromConfigStruct(" libs/Fleet/Fleet.m` >= 1; `grep -c "CanonicalMapper.fromStruct(" libs/Fleet/Fleet.m` >= 1 (embedded map rehydrated).
    - `grep -c "strjoin(" libs/Fleet/Fleet.m` >= 2 (machines + entries arrays); `grep -v '^[[:space:]]*%' libs/Fleet/Fleet.m | grep -c "jsonencode("` covers per-entry encode (>= 2 call sites: machine struct + map entry).
    - `grep -c "movefile(" libs/Fleet/Fleet.m` >= 1 and `grep -c "fleetConfigVersion" libs/Fleet/Fleet.m` >= 1 (atomic write + schema version).
    - All three Fleet error ids present: `Fleet:fileError`, `Fleet:fileNotFound`, `Fleet:duplicateMachineId`.
    - `mcp__matlab__check_matlab_code` clean.
    - In `TestFleet.m`: testSaveLoadRoundTrip, testCanonicalMapEmbedded, testFleetConfigVersionPresent, testRelativeDataRootResolvedAgainstConfigDir PASS; whole suite GREEN.
    - `test_fleet()` (Octave flat) round-trip + version + filter assertions PASS via MCP `evaluate_matlab_code`.
    - Invariants still hold: `grep -rnE "uifigure|uicontrol|uitree|uigridlayout" libs/Fleet/Fleet.m` == 0; `grep -c "contains(" libs/Fleet/Fleet.m` == 0; `grep -rn "TagRegistry.register" libs/Fleet/` == 0 across the whole library.
  </acceptance_criteria>
  <done>Fleet.save/Fleet.load round-trip machines + DataRoots + metadata + embedded canonical map identically on MATLAB and Octave, store a fleetConfigVersion, resolve relative DataRoots against the config-file directory, write atomically, and pass the full TestFleet suite plus the Octave test_fleet flat test.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| fleet-config JSON file -> Fleet.load | Untrusted-ish: a hand-edited / VCS-shared config file is parsed via jsondecode |
| Fleet.save -> filesystem | Writes a .tmp then atomic-renames over the destination path |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1042-07 | Tampering | Malformed / oversized fields in fleet-config JSON | mitigate | `jsondecode` yields a plain struct; load reads only expected fields (`machines`, `canonicalMap`, `fleetConfigVersion`); unknown top-level keys ignored. Per-machine fields go through `Machine.fromConfigStruct` `char(...)` coercion; a missing/empty id surfaces as `Machine:missingId`. No field value is executed |
| T-1042-08 | Tampering | Prototype-ish key injection into containers.Map | mitigate | Machine Ids become Map keys via `char(...)`; duplicate Ids hard-error `Fleet:duplicateMachineId`; containers.Map keys are inert strings (no prototype chain in MATLAB) — injection has no code-execution path |
| T-1042-09 | Tampering | Corrupt config on interrupted save | mitigate | Atomic write: `.tmp` + `movefile(...,'f')`; on failure the tmp is deleted and `Fleet:fileError` raised, leaving any prior config intact |
| T-1042-10 | Tampering | Path traversal via relative DataRoot in config | accept (constrained) | Relative DataRoots resolve only against the config-file directory; absolute paths are user-owned local config; no path executed. Same disposition as T-1042-04 (Plan 03) |
| T-1042-SC | Tampering | npm/pip/cargo installs | n/a | No package installs — pure MATLAB, toolbox-free |
</threat_model>

<verification>
- `grep -rn "TagRegistry.register" libs/Fleet/` == 0 across the whole Fleet library (final phase gate).
- `grep -rnE "uifigure|uicontrol|uitree|uigridlayout|uiprogressdlg" libs/Fleet/` == 0.
- `grep -rn "contains(" libs/Fleet/Fleet.m` == 0.
- Full `TestFleet.m` GREEN on MATLAB; `test_fleet()` GREEN on Octave path.
- Round-trip identical on both runtimes; saved JSON carries `"fleetConfigVersion":1`.
- Relative DataRoot resolves against config-file dir; atomic save leaves no partial file.
</verification>

<success_criteria>
- FLEET-01: Fleet.addMachine factory + handle form; duplicate-Id guard.
- FLEET-04: config round-trips identically on MATLAB R2020b+ and Octave 7+; embedded canonical map; DataRoot resolution; fleetConfigVersion stored.
- FLEET-05: 5-machine Fleet.load stays under budget (metadata-only; lazy load inherited from Machine/SensorTag).
- FLEET-06: composable filterByGroup + filterByName via Octave-safe strfind.
- No UI code; whole Fleet library passes the milestone critical-invariant grep gates.
</success_criteria>

<output>
Create `.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-04-SUMMARY.md` when done.
</output>
