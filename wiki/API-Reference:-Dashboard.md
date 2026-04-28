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
| ProgressMode | `'auto'` | 'auto' \| 'on' \| 'off' — render progress bar visibility |
| ShowTimePanel | `true` | hide the bottom time slider panel |

### Methods

#### `pg = addPage(obj, name)`

ADDPAGE Add a named page and make it the active page for addWidget.
  pg = d.addPage('Overview') creates a DashboardPage and appends it to Pages.
  Sets ActivePage to the last-added page index.
  When Pages is non-empty, addWidget routes to the active page.

#### `switchPage(obj, pageIdx)`

SWITCHPAGE Switch the active page using panel visibility toggling.
  d.switchPage(2) sets ActivePage = 2 and toggles panel visibility.

#### `w = addWidget(obj, type, varargin)`

Accept a pre-constructed widget object directly

#### `w = addCollapsible(obj, label, children, varargin)`

ADDCOLLAPSIBLE Convenience: add a GroupWidget with Mode='collapsible'.
  w = d.addCollapsible('Sensors', {w1, w2})
  w = d.addCollapsible('Sensors', {w1, w2}, 'Collapsed', true)

#### `t = getCachedTheme(obj)`

GETCACHEDTHEME Return cached theme struct, recomputing only when Theme changes.

#### `render(obj)`

#### `startLive(obj)`

#### `stopLive(obj)`

Clear IsLive FIRST so any in-flight onLiveTimerError callback
does not re-`start(obj.LiveTimer)` on the timer we are about to
delete (observed on CI as a runaway 500k+ stderr loop in
testTimerContinuesAfterError). Then stop/delete the timer with
isvalid + try/catch guards, matching LiveTagPipeline.stop().

#### `save(obj, filepath)`

#### `exportScript(obj, filepath)`

#### `exportImage(obj, filepath, format)`

EXPORTIMAGE Save the rendered dashboard figure as PNG or JPEG at 150 DPI.
  d.exportImage('out.png')           % format inferred from extension
  d.exportImage('out.png', 'png')
  d.exportImage('out.jpg', 'jpeg')

#### `preview(obj, varargin)`

PREVIEW Print ASCII representation of the dashboard to console.
  d.preview()              % default 120 chars wide
  d.preview('Width', 120)  % custom width

#### `showInfo(obj)`

SHOWINFO Display the linked Markdown info file in a browser.
  When InfoFile is empty, displays a built-in placeholder page
  describing how to attach a custom info file.

#### `writeAndOpenInfoHtml(obj, html)`

WRITEANDOPENINFOHTML Write rendered HTML to the cached temp file and open it.

#### `md = buildPlaceholderInfoMarkdown(obj)`

BUILDPLACEHOLDERINFOMARKDOWN Default info page shown when no InfoFile is set.

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

#### `detachWidget(obj, widget)`

DETACHWIDGET Pop a widget out as a standalone figure window.

#### `removeDetached(obj)`

REMOVEDETACHED Remove stale mirrors from the registry.

#### `setContentArea(obj, contentArea)`

SETCONTENTAREA Update the Layout content area.
  Provided so that DashboardBuilder can modify the layout
  without direct write-access to the Layout property (required
  for Octave compatibility).

#### `[effToolbarH, effPageBarH, effTimeH] = applyChromeVisibility(obj, toolbarH, pageBarH)`

APPLYCHROMEVISIBILITY Set chrome Visible state + return effective heights.
  Respects ShowToolbar and ShowTimePanel flags. Returns the heights
  that should be used for the content-area calculation (0 when the
  corresponding chrome element is hidden).

#### `applyVisibilityAndRelayout(obj)`

APPLYVISIBILITYANDRELAYOUT Re-apply ShowToolbar/ShowTimePanel + re-layout widgets.

#### `applyThemeToChrome(obj)`

APPLYTHEMETOCHROME Restyle figure + non-widget chrome using the current Theme.
  Widget panels are NOT touched here — call rerenderWidgets() after
  this method to recreate widget content with the new theme.

#### `rerenderWidgets(obj)`

RERENDERWIDGETS Delete all widget panels and recreate them.

#### `updateGlobalTimeRange(obj)`

UPDATEGLOBALTIMERANGE Scan all widgets for data time bounds.

#### `updateLiveTimeRange(obj)`

UPDATELIVETIMERANGE Update DataTimeRange without resetting sliders.
  Called during live mode to expand the time range as data grows.

#### `newTMax = updateLiveTimeRangeFrom(obj, ws)`

UPDATELIVETIMERANGEFROM Update DataTimeRange from pre-fetched widget list.
  Like updateLiveTimeRange but accepts ws to avoid re-fetching activePageWidgets().
  Returns the new tMax (or NaN when no widget has finite time data).

#### `createStaleBanner(obj, theme, toolbarH)`

CREATESTALEBANNER Create the hidden stale-data warning banner overlay.
  A uipanel strip below the toolbar containing a message label and
  a close button. Hidden by default; shown when staleness is detected
  and not previously dismissed by the user.

#### `showStaleBanner(obj, staleTitles)`

SHOWSTALEBANNER Display the warning listing the widgets without new data.
  staleTitles is a cell array of widget Title strings whose tMax
  did not advance on the last live tick.

#### `hideStaleBanner(obj)`

HIDESTALEBANNER Clear the stale-data warning overlay.

#### `onStaleBannerClose(obj)`

ONSTALEBANNERCLOSE User dismissed the warning; stay hidden until data resumes.

