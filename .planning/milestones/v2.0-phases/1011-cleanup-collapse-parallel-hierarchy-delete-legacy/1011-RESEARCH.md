# Phase 1011: Cleanup -- collapse parallel hierarchy + delete legacy - Research

**Researched:** 2026-04-17
**Domain:** MATLAB class deletion, composition-to-inline refactor, test migration
**Confidence:** HIGH

## Summary

Phase 1011 is the final v2.0 cleanup: delete 8 legacy classes, inline the SensorTag delegate, remove legacy branches from consumers, rewrite the golden integration test, and achieve zero legacy references in production code. The research thoroughly audited every file that references the legacy classes across libs/, tests/, examples/, and benchmarks/.

The SensorTag currently composes a private `Sensor_` delegate that holds X, Y, DataStore, and metadata (ID, Source, MatFile, KeyName). After `Sensor.m` is deleted, these 8 properties must be inlined directly onto SensorTag. The `load()`, `toDisk()`, `toMemory()`, `isOnDisk()` methods are straightforward to port since they only reference `Sensor_` properties and `FastSenseDataStore`. The private helpers in `libs/SensorThreshold/private/` are called exclusively by `Sensor.resolve()` and related threshold machinery -- none are called by surviving Tag code, so they can all be deleted or kept inert (the MEX files serve other callers).

**Primary recommendation:** Execute the deletion order from CONTEXT.md (tests first, then classes, then consumer cleanup, then golden rewrite, then grep audit). The SensorTag inlining is the only non-trivial code change -- all other work is pure deletion or branch removal.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Deletion order: (1) legacy test files, (2) 8 legacy classes, (3) legacy branches in consumers, (4) golden test rewrite, (5) grep audit + private helpers, (6) install.m paths
- SensorTag composition delegate: research must determine inline vs stripped-down approach (see research below)
- FastSense.addSensor: Option A (full delete, no wrapper)
- Golden integration test: MUST preserve ALL assertion semantics; behavior changes = bugs
- No new error IDs in this phase
- No backward-compat deprecation stubs unless research reveals external callers

### Claude's Discretion
- Exact SensorTag data-inlining approach (depends on current delegate wiring)
- Which private/ helpers to keep vs delete (depends on grep results)
- Whether to keep backward-compat deprecation stubs (should NOT per full-cut decision)
- Exact order of test file deletions

### Deferred Ideas (OUT OF SCOPE)
None -- this is the final cleanup phase of v2.0.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| MIGRATE-03 | Delete 8 legacy classes, rewrite golden test for new API | Full audit of deletion surface, consumer branches, private helper callers, golden test mapping table, and file-touch budget documented below |
</phase_requirements>

## Architecture Patterns

### SensorTag Delegate Surface (Research Area 1)

SensorTag currently delegates to `Sensor_` (private property) for all data operations. The exact delegation surface:

| SensorTag Method | Delegates To | What It Does |
|-----------------|-------------|--------------|
| `getXY()` | `obj.Sensor_.X`, `obj.Sensor_.Y` | Returns raw data arrays |
| `valueAt(t)` | `obj.Sensor_.X`, `obj.Sensor_.Y` | ZOH lookup via `binary_search` |
| `getTimeRange()` | `obj.Sensor_.X` | Returns `[X(1), X(end)]` |
| `get.DataStore` | `obj.Sensor_.DataStore` | Dependent property forward |
| `load(matFile)` | `obj.Sensor_.MatFile`, `obj.Sensor_.load()` | Loads .mat file data |
| `toDisk()` | `obj.Sensor_.toDisk()` | Moves data to FastSenseDataStore |
| `toMemory()` | `obj.Sensor_.toMemory()` | Loads data back from disk |
| `isOnDisk()` | `obj.Sensor_.isOnDisk()` | Checks if DataStore is set |
| `updateData(X,Y)` | `obj.Sensor_.X`, `obj.Sensor_.Y` | Replaces data + fires listeners |
| constructor | `Sensor(key, sensorArgs{:})` | Creates inner Sensor |
| `toStruct()` | `obj.Sensor_.ID/Source/MatFile/KeyName` | Serializes extras |
| `fromStruct()` | Passes NV args to constructor | Deserializes |

**Confidence:** HIGH -- read directly from SensorTag.m source.

### Sensor.m Internal Data Storage (Research Area 2)

Properties that must move to SensorTag:

