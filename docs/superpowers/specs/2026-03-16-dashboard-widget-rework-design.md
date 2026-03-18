# Dashboard Widget Rework — Sensor-First Data Binding

## Overview

Rework all dashboard engine widgets to use a uniform **Sensor-first data binding** model. Instead of each widget type having its own ad-hoc data connection (ValueFcn, StatusFcn, DataFcn, etc.), all widgets bind to a `Sensor` object and derive their display automatically. This eliminates boilerplate callbacks, simplifies serialization, and ensures cross-widget consistency.

**Scope:** All 8 widget types in `libs/Dashboard/`, the `DashboardWidget` base class, and the `DashboardEngine.addWidget()` API.

**Constraints:**
- MATLAB R2020b compatible (figure-based only, no uifigure)
- Builds on existing `Sensor`, `ThresholdRule`, `EventStore` classes
- Backward-compatible fallbacks where needed (RawAxesWidget callback, TextWidget static)

## Design Principles

1. **Sensor is the universal data source** — widgets derive value, units, range, status, and colors from the bound Sensor and its ThresholdRules
2. **ThresholdRule.Color is the severity signal** — no new Severity property needed; violated threshold colors drive status/gauge coloring directly. When `ThresholdRule.Color` is empty (`[]`), fall back to theme `StatusAlarmColor` for upper-direction thresholds and `StatusWarnColor` for lower-direction thresholds.
3. **Cascade for configurable properties** — custom override > threshold-derived > data-derived > theme default
4. **Minimal configuration** — binding a Sensor should produce a useful widget with zero additional config

## DashboardWidget Base Class Changes

All widgets inherit from `DashboardWidget`. The following properties are added or modified:

### New/Modified Properties

| Property | Type | Default | Description |
|---|---|---|---|
| `Title` | char | `Sensor.Name` or `''` | Display title. Defaults to Sensor name when bound. |
| `Description` | char | `''` | Optional tooltip text, shown via info icon hover on the widget header. |
| `SensorObj` | Sensor | `[]` | Primary data binding. Moved from FastSenseWidget to base class. |
| `Position` | 1x4 double | widget-specific | `[col, row, width, height]` in grid units (unchanged). |
| `ThemeOverride` | struct | `struct()` | Per-widget theme overrides (unchanged). |
| `UseGlobalTime` | logical | `true` | Follow global time slider (unchanged). |

### Info Icon Hover

When `Description` is non-empty, the widget header renders a small `(i)` icon next to the title. On mouse hover (using figure `WindowButtonMotionFcn` + `TooltipString` on a `uicontrol`), the description text appears as a tooltip. This uses standard R2020b `uicontrol` tooltip support.

### Title Cascade

1. User-specified `Title` property (if non-empty)
2. `Sensor.Name` (if Sensor is bound)
3. Empty string (widget renders without title)

## Widget Specifications

### 1. FastSenseWidget

**Binding:** Single Sensor (primary), DataStore, File, or inline XData/YData (fallbacks).

**Sensor-derived data:**
- X/Y time-series from `Sensor.X`, `Sensor.Y`
- ThresholdRules auto-resolve — violation markers and bands render automatically
- XLabel defaults to `'Time'`, YLabel defaults to `Sensor.Units`

**Unchanged behavior:** Creates a `FastSense` instance inside its panel. Full zoom/pan/downsample support. `setTimeRange()` updates xlim when `UseGlobalTime` is true. User zoom sets `UseGlobalTime = false`.

**Default size:** 12 cols x 3 rows.

### 2. NumberWidget (renamed from KpiWidget)

**Binding:** Single Sensor (primary), static value fallback.

**Sensor-derived data:**
- **Value:** `Sensor.Y(end)` — latest data point
- **Units:** `Sensor.Units`
- **Trend:** Computed from slope of recent Y values:
  - Positive slope above threshold → `'up'` (▲)
  - Negative slope below threshold → `'down'` (▼)
  - Otherwise → `'flat'` (►)
  - Trend threshold: configurable via `TrendThreshold` property (default: auto from data variance)

**Layout:** Horizontal — `[Title (left)] [Value (center)] [Trend arrow] [Units (right)]`. Font sizes scale adaptively with panel height.

**Fallback:** `StaticValue` property for fixed display without Sensor binding.

**Default size:** 6 cols x 1 row.

