<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, multi‑page support, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24‑column responsive |
| Tile content | FastSense instances only | 15 widget types (plots, gauges, numbers, tables, cards, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor binding | Via addSensor per tile | [[Sensor]] or [[Tag]] API (auto‑title, auto‑units, thresholds) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets |
| Multi‑page | No | Named pages with tab‑bar navigation |
| Container widgets | No | Group, Collapsible, Tabbed groups |
| Stale‑data warning | No | Banner when live data stops advancing |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines, cards, sparklines), JSON persistence, multi‑page layouts, or the visual editor.

---

## Quick Start

```matlab
install;

% Some example data
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

```matlab
Position = [col, row, width, height]
```

- `col`: column (1–24), left to right
- `row`: row (1+), top to bottom
- `width`: number of columns to span (1–24)
- `height`: number of rows to span

**Examples:**
```matlab
[1 1 24 4]   % Full width, 4 rows tall, top
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

If a new widget overlaps an existing one, it is automatically pushed down to the next free row.

---

## Widget Types

### FastSense (time series)

```matlab
% Sensor‑bound (preferred — uses Tag API or legacy Sensor parameter)
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

When bound to a [[Sensor]] (via `'Sensor', sensorObj`), threshold rules apply automatically (resolved violations are shown). The widget title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived. The `'Sensor'` parameter is a backward‑compatible alias for the newer Tag property; both work identically.

### Number (big value display)

```matlab
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [1 1 6 2], ...
    'Sensor', sTemp, 'Units', 'degF', 'Format', '%.1f');

% Static value
d.addWidget('number', 'Title', 'Total Count', ...
    'Position', [7 1 6 2], ...
    'StaticValue', 1234, 'Units', 'pcs', 'Format', '%d');

% Function callback
d.addWidget('number', 'Title', 'CPU Load', ...
    'Position', [13 1 6 2], ...
    'ValueFcn', @() getCpuLoad(), 'Units', '%', 'Format', '%.0f');
```

Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data. Layout: `[Title | Value+Trend | Units]`.

### Status (health indicator)

```matlab
% From a Sensor (auto‑resolves status via thresholds)
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'

% Threshold‑driven (no Sensor)
d.addWidget('status', 'Title', 'Temp Alarm', ...
    'Position', [17 1 5 2], ...
    'Threshold', myThreshold, 'ValueFcn', @getTemp);
```

Shows a colored dot (green/amber/red) and the sensor’s latest value. Status is derived automatically from threshold rules when bound to a Sensor or a Threshold object.

### Gauge (arc/donut/bar/thermometer)

```matlab
% Sensor‑bound
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Range', [0 160], 'Units', 'L/min', ...
    'Style', 'donut');

% Static value
d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', ...
    'Style', 'arc');

% Threshold‑driven
d.addWidget('gauge', 'Title', 'Pressure', ...
    'Position', [17 3 8 6], ...
    'Threshold', myThreshold, 'ValueFcn', @getPressure);
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`.  
When Sensor‑bound, range and units are auto‑derived from threshold rules and sensor properties.

### Text (labels and headers)

```matlab
d.addWidget('text', 'Title', 'Plant Overview', ...
    'Position', [1 1 6 1], ...
    'Content', 'Line 4 - Shift A', 'FontSize', 16, ...
    'Alignment', 'center');
```

### Divider (horizontal rule)

```matlab
d.addWidget('divider', 'Position', [1 3 24 1]);
d.addWidget('divider', 'Thickness', 2, 'Color', [0.8 0.2 0.2]);
```

A simple horizontal line for visual section breaks.

### Table (data display)

```matlab
% Static data
d.addWidget('table', 'Title', 'Alarm Log', ...
    'Position', [13 9 12 4], ...
    'ColumnNames', {'Time', 'Tag', 'Value'}, ...
    'Data', {{'12:00', 'T-401', '85.2'; '12:05', 'P-201', '72.1'}});

% Sensor last N rows
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

### IconCard (Mushroom‑style status card)

