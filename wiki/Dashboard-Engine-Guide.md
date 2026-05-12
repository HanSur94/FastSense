<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, visual editor, and multi-page support.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24‑column responsive |
| Tile content | FastSense instances only | 15+ widget types (plots, gauges, numbers, tables, timelines, group containers, …) |
| Persistence | None | Save as .m function or JSON; export as .m script |
| Visual editor | No | Yes (drag/resize, palette, properties panel, multi‑page aware) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets, with aggregate preview envelope |
| Sensor binding | Via addSensor per tile | Direct widget property (auto‑title, auto‑units, threshold awareness) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets in all pages |
| Multi‑page | No | Yes (addPage, switchPage, per‑page layout) |

**When to use FastSenseGrid:** A simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** Mixed widget types, gauges, KPIs, timelines, collapsible groups, multi‑page layouts, JSON/.m persistence, or the visual editor.

---

## Quick Start

```matlab
install;

% Create some data
x = linspace(0, 100, 10000);
y = sin(x) + 0.1 * randn(size(x));

% Build a dashboard
d = DashboardEngine('My First Dashboard');
d.Theme = 'light';

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

- `col` : column (1‑24)
- `row` : row (1+)
- `width` : number of columns to span (1‑24)
- `height` : number of rows to span

Examples:
```matlab
[1 1 24 4]   % Full width, 4 rows tall
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

When a new widget overlaps an existing one it is automatically pushed down. The layout resolves overlaps and scrolls the canvas when content exceeds the figure height.

---

## Widget Types

DashboardEngine supports all the classic widget types plus a rich set of advanced widgets. You can add a widget by passing its type string and name‑value pairs to `addWidget`, or by constructing a widget object directly and passing it.

```matlab
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', mySensor);
% or equivalently:
w = FastSenseWidget('Position', [1 1 12 8], 'Tag', mySensor);
d.addWidget(w);
```

### FastSense (time series)
```matlab
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Title', 'Raw', 'Position', [13 1 12 8], ...
            'XData', x, 'YData', y);
d.addWidget('fastsense', 'Title', 'File', 'Position', [1 9 24 6], ...
            'File', 'data.mat', 'XVar', 'x', 'YVar', 'y');
d.addWidget('fastsense', 'Title', 'Store', 'Position', [1 15 24 6], ...
            'DataStore', myDataStore);
```
FastSenseWidget wraps a FastSense instance. Sensor‑binding auto‑derives title, x‑label (`'Time'`), and y‑label (units/name). Threshold violations are shown automatically when bound to a Sensor with resolved rules.

### Number (big value display)
```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```
Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data. When bound to a Sensor the arrow reflects the slope of the last few values.

### Status (health indicator)
```matlab
d.addWidget('status', 'Title', 'Pump', 'Position', [7 1 5 2], 'Sensor', sTemp);
d.addWidget('status', 'Title', 'System', 'Position', [12 1 5 2], 'StaticStatus', 'ok');
d.addWidget('status', 'Title', 'Threshold', 'Position', [17 1 5 2], ...
            'Threshold', tRule, 'ValueFcn', @() currentValue);
```
Shows a coloured dot (green/amber/red) and, when sensor‑bound, the latest value. Status is derived automatically from threshold rules.

### Gauge (arc / donut / bar / thermometer)
```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Style', 'donut');

d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', 'Style', 'arc');
```
Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When Sensor‑bound, range and units are auto‑derived from threshold rules and sensor properties.

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
    'EventStoreObj', myEventStore);
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
`PlotFcn` receives the axes handle and, when Sensor‑bound, the sensor object and optionally the current global time range.

### Event Timeline
```matlab
events = struct('startTime', {0, 3600}, 'endTime', {3600, 7200}, ...
    'label', {'Idle', 'Running'}, 'color', {[0.6 0.6 0.6], [0.2 0.7 0.3]});
d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], 'Events', events);

% From EventStore (recommended)
d.addWidget('timeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], 'EventStoreObj', myEventStore);

% Filtered by sensor names
d.addWidget('timeline', 'Title', 'Temp Events', ...
    'Position', [1 19 24 3], ...
    'EventStoreObj', myEventStore, 'FilterSensors', {'T-401','T-402'});
```

### Divider (horizontal separator)
```matlab
d.addWidget('divider', 'Position', [1 3 24 1]);
d.addWidget('divider', 'Thickness', 2);
```

