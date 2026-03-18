<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Dashboard

## `DashboardEngine` --- Top-level dashboard orchestrator.

> Inherits from: `handle`

### Constructor

```matlab
obj = DashboardEngine(name, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Name | `''` |  |
| Theme | `'light'` |  |
| LiveInterval | `5` |  |
| InfoFile | `''` |  |

### Methods

#### `addWidget(obj, type, varargin)`

#### `render(obj)`

#### `startLive(obj)`

#### `stopLive(obj)`

#### `save(obj, filepath)`

#### `exportScript(obj, filepath)`

#### `showInfo(obj)`

SHOWINFO Display the linked Markdown info file in a browser.

#### `cleanupInfoTempFile(obj)`

CLEANUPINFOTEMPFILE Delete the temporary HTML file if it exists.

#### `removeWidget(obj, idx)`

REMOVEWIDGET Remove widget at given index and re-layout.

#### `setWidgetPosition(obj, idx, pos)`

SETWIDGETPOSITION Set the grid position of a widget by index.
  Clamps width to grid columns and resolves overlaps with other
  widgets.

#### `w = getWidgetByTitle(obj, title)`

GETWIDGETBYTITLE Find a widget by its Title property.
  Returns the widget object, or empty if not found.

#### `setContentArea(obj, contentArea)`

SETCONTENTAREA Update the Layout content area.
  Provided so that DashboardBuilder can modify the layout
  without direct write-access to the Layout property (required
  for Octave compatibility).

#### `rerenderWidgets(obj)`

RERENDERWIDGETS Delete all widget panels and recreate them.

#### `updateGlobalTimeRange(obj)`

UPDATEGLOBALTIMERANGE Scan all widgets for data time bounds.

#### `updateLiveTimeRange(obj)`

UPDATELIVETIMERANGE Update DataTimeRange without resetting sliders.
  Called during live mode to expand the time range as data grows.

#### `broadcastTimeRange(obj, tStart, tEnd)`

BROADCASTTIMERANGE Push time range to widgets using global time.

#### `resetGlobalTime(obj)`

RESETGLOBALTIME Re-attach all widgets to global time and apply.

### Static Methods

#### `DashboardEngine.types = widgetTypes()`

WIDGETTYPES List supported widget type strings.

#### `DashboardEngine.obj = load(filepath, varargin)`

---

## `DashboardBuilder` --- Edit mode overlay for dashboard GUI.

> Inherits from: `handle`

Provides drag/resize overlays, a widget palette sidebar, and a
  properties panel. Activated via the Edit button in DashboardToolbar.

  builder = DashboardBuilder(engine);
  builder.enterEditMode();
  builder.exitEditMode();

### Constructor

```matlab
obj = DashboardBuilder(engine)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| IsActive | `false` |  |
| MockCurrentPoint | `[]` |  |

### Methods

#### `enterEditMode(obj)`

#### `exitEditMode(obj)`

#### `selectWidget(obj, idx)`

#### `addWidget(obj, type)`

#### `deleteWidget(obj, idx)`

#### `deleteSelected(obj)`

#### `applyProperties(obj)`

#### `pos = findNextSlot(obj, type)`

#### `onDragStart(obj, widgetIdx)`

#### `onResizeStart(obj, widgetIdx)`

#### `onMouseMove(obj)`

#### `onMouseUp(obj)`

---

## `DashboardWidget` --- Abstract base class for all dashboard widgets.

> Inherits from: `handle`

Subclasses must implement:
    render(parentPanel) — create graphics objects inside the panel
    refresh()           — update data/display (called by live timer)
    getType()           — return widget type string (e.g. 'fastsense')

  Subclasses must also provide a static fromStruct(s) method.

### Constructor

