# Phase 1009: Consumer migration (one widget at a time) - Research

**Researched:** 2026-04-16
**Domain:** Structural consumer migration — additive `Tag` property on every consumer of `Sensor`/`Threshold`/`StateChannel`/`CompositeThreshold`; wire Phase 1007 `MonitorTag.appendData` into `LiveEventPipeline` to realize MONITOR-05 end-to-end; hold Pitfall 5 (no legacy deletion), Pitfall 9 (≤10% 12-widget regression), Pitfall 11 (golden untouched).
**Confidence:** HIGH — the full Tag API surface (Tag, TagRegistry, SensorTag, StateTag, MonitorTag with appendData, CompositeTag) landed in Phases 1004-1008 with green CI, and every downstream consumer's current shape is now explicit (see file inventory below).

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- **Migration pattern is additive, uniform across all consumers.** Each widget gains an additional `Tag` property. `refresh()` prefers the Tag path when set; the existing legacy property (`Sensor`/`Threshold`/etc.) branch is left byte-for-byte UNCHANGED.
  ```matlab
  if ~isempty(obj.Tag)
      if ~isa(obj.Tag, 'Tag')
          error('WidgetName:invalidTag', 'Expected Tag subclass');
      end
      % Tag-based path (getXY / valueAt)
  elseif ~isempty(obj.Sensor)
      % LEGACY path unchanged
  end
  ```
