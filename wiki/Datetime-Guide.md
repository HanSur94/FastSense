<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Datetime Guide

FastSense supports time series data with datetime X‑axes. Both MATLAB `datenum` values and `datetime` objects are accepted. This guide covers how to pass datetime data, how tick labels adapt automatically, and how to use datetime with thresholds, dashboards, and linked views.

---

## Using `datenum`

Pass `datenum` values as X data and set the `'XType'` parameter to `'datenum'`:

```matlab
% 100 000 points at 1‑second resolution (~1 day)
x = datenum(2024, 1, 1) + (0:99999) / 86400;
y = sin(2 * pi * (1:100000) / 86400) + 0.1 * randn(1, 100000);

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

`FastSense` uses the `'XType'` information to format tick labels and tooltips appropriately.

---

## Using MATLAB `datetime` (auto‑detected)

In MATLAB (not Octave) you can pass `datetime` objects directly. They are automatically converted to `datenum` and the `'XType'` is set to `'datenum'` for you:

```matlab
dt = datetime(2024, 1, 1) + hours(0:9999);
y = randn(1, 10000);

fp = FastSense();
fp.addLine(dt, y, 'DisplayName', 'Sensor');
fp.render();
```

Internally, `IsDatetime` becomes `true` and all formatting behaves identically to the `datenum` path.

---

## Auto‑Formatting Tick Labels

Tick labels automatically adapt to the visible zoom level. No manual configuration is required.

| Visible Range  | Format        | Example       |
|----------------|---------------|---------------|
| > 1 day        | `mmm dd HH:MM`| Jan 15 10:00  |
| 1 hour – 1 day | `HH:MM`       | 10:00         |
| < 1 minute     | `HH:MM:SS`    | 10:30:15      |

As you zoom in, the display gains precision; as you zoom out, date components appear.

---

## Datetime with Thresholds

Thresholds work exactly the same with datetime data:

```matlab
% ~11.5 days of data at 1‑second resolution
x = datenum(2024, 1, 1) + (0:999999) / 86400;
y = randn(1, 1000000) * 5 + 50;

fp = FastSense('Theme', 'industrial');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp.addThreshold(60, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true, 'Label', 'Low');
fp.render();
```

Violation markers and threshold lines are drawn normally.

---

## Datetime with Dashboard

Dashboards built with `FastSenseGrid` also support datenum:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;

fig = FastSenseGrid(2, 1, 'Theme', 'dark');

fp1 = fig.tile(1);
fp1.addLine(x, sin(2*pi*(1:1e6)/86400)*20+50, 'XType', 'datenum', 'DisplayName', 'Pressure');
fig.setTileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(2*pi*(1:1e6)/86400)*10+25, 'XType', 'datenum', 'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fig.renderAll();
```

Each tile automatically formats its X‑axis differently if zoom levels differ.

---

## Datetime with Linked Axes

Linked zoom/pan synchronises time ranges across multiple plots. All linked plots must use `datenum` X data:

```matlab
fig = figure;
x = datenum(2024,1,1) + (0:999999)/86400;
pressure = sin(2*pi*(1:1e6)/86400)*20 + 50;
temperature = cos(2*pi*(1:1e6)/86400)*10 + 25;

ax1 = subplot(2,1,1);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'time');
fp1.addLine(x, pressure, 'XType', 'datenum', 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2,1,2);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'time');
fp2.addLine(x, temperature, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp2.render();
```

When you zoom in one plot, the other follows with the same time window.

---

## Toolbar with Datetime

The `FastSenseToolbar` data cursor and crosshair display formatted datetime strings when `XType` is `'datenum'`:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
tb = FastSenseToolbar(fp);
% A crosshair click shows: "Jan 15, 2024 10:30:15  Y: 52.3"
```

The static method `FastSenseToolbar.formatX()` performs the conversion; it is used internally by cursor and crosshair.

---

## SensorDetailPlot with Datetime

`SensorDetailPlot` (from `FastSense`) supports datetime X‑axes via the `'XType'` parameter. Any `Tag` subclass (e.g., `Sensor` from the SensorThreshold library) can be used:

```matlab
% Assume `tagObject` is a Tag with datenum timestamps.
sdp = SensorDetailPlot(tagObject, 'XType', 'datenum', 'Theme', 'light');
sdp.render();
```

Both the main plot and the navigator strip show human‑readable time labels.

---

## Large Dataset Example

FastSense efficiently handles massive datetime datasets:

```matlab
% ~579 days of temperature data at 1‑second resolution
n = 50 000 000;
x = datenum(2024,1,1) + (0:n-1)/86400;
t = (0:n-1) / 86400;
y = 20 + 5*sin(t * 2*pi - pi/2) + ...   % daily cycle
    0.3*sin(t * 2*pi*24) + ...          % hourly ripple
    0.1*randn(1, n);                    % sensor noise

fp = FastSense('Theme', 'light');
fp.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

The downsampling pyramid ensures smooth navigation even with tens of millions of points.

---

## GNU Octave Notes

- Octave does **not** support MATLAB’s `datetime` class.
- Always use `datenum()` to create timestamps and pass `'XType', 'datenum'` explicitly.
- Tick label formatting and toolbar behaviour are identical to MATLAB.

---

## Tips

- All X data within a single `FastSense` instance must be the same type (all numeric or all datenum).
- For high‑frequency data (kHz+), `datenum` double precision is sufficient.
- Use `datenum(year, month, day, hour, min, sec)` to generate timestamps.
- Use `datestr(x(1), 'yyyy-mm-dd HH:MM:SS')` to convert back when needed.
- Tick label formatting adapts automatically to the zoom level – no manual intervention required.
- The [[API Reference: FastPlot|FastSenseToolbar]] provides `formatX()` for consistent datetime display.

---

## See Also

- [[API Reference: FastPlot]] – `addLine()` with `XType` parameter
- [[Examples]] – `example_datetime.m`, `example_sensor_detail_datetime.m`
- [[Live Mode Guide]]
- [[Dashboard Engine Guide]]