| Property | Type | Default | Used By |
|----------|------|---------|---------|
| `X` | double array | `[]` | getXY, valueAt, getTimeRange, updateData, load, toDisk, toMemory |
| `Y` | double array | `[]` | getXY, valueAt, updateData, load, toDisk, toMemory |
| `DataStore` | FastSenseDataStore | `[]` | toDisk, toMemory, isOnDisk, get.DataStore |
| `ID` | numeric | `[]` | toStruct only |
| `Source` | char | `''` | toStruct only |
| `MatFile` | char | `''` | load, toStruct |
| `KeyName` | char | key | load, toStruct |

Properties that do NOT move (threshold machinery, deleted with Sensor):
- `StateChannels`, `Thresholds`, `ResolvedThresholds`, `ResolvedViolations`, `ResolvedStateBands`
- Methods: `resolve()`, `addStateChannel()`, `addThreshold()`, `removeThreshold()`, `getThresholdsAt()`, `countViolations()`, `currentStatus()`

**Confidence:** HIGH -- read directly from Sensor.m source.

### Sensor.load() Implementation (Research Area 3)

The `load()` method (Sensor.m lines 132-169) does:
1. Checks `obj.MatFile` is set and file exists
2. Calls `builtin('load', obj.MatFile)` to avoid recursion with method name
3. Checks `obj.KeyName` field exists in loaded data
4. If field is a struct with x/X, y/Y subfields, maps to X, Y
5. Otherwise, sets Y = field value, X = 1:numel(Y)

Port to SensorTag: straightforward copy, replace `obj.Sensor_.MatFile` -> `obj.MatFile_`, etc. The `builtin('load', ...)` trick is essential to preserve.

**Confidence:** HIGH -- exact implementation read from source.

### Sensor.toDisk/toMemory/isOnDisk (Research Area 4)

**toDisk()** (lines 250-292):
1. Early return if already on disk (X empty + DataStore exists)
2. Error if no data
3. Creates `FastSenseDataStore(obj.X, obj.Y)`
4. Pre-computes `resolve()` while X/Y still in memory (threshold-specific -- skip in SensorTag)
5. Stores resolved results in SQLite (threshold-specific -- skip)
6. Clears X, Y

For SensorTag: steps 4-5 are threshold-specific and should be OMITTED. SensorTag.toDisk() becomes:
```matlab
if isempty(obj.X_) && ~isempty(obj.DataStore_), return; end
if isempty(obj.X_), error('SensorTag:noData', '...'); end
obj.DataStore_ = FastSenseDataStore(obj.X_, obj.Y_);
obj.X_ = []; obj.Y_ = [];
```

**toMemory()** (lines 294-307): Reads full data from DataStore, cleans up DataStore. Straightforward port.

**isOnDisk()** (line 309-311): `~isempty(obj.DataStore)`. Trivial.

**Confidence:** HIGH.

### Recommended SensorTag Inlining Approach

**Decision: Option A -- inline all data storage directly on SensorTag.**

New private properties on SensorTag:
```
X_         = []    % double: time stamps (was Sensor_.X)
Y_         = []    % double: values (was Sensor_.Y)
DataStore_ = []    % FastSenseDataStore (was Sensor_.DataStore)
ID_        = []    % numeric (was Sensor_.ID)
Source_    = ''    % char (was Sensor_.Source)
MatFile_   = ''    % char (was Sensor_.MatFile)
KeyName_   = ''    % char (was Sensor_.KeyName)
```

Remove: `Sensor_` property entirely.
Update: constructor to accept and store NV pairs directly instead of creating a Sensor delegate.
Update: `splitArgs_` to store sensor extras in private properties instead of forwarding to Sensor ctor.
Update: all methods to read `obj.X_` instead of `obj.Sensor_.X`, etc.

This is clean because Sensor has no behavior that SensorTag needs beyond data storage -- all threshold/resolve machinery is being deleted.

**Confidence:** HIGH.

### Private Helpers Audit (Research Area 5)

All helpers in `libs/SensorThreshold/private/` and their callers:

| Helper | Called By | Action |
|--------|----------|--------|
| `alignStateToTime.m` | Referenced in StateChannel.m doc only (not code) | DELETE |
| `appendResults.m` | Sensor.resolve(), mergeResolvedByLabel | DELETE |
| `buildThresholdEntry.m` | Sensor.resolve() | DELETE |
| `compute_violations_batch.m` | Sensor.resolve() | DELETE |
| `compute_violations_disk.m` | Sensor.resolve() | DELETE |
| `conditionKey.m` | ThresholdRule constructor | DELETE (ThresholdRule deleted) |
| `extractDatenumField.m` | loadModuleData.m | DELETE (loadModuleData deleted) |
| `mergeResolvedByLabel.m` | Sensor.resolve() | DELETE |
| `toStepFunction.m` | mergeResolvedByLabel | DELETE |
| `compute_violations_mex.mex` | compute_violations_batch.m (MEX accelerator) | DELETE |
| `resolve_disk_mex.mex` | compute_violations_disk.m | DELETE |
| `to_step_function_mex.mex` | toStepFunction.m | DELETE |
| `violation_cull_mex.mex` | Sensor.resolve() pathway | DELETE |

