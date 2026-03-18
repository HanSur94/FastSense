<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Sensors

## `Sensor` --- Represents a sensor with data, state channels, and threshold rules.

> Inherits from: `handle`

Sensor is the central class of the SensorThreshold library.  It
  bundles raw time-series data (X, Y) with a set of StateChannels
  (discrete system states) and ThresholdRules (condition-dependent
  limit values).  The resolve() method evaluates all rules against
  the state channels to produce pre-computed threshold time series,
  violation indices, and state-band regions that can be rendered by
  a plotting layer such as FastSense.

### Constructor

```matlab
obj = Sensor(key, varargin)
```

SENSOR Construct a Sensor object.
  s = Sensor(key) creates a sensor with the given string
  identifier and default property values.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Key |  | char: unique string identifier for this sensor |
| Name |  | char: human-readable display name |
| ID |  | numeric: sensor ID (e.g., from a database) |
| Source |  | char: path to the original raw data file |
| MatFile |  | char: path to .mat file with transformed data |
| KeyName |  | char: field name in .mat file (defaults to Key) |
| X |  | 1xN double: datenum time stamps |
| Y |  | 1xN (or MxN) double: sensor values |
| Units |  | char: measurement unit (e.g., 'degC', 'bar', 'rpm') |
| DataStore |  | FastSenseDataStore: disk-backed storage (set by toDisk) |
| StateChannels |  | cell array of StateChannel objects |
| ThresholdRules |  | cell array of ThresholdRule objects |
| ResolvedThresholds |  | struct array: precomputed threshold step-function lines |
| ResolvedViolations |  | struct array: precomputed violation (X,Y) points |
| ResolvedStateBands |  | struct: precomputed state region bands for shading |

### Methods

#### `load(obj)`

LOAD Load sensor data from a .mat file.
  s.load() populates s.X and s.Y by loading the file
  specified in s.MatFile using the field name s.KeyName.
  Requires MatFile and KeyName to be set.

#### `addStateChannel(obj, sc)`

ADDSTATECHANNEL Attach a StateChannel to this sensor.
  s.addStateChannel(sc) appends the given StateChannel
  object to the sensor's StateChannels list.  During
  resolve(), each attached channel's key becomes a field in
  the state struct used to evaluate ThresholdRule conditions.

#### `addThresholdRule(obj, condition, value, varargin)`

ADDTHRESHOLDRULE Add a dynamic threshold rule to this sensor.
  s.addThresholdRule(condition, value, Name, Value, ...)
  creates a new ThresholdRule and appends it to the sensor's
  ThresholdRules list.  All additional name-value arguments
  are forwarded to the ThresholdRule constructor.

#### `toDisk(obj)`

TODISK Move sensor X/Y data to disk-backed DataStore.
  s.toDisk() creates a FastSenseDataStore from the sensor's
  X and Y arrays, then clears X and Y from memory. The data
  remains accessible via s.DataStore.getRange() and
  s.DataStore.readSlice(). Subsequent calls to resolve(),
  addSensor(), and FastSense rendering all work transparently.

#### `toMemory(obj)`

TOMEMORY Load disk-backed data back into memory.
  s.toMemory() reads the full dataset from the DataStore
  back into s.X and s.Y, then cleans up the DataStore.

#### `tf = isOnDisk(obj)`

ISONDISK True if sensor data is stored on disk.

#### `resolve(obj)`

RESOLVE Precompute threshold time series, violations, and state bands.
  s.resolve() evaluates all ThresholdRules against the
  attached StateChannels and the sensor's own X/Y data.
  Results are stored in the ResolvedThresholds,
  ResolvedViolations, and ResolvedStateBands properties.

#### `active = getThresholdsAt(obj, t)`

GETTHRESHOLDSAT Evaluate all rules at a single time point.
  active = s.getThresholdsAt(t) builds the composite state
  struct at time t (by querying each StateChannel), then
  tests every ThresholdRule against that state.  Returns a
  struct array of all rules whose conditions are satisfied,
  with fields Value, Direction, and Label.

