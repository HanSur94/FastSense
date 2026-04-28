<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, JSON persistence, a visual editor, multi-page navigation, and live data mirroring.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24‑column responsive |
| Tile content | FastSense instances only | 20+ widget types (plots, gauges, KPIs, tables, bars, sparklines, …) |
| Persistence | None | JSON save/load + `.m` script export |
| Visual editor | No | Yes (drag, resize, palette, properties) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Multi‑page | No | Named pages with toolbar tab switching |
| Console preview | No | ASCII render of layout and data |
| Image export | Figure copy | High‑resolution PNG/JPEG export |
| Widget pop‑out | No | `detachWidget()` into a live mirror window |
| Stale data detection | None | Banner for widgets with no new data in live mode |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types, JSON persistence, the visual editor, multi‑page dashboards, or any of the features listed above.

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

If a new widget overlaps an existing one, it is automatically pushed down to the next free row.

---

## Widget Types

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

When bound to a Sensor, threshold rules apply automatically. The widget title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived.

### Number (big value display)

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

Shows a large number with a trend arrow (up/down/flat). Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Displays a colored dot (green/amber/red) and the sensor’s latest value. Status is derived from threshold rules automatically.

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

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When Sensor‑bound, range and units are auto‑derived.

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

% Dynamic callback
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

The `PlotFcn` receives axes as first argument. When Sensor‑bound, it also receives the Sensor object and optionally a time range.

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

### Sparkline Card (KPI + mini chart)

```matlab
d.addWidget('sparkline', 'Title', 'CPU', ...
    'Position', [1 1 6 3], ...
    'StaticValue', 42.0, 'SparkData', cpuHistory, ...
    'Units', '%', 'ShowDelta', true);
```

A compact card with a large value, a sparkline chart, and an optional delta indicator. Can also be bound to a Sensor for value & sparkline data.

### Icon Card (mushroom card)

```matlab
d.addWidget('iconcard', 'Title', 'Pump 3', ...
    'Position', [1 1 4 3], ...
    'Sensor', sPump, 'Units', 'psi');
```

Shows a colored icon (circle) reflecting the sensor’s threshold state, a large numeric value, and a secondary label.

### Chip Bar (multi‑sensor status strip)

```matlab
chips = {
    struct('label', 'Pump', 'sensor', sPump),
    struct('label', 'Tank', 'statusFcn', @() 'ok'),
    struct('label', 'Fan',  'statusFcn', @() 'alarm')
};
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 1 24 1], 'Chips', chips);
```

A horizontal row of colored status dots, ideal for a dense summary of many items.

### Bar Chart

```matlab
d.addWidget('barchart', 'Title', 'Production', ...
    'Position', [1 1 12 6], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, ...
                          'values', [120, 85, 200]), ...
    'Orientation', 'vertical');
```

Uses `DataFcn` that returns a struct with `categories` and `values`. Supports `'vertical'` / `'horizontal'` orientation and stacked mode.

### Heatmap

```matlab
d.addWidget('heatmap', 'Title', 'Correlation', ...
    'Position', [1 1 12 6], ...
    'DataFcn', @() rand(5), ...
    'Colormap', 'parula', 'ShowColorbar', true);
```

Accepts a matrix from `DataFcn`. Axes labels, colormap, and colorbar are configurable.

### Histogram

```matlab
d.addWidget('histogram', 'Title', 'Values', ...
    'Position', [1 1 8 4], ...
    'DataFcn', @() randn(1,1000), ...
    'NumBins', 30, 'EdgeColor', [0.2 0.2 0.5]);
```

### Scatter

```matlab
d.addWidget('scatter', 'Title', 'X vs Y', ...
    'Position', [1 1 8 6], ...
    'SensorX', sX, 'SensorY', sY);
```

Plots two sensors against each other. An optional third sensor can be used for point coloring.

### Image

```matlab
d.addWidget('image', 'Title', 'Layout', ...
    'Position', [1 1 8 6], ...
    'File', 'plant_layout.png', 'Scaling', 'fit');
```

Or with a function: `'ImageFcn', @() imread('file')`. Scaling modes: `'fit'`, `'fill'`, `'stretch'`.

### Divider (horizontal line)

```matlab
d.addWidget('divider', 'Position', [1 5 24 1], 'Thickness', 2);
```

A static visual separator that respects the theme’s border color.

### Group Widget (panel / collapsible / tabbed)

```matlab
% Collapsible group
w1 = d.addWidget('fastsense', ...);
w2 = d.addWidget('number', ...);
d.addWidget('group', 'Title', 'Sensors', ...
    'Position', [1 1 12 8], ...
    'Mode', 'collapsible', ...
    'Label', 'Temperature Bundle', ...
    'Children', {w1, w2});

% Or via convenience method
d.addCollapsible('Details', {w1, w2}, 'Collapsed', false);
```

`GroupWidget` supports three modes:
- `'panel'` — simple container with a sub‑grid.
- `'collapsible'` — header bar that toggles visibility.
- `'tabbed'` — multiple named tabs, each holding a set of widgets.

Children automatically flow inside the group’s local grid. Nesting depth is limited (source code enforces a max depth).

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
- **Value:** uses `Sensor.Y(end)` for number, gauge, and status widgets
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations; StatusWidget compares against all rules
- **Live refresh:** `refresh()` re‑reads sensor data

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

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