#### `msg = buildStaleMessage(obj, staleTitles, intervalStr)`

BUILDSTALEMESSAGE Compose the banner text listing stale widgets.

#### `staleTitles = detectStaleWidgets(obj, ws)`

DETECTSTALEWIDGETS Return titles of widgets whose tMax did not advance.
  Updates LastTMaxPerWidget_ with the current observation.

#### `broadcastTimeRange(obj, tStart, tEnd)`

BROADCASTTIMERANGE Push time range to widgets using global time.

#### `resetGlobalTime(obj)`

RESETGLOBALTIME Re-attach all widgets to global time and apply.

#### `realizeBatch(obj, batchSize)`

REALIZEBATCH Render widgets in batches with drawnow between.

#### `[idx, name] = activePageLabel(obj)`

ACTIVEPAGELABEL Index and name of the active page, or (1, '') if single-page.

#### `onScrollRealize(obj, topRow, bottomRow)`

ONSCROLLREALIZE Realize widgets that scroll into view.

#### `onLiveTick(obj)`

#### `markAllDirty(obj)`

MARKALLDIRTY Flag all widgets as needing refresh.
  Called on theme change, figure resize, or other global state changes.

#### `onResize(obj)`

ONRESIZE Handle figure resize: reposition all widget panels.

#### `triggerTimeSlidersChangedForTest(obj)`

TRIGGERTIMESLIDERSCHANGEDFORTEST Test-only hook to invoke the slider
  callback without going through UI events. Exposes the private
  onTimeSlidersChanged() debounce path to tests.
  (Hidden, not the narrower Access = {?matlab.unittest.TestCase},
  so Octave parsing survives — Octave has no matlab.unittest.)

#### `broadcastTimeRangeNow(obj, tStart, tEnd)`

BROADCASTTIMERANGENOW Test-only synchronous broadcast bypassing the
  SliderDebounceTimer. Stock Octave 7 batch mode has unreliable
  timer scheduling; tests should use this entry point to drive
  the broadcast deterministically. Also updates the time labels
  (skipping the debounced onRangeSelectorChanged path).

#### `env = computePreviewEnvelopeForTest(obj, nBuckets)`

COMPUTEPREVIEWENVELOPEFORTEST Test-only wrapper around the
  private computePreviewEnvelopeReturning_. Runs the real
  aggregation and returns the envelope struct so tests can
  assert shape/monotonicity without scraping the selector's
  patch handles. When nBuckets is omitted, uses the method's
  own width-derived default.

#### `str = formatTimeVal(~, t)`

FORMATTIMEVAL Format a numeric time value as a human-readable string.
  Supports three numeric ranges:
    posix epoch seconds (9e8 < t < 5e9) — converts via datenum(1970,...)+t/86400
    MATLAB datenum (t > 700000, not posix) — uses datestr directly
    raw numeric (t <= 700000) — formats as s/m/h/d suffix

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

#### `w = addIconCard(obj, varargin)`

ADDICONCARD Add an IconCardWidget via the builder.

#### `w = addChipBar(obj, varargin)`

ADDCHIPBAR Add a ChipBarWidget via the builder.

#### `w = addSparkline(obj, varargin)`

ADDSPARKLINE Add a SparklineCardWidget via the builder.

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

Map legacy 'Sensor' NV pair to 'Tag' for backward compat
of serialized dashboards.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Title | `''` | Widget title displayed in header |
| Position | `[1 1 6 2]` | [col, row, width, height] in grid units |
| ThemeOverride | `struct()` | Per-widget theme overrides (merged on top of dashboard theme) |
| UseGlobalTime | `true` | false when user manually zooms this widget |
| Description | `''` | Optional tooltip text shown via info icon hover |
| Tag | `[]` | v2.0 Tag API — any Tag subclass |
| ParentTheme | `[]` | Theme inherited from DashboardEngine |
| Dirty | `true` | true when widget needs refresh (data changed) |
| hPanel | `[]` | Handle to the uipanel this widget renders into |

### Methods

#### `t = get()`

#### `s = get()`

GET.SENSOR Backward-compat alias for Tag (v1.x API).

#### `set()`

SET.SENSOR Backward-compat alias — maps to Tag property.

#### `s = toStruct(obj)`

#### `markDirty(obj)`

MARKDIRTY Flag this widget as needing a refresh.

#### `markRealized(obj)`

MARKREALIZED Mark this widget as having been rendered.

#### `markUnrealized(obj)`

MARKUNREALIZED Mark this widget as needing re-render.

#### `setTimeRange(~, ~, ~)`

Override in subclasses to respond to global time changes.

#### `[tMin, tMax] = getTimeRange(~)`

Override in subclasses to report data time range.

#### `series = getPreviewSeries(~, ~)`

GETPREVIEWSERIES Optional preview data for the time-range envelope.
  series = getPreviewSeries(obj, nBuckets) returns a struct with
  fields xCenters, yMin, yMax — each a 1xnBuckets row vector;
  yMin/yMax MUST be normalized to [0,1] within the widget's own
  y-range. Base returns [] to opt out of the preview envelope.

#### `t = getEventTimes(~)`

GETEVENTTIMES Optional list of event times for the time-slider overlay.
  t = getEventTimes(obj) returns a row vector of event start times
  in the dashboard's time axis. Override to expose events to the
  TimeRangeSelector event-marker overlay; base returns [] so
  widgets without events contribute nothing.

