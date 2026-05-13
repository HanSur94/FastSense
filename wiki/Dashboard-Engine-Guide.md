<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, and a visual editor.

---

## Overview

`DashboardEngine` is the top‑level orchestrator for creating data‑driven dashboards. It manages a 24‑column responsive grid, a live refresh timer, global time controls, theming, and the visual editor. Widgets give you access to:

*   **16+ widget types** — time‑series plots (`FastSenseWidget`), big‑number KPIs, gauges, status indicators, tables, timelines, sparkline cards, icon cards, heatmaps, bar charts, and more.
*   **Sensor binding** — auto‑derived titles, units, value ranges, and threshold‑rule visualisation.
*   **JSON save/load** and `.m` script export for reproducible deployment.
*   **Live polling** via a configurable timer.
*   **Visual editor** with drag‑and‑resize, palette, and properties panel.

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

`DashboardEngine` uses a **24‑column grid**. Widget positions are specified as:

```
Position = [col, row, width, height]
```

*   `col` — column index (1‑24, left to right)
*   `row` — row index (1+, top to bottom)
*   `width` — number of columns the widget spans (1‑24)
*   `height` — number of rows the widget spans

Examples:
```matlab
[1 1 24 4]   % Full width, 4 rows tall, top of dashboard
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

When a new widget overlaps an existing one, it is automatically pushed down to the next free row.

---

## Widget Types

All widget classes inherit from `DashboardWidget`. The simplest way to add a widget is to pass the type string (the class name without the `Widget` suffix) and optional name‑value pairs to `addWidget`. Alternatively, you can construct the widget object directly:

```matlab
d.addWidget(IconCardWidget('Title','Pump','StaticValue',85));
```

### FastSense (time‑series plots)

```matlab
% Tag‑bound (v2.0) — recommended
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Tag', myTag);

% Inline data
d.addWidget('fastsense', 'Title', 'Raw', 'Position', [13 1 12 8], ...
    'XData', x, 'YData', y);

% From a MAT file
d.addWidget('fastsense', 'Title', 'File', 'Position', [1 9 24 6], ...
    'File', 'data.mat', 'XVar', 'x', 'YVar', 'y');

% From a DataStore
d.addWidget('fastsense', 'Title', 'Store', 'Position', [1 15 24 6], ...
    'DataStore', myDataStore);
```

When bound to a Tag (or its legacy `Sensor` alias), threshold rules are applied automatically and the widget’s title, X‑axis label (`'Time'`) and Y‑axis label (tag units or name) are auto‑derived.

### Number (big‑value KPI)

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Tag', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data. Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', 'Position', [7 1 5 2], 'Tag', sTemp);
% or with a Threshold object (no sensor needed)
d.addWidget('status', 'Title', 'System', 'Position', [12 1 5 2], ...
    'Threshold', myThreshold, 'Value', 85);

% Legacy static status
d.addWidget('status', 'Title', 'Status', 'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Shows a coloured dot (green/amber/red) and, when sensor‑bound, the latest value. Status is derived automatically from threshold rules.

### Gauge (arc / donut / bar / thermometer)

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

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When bound to a Tag, range and units are auto‑derived from threshold rules and tag properties.

### Table

```matlab
% Static data
d.addWidget('table', 'Title', 'Alarm Log', ...
    'Position', [13 9 12 4], ...
    'ColumnNames', {'Time', 'Tag', 'Value'}, ...
    'Data', {{'12:00','T-401','85.2'; '12:05','P-201','72.1'}});

% Sensor‑bound (last N rows)
d.addWidget('table', 'Title', 'Recent Data', ...
    'Position', [1 9 12 4], ...
    'Tag', sTemp, 'N', 15);

% Dynamic via callback
d.addWidget('table', 'Title', 'Live Log', ...
    'Position', [1 13 12 4], ...
    'DataFcn', @() getRecentAlarms(), ...
    'ColumnNames', {'Time', 'Tag', 'Value', 'Level'});

% Event‑mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Tag', mySensor, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

### Event Timeline

```matlab
% From a struct array
events = struct('startTime',{0,3600},'endTime',{3600,7200},...
    'label',{'Idle','Running'},'color',{[0.6 0.6 0.6],[0.2 0.7 0.3]});
d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], 'Events', events);

% From an EventStore (recommended)
d.addWidget('timeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], 'EventStoreObj', myEventStore);

% Filtered by sensor names
d.addWidget('timeline', 'Title', 'Temp Events', ...
    'Position', [1 19 24 3], 'EventStoreObj', myEventStore, ...
    'FilterSensors', {'T-401','T-402'});
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
    'Tag', mySensor, ...
    'PlotFcn', @(ax, sensor, tRange) plotCustom(ax, sensor, tRange));
```

### Group Widget (container)

