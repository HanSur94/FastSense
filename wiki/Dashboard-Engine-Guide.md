<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, and a visual editor.

---

## Overview

FastSense provides two dashboard systems:

| Feature | FastSenseGrid | DashboardEngine |
|---------|---------------|-----------------|
| Grid | Fixed rows x cols | 24‑column responsive |
| Tile content | FastSense instances only | 15+ widget types (plots, gauges, numbers, tables, etc.) |
| Persistence | None | JSON save/load + .m script export |
| Visual editor | No | Yes (drag/resize, palette, properties panel) |
| Scrolling | No | Auto‑scrollbar when content overflows |
| Global time | No | Dual sliders controlling all widgets + envelope preview |
| Sensor binding | Via addSensor per tile | Direct widget property (auto‑title, auto‑units) |
| Live mode | Per‑figure timer | Engine‑level timer refreshing all widgets |
| Multi‑page | No | Yes – named pages with tab bar |
| Widget grouping | No | Collapsible, tabbed, and panel groups |
| Data staleness | No | Automatic detection with banner warning |

**When to use FastSenseGrid:** You need a simple tiled grid of FastSense time series plots with linked axes and a toolbar.

**When to use DashboardEngine:** You need mixed widget types (gauges, KPIs, tables, timelines), JSON persistence, visual editor, or advanced layout features.

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
[1 1 24 4]   % Full width, 4 rows tall
[1 1 12 4]   % Left half
[13 1 12 4]  % Right half
[1 5 8 2]    % Left third, row 5
```

If a new widget overlaps an existing one, it is automatically pushed down to the next free row.

---

## Widget Types

DashboardEngine supports a wide range of widget types. The general usage is:

```matlab
d.addWidget('type', 'Name', Value, ...);
```

or by directly constructing the widget:

```matlab
w = FastSenseWidget('XData', x, 'YData', y);
d.addWidget(w);
```

Below is a summary of each type. See [[API Reference: Dashboard]] for full property details.

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

When bound to a Sensor (or Tag), threshold rules appear automatically, and the title, x‑label (`'Time'`), and y‑label are derived from the sensor’s Name/Units.

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

Shows a large number with a trend arrow derived from recent sensor data.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);
```

Coloured dot (green/amber/red) and latest value. Status is derived from threshold rules. Legacy interfaces (`StaticStatus`, `StatusFcn`) are still accepted.

### Gauge (arc/donut/bar/thermometer)

```matlab
d.addWidget('gauge', 'Title', 'Flow Rate', ...
    'Position', [1 3 8 6], ...
    'Sensor', sFlow, 'Range', [0 160], 'Units', 'L/min', ...
    'Style', 'donut');

d.addWidget('gauge', 'Title', 'Efficiency', ...
    'Position', [9 3 8 6], ...
    'StaticValue', 85, 'Range', [0 100], 'Units', '%', ...
    'Style', 'arc');
```

Styles: `'arc'`, `'donut'`, `'bar'`, `'thermometer'`. Range and units are auto‑derived from a bound Sensor and its threshold rules.

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
    'Position', [1 9 12 4], ...
    'ColumnNames', {'Time', 'Tag', 'Value'}, ...
    'Data', {{'12:00', 'T‑401', '85.2'}});

% Last N rows from a Sensor
d.addWidget('table', 'Title', 'Recent Data', ...
    'Position', [1 9 12 4], ...
    'Sensor', sTemp, 'N', 15);

% Dynamic data callback
d.addWidget('table', 'Title', 'Live Log', ...
    'Position', [1 13 12 4], ...
    'DataFcn', @() getRecentAlarms(), ...
    'ColumnNames', {'Time', 'Tag', 'Value'});

% Event mode (requires EventStore)
d.addWidget('table', 'Title', 'Events', ...
    'Position', [1 17 12 4], ...
    'Sensor', mySensor, 'Mode', 'events', ...
    'EventStoreObj', myEventStore, 'N', 10);
