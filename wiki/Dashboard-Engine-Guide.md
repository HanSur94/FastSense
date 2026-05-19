<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, multi‑page layouts, group containers, and a visual editor.

---

## Overview

DashboardEngine is the top‑level orchestrator for complex dashboards. It supports 13+ widget types, per‑widget sensor binding via `Tag` objects, multi‑page layouts, group containers (collapsible/tabbed), live data polling, global time controls, and a drag‑and‑drop visual editor.

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24‑column responsive |
| Tile content | FastSense instances only | 13+ widget types |
| Persistence | None | JSON save/load + .m script export |
| Multi‑page | No | Yes (switchPage) |
| Containers | No | GroupWidget (panel/collapsible/tabbed) |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets |

**When to use FastSenseGrid:** You need a lightweight tiled grid of FastSense time‑series plots with linked axes.

**When to use DashboardEngine:** You need mixed widget types, containers, multi‑page layouts, JSON persistence, or the visual editor.

---

## Quick Start

```matlab
install;

% Create some data
x = linspace(0, 100, 10000);
y = sin(x) + 0.1 * randn(size(x));

% Build a dashboard
d = DashboardEngine('My First Dashboard');
d.Theme = 'dark';

d.addWidget('fastsense', ...
    'Position', [1 1 24 6], ...
    'XData', x, 'YData', y);

d.addWidget('number', ...
    'Title', 'Latest Value', ...
    'Position', [1 7 8 2], ...
    'StaticValue', y(end), ...
    'Units', 'V');

d.render();
```

---

## Grid System

DashboardEngine uses a **24‑column grid**. Widget positions are specified as:

```
Position = [col, row, width, height]
```

- `col`: column (1‑24), left to right  
- `row`: row (1+), top to bottom  
- `width`: span in columns (1‑24)  
- `height`: span in rows  

Examples:
```matlab
[1 1 24 4]   % Full width, 4 rows tall
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

If a new widget overlaps an existing one, it is automatically pushed to the next free row.

---

## Widget Types

All widget classes are instantiated via `d.addWidget(type, ...)`. The following built‑in types are available:

### FastSense – Time Series

```matlab
% Sensor‑bound (recommended)
d.addWidget('fastsense', 'Sensor', mySensor, 'Position', [1 1 12 8]);

% Inline data
d.addWidget('fastsense', 'Title', 'Raw', 'Position', [13 1 12 8], ...
    'XData', x, 'YData', y);

% From MAT file
d.addWidget('fastsense', 'Title', 'File', 'Position', [1 9 24 6], ...
    'File', 'data.mat', 'XVar', 'x', 'YVar', 'y');

% From DataStore
d.addWidget('fastsense', 'Title', 'Store', 'Position', [1 15 24 6], ...
    'DataStore', myDataStore);
