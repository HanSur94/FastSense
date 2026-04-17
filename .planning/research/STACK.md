# Stack Research — v2.0 Tag-Based Domain Model

**Domain:** Pure-MATLAB sensor-data dashboard engine — adding a Trendminer-style unified `Tag` root that retrofits Sensor / Threshold / StateChannel and adds MonitorTag (derived 0/1/severity time-series) and CompositeTag (aggregated tag) primitives, with events bound to tags.
**Researched:** 2026-04-16
**Confidence:** HIGH (verified against existing codebase patterns in `libs/SensorThreshold/`, `libs/Dashboard/DashboardWidget.m`, `libs/EventDetection/DataSource.m`, `libs/FastSense/FastSenseDataStore.m`, plus Octave classdef compatibility docs)

---

## Summary

**The existing pure-MATLAB toolchain is sufficient for v2.0. No new dependencies are required, and none should be added.** Every capability the milestone needs (abstract base contracts, key→object registry, derived time-series persistence, batched violation kernels, event-binding maps) already exists in the codebase. The right move is to *reuse* the proven primitives:

- `methods (Abstract)` for the `Tag` root (already in production via `DashboardWidget`)
- `containers.Map` for `TagRegistry` (already in production via `SensorRegistry` and `ThresholdRegistry`)
- `FastSenseDataStore` for `MonitorTag` derived-series persistence (chunked SQLite, already used by `Sensor.toDisk()`)
- Existing MEX kernels (`compute_violations_batch`, `binary_search_mex`, `to_step_function_mex`) for MonitorTag derivation
- Throw-on-base-method pattern (already in `DataSource.fetchNew`) as the Octave-safe fallback when `Abstract` quirks bite

**Anti-additions:** do NOT introduce `dictionary` (R2022b), do NOT pull in `matlab.mixin.Heterogeneous`, do NOT add a tag-graph database, do NOT add JSON-schema validators, do NOT spin up new MEX kernels for v2.0. Each is justified below.

---

## Recommended Stack

### Core Technologies (all pre-existing — KEPT, not added)

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| MATLAB `classdef` (handle classes) | R2020b+ | `Tag` abstract root + concrete subclasses (`SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`) | Identity semantics required for shared tag references across sensors/widgets/events; matches `Threshold`/`Sensor` pattern |
| `methods (Abstract)` block | R2008a / Octave 4.0+ (partial) | Declare contract methods on `Tag` root: `valueAt(t)`, `getRange(xMin, xMax)`, `getKey()` | Already in production: `DashboardWidget` declares `render`, `refresh`, `getType` as Abstract and works on Octave |
| `containers.Map` | All MATLAB / Octave 4.0+ | `TagRegistry` (single map, char→Tag handle) replacing `SensorRegistry` + `ThresholdRegistry` | Drop-in: identical API to existing registries; consolidating to one map removes parallel-singleton drift |
| `FastSenseDataStore` (SQLite via mksqlite) | Bundled | Persist `MonitorTag` derived (X, Y) signals identically to `SensorTag` raw data | Already chunk-indexed, WAL-mode, pyramid-cached; `toDisk()` round-trips work today; reuse means MonitorTag plots/zooms at SensorTag speed |
| `compute_violations_batch` (MEX + MATLAB fallback) | Bundled | MonitorTag derivation: condition + value-vs-threshold → 0/1/severity samples | Already produces `(X, Y)` violation pairs in batched groups; MonitorTag is structurally identical (one rule, full data range) |
| `binary_search_mex` | Bundled | Map event time-ranges to tag-data index ranges for overlay rendering | Already used in `Sensor.resolve()` segment lookup; same API works for event-band index math |
| `to_step_function_mex` | Bundled | MonitorTag step-function plotting (state stays at value until next change) | Existing kernel converts `(X, Y)` to step function; MonitorTag's 0/1 signal is a step function by nature |
| `methods (Static)` registries | All MATLAB / Octave 4.0+ | `TagRegistry.get/register/unregister/list/findByTag` | Already in production via `ThresholdRegistry`; same API surface |

