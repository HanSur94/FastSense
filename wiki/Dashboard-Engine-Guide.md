<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, a visual editor, and multi-page support.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24‑column responsive |
| Tile content | FastSense instances only | 16 widget types (plots, gauges, numbers, tables, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor binding | Via addSensor per tile | Direct widget property (auto‑title, auto‑units) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets |
| Multi‑page | No | `addPage` / `switchPage` API |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines, icon cards, sparklines, etc.), JSON persistence, the visual editor, or multi‑page layouts.

DashboardEngine also supports **multi‑page** dashboards via `addPage` and `switchPage`, allowing you to organise widgets across named tabs. The toolbar automatically renders page navigation buttons when more than one page exists.

---

## Quick Start

```matlab
install;

% Create a sensor for live binding
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degC';
sTemp.X = linspace(0, 3600, 3600*10);
sTemp.Y = 22 + 5*sin(2*pi*sTemp.X/600) + 0.5*randn(size(sTemp.X));

% Build a dashboard
d = DashboardEngine('My First Dashboard');
d.Theme = 'dark';

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);

d.addWidget('number', 'Title', 'Current', ...
    'Position', [1 9 8 2], ...
    'Sensor', sTemp, 'Format', '%.1f');

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

When `addPage` is used, each page maintains its own widget list and layout. The grid is refreshed when switching pages.

---

## Widget Types

DashboardEngine supports 16 distinct widget types. Each can be added by its type string (e.g., `'fastsense'`, `'number'`) and configured with name‑value pairs.

### FastSense (time series)

The core time‑series plot widget. Supports sensor binding, inline data, file loading, and DataStore.

```matlab
% Sensor‑bound (recommended)
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);

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

When bound to a Sensor, threshold rules apply automatically. The widget title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived. Use `ShowEventMarkers = true` to overlay event markers (requires an EventStore).  

Additional properties: `XLabel`, `YLabel`, `YLimits`, `ShowThresholdLabels`, `LiveViewMode`, `EventStore`.

### Number (big value display)

Displays a large numeric value with a trend arrow.

```matlab
% Sensor‑bound
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Function callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

The trend arrow is computed from recent sensor data or callback history. Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

Colored dot indicator with sensor value.

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Status is derived automatically from threshold rules when a sensor is bound. Supports `Threshold` and `Value`/`ValueFcn` for standalone use.

### Gauge (arc/donut/bar/thermometer)

```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Range', [0 160], 'Units', 'L/min', ...
    'Style', 'donut');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When sensor‑bound, range and units are auto‑derived.

### Text (labels and headers)

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16, ...
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
    'Sensor', sTemp, 'Mode', 'events', ...
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

### Divider (visual separator)

A horizontal line to break the dashboard into sections.

```matlab
d.addWidget('divider', 'Position', [1 3 24 1], 'Thickness', 2);
% Optional: custom color
d.addWidget('divider', 'Position', [1 6 24 1], 'Color', [0.8 0.2 0.2]);
```

### Bar Chart

```matlab
% Using a callback that returns categories and values
d.addWidget('barchart', 'Title', 'Production', ...
    'Position', [1 5 8 4], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, 'values', [23 45 12]));
% Orientation and stacking
d.addWidget('barchart', 'Title', 'Stacked', ...
    'Position', [9 5 8 4], ...
    'DataFcn', @myStackedFcn, ...
    'Orientation', 'horizontal', 'Stacked', true);
```

### Chip Bar (multi‑status strip)

Compact row of mini colored dots for an at‑a‑glance health summary.

```matlab
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 1 24 1], ...
    'Chips', { ...
        struct('label', 'Pump', 'sensor', sPump), ...
        struct('label', 'Fan', 'statusFcn', @() if fanOK 'ok' else 'alarm'), ...
        struct('label', 'Tank', 'iconColor', [0.2 0.6 1.0]) });
```

Each chip struct may contain `label`, `sensor`, `statusFcn` (returning `'ok'`/`'warn'`/`'alarm'`), or `iconColor` for a fixed color.

### Heatmap

```matlab
d.addWidget('heatmap', 'Title', 'Correlation', ...
    'Position', [1 5 8 4], ...
    'DataFcn', @() rand(10), ...
    'Colormap', 'turbo', 'ShowColorbar', true, ...
    'XLabels', cellstr(num2str((1:10)')), ...
    'YLabels', cellstr(num2str((1:10)')));
```

### Histogram

```matlab
d.addWidget('histogram', 'Title', 'Distribution', ...
    'Position', [1 5 8 4], ...
    'DataFcn', @() randn(1,1000), ...
    'NumBins', 30, 'ShowNormalFit', true);
```

### Icon Card (mushroom‑style tile)

Compact card with a colored icon, primary value, and secondary label. Icon color tracks threshold state (ok/warn/alarm).

```matlab
d.addWidget('iconcard', 'Title', 'Temp', ...
    'Position', [1 1 4 2], ...
    'StaticValue', 23.5, 'Units', 'degC', 'SecondaryLabel', 'Room');

% Sensor‑bound
d.addWidget('iconcard', 'Title', 'Pressure', ...
    'Position', [5 1 4 2], ...
    'Sensor', sPress);
```

### Image

```matlab
d.addWidget('image', 'Title', 'Floor Plan', ...
    'Position', [1 5 8 6], ...
    'File', 'floorplan.png', 'Scaling', 'fit', ...
    'Caption', 'Level 1');

% Dynamic image from function
d.addWidget('image', 'Title', 'Live Camera', ...
    'Position', [9 5 8 6], ...
    'ImageFcn', @() captureFrame());
```

