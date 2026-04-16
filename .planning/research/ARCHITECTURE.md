# ARCHITECTURE.md — v2.0 Tag-Based Domain Model

**Domain:** FastSense Advanced Dashboard — v2.0 Tag-Based Domain Model
**Researched:** 2026-04-16
**Confidence:** HIGH on integration points (read all listed source files); MEDIUM on Octave abstract-class semantics; HIGH on suggested build order (derived directly from dependency graph).

---

## Summary

The current `libs/SensorThreshold/` library has three parallel but conceptually overlapping abstractions: `Sensor` (raw time-series with side-effect violation pre-computation), `StateChannel` (zero-order-hold discrete signal), and `Threshold`/`CompositeThreshold` (condition-value rules + aggregation). Each has its own registry, its own constructor pattern, and its own consumer touchpoint. Every downstream library — `FastSense`, `Dashboard` widgets, `EventDetection` — knows about all three by name.

v2.0 collapses these into a **single `Tag` root** with subclasses for each kind, and replaces the side-effect threshold computation in `Sensor.resolve()` with a first-class derived signal (`MonitorTag`) that is itself a Tag. Aggregation moves into `CompositeTag`. Events become first-class objects bound to one or more tags and rendered as overlays through a new FastSense API surface.

The integration risk is concentrated in three places:
1. **`Sensor.resolve()`'s bundled outputs** (`ResolvedThresholds`, `ResolvedViolations`, `ResolvedStateBands`) are consumed by FastSense, FastSenseWidget, EventDetection, MultiStatusWidget, IconCardWidget, EventViewer, and `detectEventsFromSensor`. Every consumer must move to reading `MonitorTag` outputs instead. This is the largest single migration.
2. **`FastSense.addSensor()` and `FastSense.addThreshold()`** are the rendering ingress. A new `addTag()` (or polymorphic dispatch via tag kind) must subsume both. The internal `Lines`/`Thresholds` struct arrays may stay; only the ingress method is replaced.
3. **`Threshold.conditions_` + `StateChannel`** evaluation is the violation-detection core. `MonitorTag` must take this over (read condition rules + state inputs from its parent SensorTag, produce a step-function or 0/1/severity Y signal).

The render core (`FastSense` downsampling, MEX kernels, `FastSenseDataStore`, `DashboardEngine`, `DashboardLayout`, `DashboardSerializer`, `DashboardTheme`) **does not change**. Only consumers of the old domain types do.

---

## Tag Interface Contract

### Minimum surface every Tag must expose

Cross-referenced against every consumer touchpoint:

| Member | Required by | Notes |
|--------|-------------|-------|
| `Key` (char) | TagRegistry, every widget, serializer, EventDetection (`sensorKey`) | Unique within registry |
| `Name` (char) | FastSenseWidget legend, DashboardWidget Title cascade, IconCardWidget label, MultiStatusWidget label | Empty allowed; consumers fall back to Key |
| `Units` (char) | FastSenseWidget YLabel cascade, IconCardWidget value formatting | Currently on Sensor; lift to Tag root |
| `Description` (char) | Widget tooltip pipeline (`DashboardWidget.Description` cascade) | New on Tag — currently absent on Sensor |
| `Tags` (cell of char) | `ThresholdRegistry.findByTag` (cross-cutting categorization) | Lift from Threshold to Tag root |
| `getXY()` → `(X, Y)` | FastSense `addLine`, `updateData`; FastSenseWidget refresh | Polymorphic: SensorTag returns raw; MonitorTag returns derived |
| `valueAt(t)` → scalar | StateChannel pattern (zero-order-hold), Sensor.getThresholdsAt, IconCardWidget.ValueFcn replacement, CompositeTag children | Vectorized form: `valueAt(tVec)` |
| `getTimeRange()` → `[tMin tMax]` | FastSenseWidget caching, DashboardWidget global time | Already a method on DashboardWidget; tag-side parallel |
| `getDataStore()` → handle or `[]` | FastSense.addSensor disk-backed branch (line 561–564) | Optional; only SensorTag with `toDisk()` returns non-empty |
| `getKind()` → char (e.g. `'sensor'`, `'monitor'`, `'composite'`, `'state'`) | TagRegistry, serializer dispatch, FastSense polymorphic render | String, not class name; survives renames |
| `toStruct()` / `fromStruct(s)` (static) | DashboardSerializer round-trip; CompositeTag child resolution order | Pattern already used by `CompositeThreshold` |
| `metadata` (struct, optional) | New: free-form per-tag attribution (asset id, source file, etc.) | Replaces ad-hoc Source / MatFile / ID props |

