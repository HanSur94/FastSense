<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single tile with one shared threshold, see violation markers for all sensors, and run event detection.

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and you want a single threshold line with violations and events computed for each sensor.

---

## Quick Example

```matlab
% Create four temperature sensors with synthetic data
keys = {'zoneA', 'zoneB', 'zoneC', 'zoneD'};
names = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};
x = linspace(0, 60, 50000);
threshold = 4.5;

figure; hold on; colors = lines(4);
for i = 1:4
    y = sin(x * 2 * pi * i / 20) + 0.3 * randn(1, numel(x)) + 3;

    st = SensorTag(keys{i}, 'Name', names{i});
    st.X = x;
    st.Y = y;
    TagRegistry.register(st.Key, st);

    % Create a MonitorTag that checks the shared threshold
    m = MonitorTag(['hi_' st.Key], st, @(x,y) y > threshold);
    TagRegistry.register(m.Key, m);

    % Plot sensor
    plot(x, y, 'Color', colors(i,:));
end
yline(threshold, 'r--', 'Shared Limit');
xlabel('Time (s)'); ylabel('Value');
legend(names{:}, 'Threshold', 'Location', 'best');
title('Multi-Sensor Shared Threshold');
hold off;

%% Event detection from MonitorTag binary output
for i = 1:4
    [mx, my] = MonitorTag(['hi_' keys{i}]).getXY();
    % Detect rising and falling edges
    d = diff([0, my, 0]);
    starts = mx(d(1:end-1) == 1);  % 0->1 edges
    ends   = mx(d(2:end) == -1);   % 1->0 edges

    fprintf('Zone %s: %d violations\n', char(64+i), numel(starts));
    for j = 1:numel(starts)
        idx = (x >= starts(j)) & (x <= ends(j));
        peak = max(st.Y(idx));
        fprintf('\tViolation %d: %.1f - %.1f s, peak = %.2f\n', j, starts(j), ends(j), peak);
    end
end
```

---

## How It Works

### 1. Separate Tags for Sensor Data and Threshold Logic

Each sensor is represented by a `SensorTag` that holds the raw (X, Y) time series. The threshold is encapsulated in a **`MonitorTag`** — a derived binary tag that evaluates its parent’s data against a logical condition.

- `SensorTag` holds the measurement (e.g., temperature in Zone A).
- `MonitorTag` holds the rule: *“signal > shared limit”*.
- `MonitorTag` can be reused with the same condition function for every sensor.

Wiring them together keeps data on the sensor and decision logic on the monitor.

### 2. One Shared Threshold Line on the Plot

When plotting, use MATLAB’s `yline` to draw the threshold once. Because all monitors share the same numeric limit, painting one line is sufficient.

```matlab
figure;
for i = 1:4
    plot(sensors{i}.X, sensors{i}.Y);
end
yline(threshold, 'r--', 'Shared Limit');
```

If you need more control (e.g., a single threshold but multiple violation colors per sensor) you can overlay based on the monitor’s binary output.

### 3. Event Detection Works Per‑Sensor

The `MonitorTag` produces a binary (0/1) series on the same grid as its parent `SensorTag`. Violations are simply continuous runs of 1’s. A compact way to extract events:

```matlab
[mx, my] = monitorTag.getXY();
d = diff([0, my, 0]);
startIdx = find(d == 1);
endIdx   = find(d == -1);
```

Each block from `mx(startIdx)` to `mx(endIdx)` gives an over‑limit excursion that can be associated with the sensor. Because each sensor has its own `MonitorTag`, violations are already separated by zone.

---

## With State-Dependent Thresholds

A shared threshold can also be conditioned on system state (e.g., operating mode). Using a `StateTag` and a `DerivedTag` you can incorporate state data into the threshold evaluation.

```matlab
% State channel for system mode
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];   % 0=idle, 1=active
stateTag = StateTag('mode', 'X', modeX, 'Y', modeY);
TagRegistry.register('mode', stateTag);

% Combine sensor and state into one DerivedTag
% parents = {sensor, state}  -> output [X, sensorY + state indicator]
derived = DerivedTag('zoneA_with_mode', {sensors{1}, stateTag}, @combineSensorState);
TagRegistry.register('zoneA_with_mode', derived);

% MonitorTag watches the DerivedTag and fires when both the signal is high AND the state is active
m = MonitorTag('zoneA_state_hi', derived, @(x, y) y(:, 1) > 4.5 & y(:, 2) == 1);
TagRegistry.register('zoneA_state_hi', m);
```

The `DerivedTag.resizeToParents` and interpolation details depend on the nature of your data. For many signals, constant‑hold‑interpolation of the state channel keeps the logic simple.

---

## Complete Multi‑Zone Example

```matlab
%% Multi-zone temperature monitoring with shared alarm level
keys = {'North', 'Central', 'South'};
names = {'Zone North', 'Zone Central', 'Zone South'};
t  = linspace(0, 120, 50000);
threshold = 30;

% System mode state tag (active between 30–90 s)
modeX = [0, 30, 90, 120];
modeY = [0, 1,  1, 0];
stateTag = StateTag('mode', 'X', modeX, 'Y', modeY);
TagRegistry.register('mode', stateTag);

% Create sensors and monitor tags
for i = 1:3
    baseline = 20 + i * 2;
    y = baseline + 5*sin(2*pi*t/40) + 2*randn(1, numel(t));

    st = SensorTag(keys{i}, 'Name', names{i});
    st.X = t;
    st.Y = y;
    TagRegistry.register(st.Key, st);

    % Simple shared threshold (no state gating)
    MonitorTag(['hi_' st.Key], st, @(x,y) y > threshold);
    TagRegistry.register(['hi_' st.Key], m);

    % State-dependent threshold (requires a DerivedTag)
    % (code omitted for brevity – see “With State‑Dependent Thresholds”)
end

%% Plot all sensors
figure; hold on;
for i = 1:3
    plot(t, SensorTag(keys{i}).Y);
end
yline(threshold, 'r--', 'Shared Limit');
title('Multi-Zone Temperature Monitoring');
xlabel('Time (s)'); ylabel('Temperature (°C)');
legend(names{:}, 'Location', 'best');
hold off;

%% Detecting events from the simple shared threshold
fprintf('=== Event Summary ===\n');
for i = 1:3
    mon = MonitorTag(['hi_' keys{i}]);
    [mx, my] = mon.getXY();
    d = diff([0, my, 0]);
    starts = mx(d(1:end-1) == 1);
    ends   = mx(d(2:end) == -1);

    for j = 1:numel(starts)
        fprintf('%s: exceeded %.1f at %.1f – %.1f s\n', ...
                names{i}, threshold, starts(j), ends(j));
    end
end
```

The same technique extends to pressure channels, any other physical quantity, or even composite signals.

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Threshold line** | Drawn once via `yline`. |
| **Violation detection** | Each `MonitorTag` computes independently, one per sensor. |
| **Event detection** | Groups of consecutive 1’s in `MonitorTag.getXY()` give start/end times. |
| **State-dependent thresholds** | Combine sensor + state via `DerivedTag` and monitor the derived signal. |
| **Legend / labels** | Use standard MATLAB graphics annotations. |

## See Also

- [[Sensors|API Reference: Sensors]] — `SensorTag`, `StateTag`, `DerivedTag`, `MonitorTag`, `TagRegistry`
- [[Event Detection|API Reference: Event Detection]] — `EventDetector` (legacy), direct binary‑vector detection
- [[Examples]] — more examples for multi‑sensor setups and thresholding
```