#### `n = countViolations(obj)`

COUNTVIOLATIONS Count total violation points across all rules.
  n = s.countViolations() returns the total number of
  violation data points summed over all ResolvedViolations.
  Call resolve() first.

#### `st = currentStatus(obj)`

CURRENTSTATUS Derive 'ok'/'warning'/'alarm' from latest value.
  st = s.currentStatus() evaluates the sensor's latest Y
  value against all threshold rules active at the latest X
  time. Returns 'ok' if no thresholds are violated,
  'warning' if a warning-level rule is violated, or 'alarm'
  if an alarm-level rule is violated.

---

## `StateChannel` --- Discrete state signal with zero-order hold lookup.

> Inherits from: `handle`

StateChannel models a piecewise-constant ("zero-order hold") time
  series representing a discrete system state (e.g., machine mode,
  recipe phase).  Given a query time, it returns the most recent
  known state value.  The class supports both numeric and
  string/categorical state values.

  StateChannel is used by Sensor to condition ThresholdRule
  evaluation: each Sensor may reference one or more StateChannels
  whose values determine which threshold rules are active at any
  given moment.

### Constructor

```matlab
obj = StateChannel(key, varargin)
```

STATECHANNEL Construct a StateChannel object.
  sc = StateChannel(key) creates a channel with the given
  identifier and default properties.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Key |  | char: unique string identifier for this state channel |
| MatFile |  | char: path to .mat file containing the state data |
| KeyName |  | char: field name in .mat file (defaults to Key) |
| X |  | 1xN datenum: sorted timestamps of state transitions |
| Y |  | 1xN numeric or 1xN cell: state values at each transition |

### Methods

#### `load(obj)`

LOAD Load state data from the external data source.
  sc.load() populates sc.X and sc.Y by loading the file
  specified in sc.MatFile.  This is a placeholder that must
  be overridden or extended to integrate with your project's
  data loading library.  Alternatively, set X and Y directly.

#### `val = valueAt(obj, t)`

VALUEAT Return state value at time t using zero-order hold.
  val = sc.valueAt(t) performs a zero-order hold lookup: it
  returns the last state value whose transition timestamp is
  at or before the query time t.  If t precedes the first
  timestamp, the first state value is returned (clamp).

---

## `ThresholdRule` --- Defines a condition-value pair for dynamic thresholds.

ThresholdRule pairs a state-condition struct with a numeric
  threshold value.  A rule is "active" when every field in its
  Condition struct matches the current system state (implicit AND).
  An empty condition struct() means the rule is always active
  (unconditional threshold).

  The Direction property determines whether the threshold is an
  upper limit ('upper' -- violation when sensor > Value) or a lower
  limit ('lower' -- violation when sensor < Value).

### Constructor

```matlab
obj = ThresholdRule(condition, value, varargin)
```

THRESHOLDRULE Construct a ThresholdRule object.
  rule = ThresholdRule(condition, value) creates a rule with
  default direction 'upper', empty label, and dashed line.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| DIRECTIONS | `{'upper', 'lower'}` | Allowed direction values |
| Condition |  | struct: field names = state channel keys, values = required state |
| Value |  | numeric: threshold value when condition is true |
| Direction |  | char: 'upper' or 'lower' violation direction |
| Label |  | char: display label for plots and legends |
| Color |  | 1x3 double: RGB color (empty = use theme default) |
| LineStyle |  | char: MATLAB line-style specifier (e.g., '--', ':') |

### Methods

#### `tf = matchesState(obj, st)`

MATCHESSTATE Check if a state struct satisfies this rule's condition.
  tf = rule.matchesState(st) returns true if every field in
  the rule's Condition struct exists in st and has a matching
  value (implicit AND logic).  An empty Condition always
  returns true, meaning the rule is unconditional.

---

## `SensorRegistry` --- Catalog of predefined sensor definitions.

