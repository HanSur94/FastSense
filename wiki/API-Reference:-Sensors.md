<!-- AUTO-GENERATED from source code by scripts/generate_api_docs.py — do not edit manually -->

# API Reference: Sensors

## `BatchTagPipeline` --- Synchronous raw-data -> per-tag .mat pipeline.

> Inherits from: `handle`

Enumerates TagRegistry for ingestable tags (SensorTag/StateTag
  with a non-empty RawSource), de-duplicates file reads, parses
  each raw file once, slices the requested column per tag, and
  writes <OutputDir>/<tag.Key>.mat in the SensorTag.load shape.

  Batch semantics (D-12, D-15, D-18):
    - OutputDir required at construction; auto-created if missing.
    - run() returns a report struct; throws TagPipeline:ingestFailed
      at end-of-run if any tag failed.
    - Each tag's ingest is a try/catch boundary; one failing tag
      does NOT abort the batch.

  Observability (Major-2 / revision-1):
    - LastFileParseCount: public SetAccess=private property
      recording the number of DISTINCT raw files parsed in the
      most recent run(). Captured BEFORE the end-of-run cache
      reset. Enables testFileCacheDedup to assert exact dedup
      without wrapping readRawDelimited_ (blocked by MATLAB's
      private-folder scoping).

  Errors (namespaced under TagPipeline:*):
    TagPipeline:invalidOutputDir      -- OutputDir missing / empty
    TagPipeline:cannotCreateOutputDir -- mkdir failed
    TagPipeline:ingestFailed          -- 1+ tags failed (end-of-run throw)
    TagPipeline:unknownExtension      -- file ext not .csv/.txt/.dat

### Constructor

```matlab
obj = BatchTagPipeline(varargin)
```

BATCHTAGPIPELINE Construct with required OutputDir NV-pair.
  p = BatchTagPipeline('OutputDir', dir)
  p = BatchTagPipeline('OutputDir', dir, 'Verbose', true)

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| OutputDir | `''` |  |
| Verbose | `false` |  |

### Methods

#### `report = run(obj)`

RUN Enumerate tags, ingest each, write per-tag .mat; throw at end if any failed.
  Returns a report struct with fields:
    succeeded - cellstr of tag keys that wrote OK
    failed    - struct array of failed tags (key, file, errorId, message)

---

## `CompositeTag` --- Aggregate MonitorTag/CompositeTag children into a 0/1 derived series.

> Inherits from: `Tag`

CompositeTag < Tag -- a derived-signal Tag that aggregates 1..N
  MonitorTag/CompositeTag children into a single 0/1 (or 0..1
  severity-pre-threshold) time series via k-way merge-sort ZOH
  streaming (implemented in Plan 02; Plan 01 ships the core API only:
  constructor, addChild cycle-DFS + type-guard + listener hookup, and
  the 7-mode aggregator helper).

  Truth Table (binary 0/1 inputs; NaN = unknown):

    AND:
      | c1  | c2  | out  |
      |  0  |  0  |  0   |
      |  0  |  1  |  0   |
      |  1  |  1  |  1   |
      |  0  | NaN | NaN  |
      |  1  | NaN | NaN  |
      | NaN | NaN | NaN  |

    OR:
      | c1  | c2  | out  |
      |  0  |  0  |  0   |
      |  0  |  1  |  1   |
      |  1  |  1  |  1   |
      |  0  | NaN |  0   |   (other operand wins)
      |  1  | NaN |  1   |   (other operand wins)
      | NaN | NaN | NaN  |

    WORST:    max(vals) ignoring NaN; all-NaN -> NaN.  Matches
              MATLAB `max([...], 'omitnan')` semantics.
    COUNT:    sum of (vals >= 0.5) ignoring NaN; then thresholded
              by obj.Threshold to 0/1.
    MAJORITY: #ones > (#non-NaN)/2 -> 1; all-NaN -> NaN.  Strictly
              binary 0/1 inputs for v2.0 (multi-state deferred).
    SEVERITY: weighted avg (sum(w_i*v_i)/sum(w_i)) over non-NaN,
              then thresholded by obj.Threshold to 0/1.  All-NaN or
              zero-weight -> NaN.
    USER_FN:  obj.UserFn(vals) -- caller handles NaN semantics.

  Properties (public):
    AggregateMode -- 'and'|'or'|'majority'|'count'|'worst'|'severity'|'user_fn'
    UserFn        -- function_handle; required when mode=='user_fn'
    Threshold     -- double; for COUNT/SEVERITY binarization (default 0.5)

  Methods (public):
    addChild(tagOrKey, 'Weight', w) -- resolves string keys via TagRegistry;
                                       cycle DFS (Key-equality per RESEARCH §7);
                                       rejects SensorTag/StateTag
    invalidate() / addListener(m)   -- observer pattern (inherited shape)
    getChildCount / getChildKeys    -- read-only inspection probes
    getChildWeights / isDirty       -- read-only inspection probes
    getChildAt(i)                   -- i-th child Tag handle (3-deep descent)
    getKind()                       -- returns 'composite'

  Methods (Tag contract -- Plan 02 merge-sort + serialization):
    getXY()         -- lazy-memoized union-of-timestamps grid via
                       RESEARCH §5 vectorized sort-based merge
                       (no set union, no linear interpolation; ALIGN-03)
    valueAt(t)      -- COMPOSITE-06 fast path; aggregates
                       child.valueAt(t) without materializing series
    getTimeRange()  -- [X(1), X(end)] of the aggregated grid
    toStruct()      -- serialize to {kind, key, ..., childkeys,
                       childweights, aggregatemode, threshold}
    fromStruct(s)   -- Static Pass-1 ctor; stashes ChildKeys_ for Pass-2
    resolveRefs(r)  -- Pass-2 wiring; iterates ChildKeys_ and calls
                       obj.addChild(registry(k), 'Weight', w) per child

  Error IDs (locked):
    CompositeTag:cycleDetected        -- addChild would create cycle
                                         (self or deeper via Key-equality DFS)
    CompositeTag:invalidChildType     -- child is not MonitorTag/CompositeTag
    CompositeTag:invalidAggregateMode -- AggregateMode not in 7-mode list
    CompositeTag:userFnRequired       -- mode=='user_fn' but UserFn empty
    CompositeTag:unknownOption        -- constructor NV-pair unknown
    CompositeTag:invalidListener      -- addListener target lacks invalidate()
    CompositeTag:dataMismatch         -- fromStruct missing required .key
    CompositeTag:unresolvedChild      -- resolveRefs key not in registry
    CompositeTag:indexOutOfBounds     -- getChildAt index out of range

  Cycle-detection note (RESEARCH §7 / Pitfall 3 Octave SIGILL):
    CompositeTag EXPLICITLY creates listener cycles (addChild wires
    composite as listener on child).  Octave's `isequal`/`==` on
    user-defined handles recurses through listener cells and hits
    SIGILL.  Use Key equality (`strcmp(a.Key, b.Key)`) for all handle
    identity checks -- TagRegistry enforces globally-unique keys so
    Key equality is semantically equivalent to handle equality within
    a registry session AND Octave-safe.

