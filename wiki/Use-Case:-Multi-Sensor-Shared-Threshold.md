<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single tile with one shared threshold, see violation markers for all sensors, and run event detection using the **Tag‑based domain model** (`SensorTag` + `MonitorTag`).

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and want a single threshold line with violations and events computed for each sensor independently, all using the new v2.0 API.

---

## Quick Example

```matlab
install;

%% Create 4 zones with the same upper limit of 4.5
threshold = 4.5;
zones    = {'Zone A','Zone B','Zone C','Zone D'};
x        = linspace(0, 60, 50000);
sensors  = cell(1, 4);
monitors = cell(1, 4);
eventStore = EventStore();                           % shared store for all monitors

for i = 1:numel(zones)
    % 1) SensorTag holds the raw data
    y = 3 + sin(x * 2 * pi * i / 20) + 0.3 * randn(1, numel(x));
    st = SensorTag(sprintf('zone_%d', i), ...
                   'Name', zones{i}, ...
                   'X', x, 'Y', y);

    % 2) MonitorTag watches for exceedances of the common threshold
    mt = MonitorTag(sprintf('hi_%d', i), st, ...
                    @(x, y) y > threshold, ...       % shared condition
                    'EventStore', eventStore, ...
                    'MinDuration', 0.5, ...
                    'Name', [zones{i} ' violation']);

    % Register for retrieval / plotting / events
    TagRegistry.register(st.Key, st);
    TagRegistry.register(mt.Key, mt);
    sensors{i}  = st;
    monitors{i} = mt;
end

%% Plot all sensors + a single threshold line
figure;
hold on;
colors = lines(4);
for i = 1:4
    plot(sensors{i}.X, sensors{i}.Y, 'Color', colors(i,:), ...
         'DisplayName', sensors{i}.Name);
    % Optionally overlay the monitor’s binary violation signal
    % (uncomment to see per‑sensor violation steps):
    % [mx, my] = monitors{i}.getXY();
    % plot(mx, my, '--', 'Color', colors(i,:));
end
yline(threshold, 'r--', 'Max Temp');
hold off;
title('Multi‑Zones — Shared Threshold');
xlabel('Time (s)'); ylabel('Value');
legend('show');

%% Retrieve and display events (all from the shared EventStore)
allEvents = eventStore.events;   % each event knows its SensorName
for i = 1:numel(allEvents)
    fprintf('  %s: %.1fs – %.1fs (peak %.2f)\n', ...
        allEvents(i).SensorName, ...
        allEvents(i).StartTime, allEvents(i).EndTime, ...
        allEvents(i).PeakValue);
end
```

**Output:** Each zone’s sensor data is plotted with a single threshold line. The `MonitorTag`s automatically detect threshold crossings, populate the shared `EventStore`, and the code prints a summary of all violations.

---

## How It Works

### 1. SensorTag stores the raw data
Each `SensorTag` is a direct carrier of the time‑series data (`X` and `Y`). It replaces the legacy `Sensor` class but retains the same `X`/`Y` shape (see [[Sensors|API Reference: Sensors]]).

```matlab
st = SensorTag('zone_1', 'X', 1:100, 'Y', sin(1:100)/10+40);
[x, y] = st.getXY();   % returns X, Y by reference
```

### 2. MonitorTag evaluates the shared threshold
A `MonitorTag` watches one parent `Tag` (here a `SensorTag`) and produces a binary 0/1 time series aligned to the parent’s grid. The condition function is shared — the **same function handle** is passed to each monitor.

```matlab
mt = MonitorTag('hi_zone_1', st, @(x,y) y > 4.5, ...
                'EventStore', eventStore, ...
                'MinDuration', 0.5);
[mx, my] = mt.getXY();   % 1 where condition true, 0 otherwise
```

Because each monitor resolves independently, every sensor carries its own violation vector. The optional `MinDuration` parameter suppresses brief glitches (<0.5 time units) exactly as the legacy `EventDetector` did.

### 3. Event emission is automatic and per‑sensor
When a `MonitorTag` is created with an `EventStore`, it emits `Event` objects on every rising/falling edge of the violation signal (see [[Event Detection|API Reference: Event Detection]]). The emitted event carries the parent sensor’s name (`SensorName = parent.Key`) and the violation window (`StartTime`, `EndTime`, `PeakValue`).

All monitors can write to a single shared `EventStore`, so retrieving all events is a single call:

```matlab
allEvents = eventStore.events;
```

### 4. Avoiding duplicate threshold lines on the plot
In the old API the same `ThresholdRule` was attached to each `Sensor` and the plot suppressed duplicates. With the new model the threshold is **not** a property of the sensor data — it lives in the condition function of the `MonitorTag`. Therefore, when plotting you draw the threshold line explicitly once (e.g., `yline(...)`), while all sensors are overlaid.

If you wish to visualise each monitor’s violation signal as a step curve, call `getXY()` on the monitor and plot it; but for a clean shared‑threshold look, plot only the sensors and one `yline`.

### 5. The entire pipeline is lazy and cascading
- `MonitorTag.getXY()` lazily evaluates the condition on first request.
- If the parent `SensorTag` is updated (`updateData(newX, newY)`), the monitor is automatically invalidated and recomputed on the next `getXY()` or event query.
- This observer chain ensures the threshold stays synchronised without manual `resolve()` calls.

