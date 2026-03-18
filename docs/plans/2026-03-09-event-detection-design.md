# Event Detection Library Design

## Overview

Third library (`libs/EventDetection/`) for FastSense — detects events from threshold violations, groups consecutive violations into events with statistics, and supports configurable callbacks, debounce, UI viewer, console output, and live detection.

## Structure

```
libs/EventDetection/
├── Event.m                    % Value class — event metadata + stats
├── EventConfig.m              % Configuration — detector, viewer, sensor mappings
├── EventDetector.m            % Core detector — debounce, callbacks
├── EventViewer.m              % Figure UI — Gantt timeline + table + click-to-plot
├── detectEventsFromSensor.m   % Convenience wrapper for Sensor objects
├── printEventSummary.m        % Console: formatted summary table
├── eventLogger.m              % Console: live logging callback factory
└── private/
    └── groupViolations.m      % Core algorithm: consecutive violations → events
```

## Event (value class)

Read-only properties:

| Property | Description |
|---|---|
| `StartTime` | First violation timestamp |
| `EndTime` | Last violation timestamp |
| `Duration` | `EndTime - StartTime` |
| `SensorName` | Sensor/channel name (string) |
| `ThresholdLabel` | e.g. "warning high", "critical low" |
| `ThresholdValue` | The threshold that was violated |
| `Direction` | `"high"` or `"low"` (above or below threshold) |
| `PeakValue` | Worst violation value (furthest from threshold) |
| `NumPoints` | Number of data points in the event time window |
| `MinValue` | Minimum signal value during event |
| `MaxValue` | Maximum signal value during event |
| `MeanValue` | Mean signal value during event |
| `RmsValue` | Root mean square of signal during event |
| `StdValue` | Standard deviation of signal during event |

Statistics (`MinValue`, `MaxValue`, `MeanValue`, `RmsValue`, `StdValue`) are computed over **all data points** within the event time window, not just violation points.

`PeakValue` = `MaxValue` for high violations, `MinValue` for low violations.

## EventDetector (main class)

### Properties

| Property | Default | Description |
|---|---|---|
| `MinDuration` | `0` | Debounce filter — events shorter than this are discarded |
| `OnEventStart` | `[]` | Function handle callback `f(event)`, called when a new event is detected |
| `MaxCallsPerEvent` | `1` | Max times `OnEventStart` fires for the same ongoing event |

### Methods

- `events = detect(obj, t, values, thresholdValue, direction, thresholdLabel, sensorName)` — returns `Event` array
  - Calls `groupViolations` to cluster consecutive violation points
  - Computes stats over each event's time window
  - Filters by `MinDuration`
  - Fires `OnEventStart` callback (up to `MaxCallsPerEvent` times per event)

### Threshold independence

Each threshold independently produces its own events. If a sensor has a warning limit at 80 and a critical limit at 100, `detect()` is called separately for each threshold, producing independent event streams.

## EventConfig (configuration class)

Code-only configuration for the event detection system.

### Properties

| Property | Default | Description |
|---|---|---|
| `Sensors` | `{}` | Cell array of `Sensor` objects |
| `SensorData` | `[]` | Struct array with fields `name`, `t`, `y` for click-to-plot |
| `MinDuration` | `0` | Debounce passed to `EventDetector` |
| `MaxCallsPerEvent` | `1` | Callback limit passed to `EventDetector` |
| `OnEventStart` | `[]` | Callback function handle |
| `ThresholdColors` | `containers.Map()` | Maps threshold labels → `[R G B]` colors |
| `AutoOpenViewer` | `false` | Auto-open `EventViewer` after detection |

### Methods

- `det = buildDetector(obj)` — returns a configured `EventDetector`
- `events = runDetection(obj)` — detects events across all configured sensors, returns combined `Event` array. Opens viewer if `AutoOpenViewer` is true.
- `addSensor(obj, sensor, t, y)` — registers a sensor with its data
- `setColor(obj, label, rgb)` — sets color for a threshold label

## EventViewer (figure UI)

Standalone MATLAB figure with two panels.

### Top panel: Gantt-style timeline
- One row per sensor
- Colored bars for each event, color-coded by threshold label (using `ThresholdColors` from config)
- Shared time axis

### Bottom panel: uitable
- Columns: Start, End, Duration, Sensor, Threshold, Direction, Peak, NumPts, Min, Max, Mean, RMS, Std
- Dropdown filter: sensor name
- Dropdown filter: threshold label
- Clicking a row → opens FastSense showing that sensor's signal zoomed to the event time range

### Methods

- `EventViewer(events)` — create viewer without click-to-plot
- `EventViewer(events, sensorData)` — create viewer with click-to-plot data
- `EventViewer(events, sensorData, thresholdColors)` — with custom colors
- `update(obj, events)` — refresh with new events (for live mode)

## Console Output

### printEventSummary(events)

Formatted table printed to console:

```
╔══════════╦══════════╦══════════╦══════════════╦══════════════════╦═══════╦══════╦══════╦═══════╦═══════╗
║ Start    ║ End      ║ Duration ║ Sensor       ║ Threshold        ║ Dir   ║ Peak ║ #Pts ║ Mean  ║ Std   ║
╠══════════╬══════════╬══════════╬══════════════╬══════════════════╬═══════╬══════╬══════╬═══════╬═══════╣
║ 10.00    ║ 25.00    ║ 15.00    ║ Temperature  ║ warning high     ║ high  ║ 95.2 ║  150 ║ 87.3  ║ 4.21  ║
╚══════════╩══════════╩══════════╩══════════════╩══════════════════╩═══════╩══════╩══════╩═══════╩═══════╝
```

Called manually at any time.

### eventLogger()

Factory function that returns a function handle for use as `OnEventStart` callback:

```matlab
det = EventDetector('OnEventStart', eventLogger());
```

Prints one-line log per event:
```
[EVENT] Temperature | warning high | HIGH | 10.00 → 25.00 (dur=15.00) | peak=95.2
```

## detectEventsFromSensor (convenience function)

```matlab
events = detectEventsFromSensor(sensor)
events = detectEventsFromSensor(sensor, detector)
```

- Resolves thresholds from a `Sensor` object (SensorThreshold library)
- Calls `EventDetector.detect()` for each threshold using sensor's X/Y data
- Returns combined `Event` array
- Accepts optional `EventDetector` instance for custom configuration; creates default if omitted

## groupViolations (private)

- Input: sorted time array, value array, threshold value, direction
- Walks through data, identifies contiguous runs where value violates threshold
- Returns struct array with start/end indices for each group

## Example Script

`examples/example_event_detection_live.m`:

1. **Mock data** — 3 industrial sensors (temperature, pressure, vibration) with realistic ramps, spikes, and oscillations that trigger threshold violations
2. **Config** — `EventConfig` with warning + critical thresholds per sensor, custom colors, `eventLogger()` callback
3. **Initial detection** — run detection on existing data, print summary, open viewer
4. **Live mode** — MATLAB `timer` (e.g. every 2 seconds) that:
   - Appends new mock data points (simulating real-time acquisition)
   - Re-runs detection
   - Updates `EventViewer` live
   - Logs new events to console
5. **Clean stop** — function to stop and delete the timer

## Integration

- No direct FastSense dependency in core classes — `EventViewer` uses FastSense for click-to-plot
- No direct SensorThreshold dependency in core — `detectEventsFromSensor` and `EventConfig` bridge the two libraries
- Path setup: root `setup.m` updated to add `libs/EventDetection/`
