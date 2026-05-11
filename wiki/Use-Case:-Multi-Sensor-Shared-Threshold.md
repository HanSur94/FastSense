<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single tile with one shared threshold, see violation markers for all sensors, and run event detection.

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and want a single threshold line with violations and events computed for each sensor.

---

## Quick Example

```matlab
% Ensure the FastPlot Tag-based libraries are on the path
install;

%% Create sensors with identical threshold rules
TagRegistry.clear();   % start fresh

names = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};
x = linspace(0, 60, 500000);
threshold = 4.5;

for i = 1:4
    % Each sensor has its own time series
    y = sin(x * 2 * pi * i / 20) + 0.3 * randn(1, numel(x)) + 3;
    
    % Construct a SensorTag and register it globally
    st = SensorTag(sprintf('zone_%d', i), 'Name', names{i}, 'X', x, 'Y', y);
    TagRegistry.register(st.Key, st);
    
    % Create a MonitorTag that shares the same threshold condition
    mt = MonitorTag(sprintf('zone_%d_hi', i), ...
                    TagRegistry.get(st.Key), ...
                    @(x, y) y > threshold);
    TagRegistry.register(mt.Key, mt);
end

%% Detect violation intervals from each monitor
for i = 1:4
    mt = TagRegistry.get(sprintf('zone_%d_hi', i));
    [mx, my] = mt.getXY();   % my is 0/1 binary alarm
    
    % Find rising and falling edges of violations
    d = diff([0 my 0]);
    starts = mx(d(1:end-1) == 1);
    ends   = mx(d(2:end)   == -1);
    
    fprintf('Zone %s: %d violations\n', names{i}, numel(starts));
    for j = 1:numel(starts)
        fprintf('  %.1fs – %.1fs\n', starts(j), ends(j));
    end
end
```

---

## How It Works

### 1. Threshold on the Tag, not just the plot

Each sensor is represented by a `SensorTag`. The shared threshold is expressed as a separate `MonitorTag` per sensor, all created with **exactly the same condition function**:

```matlab
mt = MonitorTag('zone_1_hi', sensorTag, @(x, y) y > 4.5);
```

When you call `mt.getXY()`, the `MonitorTag` lazy‑evaluates the condition on the parent’s native grid (`sensorTag.getXY()`) and returns a binary 0/1 vector.  
This means every sensor carries its own violation data, and no threshold line is drawn on a plot until you decide to visualise it.

### 2. Avoid duplicate threshold lines in visualisation

When you later visualise the data with `FastPlot` (or any plot engine), you can choose to draw the shared threshold only once. A common pattern is:

```matlab
fp = FastPlot();                 % not shown in the pure‑Tag example
for i = 1:numel(sensors)
    fp.addSensor(sensors{i}, 'ShowThresholds', (i == 1));
end
```

Alternatively, add the threshold manually to the plot **without** tying it to a specific sensor. The `MonitorTag` approach keeps visualisation and detection decoupled.

### 3. Event detection works per‑sensor

`MonitorTag` can automatically emit events if you attach an `EventStore` and callbacks (`OnEventStart`, `OnEventEnd`). In the quick example we manually extract violation intervals from the binary monitor output, which requires no additional infrastructure.  
For a more integrated pipeline, configure the monitor with an `EventStore`:

```matlab
mt.EventStore = someEventStore;   % provided by the Event Detection library
mt.OnEventStart = @(evt) fprintf('Violation started in %s\n', evt.SensorName);
mt.OnEventEnd   = @(evt) fprintf('Violation ended in %s\n', evt.SensorName);
```

Every monitor then fires independent events, each bearing the correct sensor name and threshold label.

---

## With State-Dependent Thresholds

The shared threshold can also be state‑dependent. Attach the same `StateTag` and conditional `MonitorTag` to each sensor:

```matlab
% Create a mode state tag (0 = idle, 1 = active)
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];
state = StateTag('mode', 'X', modeX, 'Y', modeY);
TagRegistry.register('mode', state);

for i = 1:4
    st = SensorTag(sprintf('zone_%d', i), ...);
    TagRegistry.register(st.Key, st);
    
    % MonitorTag that is only active when mode == 1
    mt = MonitorTag(sprintf('zone_%d_hi_active', i), ...
                    st, ...
                    @(x, y) y > 4.5, ...
                    'MinDuration', 2.0);   % suppress short noise
    TagRegistry.register(mt.Key, mt);
    
    % ... wire the monitor to a CompositeTag if combining with state ...
end
```

Each monitor evaluates the `ConditionFn` on its own parent data, so the same state rule applies synchronously across all sensors while preserving per‑sensor violation history.

---

## Complete Multi‑Zone Example

```matlab
%% Multi-zone temperature monitoring with shared alarm level
TagRegistry.clear();

zones = {'North', 'Central', 'South'};
t = linspace(0, 120, 50000);
threshold = 30;   % single alarm temperature for all zones

% Create sensors with different baselines
for i = 1:3
    baseline = 20 + i*2;
    y = baseline + 5*sin(2*pi*t/40) + 2*randn(1, numel(t));
    st = SensorTag(sprintf('temp_zone_%d', i), ...
                   'Name', sprintf('Zone %s', zones{i}), ...
                   'X', t, 'Y', y);
    TagRegistry.register(st.Key, st);
    
    % Shared threshold as a MonitorTag
    mt = MonitorTag(sprintf('temp_zone_%d_alarm', i), ...
                    st, ...
                    @(x, y) y > threshold, ...
                    'MinDuration', 2.0);
    TagRegistry.register(mt.Key, mt);
end

%% Extract and summarise violations
for i = 1:3
    mt = TagRegistry.get(sprintf('temp_zone_%d_alarm', i));
    [mx, my] = mt.getXY();
    
    d = diff([0 my 0]);
    starts = mx(d(1:end-1) == 1);
    ends   = mx(d(2:end)   == -1);
    
    fprintf('\n=== Zone %s (threshold %d °C) ===\n', zones{i}, threshold);
    for j = 1:numel(starts)
        % find peak temperature during the violation
        idx = (mx >= starts(j)) & (mx <= ends(j));
        [peakVal, peakIdx] = max(y(idx));
        peakTime = mx(find(idx, 1, 'first') + peakIdx - 1);
        
        fprintf('  Violation %d: %.1f–%.1f s, peak %.2f °C at %.1f s\n', ...
                j, starts(j), ends(j), peakVal, peakTime);
    end
end
```

---

## Key Points

| Aspect | Behaviour |
|--------|-----------|
| **Threshold logic** | Defined once as a condition function; reused in every `MonitorTag` constructor |
| **Violation markers** | Obtained from `MonitorTag.getXY()` — a binary 0/1 vector on the parent’s grid |
| **Event detection** | Per‑sensor via the monitor’s own edge detection, or manually from the binary output |
| **State‑dependent thresholds** | Supported — attach a `StateTag` and optionally combine with a `CompositeTag` |
| **Visualisation** | Plotting is separate; the `MonitorTag` carries the detection, not the visual |

## See Also

- [[Sensors|API Reference: Sensors]] — `SensorTag`, `MonitorTag`, `StateTag`
- [[Event Detection|API Reference: Event Detection]] — (for the `EventStore` and callback mechanism)
- [[TagRegistry]] — central catalog for all tags
- [[Getting Started]] — basic `SensorTag` / `MonitorTag` workflows
