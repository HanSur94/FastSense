# Feature Research — v2.0 Tag-Based Domain Model

**Domain:** Industrial historian-style time-series + tag + monitor + event model (Trendminer-flavored), embedded inside the existing FastSense MATLAB plotting/dashboard engine.
**Researched:** 2026-04-16
**Mode:** Ecosystem (focused on Tag, MonitorTag, CompositeTag, Events-on-Tag).
**Overall confidence:** MEDIUM-HIGH. Industrial historian patterns (PI AF, Trendminer, Seeq, Cognite) are well-documented and convergent; specific numeric defaults (e.g. severity scales) vary by vendor and are flagged where they do.

---

## Summary

Industrial historians (OSI PI AF, Trendminer, Seeq, Cognite Data Fusion) all converge on a remarkably similar data model:

1. **Tag** is the universal addressable identifier with a small set of mandatory fields (key, name, type, units, description) and an open metadata bag. Everything addressable in the system (raw signal, calculated signal, state channel, alarm/monitor) is a Tag with a `Type` discriminator.
2. **Derived signals** (Trendminer "monitors", Seeq "conditions" / "signal-from-condition", PI AF "analyses" emitting Event Frames) are themselves first-class signals — they have a value over time, can be plotted, can be queried, can have their own thresholds. They are NOT one-shot booleans evaluated only "now".
3. **Composite/calculated tags** typically use either (a) a small fixed library of aggregators (AND/OR/MAX/MIN/COUNT/AVG) or (b) a full formula language (Seeq Formula, PI AF Analyses). The Ambitious tier should pick (a) — table-stakes aggregators only — and explicitly defer (b) to the deferred "calc tags" milestone.
4. **Events bind to tags via reference, not embedding.** PI AF event frames `PrimaryReferencedElement` + secondary references; Trendminer events live in ContextHub and reference search/monitor tags; Seeq capsules live in conditions and are queried over signals. Many-to-many is universal; binding is by ID, not by parent ownership.
5. **Time alignment for composites uses zero-order-hold (LOCF / step interpolation) by default.** Industrial signals are sampled irregularly and represent piecewise-constant state. This is already the pattern used in `StateChannel` and `to_step_function_mex.c`.

The existing FastSense codebase has unusually good bones for this rewrite:
- `to_step_function_mex.c` already implements ZOH alignment.
- `compute_violations_mex.c` + `groupViolations.m` already produce the time-windowed booleans that a `MonitorTag` needs.
- `Threshold` already has the `Tags`/`Units`/`Description` metadata that a `Tag` needs.
- `EventStore` + `EventTimelineWidget` already render bar regions; binding them to a Tag overlay on a `FastSense` axes is a small wiring change, not new infrastructure.

**Recommendation:** Treat MonitorTag as the lynchpin — it converts "violation arrays evaluated inside `Sensor.resolve()`" into a real, plottable, persistable, event-yielding signal. Once MonitorTag exists, CompositeTag becomes "MonitorTag whose value is `f(child MonitorTag values)`" and Events-on-Tag becomes "the bands that get drawn when a MonitorTag is non-zero."

---

## Feature Landscape

### Section 1 — Tag Foundation (Tag root abstraction)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Tag.Key** (unique string id) | Every historian (PI Point name, Trendminer tag, Cognite externalId) addresses by string key. Existing `Sensor` and `Threshold` already use `Key`. | TRIVIAL | Reuse pattern from `Threshold.Key`. |
| **Tag.Name** (human display) | All historians distinguish machine id from display name. | TRIVIAL | Already on `Threshold`. |
| **Tag.Type** (discriminator) | `'sensor' \| 'state' \| 'monitor' \| 'composite'`. Trendminer uses `ANALOG`/`DISCRETE`/`STRING`; Cognite uses `is_string`; PI uses `PIPoint.PointType`. Critical for dispatch in `FastSense.addTag()`. | TRIVIAL | One enum-like char field; consumers `switch` on it. |
| **Tag.Units** (engineering unit) | PI AF has UOM database; Trendminer/Cognite/Seeq all carry units. Used for axis labels, threshold UI ("80 bar" vs "80"). | TRIVIAL | Already on `Threshold`. |
| **Tag.Description** (free text) | Universal. Used in tooltips and search. | TRIVIAL | Already on `Threshold`. |
| **Tag.Labels** (cell of strings) | Trendminer "tags-on-tags", PI AF Categories, Seeq UI tags. Flat string set, used for filter/search. | TRIVIAL | Existing `Threshold.Tags` already does this; carry forward verbatim. |
| **Tag.X / Tag.Y accessors** (or `getData(tStart, tEnd)`) | Universal "give me the time series of this tag in window W" contract. PI AF `RecordedValues`, Trendminer `getDataPoints`, Cognite `retrieve`. | LOW | Abstract method; `SensorTag` returns raw arrays, `MonitorTag` returns derived arrays, `CompositeTag` returns aggregated arrays, `StateTag` returns step values. |
| **Tag.valueAt(t)** (point lookup) | ZOH lookup at instant `t`. Already done by `StateChannel` (zero-order-hold via `to_step_function_mex.c`). Used for "what's the current value" widgets (NumberWidget, GaugeWidget, StatusWidget). | LOW | Standardize the interface so widgets don't need per-type code. |
| **Tag isa-check** (`isa(t, 'Tag')`) | Allows `FastSense.addTag(t)` and `CompositeTag.addChild(t)` to accept any subclass uniformly. | TRIVIAL | Pure MATLAB inheritance. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Tag.Criticality** (`'low'\|'medium'\|'high'\|'safety'`) | ISA-18.2 alarm priority (3-4 levels recommended). Drives default colors, sort order, "show only criticals" filter. Lightweight but signals "this is a real industrial tool." | TRIVIAL | One enum field; defaults. Carry through to derived `MonitorTag` events. |
| **Tag.SourceRef** (free-form provenance) | Cognite `source` + `sourceExternalId`, PI AF `DataReference`. "Where did this tag come from?" Useful for debugging composites. | TRIVIAL | Optional char field. |
| **Tag.Metadata** (struct, open-ended) | Cognite explicitly has open JSON `metadata`. Trendminer ContextHub. Lets users stash anything (asset id, line number, manufacturer) without schema changes. | TRIVIAL | One `struct` field; serializes via `jsonencode`. Future-proofs for asset hierarchy milestone (D). |
| **TagRegistry singleton** with `register/get/find/list` | Existing `SensorRegistry` + `ThresholdRegistry` already do this. Unifying into one `TagRegistry` removes a category of bugs (registering a sensor with the same key as a threshold). | LOW | Direct port of `SensorRegistry`'s pattern; one persistent `containers.Map`. Decision already in PROJECT.md. |
| **TagRegistry.find(filterFn)** + **TagRegistry.findByLabel(label)** | Trendminer-style "tag search," Cognite list filters. Dashboards built from queries instead of hand-typed key lists. | LOW | Filter over `containers.Map` values. |