### Supporting Libraries / Patterns (all pre-existing)

| Library | Purpose | When to Use in v2.0 |
|---------|---------|---------------------|
| `properties (Dependent)` | `Tag.Label` alias on `Name`, `Tag.IsUpper` on `Direction` | For backward-compat aliases inside Tag subclasses; partial Octave support already works for `Threshold.Label` |
| `properties (SetAccess = private)` | Cached fields like `CachedConditionKey`, `IsUpper`, derived `(X, Y)` for MonitorTag | Existing pattern from `ThresholdRule`; preserves invariants |
| `persistent` variable singleton | `TagRegistry.catalog()` cache | Existing pattern from both registries; survives across calls without globals |
| Throw-on-base-method (`error('Class:abstract', ...)`) | Defensive fallback for any abstract methods Octave fails to enforce | Existing pattern in `DataSource.fetchNew`; redundant with `methods (Abstract)` but cheap insurance |
| MATLAB timer (already wrapped by `DashboardEngine`) | Live MonitorTag refresh on the same tick as the dashboard | No new timer — MonitorTag derivation runs inside the existing `onLiveTick` single pass |
| `jsonencode` / `jsondecode` | Tag → struct → JSON round-trip for serialization | Already used by `DashboardSerializer` and `CompositeThreshold.toStruct/fromStruct`; same shape works for Tags |

### Development Tools (no change)

| Tool | Purpose | Notes |
|------|---------|-------|
| MISS_HIT (`mh_style`, `mh_lint`, `mh_metric`) | Style + complexity gate | No config changes; new `Tag*` classes follow existing PascalCase |
| `tests/run_all_tests.m` | Test runner | New `TestTag*.m` suites slot into the existing discovery |
| `install.m` | Path setup + MEX build | Unchanged — no new MEX, no new external deps to wire |

---

## Dependencies — Kept / Added / Not Added

### KEPT (no change)

| Dependency | Reason |
|------------|--------|
| MATLAB R2020b+ / Octave 7+ | Project invariant; nothing in v2.0 needs newer features |
| Bundled `mksqlite` + SQLite3 amalgamation | MonitorTag persistence reuses `FastSenseDataStore` |
| All eight existing MEX kernels (`lttb`, `minmax`, `compute_violations`, `binary_search`, `violation_cull`, `to_step_function`, `build_store`, `resolve_disk`) | MonitorTag derivation = scoped `compute_violations` over the full range; event-overlay index math = `binary_search`; step-plot = `to_step_function` |
| MATLAB built-ins: `containers.Map`, `classdef`, `properties (Dependent)`, `methods (Abstract)`, `methods (Static)`, `persistent`, `jsonencode`/`jsondecode`, MATLAB `timer` | All exercised in production today |

### ADDED

**None.** The v2.0 milestone does not require any new MATLAB toolboxes, MEX kernels, Python packages, or third-party libraries.

If anything is "added," it is purely *new MATLAB classes inside `libs/SensorThreshold/`* (the `Tag` hierarchy) — these are first-party source code, not dependencies.

