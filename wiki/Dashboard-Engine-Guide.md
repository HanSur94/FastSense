<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, multi‑page layouts, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows x cols | 24‑column responsive |
| Tile content | FastSense instances only | 14 widget types (charts, KPIs, gauges, tables, etc.) |
| Grouping | None | GroupWidget (panel / collapsible / tabbed) |
| Multi‑page | No | Named pages with tab bar |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders with data‑preview envelope |
| Sensor binding | Via addSensor per tile | Direct widget property (auto‑title, auto‑units) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets |
| Stale detection | No | Pro‑active stale‑data banner |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines, sparklines, icon cards), multi‑page support, JSON persistence, or the visual editor.

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

d.addWidget('fastsense', 'Title', 'Signal', ...
    'Position', [1 1 24 6], ...
    'XData', x, 'YData', y);

d.addWidget('number', 'Title', 'Latest Value', ...
    'Position', [1 7 8 2], ...
    'StaticValue', y(end), 'Units', 'V');

d.render();
```

---

## Grid System

DashboardEngine uses a **24‑column grid**. Widget positions are specified as:

```
Position = [col, row, width, height]
```

- `col`: column (1–24), left to right
- `row`: row (1+), top to bottom
- `width`: number of columns to span (1–24)
- `height`: number of rows to span

Examples:
```matlab
[1 1 24 4]   % Full width, 4 rows tall, top of dashboard
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

If a new widget overlaps an existing one, it is automatically pushed down to the next free row. The layout wraps content into a scrollable canvas when it exceeds the figure height.

---

## Widget Types

Widgets are added with `addWidget('type', 'Name', value, ...)` or by passing a pre‑constructed widget object. The following types are available:

### FastSense (time series)

```matlab
% Sensor‑bound (recommended)
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', mySensor);

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

When bound to a Sensor, threshold rules apply automatically (resolved violations are shown). The widget title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived. Additional properties: `Thresholds` (`'auto'` or off), `YLimits` (manual), `ShowThresholdLabels`, `ShowEventMarkers`, `LiveViewMode` (`'preserve'` or `'follow'`).

### Number (big value display)

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Or with static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Or with function callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data. Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', 'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Threshold‑based (no Sensor)
d.addWidget('status', 'Title', 'Warning', ...
    'Position', [12 1 5 2], ...
    'Threshold', myThreshold, 'Value', 85);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], 'StaticStatus', 'ok');
```

Shows a colored dot (green/amber/red) and the sensor’s latest value. Status is derived automatically from threshold rules or via `StatusFcn` / `StaticStatus`.

### Gauge (arc/donut/bar/thermometer)

```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Range', [0 160], 'Units', 'L/min', ...
    'Style', 'donut');

% Static value
d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', ...
    'Style', 'arc');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When Sensor‑bound, range and units are auto‑derived from threshold rules and sensor properties.

### Text (labels and headers)

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 – Shift A', 'FontSize', 16, ...
    'Alignment', 'center');
```

### Table (data display)

```matlab
% Static data
d.addWidget('table', 'Title', 'Alarm Log', ...
    'Position', [13 9 12 4], ...
    'ColumnNames', {'Time', 'Tag', 'Value'}, ...
    'Data', {{'12:00', 'T-401', '85.2'; '12:05', 'P-201', '72.1'}});

% Sensor data (last N rows)
d.addWidget('table', 'Title', 'Recent Data', ...
    'Position', [1 9 12 4], ...
    'Sensor', sTemp, 'N', 15);

% Dynamic data via callback
d.addWidget('table', 'Title', 'Live Log', ...
    'Position', [1 13 12 4], ...
    'DataFcn', @() getRecentAlarms(), ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Level'});

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Sensor', mySensor, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

### Raw Axes (custom plots)

```matlab
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

The `PlotFcn` receives MATLAB axes as the first argument. When Sensor‑bound, it also receives the Sensor object and optionally a time range.

### Event Timeline

