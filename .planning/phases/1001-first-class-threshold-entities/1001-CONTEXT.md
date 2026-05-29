# Phase 1001: First-Class Threshold Entities - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Make thresholds independent, reusable entities with their own registry, identity, and lifecycle — TrendMiner-style. A Threshold is a named limit concept (e.g., "Temperature High-High") that can be defined once and shared across multiple sensors. This is a breaking change to the SensorThreshold library; existing addThresholdRule API and ThresholdRules property are removed.

</domain>

<decisions>
## Implementation Decisions

### Entity model
- **D-01:** New `Threshold` class (handle class, like Sensor) — NOT an upgrade of ThresholdRule
- **D-02:** TrendMiner-style: a Threshold is a named limit concept that owns state-dependent condition-value pairs. Direction, Color, LineStyle live on the Threshold, not per-condition
- **D-03:** Threshold properties: Key, Name, Direction, Color, LineStyle, Units, Description, Tags (cell array of strings for filtering/grouping)
- **D-04:** Conditions use the existing StateChannel struct-matching mechanism: `t.addCondition(struct('machine', 1), 80)`
- **D-05:** Handle class — changes to a Threshold propagate to all sensors referencing it

### Registry & sharing
- **D-06:** `ThresholdRegistry` mirrors `SensorRegistry` exactly — static methods, persistent `containers.Map`, singleton pattern
- **D-07:** API: `get(key)`, `register(key, t)`, `unregister(key)`, `list()`, `printTable()`, `viewer()`
- **D-08:** Query methods: `findByTag(tag)`, `findByDirection('upper'/'lower')` for discovery
- **D-09:** No predefined catalog — registry starts empty, users populate at runtime
- **D-10:** `getMultiple(keys)` for batch retrieval (mirrors SensorRegistry)

### Sensor integration
- **D-11:** Breaking change: `addThresholdRule` removed entirely, `ThresholdRules` property replaced with `Thresholds`
- **D-12:** `Sensor.addThreshold()` accepts both Threshold objects and registry key strings (dual input, key auto-resolves via ThresholdRegistry)
- **D-13:** Duplicate rejection by Key — addThreshold skips/warns if same Key already attached
- **D-14:** `Sensor.removeThreshold(key)` detaches threshold from sensor (Threshold stays in registry)
- **D-15:** `Sensor.Thresholds` is a cell array of Threshold handle references

### Resolve & eval
- **D-16:** Conditions use existing StateChannel mechanism (struct-based condition matching) — no changes to condition evaluation logic
- **D-17:** Existing `Sensor.resolve()` internals adapted to iterate `Thresholds` instead of `ThresholdRules`

### Claude's Discretion
- Internal representation of conditions within Threshold (keep ThresholdRule as internal class, replace with struct array, or other — whatever makes resolve() cleanest)
- Resolve architecture: whether results stay on Sensor (current pattern) or move — Claude picks based on integration with FastSense, EventDetection, and Dashboard consumers
- Migration of existing code: SensorRegistry.catalog() predefined sensors, EventDetection, Dashboard widgets — all reference points that use ThresholdRule need updating

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### SensorThreshold library (primary target)
- `libs/SensorThreshold/Sensor.m` — Core sensor class with addThresholdRule, resolve(), ThresholdRules property (all being replaced)
- `libs/SensorThreshold/ThresholdRule.m` — Current threshold value class (being superseded by Threshold)
- `libs/SensorThreshold/SensorRegistry.m` — Registry pattern to mirror for ThresholdRegistry
- `libs/SensorThreshold/StateChannel.m` — State channel system (kept, used by new Threshold conditions)

### Downstream consumers (must be updated)
- `libs/Dashboard/FastSenseWidget.m` — References ThresholdRule via Sensor
- `libs/Dashboard/StatusWidget.m` — Reads threshold data from Sensor
- `libs/Dashboard/GaugeWidget.m` — Reads threshold data from Sensor
- `libs/Dashboard/MultiStatusWidget.m` — Reads threshold data from Sensor
- `libs/Dashboard/ChipBarWidget.m` — References ThresholdRule
- `libs/Dashboard/IconCardWidget.m` — References ThresholdRule
- `libs/EventDetection/EventViewer.m` — Uses ThresholdRules for event display
- `libs/EventDetection/IncrementalEventDetector.m` — Evaluates thresholds
- `libs/EventDetection/LiveEventPipeline.m` — Live threshold evaluation

### Private helpers (may need updates)
- `libs/SensorThreshold/private/` — MEX helpers for threshold evaluation (compute_violations_mex, etc.)

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `SensorRegistry.m`: Exact pattern to mirror for ThresholdRegistry (static methods, persistent containers.Map, get/register/unregister/list/printTable/viewer)
- `StateChannel.m`: Condition evaluation system reused directly by new Threshold class
- MEX kernels (`compute_violations_mex`, `violation_cull_mex`): Performance-critical evaluation stays the same, just called with Threshold data instead of ThresholdRule data

### Established Patterns
- Handle class with Key property for identity (Sensor pattern)
- Singleton registry with persistent variable (SensorRegistry pattern)
- Constructor with key + name-value options (Sensor, ThresholdRule, StateChannel all use this)
- Namespaced error IDs: `'ClassName:camelCaseProblem'`

### Integration Points
- `Sensor.resolve()` — main evaluation entry point, must be refactored from ThresholdRules to Thresholds
- `Sensor.addThreshold()` — new method replacing addThresholdRule
- Dashboard widgets — access thresholds via Sensor.Thresholds instead of Sensor.ThresholdRules
- EventDetection — threshold evaluation via Sensor objects
- `DashboardSerializer` — serialization of Threshold references (by key) in saved dashboards
- All test files referencing addThresholdRule or ThresholdRule

</code_context>

<specifics>
## Specific Ideas

- "Like TrendMiner" — thresholds as first-class entities, not just properties of sensors
- Complete revamp of the threshold system — breaking changes accepted, no deprecation path
- A threshold like "Temperature > 80°C" defined once and shared across 5 temperature sensors

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1001-first-class-threshold-entities*
*Context gathered: 2026-04-05*
