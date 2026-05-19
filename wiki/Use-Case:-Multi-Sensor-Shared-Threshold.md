<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

**Problem:** You have several sensors that share the same physical limit (e.g., a maximum temperature across multiple zones, or a pressure ceiling for independent channels). You want a single threshold definition, independent violation tracking per sensor, and event detection that attributes each exceedance to its originating sensor — without duplicating configuration.

---

## Quick Example

Create four `SensorTag` objects, each with its own time series, then attach a `MonitorTag` with the same condition function to each. The monitors work independently, giving you per‑sensor violation signals and extractable event segments.

```matlab
%% Setup: define a shared limit and per‑zone sensors
keys   = {'zone_A','zone_B','zone_C','zone_D'};
names  = {'Zone A','Zone B','Zone C','Zone D'};
limit  = 4.5;
sensors  = cell(1,4);
monitors = cell(1,4);

for i = 1:4
    x = linspace(0, 60, 5000);
    y = sin(x * 2 * pi * i / 20) + 0.3 * randn(1, numel(x)) + 3;

    st = SensorTag(keys{i}, 'Name', names{i}, 'X', x, 'Y', y);
    mt = MonitorTag([keys{i} '_hi'], st, @(x,y) y > limit, ...
                    'Name', [names{i} ' HI'], 'Description', 'Shared limit exceedance');

    sensors{i}  = st;
    monitors{i} = mt;
end

%% Event detection: walk each monitor’s binary series
function events = detectEvents(monitor, sensor)
    [mx, my] = monitor.getXY();
    events = struct([]);
    if isempty(mx), return; end

    inEvent = false; eventStart = NaN; peakY = NaN;
    for idx = 1:numel(mx)
        if my(idx) && ~inEvent
            inEvent = true;
            eventStart = mx(idx);
            peakY = sensor.Y(idx);
        elseif my(idx) && inEvent
            peakY = max(peakY, sensor.Y(idx));
        elseif ~my(idx) && inEvent
            inEvent = false;
            events(end+1) = struct('SensorName', sensor.Name, ...
                'StartTime', eventStart, 'EndTime', mx(idx-1), ...
                'PeakValue', peakY, 'ThresholdLabel', monitor.Name);
        end
    end
    if inEvent  % close event that runs to the end of the signal
        events(end+1) = struct('SensorName', sensor.Name, ...
            'StartTime', eventStart, 'EndTime', mx(end), ...
            'PeakValue', peakY, 'ThresholdLabel', monitor.Name);
    end
end

%% Apply to all monitors
allEvents = [];
for i = 1:numel(monitors)
    evts = detectEvents(monitors{i}, sensors{i});
    allEvents = [allEvents, evts];
end

fprintf('Detected %d events across %d sensors.\n', numel(allEvents), numel(sensors));
for e = allEvents
    fprintf('  %s: %.1fs – %.1fs (peak %.2f)\n', ...
        e.SensorName, e.StartTime, e.EndTime, e.PeakValue);
end
```

---

## How It Works

### 1. Threshold via `MonitorTag` (not a rule on the sensor itself)

Each `SensorTag` carries raw time‑series data.  A `MonitorTag` is a **derived binary tag** that evaluates a condition function on its parent’s `(X, Y)`:

```matlab
mt = MonitorTag('zone_A_hi', st, @(x,y) y > 4.5);
```

Calling `mt.getXY()` returns a `0/1` vector aligned to the parent’s time grid.  The same `ConditionFn` is used for every sensor, giving you a **single shared threshold** while keeping violation computation tied to each sensor’s data.

### 2. Independent, isolated violation tracking

Because each `MonitorTag` is bound to a different `SensorTag`, the binary series are **computed per‑sensor**; they do **not** interfere with each other.   Changing the data of one sensor invalidates only that sensor’s monitor (via the listener chain), leaving the others untouched.

### 3. Event detection directly from the binary output

`MonitorTag` provides no built‑in event grouping, but you can easily extract contiguous exceedance segments by iterating over the binary output.  The `detectEvents` helper above does this and records the peak value from the original sensor data.  This is fully self‑contained — no external `EventDetector` or `EventStore` required.

### 4. Duplicate threshold “line” is avoided by design

There is no plot‑level threshold line to worry about; the threshold lives in the `MonitorTag` condition.  When you later visualize the signals, you can add a single horizontal reference line without worrying about duplicates.

---

## With State‑Dependent Thresholds

You can make the shared threshold conditional on an external state (e.g., machine mode) by chaining a `StateTag` into the monitor’s condition.  For example, attach a `StateTag` representing the operating mode, then write a condition that only triggers during a specific state:

```matlab
% Create a state tag (mode transitions)
modeSt = StateTag('system_mode', 'X', [0 30 60 90], 'Y', [0 1 1 0]);

% Sensor
st = SensorTag('temp', 'X', t, 'Y', tempData);

% Monitor with combined condition
mt = MonitorTag('temp_alert', st, ...
    @(x,y) y > 4.5 && modeSt.valueAt(x) == 1, ...
    'Name', 'Active HI');
```

Each `MonitorTag` evaluates the same state independently — thresholds activate/deactivate synchronously across all sensors while preserving per‑sensor event attribution.

---

## Complete Multi‑Zone Example

```matlab
%% Multi‑zone monitoring with a shared alarm level
zones   = {'North', 'Central', 'South'};
keys    = {'temp_north', 'temp_central', 'temp_south'};
limit   = 30;   % °C shared upper limit
t       = linspace(0, 120, 50000);
sensors  = cell(1, 3);
monitors = cell(1, 3);

for i = 1:3
    baseline = 20 + i*2;
    y = baseline + 5*sin(2*pi*t/40) + 2*randn(1, numel(t));
    st = SensorTag(keys{i}, 'Name', zones{i}, 'X', t, 'Y', y);
    mt = MonitorTag([keys{i} '_hi'], st, @(x,y) y > limit, ...
                    'Name', [zones{i} ' HI'], 'Units', '°C');
    sensors{i}  = st;
    monitors{i} = mt;
end

%% Extract events (using the same detectEvents helper as above)
allEvents = [];
for i = 1:numel(monitors)
    evts = detectEvents(monitors{i}, sensors{i});
    allEvents = [allEvents, evts];
end

fprintf('\n=== Event Summary ===\n');
for e = allEvents
    fprintf('%s: %s violation at %.1f–%.1fs (peak %.2f°C)\n', ...
        e.SensorName, e.ThresholdLabel, e.StartTime, e.EndTime, e.PeakValue);
end
```

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Threshold definition** | A single condition function (e.g., `@(x,y) y > limit`) shared across all monitors |
| **Violation signals** | Each `MonitorTag.getXY()` returns a 0/1 vector aligned to its parent sensor |
| **Event detection** | Custom code (or a helper function) groups consecutive 1’s to extract start/end/peak |
| **State‑dependent thresholds** | Combine `StateTag.valueAt(t)` inside the `ConditionFn` — each monitor evaluates state independently |
| **Plotting** | Add a single horizontal reference line; no need to suppress duplicate threshold traces |
| **Cleanup** | Unregister tags via `TagRegistry.unregister(key)` when done |

## See Also

- [[Sensors|API Reference: Sensors]] — `SensorTag`, `MonitorTag`, `StateTag`
- [[Event Detection|API Reference: Event Detection]] — alternative `EventStore`‑based emission with `MonitorTag.EventStore`
- [[Examples]] — `example_sensor_tag_monitor`, `example_multi_zone`