### Abstract methods convention

Octave's `classdef` supports `Abstract` method attribute but with partial compatibility per the Octave wiki. The codebase already uses `DashboardWidget < handle` and `DataSource` as abstract-by-convention base classes **without using the `Abstract` attribute** — the contract is documented in the header comment and enforced by `error()` if the base method is called.

**Recommendation:** Follow the existing project convention. Do NOT use `methods (Abstract)`. Use the "throw-from-base" pattern:

```matlab
methods
    function [X, Y] = getXY(obj) %#ok<STOUT,MANU>
        error('Tag:notImplemented', ...
            '%s must implement getXY().', class(obj));
    end
end
```

This is **proven Octave-safe** (already shipped in `DashboardWidget`, `DataSource`) and matches existing error-ID conventions (`ClassName:problem`).

---

## Subclass Hierarchy

### Recommendation: FLAT hierarchy

```
Tag (handle, abstract-by-convention)
├── SensorTag      — raw time-series, on-disk capable (replaces Sensor's data role)
├── StateTag       — zero-order-hold discrete signal (replaces StateChannel)
├── MonitorTag     — derived 0/1/severity series from a parent Tag + condition (replaces Threshold/ThresholdRule + Sensor.resolve()'s violation pipeline)
└── CompositeTag   — aggregates child Tags via mode (replaces CompositeThreshold)
```

### Trade-offs vs layered

A layered design (`Tag → DataTag → SensorTag, StateTag` and `Tag → DerivedTag → MonitorTag, CompositeTag`) was considered. Reasons to reject:

| Argument for layered | Counter |
|---|---|
| "Data tags share `getXY` semantics" | They don't really — SensorTag's `getXY` reads from memory or DataStore; StateTag's is a step function. Different enough to belong in subclasses, not a shared base. |
| "Derived tags share invalidation logic" | MonitorTag's recompute trigger (parent data changed, condition changed) is different from CompositeTag's (any child status changed). Different invalidation graphs. |
| "Future calc tags fit DerivedTag" | Calc tags are deferred per PROJECT.md. Adding a layer for hypothetical future use is YAGNI. |

**Flat wins on:** simpler `isa()` checks in switch statements (registry dispatch, serializer), shallower MRO for Octave (which has known issues with deep inheritance), and matches the `DashboardWidget` precedent (20+ widget types, all flat children of `DashboardWidget`).

### What goes on the root

- `Key`, `Name`, `Units`, `Description`, `Tags` (cell), `metadata` (struct) — universal
- `Color`, `LineStyle` — only SensorTag and MonitorTag need rendering attributes; **defer to subclass**

### What stays subclass-only

- **SensorTag:** `DataStore`, `toDisk()`, `toMemory()`, `isOnDisk()`, raw `X`/`Y` properties (kept exactly as on current Sensor)
- **StateTag:** `valueAt` zero-order-hold semantics with cell or numeric Y (port from StateChannel)
- **MonitorTag:** `Parent` (Tag handle), `Conditions` (cell of ThresholdRule), `StateInputs` (cell of StateTag handles), `Severity` (numeric label e.g. 0/1/2), `Direction`
- **CompositeTag:** `AggregateMode`, `Children` (cell)

---

## MonitorTag Computation Strategy

This is the most important architectural decision because it replaces `Sensor.resolve()`'s side-effect pre-computation.

