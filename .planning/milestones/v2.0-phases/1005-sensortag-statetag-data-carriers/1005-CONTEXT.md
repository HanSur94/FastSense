# Phase 1005: SensorTag + StateTag (data carriers) - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure/retrofit phase — concrete Tag subclasses wrapping legacy data roles)

<domain>
## Phase Boundary

Port the raw-data half of the domain — `Sensor`'s data role and `StateChannel`'s ZOH lookup — into concrete Tag subclasses. Add a polymorphic `FastSense.addTag(tag)` dispatcher so users can plot raw sensor data and state channels via the new Tag API while every legacy path keeps working.

**In scope:**
- `SensorTag extends Tag` — raw (X, Y) data carrier; implements `getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, `fromStruct`; supports `load(matFile)`, `toDisk(store)`, `toMemory()`, `isOnDisk()`; `DataStore` property. Feature-equivalent to legacy `Sensor` for raw signal handling.
- `StateTag extends Tag` — zero-order-hold (ZOH) `valueAt(t)` lookup over discrete state transitions; X (timestamps) + Y (numeric or cell-array state values); `getKind() == 'state'`. Feature-equivalent to legacy `StateChannel`.
- `FastSense.addTag(tag)` — polymorphic dispatcher that routes by `tag.getKind()`:
  - `'sensor'` → existing line-rendering path (internally reuses `addLine` or equivalent)
  - `'state'` → existing band-rendering path (internally reuses `addBand` or equivalent)
  - Pitfall 1: **NO** `isa(tag, 'SensorTag')` switches — dispatch by `getKind()` string only
- `Tag.instantiateByKind(s)` extended with `'sensor'` and `'state'` cases so `TagRegistry.loadFromStructs` round-trips these subclasses

**Out of scope (later phases):**
- `MonitorTag` derived signals (Phase 1006/1007)
- `CompositeTag` aggregation (Phase 1008)
- Widget-level consumer migration (Phase 1009 — FastSenseWidget, StatusWidget, etc.)
- Event↔Tag binding (Phase 1010)
- Legacy-class deletion (Phase 1011 — Sensor.m, StateChannel.m STAY for now)

**Verification gates (from ROADMAP):**
- Pitfall 1 — `FastSense.addTag` has no `isa(t, 'SensorTag')` / `isa(t, 'StateTag')` branches. Dispatch by `tag.getKind()` only.
- Pitfall 5 — ≤15 files touched this phase. Legacy `Sensor.m` and `StateChannel.m` NOT edited. `FastSense.m` IS edited (add `addTag` method) but `addSensor` and `addLine`/`addBand` are byte-for-byte unchanged.
- Pitfall 9 (MEX wrapping cost) — `SensorTag.getXY()` returns references, not copies. Benchmark vs. legacy `Sensor.getXY` ≤5% regression for a 100k-point sensor.

</domain>

<decisions>
## Implementation Decisions

### File Organization
- `libs/SensorThreshold/SensorTag.m` — new
- `libs/SensorThreshold/StateTag.m` — new
- `libs/FastSense/FastSense.m` — EDITED (add `addTag` method only; `addLine`/`addSensor`/`addBand` unchanged)
- `libs/SensorThreshold/Tag.m` — EDITED (extend `instantiateByKind` with `'sensor'` and `'state'` cases)
- Tests dual-style per convention

### Wrapping Strategy (SensorTag vs Sensor)
- **Composition over inheritance** — SensorTag HAS-A Sensor, not IS-A. This lets SensorTag satisfy the Tag contract without pulling in Sensor's threshold-rule machinery.
- Internal `Sensor_` private property holds a delegate `Sensor` object for data storage (load/toDisk/toMemory/isOnDisk/X/Y access).
- Public surface is the Tag contract (`getXY`, `valueAt`, `getTimeRange`, `getKind`, `toStruct`, `fromStruct`) PLUS the data-API methods users need (`load`, `toDisk`, `toMemory`, `isOnDisk`).
- `getXY()` returns references to the delegate's X/Y arrays (no copy). MATLAB's copy-on-write semantics ensure no cost unless caller mutates.

### StateTag Implementation
- Stores X (timestamps, double column vector) and Y (state values — can be double OR cell array of chars per StateChannel precedent)
- `valueAt(t)` performs ZOH lookup:
  - For scalar t: find `i = find(X <= t, 1, 'last')`; return `Y(i)` (or `Y{i}` if cell)
  - For vector t: vectorized version via `interp1(X, 1:numel(X), t, 'previous')`
  - Matches `StateChannel.valueAt` semantics byte-for-byte (copy implementation from there)
- `getXY()` returns (X, Y) directly — no transformation
- `getKind() == 'state'`

### SensorTag Implementation
- `SensorTag(key, varargin)` — constructor accepts Tag name-value pairs (Name, Units, Labels, etc.) PLUS `'Data', sensorObj` or `'X', x, 'Y', y` for inline data
- `load(matFile)` — delegates to inner Sensor.load (or equivalent)
- `toDisk(store)`, `toMemory()`, `isOnDisk()` — delegate to inner Sensor
- `DataStore` property (public get, private set) — mirrors Sensor property of same name
- `getKind() == 'sensor'`
- `getXY()` returns (obj.Sensor_.X, obj.Sensor_.Y) — no copy
- `getTimeRange()` returns `[min(X), max(X)]` or delegate's time range

### FastSense.addTag Dispatcher
- New public method in FastSense.m:
  ```matlab
  function addTag(obj, tag, varargin)
      if ~isa(tag, 'Tag'), error('FastSense:invalidTag', ...); end
      kind = tag.getKind();
      switch kind
          case 'sensor'
              [x, y] = tag.getXY();
              obj.addLine(x, y, 'DisplayName', tag.Name, varargin{:});
          case 'state'
              % band rendering — use tag as ZOH state channel
              obj.addStateChannel(tag, varargin{:});  % or inline addBand logic
          otherwise
              error('FastSense:unsupportedTagKind', 'Unsupported tag kind: %s', kind);
      end
  end
  ```
- `addStateChannel(tag, varargin)` — private helper that extracts (X, Y) from StateTag and calls `addBand` for each state transition region. Reuses existing `addBand` logic.
- Uses `getKind()` switch — NO `isa()` branches (Pitfall 1).

### Tag.instantiateByKind Extension
- Extended with two new cases (keep `'mock'` for tests):
  ```matlab
  case 'sensor'
      tag = SensorTag(s.key);
      % fromStruct populates properties; delegate Sensor_ built separately if data present
  case 'state'
      tag = StateTag(s.key);
      % fromStruct populates X, Y, Labels, etc.
  ```

### Error IDs
- `SensorTag:dataMismatch`, `SensorTag:fileNotFound`, `SensorTag:invalidSource`
- `StateTag:dataMismatch`, `StateTag:emptyState`
- `FastSense:invalidTag`, `FastSense:unsupportedTagKind`

### Performance (Pitfall 9)
- `getXY()` returns delegate's arrays by handle access — MATLAB copy-on-write guarantees zero-copy when caller reads
- Benchmark task: 100k-point SensorTag vs legacy Sensor; compare `tic/toc` over 1000 `getXY` calls. Must be ≤5% slower.
- Benchmark file: `benchmarks/bench_sensortag_getxy.m` (or add to existing benchmarks/)

### Claude's Discretion
- Exact StateChannel valueAt semantics (copy from StateChannel source verbatim) — lock at research time
- Whether to implement `addStateChannel` as a new FastSense private helper or inline the logic in `addTag`
- Test assertion tolerances (time-range equality, ZOH lookup values)
- Private helper organization within `libs/SensorThreshold/private/` if needed

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `libs/SensorThreshold/Sensor.m` — raw data API (X, Y, load, toDisk, toMemory, isOnDisk, DataStore); SensorTag composes
- `libs/SensorThreshold/StateChannel.m` — ZOH lookup reference; copy `valueAt` implementation
- `libs/FastSense/FastSense.m:335` `addLine(x, y, varargin)` — sensor render path
- `libs/FastSense/FastSense.m:689` `addBand(yLow, yHigh, varargin)` — state render path (may need wrapper for ZOH-style state transitions)
- `libs/FastSense/FastSense.m:516` `addSensor(sensor, varargin)` — reference for name-value parsing; addTag follows same pattern
- Phase 1004 `libs/SensorThreshold/Tag.m` — base class; extends `instantiateByKind`
- Phase 1004 `libs/SensorThreshold/TagRegistry.m` — round-trip via `loadFromStructs` (verified working)

### Established Patterns
- Composition over inheritance for wrappers (matches DashboardWidget → FastSense relationship)
- Name-value constructor parsing via varargin loop
- `getKind()` string-based dispatch (established in Phase 1004)
- Dual-style tests (suite + flat)

### Integration Points
- FastSense.m gets ONE new method: `addTag(tag, varargin)` dispatching by `tag.getKind()`
- Tag.m `instantiateByKind` extended with 'sensor' and 'state' cases
- All existing `addSensor` callers continue working unchanged
- TagRegistry.loadFromStructs now round-trips SensorTag + StateTag correctly

</code_context>

<specifics>
## Specific Ideas

- Benchmark SensorTag.getXY against Sensor.getXY at 100k points (Pitfall 9 gate — ≤5% regression)
- `TestFastSenseAddTag` smoke test proves polymorphic dispatch works: construct one SensorTag and one StateTag, `addTag` both to the same FastSense instance, render, assert line + band are visible in the axes children
- `test_sensortag.m` must verify `load(matFile)` works (use one of the existing test fixtures)
- Verify no `isa()` calls inside `addTag` via `grep -c "isa(.*SensorTag\|isa(.*StateTag" libs/FastSense/FastSense.m` → 0

</specifics>

<deferred>
## Deferred Ideas

- MonitorTag (Phase 1006)
- CompositeTag (Phase 1008)
- Widget migration (Phase 1009)
- Event binding (Phase 1010)

</deferred>