### 3. GaugeWidget

**Binding:** Single Sensor (primary), static value fallback.

**Sensor-derived data:**
- **Value:** `Sensor.Y(end)` — latest data point
- **Units:** `Sensor.Units`
- **Range:** Cascade priority:
  1. Custom `Range` property (if user sets `[min, max]`)
  2. ThresholdRule-derived: `[min(ThresholdRule.Value), max(ThresholdRule.Value)]`
  3. Data-derived: `[min(Sensor.Y), max(Sensor.Y)]`
- **Color zones:** Cascade priority:
  1. Custom `ColorZones` property
  2. ThresholdRule-derived: each threshold's `Color` maps to its value on the gauge
  3. Default theme color coding (green/orange/red based on fraction)

**Styles:** Configured via `Style` property:

| Style | Description | Best for |
|---|---|---|
| `'arc'` | Half-circle with needle (current design, 240deg sweep) | Classic gauge look |
| `'donut'` | Full 360deg ring, value displayed in center | Utilization, percentage |
| `'bar'` | Horizontal progress bar with colored zones | Compact 1-row layouts |
| `'thermometer'` | Vertical bar with fill level | Temperature sensors |

All styles share the same data binding and color zone logic. The `Style` property defaults to `'arc'`.

**Rendering details per style:**

- **Arc:** Background arc (light) + foreground arc (colored by zone) + needle line + value text in center + min/max labels at endpoints.
- **Donut:** Full circle track (light) + colored fill arc proportional to value + value text centered inside ring + units below value.
- **Bar:** Horizontal rectangle background + colored fill from left + zone boundaries as vertical ticks + value label right-aligned + min/max at endpoints.
- **Thermometer:** Vertical rectangle with rounded bottom + colored fill from bottom up + zone boundaries as horizontal ticks + value label at top + bulb at bottom.

**Fallback:** `StaticValue` + explicit `Range` for display without Sensor binding.

**Default size:** 6 cols x 2 rows.

### 4. StatusWidget

**Binding:** Single Sensor (primary), static status fallback.

**Sensor-derived data:**
- **Status color:** Determined by current threshold violations:
  1. No active violations → theme `StatusOkColor` (green)
  2. One violation active → that ThresholdRule's `Color`
  3. Multiple violations active → color of the most extreme threshold (highest `Value` for upper direction, lowest `Value` for lower direction — the last threshold crossed)
- **Value display:** `Sensor.Y(end)` with `Sensor.Units`
- **Label:** `Sensor.Name`

**Layout (dot + value):** `[● colored dot] [Sensor.Name: value Units]`

Compact enough to tile across a dashboard row for at-a-glance status overview. The dot is a filled circle whose color reflects the current violation state.

**Fallback:** `StaticStatus` property (`'ok'`, `'warning'`, `'alarm'`) with explicit color mapping via theme.

**Default size:** 4 cols x 1 row.

### 5. TextWidget

**Binding:** None. Static content only.

**Properties:**
- `Title` — header text
- `Content` — body text
- `FontSize` — override (0 = theme default)
- `Alignment` — `'left'` | `'center'` | `'right'`
- `Description` — tooltip (inherited from base class)

No data binding, no live refresh. Used for section headers, labels, and annotations.

**Default size:** 6 cols x 1 row.

### 6. TableWidget

**Binding:** Single Sensor (primary), static data fallback.

**Two display modes:**

| Mode | Property | Data shown | Column headers |
|---|---|---|---|
| **Data mode** (default) | `Mode = 'data'` | Last N rows of `[Timestamp, Value]` from Sensor | `{'Time', Sensor.Name}` or custom `ColumnNames` |
| **Event mode** | `Mode = 'events'` | Last N events from EventStore filtered to this Sensor | `{'Start', 'End', 'Label', 'Duration'}` |

**Properties:**
- `Mode` — `'data'` (default) or `'events'`
- `N` — Number of rows to display (default: 10)
- `EventStoreObj` — EventStore to query in event mode (required for event mode)
- `ColumnNames` — Override column headers
- `Data` — Static cell array fallback (no Sensor binding)

**Event mode filtering:** When in event mode, the widget queries `EventStoreObj.getEvents()` and filters to events whose label contains `Sensor.Name`. This allows selecting events for a specific Sensor from a shared EventStore.