### Recommendation: LAZY-with-memoization, parent-driven invalidation

| Strategy | Pro | Con | Verdict |
|---|---|---|---|
| Eager (compute at construction) | Simple; matches current `resolve()` | Wastes work when MonitorTag is never plotted; can't be constructed before parent has data; recomputes on every parent update even if MonitorTag is offscreen | Reject |
| Pure lazy (compute on each query) | No cache, simplest correctness | Re-runs MEX violation kernel on every FastSense pan/zoom — would catastrophically degrade performance | Reject |
| **Lazy + cached + invalidation flag** | Computes once on first read, reuses until invalidated, scales to many MonitorTags per SensorTag, integrates cleanly with FastSenseDataStore's existing `clearResolved` pattern | Needs invalidation discipline (parent must signal change) | **Recommend** |

### Cache + invalidation mechanics

```matlab
classdef MonitorTag < Tag
    properties (Access = private)
        cachedX_  = []
        cachedY_  = []
        dirty_    = true
    end
    properties (SetAccess = private)
        Parent              % Tag handle
        Conditions          % cell of ThresholdRule
        StateInputs         % cell of StateTag handles
        Direction
    end
    methods
        function [X, Y] = getXY(obj)
            if obj.dirty_ || isempty(obj.cachedX_)
                obj.recompute_();
            end
            X = obj.cachedX_; Y = obj.cachedY_;
        end
        function invalidate(obj)
            obj.dirty_ = true;
            obj.cachedX_ = []; obj.cachedY_ = [];
        end
    end
    methods (Access = private)
        function recompute_(obj)
            % Read parent (X, Y) — recursive if Parent is itself a MonitorTag
            [pX, pY] = obj.Parent.getXY();
            % Reuse existing private/compute_violations_batch.m and
            % private/buildThresholdEntry.m logic — ported from Sensor.resolve()
            % Y is a 0/severity step-function; X is segment boundaries from StateInputs
        end
    end
end
```

### Interaction with FastSenseDataStore

**Recommendation: do NOT persist MonitorTag-derived Y to its own SQLite chunks in v2.0.**

Reasons:
- `FastSenseDataStore` is currently per-SensorTag. Adding per-MonitorTag stores multiplies SQLite file footprint.
- The current `resolve()` cache (`DataStore.storeResolved` / `loadResolved`) is exactly the pattern to keep: **a SensorTag with a DataStore can host its derived MonitorTags' caches in the same store**. Add a `storeMonitor(monitorKey, X, Y)` / `loadMonitor(monitorKey)` API to `FastSenseDataStore` mirroring the existing `storeResolved`/`loadResolved`.
- Defer per-MonitorTag SQLite to a later milestone if MonitorTags become large enough to warrant it. For v2.0's typical step-function output (tens to hundreds of segments), in-memory cache is sufficient.

### Invalidation triggers

| Trigger | Currently handled by | New MonitorTag responsibility |
|---|---|---|
| Parent SensorTag's X/Y replaced (`updateData`) | Sensor doesn't auto-invalidate; consumer must call `resolve()` again | MonitorTag listens to parent or is invalidated by `SensorTag.updateData` |
| StateTag transitions changed | Sensor.addStateChannel calls `DataStore.clearResolved()` (line 187) | Same: any input StateTag's `updateData` calls `monitor.invalidate()` for monitors that depend on it |
| Condition added/removed | Same as state | MonitorTag.addCondition() sets `obj.dirty_ = true` |
| Live tick appends new data | `IncrementalEventDetector` uses a temp Sensor + `resolve()` (lines 60–84) | MonitorTag exposes an `appendData` method that incrementally extends `cachedY_` rather than full recompute (deferred optimization) |

**For v2.0:** simple invalidate + full recompute on next `getXY()`. Match the simplicity of current Sensor.resolve(); optimize incrementally.

---

## CompositeTag Alignment Strategy

### Recommendation: Option (c) — LAZY EVALUATION at query points (`valueAt`); plus on-demand UNION GRID for `getXY`