```

### Event Timeline

```matlab
% Bound to an EventStore
d.addWidget('timeline', 'Title', 'Alarms', ...
    'Position', [1 16 24 3], ...
    'EventStoreObj', myEventStore);

% Legacy direct event structs
events = struct('startTime', {0, 3600}, 'endTime', {3600, 7200}, ...
    'label', {'Idle','Running'}, 'color', {[0.6 0.6 0.6],[0.2 0.7 0.3]});
d.addWidget('timeline', 'Title', 'Machine Mode', ...
    'Position', [1 13 24 3], 'Events', events);
```

`FilterSensors` or `FilterTagKey` can restrict events to specific sensors or tags.

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

### Divider (visual separator)

```matlab
d.addWidget('divider', 'Position', [1 3 24 1], ...
    'Thickness', 2, 'Color', [0.5 0.5 0.5]);
```

### Bar Chart

```matlab
d.addWidget('barchart', 'Title', 'Monthly Output', ...
    'Position', [1 5 12 6], ...
    'DataFcn', @() struct('categories', {{'Q1','Q2','Q3','Q4'}}, ...
                         'values', [120 245 310 280]), ...
    'Orientation', 'vertical', 'Stacked', false);
```

### Heatmap

```matlab
d.addWidget('heatmap', 'Title', 'Correlation Matrix', ...
    'Position', [1 11 8 6], ...
    'DataFcn', @() rand(5,5), ...
    'Colormap', 'parula', 'ShowColorbar', true, ...
    'XLabels', {{'A','B','C','D','E'}}, ...
    'YLabels', {{'A','B','C','D','E'}});
```

### Histogram

```matlab
d.addWidget('histogram', 'Title', 'Cycle Time', ...
    'Position', [1 17 8 4], ...
    'DataFcn', @() randn(1,200)*5+100, ...
    'NumBins', 20, 'ShowNormalFit', true, ...
    'EdgeColor', [0.2 0.2 0.2]);
```

### Image

```matlab
d.addWidget('image', 'Title', 'Floor Plan', ...
    'Position', [1 9 12 10], ...
    'File', 'floorplan.png', 'Scaling', 'fit');
```

### Scatter

```matlab
d.addWidget('scatter', 'Title', 'Pressure vs Temp', ...
    'Position', [13 9 12 8], ...
    'SensorX', sTemp, 'SensorY', sPress, ...
    'MarkerSize', 8, 'Colormap', 'parula');
% Optional colour‑by sensor: 'SensorColor', sOther
```

### Icon Card

A compact mushroom‑style card: coloured icon, large primary value, and subtitle.

```matlab
d.addWidget('iconcard', 'Title', 'Tank Level', ...
    'Position', [1 21 4 3], ...
    'StaticValue', 72.5, 'Units', '%', 'StaticState', 'ok');

% Sensor‑bound
d.addWidget('iconcard', 'Title', 'Pump Vibration', ...
    'Position', [5 21 4 3], ...
    'Sensor', sVib);
```

Properties: `IconColor`, `StaticValue`, `ValueFcn`, `StaticState`, `Units`, `Format`, `SecondaryLabel`.

### Chip Bar

A horizontal row of mini status chips—ideal for a system‑health summary.

```matlab
chips = {
    struct('label', 'Pump',  'sensor', sPump),
    struct('label', 'Fan',   'statusFcn', @() 'warn'),
    struct('label', 'Tank',  'iconColor', [0.2 0.7 0.3])
};
d.addWidget('chipbar', 'Title', 'Health Check', ...
    'Position', [1 5 24 1], 'Chips', chips);
```

Each chip can use a `Sensor`, a `statusFcn`, or a fixed `iconColor`. States: `'ok'`, `'warn'`, `'alarm'`, `'info'`, `'inactive'`.

### Sparkline Card

Combines a big number, a mini sparkline chart, and a delta indicator.

```matlab
d.addWidget('sparkline', 'Title', 'CPU Load', ...
    'Position', [1 3 6 4], ...
    'StaticValue', 42.0, 'SparkData', randn(1,100)*2+42, ...
    'Units', '%', 'ShowDelta', true, 'NSparkPoints', 50);
