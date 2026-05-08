<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Datetime Guide

FastSense fully supports time series with datetime X-axes.  You can pass
`datenum` values directly, or MATLAB `datetime` objects (which are
automatically converted to `datenum`).  Tick labels, crosshairs, and data
cursors all render in human-readable date/time format.

---

## Using `datenum`

Pass numeric `datenum` values as X data, explicitly setting `'XType'` to
`'datenum'`:

```matlab
% Generate datenum timestamps — 1-second resolution, ~1 day of data
x = datenum(2024, 1, 1) + (0:99999) / 86400;
y = sin(2 * pi * (1:100000) / 86400) + 0.1 * randn(1, 100000);

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

The `'XType'` parameter tells FastSense that the X values are numeric dates
and triggers human-readable formatting.

---

## Using MATLAB `datetime` (auto‑detected)

In MATLAB (not Octave), you can pass `datetime` objects directly.
They are automatically converted to `datenum` and the X‑type is set for you:

```matlab
dt = datetime(2024, 1, 1) + hours(0:9999);
y = randn(1, 10000);

fp = FastSense();
fp.addLine(dt, y, 'DisplayName', 'Sensor');
fp.render();
```

No `'XType'` flag is needed — it is inferred automatically, and an internal
`IsDatetime` flag is set to `true`.

---

## Auto‑Formatted Tick Labels

Tick labels on the X‑axis adapt dynamically to the visible zoom level:

| Visible Range       | Format          | Example       |
|---------------------|-----------------|---------------|
| > 1 day             | `mmm dd HH:MM`  | Jan 15 10:00  |
| 1 hour – 1 day      | `HH:MM`         | 10:00         |
| < 1 minute          | `HH:MM:SS`      | 10:30:15      |

As you zoom in, labels show more precision; zoom out and they show dates.

---

## Datetime with Thresholds

Thresholds work identically with datetime data:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;   % ~11.5 days
y = randn(1, 1000000) * 5 + 50;

fp = FastSense('Theme', 'industrial');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp.addThreshold(60, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true, 'Label', 'Low');
fp.render();
```

For time‑varying thresholds, pass `datenum` X vectors as the first two arguments
to [`addThreshold`](API Reference: FastPlot).

---

## Datetime with Dashboard

Combine datetime axes with `FastSenseGrid` tiles:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;

fig = FastSenseGrid(2, 1, 'Theme', 'dark');

fp1 = fig.tile(1);
fp1.addLine(x, sin(2*pi*(1:1e6)/86400)*20 + 50, ...
            'XType', 'datenum', 'DisplayName', 'Pressure');
fig.setTileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(2*pi*(1:1e6)/86400)*10 + 25, ...
            'XType', 'datenum', 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fig.renderAll();
```

---

## Datetime with Linked Axes

When multiple plots share a `LinkGroup`, zooming and panning stay synchronized,
showing consistent time ranges:

```matlab
fig = figure;

ax1 = subplot(2, 1, 1);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'time');
fp1.addLine(x, pressure, 'XType', 'datenum', 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2, 1, 2);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'time');
fp2.addLine(x, temperature, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp2.render();
```

All linked plots respond as one when you navigate any of them.

---

## Toolbar with Datetime

The `FastSenseToolbar` crosshair and data cursor display X values in a
human‑readable datetime format whenever `XType` is `'datenum'`:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum');
fp.render();

tb = FastSenseToolbar(fp);
% Clicking the crosshair shows something like:  "Jan 15, 2024 10:30:15  Y: 52.3"
```

The static method `FastSenseToolbar.formatX(xVal, xType)` provides the
formatting logic.  See the [API Reference: FastPlot](API Reference: FastPlot)
for details.

---

## `SensorDetailPlot` with Datetime

The [`SensorDetailPlot`](SensorDetailPlot) component accepts an `'XType'`
parameter to enable datetime axes:

```matlab
% Create sensor data with datenum timestamps
tStart = datetime(2024, 3, 11, 8, 0, 0);
tEnd   = datetime(2024, 3, 11, 10, 0, 0);
tNum   = datenum(linspace(tStart, tEnd, 72000));

s = Sensor('pressure', 'Name', 'Line Pressure');
s.X = tNum;
s.Y = 4.2 + 0.6*sin(2*pi*tNum*24/1.5) + 0.15*randn(1, 72000);
s.resolve();

% Create detail plot with datetime formatting
sdp = SensorDetailPlot(s, 'XType', 'datenum', 'Theme', 'light');
sdp.render();
```

Both the navigator and the main plot show human‑readable time labels.

---

## Large Dataset Example

FastSense handles massive datetime datasets efficiently using dynamic
downsampling:

```matlab
% ~579 days of temperature data at 1-second resolution
n = 50000000;
x = datenum(2024, 1, 1) + (0:n-1)/86400;  % ~579 days
t = (0:n-1) / 86400;                      % time in days
y = 20 + 5*sin(t*2*pi - pi/2) + ...       % daily cycle (peak at midday)
    0.3*sin(t*2*pi*24) + ...               % hourly ripple
    0.1*randn(1, n);                       % sensor noise

fp = FastSense('Theme', 'light');
fp.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

The pyramid cache ensures that zoom and pan remain responsive even with tens of
millions of points.

---

## GNU Octave Notes

- Octave does not support MATLAB’s `datetime` class.
- Use `datenum()` directly for timestamps and always pass `'XType', 'datenum'`.
- Tick label auto‑formatting works the same as in MATLAB.

```matlab
x = datenum(2024, 1, 1) + (0:99999) / 86400;
fp = FastSense();
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
```

---

## Tips

- All X data in a single `FastSense` instance must share the same X‑type
  (all numeric or all `datenum`).  Mixing is not supported.
- For high‑frequency data (kHz+), `datenum` precision (double‑precision days) is
  more than adequate — sub‑microsecond resolution is possible.
- Use `datenum(year, month, day, hour, minute, second)` to build timestamps.
- Use `datestr(x(1), 'yyyy-mm-dd HH:MM:SS')` to convert back for inspection.
- Tick label formatting adapts automatically to the zoom level; no manual
  intervention is required.
- The [`FastSenseToolbar`](API Reference: FastPlot) crosshair and data cursor
  display formatted datetime strings via `FastSenseToolbar.formatX`.

---

## See Also

- [API Reference: FastPlot](API Reference: FastPlot) — `addLine()` with the `XType` parameter
- [FastSenseToolbar](API Reference: FastPlot) — `formatX()` static method
- [Examples](Examples) — `example_datetime.m`, `example_sensor_detail_datetime.m`