- **Plan structure (4 plans, one per consumer cluster, one atomic commit each):**
  - Plan 01: `FastSenseWidget` + `SensorDetailPlot` (FastSense-layer consumers)
  - Plan 02: Dashboard widgets — `MultiStatusWidget`, `IconCardWidget`, `EventTimelineWidget`, `DashboardWidget` base `Tag` property
  - Plan 03: EventDetection consumers — `EventDetector`, `LiveEventPipeline` (realize Phase 1007 SC#4 — wire `MonitorTag.appendData`)
  - Plan 04: Pitfall 9 12-widget live-tick benchmark + phase-exit audit
- **FastSenseWidget contract (per CONTEXT):** add `Tag` property (optional); `refresh()` branches on `~isempty(obj.Tag)`; realize path calls `FastSense.addTag(tag)`; tick path needs a "update-by-Tag.Key" equivalent to `FastSense.updateData(lineIdx, X, Y)`; round-trip via `toStruct`/`fromStruct` persists `Tag.Key` and resolves via `TagRegistry.get` on load.
- **MultiStatusWidget contract:** items struct gains optional `tag` field; status derived from `tag.valueAt(now)` (0=ok, 1=alarm); CompositeTag expansion mirrors existing CompositeThreshold expand.
- **IconCardWidget contract:** optional `Tag` property; precedence `Tag > Threshold > Sensor` (existing Threshold > Sensor order preserved); status from `tag.valueAt(now)`.
- **EventTimelineWidget contract:** Query events by tag-key using MONITOR-05 carrier pattern (`Event.SensorName == parent.Key`, `Event.ThresholdLabel == monitor.Key`). Add `EventStore.getEventsForTag(tagKey)` IF not already present — implemented as `SensorName == tagKey OR ThresholdLabel == tagKey` filter.
- **SensorDetailPlot contract:** accept Tag constructor input (new branch at `assert(isa(sensor, 'Sensor'))` guard); rendering calls `tag.getXY()` instead of `sensor.X`, `sensor.Y`. Existing `Sensor` path unchanged.
- **DashboardWidget base:** add optional `Tag` property to base class (uniform serialization). `toStruct` writes `s.source = struct('type', 'tag', 'key', obj.Tag.Key)` when Tag set; `fromStruct` resolves via `TagRegistry.get` in Pass 2.
- **EventDetector:** add overload — `detect(tagOrSensor, threshold)` branching on `isa(input, 'Tag')` to call `tag.getXY()` before routing through existing violation-detection path. No architecture change.
- **LiveEventPipeline (Phase 1007 SC#4 realization):** when a target is a `MonitorTag`, call `monitor.appendData(new_x, new_y)` on tick instead of full `IncrementalEventDetector.process` recompute. Sensor-based targets keep existing path. Plan 03 SUMMARY documents tick throughput (≥ legacy gate).
- **Pitfall 9 bench design:** 12-widget dashboard mix; 6 widgets on Tags, 6 widgets on legacy Sensors. Assert `tag_tick_time ≤ 1.10 × legacy_tick_time`. Median of 3 runs. Reuse the `bench_monitortag_tick.m` shape.
- **Verification gates (phase-level):**
  - **Pitfall 5:** Zero legacy class deletions; all `addSensor`/`addThreshold` paths remain alive.
  - **Pitfall 9:** 12-widget live-tick ≤ 10% regression vs baseline.
  - **Pitfall 11:** Golden integration test (`tests/test_golden_integration.m`) UNTOUCHED throughout.
  - Every plan commit independently revertable.

### Claude's Discretion

- Exact order of per-consumer commits within Plan 02 (MultiStatus vs IconCard vs EventTimeline vs base-class Tag property) — planner picks.
- Whether `SensorDetailPlot` gets a new constructor signature (`SensorDetailPlot(tagOrSensor, ...)`) or an explicit dual path (`SensorDetailPlot('Tag', tag, ...)`).
- `EventStore.getEventsForTag` method signature — if it already exists reuse; else add it.
- How much existing Sensor→Tag test infrastructure to reuse vs create new (expect mostly new Tag-route tests plus SMOKE coverage that the legacy path still works).

### Deferred Ideas (OUT OF SCOPE)

- Event ↔ Tag binding rewrite via EventBinding registry (Phase 1010 owns EVENT-01..07).
- Legacy-class deletion (Phase 1011 owns MIGRATE-03).
- Asset hierarchy (future v2.x milestone).

</user_constraints>

<phase_requirements>
## Phase Requirements

Phase 1009 owns **ZERO exclusive REQ-IDs**. It is a pure structural integration phase that wires previously-landed capabilities into existing consumers.

| ID | Description | Research Support |
|----|-------------|------------------|
| MONITOR-05 (1006) | MonitorTag emits Events on 0→1 transitions with `TagKeys = {monitor.Key, parent.Key}` via the bound EventStore | Implementation landed in Phase 1006 Plan 02 (`fireEventsOnRisingEdges_` inside `recompute_`, uses SensorName/ThresholdLabel carrier). Phase 1009 Plan 03 wires `LiveEventPipeline` to call `MonitorTag.appendData` so the live tick realizes end-to-end auto-emit. No code change to MONITOR-05 itself — only the consumer loop. |
| MONITOR-08 (1007) | `MonitorTag.appendData(newX, newY)` streaming | Landed Phase 1007 Plan 01; 7 boundary-correctness tests green; `bench_monitortag_append` shows 10.9-12.6x speedup. Phase 1009 Plan 03 integrates it. |
| TAG-10 (1005) | `FastSense.addTag` polymorphic dispatch | Landed Phase 1005 Plan 03 + extended Phase 1006 Plan 03 (`monitor`) + Phase 1008 Plan 03 (`composite`). Used by FastSenseWidget Tag-realize path. |
| COMPOSITE-01 (1008) | CompositeTag is a Tag — usable wherever any Tag is | Landed Phase 1008. MultiStatusWidget/IconCardWidget Tag path must handle CompositeTag via `valueAt(now)` fast path (COMPOSITE-06). |

All other Tag REQs (TAG-01..10, MONITOR-01..10, COMPOSITE-01..07, META-01..04, ALIGN-01..04, MIGRATE-01..02) are prerequisites — they are DONE and consumed.

</phase_requirements>

## Summary

Phase 1009 is a plumbing phase: every current `Sensor`/`Threshold`/`CompositeThreshold`/`StateChannel` consumer gets an additive `Tag` property and an `isempty(obj.Tag)` branch in its `refresh()`/data-access path. The legacy code path is preserved byte-for-byte — this is strangler-fig discipline, not a rewrite. Per CONTEXT the work is organized as 4 atomic per-cluster commits (FastSense layer, Dashboard layer, EventDetection layer, Pitfall 9 bench + audit). Plan 03 also realizes Phase 1007 Success Criterion #4 by wiring `MonitorTag.appendData` into `LiveEventPipeline.runCycle` — the single unlanded piece of MONITOR-05 auto-emit.

The investigation surfaces one non-obvious gap: `EventTimelineWidget` currently groups events by `Event.SensorName` (legacy one-name-per-event assumption); the Phase 1006 Plan 02 carrier pattern sets `Event.SensorName = parent.Key` and `Event.ThresholdLabel = monitor.Key`, so a tag-key query can reuse the legacy fields without any Event schema change. `EventStore.getEventsForTag` does NOT exist today — it needs to be added (simple filter), which is a small net-new method, not a schema change. Everything else is additive property + dispatch branch.

**Primary recommendation:** Each plan's commit is ONE feature (one consumer cluster) + its tests, with the legacy code path untouched. Use grep gates in the Plan SUMMARY to prove (a) no edits to golden test file, (b) no edits to legacy `Sensor.m`/`Threshold.m`/etc., and (c) no new `isa(x, 'SensorTag')`/`isa(x, 'MonitorTag')` switches inside FastSense (Pitfall 1 invariant established Phase 1005 and re-asserted Phase 1008 must carry forward into FastSenseWidget — use `getKind()` + `valueAt()` + `getXY()` only).

## Standard Stack

### Core (already in the codebase, used verbatim)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `Tag` + subclasses | Phase 1004-1008 (local) | Abstract Tag domain: SensorTag, StateTag, MonitorTag, CompositeTag | THE v2.0 domain model — consumers must route through it (TAG-10) |
| `TagRegistry` | Phase 1004 | Singleton catalog + two-phase loader | Used by fromStruct to resolve `Tag.Key` string → handle (same pattern as `ThresholdRegistry` / `SensorRegistry`) |
| `FastSense.addTag(tag)` | Phase 1005-1008 (`libs/FastSense/FastSense.m:943`) | Polymorphic Tag dispatch via `getKind()` | Already handles sensor/state/monitor/composite; FastSenseWidget realize path calls this directly. Pitfall 1 invariant: NO `isa()` switches inside (enforced by test `testPitfall1NoIsaInFastSenseAddTag`). |
| `MonitorTag.appendData(newX, newY)` | Phase 1007 (`libs/SensorThreshold/MonitorTag.m:320`) | Streaming tail extension preserving hysteresis FSM + event emission | This is the one-liner Phase 1007 reserved for Phase 1009 LEP wire-up |
| `Tag.valueAt(t)` | Phase 1004 contract | ZOH scalar lookup at instant t | Used by MultiStatusWidget / IconCardWidget current-state path (COMPOSITE-06 fast path) |
| `Tag.getXY()` | Phase 1004 contract | Full (X,Y) vectors | Used by FastSenseWidget + SensorDetailPlot + EventDetector |
| `FastSense.updateData(lineIdx, newX, newY)` | (`libs/FastSense/FastSense.m:1635`) | Incremental line update without full teardown | FastSenseWidget tick path already uses this for Sensor (`refresh()` lines 127-135). Tag tick path must reuse it with the same call signature. |

### Supporting (already in the codebase)

| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `addlistener(sensor, 'X'/'Y', 'PostSet', ...)` in `DashboardEngine.wireListeners` (line 935) | Marks widget dirty when parent Sensor data appends | Live tick. **Tag path equivalent already exists**: SensorTag/StateTag/MonitorTag invalidation cascades through `MonitorTag.addListener` / parent `updateData` (MONITOR-04). Need to wire DashboardEngine to call `markDirty` when a Tag widget's Tag invalidates. |
| `MonitorTag.addListener(m)` | Register external listener notified on `invalidate()` | Can be used to connect Tag-backed widgets to dirty-flagging |
| `parseOpts` (`libs/FastSense/private/`) | Standard name-value parsing | Reuse inside Tag constructors for widgets |
| Carrier pattern: `Event.SensorName = parent.Key`, `Event.ThresholdLabel = monitor.Key` | Phase 1006 MONITOR-05 pre-Phase-1010 shape | EventTimelineWidget reads these existing fields to do tag-keyed grouping. No Event schema change. |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Additive `Tag` property on every widget | One uniform property on `DashboardWidget` base + remove per-widget Sensor | Phase 1011 does that. Doing it here would break Pitfall 5 (deletes legacy property), Pitfall 11 (touches golden fixture), and blow the revertability contract. |
| Tag-keyed event lookup via new `Event.TagKeys` | Use existing `SensorName`/`ThresholdLabel` carrier fields | Phase 1010 owns `Event.TagKeys`. Using it here is scope creep. Carrier pattern is already the MONITOR-05 contract. |
| Rewrite `EventDetector.detect` signature | Add `isa(input, 'Tag')` branch at entry, preserve old signature | Keeps legacy callers compiling. Existing signature `detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)` stays; new overload handles tag input. |
| Break `SensorDetailPlot(sensor, ...)` constructor | Relax `assert(isa(sensor, 'Sensor'))` to accept Tag OR Sensor | Safer than a second constructor. First arg is positional in all call sites; detecting `isa(arg, 'Tag')` vs `isa(arg, 'Sensor')` is unambiguous. |

**Installation:** No new packages. All code additive within existing libs.

**Version verification:** N/A — pure MATLAB/Octave, no external deps.

## Architecture Patterns

### Recommended Project Structure (NO new files; only additive edits)

```
libs/Dashboard/
├── DashboardWidget.m        # EDIT +1 property (Tag) + toStruct Tag branch
├── FastSenseWidget.m        # EDIT +1 property (Tag) + render/refresh/update Tag branches + fromStruct
├── MultiStatusWidget.m      # EDIT items struct supports 'tag' field; deriveColor Tag branch
├── IconCardWidget.m         # EDIT +1 property (Tag) + refresh Tag branch + fromStruct
├── EventTimelineWidget.m    # EDIT resolveEvents + eventStoreToStructs Tag-key grouping
libs/FastSense/
├── SensorDetailPlot.m       # EDIT constructor arg name (tagOrSensor), render dual-path
libs/EventDetection/
├── EventDetector.m          # EDIT detect() gets isa-Tag overload
├── EventStore.m             # EDIT +1 method (getEventsForTag)
├── LiveEventPipeline.m      # EDIT runCycle: MonitorTag targets use appendData (SC#4 realization)
benchmarks/
├── bench_consumer_migration_tick.m   # NEW (Plan 04, Pitfall 9 gate)
tests/suite/
├── TestFastSenseWidgetTag.m          # NEW (Plan 01)
├── TestSensorDetailPlotTag.m         # NEW (Plan 01)
├── TestMultiStatusWidgetTag.m        # NEW (Plan 02)
├── TestIconCardWidgetTag.m           # NEW (Plan 02)
├── TestEventTimelineWidgetTag.m      # NEW (Plan 02)
├── TestLiveEventPipelineTag.m        # NEW (Plan 03; end-to-end SC#4 evidence)
tests/
├── test_fastsense_widget_tag.m       # NEW (Plan 01, Octave flat)
├── test_sensor_detail_plot_tag.m     # NEW (Plan 01, Octave flat)
├── test_multistatus_widget_tag.m     # NEW (Plan 02)
├── test_icon_card_widget_tag.m       # NEW (Plan 02)
├── test_event_timeline_widget_tag.m  # NEW (Plan 02)
├── test_live_event_pipeline_tag.m    # NEW (Plan 03)
```

### Pattern 1: Uniform Tag-first dispatch (applied identically in every widget)

**What:** Public `refresh()` (or data-read methods) first checks `~isempty(obj.Tag)`, dispatches through Tag API, `return`s; only falls through to the pre-existing property-based path when Tag is unset.
**When to use:** Every consumer migration target.
**Example (canonical):**
```matlab
% Source: CONTEXT.md §Decisions; pattern matches Phase 1005 FastSense.addTag
function refresh(obj)
    if ~isempty(obj.Tag)
        if ~isa(obj.Tag, 'Tag')
            error('FastSenseWidget:invalidTag', ...
                'Tag must be a Tag subclass; got %s.', class(obj.Tag));
        end
        % Route by kind — NO isa(obj.Tag, 'SensorTag') etc (Pitfall 1)
        [x, y] = obj.Tag.getXY();
        obj.FastSenseObj.updateData(1, x, y);
        return;
    end
    % Legacy path — UNCHANGED, byte-for-byte
    if ~isempty(obj.Sensor)
        % existing code ...
    end
end
```

### Pattern 2: FastSenseWidget Tag realize + tick wiring

**What:** `render()` with a Tag calls `fp.addTag(obj.Tag)` (polymorphic by `getKind()`); `update()`/`refresh()` calls `fp.updateData(1, x, y)` with `[x,y] = obj.Tag.getXY()`.
**Why:** Re-uses the existing incremental update path (PERF2-01 optimization from Phase 1000). Line index 1 is already the convention for single-tag widgets.
**Example:**
```matlab
function render(obj, parentPanel)
    % ...
    fp = FastSense('Parent', ax);
    obj.FastSenseObj = fp;
    if ~isempty(obj.Tag)
        fp.addTag(obj.Tag);
    elseif ~isempty(obj.Sensor)
        fp.addSensor(obj.Sensor);
    elseif ~isempty(obj.DataStoreObj)
        fp.addLine([], [], 'DataStore', obj.DataStoreObj);
    % ... existing branches unchanged ...
    end
    fp.render();
end

function update(obj)
    if ~isempty(obj.Tag)
        if ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
            [x, y] = obj.Tag.getXY();
            obj.FastSenseObj.updateData(1, x, y);
            obj.updateTimeRangeCache_Tag();  % new private helper
        end
        return;
    end
    % existing Sensor path unchanged
    if ~isempty(obj.Sensor) && ~isempty(obj.FastSenseObj) && obj.FastSenseObj.IsRendered
        obj.FastSenseObj.updateData(1, obj.Sensor.X, obj.Sensor.Y);
        obj.updateTimeRangeCache();
    end
end
```

### Pattern 3: DashboardEngine dirty-flag wiring for Tag widgets

**What:** `DashboardEngine.onLiveTick` currently calls `w.markDirty()` for any widget with `~isempty(w.Sensor)` (line 829). For Tag widgets, the equivalent is: if `isa(obj.Tag, 'MonitorTag')` or similar — BUT per Pitfall 1 we do NOT use isa switches. Instead, **rely on the MonitorTag listener cascade already built in Phase 1006** (MONITOR-04 parent-driven invalidation). Option A: register the widget as a MonitorTag listener (`tag.addListener(obj)` where the widget implements `invalidate` → `markDirty`). Option B: unconditionally `markDirty()` Tag-bound widgets on every tick (matches the current Sensor-unconditional logic on line 829-831).
**When to use:** `DashboardEngine.onLiveTick` — see Plan 02 or Plan 01 depending on where the Tag widget dirty-flagging lands.
**Recommended:** Option B (match existing Sensor behavior). Cleaner; no invalidate override on every widget; parity with Sensor-path live tick.

### Pattern 4: MultiStatusWidget Tag item — struct-keyed, not new property

**What:** MultiStatusWidget already supports a `threshold` key in items (Phase 1003 CompositeThreshold expansion). Add a `tag` key alongside. `refresh()` / `deriveColorFromThreshold` / `expandSensors_` branch on which key is present.
**When to use:** MultiStatusWidget migration (Plan 02).
**Example:**
```matlab
% toStruct items entry (per-item)
if isfield(item, 'tag')
    if ischar(item.tag) || isstring(item.tag)
        entry.key = item.tag;   % persist by key
    elseif isa(item.tag, 'Tag')
        entry.key = item.tag.Key;
    end
    entry.type = 'tag';
elseif isfield(item, 'threshold')
    % existing threshold branch unchanged
end

% refresh dispatch
if isfield(item, 'tag') && ~isempty(item.tag)
    v = item.tag.valueAt(now);
    if v >= 0.5
        color = theme.StatusAlarmColor;
    else
        color = okColor;
    end
elseif isfield(item, 'threshold')
    color = obj.deriveColorFromThreshold(item, okColor, theme);
else
    color = obj.deriveColor(item, okColor);
end
```

### Pattern 5: EventTimelineWidget — tag-key filter via carrier fields

**What:** Events already carry `SensorName = parent.Key` and `ThresholdLabel = monitor.Key` (MONITOR-05 carrier). Add filter method on `EventStore`:
```matlab
function evts = getEventsForTag(obj, tagKey)
    % Filter via existing carrier fields (MONITOR-05 pre-Phase-1010 contract).
    all = obj.events_;
    if isempty(all), evts = []; return; end
    keep = false(1, numel(all));
    for i = 1:numel(all)
        keep(i) = strcmp(all(i).SensorName, tagKey) || ...
                  strcmp(all(i).ThresholdLabel, tagKey);
    end
    evts = all(keep);
end
```
**When to use:** EventTimelineWidget `resolveEvents` when `FilterTagKey` property is set. Existing `FilterSensors` cellstr path stays unchanged.

### Pattern 6: LiveEventPipeline — targets map + appendData wire-up

**What:** Today `runCycle` calls `obj.detector_.process(key, sensor, ...)` for each sensor (`processSensor` line 147). For Tag-backed monitors, route directly:
```matlab
% After extending with a MonitorTargets map (containers.Map of key->MonitorTag):
function runCycle(obj)
    obj.cycleCount_ = obj.cycleCount_ + 1;
    allNewEvents = [];
    hasNewData = false;
    sensorKeys = obj.Sensors.keys();
    for i = 1:numel(sensorKeys)
        key = sensorKeys{i};
        try
            if obj.MonitorTargets.isKey(key)
                % Tag path — Phase 1007 SC#4 realization
                [newEvents, gotData] = obj.processMonitorTag_(key);
            else
                % Legacy Sensor path — unchanged
                [newEvents, gotData] = obj.processSensor(key);
            end
            hasNewData = hasNewData || gotData;
            if ~isempty(newEvents), allNewEvents = [allNewEvents, newEvents]; end
        catch ex
            fprintf('[PIPELINE WARNING] Target "%s" failed: %s\n', key, ex.message);
        end
    end
    % ... remainder of runCycle unchanged ...
end

function [newEvents, gotData] = processMonitorTag_(obj, key)
    newEvents = [];
    gotData = false;
    if ~obj.DataSourceMap.has(key), return; end
    ds = obj.DataSourceMap.get(key);
    result = ds.fetchNew();
    if ~result.changed, return; end
    gotData = true;
    monitor = obj.MonitorTargets(key);
    % Parent tag absorbs new X/Y; MonitorTag.appendData does incremental tail computation.
    % MonitorTag fires events internally on rising edges (Phase 1006 MONITOR-05) into
    % its bound EventStore (obj.EventStore is set via MonitorTag constructor).
    monitor.Parent.updateData(result.X, result.Y);
    monitor.appendData(result.X, result.Y);
    % Harvest events that MonitorTag wrote to the store on this tick.
    % (Implementation: MonitorTag already calls EventStore.append inside fireEventsOnRisingEdges_;
    %  runCycle just needs to grab the incremental delta.)
    newEvents = obj.harvestTagEvents_(key);
end
```
**Performance:** `appendData` → 10.9-12.6x speedup vs full recompute (Phase 1007 bench). SC#4 "≥ legacy throughput" gate should be comfortable.

### Anti-Patterns to Avoid

- **`isa(tag, 'SensorTag')` switches inside the widget:** same Pitfall 1 invariant enforced in FastSense.addTag must apply to widgets — dispatch by `tag.getKind()` or rely on polymorphism of `getXY`/`valueAt`. Preserves TagRegistry's loadFromStructs round-trip — `testPitfall1NoIsaInFastSenseAddTag` is a grep gate; add equivalent for FastSenseWidget.
- **Editing the legacy branch to "simplify":** Pitfall 11 AND Pitfall 5 invariants. The `elseif ~isempty(obj.Sensor)` branch in every consumer stays BYTE-FOR-BYTE unchanged through Phase 1010. Only the new Tag branch is added above it.
- **Copying data in `Tag.getXY`:** SensorTag returns references (MATLAB COW). Widgets must not force copies with e.g. `x = obj.Tag.getXY(); x = x(:);` unless necessary.
- **Wiring DashboardEngine listeners directly to `Tag.X`/`Tag.Y`:** these properties don't always exist on abstract Tag (CompositeTag has none); use the existing invalidate/listener chain already built into MonitorTag for propagation, OR the unconditional `markDirty` path matching current Sensor behavior.
- **Writing a new `EventStore.getEventsForTag` that queries `Event.TagKeys`:** that field does not exist until Phase 1010. Use `SensorName`/`ThresholdLabel` carrier fields (Phase 1006 convention).
- **Calling `MonitorTag.appendData` WITHOUT first calling the parent's `updateData`:** the appendData docstring warns `parent.updateData` is expected to have already absorbed newX/newY before the call (`libs/SensorThreshold/MonitorTag.m:333-334`). LEP wire-up must call both in the right order.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Incremental live-tick update for a FastSenseWidget Tag | A new Tag-specific tick path | `FastSense.updateData(lineIdx, X, Y)` on `obj.FastSenseObj` | Already exists (line 1635); PERF2-01 incremental update from Phase 1000; same call shape for Sensor and Tag |
| Polymorphic Tag → FastSense dispatch | A widget-level kind switch | `FastSense.addTag(tag)` + let it switch internally on getKind() | Pitfall 1 invariant; already handles sensor/state/monitor/composite; tested via `testPitfall1NoIsaInFastSenseAddTag` |
| Incremental MonitorTag tail computation for live tick | Per-widget or per-pipeline ad-hoc streaming | `MonitorTag.appendData(newX, newY)` | Phase 1007 shipped with 10.9-12.6x speedup proof; handles hysteresis FSM carry + run-open carry + event emission on rising edges |
| Event rising-edge detection inside LiveEventPipeline | New detection loop in LEP | MonitorTag.appendData internally emits via MONITOR-05 carrier pattern | Already-built + tested in Phase 1006 Plan 02 (fireEventsOnRisingEdges_) |
| Register/resolve Tag.Key round-trip on load | Per-widget resolver | `TagRegistry.get(key)` in fromStruct | Mirrors `SensorRegistry.get` / `ThresholdRegistry.get` pattern used today |
| Cycle / duplicate-key detection on Tag add | Per-consumer validation | TagRegistry.register hard-errors on duplicate (Pitfall 7) | Already enforced Phase 1004 |
| ZOH current value for StatusWidget/IconCardWidget | Materialize full X/Y then take last | `tag.valueAt(now)` (or `valueAt(t)`) | Phase 1008 COMPOSITE-06 explicit fast path — single instant evaluation without full-series materialization |

**Key insight:** Every "new capability" needed in Phase 1009 already exists in the Tag API surface. Widgets only need to thread parameters through — no reimplementation.

## Runtime State Inventory

Phase 1009 is a refactor/migration phase. Runtime state that outlives a source edit:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **None material.** `EventStore` .mat files written by past runs carry `Event.SensorName`/`ThresholdLabel` strings — these are the carrier fields MONITOR-05 already writes `parent.Key` and `monitor.Key` into. Zero schema change; dashboard reload continues to work. | None. |
| Live service config | **None.** No running services own cross-session state tied to Sensor/Threshold keys that would break when new Tag widgets appear alongside. Widgets are in-process MATLAB objects. | None. |
| OS-registered state | **None.** No launchd / systemd / scheduler tasks reference dashboard widget identifiers. | None. |
| Secrets/env vars | **None.** `FASTSENSE_SKIP_BUILD` / `FASTSENSE_RESULTS_FILE` are CI-only and unrelated to Tag migration. | None. |
| Build artifacts / installed packages | **MEX binaries** in `libs/FastSense/private/mex_src/` do NOT encode Sensor/Threshold class names and are unaffected. No new MEX kernels planned in 1009 (Pitfall: the Phase 1007 `build_store_mex.c` schema extension for MonitorTag persistence is already shipped). | None — verified by checking `mex_src/*.c` grep for 'Sensor'/'Threshold' (no references). |

**Nothing found in categories 1-5:** state explicitly. Phase 1009 touches in-memory property shapes + method branches + serializer field names. Everything reverts cleanly via git revert of the plan commit.

## Common Pitfalls

### Pitfall 1 (over-specialized dispatch inside widgets) — CRITICAL

**What goes wrong:** Developer writes `if isa(obj.Tag, 'MonitorTag') ... elseif isa(obj.Tag, 'SensorTag') ...` inside a widget because it "reads clearly."
**Why it happens:** Autocomplete makes isa() easy; switch on kind requires typing the string.
**How to avoid:** Use `obj.Tag.getXY()` / `obj.Tag.valueAt()` — both polymorphic on Tag base. Where dispatch is truly needed (e.g., FastSenseWidget render), use `obj.Tag.getKind()` string switch, matching `FastSense.addTag` style (libs/FastSense/FastSense.m:969).
**Warning signs:** Grep `isa(.*'(Sensor|Monitor|State|Composite)Tag'` inside `libs/Dashboard/*.m` or `libs/FastSense/SensorDetailPlot.m` returns matches. Plan SUMMARY must include a zero-hit grep gate.

### Pitfall 5 (legacy property removal) — CRITICAL

**What goes wrong:** Developer "cleans up" the `obj.Sensor` property during Tag migration because "Tag replaces Sensor."
**Why it happens:** Consolidation instinct; makes diffs smaller.
**How to avoid:** ZERO removals. The legacy property, its branch in every method, and all fromStruct `'sensor'` cases stay. Every plan SUMMARY includes a per-file `git diff --stat` section showing legacy lines UNCHANGED.
**Warning signs:** `git diff phase-1008..HEAD -- libs/SensorThreshold/{Sensor,Threshold,StateChannel,CompositeThreshold,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry,ThresholdRule}.m` shows ANY change → fail the phase audit.

### Pitfall 9 (live-tick performance regression) — CRITICAL, quantified

**What goes wrong:** Tag path imposes per-tick overhead (handle dispatch, getXY copy, invalidate propagation) that trips the 10% regression gate.
**Why it happens:** Per-call overhead compounds at 12 widgets × live-tick frequency. MonitorTag.invalidate + getXY cold-recompute can out-cost a legacy Sensor.Y append-only read if ConditionFn is heavy.
**How to avoid:** Reuse `FastSense.updateData` (incremental; no full teardown); use `valueAt(now)` instead of full `getXY` for status widgets; AppendData-over-MonitorTag for LEP (proven 10.9-12.6x). 12-widget bench in Plan 04 asserts `tag_tick_time ≤ 1.10 × legacy_tick_time`.
**Warning signs:** Plan 04 bench shows > 5% overhead → diagnose per Pitfall-A6 checklist from Phase 1007 (cheap ConditionFn, growing-cache artifact, copy-on-write unnecessarily materialized).

### Pitfall 11 (golden test rewrite) — CRITICAL

**What goes wrong:** Developer "updates" `tests/test_golden_integration.m` to use Tag API.
**Why it happens:** The test uses old Sensor/Threshold/CompositeThreshold API; developer thinks "this phase migrates consumers, so the golden must migrate too."
**How to avoid:** File header says **"DO NOT REWRITE without architectural review. Modifying this test before Phase 1011 invalidates the safety net."** Phase 1011 rewrites it ONCE. Every plan in 1009 SUMMARY includes a grep gate proving the test file is untouched.
**Warning signs:** `git diff phase-1008..HEAD -- tests/test_golden_integration.m | wc -l` returns non-zero.

### Pitfall X (MONITOR-05 carrier contract on Event)

**What goes wrong:** Developer introduces `Event.TagKeys` in Phase 1009 because "it's cleaner."
**Why it happens:** Phase 1010 REQ EVENT-01 is known; developer pulls it forward.
**How to avoid:** Phase 1006 Plan 02 committed the carrier pattern (`SensorName = parent.Key`, `ThresholdLabel = monitor.Key`) specifically so Phase 1009 could wire EventTimelineWidget without touching Event schema. Phase 1010 owns the rename. EventTimelineWidget Tag-filter uses existing carrier fields.
**Warning signs:** `grep -rE "TagKeys|Event\.TagKey" libs/` returns matches during Phase 1009. This string is reserved for Phase 1010.

### Pitfall Y (LiveEventPipeline tick ordering)

**What goes wrong:** `MonitorTag.appendData(newX, newY)` is called BEFORE the parent SensorTag's `updateData(newX, newY)` — the appendData cold-path triggers a full recompute using the parent's pre-append X/Y, then next invalidate runs on stale cache.
**Why it happens:** The appendData docstring warns about this: "parent.updateData is expected to have already absorbed newX/newY into the parent before this call" (`libs/SensorThreshold/MonitorTag.m:333-334`).
**How to avoid:** In `LiveEventPipeline.processMonitorTag_`, always call `monitor.Parent.updateData(x, y)` FIRST, then `monitor.appendData(x, y)`. Add a test asserting this order (`testAppendDataOrderWithParent`).
**Warning signs:** LEP tests show event double-emission or missing events at tick boundaries.

### Pitfall Z (DashboardEngine sensor-listener wiring assumes obj.Sensor)

**What goes wrong:** `DashboardEngine.wireListeners` (line 935) only listens to `w.Sensor.X`/`Y` PostSet; Tag-bound widgets never get dirty-marked → no refresh at live tick.
**Why it happens:** wireListeners hardcodes `w.Sensor`.
**How to avoid:** Two options:
  1. (Recommended) Mirror the existing `onLiveTick` line 829 pattern: `if ~isempty(w.Sensor) || ~isempty(w.Tag), w.markDirty(); end`. Simplest, matches existing unconditional sensor path.
  2. Add `w.Tag.addListener(w)` if Tag is a MonitorTag; not worth special-casing — Option 1 is cheaper and uniform.
**Warning signs:** Live ticks stop refreshing a Tag-bound widget; easy to miss because the widget STILL renders correctly on initial load (just not on data append). Regression test: `TestLiveEventPipelineTag` asserts widget update count > 0 across a 3-tick simulation.

## Code Examples

### FastSenseWidget toStruct / fromStruct Tag round-trip

```matlab
% Source: existing FastSenseWidget.m:304-400 pattern + CONTEXT decisions
function s = toStruct(obj)
    s = toStruct@DashboardWidget(obj);    % base class handles Tag write (new Pattern 4 below)
    if ~isempty(obj.XLabel), s.xLabel = obj.XLabel; end
    % ... existing fields ...
    if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key)
        s.source = struct('type', 'tag', 'key', obj.Tag.Key);
        s.thresholds = obj.Thresholds;   % still honored when Tag is a SensorTag w/ thresholds
    elseif ~isempty(obj.Sensor)
        s.thresholds = obj.Thresholds;
        % base class already wrote s.source = struct('type', 'sensor', 'name', obj.Sensor.Key)
    elseif ~isempty(obj.File)
        % ... unchanged ...
    end
end

function obj = fromStruct(s)
    obj = FastSenseWidget();
    % ... existing base fields ...
    if isfield(s, 'source')
        switch s.source.type
            case 'tag'
                if exist('TagRegistry', 'class')
                    try
                        obj.Tag = TagRegistry.get(s.source.key);
                    catch
                        warning('FastSenseWidget:tagNotFound', ...
                            'TagRegistry key ''%s'' not found.', s.source.key);
                    end
                end
            case 'sensor'
                if exist('SensorRegistry', 'class')
                    try obj.Sensor = SensorRegistry.get(s.source.name); catch, end
                end
            % ... existing file / data cases ...
        end
    end
end
```

### DashboardWidget base Tag property + uniform serialization

```matlab
% Source: existing DashboardWidget.m:11-67 + CONTEXT decisions
% ADD to properties block:
properties (Access = public)
    Title       = ''
    Position    = [1 1 6 2]
    % ... existing properties ...
    Sensor      = []           % Sensor object for data binding (LEGACY — unchanged)
    Tag         = []           % NEW — Tag subclass (v2.0 Tag API)
end

% MODIFY toStruct to write 'tag' when Tag is set (precedence: Tag > Sensor):
function s = toStruct(obj)
    s.type = obj.Type;
    s.title = obj.Title;
    % ... existing fields ...
    if ~isempty(obj.Tag) && ~isempty(obj.Tag.Key)
        s.source = struct('type', 'tag', 'key', obj.Tag.Key);
    elseif ~isempty(obj.Sensor)
        s.source = struct('type', 'sensor', 'name', obj.Sensor.Key);
    end
end
```

### EventStore.getEventsForTag (new method; existing carrier pattern)

```matlab
% Source: new method on libs/EventDetection/EventStore.m
% Placed next to getEvents() line 37
function events = getEventsForTag(obj, tagKey)
%GETEVENTSFORTAG Return events whose SensorName or ThresholdLabel matches tagKey.
%   Implements EventTimelineWidget tag-key filter using the MONITOR-05
%   carrier pattern (Event.SensorName = parent.Key, Event.ThresholdLabel =
%   monitor.Key).  Phase 1010 (EVENT-01) will migrate to Event.TagKeys.
    events = [];
    if isempty(obj.events_), return; end
    if ~ischar(tagKey) && ~isstring(tagKey)
        error('EventStore:invalidTagKey', 'tagKey must be char or string.');
    end
    keep = false(1, numel(obj.events_));
    for i = 1:numel(obj.events_)
        ev = obj.events_(i);
        keep(i) = strcmp(ev.SensorName, tagKey) || strcmp(ev.ThresholdLabel, tagKey);
    end
    events = obj.events_(keep);
end
```

### EventDetector Tag overload

```matlab
% Source: new isa branch at top of libs/EventDetection/EventDetector.m:31
function events = detect(obj, varargin)
    %DETECT Find events from threshold violations.
    %   Two call shapes:
    %     events = det.detect(t, values, thresholdValue, direction, thresholdLabel, sensorName)
    %     events = det.detect(tag, threshold)    % NEW — v2.0 Tag overload
    if nargin == 3 && isa(varargin{1}, 'Tag') && isa(varargin{2}, 'Threshold')
        tag = varargin{1};
        threshold = varargin{2};
        [t, values] = tag.getXY();
        tVals = threshold.allValues();
        thresholdValue = tVals(1);    % single-value thresholds; composites are out of scope here
        direction = threshold.Direction;
        thresholdLabel = threshold.Name;
        sensorName = tag.Name;
        events = obj.detect_(t, values, thresholdValue, direction, thresholdLabel, sensorName);
        return;
    end
    % Legacy 6-arg shape — rename original body to detect_()
    events = obj.detect_(varargin{:});
end

function events = detect_(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)
    % ... original detect() body unchanged ...
end
```

### SensorDetailPlot dual-input guard

```matlab
% Source: replace libs/FastSense/SensorDetailPlot.m:50 assertion with a dual-input guard
function obj = SensorDetailPlot(tagOrSensor, varargin)
    if isa(tagOrSensor, 'Tag')
        obj.TagRef = tagOrSensor;           % NEW field
        obj.Sensor = [];                    % legacy ref empty in Tag mode
        [x, ~] = tagOrSensor.getXY();       % validate data exists
        if isempty(x)
            warning('SensorDetailPlot:emptyTag', 'Tag ''%s'' returned empty X.', tagOrSensor.Key);
        end
    elseif isa(tagOrSensor, 'Sensor')
        obj.Sensor = tagOrSensor;           % legacy path unchanged
    else
        error('SensorDetailPlot:invalidInput', ...
            'First argument must be a Sensor or Tag object; got %s.', class(tagOrSensor));
    end
    % ... rest of constructor unchanged; render() branches on ~isempty(obj.TagRef) ...
end
```

## State of the Art

| Old Approach (pre-Phase-1009) | Current Approach (Phase 1009) | When Changed | Impact |
|------|------|-----|----|
| Each widget hardcodes `obj.Sensor` + `obj.Sensor.Thresholds` access | Add `obj.Tag` branch first; fall through to legacy | This phase | Dashboards can now bind any Tag kind to any widget; legacy paths keep working |
| `LiveEventPipeline.runCycle` full-recompute per sensor via `IncrementalEventDetector.process(sensor, ...)` | For Tag-backed monitors, `monitor.appendData(x, y)` incremental; for Sensor, existing path | Plan 03 | 10.9-12.6x streaming speedup on Phase 1007 bench; MONITOR-05 auto-emit realized end-to-end |
| EventTimelineWidget filters by `FilterSensors` cellstr against `Event.SensorName` | Plus optional `FilterTagKey` via new `EventStore.getEventsForTag` | Plan 02 | Tag-keyed event display without Event schema change |
| FastSenseWidget render: `fp.addSensor(obj.Sensor)` only | Render: `fp.addTag(obj.Tag)` when Tag set; else `fp.addSensor` | Plan 01 | Uses existing Phase 1005-1008 polymorphic dispatch |

**Deprecated/outdated (in Phase 1009 — NOT removed yet, just superseded):**
- Implicit "widget always bound to a Sensor" assumption in `DashboardEngine.wireListeners` (line 935-949). Still works; Tag path coexists. Phase 1011 will sweep this.
- `SensorDetailPlot` single-Sensor constructor assertion — superseded by dual-input guard. Still works with existing Sensor inputs.

## Open Questions

1. **Should `DashboardWidget` base Tag property land in Plan 01 or Plan 02?**
   - What we know: Plan 01 touches FastSenseWidget which needs the Tag property; Plan 02 touches MultiStatus/IconCard/EventTimeline which all also need it.
   - What's unclear: Adding `Tag` to `DashboardWidget` base in Plan 01 lets Plan 01's FastSenseWidget use it without a redundant `Tag` on the subclass. But it also means Plan 01 ALSO touches Plan 02's consumers transitively.
   - Recommendation: **Land `DashboardWidget.Tag` as part of Plan 02** (Dashboard widgets cluster). In Plan 01, FastSenseWidget declares its own `Tag` property AND overrides toStruct to write it. Then Plan 02 moves the `Tag` property to the base class and removes the local declaration from FastSenseWidget (net-neutral, but keeps Plan 01 self-contained to FastSense-layer consumers). Alternative: accept cross-plan coupling (Plan 01 adds base Tag; Plan 02 only adds subclass-specific logic).

2. **How does `DashboardEngine.onLiveTick` mark Tag-bound widgets dirty?**
   - What we know: Line 829 unconditionally marks sensor-bound widgets dirty each tick.
   - What's unclear: Do we check `~isempty(w.Tag)` OR register Tag as an invalidate listener?
   - Recommendation: Mirror the existing Sensor approach — `if ~isempty(w.Sensor) || ~isempty(w.Tag), w.markDirty(); end`. Cheapest, uniform, Pitfall-1-preserving.

3. **Does `LiveEventPipeline` need a new `MonitorTargets` map or can it reuse `Sensors`?**
   - What we know: Current `Sensors` is `containers.Map` of key→Sensor. LEP constructor takes `(sensors, dataSourceMap, varargin)`.
   - What's unclear: If `Sensors` value becomes polymorphic (Sensor OR MonitorTag), cleanest API change is an ADDITIONAL `MonitorTargets` map. Alternative: rename to `Targets` and branch on `isa`.
   - Recommendation: **Add a new `MonitorTargets` containers.Map property** on LEP. Constructor accepts it as optional `'Monitors'` name-value pair. `runCycle` loops both maps. Legacy constructors keep working.

4. **What happens to `EventViewer`?** (`libs/EventDetection/EventViewer.m`)
   - What we know: Extensive Sensor-aware UI — popup filter by SensorName, click-to-plot with sensorData struct array, ThresholdColors by label.
   - What's unclear: CONTEXT lists 7 consumers; EventViewer is not explicitly on the list. It reads `Event.SensorName` and `Event.ThresholdLabel` directly, which (thanks to the carrier pattern) ALREADY carry Tag keys for MonitorTag-emitted events. So it should work unchanged.
   - Recommendation: **No migration in Phase 1009.** Add to Plan 04 phase-exit audit as a "verified-compatible" note. Phase 1010 may refactor for Event.TagKeys.

5. **Does `detectEventsFromSensor` (bridge helper) need a Tag overload?**
   - What we know: Helper at `libs/EventDetection/detectEventsFromSensor.m` — 66-line bridge that pulls `sensor.ResolvedViolations` and `sensor.ResolvedThresholds` and calls `EventDetector.detect`. Used by the golden test (line 35) and `LiveEventPipeline` possibly (grep check).
   - What's unclear: If a user has a SensorTag (wraps legacy Sensor via composition), do they call `detectEventsFromSensor(sensorTag)` and it works via getXY? No — it reaches into sensor.ResolvedViolations which is Sensor-specific.
   - Recommendation: **Don't add Tag overload to `detectEventsFromSensor` in Phase 1009.** Its role collapses once MonitorTag owns event emission (MONITOR-05). Plan 04 SUMMARY notes this as a Phase-1010 cleanup candidate.

## Environment Availability

All dependencies are in-tree; Phase 1009 adds zero external dependencies.

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB R2020b+ | All widgets | ✓ | R2020b+ | — |
| GNU Octave 7+ | Test suite (Octave flat-assert files) | ✓ | 7+ (Windows CI uses 9.2.0) | — |
| Bundled `mksqlite` MEX | EventStore / DataStore | ✓ | bundled at libs/FastSense/mksqlite.c | pure-MATLAB fallback already in place |
| `binary_search_mex` | MonitorTag valueAt (SensorTag) | ✓ | bundled | pure-MATLAB fallback present |
| Prior Tag phases (1004-1008) shipped | Everything | ✓ | HEAD | — |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** None.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Dual: MATLAB `matlab.unittest` suite (`tests/suite/Test*.m`) + Octave function-file mirrors (`tests/test_*.m`) |
| Config file | `tests/run_all_tests.m` (discovery) |
| Quick run command | `octave --no-gui --eval "install(); cd tests; test_<file>();"` |
| Full suite command | `octave --no-gui --eval "install(); cd tests; run_all_tests();"` |
| Phase gate | Full suite green + golden integration green + Pitfall 9 bench green |

### Phase Requirements → Test Map

Phase 1009 owns no new REQ-IDs. Tests verify behavioral parity, not new capability. Each plan's tests below:

| Plan | Behavior | Test Type | Automated Command | File Exists? |
|------|----------|-----------|-------------------|-------------|
| 01 | FastSenseWidget Tag path renders | unit | `octave --no-gui --eval "install(); cd tests; test_fastsense_widget_tag();"` | ❌ Wave 0 |
| 01 | FastSenseWidget Tag update path (live tick) | unit | same file, `testFastSenseWidgetTagUpdate` | ❌ Wave 0 |
| 01 | FastSenseWidget legacy Sensor path unchanged | smoke | reuse existing `TestFastSenseWidget.m` | ✅ |
| 01 | SensorDetailPlot accepts Tag | unit | `test_sensor_detail_plot_tag();` | ❌ Wave 0 |
| 01 | SensorDetailPlot legacy Sensor path unchanged | smoke | reuse existing `test_SensorDetailPlot.m` | ✅ |
| 02 | MultiStatusWidget item.tag routes through tag.valueAt | unit | `test_multistatus_widget_tag();` | ❌ Wave 0 |
| 02 | IconCardWidget Tag property + derive state | unit | `test_icon_card_widget_tag();` | ❌ Wave 0 |
| 02 | EventTimelineWidget FilterTagKey via carrier pattern | unit | `test_event_timeline_widget_tag();` | ❌ Wave 0 |
| 02 | DashboardWidget base Tag property toStruct/fromStruct | unit | reuse `TestDashboardWidget.m` extension | ✅ (extension) |
| 02 | Dashboard serializer Tag round-trip | integration | extend `TestDashboardSerializerRoundTrip.m` | ✅ (extension) |
| 03 | EventDetector Tag overload | unit | extend `TestEventDetector.m` (if present) or add `test_event_detector_tag.m` | ⚠️ verify |
| 03 | LiveEventPipeline MonitorTag live-tick with appendData | integration | `test_live_event_pipeline_tag();` | ❌ Wave 0 |
| 03 | LiveEventPipeline legacy Sensor path unchanged | smoke | reuse `test_live_pipeline.m` | ✅ |
| 03 | Parent.updateData → MonitorTag.appendData ordering | unit | inside `test_live_event_pipeline_tag();` (`testAppendDataOrderWithParent`) | ❌ Wave 0 |
| 04 | Pitfall 9 12-widget tick ≤ 10% regression | bench | `octave --no-gui --eval "install(); bench_consumer_migration_tick();"` | ❌ Wave 0 |
| All | Golden integration untouched | grep gate | `git diff phase-1008..HEAD -- tests/test_golden_integration.m` | ✅ (gate) |
| All | Legacy classes zero churn | grep gate | `git diff phase-1008..HEAD -- libs/SensorThreshold/{Sensor,Threshold,ThresholdRule,CompositeThreshold,StateChannel,SensorRegistry,ThresholdRegistry,ExternalSensorRegistry}.m` | ✅ (gate) |

### Sampling Rate
- **Per task commit:** `test_<cluster>_tag();` (e.g., `test_fastsense_widget_tag()` after Plan 01)
- **Per wave merge:** Cluster-wide — Plan 01 runs full `Test*Widget*.m` + `test_SensorDetailPlot`; Plan 02 runs all three new + reused existing; Plan 03 runs `test_live_event_pipeline_tag` + `test_live_pipeline` + `test_golden_integration`
- **Phase gate:** Full suite + `test_golden_integration` + `bench_consumer_migration_tick` all green; legacy zero-churn grep gate at 0 lines

### Wave 0 Gaps
- [ ] `tests/test_fastsense_widget_tag.m` + `tests/suite/TestFastSenseWidgetTag.m` — covers Plan 01 FastSenseWidget Tag path
- [ ] `tests/test_sensor_detail_plot_tag.m` + `tests/suite/TestSensorDetailPlotTag.m` — covers Plan 01 SDP Tag input
- [ ] `tests/test_multistatus_widget_tag.m` + `tests/suite/TestMultiStatusWidgetTag.m` — covers Plan 02 MultiStatus Tag items
- [ ] `tests/test_icon_card_widget_tag.m` + `tests/suite/TestIconCardWidgetTag.m` — covers Plan 02 IconCard Tag property
- [ ] `tests/test_event_timeline_widget_tag.m` + `tests/suite/TestEventTimelineWidgetTag.m` — covers Plan 02 timeline tag-key filter
- [ ] `tests/test_live_event_pipeline_tag.m` + `tests/suite/TestLiveEventPipelineTag.m` — covers Plan 03 MonitorTag appendData wiring + ordering + SC#4 evidence
- [ ] `benchmarks/bench_consumer_migration_tick.m` — covers Plan 04 Pitfall 9 gate
- [ ] Fixture tags in a shared helper: add `tests/suite/makePhase1009Fixtures.m` with factory methods (makeSensorTag, makeMonitorTag, makeCompositeTag, makeLiveFixture)
- [ ] Extension: add `testTagRoundTrip` method to `TestDashboardSerializerRoundTrip.m` (existing file)
- [ ] Extension: add `testTagSourceType` method to `TestDashboardWidget.m`-equivalent (if present; else create)
- [ ] Framework install: none (existing `install()` pipeline covers all new files)

## File-Touch Inventory (estimated)

**Production edits (libs/):**
1. `libs/Dashboard/FastSenseWidget.m` — +Tag property, +Tag branches in render/refresh/update/toStruct/fromStruct (~40-60 lines)
2. `libs/FastSense/SensorDetailPlot.m` — +TagRef field, constructor dual-path, render dual-path (~30-50 lines)
3. `libs/Dashboard/DashboardWidget.m` — +Tag property, +toStruct Tag branch (~5-8 lines)
4. `libs/Dashboard/MultiStatusWidget.m` — +item.tag branches in refresh/expandSensors_/toStruct/fromStruct/deriveColor (~30-40 lines)
5. `libs/Dashboard/IconCardWidget.m` — +Tag property, +Tag branches in refresh/toStruct/fromStruct (~25-35 lines)
6. `libs/Dashboard/EventTimelineWidget.m` — +FilterTagKey property, +getEventsForTag route in resolveEvents (~20-30 lines)
7. `libs/EventDetection/EventStore.m` — +getEventsForTag method (~15-20 lines)
8. `libs/EventDetection/EventDetector.m` — +detect Tag overload (~20-30 lines; extracts detect_ body)
9. `libs/EventDetection/LiveEventPipeline.m` — +MonitorTargets map property, +processMonitorTag_ method, +runCycle branch (~50-70 lines)
10. `libs/Dashboard/DashboardEngine.m` — +`|| ~isempty(w.Tag)` in onLiveTick line 829 (+1-2 lines)

**Production edits total: ~10 files, ~230-360 lines added. Legacy branches ZERO edits.**

**Tests (tests/, tests/suite/):**
- 6 new test file pairs (`tests/test_*_tag.m` + `tests/suite/Test*Tag.m`) → 12 files
- 2 test extensions in existing files (DashboardSerializerRoundTrip, DashboardWidget equivalents) → 2 files
- 1 shared fixture helper → 1 file
- **Tests total: ~15 new/edited files**

**Benchmarks:**
- `benchmarks/bench_consumer_migration_tick.m` (NEW) → 1 file

**Grand total estimated file touch: ~26 files.** No hard ROADMAP cap on this phase (Pitfall 5 only forbids legacy deletion). CONTEXT §specifics aims for 15-25 — we land at the high end; acceptable given 4 cluster scope.

**Per-plan file-touch targets (atomic revertability):**
- Plan 01 (FastSenseWidget + SensorDetailPlot): 2 production + 4 tests + 1 fixture = 7 files
- Plan 02 (Dashboard widgets + base): 4 production + 6 tests = 10 files
- Plan 03 (EventDetection): 3 production + 2 tests = 5 files + DashboardEngine.m one-liner = 6 files
- Plan 04 (bench + audit): 1 new bench + 1 SUMMARY = 2 files
- **Phase total: ~25 files** (close enough to the 15-25 target band with 1-file slack)

## Per-Consumer File / Method Inventory

### FastSenseWidget (libs/Dashboard/FastSenseWidget.m, 402 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Properties block (lines 12-32) | `DataStoreObj`, `XData`, `YData`, `File`, `XVar`, `YVar`, `Thresholds`, `XLabel`, `YLabel`, `YLimits`, `ShowThresholdLabels`; private `FastSenseObj`, `IsSettingTime`, `CachedXMin/Max`, `LastSensorRef` | ADD public property `Tag = []`; ADD private `LastTagRef = []` (for cache-invalidation parity) |
| Constructor (line 35) | Inherits from DashboardWidget; auto-sets YLabel from Sensor.Units/Name/Key | ADD same YLabel inference from `obj.Tag.Units/Name/Key` when Tag is set (precedence Tag > Sensor) |
| render (line 56) | Branches on Sensor / DataStoreObj / File / XData+YData; calls `fp.addSensor` / `fp.addLine` | ADD branch: `if ~isempty(obj.Tag), fp.addTag(obj.Tag); elseif ...` (existing branches untouched) |
| refresh (line 112) | `updateData(1, obj.Sensor.X, obj.Sensor.Y)` incremental path + full teardown fallback | ADD top-of-method branch: `if ~isempty(obj.Tag) && FastSenseObj valid, [x,y] = obj.Tag.getXY(); updateData(1, x, y); return; end` |
| update (line 197) | Mirror of refresh incremental path, no teardown fallback | Same addition as refresh |
| asciiRender (line 262) | Reads `obj.Sensor.Y` | ADD Tag branch: `if ~isempty(obj.Tag), [~, yData] = obj.Tag.getXY(); ...` |
| toStruct (line 304) | Writes source.type='sensor' via base class, or source.type='file'/'data' | ADD source.type='tag' branch (Tag takes precedence over Sensor) |
| fromStruct (line 354) | Switch on s.source.type: sensor / file / data | ADD `case 'tag'` via `TagRegistry.get(s.source.key)` |
| updateTimeRangeCache (line 324, private) | Reads obj.Sensor.X | ADD Tag branch: `elseif ~isempty(obj.Tag), [x,~]=obj.Tag.getXY(); ...` |

**Test targets:**
- Existing `TestFastSenseWidget.m` / `TestFastSenseWidgetUpdate.m` → smoke-test legacy Sensor path still works
- NEW `TestFastSenseWidgetTag.m` → SensorTag render, MonitorTag render, CompositeTag render, Tag update live-tick, Tag toStruct/fromStruct round-trip, YLabel auto-derive from Tag.Units

### SensorDetailPlot (libs/FastSense/SensorDetailPlot.m, 648 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Properties (line 19-22) | `Sensor`, `MainPlot`, `NavigatorPlot`, `NavigatorOverlayObj` | ADD `TagRef = []` private readable |
| Constructor (line 48) | `assert(isa(sensor, 'Sensor'))` hard-enforced | REPLACE with dual-input guard (Tag OR Sensor); set TagRef or Sensor exclusively |
| render (line 97) | `obj.Sensor.resolve()`, `fp.addLine(obj.Sensor.X, obj.Sensor.Y, ...)`, threshold loop reads `obj.Sensor.ResolvedThresholds` | ADD Tag branch: `if ~isempty(obj.TagRef), [x,y]=obj.TagRef.getXY(); fp.addLine(x,y,...); skip threshold-resolve loop; end` (Tag thresholds deferred) |
| addNavigatorThresholdBands (line 376, private) | Iterates `obj.Sensor.ResolvedThresholds` | Skip when Tag-mode (add early return `if ~isempty(obj.TagRef), return; end`) |
| filterEventsForSensor (line 475, private) | `strcmp({events.SensorName}, obj.Sensor.Key)` | ADD Tag branch: use `obj.TagRef.Key` |

**Test targets:**
- Existing `TestSensorDetailPlot.m` → legacy smoke
- NEW `TestSensorDetailPlotTag.m` → construct with SensorTag/MonitorTag; render smoke; input-type error test

### DashboardWidget base (libs/Dashboard/DashboardWidget.m, 149 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Properties (line 11-20) | `Title`, `Position`, `ThemeOverride`, `UseGlobalTime`, `Description`, `Sensor`, `ParentTheme`, `Dirty` | ADD `Tag = []` |
| Constructor (line 35) | Title cascade from Sensor.Name/Key when empty | ADD Tag cascade as alternative source |
| toStruct (line 53) | Writes `s.source = struct('type','sensor','name',obj.Sensor.Key)` when Sensor set | ADD Tag branch with precedence Tag > Sensor |

### MultiStatusWidget (libs/Dashboard/MultiStatusWidget.m, 383 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Items model (Sensors property, line 3) | Cell array of Sensors OR structs with `threshold` key | EXTEND struct shape to optionally carry `tag` field (Tag handle or string key) |
| refresh (line 32) | Iterates items: struct with `threshold` goes through deriveColorFromThreshold, raw Sensor through deriveColor | ADD branch: `if isstruct(item) && isfield(item,'tag'), color = deriveColorFromTag_(item, theme); elseif ...` |
| expandSensors_ (line 218, private) | Expands CompositeThreshold items into child rows + summary row | ADD same logic for CompositeTag when item.tag is a CompositeTag (use composite.getChildren() equivalent) |
| deriveColorFromThreshold (line 259, private) | Reads item.threshold; CompositeThreshold → computeStatus | Mirror as new `deriveColorFromTag_` using `tag.valueAt(now)` and Criticality → color mapping |
| toStruct (line 178) / fromStruct (line 329) | items.type = 'threshold' or 'sensor' with key/label fields | ADD items.type = 'tag' with tag.Key persisted |

### IconCardWidget (libs/Dashboard/IconCardWidget.m, 350 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Properties (line 24-33) | `IconColor`, `StaticValue`, `ValueFcn`, `StaticState`, `Units`, `Format`, `SecondaryLabel`, `Threshold` | ADD `Tag = []` |
| Constructor (line 45) | Resolves string Threshold key via ThresholdRegistry; mutex with Sensor | ADD same resolution for Tag; mutex precedence: Tag > Threshold > Sensor |
| refresh (line 138) | Branches: Threshold with ValueFcn or Sensor or ValueFcn or StaticValue | ADD top-most: `if ~isempty(obj.Tag), obj.CurrentValue = obj.Tag.valueAt(now); ...` |
| deriveStateFromThreshold (line 304, private) | CompositeThreshold → computeStatus; else threshold.allValues() | NEW parallel `deriveStateFromTag_` using tag.valueAt(now) and Tag.Criticality mapping |
| toStruct (line 226) / fromStruct (line 255) | source.type='threshold'|'callback'|'static'|'sensor' | ADD source.type='tag' |

### EventTimelineWidget (libs/Dashboard/EventTimelineWidget.m, 345 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Properties (line 14-20) | `EventStoreObj`, `Events`, `EventFcn`, `FilterSensors`, `ColorSource` | ADD `FilterTagKey = ''` |
| resolveEvents (line 235, private) | `obj.EventStoreObj.getEvents()` then filter by FilterSensors cellstr | ADD branch: `if ~isempty(obj.FilterTagKey), raw = obj.EventStoreObj.getEventsForTag(obj.FilterTagKey); else raw = obj.EventStoreObj.getEvents(); end` (before existing FilterSensors filter) |
| toStruct (line 191) / fromStruct (line 208) | Serializes source + filterSensors + colorSource | ADD filterTagKey round-trip field |

### EventDetector (libs/EventDetection/EventDetector.m, 88 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| detect method (line 31) | 6-arg signature: `(t, values, thresholdValue, direction, thresholdLabel, sensorName)` | RENAME body to `detect_` private; public `detect` becomes varargin shim that branches on `isa(varargin{1}, 'Tag')` |

### LiveEventPipeline (libs/EventDetection/LiveEventPipeline.m, 221 SLOC) — Plan 03 keystone

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| Properties (line 4-15) | `Sensors` (containers.Map), `DataSourceMap`, `EventStore`, `NotificationService`, `Interval`, `Status`, `MinDuration`, `EscalateSeverity`, `MaxCallsPerEvent`, `OnEventStart` | ADD `MonitorTargets = containers.Map('KeyType','char','ValueType','any')` |
| Constructor (line 24) | Accepts Sensors map + DataSourceMap + varargin | ADD optional `'Monitors'` NV pair; populate `obj.MonitorTargets` |
| runCycle (line 86) | Loops over `obj.Sensors.keys()`, calls processSensor | ADD branch: `if obj.MonitorTargets.isKey(key), [newEvents, gotData] = obj.processMonitorTag_(key); else [...] = obj.processSensor(key); end` |
| NEW method processMonitorTag_ | — | Calls `monitor.Parent.updateData(x, y)` first, then `monitor.appendData(x, y)`; events surface via MonitorTag's bound EventStore |
| updateStoreSensorData (line 189, private) | Writes `SensorData` from Sensor + Thresholds | Extend to also surface MonitorTag-parent X/Y |
| buildSensorData (line 170, private) | Reads `sensor.Thresholds` | If target is MonitorTag, derive thresholdValue/direction from ConditionFn (best-effort; may leave as NaN/'upper' with comment) |

**Test targets (Plan 03 SC#4 evidence):**
- NEW `test_live_event_pipeline_tag.m` / `TestLiveEventPipelineTag.m`:
  - `testMonitorTagPathEmitsEventsOnAppendData` — live tick with MonitorTag target; assert EventStore.events_ count increases
  - `testAppendDataOrderWithParent` — parent.updateData called BEFORE monitor.appendData
  - `testThroughputVsLegacy` — min-of-3 runs of 50 ticks × 12 targets; assert Tag path ≤ 1.10× legacy. Plan 04 moves this to bench_consumer_migration_tick.
  - `testLegacySensorPathUnchanged` — smoke test with existing Sensors-only shape

### EventStore (libs/EventDetection/EventStore.m, 148 SLOC)

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| getEvents (line 36) | Returns `obj.events_` | NEW sibling method `getEventsForTag(tagKey)` — filters events_ by SensorName==tagKey OR ThresholdLabel==tagKey |

### DashboardEngine (libs/Dashboard/DashboardEngine.m, ~1250 SLOC) — one-liner edit

| Location | Current shape | Migration action |
|----------|---------------|------------------|
| onLiveTick (line 814, specifically line 829) | `if ~isempty(w.Sensor), w.markDirty(); end` | CHANGE to `if ~isempty(w.Sensor) || ~isempty(w.Tag), w.markDirty(); end` (Plan 02 as part of Dashboard cluster) |
| wireListeners (line 935) | Listens to `w.Sensor.X`/`Y` PostSet | LEAVE as-is (Tag widgets use markDirty via onLiveTick unconditional path). Alternative: add Tag listener wiring — defer to Plan 02 discretion. |

## Sources

### Primary (HIGH confidence — read end-to-end)
- `.planning/phases/1009-consumer-migration/1009-CONTEXT.md` — authoritative user decisions
- `.planning/REQUIREMENTS.md` §Phase 1009 row (line 203, 210) — zero REQ-IDs explicit
- `.planning/ROADMAP.md` §Phase 1009 (lines 180-195) — goal, deps, success criteria, gates
- `libs/Dashboard/FastSenseWidget.m` (402 SLOC, full) — target file 1
- `libs/Dashboard/MultiStatusWidget.m` (383 SLOC, full) — target file 2
- `libs/Dashboard/IconCardWidget.m` (350 SLOC, full) — target file 3
- `libs/Dashboard/EventTimelineWidget.m` (345 SLOC, full) — target file 4
- `libs/Dashboard/DashboardWidget.m` (149 SLOC, full) — target file 5
- `libs/FastSense/SensorDetailPlot.m` (648 SLOC, full) — target file 6
- `libs/EventDetection/EventDetector.m` (88 SLOC, full) — target file 7
- `libs/EventDetection/LiveEventPipeline.m` (221 SLOC, full) — target file 8 (Plan 03 keystone)
- `libs/EventDetection/EventStore.m` (148 SLOC, full) — target file 9
- `libs/EventDetection/IncrementalEventDetector.m` (254 SLOC, full) — context for LEP rewire
- `libs/EventDetection/detectEventsFromSensor.m` (66 SLOC, full) — bridge helper; no migration
- `libs/SensorThreshold/Tag.m` (157 SLOC, full) — abstract base
- `libs/SensorThreshold/MonitorTag.m` (partial lines 1-350; appendData signature confirmed) — Phase 1007 API
- `libs/SensorThreshold/SensorTag.m` (partial lines 1-100) — composition delegate pattern
- `libs/SensorThreshold/TagRegistry.m` (partial lines 1-80) — get/register API
- `libs/FastSense/FastSense.m` addTag region (lines 943-1014) + updateData (line 1635) + addSensor (line 516)
- `libs/Dashboard/DashboardEngine.m` live-tick (lines 810-950) — wireListeners + onLiveTick patterns
- `.planning/phases/1007-monitortag-streaming-persistence/1007-03-SUMMARY.md` — SC#4 deferral rationale + appendData benchmark numbers (10.9-12.6x)
- `.planning/phases/1006-monitortag-lazy-in-memory/1006-02-SUMMARY.md` — MONITOR-05 carrier pattern (SensorName=parent.Key, ThresholdLabel=monitor.Key)
- `.planning/phases/1006-monitortag-lazy-in-memory/1006-03-SUMMARY.md` — FastSense.addTag 'monitor' case + Pitfall 9 bench template
- `.planning/phases/1008-compositetag/1008-03-SUMMARY.md` — Pitfall 1 invariant grep-guard pattern (testPitfall1NoIsaInFastSenseAddTag)
- `tests/test_golden_integration.m` (74 SLOC, full) — Pitfall 11 invariant
- `benchmarks/bench_monitortag_tick.m` (104 SLOC, full) — reusable bench template for Plan 04

### Secondary (MEDIUM confidence — skim-verified)
- `libs/Dashboard/StatusWidget.m` threshold-binding sections — verified already handles Threshold bindings → no Tag migration needed per CONTEXT ("StatusWidget/GaugeWidget got Threshold support in Phase 1001-1002; check if needed" — answer: existing Threshold path covers Tag-backed threshold use cases)
- `libs/Dashboard/GaugeWidget.m` Threshold sections — same as StatusWidget; no 1009 touch required
- `libs/Dashboard/ChipBarWidget.m` — same classification
- `libs/Dashboard/NumberWidget.m` Sensor references — pure display widget; can use Tag via DashboardWidget base property Phase 1010 if needed; not on Phase 1009 consumer list
- `libs/Dashboard/DetachedMirror.m` — clones widgets; sensor-ref restoration at line 215 — must include Tag restoration symmetry (Plan 02 nice-to-have)
- `libs/EventDetection/EventViewer.m` — reads Event.SensorName / ThresholdLabel directly; works unchanged via carrier pattern

### Tertiary (LOW confidence — flagged for planner validation)
- Test infrastructure for tag-backed fixtures — `tests/suite/MockTag.m` exists (Phase 1004), can be reused; exact shape of `makeMonitorTag` fixture TBD at planning time
- `EventDetector.detect` call sites — greps show `detectEventsFromSensor` is the primary caller; direct `detect()` invocations are few (from golden test + `IncrementalEventDetector.process`). Overload shape must not break these.

## Metadata

**Confidence breakdown:**
- User Constraints: HIGH — copied verbatim from CONTEXT.md
- Standard Stack: HIGH — all APIs landed in phases 1004-1008 with SUMMARY evidence
- Architecture Patterns: HIGH — derived from reading every target file in full
- Pitfalls: HIGH — Pitfall 1/5/9/11 precedents documented in Phase 1004-1008 SUMMARYs
- File-touch inventory: HIGH — file sizes + grep counts measured; migration actions mapped to specific line numbers
- Open Questions: MEDIUM — 5 open questions with recommendations; planner may choose alternatives

**Research date:** 2026-04-16
**Valid until:** Phase 1010 start (Event ↔ Tag binding will change `Event.TagKeys` semantics and will require re-research for EventTimelineWidget + LEP)

## RESEARCH COMPLETE

**Phase:** 1009 - Consumer migration (one widget at a time)
**Confidence:** HIGH

### Key Findings

- **Migration pattern is a one-liner per consumer**: prepend a `~isempty(obj.Tag)` dispatch branch before existing Sensor/Threshold code. Every capability needed (addTag, appendData, valueAt, TagRegistry) already exists and is tested.
- **MONITOR-05 end-to-end realization is 50-70 lines in `LiveEventPipeline`**: add `MonitorTargets` map, add `processMonitorTag_` method that calls `parent.updateData` THEN `monitor.appendData`. Phase 1007 bench proves 10.9-12.6x speedup; SC#4 ≥-legacy-throughput gate should be trivial.
- **EventTimelineWidget needs zero Event schema change**: MONITOR-05 carrier pattern writes `parent.Key`/`monitor.Key` into existing `Event.SensorName`/`ThresholdLabel` fields. New `EventStore.getEventsForTag(tagKey)` is a 15-line filter.
- **DashboardEngine one-liner change at line 829**: `|| ~isempty(w.Tag)` next to the existing Sensor check is the cheapest way to dirty-flag Tag-bound widgets on every live tick. Matches Pitfall 1 (no isa switches).
- **StatusWidget / GaugeWidget / ChipBarWidget DON'T need Tag migration in Phase 1009**: their Phase 1001-1002 Threshold binding already covers Tag-backed threshold use cases; those widgets stay on Threshold API until Phase 1011 unification.

### File Created
`.planning/phases/1009-consumer-migration/1009-RESEARCH.md`

### Confidence Assessment
| Area | Level | Reason |
|------|-------|--------|
| Standard Stack | HIGH | All Phase 1004-1008 APIs landed and tested; direct file-level verification |
| Architecture | HIGH | Every consumer target file read end-to-end; migration actions mapped to specific line numbers |
| Pitfalls | HIGH | Pitfall 1/5/9/11 precedents documented in Phase 1004-1008 SUMMARYs with grep-gate templates |
| LEP SC#4 wire-up | HIGH | MonitorTag.appendData signature + parent.updateData ordering contract explicit in Phase 1007 docstring |
| Consumer priority / plan split | MEDIUM | CONTEXT proposes 4 plans; Open Question #1 notes Plan 01/Plan 02 boundary on DashboardWidget.Tag could go either way |
| Test-harness reuse vs new | MEDIUM | Existing Tag fixtures (MockTag, Phase 1006 test files) can seed new tests; exact fixture factory shape TBD at plan time |

### Open Questions
1. DashboardWidget base Tag property: Plan 01 or Plan 02? (Recommend Plan 02 for cluster purity)
2. DashboardEngine Tag dirty-flagging: unconditional markDirty OR Tag listener subscription? (Recommend unconditional to match Sensor behavior)
3. LiveEventPipeline map shape: Sensors polymorphic OR additional MonitorTargets map? (Recommend new map)
4. EventViewer migration status? (Recommend NONE — carrier pattern means it works unchanged)
5. detectEventsFromSensor Tag overload? (Recommend SKIP — wait for Phase 1010 or 1011)

### Ready for Planning

Research complete. Planner can now create 4 PLAN.md files (Plan 01 FastSense-layer; Plan 02 Dashboard-layer; Plan 03 EventDetection LEP wire-up; Plan 04 Pitfall 9 bench + phase-exit audit).
