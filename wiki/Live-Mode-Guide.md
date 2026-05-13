<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a `.mat` file for updates and auto‑refreshing the display. Live mode works with single plots, tiled dashboards, and tabbed docks.

---

## Basic Live Plot

```matlab
install;

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
- `s` — struct loaded from the `.mat` file  
- `fp.updateData(lineIdx, newX, newY)` — replaces line data and re‑renders

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
| `'follow'`   | Scroll X‑axis to show the latest data (calls `snapToTail`). Good for monitoring |
| `'reset'`    | Zoom to show all data. Good for overview |

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change view mode while running:
```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

> **Note:** In `'follow'` mode, FastSense automatically pans the X‑axis so the right edge shows the newest data point with a small padding. The underlying `snapToTail` method can also be called manually.

---

## Polling Interval

Default is 2 seconds. Adjust with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % Poll every 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % Poll every 5 seconds
```

---

## Live Dashboard

[[FastSenseGrid|API Reference: Dashboard]] supports live mode across all tiles:

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

Attach metadata that updates on each poll. The metadata is loaded from a separate `.mat` file and attached to a specified line and tile:

```matlab
fp.startLive('data.mat', @updateFcn, ...
    'MetadataFile', 'meta.mat', ...
    'MetadataVars', {'units', 'calibration'});
```

For dashboards, you can configure metadata properties directly:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line within the tile
fig.MetadataTileIndex = 1;   % which tile to attach to
```

The [[FastSenseToolbar]] can then display metadata fields in data‑cursor tooltips when `MetadataEnabled` is `true`.

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

### Mixed MATLAB/Octave Use

If you call `fp.runLive()` on MATLAB while a timer is already running, it is a no‑op. An `onCleanup` guard calls `stopLive()` when the figure is closed.

---

## Manual Refresh

Trigger a one‑shot data reload without starting continuous polling:

```matlab
fp.refresh();
fig.refresh();
```

This loads `LiveFile`, calls `LiveUpdateFcn`, updates the file‑date stamp, and reloads the `MetadataFile` if configured.

---

## Toolbar Integration

The [[FastSenseToolbar]] provides a **Live Mode** button (toggle) and a **Refresh** button:

```matlab
tb = FastSenseToolbar(fp);
tb.toggleLive();   % start/stop live polling
tb.refresh();      % manual one‑shot reload
```

The toolbar’s **Follow** button maps directly to `setViewMode('follow')` and immediately snaps the X‑axis to the data tail. The **Violations** button toggles the global visibility of threshold violation markers.

---

## Console Progress Bars

For visual feedback during long batch operations, use `ConsoleProgressBar`:

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % becomes permanent line
```

This is especially useful inside dashboard rendering callbacks or when processing many tiles.

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring — the chart keeps the latest data in view automatically.  
- Use `'preserve'` when users need to zoom into historical data while live updates continue.  
- Keep the polling interval reasonable (1–5 seconds) to avoid overloading the file system.  
- Write the `.mat` file atomically (write to a temporary file, then rename) to prevent partial reads.  
- Live mode works with linked axes — all plots in the same `LinkGroup` pan and zoom together.  
- Set `DeferDraw = true` to skip `drawnow` during batch renders for better performance.  
- On Windows systems with limited memory, consider using `StorageMode = 'disk'` to offload large line data to SQLite.

---

## See Also

- [[API Reference: FastPlot]] — `startLive()`, `stopLive()`, `updateData()` methods  
- [[API Reference: Dashboard]] — Dashboard live mode  
- [[Examples]] — `example_dashboard_live.m`, `example_live_pipeline.m`  
- [[Architecture]] — internal live‑mode timer mechanics
