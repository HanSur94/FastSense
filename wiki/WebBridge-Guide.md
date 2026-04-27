<!-- AUTO-GENERATED from source code by scripts/generate_wiki.py — do not edit manually -->

# WebBridge Guide

WebBridge provides a powerful system for integrating FastPlot with web applications through a TCP-based communication protocol. It enables real-time data streaming, dashboard configuration synchronization, and remote control capabilities.

## Overview

WebBridge serves as a communication bridge between MATLAB/FastPlot and web clients, using NDJSON (Newline Delimited JSON) messages over TCP. This architecture allows:

- Real-time streaming of sensor data to web applications
- Bidirectional dashboard configuration synchronization
- Remote action execution from web interfaces
- Multiple concurrent client connections

The bridge operates as a pure data relay system with no dashboard rendering or UI logic, following this architecture:

```
MATLAB (tcpserver) —TCP/NDJSON—> Python (FastAPI) —HTTP/WS—> Clients
```

## Basic Usage

### Setting Up WebBridge

```matlab
% Create a dashboard with some data
dashboard = Dashboard();
dashboard.addSensor('temperature', randn(1000, 1), 'units', '°C');

% Create and start WebBridge
bridge = WebBridge(dashboard);
bridge.serve();  % Starts TCP server and launches Python bridge at localhost:8080
```

### Manual Control

```matlab
% Manual control over services
bridge = WebBridge(dashboard);
bridge.serve();     % Start both TCP and Python bridge
% ... later ...
bridge.stop();      % Stop all services and clean up resources
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

% Actions are automatically broadcast to clients when registered
```

## Data Change Notifications

### Triggering Updates

When sensor data changes, notify connected clients:

```matlab
% Notify single signal change
bridge.notifyDataChanged('temperature');

% Notify multiple signals (more efficient)
bridge.notifyDataChanged({'temp', 'pressure', 'humidity'});
```

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

## Protocol Messages

WebBridge communicates using structured NDJSON messages over TCP. The [[WebBridgeProtocol]] class handles encoding and decoding.

### Message Types

```matlab
% Initialization message (sent on client connect)
initMsg = WebBridgeProtocol.encodeInit(signals, actions);

% Data change notification
dataMsg = WebBridgeProtocol.encodeDataChanged({'sensor1', 'sensor2'});

% Actions list update
actionsMsg = WebBridgeProtocol.encodeActionsChanged({'action1', 'action2'});

% Action execution result
resultMsg = WebBridgeProtocol.encodeActionResult('req123', 'actionName', true, '');

% Shutdown notification
shutdownMsg = WebBridgeProtocol.encodeShutdown();
```

### Message Decoding

```matlab
% Decode incoming messages from clients
rawMessage = '{"type": "action_call", "name": "reset_data"}';
decodedMsg = WebBridgeProtocol.decode(rawMessage);
```

## Advanced Integration Patterns

### Multi-Sensor Dashboard

```matlab
% WebBridge handles complex dashboard configurations automatically
dashboard = Dashboard();
dashboard.addSensor('sensor1', data1, 'units', 'm/s');
dashboard.addSensor('sensor2', data2, 'units', 'Pa');
dashboard.addSensor('sensor3', data3, 'units', '°C');

% All sensors and configurations are automatically synchronized
bridge = WebBridge(dashboard);
bridge.serve();

% Any dashboard changes are automatically detected and broadcast
dashboard.Title = 'Updated Multi-Sensor Dashboard';
```

### Custom Action Handlers

```matlab
% Register actions with comprehensive error handling
bridge.registerAction('process_data', @processDataHandler);
bridge.registerAction('export_results', @exportResultsHandler);

function result = processDataHandler(params)
    try
        % Process the request
        processedData = processSignalData(params.signalId, params.method);
        result = struct('success', true, 'data', processedData);
    catch ME
        result = struct('success', false, 'error', ME.message);
    end
end

function result = exportResultsHandler(params)
    try
        filename = sprintf('export_%s.csv', datestr(now, 'yyyymmdd_HHMMSS'));
        exportToCSV(params.data, filename);
        result = struct('success', true, 'filename', filename);
    catch ME
        result = struct('success', false, 'error', ME.message);
    end
end
```