#### Anti-Features (do NOT include)

| Feature | Why Tempting | Why Bad | Alternative |
|---------|-------------|---------|-------------|
| **Asset hierarchy on Tag.Parent** | "Industrial tools have asset trees." | Already deferred in PROJECT.md to a later milestone. Adding a `Parent` field now leaks half-baked hierarchy into Tag, then forces a schema migration when the real Asset class arrives. | Leave Asset for milestone D. Use `Tag.Metadata.asset = 'pump-3'` as a stopgap stringly-typed field. |
| **Generic key-value tag-on-tag system** (PI AF custom attribute system) | "Maximum flexibility." | Becomes a stringly-typed mini-database. Searches across it are slow and untyped. Trendminer learned this lesson and now indexes specific fields. | Specific named fields (`Units`, `Criticality`, `SourceRef`) plus the open `Metadata` escape hatch. |
| **Tag versioning / history of definition changes** | "Audit trail." | Massive complexity. PI AF charges money for it. None of FastSense's actual users ask for it. | Out of scope. Live with "the latest definition wins." |
| **Quality codes per sample** (PI AF `AFValueStatus`) | "Industrial-grade." | Doubles the storage footprint, complicates every consumer (every plot, every aggregation), and FastSense data sources don't produce quality codes. | NaN already serves as "missing/bad" — keep that convention. |
| **Multiple time bases per Tag** (e.g. Tag stored in both UTC and local) | "Convenience." | Time-zone hell. Every existing FastSense MEX kernel assumes one numeric time vector. | One time base (`datenum` or numeric seconds); display formatting is a render-layer concern. |

---

### Section 2 — MonitorTag (derived 0/1/severity time series)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **MonitorTag = (sourceTag, condition) → time series** | This is the core Trendminer mental model: "a monitor is a continuously-evaluated search." Seeq calls this "condition." PI AF calls it an "analysis emitting an event frame stream." | MEDIUM | Existing `compute_violations_mex.c` + `groupViolations.m` already produce exactly this — wrap them. |
| **Output value semantics: 0/1 binary** (default) | Simplest, universal. PI AF event frames are present/absent. Trendminer monitor result is "in violation now: yes/no." | TRIVIAL | Direct from violation array. |
| **Output value semantics: tri-state ok/warn/alarm** (numeric 0/1/2) | ISA-18.2 recommends 3-4 priority levels. Lets one MonitorTag carry multiple thresholds (warn at 80, alarm at 90). Highly differentiating versus a flat boolean. | MEDIUM | Multiple `Threshold` references on one `MonitorTag`; output is `max(level)` at each sample. |
| **Output value semantics: continuous severity 0..1** (or 0..N) | Seeq supports continuous "value of condition." Useful for "how badly are we violating" plots and for severity-weighted CompositeTag aggregation. | MEDIUM | Optional mode; e.g. severity = `(value - threshold) / (alarm - warn)` clipped to [0, 1]. |
| **MonitorTag IS a Tag** (`isa(m, 'Tag')` is true) | Lets MonitorTag be plotted in `FastSense`, listed in `TagRegistry`, used as input to another `CompositeTag`, get its own `Threshold` (alarm-on-an-alarm). This recursion is what makes the whole model coherent. | LOW | Inheritance. The hard work is making sure `FastSense.addTag()` dispatches correctly. |
| **Lazy evaluation: compute on read for window [tStart, tEnd]** | Trendminer evaluates every 2 minutes; Seeq is fully lazy. Computing the entire history every time is wasteful and breaks at-scale. | MEDIUM | `MonitorTag.getData(tStart, tEnd)` calls `sourceTag.getData(tStart, tEnd)` then evaluates condition. No persistence required for v2.0. |
| **MonitorTag emits Events** (start/end pairs) | Exactly what `groupViolations` already produces. Plug into existing `EventStore` and `EventDetector`. | LOW | Reuse `EventDetector.detect()` directly with the MonitorTag's time/value arrays. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Streaming/incremental evaluation** for live mode | `IncrementalEventDetector` already exists. MonitorTag.appendData(newSamples) → emits new events without re-scanning history. | MEDIUM | Wrap `IncrementalEventDetector`; reuse `LiveEventPipeline` timer. |
| **Debounce / MinDuration** at MonitorTag level | `EventDetector.MinDuration` already exists. Promote it to MonitorTag config so "monitor X requires 5 s sustained violation." Standard ISA-18.2 alarm-suppression pattern. | TRIVIAL | One field on MonitorTag; pass through to detector. |
| **Hysteresis / deadband** (alarm-on threshold ≠ alarm-off threshold) | ISA-18.2 standard practice to prevent chatter. Trendminer/PI both support. None of FastSense currently does. | MEDIUM | Two-threshold version of violation-detection; net new MEX or pure-MATLAB. Mark as "would meaningfully exceed competitors" because most simple historians get this wrong. |
| **MonitorTag.Persist = bool** to optionally cache evaluated history to `FastSenseDataStore` | For very expensive computations or for replay debugging. SQLite-WAL infrastructure already exists. | MEDIUM | Optional; lazy by default. |