### NOT ADDED (anti-dependencies — rationale matters for the roadmap)

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| MATLAB `dictionary` (R2022b+) | Project targets R2020b minimum; Octave has **no native `dictionary`** as of 11.1.0 (Feb 2026); only an external `datatypes` package provides one. Switching breaks the Octave invariant. | Stay on `containers.Map`. Existing perf is fine — registries are O(few-hundred) entries and lookups happen at config time, not in hot loops. |
| `matlab.mixin.Heterogeneous` | The Octave wiki explicitly does not implement heterogeneous classdef arrays. Using it for `Tag[]` arrays would silently break Octave. | Use `cell` arrays of `Tag` handles (current pattern: `Sensor.Thresholds = {}`). One indirection, fully compatible. |
| `matlab.mixin.Copyable` | Octave classdef mixin support is incomplete. Tags are *handles* by design (shared reference is the whole point of a registry); deep-copy is not a Tag-system requirement. | If a clone is ever needed, use the existing `toStruct` → `fromStruct` round-trip pattern (already used by `DashboardEngine` for widget detach mirrors). |
| `matlab.mixin.SetGet` | Same Octave compatibility risk. Adds no value here — public properties + `set.X` validators (already used in `CompositeThreshold.set.AggregateMode`) cover all needed validation. | Keep using `set.PropertyName` validator methods directly on the class. |
| `Sealed = true` class attribute | Octave classdef wiki confirms partial classdef-attribute support; behavior on `Sealed` is undocumented for the target Octave versions. The Tag hierarchy explicitly *needs* subclassing, so `Sealed` would be wrong anyway. | Don't seal. Document the contract in class header comments (existing convention). |
| Enumeration classes (`enumeration` block) | Octave parses `enumeration` blocks but does nothing with them. Using one for `AggregateMode` ('and'/'or'/'majority'/'count'/'severity') or `Direction` ('upper'/'lower') would silently no-op on Octave. | Use the existing `properties (Constant)` + `set.X` validator pattern (see `ThresholdRule.DIRECTIONS` and `CompositeThreshold.set.AggregateMode`). |
| `events`/`listeners` for tag-change notification | Octave wiki: events/listeners is "parsed but nothing done with it." Using listeners to invalidate caches when a child Tag changes will break on Octave. | Cache invalidation via explicit method calls (existing pattern: `Sensor.addThreshold` calls `obj.DataStore.clearResolved()` directly). The tag-update graph is shallow — the explicit pattern stays readable. |
| `validateattributes` / `arguments` blocks | `arguments` block is R2019b but Octave support is patchy. Existing codebase uses manual `switch varargin{i}` parsing everywhere. | Continue manual name-value parsing. Mirror the constructor pattern from `Sensor`/`Threshold`/`CompositeThreshold` exactly. |
| New MEX kernel for tag aggregation (CompositeTag AND/OR/MAJORITY) | The aggregation operation is *one logical pass over already-resolved child tags*. For typical N (a few dozen children at the leaf, hundreds at the root), MATLAB-vectorized `all`/`any`/`sum` is sub-millisecond. The mex-simd-opportunities-RESEARCH.md ranking already evaluated similar candidates and ranked aggregations LOW priority. | Pure MATLAB: `all(states == 1)` for AND, `any(...)` for OR, `sum(...)/n > 0.5` for MAJORITY. Add a MEX kernel later only if profiling on a real dashboard shows it dominant. |
| Tag-graph database (Neo4j, in-process graph lib) | The Tag DAG is small (≤ low thousands of nodes), in-memory, and traversed via direct handle references. A graph database would be overkill and would smash the "no external deps" invariant. | `containers.Map` + handle-class parent/child references. Walk via simple recursion (already done in `CompositeThreshold.computeStatus`). |
| JSON-schema validation library (e.g., MATLAB JSON Schema FX submission) | Tag schemas are stable, defined in code, and serialized/deserialized only by code we own. Round-trip tests are sufficient. | Existing `toStruct`/`fromStruct` pattern; defensive `isfield` checks (already done in `CompositeThreshold.fromStruct`). |
| New persistence backend (Parquet, HDF5, MAT v7.3) for MonitorTag | `FastSenseDataStore` already handles the same data shape (1-D time series of doubles), already chunks for OOM safety, already has WAL for live use, already has pyramid downsampling. Switching backends loses years of tuning. | Reuse `FastSenseDataStore` for MonitorTag derived signals — same constructor signature `(x, y)`. |
| Python event bus for tag-change propagation | Pulls in async + IPC complexity; v2.0 is single-process MATLAB. WebBridge stays scoped to read-only browser visualization. | Keep change propagation synchronous in MATLAB. The `DashboardEngine.onLiveTick` already coordinates per-tick updates. |

---

## Integration Points (How v2.0 Hooks Into Existing Stack)

