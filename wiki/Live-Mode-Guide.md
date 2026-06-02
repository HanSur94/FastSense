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
- `fp` – the FastSense instance
- `s` – struct loaded from the `.mat` file
- `fp.updateData(lineIdx, newX, newY)` – replaces line data and re‑renders

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the Live Mode button in the [[API Reference: FastPlot#FastSenseToolbar|toolbar]].

---

## View Modes

Control how the view updates when new data arrives:

| Mode          | Behavior                                                                 |
|---------------|--------------------------------------------------------------------------|
| `'preserve'`  | Keep current zoom/pan position. The user’s view is not disturbed.        |
| `'follow'`    | Scroll the X‑axis to show the latest data. Good for monitoring.          |
| `'reset'`     | Zoom to show all data. Good for a quick overview.                        |

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change view mode while running:
```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

For one‑time “jump to tail” without changing the mode, use `snapToTail`:
```matlab
fp.snapToTail();   % move XLim so the right edge sits just past the data tail
```

The current view mode is stored in `fp.LiveViewMode` and can be read at any time.

---

## Polling Interval

Default is 2 seconds. Adjust with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % poll every 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);    % poll every 5 s
```

The interval can also be configured globally in `FastSenseDefaults`:
```matlab
cfg = FastSenseDefaults();
cfg.LiveInterval = 1.0;   % default for all new plots (if left unspecified)
```

---

## Live Dashboard

`FastSenseGrid` supports live mode across all tiles. Use the grid’s own `startLive` to synchronise polling:

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

Update callback for the dashboard:
```matlab
function updateDashboard(fig, s)
    fig.tile(1).updateData(1, s.t, s.pressure);
    fig.tile(2).updateData(1, s.t, s.temperature);
    fig.tile(3).updateData(1, s.t, s.flow);
    fig.tile(4).updateData(1, s.t, s.vibration);
end
```

The dashboard-wide `LiveViewMode`, `LiveFile`, and `LiveUpdateFcn` are propagated to each tile automatically. Individual tiles can override some settings, but normally you work through the grid.

---

## Live Mode with Metadata

Attach metadata that updates on each poll. The metadata is loaded from a separate file and attached to a chosen line and tile.

```matlab
fp.startLive('data.mat', @updateFcn, ...
    'MetadataFile', 'meta.mat', ...
    'MetadataVars', {'units', 'calibration'});
```

When using a `FastSenseGrid` you can set the metadata target explicitly:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;    % which line within the tile
fig.MetadataTileIndex = 1;    % which tile to attach to
```

Metadata variables are stored per line and can be retrieved with `lookupMetadata`:

```matlab
meta = fp.lookupMetadata(lineIdx, xValue);
```

Th reshold lines and bands are **not** affected; metadata is associated with line data only.

---

## Live Mode and Threshold Violations

Combining live updates with thresholds gives real‑time violation monitoring. Simply add thresholds before calling `render` (or use `updateData` after render) and ensure `ShowViolations` is `true`. The live callback refreshes the violation markers automatically.

```matlab
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y));
```

Violations can be toggled on/off globally while live mode is active:
```matlab
fp.setViolationsVisible(false);   % hide all markers
fp.setViolationsVisible(true);    % recompute and show
```

For dashboards, use the toolbar’s violations toggle; it iterates over all tiles.

---

## Octave Compatibility

GNU Octave does not support MATLAB timer objects. Use `runLive()` for a blocking poll loop:

```matlab
fp.render();

% Blocking loop – press Ctrl+C to stop
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

The loop automatically checks `LiveIsActive`; setting it to `false` (e.g. from a UI) will exit cleanly.

---

## Manual Refresh

Trigger a one‑shot data reload without starting continuous polling:

```matlab
fp.refresh();     % on a single FastSense
fig.refresh();    % on a FastSenseGrid dashboard
```

This reads the current `LiveFile`, calls the `LiveUpdateFcn`, and updates the timestamp. Useful for user‑driven updates or debugging.

---

## Toolbar Integration

The [[FastSenseToolbar|API Reference: FastPlot#FastSenseToolbar]] provides a Live Mode button. Attach it after rendering:

```matlab
tb = FastSenseToolbar(fp);
```

Toolbar buttons:
- **Live Mode** – toggle polling on/off with `tb.toggleLive()`
- **Refresh** – manual one‑shot reload with `tb.refresh()`
- **Follow** – toggle `preserve`/`follow` mode with `tb.setFollow(true/false)`

The toolbar automatically binds to the plot target and synchronises its state.

---

## Console Progress Bars

For long‑running tasks like rendering a large dashboard, use `ConsoleProgressBar` to show progress in the console:

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % make the bar permanent
```

This is particularly useful in conjunction with `renderAll` when building live dashboards.

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring use cases where you always want to see the latest data.
- Use `'preserve'` when users need to zoom into historical data while live updates continue.
- Keep polling interval reasonable (1–5 seconds) to avoid overwhelming the file system.
- The `.mat` file should be written atomically (write to temp file, then rename) to avoid partial reads.
- Live mode works with linked axes – all plots in the same `LinkGroup` update together.
- Use `DeferDraw = true` during batch render to skip `drawnow` and improve performance.
- To stop live mode programmatically, call `stopLive()`; the internal timer and any deferred timers are cleaned up automatically.

---

## See Also

- [[API Reference: FastPlot]] – `startLive()`, `stopLive()`, `updateData()`, `snapToTail()`
- [[API Reference: Dashboard]] – dashboard live mode and metadata
- [[Examples]] – `example_dashboard_live.m`, `example_live_pipeline.m` (if present)
- [[Datetime Guide]] – formatting X‑axis when timestamps are datenums
- [[Dashboard Engine Guide]] – widget‑based dashboards with live updates
