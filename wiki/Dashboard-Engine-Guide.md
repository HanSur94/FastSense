<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, multi-page layouts, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows × cols | 24-column responsive |
| Tile content | FastSense instances only | 19 widget types (plots, gauges, KPIs, tables, timelines, bar charts, heatmaps, images, …) |
| Grouping | No | Collapsible panels, tabbed containers |
| Multi-page | No | Named pages with switching |
| Persistence | None | JSON save/load + `.m` script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto-scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets |
| Sensor binding | Via `addSensor` per tile | Direct widget property (auto-title, auto-units) |
| Live mode | Per-figure timer | Engine-level timer refreshing all widgets |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types, grouping, multi-page layouts, JSON persistence, or the visual editor.

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

**Benefits of Sensor binding:**
- **Title:** auto-derived from `Sensor.Name` or `Sensor.Key`
- **Units:** auto-derived from `Sensor.Units`
- **Value:** uses `Sensor.Y(end)` for number, gauge, status, sparkline, and iconcards
- **Thresholds:** FastSenseWidget renders resolved thresholds and violations; StatusWidget and IconCardWidget derive state color automatically
- **Sparkline data:** SparklineCardWidget uses the sensor history for its mini‑chart
- **Live refresh:** calling `refresh()` re-reads the sensor data

You can also bind widgets to a Tag (v2.0 API) directly, but the `'Sensor'` syntax is retained for backward compatibility.

---

## Widget Types

DashboardEngine supports 19 widget types. All can be added via `d.addWidget(type, 'Property', value, ...)`, or by constructing the widget object and passing it to `addWidget`.

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

When bound to a Sensor, threshold rules apply automatically (resolved violations are shown). The widget title, X-axis label (`'Time'`), and Y-axis label (sensor Units or Name) are auto-derived.

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

Shows a large number with a trend arrow (up/down/flat) computed from recent sensor data.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'

% Threshold‑bound (no Sensor required)
d.addWidget('status', 'Title', 'Temp', ...
    'Position', [17 1 5 2], ...
    'Threshold', myThreshold, 'ValueFcn', @() readTemp());
```

Shows a colored dot (green/amber/red) and the current value. Status is derived automatically from threshold rules or a static string.

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

% Thermometer style
d.addWidget('gauge', 'Title', 'Level', ...
    'Position', [17 3 8 6], ...
    'Sensor', sLevel, 'Range', [0 100], ...
    'Style', 'thermometer');
```

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`. When Sensor-bound, range and units are auto-derived from threshold rules and sensor properties.

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

The `PlotFcn` receives MATLAB axes as the first argument. When Sensor-bound, it also receives the Sensor object and optionally a time range.

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

### Bar Chart

```matlab
d.addWidget('barchart', 'Title', 'Production', ...
    'Position', [1 1 12 6], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, ...
                          'values', [120, 95, 150]), ...
    'Orientation', 'vertical', 'Stacked', false);
```

The callback must return a struct with fields `categories` (cell array of strings) and `values` (numeric vector). Use `'Orientation', 'horizontal'` for horizontal bars.

### Chip Bar (multi‑sensor health summary)

```matlab
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 1 24 1], ...
    'Chips', { ...
        struct('label', 'Pump',  'statusFcn', @() 'ok'), ...
        struct('label', 'Tank',  'sensor', sTank), ...
        struct('label', 'Fan',   'statusFcn', @() 'warn') ...
    });
```

Displays a compact horizontal row of colored status circles, ideal for system‑health overviews. Each chip can derive color from a sensor’s threshold state, a status callback, or a static RGB.

### Divider (horizontal line)

```matlab
d.addWidget('divider', 'Position', [1 3 24 1], 'Thickness', 2, 'Color', [0.7 0.7 0.7]);
```

Use to visually separate dashboard sections. Thickness goes from 1 (thin) to 3 (thick).

### Group (panel, collapsible, tabbed)

Group widgets let you nest child widgets.

```matlab
% Simple panel
w = GroupWidget('Label', 'Process Overview', 'Mode', 'panel');
w.Children = {w1, w2, w3};
d.addWidget(w);

% Collapsible group with auto‑flow children
d.addCollapsible('Sensor Details', {w1, w2}, 'Position', [1 1 6 4]);

% Tabbed group
gt = GroupWidget('Label', 'Details', 'Mode', 'tabbed');
gt.Tabs = { ...
    struct('name', 'Temp', 'widgets', {{w_temp1, w_temp2}}), ...
    struct('name', 'Press', 'widgets', {{w_press1}}) };
d.addWidget(gt, 'Position', [1 1 12 6]);
```

The collapsible shortcut method `addCollapsible` creates a `GroupWidget` with `Mode='collapsible'` and auto‑positions child widgets. Tabbed groups display one tab at a time.

### Heatmap

```matlab
d.addWidget('heatmap', 'Title', 'Correlation', ...
    'Position', [1 1 6 6], ...
    'DataFcn', @() corrMat, ...
    'Colormap', 'parula', 'ShowColorbar', true);
