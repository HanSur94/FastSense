# Architecture Research

**Domain:** v5.0 Multi-Machine Fleet — integration architecture grounded in actual code
**Researched:** 2026-06-02
**Confidence:** HIGH (all claims backed by file:line code audit)

---

## System Overview

```
┌──────────────────────────────────────────────────────────────────────────┐
│                      FastSenseCompanion (uifigure)                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  [new: machine     │
│  │TagCatalogPane│  │DashboardList │  │InspectorPane │   selector row]     │
│  │(snapshots    │  │Pane          │  │              │                     │
│  │ Machine.find)│  │(Machine.     │  │(multi-tag /  │                     │
│  └──────┬───────┘  │ Dashboards)  │  │ comparison   │                     │
│         │          └──────┬───────┘  └──────┬───────┘                     │
│ TagSelectionChanged  DashboardSelected  OpenAdHocPlot                     │
└─────────┼──────────────────┼───────────────────────────────────────────────┘
          │  setProject(machine.Dashboards, machine)
          ▼
┌─────────────────────────────────────┐    ┌─────────────────────────────┐
│  Fleet (new — libs/Fleet/)           │    │  Global TagRegistry         │
│  ┌────────────────────────────────┐  │    │  (static-only, UNTOUCHED)   │
│  │  Machine (= "project")         │  │    │  72 static call sites       │
│  │  ┌────────────────────────┐    │  │    │  across 31 files unchanged  │
│  │  │  containers.Map        │    │  │    └─────────────────────────────┘
│  │  │  (key -> Tag handle)   │    │  │
│  │  │  DataRoot (char)       │    │  │
│  │  │  Dashboards (cell)     │    │  │
│  │  │  BatchTagPipeline*     │    │  │
│  │  │  LiveTagPipeline*      │    │  │
│  │  └────────────────────────┘    │  │
│  │  CanonicalMapper               │  │
│  └────────────────────────────────┘  │
└─────────────────────────────────────┘
          │
          ▼
┌──────────────────────────────────────────────────────────┐
│  DashboardSerializer (modified — machine-scoped resolver) │
│  FastSenseWidget.fromStruct:                              │
│    source.type='tag' → resolver(machineId, localKey)      │
│    (falls back to TagRegistry.get for no-machine path)    │
└──────────────────────────────────────────────────────────┘
```

---

## Question 1: Machine-as-Registry Duck Type — Exhaustive Call Audit

### Registry Object Calls Made By Panes/Companion

The companion and panes make calls on the registry **object** in three places.
Every other TagRegistry usage is **static** (not on the object reference):

**Companion — object call (file:line):**
- `FastSenseCompanion.m:2182` — `obj.Registry_.get(keys{k})` — last-resort fallback in `onOpenAdHocPlotRequested_` when a key is not found in the catalog snapshot. This is the ONLY object-method call on `Registry_` in the companion body.

**TagCatalogPane.m — static calls (not object calls):**
- `:60` — `TagRegistry.find(@(t) true)` in `attach()`
- `:205` — `TagRegistry.find(@(t) true)` in `refresh()`

The pane stores `obj.Registry_ = registry` (`:52`) but never calls a method on it. All actual tag enumeration goes directly to the static `TagRegistry.find`.

**FastSenseCompanion.m — static calls on TagRegistry (not on Registry_):**
- `:1616` — `TagRegistry.find(@(t) isa(t, 'Tag'))` in `scanLiveTagUpdates_` (broad scan when status table is open)
- `:1618` — `TagRegistry.find(@(t) isa(t, 'SensorTag') || isa(t, 'StateTag'))` in `scanLiveTagUpdates_` (normal live scan)

**openAdHocPlot.m (private) — static calls:**
- `:165` — `TagRegistry.find(@(tt) isa(tt, 'MonitorTag') && ...)` in `findEventStoreFor_` — finds monitors whose parent key matches a tag, to auto-wire EventStore.