```

When bound to a Sensor, the sparkline and value come from `Sensor.Y`.

### Multi‑Status

Grid of status dots for multiple sensors.

```matlab
d.addWidget('multistatus', 'Title', 'Sensors Overview', ...
    'Position', [1 7 24 2], ...
    'Sensors', {sTemp, sPress, sFlow}, ...
    'Columns', 4, 'ShowLabels', true, 'IconStyle', 'dot');
```

### Group Widget

Collapsible, tabbed, or plain panel container for other widgets. Allows nested dashboards.

```matlab
% Collapsible group
g = d.addCollapsible('Sensor Details', {w1, w2});

% Tabbed group
g = GroupWidget('Mode', 'tabbed', 'Label', 'Sections');
g.addChild(tabWidget1, 'Tab A');
g.addChild(tabWidget2, 'Tab B');
d.addWidget(g);
```

Properties: `Mode` (`'panel'`, `'collapsible'`, `'tabbed'`), `Collapsed`, `Tabs`, `ActiveTab`, `ChildAutoFlow`.

---

## Sensor Binding

The recommended way to drive dashboard widgets is through Sensor objects or the v2.0 **Tag** interface. For backward compatibility, the legacy `'Sensor'` key is mapped to the `Tag` property.

```matlab
% Create sensors
sTemp = Sensor('T‑401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = temp;
sTemp.addThresholdRule(struct(), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.resolve();

% Bind to widgets — many properties are auto‑derived
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 12 8]);
d.addWidget('number',    'Sensor', sTemp, 'Position', [13 1 6 2], 'Units', 'degF');
d.addWidget('status',    'Sensor', sTemp, 'Position', [19 1 6 2]);
d.addWidget('gauge',     'Sensor', sTemp, 'Position', [13 3 12 6]);
```

Benefits of sensor binding:
- **Title** – auto‑derived from `Sensor.Name` or `Sensor.Key`
- **Units** – auto‑derived from `Sensor.Units`
- **Value** – uses `Sensor.Y(end)` for number, gauge, status, etc.
- **Thresholds** – FastSenseWidget renders resolutions and violations
- **Status** – StatusWidget checks latest value against threshold rules
- **Live refresh** – calling `refresh()` re‑reads sensor data

For widgets that accept a `Tag` instead of a `Sensor`, you can pass a Tag object directly:

```matlab
tag = TagRegistry.get('temp_sensor');
d.addWidget('fastsense', 'Tag', tag);
```

---

## Saving and Loading

### Save to JSON

```matlab
d.save('dashboard.json');
```

The JSON contains the dashboard name, theme, live interval, grid settings, and each widget’s type, title, position, and data source. Multi‑page dashboards are fully serialized.

### Load from JSON

```matlab
d2 = DashboardEngine.load('dashboard.json');
d2.render();
```

To re‑bind Sensor objects, supply a resolver:

```matlab
d2 = DashboardEngine.load('dashboard.json', ...
    'SensorResolver', @(name) SensorRegistry.get(name));
```

### Export as MATLAB Script

```matlab
d.exportScript('rebuild_dashboard.m');
```

Generates a readable `.m` function that recreates the dashboard from scratch.

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colors, status indicators, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';            % or 'light'
d.render();
```

Available presets: `'light'`, `'dark'`. Legacy names (`'default'`, `'industrial'`, etc.) are aliased to `'light'` for backward compatibility.

Override specific theme fields:

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

---

## Live Mode

DashboardEngine supports live data updates via a timer that calls `refresh()` on all widgets.

```matlab
d = DashboardEngine('Live Monitor');
d.Theme = 'dark';
d.LiveInterval = 2;  % seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % begin periodic refresh
% … later
d.stopLive();
```

A **stale‑data banner** appears when any widget’s latest timestamp stops advancing, helping operators notice frozen feeds.

---

## Global Time Controls

The bottom‑panel **TimeRangeSelector** provides two sliders that control the visible time window across all widgets.