```matlab
% Panel mode (default)
g = GroupWidget('Title','Sensor Suite','Mode','panel');
g.addChild(NumberWidget('Title','Temp','Tag',sTemp));
g.addChild(StatusWidget('Title','Pump','Tag',sPump));
d.addWidget(g);

% Collapsible
g = GroupWidget('Label','Details','Mode','collapsible','Collapsed',true);
g.addChild(FastSenseWidget('Tag',sTemp));
d.addWidget(g);

% Tabbed
g = GroupWidget('Title','Views','Mode','tabbed');
g.addChild(FastSenseWidget('Tag',sTemp), 'Raw');
g.addChild(TableWidget('Tag',sTemp), 'Table');
d.addWidget(g);
```

### Other Widgets

Many additional widget types are available. Here is a complete list:

| Widget Type              | Key Feature                                                         |
|--------------------------|---------------------------------------------------------------------|
| `BarChartWidget`         | Bar chart from `DataFcn` returning struct with categories & values. |
| `ChipBarWidget`          | Horizontal row of status‑coloured chips for system health.          |
| `DividerWidget`          | Horizontal divider line (static).                                   |
| `HeatmapWidget`          | 2‑D matrix display with colormap and optional colour bar.           |
| `HistogramWidget`        | Data‑driven histogram, optionally with a normal‑fit overlay.        |
| `IconCardWidget`         | Mushroom‑style card: coloured icon, large value, subtitle.          |
| `ImageWidget`            | Display a PNG/JPG from file or callback.                            |
| `MultiStatusWidget`      | Grid of coloured status dots for multiple sensors.                  |
| `ScatterWidget`          | XY plot from two independent sensors.                               |
| `SparklineCardWidget`    | KPI card combining a big number with an inline sparkline.           |
| `TextWidget`             | Static text label or section header.                                |

You can add any of these by passing the type string to `addWidget` or by constructing the object directly:

```matlab
d.addWidget('barchart', 'Title','Usage', 'DataFcn', @() struct('categories',{{'A','B','C'}},'values',[10 20 30]));
d.addWidget(IconCardWidget('Title','Pump','StaticValue',85,'Units','%'));
d.addWidget(SparklineCardWidget('Title','CPU','SparkData',cpuHistory,'Units','%'));
```

For complete details, including constructor options, see the [[API Reference: Dashboard]].

---

## Sensor / Tag Binding

In v2.0, widgets are bound to `Tag` objects (which may wrap `Sensor` instances). The legacy `Sensor` name‑value pair is still accepted and internally mapped to `Tag`.

```matlab
% Create a Sensor (v1 style)
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;
% Tag binding (v2)
d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Tag', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status', 'Tag', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Tag', sTemp, 'Position', [13 3 12 6]);

% Legacy string‑based binding still works:
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
```

Benefits of sensor binding:
*   **Title** – auto‑derived from `Tag.Name` or `Tag.Key`
*   **Units** – auto‑derived from `Tag.Units`
*   **Value** – uses latest data point (`Tag.Y(end)`) for number, gauge, and status widgets
*   **Thresholds** – `FastSenseWidget` renders resolved threshold lines and violation highlights
*   **Status** – `StatusWidget` checks the latest value against all threshold rules
*   **Live refresh** – calling `refresh()` re‑reads the tag data

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

Generates a readable `.m` file with the `DashboardEngine` constructor and all `addWidget` calls needed to recreate the dashboard.

---

## Theming

`DashboardEngine` uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colours, status indicator colours, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % only 'light' and 'dark' are supported
d.render();
```

Legacy preset names ('industrial', 'scientific', 'ocean', 'default') are aliased to `'light'` for backward compatibility.

You can override specific theme properties:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

---

## Live Mode

`DashboardEngine` supports live data updates via a timer that periodically calls `refresh()` on all widgets.

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

You can also toggle live mode from the toolbar’s **Live** button. The toolbar shows the last update timestamp when live mode is active.

---

## Global Time Controls

A time‑range panel with two sliders controls the visible time window across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget:

*   **FastSenseWidget** – sets x‑limits on the underlying `FastSense` axes
*   **EventTimelineWidget** – sets x‑limits on its timeline axes
*   **RawAxesWidget** – passes the time range to the `PlotFcn`

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

The editor snaps to the 24‑column grid. Widget management functions include:

*   `addWidget(type)` – add a new widget of the specified type
*   `deleteWidget(idx)` – remove widget by index
*   `selectWidget(idx)` – select a widget for property editing
*   `setWidgetPosition(idx, pos)` – move/resize a widget programmatically

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to a Markdown file
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown to HTML and displays it in an in‑app modal window (or the system browser as a fallback). Supports basic Markdown syntax: headings, lists, code blocks, and tables.

---

## Complete Example

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours

% Machine mode state channel
scMode = StateChannel('machine');
scMode.X = [0, 3600, 7200, 28800, 36000];
scMode.Y = [0, 1, 1, 2, 1];

% Temperature Sensor
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

% Pressure Sensor
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

%% Save to JSON
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## See Also

*   [[API Reference: Dashboard]] — Full API reference for all dashboard classes
*   [[API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule
*   [[Live Mode Guide]] — Live data polling
*   [[Examples]] — `example_dashboard_engine`, `example_dashboard_all_widgets`
