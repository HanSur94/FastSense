# SensorDetailPlot — Design Spec

## Overview

A two-panel composite plot for sensor data. The upper panel shows a zoomable detail view of sensor data with thresholds and optional event shading. The lower panel is an interactive navigator showing the full data range with a highlight rectangle indicating the current zoom region.

## Architecture

Two new classes in `libs/FastPlot/`:

- **`SensorDetailPlot.m`** — Coordinator. Creates two `FastPlot` instances (main + navigator), wires bidirectional zoom synchronization, manages event rendering.
- **`NavigatorOverlay.m`** — Handles the zoom rectangle, dimming patches, and drag interaction on the navigator axes.

## Layout

```
┌──────────────────────────────────────┐
│  Main Plot (80%)            FastPlot │
│  - Sensor data line                  │
│  - Threshold lines + violations      │
│  - Event shading (optional)          │
├──────────────────────────────────────┤
│  Navigator (20%)            FastPlot │
│  - Full data range line              │
│  - Threshold bands (subtle fills)    │
│  - Event vertical lines (optional)   │
│  - Zoom rectangle + dimming          │
└──────────────────────────────────────┘
```

Height ratio is configurable via `NavigatorHeight` (default 0.20).

## Public API

### Constructor

```matlab
sdp = SensorDetailPlot(sensor)
sdp = SensorDetailPlot(sensor, Name, Value, ...)
```

**Required argument:**
- `sensor` — A resolved `Sensor` object (with `X`, `Y`, and optionally `ResolvedThresholds`).

**Name-Value options:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `Theme` | string or struct | `'default'` | FastPlot theme preset or custom struct |
| `NavigatorHeight` | double (0–1) | `0.20` | Fraction of total height for navigator |
| `ShowThresholds` | logical | `true` | Show threshold lines + violations in main plot |
| `ShowThresholdBands` | logical | `true` | Show threshold bands in navigator |
| `Events` | EventStore or Event array | `[]` | Events to display |
| `ShowEventLabels` | logical | `false` | Reserved for future use |
| `Parent` | handle | `[]` | Parent panel for embedding in FastPlotFigure |
| `Title` | string | sensor.Name | Figure/axes title |

### Methods

```matlab
sdp.render()                          % Create figure and render both panels
sdp.setZoomRange(xMin, xMax)          % Programmatically set visible range
[xMin, xMax] = sdp.getZoomRange()     % Query current visible range
```

### Properties (read-only)

```matlab
sdp.MainPlot        % FastPlot instance for the upper panel
sdp.NavigatorPlot   % FastPlot instance for the lower panel
```

`MainPlot` is exposed so users can add extra elements (markers, bands, etc.) to the detail view.

### Usage Examples

```matlab
% Standalone
s = Sensor('pressure');
s.X = t; s.Y = data;
s.addThresholdRule(ThresholdRule(struct('mode', 1), 55, 'Direction', 'upper'));
s.resolve();

sdp = SensorDetailPlot(s, 'Theme', 'dark');
sdp.render();

% With events from EventStore
store = EventStore('events.mat');
sdp = SensorDetailPlot(s, 'Events', store, 'Theme', 'industrial');
sdp.render();

% With pre-filtered Event array
events = store.query('SensorKey', 'pressure');
sdp = SensorDetailPlot(s, 'Events', events);
sdp.render();

% Inside FastPlotFigure
fig = FastPlotFigure(2, 1, 'Theme', 'dark');
sdp = SensorDetailPlot(s, 'Parent', fig.tilePanel(1), 'Events', store);
sdp.render();
fig.renderAll();
```

## Upper Plot (Main View)

### Sensor Data + Thresholds

- Uses `FastPlot.addSensor(sensor, 'ShowThresholds', true)` to render the data line, threshold lines, and violation markers.
- Inherits all existing FastPlot behavior: downsampling on zoom, pyramid caching, NaN gap handling.

### Event Shading

When `Events` is provided:

1. If input is an `EventStore`, filter events by `sensor.Key`.
2. If input is an `Event` array, use as-is.
3. For each event, render a vertical shaded region from `event.StartTime` to `event.EndTime` spanning the full Y range.
4. Color is derived from event severity:
   - `H` (high) — orange, alpha 0.12
   - `HH` (high-high) — red, alpha 0.15
   - `L` (low) — light blue, alpha 0.12
   - `LL` (low-low) — blue, alpha 0.15
   - Other/custom — theme accent color, alpha 0.10