**FastSenseWidget.m — static calls in render/fromStruct paths:**
- `:178` — `TagRegistry.getEventStore()` in `render()`
- `:1440` — `TagRegistry.getEventStore()` in `rebuildForTag_()`
- `:1516` — `TagRegistry.get(s.source.key)` in `fromStruct()` (the serializer seam — see Q2)

### Minimum Duck-Type Method Set for Machine

For panes to consume `Machine` unchanged by passing it as `registry`, Machine must implement:

| Method | Signature | Caller / File:Line | Purpose |
|--------|-----------|-------------------|---------|
| `get` | `t = obj.get(key)` | FastSenseCompanion.m:2182 (fallback) | Resolve tag by key; throw on missing |
| `find` | `ts = obj.find(predicateFn)` | TagCatalogPane.m:60,205 | Return cell of matching Tag handles |
| `findByKind` | `ts = obj.findByKind(kind)` | Not called on object today; needed for pane filter completeness | Kind-filter |
| `findByLabel` | `ts = obj.findByLabel(label)` | Not called on object today; needed for label-based workflows | Label-filter |
| `keys` | Not called on object; needed for iteration | Pipeline eligibleTags_ pattern | Return all keys as cell |

The static calls (`TagRegistry.find` in `attach`/`refresh`, `scanLiveTagUpdates_`, `findEventStoreFor_`) are NOT calls on the object reference — they are calls on the static class. These CANNOT be redirected by passing a Machine as `registry`. They hit the global TagRegistry unconditionally.

### Static TagRegistry Calls Inside Companion That Must Become Machine-Scoped

These sites enumerate the GLOBAL registry but should enumerate the active machine's catalog in v5.0:

| File | Line | Current Call | v5.0 Required Change |
|------|------|-------------|---------------------|
| `TagCatalogPane.m` | 60 | `TagRegistry.find(@(t) true)` in `attach()` | Route through `Registry_` object if it supports `find()` — OR swap to `obj.Registry_.find(@(t) true)` |
| `TagCatalogPane.m` | 205 | `TagRegistry.find(@(t) true)` in `refresh()` | Same |
| `FastSenseCompanion.m` | 1616 | `TagRegistry.find(@(t) isa(t,'Tag'))` in `scanLiveTagUpdates_` | Scope to active machine |
| `FastSenseCompanion.m` | 1618 | `TagRegistry.find(@(t) isa(t,'SensorTag')||isa(t,'StateTag'))` in `scanLiveTagUpdates_` | Scope to active machine |
| `private/openAdHocPlot.m` | 165 | `TagRegistry.find(@(tt) isa(tt,'MonitorTag')&&...)` in `findEventStoreFor_` | Must search active machine's catalog, not global registry |

**Migration strategy for the four sites:** Change `TagCatalogPane.attach` to call `obj.Registry_.find(...)` instead of `TagRegistry.find(...)` (since `Registry_` is already stored). The companion's `scanLiveTagUpdates_` call should be replaced by `obj.Registry_.find(...)` using the companion's `Registry_` reference. `findEventStoreFor_` in `openAdHocPlot.m` needs a machine context passed from the caller or uses the already-resolved Tag handles' catalog.

The two `FastSenseWidget` static calls (`TagRegistry.getEventStore()` at lines 178 and 1440) are best left untouched for now — they fall back to the global registry default EventStore slot, which is correct for single-machine use and is explicitly deferred for fleet-wide event wiring.

---

## Question 2: DashboardSerializer Resolver Seam

### How Tag-Bound Widgets Are Serialized Today

**Serialize path (FastSenseWidget.toStruct, line 1211):**
```matlab
s.source = struct('type', 'tag', 'key', obj.Tag.Key);
```
Writes `source.type='tag'` and `source.key=<localKey>` into the struct. No machine ID is stored.

**Deserialize path (FastSenseWidget.fromStruct, lines 1513-1521):**
```matlab
case 'tag'
    if exist('TagRegistry', 'class')
        try
            obj.Tag = TagRegistry.get(s.source.key);
        catch
            warning('FastSenseWidget:tagNotFound', ...
                'TagRegistry key ''%s'' not found.', s.source.key);
        end
    end
```
Calls `TagRegistry.get(key)` directly — no injected resolver, no machine context.