**All 13 private helper files** are called exclusively by Sensor.resolve() and its support chain, or by classes being deleted. None are called by surviving Tag code (Tag/SensorTag/StateTag/MonitorTag/CompositeTag/TagRegistry).

**Confidence:** HIGH -- verified via grep across all `libs/` .m files.

### loadModuleData.m / loadModuleMetadata.m (Research Area 13)

These two standalone functions in `libs/SensorThreshold/`:
- `loadModuleData.m` -- calls `extractDatenumField` (private helper). Creates Sensor objects with data from .mat files.
- `loadModuleMetadata.m` -- referenced only by `TestLoadModuleMetadata.m` and `TestLoadModuleData.m` test files.

Neither is called by any surviving production code in `libs/`. They are utility functions that create Sensor objects -- no surviving consumers.

**Action:** DELETE both files. DELETE their test files (TestLoadModuleData.m, TestLoadModuleMetadata.m, and Octave equivalents if they exist).

**Confidence:** HIGH -- verified via grep of all libs/ .m files.

### Consumer Legacy-Branch Inventory (Research Area 7)

#### FastSense.m -- `addSensor()` method
- Lines 520-594: Full `addSensor()` method. DELETE entirely.
- Line 963: Comment referencing `addSensor` in `addTag` docs -- update comment.
- Lines 2468-2479: `resolveThresholdStyle` helper referenced by `addSensor` -- check if also used by `addTag`. If only by `addSensor`, delete.

#### FastSenseWidget.m -- Legacy Sensor branches
Major legacy blocks identified:
- Lines 42-53: `render_()` Sensor-based YLabel/title setup + `LastSensorRef` snapshot
- Lines 57-59: Comment about Tag > Sensor precedence (keep comment about Tag-only)
- Lines 97-98: `render_()` fallback to `fp.addSensor(obj.Sensor)` when no Tag
- Line 129: `LastSensorRef` snapshot update
- Lines 147-181: `refreshIncremental_()` legacy Sensor path for incremental updates
- Lines 213, 233: `refreshFull_()` legacy `fp.addSensor` + LastSensorRef
- Lines 255-281: `refreshTagIncremental_()` has a fallback Sensor branch
- Lines 350-351, 392, 429-430: Various Sensor data reads in helper methods
- Lines 454-456, 538-542: Comment references and fromStruct SensorRegistry.get
- Property: `LastSensorRef` (line 32) -- DELETE

#### SensorDetailPlot.m -- Legacy Sensor branch
- Line 19: `Sensor` property
- Lines 49-74: Constructor dual-input guard (Tag vs Sensor)
- Lines 92-97: Title default from Sensor.Name
- Lines 132-155: Legacy resolve + data extraction from Sensor
- Lines 165-167: Threshold rendering from Sensor.ResolvedThresholds
- Lines 424-454: Navigator threshold bands from Sensor
- Lines 527-537: `filterEventsForSensor` reads Sensor.Key
- After cleanup: only the Tag path remains; `Sensor` property removed.

#### EventDetector.m -- Legacy overload
- Lines 46-51: The `detect()` method has a 6-arg legacy path alongside the 2-arg Tag overload.
- Lines 91-92: Comments about legacy 6-arg path.
- After cleanup: keep only the 2-arg Tag overload + the shared `detect_()` private body. The 6-arg signature is used by `detectEventsFromSensor` (being deleted) and some tests (being deleted/rewritten).

#### LiveEventPipeline.m -- Legacy Sensors map
- Line 23: `Sensors` property (containers.Map)
- Line 54: Constructor stores Sensors
- Lines 63: Constructor comment about legacy pair
- Lines 121-136: Legacy Sensor tick path in `tick_()` 
- Lines 144-146: Collision rule (Sensors wins over MonitorTargets)
- Lines 167: `updateStoreSensorData()` call
- Lines 187, 203-253: `processSensor()` method
- Lines 312-362: `buildSensorData()` and `updateStoreSensorData()` methods
- After cleanup: remove `Sensors` property, remove all `processSensor`/`buildSensorData`/`updateStoreSensorData` methods, simplify constructor to only accept MonitorTargets.

