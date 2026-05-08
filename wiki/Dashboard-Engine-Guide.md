<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Dashboard Engine Guide

Build rich, interactive dashboards with mixed widget types, sensor bindings, JSON persistence, multi-page layouts, and a visual editor.

---

## Overview

DashboardEngine provides a full-featured dashboard framework built on a 24‑column responsive grid.  
It supports 20+ widget types (gauges, big numbers, time‑series plots, tables, event timelines, custom axes, heatmaps, histograms, images, and more), live data refresh via a timer, global time‑range controls, and a drag‑and‑drop visual editor.  

Dashboards are serializable to JSON (via `save`/`load`) and exportable as self‑contained `.m` scripts.  

| Feature                  | DashboardEngine                          |
| ------------------------ | ---------------------------------------- |
| Grid                     | 24‑column responsive                     |
| Tile content             | 20+ widget types                         |
| Persistence              | JSON save/load + `.m` script export      |
| Visual editor            | Yes (drag/resize, palette, properties)   |
| Scrolling                | Auto‑scrollbar when content overflows    |
| Global time              | Dual sliders controlling all widgets     |
| Sensor binding           | Direct widget property (auto‑title, units, thresholds) |
| Live mode                | Engine‑level timer refreshing all widgets|
| Multi‑page               | Named pages with tab‑style navigation    |
| Grouping                 | Panel, collapsible, and tabbed groups    |
| Detach                   | Pop a widget into a standalone window    |
| Event overlay            | Per‑widget event markers and slider markers |

**When to choose DashboardEngine:**  
You need mixed widget types, persistent dashboards, a visual editor, or a full‑featured monitoring interface.

---

## Quick Start

```matlab
install;

% Create some data
x = linspace(0, 100, 10000);
y = sin(x) + 0.1*randn(size(x));

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

If a new widget would overlap an existing one, the layout system **pushes it down** to the next free row. Scrollbars appear automatically when the total rows exceed the viewport height.

---

## Widget Types

DashboardEngine supports the following widget types (use the string name in `addWidget(type, ...)`:

| Type string          | Widget class                | Description |
| -------------------- | --------------------------- | ----------- |
| `'fastsense'`        | FastSenseWidget             | Time‑series plot (wraps FastSense) |
| `'number'`           | NumberWidget                | Large KPI number with trend arrow |
| `'status'`           | StatusWidget                | Colored health indicator dot |
| `'gauge'`            | GaugeWidget                 | Arc, donut, bar, or thermometer gauge |
| `'text'`             | TextWidget                  | Static label or section header |
| `'table'`            | TableWidget                 | Tabular data via `uitable` |
| `'rawaxes'`          | RawAxesWidget               | Custom MATLAB axes |
| `'timeline'`         | EventTimelineWidget         | Event bars on a timeline |
| `'group'`            | GroupWidget                 | Container for other widgets (panel/collapsible/tabbed) |
| `'divider'`          | DividerWidget               | Horizontal visual separator |
| `'heatmap'`          | HeatmapWidget               | Heatmap display |
| `'histogram'`        | HistogramWidget             | Histogram plot |
| `'barchart'`         | BarChartWidget              | Bar chart (vertical/horizontal/stacked) |
| `'image'`            | ImageWidget                 | PNG/JPG image or custom image matrix |
| `'scatter'`          | ScatterWidget               | Scatter plot of two sensors |
| `'chipbar'`          | ChipBarWidget               | Compact row of status chips |
| `'iconcard'`         | IconCardWidget              | Mushroom‑style icon/value/label card |
| `'sparkline'`        | SparklineCardWidget         | KPI card with mini sparkline and delta |
| `'multistatus'`      | MultiStatusWidget           | Grid of multiple status dots |

You can also add any widget directly as an object:

```matlab
d.addWidget(SomeWidget('Title', 'Custom'));
```

### FastSense (time‑series)

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

When bound to a Sensor, threshold rules apply automatically and resolved violations are shown.  
The widget title, X‑axis label (`'Time'`), and Y‑axis label (sensor Units or Name) are auto‑derived.

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

Shows a large number with a trend arrow (up/down/flat) computed from recent data.  
Layout: `[Title | Value+Trend | Units]`. The callback can return a scalar or a struct with fields `value`, `unit`, `trend`.

### Status (health indicator)

```matlab
d.addWidget('status', 'Title', 'Pump', ...
    'Position', [7 1 5 2], ...
    'Sensor', sTemp);