```matlab
% From event structs
events = struct('startTime', {0, 3600}, 'endTime', {3600, 7200}, ...
    'label', {'Idle', 'Running'}, 'color', {[0.6 0.6 0.6], [0.2 0.7 0.3]});

d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], ...
    'Events', events);

% From EventStore (recommended)
d.addWidget('timeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], ...
    'EventStoreObj', myEventStore);

% Filtered by sensor names
d.addWidget('timeline', 'Title', 'Temp Events', ...
    'Position', [1 19 24 3], ...
    'EventStoreObj', myEventStore, ...
    'FilterSensors', {'T-401', 'T-402'});
```

### BarChart Widget

```matlab
d.addWidget('barchart', 'Title', 'Category Values', ...
    'Position', [1 9 12 6], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, ...
                          'values', [10 20 15]));
% or pass custom orientation/stacked flag
d.addWidget('barchart', 'Title', 'Stacked', ...
    'Position', [13 9 12 6], ...
    'DataFcn', @dataFn, 'Orientation', 'horizontal', 'Stacked', true);
```

### Histogram Widget

```matlab
d.addWidget('histogram', 'Title', 'Value Distribution', ...
    'Position', [1 7 12 5], ...
    'DataFcn', @getDataVector, 'NumBins', 30, ...
    'ShowNormalFit', true);
```

### Heatmap Widget

```matlab
d.addWidget('heatmap', 'Title', 'Matrix', ...
    'Position', [1 12 12 6], ...
    'DataFcn', @() randn(10,15), 'Colormap', 'turbo', ...
    'ShowColorbar', true, ...
    'XLabels', arrayfun(@num2str, 1:15, 'UniformOutput', false), ...
    'YLabels', arrayfun(@num2str, 1:10, 'UniformOutput', false));
```

### Scatter Widget

```matlab
d.addWidget('scatter', 'Title', 'X vs Y', ...
    'Position', [1 18 12 6], ...
    'SensorX', sX, 'SensorY', sY, 'MarkerSize', 6);
% Optionally color by a third sensor: 'SensorColor', sZ, 'Colormap', 'parula'
```

### Image Widget

```matlab
d.addWidget('image', 'Title', 'Logo', ...
    'Position', [1 0 6 2], ...
    'File', 'company_logo.png', 'Scaling', 'fit', 'Caption', 'ACME Inc.');
% Or via callback: 'ImageFcn', @() read_image_from_camera()
```

### Divider Widget

```matlab
d.addWidget('divider', 'Position', [1 5 24 1]);
d.addWidget('divider', 'Thickness', 2, 'Color', [0.8 0.2 0.2], 'Position', [1 10 24 1]);
```

### SparklineCard Widget

Combines a large single value, a mini sparkline chart, and a delta indicator.

```matlab
d.addWidget('sparkline', 'Title', 'CPU Load', ...
    'Position', [1 0 6 3], ...
    'Sensor', cpuSensor, 'Units', '%', ...
    'NSparkPoints', 60, 'ShowDelta', true);
% Or using static value + historical vector:
d.addWidget('sparkline', 'StaticValue', 42.5, 'SparkData', cpuHistory, ...
    'Units', '%', 'Position', [7 0 6 3]);
```

### IconCard Widget

A Mushroom‑style card: colored icon dot + primary value + subtitle.

```matlab
d.addWidget('iconcard', 'Title', 'Temp', ...
    'Position', [1 0 4 2], ...
    'Sensor', sTemp, 'Units', '°C', 'Format', '%.1f');
% With explicit state color
d.addWidget('iconcard', 'Title', 'Pump', ...
    'Position', [6 0 4 2], ...
    'StaticState', 'alarm', 'StaticValue', 0, 'Units', 'bar');
```

### ChipBar Widget

A row of mini status chips for a compact multi‑sensor overview.

```matlab
chips = {
    struct('label', 'Pump',  'statusFcn', @() 'ok'),
    struct('label', 'Tank',  'statusFcn', @() 'warn'),
    struct('label', 'Fan',   'sensor', sFan)
};
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 0 12 1], 'Chips', chips);
```

### MultiStatus Widget

A grid of status indicators for multiple sensors.