- **FastSenseWidget**, **EventTimelineWidget**, **RawAxesWidget** respond to `setTimeRange(tStart, tEnd)`.
- A semi‑transparent envelope preview (aggregate min/max or line previews) helps the user see the overall signal shape.
- Event markers (if available) are displayed as faint vertical lines.

When a user manually zooms a single widget, that widget detaches from global time. Click the **Sync** button in the toolbar to re‑attach all widgets.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode:

1. A **palette sidebar** appears with buttons for each widget type.
2. A **properties panel** shows the selected widget’s settings.
3. **Drag handles** allow repositioning on the grid.
4. **Resize handles** change widget dimensions.
5. Click **Apply** to save property changes.
6. Click **Done** to exit edit mode.

The editor snaps to the 24‑column grid. You can also add specialized widgets like **IconCard**, **ChipBar**, and **SparklineCard** directly from builder convenience methods.

Programmatic widget management:

```matlab
d.addWidget('fastsense', …);         % add any widget
d.selectWidget(idx);                % select a widget for editing
d.setWidgetPosition(idx, pos);      % move/resize programmatically
d.removeWidget(idx);                % delete a widget
```

---

## Info File Integration

Link an external Markdown documentation file to your dashboard:

```matlab
d.InfoFile = 'dashboard_help.md';
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown as HTML and opens it in the system browser.

---

## Complete Example

A multi‑sensor process dashboard with sensor‑bound widgets, groups, and a chip bar.

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours

% Machine state channel
scMode = StateChannel('machine');
scMode.X = [0, 3600, 7200, 28800, 36000];
scMode.Y = [0, 1,    1,    2,     1    ];

% Temperature sensor
sTemp = Sensor('T‑401', 'Name', 'Temperature');
sTemp.Units = 'degF';
sTemp.X = t;
sTemp.Y = 74 + 3*sin(2*pi*t/3600) + randn(1,N)*1.2;
sTemp.addStateChannel(scMode);
sTemp.addThresholdRule(struct('machine', 1), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
sTemp.addThresholdRule(struct('machine', 1), 85, 'Direction', 'upper', 'Label', 'Hi Alarm');
sTemp.resolve();

% Pressure sensor
sPress = Sensor('P‑201', 'Name', 'Pressure');
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

% Top‑row chip bar
chips = {
    struct('label','T‑401','sensor',sTemp),
    struct('label','P‑201','sensor',sPress)
};
d.addWidget('chipbar', 'Title', 'System Health', ...
    'Position', [1 1 24 1], 'Chips', chips);

% Numbers and status
d.addWidget('number', 'Title', 'Temperature', 'Position', [1 2 6 2], ...
    'Sensor', sTemp, 'Format', '%.1f');
d.addWidget('number', 'Title', 'Pressure', 'Position', [7 2 6 2], ...
    'Sensor', sPress, 'Format', '%.0f');
d.addWidget('status', 'Title', 'Temp', 'Position', [13 2 6 2], ...
    'Sensor', sTemp);
d.addWidget('status', 'Title', 'Press', 'Position', [19 2 6 2], ...
    'Sensor', sPress);

% Big plots
d.addWidget('fastsense', 'Position', [1 4 12 10], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 4 12 10], 'Sensor', sPress);

% Collapsible group with gauges and a histogram
g = d.addCollapsible('Details', {});
g.addChild(GaugeWidget('Title','Pressure Gauge','Sensor',sPress,'Style','donut','Range',[0 100],'Units','psi'));
g.addChild(RawAxesWidget('Title','Temp Histogram','PlotFcn',@(ax) histogram(ax, sTemp.Y, 50, 'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none')));
d.addWidget(g);   % placed at next free row

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## See Also

- [[API Reference: Dashboard]] – Full property and method reference for all dashboard classes
- [[API Reference: Sensors]] – Sensor, StateChannel, ThresholdRule
- [[Live Mode Guide]] – Live data polling and staleness detection
- [[Examples]] – `example_dashboard_engine`, `example_dashboard_all_widgets`