% Legacy static status
d.addWidget('status', 'Title', 'System', ...
    'Position', [12 1 5 2], ...
    'StaticStatus', 'ok');  % 'ok', 'warning', 'alarm'
```

Shows a colored dot (green/amber/red) and the sensor’s latest value. Status is derived automatically from threshold rules when a Sensor or Threshold is given.

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

Styles: `'arc'` (default), `'donut'`, `'bar'`, `'thermometer'`.  
When Sensor‑bound, range and units are auto‑derived from threshold rules and sensor properties.

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

`PlotFcn` receives the axes as first argument. When Sensor‑bound, it also receives the Sensor object and optionally a time range.

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

### Additional Widgets

**DividerWidget** – horizontal line for visual grouping.
```matlab
d.addWidget('divider', 'Position', [1 5 24 1], 'Thickness', 2);
```

**BarChartWidget** – vertical or horizontal bar chart.
```matlab
d.addWidget('barchart', 'Title', 'Qty by SKU', ...
    'Position', [1 7 12 6], ...
    'DataFcn', @() struct('categories', {{'A','B','C'}}, 'values', [45 70 30]));
```

**ChipBarWidget** – compact row of colored status chips.
```matlab
w = ChipBarWidget('Title', 'System Health', 'Position', [1 1 24 1]);
w.Chips = {
    struct('label', 'Pump',   'sensor', sPump),
    struct('label', 'Tank',   'sensor', sTank),
    struct('label', 'Fan',    'statusFcn', @() 'warn')
};
d.addWidget(w);
```

**IconCardWidget** – Mushroom‑style card (icon, value, label).
```matlab
d.addWidget('iconcard', 'Title', 'Temp', ...
    'Position', [1 3 6 3], ...
    'StaticValue', 23.5, 'Units', 'degC');
```

**SparklineCardWidget** – KPI card with sparkline and delta.
```matlab
d.addWidget('sparkline', 'Title', 'CPU', ...
    'Position', [1 5 6 3], ...
    'StaticValue', 42.0, 'SparkData', randn(1,100), 'Units', '%');
```

**MultiStatusWidget** – grid of multiple sensor status dots.
```matlab
d.addWidget('multistatus', 'Position', [1 7 12 3], ...
    'Sensors', {s1, s2, s3, s4, s5});
```

**HeatmapWidget**, **HistogramWidget**, **ImageWidget**, **ScatterWidget** – follow the same pattern with appropriate `DataFcn`/`File`/`Sensor` properties.

---

## Sensor Binding

The recommended way to drive dashboard widgets is through **Sensor objects**. Sensors carry data, state channels, and threshold rules. When you bind a widget to a Sensor, many properties are auto‑derived.

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

**Benefits of Sensor binding:**  
- **Title** – auto‑derived from `Sensor.Name` or `Sensor.Key`  
- **Units** – auto‑derived from `Sensor.Units`  
- **Value** – `Sensor.Y(end)` for number, gauge, status  
- **Thresholds** – FastSenseWidget renders resolved thresholds and violations  
- **Status** – StatusWidget checks latest value against all threshold rules  
- **Live refresh** – `refresh()` re‑reads sensor data

**Legacy** binding via `'Sensor'` name‑value pair is aliased to a Tag property under the hood; for new code, passing the Sensor directly is preferred.

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

Generates a readable `.m` file that, when executed, recreates the dashboard (including multi‑page structures, groups, and collapsible containers).

---

## Theming

DashboardEngine uses `DashboardTheme`, which extends `FastSenseTheme` with dashboard‑specific fields (widget backgrounds, border colors, status indicator colors, etc.).

```matlab
d = DashboardEngine('My Dashboard');
d.Theme = 'dark';        % or 'light'
d.render();
```

Available presets: `'light'`, `'dark'`. Legacy names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are aliased to `'light'` for backward compatibility.

**Overriding specific theme properties:**

```matlab
theme = DashboardTheme('dark', 'WidgetBackground', [0.1 0.1 0.2]);
d.Theme = theme;
```

You can also assign theme fields after creation:
```matlab
d.Theme.WidgetBackground = [0.1 0.1 0.2];
```

To force a theme re‑render without rebuilding the whole dashboard, call:
```matlab
d.rerenderWidgets();
```

Every widget can have a **per‑widget theme override** via the `ThemeOverride` property (a struct merged on top of the dashboard theme). Not all widgets use all fields, but the base class makes it available.

---

## Live Mode

DashboardEngine can poll data sources at a fixed interval and refresh all widgets automatically.

```matlab
d = DashboardEngine('Live Monitor');
d.Theme = 'dark';
d.LiveInterval = 2;  % seconds