### Constructor

```matlab
obj = CompositeTag(key, aggregateMode, varargin)
```

COMPOSITETAG Construct a CompositeTag with aggregation mode + Tag NV pairs.
  c = CompositeTag(key)                       -- mode defaults to 'and'
  c = CompositeTag(key, mode)                 -- mode in the 7-mode set
  c = CompositeTag(key, mode, NV, NV, ...)    -- Tag + CompositeTag NV pairs

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| AggregateMode | `'and'` | 'and'\|'or'\|'majority'\|'count'\|'worst'\|'severity'\|'user_fn' |
| UserFn | `[]` | function_handle; required for 'user_fn' |
| Threshold | `0.5` | for COUNT/SEVERITY binarization |

### Methods

#### `addChild(obj, tagOrKey, varargin)`

ADDCHILD Attach a MonitorTag/CompositeTag child with optional Weight.
  addChild(tagHandle)               -- handle path
  addChild('keyString')             -- registry-resolved path
  addChild(tagOrKey, 'Weight', w)   -- SEVERITY-mode weight (default 1.0)

#### `invalidate(obj)`

INVALIDATE Clear cache + mark dirty; cascade to downstream listeners.

#### `addListener(obj, m)`

ADDLISTENER Register a listener notified when this composite invalidates.
  Errors: CompositeTag:invalidListener if ~ismethod(m, 'invalidate').

#### `n = getChildCount(obj)`

GETCHILDCOUNT Return the number of attached children.

#### `keys = getChildKeys(obj)`

GETCHILDKEYS Return a cellstr of child Keys (order preserved).

#### `w = getChildWeights(obj)`

GETCHILDWEIGHTS Return a numeric row vector of child weights.

#### `tf = isDirty(obj)`

ISDIRTY Return whether the composite cache is stale.

#### `k = getKind(~)`

GETKIND Return the literal kind identifier 'composite'.

#### `[x, y] = getXY(obj)`

GETXY Lazy-memoized union-of-timestamps grid via merge-sort streaming.
  Aggregates every child's (X, Y) via the RESEARCH §5
  vectorized sort-based algorithm (no set-union, no linear
  interpolation).  Drops samples before `max(child.X(1))`
  per ALIGN-03.  Cache stays warm across calls; invalidate()
  (cascade from any child) clears it.

#### `v = valueAt(obj, t)`

VALUEAT COMPOSITE-06 fast-path -- aggregate child.valueAt(t).
  Iterates children and aggregates their instantaneous
  scalar values; NEVER materializes the full series.  Does
  NOT increment recomputeCount_ and does NOT warm the cache.
  At N=8 children, depth 3, log(M)=17 -> ~400 ops per call
  (sub-microsecond vs. ~150ms for a full getXY).

