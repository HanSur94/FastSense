<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single tile with one shared threshold, see violation markers for all sensors, and run event detection.

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and want a single threshold line with violations and events computed for each sensor.

---

## Quick Example

```matlab
install;

%% Create sensors with identical threshold rules
sensors = cell(1, 4);
names = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};
x = linspace(0, 60, 500000);

for i = 1:4
    s = Sensor(sprintf('zone_%d', i), 'Name', names{i});
    s.X = x;
    s.Y = sin(x * 2 * pi * i / 20) + 0.3 * randn(1, numel(x)) + 3;

    % Same threshold rule for every sensor
    s.addThresholdRule(struct(), 4.5, 'Direction', 'upper', 'Label', 'Max Temp');
    s.resolve();

    sensors{i} = s;
end

%% Plot all sensors on a single tile
fp = FastSense();
for i = 1:numel(sensors)
    % Show threshold line only for the first sensor to avoid duplicates
    fp.addSensor(sensors{i}, 'ShowThresholds', (i == 1));
end
fp.render();
title(fp.hAxes, 'Multi-Sensor — Shared Threshold');
legend(fp.hAxes, 'show');

%% Detect events for all sensors
detector = EventDetector('MinDuration', 0.5);
allEvents = [];
for i = 1:numel(sensors)
    evts = detectEventsFromSensor(sensors{i}, detector);
    if ~isempty(evts)
        allEvents = [allEvents, evts];
    end
end
fprintf('Detected %d events across %d sensors.\n', numel(allEvents), numel(sensors));
```

---

## How It Works

### 1. Threshold on the Sensor, not just the plot

Each `Sensor` gets the same `ThresholdRule`. When you call `resolve()`, each sensor independently computes:
- **ResolvedThresholds** — the threshold step-function line
- **ResolvedViolations** — the (X, Y) points that exceed the limit

This means every sensor carries its own violation data, which is required for event detection.

### 2. Avoid duplicate threshold lines

When calling `addSensor()`, pass `'ShowThresholds', true` only for the **first** sensor. All subsequent sensors use `'ShowThresholds', false`. This draws the threshold line once while still computing violations for every sensor.

Alternatively, skip `ShowThresholds` entirely and add the threshold manually:

```matlab
for i = 1:numel(sensors)
    fp.addSensor(sensors{i}, 'ShowThresholds', false);
end
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true, ...
    'Label', 'Max Temp', 'Color', 'r');
```

This approach draws a single shared threshold line and FastSense computes violation markers against **all lines** on the tile during rendering (see `updateViolations` in FastSense.m).

### 3. Event detection works per-sensor

`detectEventsFromSensor()` reads each sensor's `ResolvedViolations` and groups consecutive violation points into `Event` objects. Since each sensor resolved independently, events are attributed to the correct sensor:

```matlab
% Each event knows which sensor it came from
for i = 1:numel(allEvents)
    fprintf('  %s: %.1fs – %.1fs (peak %.2f)\n', ...
        allEvents(i).SensorName, ...
        allEvents(i).StartTime, allEvents(i).EndTime, ...
        allEvents(i).PeakValue);
end
```

---

## With State-Dependent Thresholds

The shared threshold can also be state-dependent. Attach the same `StateChannel` and conditional `ThresholdRule` to each sensor:

```matlab
for i = 1:numel(sensors)
    sc = StateChannel('mode');
    sc.X = modeX;
    sc.Y = modeValues;   % same state for all sensors
    sensors{i}.addStateChannel(sc);

    % Threshold only active during 'run' mode
    sensors{i}.addThresholdRule(struct('mode', 'run'), 4.5, ...
        'Direction', 'upper', 'Label', 'Run HI');
    sensors{i}.resolve();
end
```

Each sensor evaluates the same state conditions independently, so thresholds activate/deactivate synchronously across all sensors while maintaining individual violation tracking.

---

## Complete Multi-Zone Example

```matlab
%% Multi-zone temperature monitoring with shared alarm level
sensors = cell(1, 3);
zones = {'North', 'Central', 'South'};
t = linspace(0, 120, 50000);

% Create state channel for system mode
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];  % 0=idle, 1=active

for i = 1:3
    s = Sensor(sprintf('temp_zone_%d', i), 'Name', sprintf('Zone %s', zones{i}));
    s.X = t;
    
    % Each zone has different baseline but similar patterns
    baseline = 20 + i * 2;
    s.Y = baseline + 5*sin(2*pi*t/40) + 2*randn(1, numel(t));
    
    % Add state channel
    sc = StateChannel('system_mode');
    sc.X = modeX;
    sc.Y = modeY;
    s.addStateChannel(sc);
    
    % Shared threshold rules
    s.addThresholdRule(struct(), 30, 'Direction', 'upper', 'Label', 'Max Temp (any mode)');
    s.addThresholdRule(struct('system_mode', 1), 28, 'Direction', 'upper', 'Label', 'Max Temp (active)');
    s.resolve();
    
    sensors{i} = s;
end

%% Plot with shared thresholds
fp = FastSense();
for i = 1:numel(sensors)
    fp.addSensor(sensors{i}, 'ShowThresholds', (i == 1));
end
fp.render();
title('Multi-Zone Temperature Monitoring');
xlabel('Time (s)');
ylabel('Temperature (°C)');
legend('show');

%% Event detection
detector = EventDetector('MinDuration', 2.0);
allEvents = [];
for i = 1:numel(sensors)
    evts = detectEventsFromSensor(sensors{i}, detector);
    allEvents = [allEvents, evts];
end

fprintf('\n=== Event Summary ===\n');
for i = 1:numel(allEvents)
    fprintf('%s: %s violation at %.1f-%.1fs (peak %.2f°C)\n', ...
        allEvents(i).SensorName, allEvents(i).ThresholdLabel, ...
        allEvents(i).StartTime, allEvents(i).EndTime, allEvents(i).PeakValue);
end
```

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Threshold line** | Drawn once (first sensor or manual `addThreshold`) |
| **Violation markers** | Computed for every line on the tile |
| **Event detection** | Per-sensor via `detectEventsFromSensor()` — requires `resolve()` on each sensor |
| **State-dependent thresholds** | Supported — attach identical `StateChannel` + `ThresholdRule` to each sensor |
| **EventViewer** | Shows events from all sensors, attributed by name |

## See Also

- [[Sensors|API Reference: Sensors]] — `Sensor`, `ThresholdRule`, `StateChannel`
- [[Event Detection|API Reference: Event Detection]] — `EventDetector`, `detectEventsFromSensor`, `EventViewer`
- [[Examples]] — `example_multi_sensor_linked`, `example_sensor_threshold`, `example_sensor_multi_state`
