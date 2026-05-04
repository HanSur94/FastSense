<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

Live mode allows a FastSense plot or Dashboard to continuously poll a `.mat` file for new data and automatically update the display. It works with single plots, tiled dashboards, and tabbed docks, with fine control over polling interval, view behaviour, and metadata attachment.

---

## Basic Live Plot

Create a FastSense instance, define the initial data, and then start polling:

```matlab
install;

fp = FastSense('Theme', 'dark');
x = linspace(0, 10, 1e5);
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

% Callback receives the FastSense object and the struct loaded from the file
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
```

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is called every poll cycle:
- `fp` — the FastSense instance
- `s` — struct loaded from the `.mat` file
- `fp.updateData(lineIdx, newX, newY)` — replaces the raw data for the specified line and re‑renders.

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the **Live Mode** button in the toolbar (see [[API Reference: FastSenseToolbar]]).

---

## View Modes

Control how the X‑axis adjusts after new data is loaded:

| Mode | Behaviour |
|------|-----------|
| `'preserve'` | Keep current zoom/pan position. User’s view is not disturbed. |
| `'follow'`   | Scroll the X‑axis to show the latest data (monitoring use case). |
| `'reset'`    | Zoom out to show all data in the series. |

Set the mode when starting live:

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change view mode while live mode is active:

```matlab
fp.setViewMode('preserve');
fp.setViewMode('follow');
```

The current mode is stored in the public property `LiveViewMode`.

---

## Polling Interval

Default polling interval is **2 seconds**. Adjust it with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % poll every 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % poll every 5 s
```

The interval is also available as the property `LiveInterval`.

---

## Live Dashboard

`FastSenseGrid` (tiled layout) supports live mode that synchronises file polling across all tiles.

```matlab
fig = FastSenseGrid(2, 2, 'Theme', 'dark');

% Set up four tiles
fp1 = fig.tile(1); fp1.addLine(x, y1, 'DisplayName', 'Pressure');
fp2 = fig.tile(2); fp2.addLine(x, y2, 'DisplayName', 'Temperature');
fp3 = fig.tile(3); fp3.addLine(x, y3, 'DisplayName', 'Flow');
fp4 = fig.tile(4); fp4.addLine(x, y4, 'DisplayName', 'Vibration');

fig.renderAll();

% Start live mode on the entire dashboard
fig.startLive('sensors.mat', @(fig, s) updateDashboard(fig, s), ...
    'Interval', 2, 'ViewMode', 'follow');
```

The update callback receives the `FastSenseGrid` instance and the struct loaded from the file. Inside the callback, you update each tile’s data independently:

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

Attach metadata that updates on every poll by setting the metadata properties **before** starting live mode.

### Single Plot

```matlab
fp.MetadataFile = 'meta.mat';
fp.MetadataVars = {'units', 'calibration'};
fp.MetadataLineIndex = 1;   % which line to attach metadata to
fp.startLive('data.mat', @updateFcn);
```

### Dashboard

For a dashboard, use the figure‑level metadata properties:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line within the tile
fig.MetadataTileIndex = 1;   % which tile to attach metadata to
fig.startLive('data.mat', @updateDashboard);
```

Metadata is loaded from a separate `.mat` file each time the main data file changes. The values are attached to the specified tile and line and can be retrieved later with `lookupMetadata`.

---

## Octave Compatibility

GNU Octave does not support MATLAB timer objects. Use `runLive()` for a **blocking** poll loop:

```matlab
fp.render();
fp.LiveFile = 'data.mat';
fp.LiveUpdateFcn = @(fp, s) fp.updateData(1, s.x, s.y);
fp.runLive();   % press Ctrl+C to stop
```

For dashboards:

```matlab
fig.renderAll();
fig.LiveFile = 'data.mat';
fig.LiveUpdateFcn = @myUpdateFcn;
fig.runLive();
```

---

## Manual Refresh

Trigger a one‑shot reload without starting continuous polling:

```matlab
fp.refresh();    % loads LiveFile and calls LiveUpdateFcn once
fig.refresh();   % same for a dashboard
```

---

## Toolbar Integration

The [[API Reference: FastSenseToolbar|FastSenseToolbar]] provides a **Live Mode** toggle button and a **Refresh** button:

```matlab
tb = FastSenseToolbar(fp);
% Click the toolbar buttons interactively, or call programmatically:
tb.toggleLive();   % start/stop live mode
tb.refresh();      % manual one‑shot reload
```

---

## Console Progress Bars

During long operations (e.g., rendering many tiles), you may want visual feedback. Use `ConsoleProgressBar` for a single‑line progress indicator:

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % makes the bar permanent
```

This class is not specifically tied to live mode, but it can be useful inside update callbacks or dashboards where you want to show progress.

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring dashboards — you’ll always see the freshest data.
- Use `'preserve'` when users need to zoom into historical data while live updates continue in the background.
- Keep polling intervals reasonable (1–5 seconds) to avoid hammering the file system.
- Write the `.mat` file **atomically**: save to a temporary file, then rename. This avoids partially‑written files being read by the poller.
- Live mode works with linked axes — all plots in the same `LinkGroup` update together.
- Set `DeferDraw = true` on the FastSense instance to suppress `drawnow` during batch updates for better performance.
- If you need to update metadata synchronously, set `MetadataFile` before `startLive`; the metadata is reloaded on every file change.

---

## See Also

- [[API Reference: FastPlot]] — `startLive()`, `stopLive()`, `updateData()`, `refresh()`
- [[API Reference: Dashboard]] — `FastSenseGrid` live mode
- [[Examples]] — `example_dashboard_live.m` (dashboard live example)
- [[Getting Started]] — basic plot setup
- [[Architecture]] — internal timer lifecycle
