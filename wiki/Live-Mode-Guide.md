<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a .mat file for updates and auto-refreshing the display. Live mode works with single plots, tiled dashboards, and tabbed docks.

---

## Basic Live Plot

```matlab
setup;

% Create initial plot
fp = FastSense('Theme', 'dark');
x = linspace(0, 10, 1e5);
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

% Start polling
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
```

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is called every poll cycle:
- `fp` — the FastSense instance
- `s` — struct loaded from the .mat file
- `fp.updateData(lineIdx, newX, newY)` — replaces line data and re-renders

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the Live Mode button in the [[FastSenseToolbar|API Reference: FastSenseToolbar]].

---

## View Modes

Control how the view updates when new data arrives:

| Mode | Behavior |
|------|----------|
| `'preserve'` | Keep current zoom/pan position. User's view is not disturbed |
| `'follow'` | Scroll X-axis to show the latest data. Good for monitoring |
| `'reset'` | Zoom to show all data. Good for overview |

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change view mode while running:
```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

---

## Polling Interval

Default is 2 seconds. Adjust with the 'Interval' option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % Poll every 500ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % Poll every 5 seconds
```

---

## Live Dashboard

FastSenseGrid supports live mode across all tiles:

```matlab
fig = FastSenseGrid(2, 2, 'Theme', 'dark');

fp1 = fig.tile(1); fp1.addLine(x, y1, 'DisplayName', 'Pressure');
fp2 = fig.tile(2); fp2.addLine(x, y2, 'DisplayName', 'Temperature');
fp3 = fig.tile(3); fp3.addLine(x, y3, 'DisplayName', 'Flow');
fp4 = fig.tile(4); fp4.addLine(x, y4, 'DisplayName', 'Vibration');

fig.renderAll();

% Start live mode on the entire dashboard
fig.startLive('sensors.mat', @(fig, s) updateDashboard(fig, s), ...
    'Interval', 2, 'ViewMode', 'follow');
```

Update callback for dashboard:
```matlab
function updateDashboard(fig, s)
    fig.tile(1).updateData(1, s.t, s.pressure);
    fig.tile(2).updateData(1, s.t, s.temperature);
    fig.tile(3).updateData(1, s.t, s.flow);
    fig.tile(4).updateData(1, s.t, s.vibration);
end
```

---

## Live Mode with Metadata

Attach metadata that updates on each poll:

```matlab
fp.startLive('data.mat', @updateFcn, ...
    'MetadataFile', 'meta.mat', ...
    'MetadataVars', {'units', 'calibration'});
```

The metadata is loaded from a separate file and attached to the specified line and tile:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line within the tile
fig.MetadataTileIndex = 1;   % which tile to attach to
```

---

## Live Event Detection

Combine live mode with event detection for real-time monitoring using the LiveEventPipeline:

```matlab
% Create sensors with thresholds
tempSensor = Sensor('temperature', 'Name', 'Temperature');
tempSensor.addThresholdRule(struct(), 78, 'Direction', 'upper', 'Label', 'Hi Warn');
tempSensor.addThresholdRule(struct(), 82, 'Direction', 'upper', 'Label', 'Hi Alarm');

sensors = containers.Map();
sensors('temperature') = tempSensor;

% Configure data sources
dsMap = DataSourceMap();
dsMap.add('temperature', MockDataSource('BaseValue', 70, 'NoiseStd', 2));

% Set up pipeline with event store
pipeline = LiveEventPipeline(sensors, dsMap, ...
    'EventFile', 'events.mat', ...
    'Interval', 15, ...
    'MinDuration', 0.5);

% Start live event detection
pipeline.start();
```

---

## Dashboard Live Mode

The example_dashboard_live.m script shows a complete live dashboard with sensor-bound widgets:

```matlab
% Create dashboard with live sensor data
d = DashboardEngine('Live Process Monitoring');
d.Theme = 'light';
d.LiveInterval = 1;

% Sensor-bound widgets auto-update from Sensor.Y data
d.addWidget('number', 'Title', 'Temperature', ...
    'Position', [5 1 5 2], ...
    'Sensor', sTemp, ...
    'Format', '%.1f');

d.addWidget('status', 'Title', 'Temp', ...
    'Position', [15 1 5 2], ...
    'Sensor', sTemp);

d.addWidget('fastsense', ...
    'Position', [1 3 12 8], ...
    'Sensor', sTemp);

% Background timer generates sensor data at 10 Hz
hDataTimer = timer('ExecutionMode', 'fixedRate', ...
    'Period', 0.1, ...
    'TimerFcn', @(~,~) updateSensorData());

% Start dashboard live mode (refreshes display every second)
d.render();
start(hDataTimer);
d.startLive();
```

---

## Manual Refresh

Trigger a one-shot data reload without starting continuous polling:

```matlab
fp.refresh();
fig.refresh();
```

---

## Octave Compatibility

GNU Octave does not support MATLAB timers. Use `runLive()` for a blocking poll loop:

```matlab
fp.render();

% Blocking loop — press Ctrl+C to stop
fp.LiveFile = 'data.mat';
fp.LiveUpdateFcn = @(fp, s) fp.updateData(1, s.x, s.y);
fp.runLive();
```

For dashboards:
```matlab
fig.renderAll();
fig.LiveFile = 'data.mat';
fig.LiveUpdateFcn = @myUpdateFcn;
fig.runLive();
```

---

## Progress Indication

Use [[ConsoleProgressBar|API Reference: Utilities]] for visual feedback during long operations:

```matlab
pb = ConsoleProgressBar(2);   % 2-space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % becomes permanent line
```

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring use cases where you always want to see the latest data
- Use `'preserve'` when users need to zoom into historical data while live updates continue
- Keep polling interval reasonable (1-5 seconds) to avoid overwhelming the file system
- The .mat file should be written atomically (write to temp file, then rename) to avoid partial reads
- Live mode works with linked axes — all linked plots update together
- Use `DeferDraw = true` to skip drawnow during batch render for better performance
- Dashboard widgets bound to Sensor objects automatically update when the Sensor.Y data changes

---

## See Also

- [[API Reference: FastPlot]] — startLive(), stopLive(), updateData() methods
- [[API Reference: Dashboard]] — Dashboard live mode
- [[API Reference: Event Detection]] — Live event detection
- [[Examples]] — example_dashboard_live.m, example_live_pipeline.m