```

### Histogram

```matlab
d.addWidget('histogram', 'Title', 'Temp Distribution', ...
    'Position', [1 1 6 4], ...
    'DataFcn', @() tempData, ...
    'NumBins', 30, 'ShowNormalFit', true);
```

### IconCard (Mushroom‑style card)

```matlab
% Sensor‑bound – state color automatically derived
d.addWidget('iconcard', 'Title', 'Pump', ...
    'Position', [1 1 4 2], ...
    'Sensor', sPump, 'Units', 'rpm', 'Format', '%.0f');

% Static state
d.addWidget('iconcard', 'Title', 'Motor', ...
    'Position', [5 1 4 2], ...
    'StaticValue', 0, 'StaticState', 'inactive', 'SecondaryLabel', 'Off');
```

Displays a colored icon circle, a large primary value, and a subtitle label. Icon color reflects the current threshold state (ok/warn/alarm/info/inactive).

### Image

```matlab
d.addWidget('image', 'Title', 'Site Layout', ...
    'Position', [1 1 8 6], ...
    'File', 'layout.png', 'Scaling', 'fit', 'Caption', 'Floor 2');
```

### MultiStatus (grid of status dots)

```matlab
d.addWidget('multistatus', 'Title', 'Pumps', ...
    'Position', [1 1 6 3], ...
    'Sensors', {sPump1, sPump2, sPump3}, ...
    'ShowLabels', true, 'IconStyle', 'square');
```

### Scatter (sensor vs sensor)

```matlab
d.addWidget('scatter', 'Title', 'Temp vs Load', ...
    'Position', [1 1 8 6], ...
    'SensorX', sTemp, 'SensorY', sLoad, ...
    'MarkerSize', 6, 'Colormap', 'parula');
```

Optionally color‑code points with a third sensor via `SensorColor`.

### SparklineCard (KPI with mini‑chart)

```matlab
d.addWidget('sparklinecard', 'Title', 'CPU Load', ...
    'Position', [1 1 4 2], ...
    'StaticValue', 42.5, 'SparkData', cpuHistory, ...
    'Units', '%', 'ShowDelta', true, 'DeltaFormat', '%+.1f');
```

Sensor‑bound: the sparkline shows the sensor’s last N points, the value is the latest reading, and the delta is derived from the slope.

---

## Grouping Widgets

You can organize widgets into collapsible panels or tabbed containers using the `GroupWidget` class.

**Collapsible groups** are created with `addCollapsible`:

```matlab
w1 = NumberWidget('Title', 'Temp', ...);
w2 = NumberWidget('Title', 'Pressure', ...);
d.addCollapsible('Sensor KPIs', {w1, w2}, ...
    'Position', [1 1 12 4], 'Collapsed', false);
```

This automatically arranges the children within the group’s grid area. Set `ChildAutoFlow = true` (default) to let the group auto‑position children.

**Tabbed groups** allow switching between sets of widgets:

```matlab
gt = GroupWidget('Label', 'Details', 'Mode', 'tabbed');
gt.Tabs = { ...
    struct('name', 'Temp', 'widgets', {{w_temp1, w_temp2}}), ...
    struct('name', 'Press', 'widgets', {{w_press1}}) };
d.addWidget(gt, 'Position', [1 1 12 6]);
```

Call `gt.switchTab('Press')` programmatically, or let the user click the tab headers.

---

## Multi‑Page Dashboards

Large dashboards can be split into named pages with a page bar for switching:

```matlab
d = DashboardEngine('Plant Monitor');
d.addPage('Overview');       % now the active page
d.addWidget('fastsense', ...);  % goes to Overview

d.addPage('Details');        % switches to Details page
d.addWidget('table', ...);

d.render();                  % renders the active page with a page bar
```

Switch pages programmatically: `d.switchPage(2)` (index). The toolbar includes a page bar when pages exist.

---

## Live Mode

DashboardEngine supports live data updates via a timer that periodically calls `refresh()` on all widgets.

```matlab
d = DashboardEngine('Live Monitor');
d.Theme = 'dark';
d.LiveInterval = 2;  % refresh every 2 seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);