#### `[tMin, tMax] = getTimeRange(obj)`

GETTIMERANGE Return [X(1), X(end)] of the aggregated grid.
  Warms the merge-sort cache if cold.  Returns [NaN NaN] when
  there are no children or any child has no data.

#### `s = toStruct(obj)`

TOSTRUCT Serialize CompositeTag to a plain struct.
  Emits {kind='composite', key, name, labels, metadata,
  criticality, units, description, sourceref, aggregatemode,
  threshold, childkeys, childweights}.  UserFn is NOT
  serialized (function handles cannot round-trip); consumers
  must re-bind UserFn after loadFromStructs for 'user_fn' mode.
  childkeys is double-wrapped (cell-in-cell) to survive the
  MATLAB struct() cellstr-collapse idiom; fromStruct unwraps.

#### `resolveRefs(obj, registry)`

RESOLVEREFS Pass-2 hook -- wire stashed ChildKeys_ via addChild.
  Called by TagRegistry.loadFromStructs (and local two-pass
  loaders during Plan 02 tests).  Re-uses the validated
  addChild path so type guard + cycle DFS + listener hookup
  all run on deserialized children.

#### `tag = getChildAt(obj, i)`

GETCHILDAT Return the Tag handle of the i-th child (1-based).
  Test-affordance API for 3-deep descent assertions
  (Pitfall 8 round-trip).  Not a mutation path -- child
  insertion goes through addChild.

### Static Methods

#### `CompositeTag.out = aggregateForTesting(vals, weights, mode, userFn, threshold)`

AGGREGATEFORTESTING Public test-probe wrapper over private aggregate_.
  Exists SOLELY so suite/flat tests can exercise the truth
  tables without materializing a full CompositeTag + children
  graph.  Not part of the stable public API -- consumers
  should use getXY() / valueAt() instead (Plan 02).

#### `CompositeTag.obj = fromStruct(s)`

FROMSTRUCT Pass-1 reconstruction from a toStruct output.
  Constructs an empty-children CompositeTag and stashes
  `ChildKeys_` + `ChildWeights_` for Pass-2 `resolveRefs` to
  consume.  UserFn is NOT restored -- consumers re-bind it
  after loadFromStructs for 'user_fn' mode.

---

## `LiveTagPipeline` --- Timer-driven raw-data -> per-tag .mat pipeline.

> Inherits from: `handle`

Mirrors MatFileDataSource's modTime + lastIndex state machine
  over raw text files. Does NOT subclass LiveEventPipeline (D-14)
  -- borrows the timer ergonomics only.

  Live semantics (D-13, D-14, D-18):
    - Each tick re-enumerates TagRegistry, stats each tag's RawSource.file.
    - Files with advanced mtime are re-parsed ONCE (per-tick file cache).
    - New rows (lastIndex+1 : total) are appended to <OutputDir>/<tag.Key>.mat.
    - Append uses load->concat->save (Pitfall 2 guard); the writer
      never uses the dash-append flag of save (which would clobber
      the existing `data` variable rather than merge its fields).
    - Per-tag try/catch: one tag's failure does NOT abort the tick.
    - tagState_ entries GC'd each tick for tags no longer eligible.

  Observability (Major-2 / revision-1):
    - LastFileParseCount: public SetAccess=private property recording the
      number of DISTINCT files parsed in the most recent tick. Captured
      BEFORE the per-tick tickCache goes out of scope. Mirrors
      BatchTagPipeline's mechanism so tests can assert dedup behavior
      via direct property read rather than wrapping readRawDelimited_.

  Shares readRawDelimited_ / selectTimeAndValue_ / writeTagMat_ with
  BatchTagPipeline -- single source of truth for parse + shape + write.

### Constructor

```matlab
obj = LiveTagPipeline(varargin)
```

LIVETAGPIPELINE Construct with OutputDir (required) + options.
  p = LiveTagPipeline('OutputDir', dir)
  p = LiveTagPipeline('OutputDir', dir, 'Interval', 5, 'Verbose', true)
  p = LiveTagPipeline('OutputDir', dir, 'ErrorFcn', @(ex) ...)

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| OutputDir | `''` |  |
| Interval | `15` | seconds |
| Status | `'stopped'` | 'stopped' \| 'running' \| 'error' |
| ErrorFcn | `[]` | optional @(ex) callback for tick-level errors |
| Verbose | `false` |  |

### Methods

#### `start(obj)`

START Launch the polling timer and set Status='running'.

#### `stop(obj)`

STOP Halt the polling timer; mirrors the pattern used by the
  live-event pipeline class in libs/EventDetection/.
  Pitfall 8 -- guard with isvalid + try/catch so stop()
  during an in-flight tick doesn't cascade errors.

#### `tickOnce(obj)`

