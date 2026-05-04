<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Getting Started

A step-by-step tutorial introducing FastSense’s core features for ultra-fast time series plotting.

## 1. Your First Plot

```matlab
% Set up the library
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));

% Create a 10 million point dataset
fp = FastSense();
x = linspace(0, 100, 1e7);  % 10 million points
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Noisy Sine');
fp.render();
```

Try zooming and panning — FastSense automatically downsamples data to screen resolution in real time, keeping the display responsive regardless of dataset size.

## 2. Themes

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.render();
```

Valid presets are `'light'` and `'dark'`. The legacy names `'default'`, `'industrial'`, `'scientific'`, and `'ocean'` are accepted but map to `'light'` for backward compatibility.  
See [[API Reference: Themes]] for customization with structs and palette names.

## 3. Thresholds and Violations

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Pressure');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r', 'Label', 'High');
fp.addThreshold(-0.8, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'b', 'Label', 'Low');
fp.render();
```

Red circles appear where data exceeds the threshold. Thresholds can also be time-varying (step‑function) by passing both `thX` and `thY` vectors.

## 4. Multiple Lines

```matlab
fp = FastSense('Theme', 'light');
fp.addLine(x, sin(x), 'DisplayName', 'Channel A');
fp.addLine(x, cos(x), 'DisplayName', 'Channel B');
fp.addLine(x, sin(2*x) * 0.5, 'DisplayName', 'Channel C');
fp.render();
```

Colors auto-cycle from the theme’s palette. Use `resetColorIndex()` to restart the color sequence.

## 5. Visual Annotations

### Horizontal Bands (alarm zones)
```matlab
fp.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'High Alarm');
```

### Shaded Regions (between curves)
```matlab
fp.addShaded(x, y+0.5, y-0.5, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.2, 'DisplayName', 'Envelope');
```

### Area Fills
```matlab
fp.addFill(x, abs(y), 'FaceColor', [0 0.5 1], 'Baseline', 0, 'DisplayName', 'Energy');
```

### Event Markers
```matlab
fp.addMarker([10 30 70], [0.9 0.9 0.9], 'Marker', 'v', 'MarkerSize', 10, 'Color', [1 0 0], 'Label', 'Events');
```

All annotation types must be added **before** calling `render()`.

## 6. Dashboard Layout

```matlab
fig = FastSenseGrid(2, 2, 'Theme', 'dark', 'Name', 'Monitor');
fig.setTileSpan(1, [1 2]);  % top tile spans full width

fp1 = fig.tile(1);
fp1.addLine(x, sin(x)*50+50, 'DisplayName', 'Pressure');
fp1.addBand(90, 100, 'FaceColor', [1 0 0], 'FaceAlpha', 0.12, 'Label', 'Alarm');
fig.setTileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(x)*20+60, 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fp3 = fig.tile(3);
fp3.addLine(x, randn(size(x)), 'DisplayName', 'Vibration');
fig.setTileTitle(3, 'Vibration');

fig.renderAll();
```

Tiles can also contain raw MATLAB axes (via `fig.axes(n)`) or custom uipanels (via `fig.tilePanel(n)`). See [[Dashboard|API Reference: Dashboard]] for advanced tile spanning and padding options.

## 7. Toolbar

```matlab
tb = FastSenseToolbar(fig);
```

The toolbar provides buttons for Data Cursor, Crosshair, Grid, Legend, Autoscale Y, Export PNG, Export Data, Refresh, Live Mode, Metadata, and Violations. Toggle each on/off; the toolbar binds automatically to the target `FastSense` or `FastSenseGrid`.

## 8. Linked Axes

```matlab
figure;
ax1 = subplot(2, 1, 1);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'sync');
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2, 1, 2);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'sync');
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fp2.render();
```

Zoom or pan in one subplot — the other follows.

## 9. Datetime Axes

```matlab
x = datenum(2024,1,1) + (0:99999)/86400;
y = sin(2*pi*(1:100000)/86400);
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

The `'XType'` option triggers automatic date formatting. For more details see [[Datetime Guide]].

## 10. Logarithmic Axes

```matlab
% Exponential growth data
n2 = 1e6;
x2 = linspace(1, 1000, n2);
y2 = exp(x2 / 200) .* (1 + 0.1 * randn(1, n2));

fp2 = FastSense();
fp2.addLine(x2, y2, 'DisplayName', 'Exponential Growth');
fp2.setScale('YScale', 'log');
fp2.render();
```

Use `setScale('XScale', 'log')` and/or `'YScale', 'log'` to toggle logarithmic scaling.

## 11. Updating Data

```matlab
% Replace line data on an already-rendered plot
newY = cos(x * 2*pi/15) + 0.4*randn(size(x));
fp.updateData(1, x, newY);
```

The change is instantly downsampled and displayed. Only numeric data can be replaced after rendering; new annotations require a fresh `FastSense` instance.

## 12. Downsampling Methods

MinMax (default) preserves signal envelope. LTTB (Largest-Triangle-Three-Buckets) preserves visual shape.

```matlab
fp = FastSense('DefaultDownsampleMethod', 'lttb');
fp.addLine(x, y, 'DisplayName', 'LTTB');
fp.render();
```

Or per-line:

```matlab
fp.addLine(x, y1, 'DownsampleMethod', 'minmax', 'DisplayName', 'MinMax');
fp.addLine(x, y2, 'DownsampleMethod', 'lttb', 'DisplayName', 'LTTB');
```

## 13. Live Mode

```matlab
% Start live mode to auto-refresh from a .mat file
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y), 'Interval', 1);
```

The callback is triggered whenever the file’s modification date changes. Use `stopLive()` to halt polling. On Octave, use `runLive()` for a blocking poll loop.

## 14. Figure Distribution

```matlab
% Auto-arrange all open figures on screen
FastSense.distFig();

% Or use specific grid dimensions
FastSense.distFig('Rows', 2, 'Cols', 3);
```

This utility is bundled from third‑party code and distributes figure windows to fill the primary monitor.

## Next Steps

- [[FastPlot|API Reference: FastPlot]] — full constructor options, properties, methods
- [[Dashboard|API Reference: Dashboard]] — tiled and tabbed layouts
- [[Themes|API Reference: Themes]] — theme presets, palettes, and overrides
- [[Sensors|API Reference: Sensors]] — state‑dependent thresholds via `addTag`
- [[Event Detection|API Reference: Event Detection]] — event detection and viewer
- [[Live Mode Guide]] — live data polling details
- [[Datetime Guide]] — datetime axis handling
- [[Dashboard Engine Guide]] — widget‑based dashboards with gauges and edit mode
- [[Examples]] — 40+ runnable examples

For installation and MEX compilation, see [[Installation]].