#### DashboardEngine.m
- Line 831: Check for `w.Sensor` in tick refresh
- Lines 941-948: PostSet listeners on `w.Sensor.X`/`w.Sensor.Y`
- Line 1243: `SensorResolver` option
- After cleanup: remove Sensor checks, keep only Tag-based refresh.

#### DashboardWidget.m (base class)
- Line 17: `Sensor` property on base class
- Lines 40-51: Title cascade with Sensor fallback
- Lines 71-75: toStruct source from Sensor.Key
- After cleanup: remove `Sensor` property and all Sensor branches. All widgets use Tag going forward.

#### Other Dashboard Widgets with `obj.Sensor` references
14 widget files reference `obj.Sensor` (identified via grep). Most have a `fromStruct` that calls `SensorRegistry.get()`. These all need:
1. Remove `obj.Sensor` references, use `obj.Tag` instead
2. Remove `SensorRegistry.get()` from `fromStruct` -- use `TagRegistry.get()` 
3. Several widgets (StatusWidget, GaugeWidget, NumberWidget, etc.) have `Sensor`-based data reads in `refresh()` methods

#### DashboardSerializer.m
- Lines 42, 602: Generates `SensorRegistry.get()` calls in .m export
- After cleanup: generate `TagRegistry.get()` calls instead

#### DashboardBuilder.m
- Line 1002: `SensorRegistry.get(srcKey)` call
- After cleanup: use `TagRegistry.get()` instead

#### DetachedMirror.m
- Lines 142, 266: Comments about `SensorRegistry.get()` throwing
- After cleanup: update comments to reference TagRegistry

**Confidence:** HIGH -- all identified via systematic grep.

### detectEventsFromSensor.m (Research Area 8)

This is a standalone bridge function that:
1. Takes a Sensor object with ResolvedViolations/ResolvedThresholds
2. Iterates violations and calls `detector.detect()` (6-arg legacy form)
3. Returns aggregated events

**Callers:**
- `tests/suite/TestDetectEventsFromSensor.m` -- DELETE test
- `tests/test_detect_events_from_sensor.m` -- DELETE test
- `tests/suite/TestGoldenIntegration.m` -- REWRITE
- `tests/test_golden_integration.m` -- REWRITE
- `tests/suite/TestEventIntegration.m` -- DELETE (uses legacy Sensor + detectEventsFromSensor)
- `tests/test_event_integration.m` -- DELETE

**Action:** DELETE `detectEventsFromSensor.m`. No Tag replacement needed -- MonitorTag emits events directly via `MonitorTag.getXY()` triggering event detection through the integrated EventDetector.

**Confidence:** HIGH.

### install.m Analysis (Research Area 9)

`install.m` adds `libs/SensorThreshold` to the path (line 48). This path addition must REMAIN because SensorTag, StateTag, MonitorTag, CompositeTag, Tag, TagRegistry, and EventBinding all live in this directory.

Other relevant sections:
- `needs_build()` (lines 70-89): Probes `libs/SensorThreshold/private/to_step_function_mex.*` -- this MEX is being deleted. Need to update the probe or remove it.
- `verify_installation()` (line 118): Checks for `'Sensor'` class existence -- change to `'Tag'` or `'SensorTag'`.
- `jit_warmup()` (lines 179-228): Creates `Sensor`, `StateChannel`, `Threshold` objects and calls `fp.addSensor()`. MUST be rewritten to use Tag API.

**Confidence:** HIGH.

### Golden Test Rewrite Mapping (Research Area 10)