TICKONCE Run one tick synchronously (exposed for tests).
  Production callers use start()/stop(); tests call this
  to avoid pausing for timer intervals.

#### `n = get()`

GET.TAGSTATECOUNT Dependent property exposing tagState_.Count.
  RESEARCH Q3 observability -- lets tests verify that entries
  for unregistered tags are GC'd between ticks.

---

## `MonitorTag` --- Derived 0/1 binary time-series Tag — lazy-by-default, no persistence.

> Inherits from: `Tag`

MonitorTag produces a binary alarm/ok signal by evaluating a
  user-supplied ConditionFn against its Parent tag's (X, Y). Output
  is cached on first read and recomputed only when invalidate() is
  called (directly or via parent.updateData listener notification).

  This Phase 1006 implementation is lazy-by-default, no persistence —
  no FastSense data store writes, no disk footprint. Opt-in persistence
  arrives in Phase 1007 (MONITOR-09).

  MONITOR-05 note: Phase 1006 (later plans) uses the existing Event
  carrier fields SensorName = Parent.Key and ThresholdLabel = obj.Key.
  Phase 1010 (EVENT-01) will migrate to a per-Tag keys field on Event.
  Do NOT write a TagKeys field in this class — it does not exist on
  Event yet (the carrier pattern uses SensorName + ThresholdLabel).

  MONITOR-10: Only event-level callbacks (OnEventStart, OnEventEnd)
  are supported. Per-sample callbacks are a documented anti-pattern
  (PI-AF side-effect pitfall). This class MUST NOT expose keywords
  whose shape is a per-sample callback.

  ALIGN: operates directly on parent's native grid via parent.getXY().
  No interp1 linear ever — ZOH is the only legal alignment when
  aggregating across parents (CompositeTag in a later phase will
  re-assert this contract via valueAt-on-common-grid).

  Lifecycle: MonitorTag holds a Parent handle; Parent holds a strong
  reference to MonitorTag via its listeners_ cell. To dispose,
  unregister the monitor via TagRegistry.unregister AND reset the
  parent's listener cell (or construct a fresh parent).

  Properties (public):
    Parent               — Tag handle (required at construction)
    ConditionFn          — function_handle @(x,y)->logical (required)
    AlarmOffConditionFn  — function_handle; [] means no hysteresis
    MinDuration          — native parent-X units; 0 disables debounce
    EventStore           — EventStore handle; [] disables event emission
    OnEventStart         — function_handle @(event); [] disables
    OnEventEnd           — function_handle @(event); [] disables
    Persist              — logical; when true, derived (X, Y) is
                           cached to DataStore via storeMonitor on
                           every recompute_()/appendData() and loaded
                           on first getXY() (staleness-checked via
                           quad-signature). Default false — the opt-in
                           default enforces Pitfall 2 cache-invalidation
                           discipline: consumers that do not opt in
                           pay zero disk cost.
    DataStore            — FastSenseDataStore handle; required when
                           Persist=true. Provides storeMonitor /
                           loadMonitor / clearMonitor back-end.

  Methods (Tag contract):
    getXY                — lazy-memoized 0/1 vector on parent's grid
    valueAt(t)           — ZOH lookup into getXY cache
    getTimeRange         — [X(1), X(end)]; [NaN NaN] if empty
    getKind              — returns 'monitor'
    toStruct             — serialize (no function handles, no data)
    fromStruct (Static)  — Pass-1 reconstruction (dummy parent)
    resolveRefs(registry)— Pass-2 wire Parent + register listener

  Methods (additional):
    invalidate           — clear cache + mark dirty
    appendData(newX,newY) — Phase 1007 (MONITOR-08) streaming tail.
                            Extends cache incrementally; preserves
                            hysteresis FSM state and MinDuration
                            bookkeeping across the append boundary.
                            Falls back to full recompute_() when
                            the cache is dirty/empty (cold start).

  Error IDs:
    MonitorTag:invalidParent            — parentTag not a Tag
    MonitorTag:invalidCondition         — conditionFn not a function_handle
    MonitorTag:unknownOption            — unknown NV key or dangling key
    MonitorTag:dataMismatch             — fromStruct missing required fields
    MonitorTag:unresolvedParent         — Pass-2 parent key not in registry
    MonitorTag:invalidData              — appendData numeric/length mismatch
    MonitorTag:persistDataStoreRequired — Persist=true but DataStore empty

  Persistence (Phase 1007 MONITOR-09):
    Opt-in via Persist=true + DataStore. Staleness detection uses a
    quad-signature (parent_key, num_points, parent_xmin, parent_xmax)
    stamped at write. Default-off preserves Pitfall 2 cache-invalidation
    safety — consumers that do not opt in pay zero disk cost.

### Constructor

```matlab
obj = MonitorTag(key, parentTag, conditionFn, varargin)
```

