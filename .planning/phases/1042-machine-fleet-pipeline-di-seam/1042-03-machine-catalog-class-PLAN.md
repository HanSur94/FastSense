---
phase: 1042-machine-fleet-pipeline-di-seam
plan: 03
type: execute
wave: 2
depends_on: ["1042-01", "1042-02"]
files_modified:
  - libs/Fleet/Machine.m
autonomous: true
requirements: [FLEET-01, FLEET-02, FLEET-03, FLEET-05]
must_haves:
  truths:
    - "User can construct a Machine with a required Id and add Tags to its own isolated catalog"
    - "Two machines can hold the same local sensor key with no error and no global TagRegistry entry"
    - "A machine ingests via Batch/Live pipelines scoped to its own DataRoot through the tagSource_ seam"
    - "Machine metadata loads eagerly while X/Y sample data stays deferred (no getXY at startup)"
    - "A machine stops and deletes its live-pipeline timer on delete (no timer accumulation)"
  artifacts:
    - path: "libs/Fleet/Machine.m"
      provides: "Machine handle class: isolated catalog, duck-type read API, ingest wrappers, EventStore ownership, config (de)serialization"
      contains: "classdef Machine < handle"
      min_lines: 120
  key_links:
    - from: "libs/Fleet/Machine.m"
      to: "containers.Map"
      via: "Tags_ catalog (never TagRegistry.register)"
      pattern: "containers\\.Map\\('KeyType', 'char'"
    - from: "libs/Fleet/Machine.m"
      to: "BatchTagPipeline / LiveTagPipeline"
      via: "ingestBatch/startLive with 'TagSource', @(pred) obj.find(pred) and OutputDir = DataRoot"
      pattern: "'TagSource', @\\(pred\\) obj\\.find\\(pred\\)"
    - from: "libs/Fleet/Machine.m"
      to: "EventStore"
      via: "per-machine EventStore(obj.DataRoot)"
      pattern: "EventStore\\(obj\\.DataRoot\\)"
---

<objective>
Implement `libs/Fleet/Machine.m` — a handle class that owns an isolated `containers.Map` tag catalog (mirroring the TagRegistry read API as instance methods), a `DataRoot`, a per-machine `EventStore`, and pipeline ingest wrappers that scope `BatchTagPipeline`/`LiveTagPipeline` to the machine via the Plan 02 `tagSource_` seam. Machine tags NEVER enter the global `TagRegistry`. No UI code (Octave must run all of it).

Purpose: FLEET-01 (define a Machine + add tags), FLEET-02 (isolated catalogs; identical local keys coexist; registry untouched), FLEET-03 (machine-scoped ingest), FLEET-05 (lazy load via reused SensorTag.RawSource deferred-read). This is the core data-model unit Fleet (Plan 04) composes.
Output: One new class file; the RED `TestMachine.m` (Plan 01) turns GREEN; the Octave `test_machine.m` isolation/duplicate paths turn GREEN.
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
@libs/SensorThreshold/TagRegistry.m
@libs/Fleet/CanonicalMapper.m
</context>