#### Anti-Features

| Feature | Why Tempting | Why Bad | Alternative |
|---------|-------------|---------|-------------|
| **Eager full-history computation at MonitorTag construction** | Simple, "obvious." | Will OOM on multi-year datasets; will block constructor. Industrial datasets routinely hit billions of samples. | Lazy-windowed only. Always evaluate over `[tStart, tEnd]` from `getData()`. |
| **String-based condition DSL** (`"sensor1 > 80 AND sensor2 < 20"`) | Trendminer-like UX. | Greenfield interpreter, parser, error messages. Reserved for the deferred "calc tags" milestone (G). | Function handle: `MonitorTag('m', sourceTag, @(v) v > 80)`. MATLAB-native, debuggable, no parser. |
| **Multiple value semantics on one MonitorTag** (binary AND severity AND categorical) | "Maximum flexibility." | Confuses every consumer. CompositeTag aggregation has to special-case. | Pick ONE semantic per MonitorTag; configure via `MonitorTag.OutputMode = 'binary' \| 'tristate' \| 'severity'`. |
| **Per-sample callbacks during evaluation** | "Real-time hooks." | Same trap as PI AF analyses with side effects — unpredictable, non-replayable, hard to test. | Event callbacks at MonitorTag level only (`OnEventStart`/`OnEventEnd`), reusing `EventDetector`'s pattern. |
| **MonitorTag rewrites violation results back into `Sensor`** | "Backward compat." | The whole point of v2.0 is to STOP cramming violation logic into `Sensor.resolve()`. Reintroducing the back-write recreates the entanglement. | MonitorTag is downstream-only. `Sensor` (now `SensorTag`) does not know which monitors observe it. |

---

### Section 3 — CompositeTag (recursive aggregation)

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **AggregateMode: AND** (all children OK → OK) | Already in `CompositeThreshold`. Universal "all subsystems healthy" pattern. | TRIVIAL | Direct port. |
| **AggregateMode: OR** (any child OK → OK) | Already in `CompositeThreshold`. Redundancy modeling ("at least one pump running"). | TRIVIAL | Direct port. |
| **AggregateMode: MAJORITY** (>50% OK → OK) | Already in `CompositeThreshold`. 2-out-of-3 voting pattern. | TRIVIAL | Direct port. |
| **AggregateMode: COUNT** (numeric: how many children are non-zero) | Standard "number of active alarms" KPI; drives the most common dashboard widget (number of alarms in section X). | TRIVIAL | `sum(childValues > 0)`. |
| **AggregateMode: WORST_CASE / MAX** (output = max severity across children) | "Asset health rollup," ISA-18.2 priority propagation, Trendminer/Seeq alarm rollup. The single most-requested aggregation in industrial monitoring after AND. | TRIVIAL | `max(childValues)`. Works naturally with tri-state and severity outputs. |
| **CompositeTag IS a Tag (and IS a MonitorTag-shaped output)** | Recursion. A CompositeTag can be a child of another CompositeTag. Already proven in `CompositeThreshold`. | LOW | Inheritance hierarchy: `CompositeTag < MonitorTag < Tag` (or `CompositeTag < Tag` with shared duck-typing for `getData/valueAt`). |
| **Children referenced by Tag handle OR by Tag key (via TagRegistry)** | Already in `CompositeThreshold.addChild` (accepts handle or key). Required for serialization. | LOW | Direct port. |
| **Self-reference guard** | Already in `CompositeThreshold` (`isequal(t, obj)` check). | TRIVIAL | Direct port. Plus deeper cycle-detection for nested composites (parent → child → grandchild → parent). |
| **Time-aligned evaluation across children** | If children have different X arrays, must align before aggregating. ZOH (LOCF) is the industrial standard. | MEDIUM | See Section 6. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **AggregateMode: SEVERITY** (weighted average, e.g. `0.6*pump + 0.4*sensor`) | Asset Health Index (AHI) pattern. Goes beyond AND/OR into actual numeric scoring. Used in OEE-style dashboards. | LOW | Per-child weight stored on the addChild entry. |
| **AggregateMode: USER_FN** (function handle `@(childValues) ...`) | Escape hatch for the 5% of cases the built-in aggregators don't cover. Native MATLAB, no DSL. | TRIVIAL | One field; one `feval`. |
| **Cycle detection on add** (not just self-ref) | Catches accidentally circular composites (A → B → A). PI AF lets users do this and then crashes at runtime. | LOW | DFS at addChild time. |
| **Per-child weight + per-child threshold override** | Mature historians let you say "this child contributes 0.3 weight and only counts as alarm above its 'high-high' level." | MEDIUM | Optional fields on the addChild entry; can be added later. |