MONITORTAG Construct a MonitorTag.
  m = MonitorTag(key, parentTag, conditionFn) creates a lazy
  binary monitor whose output is conditionFn(parentTag.X,
  parentTag.Y) aligned to parent's native grid.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Parent |  | Tag handle (required) |
| ConditionFn |  | function_handle @(x,y) -> logical (required) |
| AlarmOffConditionFn | `[]` | function_handle; [] means no hysteresis |
| MinDuration | `0` | native parent-X units; 0 disables debounce |
| OnEventStart | `[]` | function_handle @(event); [] disables callback |
| OnEventEnd | `[]` | function_handle @(event); [] disables callback |
| Persist | `false` | MONITOR-09 opt-in (Pitfall 2 default-off) |
| DataStore | `[]` | FastSenseDataStore handle; required when Persist=true |

### Methods

#### `[x, y] = getXY(obj)`

GETXY Return lazy-memoized 0/1 vector aligned to parent's grid.
  When Persist=true + DataStore bound, first attempts a disk
  load via tryLoadFromDisk_ (quad-signature staleness check).
  On miss or stale cache, falls through to recompute_() and
  then persistIfEnabled_() writes the fresh row.

#### `v = valueAt(obj, t)`

VALUEAT ZOH lookup into the cached 0/1 series.
  Returns NaN if parent has no data.

#### `[tMin, tMax] = getTimeRange(obj)`

GETTIMERANGE Return [X(1), X(end)]; [NaN NaN] if empty.

#### `k = getKind(obj)`

GETKIND Return the kind identifier 'monitor'.

#### `s = toStruct(obj)`

TOSTRUCT Serialize MonitorTag state to a plain struct.
  Function handles are NOT serialized — consumers re-bind
  ConditionFn / AlarmOffConditionFn / EventStore / callbacks
  after loadFromStructs. The Parent handle is stored as its
  Key string (parentkey); resolveRefs wires the real handle
  in Pass 2 of the two-phase loader.

#### `resolveRefs(obj, registry)`

RESOLVEREFS Pass-2 hook to wire Parent from registry by key.
  Called by TagRegistry.loadFromStructs. On success:
    - obj.Parent is swapped to the real registry entry
    - obj registers itself as a listener on the real parent
    - obj.invalidate() clears any stale cache
    - obj.ParentKey_ is cleared (consumed)

#### `invalidate(obj)`

INVALIDATE Clear cache + mark dirty; cascade to downstream listeners.
  MonitorTag itself is observable: downstream MonitorTags
  (recursive chains) register as listeners and are invalidated
  here so that a root-parent update propagates through the
  full derivation chain.

#### `addListener(obj, m)`

ADDLISTENER Register a listener notified when this monitor invalidates.
  Enables recursive MonitorTag chains — an outer MonitorTag
  that wraps an inner MonitorTag registers as the inner's
  listener so that root-parent updates cascade through.

#### `appendData(obj, newX, newY)`

APPENDDATA Extend cached (X, Y) with new tail samples — no full recompute.
  Preserves hysteresis FSM state and MinDuration bookkeeping
  across the append boundary (MONITOR-08). Events fire only
  for runs that COMPLETE (reach a falling edge) inside newX:
  a run still open at the tail end is carried as state for
  the next appendData call; a run that was already open at
  the cache end and closes inside newX fires ONE event with
  StartTime = the original (carried) start.

#### `set()`

#### `set()`

#### `set()`

### Static Methods

#### `MonitorTag.obj = fromStruct(s)`

FROMSTRUCT Pass-1 reconstruction from a toStruct output.
  The real Parent handle is wired in Pass 2 via resolveRefs.
  ConditionFn / AlarmOffConditionFn / EventStore / callbacks
  are NOT restored — consumers must re-bind these after load.

---

## `SensorTag` --- Concrete Tag subclass for sensor time-series data.

> Inherits from: `Tag`

SensorTag is the primary sensor data carrier in the Tag-based domain
  model.  It stores time-series data (X, Y) directly and satisfies the
  Tag contract (getXY, valueAt, getTimeRange, getKind='sensor',
  toStruct, fromStruct).  Data-role methods (load, toDisk, toMemory,
  isOnDisk) operate on the inlined private properties.

  Properties (Dependent): DataStore -- read-only view of the disk store.

  Constructor accepts Tag universals (Name, Units, Description,
  Labels, Metadata, Criticality, SourceRef), sensor extras (ID,
  Source, MatFile, KeyName), and inline 'X'/'Y' data arrays.

### Constructor

```matlab
obj = SensorTag(key, varargin)
```

SENSORTAG Construct a SensorTag with inlined data storage.
  t = SensorTag(key) creates a SensorTag with the given key.

### Methods

#### `ds = get()`

GET.DATASTORE Return the disk-backed DataStore (read-only view).

#### `v = get()`

GET.X Read-only access to timestamps (backward-compat with legacy Sensor.X).

#### `v = get()`