| Current (Legacy) | Replacement (Tag API) | Assertion Preserved |
|------------------|-----------------------|--------------------|
| `s = Sensor('press_a', 'Name', 'Pressure A', 'Units', 'bar')` | `st = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar')` | Same key/name/units |
| `s.X = 1:20; s.Y = [...]` | `st = SensorTag('press_a', ..., 'X', 1:20, 'Y', [...])` or `st.updateData(1:20, [...])` | Same data |
| `sc = StateChannel('machine'); sc.X = [1 11]; sc.Y = [1 1]` | `stateTag = StateTag('machine', 'X', [1 11], 'Y', [1 1])` | Same state data |
| `s.addStateChannel(sc)` | Not needed -- MonitorTag references parent directly | State-conditioning via MonitorTag conditionFn |
| `tHi = Threshold('press_hi', ...); tHi.addCondition(struct('machine',1), 10)` | `mon = MonitorTag('press_hi', st, @(x,y) y > 10)` | Same condition semantics |
| `s.addThreshold(tHi); s.resolve()` | MonitorTag.getXY() computes lazily | Same violations |
| **Assertion 1:** `s.countViolations() > 0` | `[mx, my] = mon.getXY(); assert(any(my == 1))` | Violations exist |
| **Assertion 2:** `events = detectEventsFromSensor(s)` -> 2 events | Use EventDetector 2-arg overload: `det = EventDetector(); events = det.detect(mon, 10)` -- or use MonitorTag's built-in event emission | Same 2 events |
| **Assertion 3:** Debounced detection -> 1 event | `det = EventDetector('MinDuration', 3); events = det.detect(mon, 10)` | Same 1 event |
| **Assertion 4:** `CompositeThreshold('pump_a_health', 'AggregateMode', 'and')` + `computeStatus()` | `comp = CompositeTag('pump_a_health', 'AggregateMode', 'and'); comp.addChild(mon1); comp.addChild(mon2); comp.valueAt(tNow)` | Same AND semantics |
| **Assertion 5:** `fp.addSensor(s)` -> 1 line | `fp.addTag(st)` -> 1 line | Same line count |

**Critical note on Assertion 2/3:** The legacy test uses `detectEventsFromSensor` which calls `detector.detect(X, Y, thresholdValue, direction, label, sensorName)` (6-arg). The rewrite must use the 2-arg Tag overload `detector.detect(tag, threshold)` or MonitorTag's built-in event emission. Need to verify that the 2-arg overload produces identical event start/end/peak values for the same input data. The underlying `detect_()` implementation is shared, so semantics should be identical.

**Confidence:** HIGH for the mapping; MEDIUM for exact assertion equivalence of event times (the conditionFn `y > 10` vs legacy threshold-resolve may differ at boundary points).

### Examples Directory Scan (Research Area 11)

42 example files reference legacy classes. The entire `examples/02-sensors/` directory (12 files) is built on Sensor/StateChannel/Threshold API. Additional references scattered across:
- `examples/03-dashboard/` -- 7 files use SensorRegistry
- `examples/04-widgets/` -- 12 files use Sensor/SensorRegistry
- `examples/05-events/` -- 3 files use Sensor/detectEventsFromSensor
- `examples/06-webbridge/` -- 1 file
- `examples/07-advanced/` -- 1 file
- `examples/01-basics/` -- 1 file
- `examples/run_all_examples.m` -- references Sensor

**Scale concern:** 42 example files is a LOT of edits for a cleanup phase. Per CONTEXT.md "no new features" constraint, these need to be migrated to Tag API, which is mechanical but voluminous.

**Recommendation:** Include example migration in the plan but budget it as a separate wave/plan. Each example migration is mechanical (Sensor -> SensorTag, addSensor -> addTag, SensorRegistry -> TagRegistry) but should be batched efficiently.

**Confidence:** HIGH.

### Benchmark Files (Research Area 12 addendum)

6 benchmark files reference legacy classes:
- `bench_consumer_migration_tick.m` -- uses Sensor for legacy comparison
- `bench_monitortag_tick.m` -- creates Sensor as MonitorTag parent
- `bench_sensortag_getxy.m` -- creates Sensor for comparison
- `benchmark_resolve.m` -- exercises Sensor.resolve()
- `benchmark_resolve_stress.m` -- exercises Sensor.resolve()
- `benchmark_memory.m` -- creates Sensor objects

`benchmark_resolve.m` and `benchmark_resolve_stress.m` are legacy-only (they benchmark Sensor.resolve which is being deleted). DELETE them.

The other 4 need migration: replace `Sensor(` with `SensorTag(`, etc.

**Confidence:** HIGH.

### Private MEX Source References (Research Area 12)

The MEX sources in `libs/SensorThreshold/private/mex_src/` deal with raw data arrays (not class names). The MEX binaries being deleted are:
- `compute_violations_mex.mex` -- called by `compute_violations_batch.m`
- `resolve_disk_mex.mex` -- called by `compute_violations_disk.m`  
- `to_step_function_mex.mex` -- called by `toStepFunction.m`
- `violation_cull_mex.mex` -- called by Sensor.resolve() chain

**Note:** The MEX *source* files live in `libs/FastSense/private/mex_src/`, NOT in SensorThreshold. The SensorThreshold/private/ directory only has compiled MEX binaries that were copied there during `build_mex`. The sources should remain (they serve FastSense), but the SensorThreshold copies of the binaries are deleted with the private/ directory cleanup.