| Option | Pro | Con |
|---|---|---|
| (a) Union of all child X, fill last-known | Single canonical series; works with FastSense unchanged | Memory O(sum of N_i); recomputes on any child change |
| (b) Resample to target grid | Fixed cost; predictable; FastSense-friendly | Loses temporal precision of edge transitions; arbitrary grid choice |
| **(c) Lazy via valueAt at query points + union for full series** | `computeStatus()` (current-instant query) is just `valueAt(now)` over children; full plot generates union only when needed | Two code paths, but they share `valueAt` |

### Concrete approach

```matlab
classdef CompositeTag < Tag
    methods
        function val = valueAt(obj, t)
            % Aggregate children at point t
            childVals = zeros(1, numel(obj.Children));
            for i = 1:numel(obj.Children)
                childVals(i) = obj.Children{i}.valueAt(t);
            end
            val = obj.applyAggregate_(childVals);
        end

        function [X, Y] = getXY(obj)
            % Union grid: all unique transition times from all children
            allX = [];
            for i = 1:numel(obj.Children)
                [cX, ~] = obj.Children{i}.getXY();
                allX = [allX, cX];
            end
            X = unique(allX);
            Y = obj.valueAt(X);  % vectorized
        end
    end
end
```

### Why this fits FastSense/MEX best

- The existing pipeline already relies on **step-function representations** (`buildThresholdEntry`, `to_step_function_mex`, `mergeResolvedByLabel`).
- `valueAt(tVec)` for StateTag uses `binary_search_mex` — already SIMD-optimized.
- The union grid is bounded by sum of segment counts (typically dozens to thousands). FastSense downsampling kicks in only above `MinPointsForDownsample = 5000`; CompositeTag output is virtually always below that.

---

## TagRegistry Organization

### Recommendation: FLAT keyspace, with `getKind()` discrimination + `findByKind()` filter

```matlab
classdef TagRegistry
    methods (Static)
        function t = get(key)              % unified lookup, single namespace
        function register(key, tag)
        function unregister(key)
        function clear()
        function tags = findByKind(kind)   % 'sensor'|'state'|'monitor'|'composite'
        function tags = findByTag(tag)     % searches Tags property
        function list()
        function printTable()
        function viewer()
    end
end
```

### Why flat over namespaced

| Option | Pro | Con |
|---|---|---|
| **Flat (`'press_hi'`)** with `getKind()` discrimination | One lookup; matches current `SensorRegistry`+`ThresholdRegistry` API; uniform `add(key)`-resolves-to-tag in widgets | Must enforce key uniqueness across all kinds |
| Namespaced (`'sensor/press'`, `'monitor/press_hi'`) | Self-documenting keys; can't collide across kinds | Awkward to type; serialization keys become more verbose |
| Per-kind separate registries | Familiar (current state) | The whole point of v2.0 is unification — back-tracks |

**Key uniqueness:** enforce via `register()` raising `TagRegistry:duplicateKey` if `isKey(k)` and the existing entry is a different handle.

### Two-phase deserialization — fixes the CompositeThreshold ordering trap

Current `CompositeThreshold.fromStruct()` (lines 276–334) requires all child Threshold objects to be registered BEFORE the parent composite is reconstructed. This caveat is documented but error-prone. v2.0 should fix it.

```matlab
methods (Static)
    function loadFromStructs(structs)
        % Phase 1: instantiate all tags (composites get empty children)
        for i = 1:numel(structs)
            s = structs{i};
            switch s.kind
                case 'sensor',    t = SensorTag.fromStruct(s);
                case 'state',     t = StateTag.fromStruct(s);
                case 'monitor',   t = MonitorTag.fromStruct(s);   % parent ref deferred
                case 'composite', t = CompositeTag.fromStruct(s); % children refs deferred
            end
            TagRegistry.register(s.key, t);
        end
        % Phase 2: resolve cross-references
        for i = 1:numel(structs)
            s = structs{i};
            t = TagRegistry.get(s.key);
            if ismethod(t, 'resolveRefs')
                t.resolveRefs(s);  % MonitorTag resolves Parent, CompositeTag resolves Children
            end
        end
    end
end
```

