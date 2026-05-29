<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a `.mat` file for updates and auto‑refreshing the display. Live mode works with single plots, tiled dashboards (`FastSenseGrid`), and tabbed docks (`FastSenseDock`).

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

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is invoked every poll cycle:
- `fp` – the `FastSense` instance
- `s` – struct loaded from the `.mat` file
- `updateData(lineIdx, newX, newY)` – replaces line data and re‑renders

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the **Live Mode** button in the [[FastSenseToolbar|API Reference: FastSenseToolbar]].

---

## View Modes

Control how the view updates when new data arrives:

| Mode        | Behaviour                                                                 |
|-------------|---------------------------------------------------------------------------|
| `'preserve'` | Keep current zoom/pan position. The user’s view is undisturbed.          |
| `'follow'`   | Scroll the X‑axis to show the latest data. Good for monitoring.          |
| `'reset'`    | Zoom to show all data. Provides a full overview.                        |

Set the mode when starting live mode:

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change interactively while live mode is running:

```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

The mode can also be changed by clicking the **Follow** button on the toolbar.

---

## Polling Interval

Default interval is `2.0` seconds. Adjust with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);   % 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % 5 seconds
```

---

## Live Dashboard

`FastSenseGrid` supports live mode across all tiles simultaneously:

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

A typical update callback for a dashboard:

```matlab
function updateDashboard(fig, s)
    fig.tile(1).updateData(1, s.t, s.pressure);
    fig.tile(2).updateData(1, s.t, s.temperature);
    fig.tile(3).updateData(1, s.t, s.flow);
    fig.tile(4).updateData(1, s.t, s.vibration);
end
```

The same `startLive` / `stopLive` / `refresh` / `setViewMode` methods exist on the `FastSenseGrid` object.

---

## Live Mode with Metadata

You can load and attach per‑poll metadata from a separate `.mat` file. The metadata is attached to a specified line and automatically updated on every poll.

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.render();

% Configure metadata
fp.MetadataFile = 'meta.mat';           % path to metadata file
fp.MetadataVars = {'units', 'calibration'};
fp.MetadataLineIndex = 1;               % line to attach to

fp.startLive('data.mat', @updateFcn);
```

For `FastSenseGrid` dashboards, you can target a specific tile and line:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line within the tile
fig.MetadataTileIndex = 1;   % which tile to attach to
```

The metadata is loaded on each poll and attached to the specified line. The active metadata for a given X coordinate can be retrieved with `lookupMetadata(lineIdx, xValue)`.

---

## Octave Compatibility

GNU Octave does not support MATLAB timers. Use `runLive()` for a blocking poll loop:

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

`runLive()` is a no‑op on MATLAB when the timer is already active; it is intended only for the Octave fallback.

---

## Manual Refresh

Trigger a one‑shot data reload without starting continuous polling:

```matlab
fp.refresh();
fig.refresh();
```

---

## Toolbar Integration

The [[FastSenseToolbar|API Reference: FastSenseToolbar]] provides a Live Mode toggle button:

```matlab
tb = FastSenseToolbar(fp);
% Click the Live Mode button to start/stop polling.
% Programmatic equivalents:
tb.toggleLive();
```

The **Refresh** button triggers a manual reload:

```matlab
tb.refresh();
```

---

## Console Progress Bars

`ConsoleProgressBar` is a lightweight utility for visual feedback during long operations (e.g., rendering multiple tiles). It is not specific to live mode but is often used in conjunction with live dashboards.

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % final line remains in console
```

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring use cases where you always want to see the latest data.
- Use `'preserve'` when users need to zoom into historical data while live updates continue.
- Keep the polling interval reasonable (1–5 seconds) to avoid overloading the file system.
- The `.mat` file should be written atomically (write to a temp file, then rename) to avoid partial reads.
- Live mode works with linked axes – all plots in a link group update together.
- Use `DeferDraw = true` to skip `drawnow` during batch render for better performance.
- For large datasets, consider using the `StorageMode = 'disk'` option to avoid memory pressure.

---

## See Also

- [[API Reference: FastPlot]] – `startLive()`, `stopLive()`, `updateData()` methods
- [[API Reference: Dashboard]] – `FastSenseGrid` live mode
- [[API Reference: Event Detection]] – live event detection pipelines
- [[Examples]] – `example_dashboard_live.m`