```matlab
obj = DashboardWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Title | `''` | Widget title displayed in header |
| Position | `[1 1 6 2]` | [col, row, width, height] in grid units |
| ThemeOverride | `struct()` | Per-widget theme overrides (merged on top of dashboard theme) |
| UseGlobalTime | `true` | false when user manually zooms this widget |
| Description | `''` | Optional tooltip text shown via info icon hover |
| Sensor | `[]` | Sensor object for data binding (primary source) |
| ParentTheme | `[]` | Theme inherited from DashboardEngine |

### Methods

#### `t = get()`

#### `s = toStruct(obj)`

#### `setTimeRange(~, ~, ~)`

Override in subclasses to respond to global time changes.

#### `[tMin, tMax] = getTimeRange(~)`

Override in subclasses to report data time range.

---

## `FastSenseWidget` --- Dashboard widget wrapping a FastSense instance.

> Inherits from: `DashboardWidget`

Supports three data binding modes:
    Sensor:    w = FastSenseWidget('Sensor', sensorObj)
    DataStore: w = FastSenseWidget('DataStore', dsObj)
    Inline:    w = FastSenseWidget('XData', x, 'YData', y)
    File:      w = FastSenseWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')

  When bound to a Sensor, ThresholdRules apply automatically.

### Constructor

```matlab
obj = FastSenseWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DataStoreObj | `[]` |  |
| XData | `[]` |  |
| YData | `[]` |  |
| File | `''` |  |
| XVar | `''` |  |
| YVar | `''` |  |
| Thresholds | `'auto'` |  |
| XLabel | `''` | X-axis label (auto-set from Sensor if empty) |
| YLabel | `''` | Y-axis label (auto-set from Sensor if empty) |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

Re-render sensor-bound widgets so updated data + violations show.
Preserves current zoom state (xlim) across the rebuild.

#### `setTimeRange(obj, tStart, tEnd)`

#### `onXLimChanged(obj)`

If xlim changed by user zoom/pan (not by setTimeRange),
detach this widget from global time.

#### `[tMin, tMax] = getTimeRange(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `FastSenseWidget.obj = fromStruct(s)`

---

## `GaugeWidget` --- Gauge widget with arc, donut, bar, and thermometer styles.

> Inherits from: `DashboardWidget`

w = GaugeWidget('Title', 'Pressure', 'ValueFcn', @() getPressure(), ...
                  'Range', [0 100], 'Units', 'bar');
  w = GaugeWidget('Sensor', mySensor, 'Style', 'donut');

### Constructor

```matlab
obj = GaugeWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| ValueFcn | `[]` |  |
| Range | `[]` | Empty default for auto-derivation cascade |
| Units | `''` |  |
| StaticValue | `[]` |  |
| Style | `'arc'` | 'arc', 'donut', 'bar', 'thermometer' |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `GaugeWidget.obj = fromStruct(s)`

---

## `NumberWidget` --- Dashboard widget showing a big number with label and trend.

> Inherits from: `DashboardWidget`

w = NumberWidget('Title', 'Temp', 'ValueFcn', @() readTemp(), 'Units', 'degC');

  ValueFcn returns either:
    - A scalar (displayed as-is)
    - A struct with fields: value, unit, trend ('up'/'down'/'flat')

### Constructor

```matlab
obj = NumberWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| ValueFcn | `[]` | function_handle returning scalar or struct |
| Units | `''` | unit label string |
| Format | `'%.1f'` | sprintf format for value |
| StaticValue | `[]` | fixed value (no callback needed) |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `NumberWidget.obj = fromStruct(s)`

---

## `StatusWidget` --- Colored dot indicator with sensor value.

> Inherits from: `DashboardWidget`

Sensor-first:
    w = StatusWidget('Sensor', sensorObj);

  Legacy (still supported):
    w = StatusWidget('Title', 'Pump 1', 'StatusFcn', @() 'ok');

### Constructor

