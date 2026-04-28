<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# Use Case: Multi-Sensor Shared Threshold

Plot multiple sensors on a single tile with one shared threshold, see violation markers for all sensors, and run event detection.

**When to use:** You have several sensors that share the same physical limit (e.g., max temperature across zones, pressure across channels) and want a single threshold line with violations and events computed for each sensor.

---

## Quick Example

```matlab
% Add toolbox to path (adjust as needed)
addpath(genpath('libs'));

% Create three zone sensors with slightly different baselines
zones    = {'North', 'Central', 'South'};
t        = linspace(0, 120, 50000);
sensors  = cell(1, 3);
baseline = [22, 25, 23];  % zone baselines

for i = 1:3
    key = sprintf('zone_%s', zones{i});
    y   = baseline(i) + 6*sin(2*pi*t/40) + 2*randn(1, numel(t));
    sensors{i} = SensorTag(key, 'X', t, 'Y', y, ...
        'Name', sprintf('Zone %s', zones{i}), 'Units', '°C');
end

% Shared threshold: identical condition function for all zones
threshold_value = 30;
condFn = @(x, y) y > threshold_value;

% Create a MonitorTag for each zone
monitors = cell(1,3);
for i = 1:3
    monitors{i} = MonitorTag(['mon_', sensors{i}.Key], sensors{i}, condFn, ...
        'MinDuration', 0.5);
end

% Plot each sensor and its binary alarm on the same axis
figure;
hold on;
colors = lines(3);
legEntries = [];
for i = 1:3
    [x, y] = sensors{i}.getXY();
    plot(x, y, 'DisplayName', sensors{i}.Name, 'Color', colors(i,:));
    % Binary alarm as shaded overlay or second y-axis? We'll use a second
    % plot with offset to visualize.
    
    [~, bin] = monitors{i}.getXY();
    % Convert 0/1 to NaN/2 to show only alarm regions
    alarmY = nan(size(bin));
    alarmY(bin==1) = 40 + i;  % offset to separate visually
    plot(x, alarmY, 'o', 'MarkerSize', 2, 'Color', colors(i,:), ...
        'HandleVisibility','off');
end
yline(threshold_value, 'r--', 'Max Temp = 30 °C', 'LineWidth', 1.2);
xlabel('Time (s)'); ylabel('Temperature (°C)');
title('Multi-Zone Shared Threshold');
grid on; legend('show');

% Event detection: scan each monitor's binary series for contiguous runs
fprintf('Detected threshold violations:\n');
for i = 1:3
    [x, bin] = monitors{i}.getXY();
    inEvent = false;
    startT  = NaN;
    peakVal = -Inf;
    for k = 1:length(bin)
        if bin(k) == 1
            if ~inEvent
                inEvent = true;
                startT  = x(k);
                peakVal = sensors{i}.valueAt(x(k));
            else
                peakVal = max(peakVal, sensors{i}.valueAt(x(k)));
            end
        else
            if inEvent
                inEvent = false;
                fprintf('  %s: %.1f–%.1f s, peak %.2f°C\n', ...
                    sensors{i}.Name, startT, x(k), peakVal);
            end
        end
    end
    % Close event if still open at end
    if inEvent
        fprintf('  %s: %.1f–%.1f s (ongoing), peak %.2f°C\n', ...
            sensors{i}.Name, startT, x(end), peakVal);
    end
end
```

---

## How It Works

### 1. One Condition, Many Monitors

The threshold logic is captured in a single anonymous function (`y > 30`) that is reused identically for every `MonitorTag`. The `MonitorTag` constructor takes the parent `SensorTag` and the condition function, producing a binary 0/1 series aligned to the parent’s time grid.

```matlab
condFn = @(x, y) y > 30;
mon1 = MonitorTag('mon_North', sensorNorth, condFn);
mon2 = MonitorTag('mon_Central', sensorCentral, condFn);
```

Each `MonitorTag` lazily memorizes its output. Calling `getXY()` returns the full binary vector. Because the condition is shared, the threshold semantics are identical — only the underlying sensor data differ.

### 2. One Threshold Line, Multiple Violations

When plotting, draw the threshold line once (e.g., `yline()`). Each `MonitorTag` independently computes its own violation points. There is no need to toggle `ShowThresholds` as in the legacy system — the binary alarm data lives on the monitor. You can overlay violation markers from each monitor individually.

### 3. Event Detection from Binary Series

The binary output of each `MonitorTag` is a perfect source for event detection. In the example above, a simple state machine scans for runs of `1`s and reports start/end times and peak value. This can be enhanced by setting `MonitorTag.MinDuration` to merge short interruptions, or by binding an `EventStore` and callbacks (`OnEventStart`, `OnEventEnd`) for automatic event logging (requires the `EventDetection` package, not detailed here).

**Key point:** Because each sensor has its own `MonitorTag`, events are automatically attributed to the correct sensor.

---

## With State-Dependent Thresholds

A shared threshold that depends on operating mode can be implemented by injecting a `StateTag` into the condition function. The condition must evaluate the state at the current timepoint(s) using `StateTag.valueAt()`.