```matlab
d.addWidget('iconcard', 'Title', 'Temp', ...
    'Position', [1 1 4 2], ...
    'Sensor', sTemp, 'Units', 'degC');

% With static state
d.addWidget('iconcard', 'Title', 'Pump', ...
    'Position', [5 1 4 2], ...
    'StaticValue', 85, 'StaticState', 'ok', 'Units', '%');
```

Compact card with a colored circle icon (reflects threshold state), a primary numeric value, and a secondary label. Supports `StaticValue`, `Sensor`, or `ValueFcn`.

### ChipBar (inline status chips)

```matlab
% Manually defined chips
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 1 12 1], ...
    'Chips', { ...
        struct('label', 'Pump',  'statusFcn', @() 'ok'), ...
        struct('label', 'Tank',  'statusFcn', @() 'warn'), ...
        struct('label', 'Fan',   'statusFcn', @() 'alarm') ...
    });

% Sensor‑driven chips (auto color)
d.addWidget('chipbar', 'Title', 'Sensors', ...
    'Position', [1 2 12 1], ...
    'Chips', { ...
        struct('label', 'T-401', 'sensor', sTemp), ...
        struct('label', 'P-201', 'sensor', sPress) ...
    });
```

A horizontal row of colored circles with labels — a dense multi‑sensor status overview at a glance.

### SparklineCard (KPI with mini chart)

```matlab
d.addWidget('sparkline', 'Title', 'CPU', ...
    'Position', [1 1 6 3], ...
    'Sensor', sCpu, 'Units', '%', 'Format', '%.1f');

% Static value + sparkline vector
d.addWidget('sparkline', 'Title', 'Memory', ...
    'Position', [7 1 6 3], ...
    'StaticValue', 42.5, 'SparkData', memoryHistory, 'Units', 'GB');
```

Combines a large KPI number with a tiny sparkline chart and a delta indicator (showing change direction/magnitude). The sparkline uses the last `NSparkPoints` (default 50) values.

### BarChart and Histogram

```matlab
% Bar chart from a callback
d.addWidget('barchart', 'Title', 'Category Counts', ...
    'Position', [1 1 8 4], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, 'values', [10 25 15]), ...
    'Orientation', 'vertical');

% Histogram of live data
d.addWidget('histogram', 'Title', 'Distribution', ...
    'Position', [9 1 8 4], ...
    'DataFcn', @() randn(1,1000), ...
    'NumBins', 30, 'ShowNormalFit', true);
```

### Scatter (X‑Y from two sensors)

```matlab
d.addWidget('scatter', 'Title', 'Temp vs Pressure', ...
    'Position', [1 1 12 6], ...
    'SensorX', sTemp, 'SensorY', sPress, ...
    'MarkerSize', 8, 'Colormap', 'jet');
```

### Image (static or dynamic)

```matlab
d.addWidget('image', 'Title', 'Site Plan', ...
    'Position', [1 1 12 6], ...
    'File', 'floorplan.png', 'Scaling', 'fit');

% Dynamic image from callback
d.addWidget('image', 'Title', 'Snapshot', ...
    'Position', [13 1 12 6], ...
    'ImageFcn', @() snapshotCamera(), 'Caption', 'Latest frame');
```

### Container Widgets: Group, Collapsible, Tabs

```matlab
% Simple group of widgets
grp = GroupWidget('Label', 'Sensors Group', 'Mode', 'panel');
grp.addChild(w1); grp.addChild(w2);
d.addWidget(grp);

% Collapsible group
d.addCollapsible('Sensors', {w1, w2}, 'Collapsed', false);

% Tabbed group
d.addWidget('group', 'Mode', 'tabbed', ...
    'Label', 'Views', 'Tabs', { ...
        struct('name', 'Table', 'widgets', {{tbl}}), ...
        struct('name', 'Chart', 'widgets', {{chart}}) ...
    });
```

The visual editor (Edit button) can manage these as well.

---

## Sensor Binding ([[Sensor]] and [[Tag]] API)

All widgets support binding to a Sensor object via the `'Sensor'` parameter (backward‑compatible) or the newer `'Tag'` parameter (v2.0). Both work identically — the engine uses a unified Tag property:

```matlab
% Create and configure a sensor
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

% Bind it to widgets (legacy style)
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number',   'Sensor', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status',   'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge',    'Sensor', sTemp, 'Position', [13 3 12 6]);

% New‑style: use 'Tag' (same effect)
d.addWidget('fastsense', 'Tag', sTemp, 'Position', [1 1 12 8]);
```

**Benefits of Sensor/Tag binding:**
- **Title:** auto‑derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto‑derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, status, iconcard, etc.
- **Thresholds:** FastSenseWidget renders resolved thresholds; StatusWidget checks against all rules
- **Live refresh:** calling `refresh()` re‑reads sensor data

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON includes the dashboard name, theme, live interval, pages (if multi‑page), and every widget’s type, title, position, and data source.

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re‑bind Sensor objects on load, provide a resolver:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### Export as MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` function that returns a DashboardEngine with all `addWidget` calls. Useful for version control or sharing.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colors, status colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

**Presets:** `'light'` (default), `'dark'`.  
Legacy names `'industrial'`, `'scientific'`, `'ocean'`, `'default'` are aliased to `'light'`.

Override specific properties:

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

You can also toggle live mode from the toolbar’s **Live** button (blue border when active). The toolbar shows the last update timestamp.

A **stale‑data banner** appears automatically when any widget stops receiving fresh data during live mode.

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on every widget.  

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the PlotFcn

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets.

The time panel also shows an envelope of the aggregate min/max across all widgets (a preview of data density), and can display event markers as small vertical lines.

---

## Multi‑Page Support

For complex dashboards, you can split widgets across named pages:

```matlab
d = DashboardEngine('Process Overview');
d.Theme = 'light';

% Page 1: Summary
pg1 = d.addPage('Overview');
d.switchPage(1);   % becomes active page (or via toolbar tabs)
d.addWidget('number', 'Title', 'Temp', 'Sensor', sTemp, 'Position', [1 1 6 2]);
d.addWidget('number', 'Title', 'Press', 'Sensor', sPress, 'Position', [7 1 6 2]);

% Page 2: Details
pg2 = d.addPage('Details');
d.switchPage(2);
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('fastsense', 'Sensor', sPress, 'Position', [13 1 12 8]);

d.render();
```

A tab‑bar appears at the top of the dashboard for page navigation. Widgets are rendered only on the active page; switching pages uses panel visibility toggling for fast response.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type
2. A **properties panel** appears on the right showing the selected widget’s settings
3. **Drag handles** let you reposition widgets on the grid
4. **Resize handles** let you change widget dimensions
5. Click **Apply** to save property changes
6. Click **Done** to exit edit mode

The editor snaps to the 24‑column grid. You can change title, position, axis labels, and data source directly in the properties panel.

Programmatic widget management:
- `addWidget(type, ...)` – add a new widget
- `deleteWidget(idx)` – remove widget by index
- `setWidgetPosition(idx, pos)` – reposition/resize programmatically
- `detachWidget(widget)` – pop a widget into a standalone window (live‑mirrored)
- `getWidgetByTitle(title)` – find a widget by its Title

---

## Info File Integration

Link external Markdown documentation to your dashboard:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown as HTML and opens it in an in‑app modal window (or the system browser as fallback). It supports headings, lists, code blocks, tables, and images.

---

## Complete Example

This example creates a multi‑page process monitoring dashboard:

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

%% Build dashboard with two pages
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;

% Page 1: Summary
d.addPage('Overview');
d.addWidget('text', 'Title', 'Overview', 'Position', [1 1 4 2], ...
    'Content', 'Line 4 — Shift A', 'FontSize', 16);
d.addWidget('number', 'Title', 'Temperature', 'Position', [5 1 5 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [10 1 5 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [15 1 5 2], 'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [20 1 5 2], 'Sensor', sPress);

% Page 2: Details
d.addPage('Details');
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 1 12 8], 'Sensor', sPress);
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 9 8 6], ...
    'Sensor', sPress, 'Range', [0 100], 'Units', 'psi');
d.addWidget('rawaxes', 'Title', 'Temp Distribution', 'Position', [9 9 8 6], ...
    'PlotFcn', @(ax) histogram(ax, sTemp.Y, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

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
