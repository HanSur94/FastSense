<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by continuously polling a `.mat` file for new data and auto-refreshing the display. Live mode works with single plots, tiled dashboards ([[Dashboard|API Reference: Dashboard]]), and tabbed docks ([[FastSenseDock|API Reference: FastSenseDock]]). It can also update per‑point metadata from a companion file.

---

## Basic Live Plot

1. **Create a plot** (add lines, thresholds, etc.) and call `render()`.  
2. **Start live polling** with `startLive()`, providing a `.mat` file path and a callback that handles the newly loaded data.

```matlab
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

The callback receives:

- `fp` – the FastSense instance  
- `s` – struct loaded from the `.mat` file  

In the callback you typically call `fp.updateData(lineIdx, newX, newY)` to replace the line data and re‑render.

### Stopping Live Mode

```matlab
fp.stopLive();
```

The live timer stops immediately. You can also use the **Live Mode** toggle button in the [[FastSenseToolbar|API Reference: FastSenseToolbar]].

---

## View Modes

Control how the X‑axis reacts when new data arrives:

| Mode        | Behavior |
|-------------|----------|
| `'preserve'` | Keep the user’s current zoom/pan position. The view is not disturbed. |
| `'follow'`   | Scroll the X‑axis to show the latest data. Ideal for monitoring. |
| `'reset'`    | Zoom out to show all data. Good for occasional overviews. |
| `''` (empty) | No automatic view adjustment. Equivalent to avoid changing limits. |

Set the view mode at startup:

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change it while live mode is running:

```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

---

## Polling Interval

The default polling interval is **2 seconds**. Adjust with the `'Interval'` parameter (in seconds):

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);   % every half‑second
fp.startLive('data.mat', @updateFcn, 'Interval', 5);      % every 5 seconds
```

---

## Manual Refresh

Trigger a one‑shot data reload without starting a timer:

```matlab
fp.refresh();
```

This loads the file set in `LiveFile`, calls `LiveUpdateFcn`, reloads metadata if configured, and updates the display once. The timestamp `LiveFileDate` is updated so that the next `refresh()` only pulls new data when the file has actually changed.

---

## Live Dashboard (FastSenseGrid)

[[FastSenseGrid|API Reference: Dashboard]] orchestrates live mode across all tiles of a dashboard.

### Setting Up

```matlab
fig = FastSenseGrid(2, 2, 'Theme', 'dark');

fp1 = fig.tile(1); fp1.addLine(x, y1, 'DisplayName', 'Pressure');
fp2 = fig.tile(2); fp2.addLine(x, y2, 'DisplayName', 'Temperature');
fp3 = fig.tile(3); fp3.addLine(x, y3, 'DisplayName', 'Flow');
fp4 = fig.tile(4); fp4.addLine(x, y4, 'DisplayName', 'Vibration');

fig.renderAll();

% Start live mode on the whole dashboard
fig.startLive('sensors.mat', @(fig, s) updateDashboard(fig, s), ...
    'Interval', 2, 'ViewMode', 'follow');
```

The update callback needs to push data to each tile:

```matlab
function updateDashboard(fig, s)
    fig.tile(1).updateData(1, s.t, s.pressure);
    fig.tile(2).updateData(1, s.t, s.temperature);
    fig.tile(3).updateData(1, s.t, s.flow);
    fig.tile(4).updateData(1, s.t, s.vibration);
end
```

`fig.startLive()` sets `LiveFile`, `LiveUpdateFcn`, and `LiveInterval` on the grid, starts a timer that calls the callback, and propagates `ViewMode` to all tiles.

### Controlling the Dashboard

- `fig.stopLive()` stops the timer.  
- `fig.refresh()` – manual one‑shot update.  
- `fig.setViewMode('follow')` – sets the view mode on every tile.  

---

## Live Mode with Metadata

You can attach metadata (e.g., sensor units, calibration info) that updates together with the data. The metadata is loaded from a *separate* `.mat` file.

### Per‑Plot Metadata

```matlab
fp.LiveFile      = 'data.mat';
fp.LiveUpdateFcn = @updateFcn;
fp.MetadataFile  = 'meta.mat';
fp.MetadataVars  = {'units', 'calibration'};   % variable names to extract
fp.MetadataLineIndex = 1;                      % which line to attach to

fp.startLive();
```

The metadata is attached to the specified line as a `struct` and can be queried with `fp.lookupMetadata()`. When a metadata file is configured, `refresh()` reloads it automatically.

### Dashboard Metadata

For a grid dashboard, set the properties before calling `startLive`:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line within the target tile
fig.MetadataTileIndex = 1;   % which tile receives the metadata
```

The metadata is forwarded to the tile’s `setLineMetadata()` on each poll.

---

## Octave Compatibility

GNU Octave does not support MATLAB `timer` objects. Use `runLive()` as a blocking alternative:

```matlab
fp.render();
fp.LiveFile = 'data.mat';
fp.LiveUpdateFcn = @(fp, s) fp.updateData(1, s.x, s.y);
fp.runLive();          % blocks until Ctrl+C or LiveIsActive becomes false
```

For dashboards:

```matlab
fig.renderAll();
fig.LiveFile = 'data.mat';
fig.LiveUpdateFcn = @myUpdateFcn;
fig.runLive();
```

`runLive()` loops internally at the configured `LiveInterval`, stopping when the figure is closed or `stopLive()` is called.

---

## Toolbar Integration

[[FastSenseToolbar|API Reference: FastSenseToolbar]] provides toolbar buttons for live mode:

```matlab
tb = FastSenseToolbar(fp);
% Click the Live Mode button to toggle polling on/off
% Or programmatically:
tb.toggleLive();
```

The **Refresh** button calls `tb.refresh()`, triggering a manual one‑shot reload of data and metadata.

---

## Console Progress Bars

During long render operations you may see a console progress bar. You can also use `ConsoleProgressBar` manually for feedback in custom loops:

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % leave the final bar on the console
```

---

## Tips

- **Polling interval** – Keep it reasonable (1–5 s) to avoid filesystem stress.  
- **Atomic writes** – Write the `.mat` file atomically (write to a temp file, then rename) to prevent partial reads.  
- **View mode** – Use `'follow'` for real‑time monitoring, `'preserve'` when users are inspecting historical data while live updates continue.  
- **Deferred rendering** – Set `DeferDraw = true` on the plot or grid to skip `drawnow` during batch updates, improving performance.  
- **Metadata** – Metadata files can be updated independently from the main data file; they are reloaded on every poll or manual refresh.  
- **Linked axes** – Live mode works with linked axes – all linked plots update together.  

---

## See Also

- [[API Reference: FastPlot]] – `startLive()`, `stopLive()`, `refresh()`, `updateData()`, `setViewMode()`
- [[API Reference: Dashboard]] – dashboard live mode (`FastSenseGrid.startLive`)
- [[API Reference: FastSenseDock]] – tabbed dock live mode
- [[API Reference: FastSenseToolbar]] – Live Mode toggle and Refresh buttons
- [[Examples]] – `example_dashboard_live.m`, `example_live_pipeline.m`
