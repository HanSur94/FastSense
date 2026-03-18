# Datetime Guide

FastPlot supports time series data with datetime X-axes. Both datenum values and MATLAB datetime objects are supported.

---

## Using datenum

Pass datenum values as X data with `'XType', 'datenum'`:

```matlab
% Generate datenum time stamps
x = datenum(2024, 1, 1) + (0:99999) / 86400;  % 1-second resolution, ~1 day
y = sin(2 * pi * (1:100000) / 86400) + 0.1 * randn(1, 100000);

fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Daily Cycle');
fp.render();
```

---

## Using MATLAB datetime (auto-detected)

In MATLAB (not Octave), you can pass datetime objects directly — they are auto-converted to datenum:

```matlab
dt = datetime(2024, 1, 1) + hours(0:9999);
y = randn(1, 10000);

fp = FastPlot();
fp.addLine(dt, y, 'DisplayName', 'Sensor');
fp.render();
```

The `XType` is set automatically to 'datenum' and `IsDatetime` becomes true.

---

## Auto-Formatting Tick Labels

Tick labels automatically adapt to the visible zoom level:

| Visible Range | Format | Example |
|--------------|--------|---------|
| > 1 day | `mmm dd HH:MM` | Jan 15 10:00 |
| 1 hour – 1 day | `HH:MM` | 10:00 |
| < 1 minute | `HH:MM:SS` | 10:30:15 |

As you zoom in, tick labels progressively show more precision. Zoom out and they show dates.

---

## Datetime with Thresholds

Thresholds work the same way with datetime data:

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;  % ~11.5 days
y = randn(1, 1000000) * 5 + 50;

fp = FastPlot('Theme', 'industrial');
fp.addLine(x, y, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp.addThreshold(60, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'High');
fp.addThreshold(40, 'Direction', 'lower', 'ShowViolations', true, 'Label', 'Low');
fp.render();
```

---

## Datetime with Dashboard

```matlab
x = datenum(2024, 1, 1) + (0:999999) / 86400;

fig = FastPlotFigure(2, 1, 'Theme', 'dark');

fp1 = fig.tile(1);
fp1.addLine(x, sin(2*pi*(1:1e6)/86400)*20+50, 'XType', 'datenum', 'DisplayName', 'Pressure');
fig.tileTitle(1, 'Pressure');

fp2 = fig.tile(2);
fp2.addLine(x, cos(2*pi*(1:1e6)/86400)*10+25, 'XType', 'datenum', 'DisplayName', 'Temperature');
fig.tileTitle(2, 'Temperature');

fig.renderAll();
```

---

## Datetime with Linked Axes

Linked axes work with datetime — synchronized zoom/pan shows consistent time ranges:

```matlab
fig = figure;

ax1 = subplot(2, 1, 1);
fp1 = FastPlot('Parent', ax1, 'LinkGroup', 'time');
fp1.addLine(x, pressure, 'XType', 'datenum', 'DisplayName', 'Pressure');
fp1.render();

ax2 = subplot(2, 1, 2);
fp2 = FastPlot('Parent', ax2, 'LinkGroup', 'time');
fp2.addLine(x, temperature, 'XType', 'datenum', 'DisplayName', 'Temperature');
fp2.render();
```

---

## Toolbar with Datetime

The crosshair and data cursor display datetime values in human-readable format when XType is 'datenum':

```matlab
fp = FastPlot('Theme', 'dark');
fp.addLine(x, y, 'XType', 'datenum');
fp.render();
tb = FastPlotToolbar(fp);
% Crosshair shows: "Jan 15, 2024 10:30:15  Y: 52.3"
```

---

## Sensor Data with Datetime

Sensor X data is typically in datenum format:

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

fp = FastPlot('Theme', 'dark');
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
```

---

## GNU Octave Notes

- Octave does not support MATLAB's `datetime` class
- Use `datenum()` directly for time stamps
- Always pass `'XType', 'datenum'` explicitly
- Tick label formatting works the same way

---

## Tips

- All X data in a single FastPlot must be the same type (all numeric or all datenum)
- For high-frequency data (kHz+), datenum precision is sufficient (double-precision days)
- Use `datenum()` for generating time stamps: `datenum(year, month, day, hour, min, sec)`
- Use `datestr()` for converting back: `datestr(x(1), 'yyyy-mm-dd HH:MM:SS')`

---

## See Also

- [[API Reference: FastPlot]] — addLine() with XType parameter
- [[API Reference: Sensors]] — Sensor X data
- [[Examples]] — example_datetime.m