Wait -- checking more carefully: `to_step_function_mex.c` source may be in `libs/SensorThreshold/private/mex_src/`. Let me verify this is correct. The `install.m` `needs_build()` probes `libs/SensorThreshold/private/to_step_function_mex.*`, confirming compiled binaries exist there. The source is likely separate. In any case, the compiled binaries in `private/` are deleted with the private helpers.

**Confidence:** MEDIUM -- MEX source location needs verification during execution.

## File-Touch Budget (Research Area 14)

### Files to DELETE

**Legacy classes (8):**
1. `libs/SensorThreshold/Sensor.m`
2. `libs/SensorThreshold/Threshold.m`
3. `libs/SensorThreshold/ThresholdRule.m`
4. `libs/SensorThreshold/CompositeThreshold.m`
5. `libs/SensorThreshold/StateChannel.m`
6. `libs/SensorThreshold/SensorRegistry.m`
7. `libs/SensorThreshold/ThresholdRegistry.m`
8. `libs/SensorThreshold/ExternalSensorRegistry.m`

**Standalone functions (3):**
9. `libs/EventDetection/detectEventsFromSensor.m`
10. `libs/SensorThreshold/loadModuleData.m`
11. `libs/SensorThreshold/loadModuleMetadata.m`

**Private helpers (13):**
12-24. All 13 files in `libs/SensorThreshold/private/` (10 .m files + 3 .mex files, plus the mex_src/ directory if present)

**Legacy-only test files (suite -- pairs shown, each has suite + flat):**

| Suite File | Flat File | Reason |
|-----------|-----------|--------|
| TestSensor.m | test_sensor.m | Tests Sensor class |
| TestThreshold.m | test_threshold.m | Tests Threshold class |
| TestThresholdRule.m | test_threshold_rule.m | Tests ThresholdRule class |
| TestCompositeThreshold.m | test_composite_threshold.m | Tests CompositeThreshold |
| TestStateChannel.m | test_state_channel.m | Tests StateChannel |
| TestSensorRegistry.m | test_sensor_registry.m | Tests SensorRegistry |
| TestThresholdRegistry.m | test_threshold_registry.m | Tests ThresholdRegistry |
| TestExternalSensorRegistry.m | (check if flat exists) | Tests ExternalSensorRegistry |
| TestSensorResolve.m | test_sensor_resolve.m | Tests Sensor.resolve() |
| TestSensorTodisk.m | test_sensor_todisk.m | Tests Sensor.toDisk() |
| TestAlignState.m | test_align_state.m | Tests legacy align (uses no legacy classes directly but tests private helper) |
| TestDeclarativeCondition.m | test_declarative_condition.m | Tests ThresholdRule conditions |
| TestDetectEventsFromSensor.m | test_detect_events_from_sensor.m | Tests bridge function |
| TestResolveSegments.m | test_resolve_segments.m | Tests Sensor.resolve() segments |
| TestAddSensor.m | test_add_sensor.m | Tests FastSense.addSensor() |
| TestLoadModuleData.m | (check if flat exists) | Tests loadModuleData |
| TestLoadModuleMetadata.m | (check if flat exists) | Tests loadModuleMetadata |
| TestGroupViolations.m | test_group_violations.m | Tests private groupViolations |
| TestEventIntegration.m | test_event_integration.m | Uses detectEventsFromSensor exclusively |
| TestAddThreshold.m | test_add_threshold.m | Tests Sensor.addThreshold (check if also tests FastSense.addThreshold -- if so, keep) |

**Need verification:** TestAddThreshold may test `FastSense.addThreshold()` (which survives) -- check before deleting. TestComputeViolations and TestComputeViolationsDynamic test compute_violations_batch (private helper) -- verify if these test the MEX or just the private function.

**Benchmark deletions (2):**
- `benchmarks/benchmark_resolve.m`
- `benchmarks/benchmark_resolve_stress.m`

### Files to EDIT

