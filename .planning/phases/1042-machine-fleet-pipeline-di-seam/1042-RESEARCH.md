# Phase 1042: Machine + Fleet + Pipeline DI Seam - Research

**Researched:** 2026-06-03
**Domain:** Pure-MATLAB data model — `Machine`, `Fleet`, pipeline `tagSource_` DI seam
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Catalog Population & Lazy Load (FLEET-01, FLEET-05)**
- D-01: Tags populated programmatically via `machine.addTag(t)`. No manifest/catalog file format.
- D-02: "Metadata-only at startup" reuses existing `SensorTag.RawSource` deferred-read path. X/Y arrays not materialized until first `getXY()`. No new lazy mechanism.
- D-03: Fleet config persists machine definitions (Id/Name/DataRoot/Group/Metadata) + embedded canonical map. Does NOT serialize tag catalog. Tags rebuilt by user script or rehydrated from DataRoot `.mat` files.
- D-04: Filesystem auto-discovery of tags from DataRoot is OUT.

**Canonical Map Storage (FLEET-04)**
- D-05: Canonical map embedded inside the single fleet JSON under a `canonicalMap` key. `Fleet.save` inlines `CanonicalMapper.toStruct()`; `Fleet.load` rehydrates via `CanonicalMapper.fromStruct()`.
- D-06: `CanonicalMapper.save`/`load` (lines 351/413) unchanged for direct editor use. Fleet reuses only `toStruct`/`fromStruct` (lines 337/387).

**DataRoot Path Persistence (FLEET-04)**
- D-07: Paths stored as-given. Relative DataRoot resolves against config file's directory on load. Absolute paths used verbatim. Leading `~` expanded.
- D-08: Auto-relativizing absolute DataRoots on save is deferred.

**Machine API & Identity (FLEET-01, FLEET-06)**
- D-09: `Fleet.addMachine` primary form is name-value factory; also accepts pre-built handle. Machine has public NV constructor.
- D-10: `Id` is user-supplied, required, unique within a Fleet. Error `Fleet:duplicateMachineId` on collision. `Name` defaults to `Id` when omitted.
- D-11: `Group` is a single freeform char (default `''`). `Fleet.filterByGroup(g)` and `Fleet.filterByName(pattern)` return machine subsets, composable by chaining. Free-text search uses `strfind(lower(...))`, never `contains`.

**Pipeline DI Seam (FLEET-03) — locked by research**
- D-12: Add private `tagSource_ = @TagRegistry.find` to both `BatchTagPipeline` and `LiveTagPipeline`; `eligibleTags_` calls `obj.tagSource_(pred)` instead of static `TagRegistry.find`. Expose via `'TagSource'` constructor NV pair.
- D-13: `Machine.ingestBatch()` / `Machine.startLive(interval)` wrap pipelines with `OutputDir = machine.DataRoot` and `TagSource = @(pred) machine.find(pred)`. Forward `'SharedRoot'` optionally.

**Machine-owned services**
- D-14: Each `Machine` owns `EventStore = EventStore(machine.DataRoot)`. Global `TagRegistry.setEventStore` slot NOT touched. Machine holds `Dashboards` (cell).

### Claude's Discretion

The planner may refine mechanics (exact property names, error-id spelling, private-helper decomposition, `fleetConfigVersion` value) as long as the ROADMAP success criteria and milestone critical invariants hold.

### Deferred Ideas (OUT OF SCOPE)

- Auto-relativize absolute DataRoot on save (D-08)
- Per-machine catalog manifest written to DataRoot for cross-session rehydration
- Filesystem auto-discovery of machines/tags
- `fleetConfigVersion` migration logic beyond a stored version field
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FLEET-01 | User can define a Machine and add it to a Fleet via script API | Machine NV constructor + Fleet.addMachine factory + containers.Map catalog (Section: Standard Stack) |
| FLEET-02 | Two machines with identical local sensor key coexist without error; machine tags never enter global TagRegistry | Machine owns isolated containers.Map; grep gate; TagRegistry.list() == 0 after 2-machine load (Section: Architecture Patterns) |
| FLEET-03 | Machine ingests via BatchTagPipeline/LiveTagPipeline scoped to its own DataRoot; single-machine usage byte-for-byte unchanged | tagSource_ DI seam; default @TagRegistry.find preserved (Section: Architecture Patterns + Code Examples) |
| FLEET-04 | Fleet config round-trips identically on MATLAB R2020b+ and Octave 7+ | jsonencode per-entry + strjoin pattern from CanonicalMapper.save; normalizeToCell on load; DataRoot path resolution (Section: Common Pitfalls + Code Examples) |
| FLEET-05 | Fleet startup with 5-machine test set stays under 2 s / 50 MB | SensorTag.RawSource deferred-read reused; no X/Y materialization at Fleet startup (Section: Architecture Patterns) |
| FLEET-06 | User can assign a machine to a group and filter/browse the fleet composably | Machine.Group char field + Fleet.filterByGroup/filterByName with strfind(lower(...)) (Section: Standard Stack) |
</phase_requirements>

---

## Summary

Phase 1042 delivers the core Fleet data-model layer: `libs/Fleet/Machine.m`, `libs/Fleet/Fleet.m`, the `tagSource_` DI seam in `BatchTagPipeline` and `LiveTagPipeline`, and test suites for both. `CanonicalMapper.m` and `CanonicalMapEditor.m` (Phase 1041) already exist in `libs/Fleet/` and are dependencies, not deliverables. `install.m` already wires `addpath(fullfile(root, 'libs', 'Fleet'))` — no change needed.

This is a pure data-model phase with no UI code. All Fleet data-model code must run on Octave 7+. The three key implementation challenges are: (1) the JSON round-trip for a heterogeneous fleet config struct containing an embedded canonical-map struct with a `cells-of-structs` entries field, (2) the minimal tagSource_ DI edit that keeps single-machine pipelines byte-for-byte identical while giving Machine full per-machine scoping, and (3) the lazy-load discipline — the `SensorTag.RawSource` path defers X/Y materialization by design, so Machine just needs to not call `getXY()` at startup.

