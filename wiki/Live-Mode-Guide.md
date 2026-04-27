<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Live Mode Guide

FastSense supports live data visualization by polling a .mat file for updates and auto-refreshing the display. Live mode works with single plots, tiled dashboards, and tabbed docks.

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

The callback `@(fp, s) fp.updateData(1, s.x, s.y)` is called every poll cycle:
- `fp` — the FastSense instance
- `s` — struct loaded from the .mat file
- `fp.updateData(lineIdx, newX, newY)` — replaces line data and re-renders

### Stopping Live Mode

```matlab
fp.stopLive();
```

Or use the Live Mode button in the [[FastSenseToolbar|API Reference: Utilities]].

---

## View Modes

Control how the view updates when new data arrives:

| Mode | Behavior |
|------|----------|
| `'preserve'` | Keep current zoom/pan position. User's view is not disturbed |
| `'follow'` | Scroll X-axis to show the latest data. Good for monitoring |
| `'reset'` | Zoom to show all data. Good for overview |

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

Default is 2 seconds. Adjust with the 'Interval' option:

```matlab
fp.startLive('data.mat', @updateFcn, 'Interval', 0.5);  % Poll every 500ms
fp.startLive('data.mat', @updateFcn, 'Interval', 5);     % Poll every 5 seconds
```

---

## Live Dashboard

FastSenseGrid supports live mode across all tiles:

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

Attach metadata that updates on each poll:

```matlab
fp.startLive('data.mat', @updateFcn, ...
    'MetadataFile', 'meta.mat', ...
    'MetadataVars', {'units', 'calibration'});
```

The metadata is loaded from a separate file and attached to the specified line and tile:

```matlab
fig.MetadataFile = 'metadata.mat';
fig.MetadataVars = {'sensor_id', 'location', 'units'};
fig.MetadataLineIndex = 1;   % which line within the tile
fig.MetadataTileIndex = 1;   % which tile to attach to
```

---

## Tabbed Dock Live Mode

FastSenseDock inherits live mode functionality from its contained FastSenseGrid instances. Each tab can have its own live configuration:

```matlab
dock = FastSenseDock('Theme', 'dark', 'Name', 'Dashboard');

% Add tabs with individual live setups
fig1 = FastSenseGrid(2, 1, 'ParentFigure', dock.hFigure);
fig1.tile(1).addLine(x, y1); fig1.tile(2).addLine(x, y2);
dock.addTab(fig1, 'Temperature');
fig1.startLive('temp_data.mat', @tempUpdateFcn);

fig2 = FastSenseGrid(1, 1, 'ParentFigure', dock.hFigure);
fig2.tile(1).addLine(x, y3);
dock.addTab(fig2, 'Pressure');
fig2.startLive('pressure_data.mat', @pressureUpdateFcn, 'Interval', 1);

dock.render();
```

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

---

## Manual Refresh

Trigger a one-shot data reload without starting continuous polling:

```matlab
fp.refresh();
fig.refresh();
```

---

## Toolbar Integration

The [[FastSenseToolbar|API Reference: Utilities]] provides a Live Mode button:

```matlab
tb = FastSenseToolbar(fp);
% Click the Live Mode button to toggle polling on/off
% Or programmatically:
tb.toggleLive();
```

The Refresh button triggers a manual one-shot reload:
```matlab
tb.refresh();
```

---

## Console Progress Bars

Use ConsoleProgressBar for visual feedback during long operations:

```matlab
pb = ConsoleProgressBar(2);   % 2-space indent
pb.start();
for k = 1:8
    pb.update(k, 8, 'Tile 1');
    pause(0.1);
end
pb.freeze();   % becomes permanent line
```

---

## Tips

- Set `'ViewMode', 'follow'` for monitoring use cases where you always want to see the latest data
- Use `'preserve'` when users need to zoom into historical data while live updates continue
- Keep polling interval reasonable (1-5 seconds) to avoid overwhelming the file system
- The .mat file should be written atomically (write to temp file, then rename) to avoid partial reads
- Live mode works with linked axes — all linked plots update together
- Use `DeferDraw = true` to skip drawnow during batch render for better performance

---

## See Also

- [[API Reference: FastPlot]] — startLive(), stopLive(), updateData() methods
- [[API Reference: Dashboard]] — Dashboard live mode
- [[API Reference: Event Detection]] — Live event detection
- [[Examples]] — example_dashboard_live.m, example_live_pipeline.m
