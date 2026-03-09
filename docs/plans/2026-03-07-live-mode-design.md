# FastPlot Live Mode Design

## Overview

Add live plotting capability to FastPlot by watching a `.mat` file for changes and automatically refreshing plot data. No new classes — live mode is built directly into `FastPlot` and `FastPlotFigure`.

## User Workflow

1. User loads `.mat` file and creates plots as usual
2. User activates live mode via `startLive()` or toolbar button
3. FastPlot polls the file for changes and calls a user-provided update callback

## Usage Examples

### Single plot

```matlab
s = load('sensor_data.mat');
fp = FastPlot('Theme', 'dark');
fp.addLine(s.time, s.pressure, 'DisplayName', 'Pressure');
fp.addThreshold(100, 'Direction', 'upper', 'ShowViolations', true);
fp.render();

fp.startLive('sensor_data.mat', @(fp, data) liveUpdate(fp, data), ...
    'Interval', 2, 'ViewMode', 'preserve');

function liveUpdate(fp, s)
    fp.updateData(1, s.time, s.pressure);
end
```

### Dashboard

```matlab
fig = FastPlotFigure(2, 1, 'Theme', 'dark');
s = load('sensors.mat');
fp1 = fig.tile(1); fp1.addLine(s.time, s.pressure);
fp2 = fig.tile(2); fp2.addLine(s.time, s.temperature);
fig.renderAll();

fig.startLive('sensors.mat', @(fig, s) updateDash(fig, s), 'Interval', 2);

function updateDash(fig, s)
    fig.tile(1).updateData(1, s.time, s.pressure);
    fig.tile(2).updateData(1, s.time, s.temperature);
end
```

## Design

### 1. `FastPlot.updateData(lineIdx, newX, newY)`

Core data replacement method.

- Replaces raw X/Y data for the given line index
- Clears cached pyramid levels (rebuild lazily on next zoom)
- Re-downsamples to current screen resolution and visible range
- Updates violation markers for all thresholds
- Respects the current view mode
- Handles different data lengths, NaN recomputation

### 2. Live mode on `FastPlot`

New properties:

| Property | Default | Description |
|----------|---------|-------------|
| `LiveFile` | `''` | Path to .mat file |
| `LiveUpdateFcn` | `[]` | `@(fp, data)` callback |
| `LiveTimer` | `[]` | Timer object |
| `LiveInterval` | `2.0` | Poll interval in seconds |
| `LiveFileDate` | `0` | Last known file modification time |
| `LiveViewMode` | `'preserve'` | `'preserve'`, `'follow'`, or `'reset'` |
| `LiveIsActive` | `false` | Whether polling is running |

New public methods:

| Method | Description |
|--------|-------------|
| `startLive(file, updateFcn, ...)` | Configure and start polling. Options: `'Interval'`, `'ViewMode'` |
| `stopLive()` | Stop timer, clear live state |
| `refresh()` | Manual one-shot: reload file, call updateFcn |
| `setViewMode(mode)` | Change view mode at runtime |

Timer callback flow:

1. Check `dir(LiveFile).datenum` against `LiveFileDate`
2. If unchanged, skip
3. If changed, `data = load(LiveFile)`, call `LiveUpdateFcn(obj, data)`, apply view mode, `drawnow`
4. Store new `LiveFileDate`
5. If file missing or load fails, skip silently (file may be mid-write)

Cleanup: `stopLive()` called automatically when figure closes via `DeleteFcn`.

### 3. Live mode on `FastPlotFigure`

Same interface as FastPlot: `startLive()`, `stopLive()`, `refresh()`, `setViewMode()`. Owns the timer, callback receives `(fig, data)` so user can update any tile.

### 4. Toolbar integration

| Button | Type | Behavior |
|--------|------|----------|
| Live | Toggle | Start/stop polling if `LiveFile` is configured |
| Refresh | Push | Call `refresh()` for manual one-shot reload |

### 5. View modes

| Mode | Behavior |
|------|----------|
| `'preserve'` | Keep current XLim/YLim. Data updates underneath. Default. |
| `'follow'` | Keep same window width, shift XLim to latest X. Y autoscales to visible. |
| `'reset'` | Reset XLim to full data range. Y autoscales to full data. |

Applied via private `applyViewMode()` after each `updateData()`. For linked axes, view mode propagates through existing link mechanism.

### File change detection

Timer-based polling using `dir(file).datenum`. Non-blocking, works on both MATLAB and Octave, no OS dependencies. 1-2 second interval is sufficient for the "file updated from time to time" use case.

## Changes to existing files

| File | Changes |
|------|---------|
| `FastPlot.m` | Add `updateData()`, `startLive()`, `stopLive()`, `refresh()`, `setViewMode()`, live properties, `applyViewMode()` private method |
| `FastPlotFigure.m` | Add `startLive()`, `stopLive()`, `refresh()`, `setViewMode()`, live properties |
| `FastPlotToolbar.m` | Add Live toggle button, Refresh push button |

## New files

| File | Description |
|------|-------------|
| `examples/example_live.m` | Example demonstrating live mode with a simulated updating .mat file |
| `tests/test_live.m` | Tests for updateData, startLive/stopLive, view modes |

## Not in scope

- OS filesystem event watchers (fragile, platform-specific)
- Automatic field-name-to-line mapping (callback is more flexible)
- Streaming/append mode (whole struct reloaded each time, matches file-overwrite pattern)