**DashboardSerializer.configToWidgets resolver hook (lines 388-411):**
```matlab
function widgets = configToWidgets(config, resolver)
    if nargin < 2, resolver = []; end
    ...
    if ~isempty(resolver) && isfield(ws, 'source') && strcmp(ws.source.type, 'sensor')
        try
            widgets{i}.Sensor = resolver(ws.source.name);
        ...
```
There IS a resolver hook, but it checks for `source.type='sensor'` (legacy path), not `source.type='tag'` (current v2.0 path). The tag-bind path is handled entirely inside `FastSenseWidget.fromStruct` — the resolver is bypassed.

### Minimal Change: Machine-Scoped Resolver Seam

**Approach:** Add a static resolver hook to `FastSenseWidget.fromStruct` that accepts an optional function handle. Default is `[]`, which falls back to `TagRegistry.get` (backward compat preserved).

```matlab
% FastSenseWidget.fromStruct (modified)
function obj = fromStruct(s, tagResolver)
    if nargin < 2, tagResolver = []; end
    ...
    case 'tag'
        if ~isempty(tagResolver)
            try
                obj.Tag = tagResolver(s.source.key);
            catch
                warning('FastSenseWidget:tagNotFound', ...
                    'Resolver could not find key ''%s''.', s.source.key);
            end
        elseif exist('TagRegistry', 'class')
            try
                obj.Tag = TagRegistry.get(s.source.key);
            catch
                warning(...)
            end
        end
```

**DashboardSerializer.createWidgetFromStruct** (line 418) becomes:
```matlab
case 'fastsense'
    w = FastSenseWidget.fromStruct(ws, tagResolver);
```

**DashboardSerializer.configToWidgets** gets a new optional `tagResolver` arg threaded through to `createWidgetFromStruct`. The resolver signature is:
```
tagResolver = @(localKey) machine.get(localKey)
```

**Call site in the companion / Fleet:**
```matlab
resolver = @(k) machine.get(k);
engine = DashboardEngine.load(jsonPath, resolver);
% or:
widgets = DashboardSerializer.configToWidgets(config, resolver);
```

DashboardEngine.load already calls `DashboardSerializer.loadJSON` then reconstructs widgets. A `resolver` arg threaded into `DashboardEngine.load` covers the full round-trip.

**JSON serialization** does NOT change — `source.type='tag'` + `source.key=<localKey>` is already the right shape. The `machineId` is known at load time from context (which machine's JSON you're loading), not stored in the widget struct.

**Files to modify:**
- `libs/Dashboard/FastSenseWidget.m` — `fromStruct` gains optional `tagResolver` arg
- `libs/Dashboard/DashboardSerializer.m` — `configToWidgets` + `createWidgetFromStruct` thread `tagResolver`
- `libs/Dashboard/DashboardEngine.m` — `load()` accepts optional resolver; threads it to DashboardSerializer

---

## Question 3: Per-Machine Ingestion

### Current Pipeline Tag Enumeration

Both pipelines use an identical `eligibleTags_` private method that calls the global static registry:

**BatchTagPipeline.m:256:**
```matlab
function tags = eligibleTags_(~)
    tags = TagRegistry.find(@(t) ...
        (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
        isstruct(t.RawSource) && ...
        isfield(t.RawSource, 'file') && ...
        ~isempty(t.RawSource.file));
end
```

**LiveTagPipeline.m:801:** Identical body, same static `TagRegistry.find` call.

### Minimal Change: Tag Source Injection

Add a `TagSource` property (function handle) to both pipelines. Default is `@TagRegistry.find` — backward compat. Machine-scoped pipelines pass `@(pred) machine.find(pred)`.