5. Event metadata (severity, label, duration, peak value) is attached to the patch `UserData` property for access by `FastPlotToolbar` cursor/crosshair.
6. No permanent text labels on the plot.

## Lower Plot (Navigator)

### Full Data Range

- Renders the sensor data line using `FastPlot.addLine()` across the full time range.
- Navigator axes XLim is fixed to `[min(sensor.X), max(sensor.X)]` and does not change.
- Downsampling is applied once at render time (the navigator never re-downsamples since it doesn't zoom).

### Threshold Bands

When `ShowThresholdBands` is true:

- For each resolved threshold with `Direction = 'upper'`: band from threshold value to axes YMax.
- For each resolved threshold with `Direction = 'lower'`: band from axes YMin to threshold value.
- Time-varying thresholds: band follows the step-function shape using `patch()` with the threshold's X/Y vectors.
- Color: threshold's own `Color` at alpha 0.08–0.12 (subtle).
- Overlapping bands (e.g., H and HH) stack additively for stronger saturation in the most critical zones.
- Falls back to theme-based red (upper) / blue (lower) if threshold has no color set.
- No threshold lines or violation markers in the navigator.

### Event Vertical Lines

When `Events` is provided:

- Each event is rendered as a vertical line at `event.StartTime`.
- Color matches the severity color scheme (same as upper plot shading).
- Line width: 1px. No labels.

## NavigatorOverlay

### Visual Elements

All drawn on the navigator axes:

- `hRegion` — semi-transparent rectangle (e.g., theme accent, alpha 0.15) over the visible range.
- `hDimLeft` — gray overlay patch from data start to zoom start (alpha 0.4).
- `hDimRight` — gray overlay patch from zoom end to data end (alpha 0.4).
- `hEdgeLeft`, `hEdgeRight` — thin vertical lines at region boundaries for grab affordance.

### Mouse Interaction

Five states:

| State | Trigger | Behavior |
|-------|---------|----------|
| Idle | — | No drag in progress |
| Panning | Click inside rectangle | Drag moves entire region horizontally |
| ResizingLeft | Click on left edge | Drag changes zoom start |
| ResizingRight | Click on right edge | Drag changes zoom end |
| Click-to-center | Click outside rectangle | Region jumps to center on click X |

**Edge hit detection:** 5-pixel tolerance converted to data units.

**Boundary clamping:** All dragging is clamped to the navigator's full data XLim.

**Minimum width:** The region cannot be resized smaller than a minimum threshold (e.g., 0.5% of total range) to prevent zero-width zoom.

### Callback Interface

```matlab
overlay.OnRangeChanged = @(xMin, xMax) ...;   % Callback when user drags
overlay.setRange(xMin, xMax);                   % Programmatic update
```

## Bidirectional Synchronization

```
User zooms/pans in main plot
  → FastPlot XLim PostSet listener fires
    → SensorDetailPlot receives new XLim
      → Calls NavigatorOverlay.setRange(xMin, xMax)
        → Overlay updates rectangle + dim patches

User drags in navigator
  → NavigatorOverlay fires OnRangeChanged(xMin, xMax)
    → SensorDetailPlot receives callback
      → Sets MainPlot axes XLim
        → FastPlot zoom listener fires, re-downsamples visible data
```

A guard flag prevents infinite callback loops (main→navigator→main→...).

## Integration with FastPlotFigure

When `Parent` is provided:

- `SensorDetailPlot` creates its layout inside the given panel handle.
- Does not create its own figure window.
- The parent panel is subdivided into two sub-panels for main and navigator.
- Compatible with `FastPlotFigure.tilePanel(n)` to embed in dashboard tiles.

## File Locations

| File | Location |
|------|----------|
| `SensorDetailPlot.m` | `libs/FastPlot/SensorDetailPlot.m` |
| `NavigatorOverlay.m` | `libs/FastPlot/NavigatorOverlay.m` |
| `example_sensor_detail.m` | `examples/example_sensor_detail.m` |
| `test_SensorDetailPlot.m` | `tests/test_SensorDetailPlot.m` |
| `test_NavigatorOverlay.m` | `tests/test_NavigatorOverlay.m` |

## Dependencies

- `FastPlot` — rendering engine for both panels
- `Sensor`, `ThresholdRule`, `StateChannel` — sensor data model
- `EventStore`, `Event` — event data (optional)
- `FastPlotFigure` — for dashboard embedding (optional)
- `FastPlotTheme` — theme system