**Primary recommendation:** Implement Machine as a handle class with a `containers.Map` catalog that mirrors the `TagRegistry` read API. Implement Fleet as a handle class owning a `containers.Map` of machines. Write the JSON config using the same per-entry `jsonencode + strjoin` pattern already used by `CanonicalMapper.save`. Confirm Octave CI coverage for `TestMachine.m` and `TestFleet.m` by checking that they are `test_*.m` flat files (not class-based suites) — class-based suites only run on MATLAB in the current `run_all_tests.m`.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Isolated per-machine tag catalog | Machine (data model) | — | Machine owns containers.Map; TagRegistry never touched |
| Fleet search / filter | Fleet (data model) | — | Composable filterByGroup/filterByName return machine subsets |
| Fleet config persistence | Fleet (data model) | CanonicalMapper (toStruct/fromStruct) | Fleet.save/load owns JSON; delegates canonical-map serialization to CanonicalMapper |
| Pipeline tag enumeration | BatchTagPipeline / LiveTagPipeline (data pipeline) | Machine (via tagSource_ closure) | DI seam; pipelines own the enumeration logic; Machine provides the predicate source |
| Lazy data loading | SensorTag.RawSource (existing mechanism) | Machine (avoids eager load) | Existing deferred-read path; Machine does not need new code |
| Per-machine EventStore | Machine (data model) | EventStore (existing class) | Machine.DataRoot passed to EventStore constructor; global slot untouched |
| Cross-session canonical map | Fleet JSON (embedded) | CanonicalMapper.fromStruct | Single-file VCS artifact |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `containers.Map('KeyType','char','ValueType','any')` | MATLAB R2006b+ / Octave 7+ | Machine.Tags_ catalog | Same form used by TagRegistry internally; Octave-compatible |
| `jsonencode` / `jsondecode` | MATLAB R2016b+ / Octave 5+ | Fleet config serialization | Already used throughout codebase (DashboardSerializer, CanonicalMapper); confirmed in `libs/Concurrency/ndjsonDecode.m:29` |
| `movefile(tmp, dest, 'f')` | MATLAB R2006b+ / Octave 7+ | Atomic Fleet.save | Pattern already in `companionPrefs.m` and `EventStore.save()` |
| `strfind(lower(str), lower(pattern))` | All targets | Fleet.filterByName text search | Octave-safe; already in `filterTags.m`, `filterDashboards.m`; never `contains()` |
| `EventStore(dataRoot)` | Phase 1039 (shipped) | Per-machine event persistence | Existing class; single-user mode (no SharedRoot) for per-machine use |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `normalizeToCell` | In-repo (`libs/Dashboard/private/`) | Post-jsondecode cell normalization | After jsondecode of fleet config's machines array and canonical map entries array |
| `SensorTag.RawSource` deferred-read | In-repo | Lazy data loading for FLEET-05 | Machine.addTag stores tag metadata; X/Y only materialize on first getXY() call |
| `BatchTagPipeline` / `LiveTagPipeline` | In-repo | Machine.ingestBatch / Machine.startLive | Wrapped with TagSource + OutputDir = machine.DataRoot |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `jsonencode` per-entry + `strjoin` | bare `jsonencode` on cell-of-structs | Bare `jsonencode` on cell arrays produces subtly different output on Octave vs MATLAB (empty cells, null vs []) — per-entry pattern avoids this entirely |
| `strfind(lower(...))` | `contains()` | `contains` with cell patterns is not reliably available across all Octave versions; `strfind` is universal |
| `containers.Map` for machine catalog | struct with dynamic fields | Map gives O(1) keyed access; matches TagRegistry internal structure |

**No new packages to install** — all functionality uses existing MATLAB/Octave primitives and in-repo helpers.

---

## Package Legitimacy Audit

Not applicable — this phase installs no external packages. Pure-MATLAB, toolbox-free.

---

## Architecture Patterns

### System Architecture Diagram

```
User script
    |
    v
Fleet.addMachine('Id','M01','Name','Machine 1','DataRoot','/data/m01')
    |
    v
Fleet (containers.Map: machineId -> Machine handle)
    |-- Fleet.filterByGroup(g) -> Machine subset
    |-- Fleet.filterByName(pattern) -> Machine subset
    |-- Fleet.resolveLogical(logicalId) -> {machine, Tag} pairs [calls CanonicalMapper]
    |-- Fleet.save(path) -> JSON [per-entry jsonencode + strjoin]
    |-- Fleet.load(path) -> Fleet [jsondecode + normalizeToCell + CanonicalMapper.fromStruct]
    |
    v
Machine (containers.Map: localKey -> Tag handle)
    |-- machine.addTag(t)            -- populate catalog
    |-- machine.get(localKey)        -- TagRegistry.get duck-type
    |-- machine.find(predicateFn)    -- TagRegistry.find duck-type
    |-- machine.findByKind(kind)     -- TagRegistry.findByKind duck-type
    |-- machine.findByLabel(label)   -- TagRegistry.findByLabel duck-type
    |-- machine.keys()               -- TagRegistry.keys duck-type
    |-- machine.ingestBatch()        -- BatchTagPipeline(OutputDir=DataRoot, TagSource=@machine.find)
    |-- machine.startLive(interval)  -- LiveTagPipeline(OutputDir=DataRoot, TagSource=@machine.find)
    |-- machine.DataRoot             -- isolation boundary for pipelines + EventStore
    |-- machine.EventStore           -- EventStore(machine.DataRoot)
    |-- machine.Dashboards           -- cell (for Phase 1044)

BatchTagPipeline / LiveTagPipeline
    |-- tagSource_ = @TagRegistry.find  [DEFAULT — single-machine unchanged]
    |-- eligibleTags_: obj.tagSource_(@(t) isa(t,'SensorTag')||...)
    |-- constructor NV: 'TagSource', fnHandle
```

