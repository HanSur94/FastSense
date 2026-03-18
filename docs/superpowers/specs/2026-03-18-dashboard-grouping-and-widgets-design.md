# Dashboard Grouping & New Widgets Design

## Overview

Expand the FastSense dashboard with a widget grouping system (Phase A) and six new widget types (Phase B). Phase A introduces `GroupWidget` — a container that organizes child widgets into titled panels, collapsible sections, or tabbed views. Phase B adds HeatmapWidget, BarChartWidget, HistogramWidget, ScatterWidget, ImageWidget, and MultiStatusWidget.

## Phasing

- **Phase A — GroupWidget**: Adds grouping to the layout system. Must land first since all future widgets benefit from being groupable.
- **Phase B — New Widgets**: Six new widget types built on the existing `DashboardWidget` pattern with Sensor-first data binding.

---

## Phase A: GroupWidget

### Class Definition

**File**: `libs/Dashboard/GroupWidget.m`
**Extends**: `DashboardWidget`

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Mode` | `'panel'` \| `'collapsible'` \| `'tabbed'` | `'panel'` | Grouping behavior |
| `Label` | string | `''` | Title shown in header bar |
| `Collapsed` | logical | `false` | Whether group is collapsed (collapsible mode only) |
| `Children` | cell array of DashboardWidget | `{}` | Child widgets (panel/collapsible modes) |
| `Tabs` | struct | `struct()` | Map of tab name → child widget arrays (tabbed mode only) |
| `ActiveTab` | string | `''` | Currently visible tab (tabbed mode only) |
| `ChildColumns` | integer | `24` | Column count for child sub-grid |
| `ChildAutoFlow` | logical | `true` | Auto-arrange children left-to-right |

### API

```matlab
% Panel mode (default)
g = GroupWidget('Label', 'Motor Health');
g.addChild(NumberWidget('Sensor', rpm_sensor));
g.addChild(GaugeWidget('Sensor', temp_sensor));

% Collapsible mode
g = GroupWidget('Label', 'Motor Health', 'Mode', 'collapsible');
g.addChild(NumberWidget('Sensor', rpm_sensor));
g.addChild(GaugeWidget('Sensor', temp_sensor));

