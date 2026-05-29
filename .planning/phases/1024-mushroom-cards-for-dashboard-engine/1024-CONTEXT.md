# Phase 999.1: Mushroom Cards for Dashboard Engine - Context

**Gathered:** 2026-04-05
**Status:** Ready for planning

<domain>
## Phase Boundary

Add three new Mushroom Card-style widget classes to the dashboard engine: IconCardWidget (icon + value + state color), ChipBarWidget (horizontal row of mini status chips), and SparklineCardWidget (value + inline sparkline + delta). Plus theme additions (InfoColor) and DashboardBuilder/Serializer integration. All implemented in pure MATLAB, subclassing DashboardWidget, compatible with MATLAB R2020b+ and Octave 7+.

</domain>

<decisions>
## Implementation Decisions

### Widget Visual Design
- State indicated via icon color only (no accent bar or background tint by default) — matches existing StatusWidget pattern, least visual noise
- IconCardWidget supports circle shape only — simple, matches StatusWidget, covers 90% of use cases
- NumberWidget remains unchanged — no icon slot or accent bar added; users wanting icon+value use IconCardWidget instead
- SparklineCardWidget delta shows numeric value with arrow (e.g., "+1.2 ▲") — most info-dense format, validated by Streamlit and Grafana patterns

### ChipBarWidget Architecture
- New ChipBarWidget class (not extending MultiStatusWidget) — single responsibility, preserves MultiStatusWidget's existing vertical layout
- Chips defined via cell array of structs with `sensor` or `statusFcn` fields — consistent with existing sensor-binding pattern across all dashboard widgets
- Chip count immutable after render() — avoids handle lifecycle complexity; Chips property must be set before render()
- Single shared axes for all chips — fewer graphics objects, better performance with many chips

### Theme & Serialization Integration
- Add `InfoColor` = `[0.27 0.52 0.85]` (blue) to all 6 DashboardTheme presets — fills gap for active/non-alarm state indication
- Serialization type strings: `'iconcard'`, `'chipbar'`, `'sparkline'` — lowercase, consistent with existing type strings
- DashboardBuilder gets `addIconCard()`, `addChipBar()`, `addSparkline()` convenience methods — consistent with existing `addNumber()`, `addStatus()` etc.
- One TestXxxWidget.m per new class + extend TestDashboardSerializer — follows existing test organization pattern

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `StatusWidget.m` — icon circle drawing pattern (fill + theta), adaptive font sizing
- `GaugeWidget.m` — axes setup for non-interactive drawing, fill patterns
- `NumberWidget.m` — three-path data binding (Sensor/ValueFcn/StaticValue), trend computation, toStruct/fromStruct pattern
- `DashboardWidget.m` — base class with render/refresh/getType/toStruct/fromStruct contract
- `DashboardTheme.m` — 6 presets with StatusOkColor/StatusWarnColor/StatusAlarmColor
- `DashboardBuilder.m` — addNumber/addStatus/addGauge convenience methods
- `DashboardSerializer.m` — fromStruct type dispatch switch, loadJSON/saveJSON

### Established Patterns
- Icon circles: `fill(hAx, cos(theta), sin(theta), color, 'EdgeColor', 'none')`
- Axes guard: `try set(hAx, 'PickableParts', 'none'); catch, end` + `try disableDefaultInteractivity(hAx); catch, end`
- Refresh guard: `if isempty(obj.hPanel) || ~ishandle(obj.hPanel), return; end`
- Adaptive font: `max(7, min(14, round(pH * 0.28)))`
- Theme access: `theme = obj.getTheme()` (protected method on DashboardWidget)

### Integration Points
- `DashboardSerializer.fromStruct()` — add 3 new cases to type dispatch switch
- `DashboardBuilder.m` — add 3 new convenience methods
- `DashboardTheme.m` — add InfoColor field to all 6 presets
- `DetachedMirror.cloneWidget()` — add 3 new cases to the 15-type dispatch switch
- `tests/suite/TestDashboardSerializer.m` — extend with new type round-trip tests
- `tests/suite/TestDashboardTheme.m` — assert new theme fields present

</code_context>

<specifics>
## Specific Ideas

- Inspired by Home Assistant Mushroom Cards — compact, icon-first, state-colored card language
- ChipBarWidget serves as "system health bar" — horizontal strip at top of dashboard section
- SparklineCardWidget combines Streamlit st.metric delta pattern with inline mini-chart
- Research validated 3 archetypes cover 80% of Mushroom Cards visual language

</specifics>

<deferred>
## Deferred Ideas

- State timeline widget (horizontal colored bar per sensor over time) — separate phase
- Left-border accent pattern (Apple Health style) — could be added later as optional property
- Dynamic chip add/remove at runtime — future enhancement if needed
- Square/diamond icon shapes — can be added later if circle proves insufficient

</deferred>
