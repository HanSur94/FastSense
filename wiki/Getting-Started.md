<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Getting Started

A step-by-step tutorial introducing FastSense's core features for ultra-fast time series plotting.

## 1. Setup and First Plot

Before using FastSense, add the library to your MATLAB path. From the project root, run `install.m`:

```matlab
% Set up the library
projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'install.m'));
```

Now create a 10‑million‑point dataset and render it:

```matlab
fp = FastSense();
x = linspace(0, 100, 1e7);  % 10 million points
y = sin(x) + 0.1 * randn(size(x));
fp.addLine(x, y, 'DisplayName', 'Noisy Sine');
fp.render();
```

Try zooming and panning — FastSense automatically downsamples data to screen resolution in real time, keeping the display responsive regardless of dataset size.

## 2. Themes

Choose a visual style with a theme preset:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor');
fp.render();
```

FastSense supports two main themes: `'light'` and `'dark'`. Legacy preset names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are accepted and map to `'light'`. To customise further, see [[API Reference: Themes]] for colour palettes, fonts, grid styles, and custom overrides.

## 3. Thresholds and Violations

Add constant thresholds with automatic violation markers:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Pressure');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r', 'Label', 'High');
fp.addThreshold(-0.8, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'b', 'Label', 'Low');
fp.render();
```

Red circles appear where data exceeds the upper threshold, blue circles below the lower bound. Time‑varying thresholds are also supported via separate X/Y inputs.

## 4. Multiple Lines

Plot several series on the same axes; colours auto‑cycle from the theme palette:

```matlab
fp = FastSense('Theme', 'legacy scientific');  % 'ocean' alias
fp.addLine(x, sin(x), 'DisplayName', 'Channel A');
fp.addLine(x, cos(x), 'DisplayName', 'Channel B');
fp.addLine(x, sin(2*x) * 0.5, 'DisplayName', 'Channel C');
fp.render();
```

Use `resetColorIndex()` to restart the colour sequence.

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

All layers (`addBand`, `addShaded`, `addFill`, `addMarker`) must be called **before** `render()`. After rendering, use `updateData()` to replace line data, or create a new `FastSense` instance to add more annotations.

## 6. Dashboard Layout

Combine multiple plots into a single‑window dashboard with `FastSenseGrid`:

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

See [[Dashboard|API Reference: Dashboard]] for tile spanning, custom tile themes, and mixed‑type layouts (FastSense + raw axes).

## 7. Toolbar

Attach an interactive toolbar for cursor tracking, grid/legend toggles, Y‑autoscale, PNG export, and live‑mode controls:

```matlab
tb = FastSenseToolbar(fig);
```

Main buttons: Data Cursor, Crosshair, Grid, Legend, Autoscale Y, Export PNG, Export Data, Refresh, Live Mode, Follow, Metadata, Violations. The toolbar automatically rebinds to the active tab in `FastSenseDock`.

## 8. Linked Axes

Synchronise zoom and pan across multiple subplots by assigning them to the same `LinkGroup`:

```matlab
fig = figure;
ax1 = subplot(2, 1, 1);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'sync');
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2, 1, 2);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'sync');
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fp2.render();
```

Zoom in one subplot — the other follows.

## 9. Datetime Axes

Use serial date numbers with `'datenum'` type:

```matlab
x = datenum(2024,1,1) + (0:99999)/86400;
y = sin(2*pi*(1:100000)/86400);
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

The X‑axis automatically formats tick labels as time/date. See [[Datetime Guide]] for additional options.

## 10. Logarithmic Axes

Set the scale via `setScale()`:

```matlab
n2 = 1e6;
x2 = linspace(1, 1000, n2);
y2 = exp(x2 / 200) .* (1 + 0.1 * randn(1, n2));

fp2 = FastSense();
fp2.addLine(x2, y2, 'DisplayName', 'Exponential Growth');
fp2.setScale('YScale', 'log');
fp2.render();
```

Use `'XScale'` for the X‑axis, or set both together.

## 11. Updating Data

Replace line data on an already‑rendered plot:

```matlab
newY = cos(x * 2*pi/15) + 0.4*randn(size(x));
fp.updateData(1, x, newY);
```

Optionally attach updated metadata as a struct (third argument).

## 12. Downsampling Methods

Two algorithms are available:

- **MinMax** (default) — preserves signal envelope and extremes.
- **LTTB** (Largest-Triangle-Three-Buckets) — preserves visual shape.

Set globally:

```matlab
fp = FastSense('DefaultDownsampleMethod', 'lttb');
fp.addLine(x, y, 'DisplayName', 'LTTB');
fp.render();
```

Or per‑line:

```matlab
fp.addLine(x, y1, 'DownsampleMethod', 'minmax', 'DisplayName', 'MinMax');
fp.addLine(x, y2, 'DownsampleMethod', 'lttb', 'DisplayName', 'LTTB');
```

For performance tuning, see [[API Reference: FastPlot]].

## 13. Live Mode

Poll a `.mat` file for new data and auto‑refresh the plot:

```matlab
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y), 'Interval', 1);
```

The callback is invoked whenever the file’s modification date changes. Use `'ViewMode'` to control the X‑axis behaviour (`'preserve'`, `'follow'`, or `'reset'`). Stop live mode with `fp.stopLive()`.

## 14. Figure Distribution

Arrange all open figures neatly across the screen:

```matlab
FastSense.distFig();                % auto‑arrange
FastSense.distFig('Rows', 2, 'Cols', 3);   % 2‑row, 3‑col grid
```

## Next Steps

- [[API Reference: FastPlot]] — full constructor options, properties, and methods for `FastSense`
- [[Dashboard|API Reference: Dashboard]] — `FastSenseGrid`, `FastSenseDock`, and tiled/tabbed layouts
- [[Themes|API Reference: Themes]] — customising colour, fonts, and style
- [[Sensors|API Reference: Sensors]] — state‑dependent thresholds and `SensorDetailPlot`
- [[Event Detection|API Reference: Event Detection]] — event detection, storage, and viewer
- [[Live Mode Guide]] — live data polling in depth
- [[Datetime Guide]] — datetime axes and formatting
- [[Utilities|API Reference: Utilities]] — helper functions like `binary_search`, `mex_stamp`, and more
- [[Examples]] — 40+ runnable example scripts
