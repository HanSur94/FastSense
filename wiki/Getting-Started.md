# Getting Started

A step-by-step tutorial introducing FastPlot's core features.

## 1. Your First Plot

```matlab
setup;

fp = FastPlot();
x = linspace(0, 100, 1e7);  % 10 million points
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Noisy Sine');
fp.render();
```

Try zooming and panning — FastPlot re-downsamples in real time, keeping the display responsive regardless of dataset size.

## 2. Themes

```matlab
fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.render();
```

Available presets: 'default', 'dark', 'light', 'industrial', 'scientific', 'ocean'. See [[API Reference: Themes]] for customization.

## 3. Thresholds and Violations

```matlab
fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Pressure');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r', 'Label', 'High');
fp.addThreshold(-0.8, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'b', 'Label', 'Low');
fp.render();
```

Red circles appear where data exceeds the threshold.

## 4. Multiple Lines

```matlab
fp = FastPlot('Theme', 'scientific');
fp.addLine(x, sin(x), 'DisplayName', 'Channel A');
fp.addLine(x, cos(x), 'DisplayName', 'Channel B');
fp.addLine(x, sin(2*x) * 0.5, 'DisplayName', 'Channel C');
fp.render();
```

Colors auto-cycle from the theme's palette.

## 5. Visual Annotations

### Bands (horizontal alarm zones)
```matlab
fp.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'High Alarm');
```

### Shaded regions (between curves)
```matlab
fp.addShaded(x, y+0.5, y-0.5, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.2, 'DisplayName', 'Envelope');
```

### Area fills
```matlab
fp.addFill(x, abs(y), 'FaceColor', [0 0.5 1], 'Baseline', 0, 'DisplayName', 'Energy');
```

### Event markers
```matlab
fp.addMarker([10 30 70], [0.9 0.9 0.9], 'Marker', 'v', 'MarkerSize', 10, 'Color', [1 0 0], 'Label', 'Events');
```

## 6. Dashboard Layout

```matlab
fig = FastPlotFigure(2, 2, 'Theme', 'dark', 'Name', 'Monitor');
fig.setTileSpan(1, [1 2]);  % top tile spans full width

fp1 = fig.tile(1);
fp1.addLine(x, sin(x)*50+50, 'DisplayName', 'Pressure');
fp1.addBand(90, 100, 'FaceColor', [1 0 0], 'FaceAlpha', 0.12, 'Label', 'Alarm');
fig.tileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(x)*20+60, 'DisplayName', 'Temperature');
fig.tileTitle(2, 'Temperature');

fp3 = fig.tile(3);
fp3.addLine(x, randn(size(x)), 'DisplayName', 'Vibration');
fig.tileTitle(3, 'Vibration');

fig.renderAll();
```

## 7. Toolbar

```matlab
tb = FastPlotToolbar(fig);
```

Buttons: Data Cursor, Crosshair, Grid, Legend, Autoscale Y, Export PNG, Refresh, Live Mode, Metadata, Violations.

## 8. Linked Axes

```matlab
fig = figure;
ax1 = subplot(2, 1, 1);
fp1 = FastPlot('Parent', ax1, 'LinkGroup', 'sync');
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2, 1, 2);
fp2 = FastPlot('Parent', ax2, 'LinkGroup', 'sync');
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fp2.render();
```

Zoom in one subplot, the other follows.

## 9. Datetime Axes

```matlab
x = datenum(2024,1,1) + (0:99999)/86400;
y = sin(2*pi*(1:100000)/86400);
fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

## 10. Sensor System

```matlab
s = Sensor('pressure', 'Name', 'Chamber Pressure');
s.X = linspace(0, 100, 1e6);
s.Y = randn(1, 1e6) * 10 + 50;

sc = StateChannel('machine');
sc.X = [0 30 60 80]; sc.Y = [0 1 2 1];
s.addStateChannel(sc);
s.addThresholdRule(struct('machine', 1), 70, 'Direction', 'upper', 'Label', 'Run HI');
s.addThresholdRule(struct('machine', 2), 55, 'Direction', 'upper', 'Label', 'Boost HI');
s.resolve();

fp = FastPlot('Theme', 'industrial');
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
```

## 11. Event Detection

```matlab
det = EventDetector('MinDuration', 0.5);
events = detectEventsFromSensor(s, det);
printEventSummary(events);

sensorData = struct('name', 'pressure', 't', s.X, 'y', s.Y);
viewer = EventViewer(events, sensorData);
```

## 12. Downsampling Methods

MinMax (default) preserves signal envelope. LTTB preserves visual shape.

```matlab
fp = FastPlot('DefaultDownsampleMethod', 'lttb');
fp.addLine(x, y, 'DisplayName', 'LTTB');
fp.render();
```

Or per-line:
```matlab
fp.addLine(x, y1, 'DownsampleMethod', 'minmax', 'DisplayName', 'MinMax');
fp.addLine(x, y2, 'DownsampleMethod', 'lttb', 'DisplayName', 'LTTB');
```

## Next Steps

- [[API Reference: FastPlot]] — full constructor options, properties, methods
- [[API Reference: Dashboard]] — tiled and tabbed layouts
- [[API Reference: Sensors]] — state-dependent thresholds
- [[API Reference: Event Detection]] — event detection and viewer
- [[Live Mode Guide]] — live data polling
- [[Datetime Guide]] — datetime axes
- [[Dashboard Engine Guide]] — DashboardEngine + DashboardBuilder
- [[Examples]] — 40+ runnable examples