d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 1 24 8]);
d.addWidget('number', 'Sensor', sTemp, 'Position', [1 9 12 2]);

d.render();
d.startLive();   % starts the timer
% ... later
d.stopLive();    % stops the timer
```

**Live button in the toolbar** toggles live mode on/off. When active, the button is highlighted with a blue border. The toolbar also shows the last update timestamp.

If a widget’s data timestamp fails to advance (stale data), a **stale‑data banner** appears at the top of the dashboard listing the affected widgets. It can be dismissed manually and will re‑appear on the next tick if the situation persists.

Tick errors do not stop the timer — the engine logs the error and continues (see `onLiveTimerError`).

---

## Global Time Controls

The **time panel** at the bottom of the dashboard has two sliders that control the visible time range across **all widgets on all pages**.

- Moving the sliders calls `setTimeRange(tStart, tEnd)` on each widget.
- **FastSenseWidget** adjusts its `xlim` (preserving zoom state if the widget is detached from global time).
- **EventTimelineWidget** and **RawAxesWidget** adjust accordingly.
- Widgets can detach from global time when the user manually zooms (`UseGlobalTime = false`).

**Sync button** (refresh icon in toolbar) re‑attaches all widgets to global time and resets to the full data extent.

**Preview envelope** – in the time slider background, a faint min/max envelope of all widget data (and event markers) is drawn, giving an overview of data distribution across time.

---

## Visual Editor

Click the **Edit** button in the toolbar to enter edit mode.

- A **palette sidebar** appears on the left with buttons for each widget type.
- A **properties panel** appears on the right showing the selected widget’s settings (title, position, data source, etc.).
- **Drag handles** let you reposition widgets on the grid.
- **Resize handles** let you change widget dimensions (snapping to the 24‑column grid).
- Click **Apply** to save property changes, **Done** to exit edit mode.

Programmatic widget management:
```matlab
d.addWidget('text', 'Title', 'New', 'Position', [1 1 6 2]);
d.deleteWidget(idx);            % remove widget by index
d.setWidgetPosition(idx, [1 3 8 2]);  % move/resize
```

The editor also supports multi‑page and group widgets: you can add pages, and inside groups you can drag children within the group’s sub‑grid.

---

## Info File Integration

Dashboards can link to an external Markdown documentation file:

```matlab
d.InfoFile = 'dashboard_help.md';  % path to Markdown
d.render();
```

An **Info** button appears in the toolbar. Clicking it renders the Markdown as HTML (via `MarkdownRenderer`) and opens it in the system browser. Alternatively, a temporary HTML file is created and launched via `web()`, or, on newer MATLAB, in an in‑app modal.

If no `InfoFile` is set, clicking the Info button displays a placeholder page that explains how to attach custom documentation.

---

## Multi‑Page Dashboards

You can split a dashboard into named pages with tab‑style navigation.

```matlab
d = DashboardEngine('Multi‑Page Example');

% Page 1
d.addPage('Overview');
d.addWidget('text', 'Title', 'Welcome', 'Position', [1 1 24 1], ...
    'Content', 'Main view');
d.addWidget('fastsense', 'Sensor', sTemp, 'Position', [1 3 24 8]);

% Page 2
d.addPage('Details');
d.addWidget('table', 'Title', 'Raw Data', 'Position', [1 1 24 8], ...
    'Sensor', sTemp, 'N', 50);
d.addWidget('gauge', 'Title', 'Temp', 'Position', [1 9 8 6], 'Sensor', sTemp);

d.render();
```

When `addPage()` is called, subsequent `addWidget()` calls are routed to that page until you switch back (`switchPage(idx)` or via the editor). The toolbar automatically shows page tabs above the content area.

Each page is a `DashboardPage` object holding a list of widgets. The layout system reflows all widgets across pages (hiding inactive pages) and updates scrollbars.

---

## Grouping and Layout Containers

`GroupWidget` allows you to embed other widgets inside a panel, collapsible region, or tabbed container.

**Panel mode** (default) – groups children under a colored header.

```matlab
d.addWidget('group', 'Label', 'Sensor Suite', ...
    'Children', {w1, w2, w3});