### Group (panel / collapsible / tabbed containers)
```matlab
% Panel group
g = GroupWidget('Mode', 'panel', 'Label', 'Sensor Group');
g.addChild(NumberWidget('Title', 'T1'));
g.addChild(NumberWidget('Title', 'T2'));
d.addWidget(g);

% Collapsible group (via convenience method)
w1 = FastSenseWidget(...); w2 = NumberWidget(...);
d.addCollapsible('Sensor Details', {w1, w2}, 'Collapsed', true);

% Tabbed group
g = GroupWidget('Mode', 'tabbed', 'Label', 'Data Views');
g.addChild(fsWidget, 'Tab 1');
g.addChild(rawAxesWidget, 'Tab 2');
d.addWidget(g);
```

### Chip Bar (multi‑sensor status strip)
```matlab
d.addWidget('chipbar', 'Title', 'System State', 'Chips', {
    struct('label','Pump','sensor',sPump),
    struct('label','Tank','sensor',sTank),
    struct('label','Fan','statusFcn',@() 'warn')
});
```

### Icon Card (compact KPI with icon)
```matlab
d.addWidget('iconcard', 'Title', 'Temp', ...
    'StaticValue', 23.5, 'Units', 'degC', 'StaticState', 'ok');
```

### Sparkline Card (KPI + mini sparkline)
```matlab
d.addWidget('sparkline', 'Title', 'CPU', ...
    'StaticValue', 42.0, 'SparkData', cpuHistory, 'Units', '%');
```

### Bar Chart
```matlab
d.addWidget('barchart', 'Title', 'Production', ...
    'DataFcn', @() struct('categories',{{'A','B','C'}},'values',[10 20 15]));
```

### Heatmap
```matlab
d.addWidget('heatmap', 'Title', 'Matrix', 'DataFcn', @() rand(5));
```

### Histogram
```matlab
d.addWidget('histogram', 'Title', 'Distribution', 'DataFcn', @() randn(1,1000));
```

### Image
```matlab
d.addWidget('image', 'Title', 'Photo', 'File', 'photo.png');
```

### Scatter
```matlab
d.addWidget('scatter', 'Title', 'Crossplot', ...
    'SensorX', sTemp, 'SensorY', sPress);
```

### Multi‑Status (grid of status dots)
```matlab
d.addWidget('multistatus', 'Title', 'Overview', ...
    'Sensors', {s1, s2, s3}, 'ShowLabels', true);
```

For complete property lists and usage see the individual widget API pages under [[Dashboard]].

---

## Sensor Binding

Sensor objects drive the most powerful part of the dashboard. Binding a widget to a Sensor via the `Tag` property (or legacy `Sensor` alias) provides:

- **Title** — auto‑derived from `Sensor.Name` or `Sensor.Key`
- **Units** — from `Sensor.Units`
- **Value** — latest data point for number, gauge, status, icon card, etc.
- **Threshold rules** — resolved violations shown in FastSense, Status, Gauge, and Icon Card widgets
- **Live refresh** — calling `refresh()` re‑reads the sensor data

```matlab
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;
sTemp.addThresholdRule(struct('machine',1), 78, 'Direction','upper','Label','Hi Warn');
sTemp.addThresholdRule(struct('machine',1), 85, 'Direction','upper','Label','Hi Alarm');
sTemp.resolve();

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [13 1 6 2]);
d.addWidget('status', 'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Sensor', sTemp, 'Position', [13 3 12 6]);
```

---

## Multi‑Page Dashboards

Build large dashboards with tabbed pages. Each page holds its own set of widgets; the layout manages visibility automatically.

