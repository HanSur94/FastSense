<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a `.mat` file for updates and auto-refreshing the display. The live mode mechanism works with single plots, tiled dashboards (`FastSenseGrid`), and tabbed docks (`FastSenseDock`). This guide covers all live-mode capabilities found in the core library.

---

## Basic Live Plot

The simplest live plot polls a `.mat` file containing time‑series data and replaces the line data on every change.

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

The callback receives two arguments:
- `fp` – the `FastSense` instance that owns the plot
- `s`  – struct loaded from `data.mat`

The expression `fp.updateData(lineIdx, newX, newY)` replaces the raw data for the specified line and triggers a re‑downsample followed by a redraw. If your `.mat` file contains a different variable name, adjust the callback accordingly.

### Stopping Live Mode

```matlab
fp.stopLive();
```

This halts the polling timer and cleans up related resources. The Live Mode button in the toolbar (see [[#Toolbar Integration]]) also toggles the live state.

---

## View Modes

When new data arrives, the view mode determines how the X‑axis limits are adjusted:

| Mode        | Behaviour |
|-------------|-----------|
| `'preserve'` | Keep current zoom/pan position. User’s view is not disturbed. |
| `'follow'`   | Scroll the X-axis to show the latest data. Ideal for real‑time monitoring. |
| `'reset'`    | Zoom out to show all data. Good for an overview after a data refresh. |

Specify the view mode at start‑time:

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change the mode while polling is active:

```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

---

## Polling Interval

The default poll interval is 2 seconds. Override it with the `'Interval'` name‑value argument:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % Poll every 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);    % Poll every 5 seconds
```

Very short intervals (e.g., < 0.2 s) may cause file‑system thrash; keep the interval reasonable for your use case.

---

## Live Dashboard

`FastSenseGrid` (tiled layout) can run live mode across all tiles simultaneously. The grid manages a single polling loop, and your callback updates each tile individually.

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

A typical update callback for the dashboard:

```matlab
function updateDashboard(fig, s)
    fig.tile(1).updateData(1, s.t, s.pressure);
    fig.tile(2).updateData(1, s.t, s.temperature);
    fig.tile(3).updateData(1, s.t, s.flow);
    fig.tile(4).updateData(1, s.t, s.vibration);
end
```

If a tile does not yet exist (e.g., created lazily by `fig.tile(n)`), the callback must ensure it has been rendered before calling `updateData`. In the example above, `renderAll` eagerly renders all tiles, so the tiles are ready.

---

## Live Mode with Metadata

You can attach metadata (extra information about the data) that is loaded from a separate `.mat` file and updates on each poll. Metadata is attached to a specific line and tile.

```matlab
fp.startLive('data.mat', @updateFcn, ...
    'MetadataFile', 'meta.mat', ...
    'MetadataVars', {'units', 'calibration'});
```

For a dashboard, configure the same properties on the `FastSenseGrid` instance and specify which tile and line receive the metadata:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line index within the tile
fig.MetadataTileIndex = 1;   % which tile to attach to
```

The metadata is loaded on every live poll (or manual `refresh()`), and is available for lookup later using `fp.lookupMetadata(lineIdx, xValue)`.

---

## Octave Compatibility

GNU Octave does not support MATLAB timer objects. For Octave, use the blocking `runLive()` method instead:

```matlab
fp.render();
fp.LiveFile = 'data.mat';
fp.LiveUpdateFcn = @(fp, s) fp.updateData(1, s.x, s.y);
fp.runLive();   % Blocking loop — press Ctrl+C to stop
```

For dashboards:

```matlab
fig.renderAll();
fig.LiveFile = 'data.mat';
fig.LiveUpdateFcn = @myUpdateFcn;
fig.runLive();
```

On MATLAB, calling `runLive()` when the timer is already active is a no‑op; the timer continues in the background. The blocking loop is used only when timers are unavailable.

---

## Manual Refresh

Trigger a one‑time data reload without starting a continuous polling timer:

```matlab
fp.refresh();   % FastSense
fig.refresh();  % FastSenseGrid
```

The `refresh` method loads the current `LiveFile`, invokes the `LiveUpdateFcn`, and reloads the metadata file if one is configured. This is useful for sporadic updates, e.g., a “Refresh” button in a UI.

---

## Toolbar Integration

The [[API Reference: FastPlot|FastSenseToolbar]] provides dedicated buttons for live‑mode control:

```matlab
tb = FastSenseToolbar(fp);
```

- **Live Mode** – toggles polling on/off (calls `startLive` / `stopLive` under the hood).
- **Refresh** – triggers a manual one‑shot reload (`fp.refresh()`).
- **Follow** – sets `ViewMode` to `'follow'` and, if the current XLim does not already include the data tail, snaps to the end.

You can invoke these actions programmatically:

```matlab
tb.toggleLive();
tb.setFollow(true);
tb.refresh();
```

The toolbar rebinds itself automatically to a new `FastSenseGrid` or `FastSense` target via `tb.rebind(target)`.

---

## Console Progress Bars

If you need visual feedback during long operations (e.g., a multi‑tile render), you can use `ConsoleProgressBar` hich is independent of live mode but often used alongside it.

```matlab
pb = ConsoleProgressBar(2);   % 2-space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % makes the current bar state permanent
```

The progress bar overwrites itself in the console window. Call `freeze()` to keep the current state visible before starting a new bar on the next line, or call `finish()` to mark the bar complete at 100%.

`FastSense` and `FastSenseGrid` respect the `ShowProgress` property (default `true`) and automatically create a progress bar during `render()` / `renderAll()`. You can disable it with:

```matlab
fp.ShowProgress = false;
fig.ShowProgress = false;
```

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring dashboards where you always want to see the latest data.
- Use `'preserve'` when operators need to zoom into historical data while live updates continue in the background.
- Keep the polling interval reasonable (1–5 seconds) to avoid overloading the file system. If your data changes faster, consider streaming approaches instead of file polling.
- Write the `.mat` file atomically (save to a temporary file and then rename) to prevent live mode from reading a partially written file.
- Live mode works seamlessly with linked axes (`LinkGroup`). All linked plots update together when any one of them changes.
- Use `DeferDraw = true` to suppress `drawnow` during batch renders and speed up initial display.
- The event‑picking UI (`startEventPick_`, `openEventDetails_`) is separate from live mode but can coexist; the toolbar’s hover crosshair continues to function during live updates.
- On Octave, the blocking `runLive()` loop exits when the figure is closed or when `LiveIsActive` is set to `false`.

---

## See Also

- [[API Reference: FastPlot]] – `startLive()`, `stopLive()`, `updateData()`, `refresh()`
- [[API Reference: Dashboard]] – `FastSenseGrid` live mode methods
- [[API Reference: Themes]] – theming of axes during live updates
- [[Examples]] – look for `example_dashboard_live.m` and `example_live_pipeline.m` (if present) for complete scripts.
