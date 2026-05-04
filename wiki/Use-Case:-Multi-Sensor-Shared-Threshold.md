<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single tile with one shared threshold, see violation markers for all sensors, and run event detection.

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and want a single threshold line with violations and events computed for each sensor.

---

## Quick Example

```matlab
install;

%% Create sensor tags with identical monitoring rule
zones = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};
t = linspace(0, 60, 500000);
tags = cell(1, 4);

for k = 1:4
    % Create a SensorTag for each zone
    st = SensorTag(sprintf('zone_%d', k), 'Name', zones{k});
    st.X = t;
    st.Y = sin(t * 2*pi * k/20) + 0.3*randn(1, numel(t)) + 3;
    TagRegistry.register(st.Key, st);

    % Each sensor gets its own MonitorTag with the same upper bound
    mt = MonitorTag(['zone' num2str(k) '_hi'], st, @(x,y) y > 4.5);
    mt.Name = 'Max Temp';
    TagRegistry.register(mt.Key, mt);

    tags{k} = st;
end

%% Retrieve violation windows (manual runs detection)
fprintf('Violations per sensor:\n');
for k = 1:4
    mtKey = ['zone' num2str(k) '_hi'];
    mt = TagRegistry.get(mtKey);
    [mx, my] = mt.getXY();
    % Find runs where my == 1
    d = diff([0 my 0]);
    starts = find(d == 1);
    stops = find(d == -1) - 1;
    fprintf('  %s: %d violation fragments\n', zones{k}, numel(starts));
end
```

---

## How It Works

### 1. Thresholds as separate MonitorTag instances

Each `SensorTag` gets its own `MonitorTag` that applies the exact same condition (`@(x,y) y > 4.5`). Because the condition is identical, the threshold value is shared across all sensors. Each monitor independently evaluates the sensor data and produces a 0/1 signal. This is the Tag‑based equivalent of the legacy `Sensor.addThresholdRule()`.

### 2. Violation extraction via getXY

Calling `mt.getXY()` returns the binary mask aligned to the parent sensor’s timestamps. You can then locate violation segments manually:

```matlab
mt = TagRegistry.get('zone1_hi');
[x, y] = mt.getXY();
% Find rising and falling edges
edges = diff([0 y 0]);
startIdx = find(edges == 1);
endIdx   = find(edges == -1) - 1;
```

These indices map directly to the parent sensor’s `X` array.

### 3. Centralised event storage (optional)

If you attach a shared `EventStore` handle to each `MonitorTag`, the monitor will automatically record events when violation runs begin and end. Events are attributed to the monitor’s key, which you can later correlate to the parent sensor.

```matlab
% Create a single EventStore and reuse it
store = EventStore();
for k = 1:4
    st = TagRegistry.get(sprintf('zone_%d', k));
    mt = MonitorTag(sprintf('zone%d_hi_event', k), st, @(x,y) y > 4.5);
    mt.EventStore = store;   % all monitors write to the same store
end
```

---

## With State-Dependent Thresholds

The shared threshold can also be state‑dependent. Use a `StateTag` to represent the system mode and a `DerivedTag` to produce a “masked” signal that is only above threshold when the mode is active. Then monitor the derived signal.

```matlab
%% Define system mode (0=idle, 1=run)
modeX = [0, 30, 60, 90];
modeY = [0, 1, 1, 0];
modeTag = StateTag('system_mode', 'X', modeX, 'Y', modeY);
TagRegistry.register('system_mode', modeTag);

%% For each zone, create a DerivedTag that applies the state gate
for k = 1:4
    sensorTag = TagRegistry.get(sprintf('zone_%d', k));

    % derivedTag will output sensor value only when mode==1; NaN otherwise
    dt = DerivedTag(sprintf('zone%d_gated', k), {sensorTag, modeTag}, ...
        @(parents) gateByMode(parents{1}, parents{2}));
    TagRegistry.register(dt.Key, dt);

    % Monitor the gated signal for exceedances
    mt = MonitorTag(sprintf('zone%d_hi_gated', k), dt, @(x,y) y > 4.5);
    TagRegistry.register(mt.Key, mt);
end

function [X, Y] = gateByMode(sensorTag, modeTag)
    % Returns the sensor series unchanged when mode==1; NaN elsewhere
    X = sensorTag.X;
    Y = sensorTag.Y;
    modeVals = modeTag.valueAt(sensorTag.X);
    Y(modeVals ~= 1) = NaN;   % gate: no data when not in run
end
```

Now each zone only reports a threshold violation during the ‘run’ periods.

---

## Complete Multi-Zone Example

```matlab
%% Multi-zone temperature monitoring with shared alarm level
zones = {'North', 'Central', 'South'};
t = linspace(0, 120, 50000);
alarmValue = 30;

% Build sensor tags
sensorTags = cell(1, 3);
for k = 1:3
    st = SensorTag(sprintf('temp_%s', zones{k}), ...
        'Name', sprintf('Zone %s', zones{k}), ...
        'Units', '°C');
    st.X = t;
    % slightly different baselines but similar patterns
    st.Y = 20 + k*2 + 5*sin(2*pi*t/40) + 2*randn(1, numel(t));
    TagRegistry.register(st.Key, st);
    sensorTags{k} = st;

    % Attach a MonitorTag that fires above alarmValue
    mt = MonitorTag(sprintf('temp_%s_hi', zones{k}), st, ...
        @(x,y) y > alarmValue);
    mt.Name = 'Overheat Alarm';
    TagRegistry.register(mt.Key, mt);
end

%% Inspect violations manually
fprintf('\n=== Violation Log ===\n');
for k = 1:3
    mt = TagRegistry.get(sprintf('temp_%s_hi', zones{k}));
    [~, y] = mt.getXY();
    runStarts = find(diff([0; y(:); 0]) == 1);
    runEnds   = find(diff([0; y(:); 0]) == -1) - 1;
    for r = 1:numel(runStarts)
        tStart = mt.Parent.X(runStarts(r));
        tEnd   = mt.Parent.X(runEnds(r));
        peak  = max(mt.Parent.Y(runStarts(r):runEnds(r)));
        fprintf('%s: %.1fs – %.1fs  (peak %.2f°C)\n', ...
            zones{k}, tStart, tEnd, peak);
    end
end

%% To use event store instead, simply:
% store = EventStore();
% for k = 1:3
%    % re‑create monitor with EventStore
%    st = TagRegistry.get(sprintf('temp_%s', zones{k}));
%    mt = MonitorTag(sprintf('temp_%s_hi_evt', zones{k}), st, ...
%        @(x,y) y > alarmValue, 'EventStore', store);
%    TagRegistry.register(mt.Key, mt);
% end
% % Events are now accessible via store’s query methods.
```

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Shared threshold** | Create one `MonitorTag` per sensor with the exact same `ConditionFn`. |
| **Violation detection** | Inspect the monitor’s `getXY()` or rely on `EventStore` for automatic event logging. |
| **State‑dependent thresholds** | Combine a `StateTag` with a `DerivedTag` that gates the sensor signal; monitor the derived signal. |
| **Event attribution** | Events recorded by a monitor carry its key, which you can link back to the parent sensor. |
| **Plotting** | Not shown here — use your plotting library of choice. In FastPlot, pass the `SensorTag` or `MonitorTag` to the plot builder. |

---

## See Also

- [[Sensors|API Reference: Sensors]] — `SensorTag`, `MonitorTag`, `StateTag`, `DerivedTag`
- [[Event Detection|API Reference: Event Detection]] — `EventStore`, event callbacks
- [[Examples]] — detailed examples using the Tag domain model