d.render();
d.startLive();   % start periodic refresh
% ... later
d.stopLive();    % stop
```

You can also toggle live mode from the toolbar’s **Live** button. The toolbar shows the last update timestamp when live mode is active.

**Stale data detection:** If a widget’s time range hasn’t advanced on a live tick, a banner warns the user. The banner can be dismissed, and it stays hidden until data resumes.

---

## Global Time Controls

The time panel at the bottom of the dashboard has two sliders that control the visible time range across all widgets. Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget.

- **FastSenseWidget:** sets xlim on the FastSense axes
- **EventTimelineWidget:** sets xlim on the timeline axes
- **RawAxesWidget:** passes the time range to the PlotFcn
- **GaugeWidget & others:** unaffected unless they implement time control

If a user manually zooms a specific widget, that widget detaches from global time (`UseGlobalTime = false`). Click the **Sync** button in the toolbar to re‑attach all widgets.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears on the left with buttons for each widget type
2. A **properties panel** appears on the right showing the selected widget’s settings
3. **Drag handles** let you reposition widgets on the grid
4. **Resize handles** let you change widget dimensions
5. Click **Apply** to save property changes
6. Click **Done** to exit edit mode

The editor snaps to the 24-column grid. You can change the widget’s title, position, axis labels, and data source directly in the properties panel.

Programmatic widget management functions:
- `d.addWidget(type)` — add a new widget of the specified type
- `d.removeWidget(idx)` — remove widget by index
- `d.setWidgetPosition(idx, pos)` — move/resize widget programmatically
- `d.getWidgetByTitle(title)` — find a widget by its Title

---

## Saving and Loading

### Save to MATLAB function (recommended)

```matlab
d.save('dashboard.json');
```

This generates a `.m` function that returns a `DashboardEngine` instance. The file can be loaded with:

```matlab
d2 = DashboardEngine.load('dashboard.m');
d2.render();
```

### Save to JSON

```matlab
d.saveJSON('dashboard.json');
```

Load back with sensor resolution:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
d2.render();
```

### Export as standalone script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` file that reconstructs the dashboard using `DashboardEngine` constructor and `addWidget` calls.

### Export image (PNG/JPEG)

```matlab
d.exportImage('dashboard.png');         % PNG at 150 DPI
d.exportImage('dashboard.jpg', 'jpeg'); % JPEG
```

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard-specific fields (widget backgrounds, border colors, status indicator colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

**Available presets:** `'light'` (default) and `'dark'`. Legacy preset names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are aliased to `'light'` for backward compatibility.

You can override specific theme properties:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2], 'KpiFontSize', 32);
d.Theme = theme;
```

Theme changes propagate to the toolbar, time panel, and all widgets.

---

## Info File Integration

Dashboards can link to external Markdown documentation files:

```matlab
d = DashboardEngine('My Dashboard');
d.InfoFile = 'dashboard_help.md';  % path to Markdown file
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown file as HTML and opens it in the system browser. Supports basic Markdown syntax including headers, lists, code blocks, tables, and images.

---

## Complete Example

This example creates a process monitoring dashboard with sensor-bound widgets, groups, and pages:

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours

% Create sensors
sTemp = Sensor('T-401', 'Name', 'Temperature', 'Units', 'degF');
sTemp.X = t;
sTemp.Y = 74 + 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
sTemp.addThresholdRule(struct(), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

sPress = Sensor('P-201', 'Name', 'Pressure', 'Units', 'psi');
sPress.X = t;
sPress.Y = 55 + 20*sin(2*pi*t/7200) + randn(1,N)*1.5;
sPress.addThresholdRule(struct(), 65, 'Direction', 'upper', 'Label', 'Hi Warn');
sPress.addThresholdRule(struct(), 70, 'Direction', 'upper', 'Label', 'Hi Alarm');
sPress.resolve();

%% Build dashboard
d = DashboardEngine('Process Monitoring — Line 4');
d.Theme = 'light';
d.LiveInterval = 5;
d.InfoFile = 'process_help.md';

% Page 1: Overview
d.addPage('Overview');

% Chip bar health summary
d.addWidget('chipbar', 'Position', [1 1 24 1], 'Chips', { ...
    struct('label', 'Temp',  'sensor', sTemp), ...
    struct('label', 'Press', 'sensor', sPress) });

% Number widgets
d.addWidget('number', 'Title', 'Temperature', 'Position', [1 2 6 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [7 2 6 2], ...
    'Sensor', sPress, 'Format', '%.0f');

% Collapsible group with gauges
wGauge1 = GaugeWidget('Sensor', sTemp, 'Style', 'donut', ...
    'Range', [74 90], 'Units', 'degF');
wGauge2 = GaugeWidget('Sensor', sPress, 'Style', 'arc', ...
    'Range', [30 100], 'Units', 'psi');
d.addCollapsible('Gauges', {wGauge1, wGauge2}, 'Position', [1 4 12 6]);

% Sparkline cards
d.addWidget('sparklinecard', 'Title', 'Temp Trend', 'Position', [13 4 6 3], ...
    'Sensor', sTemp, 'Units', 'degF', 'ShowDelta', true);
d.addWidget('sparklinecard', 'Title', 'Press Trend', 'Position', [19 4 6 3], ...
    'Sensor', sPress, 'Units', 'psi', 'ShowDelta', true);

% Page 2: Trends
d.addPage('Trends');
d.addWidget('fastsense', 'Position', [1 1 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 1 12 8], 'Sensor', sPress);

% Event timeline from EventStore (requires event detection setup)
% d.addWidget('timeline', 'Position', [1 9 24 3], 'EventStoreObj', myEventStore);

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.m'));
```

---

## See Also

- [[API Reference: Dashboard]] — Full API reference for all dashboard classes
- [[API Reference: Sensors]] — Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] — Live data polling details
- [[Examples]] — Example scripts: `example_dashboard_engine`, `example_dashboard_all_widgets`
