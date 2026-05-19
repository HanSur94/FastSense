<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Event Detection

## `Event` --- Represents a single detected threshold violation event.

> Inherits from: `handle`

e = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
  e.setStats(peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)

  Phase 1032 additions:
    Identity (struct, default empty)        — IDENT-02 audit trail; populated at emission
    AckedAt  (numeric, default [])          — datenum of ack; [] = unacked
    AckedBy  (struct, default empty struct) — {user, host, epoch, comment}; populated by EventStore.acknowledgeEvent
    AckComment (char, default '')           — convenience alias for AckedBy.comment
  Method:
    computeDisplayState — returns 'unacked-active' | 'acked-active' | 'acked-cleared' | 'unacked-cleared' (ISA-18.2 §5.4)
  Static helper:
    Event.fromStructSafe(s)  — promote legacy struct to Event with safe field defaults

### Constructor

```matlab
obj = Event(startTime, endTime, sensorName, thresholdLabel, thresholdValue, direction)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| TagKeys | `{}` | cell of char: tag keys bound to this event (EVENT-01) |
| Severity | `1` | numeric: 1=ok/info, 2=warn, 3=alarm (EVENT-04) |
| Category | `''` | char: alarm\|maintenance\|process_change\|manual_annotation (EVENT-05) |
| Id | `''` | char: unique id assigned by EventStore.append (EVENT-02) |
| IsOpen | `false` | logical: true while event is still open (EndTime = NaN) — Phase 1012 |
| Notes | `''` | char: free-form user annotation edited via details popup — Phase 1012 |
| Identity | `struct()` |  |
| AckedAt | `[]` | numeric epoch (datenum); [] means unacked. Set by EventStore.acknowledgeEvent |
| AckedBy | `struct()` | {user, host, epoch, comment}; populated by EventStore.acknowledgeEvent |
| AckComment | `''` | char: convenience alias; mirrors AckedBy.comment after acknowledgeEvent |
| DIRECTIONS | `{'upper', 'lower'}` |  |

### Methods

#### `obj = setStats(obj, peakValue, numPoints, minVal, maxVal, meanVal, rmsVal, stdVal)`

SETSTATS Set event statistics.

#### `obj = close(obj, endTime, finalStats)`

CLOSE Close an open event in place; update EndTime, Duration, and optional running stats.
  ev.close(endTime, finalStats) mutates the SetAccess=private
  fields EndTime and Duration and optionally populates stats
  from a struct with fields {PeakValue, NumPoints, MinValue,
  MaxValue, MeanValue, RmsValue, StdValue}. Toggles IsOpen
  false. Called by EventStore.closeEvent.

#### `obj = escalateTo(obj, newLabel, newThresholdValue)`

ESCALATETOP Escalate event to a higher severity threshold.

#### `s = computeDisplayState(obj)`

COMPUTEDISPLAYSTATE Return the ISA-18.2 / EEMUA-191 three-state alarm visual state name.
  States:
    'unacked-active'  — event is still open (IsOpen=true) AND not acked
    'acked-active'    — event is still open AND acked (operator saw it but condition persists)
    'acked-cleared'   — event has been closed AND acked (normal happy-path closure)
    'unacked-cleared' — event closed but never acked (audit-trail anomaly; UI may render distinctly)

### Static Methods

#### `Event.ev = fromStructSafe(s)`

FROMSTRUCTSAFE Promote a struct (legacy or v4.0) to an Event instance with field defaults.
  Used by EventStore.getEvents() merge code AND by Phase 1033 consolidator
  to unify mixed struct/Event arrays.  Missing fields default safely:
    Identity   = struct()
    AckedAt    = []
    AckedBy    = struct()
    AckComment = ''
  (i.e., the same defaults as the property declarations).

---

## `EventStore` --- Atomic read/write of events to a shared .mat file.

> Inherits from: `handle`

Single-user mode (default):
    es = EventStore(filePath)
    es = EventStore(filePath, 'MaxBackups', 3)
  Events are stored in a MAT file via atomic temp+rename.  All
  existing tests exercise this path unchanged.

  Cluster mode (opt-in):
    es = EventStore(filePath, 'SharedRoot', sharedMountPath)
  Opens (or creates) <SharedRoot>/events/store.sqlite via mksqlite
  with journal_mode=DELETE + busy_timeout=10000 + locking_mode=NORMAL.
  All cluster writes use BEGIN IMMEDIATE + application-level retry on
  'database is locked' (see STACK.md §2, PITFALLS Pitfall 6).
  The local-per-user FastSenseDataStore continues to use WAL — only
  the cluster-mode EventStore switches to rollback mode.

  Errors (cluster mode only):
    EventStore:mksqliteUnavailable — mksqlite MEX not compiled
    EventStore:notClusterMode      — cluster method called in single-user mode
    EventStore:invalidAckRecord    — rec is not a scalar struct
    EventStore:appendAckFailed     — INSERT retries exhausted on database lock
    EventStore:retryExhausted      — busyRetryWrap_ ran 10 attempts and still hit 'database is locked'
    EventStore:mergeShapeMismatch  — getEvents cluster-merge could not concatenate heterogeneous shapes (warning, not error)

  busyRetryWrap_ is exposed as a public Static method so that test harnesses
  can call it with synthetic fn arguments.  In production it is called only
  from within EventStore cluster-mode transactions.

### Constructor

```matlab
obj = EventStore(filePath, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| FilePath | `''` |  |
| MaxBackups | `5` |  |
| PipelineConfig | `struct()` |  |
| SensorData | `[]` | struct array: name, t, y (for EventViewer click-to-plot) |
| ThresholdColors | `struct()` | serialized threshold colors struct |
| Timestamp | `[]` | datetime: when events were saved |

### Methods

#### `append(obj, newEvents)`

#### `events = getEvents(obj)`

GETEVENTS Return all events.
  Single-user mode: returns in-memory events_ (unchanged from pre-plan).
  Cluster mode: merges in-memory events_ with per-tag NDJSON logs under
  <sharedRoot>/events/*.events.ndjson via EventLogReader.readAll().
  Best-effort merge — if NDJSON read fails, falls back to in-memory only.

#### `closeEvent(obj, eventId, endTime, finalStats)`

CLOSEEVENT Close an open event in place.
  es.closeEvent(eventId, endTime, finalStats) locates an open
  Event by Id, delegates to ev.close(endTime, finalStats) for
  the in-place mutation, and returns. finalStats may be []
  (empty) to skip stats update. Does NOT call save() — consumers
  decide when to persist (Pitfall 2).

#### `events = getEventsForTag(obj, tagKey)`

GETEVENTSFORTAG Return events bound to tagKey via EventBinding + carrier fallback.
  Primary path: uses EventBinding.getEventsForTag for events
  with non-empty Id (Phase 1010 EVENT-01/EVENT-03).
  Fallback path: carrier-field matching (SensorName/ThresholdLabel)
  for events without Id (backward compat, Pitfall 4).
  Cluster mode: merges the in-memory/EventBinding result with events from
  the per-tag NDJSON log (<sharedRoot>/events/<tagKey>.events.ndjson).

#### `save(obj)`

#### `n = numEvents(obj)`

#### `appendAckRecord(obj, rec)`

APPENDACKRECORD Insert an ack/comment row in cluster mode.
  rec — struct with fields: eventId (char), by_user (char),
        by_host (char), epoch (double), comment (char, optional)

#### `rows = getAckRecords(obj)`

GETACKRECORDS Return all ack rows from cluster-mode store.
  Returns a struct array with fields: event_id, by_user, by_host,
  epoch, comment.  Cluster mode only.

#### `ack = acknowledgeEvent(obj, eventId, opts)`

ACKNOWLEDGEEVENT Record an acknowledgement for an event (ACK-01/03 + IDENT-02).
  ack = es.acknowledgeEvent(eventId, opts)

#### `rows = getAckRecordsForEvent(obj, eventId)`

GETACKRECORDSFOREVENT Return ack records for a specific event.
  Single-user: filters obj.acks_; cluster: queries SQLite WHERE event_id = ?.

### Static Methods

#### `EventStore.[events, meta, changed] = loadFile(filePath)`

#### `EventStore.out = busyRetryWrap_(fn)`

BUSYRETRYWRAP_ Generalised SQLite "database is locked" retry loop (Pitfall 6).
  out = EventStore.busyRetryWrap_(@() doSomeMksqliteTransaction())

#### `EventStore.out = mergeEventStructs_(a, b)`

MERGEEVENTSTRUCTS_ Concatenate two event collections tolerating shape heterogeneity.
  Best-effort concatenation — if types are incompatible (Event handle vs struct),
  returns a unchanged with a warning.  Phase 1033's snapshot consolidator will
  unify the shape canonically.

---

## `EventViewer` --- Figure-based event viewer with Gantt timeline and filterable table.

> Inherits from: `handle`

viewer = EventViewer(events)
  viewer = EventViewer(events, sensorData)
  viewer = EventViewer(events, sensorData, thresholdColors)
  viewer.update(newEvents)

### Constructor

```matlab
obj = EventViewer(events, sensorData, thresholdColors)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Events |  | Event array |
| SensorData |  | struct array: name, t, y (for click-to-plot) |
| ThresholdColors |  | containers.Map: label -> [R G B] |
| hFigure |  | figure handle |
| BarPositions |  | Nx4 matrix: [x, y, w, h] cached from drawTimeline |
| BarRects |  | rectangle handles for hover detection |
| BarEvents |  | Event objects corresponding to BarRects |

### Methods

#### `update(obj, events)`

UPDATE Refresh the viewer with new events.

#### `names = getSensorNames(obj)`

GETSENSORNAMES Get unique sensor names from events.

#### `labels = getThresholdLabels(obj)`

GETTHRESHOLDLABELS Get unique threshold labels from events.

#### `refreshFromFile(obj)`

REFRESHFROMFILE Reload events from the source .mat file.

#### `startAutoRefresh(obj, interval)`

STARTAUTOREFRESH Start polling the source file at given interval.
  obj.startAutoRefresh(5)  % refresh every 5 seconds

#### `stopAutoRefresh(obj)`

STOPAUTOREFRESH Stop the auto-refresh timer.

### Static Methods

#### `EventViewer.viewer = fromFile(filepath)`

FROMFILE Open EventViewer from a saved .mat event store file.
  viewer = EventViewer.fromFile('events.mat')

---

## `LiveEventPipeline` --- Orchestrates live event detection.

> Inherits from: `handle`

Uses MonitorTargets — containers.Map of key -> MonitorTag;
  processed via MonitorTag.appendData (Phase 1007 MONITOR-08
  streaming tail extension).

  Ordering invariant (Pitfall Y) — enforced by processMonitorTag_:
    monitor.Parent.updateData(newX, newY)  <- called FIRST
    monitor.appendData(newX, newY)         <- THEN
  The reverse order causes cache incoherence: MonitorTag.appendData's
  cold path recomputes against a stale parent grid.  See the docstring
  at libs/SensorThreshold/MonitorTag.m lines 330-334 for the contract.

  Cluster mode (Phase 1032, Plan 02):
    - Enabled by passing 'SharedRoot' NV-pair to constructor.
    - processMonitorTag_ acquires the per-monitor FileLock via
      TagWriteCoordinator BEFORE parent.updateData + monitor.appendData.
    - On lock contention (ok=false), the monitor is skipped this tick;
      SkippedMonitorCount is incremented and LastLockContentionEvent is
      populated.
    - BusyMode='drop' is forced in cluster-mode timer (Pitfall 7).
    - EventLog handles are wired into each MonitorTag at construction
      so MonitorTag.emitEvent_ routes cluster-mode writes to the NDJSON log.
    - Single-user mode (no SharedRoot) exercises ZERO Concurrency-library
      code paths (byte-identical guarantee).

  Cluster-mode observability:
    SkippedMonitorCount      — incremented on lock contention per-monitor per-tick
    LastTickDurationSec      — wall-clock duration of most recent runCycle
    LastLockContentionEvent  — {tagKey, holder.{user,host,age}} struct for Phase 1033 UI

### Constructor

```matlab
obj = LiveEventPipeline(monitors, dataSourceMap, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| MonitorTargets |  | containers.Map: key -> MonitorTag |
| DataSourceMap |  | DataSourceMap |
| EventStore |  | EventStore |
| NotificationService |  | NotificationService |
| Interval | `15` | seconds |
| Status | `'stopped'` |  |
| MinDuration | `0` |  |
| EscalateSeverity | `true` |  |
| MaxCallsPerEvent | `1` |  |
| OnEventStart | `[]` |  |

### Methods

#### `start(obj)`

#### `stop(obj)`

#### `runCycle(obj)`

RUNCYCLE Execute one poll cycle synchronously (exposed for tests + timer callback).
  Phase 1032-02: tic/toc for LastTickDurationSec (Pitfall 7 ops surface);
  drawnow limitrate nocallbacks in cluster mode (Pitfall 7 reentrancy guard).

---

## `NotificationService` --- Rule-based email notifications with event snapshots.

> Inherits from: `handle`

### Constructor

```matlab
obj = NotificationService(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Rules | `[]` |  |
| DefaultRule | `[]` |  |
| Enabled | `true` |  |
| DryRun | `false` |  |
| SnapshotDir | `''` |  |
| SnapshotRetention | `7` | days |
| SmtpServer | `''` |  |
| SmtpPort | `25` |  |
| SmtpUser | `''` |  |
| SmtpPassword | `''` |  |
| FromAddress | `'fastsense@noreply.com'` |  |
| NotificationCount | `0` |  |

### Methods

#### `addRule(obj, rule)`

#### `setDefaultRule(obj, rule)`

#### `rule = findBestRule(obj, event)`

#### `notify(obj, event, sensorData)`

#### `cleanupSnapshots(obj)`

---

## `NotificationRule` --- Configures notification for sensor/threshold events.

> Inherits from: `handle`

### Constructor

```matlab
obj = NotificationRule(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| SensorKey | `''` |  |
| ThresholdLabel | `''` |  |
| Recipients | `{{}}` |  |
| Subject | `'Event: {sensor} - {threshold}'` |  |
| Message | `'{sensor} exceeded {threshold} ({direction}) at {startTime}. Peak: {peak}'` |  |
| IncludeSnapshot | `true` |  |
| ContextHours | `2` |  |
| SnapshotPadding | `0.1` |  |
| SnapshotSize | `[800, 400]` |  |

### Methods

#### `score = matches(obj, event)`

Returns match score: 3=sensor+threshold, 2=sensor, 1=default, 0=no match

#### `txt = fillTemplate(~, template, event)`

---

## `DataSource` --- Abstract interface for fetching new sensor data.

> Inherits from: `handle`

Subclasses must implement fetchNew() which returns a struct:
    .X       — 1xN datenum timestamps
    .Y       — 1xN (or MxN) values
    .stateX  — 1xK datenum state timestamps (empty if none)
    .stateY  — 1xK state values (empty if none)
    .changed — logical, true if new data since last call

### Methods

#### `result = fetchNew(obj)`

### Static Methods

#### `DataSource.result = emptyResult()`

---

## `MatFileDataSource` --- Reads sensor data from a continuously-updated .mat file.

> Inherits from: `DataSource`

### Constructor

```matlab
obj = MatFileDataSource(filePath, varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| FilePath | `''` |  |
| XVar | `'X'` |  |
| YVar | `'Y'` |  |
| StateXVar | `''` |  |
| StateYVar | `''` |  |

### Methods

#### `result = fetchNew(obj)`

---

## `DataSourceMap` --- Maps sensor keys to DataSource instances.

> Inherits from: `handle`

### Constructor

```matlab
obj = DataSourceMap()
```

### Methods

#### `add(obj, key, dataSource)`

#### `ds = get(obj, key)`

#### `k = keys(obj)`

#### `tf = has(obj, key)`

#### `remove(obj, key)`

---

## `EventBinding` --- Singleton many-to-many registry binding Events to Tags.

EventBinding stores (eventId, tagKey) pairs using two persistent
  containers.Map indexes (forward: eventId -> {tagKeys}, reverse:
  tagKey -> {eventIds}) for O(1) lookup in both directions.

  This is the single-write-side for Event-Tag binding (EVENT-02).
  Only EventBinding.attach mutates the registry. Convenience wrappers
  on Event/Tag/EventStore delegate to this class.

### Static Methods

#### `EventBinding.attach(eventId, tagKey)`

ATTACH Bind an event to a tag (idempotent).
  EventBinding.attach(eventId, tagKey) adds the (eventId, tagKey)
  pair to both forward and reverse indexes. Silent on duplicate.

#### `EventBinding.keys = getTagKeysForEvent(eventId)`

GETTAGKEYSFOREVENT Return cell of tagKey strings bound to eventId.

#### `EventBinding.events = getEventsForTag(tagKey, eventStore)`

GETEVENTSFORTAG Return Event array bound to tagKey via reverse index.
  Uses the reverse index for O(1) lookup of eventIds, then
  filters the eventStore's events by matching Id.

#### `EventBinding.clear()`

CLEAR Reset all bindings in both forward and reverse indexes.

---

## `MockDataSource` --- Generates realistic industrial sensor signals for testing.

> Inherits from: `DataSource`

### Constructor

```matlab
obj = MockDataSource(varargin)
```

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| BaseValue | `100` |  |
| NoiseStd | `1` |  |
| DriftRate | `0` | drift per second |
| SampleInterval | `3` | seconds between points |
| BacklogDays | `3` | days of history on first fetch |
| ViolationProbability | `0.005` | chance per point of starting violation |
| ViolationAmplitude | `20` | how far signal ramps beyond base |
| ViolationDuration | `60` | seconds per violation episode |
| StateValues | `{{}}` | cell of char, e.g. {'idle','running'} |
| StateChangeProbability | `0.001` | chance per point of state transition |
| Seed | `[]` | optional RNG seed |
| PipelineInterval | `15` | seconds per fetch cycle |

### Methods

#### `result = fetchNew(obj)`