**TagRegistry — untouched.** 72 static call sites across 31 files are not modified in this phase.

### Recommended Project Structure

```
libs/Fleet/
├── CanonicalMapper.m    (Phase 1041 — shipped)
├── CanonicalMapEditor.m (Phase 1041 — shipped)
├── Machine.m            (NEW — Phase 1042)
└── Fleet.m              (NEW — Phase 1042)

libs/SensorThreshold/
├── BatchTagPipeline.m   (MODIFIED — tagSource_ DI seam only)
└── LiveTagPipeline.m    (MODIFIED — tagSource_ DI seam only)

tests/suite/
├── TestMachine.m        (NEW — MATLAB class-based; will run on MATLAB CI)
└── TestFleet.m          (NEW — MATLAB class-based; will run on MATLAB CI)

tests/
├── test_machine.m       (NEW — Octave flat; will run on Octave CI)
└── test_fleet.m         (NEW — Octave flat; will run on Octave CI)
```

**Critical test structure note:** `run_all_tests.m` runs `tests/suite/Test*.m` on MATLAB (via `TestSuite.fromFolder`) and `tests/test_*.m` on Octave (via `dir('test_*.m')`). Class-based `TestMachine.m` in `tests/suite/` will NOT run on Octave. To get Octave CI coverage, flat function-based `test_machine.m` and `test_fleet.m` must be added to `tests/`. SUMMARY.md flags this explicitly: "TestMachine.m and TestCanonicalMapper.m must be explicitly added to the Octave CI job — not automatic." This is the most commonly missed planning gap for this phase.

### Pattern 1: Machine Duck-Type Read API

Machine must implement the exact same method signatures as TagRegistry object methods so Phase 1044 panes can pass a Machine handle as `registry` without changes.

```matlab
% [CITED: libs/SensorThreshold/TagRegistry.m:47,154,195,174]
% TagRegistry object method signatures Machine must mirror:

% Machine.get(localKey) — mirrors TagRegistry.get(key)
function t = get(obj, localKey)
    if ~obj.Tags_.isKey(localKey)
        error('Machine:unknownKey', ...
            'No tag with key ''%s'' in machine ''%s''.', localKey, obj.Id);
    end
    t = obj.Tags_(localKey);
end

% Machine.find(predicateFn) — mirrors TagRegistry.find(predicateFn)
function ts = find(obj, predicateFn)
    ks = obj.Tags_.keys();
    ts = {};
    for i = 1:numel(ks)
        t = obj.Tags_(ks{i});
        if predicateFn(t)
            ts{end+1} = t; %#ok<AGROW>
        end
    end
end

% Machine.findByKind(kind) — mirrors TagRegistry.findByKind(kind)
function ts = findByKind(obj, kind)
    ts = obj.find(@(t) strcmp(t.getKind(), kind));
end

% Machine.findByLabel(label) — mirrors TagRegistry.findByLabel(label)
function ts = findByLabel(obj, label)
    ts = obj.find(@(t) any(strcmp(label, t.Labels)));
end

% Machine.keys() — mirrors TagRegistry catalog keys
function ks = keys(obj)
    ks = obj.Tags_.keys();
end
```

**Key asymmetry vs TagRegistry:** Machine is a handle class instance. TagRegistry is a static class. The caller in Phase 1044 will call `obj.Registry_.find(...)` (object method) — this works because Machine implements `find` as an instance method. The four static `TagRegistry.find(...)` sites (TagCatalogPane.m:60,205; FastSenseCompanion.m:1616,1618) are NOT in scope for Phase 1042; they are retargeted in Phase 1044.

### Pattern 2: Pipeline tagSource_ DI Seam

**BatchTagPipeline change** — minimal, additive:

```matlab
% [CITED: libs/SensorThreshold/BatchTagPipeline.m:251-261]
% Existing eligibleTags_ (line 251):
%   function tags = eligibleTags_(~)
%       tags = TagRegistry.find(@(t) ...
%
% After DI seam:

properties (Access = private)
    % ... existing properties ...
    tagSource_ = @TagRegistry.find   % DI seam; default = single-machine path (FLEET-03/D-12)
end

% Constructor switch case addition (mirrors existing 'Verbose' case):
case 'TagSource'
    opts.TagSource = varargin{k+1};
% ... then after the switch loop:
obj.tagSource_ = opts.TagSource;   % replaces default only when caller sets it

% eligibleTags_ becomes:
function tags = eligibleTags_(obj)
    tags = obj.tagSource_(@(t) ...
        (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
        isstruct(t.RawSource) && ...
        isfield(t.RawSource, 'file') && ...
        ~isempty(t.RawSource.file));
end
```

**Exact same pattern** applies to `LiveTagPipeline.m:786-806`. The `eligibleTags_` method comment there notes the predicate must be "byte-semantically identical to BatchTagPipeline.eligibleTags_" — after the DI seam change, both call `obj.tagSource_(pred)` with the same predicate body.

**IMPORTANT:** Both pipelines have unknown-option guards that hard-error:
```matlab
% BatchTagPipeline.m:98:
otherwise
    error('TagPipeline:invalidOutputDir', 'Unknown option ''%s''.', key);
```
The `'TagSource'` case must be added to the switch block BEFORE the `otherwise` branch in both files, or the constructor will reject it. Default must be set in the `opts` struct initialization too:
```matlab
% BatchTagPipeline: opts = struct('OutputDir', '', 'Verbose', false);
% After: opts = struct('OutputDir', '', 'Verbose', false, 'TagSource', @TagRegistry.find);
```

### Pattern 3: Fleet JSON Round-Trip (Octave-Safe)

The canonical pattern — established by `CanonicalMapper.save` (lines 351-383) — encodes each entry individually and assembles the JSON array manually:

```matlab
% [CITED: libs/Fleet/CanonicalMapper.m:351-383]
% Fleet.save must replicate this pattern for the machines array:

function save(obj, filepath)
    % 1. Build machines JSON array
    nMachines = numel(obj.MachineIds_);
    machineParts = cell(1, nMachines);
    for i = 1:nMachines
        m = obj.Machines_(obj.MachineIds_{i});
        machineParts{i} = jsonencode(m.toConfigStruct());
    end
    machinesJson = ['[' strjoin(machineParts, ',') ']'];

    % 2. Embed canonical map using CanonicalMapper.toStruct + per-entry encoding
    cmStruct = obj.Mapper_.toStruct();
    nEntries = numel(cmStruct.entries);
    if nEntries == 0
        cmEntriesJson = '[]';
    else
        cmParts = cell(1, nEntries);
        for j = 1:nEntries
            cmParts{j} = jsonencode(cmStruct.entries{j});
        end
        cmEntriesJson = ['[' strjoin(cmParts, ',') ']'];
    end
    cmJson = sprintf('{"version":%d,"entries":%s}', cmStruct.version, cmEntriesJson);

    % 3. Assemble top-level JSON
    json = sprintf('{"fleetConfigVersion":1,"machines":%s,"canonicalMap":%s}', ...
        machinesJson, cmJson);

    % 4. Atomic write (movefile pattern)
    tmp = [filepath '.tmp'];
    fid = fopen(tmp, 'w');
    if fid == -1; error('Fleet:fileError', 'Cannot open: %s', tmp); end
    fwrite(fid, json);
    fclose(fid);
    try
        movefile(tmp, filepath, 'f');
    catch mvErr
        if exist(tmp, 'file') == 2; delete(tmp); end
        error('Fleet:fileError', 'Failed to save to %s: %s', filepath, mvErr.message);
    end
end
```

**Fleet.load must apply normalizeToCell** after jsondecode, because jsondecode collapses a homogeneous JSON array of objects into a MATLAB struct array:

```matlab
% [CITED: libs/Dashboard/private/normalizeToCell.m]
% [CITED: libs/Fleet/CanonicalMapper.m:387-411 fromStruct normalizeToCell_ pattern]

function obj = load(filepath)
    fid = fopen(filepath, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);
    s = jsondecode(raw);

    % Schema version guard (Pitfall 12)
    if ~isfield(s, 'fleetConfigVersion')
        s.fleetConfigVersion = 1;
    end

    obj = Fleet();
    % normalizeToCell converts struct array back to cell array
    machines = normalizeToCell(s.machines);
    for i = 1:numel(machines)
        m = Machine.fromConfigStruct(machines{i}, filepath);  % filepath for relative-path resolution
        obj.addMachine(m);
    end
    if isfield(s, 'canonicalMap')
        obj.Mapper_ = CanonicalMapper.fromStruct(s.canonicalMap);
    end
end
```

`normalizeToCell` is in `libs/Dashboard/private/` — it is a private function scoped to `libs/Dashboard`. Fleet code in `libs/Fleet/` cannot call it directly. **The planner must include a task to copy or recreate `normalizeToCell` as `libs/Fleet/private/normalizeToCell_.m`** (note the trailing underscore as a private helper per CLAUDE.md convention), or inline the 8-line normalization logic directly in Fleet.load. The CanonicalMapper already has its own private copy (`normalizeToCell_` — see `fromStruct` at line 399: `entries = normalizeToCell_(entries)`). Machine.fromStruct should follow the same pattern.

### Pattern 4: DataRoot Path Resolution on Load

```matlab
% [CITED: 1042-CONTEXT.md D-07]
% Machine.fromConfigStruct(s, fleetFilePath) path resolution:

function obj = fromConfigStruct(s, fleetFilePath)
    obj = Machine('Id', s.id, 'Name', s.name, 'Group', s.group);
    dataRoot = s.dataRoot;
    % Expand leading ~
    if numel(dataRoot) >= 1 && dataRoot(1) == '~'
        dataRoot = [char(java.lang.System.getProperty('user.home')) dataRoot(2:end)];
        % Octave: use getenv('HOME') instead of java
    end
    % Relative path: resolve against fleet config file directory
    if ~isempty(dataRoot) && dataRoot(1) ~= filesep && ~(numel(dataRoot)>1 && dataRoot(2)==':')
        fleetDir = fileparts(fleetFilePath);
        dataRoot = fullfile(fleetDir, dataRoot);
    end
    obj.DataRoot = dataRoot;
    if isfield(s, 'metadata')
        obj.Metadata = s.metadata;
    end
end
```

**Octave note for `~` expansion:** MATLAB supports `java.lang.System.getProperty('user.home')`; Octave does not have Java. Use `getenv('HOME')` as the Octave path. Guard with `exist('OCTAVE_VERSION','builtin')` or use `getenv('HOME')` on both (works on MATLAB too via the environment variable).

### Pattern 5: Machine.ingestBatch / Machine.startLive Wrappers

```matlab
% [CITED: .planning/research/ARCHITECTURE.md lines 244-277]

function report = ingestBatch(obj, varargin)
    %INGESTBATCH Run BatchTagPipeline scoped to this machine's catalog and DataRoot.
    p = BatchTagPipeline('OutputDir', obj.DataRoot, ...
        'TagSource', @(pred) obj.find(pred), ...
        varargin{:});
    report = p.run();
end

function startLive(obj, interval, varargin)
    %STARTLIVE Start LiveTagPipeline scoped to this machine's catalog and DataRoot.
    if nargin < 2 || isempty(interval)
        interval = 15;
    end
    obj.LivePipeline_ = LiveTagPipeline('OutputDir', obj.DataRoot, ...
        'TagSource', @(pred) obj.find(pred), ...
        'Interval',  interval, ...
        varargin{:});   % allows 'SharedRoot' passthrough for cluster machines
    obj.LivePipeline_.start();
end
```