#### `lines = asciiRender(obj, width, height)`

ASCIIRENDER Return ASCII representation of this widget.
  lines = asciiRender(obj, width, height) returns a cell array
  of strings, each exactly WIDTH characters. HEIGHT is the
  available number of lines. Default implementation shows
  [type] Title; subclasses override for richer content.

#### `render(~, ~)`

#### `refresh(~)`

#### `t = getType(~)`

---

## `FastSenseWidget` --- Dashboard widget wrapping a FastSense instance.

> Inherits from: `DashboardWidget`

Supports data binding modes:
    Tag:       w = FastSenseWidget('Tag', tagObj)
    DataStore: w = FastSenseWidget('DataStore', dsObj)
    Inline:    w = FastSenseWidget('XData', x, 'YData', y)
    File:      w = FastSenseWidget('File', 'path.mat', 'XVar', 'x', 'YVar', 'y')

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
| YLimits | `[]` | Fixed Y-axis range [min max]; empty = auto-scale |
| ShowThresholdLabels | `false` | show inline name labels on threshold lines |
| ShowEventMarkers | `false` | Phase 1012 — toggle event round-marker overlay |
| EventStore | `[]` | Phase 1012 — EventStore handle forwarded to inner FastSense |
| LiveViewMode | `'reset'` |  |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

Re-render Tag-bound widgets so updated data shows.
Uses incremental updateData() path when tag identity is unchanged
(PERF2-01); falls back to full teardown/rebuild on first render,
tag swap, or error.  Zoom state (xlim) is preserved in both paths.

#### `update(obj)`

UPDATE Incrementally update Tag data without full axes rebuild.
  Uses FastSenseObj.updateData() to replace data and re-downsample,
  avoiding the expensive delete/recreate cycle of refresh().
  Falls back to refresh() if FastSenseObj is not in a renderable state.

#### `autoScaleY_(obj, y)`

AUTOSCALEY_ Rescale the Y axis to cover current data + thresholds.
  FastSense locks YLim to manual mode at first render, so new
  samples outside the initial range would fall off the chart.
  This helper recomputes the Y extent every tick (including any
  threshold values so MonitorTag lines stay visible) and updates
  the axes. Skipped when:
    - the widget has a user-pinned YLimits NV-pair, or
    - the user manually zoomed Y via mouse (UserZoomedY),
  so we never fight an explicit human interaction.

#### `onYLimChanged(obj)`

ONYLIMCHANGED Detach widget from automatic Y rescale after user zoom.
  Fired by the YLim PostSet listener. When the YLim change came
  from inside autoScaleY_ (IsSettingYLim==true) we ignore it; any
  other source — mouse scroll, drag, zoom toolbar, programmatic
  ylim() from user code — counts as a manual override and
  latches UserZoomedY so live ticks stop fighting the user.

#### `setTimeRange(obj, tStart, tEnd)`

#### `onXLimChanged(obj)`

If xlim changed by user zoom/pan (not by setTimeRange),
detach this widget from global time.

#### `[tMin, tMax] = getTimeRange(obj)`

Return cached min/max in O(1). Cache is kept up to date by
updateTimeRangeCache() which is called from render/refresh/update.

#### `series = getPreviewSeries(obj, nBuckets)`

GETPREVIEWSERIES Per-bucket min/max preview for the dashboard envelope.
  series = getPreviewSeries(obj, nBuckets) returns a struct with
  fields xCenters, yMin, yMax — each a 1xnBuckets row vector; yMin
  and yMax are normalized into [0,1] across the widget's own
  current y-range. Returns [] when no data is bound or when the
  sample count is too low to downsample meaningfully.

#### `t = getEventTimes(obj)`

GETEVENTTIMES Event start times from the wrapped FastSense.EventStore.
  Returns [] when the FastSense instance is absent, has no
  EventStore, or when any access raises. Never throws.

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `FastSenseWidget.obj = fromStruct(s)`

---

## `GaugeWidget` --- Gauge widget with arc, donut, bar, and thermometer styles.

> Inherits from: `DashboardWidget`

w = GaugeWidget('Title', 'Pressure', 'ValueFcn', @() getPressure(), ...
                  'Range', [0 100], 'Units', 'bar');
  w = GaugeWidget('Sensor', mySensor, 'Style', 'donut');
  w = GaugeWidget('Threshold', t, 'StaticValue', 50);

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
| Threshold | `[]` | Threshold object or registry key string (per D-01) |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

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

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `NumberWidget.obj = fromStruct(s)`

---

## `StatusWidget` --- Colored dot indicator with sensor value.

> Inherits from: `DashboardWidget`

Sensor-first:
    w = StatusWidget('Sensor', sensorObj);

  Threshold-bound (no Sensor required):
    w = StatusWidget('Title', 'Temp', 'Threshold', t, 'Value', 85);
    w = StatusWidget('Title', 'Temp', 'Threshold', 'temp_hi', 'ValueFcn', @getTemp);

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
| Threshold | `[]` | Threshold object or registry key string (per D-01) |
| Value | `[]` | Scalar numeric value for threshold comparison (per D-03) |
| ValueFcn | `[]` | Function handle returning scalar value (per D-03, D-09) |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

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

#### `lines = asciiRender(obj, width, height)`

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

#### `lines = asciiRender(obj, width, height)`

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

#### `lines = asciiRender(obj, width, height)`

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
| FilterTagKey | `''` | Tag-key filter (MONITOR-05 carrier: SensorName OR ThresholdLabel match) |
| ColorSource | `'event'` | 'event' or 'theme' |