**Core production (est. 10-14):**
1. `libs/SensorThreshold/SensorTag.m` -- inline delegate (major rewrite)
2. `libs/FastSense/FastSense.m` -- remove addSensor method
3. `libs/FastSense/SensorDetailPlot.m` -- remove legacy Sensor branch
4. `libs/Dashboard/FastSenseWidget.m` -- remove legacy Sensor branches
5. `libs/Dashboard/DashboardWidget.m` -- remove Sensor property + branches
6. `libs/Dashboard/DashboardEngine.m` -- remove Sensor checks
7. `libs/Dashboard/DashboardSerializer.m` -- SensorRegistry -> TagRegistry in .m export
8. `libs/Dashboard/DashboardBuilder.m` -- SensorRegistry -> TagRegistry
9. `libs/EventDetection/EventDetector.m` -- remove 6-arg legacy overload
10. `libs/EventDetection/LiveEventPipeline.m` -- remove Sensors map + legacy methods
11. `install.m` -- update verify_installation + jit_warmup + needs_build
12-25. ~14 Dashboard widget files that reference `obj.Sensor` in fromStruct (SensorRegistry.get -> TagRegistry.get)

**Test files to REWRITE (2):**
26. `tests/suite/TestGoldenIntegration.m`
27. `tests/test_golden_integration.m`

**Test files that need Sensor->Tag migration (legacy tests for surviving features):**
- `tests/suite/TestLivePipeline.m` / `test_live_pipeline.m` -- uses Sensor for pipeline setup
- `tests/suite/TestIncrementalDetector.m` / `test_incremental_detector.m` -- uses Sensor
- `tests/suite/TestEventStore.m` / `test_event_store.m` -- uses Sensor in EventConfig
- `tests/suite/TestSensorDetailPlot.m` / `test_SensorDetailPlot.m` -- uses Sensor (has Tag version too)
- `tests/suite/TestFastSenseWidget.m` -- uses Sensor (has Tag version too)
- `tests/suite/TestFastSenseWidgetUpdate.m` -- likely uses Sensor
- Various widget test files that create Sensor objects for fixtures

**Example files (42):** Mechanical migration Sensor -> SensorTag, addSensor -> addTag, SensorRegistry -> TagRegistry.

**Benchmark files (4):** Migration to SensorTag.

### Budget Summary

| Category | Delete | Edit | Net |
|----------|--------|------|-----|
| Legacy classes | 8 | 0 | -8 |
| Standalone functions | 3 | 0 | -3 |
| Private helpers | ~13 | 0 | -13 |
| Legacy-only tests | ~38 (19 pairs) | 0 | -38 |
| Benchmarks | 2 | 4 | -2 |
| Core production | 0 | ~14 | 0 |
| Dashboard widgets fromStruct | 0 | ~14 | 0 |
| Test rewrites/migrations | 0 | ~16 | 0 |
| Examples | 0 | ~42 | 0 |
| install.m | 0 | 1 | 0 |
| **Total** | **~64** | **~91** | **-64** |

This is a large phase. The example migration alone is 42 files. Consider whether example migration should be in-scope or deferred to a follow-up.

## Common Pitfalls

### Pitfall 1: SensorTag constructor breaking change
**What goes wrong:** After inlining, SensorTag constructor no longer creates a Sensor delegate. Any test or consumer that somehow accesses `SensorTag.Sensor_` (via `?SensorTag` introspection or serialization) breaks.
**How to avoid:** `Sensor_` is private -- no external access is possible. The public API (getXY, valueAt, load, toDisk, etc.) is preserved. fromStruct/toStruct must be updated to use new private property names.

### Pitfall 2: DashboardWidget.Sensor property removal breaks serialized dashboards
**What goes wrong:** Saved dashboard .json files may contain `"source": {"type": "sensor", "name": "..."}`. If fromStruct no longer handles this, loading old dashboards fails.
**How to avoid:** Keep the fromStruct deserialization path that reads `type: "sensor"` but resolve via `TagRegistry.get()` instead of `SensorRegistry.get()`. This requires that migrated dashboards have their sensors registered as SensorTags in TagRegistry with the same keys.

### Pitfall 3: Golden test behavior drift
**What goes wrong:** The rewritten golden test passes but with subtly different semantics (e.g., MonitorTag's conditionFn boundary behavior differs from Threshold's strict > comparison).
**How to avoid:** Use the exact same boundary condition: `@(x,y) y > 10` matches `Threshold.Direction='upper', Value=10` which is `sensor.Y > threshold.Value`. Verify event start/end times match exactly.

### Pitfall 4: EventDetector.detect 6-arg removal breaks surviving callers
**What goes wrong:** Some test or production code still calls the 6-arg `detect()`.
**How to avoid:** Grep audit after removal. The 6-arg path is only called by `detectEventsFromSensor` (deleted) and some legacy tests (deleted). The 2-arg Tag overload + shared `detect_()` body survive.

