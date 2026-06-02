<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Getting Started

A step-by-step tutorial introducing FastSense's core features for ultra‑fast time series plotting.

## 1. Your First Plot

```matlab
% Set up the library (only needed once per session)
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

Available presets: `'light'` (default), `'dark'`.  
Legacy names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are aliased to `'light'` for backward compatibility.  
See [[API Reference: Themes]] for full customisation options.

## 3. Thresholds and Violations

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Pressure');
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, ...
                'Color', 'r', 'Label', 'High');
fp.addThreshold(-0.8, 'Direction', 'lower', 'ShowViolations', true, ...
                'Color', 'b', 'Label', 'Low');
fp.render();
```

Red (upper) and blue (lower) circles appear automatically where data crosses the thresholds.

## 4. Multiple Lines

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, sin(x), 'DisplayName', 'Channel A');
fp.addLine(x, cos(x), 'DisplayName', 'Channel B');
fp.addLine(x, sin(2*x) * 0.5, 'DisplayName', 'Channel C');
fp.render();
```

Colors auto‑cycle from the theme’s palette. Use `resetColorIndex()` to restart the color sequence.

## 5. Visual Annotations

### Horizontal Bands (alarm zones)
```matlab
fp.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, ...
           'Label', 'High Alarm');
```

### Shaded Regions (between curves)
```matlab
fp.addShaded(x, y+0.5, y-0.5, 'FaceColor', [0.3 0.7 1], ...
             'FaceAlpha', 0.2, 'DisplayName', 'Envelope');
```

### Area Fills
```matlab
fp.addFill(x, abs(y), 'FaceColor', [0 0.5 1], 'Baseline', 0, ...
           'DisplayName', 'Energy');
```

### Event Markers
```matlab
fp.addMarker([10 30 70], [0.9 0.9 0.9], 'Marker', 'v', ...
             'MarkerSize', 10, 'Color', [1 0 0], 'Label', 'Events');
```

All annotation calls must be made **before** `render()`.

## 6. Dashboard Layout

Create a tiled grid of FastSense plots with `FastSenseGrid`:

```matlab
fig = FastSenseGrid(2, 2, 'Theme', 'dark', 'Name', 'Monitor');
fig.setTileSpan(1, [1 2]);  % top tile spans full width

fp1 = fig.tile(1);
fp1.addLine(x, sin(x)*50+50, 'DisplayName', 'Pressure');
fp1.addBand(90, 100, 'FaceColor', [1 0 0], 'FaceAlpha', 0.12, ...
            'Label', 'Alarm');
fig.setTileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(x)*20+60, 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fp3 = fig.tile(3);
fp3.addLine(x, randn(size(x)), 'DisplayName', 'Vibration');
fig.setTileTitle(3, 'Vibration');

fig.renderAll();
```

Tiles are rendered lazily; `renderAll()` ensures every tile is shown.

## 7. Toolbar

Attach an interactive toolbar to any FastSense or FastSenseGrid:

```matlab
tb = FastSenseToolbar(fig);   % or tb = FastSenseToolbar(fp);
```

Buttons: Data Cursor, Crosshair, Grid, Legend, Autoscale Y, Export PNG, Export Data, Refresh, Live Mode, Follow, Metadata, Violations.

## 8. Hover Crosshair

By default, a vertical crosshair with a multi‑line datatip appears when the mouse moves over the plot. Each visible line contributes a row showing its `DisplayName` and the interpolated Y value at the cursor X position.

To disable the hover crosshair:

```matlab
fp = FastSense('HoverCrosshair', false);
```

or set the property after construction:

```matlab
fp.HoverCrosshair = false;   % disable the automatic hover crosshair
```

## 9. Linked Axes

Synchronise zoom and pan across multiple plots using `LinkGroup`:

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

Zoom in one plot and the other follows instantly.

## 10. Datetime Axes

```matlab
% 100k datenum points covering ~1 day
x = datenum(2024,1,1) + (0:99999)/86400;
y = sin(2*pi*(1:100000)/86400);
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

`XType` can be `'numeric'` (default) or `'datenum'`. The toolbar’s data cursor automatically formats the X value accordingly.

## 11. Logarithmic Axes

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

Use `setScale('XScale', 'log')` for a logarithmic X‑axis or combine both. Call `setScale` **before** `render()` for best results.

## 12. Updating Data

After a plot has been rendered, you can replace a line’s data in place:

```matlab
newY = cos(x * 2*pi/15) + 0.4*randn(size(x));
fp.updateData(1, x, newY);
```

This re‑downsamples only the changed line and refreshes the display.

## 13. Downsampling Methods

The default `'minmax'` (min‑max) preserves signal envelopes; `'lttb'` (Largest‑Triangle‑Three‑Buckets) preserves visual shape.

Set the default globally in the constructor:

```matlab
fp = FastSense('DefaultDownsampleMethod', 'lttb');
fp.addLine(x, y, 'DisplayName', 'LTTB');
fp.render();
```

Or choose per line:

```matlab
fp.addLine(x, y1, 'DownsampleMethod', 'minmax', 'DisplayName', 'MinMax');
fp.addLine(x, y2, 'DownsampleMethod', 'lttb',  'DisplayName', 'LTTB');
```

## 14. Live Mode

Watch a `.mat` file for changes and auto‑refresh the plot:

```matlab
% Start live mode – callback is triggered whenever the file is modified
fp.startLive('data.mat', @(fp, s) fp.updateData(1, s.x, s.y), ...
             'Interval', 1);   % poll every 1 second
```

With `'ViewMode', 'follow'` the X‑axis automatically pans to the tail of the data.

## 15. Figure Distribution

After creating many plots, arrange them neatly on screen:

```matlab
FastSense.distFig();                    % auto tile all figures
FastSense.distFig('Rows', 2, 'Cols', 3); % 2‑by‑3 grid
```

## Next Steps

- [[FastPlot|API Reference: FastPlot]] — full constructor options, properties, methods
- [[Dashboard|API Reference: Dashboard]] — tiled and tabbed layouts
- [[Themes|API Reference: Themes]] — theme presets and custom styling
- [[Sensors|API Reference: Sensors]] — state‑dependent thresholds
- [[Event Detection|API Reference: Event Detection]] — event detection and viewer
- [[Live Mode Guide]] — live data polling in depth
- [[Datetime Guide]] — datetime axes and formatting
- [[Dashboard Engine Guide]] — DashboardEngine + DashboardBuilder
- [[Examples]] — 40+ runnable examples