### Methods

#### `render(obj, parentPanel)`

#### `setTimeRange(obj, tStart, tEnd)`

#### `[tMin, tMax] = getTimeRange(obj)`

#### `t = getEventTimes(obj)`

GETEVENTTIMES Event start times from resolveEvents (override).
  Mirrors the same filtering pipeline the widget uses to draw
  bars, so the time-slider overlay always matches what the
  widget itself renders.

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `EventTimelineWidget.obj = fromStruct(s)`

---

## `DashboardSerializer` --- JSON load/save and .m export for dashboard configs.

### Static Methods

#### `DashboardSerializer.save(config, filepath)`

SAVE Write dashboard config as a MATLAB function file.
  The output is a function returning a DashboardEngine.

#### `DashboardSerializer.saveJSON(config, filepath)`

SAVEJSON Write dashboard config struct to JSON file.
 Handles both single-page (widgets field) and multi-page (pages field).
 Widgets/pages may have heterogeneous fields, so encode each entry
 individually and assemble the JSON array by hand.

#### `DashboardSerializer.result = load(filepath)`

LOAD Load dashboard config from file.
  For .m files: uses feval to execute the function and return the engine.
  For .json files: uses legacy JSON parsing.

#### `DashboardSerializer.config = loadJSON(filepath)`

LOADJSON Legacy: read dashboard config from JSON file.

#### `DashboardSerializer.config = widgetsToConfig(name, theme, liveInterval, widgets, infoFile)`

WIDGETSTOCONFIG Build a config struct from widget objects.

#### `DashboardSerializer.config = widgetsPagesToConfig(name, theme, liveInterval, pages, activePage, infoFile)`

WIDGETSPAGESTOCONFIG Build a multi-page config struct from page objects.
  pages is a cell array of DashboardPage objects.
  activePage is the Name string of the active page.

#### `DashboardSerializer.widgets = configToWidgets(config, resolver)`

CONFIGTOWIDGETS Create widget objects from config struct.
  configToWidgets(config) — no sensor resolution
  configToWidgets(config, resolver) — resolver is a function
    handle @(name) that returns a Sensor object by name.

#### `DashboardSerializer.w = createWidgetFromStruct(ws)`

CREATEWIDGETFROMSTRUCT Create a single widget from a struct.

#### `DashboardSerializer.exportScript(config, filepath)`

EXPORTSCRIPT Generate a readable .m script from config.

#### `DashboardSerializer.exportScriptPages(config, filepath)`

EXPORTSCRIPTPAGES Generate a MATLAB function file from a multi-page config.
  The output is a function returning a DashboardEngine so that
  DashboardEngine.load() can use feval(funcname) to reconstruct it.
  Emits d.addPage('Name') + d.switchPage(N) before each page's widget block
  so that addWidget routes to the correct page.

#### `DashboardSerializer.[childLines, varName, groupCount] = emitChildWidget(cw, groupCount)`

EMITCHILDWIDGET Emit .m constructor lines for a child widget.
  Used by DashboardSerializer.save() to emit child code for GroupWidget
  children. Children are created by constructor, not d.addWidget().
  Returns the generated code lines, the variable name assigned, and the
  updated groupCount (in case the child is itself a GroupWidget).

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
| Padding | `[0 0 0 0]` |  |
| GapH | `0` |  |
| GapV | `0` |  |
| RowHeight | `0.22` |  |
| ScrollbarWidth | `0.015` |  |
| OnScrollCallback | `[]` | function handle: @(topRow, bottomRow) |
| DetachCallback | `[]` | function handle: @(widget) — set by DashboardEngine |
| VisibleRows | `[1 Inf]` | [topRow bottomRow] currently visible |
| hFigure | `[]` | Figure handle for popup dismiss callbacks |
| hInfoPopup | `[]` | Handle to active info popup uipanel (at most one) |

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

#### `ensureViewport(obj, hFigure, theme)`

ENSUREVIEWPORT Create viewport/canvas/scrollbar only if they do not exist yet.
  Idempotent: if the viewport handle is already valid, returns immediately
  without deleting or recreating anything. On the first call the viewport,
  canvas, and (if needed) scrollbar are created and TotalRows is reset to 0
  so that subsequent additive allocatePanels calls accumulate row counts.

#### `resetViewport(obj)`

RESETVIEWPORT Destroy the current viewport so the next ensureViewport call rebuilds it.
  Use when a full layout rebuild is required (e.g. single-page reflow).

#### `allocatePanels(obj, hFigure, widgets, theme)`

ALLOCATEPANELS Create placeholder panels for widgets (additive; no viewport destruction).
  Calls ensureViewport (idempotent) to guarantee hViewport/hCanvas exist, then
  accumulates TotalRows and appends widget panels to the shared canvas.
  Multiple calls for different page-widget sets are safe: earlier panels survive.
Ensure viewport exists (idempotent — no-op if already live)

#### `realizeWidget(obj, widget)`

REALIZEWIDGET Render a single widget into its pre-allocated panel.

#### `createPanels(obj, hFigure, widgets, theme)`

CREATEPANELS Create and render all widget panels (legacy path).

#### `reflow(obj, hFigure, widgets, theme)`

Re-run layout after dynamic changes (e.g., group collapse/expand).
Tears down and recreates all panels, calling render() on each widget.

#### `onScroll(obj, val)`

