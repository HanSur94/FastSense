<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Getting Started

A step-by-step tutorial introducing FastSense's core features for ultra-fast time series plotting.

## 1. Installation and Setup

```matlab
% Run the installer from the repository root
run('install.m');

% Or manually add to path if install.m isn't available
projectRoot = fileparts(which('FastSense'));
addpath(genpath(projectRoot));
```

The installer automatically compiles MEX acceleration files and sets up the MATLAB path for optimal performance.

## 2. Your First Plot

```matlab
% Create a large dataset to see the downsampling in action
x = linspace(0, 100, 1e7);  % 10 million points
y = sin(x) + 0.1 * randn(size(x));

% Create and render the plot
fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Noisy Sine Wave');
fp.render();
```

Try zooming and panning — FastSense automatically downsamples data to screen resolution in real time, keeping the display responsive regardless of dataset size.

## 3. Themes

FastSense includes built-in themes for different visual styles:

```matlab
% Dark theme for modern dashboards
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Sensor Data');
fp.render();
```

Available themes: `'light'` (default), `'dark'`. Legacy theme names (`'default'`, `'industrial'`, `'scientific'`, `'ocean'`) are aliased to `'light'` for backward compatibility.

## 4. Thresholds and Violations

Add threshold lines with automatic violation detection:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'DisplayName', 'Pressure');

% Add upper and lower thresholds with violation markers
fp.addThreshold(0.8, 'Direction', 'upper', 'ShowViolations', true, 'Color', 'r', 'Label', 'High Alarm');
fp.addThreshold(-0.8, 'Direction', 'lower', 'ShowViolations', true, 'Color', 'b', 'Label', 'Low Alarm');
fp.render();
```

Red circles automatically appear where data exceeds the thresholds.

## 5. Multiple Lines

```matlab
fp = FastSense('Theme', 'light');
fp.addLine(x, sin(x), 'DisplayName', 'Channel A');
fp.addLine(x, cos(x), 'DisplayName', 'Channel B');
fp.addLine(x, sin(2*x) * 0.5, 'DisplayName', 'Channel C');
fp.render();
```

Colors automatically cycle through the theme's palette. Use `resetColorIndex()` to restart the color sequence.

## 6. Visual Annotations

### Horizontal Bands (alarm zones)
```matlab
fp.addBand(0.8, 1.0, 'FaceColor', [1 0.3 0.3], 'FaceAlpha', 0.15, 'Label', 'High Alarm Zone');
```

### Shaded Regions (between curves)
```matlab
upper = y + 0.5;
lower = y - 0.5;
fp.addShaded(x, upper, lower, 'FaceColor', [0.3 0.7 1], 'FaceAlpha', 0.2, 'DisplayName', 'Confidence Envelope');
```

### Area Fills
```matlab
fp.addFill(x, abs(y), 'FaceColor', [0 0.5 1], 'Baseline', 0, 'DisplayName', 'Energy');
```

### Event Markers
```matlab
eventTimes = [10 30 70];
eventValues = [0.9 0.9 0.9];
fp.addMarker(eventTimes, eventValues, 'Marker', 'v', 'MarkerSize', 10, 'Color', [1 0 0], 'Label', 'Events');
```

## 7. Dashboard Layout

Create multi-tile dashboards with `FastSenseGrid`:

```matlab
fig = FastSenseGrid(2, 2, 'Theme', 'dark', 'Name', 'Control Room');
fig.setTileSpan(1, [1 2]);  % top tile spans full width

% Top tile: pressure with alarm band
fp1 = fig.tile(1);
fp1.addLine(x, sin(x)*50+50, 'DisplayName', 'Pressure');
fp1.addBand(90, 100, 'FaceColor', [1 0 0], 'FaceAlpha', 0.12, 'Label', 'Critical');
fig.setTileTitle(1, 'System Pressure (PSI)');