### Batch Data Operations

```matlab
% Efficient handling of multiple simultaneous updates
function performBatchUpdate()
    % Update multiple sensors
    sensors = {'temperature', 'pressure', 'humidity', 'flow_rate'};
    
    for i = 1:length(sensors)
        updateSensorData(sensors{i});
    end
    
    % Single notification for all changes
    bridge.notifyDataChanged(sensors);
end
```

## Integration with Dashboard System

WebBridge works seamlessly with the [[Dashboard|API Reference: Dashboard]] system:

```matlab
% Dashboard property changes are automatically detected
dashboard = Dashboard();
bridge = WebBridge(dashboard);
bridge.serve();

% These changes trigger automatic config synchronization
dashboard.Title = 'Production Dashboard';
dashboard.Theme = 'dark';
dashboard.Layout = 'grid';

% Sensor additions/modifications are also synchronized
newSensor = dashboard.addSensor('vibration', vibData, 'units', 'g');
```

## Performance Considerations

### Efficient Data Notifications

```matlab
% Batch multiple signal updates for better performance
signalsToUpdate = {'temp', 'pressure', 'humidity'};
bridge.notifyDataChanged(signalsToUpdate);

% Avoid individual notifications:
% bridge.notifyDataChanged('temp');      % Less efficient
% bridge.notifyDataChanged('pressure');  % for multiple
% bridge.notifyDataChanged('humidity');  % updates
```

### Resource Management

```matlab
% Properly clean up resources
bridge = WebBridge(dashboard);
bridge.serve();

% ... application logic ...

% Always stop the bridge to clean up TCP connections and Python processes
bridge.stop();
```

## Error Handling

### Connection Management

WebBridge automatically handles:
- Multiple concurrent client connections
- Client disconnection cleanup
- TCP server error recovery
- Python bridge process management

### Action Error Reporting

```matlab
% Action errors are automatically captured and sent to clients
bridge.registerAction('failing_action', @() error('Something went wrong'));

% Client receives: {"ok": false, "error": "Something went wrong"}
% No need for manual error handling in simple cases
```

## Best Practices

1. **Register all actions before serving** to ensure clients receive the complete actions list
2. **Use batch notifications** for multiple simultaneous data updates
3. **Handle action errors gracefully** with try-catch blocks in complex handlers
4. **Always call stop()** when shutting down to clean up resources
5. **Test action callbacks independently** before registering them with the bridge
6. **Use meaningful action names** that describe their purpose clearly

## Common Use Cases

### Real-Time Monitoring Dashboard

```matlab
% Set up real-time monitoring with WebBridge
dashboard = Dashboard();
sensors = {'cpu_temp', 'memory_usage', 'disk_io'};

for i = 1:length(sensors)
    dashboard.addSensor(sensors{i}, []);
end

bridge = WebBridge(dashboard);
bridge.registerAction('reset_monitoring', @resetAllSensors);
bridge.serve();

% Update loop (would typically run in a timer or separate thread)
while isRunning
    newData = collectSystemMetrics();
    updateSensorData(newData);
    bridge.notifyDataChanged(sensors);
    pause(1);
end
```

### Remote Control Interface

```matlab
% Create a remotely controllable system
bridge = WebBridge(dashboard);

% Register control actions
bridge.registerAction('start_acquisition', @startDataAcquisition);
bridge.registerAction('stop_acquisition', @stopDataAcquisition);
bridge.registerAction('calibrate_sensors', @calibrateAllSensors);
bridge.registerAction('get_system_status', @getSystemStatus);

bridge.serve();
% System is now controllable via web interface at localhost:8080
```

For more information on dashboard configuration and sensor management, see the [[Dashboard|API Reference: Dashboard]] page.