**SharedRoot passthrough:** `varargin{:}` at the end of both constructors allows the caller to pass `'SharedRoot', root` when this machine is part of a v4.0 cluster. Omitting SharedRoot runs zero cluster-path code — the pipeline's `IsClusterMode_` gate (line 227: `~isempty(opts.SharedRoot)`) stays false.

### Pattern 6: Fleet.addMachine — Duplicate Id Guard

```matlab
% [CITED: libs/SensorThreshold/TagRegistry.m:86-94 — mirrors duplicate-key hard-error pattern]

function m = addMachine(obj, varargin)
    %ADDMACHINE Add a machine to the fleet (factory or pre-built handle form).
    if numel(varargin) == 1 && isa(varargin{1}, 'Machine')
        m = varargin{1};
    else
        m = Machine(varargin{:});
    end
    if obj.Machines_.isKey(m.Id)
        error('Fleet:duplicateMachineId', ...
            'Machine with Id ''%s'' already in fleet. Use a unique Id.', m.Id);
    end
    obj.Machines_(m.Id) = m;
    obj.MachineIds_{end+1} = m.Id;   % preserve insertion order
end
```

### Anti-Patterns to Avoid

- **Calling TagRegistry.register inside Machine or Fleet:** Causes `TagRegistry:duplicateKey` crash on second machine with same local key. Gate: `grep -rn "TagRegistry.register" libs/Fleet/` must return 0.
- **Using `contains()` in Fleet code:** Use `~isempty(strfind(lower(s), lower(p)))`. `contains` with cell patterns is unreliable across Octave versions.
- **Calling bare `jsonencode` on a cell-of-structs:** Produces `null` vs `[]` divergence between MATLAB and Octave. Use per-entry encode + strjoin.
- **Calling `getXY()` or materializing X/Y arrays at Fleet startup or in `addTag`:** Violates lazy-load discipline. FLEET-05 budget requires metadata-only load.
- **Putting `uifigure`, `uicontrol`, `uitree`, `uigridlayout`, or `uiprogressdlg` in `libs/Fleet/`:** Breaks Octave CI immediately. Gate: grep must return 0.
- **Using `dir('**/*.mat')` recursive glob:** Not supported in Octave. Use explicit `dir(fullfile(root,'*.mat'))` with iterative `isdir` descent.
- **Forgetting the `otherwise` error block:** Both pipeline constructors have `error('TagPipeline:invalidOutputDir','Unknown option...')` in `otherwise`. The `'TagSource'` case MUST be added to the switch before `otherwise`, or the pipeline rejects it.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-entry JSON encoding | Custom serializer | `jsonencode` per struct + `strjoin` | Exact pattern in CanonicalMapper.save:354-366; Octave-safe |
| Post-jsondecode cell normalization | Inline `if isstruct` guard | Private copy of `normalizeToCell` | 8-line helper already proven across Dashboard and CanonicalMapper |
| Atomic file write | Direct `fopen`/`fwrite` | `movefile(tmp, dest, 'f')` pattern | Already in `companionPrefs.m` + `EventStore.save()`; prevents corrupt files |
| Per-machine event persistence | New event system | `EventStore(machine.DataRoot)` | Phase 1039 cluster-safe pattern; single-user mode is correct for per-machine |
| Lazy data loading | New manifest format | `SensorTag.RawSource` deferred-read | Already the production mechanism; Tag objects carry metadata eagerly, X/Y deferred |

**Key insight:** Every infrastructure need in this phase has a working implementation already present in the codebase. The challenge is wiring them correctly, not building new mechanisms.

---

## Runtime State Inventory

This is a new-code phase (not a rename/refactor/migration phase). No existing runtime state is modified or renamed.

**Confirmed: None** — verified by phase scope (new `Machine.m`, `Fleet.m`, additive DI seam on pipelines). Existing TagRegistry state is neither read nor written by Fleet code. Existing single-machine pipeline state is unchanged (default `tagSource_` = `@TagRegistry.find`).

---

## Common Pitfalls

### Pitfall 1: Octave CI Gap — Class-Based Tests Don't Run on Octave

**What goes wrong:** `TestMachine.m` is added as `tests/suite/TestMachine.m` (class-based). `run_all_tests.m` Octave branch runs only `tests/test_*.m` files via `dir(fullfile(test_dir, 'test_*.m'))`. Class-based suites never execute on Octave CI. Machine and Fleet run on Octave (no `ui*` calls), but the behavior is never tested there.

**Why it happens:** The MATLAB and Octave test paths are separate in `run_all_tests.m`. Class-based suites are MATLAB-only. There is no automatic promotion from `tests/suite/` to Octave's flat test discovery.

**How to avoid:** Create companion flat files `tests/test_machine.m` and `tests/test_fleet.m` that cover the Octave-critical paths: tag isolation (`grep` gate), JSON round-trip, `filterByName`/`filterByGroup`, and tagSource_ default behavior. The class-based suites can be more comprehensive. SUMMARY.md explicitly flags this gap.

**Warning signs:** Octave CI passes but `tests/test_machine.m` does not exist. Fleet/Machine claims to be Octave-compatible but no Octave test exercises it.

### Pitfall 2: normalizeToCell Is a Private Function to libs/Dashboard

**What goes wrong:** `Fleet.load` calls `normalizeToCell(s.machines)` — but `normalizeToCell.m` lives in `libs/Dashboard/private/`. MATLAB private/ scoping means it is only callable from within the same folder or parent class. Fleet code in `libs/Fleet/` cannot call it.

**Why it happens:** The function is widely useful but was created as a Dashboard-private helper. CanonicalMapper already solved this by having its own `normalizeToCell_` (private copy, trailing underscore).

**How to avoid:** Create `libs/Fleet/private/normalizeToCell_.m` (or inline the 8-line logic). The planner must include this as an explicit task, not assume the Dashboard version is accessible.

### Pitfall 3: jsonencode on Machines Array Produces Different Output on Octave

**What goes wrong:** `jsonencode(struct_array)` and `jsonencode(cell_of_structs)` behave differently across MATLAB and Octave versions, especially for empty fields (null vs `[]` vs `""`). A fleet config written on MATLAB may not `jsondecode` cleanly on Octave.