Generates a readable `.m` file with `DashboardEngine` constructor and `addWidget` calls that recreates the dashboard. Multi‑page dashboards are fully supported.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colors, status indicator colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

Available presets: `'dark'` and `'light'`. Legacy preset names (`'default'`, `'industrial'`, …) are aliased to `'light'` for backward compatibility.

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

You can also toggle live mode from the toolbar’s **Live** button. The toolbar shows a blue border when live mode is active and displays the last update timestamp.

### Stale Data Detection

During live mode, if a widget’s latest timestamp ceases to advance, a warning banner appears below the toolbar listing the stale widgets. The banner can be dismissed by the user; it remains hidden until data resumes.

```matlab
% The banner is automatically created and updated by the engine.
% You can control its visibility indirectly via:
d.ProgressMode = 'auto';   % 'auto', 'on', 'off' — render progress bar visibility
```

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget.

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the `PlotFcn`

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets.

### Time Range Envelope

The slider panel displays an aggregate down‑sampled preview of all FastSense widget data as a shaded envelope behind the selection rectangle. This gives an overview of data density before scrubbing.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type.
2. A **properties panel** appears on the right showing the selected widget’s settings.
3. **Drag handles** let you reposition widgets on the grid.
4. **Resize handles** let you change widget dimensions.
5. Click **Apply** to save property changes.
6. Click **Done** to exit edit mode.

The editor snaps to the 24‑column grid. You can change the widget’s title, position, axis labels, and data source directly in the properties panel. Certain widget types have specialized add‑methods in the builder (e.g., `addIconCard`, `addChipBar`, `addSparkline`) that streamline creation.

Widget management functions:
- `addWidget(type)` – add a new widget of the specified type
- `deleteWidget(idx)` – remove widget by index
- `selectWidget(idx)` – select a widget for property editing
- `setWidgetPosition(idx, pos)` – move/resize widget programmatically

---

## Multi‑Page Dashboards

Dashboards can be organized into multiple named pages, each holding its own set of widgets. The toolbar automatically shows navigation tabs when pages are defined.

```matlab
d = DashboardEngine('Plant Monitor');
d.Theme = 'dark';

% Create first page (active by default after first addPage)
pgOverview = d.addPage('Overview');
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [13 1 6 2]);

% Create second page
d.switchPage(2);   % explicitly switch before adding widgets
pgAlarms = d.addPage('Alarms');
d.addWidget('table', 'Title', 'All Alarms', 'Position', [1 1 24 6], ...)

d.render();
```

`addPage(name)` creates a `DashboardPage`, appends it to `Pages`, and makes it the active page for subsequent `addWidget` calls. You can switch between pages with `switchPage(n)` or by clicking the tabs in the toolbar.

Multi‑page configuration is fully serialized in JSON and in exported scripts.

---

## Console Preview

To quickly inspect a dashboard’s layout and widget summaries without rendering a figure, use `preview()`:

```matlab
d.preview();            % default 120‑char width
d.preview('Width', 80); % custom width
```

This prints an ASCII representation to the console, with each widget’s type, title, and a basic data indicator.

---

## Export Image

Save the rendered dashboard as a high‑resolution PNG or JPEG from code:

```matlab
d.exportImage('dashboard.png');           % PNG at 150 DPI
d.exportImage('dashboard.jpg', 'jpeg');   % JPEG
```

The toolbar’s **Image** button opens a save dialog with the same functionality.

---

## Detached Mirror Pop‑outs

Any widget can be detached into its own standalone figure window that continues to receive live updates:

```matlab
d.detachWidget(w);   % w is a widget handle
```

The mirror is a cloned copy. It is ticked by the same live timer. Dead mirrors are automatically cleaned up. Use `removeDetached(obj)` to manually prune stale mirrors.

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML and opens it in the system browser. Supports basic Markdown syntax (headings, lists, code, tables). When no `InfoFile` is set, a placeholder page is shown describing how to attach one.

---

## Complete Example

This example creates a process monitoring dashboard with sensor‑bound widgets, a sparkline card, and a collapsible group:

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

% CPU load history for sparkline
cpuHistory = 30 + 20*rand(1,60);

%% Build dashboard
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Header row
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

% Main plot row
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

% Bottom row: gauge, sparkline, and collapsible details
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 11 8 6], ...
    'Sensor', sPress, 'Range', [0 100], 'Units', 'psi');
d.addWidget('sparkline', 'Title', 'CPU Load', 'Position', [9 11 6 3], ...
    'StaticValue', cpuHistory(end), 'SparkData', cpuHistory, ...
    'Units', '%');

% Collapsible group for additional sensors
wAlarm = d.addWidget('table', 'Title', 'Alarms', ...
    'Position', [1 14 12 4], 'Sensor', sTemp, 'N', 10);
wEvent = d.addWidget('timeline', 'Title', 'Events', ...
    'Position', [1 18 12 3], 'EventStoreObj', myEventStore);
d.addCollapsible('More Details', {wAlarm, wEvent}, 'Collapsed', true);

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## See Also

- [[API Reference: Dashboard]] — Full API reference for all dashboard classes
- [[API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] — Live data polling
- [[Examples]] — `example_dashboard_engine`, `example_dashboard_all_widgets`