#### Anti-Features

| Feature | Why Tempting | Why Bad | Alternative |
|---------|-------------|---------|-------------|
| **Arbitrary user-supplied output value type** | "Maximum flexibility." | Aggregation rules require knowing whether children are binary, tri-state, or severity. Mixing breaks invariants. | Compositing rule: ALL children of a CompositeTag must share the same `OutputMode`. Validate at addChild. |
| **Implicit child resolution by name pattern (`"pump_*"`)** | Trendminer "search-as-monitor" UX. | Hidden dependencies; refactor breaks composites silently. | Explicit children only. (Search-by-label is a query-builder concern, not a composite concern.) |
| **Composites that own their children's lifecycle** | "Parent-controlled state." | Children are independently registered Tags with their own lifecycles. Owning them creates double-free hazards on serialize/load. | Composites hold references only; never delete children. (This is what `CompositeThreshold` already does correctly.) |
| **Materialized aggregation cache** (write rolled-up signal back to disk) | "Performance." | Cache invalidation is the harder problem. Lazy aggregation + downsampling is fast enough for FastSense's MEX-accelerated path. | Lazy. Reuse existing pyramid-level downsampling for the rolled-up output. |

---

### Section 4 — Tag Metadata + Search

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Universal metadata fields** (key, name, type, units, description, labels) | See Section 1. Every historian has these. | TRIVIAL | All present in current `Threshold`. |
| **Flat label set** (`{'pressure', 'pump-3', 'critical'}`) | Trendminer tag-on-tag, PI Categories. Flat is enough; users always reach for hierarchy and then regret it. | TRIVIAL | Already on `Threshold.Tags`. Rename to `Tag.Labels` to avoid confusion with the Tag class itself. |
| **`TagRegistry.find(predicate)`** | Filter all tags by arbitrary criteria. Powers list/picker widgets and label-driven dashboards. | LOW | Iterate over `containers.Map`. |
| **`TagRegistry.findByLabel(label)`** | Convenience wrapper; most common search. | TRIVIAL | One-line on top of `find`. |
| **`TagRegistry.findByType(type)`** | Get all sensor tags / all monitor tags. | TRIVIAL | One-line. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Open metadata bag (`Tag.Metadata struct`)** | Cognite-style escape hatch. Users can add `asset='pump-3'` or `vendor='Siemens'` without schema migration. Future-proofs for the deferred Asset milestone. | TRIVIAL | One `struct` field. |
| **Auto-derived labels from Type/Units** | When a SensorTag has `Units='bar'`, auto-add label `'pressure'` (configurable map). Reduces user typing without losing flatness. | LOW | Optional; can be added later. |
| **Label-driven dashboard widgets** (`addAllByLabel('critical')`) | Drives the killer Trendminer demo: "show me all critical alarms across the whole plant." Composes with CompositeTag (`COUNT` of all critical-labeled MonitorTags). | LOW | Convenience method on DashboardBuilder. |

#### Anti-Features

