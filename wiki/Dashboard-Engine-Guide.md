<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows x cols | 24-column responsive |
| Tile content | FastSense instances only | 17+ widget types (plots, gauges, numbers, tables, custom, containers) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto-scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor binding | Via addSensor per tile | Direct widget property (auto-title, auto-units) |
| Live mode | Per-figure timer | Engine-level timer refreshing all widgets |
| Multi‑page | No | Named pages with tabs, addPage(), switchPage() |
| Container widgets | No | GroupWidget (panel/collapsible/tabbed) |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines, heatmaps, etc.), JSON persistence, multi‑page dashboards, or the visual editor.

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

DashboardEngine uses a **24-column grid**. Widget positions are specified as:

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

If a new widget overlaps an existing one, it is automatically pushed down to the next free row.

---

## Multi-Page Dashboards

Create named pages and switch between them with tabs.

```matlab
d = DashboardEngine('Multi-Page');
pg = d.addPage('Overview');       % adds first page, makes it active
d.addWidget('number', ...);       % goes to Overview

d.addPage('Details');
d.switchPage(2);                   % set active page to Details
d.addWidget('fastsense', ...);
```

`addWidget()` always routes to the active page. Use `switchPage(idx)` to programmatically change the page. Each page has its own widget list and independent layout. Time‑slider controls and live mode operate across all pages.

---

## Group / Container Widgets

The `GroupWidget` organizes other widgets into a single unit with a header.

Modes:
- `'panel'` – static titled panel (default)
- `'collapsible'` – user can collapse/expand the group
- `'tabbed'` – internal tabs hold separate widget sets

```matlab
% Collapsible group via convenience method
d.addCollapsible('Environment', {w1, w2}, 'Collapsed', false);

% Full control: GroupWidget with tabbed children
g = GroupWidget('Mode', 'tabbed', 'Label', 'Sensors');
g.addChild(tWidget, 'Temperature');
g.addChild(pWidget, 'Pressure');
g.switchTab('Temperature');
d.addWidget(g);
```

`GroupWidget` respects the 24‑column grid but can sub‑divide its interior further with `ChildColumns` and `ChildAutoFlow`.

---

## Widget Types

### FastSense (time series)

```matlab
% Sensor-bound (recommended)
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

When bound to a Sensor, threshold rules apply automatically (resolved violations are shown). The widget title, X-axis label (`'Time'`), and Y-axis label (sensor Units or Name) are auto-derived. Event markers can be toggled with `ShowEventMarkers` and linked to an `EventStore`.

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
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Shows a colored dot (green/amber/red) and the sensor's latest value. Status is derived automatically from threshold rules. Can also be bound to a `Threshold` object with a `Value` or `ValueFcn`.

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

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`.

When Sensor-bound, range and units are auto-derived from threshold rules and sensor properties.

### Text (labels and headers)

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 - Shift A', 'FontSize', 16, ...
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

% Sensor-bound with time range
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Sensor', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

The `PlotFcn` receives MATLAB axes as the first argument. When Sensor-bound, it also receives the Sensor object and optionally a time range. `DataRangeFcn` can provide the widget’s time span for global time‑slider integration.

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

% Filtered by sensor names or Tag keys
d.addWidget('timeline', 'Title', 'Temp Events', ...
    'Position', [1 19 24 3], ...
    'EventStoreObj', myEventStore, ...
    'FilterSensors', {'T-401', 'T-402'}, ...
    'FilterTagKey', 'temp_hi');
```

### Divider

A static horizontal line for visual section separation. Uses theme’s `WidgetBorderColor` unless overridden.

```matlab
d.addWidget('divider', 'Position', [1 3 24 1], 'Thickness', 2);
```

### IconCard (Mushroom Card)

Compact card with a colored icon circle, primary value, and label.

```matlab
d.addWidget('iconcard', 'Title', 'Pump', ...
    'Sensor', pumpSensor, 'StaticState', 'ok', 'Units', 'rpm');
```

### SparklineCard

KPI card combining a big number with a mini sparkline and delta indicator.

```matlab
d.addWidget('sparkline', 'Title', 'CPU', ...
    'StaticValue', 42, 'SparkData', cpuHistory, 'Units', '%', ...
    'NSparkPoints', 30);
```

### ChipBar

Horizontal row of mini status chips for a dense multi-sensor summary.

```matlab
d.addWidget('chipbar', 'Chips', {
    struct('label','Pump','sensor',sPump),
    struct('label','Tank','sensor',sTank)});