```matlab
obj = StatusWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| StatusFcn | `[]` | function_handle returning 'ok'/'warning'/'alarm' (legacy) |
| StaticStatus | `''` | fixed status string (legacy) |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `StatusWidget.obj = fromStruct(s)`

---

## `TextWidget` --- Static text label or section header.

> Inherits from: `DashboardWidget`

w = TextWidget('Title', 'Section A', 'Content', 'Sensor overview');

### Constructor

```matlab
obj = TextWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Content | `''` | body text |
| FontSize | `0` | 0 = use theme default |
| Alignment | `'left'` | 'left', 'center', 'right' |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(~)`

Static widget — nothing to refresh

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `TextWidget.obj = fromStruct(s)`

---

## `TableWidget` --- Tabular data display using uitable.

> Inherits from: `DashboardWidget`

w = TableWidget('Title', 'Sensor Data', 'DataFcn', @() getData());
  w = TableWidget('Title', 'Static', 'Data', {{'A',1;'B',2}}, ...
                  'ColumnNames', {'Name','Value'});
  w = TableWidget('Sensor', sensorObj);                 % last N data rows
  w = TableWidget('Sensor', sensorObj, 'Mode', 'events', 'EventStoreObj', store);

### Constructor

```matlab
obj = TableWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DataFcn | `[]` |  |
| Data | `{}` |  |
| ColumnNames | `{}` |  |
| Mode | `'data'` | 'data' or 'events' |
| N | `10` | number of rows to display |
| EventStoreObj | `[]` | EventStore for event mode |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `TableWidget.obj = fromStruct(s)`

---

## `RawAxesWidget` --- User-supplied plot function on raw MATLAB axes.

> Inherits from: `DashboardWidget`

w = RawAxesWidget('Title', 'Histogram', ...
      'PlotFcn', @(ax) histogram(ax, randn(1,1000)));

  When bound to a Sensor, the PlotFcn receives (ax, sensor) or
  (ax, sensor, timeRange) depending on its nargin.

### Constructor