### MEX kernel reuse

| Existing Kernel | v2.0 Use Case |
|-----------------|---------------|
| `compute_violations_batch` (MEX + MATLAB fallback in `libs/SensorThreshold/private/`) | **MonitorTag derivation core.** A MonitorTag is `(parentTag, condition, threshold)`. Derivation = run `compute_violations_batch` over the parent's full data, with one rule, then convert "violation indices" into a 0/1 (or severity) `Y` series. The kernel already returns `(violX, violY)` pairs; MonitorTag wraps that in a `(allX, derivedY)` series. |
| `compute_violations_disk` (MATLAB wrapper around the kernel) | MonitorTag over a disk-backed parent SensorTag. Already memory-safe (segment-by-segment). |
| `binary_search_mex` | Event ↔ tag binding: given an event with `(tStart, tEnd)`, find tag-data index range for overlay. Already the way `Sensor.resolve` does segment lookup. |
| `to_step_function_mex` | MonitorTag plot: 0/1 signal renders as a step function. Already the kernel used by `Sensor.resolve` for state-band rendering. |
| `lttb_core_mex`, `minmax_core_mex` | Downsampling MonitorTag plots in FastSense. No change — FastSense calls these on whatever `(X, Y)` the tag exposes via `getRange`. |
| `violation_cull_mex` | If MonitorTag is added as an overlay on a SensorTag plot, this kernel culls dense overlay markers. Already used by FastSense. |
| `resolve_disk_mex`, `build_store_mex` | MonitorTag persistence to `FastSenseDataStore` round-trip. Same path as `Sensor.toDisk()`. |

**Net new MEX kernels for v2.0: zero.** The tag system is a refactor + composition layer over already-MEX-accelerated primitives.

### `FastSenseDataStore` reuse for MonitorTag

`FastSenseDataStore(x, y)` is already used by `Sensor.toDisk()`. MonitorTag derived series have identical shape: 1-D `X` (datenum) + 1-D `Y` (double). The constructor signature works as-is. The pyramid + WAL + chunk-overlap-query infrastructure transfers verbatim.

**Edge cases to confirm during phase implementation:**
- MonitorTag's `Y` is binary {0,1} or low-cardinality {0,1,2}; the existing pyramid (designed for sensor-noise data) still works but is slightly wasteful. Acceptable — MonitorTag series are smaller than parent sensor series, so the wasted bytes are negligible.
- `addColumn`/`getColumn` API can store a "severity" column alongside the 0/1 signal if the milestone wants it.

### `containers.Map` for `TagRegistry`

Direct port of the existing `ThresholdRegistry` (which is itself a port of `SensorRegistry`). Combined: one `TagRegistry` replaces both. Same `catalog()` persistent-variable singleton, same `get`/`register`/`unregister`/`list`/`printTable`/`viewer` API. Add `findByType(cls)` and `findByTag(tagName)` (last word "tag" here means the Trendminer-style label, not the `Tag` object — minor naming overlap to flag for the roadmap).

### Abstract-class contract for `Tag` root