```

When bound to a Sensor (via `'Sensor'`, or `'Tag'` in the v2.0 API), title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived. Threshold rules are applied automatically and resolved violations shown.

### Number – Big Value Display

```matlab
% Sensor‑bound
d.addWidget('number', 'Title', 'Temperature', 'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', 'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Function callback
d.addWidget('number', 'Title', 'CPU Load', 'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data.

### Status – Health Indicator

```matlab
% Sensor‑bound (state derived from thresholds)
d.addWidget('status', 'Title', 'Pump', 'Position', [7 1 5 2], 'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', 'Position', [12 1 5 2], 'StaticStatus', 'ok');
```

Displays a colored dot (green/amber/red) plus the sensor’s latest value. Status color is resolved from threshold rules.

### Gauge – Arc / Donut / Bar / Thermometer

```matlab
% Sensor‑bound
d.addWidget('gauge', 'Title', 'Flow Rate', 'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Range', [0 160], 'Units', 'L/min', 'Style', 'donut');

% Static value
d.addWidget('gauge', 'Title', 'Efficiency', 'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', 'Style', 'arc');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When bound to a Sensor, range and units are auto‑derived.

### Table – Data Display

```matlab
% Static data
d.addWidget('table', 'Title', 'Alarm Log', 'Position', [13 9 12 4], ...
    'ColumnNames', {'Time', 'Tag', 'Value'}, ...
    'Data', {{'12:00', 'T-401', '85.2'; '12:05', 'P-201', '72.1'}};

% Sensor last N rows
d.addWidget('table', 'Title', 'Recent Data', 'Position', [1 9 12 4], ...
    'Sensor', sTemp, 'N', 15);

% Dynamic data via callback
d.addWidget('table', 'Title', 'Live Log', 'Position', [1 13 12 4], ...
    'DataFcn', @() getRecentAlarms(), 'ColumnNames', {'Time', 'Tag', 'Value', 'Level'});

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', 'Position', [1 17 12 4], ...
    'Sensor', mySensor, 'EventStoreObj', myEventStore, 'Mode', 'events');
```

### Raw Axes – Custom MATLAB Plots

```matlab
% Simple histogram
d.addWidget('rawaxes', 'Title', 'Temperature Distribution', ...
    'Position', [1 5 8 4], ...
    'PlotFcn', @(ax) histogram(ax, tempData, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

% Sensor‑bound with time range
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Sensor', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

The `PlotFcn` receives a single MATLAB axes handle. When bound to a Sensor, it also receives the Sensor object and/or the current time range, depending on the function’s `nargin`.

### Event Timeline

```matlab
% From event structs
events = struct('startTime', {0, 3600}, 'endTime', {3600, 7200}, ...
    'label', {'Idle', 'Running'}, 'color', {[0.6 0.6 0.6], [0.2 0.7 0.3]});

d.addWidget('eventtimeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], ...
    'Events', events);

% From EventStore (recommended)
d.addWidget('eventtimeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], ...
    'EventStoreObj', myEventStore);

% Filter by sensor names
d.addWidget('eventtimeline', 'Title', 'Temp Events', ...
    'Position', [1 19 24 3], ...
    'EventStoreObj', myEventStore, ...
    'FilterSensors', {'T-401', 'T-402'});
```

Bars are colored by event label or Theme palette (`StatusOkColor`, `StatusWarnColor`, `StatusAlarmColor`).

### Modern KPI Cards

Newer compact widgets replace the classic NumberWidget in many designs.

**IconCardWidget** – Mushroom‑style card with icon, value, label:
```matlab
d.addWidget('iconcard', ...
    'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'StaticValue', 23.5, 'Units', 'degC', ...
    'StaticState', 'ok');   % auto‑derive color from state
```

**SparklineCardWidget** – KPI with inline sparkline:
```matlab
d.addWidget('sparklinecard', ...
    'Title', 'CPU', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 42.0, ...
    'SparkData', cpuHistory, ...
    'Units', '%');
```

### Specialty Widgets

- **BarChartWidget** – vertical/horizontal bar chart via `staticValue` or `DataFcn`.
- **HistogramWidget** – dynamic histogram via `DataFcn`.
- **HeatmapWidget** – heatmap from matrix data.
- **ScatterWidget** – X‑Y scatter with optional color sensor.
- **ImageWidget** – display PNG/JPG images.
- **DividerWidget** – horizontal rule for visual separation.
- **TextWidget** – static label / section header.
- **ChipBarWidget** – compact row of colored status chips (health overview).
- **MultiStatusWidget** – multiple Sensor status dots.

All follow the same `addWidget` pattern and the standard `Position` grid.

---

## Sensor Binding

Bind widgets to any object with a `.Y` property (typically a Sensor, LiveTag, or MonitorTag):

```matlab
% Sensor‑bound widgets derive title, units, value, thresholds automatically
d.addWidget('fastsense', 'Sensor', mySensor, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', mySensor, 'Units', 'bar', 'Format', '%.1f');
d.addWidget('status', 'Sensor', mySensor);
d.addWidget('gauge', 'Sensor', mySensor, 'Style', 'arc');
```

When bound:
- **Title:** auto‑derived from `Sensor.Name` or `Sensor.Key`.
- **Units:** auto‑derived from `Sensor.Units`.
- **Value:** always `Sensor.Y(end)` for number / gauge / status.
- **Thresholds:** automatically drawn and resolved on FastSense charts.

The `'Sensor'` NV pair is a backwards‑compatible alias for the v2.0 `'Tag'` property.

---

## Multi‑Page Dashboards

Dashboards can contain multiple named pages. Widgets are added to the active page:

```matlab
d = DashboardEngine('Process Monitor');
d.addPage('Overview');
d.addWidget('text', 'Title', 'Plant1', 'Content', 'Plant A Overview', ...);
d.addWidget('fastsense', 'Sensor', sTemp, ...);

d.addPage('Details');
d.addWidget('table', 'Title', 'Alarm Log', ...);

% Explicit page switching
d.switchPage(1);   % 'Overview'
d.switchPage(2);   % 'Details'
```

Pages are saved/loaded with the dashboard config.

---

## GroupWidget & Containers

GroupWidget lets you nest widgets inside a panel, collapsible section, or tabbed container:

```matlab
% Simple panel group
wGroup = GroupWidget('Label', 'Sensor Panel', 'Position', [1 1 24 8]);
wGroup.addChild(wSensorPlot);
wGroup.addChild(wSensorTable);
d.addWidget(wGroup);

% Collapsible group
d.addCollapsible('Sensor Details', {w1, w2}, 'Collapsed', false);

% Tabbed container
wTab = GroupWidget('Mode', 'tabbed', 'Label', 'Tabs');
wTab.addChild(wTrend, 'Trend');
wTab.addChild(wHistogram, 'Histogram');
d.addWidget(wTab);
```

The visual editor (Edit mode) also provides UI controls for children arrangement.

---

## Saving and Loading

### Save to JSON / Reconstruct from .m

```matlab
d.save('dashboard.json');        % JSON export
d.exportScript('rebuild.m');     % human‑readable MATLAB script
```

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re‑bind Sensor objects, supply a resolver that returns an object with a `.Y` property:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

The `.m` script recreates the dashboard with `addWidget` calls — no data dependency.

---

## Theming

DashboardEngine uses the `DashboardTheme` function (which extends `FastSenseTheme`):

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';      % or 'light' (default supports legacy aliases)
d.render();
```

Available presets: `'light'`, `'dark'`. Legacy preset names are aliased to `'light'`.

For full control, provide a struct with `DashboardTheme` options:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.05 0.05 0.15]);
d.Theme = theme;
```

Key dashboard‑specific fields: `DashboardBackground`, `WidgetBackground`, `WidgetBorderColor`, `ToolbarBackground`, `ToolbarFontColor`, `StatusOkColor`, `StatusWarnColor`, `StatusAlarmColor`, etc.

---

## Live Mode

Enable polling of all bound sensors:

```matlab
d.LiveInterval = 2;   % seconds
d.render();
d.startLive();       % start background timer
```

The toolbar provides a **Live** toggle with a blue border when active. The timer calls `refresh()` on every widget (and all detached mirrors). Time‑range labels update each tick. If a bound sensor’s maximum time hasn’t advanced, a **stale‑data banner** may appear at the top of the dashboard (dismissible).

---

## Global Time Controls

The bottom time‑panel has dual sliders controlling the visible time range across **all** widgets on **all pages**. Moving a handle calls `setTimeRange(tStart, tEnd)` on every widget that has `UseGlobalTime = true`.

If a user manually zooms a widget (drag/scroll on its axes), `UseGlobalTime` becomes `false` for that widget, detaching it from the sliders. Click the **Sync** toolbar button to re‑attach all widgets.

The slider also shows:
- A **grey envelope** showing the aggregate min/max envelope of all series (preview) — controlled by `dataPreview`, and
- **Event markers** as vertical tick marks if the `EventMarkersVisible` flag is `true` (default). The toolbar **E** button toggles global event‑marker visibility.

---

## Visual Editor

Activate the visual editor via the **Edit** toolbar button. This enters a drag‑and‑drop mode:

1. A **widget palette** sidebar appears with buttons for each type.
2. A **properties panel** shows the selected widget’s settings.
3. **Drag handles** reposition widgets; **resize handles** change dimensions.
4. Click **Apply** to save property changes.
5. Click **Done** to exit edit mode.

Widget snapping follows the 24‑column grid. You can also add/delete widgets programmatically:

```matlab
builder = DashboardBuilder(d);
builder.addWidget('rawaxes');
builder.deleteSelected();
```

---

## Info File Integration

Link external Markdown documentation:

```matlab
d.InfoFile = 'dashboard_help.md';  % Markdown file
d.render();
```

An **Info** button (toolbar) renders the file to HTML and displays it inside a modal panel. When `InfoFile` is empty, a placeholder page describes the feature.

---

## Complete Example

Multi‑sensor process dashboard with modern and classic widgets:

```matlab
%% Generate data
rng(42);
t = linspace(0, 86400, 10000);   % 24 hours
temp = 74 + 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
press = 55 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;

% Create sensors
sTemp = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degF', ...
    'X', t, 'Y', temp);
sPress = Sensor('P-201', 'Name', 'Pressure', 'Units', 'psi', ...
    'X', t, 'Y', press);

%% Build dashboard
d = DashboardEngine('Plant Overview', 'Theme', 'light', 'LiveInterval', 5);

% Header – title bar
d.addWidget('text', 'Title', 'Plant Globals', ...
    'Position', [1 1 24 1], 'Content', 'Line 4 · Shift A', 'FontSize', 16);

% Top row – compact KPI cards
d.addWidget('sparklinecard', 'Title', 'Temperature', ...
    'Position', [1 2 6 2], 'Sensor', sTemp, 'Units', 'degF');
d.addWidget('sparklinecard', 'Title', 'Pressure', ...
    'Position', [7 2 6 2], 'Sensor', sPress, 'Units', 'psi');
d.addWidget('iconcard', 'Title', 'System', ...
    'Position', [13 2 4 2], 'StaticValue', 1, 'StaticState', 'ok');
d.addWidget('divider', 'Position', [17 2 1 2]);

% Time‑series charts
d.addWidget('fastsense', 'Position', [1 4 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 4 12 8], 'Sensor', sPress);

% Status panel and event timeline
d.addWidget('status', 'Position', [1 12 6 2], 'Sensor', sTemp);
d.addWidget('eventtimeline', 'Title', 'Machine Modes', ...
    'Position', [7 12 18 4], 'EventStoreObj', myEventStore);

d.render();
d.startLive();
```

---

## See Also

- [[API Reference: Dashboard]] – Full API for DashboardEngine, DashboardWidget, and all widget subclasses.
- [[API Reference: Sensors]] – Sensor, StateChannel, ThresholdRule.
- [[Live Mode Guide]] – Live data polling in depth.
- [[Examples]] – `example_dashboard_engine`, `example_all_widgets`, and more.