This eliminates the order-dependent registration trap.

---

## Event ↔ Tag Binding

### Recommendation: BIDIRECTIONAL binding; Event holds tag references; tags hold a *queryable* event list (not stored)

- `Event` gains `TagKeys` (cell of char) — replaces current `SensorName`/`ThresholdLabel` strings. Many-to-many supported.
- `Event` keeps its current stat fields (PeakValue, NumPoints, Min/Max/Mean/RMS/Std, Direction, Duration).
- `EventStore` gains `eventsForTag(key)` that filters by `TagKeys`. No back-pointer on Tag itself.
- FastSense gains an `attachEventStore(store)` method (or accepts events at addTag time): when rendering a tag, it queries `store.eventsForTag(tag.Key)` and overlays them.

### FastSense overlay API

**Recommendation:** Add `addEventBand(xStart, xEnd, varargin)` — analogous to the existing horizontal `addBand(yLow, yHigh, ...)`. Then `addEventOverlay(events)` is sugar over a loop of `addEventBand` calls. The internal `Bands` struct array gains a `Direction` field (`'horizontal'` or `'vertical'`) so the same render code path handles both.

### Where the binding lives

**In Event.** Tags do NOT carry an Events cell. Reasons:
- Events outlive their tags being plotted (EventStore is persistent; tags are recreated)
- Many-to-many cardinality is naturally a property of the relationship's "owning" side (Event)
- Symmetry with current Event having `SensorName` / `ThresholdLabel` already — just generalize them

---

## Suggested Build Order

| Phase | Deliverable | Depends on | Justification |
|---|---|---|---|
| **1** | `Tag` abstract base + `TagRegistry` (with two-phase load) | nothing | Foundation; no consumers yet, but unblocks all later phases. Tests: registry CRUD, getKind dispatch. |
| **2** | `SensorTag` (keep `toDisk`/DataStore semantics intact); `StateTag` | Phase 1 | Both are pure data carriers; no derived computation. **Build in same phase** (independent siblings; shipping one without the other leaves consumers half-migrated). |
| **3** | Update `FastSense.addSensor` → `addTag` (polymorphic) and `FastSenseWidget` to bind to `SensorTag`. Migrate consumers: `MultiStatusWidget`, `IconCardWidget`, `EventTimelineWidget`, `SensorDetailPlot`, `MockDataSource`/`MatFileDataSource` | Phase 2 | At this point SensorTag fully replaces Sensor for raw plotting. Tests pass for non-thresholded plots. |
| **4** | `MonitorTag` — port `Sensor.resolve()` + `compute_violations_batch` + `buildThresholdEntry` + `mergeResolvedByLabel` into MonitorTag's `recompute_`. Replace `Sensor.ResolvedThresholds`/`ResolvedViolations` consumers. | Phase 3 | The old `resolve()` becomes an internal MonitorTag method. Threshold/ThresholdRule classes remain temporarily as helper structs for Conditions, then are deleted in Phase 7. |
| **5** | Update `EventDetection` to consume MonitorTag: rewrite `detectEventsFromSensor` → `detectEventsFromMonitor`; rewrite `IncrementalEventDetector`. Update `EventStore`/`EventViewer`. | Phase 4 | Largest single integration. |
| **6** | `CompositeTag` — port `CompositeThreshold` aggregation logic. Update `MultiStatusWidget` and `IconCardWidget`. | Phase 5 | Composite needs MonitorTag to exist. |
| **7** | Events on tags: `Event.TagKeys`; `EventStore.eventsForTag`; `FastSense.addEventBand`/`addEventOverlay`; widget integration. **Delete** old classes. | Phase 6 | Final integration; deletion of legacy types only after no consumers reference them. |

### Key adjustments from initial proposal

