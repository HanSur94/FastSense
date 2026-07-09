<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# WebBridge Guide

WebBridge provides a powerful system for integrating FastPlot with web applications through a TCP-based communication protocol. It enables real-time data streaming, dashboard configuration synchronization, and remote control capabilities.

## Overview

WebBridge serves as a communication bridge between MATLAB/FastPlot and web clients, using NDJSON (Newline Delimited JSON) messages over TCP. This architecture allows:

- Real-time streaming of sensor data to web applications
- Bidirectional dashboard configuration synchronization
- Remote action execution from web interfaces
- Multiple concurrent client connections

## Basic Usage

### Setting Up WebBridge

```matlab
% Create a dashboard with some data
dashboard = Dashboard();
dashboard.addSensor('temperature', randn(1000, 1), 'units', '°C');

% Create and start WebBridge
bridge = WebBridge(dashboard);
bridge.serve();  % Starts both TCP server and data polling
```

### Configuration Options

```matlab
% Customize polling interval for configuration changes
bridge = WebBridge(dashboard, 'ConfigPollInterval', 0.5);  % Poll every 500ms

% Manual control over TCP server
bridge = WebBridge(dashboard);
bridge.startTcp();  % Start TCP server only
% ... later ...
bridge.stop();      % Stop all services
```

## Protocol Messages

WebBridge uses a structured message protocol for communication:

### Initialization Messages

When a client connects, WebBridge sends initialization data:

```matlab
% The bridge automatically sends:
% - Signal definitions (names, units, data types)
% - Dashboard configuration (layouts, themes, etc.)
% - Available actions list
```

### Data Update Messages

As data changes, WebBridge streams updates:

```matlab
% Manually trigger data change notifications
bridge.notifyDataChanged('temperature');  % Single signal
bridge.notifyDataChanged({'temp', 'pressure'});  % Multiple signals
```

### Configuration Synchronization

Dashboard configuration changes are automatically detected and broadcast:

```matlab
% Any changes to dashboard properties trigger config updates
dashboard.Title = 'Updated Dashboard';
% WebBridge automatically detects and broadcasts this change
```

## Remote Actions

### Registering Actions

Register callback functions that can be invoked from web clients:

```matlab
% Register a simple action
bridge.registerAction('reset_data', @() resetSensorData());

% Register an action with parameters
bridge.registerAction('set_threshold', @(params) setThreshold(params.value));

% Register an action that returns results
bridge.registerAction('get_stats', @() struct('mean', mean(data), 'std', std(data)));
```

### Action Management

```matlab
% Check if an action exists
if bridge.hasAction('reset_data')
    disp('Reset action is available');
end

% List every currently registered action
names = bridge.listActions();   % cellstr, {} when none are registered

% Remove a registered action (no-op if it isn't registered)
bridge.unregisterAction('reset_data');

% Actions are automatically broadcast to clients when registered or
% unregistered (while a client is connected)
```

## Advanced Integration Patterns

### Live Data Streaming

```matlab
dashboard = Dashboard();
sensor = dashboard.addSensor('live_data', []);
bridge = WebBridge(dashboard);
bridge.serve();

% Simulate live data updates
timer_obj = timer('ExecutionMode', 'fixedRate', 'Period', 0.1, ...
    'TimerFcn', @(~,~) updateLiveData());

    function updateLiveData()
        new_data = randn(10, 1);
        sensor.appendData(new_data);
        bridge.notifyDataChanged('live_data');
    end

start(timer_obj);
```

### Multi-Dashboard Broadcasting

```matlab
% WebBridge can handle complex dashboard configurations
dashboard = Dashboard();
dashboard.addSensor('sensor1', data1);
dashboard.addSensor('sensor2', data2);

% All sensors and their configurations are automatically synchronized
bridge = WebBridge(dashboard);
bridge.serve();
```

### Custom Action Handlers

```matlab
% Register actions with error handling
bridge.registerAction('process_data', @processDataHandler);

function result = processDataHandler(params)
    try
        % Process the request
        result = struct('success', true, 'data', processedData);
    catch ME
        result = struct('success', false, 'error', ME.message);
    end
end
```

## Protocol Details

### Message Format

All messages use NDJSON format (one JSON object per line):

```matlab
% Example message types sent by WebBridge:
% {"type": "init", "signals": [...], "dashboard": {...}, "actions": [...]}
% {"type": "data_changed", "signalIds": ["sensor1", "sensor2"]}
% {"type": "config_changed", "dashboard": {...}}
% {"type": "actions_changed", "actionNames": ["action1", "action2"]}
% {"type": "action_result", "requestId": "123", "name": "action1", "ok": true, "data": {...}}
```

### Client Integration

Web clients should handle these message types:

- `init`: Initial data and configuration
- `data_changed`: Signal data updates
- `config_changed`: Dashboard configuration updates
- `actions_changed`: Available actions list updates
- `action_result`: Results from action execution

## Performance Considerations

### Efficient Data Updates

```matlab
% Batch multiple signal updates
bridge.notifyDataChanged({'temp', 'pressure', 'humidity'});

% Rather than individual notifications:
% bridge.notifyDataChanged('temp');
% bridge.notifyDataChanged('pressure');
% bridge.notifyDataChanged('humidity');
```

### Configuration Polling

```matlab
% Adjust polling frequency based on needs
bridge.ConfigPollInterval = 2.0;  % Less frequent for stable configurations
bridge.ConfigPollInterval = 0.1;  % More frequent for dynamic dashboards
```

## Error Handling

### Connection Management

```matlab
% WebBridge handles client connections automatically
% Multiple clients can connect simultaneously
% Disconnected clients are automatically cleaned up
```

### Action Error Reporting

```matlab
% Action errors are automatically captured and sent to clients
bridge.registerAction('failing_action', @() error('Something went wrong'));
% Client receives: {"ok": false, "error": "Something went wrong"}
```

## Integration with Dashboard Engine

WebBridge works seamlessly with the [[Dashboard Engine Guide]]:

```matlab
% Dashboard engine changes are automatically synchronized
dashboard.Theme = 'dark';
dashboard.Layout = 'grid';
% WebBridge detects and broadcasts these changes
```

## Best Practices

1. **Register all actions before starting the server** to ensure clients receive the complete actions list
2. **Use batch notifications** for multiple simultaneous data updates
3. **Handle action errors gracefully** with try-catch blocks
4. **Set appropriate polling intervals** based on configuration change frequency
5. **Clean up resources** by calling `stop()` when shutting down

For more information on dashboard configuration, see the [[Dashboard|API Reference: Dashboard]] page.
