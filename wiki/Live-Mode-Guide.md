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

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is called every poll cycle:
- `fp` — the FastSense instance
- `s` — struct loaded from the `.mat` file
- `fp.updateData(lineIdx, newX, newY)` replaces line data and re-renders

By default, the plot is polled every 2 seconds (see the `LiveInterval` property). When the file’s modification time changes, the new data is loaded and the display updates.

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the **Live Mode** button in the [[FastSenseToolbar]] (see [Toolbar Integration](#toolbar-integration)).

---

## View Modes

Control how the view updates when new data arrives:

| Mode       | Behavior                                                       |
|------------|----------------------------------------------------------------|
| `'preserve'` | Keep current zoom/pan position. User’s view is not disturbed. |
| `'follow'`   | Scroll the X‑axis to show the latest data. Ideal for monitoring. |
| `'reset'`    | Zoom to show all data. Good for overview.                      |

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

Default is 2 seconds. Adjust with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % poll every 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % poll every 5 s
```

You can also set the `LiveInterval` property before calling `startLive`:

```matlab
fp.LiveInterval = 1.5;
fp.startLive('data.mat', @updateFcn);
```

---

## Live Dashboard

`FastSenseGrid` supports live mode across all tiles:

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

The `fig.startLive` method creates a single timer that polls the file and calls the update function; each tile’s line is updated independently.

---

## Live Mode with Metadata

You can attach metadata (extra fields like units, calibration date, etc.) that updates with every poll.

Metadata is loaded from a **separate** `.mat` file. Set the `MetadataFile`, `MetadataVars`, and line/tile indices **before** starting live mode:

```matlab
fp = FastSense(...);
% ... add lines, render ...

fp.MetadataFile = 'meta.mat';
fp.MetadataVars = {'units', 'calibration'};
fp.MetadataLineIndex = 1;   % which line within the plot gets the metadata
fp.startLive('data.mat', @updateFcn);
```

Now, on every refresh, the variables `units` and `calibration` are loaded from `meta.mat` and attached to the specified line. You can then use `lookupMetadata` to retrieve the metadata at any point:

```matlab
m = fp.lookupMetadata(1, 3.5);   % metadata at x=3.5 for line 1
disp(m.units)
```

On a `FastSenseGrid`, you have analogous properties, plus `MetadataTileIndex` to select which tile’s line receives the metadata:

```matlab
fig.MetadataFile = 'meta.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;
fig.MetadataTileIndex = 1;   % attach to tile 1’s line
```

---

## Octave Compatibility

GNU Octave does not support MATLAB timers. Use `runLive()` for a blocking poll loop:

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

Trigger a one-shot data reload without starting continuous polling:

```matlab
fp.refresh();    % loads LiveFile, calls LiveUpdateFcn, reloads metadata
fig.refresh();
```

---

## Toolbar Integration

The [[FastSenseToolbar]] provides a **Live Mode** button and a **Refresh** button.

```matlab
tb = FastSenseToolbar(fp);
% Click the Live Mode button to toggle polling on/off
% Or programmatically:
tb.toggleLive();
```

The Refresh button triggers `fp.refresh()`:

```matlab
tb.refresh();
```

When toolbar is attached to a `FastSenseGrid`, `toggleLive` starts/stops live mode on the whole dashboard.

---

## Console Progress Bars

`ConsoleProgressBar` is a lightweight utility for visual feedback during long operations (e.g., rendering many dashboards). It is not tied to live mode, but useful for scripts that prepare or refresh data.

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % makes the current state permanent (prints newline)
```

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring use cases where you always want to see the latest data.
- Use `'preserve'` when users need to zoom into historical data while live updates continue.
- Keep the polling interval reasonable (1–5 seconds) to avoid overwhelming the file system.
- Write the `.mat` file **atomically** (write to a temp file, then rename) to prevent partial reads.
- Live mode works with linked axes — all linked plots update together when `updateData` is called on any of them.
- Use `DeferDraw = true` to suppress `drawnow` during batch updates (improves performance).
- Metadata variables are loaded from a **separate** `.mat` file and are attached to a specific line; make sure the variable names exist in that file.

---

## See Also

- [[API Reference: FastPlot]] — `startLive()`, `stopLive()`, `updateData()`, `refresh()`, `setViewMode()` methods and live‑related properties
- [[Dashboard|API Reference: Dashboard]] — Dashboard live mode (`startLive`, `stopLive`, `refresh`)
- [[Examples]] — `example_dashboard_live.m` (if available)
