# Phase 1003: Composite Thresholds - Context

**Gathered:** 2026-04-06
**Status:** Ready for planning

<domain>
## Phase Boundary

CompositeThreshold class that aggregates child Threshold objects for hierarchical status monitoring. A composite is green only when all children are green (configurable AND/OR/MAJORITY logic). Enables system health trees where "Component A" aggregates "A.A" and "A.B" sub-component status. Composites can nest (tree structure) and integrate with existing widgets.

</domain>

<decisions>
## Implementation Decisions

### Aggregation model
- **D-01:** CompositeThreshold inherits from Threshold — usable anywhere a Threshold is accepted (widgets, sensors, registry)
- **D-02:** Default aggregation logic is AND (all children must be ok). Configurable via `AggregateMode` property: 'and', 'or', 'majority'
- **D-03:** Composites can nest — tree structure where children can be Threshold or CompositeThreshold objects
- **D-04:** `computeStatus(values)` method evaluates each child's current value against its limits, returns aggregate ok/warning/alarm

### Child management
- **D-05:** `addChild(thresholdOrKey)` method — accepts Threshold objects or registry key strings (same dual-input as Sensor.addThreshold)
- **D-06:** Each child carries its own current value via ValueFcn or static value (from Phase 1002 widget pattern). Composite evaluates all children's values.
- **D-07:** Same Threshold can be a child of multiple composites — handle class shared references

### Widget integration
- **D-08:** MultiStatusWidget auto-expands CompositeThresholds — shows each child as a status dot in the grid plus a summary row for the composite
- **D-09:** CompositeThreshold registered in ThresholdRegistry like any Threshold (same registry, same API)

### Claude's Discretion
- Internal representation of child list (cell array, containers.Map, etc.)
- How computeStatus traverses the tree for nested composites
- removeChild API (if needed)
- StatusWidget/GaugeWidget behavior when bound to a CompositeThreshold
- Serialization format for composite structure in JSON

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Threshold system (Phases 1001-1002)
- `libs/SensorThreshold/Threshold.m` — Base class to inherit from; handle class with Key, Name, conditions_, allValues()
- `libs/SensorThreshold/ThresholdRegistry.m` — Registry that must accept CompositeThreshold
- `libs/Dashboard/StatusWidget.m` — Phase 1002 Threshold binding (deriveStatusFromThreshold)
- `libs/Dashboard/MultiStatusWidget.m` — Phase 1002 struct-based threshold items, needs composite expansion

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `Threshold.m` — Base class with all entity properties, handle class pattern
- Phase 1002 widget integration — `deriveStatusFromThreshold()` pattern works for composites
- ThresholdRegistry — accepts any Threshold subclass without modification

### Established Patterns
- Handle class inheritance (`classdef X < handle`)
- Dual input (object or string key) for addChild, matching addThreshold pattern
- TDD approach with both suite tests (TestX.m) and Octave function tests (test_x.m)

### Integration Points
- CompositeThreshold.computeStatus() — new method that widgets call to get aggregate status
- MultiStatusWidget.refresh() — needs composite expansion logic
- Serialization — CompositeThreshold.toStruct/fromStruct with children array

</code_context>

<specifics>
## Specific Ideas

- "Combine threshold objects together to new ones, threshold nesting to show status of components"
- "Component A is green because it consists of A.A and A.B and both are green"
- TrendMiner-style hierarchical monitoring for system health dashboards

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 1003-composite-thresholds*
*Context gathered: 2026-04-06*