```matlab
% Create a state channel for machine mode
modeX = [0, 30, 60, 90, 120];               % transition times
modeY = {'idle', 'active', 'active', 'idle'}; % state values
stateTag = StateTag('machine_mode', 'X', modeX, 'Y', modeY);

% Build a condition that raises alarm only in 'active' mode
threshold = 28;
condFn_active = @(x, y) y > threshold & ...
    strcmp(stateTag.valueAt(x), 'active');

% Apply identical condition to all zones
for i = 1:3
    monitors{i} = MonitorTag(['mon_active_', sensors{i}.Key], ...
        sensors{i}, condFn_active, 'MinDuration', 2.0);
end
```

Because `stateTag.valueAt(x)` is vectorised, it works seamlessly with the vectorised condition function. Every monitor uses the same state tag to decide when the threshold is active, ensuring synchronised activation/deactivation.

---

## Complete Multi-Zone Example

```matlab
%% Setup
t = linspace(0, 180, 60000);
zones = {'Extruder','Die','Chiller'};
baseline = [200, 215, 180];
noiseAmp = 3;

% Create sensors
sensors = cell(1,3);
for i = 1:3
    y = baseline(i) + 10*sin(2*pi*t/50) + noiseAmp*randn(1,numel(t));
    sensors{i} = SensorTag(sprintf('temp_%s', zones{i}), ...
        'X', t, 'Y', y, 'Name', zones{i}, 'Units', '°C');
end

% Shared high-limit
hi_limit = 210;
condHi = @(x,y) y > hi_limit;

% Mode state: maintenance [0–30, 120–150], otherwise production
modeX = [0, 30, 60, 120, 150, 180];
modeY = [0,    1,   1,    0,   1,   0];  % 0=maintenance, 1=production
stateTag = StateTag('plant_mode', 'X', modeX, 'Y', modeY);

% Conditional threshold: tighter limit during production
prod_limit = 205;
condProd = @(x,y) y > prod_limit & stateTag.valueAt(x) == 1;

% Create monitors
monitorsHi  = cell(1,3);
monitorsPr  = cell(1,3);
for i = 1:3
    monitorsHi{i} = MonitorTag(['hi_',   sensors{i}.Key], sensors{i}, condHi, ...
        'MinDuration', 1.0);
    monitorsPr{i} = MonitorTag(['prod_', sensors{i}.Key], sensors{i}, condProd, ...
        'MinDuration', 0.5);
end

% Plot
figure;
subplot(2,1,1); hold on;
for i = 1:3
    plot(t, sensors{i}.Value, 'DisplayName', sensors{i}.Name);
end
yline(hi_limit, 'r--', 'High Limit');
yline(prod_limit, 'm--', 'Production Limit');
ylabel('°C'); legend('show');

subplot(2,1,2); hold on;
for i = 1:3
    [~, bin] = monitorsProd{i}.getXY();
    stairs(t, bin + (i-1)*1.2, 'DisplayName', [sensors{i}.Name,' (prod alarm)']);
end
ylim([-0.2 3.6]); xlabel('Time (s)'); ylabel('Alarm');
legend('show');

% Event detection (simple scan, production alarm only)
fprintf('Production-limit violations:\n');
for i = 1:3
    [x, bin] = monitorsProd{i}.getXY();
    inEvent = false;
    startT  = NaN;
    peakVal = -Inf;
    for k = 1:length(bin)
        if bin(k) == 1
            if ~inEvent
                inEvent = true;
                startT = x(k);
                peakVal = sensors{i}.valueAt(x(k));
            else
                peakVal = max(peakVal, sensors{i}.valueAt(x(k)));
            end
        else
            if inEvent
                fprintf('  %s: %.1f–%.1f s, peak %.1f°C\n', ...
                    sensors{i}.Name, startT, x(k), peakVal);
                inEvent = false;
            end
        end
    end
    if inEvent
        fprintf('  %s: %.1f–%.1f s (ongoing), peak %.1f°C\n', ...
            sensors{i}.Name, startT, x(end), peakVal);
    end
end
```

---

## Key Points

| Aspect | Behavior |
|--------|----------|
| **Shared condition** | Reuse the same function handle when constructing `MonitorTag` per sensor |
| **Threshold line** | Drawn once with a single `yline()` (or `plot()`) |
| **Violation markers** | Binary 0/1 series from each `MonitorTag.getXY()` — overlapped on plot |
| **Event detection** | Simple state machine scanning binary series, or use `MonitorTag` built‑in event emission when `EventStore` is bound |
| **State‑dependent thresholds** | Use a `StateTag` inside the condition function; each monitor evaluates synchronised state |

## See Also

- [[Sensors | API Reference: Sensors]] — `SensorTag`, `MonitorTag`, `StateTag`
- [[Event Detection | API Reference: Event Detection]] — `EventDetector`, `detectEventsFromSensor`, `EventViewer`
- [[Examples]] — example scripts for multi‑sensor linked, sensor threshold, and multi‑state configurations.