% Bottom left: temperature
fp2 = fig.tile(2);
fp2.addLine(x, cos(x)*20+60, 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature (°C)');

% Bottom right: vibration
fp3 = fig.tile(3);
fp3.addLine(x, randn(size(x)), 'DisplayName', 'Vibration');
fig.setTileTitle(3, 'Vibration (g)');

fig.renderAll();
```

## 8. Interactive Toolbar

Add interactive controls with `FastSenseToolbar`:

```matlab
tb = FastSenseToolbar(fig);
```

Toolbar buttons include:
- **Data Cursor** — snap to nearest data points with value display
- **Crosshair** — real-time coordinate tracking
- **Grid/Legend** — toggle visibility
- **Autoscale Y** — fit Y-axis to visible data
- **Export** — save as PNG or export raw data as CSV/MAT
- **Live Mode** — automatic file polling and refresh
- **Metadata** — enhanced tooltips with metadata fields
- **Violations** — toggle violation marker visibility

## 9. Linked Axes

Synchronize zoom and pan across multiple plots:

```matlab
fig = figure;
ax1 = subplot(2, 1, 1);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'synchronized');
fp1.addLine(x, sin(x), 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2, 1, 2);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'synchronized');
fp2.addLine(x, cos(x), 'DisplayName', 'Temperature');
fp2.render();
```

Zooming in one subplot automatically updates the other.

## 10. Datetime Axes

Display time series data with automatic datetime formatting:

```matlab
% Create datetime X-axis data
startTime = datenum(2024, 1, 1);
x_time = startTime + (0:99999)/86400;  % 100k points over ~274 days
y_daily = sin(2*pi*(1:100000)/86400);  % daily cycle

fp = FastSense('Theme', 'dark');
fp.addLine(x_time, y_daily, 'XType', 'datenum', 'DisplayName', 'Daily Pattern');
fp.render();
```

The X-axis automatically formats dates and adjusts tick spacing based on the time range.

## 11. Logarithmic Axes

Handle exponential or power-law data with logarithmic scaling:

```matlab
% Exponential growth data
x_exp = linspace(1, 1000, 1e6);
y_exp = exp(x_exp / 200) .* (1 + 0.1 * randn(1, 1e6));

fp = FastSense('YScale', 'log');
fp.addLine(x_exp, y_exp, 'DisplayName', 'Exponential Growth');
fp.render();
```

Use `'XScale', 'log'` for logarithmic X-axis or set both for log-log plots.

## 12. Updating Data

Replace line data on already-rendered plots without recreating:

```matlab
% Update with new data
newY = cos(x * 2*pi/15) + 0.4*randn(size(x));
fp.updateData(1, x, newY);  % Update line 1
```

This maintains zoom state and is much faster than re-rendering.

## 13. Downsampling Methods

FastSense offers two downsampling algorithms:

```matlab
% MinMax preserves signal envelope (default)
fp1 = FastSense('DefaultDownsampleMethod', 'minmax');
fp1.addLine(x, y, 'DisplayName', 'MinMax');

% LTTB preserves visual shape
fp2 = FastSense('DefaultDownsampleMethod', 'lttb');
fp2.addLine(x, y, 'DisplayName', 'LTTB');
```

Or set per-line:
```matlab
fp.addLine(x, y1, 'DownsampleMethod', 'minmax', 'DisplayName', 'Envelope');
fp.addLine(x, y2, 'DownsampleMethod', 'lttb', 'DisplayName', 'Shape');
```

## 14. Live Mode

Automatically refresh data from a file:

```matlab
% Create initial plot
fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Live Data');
fp.render();

% Start live monitoring
fp.startLive('sensor_data.mat', @(fp, data) fp.updateData(1, data.x, data.y), 'Interval', 1);
```

The plot automatically updates whenever `sensor_data.mat` changes.

## 15. Performance Tuning

Control when downsampling activates:

```matlab
% Only downsample series with more than 10,000 points
fp = FastSense('MinPointsForDownsample', 10000);

% Use disk storage for very large datasets
fp = FastSense('StorageMode', 'disk');
```

Storage modes:
- `'memory'` — keep all data in RAM (fastest, limited by memory)
- `'disk'` — use SQLite disk storage (handles unlimited data size)
- `'auto'` — choose based on data size (default)

## 16. Figure Distribution

Automatically arrange multiple figure windows:

```matlab
% Auto-arrange all open figures to fill the screen
FastSense.distFig();

% Or specify a grid layout
FastSense.distFig('Rows', 2, 'Cols', 3);
```

Useful for organizing multiple dashboards or comparison plots.

## Next Steps

Explore the detailed API documentation:

- [[FastPlot|API Reference: FastPlot]] — complete constructor options and methods
- [[Dashboard|API Reference: Dashboard]] — advanced dashboard layouts and tabbed interfaces  
- [[Themes|API Reference: Themes]] — custom theme creation and color palettes
- [[Live Mode Guide]] — advanced live data polling patterns
- [[Datetime Guide]] — working with time series data
- [[Examples]] — 40+ runnable examples covering all features

For widget-based dashboards with gauges and controls, see [[Dashboard Engine Guide]].