GET.Y Read-only access to values (backward-compat with legacy Sensor.Y).

#### `v = get()`

GET.THRESHOLDS Always empty cell array (backward-compat stub).
  Legacy Sensor class exposed a Thresholds cell array of
  ThresholdRule handles. In the v2.0 Tag model, thresholds
  are expressed as MonitorTag children bound via TagRegistry
  — not as a nested collection on the sensor. Widgets that
  still read .Thresholds (GaugeWidget, StatusWidget) see an
  empty cell here and fall through to their "no thresholds"
  branch. Consumers should migrate to the TagRegistry +
  MonitorTag workflow for threshold behaviour.

#### `r = get()`

GET.RAWSOURCE Return the raw-data source binding (read-only view).
  Populated only for SensorTags whose 'RawSource' NV-pair was
  set at construction. Consumed by BatchTagPipeline /
  LiveTagPipeline to locate the raw file + column for this tag.

#### `[X, Y] = getXY(obj)`

GETXY Return X, Y by reference (zero-copy via COW).
  MATLAB copy-on-write guarantees no memory allocation until
  the caller mutates X or Y.

#### `v = valueAt(obj, t)`

VALUEAT Return Y at the last index where X <= t (ZOH, clamped).
  Returns NaN on empty data.

#### `[tMin, tMax] = getTimeRange(obj)`

GETTIMERANGE Return [X(1), X(end)].  [NaN NaN] if empty.

#### `k = getKind(obj)`

GETKIND Return the literal kind identifier 'sensor'.

#### `s = toStruct(obj)`

TOSTRUCT Serialize SensorTag state to a plain struct.
  Tag universals at the top level; sensor-specific extras
  nested under s.sensor (only when non-default) to keep the
  struct compact.  X/Y are INTENTIONALLY OMITTED -- runtime
  data, not serialization state.

#### `load(obj, matFile)`

LOAD Load sensor data from a .mat file.
  t.load() uses the already-configured MatFile.
  t.load(path) sets MatFile before loading.

#### `toDisk(obj)`

TODISK Move X/Y data to disk-backed FastSenseDataStore.
  Clears X_ and Y_ from memory after transfer.

#### `toMemory(obj)`

TOMEMORY Load disk-backed data back into memory.

#### `tf = isOnDisk(obj)`

ISONDISK True if sensor data is stored on disk.

#### `addListener(obj, m)`

ADDLISTENER Register a listener notified on underlying data change.
  Listener must implement an invalidate() method. Strong
  reference -- caller manages lifecycle.

#### `updateData(obj, X, Y)`

UPDATEDATA Replace X/Y data and fire listeners.

### Static Methods

#### `SensorTag.obj = fromStruct(s)`

FROMSTRUCT Reconstruct SensorTag from a toStruct output.

---

## `StateTag` --- Concrete Tag subclass for discrete state signals with ZOH lookup.

> Inherits from: `Tag`

StateTag models a piecewise-constant ("zero-order hold") time
  series representing a discrete system state (e.g., machine mode,
  recipe phase).  valueAt(t) returns the most recent known state
  value using a right-biased binary search on X.  Supports BOTH
  numeric and cellstr Y — semantics are byte-for-byte equivalent to
  legacy StateChannel.valueAt.  Adds StateTag:emptyState guard so
  unloaded tags produce a clean error instead of a bounds crash.

  Properties (public, in addition to Tag universals):
    X — 1xN sorted numeric: timestamps of state transitions
    Y — 1xN numeric OR 1xN cell of char: state values

  Methods:
    StateTag     — constructor (key + 'X','Y' + Tag universals)
    getXY        — return [X, Y] (pass-through)
    valueAt(t)   — ZOH lookup; scalar or vector t; numeric or cellstr Y
    getTimeRange — [X(1), X(end)]; [NaN NaN] if empty
    getKind      — returns 'state'
    toStruct     — serialize X, Y, plus Tag universals
    fromStruct   — static factory rebuilding StateTag from toStruct

  Error IDs:
    StateTag:emptyState     — valueAt on empty X/Y
    StateTag:unknownOption  — unknown constructor name-value key
    StateTag:dataMismatch   — fromStruct struct missing .key

### Constructor

```matlab
obj = StateTag(key, varargin)
```

STATETAG Construct a StateTag; delegates universals to Tag + parses X/Y + RawSource.
  Valid name-value keys: 'X', 'Y', 'RawSource', plus Tag universals
  (Name, Units, Description, Labels, Metadata, Criticality, SourceRef).
  Raises StateTag:unknownOption for unrecognized or dangling keys.
  Raises TagPipeline:invalidRawSource if RawSource is malformed.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| X | `[]` | 1xN numeric: sorted transition timestamps |
| Y | `[]` | 1xN numeric OR 1xN cell of char: state values |

### Methods

#### `r = get()`