**Why it happens:** Octave's `jsonencode` has subtle differences from MATLAB's for edge cases: `{}` → `null` vs `[]`, empty char `''` → `null` vs `""`.

**How to avoid:** Use the `jsonencode` per-struct entry + `strjoin` pattern from `CanonicalMapper.save` (verified working on both platforms). For each machine config struct, call `jsonencode(m.toConfigStruct())` on a scalar struct with well-typed fields (char for strings, double for numbers). Avoid empty cell arrays in the serialized struct.

**Specific cross-platform tested pattern:**
```matlab
% Safe: scalar struct with char fields
s = struct('id', char(m.Id), 'name', char(m.Name), 'dataRoot', char(m.DataRoot), ...
           'group', char(m.Group));
part = jsonencode(s);   % produces {"id":"...","name":"...","dataRoot":"...","group":"..."}
```

### Pitfall 4: Fleet.filterByName Returns Wrong Results Without Case Normalization

**What goes wrong:** `strfind(m.Name, pattern)` is case-sensitive. `filterByName('machine 1')` misses `'Machine 1'`.

**Why it happens:** Direct `strfind` without lowercasing.

**How to avoid:** `~isempty(strfind(lower(m.Name), lower(pattern)))`. Same pattern already in `filterTags.m` and `filterDashboards.m`.

### Pitfall 5: Machine.addTag Called with a Tag Already in Another Machine's Map

**What goes wrong:** If a user constructs one SensorTag object and adds it to two machines (`m1.addTag(t); m2.addTag(t)`), both machines hold a reference to the same handle. Calling `m1.getXY()` or modifying the tag on one machine affects the other.

**Why it happens:** `containers.Map` stores object handles, not copies. MATLAB handle classes share identity.

**How to avoid:** Document in `Machine.addTag` that tags should not be shared across machines. For Phase 1042 the constraint is advisory (no enforcement mechanism needed); the real guard is that each machine's pipeline creates its own Tag objects from the machine's DataRoot. Flag in the header comment.

### Pitfall 6: DataRoot Missing at ingestBatch Time

**What goes wrong:** `Machine.DataRoot` is set to a path that does not yet exist. `BatchTagPipeline` constructor calls `mkdir(opts.OutputDir)` if absent (line 210 in LiveTagPipeline), so this is handled for Live. BatchTagPipeline also handles this (it creates OutputDir in its constructor). But if DataRoot is empty or invalid, the error message is `TagPipeline:invalidOutputDir` which does not mention the machine context.

**How to avoid:** `Machine.addTag` or `Machine.ingestBatch` should validate that `obj.DataRoot` is non-empty before constructing the pipeline. Emit `Machine:missingDataRoot` if empty.

---

## Code Examples

### Machine Constructor and Tag Registration

```matlab
% [CITED: .planning/research/ARCHITECTURE.md lines 203-278, D-09/D-10]
% Machine NV constructor (D-09):
m = Machine('Id', 'M01', 'Name', 'Pump Station 1', 'DataRoot', '/data/m01', 'Group', 'pumps');

% addTag — populates catalog WITHOUT calling TagRegistry.register:
t = SensorTag('temperature', 'Name', 'Motor Temperature', 'Units', 'degC');
t.RawSource = struct('file', '/raw/m01/temp.csv', 'timeCol', 1, 'valueCol', 2);
m.addTag(t);   % stores t in m.Tags_('temperature')

% Fleet factory form:
fleet = Fleet();
m = fleet.addMachine('Id', 'M01', 'Name', 'Pump Station 1', 'DataRoot', '/data/m01');
```

### TagRegistry.list() Verification After 2-Machine Load (FLEET-02 gate)

```matlab
% [CITED: .planning/REQUIREMENTS.md FLEET-02, .planning/STATE.md Critical Invariants]
% After loading a 2-machine fleet, TagRegistry must show 0 machine tags:
TagRegistry.clear();   % start clean
m1 = Machine('Id','M01','DataRoot','/data/m01');
m1.addTag(SensorTag('temperature'));   % goes into m1.Tags_, NOT TagRegistry
m2 = Machine('Id','M02','DataRoot','/data/m02');
m2.addTag(SensorTag('temperature'));   % same key, different machine — no error
fleet = Fleet();
fleet.addMachine(m1);
fleet.addMachine(m2);
% Verify:
TagRegistry.list();    % must show 0 entries
assert(isempty(TagRegistry.find(@(t) true)));  % cell must be empty
```

### Fleet JSON Round-Trip (Octave-safe)

```matlab
% [CITED: libs/Fleet/CanonicalMapper.m:351-426 — save/load pattern]
fleet = Fleet();
fleet.addMachine('Id','M01','Name','Alpha','DataRoot','../data/m01','Group','pumps');
fleet.addMachine('Id','M02','Name','Beta', 'DataRoot','../data/m02','Group','pumps');
fleet.save('/project/fleet.json');
fleet2 = Fleet.load('/project/fleet.json');
assert(fleet2.machineCount() == 2);
assert(strcmp(fleet2.getMachine('M01').Name, 'Alpha'));
```

### tagSource_ DI Seam — Byte-Identical Single-Machine Test

