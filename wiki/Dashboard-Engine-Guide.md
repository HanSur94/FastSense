<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor/tag bindings, JSON persistence, a visual editor, and support for multi‑page layouts.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24‑column responsive |
| Tile content | FastSense instances only | 17+ widget types (plots, gauges, numbers, tables, icons, sparklines, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor/Tag binding | Per‑tile `addSensor` | Direct `Tag`/`Sensor` property (auto‑title, auto‑units) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets |
| Multi‑page | No | Named pages with tabbed navigation |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines), JSON persistence, the visual editor, or multi‑page dashboards.

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

If a new widget overlaps an existing one, it is automatically pushed down to the next free row (handled by `DashboardLayout.resolveOverlap()`).

---

## Widget Types

All widgets are added via `addWidget(type, ...)`, where `type` is a string like `'fastsense'`, `'number'`, `'gauge'`, etc. The complete list of supported types can be obtained from `DashboardEngine.widgetTypes()`.

### FastSense (time series)

```matlab
% Sensor‑bound (Tag)
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Tag', mySensor);

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

When bound to a Sensor (via `Tag` or the legacy `'Sensor'` name‑value pair), threshold rules apply automatically and resolved violations are shown. The widget title, X‑axis label (default `'Time'`), and Y‑axis label (sensor `Units` or `Name`) are auto‑derived.

### Number (big value display)

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Tag', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Or with static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');
```

Shows a large number with a trend arrow (up/down/flat) computed from recent data. Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Tag', sTemp);
```

Shows a colored dot (green/amber/red) and the latest value. Status is derived automatically from threshold rules. You can also bind a `Threshold` object directly:

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Threshold', myThreshold, 'ValueFcn', @() readValue());
```

### Gauge (arc/donut/bar/thermometer)

```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Tag', sFlow, 'Range', [0 160], 'Units', 'L/min', ...
    'Style', 'donut');

% Static value
d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', ...
    'Style', 'arc');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`.

When Sensor‑bound, range and units are auto‑derived from threshold rules and sensor properties. The gauge arc color updates according to the current threshold state.

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
    'Tag', sTemp, 'N', 15);

% Dynamic data via callback
d.addWidget('table', 'Title', 'Live Log', ...
    'Position', [1 13 12 4], ...
    'DataFcn', @() getRecentAlarms(), ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Level'});

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Tag', mySensor, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

### Raw Axes (custom plots)

```matlab
d.addWidget('rawaxes', 'Title', 'Temperature Distribution', ...
    'Position', [1 5 8 4], ...
    'PlotFcn', @(ax) histogram(ax, tempData, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));
```

The `PlotFcn` receives MATLAB axes as the first argument. When Sensor‑bound, it also receives the Sensor object and optionally a time range:

```matlab
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Tag', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

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

### Additional Widget Types

DashboardEngine supports many more widget types beyond the core set above. All follow the same `addWidget` pattern.

- **BarChartWidget** (`barchart`)  
  `'DataFcn', @() struct('categories',{...},'values',[...])`

- **ChipBarWidget** (`chipbar`)  
  Compact row of mini status circles; define `Chips` as a cell array of structs with `label`, `statusFcn`, etc.

- **IconCardWidget** (`iconcard`)  
  Mushroom‑style card with colored icon, value, and label. State color responds to thresholds.

- **SparklineCardWidget** (`sparklinecard`)  
  KPI card with a large value, sparkline miniature chart, and delta indicator.

- **ImageWidget** (`image`)  
  Display an image file or callback matrix.

- **HistogramWidget** (`histogram`)  
  `DataFcn` returning a vector; auto‑binning and optional normal‑fit overlay.

- **ScatterWidget** (`scatter`)  
  Two‑sensor XY scatter with optional third‑sensor color mapping.

- **MultiStatusWidget** (`multistatus`)  
  Grid of status indicators for multiple sensors.

- **DividerWidget** (`divider`)  
  Simple horizontal divider line.

- **GroupWidget** (`group`) – see [[#Group Widgets and Collapsible Sections]]

---

## Sensor Binding and Tags

The recommended way to drive dashboard widgets is through **Tag** objects (which include `Sensor` objects, because `Sensor` is a subclass of `Tag`). You can assign a `Tag` directly, or use the legacy `'Sensor'` name‑value pair which maps to the `Tag` property.

```matlab
% Create and configure a Sensor
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

% All widgets auto‑derive from the Tag:
d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number',   'Tag', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status',   'Tag', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge',    'Tag', sTemp, 'Position', [13 3 12 6]);
```

Benefits of Tag binding:

- **Title:** auto‑derived from `Tag.Name` or `Tag.Key`
- **Units:** auto‑derived from `Tag.Units`
- **Value:** uses `Tag.Y(end)` for number, gauge, and status widgets
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations; StatusWidget and GaugeWidget colour based on threshold state
- **Live refresh:** calling `refresh()` re‑reads the tag data

You can also bind to a `MonitorTag` or any other `Tag` subclass.

---

## Multi‑Page Dashboards

You can partition a dashboard into named pages, each with its own set of widgets.

```matlab
d = DashboardEngine('Line Monitor');
d.Theme = 'light';

% Add a page – becomes active automatically
pg1 = d.addPage('Temperature');

% Add widgets to the active page
d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 3 12 8]);