GET.RAWSOURCE Return the raw-data source binding (read-only view).
  Populated only for StateTags whose 'RawSource' NV-pair was
  set at construction. Consumed by BatchTagPipeline /
  LiveTagPipeline to locate the raw file + column for this tag.

#### `[X, Y] = getXY(obj)`

GETXY Return [X, Y] data vectors (pass-through).

#### `val = valueAt(obj, t)`

VALUEAT Return state value at t using zero-order hold.
  Right-biased binary search on X: largest idx with X(idx)<=t,
  clamped to [1, N].  Supports scalar and vector t for both
  numeric and cellstr Y.  Raises StateTag:emptyState if X or
  Y is empty.  Semantics match StateChannel.valueAt byte-for-byte.

#### `[tMin, tMax] = getTimeRange(obj)`

GETTIMERANGE Return [X(1), X(end)]; [NaN NaN] if empty.

#### `k = getKind(obj)`

GETKIND Return the kind identifier 'state'.

#### `s = toStruct(obj)`

TOSTRUCT Serialize StateTag to a plain struct.
  Wraps cellstr Labels and cellstr Y once via {...} to survive
  MATLAB's struct() cellstr-collapse.  fromStruct unwraps.

#### `addListener(obj, m)`

ADDLISTENER Register a listener notified on underlying data change.
  Listener must implement an invalidate() method. Strong
  reference — caller manages lifecycle.

#### `updateData(obj, X, Y)`

UPDATEDATA Replace public X/Y and fire listeners (MONITOR-04).
  Additive API — does NOT touch constructor or getXY paths.
  Any registered MonitorTag or other listener receives an
  invalidate() call after the new data is installed.

### Static Methods

#### `StateTag.obj = fromStruct(s)`

FROMSTRUCT Reconstruct StateTag from a toStruct output.

---

## `Tag` --- Abstract base for the unified Tag domain model.

> Inherits from: `handle`

Tag is the root of the v2.0 domain hierarchy.  Subclasses
  (SensorTag, StateTag, MonitorTag, CompositeTag) provide concrete
  implementations of the six abstract-by-convention methods.

  Tag uses the Octave-safe "throw-from-base" abstract pattern:
  the base class provides stub methods that raise a notImplemented
  error, and subclasses override with concrete implementations.
  Do NOT use the Abstract-methods block pattern here — it has
  divergent semantics between MATLAB and Octave (see DataSource.m
  for the proven pattern used here).

  Tag Properties (public):
    Key         — char: unique identifier (required, non-empty)
    Name        — char: human-readable name (defaults to Key)
    Units       — char: measurement unit
    Description — char: free-text description
    Labels      — cellstr: cross-cutting classification (META-01)
    Metadata    — struct: open key-value bag (META-03)
    Criticality — char enum: 'low'|'medium'|'high'|'safety' (META-04)
    SourceRef   — char: optional provenance string

  Tag Methods (abstract-by-convention — subclass must implement):
    getXY               — return [X, Y] data vectors
    valueAt(t)          — return scalar value at time t
    getTimeRange        — return [tMin, tMax]
    getKind             — return kind string ('sensor'|'state'|'monitor'|'composite'|'mock')
    toStruct            — return serializable struct
    fromStruct (Static) — reconstruct from struct

  Tag Methods (default hooks — override when needed):
    resolveRefs(registry) — Pass-2 deserialization hook; default no-op

### Constructor

```matlab
obj = Tag(key, varargin)
```

TAG Construct a Tag with required key and optional name-value pairs.

### Properties

| Property | Default | Description |
|----------|---------|-------------|
| Key | `''` | char: unique identifier |
| Name | `''` | char: human-readable name |
| Units | `''` | char: measurement unit |
| Description | `''` | char: free-text description |
| Labels | `{}` | cellstr: cross-cutting classification |
| Metadata | `struct()` | struct: open key-value bag |
| Criticality | `'medium'` | char enum: 'low'\|'medium'\|'high'\|'safety' |
| SourceRef | `''` | char: optional provenance string |
| EventStore | `[]` | EventStore handle; [] disables event convenience methods |

### Methods

#### `set()`

SET.CRITICALITY Validate enum before assigning.

#### `[X, Y] = getXY(obj)`

GETXY Return [X, Y] data vectors.  Subclass must override.

#### `v = valueAt(obj, t)`

VALUEAT Return scalar value at time t.  Subclass must override.

#### `[tMin, tMax] = getTimeRange(obj)`

GETTIMERANGE Return [tMin, tMax] time bounds.  Subclass must override.

#### `k = getKind(obj)`

GETKIND Return kind string.  Subclass must override.

#### `s = toStruct(obj)`

TOSTRUCT Return serializable struct.  Subclass must override.

#### `resolveRefs(obj, registry)`

RESOLVEREFS Pass-2 hook for two-phase deserialization.
  Default: no-op.  CompositeTag (Phase 1008) will override to
  wire up children by key.  Leaf tags (Sensor/State/Monitor)
  do not need references resolved.