```matlab
% [CITED: libs/SensorThreshold/BatchTagPipeline.m:251-261, D-12]
% Existing single-machine usage — UNCHANGED after the DI seam:
TagRegistry.register('temp_a', SensorTag('temp_a'));
p = BatchTagPipeline('OutputDir', tmpdir);
% p.tagSource_ == @TagRegistry.find  (default — no change to caller)
report = p.run();   % calls TagRegistry.find exactly as before

% Machine-scoped pipeline:
m = Machine('Id','M01','DataRoot', tmpdir);
m.addTag(SensorTag('temp_a'));
m.ingestBatch();   % BatchTagPipeline('OutputDir',m.DataRoot,'TagSource',@(pred)m.find(pred))
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Single global TagRegistry for all tags | Machine owns isolated `containers.Map`; TagRegistry untouched | Phase 1042 (this phase) | Enables N machines with identical local keys to coexist |
| pipelines enumerate TagRegistry statically | `tagSource_` DI seam; default is still @TagRegistry.find | Phase 1042 (this phase) | Single-machine callers unchanged; machine-scoped callers pass @machine.find |

**No deprecated approaches in this phase** — the additive nature of the DI seam preserves backward compatibility by design.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `normalizeToCell` in `libs/Dashboard/private/` is not callable from `libs/Fleet/` | Common Pitfalls #2 | If MATLAB's private/ scoping allows cross-library access, the task to copy it can be skipped — but the Octave behavior would still differ; safest to copy regardless |
| A2 | `getenv('HOME')` works on both MATLAB and Octave for `~` expansion | Pattern 4 | If `getenv('HOME')` is empty on some platform, `~`-paths in DataRoot would not expand — warn-and-skip is the safe fallback |
| A3 | `CanonicalMapper.toStruct` always returns `s.entries` as a MATLAB cell (not struct array) | Pattern 3 | `toStruct` builds `entryList` as a cell (confirmed at line 341: `entryList = {}`), so this is correct; LOW risk |

**Verified claims (not assumed):**
- `install.m` already has `addpath(fullfile(root, 'libs', 'Fleet'))` — confirmed at line 63. No install.m change needed.
- `libs/Fleet/` currently contains only `CanonicalMapper.m` and `CanonicalMapEditor.m` (Phase 1041 deliverables). `Machine.m` and `Fleet.m` are absent.
- `tests/suite/TestCanonicalMapper.m` exists. `TestMachine.m` and `TestFleet.m` do not.
- `tests/test_machine.m` and `tests/test_fleet.m` do not exist — both needed for Octave CI.
- Both pipeline `eligibleTags_` calls are at `BatchTagPipeline.m:256` and `LiveTagPipeline.m:801` — confirmed by direct read.
- Both pipelines have `otherwise` error guards that will reject unknown constructor options if `'TagSource'` is not added to the switch.
- `normalizeToCell.m` is `libs/Dashboard/private/normalizeToCell.m` — confirmed by direct read.
- `CanonicalMapper.fromStruct` already has its own private `normalizeToCell_` inline at line 399 — confirmed.

---

## Open Questions

1. **`~` expansion in DataRoot on Windows**
   - What we know: Windows paths start with drive letter (e.g., `C:\`), not `~`; `~` expansion only relevant on macOS/Linux
   - What's unclear: Is `~` in a Windows DataRoot a supported input at all?
   - Recommendation: Expand `~` on macOS/Linux using `getenv('HOME')`; on Windows, `~` is not a standard path prefix — skip expansion or warn and return as-is

2. **LivePipeline_ property on Machine — stop on delete?**
   - What we know: `Machine` will hold `LivePipeline_` as a private property; `LiveTagPipeline` owns a MATLAB timer
   - What's unclear: Should `Machine.delete()` stop and delete the timer? CLAUDE.md says "stop(t); delete(t); always in that order" but that applies to companion timers
   - Recommendation: Yes — implement `delete(obj)` on Machine that calls `obj.LivePipeline_.stop()` and `delete(obj.LivePipeline_)` if non-empty; prevents timer accumulation across session

3. **Machine.toConfigStruct field names**
   - What we know: The fleet JSON must store Id, Name, DataRoot, Group, Metadata at minimum
   - What's unclear: Should field names be camelCase (`dataRoot`) or PascalCase (`DataRoot`) in JSON?
   - Recommendation: camelCase for JSON fields (standard JSON convention; consistent with CanonicalMapper entry fields `machineId`, `localKey`, etc.); MATLAB properties stay PascalCase per CLAUDE.md

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| `jsonencode` / `jsondecode` | Fleet.save/load | ✓ | MATLAB R2016b+ / Octave 5+ | — (confirmed in ndjsonDecode.m:29) |
| `movefile` | Fleet.save atomic write | ✓ | All targets | — |
| `containers.Map` | Machine.Tags_, Fleet.Machines_ | ✓ | MATLAB R2006b+ / Octave 7+ | — |
| `EventStore` class | Machine.EventStore | ✓ | Phase 1039 (shipped) | — |
| `CanonicalMapper` class | Fleet.Mapper_ | ✓ | Phase 1041 (shipped) | — |
| `install.m` Fleet path | All Fleet classes | ✓ | Already wired at line 63 | — |

**Missing dependencies with no fallback:** None.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | `matlab.unittest` (MATLAB) / flat `test_*.m` (Octave) |
| Config file | `tests/run_all_tests.m` (auto-discovers `tests/suite/Test*.m` on MATLAB, `tests/test_*.m` on Octave) |
| Quick run command | `mcp__matlab__run_matlab_test_file 'tests/suite/TestMachine.m'` |
| Full suite command | `run_all_tests()` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FLEET-01 | Machine NV constructor; Fleet.addMachine factory + handle form | unit | `mcp__matlab__run_matlab_test_file 'tests/suite/TestMachine.m'` | ❌ Wave 0 |
| FLEET-01 | Fleet.addMachine returns Machine handle | unit | same | ❌ Wave 0 |
| FLEET-02 | Two machines with key `'temperature'` coexist; TagRegistry.list() == 0 | unit | same | ❌ Wave 0 |
| FLEET-02 | `grep -rn "TagRegistry.register" libs/Fleet/` returns 0 | static grep | `grep -rn "TagRegistry.register" libs/Fleet/` | — (gate, not test file) |
| FLEET-03 | Machine.ingestBatch scopes to machine DataRoot | unit | `mcp__matlab__run_matlab_test_file 'tests/suite/TestMachine.m'` | ❌ Wave 0 |
| FLEET-03 | Single-machine BatchTagPipeline unchanged (no 'TagSource' arg) | unit | same | ❌ Wave 0 |
| FLEET-04 | Fleet.save/Fleet.load round-trip on MATLAB | unit | `mcp__matlab__run_matlab_test_file 'tests/suite/TestFleet.m'` | ❌ Wave 0 |
| FLEET-04 | Fleet.save/Fleet.load round-trip on Octave | unit | `octave --eval "addpath(pwd); install(); test_fleet();"` | ❌ Wave 0 |
| FLEET-05 | 5-machine startup < 2s / < 50MB (no X/Y materialization) | integration | `mcp__matlab__run_matlab_test_file 'tests/suite/TestFleet.m'` (timing test) | ❌ Wave 0 |
| FLEET-06 | filterByGroup / filterByName composable | unit | same | ❌ Wave 0 |
| FLEET-06 | `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout" libs/Fleet/` returns 0 | static grep | `grep` gate | — (gate, not test file) |