**Default size:** 8 cols x 2 rows.

### 7. RawAxesWidget

**Binding:** Single Sensor (optional), bare callback fallback.

**Two signatures for PlotFcn:**

| Binding | PlotFcn signature | Example |
|---|---|---|
| Sensor bound | `@(ax, sensor)` | `@(ax, s) histogram(ax, s.Y)` |
| No Sensor | `@(ax)` | `@(ax) bar(ax, categories, counts)` |

**Sensor-derived data:** The full Sensor object is passed to the PlotFcn. The user has access to X, Y, ThresholdRules, Name, Units — full flexibility for custom visualizations (histograms, scatter plots, bar charts, etc.).

**Time integration:** When Sensor is bound and PlotFcn accepts 3+ arguments, signature becomes `@(ax, sensor, tRange)` where `tRange = [tStart, tEnd]` from global time slider.

**PlotFcn dispatch logic:** The existing `nargin(PlotFcn)` dispatch in `callPlotFcn` must be updated for the new signatures:
- `nargin == 1`: no Sensor, no time range → `PlotFcn(ax)`
- `nargin == 2`: Sensor bound, no time range → `PlotFcn(ax, sensor)`
- `nargin >= 3`: Sensor bound + time range → `PlotFcn(ax, sensor, tRange)`
- No-Sensor + time range (`@(ax, tRange)`) is preserved as legacy: detected when no SensorObj is bound and `nargin == 2`.

**Serialization:** Sensor reference serializes cleanly. PlotFcn callbacks using `str2func`-compatible function names serialize; anonymous functions do not (user warned on save).

**Default size:** 8 cols x 2 rows.

### 8. EventTimelineWidget

**Binding:** EventStore (primary). Does NOT bind to Sensor.

**Properties:**
- `EventStoreObj` — EventStore to display (required)
- `FilterSensors` — Optional cell array of Sensor names to filter events (default: show all)
- `ColorSource` — `'event'` (use event/ThresholdRule colors) or `'theme'` (default theme palette)

**Rendering:**
- Horizontal Gantt-style timeline
- Each unique event label gets its own lane (Y-axis row)
- Colored bars for each event span (startTime to endTime)
- Bar colors from ThresholdRule.Color when available, otherwise from theme palette
- Y-axis labels show event labels (e.g., "T-401 — Hi Alarm")

**Time integration:** `setTimeRange()` updates xlim when `UseGlobalTime` is true.

**Default size:** 24 cols x 2 rows (full width).

## Unified addWidget API

The `DashboardEngine.addWidget()` method signature remains the same but all widget types now accept `'Sensor'` as a primary binding:

```matlab
% Sensor-first (recommended for all sensor-bound widgets)
d.addWidget('fastsense',  'Sensor', sTemp, 'Position', [1 1 12 3]);
d.addWidget('number',    'Sensor', sTemp, 'Position', [13 1 6 1]);
d.addWidget('gauge',     'Sensor', sPressure, 'Style', 'donut', 'Position', [13 2 6 2]);
d.addWidget('status',    'Sensor', sTemp, 'Position', [19 1 6 1]);
d.addWidget('table',     'Sensor', sTemp, 'Mode', 'data', 'N', 20, 'Position', [1 4 8 2]);
d.addWidget('rawaxes',   'Sensor', sTemp, 'PlotFcn', @(ax,s) histogram(ax, s.Y), 'Position', [9 4 8 2]);

% EventStore binding (EventTimelineWidget only)
d.addWidget('timeline',  'EventStore', myStore, 'Position', [1 6 24 2]);

% Static (TextWidget)
d.addWidget('text', 'Title', 'Section A', 'Content', 'Overview', 'Position', [1 8 6 1]);
```

**Type string mapping:**
- `'fastsense'` → FastSenseWidget
- `'number'` → NumberWidget (was `'kpi'`)
- `'gauge'` → GaugeWidget
- `'status'` → StatusWidget
- `'text'` → TextWidget
- `'table'` → TableWidget
- `'rawaxes'` → RawAxesWidget
- `'timeline'` → EventTimelineWidget

**Backward compatibility:** The type string `'kpi'` should remain as an alias for `'number'` during a deprecation period.

## Serialization Changes

### JSON Format

Sensor-bound widgets serialize the Sensor's `Key` property (not the Sensor object or display Name). The `"name"` field in the JSON source block always refers to `Sensor.Key`:

```json
{
  "type": "number",
  "title": "Current Temp",
  "description": "Outlet temperature after heat exchanger",
  "position": {"col": 13, "row": 1, "width": 6, "height": 1},
  "source": {"type": "sensor", "name": "T-401"}
}
```

```json
{
  "type": "gauge",
  "title": "Pressure",
  "position": {"col": 13, "row": 2, "width": 6, "height": 2},
  "source": {"type": "sensor", "name": "P-201"},
  "style": "donut",
  "range": [0, 100]
}
```

```json
{
  "type": "timeline",
  "title": "Threshold Violations",
  "position": {"col": 1, "row": 6, "width": 24, "height": 2},
  "source": {"type": "eventstore", "path": "events/violations.mat"},
  "filterSensors": ["T-401", "P-201"]
}
```

EventTimelineWidget continues to serialize EventStore via file path (consistent with existing `EventStore(filePath)` constructor). The `"path"` field references the EventStore's `FilePath` property.

### Sensor Resolution on Load

On `DashboardEngine.load()`, Sensor names are resolved via a **SensorRegistry** or a user-provided resolver function. If a Sensor cannot be found, the widget renders in an error/placeholder state rather than crashing.

```matlab
d = DashboardEngine.load('dashboard.json', 'SensorResolver', @(name) SensorRegistry.get(name));
```

## Live Refresh Behavior

The existing live timer architecture is unchanged. On each tick:

1. `DashboardEngine.onLiveTick()` iterates all widgets
2. Each widget's `refresh()` re-reads from its bound Sensor:
   - NumberWidget: re-evaluates `Sensor.Y(end)`, recomputes trend
   - GaugeWidget: re-evaluates `Sensor.Y(end)`, updates needle/fill
   - StatusWidget: re-checks current violations, updates dot color
   - TableWidget: re-queries last N data points or events
   - FastSenseWidget: re-renders with latest Sensor data
   - RawAxesWidget: clears and re-calls PlotFcn with updated Sensor
   - EventTimelineWidget: re-queries EventStore
   - TextWidget: no-op (static)
3. Toolbar updates last-update timestamp
4. Global time sliders re-broadcast if data range expanded

## Migration Path

### New Sensor Property (Prerequisite)
- Add `Units` (char, default `''`) as a public property on `Sensor.m`. Multiple widgets derive unit labels from this property. Existing Sensors without `Units` set will display empty unit strings, which is safe.

### Renamed Files
- `KpiWidget.m` → `NumberWidget.m`

### Moved Properties
- `SensorObj` moves from `FastSenseWidget` to `DashboardWidget` base class

### API Changes
- `DashboardEngine.load(filepath)` gains an optional name-value parameter: `'SensorResolver'`, a function handle `@(key) -> Sensor`. Existing single-argument calls continue to work (default resolver attempts `SensorRegistry.get(key)` if available, otherwise leaves widget unbound).
- `DashboardEngine.addWidget()` switch-case: add `'number'` case for NumberWidget
- `DashboardSerializer.configToWidgets()` switch-case: add `'number'` case for NumberWidget

### Deprecated Properties
- `KpiWidget.ValueFcn` → bind Sensor instead (keep as fallback)
- `GaugeWidget.ValueFcn` → bind Sensor instead (keep as fallback)
- `StatusWidget.StatusFcn` → bind Sensor instead (keep as fallback)
- `TableWidget.DataFcn` → bind Sensor instead (keep as fallback)

### Deprecated Type Strings
- `'kpi'` → alias for `'number'` (warn on use). Both `DashboardEngine.addWidget()` and `DashboardSerializer.configToWidgets()` must handle `'kpi'` as an alias that maps to NumberWidget.

## Testing Strategy

Each widget gets round-trip tests for:
- Sensor binding: bind Sensor, render, verify derived values match Sensor data
- Fallback binding: static/callback path still works
- Serialization: toStruct → fromStruct round-trip preserves all properties
- Live refresh: bind Sensor, call refresh(), verify display updates
- Description tooltip: set Description, verify info icon renders

GaugeWidget additionally tests all 4 styles (arc, donut, bar, thermometer).
StatusWidget tests threshold color derivation with 0, 1, and multiple active violations.
TableWidget tests both data and event modes.
