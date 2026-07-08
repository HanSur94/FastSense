<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, pages, groups, plant-log overlays, and a visual editor.

---

## Overview

The Dashboard Engine (`DashboardEngine`) is a feature‑complete dashboarding system built on a responsive 24‑column grid. It supports **12+ widget types** (plots, gauges, numbers, tables, histograms, sparkline cards, …), **sensor‑bound auto‑configuration**, **multi‑page layouts**, **collapsible/tabbed groups**, **live data refresh**, **global time controls**, and **JSON/script persistence**.

| Feature               | FastSenseGrid   | DashboardEngine |
|-----------------------|-----------------|-----------------|
| Grid                  | Fixed rows×cols | 24‑column responsive |
| Widget types          | FastSense only  | 12+ (plots, gauges, KPIs, tables, histograms, sparkline cards, …) |
| Multi‑page            | No              | Yes (named pages with tab bar) |
| Group containers      | No              | Panel, collapsible, tabbed groups |
| Persistence           | None            | JSON save/load + `.m` script export |
| Visual editor         | No              | Yes (drag/resize, palette, properties panel) |
| Scrolling             | No              | Auto‑scrollbar when content overflows |
| Global time           | No              | Dual sliders + data‑preview envelope controlling all widgets |
| Sensor binding        | Per‑tile addSensor | Direct widget property (auto‑title, auto‑units, thresholds) |
| Live mode             | Per‑figure timer | Engine‑level timer refreshing all widgets |
| Plant‑log overlay     | No              | Per‑widget vertical markers from plant‑log files |
| Detachable widgets    | No              | Detach any widget as a standalone live‑mirrored window |

**When to use FastSenseGrid:** Simple tiled FastSense time‑series plots with linked axes and a toolbar.

**When to use DashboardEngine:** Mixed widget types, multi‑page layouts, JSON persistence, visual editor, live sensor binding, or plant‑log overlays.

---

## Quick Start

```matlab
install;

% Create a DashboardEngine instance
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';
d.LiveInterval = 2;          % refresh every 2 sec

% Add widgets with grid positions [col row width height]
d.addWidget('fastsense', 'Title', 'Signal', ...
    'Position', [1 1 24 6], ...
    'XData', linspace(0, 100, 1000), ...
    'YData', sin(linspace(0, 10, 1000)) + 0.1*randn(1,1000));

d.addWidget('number', 'Title', 'Latest Value', ...
    'Position', [1 7 8 2], ...
    'StaticValue', 1.23, 'Units', 'V');

d.render();  % must be called once after construction

% Save dashboard (later reload with DashboardEngine.load('file.json'))
d.save('myDashboard.json');
```

---

## Grid System

Positions use **`[col, row, width, height]`** in a **24‑column grid**. Rows start at 1 (top) and grow downward. Width & height are in column/row units.

```matlab
[1 1 24 4]   % full width, 4 rows tall
[1 1 12 4]   % left half
[13 1 12 4]  % right half
[1 5 8 2]    % left third, row 5
```

Overlapping widgets are automatically pushed downward to the next free row.

---

## Widget Types

### FastSense (time‑series)

Primary data‑binding widget. Wraps a `FastSense` instance.

```matlab
% Sensor‑bound (auto‑title, units, thresholds)
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', sensorObj);

% Inline data
d.addWidget('fastsense', 'Title', 'Raw', 'Position', [13 1 12 8], ...
    'XData', t, 'YData', y);

% From MAT file
d.addWidget('fastsense', 'Title', 'File', 'Position', [1 9 24 6], ...
    'File', 'data.mat', 'XVar', 'x', 'YVar', 'y');

% From DataStore
d.addWidget('fastsense', 'Title', 'Store', 'Position', [1 15 24 6], ...
    'DataStore', myDataStore);
```

Threshold lines and violations are drawn automatically when bound to a `Sensor` with resolved rules.

### Number (KPI card)

Large numeric display with optional trend arrow.