```matlab
obj = RawAxesWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| PlotFcn | `[]` | @(ax) or @(ax, sensor[, tRange]) or @(ax, tRange) |
| DataRangeFcn | `[]` | @() returning [tMin tMax] for global time range detection |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `setTimeRange(obj, tStart, tEnd)`

#### `[tMin, tMax] = getTimeRange(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `RawAxesWidget.obj = fromStruct(s)`

---

## `EventTimelineWidget` --- Displays events as colored bars on a timeline.

> Inherits from: `DashboardWidget`

Preferred: bind to an EventStore from the event detection system:
    w = EventTimelineWidget('Title', 'Events', 'EventStoreObj', store);

  Legacy (still supported for backwards compatibility):
    w = EventTimelineWidget('Title', 'Events', 'EventFcn', @() getEvents());
    w = EventTimelineWidget('Title', 'Events', 'Events', eventArray);

  Events must be a struct array with fields:
    startTime, endTime, label, color (optional)

### Constructor

```matlab
obj = EventTimelineWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| EventStoreObj | `[]` | EventStore handle — primary data source |
| Events | `[]` | struct array of events (legacy) |
| EventFcn | `[]` | function_handle returning events (legacy) |
| FilterSensors | `{}` | Cell array of Sensor names to filter |
| ColorSource | `'event'` | 'event' or 'theme' |

### Methods

#### `render(obj, parentPanel)`

#### `setTimeRange(obj, tStart, tEnd)`

#### `[tMin, tMax] = getTimeRange(obj)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `s = toStruct(obj)`

### Static Methods

#### `EventTimelineWidget.obj = fromStruct(s)`

---

## `DashboardSerializer` --- JSON load/save and .m export for dashboard configs.

### Static Methods

#### `DashboardSerializer.save(config, filepath)`

SAVE Write dashboard config struct to JSON file.
 Widgets may have heterogeneous fields, so encode each
 widget individually and assemble the JSON array by hand.

#### `DashboardSerializer.config = load(filepath)`

LOAD Read dashboard config from JSON file.

#### `DashboardSerializer.config = widgetsToConfig(name, theme, liveInterval, widgets, infoFile)`

WIDGETSTOCONFIG Build a config struct from widget objects.

#### `DashboardSerializer.widgets = configToWidgets(config, resolver)`

CONFIGTOWIDGETS Create widget objects from config struct.
  configToWidgets(config) — no sensor resolution
  configToWidgets(config, resolver) — resolver is a function
    handle @(name) that returns a Sensor object by name.

#### `DashboardSerializer.exportScript(config, filepath)`

EXPORTSCRIPT Generate a readable .m script from config.

---

## `DashboardLayout` --- Manages 24-column responsive grid positioning.

> Inherits from: `handle`

Converts widget grid positions [col, row, width, height] to normalized
  canvas coordinates [x, y, w, h]. Handles overlap resolution, row
  calculation, and scrollable canvas when content exceeds the viewport.

### Constructor

```matlab
obj = DashboardLayout(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Columns | `24` |  |
| TotalRows | `4` |  |
| ContentArea | `[0 0 1 1]` |  |
| Padding | `[0.02 0.02 0.02 0.02]` |  |
| GapH | `0.008` |  |
| GapV | `0.015` |  |
| RowHeight | `0.22` |  |
| ScrollbarWidth | `0.015` |  |

### Methods

#### `cr = canvasRatio(obj)`

CANVASRATIO Ratio of canvas height to viewport height.
  Returns 1 when content fits, >1 when scrolling is needed.

#### `pos = computePosition(obj, gridPos)`

COMPUTEPOSITION Convert grid position to canvas-normalized coords.

#### `[stepW, stepH, cellW, cellH] = canvasStepSizes(obj)`

CANVASSTEPSIZES Grid step sizes in canvas-normalized coords.

#### `[dx_c, dy_c] = figureToCanvasDelta(obj, dx_fig, dy_fig)`

FIGURETOCANVASDELTA Convert figure-normalized deltas to canvas deltas.

#### `maxRow = calculateMaxRow(obj, widgets)`

#### `tf = overlaps(obj, posA, posB)`

#### `newPos = resolveOverlap(obj, pos, existingPositions)`

#### `createPanels(obj, hFigure, widgets, theme)`

Save current scroll state before any updates

#### `onScroll(obj, val)`

ONSCROLL Adjust canvas position from scrollbar value.
  val=1 shows top, val=0 shows bottom.

---

## `DashboardToolbar` --- Global toolbar for dashboard controls.

> Inherits from: `handle`

Provides buttons for: Live mode toggle, Edit mode, Save, Export.
  Sits at the top of the dashboard figure.

### Constructor

```matlab
obj = DashboardToolbar(engine, hFigure, theme)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Height | `0.04` |  |

### Methods

#### `setLastUpdateTime(obj, t)`

SETLASTUPDATETIME Update the last-update label with a timestamp.

#### `onNameEdit(obj, src)`

#### `onLiveToggle(obj, src)`

#### `onSave(obj)`

#### `onExport(obj)`

#### `onInfo(obj)`

#### `onEdit(obj)`

#### `contentArea = getContentArea(obj)`

---

## `MarkdownRenderer` --- Lightweight Markdown-to-HTML converter.

html = MarkdownRenderer.render(mdText)
  html = MarkdownRenderer.render(mdText, themeName)
  html = MarkdownRenderer.render(mdText, themeName, basePath)

  Converts a subset of Markdown to a self-contained HTML document.
  Supported: headings (#-###), **bold**, *italic*, `inline code`,
  fenced code blocks, `[links](url)`, `![images](src)`, unordered/ordered
  lists, horizontal rules (---), tables (pipe-delimited), and paragraph
  breaks.

  The optional themeName ('light', 'dark', etc.) controls the CSS
  color scheme. Unrecognized themes default to 'light'.

### Static Methods

#### `MarkdownRenderer.html = render(mdText, themeName, basePath)`