```matlab
% In BatchTagPipeline constructor, add:
properties (Access = private)
    tagSource_ = @TagRegistry.find   % DI seam; tests + machine use can override
end

% eligibleTags_ becomes:
function tags = eligibleTags_(obj)
    tags = obj.tagSource_(@(t) ...
        (isa(t, 'SensorTag') || isa(t, 'StateTag')) && ...
        isstruct(t.RawSource) && ...
        isfield(t.RawSource, 'file') && ...
        ~isempty(t.RawSource.file));
end
```

Add a constructor option `'TagSource'` NV pair, or a Hidden setter `setTagSourceForTesting_` matching the existing DI seam pattern (see `setWriteFnForTesting_`).

### Machine.ingestBatch / Machine.startLive Wrappers

Machine owns per-machine ingestion. The minimal implementation:

```matlab
% Machine.m
function report = ingestBatch(obj)
    p = BatchTagPipeline('OutputDir', obj.DataRoot, ...
        'TagSource', @(pred) obj.find(pred));
    report = p.run();
end

function startLive(obj, interval)
    obj.LivePipeline_ = LiveTagPipeline('OutputDir', obj.DataRoot, ...
        'TagSource', @(pred) obj.find(pred), ...
        'Interval',  interval);
    obj.LivePipeline_.start();
end
```

`OutputDir` is `machine.DataRoot` — each machine writes `.mat` files into its own isolated data root. No global registry pollution.

### Interaction With v4.0 SharedRoot / Cluster Mode

`LiveTagPipeline` cluster mode is keyed on the `'SharedRoot'` NV-pair (line 227: `obj.IsClusterMode_ = ~isempty(opts.SharedRoot)`). Machine wrappers can pass `'SharedRoot'` forward if the machine is part of a multi-writer cluster:

```matlab
obj.LivePipeline_ = LiveTagPipeline('OutputDir', obj.DataRoot, ...
    'TagSource',   @(pred) obj.find(pred), ...
    'SharedRoot',  sharedRoot, ...  % optional; machine knows its own cluster status
    'Interval',    interval);
```