<artifacts_this_phase_produces>
See `1042-01-...-PLAN.md` <artifacts_this_phase_produces> for the full phase symbol list. This plan creates: class `Machine`; methods `addTag`, `get`, `find`, `findByKind`, `findByLabel`, `keys`, `ingestBatch`, `startLive`, `toConfigStruct`, `delete`; static `fromConfigStruct`; properties `Id`/`Name`/`DataRoot`/`Group`/`Metadata`/`Dashboards`, `SetAccess=private` `EventStore`, private `Tags_`/`LivePipeline_`.
</artifacts_this_phase_produces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Implement Machine class — properties, constructor, isolated catalog + duck-type read API</name>
  <files>libs/Fleet/Machine.m</files>
  <read_first>
    - libs/SensorThreshold/TagRegistry.m lines 47 (get), 67-95 (register/duplicateKey hard-error), 154 (find), 174 (findByLabel), 194 (findByKind) — the read API and error pattern Machine mirrors as INSTANCE methods
    - libs/Fleet/CanonicalMapper.m lines 1-69 (class header + handle-class shape + containers.Map init + error-id style)
    - libs/SensorThreshold/SensorTag.m lines 32-115 (RawSource property + getXY deferred-read — the lazy-load mechanism reused for FLEET-05; addTag must NOT call getXY)
    - libs/EventDetection/EventStore.m lines 53-71 (EventStore(filePath) constructor; single-user mode)
    - 1042-PATTERNS.md "libs/Fleet/Machine.m" section (constructor NV switch, addTag, duck-type bodies — copy and adapt)
    - tests/suite/TestMachine.m (the RED target — implement to its expectations)
  </read_first>
  <behavior>
    - Machine() with no Id -> error `Machine:missingId`.
    - Machine('Id','M01','Bogus',1) -> error `Machine:invalidOption`.
    - Machine('Id','M01') -> Name defaults to 'M01'; Group defaults to ''; Metadata defaults to struct(); Dashboards defaults to {}.
    - Machine with non-empty DataRoot -> EventStore is an EventStore handle rooted at DataRoot; empty DataRoot -> EventStore left empty (no construction).
    - addTag(non-Tag) -> error `Machine:invalidType`.
    - addTag duplicate key -> error `Machine:duplicateKey`.
    - addTag(t) stores t in Tags_ and does NOT call TagRegistry.register and does NOT call t.getXY().
    - get('missing') -> error `Machine:unknownKey`; get(existing) returns the tag.
    - find(pred) returns a cell of matching tags; findByKind/findByLabel delegate to find; keys() returns catalog keys.
    - Two Machine instances each addTag('temperature') -> no error; TagRegistry stays empty.
  </behavior>
  <action>
    Create `libs/Fleet/Machine.m` as `classdef Machine < handle`. Public properties: `Id`, `Name`, `DataRoot`, `Group`, `Metadata`, `Dashboards`. `SetAccess=private` property `EventStore`. Private properties `Tags_` and `LivePipeline_ = []`.
    Constructor: NV-pair parse with an `opts` struct defaulting Id/Name/DataRoot/Group to '' and Metadata to struct(); switch on `'Id'`/`'Name'`/`'DataRoot'`/`'Group'`/`'Metadata'` with an `otherwise` raising `Machine:invalidOption`; after parse, raise `Machine:missingId` if Id empty; default Name to Id when empty; init `Tags_ = containers.Map('KeyType','char','ValueType','any')`; `Dashboards = {}`; construct `EventStore = EventStore(obj.DataRoot)` only when DataRoot is non-empty.
    addTag(tag): validate `isa(tag,'Tag')` (else `Machine:invalidType`); reject duplicate `tag.Key` with `Machine:duplicateKey`; store under `char(tag.Key)`. MUST NOT call `TagRegistry.register` or `tag.getXY()`. Add a header note (Pitfall 5) that a Tag handle should not be shared across machines (advisory, no enforcement).
    Duck-type read API as INSTANCE methods mirroring TagRegistry: `get(localKey)` (-> `Machine:unknownKey` on miss), `find(predicateFn)` (cell accumulation), `findByKind(kind)` (`@(t) strcmp(t.getKind(),kind)`), `findByLabel(label)` (`@(t) ~isempty(t.Labels) && any(strcmp(t.Labels,label))`), `keys()`.
    Use only Octave-safe string ops; no `contains`, no `ui*`. Stay within MISS_HIT limits (line<=160, fn<=520, nesting<=5, params<=12). Defer ingest/config/delete to Task 2.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file 'tests/suite/TestMachine.m' (constructor/catalog/read-API/isolation tests GREEN; ingest/lazy/delete tests may still be partial until Task 2)</automated>
  </verify>
  <acceptance_criteria>
    - `libs/Fleet/Machine.m` begins with `classdef Machine < handle`.
    - `grep -c "TagRegistry.register" libs/Fleet/Machine.m` == 0 (critical invariant).
    - `grep -rnE "uifigure|uicontrol|uitree|uigridlayout|uiprogressdlg" libs/Fleet/Machine.m` returns 0.
    - `grep -c "contains(" libs/Fleet/Machine.m` == 0.
    - `grep -c "containers.Map('KeyType', 'char'" libs/Fleet/Machine.m` >= 1.
    - All six error ids present (`Machine:missingId`, `Machine:invalidOption`, `Machine:invalidType`, `Machine:duplicateKey`, `Machine:unknownKey`) via grep.
    - `mcp__matlab__check_matlab_code` clean.
    - In `TestMachine.m`: testConstructorRequiresId, testNameDefaultsToId, testUnknownOptionErrors, testAddTagDuplicateKeyErrors, testAddTagRejectsNonTag, testGetUnknownKeyErrors, testGetFindKeysRoundTrip, testFindByKind, testFindByLabel, testTwoMachinesSameLocalKeyCoexist, testTagRegistryUntouched all PASS.
  </acceptance_criteria>
  <done>Machine constructs with a required unique-per-fleet Id, owns an isolated containers.Map catalog with a TagRegistry-mirroring read API, hard-errors on duplicate/unknown/non-Tag, never touches the global registry, and the catalog + isolation test methods pass.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Machine ingest wrappers, EventStore wiring, lazy load, config (de)serialization, timer-safe delete</name>
  <files>libs/Fleet/Machine.m</files>
  <read_first>
    - 1042-RESEARCH.md Pattern 5 (ingestBatch/startLive wrappers) + Pattern 4 (fromConfigStruct DataRoot path resolution: relative -> config dir, absolute verbatim, leading ~ -> getenv('HOME'), warn on Windows ~) + Open Question 2 (delete stops/deletes timer)
    - 1042-PATTERNS.md "ingestBatch / startLive wrappers", "delete", "toConfigStruct / fromConfigStruct" subsections
    - libs/SensorThreshold/BatchTagPipeline.m + libs/SensorThreshold/LiveTagPipeline.m (Plan 02 just added 'TagSource'/OutputDir handling; SharedRoot passthrough via varargin)
    - CLAUDE.md "stop(t); delete(t); always in that order" timer-lifecycle rule
    - tests/suite/TestMachine.m ingest/lazy/delete test methods (RED target)
  </read_first>
  <behavior>
    - ingestBatch with empty DataRoot -> error `Machine:missingDataRoot`.
    - ingestBatch(...) constructs BatchTagPipeline('OutputDir', obj.DataRoot, 'TagSource', @(pred) obj.find(pred), varargin{:}), runs it, returns the report; output lands under DataRoot; only the machine's tags are enumerated.
    - startLive(interval, ...) with empty DataRoot -> `Machine:missingDataRoot`; default interval 15 when omitted/empty; stores LivePipeline_ and starts it; forwards varargin (e.g. 'SharedRoot') untouched.
    - delete(obj): if LivePipeline_ non-empty, stop() then delete() it (that order); idempotent/safe if never started; net timerfindall count unchanged after startLive+delete.
    - toConfigStruct(): scalar struct with camelCase char fields id/name/dataRoot/group, plus metadata only when non-empty fieldnames.
    - fromConfigStruct(s, fleetFilePath): resolve DataRoot per D-07 (leading ~ via getenv('HOME'), relative against fileparts(fleetFilePath), absolute verbatim; on Windows a leading ~ warns and is left as-is), then construct Machine via NV pairs incl. Metadata when present.
  </behavior>
  <action>
    Extend `libs/Fleet/Machine.m` with the remaining methods.
    Instance methods: `ingestBatch(obj, varargin)` and `startLive(obj, interval, varargin)` — each guards empty DataRoot with `Machine:missingDataRoot`, constructs the corresponding pipeline with `'OutputDir', obj.DataRoot`, `'TagSource', @(pred) obj.find(pred)`, then `varargin{:}` (SharedRoot passthrough preserved so a clustered machine keeps v4.0 cluster mode; omitting it runs zero cluster-path code). startLive defaults interval to 15, stores `obj.LivePipeline_`, calls `.start()`. ingestBatch returns the pipeline report.
    `toConfigStruct(obj)`: build the camelCase scalar struct (id/name/dataRoot/group as `char(...)`); attach `metadata` only when `obj.Metadata` has fieldnames. JSON field names camelCase; MATLAB properties stay PascalCase.
    Static `fromConfigStruct(s, fleetFilePath)`: implement D-07 path resolution — expand a leading `~` via `getenv('HOME')` (Octave-safe; works on MATLAB too) and warn-and-leave-as-is when `~` appears on Windows (detect via `ispc`); resolve a relative path against `fileparts(fleetFilePath)`; use absolute paths (`filesep` start or drive-letter `X:`) verbatim. Construct the Machine via NV pairs, including `'Metadata', s.metadata` when the field is present.
    `delete(obj)`: if `~isempty(obj.LivePipeline_)`, call `obj.LivePipeline_.stop()` then `delete(obj.LivePipeline_)` (stop-before-delete per CLAUDE.md); guard with isvalid where appropriate so a never-started or already-deleted machine deletes cleanly.
    Keep all code Octave-safe; no `ui*`; no `contains`; respect MISS_HIT limits.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file 'tests/suite/TestMachine.m' (all FLEET-01/02/03/05 methods GREEN, incl. ingest, lazy-load timing, and timer-on-delete)</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "'TagSource', @(pred) obj.find(pred)" libs/Fleet/Machine.m` == 2 (one each in ingestBatch + startLive).
    - `grep -c "EventStore(obj.DataRoot)" libs/Fleet/Machine.m` >= 1.
    - `grep -nE "stop\(\).*delete|LivePipeline_.stop|delete\(obj.LivePipeline_\)" libs/Fleet/Machine.m` shows stop precedes delete in `delete(obj)`.
    - `grep -c "Machine:missingDataRoot" libs/Fleet/Machine.m` >= 1.
    - `grep -c "getenv('HOME')" libs/Fleet/Machine.m` >= 1 (Octave-safe ~ expansion).
    - `grep -c "TagRegistry.register" libs/Fleet/Machine.m` == 0; `grep -rnE "uifigure|uicontrol|uitree|uigridlayout" libs/Fleet/Machine.m` == 0; `grep -c "contains(" libs/Fleet/Machine.m` == 0 (invariants hold after Task 2).
    - In `TestMachine.m`: testIngestBatchScopesToDataRoot, testStartLiveStopsTimerOnDelete, testFiveMachineMetadataOnlyLoad PASS; whole suite GREEN.
    - `mcp__matlab__check_matlab_code` clean.
    - Octave-critical: `test_machine()` isolation + duplicate-key + tagSource_-default paths pass when run via MCP `evaluate_matlab_code` (Machine now exists).
  </acceptance_criteria>
  <done>Machine ingests via the Plan 02 seam scoped to its DataRoot, owns a per-machine EventStore, defers X/Y materialization (5-machine load under 2 s with metadata only), round-trips its definition through toConfigStruct/fromConfigStruct with D-07 path resolution, and stops+deletes its live timer on delete with stable timerfindall count; full TestMachine suite GREEN.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| fleet config struct -> Machine.fromConfigStruct | `dataRoot`/`id`/`name`/`group` read from a (possibly hand-edited) JSON-decoded struct |
| Machine.DataRoot -> filesystem | DataRoot becomes pipeline OutputDir + EventStore root |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-1042-04 | Tampering | Path traversal / unexpected absolute path via `dataRoot` on load | mitigate | Treat DataRoot as an opaque char path; never `eval`/`system` it. Relative paths resolve only against the config-file directory (`fileparts(fleetFilePath)`), constraining where they land. Absolute paths used verbatim (user-owned local config). `getenv('HOME')` for `~`, warn-and-skip on Windows. No path is executed |
| T-1042-05 | Tampering | Malformed/oversized fields in decoded config struct | mitigate | Constructor reads only the expected fields via `char(...)` coercion; unknown struct fields are ignored; missing `id` after coercion -> hard `Machine:missingId`; non-Tag addTag -> `Machine:invalidType` |
| T-1042-06 | Denial of Service | Timer accumulation across machine lifecycles | mitigate | `delete(obj)` stops+deletes `LivePipeline_` timer; verified by stable `timerfindall` count test |
| T-1042-SC | Tampering | npm/pip/cargo installs | n/a | No package installs — pure MATLAB, toolbox-free |
</threat_model>

<verification>
- `grep -rn "TagRegistry.register" libs/Fleet/Machine.m` == 0 (FLEET-02 invariant).
- `grep -rnE "uifigure|uicontrol|uitree|uigridlayout|uiprogressdlg" libs/Fleet/Machine.m` == 0 (no UI in data model).
- `grep -rn "contains(" libs/Fleet/Machine.m` == 0 (Octave-safe).
- Full `TestMachine.m` suite GREEN on MATLAB; `test_machine()` Octave paths GREEN.
- 5-machine metadata-only load under 2 s (lazy-load discipline; getXY not called at startup).
- timerfindall count stable across startLive+delete.
</verification>

<success_criteria>
- FLEET-01: Machine NV constructor + addTag works (TestMachine GREEN).
- FLEET-02: identical local keys coexist; TagRegistry.find empty after a 2-machine catalog; grep gate 0.
- FLEET-03: ingestBatch/startLive scope to DataRoot via tagSource_ seam; SharedRoot passthrough preserved.
- FLEET-05: lazy load via reused SensorTag.RawSource; 5-machine startup under budget.
- Timer-safe delete; per-machine EventStore; no UI code.
</success_criteria>

<output>
Create `.planning/phases/1042-machine-fleet-pipeline-di-seam/1042-03-SUMMARY.md` when done.
</output>