```matlab
d.addWidget('multistatus', 'Title', 'All Sensors', ...
    'Position', [1 0 12 2], ...
    'Sensors', {sTemp, sPress, sFlow}, ...
    'IconStyle', 'square', 'Columns', 3, 'ShowLabels', true);
```

### GroupWidget

Container widget for layout grouping. Supports three modes:

- **panel** — static container with optional label
- **collapsible** — expand/contract section (can be toggled via dashboard UI)
- **tabbed** — tabs inside the widget area

```matlab
% Panel group
g = GroupWidget('Mode', 'panel', 'Label', 'Sensor Suite', ...
    'Position', [1 5 24 10]);
g.addChild(FastSenseWidget('Sensor', sTemp));
g.addChild(NumberWidget('Sensor', sTemp));
d.addWidget(g);

% Collapsible group via convenience method
d.addCollapsible('Live KPIs', {kpi1, kpi2, kpi3}, ...
    'Position', [1 0 24 6]);

% Tabbed group
g = GroupWidget('Mode', 'tabbed', 'Position', [1 5 24 12]);
g.addChild(tab1widget, 'Overview');
g.addChild(tab2widget, 'Details');
d.addWidget(g);
```

GroupWidget supports automatic child flow (`ChildAutoFlow`, default true) and a configurable sub‑column count (`ChildColumns`).

> **Depths and nesting:** GroupWidget children are recursively checked for excessive nesting during `addChild`. Keep groups shallow for clarity.

---

## Sensor Binding

The recommended way to drive dashboard widgets is through Sensor objects. Create sensors with data, state channels, and threshold rules, then bind them to widgets:

```matlab
% Create and configure sensor
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;

sc = StateChannel('machine');
sc.X = [0 7200 43200]; sc.Y = [0 1 0];
sTemp.addStateChannel(sc);

sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% All of these auto‑derive from the Sensor:
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status', 'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Sensor', sTemp, 'Position', [13 3 12 6]);
```

Benefits of Sensor binding:
- **Title:** auto‑derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto‑derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, status widgets
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations
- **Status:** StatusWidget checks the latest value against all threshold rules
- **Live refresh:** calling `refresh()` re‑reads the sensor data

> **Backward compatibility:** The `'Sensor'` name‑value pair is an alias for the underlying `'Tag'` property (v2.0 Tag API). Both work identically.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colors, status indicator colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'light';  % or 'dark'
d.render();
```

Available presets: `'light'`, `'dark'`. Legacy preset names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are aliased to `'light'`.

You can also override specific theme properties:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

Theme is applied to the figure background, toolbar, time selector, and all widgets. Widgets can have a local `ThemeOverride` struct for per‑widget tweaks.

See [[Themes|API Reference: Themes]] for a full list of dashboard‑specific fields.

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON file contains the dashboard name, theme, live interval, grid settings, and each widget’s type, title, position, and data source.

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re‑bind Sensor objects on load, provide a resolver function:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### Export as MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` file with `DashboardEngine` constructor and `addWidget` calls that recreates the dashboard. The script is a function returning a `DashboardEngine` instance, suitable for `DashboardEngine.load()` to `feval`.

### Save and Load Multi‑page Dashboards

Multi‑page dashboards (see below) save all pages and the active page index automatically. Loading with a `SensorResolver` works across all pages.

---

## Live Mode

DashboardEngine supports live data updates via a timer that periodically calls `refresh()` on all widgets.

```matlab
d = DashboardEngine('Live Monitor');
d.Theme = 'dark';
d.LiveInterval = 2;  % refresh every 2 seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % start periodic refresh
% ... later
d.stopLive();    % stop
```

You can also toggle live mode from the toolbar’s **Live** button (highlighted with a blue border when active). The toolbar shows the last update timestamp.

During live mode:
- A stale‑data banner appears at the top if any widget’s latest timestamp fails to advance after a tick.
- The **Follow** toggle on the toolbar forces all FastSense widgets into `LiveViewMode = 'follow'`, snapping charts to the current data tail.

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget.

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the PlotFcn
- **GroupWidget:** recursively forwards to children

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets (also called “Reset”).