Single-machine use omits `SharedRoot` — zero cluster code path runs (the pipeline's own `CONTEXT.md Success Criterion 5 / byte-identical guarantee` already covers this).

---

## Question 4: EventStore + MonitorTag Per Machine

### Current Global Slot

`TagRegistry.setEventStore` / `TagRegistry.getEventStore` use a `persistent containers.Map` (lines 123-152). This is a single global slot used by `FastSenseWidget.render` (line 178), `FastSenseWidget.rebuildForTag_` (line 1440), `EventTimelineWidget`, and `TableWidget(events)` when no per-instance EventStore is configured.

### In-Scope vs Deferred

**In scope for v5.0 (per PROJECT.md):**
Per-machine tags (SensorTag, MonitorTag) that belong to Machine's catalog work normally when their EventStore is wired explicitly — either on the widget directly (`widget.EventStore = store`) or via `machine.EventStore` property that Machine exposes.

The `FastSenseWidget` already has a priority chain: widget-level `EventStore` (line 176-183) takes priority over the registry default. So wiring `machine.EventStore` at the `openAdHocPlot` / dashboard-load level is sufficient — no global slot change needed.

**Deferred (per PROJECT.md explicit deferral):**
Cross-machine MonitorTag/event rollups and fleet-wide background monitoring. The global `TagRegistry.setEventStore` slot is not touched.

**Minimum required for per-machine tags to work:**
- `Machine` exposes an `EventStore` property (or `getEventStore()` method) returning the machine-scoped EventStore handle.
- `openAdHocPlot.m`'s `findEventStoreFor_` (line 159-177) uses `TagRegistry.find` to locate monitors. When called for a machine-context ad-hoc plot, it must search the machine's catalog instead. The fix: pass the machine (or its `find` handle) into `openAdHocPlot` as an optional argument, or use the already-resolved Tag handles' parent-machine reference.
- `CompanionEventViewer` and the companion bell continue to use the single `EventStore_` wired at construction / `setProject` — for the active machine, this is `machine.EventStore`.

**EventStore per machine:** Machine owns `EventStore_ = EventStore(machine.DataRoot)` (cluster-safe per Phase 1039 pattern). `TagRegistry.setEventStore` is not called per machine — the machine's EventStore is threaded explicitly.

---

## Question 5: Comparison Data Flow

### Fleet.resolveLogical → openAdHocPlot Overlay

```
Fleet.resolveLogical(logicalId)
    → CanonicalMapper.machinesForLogical(logicalId)
    → for each machine: machine.get(machine.localKeyFor(logicalId))
    → returns cell of {machine, Tag} pairs

Companion OpenComparison handler:
    tags = cellfun(@(pair) pair{2}, resolved, 'UniformOutput', false)
    openAdHocPlot(tags, 'Overlay', themePreset)
```

### Does openAdHocPlot Accept Tag Objects Directly?

YES. `openAdHocPlot.m:47`: the function accepts `tags` as "1xN cell of Tag handles (already resolved by caller)". It calls `tg.getXY()` (line 69) and `tg.Name` (line 63) — these are part of the Tag abstract interface implemented by all Tag subclasses. No TagRegistry lookup is performed for the tags themselves.

The `findEventStoreFor_` sub-helper (line 159) does call `TagRegistry.find` to locate monitors — this is the one site that needs scoping to the machine's catalog for comparison overlays. Options:
1. Pass an optional `monitorSource` argument to `openAdHocPlot` alongside the tag cell.
2. Each Tag could carry a weak back-reference to its owning Machine (simpler for the comparison path but adds coupling).
3. Accept that `findEventStoreFor_` returns `[]` for machine-catalog tags (safe — widget simply has no auto-wired EventStore, which is acceptable for v5.0 comparison views where EventStore overlay is secondary).

**Option 3 is the safest minimal path** for v5.0: comparison overlays work without EventStore auto-wiring. EventStore per-machine can be wired explicitly by the caller if needed.

### Per-Series Color/Legend

`openAdHocPlot` Overlay mode (line 143-157) calls `plot(ax, tv, y, 'DisplayName', char(names{k}), 'LineWidth', 1.2)`. MATLAB auto-assigns colors from the axes ColorOrder. There is no per-series color injection today.

For comparison overlays, the `plotOverlay_` helper needs to accept per-series colors. Minimal change: add an optional `colors` arg to `openAdHocPlot` (or augment the tags input to be a struct array `{tag, color, machineName}`). For v5.0, the machine name is the natural legend entry:

```matlab
% openAdHocPlot comparison call from Companion:
tagNames = cellfun(@(p) sprintf('%s / %s', p{1}.Name, p{2}.Name), resolved, 'UniformOutput', false);
% p{1} = machine, p{2} = Tag
openAdHocPlot(tags, 'Overlay', themePreset, 'DisplayNames', tagNames)
```

The `plotOverlay_` helper already uses `validNames` as `DisplayName` — passing machine-qualified names is sufficient for legend differentiation without deeper changes.

---

## Question 6: Suggested Build Order

### New vs Modified Files

```
libs/Fleet/                      NEW
├── Machine.m                    NEW — owns containers.Map catalog; mirrors TagRegistry read API
├── Fleet.m                      NEW — searchable machines + config persistence
└── CanonicalMapper.m            NEW — per-machine localKey ↔ logicalId mapping

libs/Dashboard/
├── DashboardEngine.m            MODIFIED — load() accepts optional tagResolver arg
├── DashboardSerializer.m        MODIFIED — configToWidgets/createWidgetFromStruct thread tagResolver
└── FastSenseWidget.m            MODIFIED — fromStruct gains optional tagResolver arg

libs/FastSenseCompanion/
├── FastSenseCompanion.m         MODIFIED — setProject accepts Machine; adds machine selector; wires static TagRegistry.find → machine.find in catalog/live-scan paths
├── TagCatalogPane.m             MODIFIED — attach/refresh call obj.Registry_.find instead of TagRegistry.find (4-line change)
└── private/openAdHocPlot.m     MODIFIED — findEventStoreFor_ accepts optional machine source arg

libs/SensorThreshold/
├── BatchTagPipeline.m           MODIFIED — tagSource_ DI seam; TagSource constructor NV pair
└── LiveTagPipeline.m            MODIFIED — identical tagSource_ DI seam

tests/
├── suite/TestMachine.m          NEW
├── suite/TestFleet.m            NEW
├── suite/TestCanonicalMapper.m  NEW
└── suite/TestFleetIntegration.m NEW — end-to-end: Machine ingestion + Companion setProject
```

### Dependency-Ordered Build Sequence

**Phase 1 — CanonicalMapper (canonical-map-first, no dependencies):**
- `libs/Fleet/CanonicalMapper.m` NEW
- `tests/suite/TestCanonicalMapper.m` NEW
- No existing code changes. Standalone; fully testable.

**Phase 2 — Machine (depends on CanonicalMapper):**
- `libs/Fleet/Machine.m` NEW
- `libs/SensorThreshold/BatchTagPipeline.m` MODIFIED (tagSource_ seam only)
- `libs/SensorThreshold/LiveTagPipeline.m` MODIFIED (tagSource_ seam only)
- `tests/suite/TestMachine.m` NEW
- Pipeline seam changes are additive (default unchanged); safe to merge.

**Phase 3 — Fleet (depends on Machine):**
- `libs/Fleet/Fleet.m` NEW
- `tests/suite/TestFleet.m` NEW
- No existing code changes.

**Phase 4 — DashboardSerializer resolver seam (depends on nothing, backward-compat):**
- `libs/Dashboard/FastSenseWidget.m` MODIFIED (fromStruct optional tagResolver)
- `libs/Dashboard/DashboardSerializer.m` MODIFIED (configToWidgets threads resolver)
- `libs/Dashboard/DashboardEngine.m` MODIFIED (load() optional resolver)
- Additive: existing dashboards with no resolver arg work identically.

**Phase 5 — Companion machine dimension (depends on Phases 1-4):**
- `libs/FastSenseCompanion/FastSenseCompanion.m` MODIFIED
- `libs/FastSenseCompanion/TagCatalogPane.m` MODIFIED
- `libs/FastSenseCompanion/private/openAdHocPlot.m` MODIFIED
- Machine selector UI (deferred from v5.0 per PROJECT.md, but setProject(machine) wire-up is Phase 5)

**Phase 6 — Integration tests:**
- `tests/suite/TestFleetIntegration.m` NEW

### Rationale for Ordering

- CanonicalMapper first because Fleet.resolveLogical depends on it, and it has zero external dependencies — validates the core logical-sensor mapping logic before any wiring.
- Machine second because pipelines and companion depend on it; the DI seam changes to pipelines are the lowest-risk modifications (additive, no default behavior change).
- Fleet third because it's a container over Machine — needs Machine stable.
- Serializer seam fourth because it's independent of Fleet/Machine and touches Dashboard code that has its own test suite. Isolating it lets existing DashboardSerializer tests validate backward compat before companion wiring starts.
- Companion last because it consumes everything above; it is the highest integration surface and changes there are the most expensive to debug.

---

## Integration Points

### Confirmed Exact Seams

| Seam | Current Code | v5.0 Change | File:Line |
|------|-------------|-------------|-----------|
| Companion registry object call | `obj.Registry_.get(key)` | Works unchanged if Machine implements `get(key)` | FastSenseCompanion.m:2182 |
| CatalogPane tag enumeration | `TagRegistry.find(@(t) true)` (static) | Change to `obj.Registry_.find(@(t) true)` | TagCatalogPane.m:60,205 |
| Live scan enumeration | `TagRegistry.find(@(t) isa(t,'Tag'))` (static) | Change to `obj.Registry_.find(...)` | FastSenseCompanion.m:1616,1618 |
| openAdHocPlot monitor lookup | `TagRegistry.find(@(tt) isa(tt,'MonitorTag')...)` (static) | Accept no-result gracefully (Option 3) or add machine arg | openAdHocPlot.m:165 |
| Widget tag resolution in fromStruct | `TagRegistry.get(s.source.key)` | Add optional `tagResolver` arg; default unchanged | FastSenseWidget.m:1516 |
| EventStore forwarding in render | `TagRegistry.getEventStore()` | Unchanged — global slot; machine uses explicit widget.EventStore | FastSenseWidget.m:178,1440 |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| Machine ↔ TagCatalogPane | Machine passed as `registry` arg; pane calls `registry.find(pred)` | Machine must implement `find(predicateFn)` |
| Machine ↔ FastSenseCompanion | Via `setProject(machine.Dashboards, machine)` | Existing setProject contract reused exactly |
| Machine ↔ DashboardSerializer | Via `tagResolver = @(k) machine.get(k)` passed at load time | New optional arg; old callers unaffected |
| Fleet ↔ CanonicalMapper | `fleet.mapper.machinesForLogical(id)` | CanonicalMapper is owned by Fleet |
| Machine ↔ Pipelines | `'TagSource', @(pred) machine.find(pred)` in pipeline constructor | New NV pair; default `@TagRegistry.find` preserved |

---

## Anti-Patterns

### Anti-Pattern 1: Modifying TagRegistry to be Instantiable

**What people do:** Try to make `TagRegistry` a handle class to avoid the duck-type seam.
**Why it's wrong:** 72 static call sites across 31 files; persistent `catalog()` cannot be instanced without breaking all existing single-machine code paths.
**Do this instead:** Machine owns a `containers.Map` internally and exposes the same read API (`get`, `find`, `findByKind`, `findByLabel`).

### Anti-Pattern 2: Storing machineId in Widget Structs

**What people do:** Serialize `source.machineId` alongside `source.key` in `FastSenseWidget.toStruct`.
**Why it's wrong:** Dashboard JSON becomes machine-specific instead of portable. Clone/remap workflows become harder. The resolver is the right injection point — it knows the machine context from the load site, not from the JSON.
**Do this instead:** Keep JSON as `{type:'tag', key:'localKey'}`. Inject machine context via the resolver function handle at load time.

### Anti-Pattern 3: Calling TagRegistry.find Inside Machine Methods

**What people do:** Machine.find internally delegates to `TagRegistry.find` filtered by a namespace prefix.
**Why it's wrong:** This is Approach 2 (namespaced compound keys) which was explicitly rejected — it requires forced per-machine filtering everywhere and causes key-sprawl.
**Do this instead:** Machine owns its own `containers.Map`; `Machine.find` iterates that map directly.

---

## Sources

All findings are based on direct code audit of the following files at commit HEAD on branch `claude/friendly-leakey-0bc166`:

- `libs/SensorThreshold/TagRegistry.m` — full file
- `libs/SensorThreshold/SensorTag.m` — full file
- `libs/SensorThreshold/BatchTagPipeline.m` — full file (eligibleTags_ at line 256)
- `libs/SensorThreshold/LiveTagPipeline.m` — full file (eligibleTags_ at line 801)
- `libs/Dashboard/DashboardSerializer.m` — full file (configToWidgets resolver hook at line 388; linesForWidget tag path at line 793)
- `libs/Dashboard/FastSenseWidget.m` — full file (toStruct line 1211; fromStruct lines 1501-1573; TagRegistry.getEventStore lines 178, 1440)
- `libs/FastSenseCompanion/FastSenseCompanion.m` — constructor (lines 131-500), setProject (lines 725-801), scanLiveTagUpdates_ (lines 1600-1657), onOpenAdHocPlotRequested_ (lines 2150-2240)
- `libs/FastSenseCompanion/TagCatalogPane.m` — attach (lines 45-180), refresh (lines 201-211), getSelectedTags (lines 220-238)
- `libs/FastSenseCompanion/DashboardListPane.m` — attach (lines 46-126)
- `libs/FastSenseCompanion/private/openAdHocPlot.m` — full file (findEventStoreFor_ at line 159)
- `.planning/PROJECT.md` — v5.0 scope and decisions

---
*Architecture research for: FastSense v5.0 Multi-Machine Fleet integration*
*Researched: 2026-06-02*