---

## With State‑Dependent Thresholds

The shared threshold can depend on a system mode stored in a `StateTag`. Create one `StateTag`, then condition functions query it at evaluation time.

```matlab
%% State‑channel: 0 = idle, 1 = active
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];
state = StateTag('mode', 'X', modeX, 'Y', modeY);
TagRegistry.register('mode', state);

%% Two threshold levels
threshold_idle   = 5.0;
threshold_active = 4.0;

for i = 1:3
    st = SensorTag(sprintf('zone_%d', i), 'X', t, 'Y', yData(i,:));
    TagRegistry.register(st.Key, st);

    % Condition closure that reads the current state
    condFn = @(x, y) conditionalThreshold(x, y, 'mode', threshold_idle, threshold_active);
    mt = MonitorTag(sprintf('hi_zone_%d', i), st, condFn, ...
                    'EventStore', eventStore);
    TagRegistry.register(mt.Key, mt);
end

function above = conditionalThreshold(x, y, stateKey, threshIdle, threshActive)
    % Look up the instantaneous state at each x sample
    modeValues = TagRegistry.get(stateKey).valueAt(x);
    % modeValues is numeric (0 or 1) for each x
    thresh = (modeValues == 1) * threshActive + (modeValues == 0) * threshIdle;
    above = y(:) > thresh(:);
end
```

Each monitor calls `conditionalThreshold` on every parent sample, which pulls the current mode from the `StateTag` using `valueAt(x)`. The thresholds change synchronously for all sensors, but each monitor tracks violations independently.

---

## Complete Multi‑Zone Example

```matlab
%% Multi-zone temperature monitoring with shared alarm level
zones   = {'North','Central','South'};
t       = linspace(0, 120, 50000);
eventStore = EventStore();

% Mode state: idle (0) → active (1) → idle (0)
state = StateTag('sys_mode', ...
    'X', [0, 30, 60, 90], 'Y', [0, 1, 1, 0]);
TagRegistry.register('sys_mode', state);

% One shared event store for all monitors
eventStore = EventStore();

sensors = cell(1, 3);
for i = 1:3
    baseline = 20 + i * 2;
    y = baseline + 5 * sin(2 * pi * t / 40) + 2 * randn(1, numel(t));

    st = SensorTag(sprintf('temp_zone_%d', i), ...
        'Name', sprintf('Zone %s', zones{i}), ...
        'X', t, 'Y', y);
    TagRegistry.register(st.Key, st);
    sensors{i} = st;

    % Two thresholds: 30°C always, 28°C when active
    condFn = @(x, y) y > (30 - 2 * (TagRegistry.get('sys_mode').valueAt(x) == 1));
    mt = MonitorTag(sprintf('hi_zone_%d', i), st, condFn, ...
        'EventStore', eventStore, 'MinDuration', 2.0);
    TagRegistry.register(mt.Key, mt);
end

%% Plot
figure; hold on;
colors = lines(3);
for i = 1:3
    plot(sensors{i}.X, sensors{i}.Y, 'Color', colors(i,:), ...
        'DisplayName', sensors{i}.Name);
end
% Draw the two threshold levels (simplified; actual level changes per sample)
yline(30, 'r--', 'Max Temp (any mode)');
yline(28, 'm--', 'Max Temp (active)');
hold off; title('Multi‑Zone Temperature Monitoring');
xlabel('Time (s)'); ylabel('Temperature (°C)');
legend('show');

%% Event summary
events = eventStore.events;
fprintf('\n=== Event Summary ===\n');
for i = 1:numel(events)
    fprintf('%s: %s violation at %.1f–%.1f s (peak %.2f°C)\n', ...
        events(i).SensorName, events(i).ThresholdLabel, ...
        events(i).StartTime, events(i).EndTime, events(i).PeakValue);
end
```

The mode‑dependent threshold demotes the limit to 28 °C whenever `sys_mode` is active (`mode.X` = [30, 90) → value 1). All zones evaluate the same rule, but each one’s events are tagged with its own name.

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Threshold line** | Drawn once on the plot (e.g., `yline`), not by each sensor. |
| **Violation tracking** | Each `MonitorTag` computes its own 0/1 binary series. |
| **Event detection** | Automatic via `MonitorTag` + `EventStore`. No separate `detectEventsFromSensor()` needed. |
| **Shared condition** | Pass the same function handle to each monitor. |
| **State‑dependent thresholds** | `StateTag` + a condition closure that calls `valueAt(x)` to read the current state. |
| **Data updates** | Call `updateData()` on the `SensorTag`; all monitors recalc automatically. |

## See Also

- [[Sensors|API Reference: Sensors]] — `SensorTag`, `StateTag`
- [[Tag Registry|API Reference: Tags]] — `TagRegistry` (register, get, load)
- [[Event Detection|API Reference: Event Detection]] — `MonitorTag`, `EventStore`, `EventViewer`
- [[Examples]] — `example_multi_sensor_linked`, `example_sensor_threshold` (migrated to Tags)
- [[Live Mode Guide]] — streaming data with `LiveTagPipeline`