- **Combine SensorTag + StateTag** into one phase (independent siblings; splitting creates awkward half-migrated state).
- **MonitorTag before CompositeTag**, before EventDetection migration. Building Composite before EventDetection is migrated would leave EventDetector still consuming old Sensor while CompositeTag references new MonitorTag — split brain.
- **Events on tags is last + deletion phase** — defer all legacy-class deletions to here so each intermediate phase can run tests against the old code as a reference.

### Each phase ships a working slice

After Phase 2, raw plots work; after Phase 3, all non-monitor widgets work; after Phase 4, monitors render; after Phase 5, events work end-to-end; after Phase 6, composite status displays work; after Phase 7, the system is unified and old types are gone.

---

## Backward Compatibility

**Recommendation: REWRITE TESTS WITH EACH PHASE; no adapter layer.**

Per PROJECT.md: *"No users — backward compatibility is NOT a constraint"* and *"Greenfield rewrite of `libs/SensorThreshold/`"*.

### Why reject adapter layer

| Adapter approach | Cost | Verdict |
|---|---|---|
| Build `Sensor extends SensorTag` shim | Adapter classes proliferate; defeats greenfield intent; doubles the surface | Reject |
| Keep Threshold class as ConditionBag inside MonitorTag | Internal helper struct is fine; do not export it | OK as private helper, not as public class |
| Deprecation warnings on old APIs | Premature for no-user codebase | Reject |

### Test migration discipline

For each phase:
1. **Identify tests that touch the migrated class** (`tests/test_sensor.m`, `tests/test_threshold.m`, `tests/suite/TestSensor.m`, etc.)
2. **Rewrite in-place** — do not branch. Replace `Sensor('x')` with `SensorTag('x')`, `Threshold(...).addCondition(...)` with `MonitorTag(...).addCondition(...)`.
3. **Run `tests/run_all_tests.m`** at end of each phase. Phase is complete only when all tests green.
4. Tests that test integration patterns get rewritten in their phase even if the underlying class hasn't been touched yet.

### Coverage maintenance

- Phase 4 (MonitorTag) is the highest test churn — most existing `resolve()` tests, `compute_violations_batch` tests, `mergeResolvedByLabel` tests need their setup rewritten.
- Phase 7 (deletion) is mostly removing tests for deleted classes; new event-overlay rendering tests added.

---

## Integration Points

