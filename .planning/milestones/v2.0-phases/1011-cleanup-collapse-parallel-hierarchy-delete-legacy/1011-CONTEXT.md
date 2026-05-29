# Phase 1011: Cleanup — collapse parallel hierarchy + delete legacy - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning
**Mode:** Auto-generated (cleanup phase — deletion + migration of golden test + zero-reference audit)

<domain>
## Phase Boundary

Delete the 8 legacy classes, fold remaining adapter shims, rewrite the golden integration test to use the new Tag API (`addSensor` → `addTag`), and ship a unified Tag-only domain model with a green test suite.

**In scope:**
- DELETE 8 legacy classes from `libs/SensorThreshold/`:
  - `Sensor.m`, `Threshold.m`, `ThresholdRule.m`, `CompositeThreshold.m`
  - `StateChannel.m`, `SensorRegistry.m`, `ThresholdRegistry.m`, `ExternalSensorRegistry.m`
- DELETE legacy test files that exclusively test deleted classes (e.g., TestSensor.m, TestThreshold.m, TestCompositeThreshold.m, test_sensor.m, test_threshold.m, test_composite_threshold.m, etc.)
- REWRITE golden integration test (`TestGoldenIntegration.m` + `test_golden_integration.m`) to use Tag API:
  - `addSensor` → `addTag`; `Sensor` → `SensorTag`; `Threshold` → construct MonitorTag with condition
  - `CompositeThreshold` → `CompositeTag` with AND mode
  - Preserve ALL assertion semantics — if a behavior changes, it's a BUG to investigate, not a test to fix
- REMOVE legacy references from production code:
  - SensorTag composition delegate (`Sensor_` property) — inline the data if possible, or keep delegate as private impl detail
  - FastSenseWidget legacy `Sensor` dispatch branch — remove, leave only Tag path
  - SensorDetailPlot legacy `Sensor` branch
  - EventDetector legacy `Sensor` overload
  - LiveEventPipeline legacy `Sensors` map paths
  - DashboardEngine any remaining Sensor-specific logic
  - Remove `addSensor()` from FastSense.m (redirect to `addTag` via a deprecation error OR just delete)
- GREP AUDIT: `grep -rE 'Sensor\(|Threshold\(|CompositeThreshold\(|StateChannel\(|SensorRegistry\.|ThresholdRegistry\.|ExternalSensorRegistry\.' libs/ tests/ examples/ benchmarks/` → ZERO hits in production code
- Update `install.m` if it references paths to deleted files
- Update `private/` directory: remove any helpers only used by deleted classes

**Out of scope:**
- No new features (Pitfall 12 — feature creep forbidden under cleanup)
- No new REQ-IDs beyond MIGRATE-03
- No new capabilities

**Verification gates:**
- Pitfall 5: This is the ONE phase where deletions are ALLOWED
- Pitfall 11: Golden test REWRITE preserves assertion semantics; behavior changes = bugs to investigate
- Pitfall 12: No D/F/G features introduced under cleanup guise

</domain>

<decisions>
## Implementation Decisions

### Deletion Order
1. First: Delete legacy test files (reduces noise in grep audit)
2. Then: Delete legacy classes (the 8 files)
3. Then: Remove legacy branches in consumers (FastSenseWidget, SensorDetailPlot, EventDetector, LiveEventPipeline, DashboardEngine)
4. Then: Rewrite golden integration test
5. Then: Grep audit + clean remaining private/ helpers
6. Finally: Update install.m paths

### SensorTag Composition Delegate
- `SensorTag` currently HAS-A `Sensor_` private delegate. After `Sensor.m` is deleted, `SensorTag` must either:
  - **Option A:** Inline the data storage (X, Y properties directly on SensorTag instead of delegating to Sensor). This breaks the composition — but Sensor is gone, so there's nothing to compose.
  - **Option B:** Keep a stripped-down private data-holder in SensorTag (embed minimal X/Y + DataStore logic directly).
  - **Decision:** Research must determine which is cleaner given the existing code. The `load()`, `toDisk()`, `toMemory()` methods delegate to Sensor — they need to be reimplemented on SensorTag directly.

### FastSense.addSensor Removal
- Currently `FastSense.addSensor(sensor, ...)` exists alongside `addTag`. After cleanup:
  - **Option A:** Delete `addSensor` entirely — callers must use `addTag`.
  - **Option B:** Make `addSensor` a thin wrapper that constructs a SensorTag and calls `addTag`.
  - **Decision:** Option A is cleaner (full cut). Any remaining callers are bugs to find in the grep audit.