```matlab
% From a Sensor
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Dynamic callback
d.addWidget('number', 'Title', 'CPU', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

### Status (health indicator)

Colored dot (green/amber/red) with auto‑derived state from a `Sensor` or threshold rule.

```matlab
% Sensor‑bound (state from threshold rules)
d.addWidget('status', 'Title', 'Pump', 'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Threshold‑driven (no Sensor needed)
d.addWidget('status', 'Title', 'System', 'Position', [12 1 5 2], ...
    'Threshold', 'system_hi', 'ValueFcn', @() getSystemValue());

% MonitorTag bound via 'Tag' — its 0/1 alarm signal maps straight to
% 'violation' (red) / 'ok' (green), no separate 'Threshold' binding needed
d.addWidget('status', 'Title', 'Alarm', 'Position', [17 1 5 2], ...
    'Tag', alarm);

% Legacy static
d.addWidget('status', 'Title', 'System', 'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');   % 'ok' | 'warning' | 'alarm'
```

### Gauge (arc / donut / bar / thermometer)

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

When `Sensor`‑bound, range, units and thresholds are auto‑derived.

### Text (label / header)

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 - Shift A', 'FontSize', 16, ...
    'Alignment', 'center');
```

### Table

```matlab
% Static
d.addWidget('table', 'Title', 'Alarm Log', ...
    'Position', [13 9 12 4], ...
    'ColumnNames', {'Time','Tag','Value'}, ...
    'Data', {{'12:00','T-401','85.2';'12:05','P-201','72.1'}});

% Last N rows from Sensor
d.addWidget('table', 'Title', 'Recent Data', ...
    'Position', [1 9 12 4], ...
    'Sensor', sTemp, 'N', 15);

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Sensor', sTemp, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

### Raw Axes (custom plot)

```matlab
d.addWidget('rawaxes', 'Title', 'Temperature Distribution', ...
    'Position', [1 5 8 4], ...
    'PlotFcn', @(ax) histogram(ax, tempData, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

% Sensor‑bound with time range
d.addWidget('rawaxes', 'Title', 'Custom Analysis', ...
    'Position', [9 5 8 4], ...
    'Sensor', sTemp, ...
    'PlotFcn', @(ax, sensor, tRange) customPlot(ax, sensor, tRange));
```

### Event Timeline

```matlab
events = struct('startTime', {0,3600}, 'endTime', {3600,7200}, ...
    'label', {'Idle','Running'}, 'color', {[0.6 0.6 0.6],[0.2 0.7 0.3]});

d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], 'Events', events);

% From EventStore (preferred)
d.addWidget('timeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], ...
    'EventStoreObj', myEventStore);
```

### Sparkline Card

KPI card combining a big number, delta indicator, and a mini sparkline chart.

```matlab
d.addWidget('sparkline', 'Title', 'CPU Load', ...
    'Position', [1 1 6 3], ...
    'Sensor', sCPU, 'Units', '%', 'Format', '%.0f', ...
    'NSparkPoints', 60);
```

You can also provide `StaticValue` and `SparkData` vector directly.

### Icon Card (Mushroom‑style)

```matlab
d.addWidget('iconcard', 'Title', 'Temp', ...
    'Position', [1 1 4 2], ...
    'Sensor', sTemp, 'Units', 'degC');
```

State‑colored circle icon, numeric value, and label.

### Chip Bar

Horizontal row of mini status chips for system health summary.

```matlab
d.addWidget('chipbar', 'Title', 'Health', ...
    'Position', [1 1 24 1], ...
    'Chips', {
        struct('label','Pump', 'statusFcn',@() 'ok'),
        struct('label','Tank', 'statusFcn',@() 'warn'),
        struct('label','Fan',  'statusFcn',@() 'alarm')
    });
```

### Bar Chart

```matlab
d.addWidget('barchart', 'Title', 'Production', ...
    'Position', [1 1 12 6], ...
    'DataFcn', @() struct('categories',{{'A','B'}},'values',[10 20]), ...
    'Orientation', 'horizontal');
```

### Heatmap

```matlab
d.addWidget('heatmap', 'Title', 'Matrix', ...
    'Position', [1 1 8 6], ...
    'DataFcn', @() rand(10), 'Colormap', 'jet', ...
    'XLabels', sprintfc('C%d',1:10), 'YLabels', sprintfc('R%d',1:10));
```

### Histogram

```matlab
d.addWidget('histogram', 'Title', 'Distribution', ...
    'Position', [1 1 8 4], ...
    'DataFcn', @() randn(1000,1), 'NumBins', 30);
```

### Scatter

```matlab
d.addWidget('scatter', 'Title', 'Temp vs Press', ...
    'Position', [1 1 12 8], ...
    'SensorX', sTemp, 'SensorY', sPress, 'MarkerSize', 4);
```

### Image

```matlab
d.addWidget('image', 'Title', 'Schematic', ...
    'Position', [1 1 8 6], ...
    'File', 'plant_schematic.png');
```

### Divider (horizontal rule)

```matlab
d.addWidget('divider', 'Position', [1 5 24 1]);
% or with custom thickness
d.addWidget('divider', 'Thickness', 2);
```

---

## Multi‑page Layouts

Create named pages and switch between them via the tab bar.

```matlab
d = DashboardEngine('Multi‑page');
d.Theme = 'dark';

% Add pages
pg1 = d.addPage('Overview');
pg2 = d.addPage('Details');

d.addWidget('fastsense', ...);   % goes to active page (last added)
d.addWidget('number', ...);

d.switchPage(1);                 % now active page is 'Overview'
d.addWidget('text', ...);
```

Pages are serialized/deserialized automatically.

---

## Group Containers

Group widgets visually (panel), collapsibly, or as tabs.

```matlab
% Collapsible group
d.addCollapsible('Sensors', {widget1, widget2}, 'Collapsed', false);

% Tabbed group
g = GroupWidget('Mode', 'tabbed', 'Label', 'Views');
g.addChild(widgetA, 'Raw');
g.addChild(widgetB, 'Trend');
d.addWidget(g);
```

Groups support nesting, reflow on collapse/expand, and are fully serializable.

---

## Sensor Binding

Bind a `Sensor` object to any data widget for automatic title, units, and range derivation.

```matlab
sTemp = Sensor('T-401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;   sTemp.Y = temp;
sTemp.addThresholdRule(struct('machine',1), 78, 'Direction','upper','Label','Hi Warn');
sTemp.addThresholdRule(struct('machine',1), 85, 'Direction','upper','Label','Hi Alarm');
sTemp.resolve();

% Auto‑configure widgets
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number',    'Sensor', sTemp, 'Position', [13 1 6 2]);
d.addWidget('status',    'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge',     'Sensor', sTemp, 'Position', [13 3 12 6]);
```

Widgets react to sensor changes on `refresh()`.

---

## Theming

```matlab
d.Theme = 'dark';   % 'light', 'dark' 
d.render();

% per‑widget override
widget.ThemeOverride = struct('WidgetBackground', [0.1 0.1 0.2]);
```

Theme presets cover all widget colours, toolbar, and font sizes. The `DashboardTheme` function generates the full struct.

---

## Live Mode

Start a periodic refresh timer.

```matlab
d.LiveInterval = 2;        % seconds
d.render();
d.startLive();
% ... d.stopLive();
```

A toolbar button toggles live mode. During live updates a stale‑data banner warns if any widget’s timestamp hasn’t advanced.

---

## Global Time Controls

A time‑range selector with dual sliders and a data‑preview envelope sits at the bottom of the dashboard. Moving the sliders broadcasts `setTimeRange(tStart, tEnd)` to all widgets that have `UseGlobalTime = true`.

```matlab
d.broadcastTimeRange(3600, 7200);   % programmatic
```

Widgets that are manually zoomed detach from global time. The **Sync** toolbar button re‑attaches all widgets.

---

## Plant‑Log Integration

Attach a plant‑log file to overlay per‑widget vertical markers.

```matlab
store = d.attachPlantLog('plant_log.csv', ...
    'Interval', 5, 'StartTail', true);
% Each widget shows plant‑log markers when the toggle is enabled.
% Remove with:
d.detachPlantLog();
```

A toggle button (added to each widget’s chrome) switches the overlay on/off.

---

## Detachable Mirrors

Pop any widget into its own live‑mirrored figure.

```matlab
d.detachWidget(someWidget);
% The mirror is updated by the engine’s live timer.
```

---

## Visual Editor

Enter edit mode via the **Edit** button in the toolbar.

- Palette sidebar for adding widgets
- Drag handles for repositioning (snaps to grid)
- Resize handles
- Properties panel to change title, position, data source, etc.

Widget management APIs:

```matlab
d.addWidget('type', ...);
d.deleteWidget(idx);
d.selectWidget(idx);
d.setWidgetPosition(idx, [col row w h]);
```

---

## Info File

Link an external Markdown file to the dashboard’s Info button.

```matlab
d.InfoFile = 'dashboard_help.md';
d.render();
```

Clicking Info renders the Markdown as HTML and displays it in‑app.

---

## Save, Load, Export

### JSON

```matlab
d.save('dashboard.json');
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

### Image (PNG / JPEG)

```matlab
d.exportImage('output.png');   % format from extension
```

---

## Complete Example

```matlab
install;

% Generate data
rng(42);
t = linspace(0, 86400, 10000);
yTemp = 74 + 3*sin(2*pi*t/3600) + 1.2*randn(size(t));
sTemp = Sensor('T-401','Name','Temperature','Units','degF');
sTemp.X = t; sTemp.Y = yTemp;
sTemp.addThresholdRule(struct(), 78, 'Direction','upper','Label','Hi Warn');
sTemp.addThresholdRule(struct(), 85, 'Direction','upper','Label','Hi Alarm');
sTemp.resolve();

d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Header row
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('status', 'Title', 'Status', 'Position', [10 1 5 2], ...
    'Sensor', sTemp);
d.addWidget('sparkline', 'Title', 'CPU', 'Position', [15 1 5 2], ...
    'Sensor', sTemp, 'Units', 'degF');

% Main plot row
d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('rawaxes', 'Title', 'Histogram', 'Position', [13 3 12 8], ...
    'PlotFcn', @(ax) histogram(ax, sTemp.Y, 50));
d.addWidget('gauge', 'Title', 'Temp Gauge', 'Position', [1 11 8 6], ...
    'Sensor', sTemp, 'Range', [0 100], 'Units', 'degF');
d.addWidget('divider', 'Position', [9 11 1 6]);

d.render();
d.save(fullfile(tempdir,'process_dashboard.json'));
```

---

## See Also

- [[API Reference: Dashboard]] – Full API reference for all dashboard classes
- [[API Reference: Sensors]] – Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] – Live data polling
- [[Examples]] – `example_dashboard_engine`, `example_dashboard_all_widgets`