### Sampling Rate

- **Per task commit:** Run `TestMachine.m` or `TestFleet.m` (whichever changed)
- **Per wave merge:** Full suite `run_all_tests()`
- **Phase gate:** Full suite green + both grep gates pass + Octave flat tests pass

### Wave 0 Gaps

- [ ] `tests/suite/TestMachine.m` — covers FLEET-01, FLEET-02, FLEET-03, FLEET-05
- [ ] `tests/suite/TestFleet.m` — covers FLEET-01, FLEET-04, FLEET-05, FLEET-06
- [ ] `tests/test_machine.m` — Octave flat; covers FLEET-02 isolation, FLEET-03 tagSource_ default
- [ ] `tests/test_fleet.m` — Octave flat; covers FLEET-04 JSON round-trip on Octave
- [ ] `libs/Fleet/Machine.m` — does not exist
- [ ] `libs/Fleet/Fleet.m` — does not exist
- [ ] `libs/Fleet/private/normalizeToCell_.m` — does not exist (copy of Dashboard private helper)

---

## Security Domain

`security_enforcement` is not set to false in `.planning/config.json`. Standard check applies.

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — (no auth in data model layer) |
| V3 Session Management | no | — |
| V4 Access Control | no | — (no user-facing API; script-only) |
| V5 Input Validation | yes (limited) | Machine Id, DataRoot path inputs validated at construction; unknown constructor NV keys hard-error |
| V6 Cryptography | no | — |

### Known Threat Patterns for This Stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Path traversal via DataRoot | Tampering | Validate DataRoot is a non-empty char; do not evaluate it; warn if path does not exist at load time |
| Fleet JSON with malicious field injection | Tampering | `jsondecode` produces a struct; only expected fields are accessed; unknown fields ignored |
| Symbol flooding via machine Id | Denial of Service | `Fleet.addMachine` hard-errors on duplicate Id; no unbounded accumulation |

Risk level for this phase is LOW — the Fleet data model is a local MATLAB script API with no network exposure and no web surface.

---

## Sources

### Primary (HIGH confidence — direct code audit at commit HEAD)

- `libs/Fleet/CanonicalMapper.m` — `toStruct`/`fromStruct` at lines 337/387; `save`/`load` at lines 351/413; `normalizeToCell_` usage at line 399; entry struct fields confirmed
- `libs/SensorThreshold/BatchTagPipeline.m` — `eligibleTags_` at line 251-261; constructor switch at lines 86-103; `otherwise` guard at line 98; private property block at lines 41-74
- `libs/SensorThreshold/LiveTagPipeline.m` — `eligibleTags_` at lines 786-806; constructor switch at lines 178-205; SharedRoot/IsClusterMode_ at lines 159, 225-241
- `libs/SensorThreshold/TagRegistry.m` — read API (`get`, `find`, `findByKind`, `findByLabel`) at lines 47, 154, 195, 174; hard-error `duplicateKey` at line 90; `clear()` at line 109
- `libs/EventDetection/EventStore.m` — constructor signature `EventStore(filePath, varargin)` at line 53; single-user vs cluster mode at lines 60-71
- `libs/Dashboard/private/normalizeToCell.m` — full file (8 lines); confirmed Dashboard-private scope
- `install.m` — `addpath(fullfile(root,'libs','Fleet'))` at line 63 — Fleet path already wired
- `tests/run_all_tests.m` — Octave branch at line 98 (`dir('test_*.m')`) vs MATLAB branch (`TestSuite.fromFolder`); confirms class-based suites do not run on Octave
- `.github/workflows/tests.yml` — Octave CI runs `run_all_tests('${TEST_PATTERN}')` at line 286
- `libs/Fleet/` directory listing — `CanonicalMapper.m` + `CanonicalMapEditor.m` present; `Machine.m` and `Fleet.m` absent
- `tests/suite/` directory listing — `TestCanonicalMapper.m` present; `TestMachine.m` and `TestFleet.m` absent

### Secondary (HIGH confidence — planning artifacts from direct research pass)

- `.planning/research/ARCHITECTURE.md` — Q1 (Machine duck-type API), Q3 (pipeline DI seam + Machine.ingestBatch/startLive), Q4 (per-machine EventStore), all confirmed against codebase above
- `.planning/research/PITFALLS.md` — Pitfalls 1, 5, 6, 9, 12, 13, 14 with file:line evidence
- `.planning/research/SUMMARY.md` — Phase 2 deliverables, exit gates, and the Octave CI gap flag
- `1042-CONTEXT.md` — D-01..D-14 locked decisions

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all primitives verified against existing code in this codebase
- Architecture: HIGH — all patterns derived from live code (CanonicalMapper.save, TagRegistry, pipelines)
- Pitfalls: HIGH — all traced to specific file:line evidence; Octave CI gap confirmed by reading `run_all_tests.m`
- Test strategy: HIGH — run_all_tests.m structure confirms the MATLAB/Octave test split

**Research date:** 2026-06-03
**Valid until:** 2026-08-03 (stable primitives; no new MATLAB/Octave version changes expected)
