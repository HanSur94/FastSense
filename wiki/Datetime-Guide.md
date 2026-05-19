<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Datetime Guide

FastSense supports time series data with datetime X-axes. Both `datenum` values and MATLAB `datetime` objects are supported. Tick labels are automatically formatted to show the appropriate level of precision as you zoom in and out.

---

## Using datenum

Pass datenum values as X data and set `'XType', 'datenum'`:

```matlab
% Generate 1-second timestamps over ~1 day
x = datenum(2024, 1, 1) + (0:99999) / 86400;   % serial date numbers
y = sin(2 * pi * (1:100000) / 86400) + 0.1 * randn(1, 100000);

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

The `XType` property tells FastSense to treat the X data as serial date numbers and to format tick labels as human-readable dates and times.

---

## Using MATLAB datetime (auto-detected)

If you pass MATLAB `datetime` objects, they are automatically converted to `datenum` and the `XType` is set to `'datenum'` internally. The internal `IsDatetime` flag becomes `true`.

```matlab
dt = datetime(2024, 1, 1) + hours(0:9999);
y = randn(1, 10000);

fp = FastSense();
fp.addLine(dt, y, 'DisplayName', 'Sensor');
fp.render();
```

No need to specify `'XType'` — it’s inferred from the input type.

---

## Auto-Formatting Tick Labels

As you zoom in and out, the X-axis tick labels automatically change their format to match the visible time span:

| Visible Range       | Format          | Example       |
|---------------------|-----------------|---------------|
| `> 1 day`           | `mmm dd HH:MM`  | Jan 15 10:00  |
| `1 hour – 1 day`    | `HH:MM`         | 10:00         |
| `< 1 minute`        | `HH:MM:SS`      | 10:30:15      |

The formatting is handled entirely by FastSense; no manual intervention is needed. This makes it easy to explore high‑frequency sensor data without losing the date context.

---

## Datetime with Thresholds

Threshold lines (constant or time‑varying) work exactly the same way with datetime X-axes:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;   % ~11.5 days
y = randn(1, 1000000) * 5 + 50;

fp = FastSense('Theme', 'industrial');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp.addThreshold(60, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true, 'Label', 'Low');
fp.render();
```

Violation markers appear at the exact times where the data crosses the threshold.

---

## Datetime with Dashboard

Tiled dashboards (`FastSenseGrid`) support datetime axes on a per‑tile basis:

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

Each tile independently downsamples and renders its datetime data.

---

## Datetime with Linked Axes

Linked zoom/pan works seamlessly with datetime axes. Use the same `LinkGroup` name on multiple `FastSense` instances:

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

Zooming or panning in one plot synchronises the other, keeping the datetime ranges aligned.

---

## Toolbar with Datetime

The `FastSenseToolbar` ([[API Reference: Utilities]]) crosshair and data cursor display X values in human‑readable format when `XType` is `'datenum'`. The static method `FastSenseToolbar.formatX` handles this conversion:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
tb = FastSenseToolbar(fp);
% Hover crosshair shows: "Jan 15, 2024 10:30:15  Y: 52.3"
```

You can reuse the formatting in your own code:
```matlab
s = FastSenseToolbar.formatX(datenum(2024,1,15,10,30,15), 'datenum');
% s = 'Jan 15, 2024 10:30:15'
```

---

## Sensor Data with Datetime

Sensor objects (`[[API Reference: Sensors]]`) often store timestamps as `datenum` vectors. You can plot them directly:

```matlab
s = Sensor('pressure', 'Name', 'Chamber Pressure');
s.X = datenum(2024, 1, 1) + (0:999999) / 86400;
s.Y = randn(1, 1000000) * 10 + 50;

sc = StateChannel('machine');
sc.X = datenum(2024, 1, 1) + [0 3 7 10];  % Day boundaries
sc.Y = [0 1 2 1];
s.addStateChannel(sc);

s.addThresholdRule(struct('machine', 1), 70, 'Direction', 'upper', 'Label', 'Run HI');
s.resolve();

fp = FastSense('Theme', 'dark');
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
```

`addSensor` automatically sets `XType` to `'datenum'` if the sensor’s X data is in serial date format.

---

## SensorDetailPlot with Datetime

The `SensorDetailPlot` component also supports datetime X‑axes:

```matlab
% Create sensor with datenum timestamps
tStart = datetime(2024, 3, 11, 8, 0, 0);
tEnd = datetime(2024, 3, 11, 10, 0, 0);
tDatetime = linspace(tStart, tEnd, 72000);
tNum = datenum(tDatetime);

s = Sensor('pressure', 'Name', 'Line Pressure');
s.X = tNum;
s.Y = 4.2 + 0.6*sin(2*pi*tNum*24/1.5) + 0.15*randn(1, 72000);
s.resolve();

% Create detail plot with datetime formatting
sdp = SensorDetailPlot(s, 'XType', 'datenum', 'Theme', 'light');
sdp.render();
```

Both the navigator and the main detail panel show human‑readable date/time labels, and the navigator’s zoom rectangle updates accordingly.

---

## Large Dataset Example

FastSense is built for massive data. Here’s ~579 days of temperature data at 1-second resolution (50 million points):

```matlab
n = 50000000;
x = datenum(2024,1,1) + (0:n-1)/86400;        % ~579 days
t = (0:n-1) / 86400;                           % time in days
y = 20 + 5*sin(t * 2*pi - pi/2) + ...          % daily cycle (peak at midday)
    0.3*sin(t * 2*pi*24) + ...                 % hourly ripple
    0.1*randn(1,n);                             % sensor noise

fp = FastSense('Theme', 'light');
fp.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

The downsampling pyramid keeps interactions fluid, even with 50 million points.

---

## GNU Octave Notes

- Octave does **not** support MATLAB’s `datetime` class.
- Always use `datenum()` for timestamps.
- You **must** pass `'XType', 'datenum'` explicitly; auto‑detection does not apply.
- Tick label formatting works identically to MATLAB.

Example for Octave:
```matlab
x = datenum(2024, 1, 1) + (0:9999)/86400;
y = randn(1, 10000);
fp = FastSense();
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
```

---

## Tips

- All X data in a single `FastSense` must share the same `XType` (all numeric or all `'datenum'`).
- For high‑frequency data (kHz and above), `datenum`’s double‑precision representation is more than sufficient to preserve sub‑microsecond resolution.
- Generate timestamps with `datenum(year, month, day, hour, min, sec)`.
- Convert a datenum back to a readable string with `datestr(x(1), 'yyyy-mm-dd HH:MM:SS')`.
- The toolbar’s `formatX` static method ([[API Reference: Utilities]]) provides a consistent way to format any datenum value.
- Tick label formatting adapts automatically — you never need to fiddle with `XTickLabel`.

---

## See Also

- [[API Reference: FastPlot]] — `addLine()` with `XType` parameter and auto‑conversion of `datetime`
- [[API Reference: Sensors]] — Sensor X data in datenum format
- [[API Reference: Utilities]] — `FastSenseToolbar` and its `formatX()` static method
- [[Examples]] — `example_datetime.m`, `example_sensor_detail_datetime.m`