Use the **same dual-pattern** as the existing codebase:
1. Declare contract methods in `methods (Abstract)` block (works on MATLAB; partial on Octave per wiki bug #51377).
2. Provide a concrete base implementation that **throws** `error('Tag:abstract', 'getRange must be implemented by subclass')` — defensive fallback for Octave's partial enforcement. (This is exactly how `DataSource.fetchNew` is structured.)

Since the codebase already ships `DashboardWidget` with `methods (Abstract)` and runs on Octave 7+/9+ in CI, this pattern is **proven**, not speculative. The throw-fallback adds belt to the suspenders.

---

## Octave Compatibility Risks (Identified, with Mitigations)

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| `methods (Abstract)` not enforced on Octave for some attribute combinations (Octave bug #51377) | LOW (existing `DashboardWidget` works) | Subclass forgets to implement → silent NOOP at runtime | Pair Abstract block with concrete throw-stub in `Tag` base — established pattern in `DataSource.fetchNew` |
| Heterogeneous arrays of mixed Tag subclasses via `[t1, t2, t3]` | HIGH on Octave (no `matlab.mixin.Heterogeneous`) | Concatenation falls back to comma-list or errors | **Mandate cell arrays everywhere.** Existing pattern: `Sensor.Thresholds = {}`, `CompositeThreshold.children_ = {}`. Never use `[]` to collect Tag objects. |
| `properties (Dependent)` partial support | LOW (already works for `Threshold.Label`) | Some attribute combos fail | Keep dependent properties simple — single `get.X` returning a plain value. Avoid `Dependent + Constant` and similar exotic combinations. |
| `events`/listeners parsed-but-ignored | HIGH if used | Tag-change cascade silently breaks | Banned outright (see anti-dependencies above). Use explicit method calls for invalidation. |
| `enumeration` blocks parsed-but-ignored | HIGH if used | `AggregateMode` validation silently passes any string | Banned. Use `set.AggregateMode` validator (already pattern in `CompositeThreshold`). |
| `dictionary` type unavailable on Octave | CERTAIN | Code that uses it errors at parse time | Banned. Stay on `containers.Map`. |
| `arguments` blocks patchy on Octave | MEDIUM | Constructor arg validation diverges between MATLAB and Octave | Stick with manual name-value parsing (existing pattern in every constructor). |
| Handle identity check via `==` on Octave | LOW (works for `handle` subclasses) | Self-reference detection fails | Use `isequal(t, obj)` — already done in `CompositeThreshold.addChild` self-reference guard with the comment "isequal is used for Octave handle-identity safety". |

**Bottom line:** the Octave invariant is preserved by following the patterns already in the codebase. The risk vector is *deviating* from those patterns, not the new milestone scope itself.

---

## Native MATLAB Features for the Tag Root Contract — Recommendations

For the `Tag` abstract root contract, use these (all proven in the codebase or low-risk on Octave):

| Feature | Use For | Justification |
|---------|---------|---------------|
| `classdef Tag < handle` | Root class | Identity semantics required (registry shares references); `handle` works on Octave |
| `methods (Abstract)` block | Required interface methods (`valueAt`, `getRange`, `getKey`, `getDisplayName`) | Pattern proven in `DashboardWidget`; pair with throw-stubs for Octave belt-and-braces |
| `methods (Static)` `fromStruct` | Deserialization (subclasses override) | Existing pattern in `CompositeThreshold.fromStruct` |
| `properties (SetAccess = private)` | Cached fields (e.g., `CachedConditionKey`, `IsUpper`, derived series cache) | Existing pattern in `ThresholdRule` and `Threshold` |
| `properties (Dependent)` | Backward-compat aliases (`Label` → `Name`) | Already proven in `Threshold.Label` |
| `properties (Constant)` for enumerated string sets | `Tag.VALID_AGGREGATE_MODES`, `Tag.VALID_DIRECTIONS` | Existing pattern in `ThresholdRule.DIRECTIONS` |
| `set.PropertyName` validators | Validate enumerated assignments at set time | Existing pattern in `CompositeThreshold.set.AggregateMode` |
| `properties (Access = private)` with trailing underscore | Internal state (`children_`, `conditions_`) | Existing convention across the codebase |

Avoid (per anti-deps): `matlab.mixin.*`, `Sealed`, `enumeration`, `events`, `arguments` blocks.

---

## Stack Patterns by Variant

**If MATLAB R2020b only (target floor):**
- All listed primitives available. No further work.

**If targeting Octave 7+/9+/11+ (also a project invariant):**
- Use cell arrays for any Tag collection (never `[Tag1; Tag2]`).
- Pair every `methods (Abstract)` with a throw-stub.
- Use `isequal(a, b)` for handle identity, never `a == b`.
- Use manual name-value parsing in constructors.
- Use `properties (Constant)` + `set.X` validator for enumerations, never `enumeration` blocks.

**If a future MonitorTag has very high sample count (>10M derived samples):**
- Same path as `Sensor.toDisk()` — call `monitor.toDisk()` to push to `FastSenseDataStore`.
- All FastSense rendering already handles disk-backed signals via `getRange`.

**If CompositeTag depth > ~50 levels:**
- Recursion in `computeStatus` could approach MATLAB's recursion limit. **Mitigation, only if observed:** convert recursion to iterative DFS with an explicit work-list. Not a v2.0 problem unless usage shows it.

---

## Version Compatibility (Targets)

| Component | Required | Confirmed on |
|-----------|----------|--------------|
| MATLAB | R2020b+ | Existing project floor; CI matrix |
| GNU Octave | 7+ | Project invariant; CI Windows uses Octave 9.2.0 |
| `containers.Map` | All listed versions | Existing `SensorRegistry`/`ThresholdRegistry` work today |
| `methods (Abstract)` | All listed versions (Octave: partial — pair with throw-stub) | Existing `DashboardWidget` works on the CI matrix |
| `properties (Dependent)` | All listed versions (Octave: partial) | Existing `Threshold.Label` works |
| `mksqlite` (bundled) | All listed versions | Existing `FastSenseDataStore` works |

---

## Sources

- `/Users/hannessuhr/FastPlot/.claude/worktrees/reverent-bohr/CLAUDE.md` — project tech stack, conventions, and Octave/MATLAB invariant (HIGH confidence — first-party)
- `/Users/hannessuhr/FastPlot/.claude/worktrees/reverent-bohr/.planning/PROJECT.md` — milestone scope, "no users / no backward compat" constraint, deferred features (HIGH)
- `libs/SensorThreshold/Sensor.m`, `Threshold.m`, `CompositeThreshold.m`, `ThresholdRegistry.m`, `SensorRegistry.m`, `ThresholdRule.m` — current registry, validator, dependent-property, set-validator, and persistent-singleton patterns (HIGH — direct source inspection)
- `libs/Dashboard/DashboardWidget.m` — proof that `methods (Abstract)` works on the project's Octave matrix (HIGH — direct source inspection)
- `libs/EventDetection/DataSource.m` — proof of throw-on-base-method pattern as Octave-safe abstract fallback (HIGH — direct source inspection)
- `libs/FastSense/FastSenseDataStore.m` — confirmation that the SQLite-backed store handles arbitrary `(x, y)` signals (used today by `Sensor.toDisk`) and is reusable for MonitorTag (HIGH — direct source inspection)
- `.planning/research/mex-simd-opportunities-RESEARCH.md` — prior research that already evaluated MEX-kernel candidates and ranked aggregation operations LOW priority; informs the "no new MEX kernel" decision (HIGH — first-party prior research)
- [Octave Classdef wiki](https://wiki.octave.org/Classdef) — authoritative status of `Abstract` (partial, bug #51377), `enumeration` (parsed-no-op), `events` (parsed-no-op), heterogeneous arrays (not implemented) (HIGH — verified via WebFetch 2026-04-16)
- [GNU Octave 11.1.0 release notes / built-in data types](https://docs.octave.org/latest/Built_002din-Data-Types.html) — confirms no native `dictionary` in core Octave 11 as of Feb 2026; only the external `datatypes` package provides one (HIGH — verified via WebSearch 2026-04-16)
- [MATLAB `dictionary` docs](https://www.mathworks.com/help/matlab/ref/dictionary.html) — confirms `dictionary` is R2022b+, above the R2020b project floor (HIGH — Mathworks official)
- [MathWorks `matlab.mixin.Heterogeneous`](https://www.mathworks.com/help/matlab/ref/matlab.mixin.heterogeneous-class.html) — MATLAB-only feature; cross-referenced with Octave wiki to confirm no Octave equivalent (HIGH)

---

*Stack research for: v2.0 Tag-Based Domain Model on existing pure-MATLAB FastSense codebase*
*Researched: 2026-04-16*