% Add a second page
pg2 = d.addPage('Pressure');
d.addWidget('fastsense', 'Tag', sPress, 'Position', [1 3 12 8]);

% Switch back to the first page
d.switchPage(1);

d.render();
```

When pages exist, a tab bar appears below the toolbar. Widget management methods like `addWidget`, `removeWidget`, `rerenderWidgets` operate on the currently active page. Global time controls, live mode, and the visual editor work across all pages.

---

## Group Widgets and Collapsible Sections

`GroupWidget` lets you organise widgets into panels, collapsible sections, or tabs.

### Panel mode (default)

```matlab
g = GroupWidget('Mode', 'panel', 'Label', 'Sensors');
g.addChild(w1);
g.addChild(w2);
d.addWidget(g, 'Position', [1 1 12 8]);
```

### Collapsible mode

```matlab
% Convenience helper on the engine
d.addCollapsible('Sensors', {w1, w2}, 'Position', [1 1 12 8], 'Collapsed', true);
```

### Tabbed mode

```matlab
g = GroupWidget('Mode', 'tabbed', 'Label', 'Details');
g.addChild(wTemp, 'Temperature');
g.addChild(wPress, 'Pressure');
d.addWidget(g, 'Position', [1 1 12 8]);
```

Group widgets participate in the live timer and global time broadcast, aggregating time ranges from all children.

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON file contains the dashboard name, theme, live interval, grid settings, pages, and each widget’s type, title, position, and data source.

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re‑bind Sensor/Tag objects on load, provide a resolver function:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### Export as MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` file that, when executed, returns a fully configured `DashboardEngine` replicating the dashboard.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colors, status indicator colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

Available presets: `'light'` and `'dark'`.  
(Legacy names `'default'`, `'industrial'`, `'scientific'`, `'ocean'` are aliased to `'light'`.)

You can also override specific theme properties:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

See [[API Reference: Themes]] for all theme fields.

---

## Live Mode

DashboardEngine supports live data updates via a timer that periodically calls `refresh()` on all widgets.

```matlab
d = DashboardEngine('Live Monitor');
d.Theme = 'dark';
d.LiveInterval = 2;  % refresh every 2 seconds

d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number',   'Tag', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % start periodic refresh
% ... later
d.stopLive();    % stop
```

You can also toggle live mode from the toolbar’s **Live** button. The toolbar shows the last update timestamp when live mode is active.

---

## Global Time Controls

The time panel at the bottom of the dashboard (when `ShowTimePanel` is `true`) contains a dual‑slider selector that controls the visible time range across all widgets. Moving the sliders calls `broadcastTimeRange(tStart, tEnd)` on every widget.

- **FastSenseWidget:** sets `xlim` on the FastSense axes.
- **EventTimelineWidget:** sets `xlim` on the timeline axes.
- **RawAxesWidget:** passes the time range to the `PlotFcn`.

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type.
2. A **properties panel** appears on the right showing the selected widget’s settings.
3. **Drag handles** let you reposition widgets on the grid.
4. **Resize handles** let you change widget dimensions.
5. Click **Apply** to save property changes.
6. Click **Done** to exit edit mode.

The editor snaps to the 24‑column grid. You can change the widget’s title, position, axis labels, and data source directly in the properties panel.

Widget management functions that can also be called programmatically:
- `addWidget(type)` – add a new widget of the specified type.
- `deleteWidget(idx)` – remove widget by index.
- `selectWidget(idx)` – select a widget for property editing.
- `setWidgetPosition(idx, pos)` – move/resize widget programmatically.

---

## Info File Integration

Dashboards can link to an external Markdown documentation file:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

A toolbar **Info** button appears. Clicking it renders the Markdown to HTML (using the current theme) and opens it in an in‑app modal window (or a system browser on older MATLAB releases). When no `InfoFile` is set, a placeholder page is shown explaining how to attach one.

---

## Complete Example

This example creates a process monitoring dashboard with sensor‑bound widgets, a gauge, and a custom histogram.

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
d = DashboardEngine('Process Monitoring – Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Header row: text + numbers + status
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 – Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Tag', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Tag', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], 'Tag', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], 'Tag', sPress);

% Plot row: sensor‑bound FastSense widgets
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Tag', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Tag', sPress);

% Bottom row: gauge + custom plot
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 11 8 6], ...
    'Tag', sPress, 'Range', [0 100], 'Units', 'psi');
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
- [[API Reference: Themes]] – Theme presets and field descriptions
- [[Live Mode Guide]] – Live data polling
- [[Examples]] – `example_dashboard_engine`, `example_dashboard_all_widgets`
