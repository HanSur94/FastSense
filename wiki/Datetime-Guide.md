<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Datetime Guide

FastSense supports time series data with datetime X-axes. Both datenum values and MATLAB datetime objects are supported. Dashboards, linked axes, and the toolbar automatically display human‑readable timestamps and adapt tick label formatting to the visible zoom level.

---

## Using datenum

Pass datenum values as X data and specify `'XType', 'datenum'`:

```matlab
% Generate datenum time stamps
x = datenum(2024, 1, 1) + (0:99999) / 86400;   % 1-second resolution, ~1 day
y = sin(2 * pi * (1:100000) / 86400) + 0.1 * randn(1, 100000);

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

---

## Using MATLAB datetime (auto‑detected)

In MATLAB (not Octave), you can pass datetime objects directly — they are automatically converted to datenum:

```matlab
dt = datetime(2024, 1, 1) + hours(0:9999);
y = randn(1, 10000);

fp = FastSense();
fp.addLine(dt, y, 'DisplayName', 'Sensor');
fp.render();
```

The `XType` is set automatically to `'datenum'` and the internal `IsDatetime` flag becomes `true`.

---

## Auto‑Formatting Tick Labels

Tick labels automatically adapt to the visible zoom level without any manual intervention:

| Visible Range   | Format         | Example        |
|-----------------|----------------|----------------|
| > 1 day         | `mmm dd HH:MM` | Jan 15 10:00   |
| 1 hour – 1 day  | `HH:MM`        | 10:00          |
| < 1 minute      | `HH:MM:SS`     | 10:30:15       |

As you zoom in, labels progressively show more precision; zooming out shows date‑level detail.

---

## Datetime with Thresholds

Thresholds work identically with datetime data — just supply the Y value:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;   % ~11.5 days
y = randn(1, 1000000) * 5 + 50;

fp = FastSense('Theme', 'industrial');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp.addThreshold(60, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true, 'Label', 'Low');
fp.render();
```

---

## Datetime with Dashboard

Use `FastSenseGrid` to arrange multiple datetime‑aware tiles:

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

---

## Datetime with Linked Axes

Linked zoom/pan across multiple plots works transparently with datetime X‑axes:

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

Both plots stay synchronised in time as you pan or zoom.

---

## Toolbar with Datetime

The `FastSenseToolbar` crosshair and data cursor display datetime values in a human‑readable format whenever `XType` is `'datenum'`:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
tb = FastSenseToolbar(fp);
% Crosshair shows: "Jan 15, 2024 10:30:15  Y: 52.3"
```

The toolbar’s static `formatX()` method provides consistent datetime formatting for all tooltips.

---

## Large Dataset Example

FastSense handles massive datetime datasets efficiently thanks to dynamic downsampling:

```matlab
% ~579 days of temperature data at 1‑second resolution
n = 50000000;
x = datenum(2024,1,1) + (0:n-1)/86400;
t = (0:n-1) / 86400;                     % time in days
y = 20 + 5*sin(t * 2*pi - pi/2) + ...   % daily cycle (peak at midday)
    0.3*sin(t * 2*pi*24) + ...           % hourly ripple
    0.1*randn(1,n);                      % sensor noise

fp = FastSense('Theme', 'light');
fp.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

---

## GNU Octave Notes

- Octave does not support MATLAB’s `datetime` class.
- Use `datenum()` directly for time stamps.
- Always pass `'XType', 'datenum'` explicitly when using datenum values.
- Tick label formatting works the same way.

---

## Tips

- All X data in a single `FastSense` must be of the same type — either all numeric or all datenum.
- For high‑frequency data (kHz+), datenum precision is sufficient (double‑precision days).
- Use `datenum()` for generating time stamps: `datenum(year, month, day, hour, min, sec)`.
- Use `datestr()` for converting back: `datestr(x(1), 'yyyy-mm-dd HH:MM:SS')`.
- Datetime formatting automatically adapts to zoom level — no manual intervention needed.
- The [[API Reference: FastPlot|FastSenseToolbar]] crosshair and data cursor show formatted datetime strings via `formatX()`.

---

## See Also

- [[API Reference: FastPlot]] — `addLine()` with `XType` parameter
- [[Examples]] — `example_datetime.m`, `example_sensor_detail_datetime.m`
