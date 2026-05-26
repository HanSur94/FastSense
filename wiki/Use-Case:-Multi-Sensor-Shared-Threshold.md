<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Use the Tag‑based domain model (`SensorTag`, `MonitorTag`, `StateTag`) to monitor several sensors against a single threshold. Each sensor gets its own `MonitorTag` with the same condition function, so violations and events are tracked per‑sensor while the threshold rule is defined once.

**When to use:** You have multiple sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and you want a single threshold line (in plots) with per‑sensor violation markers and event detection, all using the v2.0 Tag architecture.

---

## Quick Example

```matlab
install;   % ensure path

%% Create sensors
nSensors = 4;
sensors  = cell(1, nSensors);
names    = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};
x        = linspace(0, 60, 500000);

for i = 1:nSensors
    s = SensorTag(sprintf('zone_%d', i), 'Name', names{i});
    % Inline data — use updateData to set X/Y
    s.updateData(x, sin(x * 2 * pi * i / 20) + 0.3 * randn(1, numel(x)) + 3);
    sensors{i} = s;
    TagRegistry.register(s.Key, s);
end

%% Define shared threshold via MonitorTag
thresholdValue = 4.5;
condition      = @(x, y) y > thresholdValue;   % shared condition

% Attach a MonitorTag to each sensor
monitors = cell(1, nSensors);
for i = 1:nSensors
    m = MonitorTag(sprintf('mon_zone_%d', i), sensors{i}, condition, ...
                   'MinDuration', 0.5);
    % Each monitor will emit events to its own EventStore (set below)
    monitors{i} = m;
    TagRegistry.register(m.Key, m);
end

%% (Plotting)  Standard MATLAB plot — one line per sensor, threshold manually added
figure;
hold on;
for i = 1:nSensors
    [xi, yi] = sensors{i}.getXY();
    plot(xi, yi, 'DisplayName', sensors{i}.Name);
end
yline(thresholdValue, 'r--', 'Shared Threshold');
xlabel('Time'); ylabel('Value'); legend;

%% Detect events per sensor using MonitorTag’s EventStore
store = EventStore();   % single EventStore for all monitors (optional)
for i = 1:nSensors
    monitors{i}.EventStore = store;   % bind to common store
    % force computation & event emission by calling getXY
    monitors{i}.getXY();
end

% Retrieve all events from the EventStore
allEvents = store.getAllEvents();   % or store.getEvents() depending on version
fprintf('Detected %d events across %d sensors.\n', numel(allEvents), nSensors);

%% Print event details
for i = 1:numel(allEvents)
    evt = allEvents(i);
    fprintf('  %s: %.1fs – %.1fs (peak %.2f)\n', ...
        evt.SensorName, evt.StartTime, evt.EndTime, evt.PeakValue);
end
```

---

## How It Works

### 1. Shared condition, per‑sensor monitoring

Instead of attaching `ThresholdRule` objects to a legacy `Sensor`, you create a `SensorTag` for each data channel and then pair it with a `MonitorTag`. The condition function is the same across all monitors, so the threshold rule is defined once:

```matlab
thresholdCondition = @(x, y) y > 4.5;
```

Each `MonitorTag` evaluates this condition against its parent sensor’s grid. Calling `getXY()` on the monitor returns a 0/1 binary series aligned to the sensor’s time vector, and also triggers the monitor’s internal event state machine.

### 2. Event detection through MonitorTag

`MonitorTag` detects alarm start and end automatically when its `EventStore` is set. You do **not** need a separate `EventDetector` – the monitor itself handles hysteresis (`AlarmOffConditionFn` if desired) and `MinDuration` debouncing. The events are attributed to the sensor name (the parent’s `Name`), so you can later filter by sensor.

If you want to centralise events, bind every monitor to the same `EventStore` as shown above. Alternatively, use separate stores and merge them later.

### 3. Plotting

The Tag library does **not** include a plotting engine (the legacy `FastSense` class is no longer used). However, you can plot sensor data with standard MATLAB graphics and manually add a shared threshold line. For a more integrated dashboard, see [[Dashboard|API Reference: Dashboard]] for the widget‑based UI that works with `SensorTag` and `MonitorTag`.

To avoid cluttering the plot, you can choose to show binary state from a monitor instead of the raw data – just `plot(monitor.getXY())`.

---

## With State‑Dependent Thresholds