ONSCROLL Adjust canvas position from scrollbar value.
  val=1 shows top, val=0 shows bottom.

#### `rows = computeVisibleRows(obj, scrollVal)`

COMPUTEVISIBLEROWS Derive visible row range from scroll position.

#### `vis = isWidgetVisible(obj, gridPos, buffer)`

ISWIDGETVISIBLE Check if widget rows overlap visible range + buffer.

#### `openInfoPopup(obj, widget, theme)`

OPENINFOPOPUP Open a modal figure window showing widget Description.

#### `closeInfoPopup(obj)`

CLOSEINFOPOPUP Close and delete the active info popup panel.

#### `onFigureClickForDismiss(obj)`

ONFIGURECLICKFORDISMISS Dismiss popup if click was outside the popup panel.

#### `onKeyPressForDismiss(obj, eventData)`

ONKEYPRESSFORDISMISS Dismiss popup when Escape is pressed.

---

## `DashboardToolbar` --- Global toolbar for dashboard controls.

> Inherits from: `handle`

Provides buttons for: Sync, Live (toggle with blue border when active),
  Config (opens DashboardConfigDialog), Image, Export, and Info (always
  present — shows a placeholder page when no InfoFile is configured).
  Every button has a descriptive tooltip. Sits at the top of the
  dashboard figure.

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

#### `setLiveActiveIndicator(obj, isActive)`

SETLIVEACTIVEINDICATOR Show a blue surround when live mode is active.

#### `onConfig(obj)`

ONCONFIG Open the dashboard config dialog.

#### `onExport(obj)`

#### `onImage(obj)`

ONIMAGE Open save dialog and export dashboard figure as PNG/JPEG.
  Pops a uiputfile with PNG+JPEG filters, defaults to the
  sanitized dashboard name plus timestamp. On cancel, returns
  silently. On engine error, surfaces message via warndlg.

#### `dispatchImageExport(obj, file, path, idx)`

DISPATCHIMAGEEXPORT Post-dialog dispatcher — testable without uiputfile.
  file  — filename string, or 0 on user-cancel
  path  — directory path from uiputfile
  idx   — filter index (1=PNG, 2=JPEG). Defaults to PNG.

#### `fname = defaultImageFilename(obj)`