### Scatter

```matlab
d.addWidget('scatter', 'Title', 'Temp vs Press', ...
    'Position', [1 5 12 6], ...
    'SensorX', sTemp, 'SensorY', sPress, 'MarkerSize', 6);

% Color‑coded by third sensor
d.addWidget('scatter', 'Title', 'Temp vs Press (Flow)', ...
    'Position', [13 5 12 6], ...
    'SensorX', sTemp, 'SensorY', sPress, ...
    'SensorColor', sFlow, 'Colormap', 'parula');
```

### Sparkline Card (KPI with mini‑chart)

Combines a big‑number value with a small inline sparkline and delta indicator.

```matlab
d.addWidget('sparkline', 'Title', 'CPU Load', ...
    'Position', [1 1 4 2], ...
    'Sensor', sCpu, 'NSparkPoints', 50, 'ShowDelta', true);

% Static data
d.addWidget('sparkline', 'Title', 'Memory', ...
    'Position', [5 1 4 2], ...
    'StaticValue', 42.0, 'SparkData', memHistory, ...
    'Units', '%', 'Format', '%.0f');
```

### Group (panel / collapsible / tabbed)

Container widget that groups other widgets. Three modes: `'panel'` (flat group), `'collapsible'` (collapsible header), `'tabbed'` (tabs).

```matlab
% Panel group
w1 = NumberWidget('Title', 'Temp', 'Sensor', sTemp);
w2 = StatusWidget('Sensor', sTemp);
d.addWidget('group', 'Position', [1 1 12 4], ...
    'Label', 'Temperature', 'Children', {w1, w2});

% Collapsible group (convenience method)
d.addCollapsible('Sensor Group', {w1, w2}, 'Collapsed', false);

% Tabbed group
d.addWidget('group', 'Position', [13 1 12 4], ...
    'Mode', 'tabbed', ...
    'Tabs', { ...
        struct('name', 'Tab 1', 'widgets', {{w1, w2}}), ...
        struct('name', 'Tab 2', 'widgets', {{w3}}) });
```

When using groups, child widgets are not added directly to the dashboard with `addWidget`; they are passed as children to the group.

---

## Sensor Binding

The recommended way to drive dashboard widgets is through Sensor objects. They provide unified data, state channels, and threshold rules.

```matlab
% Create and configure sensor
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;
sTemp.addThresholdRule(struct('machine', 1), 78, ...
    'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.resolve();

% Bind to widgets
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [13 1 6 2]);
d.addWidget('status', 'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge', 'Sensor', sTemp, 'Position', [13 3 12 6]);

% Widget properties auto‑derived from Sensor:
% - Title ← Sensor.Name or Sensor.Key
% - Units ← Sensor.Units
% - Values ← Sensor.Y(end)
% - Threshold violations overlay automatically
```

> **Backward compatibility note:** The legacy `'Sensor'` name‑value pair is still accepted. Internally it maps to the `Tag` property for compatibility with newer APIs.

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

Generates a readable `.m` file that, when run, returns a `DashboardEngine` instance.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields.

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % 'light' or 'dark'
d.render();
```

**Presets:** `'light'` and `'dark'` only. Legacy preset names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are silently aliased to `'light'`.

Override specific theme properties:

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
d.LiveInterval = 2;  % seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % start periodic refresh
% ... later
d.stopLive();    % stop
```

The toolbar’s **Live** button toggles the engine‑level timer. When active, the button shows a blue border and the toolbar displays the last update timestamp.

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each time‑aware widget.

- **FastSenseWidget:** sets xlim on the FastSense axes  
- **EventTimelineWidget:** sets xlim on the timeline axes  
- **RawAxesWidget:** passes the time range to the PlotFcn  

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets. The **Reset** button re‑renders all widgets on the current page (handy for recovery from transient errors).

The time slider also renders an **aggregate preview envelope** from all visible widgets, plus **event markers** for any widgets that expose events. Use `d.EventMarkersVisible = true` to toggle this overlay globally.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type  
2. A **properties panel** appears on the right showing the selected widget’s settings  
3. **Drag handles** let you reposition widgets on the 24‑column grid  
4. **Resize handles** let you change widget dimensions  
5. Click **Apply** to save property changes  
6. Click **Done** to exit edit mode  

Group widgets, icon cards, chip bars, and sparklines can be added through the palette or programmatically.

A **Config** button on the toolbar opens a dialog that edits global dashboard properties (`Name`, `Theme`, `LiveInterval`, `ProgressMode`, etc.) without touching the code.

Widget management methods:
- `addWidget(type)` — add a new widget of the specified type  
- `deleteWidget(idx)` — remove widget by index  
- `selectWidget(idx)` — select a widget for property editing  
- `setWidgetPosition(idx, pos)` — move/resize widget programmatically  

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML and opens it in the system browser (or optionally in an in‑app modal). Supports basic Markdown syntax including headers, lists, code blocks, and tables. If no file is set, a default placeholder page explains how to link one.

---

## Complete Example

This example creates a process monitoring dashboard with sensor‑bound widgets:

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
sTemp.addThresholdRule(struct('machine', 1), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
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
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], ...
    'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], ...
    'Sensor', sPress);

% Plot row: sensor‑bound FastSense widgets
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

% Bottom row: gauge + custom plot
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

- [[Dashboard|API Reference: Dashboard]] — Full API reference for all dashboard classes  
- [[Sensors|API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule  
- [[Live Mode Guide]] — Live data polling  
- [[Examples]] — `example_dashboard_engine`, `example_dashboard_all_widgets`
