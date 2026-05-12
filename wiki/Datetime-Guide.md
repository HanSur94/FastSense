<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Datetime Guide

FastSense supports time series data with datetime X‑axes. Both `datenum` values and MATLAB `datetime` objects are accepted.

---

## Using `datenum`

Pass `datenum` values as X data and set the `'XType'` option to `'datenum'`:

```matlab
% Generate datenum time stamps (1‑second resolution, ~1 day)
x = datenum(2024, 1, 1) + (0:99999) / 86400;
y = sin(2 * pi * (1:100000) / 86400) + 0.1 * randn(1, 100000);

fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

The `'XType'` option tells FastSense to interpret the X values as serial date numbers and to format axis ticks accordingly.

---

## Using MATLAB `datetime` (auto‑detected)

On MATLAB (this feature is not available in Octave), you can pass `datetime` objects directly. They are automatically converted to `datenum` and the `XType` is set to `'datenum'` for you:

```matlab
dt = datetime(2024, 1, 1) + hours(0:9999);
y = randn(1, 10000);

fp = FastSense();
fp.addLine(dt, y, 'DisplayName', 'Sensor');
fp.render();
```

No manual `'XType'` setting is required; the conversion happens inside `addLine`.

---

## Auto‑Formatting Tick Labels

When `XType` is `'datenum'`, the tick labels automatically adapt to the visible zoom level:

| Visible Range   | Format       | Example       |
|-----------------|--------------|---------------|
| > 1 day         | `mmm dd HH:MM` | Jan 15 10:00  |
| 1 hour – 1 day  | `HH:MM`        | 10:00         |
| < 1 minute      | `HH:MM:SS`     | 10:30:15      |

As you zoom in, tick labels show progressively more precision. Zoom out and they revert to date‑level granularity.

---

## Datetime with Thresholds

Thresholds work identically regardless of the X type:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;  % ~11.5 days
y = randn(1, 1000000) * 5 + 50;

fp = FastSense('Theme', 'industrial');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp.addThreshold(60, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true, 'Label', 'Low');
fp.render();
```

Violation markers appear at the exact datenum coordinates where the line crosses the threshold.

---

## Datetime with Dashboard

A `FastSenseGrid` dashboard can seamlessly mix tiles with datetime axes:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;

fig = FastSenseGrid(2, 1, 'Theme', 'dark');

fp1 = fig.tile(1);
fp1.addLine(x, sin(2*pi*(1:1e6)/86400)*20+50, 'XType', 'datenum', ...
             'DisplayName', 'Pressure');
fig.setTileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(2*pi*(1:1e6)/86400)*10+25, 'XType', 'datenum', ...
             'DisplayName', 'Temperature');
fig.setTileTitle(2, 'Temperature');

fig.renderAll();
```

---

## Datetime with Linked Axes

Linked zoom/pan works with datetime as well — all plots in the same `LinkGroup` stay synchronised in time:

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

Zoom or pan in one subplot and the other follows the same time range.

---

## Toolbar with Datetime

The crosshair and data cursor display datetime values in human‑readable format when `XType` is `'datenum'`:

```matlab
fp = FastSense('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
tb = FastSenseToolbar(fp);
% Crosshair shows something like: "Jan 15, 2024 10:30:15   Y: 52.3"
```

The toolbar’s static method `FastSenseToolbar.formatX` (described in [[API Reference: FastPlot|FastSenseToolbar]]) is used internally to generate the formatted strings.

---

## Sensor Data with Datetime

`Sensor` objects typically carry datenum timestamps in their `X` property:

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

The `addSensor` call automatically respects the `XType` of the sensor’s X data.

---

## `SensorDetailPlot` with Datetime

The `SensorDetailPlot` component supports datetime X‑axes through its `'XType'` parameter:

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

Both the navigator strip and the main detail plot show human‑readable time labels.

---

## Large Dataset Example

FastSense handles huge datetime datasets efficiently — for example, 50 million points covering ~579 days of 1‑second temperature data:

```matlab
n = 50000000;
x = datenum(2024,1,1) + (0:n-1)/86400;  % ~579 days
t = (0:n-1) / 86400;  % time in days
y = 20 + 5*sin(t * 2*pi - pi/2) + ...  % daily cycle (peak at midday)
    0.3*sin(t * 2*pi*24) + ...            % hourly ripple
    0.1*randn(1,n);                       % sensor noise

fp = FastSense('Theme', 'light');
fp.addLine(x, y, 'DisplayName', 'Temperature', 'XType', 'datenum');
fp.addThreshold(24, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

Downsampling and multi‑level pyramid caching keep the plot responsive even at this scale.

---

## GNU Octave Notes

- Octave does **not** support MATLAB’s `datetime` class.
- Always use `datenum` to create timestamps and pass `'XType', 'datenum'` explicitly.
- Tick label formatting works the same way (automatic zoom‑adaptive labels).

---

## Tips

- All X data in a single `FastSense` instance must be of the same type (all numeric or all datenum).
- Double‑precision `datenum` values provide ample resolution even for kHz‑rate data.
- Generate datenum stamps with `datenum(year, month, day, hour, min, sec)`.
- Convert back for display using `datestr(x(1), 'yyyy-mm-dd HH:MM:SS')`.
- The toolbar’s `formatX` static method ([[API Reference: FastPlot|FastSenseToolbar]]) can be used standalone to format any datenum value.
- Datetime formatting adapts automatically to zoom level — no manual intervention is needed.

---

## See Also

- [[API Reference: FastPlot]] — `addLine` with `XType` parameter, `FastSenseToolbar.formatX`
- [[API Reference: Sensors]] — sensor X data
- [[Examples]] — `example_datetime.m`, `example_sensor_detail_datetime.m`