```

### MultiStatus

Grid of status indicators for multiple sensors.

```matlab
d.addWidget('multistatus', 'Sensors', {s1, s2, s3}, 'Columns', 3);
```

### Histogram

Dynamic histogram display.

```matlab
d.addWidget('histogram', 'DataFcn', @() randn(1,1000), 'NumBins', 20);
```

### BarChart

Vertical or horizontal bar chart from a callback.

```matlab
d.addWidget('barchart', 'DataFcn', @() myBarData(), 'Orientation', 'horizontal');
```

### Heatmap

Heatmap widget with configurable colormap and axis labels.

```matlab
d.addWidget('heatmap', 'DataFcn', @() rand(10,10), 'Colormap', 'turbo');
```

### Scatter

Scatter plot with optional color coding from a third sensor.

```matlab
d.addWidget('scatter', 'SensorX', sX, 'SensorY', sY, 'SensorColor', sZ);
```

### Image

Display images from file or callback.

```matlab
d.addWidget('image', 'File', 'photo.jpg', 'Scaling', 'fit');
```

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

% All of these auto-derive from the Sensor:
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status', 'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Sensor', sTemp, 'Position', [13 3 12 6]);
```

Benefits of Sensor binding:
- **Title:** auto-derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto-derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, and status widgets
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations
- **Status:** StatusWidget checks the latest value against all threshold rules
- **Live refresh:** calling `refresh()` re-reads the sensor data

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON file contains the dashboard name, theme, live interval, grid settings, and each widget's type, title, position, and data source. Multi‑page dashboards are fully supported.

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re-bind Sensor objects on load, provide a resolver function:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### Export as MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` file with `DashboardEngine` constructor and `addWidget` calls that recreates the dashboard.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard-specific fields (widget backgrounds, border colors, status indicator colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

Available presets: `'light'` and `'dark'`. Legacy names (`'default'`, `'industrial'`, etc.) are aliased to `'light'`.

You can also override specific theme properties:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

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

You can also toggle live mode from the toolbar's Live button. The toolbar shows the last update timestamp when live mode is active.

Global “Follow” mode (`Follow` button) locks all FastSense charts to auto‑pan to the data tail during live updates.

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget.

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the PlotFcn
- **GroupWidget:** propagates to all children

A preview envelope shows aggregate min/max lines and event markers. If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re-attach all widgets.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type
2. A **properties panel** appears on the right showing the selected widget's settings
3. **Drag handles** let you reposition widgets on the grid
4. **Resize handles** let you change widget dimensions
5. Click **Apply** to save property changes
6. Click **Done** to exit edit mode

The editor snaps to the 24-column grid. You can change the widget's title, position, axis labels, and data source directly in the properties panel.

Widget management functions:
- `addWidget(type)` - add a new widget of the specified type
- `deleteWidget(idx)` - remove widget by index
- `selectWidget(idx)` - select a widget for property editing
- `setWidgetPosition(idx, pos)` - move/resize widget programmatically

---

## Detaching Widgets

Pop out any widget into a standalone mirror window that stays synced with the live timer:

```matlab
d.detachWidget(widget);
```

The original dashboard widget remains; the mirror is a clone. Use `removeDetached()` to clean up stale mirrors.

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML and shows it in a modal window. A placeholder page is displayed when no file is linked.

---

## Progress Bar During Render

For large dashboards, the engine reports rendering progress to the console. Control the visibility with `ProgressMode`:

```matlab
d.ProgressMode = 'on';   % always show
% 'auto' (default) — only in interactive sessions; 'off' — silent
```

---

## Complete Example

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours

scMode = StateChannel('machine');
scMode.X = [0, 3600, 7200, 28800, 36000];
scMode.Y = [0, 1,    1,    2,     1    ];

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

d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], ...
    'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], ...
    'Sensor', sPress);

d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 11 8 6], ...
    'Sensor', sPress, 'Range', [0 100], 'Units', 'psi');
d.addWidget('rawaxes', 'Title', 'Temp Distribution', 'Position', [9 11 8 6], ...
    'PlotFcn', @(ax) histogram(ax, sTemp.Y, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## See Also

- [[API Reference: Dashboard]] – Full API reference for all dashboard classes
- [[API Reference: Sensors]] – Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] – Live data polling
- [[Examples]] – `example_dashboard_engine`, `example_dashboard_all_widgets`