```

**Collapsible mode** – header with collapse/expand toggle.

```matlab
collapsed = d.addCollapsible('Advanced Settings', {wA, wB});
collapsed.collapse();  % collapse programmatically
collapsed.expand();
```

**Tabbed mode** – children organized under tabs.

```matlab
dg = GroupWidget('Mode', 'tabbed', 'Label', 'Views');
dg.addChild(wPlot, 'Chart');
dg.addChild(wTable, 'Table');
d.addWidget(dg);
```

Groups can be nested, though depth is limited (the engine enforces a maximum nesting depth via `addChild` checks). Group children are laid out automatically in a sub‑grid (`ChildColumns`, `ChildAutoFlow`).

When a collapsible group expands or collapses, the parent layout reflows automatically.

---

## Detaching Widgets

You can pop any widget into a standalone figure window that remains live‑mirrored (updated by the engine’s live timer).

```matlab
d.detachWidget(d.getWidgetByTitle('Temperature'));
```

This creates a `DetachedMirror` object, clones the widget (via `toStruct`/`fromStruct`), and renders it in a separate figure. The mirror is kept in sync during live ticks. Closing the detached window cleans up the mirror automatically.

---

## Progress Bar and Stale Banner

**Progress bar** – during long renders (many widgets), a self‑updating progress line is printed to the console. You can control its visibility with:

```matlab
d.ProgressMode = 'on';   % 'auto' (default), 'on', 'off'
```

**Stale banner** – if, during live mode, a widget’s time range fails to advance, a warning banner appears listing the stale widget titles. This helps spot sensor connectivity issues. The banner’s reserved space is always at the top of the figure, independent of toolbar/page height.

---

## Export Image

Capture the current dashboard figure as a PNG or JPEG at 150 DPI.

```matlab
d.exportImage('dashboard.png');
d.exportImage('dashboard.jpg', 'jpeg');
```

The default filename is `{dashboard name}_{timestamp}.png`. The toolbar **Image** button invokes a save dialog.

---

## Complete Example

This example creates a process monitoring dashboard with sensor‑bound widgets, multi‑page, and live mode.

```matlab
install;

%% Generate data
rng(42);
N = 10000;
t = linspace(0, 86400, N);  % 24 hours in seconds

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

% Page 1 — Overview
d.addPage('Overview');
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

d.addWidget('fastsense', 'Position', [1 3 12 8], 'Sensor', sTemp);
d.addWidget('fastsense', 'Position', [13 3 12 8], 'Sensor', sPress);

% Page 2 — Details
d.addPage('Details');
d.addWidget('gauge', 'Title', 'Pressure', 'Position', [1 1 8 6], ...
    'Sensor', sPress, 'Range', [0 100], 'Units', 'psi');
d.addWidget('rawaxes', 'Title', 'Temp Distribution', 'Position', [9 1 8 6], ...
    'PlotFcn', @(ax) histogram(ax, sTemp.Y, 50, ...
        'FaceColor', [0.31 0.80 0.64], 'EdgeColor', 'none'));

d.render();

%% Save
d.save(fullfile(tempdir, 'process_dashboard.json'));
```

---

## Tips and Gotchas

- **Widget order matters** – when adding widgets that share grid space, add them in the order you want them stacked (first‑added gets priority). The layout resolves overlaps by pushing later widgets down.
- **Sensor resolution** – when loading from JSON, Sensor bindings are lost unless you provide a `SensorResolver` function that maps Saved Sensor names back to live objects.
- **Group nesting depth** – the engine enforces a maximum nesting depth for GroupWidget children to prevent infinite recursion.
- **Live mode and manual zoom** – manually zooming a FastSense widget detaches it from global time so that it won’t scroll with the slider. Use the Sync button to re‑attach.
- **Event markers** – the toolbar **Events** button toggles a global event‑marker overlay on all widgets that support it (FastSenseWidget, RawAxesWidget). This state is not persisted.
- **ProgressMode** – for batch scripts or CI, set to `'off'` to keep output clean.
- **DetachedMirrors** – they are automatically added to the engine’s lifecycle; closing the window calls `removeDetached()` to avoid stale handles.

---

## See Also

- [[API Reference: Dashboard]] – Full API reference for all dashboard classes  
- [[API Reference: Sensors]] – Sensor, StateChannel, ThresholdRule  
- [[Live Mode Guide]] – Live data polling details  
- [[Examples]] – `example_dashboard_engine`, `example_dashboard_all_widgets`
