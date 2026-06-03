<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a `.mat` file for updates and auto‑refreshing the display. Live mode works with single plots, tiled dashboards (`FastSenseGrid`), and tab‑docked configurations (`FastSenseDock`).

---

## Basic Live Plot

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

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is executed each poll cycle:
- `fp` — the FastSense instance
- `s` — struct loaded from the `.mat` file
- `fp.updateData(lineIdx, newX, newY)` replaces line data and triggers re‑rendering

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the **Live Mode** button in the toolbar.

---

## View Modes

Control how the view adjusts when new data arrives:

| Mode        | Behavior |
|-------------|----------|
| `'preserve'`| Keep current zoom/pan position. The user’s view is not disturbed. |
| `'follow'`  | Scroll the X‑axis to show the latest data. Ideal for monitoring. |
| `'reset'`   | Zoom to show all data. Good for an overview. |

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change view mode while polling:

```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

---

## Polling Interval

The default interval is 2 seconds. Adjust with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % 5 seconds
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

---

## Live Mode with Metadata

Metadata that updates on each poll is loaded from a separate `.mat` file and attached to a specific line:

```matlab
fp.MetadataFile = 'meta.mat';
fp.MetadataVars = {'units', 'calibration'};
fp.MetadataLineIndex = 1;

fp.startLive('data.mat', @updateFcn);
```

For dashboards, the same properties are available on the `FastSenseGrid` object and you can also specify the target tile:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;      % line within the tile
fig.MetadataTileIndex = 1;      % which tile receives the metadata
```

The metadata can be queried later using `lookupMetadata(lineIdx, xValue)`, which applies forward‑fill semantics.

---

## Octave Compatibility

GNU Octave does not support MATLAB timers. Use `runLive()` for a blocking poll loop:

```matlab
fp.render();

% Polling loop — press Ctrl+C to stop
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

## Manual Refresh

Trigger a one‑shot data reload without starting continuous polling:

```matlab
fp.refresh();
fig.refresh();
```

The `refresh()` method reloads the current `LiveFile` (and the `MetadataFile`, if configured) and invokes the update callback once.

---

## Toolbar Integration

The [[API Reference: FastPlot#FastSenseToolbar|FastSenseToolbar]] provides a Live Mode button and a Refresh button:

```matlab
tb = FastSenseToolbar(fp);
% Click the Live Mode button to toggle polling on/off
% Programmatically:
tb.toggleLive();
```

A manual refresh via the toolbar:

```matlab
tb.refresh();
```

The toolbar also includes a `setFollow(true/false)` method to change the view mode to `'follow'` or `'preserve'`.

---

## Console Progress Bars

Use `ConsoleProgressBar` for visual feedback during long render operations (e.g., when rendering a multi‑tile dashboard):

```matlab
pb = ConsoleProgressBar(2);   % 2‑space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % makes the bar a permanent line
```

The class provides three lifecycle methods:
- `start()` – initialise the bar
- `update(current, total, label)` – update progress and redraw in‑place
- `freeze()` – finalise the bar on its own line (allows subsequent bars to be printed below)
- `finish()` – equivalent to setting progress to 100 % and calling `freeze()`

This utility is independent of live mode but is often used when building dashboards with `renderAll`.

---

## Tips

- Use `'ViewMode', 'follow'` for monitoring use cases where you always want to see the latest data.
- Use `'preserve'` when users need to zoom into historical data while live updates continue.
- Keep the polling interval reasonable (1–5 seconds) to avoid overwhelming the file system.
- The `.mat` file should be written atomically (write to a temporary file, then rename) to avoid partial reads.
- Live mode works with linked axes — all plots in the same `LinkGroup` update together.
- Set `DeferDraw = true` to skip `drawnow` during batch updates for better performance.
- The `snapToTail()` method can be used to manually scroll the X‑axis to the data tail without changing the view mode.

---

## See Also

- [[API Reference: FastPlot]] — `startLive()`, `stopLive()`, `updateData()` methods
- [[API Reference: Dashboard]] — Dashboard live mode (`FastSenseGrid.startLive`)
- [[API Reference: Event Detection]] — Event detection library
- [[Examples]] — `example_dashboard_live.m` and other live‑mode examples