% Tabbed mode
g = GroupWidget('Label', 'Analysis', 'Mode', 'tabbed');
g.addChild(chart1, 'Overview');
g.addChild(chart2, 'Overview');
g.addChild(table1, 'Detail');
```

### Methods

| Method | Signature | Description |
|--------|-----------|-------------|
| `addChild` | `addChild(widget)` or `addChild(widget, tabName)` | Add child widget. Second form required for tabbed mode. |
| `removeChild` | `removeChild(widget)` | Remove child by reference |
| `render` | `render(parentPanel)` | Render header + child sub-layout into parent uipanel |
| `refresh` | `refresh()` | Calls `refresh()` on all visible children |
| `collapse` | `collapse()` | Collapse (collapsible mode only) |
| `expand` | `expand()` | Expand (collapsible mode only) |
| `switchTab` | `switchTab(tabName)` | Switch active tab (tabbed mode only) |

### Layout Integration

GroupWidget occupies a position on the main 24-column grid like any other widget (e.g., `Position = [1, 1, 12, 4]`). Inside, it creates a child layout context.

**Child positioning**:
- **Auto-flow (default)**: Children laid out left-to-right with equal width (`ChildColumns / numChildren`), wrapping to next row when full.
- **Explicit**: If a child has `Position` set, it is interpreted relative to the group's sub-grid, not the main dashboard grid.

**Collapse behavior** (collapsible mode):
- Collapsed: group height shrinks to header bar only (~1 grid row).
- DashboardLayout re-runs `resolveOverlap()` to shift widgets below upward.
- Expanded: original height restores, widgets shift back.
- Children are hidden (not destroyed) when collapsed — state and data persist.

**Tabbed behavior**:
- All tabs share the same spatial area.
- Only the active tab's children are visible.
- Tab switching hides/shows child panels — no re-creation, so widget state is preserved.
- Tab bar rendered as `uicontrol` buttons in the header area.

**Nesting**: Groups may contain other groups. Maximum nesting depth of 2 enforced to avoid complexity.

### Serialization

**JSON format**:

Panel/collapsible mode:
```json
{
  "Type": "group",
  "Label": "Motor Health",
  "Mode": "collapsible",
  "Collapsed": false,
  "Position": [1, 1, 12, 4],
  "ChildAutoFlow": true,
  "Children": [
    { "Type": "number", "Sensor": "rpm_main" },
    { "Type": "gauge", "Sensor": "temp_bearing" }
  ]
}
```

Tabbed mode:
```json
{
  "Type": "group",
  "Label": "Analysis",
  "Mode": "tabbed",
  "Position": [1, 1, 24, 6],
  "ActiveTab": "Overview",
  "Tabs": {
    "Overview": [
      { "Type": "fastsense", "Sensor": "rpm_main" },
      { "Type": "gauge", "Sensor": "temp_bearing" }
    ],
    "Detail": [
      { "Type": "table", "Sensor": "rpm_main" }
    ]
  }
}
```

**Script export**: Generates `addChild` calls. Tabbed children use `g.addChild(widget, 'TabName')` form.

### Theming

New fields added to `DashboardTheme.m`:

| Field | Description | Dark Default | Light Default |
|-------|-------------|-------------|--------------|
| `GroupHeaderBg` | Header bar background | `[0.16 0.22 0.34]` | `[0.90 0.92 0.95]` |
| `GroupHeaderFg` | Header bar text color | `[0.95 0.95 0.95]` | `[0.15 0.15 0.15]` |
| `GroupBorderColor` | Panel border | `[0.25 0.30 0.40]` | `[0.80 0.82 0.85]` |
| `GroupBorderRadius` | Corner radius (px) | `4` | `4` |
| `TabActiveBg` | Active tab background | matches `GroupHeaderBg` | matches `GroupHeaderBg` |
| `TabInactiveBg` | Inactive tab background | `[0.10 0.12 0.18]` | `[0.82 0.84 0.88]` |

All 6 existing theme presets get updated with appropriate group colors.

### DashboardLayout Changes

- `addWidget` must detect `GroupWidget` and register it as a container.
- `computePosition` unchanged — GroupWidget gets a position like any widget.
- `resolveOverlap` must handle dynamic height changes from collapse/expand.
- New helper: `computeChildPositions(groupWidget)` for sub-grid layout within a group.

### Bridge / Web Export Changes

- `dashboard.js`: Add CSS Grid nesting for group containers.
- `widgets.js`: Add `group` type dispatcher that renders header + child container, handles collapse toggle and tab switching via JavaScript.

---

## Phase B: New Widgets

All widgets follow the existing `DashboardWidget` pattern: Sensor-first data binding, `render()` / `refresh()` / `serialize()` interface, R2020b + Octave compatible.

### HeatmapWidget

**File**: `libs/Dashboard/HeatmapWidget.m`
**Purpose**: 2D color grid for visualizing matrices — sensor values over time-of-day vs. day-of-week, spatial temperature maps.

| Property | Type | Description |
|----------|------|-------------|
| `Sensor` | Sensor | Primary data source |
| `DataFcn` | function_handle | Alternative: callback returning matrix |
| `Colormap` | string or Nx3 | Colormap name or matrix (default `'parula'`) |
| `ShowColorbar` | logical | Show colorbar (default `true`) |
| `XLabels` | cell array | Optional axis labels |
| `YLabels` | cell array | Optional axis labels |

**Renders with**: `imagesc` or `pcolor` + `colorbar` on a standard `axes`.

### BarChartWidget

**File**: `libs/Dashboard/BarChartWidget.m`
**Purpose**: Horizontal or vertical bars for comparing discrete categories.

| Property | Type | Description |
|----------|------|-------------|
| `Sensor` | Sensor or Sensor array | Data source(s) |
| `DataFcn` | function_handle | Alternative: callback returning struct with `categories` and `values` |
| `Orientation` | `'vertical'` \| `'horizontal'` | Bar direction (default `'vertical'`) |
| `Stacked` | logical | Stacked bars when multiple sensors (default `false`) |

**Renders with**: `bar` or `barh`.

### HistogramWidget

**File**: `libs/Dashboard/HistogramWidget.m`
**Purpose**: Distribution of sensor values with bin counts.

| Property | Type | Description |
|----------|------|-------------|
| `Sensor` | Sensor | Data source |
| `NumBins` | integer | Number of bins (default auto) |
| `ShowNormalFit` | logical | Overlay normal distribution curve (default `false`) |
| `EdgeColor` | RGB | Bin edge color |

**Renders with**: `bar` on computed bin edges (for Octave compatibility, not `histogram`).

### ScatterWidget

**File**: `libs/Dashboard/ScatterWidget.m`
**Purpose**: X vs. Y scatter plot correlating two sensors.

| Property | Type | Description |
|----------|------|-------------|
| `SensorX` | Sensor | X-axis data |
| `SensorY` | Sensor | Y-axis data |
| `SensorColor` | Sensor | Optional: color-code points by a third sensor |
| `MarkerSize` | scalar | Point size (default `6`) |
| `Colormap` | string or Nx3 | Colormap for color-coded mode |

**Renders with**: `scatter` or `line(..., 'LineStyle', 'none', 'Marker', '.')` for Octave fallback.

### ImageWidget

**File**: `libs/Dashboard/ImageWidget.m`
**Purpose**: Display a static image — plant layouts, P&ID diagrams, camera snapshots.

| Property | Type | Description |
|----------|------|-------------|
| `File` | string | Path to image file (PNG, JPG, SVG) |
| `ImageFcn` | function_handle | Alternative: callback returning image matrix |
| `Scaling` | `'fit'` \| `'fill'` \| `'stretch'` | How image fits the widget area (default `'fit'`) |
| `Caption` | string | Optional caption below image |

**Renders with**: `imshow` / `image` with `axis image` for aspect ratio.

### MultiStatusWidget

**File**: `libs/Dashboard/MultiStatusWidget.m`
**Purpose**: Grid of colored status indicators — monitor many sensors at a glance.

| Property | Type | Description |
|----------|------|-------------|
| `Sensors` | Sensor array | Array of sensors with ThresholdRules |
| `Columns` | integer | Grid column count (default auto based on count) |
| `ShowLabels` | logical | Show sensor display name next to each dot (default `true`) |
| `IconStyle` | `'dot'` \| `'square'` \| `'icon'` | Indicator shape (default `'dot'`) |

**Renders with**: `patch` or `rectangle` objects + `text` labels, colored by `ThresholdRule.Color`.

---

## Compatibility

- **MATLAB**: R2020b+ (pure `figure`, `uipanel`, `uicontrol`, `axes` — no App Designer)
- **Octave**: Compatible via same rendering primitives
- **No new dependencies**: All rendering uses base MATLAB/Octave graphics

## Testing

Each new widget and each GroupWidget mode gets:
- Unit tests for construction, property validation, render, refresh, serialize/deserialize
- Integration test with DashboardEngine (add to dashboard, verify layout)
- Round-trip serialization test (JSON save → load → verify equality)
- Octave compatibility test (skip where platform limitations apply)