| File | Phase | Change |
|---|---|---|
| `libs/SensorThreshold/Tag.m` | 1 | **NEW** — abstract base; throw-from-base contract |
| `libs/SensorThreshold/TagRegistry.m` | 1 | **NEW** — replaces `SensorRegistry.m` + `ThresholdRegistry.m`; two-phase loadFromStructs |
| `libs/SensorThreshold/SensorTag.m` | 2 | **NEW** — port from `Sensor.m` lines 58–313 (props, load, toDisk, toMemory, isOnDisk); drop `addStateChannel`, `addThreshold`, `resolve`, `getThresholdsAt`, `countViolations`, `currentStatus`, `Resolved*` props |
| `libs/SensorThreshold/StateTag.m` | 2 | **NEW** — port from `StateChannel.m` (rename, change parent class only; preserve `valueAt` and `bsearchRight`) |
| `libs/FastSense/FastSense.m` | 3 | **MODIFY** — replace `addSensor` (lines 516–597) with polymorphic `addTag(tag, varargin)`; route by `tag.getKind()` |
| `libs/FastSense/SensorDetailPlot.m` | 3 | **MODIFY** — consumes `Sensor` directly; rewrite to consume `SensorTag` |
| `libs/Dashboard/FastSenseWidget.m` | 3 | **MODIFY** — `Sensor` property replaced with `Tag` property; auto-detect kind |
| `libs/Dashboard/DashboardWidget.m` | 3 | **MODIFY** — base-class `Sensor` property → `Tag`; Title cascade reads `.Tag.Name` / `.Tag.Key` |
| `libs/Dashboard/MultiStatusWidget.m` | 3, then 6 | **MODIFY twice** — Phase 3: `Sensors{}` → `Tags{}`; Phase 6: rewrite `expandSensors_` for `CompositeTag` |
| `libs/Dashboard/IconCardWidget.m` | 3, then 6 | **MODIFY twice** — Phase 3: `Sensor`→`Tag`; Phase 6: `Threshold` prop → `Tag` prop (any kind, including CompositeTag) |
| `libs/Dashboard/EventTimelineWidget.m` | 3, then 7 | **MODIFY** — Phase 3: filter by Tag.Key; Phase 7: consume new `Event.TagKeys` |
| `libs/SensorThreshold/MonitorTag.m` | 4 | **NEW** — Parent, Conditions, StateInputs, invalidate/recompute pattern; `recompute_` ports `Sensor.resolve()` body |
| `libs/SensorThreshold/private/compute_violations_batch.m` | 4 | **MOVE** — stays as private helper, called from MonitorTag instead of Sensor |
| `libs/SensorThreshold/private/buildThresholdEntry.m`, `mergeResolvedByLabel.m`, `appendResults.m` | 4 | **MOVE / SIMPLIFY** — only used by MonitorTag's recompute |
| `libs/FastSense/FastSenseDataStore.m` | 4 | **MODIFY** — add `storeMonitor`/`loadMonitor` mirroring existing `storeResolved`/`loadResolved` |
| `libs/EventDetection/detectEventsFromSensor.m` | 5 | **REPLACE** — new `detectEventsFromMonitor(monitorTag, detector)` |
| `libs/EventDetection/EventDetector.m` | 5 | **MODIFY** — `detect()` simplifies: takes (tag, X, Y) |
| `libs/EventDetection/IncrementalEventDetector.m` | 5 | **REWRITE** — current code (lines 31–175) builds temp Sensor + resolves; new code calls `monitorTag.appendData(newX, newY)` |
| `libs/EventDetection/Event.m` | 5 then 7 | **MODIFY** — Phase 5: keep `SensorName`/`ThresholdLabel` for compat; Phase 7: replace with `TagKeys` cell |
| `libs/EventDetection/EventStore.m` | 7 | **MODIFY** — add `eventsForTag(key)`; persistence gains `tagKeys` field |
| `libs/EventDetection/EventViewer.m` | 5 | **MODIFY** — column renaming (Sensor → Tag); click-to-plot uses TagRegistry.get |
| `libs/EventDetection/MockDataSource.m`, `MatFileDataSource.m` | 5 | **MODIFY** — return Tag-shaped data |
| `libs/SensorThreshold/CompositeTag.m` | 6 | **NEW** — port from `CompositeThreshold.m`; `applyAggregateMode_` preserved; valueAt/getXY new |
| `libs/FastSense/FastSense.m` | 7 | **MODIFY** — add `addEventBand`, `addEventOverlay`; extend `Bands` struct with Direction field |
| `libs/Dashboard/FastSenseWidget.m` | 7 | **MODIFY** — auto-overlay events from bound EventStore |
| `libs/Dashboard/DashboardSerializer.m` | 1, 7 | **MODIFY** — Phase 1: support `tag` source type; Phase 7: drop legacy `sensor` source path |
| **DELETE** in Phase 7 | 7 | `Sensor.m`, `Threshold.m`, `ThresholdRule.m`, `CompositeThreshold.m`, `StateChannel.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m` |
| `tests/test_sensor.m`, `test_threshold.m`, etc. | 2–7 | **REWRITE** in the phase that touches the producing class |
| `libs/WebBridge/` | none | **NO CHANGE** — consumes serialized dashboard config + SQLite files; tag changes are transparent |

### Render layer untouched