```matlab
d = DashboardEngine('Plant Monitor');
d.Theme = 'dark';

% Add pages
d.addPage('Overview');
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 1 6 2]);
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 3 24 8]);

d.addPage('Details');
d.addWidget('gauge', 'Sensor', sPress, 'Position', [1 1 8 6]);
d.addWidget('table', 'Sensor', sTemp, 'Position', [9 1 16 6]);

% Set active page
d.switchPage(1);
d.render();
```
A page‑tab bar appears at the top when multiple pages exist. The visual editor respects page boundaries.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends FastSenseTheme with dashboard‑specific fields (widget backgrounds, border colours, status indicator colours, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'light';          % or 'dark'
d.render();
```

Legacy preset names `'default'`, `'industrial'`, `'scientific'`, `'ocean'` are aliased to `'light'` for backward compatibility.

Override specific properties:
```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
d.render();
```

---

## Live Mode

DashboardEngine supports live data updates via a timer that calls `refresh()` on all widgets across all pages.

```matlab
d.LiveInterval = 2;   % seconds
d.render();
d.startLive();

% ... later
d.stopLive();
```

The toolbar shows a blue border on the Live button when active and displays the last update timestamp.

---

## Global Time Controls

The time panel at the bottom has two sliders that control the visible time range for all widgets. Moving the sliders broadcasts `setTimeRange(tStart, tEnd)` to every widget in every page.

- **FastSenseWidget** sets xlim on the FastSense axes.
- **EventTimelineWidget** adjusts the timeline view.
- **RawAxesWidget** passes the time range to the PlotFcn.

If you manually zoom a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets.

An aggregate envelope (min/max) from all plot‑based widgets is drawn behind the sliders, and event markers are shown when visible.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type.
2. A **properties panel** on the right shows settings for the selected widget.
3. **Drag handles** let you reposition widgets on the grid.
4. **Resize handles** let you change widget dimensions.
5. Click **Apply** to save property changes.
6. Click **Done** to exit edit mode.

Widget management in code:
- `d.addWidget(type, ...)` — add new widget
- `d.removeWidget(idx)` — remove widget by index
- `d.setWidgetPosition(idx, pos)` — move/resize programmatically

---

## Saving and Loading

### Save as MATLAB function (recommended)
```matlab
d.save('my_dashboard.m');
```
Generates a .m function that recreates the engine and all widgets. Reload:
```matlab
d2 = DashboardEngine.load('my_dashboard.m');
```

### Save as JSON
```matlab
DashboardSerializer.saveJSON(d.buildConfig(), 'dashboard.json');
% or via convenience:
d.save('dashboard.json');   % also calls saveJSON for .json extension
```
Load (with optional sensor resolver):
```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
```

### Export as MATLAB script (reproducible script)
```matlab
d.exportScript('rebuild_dashboard.m');
```
Creates a script with `DashboardEngine` constructor and `addWidget` calls.

---

## Info File Integration

Link an external Markdown documentation file:
```matlab
d.InfoFile = 'dashboard_help.md';
d.render();
```
An **Info** button appears in the toolbar. Clicking it renders the Markdown to styled HTML and displays it in an in‑app modal or system browser.

---

## Complete Example

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);

sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = 74 + 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
sTemp.addThresholdRule(struct(), 78, 'Direction','upper','Label','Hi Warn');
sTemp.addThresholdRule(struct(), 85, 'Direction','upper','Label','Hi Alarm');
sTemp.resolve();

sPress = Sensor('P-201', 'Name', 'Pressure');
sPress.Units = 'psi';
sPress.X = t;
sPress.Y = 55 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, 'Direction','upper','Label','Hi Warn');
sPress.addThresholdRule(struct(), 70, 'Direction','upper','Label','Hi Alarm');
sPress.resolve();

%% Build a multi‑page dashboard
d = DashboardEngine('Process Monitor — Line 4');
d.Theme = 'dark';
d.LiveInterval = 5;

% Page 1: Overview
d.addPage('Overview');
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temp', 'Position', [5 1 5 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Press', 'Position', [10 1 5 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp Status', 'Position', [15 1 5 2], ...
    'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press Status', 'Position', [20 1 5 2], ...
    'Sensor', sPress);
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

% Page 2: Diagnostics
d.addPage('Diagnostics');
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 1 8 6], ...
    'Sensor', sPress, 'Style', 'arc');
d.addWidget('sparkline', 'Title', 'Temp Trend', 'Position', [9 1 8 6], ...
    'Sensor', sTemp, 'Units', 'degF');
d.addWidget('timeline', 'Title', 'Alarms', 'Position', [1 7 24 4], ...
    'EventStoreObj', myEventStore);
d.addWidget('chipbar', 'Title', 'System Health', 'Position', [1 11 24 1], ...
    'Chips', {{'Pump', sTemp}, {'Tank', sPress}});

d.render();
```

---

## See Also

- [[API Reference: Dashboard]] — full API reference for all dashboard classes
- [[API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] — live data polling
- [[Examples]] — additional examples in `example_dashboard_engine`, `example_dashboard_all_widgets`