### Golden Integration Test Rewrite
- MUST preserve ALL assertion semantics. The test currently exercises:
  - Sensor construction + data loading
  - Threshold condition evaluation
  - CompositeThreshold AND-mode
  - EventDetector run → violation count + event times
  - FastSense rendering
- Rewrite equivalences:
  - `Sensor(key)` → `SensorTag(key)`
  - `Threshold(key, ...)` → `MonitorTag(key, sensorTag, conditionFn, ...)`
  - `CompositeThreshold(key, 'and')` → `CompositeTag(key, 'and')`
  - `detectEventsFromSensor(sensor, threshold)` → `monitor.getXY()` + check events in EventStore
  - `FastSense.addSensor(sensor)` → `FastSense.addTag(sensorTag)`
- Same fixture data (synthetic sinusoid, same threshold values, same expected violation count)

### Private Helpers Cleanup
- Scan `libs/SensorThreshold/private/` for functions only referenced by deleted classes
- `compute_violations.m`, `groupViolations.m`, `parseOpts.m` — check if still used by remaining code
- Delete any helper with zero remaining callers

### Error IDs
- No new error IDs in this phase — only deletions + rewrites

### Claude's Discretion
- Exact SensorTag data-inlining approach (depends on current delegate wiring)
- Which private/ helpers to keep vs delete (depends on grep results)
- Whether to keep backward-compat deprecation stubs for `addSensor`/`SensorRegistry.get` (Claude should NOT — per "full cut" decision, unless research reveals external callers)
- Exact order of test file deletions

</decisions>

<code_context>
## Existing Code Insights

### Files to DELETE (8 legacy classes)
- libs/SensorThreshold/Sensor.m
- libs/SensorThreshold/Threshold.m
- libs/SensorThreshold/ThresholdRule.m
- libs/SensorThreshold/CompositeThreshold.m
- libs/SensorThreshold/StateChannel.m
- libs/SensorThreshold/SensorRegistry.m
- libs/SensorThreshold/ThresholdRegistry.m
- libs/SensorThreshold/ExternalSensorRegistry.m

### Files to DELETE (legacy test files — verify full list during research)
- tests/suite/TestSensor.m
- tests/suite/TestThreshold.m (if exists)
- tests/suite/TestCompositeThreshold.m
- tests/test_sensor.m
- tests/test_threshold.m (if exists)
- tests/test_composite_threshold.m
- tests/test_add_sensor.m
- tests/test_add_threshold.m
- tests/test_align_state.m
- tests/test_declarative_condition.m (if only used by Threshold)
- tests/test_state_channel.m (if exists)
- Any other test exclusively exercising deleted classes

### Files to EDIT (remove legacy branches)
- libs/Dashboard/FastSenseWidget.m (remove Sensor dispatch, leave Tag-only)
- libs/FastSense/SensorDetailPlot.m (remove legacy Sensor branch)
- libs/FastSense/FastSense.m (remove addSensor method)
- libs/EventDetection/EventDetector.m (remove legacy Sensor overload)
- libs/EventDetection/LiveEventPipeline.m (remove legacy Sensors map paths)
- libs/Dashboard/DashboardEngine.m (remove Sensor-specific tick logic if any remains)
- libs/SensorThreshold/SensorTag.m (inline data storage after Sensor.m deletion)
- tests/suite/TestGoldenIntegration.m (REWRITE to Tag API)
- tests/test_golden_integration.m (REWRITE to Tag API)
- install.m (update path references if needed)

</code_context>

<specifics>
## Specific Ideas

- Before deleting Sensor.m, grep for ALL callers: `grep -rn "Sensor(" libs/ tests/ examples/ benchmarks/ --include="*.m" | grep -v SensorTag | grep -v SensorDetail | grep -v "SensorRegistry"` — each caller must be migrated or deleted
- SensorTag data inlining: move X_, Y_, DataStore_ from Sensor delegate directly into SensorTag properties. Forward-port `load()`, `toDisk()`, `toMemory()`, `isOnDisk()` to operate on these directly (no delegate).
- Run `tests/run_all_tests.m` after EVERY deletion to catch breakages immediately
- The golden test rewrite is the crown jewel of this phase — it proves the v2.0 migration is semantically complete

</specifics>

<deferred>
## Deferred Ideas

None — this is the final cleanup phase of v2.0.

</deferred>