| Feature | Why Tempting | Why Bad | Alternative |
|---------|-------------|---------|-------------|
| **Hierarchical label paths** (`'plant/unit-A/pump-3'`) | "More structure." | Reinventing asset hierarchy badly via strings. Becomes inconsistent (some labels are paths, others aren't). | Flat labels only. Real hierarchy belongs in the Asset milestone. |
| **Key-value pair labels** (`{'asset': 'pump-3'}`) | "Structured search." | Two redundant systems with the open `Metadata` struct. | Use the `Metadata` struct for k/v; `Labels` is flat-string-only. |
| **Full-text search across descriptions** | "Trendminer-like UX." | Requires a search index. Premature for MATLAB-script-driven workflows. | `find(@(t) contains(t.Description, 'pump'))` is good enough. |
| **Synced external metadata source** (read tag definitions from a CSV/JSON file at runtime) | "Don't hardcode tags." | Out of scope; conflates registry with data source. | Users can build their own loader on top of `TagRegistry.register`. |

---

### Section 5 — Events Attached to Tags

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Event references Tag by key, not handle** | Survives serialization. PI AF event frames carry `PrimaryReferencedElement` IDs; Cognite events carry `assetIds` array; Trendminer ContextHub events reference tag/asset IDs. | LOW | Add `TagKey` field to `Event`. |
| **Many-to-many: one Event references multiple Tags** | Universal. PI AF event frames have `Elements` collection; Cognite events have `assetIds` array (and time-series link); Trendminer events can be tagged with multiple context items. | LOW | `TagKeys` cell array on `Event` (replaces single `SensorName` over time, but keep `SensorName` for backward-compat readability). |
| **Event metadata: StartTime, EndTime, Duration, Label, Severity, Message** | All universal. Existing `Event` has start/end/duration/label/value/direction/stats. Add `Severity` (or reuse `Direction` + threshold value to derive). | LOW | Mostly already there. |
| **FastSense overlay rendering: events as shaded regions on a tag's plot** | Standard "annotated chart" — Trendminer event overlays, Seeq capsule rendering, Grafana annotation regions. | MEDIUM | New: extend `FastSense` to render events bound to its tags as background patches (similar to how thresholds are drawn as horizontal lines). |
| **Event color from severity, not per-event color** | Consistent dashboard look. ISA-18.2 priority colors. Existing `EventTimelineWidget` already does theme-color-by-label heuristic; formalize. | TRIVIAL | Map severity → theme color (`StatusOkColor`, `StatusWarnColor`, `StatusAlarmColor`). |
| **Filter events by tag at render time** | "Show events for this widget's tags only." Existing `EventTimelineWidget.FilterSensors` already does this by string match; replace with proper tag-key filter. | LOW | `EventTimelineWidget.FilterTags = {'press_hi', 'temp_hi'}`. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Auto-emit: MonitorTag automatically produces Events for its violations** | Closes the loop. User configures threshold; events appear; events overlay the plot. No glue code. | LOW | `MonitorTag` wraps `EventDetector` internally; `EventStore` indexed by source MonitorTag key. |
| **Render mode: regions vs. markers vs. swim-lanes** | Different event types want different rendering. State changes → markers (vertical lines). Alarm windows → regions (shaded patches). Categorized faults → swim-lanes (current `EventTimelineWidget` y-axis lanes). | MEDIUM | Per-event `RenderMode` field; FastSense overlay dispatches. |
| **Event categories** (`'alarm', 'maintenance', 'process_change', 'manual_annotation'`) | Used to drive color, render mode, and filter. PI AF has event frame templates; Trendminer has event categories. | LOW | One enum field. |
| **Severity field on Event** (numeric 0..N or enum) | Enables the rendering-by-severity story end-to-end. ISA-18.2 priority levels. | TRIVIAL | One field; map to color. |
| **Manual event creation API** (`tag.addManualEvent(tStart, tEnd, label, message)`) | Used everywhere — operators annotate "this was a maintenance window, ignore." Foundation for the deferred custom-event-GUI milestone (F). | LOW | Pure code path; GUI is later. |

#### Anti-Features

| Feature | Why Tempting | Why Bad | Alternative |
|---------|-------------|---------|-------------|
| **Events embedded in Tag (`Tag.Events = [...]`)** | "Easy access." | Breaks many-to-many. Forces duplication when one event references two tags. Re-creates the `Sensor.resolve()` entanglement we're escaping. | Events live in `EventStore`, indexed by `TagKey`. Tags query the store. |
| **Per-event drawing customization** (color, line width, hatch pattern) | "Pretty charts." | Users will inevitably create unreadable mess. Theme-driven coloring is more consistent and easier to test. | Severity → color via theme. |
| **Event mutation after creation** (operators "edit" events) | "User control." | Audit trail nightmare. PI AF supports it grudgingly; users hate the resulting confusion about ground truth. | Events are immutable; "edit" = "create override event with link to original." Out of scope for v2.0. |
| **Event acknowledgement workflow** (alarm acknowledge state, ISA-18.2 lifecycle) | "Industrial-grade." | Needs user identity, persistence beyond `EventStore`'s flat structure, UI flows. Massive scope creep. | Out of scope for v2.0. Mention in PITFALLS as "do not slip in." |
| **Recursive events that emit events** (event-on-event-on-event) | "Symmetric with CompositeTag." | Untyped recursion explosion. Trendminer wisely keeps events as terminals, not sources. | Events are leaves. Composite *signals* recurse; composite *events* do not. |
| **Tying every Event to exactly one MonitorTag (1:1)** | Looks clean. | Manual events don't have a source MonitorTag. Composite events come from multiple. | Events have 0..N tag references. The auto-emitted ones from MonitorTag have 1; manual ones may have 0..N. |

---

### Section 6 — Time-Axis Alignment for Composites

#### Table Stakes

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| **Zero-Order-Hold (LOCF / step) alignment** | The default in every industrial historian and in pandas (`.ffill()`). Industrial signals represent piecewise-constant state (a sensor reading is valid until the next sample). PI AF, Trendminer, Cognite, Seeq all default to ZOH. | LOW | `to_step_function_mex.c` already implements this. Promote to a public utility callable from `CompositeTag.aggregateChildren()`. |
| **Union-of-timestamps grid** | When aggregating N children, evaluate at every timestamp from any child (not on a fixed regular grid). Preserves event-edges; doesn't introduce sampling artifacts. Standard Seeq behavior. | LOW | `unique([child1.X; child2.X; ...])`. Then ZOH-lookup each child at each grid point. |
| **valueAt(t) for any Tag** | The atomic primitive. ZOH lookup at instant `t`. Already done by `StateChannel`. | LOW | Standardize across all Tag subclasses. Existing `binary_search_mex.c` is the right kernel. |
| **Aggregation only over grid points where ALL children have ≥1 prior sample** | Avoids "child not yet started" false alarms at the beginning of the time range. Universal industrial pattern. | TRIVIAL | Drop grid points before `max(child.X(1))`. |
| **NaN handling in aggregation** | NaN = "missing/bad" by FastSense convention. AND with NaN → NaN; OR with NaN → other; MAX with NaN → ignore. Standard semantics. | LOW | One pass at aggregation. Use existing IEEE 754 conventions. |

#### Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| **Optional regular-grid resample mode** (`CompositeTag.AlignMode = 'union' \| 'regular'`) | Some downstream calculations want fixed sample period (e.g. FFT, downsampling). | LOW | Optional; `union` is default. |
| **Alignment caching keyed on (children, window)** | Repeated `getData` over the same window doesn't re-walk all children. | MEDIUM | Optional optimization; only worth it if profiling shows it matters. |

#### Anti-Features

| Feature | Why Tempting | Why Bad | Alternative |
|---------|-------------|---------|-------------|
| **Linear interpolation between samples** | "Smooth" looking. | Wrong for state signals (interpolating "0" and "1" gives "0.5", which is not a valid state). Wrong for sensor readings whose physical interpretation is "the value at time T was X, and we don't know what it was between T and the next sample." | ZOH only. Period. Linear is a render-only concern, never an aggregation concern. |
| **Auto-detect sample rate per child** | "Convenient." | Industrial sample rates are wildly inconsistent (1 Hz for some, 10 ms for others, irregular for state changes). Auto-detection guesses wrong constantly. | Each child carries its own X array; no resampling assumed. |
| **Padding short-history children with zeros at the start** | "Avoids dropping data." | Zero is a valid value for binary signals — padding-with-zero looks like "OK," falsely raising the COUNT/MAJORITY result. | Drop pre-history grid points; document the behavior. |
| **Time-zone-aware alignment** | "Localization." | Already excluded by Tag-level "one time base" rule. | Display formatting only. |

---

## Feature Dependencies

```
Tag (root abstract) ──────────────────┐
    ├──> SensorTag                    │
    ├──> StateTag                     │
    ├──> MonitorTag ──────────────────┤
    │       │                         │
    │       └─requires─> Threshold    │
    │       └─emits────> Event        │
    │                                 │
    └──> CompositeTag ────────────────┘
            │
            └─requires─> MonitorTag (children must be MonitorTag-compatible)
            └─requires─> Time alignment (Section 6)

TagRegistry ──singleton──> all Tag instances

Event ──references-by-key──> Tag(s)
   └─persisted-in──> EventStore
   └─rendered-by──> FastSense (overlay) AND EventTimelineWidget

FastSense.addTag() ──dispatches-on──> Tag.Type
    │
    ├──> SensorTag → existing line plot
    ├──> StateTag → existing band overlay
    ├──> MonitorTag → new: 0/1 step plot + event overlay
    └──> CompositeTag → recursive: render aggregated value as MonitorTag-style plot
```

### Dependency Notes (critical for phase ordering)

- **Tag (Section 1) MUST be designed first.** Every other section depends on the Tag interface contract. No partial designs.
- **MonitorTag (Section 2) requires Tag + Threshold + EventDetector.** EventDetector and `compute_violations` already exist — wrap, don't rewrite.
- **CompositeTag (Section 3) requires MonitorTag.** Aggregation operates on MonitorTag-shaped outputs (binary or severity). Children that are SensorTags must be wrapped in an implicit MonitorTag, or CompositeTag must reject non-MonitorTag children.
- **Time alignment (Section 6) is a hard prerequisite for CompositeTag.** Cannot ship CompositeTag without ZOH alignment.
- **Tag metadata + search (Section 4) is independent.** Can ship in parallel with any other section. Lowest-risk to drop or descope.
- **Events-on-Tag (Section 5) requires Tag and is enhanced by MonitorTag.** Manual events can ship without MonitorTag; auto-emitted events depend on MonitorTag.
- **FastSense overlay rendering (Section 5 differentiator)** depends on `FastSense` knowing which Tags it owns and which Events reference those Tags. New `EventStore` query API: `getEventsForTag(key)`.
- **TagRegistry (Section 1 differentiator)** is a prerequisite for serializing CompositeTag children by key (existing `CompositeThreshold.fromStruct` pattern).

---

## Phase Ordering Implications

Suggested phase grouping (for the orchestrator's roadmap synthesis — not prescriptive):

1. **Phase A: Tag root + retrofit** (Section 1, Section 4 minimal)
   - `Tag` abstract class, `TagRegistry`
   - `SensorTag`, `StateTag`, `Threshold` rewritten as Tag subclasses
   - `FastSense.addTag()` dispatch
   - `Tag.Labels`, `Tag.Metadata`, `TagRegistry.find/findByLabel/findByType`
   - **Blocks everything else.**

2. **Phase B: MonitorTag + Time alignment primitives** (Section 2, Section 6 prerequisites)
   - `MonitorTag` wraps `compute_violations` + `EventDetector`
   - Output modes: binary, tri-state, severity
   - Lazy windowed evaluation
   - `valueAt(t)` standardized across all Tags using `binary_search_mex` + ZOH
   - Auto-emit events to `EventStore`

3. **Phase C: CompositeTag + Full time alignment** (Section 3, Section 6 full)
   - `CompositeTag < Tag` (replaces `CompositeThreshold`)
   - Aggregators: AND/OR/MAJORITY/COUNT/MAX/SEVERITY/USER_FN
   - Union-grid + ZOH alignment in `aggregateChildren_()`
   - Cycle detection on addChild

4. **Phase D: Events-on-Tag rendering** (Section 5)
   - `Event.TagKeys` (cell of strings, many-to-many)
   - `EventStore.getEventsForTag(key)`
   - `FastSense` overlay: render events as shaded regions on tag plot
   - `EventTimelineWidget.FilterTags` (replaces `FilterSensors`)
   - `EventTimelineWidget` color by severity

Phases B and D have a soft dependency: Phase D works without Phase B (manual events only), but is dramatically more useful with it (auto-emitted events from monitors). Recommend B before D.

Phases A and B are the highest-risk; Phases C and D are lower-risk because they build on stable foundations.

---

## Anti-Features Summary (consolidated for the requirements gatherer)

These should appear explicitly in PROJECT.md "Out of Scope" or in PITFALLS.md to prevent scope creep:

- **No asset hierarchy** in v2.0 — deferred to milestone D, even though every research source mentions it.
- **No formula DSL / calc tags** — deferred to milestone G; use MATLAB function handles instead.
- **No alarm acknowledgement workflow** — full ISA-18.2 alarm lifecycle is a separate product.
- **No event mutation / editing** — events are immutable; "edit" = "supersede with new event."
- **No quality codes per sample** — NaN remains the missing-value convention.
- **No linear interpolation in CompositeTag aggregation** — ZOH only.
- **No string-based search DSL** — function-handle predicates only.
- **No hierarchical label paths** — flat labels only; metadata struct for structure.
- **No materialized aggregation cache** — lazy evaluation only.
- **No per-sample side-effect callbacks** — event-level callbacks only.
- **No back-write of MonitorTag results into source SensorTag** — downstream-only data flow.
- **No multi-output-mode MonitorTag** — pick one of binary/tri-state/severity per MonitorTag.

---

## Competitor Feature Matrix

| Capability | OSI PI AF | Trendminer | Seeq | Cognite DF | v2.0 Plan |
|------------|-----------|------------|------|------------|-----------|
| Universal addressable Tag | PI Point + AF Element/Attribute | Tag (ANALOG/DISCRETE/STRING) | Signal/Condition | TimeSeries (with `is_string`) | `Tag` abstract + `Type` discriminator |
| Derived signal | Analyses → Event Frames | Monitors | Calculated Signals (Formula) | Functions / Calculations | `MonitorTag` (function handle) |
| Composite/rollup | AF Analyses with formulas | Composite contexts | Composite conditions | Data modeling instances | `CompositeTag` + 7 built-in modes |
| Asset hierarchy | First-class Element tree | Assets + ContextHub | Asset Trees (SPy) | Asset hierarchy | DEFERRED to milestone D |
| Event/alarm | Event Frames | ContextHub events | Capsules within Conditions | Events | Existing `Event` + tag binding |
| Event ↔ Tag binding | Many-to-many via Element refs | Many-to-many via context refs | Conditions over Signals | Many-to-many `assetIds` | Many-to-many via `Event.TagKeys` |
| Severity model | Configurable priority enum | Priority on monitor | Capsule properties | Custom metadata | Tri-state + numeric severity |
| Time alignment | ZOH default + interp options | ZOH default | ZOH (step interpolation) | ZOH default | ZOH default (existing MEX) |
| Search | AF query syntax | Full ContextHub search | SPy + Workbench search | List filters + DM query | Function-handle predicates |
| Calc DSL | AF Analyses formulas | Search expressions | Seeq Formula | Functions (Python) | DEFERRED to milestone G |

The v2.0 plan deliberately matches industry-standard semantics on the foundational features (Tag, alignment, event binding, basic aggregation) while explicitly deferring the higher-complexity differentiators (asset hierarchy, formula DSL, full alarm lifecycle) to later milestones. This is a defensible "MVP industrial historian feature set" positioning.

---

## Sources

- [TrendMiner — Time series data connector docs](https://documentation.trendminer.com/2025.R1.0/en/how-to-write-your-own-time-series-data-connector--step-by-step-quick-start-guide.html) — tag types ANALOG/DISCRETE/STRING; Ts+value sample shape
- [TrendMiner — Index manager and tag indexing](https://documentation.trendminer.com/en/index-manager-and-performance-overview.html) — monitor tags must be indexed; updated every 2 min
- [TrendMiner — Monitoring and alert overview](https://userguide.trendminer.com/2025.R3.0/en/monitoring-and-alert-overview.html) — monitor model, event registration, action execution
- [TrendMiner — Monitor states](https://documentation.trendminer.com/en/monitor-states.html) — system-disabled state, monitor health
- [TrendMiner — Context items / ContextHub](https://userguide.trendminer.com/en/context-items.html) — many-to-many event/tag/asset binding
- [OSI PI / AVEVA — Building PI System Assets and Analytics with PI AF (PDF)](https://cdn.osisoft.com/learningcontent/pdfs/BuildingPISystemAssetsWorkbook.pdf) — Element/Attribute/Analysis structure, UOM, data references
- [OSI PI / AVEVA — Event Frames and Notifications (PDF, 2023)](https://osicdn.blob.core.windows.net/learningcontent/Online%20Course%20Workbooks/Event%20Frames%20and%20Notificationsv2023.pdf) — event frame ↔ element ↔ attribute binding
- [AVEVA — Understand event frames in PI AF](https://docs.aveva.com/bundle/pi-server-l-af-pse/page/1021923.html) — event frame data model
- [Seeq — Signal from Condition](https://support.seeq.com/kb/latest/cloud/signal-from-condition) — derived signals, capsule-bounded aggregation, step/linear/discrete interpolation
- [Seeq — Capsule Time](https://support.seeq.com/kb/R65/cloud/capsule-time) — condition/capsule data model
- [Seeq — Aggregate and Analyze Alarms](https://www.seeq.com/resources/use-cases/aggregate-and-analyze-alarms/) — alarm aggregation patterns
- [Seeq — Notifications on Conditions](https://support.seeq.com/kb/R64/cloud/notifications-on-conditions) — event-driven actions
- [Cognite Docs — Time series API (20230101)](https://api-docs.cognite.com/20230101/tag/Time-series/) — TimeSeries object shape, is_string flag, asset binding
- [Cognite Docs — Assets concept](https://docs.cognite.com/dev/concepts/resource_types/assets/) — asset hierarchy, root assets, contextualization
- [ANSI/ISA-18.2-2016 — Management of Alarm Systems for the Process Industries (PDF preview)](https://18817087.s21i.faiusr.com/61/ABUIABA9GAAgyZfj5AUozIu7wwI.pdf) — 3-4 priority levels, alarm states, hysteresis
- [ISA — Understanding and Applying ANSI/ISA 18.2 (PDF)](https://www.isa.org/getmedia/55b4210e-6cb2-4de4-89f8-2b5b6b46d954/PAS-Understanding-ISA-18-2.pdf) — alarm lifecycle, priority recommendations
- [Yokogawa — Implementing Alarm Management per ANSI/ISA-18.2](https://www.yokogawa.com/us/library/resources/media-publications/implementing-alarm-management-per-the-ansi-isa-182-standard-control-engineering/) — operational guidance
- [TotalEnergies Digital Factory — The problem with resampling time series (Medium)](https://medium.com/totalenergies-digital-factory/time-series-the-problem-with-resampling-7baea5a3873c) — industrial resampling pitfalls
- [imputeTS / R — Last Observation Carried Forward (LOCF)](https://steffenmoritz.github.io/imputeTS/reference/na_locf.html) — ZOH/LOCF nomenclature
- [MathWorks — Zero-Order Hold (Simulink)](https://www.mathworks.com/help/simulink/slref/zeroorderhold.html) — ZOH semantics in MATLAB ecosystem
- [MaintainNow — Asset Health Index (AHI) definition](https://www.maintainnow.app/learn/definitions/asset-health-index-ahi) — composite KPI / weighted-severity rollup pattern
- [Vertech — Unique Approach to SCADA Alarm Management](https://www.vertech.com/blog/a-unique-approach-to-scada-system-alarm-management) — hierarchical alarm rollup, parent-child suppression

---

**Confidence assessment:**

| Area | Level | Why |
|------|-------|-----|
| Tag interface contract (Section 1) | HIGH | Convergent across all 4 historians; existing `Threshold`/`Sensor` already model 80% of it. |
| MonitorTag value semantics (Section 2) | HIGH | Trendminer/Seeq/PI all derive signals from conditions; ISA-18.2 documents tri-state/severity. |
| CompositeTag aggregation modes (Section 3) | HIGH | AND/OR/MAJORITY/MAX/COUNT are universal; SEVERITY weighted is widely-used (AHI/OEE pattern); existing `CompositeThreshold` already validates the recursive design. |
| Tag metadata + search (Section 4) | MEDIUM-HIGH | Universal flat-label + open-metadata pattern; "should we add hierarchy" is the only contention point and PROJECT.md already answers it. |
| Events on Tag (Section 5) | HIGH | Many-to-many tag↔event binding is universal; FastSense overlay rendering is a small, well-scoped extension. |
| Time alignment (Section 6) | HIGH | ZOH/LOCF is the universal default; existing MEX kernel proves the pattern. |

---

*Feature research for: v2.0 Tag-Based Domain Model*
*Researched: 2026-04-16*
