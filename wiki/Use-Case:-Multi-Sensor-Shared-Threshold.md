<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single axis with one shared threshold, detect violations per sensor, and optionally aggregate events with a single boolean logic.

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and want a single threshold line with violations and events computed for each sensor.

---

## Quick Example

```matlab
% Create four SensorTags with synthetic data
t = linspace(0, 60, 5000);
sensors = cell(1, 4);
regionNames = {'Zone A', 'Zone B', 'Zone C', 'Zone D'};
for i = 1:4
    st = SensorTag(sprintf('zone_%d', i), ...
        'X', t, ...
        'Y', sin(t*2*pi*i/60) + 0.3*randn(1, numel(t)) + 3);
    st.Name = regionNames{i};
    TagRegistry.register(sprintf('zone_%d', i), st);
    sensors{i} = st;
end

% Shared threshold condition
limit = 4.5;
condFn = @(x, y) y > limit;

% Create a MonitorTag for each sensor with the same condition
monitors = cell(1, 4);
for i = 1:4
    mon = MonitorTag(sprintf('mon_%d', i), sensors{i}, condFn);
    mon.Name = sprintf('%s HI', regionNames{i});
    TagRegistry.register(sprintf('mon_%d', i), mon);
    monitors{i} = mon;
end

% Aggregate all monitors with OR logic (alarm if any zone above limit)
alarm = CompositeTag('any_hi', 'or');
for i = 1:4
    alarm.addChild(monitors{i});
end

% Plot all sensors on the same axes
figure;
colors = lines(4);
for i = 1:4
    [x, y] = sensors{i}.getXY();
    plot(x, y, 'Color', colors(i,:), 'DisplayName', regionNames{i});
    hold on;
end
yline(limit, 'r--', 'LineWidth', 1.5);  % shared threshold line
legend('Location', 'best');
title('Multi‑Sensor Shared Threshold');
xlabel('Time (s)'); ylabel('Value');

% Detect events from the combined alarm
[~, alarmY] = alarm.getXY();
edges = diff([0; alarmY(:)]) > 0;               % rising edges
eventStarts = find(edges);
for i = 1:length(eventStarts)
    fprintf('Alarm raised at t=%.2f\n', t(eventStarts(i)));
end
```

---

## How It Works

### 1. Threshold logic lives in MonitorTag

In the v2.0 domain model, thresholds are expressed as `MonitorTag` objects attached to one or more parent sensors. Each `MonitorTag` stores a `ConditionFn` that receives `(x, y)` arrays and returns a logical. Calling `getXY()` on the monitor returns `[X, Y]` where `Y` is the 0/1 alarm signal aligned to the parent’s native grid. 

When you supply the same `ConditionFn` to multiple monitors, you get independent alarm signals for each sensor but identical threshold logic.

### 2. Share a threshold line in a plot

The threshold is just a constant (`y = limit`). Plot the raw sensor data with `plot()`, then add a horizontal line at `y = limit` with `yline()` (or `refline` on older releases). All sensors share that one line.

If you use the `CompositeTag` to compute a global alarm, that binary series can also be overlayed on the plot.

### 3. Event detection

`MonitorTag` supports automatic event emission when you attach an `EventStore` (the v2.0 replacement for `EventDetector`). Set `mon.EventStore = myStore` and the monitor will emit `Event` objects for rising/falling edges. Alternatively you can extract event periods manually by scanning the binary output from `getXY()`, as shown above.

`CompositeTag` works similarly — its `getXY()` yields the aggregated binary signal.

---

## With State‑Dependent Thresholds

Often the limit changes with system mode. Use a `StateTag` to hold the mode, and embed its `valueAt` lookup into the `ConditionFn` so the limit adjusts:

```matlab
% Define mode profile
modeX = [0 30 60 90];
modeY = [0 1 1 0];                           % 0=idle, 1=active
modeTag = StateTag('system_mode', 'X', modeX, 'Y', modeY);
TagRegistry.register('system_mode', modeTag);

% Condition depends on both sensor value and current mode
limitLo = 5.0;  % idle limit
limitHi = 3.5;  % active limit
condFn = @(x, y) ...
    (modeTag.valueAt(x) == 1) & (y > limitHi) | ...
    (modeTag.valueAt(x) == 0) & (y > limitLo);

% Attach to a sensor
st = SensorTag('zone1', 'X', t, 'Y', myData);
m  = MonitorTag('zone1_hi', st, condFn);
```

Because `ConditionFn` receives the full `X` array for the monitor, the `valueAt` call translates to a state look‑up for each timestamp. The resulting `MonitorTag` automatically re‑evaluates whenever the parent sensor or the state tag changes (via `invalidate` cascading from `updateData` listener notifications).

---

## Complete Multi‑Zone Example

```matlab
%% Setup
TagRegistry.clear();                          % start fresh
names = {'North', 'Central', 'South'};
t = linspace(0, 120, 50000);

% State tag for machine mode
modeTag = StateTag('mode', 'X', [0 30 60 90], 'Y', [0 1 1 0]);
TagRegistry.register('mode', modeTag);

%% Create sensors and state‑aware monitors
limit = struct('lo', 28, 'hi', 24);
condFn = @(x, y) ...
    (modeTag.valueAt(x) == 0) & (y > limit.lo) | ...
    (modeTag.valueAt(x) == 1) & (y > limit.hi);

for i = 1:3
    st = SensorTag(sprintf('zone_%d', i), ...
        'X', t, ...
        'Y', 25 + i*2 + 5*sin(t*2*pi/40) + 2*randn(1, numel(t)));
    st.Name = names{i};
    TagRegistry.register(sprintf('zone_%d', i), st);

    mon = MonitorTag(sprintf('mon_%d', i), st, condFn);
    mon.Name = [names{i} ' HI'];
    TagRegistry.register(sprintf('mon_%d', i), mon);
end

%% Global alarm composite
alarm = CompositeTag('global_alarm', 'or');
alarm.addChild(TagRegistry.get('mon_1'));
alarm.addChild(TagRegistry.get('mon_2'));
alarm.addChild(TagRegistry.get('mon_3'));

%% Plot
figure;
hold on;
colors = lines(3);
for i = 1:3
    st = TagRegistry.get(sprintf('zone_%d',i));
    [x, y] = st.getXY();
    plot(x, y, 'Color', colors(i,:), 'DisplayName', st.Name);
end
xlabel('Time (s)'); ylabel('Temperature (°C)');
title('Multi‑Zone Temperature Monitoring');
legend('show');

%% Overlay global alarm
[~, alarmY] = alarm.getXY();
stairs(t, alarmY*max(cat(1, sensors{:}.getXY()), 'LineWidth', 2, 'DisplayName', 'Global Alarm');

%% Manual events from the global alarm
edges = diff([0; alarmY(:)]) > 0;
starts = find(edges);
fprintf('Detected %d alarm periods\n', numel(starts));
```

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Threshold** | Defined as `MonitorTag` condition function; attach to each sensor. |
| **Plotting shared line** | Use a common `yline()`, not threshold-per-sensor duplicate. |
| **Event detection** | Monitors with `EventStore` or manual edge‑detection on `getXY()`. |
| **State‑dependent limits** | Embed `valueAt()` on a `StateTag` in the `ConditionFn`. |
| **Aggregated alarm** | `CompositeTag` with `'or'` mode consolidates multiple monitors. |

---

## See
