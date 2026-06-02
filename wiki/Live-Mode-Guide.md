<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a `.mat` file for updates and auto‑refreshing the display. Live mode works with single plots, tiled dashboards ([[Dashboard|API Reference: Dashboard]]), and tabbed docks.

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

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is called on every poll cycle:
- `fp` – the FastSense instance
- `s`   – struct loaded from the `.mat` file
- `fp.updateData(lineIdx, newX, newY)` – replaces the line’s data and re‑renders

### Stopping Live Mode

```matlab
fp.stopLive();
```

You can also use the **Live Mode** button in the toolbar (see [Toolbar Integration](#toolbar-integration)).

---

## View Modes

Control how the view updates when new data arrives:

| Mode        | Behavior                                                                 |
|-------------|--------------------------------------------------------------------------|
| `'preserve'` | Keep the current zoom/pan position. The user’s view is not disturbed.   |
| `'follow'`   | Scroll the X‑axis to show the latest data. Ideal for monitoring.        |
| `'reset'`    | Zoom to show all data. Good for an overview.                            |

```matlab
fp.startLive('data.mat', @updateFcn, 'ViewMode', 'follow');
```

Change the view mode at runtime:

```matlab
fp.setViewMode('follow');
fp.setViewMode('preserve');
```

---

## Polling Interval

The default interval is 2 seconds. Adjust it with the `'Interval'` option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);   % poll every 500 ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);      % poll every 5 s
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

Update callback for a dashboard:

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

Attach metadata that updates on each poll cycle. The metadata is loaded from a separate file and attached to a specific line and tile.

```matlab
fig = FastSenseGrid(2, 1, 'Theme', 'dark');
fig.tile(1).addLine(t, sensorData, 'DisplayName', 'Channel A');
fig.tile(2).addLine(t, sensorData2, 'DisplayName', 'Channel B');
fig.renderAll();

% Configure metadata source
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % line within the tile
fig.MetadataTileIndex = 1;   % which tile to attach metadata to

fig.startLive('live_data.mat', @updateWithMeta, 'Interval', 2);
```

Inside the update callback, you can also use `fp.setLineMetadata(lineIdx, meta)` to replace metadata on a line without relying on the file. For dashboards, set the properties directly on the `FastSenseGrid` object; they will be forwarded to the relevant tile.

---

## Event Overlays in Live Mode

You can display real‑time event markers by attaching an **EventStore** to a `FastSense` instance and enabling the overlay.

```matlab
fp.EventStore = myEventStore;   % EventStore handle
fp.ShowEventMarkers = true;
% Optionally refresh the event layer after adding new events:
fp.refreshEventLayer();
```

During live updates, call `fp.refreshEventLayer()` in your callback to reflect the latest events. For details on creating and managing events, see the [[Event Detection|API Reference: Event Detection]] documentation.

---

## Octave Compatibility

GNU Octave does not support MATLAB timer objects. Use `runLive()` instead for a blocking poll loop:

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

Trigger a one‑shot data reload without starting continuous polling:

```matlab
fp.refresh();      % for a single plot
fig.refresh();     % for a FastSenseGrid
```

---

## Toolbar Integration

The [[API Reference: FastPlot|API Reference: FastPlot]] toolbar provides a **Live Mode** toggle button, a **Refresh** button, and a **Follow** mode toggle.

```matlab
tb = FastSenseToolbar(fp);
% Click the Live Mode button to toggle polling on/off
% Or programmatically:
tb.toggleLive();
```

The Refresh button calls `fp.refresh()` or `fig.refresh()`. The Follow button sets `LiveViewMode='follow'` and snaps the X‑axis to the data tail.

---

## Console Progress Bars

Use `ConsoleProgressBar` for visual feedback during lengthy live updates (e.g., when processing many tiles or heavy computation).

```matlab
fp.startLive('data.mat', @(fp, s) updateWithProgress(fp, s), 'Interval', 2);

function updateWithProgress(fp, s)
    pb = ConsoleProgressBar(0);
    pb.start();
    % Simulate work across multiple lines/tiles
    nLines = 3;   % example
    for i = 1:nLines
        pb.update(i, nLines, ['Signal ' num2str(i)]);
        % update data ...
        fp.updateData(i, s.x, s.(['y' num2str(i)]));
    end
    pb.freeze();   % keeps the final progress line visible
end
```

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring use cases – you always see the latest data.
- Use `'preserve'` when users need to zoom into historical data while live updates continue.
- Keep the polling interval reasonable (1–5 seconds) to avoid excessive file‑system load.
- Write the `.mat` file **atomically** (write to a temp file, then rename) to prevent partial reads.
- Live mode works with linked axes – all plots in the same `LinkGroup` update together.
- Set `DeferDraw = true` on a `FastSense` instance before a batch of `updateData` calls, then clear it to avoid multiple `drawnow` events.
- Use the `'SkipViewMode'` option in `updateData` to suppress X‑axis auto‑adjustment when it is not needed:  
  `fp.updateData(1, newX, newY, 'SkipViewMode', true);`.
- For dashboards, you can assign a `ConsoleProgressBar` parent to `renderAll` via the `parentProgressBar` argument to show hierarchical progress.

---

## See Also

- [[API Reference: FastPlot]] – `startLive()`, `stopLive()`, `updateData()`, `refresh()`
- [[Dashboard|API Reference: Dashboard]] – dashboard live mode (`FastSenseGrid`)
- [[API Reference: Event Detection]] – overlaying events with `EventStore`
- [[Examples]] – `example_dashboard_live.m`, `example_live_pipeline.m` (if available)
