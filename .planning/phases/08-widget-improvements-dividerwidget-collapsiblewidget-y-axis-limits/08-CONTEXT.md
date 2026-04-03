# Phase 8: Widget Improvements — DividerWidget, CollapsibleWidget, Y-Axis Limits - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Three widget improvements for the dashboard engine:
1. **DividerWidget** — a new widget type that renders a horizontal divider line for visual separation of dashboard sections
2. **CollapsibleWidget convenience API** — a DashboardBuilder shorthand for GroupWidget's existing collapsible mode (built in Phase 2)
3. **Y-axis limits** — configurable min/max Y-axis range for FastSenseWidget chart widgets

</domain>

<decisions>
## Implementation Decisions

### DividerWidget Design
- Horizontal line (1px solid, theme-colored) as visual style
- Configurable properties: Thickness (line width) and Color override only — minimal config
- Occupies a full grid row (height=1) — consistent with 24-column grid system
- Horizontal orientation only — dashboards flow top-to-bottom

### CollapsibleWidget Behavior
- Reuse existing GroupWidget with Mode='collapsible' — already built in Phase 2 with reflow, serialization, theming
- Add DashboardEngine convenience method: addCollapsible(label, children) that creates GroupWidget with Mode='collapsible' (DashboardEngine owns the programmatic API; DashboardBuilder is the GUI overlay)
- No new collapse features needed — existing collapse/expand + reflow + serialization is sufficient
- Default collapsed state configurable via existing Collapsed property on GroupWidget

### Y-Axis Limits Configuration
- FastSenseWidget only — primary chart widget with Y axis; other chart widgets can follow later
- Property: YLimits = [] on FastSenseWidget — empty means auto, [min max] sets fixed range
- Serialized via toStruct/fromStruct — limits are part of dashboard config
- Reapplied during refresh() to keep fixed range stable across data updates

### Claude's Discretion
- DividerWidget render implementation details (line rendering via axes or uipanel)
- Exact DashboardBuilder convenience method signature
- Test structure and coverage scope
- DashboardSerializer type dispatch for DividerWidget

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardWidget.m` — abstract base class with toStruct/fromStruct, render/refresh/getType contract
- `GroupWidget.m` — already has Mode='collapsible' with collapse()/expand(), ReflowCallback, Collapsed property
- `DashboardBuilder.m` — builder pattern with addWidget(), addGroup() methods
- `DashboardSerializer.m` — type-based dispatch for JSON/script serialization
- `DashboardLayout.m` — 24-column grid with realizeWidget() for panel creation
- `DashboardTheme.m` — 6 presets with WidgetBorder, WidgetBg, TextColor for consistent styling

### Established Patterns
- Widget creation: subclass DashboardWidget, implement render/refresh/getType/fromStruct
- Serialization: toStruct() returns type+properties struct, fromStruct(s) reconstructs from struct
- Builder: addWidget() is the central method; convenience methods call it internally
- Theme: widgets read ParentTheme for colors during render()
- DetachedMirror: cloneWidget() has 15-type dispatch switch — new widget types must be added

### Integration Points
- DashboardSerializer type dispatch (loadJSON type→class mapping)
- DashboardBuilder convenience methods
- DetachedMirror.cloneWidget() type switch
- DashboardLayout.realizeWidget() — no changes needed (generic)

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches following existing widget patterns.

</specifics>

<deferred>
## Deferred Ideas

- Y-axis limits for other chart widgets (BarChartWidget, HistogramWidget, ScatterWidget, HeatmapWidget) — future phase
- Vertical divider orientation — future if needed

</deferred>