The time‑range selector also shows a preview envelope (aggregated min/max across all FastSense widgets) and event markers from any bound event stores.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type
2. A **properties panel** appears on the right showing the selected widget’s settings
3. **Drag handles** let you reposition widgets on the grid
4. **Resize handles** let you change widget dimensions
5. Click **Apply** to save property changes
6. Click **Done** to exit edit mode

Widget management functions (programmatic):
- `addWidget(type)` — add a new widget of the specified type
- `deleteWidget(idx)` — remove widget by index
- `selectWidget(idx)` — select a widget for property editing
- `setWidgetPosition(idx, pos)` — move/resize widget programmatically

The editor snaps to the 24‑column grid. You can change the widget’s title, position, axis labels, and data source directly in the properties panel.

---

## Multi‑Page Dashboards

Dashboards can have multiple pages (tabs) via `addPage` and `switchPage`.

```matlab
d = DashboardEngine('Multi‑Page Monitor', 'Theme', 'dark');

% Create and populate first page
pg1 = d.addPage('Overview');
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);

% Second page
d.addPage('Details');
d.addWidget('table', 'Sensor', sTemp, 'Position', [1 1 24 8]);

d.render();
```

The `addPage(name)` method creates a new page, sets it as active, and returns a `DashboardPage` object. Subsequent `addWidget` calls go to the active page. `switchPage(idx)` changes the visible tab.

Multi‑page dashboards are fully serializable.

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML and displays it in an in‑app modal window (MATLAB R2020b+). If the modal cannot be created, the system browser is used. Supports basic Markdown syntax including headings, lists, code blocks, tables, and images.

When no `InfoFile` is set, a placeholder page explains how to attach custom documentation.

---

## Detaching Widgets

Any widget can be popped out into its own standalone figure window for a quick live‑mirror view:

```matlab
mirror = d.detachWidget(myWidget);
% The engine ticks the mirror on each live tick.
% Closing the mirror window cleans up automatically.
```

This is useful for focusing on a single plot during live monitoring without giving up the main dashboard.

---

## Complete Example

This example builds a process monitoring dashboard with sensors, multiple widget types, and groups.

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours

% Machine mode state channel
scMode = StateChannel('machine');
scMode.X = [0, 3600, 7200, 28800, 36000];
scMode.Y = [0, 1,    1,    2,     1    ];

% Temperature sensor
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = 74 + 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
sTemp.addStateChannel(scMode);
sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, ...
    'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% Pressure sensor
sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'psi';
sPress.X = t;
sPress.Y = 55 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, 'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 70, 'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

%% Build dashboard
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Header row: text + numbers + statuses
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], 'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], 'Sensor', sPress);

% Plot row: sensor‑bound FastSense widgets
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

% Bottom row: gauge + custom plot
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 11 8 6], ...
    'Sensor', sPress, 'Range', [0 100], 'Units', 'psi');
d.addWidget('rawaxes', 'Title', 'Temp Distribution', 'Position', [9 11 8 6], ...
    'PlotFcn', @(ax) histogram(ax, sTemp.Y, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

% Collapsible group with sparklines and icon cards
groupKids = {
    SparklineCardWidget('Sensor', sTemp, 'Units', '°F', 'NSparkPoints', 60),
    SparklineCardWidget('Sensor', sPress, 'Units', 'psi', 'NSparkPoints', 60),
    IconCardWidget('Sensor', sTemp, 'Units', '°F', 'StaticState', ''),
    IconCardWidget('Sensor', sPress, 'Units', 'psi', 'StaticState', '')
};
d.addCollapsible('KPIs', groupKids, 'Position', [1 17 24 5]);

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## See Also

- [[Dashboard|API Reference: Dashboard]] — Full API reference for all dashboard classes
- [[Sensors|API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule
- [[Themes|API Reference: Themes]] — DashboardTheme and FastSenseTheme details
- [[Live Mode Guide]] — Deep dive on live data polling
- [[Examples]] — Bundled example scripts (`example_dashboard_engine`, `example_dashboard_all_widgets`, etc.)
```
