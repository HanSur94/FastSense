<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# WebBridge Guide

WebBridge provides a connectivity layer between MATLAB/FastPlot dashboards and external web applications. It streams signal data, synchronizes dashboard configuration, and allows remote code execution via a TCP-based protocol using NDJSON messages.

## Overview

WebBridge is a pure data relay – it does not render any UI. It exposes a TCP server inside MATLAB and launches a companion Python‑based bridge that translates the TCP stream into HTTP and WebSocket for web clients.

**When to use WebBridge**
- You need a live dashboard view in a web browser.
- You want to trigger MATLAB functions from a web interface.
- You need to stream sensor data to multiple remote consumers.

## Basic Usage

### Creating a Bridge and Starting the Server

```matlab
% Build a dashboard with one sensor
dashboard = Dashboard();
dashboard.addSensor('temperature', randn(1000,1), 'units', '°C');

% Create the bridge and start all services
bridge = WebBridge(dashboard);
bridge.serve();   % TCP server + Python HTTP/WS bridge on port 8080
```

The call to `serve()` is blocking only in the sense that it keeps the TCP server alive; you can continue to execute MATLAB commands in the same session while the bridge runs.

### Stopping the Bridge

```matlab
bridge.stop();   % clean shutdown of TCP server and Python bridge
```

## Protocol Messages

WebBridge uses **NDJSON** (Newline Delimited JSON). Internally the `WebBridgeProtocol` class encodes and decodes the following message types.

### Initialization (`init`)

Sent when a client first connects. It contains the list of signals (name, units, data type, …), the current dashboard configuration, and all registered actions.

### Data Update (`data_changed`)

Broadcast when data for one or more signals has changed. The message carries the identifiers of the affected signals.

```matlab
bridge.notifyDataChanged('temperature');                % single signal
bridge.notifyDataChanged({'temp','pressure','hum'});   % batch
```

### Action Change (`actions_changed`)

Sent whenever an action is registered or removed. The message lists the currently available action names.

### Action Result (`action_result`)

Sent as a response after a client requests the execution of an action. It includes the request ID, the action name, a success flag, and any returned data or error message.

### Shutdown (`shutdown`)

Indicates the bridge is about to close.

**Example JSON messages (client view)**
```json
// init:
{"type":"init","signals":[...],"dashboard":{...},"actions":["reset","recalc"]}

// data_changed:
{"type":"data_changed","signalIds":["temp","pressure"]}

// action_result (success):
{"type":"action_result","requestId":"42","name":"recalc","ok":true,"data":{"mean":23.4}}

// action_result (error):
{"type":"action_result","requestId":"42","name":"recalc","ok":false,"error":"Something went wrong"}
```

## Remote Actions

Actions are MATLAB callbacks that web clients can invoke. They are registered on the bridge and immediately broadcast to all connected clients.

### Registering an Action

```matlab
% Simple action without parameters
bridge.registerAction('reset', @() resetSensorData());

% Action with a parameters struct
bridge.registerAction('set_threshold', @(p) setThreshold(p.value));

% Action that returns a result
bridge.registerAction('stats', @() struct('mean', mean(data), 'std', std(data)));
```

The callback can accept zero or one argument. If a client sends a JSON payload, it is passed as a MATLAB struct.

### Checking for an Action

```matlab
if bridge.hasAction('reset')
    disp('Reset action is available');
end
```

### Error Handling in Actions

If an action throws an error, the bridge automatically catches it and sends a failure response to the client:

```matlab
bridge.registerAction('failing', @() error('Something went wrong'));
```

The client will receive `{"ok":false, "error":"Something went wrong"}`.

## Advanced Integration Patterns

### Live Data Streaming

```matlab
dashboard = Dashboard();
sensor = dashboard.addSensor('live', []);
bridge = WebBridge(dashboard);
bridge.serve();

% Update data periodically
t = timer('ExecutionMode','fixedRate','Period',0.1, ...
          'TimerFcn',@(~,~) liveUpdate());
start(t);

function liveUpdate()
    newChunk = randn(10,1);
    sensor.appendData(newChunk);
    bridge.notifyDataChanged('live');
end
```

### Multiple Connected Clients

WebBridge can serve an arbitrary number of clients simultaneously. Every client receives the same set of signals and actions, and any action request is executed once on the MATLAB side regardless of the number of clients.

### Dashboards with Multiple Sensors

All sensors added to the `Dashboard` are automatically discovered and exposed via the bridge:

```matlab
dashboard = Dashboard();
dashboard.addSensor('vibration', dataVib, 'units', 'g');
dashboard.addSensor('pressure', dataPress, 'units', 'psi');
bridge = WebBridge(dashboard);
bridge.serve();
```

No additional registration is needed for sensors.

## Performance Considerations

- **Batch data notifications** – use `notifyDataChanged` with a cell array of signal names instead of calling it multiple times in a loop.
- **Avoid excessive action calls** – Keep action handlers lightweight; heavy computation should be performed asynchronously inside MATLAB and only the result pushed to clients.

## Integration with Dashboard Engine

WebBridge automatically picks up changes to the `Dashboard` object (e.g., layout, theme, sensor list) and broadcasts them to connected clients. For more information on dashboard configuration see [[Dashboard Engine Guide]].

## Error Handling

- **Disconnected clients** are cleaned up automatically.
- **Action errors** are captured and returned to the requesting client with `ok = false`.
- **Stop gracefully** – always call `bridge.stop()` before clearing the dashboard or exiting MATLAB to ensure the TCP server and Python process are terminated.

## Best Practices

1. **Register all actions before calling `serve()`** so that the `init` message includes the complete action list.
2. **Batch data change notifications** when updating multiple signals at once.
3. **Wrap complex action callbacks** in try–catch blocks when you need custom error messages.
4. **Do not block the MATLAB command window** from inside an action – use `timer` or `afterEach` for long‑running tasks.
5. **Keep the Python bridge** at the same version as the MATLAB WebBridge; they are tightly coupled.

## See Also

- [[Dashboard|API Reference: Dashboard]]
- [[Sensors|API Reference: Sensors]]
- [[Dashboard Engine Guide]]
- `WebBridgeProtocol` (internal message encoding/decoding)