When the threshold depends on a system mode (e.g., “run” vs “idle”), attach the same `StateTag` to each sensor as a parent via a `DerivedTag` or by using the state inside the monitor’s condition function.

### Example using condition that references a shared StateTag

```matlab
% Create a StateTag for system mode
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];   % 0=idle, 1=active
stMode = StateTag('system_mode', 'X', modeX, 'Y', modeY);
TagRegistry.register(stMode.Key, stMode);

% Condition checks the state value at the current time
activeThreshold = 28;
sharedCondition = @(x, y) deal(y > 30);   % base threshold, but we'll override per sensor

% For each sensor, create a MonitorTag that queries both sensor and state
for i = 1:nSensors
    % Use a closure that captures the state tag and sensor index
    thisSensor = sensors{i};   % capture for closure
    conditionFn = @(x, y) ...
        (y > 30) & (stMode.valueAt(x) == 1) | ...   % lower threshold in active mode
        (y > 33);                                    % idle threshold
    m = MonitorTag(sprintf('mon_state_%d', i), thisSensor, conditionFn, ...
                   'MinDuration', 2.0);
    m.EventStore = store;
    monitors{i} = m;
    TagRegistry.register(m.Key, m);
end

% Trigger evaluation
for i = 1:nSensors
    monitors{i}.getXY();
end
```

Each monitor evaluates independently, using the same `StateTag` for look‑up. The condition function can incorporate any logic, but the **shared rule** is expressed once inside the `conditionFn` and reused across sensors.

---

## Complete Multi‑Zone Example (Tag‑Based)

```matlab
%% Multi-zone temperature monitoring with shared alarm level
install;

nZones = 3;
zones  = {'North', 'Central', 'South'};
t      = linspace(0, 120, 50000);

% Shared system mode
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];
stMode = StateTag('system_mode', 'X', modeX, 'Y', modeY);
TagRegistry.register(stMode.Key, stMode);

% Build sensors and monitors
sensors  = cell(1, nZones);
monitors = cell(1, nZones);
store    = EventStore();

for i = 1:nZones
    % SensorTag
    s = SensorTag(sprintf('temp_zone_%d', i), 'Name', sprintf('Zone %s', zones{i}));
    baseline = 20 + i * 2;
    s.updateData(t, baseline + 5*sin(2*pi*t/40) + 2*randn(1, numel(t)));
    sensors{i} = s;
    TagRegistry.register(s.Key, s);
    
    % Condition: threshold depends on mode -> 28°C active, 30°C idle
    conditionFn = @(x, y) ...
        (y > 28 & stMode.valueAt(x) == 1) | (y > 30);
    
    m = MonitorTag(sprintf('mon_temp_%d', i), s, conditionFn, ...
                   'MinDuration', 2.0);
    m.EventStore = store;
    monitors{i} = m;
    TagRegistry.register(m.Key, m);
    
    % Force evaluation
    m.getXY();
end

% Retrieve events
allEvents = store.getAllEvents();
fprintf('\n=== Event Summary ===\n');
for i = 1:numel(allEvents)
    evt = allEvents(i);
    fprintf('%s: violation at %.1f-%.1fs (peak %.2f°C)\n', ...
        evt.SensorName, evt.StartTime, evt.EndTime, evt.PeakValue);
end
```

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Threshold rule** | Expressed once as a `MonitorTag` condition function, reused across sensors |
| **Violation tracking** | Each `MonitorTag` computes a 0/1 alarm series; events are emitted per‑sensor |
| **Event detection** | Built‑in via `MonitorTag` + `EventStore`; no separate `EventDetector` needed |
| **State‑dependent thresholds** | Supported — `MonitorTag` condition can query a shared `StateTag` or incorporate any logic |
| **Plotting** | Use standard MATLAB plotting; Tag library does not provide a plotting engine (see [[Dashboard]] for widget‑based visualisation) |

## See Also

- [[Sensors|API Reference: Sensors]] — `SensorTag`, `StateTag`, `MonitorTag`, `DerivedTag`, `CompositeTag`
- [[Event Detection|API Reference: Event Detection]] — `EventStore`, `MonitorTag` event lifecycle
- [[Dashboard|API Reference: Dashboard]] — widget‑based visualisation of Tag data
- [[Examples]] — example scripts that demonstrate the Tag‑based workflow
