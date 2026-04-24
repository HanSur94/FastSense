# Phase 1002: Direct Widget-Threshold Binding - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

StatusWidget, GaugeWidget, MultiStatusWidget, ChipBarWidget, and IconCardWidget can reference Threshold objects directly without requiring a Sensor. Enables standalone threshold-driven status indicators where a Value/ValueFcn provides the current reading and the Threshold defines the limits.

</domain>

<decisions>
## Implementation Decisions

### Widget input model
- **D-01:** New `Threshold` property on each supported widget alongside existing `Sensor` property
- **D-02:** Widget checks Threshold first, falls back to Sensor path (additive, not replacing)
- **D-03:** Current value comes from new `Value` property (manual) or `ValueFcn` callback (live)
- **D-04:** Supported widgets: StatusWidget, GaugeWidget, MultiStatusWidget, ChipBarWidget, IconCardWidget
- **D-05:** StatusWidget derives ok/warning/alarm from Value + Threshold conditions using the same logic as the Sensor path but with a different value source

### API design
- **D-06:** Constructor syntax: `StatusWidget('Threshold', t, 'Value', 42)` or `StatusWidget('Threshold', 'temp_hh', 'ValueFcn', @() readTemp())`
- **D-07:** Threshold property accepts both Threshold objects and registry key strings (like Sensor.addThreshold)
- **D-08:** Sensor and standalone Threshold are mutually exclusive on a widget — setting one clears the other
- **D-09:** ValueFcn is called on each DashboardEngine live tick via widget.refresh()

### Serialization & backward compat
- **D-10:** Threshold-only widgets serialize threshold key in JSON: `"threshold": "temp_hh"`
- **D-11:** On load, threshold resolved from ThresholdRegistry
- **D-12:** Zero changes to existing Sensor-bound widget behavior — Threshold binding is purely additive

### Claude's Discretion
- Internal implementation of the dual Sensor/Threshold path in each widget
- How ValueFcn integrates with existing refresh() lifecycle
- Error handling for missing ThresholdRegistry keys on load
- DashboardBuilder convenience methods (if any)

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Widget classes (primary targets)
- `libs/Dashboard/StatusWidget.m` — Current Sensor-based status derivation, deriveStatusFromSensor
- `libs/Dashboard/GaugeWidget.m` — Current Sensor-based gauge rendering, deriveRange
- `libs/Dashboard/MultiStatusWidget.m` — Multi-sensor status grid
- `libs/Dashboard/ChipBarWidget.m` — Chip bar with threshold coloring
- `libs/Dashboard/IconCardWidget.m` — Icon card with threshold status

### Threshold system (Phase 1001)
- `libs/SensorThreshold/Threshold.m` — Handle class with allValues(), IsUpper, conditions_
- `libs/SensorThreshold/ThresholdRegistry.m` — Singleton registry with get(), findByTag()

### Serialization
- `libs/Dashboard/DashboardSerializer.m` — JSON save/load, widget dispatch
- `libs/Dashboard/DashboardEngine.m` — realizeWidget(), refresh lifecycle

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Threshold.allValues()` — returns all condition values for range derivation in GaugeWidget
- `Threshold.IsUpper` — cached direction for status comparison
- `ThresholdRegistry.get(key)` — string-based resolution pattern already used by Sensor.addThreshold
- Existing `ValueFcn` pattern on IconCardWidget/SparklineCardWidget — callback-driven value updates

### Established Patterns
- Widget constructor: name-value pairs via varargin, parsed with parseOpts or manual extraction
- DashboardWidget.Sensor property: set in constructor, used in render/refresh
- realizeWidget() in DashboardEngine: central injection point for new widget types
- toStruct/fromStruct for serialization round-trip

### Integration Points
- Each widget's render() and refresh() methods need a Threshold-only code path
- DashboardSerializer.loadJSON must resolve threshold keys from ThresholdRegistry
- DashboardEngine refresh timer calls widget.refresh() — ValueFcn evaluated there

</code_context>

<specifics>
## Specific Ideas

- "Attach thresholds to status widgets directly" — user wants sensor-less monitoring
- Use case: standalone threshold indicators for system component health
- Foundation for Phase 1003 (Composite Thresholds) which builds hierarchical status trees

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1002-direct-widget-threshold-binding*
*Context gathered: 2026-04-06*
