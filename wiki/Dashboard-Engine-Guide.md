<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows x cols | 24-column responsive |
| Tile content | FastSense instances only | 15+ widget types (plots, gauges, numbers, tables, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto-scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor binding | Via addSensor per tile | Direct widget property (auto-title, auto-units) |
| Live mode | Per-figure timer | Engine-level timer refreshing all widgets |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines), JSON persistence, or the visual editor.

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

- `col`: column (1-24), left to right
- `row`: row (1+), top to bottom
- `width`: number of columns to span (1-24)
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

DashboardEngine supports 15+ widget types for different visualization needs:

### FastSense (time series)

The primary plotting widget for time series data with threshold visualization.

```matlab
% Sensor-bound (recommended)
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

When bound to a Sensor, threshold rules apply automatically (resolved violations are shown). The widget title, X-axis label (`'Time'`), and Y-axis label (sensor Units or Name) are auto-derived.

### Number (big value display)

Shows a large number with optional trend arrow and units.

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Tag', sTemp, 'Units', 'degF', 'Format', '%.1f');

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

Colored dot indicator showing sensor health state.

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Tag', sTemp);

% Threshold-bound (no Sensor required)
d.addWidget('status', 'Title', 'Temp', ...
    'Position', [12 1 5 2], ...
    'Threshold', 'temp_hi', 'ValueFcn', @getTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [17 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Shows a colored dot (green/amber/red) and the sensor's latest value. Status is derived automatically from threshold rules.

### Gauge (arc/donut/bar/thermometer)

Visual gauges with multiple style options.

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

When Sensor-bound, range and units are auto-derived from threshold rules and sensor properties.

### Text (labels and headers)

Static text labels for section headers and annotations.

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 - Shift A', 'FontSize', 16, ...
    'Alignment', 'center');
```

### Table (data display)

Tabular data display with multiple data source options.

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

Full control over MATLAB axes for custom visualizations.

```matlab
d.addWidget('rawaxes', 'Title', 'Temperature Distribution', ...
    'Position', [1 5 8 4], ...
    'PlotFcn', @(ax) histogram(ax, tempData, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

% Sensor-bound with time range
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Tag', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

The `PlotFcn` receives MATLAB axes as the first argument. When Sensor-bound, it also receives the Sensor object and optionally a time range.

### Event Timeline

Displays events as colored bars on a timeline.

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

DashboardEngine also supports these specialized widgets:

- **IconCard** - Compact card with colored icon, value, and label (Mushroom Card style)
- **SparklineCard** - KPI card with big number, mini sparkline chart, and delta indicator  
- **ChipBar** - Horizontal row of mini status chips for system health summary
- **Group** - Container widget with panel, collapsible, and tabbed modes
- **Divider** - Horizontal line for visual section separation
- **Heatmap** - Matrix data visualization with colormap
- **Histogram** - Distribution plots with optional normal fit overlay
- **BarChart** - Vertical/horizontal bar charts with stacking support
- **Scatter** - Scatter plots with optional color coding
- **Image** - Static image display with scaling options
- **MultiStatus** - Grid of status indicators for multiple sensors

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
d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Tag', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status', 'Tag', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Tag', sTemp, 'Position', [13 3 12 6]);
```

Benefits of Sensor binding:
- **Title:** auto-derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto-derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, and status widgets
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations
- **Status:** StatusWidget checks the latest value against all threshold rules
- **Live refresh:** calling `refresh()` re-reads the sensor data

---

## Multi-Page Dashboards

DashboardEngine supports multiple named pages within a single dashboard:

```matlab
d = DashboardEngine('Multi-Page Dashboard');

% Add pages
pg1 = d.addPage('Overview');
pg2 = d.addPage('Details');

% Switch to first page and add widgets
d.switchPage(1);
d.addWidget('text', 'Title', 'System Overview', 'Position', [1 1 24 1]);
d.addWidget('number', 'Title', 'Temperature', 'Position', [1 2 6 2], ...
    'Tag', sTemp);

% Switch to second page and add different widgets
d.switchPage(2);
d.addWidget('fastsense', 'Position', [1 1 24 8], 'Tag', sTemp);
d.addWidget('table', 'Title', 'Data Log', 'Position', [1 9 24 4], ...
    'Tag', sTemp, 'N', 20);

d.render();
```

Page navigation appears as tabs at the top of the dashboard when multiple pages exist.

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON file contains the dashboard name, theme, live interval, grid settings, and each widget's type, title, position, and data source.

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
d.Theme = 'dark';        % or 'light' (legacy presets aliased to 'light')
d.render();
```

Available presets: `'light'` (default), `'dark'`. Legacy presets (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are aliased to `'light'` for backward compatibility.

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

d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Tag', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % start periodic refresh
% ... later
d.stopLive();    % stop
```

You can also toggle live mode from the toolbar's Live button. The toolbar shows the last update timestamp when live mode is active.

### Stale Data Detection

During live mode, DashboardEngine monitors each widget's data time range. If a widget's maximum time value doesn't advance for multiple refresh cycles, a warning banner appears listing the stale widgets. Users can dismiss the banner, which stays hidden until data resumes flowing.

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget.

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the PlotFcn

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re-attach all widgets.

The time selector includes an optional data preview envelope showing aggregated min/max bounds across all widgets, helping users identify periods of interest.

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

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML and opens it in the system browser. Supports basic Markdown syntax including headers, lists, code blocks, and tables.

---

## Progress Indicators

DashboardEngine shows a progress bar during widget rendering when processing large numbers of widgets:

```matlab
d = DashboardEngine('Large Dashboard');
d.ProgressMode = 'on';    % 'auto' (default), 'on', 'off'
d.render();               % shows progress for widget realization
```

In `'auto'` mode, progress is shown only in interactive MATLAB sessions. Set to `'off'` to disable entirely, or `'on'` to force display even in batch mode.

---

## Complete Example

This example creates a process monitoring dashboard with sensor-bound widgets:

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

% Header row: text + numbers + status
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Tag', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Tag', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], ...
    'Tag', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], ...
    'Tag', sPress);

% Plot row: sensor-bound FastSense widgets
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

- [[API Reference: Dashboard]] -- Full API reference for all dashboard classes
- [[API Reference: Sensors]] -- Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] -- Live data polling
- [[Examples]] -- `example_dashboard_engine`, `example_dashboard_all_widgets`