DEFAULTIMAGEFILENAME Build sanitized default filename for the dialog.
  Pattern: {sanitized Engine.Name}_{yyyymmdd_HHMMSS}.png
  Sanitization: replace [/\:*?"<>|] and whitespace with '_'.
  NOTE: datestr format 'yyyymmdd_HHMMSS' (lowercase mm=month here,
  HHMMSS=seconds). This differs from datetime/ISO notation —
  see libs/EventDetection/generateEventSnapshot.m:28 for the
  in-codebase precedent.

#### `onInfo(obj)`

#### `contentArea = getContentArea(obj)`

---

## `BarChartWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = BarChartWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DataFcn | `[]` | @() struct('categories',{},'values',[]) |
| Orientation | `'vertical'` | 'vertical' or 'horizontal' |
| Stacked | `false` |  |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `BarChartWidget.obj = fromStruct(s)`

---

## `ChipBarWidget` --- Horizontal row of mini status chips for system health summary.

> Inherits from: `DashboardWidget`

Displays N colored circle icons with labels in a compact horizontal strip.
  Designed as a dense multi-sensor status overview at a glance.

### Constructor

```matlab
obj = ChipBarWidget(varargin)
```

CHIPBARWIDGET Construct a ChipBarWidget with optional name-value pairs.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Chips | `{}` | Cell array of chip structs (label, statusFcn, sensor, iconColor) |

### Methods

#### `render(obj, parentPanel)`

RENDER Draw all chips in a single shared axes inside parentPanel.

#### `refresh(obj)`

REFRESH Update chip circle colors from statusFcn or sensor state.

#### `t = getType(~)`

GETTYPE Return widget type string.

#### `s = toStruct(obj)`

TOSTRUCT Serialize widget to struct for JSON export.

### Static Methods

#### `ChipBarWidget.obj = fromStruct(s)`

FROMSTRUCT Reconstruct ChipBarWidget from a saved struct.

---

## `DashboardConfigDialog` --- Config editor for a DashboardEngine.

> Inherits from: `handle`

Opens a figure listing every public DashboardEngine property with
  an editable control. Apply writes values back to the engine and
  propagates visible changes (figure title, theme re-render, live
  timer restart). Close dismisses without additional changes.

  Enum-like properties get a popup menu:
    Theme         — {'light', 'dark'}
    ProgressMode  — {'auto', 'on', 'off'}
  Numeric properties get a numeric edit control. Everything else
  gets a plain text edit.

  Usage (usually invoked by the toolbar Config button):
    dlg = DashboardConfigDialog(engine);
    % ...user edits fields, clicks Apply/Close...

### Constructor

```matlab
obj = DashboardConfigDialog(engine)
```

### Methods

#### `close(obj)`

CLOSE Destroy the dialog figure.

#### `apply(obj)`

APPLY Write all control values back to the engine and propagate.

---

## `DashboardPage` --- Named page container within a multi-page dashboard.

> Inherits from: `handle`

Each DashboardPage holds a list of widgets to be rendered when the
  page is active. DashboardEngine maintains a Pages cell array of
  DashboardPage objects and routes addWidget() to the active page.

### Constructor

```matlab
obj = DashboardPage(name)
```

DASHBOARDPAGE Construct a named page container.
  pg = DashboardPage()        creates page with Name = ''
  pg = DashboardPage('Name')  creates page with given Name

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Name | `''` |  |
| Widgets | `{}` |  |

### Methods

#### `w = addWidget(obj, w)`

ADDWIDGET Append widget w to the Widgets list.
  pg.addWidget(w) appends w to obj.Widgets.

#### `s = toStruct(obj)`

TOSTRUCT Serialize the page to a struct with name and widgets fields.
  s = pg.toStruct() returns s.name (char) and s.widgets (cell).

---

## `DashboardProgress` --- Progress-bar helper for DashboardEngine render passes.

> Inherits from: `handle`

Emits a self-updating progress line to stdout as widgets are realized
  during DashboardEngine.render() / rerenderWidgets(), and a final
  summary line on completion.

  Silent outside interactive sessions so test / CI output stays clean.

### Constructor

```matlab
obj = DashboardProgress(name, totalWidgets, totalPages, mode)
```

### Methods

#### `tick(obj, widget, pageIdx, pageName)`

#### `finish(obj)`

---

## `DetachedMirror` --- Standalone live-mirrored widget window for DashboardEngine.

> Inherits from: `handle`

DetachedMirror wraps a cloned DashboardWidget in a standalone MATLAB
  figure window. The clone is produced via toStruct/fromStruct with post-
  clone live-reference restoration for FastSenseWidget and RawAxesWidget.

  The mirror is NOT a DashboardWidget subclass — it wraps one. It belongs
  to DashboardEngine.DetachedMirrors and is ticked by the engine's existing
  LiveTimer via the engine's onLiveTick() loop.

  Usage (called internally by DashboardEngine.detachWidget()):
    theme = DashboardTheme(obj.Theme);
    cb    = @() obj.removeDetached(mirror);
    mirror = DetachedMirror(originalWidget, theme, cb);

  Properties (SetAccess = private):
    hFigure        — standalone MATLAB figure window handle
    hPanel         — full-figure uipanel that hosts the cloned widget
    Widget         — cloned DashboardWidget instance
    RemoveCallback — @() called by onFigureClose() before delete(hFigure)

### Constructor

```matlab
obj = DetachedMirror(originalWidget, themeStruct, removeCallback)
```

DETACHEDMIRROR Create a detached live-mirror window for originalWidget.

### Methods

#### `tick(obj)`

TICK Refresh the cloned widget; no-op if figure is stale.

#### `result = isStale(obj)`

ISSTALE Return true when the mirror's figure has been closed or destroyed.

---

## `DividerWidget` --- Horizontal divider line for visual section separation.

> Inherits from: `DashboardWidget`

DividerWidget renders a horizontal colored line using the theme's
  WidgetBorderColor (or a custom Color override). It is a static widget
  with no data binding.

### Constructor

```matlab
obj = DividerWidget(varargin)
```

DIVIDERWIDGET Construct a DividerWidget.
  obj = DividerWidget() creates with defaults.
  obj = DividerWidget('Thickness', 2, 'Color', [1 0 0]) sets props.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Thickness | `1` | Relative line thickness (1=thin, 2=medium, 3=thick) |
| Color | `[]` | RGB override; empty = use theme WidgetBorderColor |

### Methods

#### `render(obj, parentPanel)`

RENDER Create the divider line inside parentPanel.
  render(obj, parentPanel) creates a uipanel that acts as a
  horizontal colored line centered vertically in the panel.

#### `refresh(~)`

REFRESH No-op for static widget.

#### `t = getType(~)`

GETTYPE Return widget type string.

#### `lines = asciiRender(obj, width, height)`

ASCIIRENDER Return ASCII representation of the divider.
  First line is a row of dashes; remaining lines are blank.

#### `s = toStruct(obj)`

TOSTRUCT Serialize to struct.
  Omits 'thickness' at default (1) and 'color' when empty.

### Static Methods

#### `DividerWidget.obj = fromStruct(s)`

FROMSTRUCT Reconstruct DividerWidget from serialized struct.

---

## `GroupWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = GroupWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Mode | `'panel'` | 'panel', 'collapsible', 'tabbed' |
| Label | `''` | Title shown in header bar |
| Collapsed | `false` | Collapsed state (collapsible mode only) |
| Children | `{}` | Cell array of DashboardWidget (panel/collapsible) |
| Tabs | `{}` | Cell array of struct('name','...','widgets',{{}}) |
| ActiveTab | `''` | Current tab name (tabbed mode) |
| ChildColumns | `24` | Sub-grid column count |
| ChildAutoFlow | `true` | Auto-arrange children |
| ReflowCallback | `[]` | Callback invoked after collapse/expand (injected by DashboardEngine) |

### Methods

#### `addChild(obj, widget, tabName)`

Check nesting depth for GroupWidget children

#### `removeChild(obj, idx)`

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `[tMin, tMax] = getTimeRange(obj)`

GETTIMERANGE Aggregate time range from all children and tabs.

#### `t = getType(obj)`

#### `lines = asciiRender(obj, width, height)`

#### `setTimeRange(obj, tStart, tEnd)`

#### `s = toStruct(obj)`

#### `collapse(obj)`

#### `expand(obj)`

#### `switchTab(obj, tabName)`

### Static Methods

#### `GroupWidget.obj = fromStruct(s)`

---

## `HeatmapWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = HeatmapWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DataFcn | `[]` | function_handle returning matrix |
| Colormap | `'parula'` | colormap name or Nx3 matrix |
| ShowColorbar | `true` |  |
| XLabels | `{}` | cell array of axis labels |
| YLabels | `{}` | cell array of axis labels |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `HeatmapWidget.obj = fromStruct(s)`

---

## `HistogramWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = HistogramWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DataFcn | `[]` |  |
| NumBins | `[]` | empty = auto |
| ShowNormalFit | `false` |  |
| EdgeColor | `[]` | RGB or empty for default |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `HistogramWidget.obj = fromStruct(s)`

---

## `IconCardWidget` --- Compact Mushroom Card-style widget with colored icon, value, and label.

> Inherits from: `DashboardWidget`

Displays a state-colored circle icon at the left, a primary numeric value in
  the center, and a secondary label below the value. Icon color reflects the
  current threshold state (ok/warn/alarm/info/inactive).

### Constructor

```matlab
obj = IconCardWidget(varargin)
```

ICONCARDWIDGET Construct an IconCardWidget with optional name-value pairs.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| IconColor | `'auto'` | RGB triplet or 'auto' (derive from state) |
| StaticValue | `[]` | Fixed static value (number) |
| ValueFcn | `[]` | Function handle returning scalar or struct |
| StaticState | `''` | 'ok','warn','alarm','info','inactive','' |
| Units | `''` | Display units string |
| Format | `'%.1f'` | sprintf format for numeric value |
| SecondaryLabel | `''` | Subtitle text below primary value |
| Threshold | `[]` | Threshold object or registry key string (per D-01) |

### Methods

#### `render(obj, parentPanel)`

RENDER Create icon, value text, and label inside parentPanel.

#### `refresh(obj)`

REFRESH Update icon color, value display, and label.

#### `t = getType(~)`

GETTYPE Return widget type string.

#### `s = toStruct(obj)`

TOSTRUCT Serialize widget to struct for JSON export.

### Static Methods

#### `IconCardWidget.obj = fromStruct(s)`

FROMSTRUCT Reconstruct IconCardWidget from a serialized struct.

---

## `ImageWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = ImageWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| File | `''` | Path to image file (PNG, JPG) |
| ImageFcn | `[]` | function_handle returning image matrix |
| Scaling | `'fit'` | 'fit', 'fill', 'stretch' |
| Caption | `''` |  |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `ImageWidget.obj = fromStruct(s)`

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

---

## `MultiStatusWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = MultiStatusWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Sensors | `{}` | Cell array of Sensor objects |
| Columns | `[]` | Grid columns (empty = auto) |
| ShowLabels | `true` |  |
| IconStyle | `'dot'` | 'dot', 'square', 'icon' |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

Fully override — does not use base Sensor property

### Static Methods

#### `MultiStatusWidget.obj = fromStruct(s)`

---

## `ScatterWidget`

> Inherits from: `DashboardWidget`

### Constructor

```matlab
obj = ScatterWidget(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| SensorX | `[]` | Sensor for X axis |
| SensorY | `[]` | Sensor for Y axis |
| SensorColor | `[]` | Optional: color-code by third sensor |
| MarkerSize | `6` |  |
| Colormap | `'parula'` |  |

### Methods

#### `render(obj, parentPanel)`

#### `refresh(obj)`

#### `t = getType(~)`

#### `lines = asciiRender(obj, width, height)`

#### `s = toStruct(obj)`

### Static Methods

#### `ScatterWidget.obj = fromStruct(s)`

---

## `SparklineCardWidget` --- KPI card combining a big-number display with a mini sparkline chart and delta indicator.

> Inherits from: `DashboardWidget`

w = SparklineCardWidget('Title', 'CPU', 'StaticValue', 42.0, ...
                          'SparkData', cpuHistory, 'Units', '%');

  The card is divided into three zones:
    Top row   — title (left) and delta indicator (right)
    Middle    — large primary value
    Bottom    — sparkline mini-chart (bottom 35% of card)

  Data binding (three-path, resolved in priority order):
    1. Sensor   — uses Sensor.Y for both value and sparkline
    2. ValueFcn — function_handle returning scalar or struct
    3. StaticValue + SparkData — static numeric value with separate sparkline vector

  Properties:
    StaticValue  — fixed scalar value
    ValueFcn     — function handle returning scalar or struct(.value, .unit)
    Units        — display unit string
    Format       — sprintf format for primary value (default '%.1f')
    NSparkPoints — number of tail points shown in sparkline (default 50)
    ShowDelta    — show delta indicator (default true)
    DeltaFormat  — sprintf format for delta (default '%+.1f')
    SparkColor   — sparkline line color; empty => theme.DragHandleColor
    SparkData    — numeric vector for sparkline (used when no Sensor)

### Constructor

```matlab
obj = SparklineCardWidget(varargin)
```

SPARKLINECARDWIDGET Construct a SparklineCardWidget.
  Accepts name-value pairs for any public property.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| StaticValue | `[]` | Fixed scalar value displayed in the card |
| ValueFcn | `[]` | Function handle returning scalar or struct |
| Units | `''` | Unit label appended to primary value |
| Format | `'%.1f'` | sprintf format string for primary value |
| NSparkPoints | `50` | Number of tail data points in sparkline |
| ShowDelta | `true` | Whether to show the delta indicator |
| DeltaFormat | `'%+.1f'` | sprintf format string for delta value |
| SparkColor | `[]` | Sparkline line color (empty = theme default) |
| SparkData | `[]` | Numeric vector for sparkline (alternative to Sensor) |

### Methods

#### `render(obj, parentPanel)`

RENDER Create all graphics objects inside parentPanel.

#### `refresh(obj)`

REFRESH Update displayed value, sparkline, and delta indicator.

#### `t = getType(~)`

GETTYPE Return widget type string.

#### `s = toStruct(obj)`

TOSTRUCT Serialize widget to a struct for JSON export.

### Static Methods

#### `SparklineCardWidget.obj = fromStruct(s)`

FROMSTRUCT Deserialize a SparklineCardWidget from a struct.

---

## `TimeRangeSelector` --- Single-window time-range selector with data-preview envelope.

> Inherits from: `handle`

selector = TimeRangeSelector(hPanel) attaches a time-range selector to a
  uipanel. The selector owns its own axes inside the panel and draws:

      * an (optional) aggregate min/max envelope patch behind the selection,
      * a semi-transparent selection rectangle that can be panned by dragging
        its middle and resized by dragging either of its two edge handles,
      * two line handles at the left and right edges of the selection window.

  Interaction uses figure-level WindowButton{Down,Motion,Up}Fcn. Any previously
  installed callbacks are saved on construction and restored on delete().

  Usage (the contract plan 03 uses to wire this into DashboardEngine):

      selector = TimeRangeSelector(hPanel, ...
          'OnRangeChanged', @(tStart, tEnd) onRangeChanged(tStart, tEnd), ...
          'Theme',          themeStruct);
      selector.setDataRange(tMin, tMax);        % full extent user can scrub
      selector.setSelection(tStart, tEnd);      % fires OnRangeChanged
      selector.setEnvelope(xC, yMin, yMax);     % optional preview
      [tS, tE] = selector.getSelection();
      delete(selector);                         % restores figure callbacks

  Properties (public, configurable):
      OnRangeChanged  Function handle @(tStart, tEnd). May be [].
      Theme           Theme struct (or []).
      MinWidthFrac    Minimum selection width as fraction of DataRange span.
      EdgeTolPx       Pixel tolerance for edge hit-testing.

  Properties (read-only, set internally):
      hPanel, hFigure, hAxes, hEnvelope, hSelection, hEdgeLeft, hEdgeRight
      DataRange       1x2 [tMin tMax].
      Selection       1x2 [tStart tEnd].
      DragState       'idle' | 'panning' | 'resizeLeft' | 'resizeRight'.

  Methods:
      setDataRange(tMin, tMax)         Set full extent; rescales selection.
      setSelection(tStart, tEnd)       Set/clamp/reorder selection; fires callback.
      getSelection()                   Return [tStart, tEnd].
      setEnvelope(xC, yMin, yMax)      Update or hide aggregate envelope.
      delete()                         Restore saved figure callbacks.

  Compatible with MATLAB R2020b+ and Octave 7+ (D-11): uses only axes, patch,
  line, uipanel primitives and WindowButton{Down,Motion,Up}Fcn — no
  matlab.graphics.*, no uifigure/uiaxes, no addlistener on primitive properties.

### Constructor

```matlab
obj = TimeRangeSelector(hPanel, varargin)
```

TimeRangeSelector  Construct a selector attached to a uipanel.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| OnRangeChanged | `[]` | function handle @(tStart, tEnd) |
| Theme | `[]` | struct from DashboardTheme, or [] |
| MinWidthFrac | `0.005` | minimum selection width as fraction of DataRange span |
| EdgeTolPx | `10` | pixel tolerance for edge hit-test |

### Methods

#### `setDataRange(obj, tMin, tMax)`

setDataRange  Set the full extent the user can scrub over.
  The current selection is rescaled proportionally so that a
  50%-selected window remains 50% wide after the change.
  Programmatic — does NOT fire OnRangeChanged; only user
  drag interactions do.

#### `setSelection(obj, tStart, tEnd)`

setSelection  Update the selection window, clamping and reordering.
  Swapped inputs (tStart > tEnd) are reordered. Values outside
  DataRange are clamped. Widths smaller than MinWidthFrac * span
  are widened around the requested midpoint. Fires OnRangeChanged
  with the final [tStart, tEnd] (if the callback is set).
Reorder swapped bounds (tStart < tEnd).

#### `[tStart, tEnd] = getSelection(obj)`

getSelection  Return the current selection as [tStart, tEnd].

#### `setLabels(obj, leftText, rightText)`

setLabels  Update the inline edge labels that track the selection.
  Pass empty strings to hide a side's label. The text sits at the
  mid-height of the selector, inside each edge handle.

#### `setEnvelope(obj, xC, yMin, yMax)`

setEnvelope  (Legacy) Draw the aggregate min/max preview envelope.
  Kept for backward compat with tests. New code should prefer
  setPreviewLines for per-widget line previews.

#### `setPreviewLines(obj, lines)`

setPreviewLines  Draw one downsampled line per widget preview.
  lines is a cell array of structs, each with fields x and y
  (equal-length row vectors; y already normalized to [0,1]).
  Each line is rendered with a distinct color from a fixed
  palette, placed behind the selection rectangle so drag
  interactions remain unaffected.
Clear previous preview lines.

#### `setEventMarkers(obj, times)`

setEventMarkers  Draw a faint full-height line per event time.
  setEventMarkers(times) clears any existing markers and draws
  one vertical line per finite time in `times`. Non-finite
  values (NaN, +/-Inf) are silently dropped. Empty input just
  clears the markers.