#### `addManualEvent(obj, tStart, tEnd, label, message)`

ADDMANUALEVENT Create a manual annotation event bound to this tag.
  tag.addManualEvent(tStart, tEnd, label, message) creates an Event
  with Category = 'manual_annotation' and TagKeys = {obj.Key},
  appends to the bound EventStore, and registers in EventBinding.

#### `events = eventsAttached(obj)`

EVENTSATTACHED Query events bound to this tag via EventBinding.
  Returns Event array (possibly empty). This is a query, NOT a
  stored property -- no Event handles on Tag (Pitfall 4).

### Static Methods

#### `Tag.obj = fromStruct(s)`

FROMSTRUCT Reconstruct a Tag from a struct.  Subclass must override.

---

## `TagRegistry` --- Singleton catalog of named Tag entities.

TagRegistry provides a centralized, persistent catalog of all
  known Tag objects in the v2.0 domain model.  It mirrors the
  ThresholdRegistry API for CRUD / query / introspection, with
  three intentional deltas:

    1. register() HARD-ERRORS on duplicate key (Pitfall 7).
       ThresholdRegistry silently overwrites — TagRegistry does
       not, to prevent subtle identity bugs when two different
       tags claim the same key.
    2. loadFromStructs() uses two-phase deserialization
       (Pitfall 8):
         Pass 1 — instantiate every tag with empty children.
         Pass 2 — call tag.resolveRefs(registry) on each.
       This is order-insensitive; no silent try/warn/skip.  Any
       resolveRefs failure is wrapped as TagRegistry unresolvedRef.
    3. findByKind() replaces findByDirection() because Tag is
       multi-kind (sensor | state | monitor | composite | mock).

  The catalog starts EMPTY on first use.

  TagRegistry Methods (Static, public):
    get             — retrieve Tag by key; errors if missing
    register        — add Tag to catalog; hard error on duplicate
    unregister      — remove Tag (silent no-op if missing)
    clear           — wipe catalog
    find            — tags matching predicate fn
    findByLabel     — tags carrying a given label (META-02)
    findByKind      — tags whose getKind() matches
    list            — print sorted keys + names to command window
    printTable      — detailed table (Key/Name/Kind/Criticality/Units/Labels)
    viewer          — uitable GUI (Octave-safe)
    loadFromStructs — two-phase JSON round-trip (TAG-06, TAG-07)
    instantiateByKind — dispatch s.kind -> the right fromStruct

### Static Methods

#### `TagRegistry.t = get(key)`

GET Retrieve a Tag by key.
  t = TagRegistry.get(key) returns the Tag stored under key.
  Throws TagRegistry unknownKey if not registered.

#### `TagRegistry.register(key, tag)`

REGISTER Add a Tag to the catalog (hard error on collision).
  TagRegistry.register(key, tag) stores tag under key.
  Unlike ThresholdRegistry (which silently overwrites), this
  registry HARD-ERRORS on collision with TagRegistry
  duplicateKey (Pitfall 7).  Call TagRegistry.unregister(key)
  first to replace an existing entry.

#### `TagRegistry.unregister(key)`

UNREGISTER Remove a Tag (silent no-op if missing).

#### `TagRegistry.clear()`

CLEAR Wipe the catalog.  Primarily for test isolation.

#### `TagRegistry.ts = find(predicateFn)`

FIND Return cell of Tags matching predicateFn(tag) -> logical.

#### `TagRegistry.ts = findByLabel(label)`

FINDBYLABEL Return cell of Tags carrying the given label (META-02).

#### `TagRegistry.ts = findByKind(kind)`

FINDBYKIND Return cell of Tags where getKind() == kind.

#### `TagRegistry.list()`

LIST Print sorted keys + names to command window.

#### `TagRegistry.printTable()`

PRINTTABLE Print Key/Name/Kind/Criticality/Units/Labels table.

#### `TagRegistry.hFig = viewer()`

VIEWER Open uitable GUI showing all registered tags (Octave-safe).

#### `TagRegistry.loadFromStructs(structs)`

LOADFROMSTRUCTS Two-phase JSON deserialization (TAG-06, Pitfall 8).
  Pass 1: instantiate every tag with empty children and
          register it via TagRegistry.register (so duplicate
          keys in the input surface as TagRegistry
          duplicateKey, and unknown kinds surface as
          TagRegistry unknownKind).
  Pass 2: call tag.resolveRefs(catalog) on every registered
          tag.  Any error raised during Pass 2 is wrapped
          and rethrown as TagRegistry unresolvedRef — never
          silently swallowed.

#### `TagRegistry.tag = instantiateByKind(s)`

INSTANTIATEBYKIND Dispatch fromStruct based on s.kind.
  Phase 1004 ships 'mock' and 'mockThrowingResolve' only
  (tests).  Phase 1005+ extends the switch for sensor,
  state, monitor, and composite kinds.

