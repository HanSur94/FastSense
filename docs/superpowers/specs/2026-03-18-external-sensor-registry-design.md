# External Sensor Registry Design

**Date:** 2026-03-18
**Status:** Draft

## Problem

External libraries produce .mat files containing raw timeseries data (multiple signals per file, multiple files). We need a way to define sensors against this data and integrate them into the FastSense live pipeline — without modifying the existing `SensorRegistry` or any other FastPlot API.

## Solution

A single new class: `ExternalSensorRegistry`, located in `libs/SensorThreshold/ExternalSensorRegistry.m`.

## Design

### ExternalSensorRegistry

A non-singleton registry where sensors are explicitly defined in code and wired to .mat file data sources.

**Key differences from SensorRegistry:**
- Not a singleton — multiple instances allowed (one per external library/project)
- No hardcoded `catalog()` — sensors are registered externally via `register()`
- Owns a `DataSourceMap` built up by `wireMatFile()` calls
- Has a `Name` property to identify the registry instance

**Properties:**
- `Name` (char) — human-readable label (e.g., `'VibrationLab'`)
- `Catalog` (containers.Map) — char → Sensor mapping
- `DSMap` (DataSourceMap) — internal, built by `wireMatFile()`

### Public API

#### Sensor Management (based on SensorRegistry, with additions)

| Method | Signature | Description |
|--------|-----------|-------------|
| Constructor | `ExternalSensorRegistry(name)` | Create registry with a name |
| `register` | `register(key, sensor)` | Add a Sensor to the catalog |
| `unregister` | `unregister(key)` | Remove a Sensor from the catalog |
| `get` | `get(key)` → Sensor | Retrieve sensor by key |
| `getMultiple` | `getMultiple(keys)` → cell array | Retrieve multiple sensors |
| `getAll` | `getAll()` → containers.Map | Return full catalog |
| `keys` | `keys()` → cell array | All registered keys |
| `count` | `count()` → double | Number of sensors |
| `list` | `list()` | Print summary table to console |
| `printTable` | `printTable()` | Print detailed table |
| `viewer` | `viewer()` → figure | GUI uitable of all sensors |

#### Data Wiring

| Method | Signature | Description |
|--------|-----------|-------------|
| `wireMatFile` | `wireMatFile(path, mappings)` | Wire .mat file fields to sensor keys |
| `wireStateChannel` | `wireStateChannel(sensorKey, stateKey, matPath, NV...)` | Wire state channel data to a sensor |
| `getDataSourceMap` | `getDataSourceMap()` → DataSourceMap | Return DataSourceMap for pipeline use |

### wireMatFile

Connects fields in a .mat file to sensors already registered in the catalog.

**Signature:**
```matlab
reg.wireMatFile(matFilePath, mappings)
```

**Parameters:**
- `matFilePath` (char) — path to the .mat file
- `mappings` (Nx3+ cell array) — each row: `{sensorKey, 'XVar', xFieldName, 'YVar', yFieldName}`

**Behavior:**
1. For each row in mappings:
   - Validates that `sensorKey` exists in the catalog (error if not)
   - Sets `Sensor.MatFile = matFilePath`
   - Sets `Sensor.KeyName` to the YVar field name
   - Creates a `MatFileDataSource(matFilePath, 'XVar', xField, 'YVar', yField)`
   - Adds it to the internal `DataSourceMap` under the sensor key
2. If a sensor key is already wired (checked via `DataSourceMap.has()`), the new wiring overwrites with a warning issued via `warning()`

### wireStateChannel

Attaches a state channel from a .mat file to a registered sensor.

**Signature:**
```matlab
reg.wireStateChannel(sensorKey, stateKey, matFilePath, 'XVar', xField, 'YVar', yField)
```

**Behavior:**
1. Validates `sensorKey` exists in the catalog (error if not)
2. Creates a `StateChannel(stateKey, 'MatFile', matFilePath, 'KeyName', yField)` (note: `stateKey` is positional)
3. Calls `sensor.addStateChannel(sc)` on the target sensor
4. If the state data lives in the **same** .mat file as the sensor data, updates the existing `MatFileDataSource` to include `StateXVar`/`StateYVar`
5. If the state data lives in a **different** .mat file, the `StateChannel` loads its own data via `StateChannel.MatFile` / `StateChannel.load()` — no changes to the sensor's `MatFileDataSource`

### getDataSourceMap

Returns the internal `DataSourceMap` so it can be passed directly to `LiveEventPipeline`.

### Usage Example

```matlab
%% 1. Define the registry
reg = ExternalSensorRegistry('VibrationLab');

%% 2. Define sensors explicitly (note: key is positional first argument)
s1 = Sensor('bearing_temp', 'Name', 'Bearing Temperature', ...
            'Units', 'degC', 'ID', 101);
% struct() = empty condition = unconditional (always active regardless of state)
s1.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'Warning');
s1.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'Critical');
reg.register('bearing_temp', s1);

s2 = Sensor('oil_pressure', 'Name', 'Oil Pressure', ...
            'Units', 'bar', 'ID', 102);
s2.addThresholdRule(struct(), 2.0, 'Direction', 'lower', 'Label', 'Low Pressure');
reg.register('oil_pressure', s2);

%% 3. Wire .mat file data
reg.wireMatFile('lab1/vibration.mat', {
    'bearing_temp',  'XVar', 'time', 'YVar', 'temp_bearing';
    'oil_pressure',  'XVar', 'time', 'YVar', 'press_oil';
});

%% 4. Wire state channels
reg.wireStateChannel('bearing_temp', 'machine_state', ...
    'lab1/states.mat', 'XVar', 'state_time', 'YVar', 'state_val');

%% 5. Use with live pipeline
dsMap = reg.getDataSourceMap();
sensors = reg.getAll();

pipeline = LiveEventPipeline(sensors, dsMap, ...
    'EventFile', 'output/events.mat', ...
    'Interval', 15);
pipeline.start();
```

## Scope

### In scope
- `ExternalSensorRegistry` class with full API
- `wireMatFile` and `wireStateChannel` methods
- Integration with existing `LiveEventPipeline` via `getDataSourceMap()`

### Out of scope
- Changes to `SensorRegistry`, `Sensor`, `DataSource`, `LiveEventPipeline`, or any other existing class
- Config-file-based sensor definitions (all config is in code)
- Auto-discovery of signals from .mat files

## File Changes

| File | Change |
|------|--------|
| `libs/SensorThreshold/ExternalSensorRegistry.m` | **New** — the entire design |

One new file. Zero modifications to existing files.