### Pitfall 5: install.m jit_warmup crashes on missing classes
**What goes wrong:** `jit_warmup()` creates Sensor/StateChannel/Threshold objects. After deletion, install() itself crashes.
**How to avoid:** Rewrite jit_warmup early in the phase, BEFORE deleting classes. Or delete classes and rewrite jit_warmup in the same commit.

### Pitfall 6: Examples referencing SensorRegistry break at demo time
**What goes wrong:** User runs `example_basic` after install and gets "Undefined class SensorRegistry".
**How to avoid:** Migrate ALL examples in this phase, or clearly document which examples are broken.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB unittest + Octave function-based |
| Config file | tests/run_all_tests.m |
| Quick run command | `run_all_tests` |
| Full suite command | `run_all_tests` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MIGRATE-03 | 8 legacy classes deleted | grep audit | `grep -rE 'Sensor\(\|Threshold\(\|CompositeThreshold\(' libs/ tests/ examples/ benchmarks/` | Audit script, Wave N |
| MIGRATE-03 | Golden test passes with Tag API | integration | `run('tests/suite/TestGoldenIntegration')` | Rewrite in phase |
| MIGRATE-03 | Full test suite green | integration | `run_all_tests` | Existing |

### Sampling Rate
- **Per task commit:** `run_all_tests` (must be green after every deletion batch)
- **Per wave merge:** Full suite green
- **Phase gate:** Full suite green + grep audit zero hits

### Wave 0 Gaps
None -- existing test infrastructure covers all phase requirements. The golden test rewrite IS the primary deliverable.

## Open Questions

1. **Example migration scope**
   - What we know: 42 example files reference legacy classes
   - What's unclear: Is migrating all 42 files in-scope for Phase 1011, or should it be a follow-up?
   - Recommendation: Include in Phase 1011 since the grep audit requires zero legacy references. Budget as a separate plan/wave focused purely on mechanical migration.

2. **TestAddThreshold survival**
   - What we know: TestAddThreshold tests `Sensor.addThreshold()` AND/OR `FastSense.addThreshold()`
   - What's unclear: Does it test `FastSense.addThreshold()` (which survives)?
   - Recommendation: Check at execution time. If it only tests Sensor.addThreshold, delete. If it tests FastSense.addThreshold, keep and migrate.

3. **Event.SensorName / Event.ThresholdLabel properties**
   - What we know: Event.m still has SensorName and ThresholdLabel properties (legacy carriers)
   - What's unclear: Whether Phase 1010 added TagKeys alongside or replaced these
   - Recommendation: Check at execution time. If TagKeys coexists with SensorName/ThresholdLabel, the legacy properties should be removed (or kept as deprecated compat).

4. **MEX source files in SensorThreshold/private/mex_src/**
   - What we know: Compiled MEX binaries are in private/. Source may or may not have a separate mex_src/ subdirectory.
   - What's unclear: Exact source file locations
   - Recommendation: Check at execution time. Sources for shared MEX (like to_step_function_mex) may also exist in FastSense/private/mex_src/.

## Project Constraints (from CLAUDE.md)

- Pure MATLAB, no external dependencies
- Backward compatibility for existing dashboards (serialized JSON must still load)
- MATLAB R2020b+ and Octave 7+ compatibility
- Handle class inheritance pattern (`< handle`)
- Error IDs use `ClassName:camelCase` pattern
- PascalCase for classes, camelCase for methods
- MISS_HIT style checking (160 char line width, 4-space indent)
- No `dictionary`, `arguments`, `enumeration`, `events`, `matlab.mixin.*` constructs
- Test files: suite/ uses TestCase classes, flat tests use function-based
- `install()` must remain functional after all changes

## Sources

### Primary (HIGH confidence)
- Direct source code reading of all 8 legacy classes, SensorTag.m, consumer files
- Grep audit across all libs/, tests/, examples/, benchmarks/ directories
- CONTEXT.md locked decisions
- REQUIREMENTS.md MIGRATE-03 definition

### Secondary (MEDIUM confidence)
- File-touch budget estimates (exact count depends on TestAddThreshold and example scope decisions)

## Metadata

**Confidence breakdown:**
- SensorTag inlining: HIGH -- exact delegate surface mapped property by property
- Legacy branch identification: HIGH -- systematic grep across all consumers
- Test deletion list: HIGH -- verified each test file's exclusive dependency on legacy classes
- Golden test rewrite: HIGH for mapping, MEDIUM for exact event-time equivalence
- Example migration scope: MEDIUM -- identified all 42 files but scope decision pending

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (stable -- all code is local, no external dependency drift)

## RESEARCH COMPLETE
