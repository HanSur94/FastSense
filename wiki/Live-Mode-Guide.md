<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a `.mat` file for updates and auto‑refreshing the display. Live mode works with single plots, tiled dashboards (`FastSenseGrid`), and tabbed docks (`FastSenseDock`), and is compatible with both MATLAB and GNU Octave through separate timer‑based and blocking‑loop implementations.

---

## Basic Live Plot

Create an initial plot with `FastSense`, then launch live mode by providing the path to a `.mat` file and an update callback.

```matlab
install;

% Create initial plot
fp = FastSense('Theme', 'dark');
x = linspace(0, 10, 1e5);
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

% Start live polling
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
```

The callback `@(fp, s)` receives the `FastSense` instance and the struct `s` loaded from the file.  Call `fp.updateData(lineIdx, newX, newY)` to replace the raw data for a line and trigger a re‑downsample/redraw.

You can set the polling interval directly on the object before starting:

```matlab
fp.LiveInterval = 2.0;  % seconds (default: 2.0)
```

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the **Live Mode** button in the toolbar.

---

## View Modes

The `LiveViewMode` property controls how the axes behave when new data arrives.  It is applied separately on each `render()` and `updateData()` call.

| Mode         | Behavior |
|--------------|----------|
| `'preserve'` | Keep current zoom/pan position. The user’s view is undisturbed. |
| `'follow'`   | Scroll the X‑axis to show the latest data (great for monitoring). |
| `'reset'`    | Zoom to show *all* data (great for overview). |

Set the mode before launching live mode:

```matlab
fp.LiveViewMode = 'follow';
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
```

Change mode on‑the‑fly with `setViewMode()`:

```matlab
fp.setViewMode('preserve');
fp.setViewMode('follow');
```

---

## Polling Interval

The default polling interval is 2 seconds.  Override it by setting the `LiveInterval` property:

```matlab
fp.LiveInterval = 0.5;
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));  % poll every 500 ms
```

---

## Live Dashboard

`FastSenseGrid` supports live mode across all tiles through the same interface:

```matlab
% Build a 2x2 dashboard
fig = FastSenseGrid(2, 2, 'Theme', 'dark');
fp1 = fig.tile(1); fp1.addLine(x, y1, 'DisplayName', 'Pressure');
fp2 = fig.tile(2); fp2.addLine(x, y2, 'DisplayName', 'Temperature');
fp3 = fig.tile(3); fp3.addLine(x, y3, 'DisplayName', 'Flow');
fig.tile(4).addLine(x, y4, 'DisplayName', 'Vibration');
fig.renderAll();

% Start live mode on the entire dashboard
fig.startLive('sensors.mat', @(fig, s) updateDashboard(fig, s));
```

The update callback for a dashboard looks like:

```matlab
function updateDashboard(fig, s)
    fig.tile(1).updateData(1, s.t, s.pressure);
    fig.tile(2).updateData(1, s.t, s.temperature);
    fig.tile(3).updateData(1, s.t, s.flow);
    fig.tile(4).updateData(1, s.t, s.vibration);
end
```

All view‑mode options and the `LiveInterval` property work the same as in the single‑plot case.

---

## Live Mode with Metadata

You can load metadata from a separate `.mat` file and attach it to a specific line and tile.  The metadata updates on each poll cycle.

Configure the metadata location and variables:

```matlab
fp.MetadataFile = 'meta.mat';
fp.MetadataVars = {'units', 'location', 'sensor_type'};
fp.MetadataLineIndex = 1;  % attach to first (or any) line in the tile
```

For a `FastSenseGrid` dashboard, the same fields exist on the grid object; additionally, you can specify which tile the metadata belongs to:

```matlab
fig.MetadataTileIndex = 2;  % attach to the second tile
fig.MetadataLineIndex = 1;
fig.MetadataFile = 'meta.mat';
fig.MetadataVars = {'units', 'calibration'};
```

The metadata is then accessible in datatips and tooltips when the toolbar’s **Metadata** toggle is enabled.

---

## Octave Compatibility

GNU Octave does not support MATLAB `timer` objects.  Use the **blocking poll loop** instead:

```matlab
fp.LiveFile = 'data.mat';
fp.LiveUpdateFcn = @(fp, s) fp.updateData(1, s.x, s.y);
fp.runLive();  % blocks until Ctrl+C
```

For dashboards:

```matlab
fig.renderAll();
fig.LiveFile = 'data.mat';
fig.LiveUpdateFcn = @myUpdateFcn;
fig.runLive();
```

The loop reads the `.mat` file at `LiveInterval` seconds and calls `LiveUpdateFcn` when the file modification date changes.  Press **Ctrl+C** to stop.

---

## Manual Refresh

Trigger a one‑shot reload without starting continuous polling:

```matlab
fp.refresh();   % loads fp.LiveFile, calls LiveUpdateFcn
fig.refresh();  % same for grids
```

---

## Toolbar Integration

The [[API Reference: FastPlot|FastSenseToolbar]] **Live Mode** button toggles polling on and off.  The **Refresh** button triggers a one‑shot reload, and the **Follow** button toggles `'follow'` vs. `'preserve'` view modes.

```matlab
tb = FastSenseToolbar(fp);
tb.toggleLive();   % start/stop live polling programmatically
tb.refresh();      % manual one-shot refresh
tb.setFollow(true)  % enable follow mode (Keep latest data visible)
```

---

## Console Progress Bars

During long render operations (e.g., the initial `render()` on large datasets), a `ConsoleProgressBar` provides visual feedback in the console:

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();     % make current state permanent
```

If `ShowProgress` is `true` (default), the dashboard renderer automatically displays hierarchical progress for each tile.

---

## Tips

- Use `'ViewMode', 'follow'` when you want the plot to always show the latest incoming data.
- Use `'preserve'` if users need to inspect a specific time window while live updates continue.
- Set the polling interval to a reasonable value (1–5 seconds) to avoid flooding the filesystem or the MATLAB process.
- Write the `.mat` file atomically: save to a temporary file, then `movefile()` it over the target. This prevents `load()` from reading a partially written file.
- Live mode works seamlessly with linked axes (`LinkGroup`) — all linked plots update together.
- Use `DeferDraw = true` during batch updates to skip `drawnow` calls for better performance.
- For Octave, remember to use `runLive()` instead of `startLive()` for the blocking poll loop.

---

## See Also

- [[API Reference: FastPlot]] — `startLive()`, `stopLive()`, `updateData()` methods
- [[API Reference: Dashboard]] — Dashboard live mode
- [[API Reference: Event Detection]] — Event layer and live event pipelines
- [[Examples]] — example_dashboard_live.m, example_live_pipeline.m