SensorRegistry provides a centralized, singleton-style catalog of
  all known Sensor objects in the SensorThreshold library. Sensor
  definitions are specified in the private catalog() method and
  cached in a persistent variable so that repeated lookups incur no
  construction overhead.

  To add a new sensor, edit the catalog() method at the bottom of
  this file.  Each entry creates a Sensor object, optionally
  configures its state channels and threshold rules, then stores it
  in the containers.Map keyed by a short string identifier.

### Static Methods

#### `SensorRegistry.s = get(key)`

GET Retrieve a predefined sensor by key.
  s = SensorRegistry.get(key) returns the Sensor object
  registered under the string key. Throws an error if the
  key is not found in the catalog.

#### `SensorRegistry.sensors = getMultiple(keys)`

GETMULTIPLE Retrieve multiple sensors by key.
  sensors = SensorRegistry.getMultiple(keys) returns a cell
  array of Sensor objects, one per element of the input keys.

#### `SensorRegistry.list()`

LIST Print all available sensor keys and names.
  SensorRegistry.list() prints a formatted table of every
  registered sensor key and its human-readable name to the
  command window.  Keys are sorted alphabetically.

#### `SensorRegistry.register(key, sensor)`

REGISTER Add a sensor to the catalog at runtime.
  SensorRegistry.register('myKey', sensorObj)

#### `SensorRegistry.unregister(key)`

UNREGISTER Remove a sensor from the catalog.

#### `SensorRegistry.printTable()`

PRINTTABLE Print a detailed table of all registered sensors.
  SensorRegistry.printTable() prints a formatted table with
  columns: Key, Name, ID, Source, MatFile, #States, #Rules, #Points.

#### `SensorRegistry.hFig = viewer()`

VIEWER Open a GUI figure showing all registered sensors.
  hFig = SensorRegistry.viewer() creates a figure with a
  uitable listing every sensor's Key, Name, ID, Source,
  MatFile, #States, #Rules, and #Points.

---

## `ExternalSensorRegistry` --- Non-singleton sensor registry for external data.

> Inherits from: `handle`

ExternalSensorRegistry holds explicitly registered Sensor objects
  and wires them to .mat file data sources for use with
  LiveEventPipeline.

  Unlike SensorRegistry (singleton with hardcoded catalog), this
  class supports multiple instances and is populated via register().

### Constructor

```matlab
obj = ExternalSensorRegistry(name)
```

EXTERNALSENSORREGISTRY Construct a named registry.
  reg = ExternalSensorRegistry('MyLab')

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Name |  | char: human-readable label for this registry |

### Methods

#### `n = count(obj)`

COUNT Number of registered sensors.

#### `k = keys(obj)`

KEYS Return all registered sensor keys.

#### `register(obj, key, sensor)`

REGISTER Add a Sensor to the catalog.
  reg.register('key', sensorObj)

#### `unregister(obj, key)`

UNREGISTER Remove a Sensor from the catalog.

#### `s = get(obj, key)`

GET Retrieve a sensor by key.

#### `sensors = getMultiple(obj, keys)`

GETMULTIPLE Retrieve multiple sensors by key.

#### `m = getAll(obj)`

GETALL Return a copy of the catalog as a containers.Map.

#### `list(obj)`

LIST Print all registered sensor keys and names.

#### `printTable(obj)`

PRINTTABLE Print a detailed table of all registered sensors.

#### `wireMatFile(obj, matFilePath, mappings)`

WIREMATFILE Wire .mat file fields to registered sensor keys.
  reg.wireMatFile('data.mat', {
      'sensorKey', 'XVar', 'time', 'YVar', 'value';
  })

#### `dsMap = getDataSourceMap(obj)`

GETDATASOURCEMAP Return the DataSourceMap for pipeline use.

#### `hFig = viewer(obj)`

VIEWER Open a GUI figure showing all registered sensors.

#### `wireStateChannel(obj, sensorKey, stateKey, matFilePath, varargin)`

WIRESTATECHANNEL Wire state channel data to a registered sensor.
  reg.wireStateChannel('sensorKey', 'stateKey', 'states.mat', ...
      'XVar', 'state_time', 'YVar', 'state_val')