These files **do not change**:
- All `libs/FastSense/private/mex_src/*.c` and corresponding `.m` fallbacks
- `libs/FastSense/FastSenseDataStore.m` core read/write API (only adds helpers in Phase 4)
- `libs/FastSense/FastSenseTheme.m`, `FastSenseGrid.m`, `FastSenseDock.m`, `FastSenseToolbar.m`, `NavigatorOverlay.m`
- `libs/Dashboard/DashboardEngine.m`, `DashboardLayout.m`, `DashboardTheme.m`, `DashboardToolbar.m`, `DashboardBuilder.m`, `DashboardPage.m`, `DetachedMirror.m`, `MarkdownRenderer.m`, `DividerWidget.m`
- `bridge/python/`, `bridge/web/` (entire WebBridge stack)

---

## Open Questions

1. **MonitorTag severity encoding.** Y as `0/1` (binary), `0/severity-level` (multi-level integer), or `0/threshold-value` (float)? **Suggest:** integer severity (0=ok, 1=warn, 2=alarm) with the threshold-value-at-time available as a separate channel.
2. **Should `StateTag` be plottable as a Tag in FastSense?** Currently StateChannel is a condition input only. **Suggest:** allow but render as bands by default (kind='state' branch in FastSense.addTag).
3. **CompositeTag with mixed-kind children.** Can a CompositeTag have a SensorTag child? **Suggest:** error in Phase 6 — CompositeTag children must be MonitorTag or CompositeTag.
4. **Live append performance for MonitorTag.** Phase 4 ships full-recompute on invalidation. **Suggest:** add `MonitorTag.appendData(newX, newY)` in Phase 5 that extends `cachedY_` by computing only the new tail.
5. **Event-tag binding cardinality enforcement.** When an Event references multiple tags via `TagKeys`, what happens if one tag is deleted? **Suggest:** keep TagKeys as strings (not handles); orphaned references tolerated with `(unknown tag)` placeholder in EventViewer.
6. **Migration state for existing SQLite caches.** No users per PROJECT.md; verify no test fixtures depend on the old schema.
7. **`metadata` struct convention on Tag root.** Free-form is flexible but rapidly becomes a dumping ground. Suggest documenting expected keys (`asset`, `source`, `id`) even if unenforced.

---

## Confidence Assessment

| Area | Level | Reason |
|------|-------|--------|
| Tag interface contract | HIGH | Derived directly from grep of consumer touchpoints in source files |
| Subclass hierarchy | HIGH | Small surface, flat is consistent with DashboardWidget precedent |
| MonitorTag computation | MEDIUM | Lazy+cache is standard but performance under FastSense pan/zoom unverified — needs Phase 4 benchmarking |
| CompositeTag alignment | HIGH | Step-function representation is what existing MEX kernels already operate on |
| TagRegistry organization | HIGH | Two-phase loading is a textbook fix for the documented CompositeThreshold ordering trap |
| Event-tag binding | MEDIUM | Recommendation rests on judgement; "Tag.Events back-pointer" alternative is also defensible |
| Build order | HIGH | Direct dependency analysis; each phase boundary keeps test suite runnable |
| Octave abstract semantics | MEDIUM | Abstract attribute support partial per Octave wiki; throw-from-base pattern HIGH confidence (already shipped) |

---

## Roadmap Implications

**Suggested 7-phase structure:**
1. Tag root + TagRegistry (foundation, low risk)
2. SensorTag + StateTag (paired data carriers)
3. FastSense.addTag + all dashboard widget consumer migration
4. MonitorTag (largest single phase — ports Sensor.resolve)
5. EventDetection migration (second-largest)
6. CompositeTag (small, isolated)
7. Events-on-tags + legacy class deletion

Phase 4 and Phase 5 are the largest. Consider research flags for both:
- Phase 4: re-verify `compute_violations_batch` semantics survive the move into MonitorTag with no behavior change
- Phase 5: Incremental detector rewrite is novel; benchmark Phase 4's MonitorTag invalidation pattern under live tick load before committing

---

## Sources

- [Octave Classdef wiki](https://wiki.octave.org/Classdef)
- [classdef Classes (GNU Octave 10.3.0)](https://docs.octave.org/interpreter/classdef-Classes.html)
