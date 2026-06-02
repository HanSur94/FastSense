# Pitfalls Research — v5.0 Multi-Machine Fleet

**Domain:** Adding a multi-machine fleet layer (Machine/Fleet/CanonicalMapper in new `libs/Fleet/`) + companion machine selector + cross-machine comparison to a pure-MATLAB, backward-compat-constrained sensor dashboard.
**Researched:** 2026-06-02
**Confidence:** HIGH — all findings traced to concrete files in this repo; confirmed against TagRegistry.m, DashboardSerializer.m, FastSenseWidget.m, DashboardEngine.m, LiveTagPipeline.m, FastSenseCompanion.m, and prior v4.0 pitfall research.

---

## Critical Pitfalls

### Pitfall 1: Accidental Registration of Machine Tags into the Global TagRegistry

**What goes wrong:**

During `Machine` construction or `BatchTagPipeline` ingestion scoped to a machine, any code path that calls `TagRegistry.register(key, tag)` without knowing it is operating in fleet context immediately hard-errors `TagRegistry:duplicateKey` the moment a second machine tries to register a tag with the same local key (e.g., `'temperature'`, `'pressure'`). This is not a soft warning — it is an unrecoverable error. On a 20-machine fleet where every machine has `'temperature'`, the first machine's ingestion call triggers 19 future hard errors.

The trap is subtle: `TagRegistry.register` is called from 30+ files spanning `SensorTag.fromStruct`, `TagRegistry.loadFromStructs`, `BatchTagPipeline`, any `example_*.m` that registers tags for itself, and potentially any new fleet-setup script written by a developer who copies the single-machine pattern.

**Why it happens:**

Single-machine usage always calls `TagRegistry.register('myKey', tag)` — this is the canonical entry point documented in every example, the header of `TagRegistry.m`, and all existing pipeline code. A fleet developer writing `machine.loadTags()` may copy the `BatchTagPipeline` usage pattern and reach for `TagRegistry.register` because that is what the pipeline already calls internally via `loadFromStructs`. There is no API guard that says "this operation is machine-scoped."

**How to avoid:**

- `Machine` MUST own its own `containers.Map` (called, e.g., `Tags_`) and MUST NEVER call `TagRegistry.register`. This is the core architectural invariant. Lock it in the `Machine` constructor header as an explicit `%   NOTE: this class NEVER calls TagRegistry.register` comment.
- `BatchTagPipeline` gets a new constructor option `'Machine'` (a `Machine` handle). When this option is present, the pipeline's internal `TagRegistry.loadFromStructs` call is replaced by `machine.registerTag(key, tag)` — writing into the machine's private map, not the global catalog.
- The legacy single-machine path (`BatchTagPipeline` without `'Machine'`) continues to call `TagRegistry.register` unchanged.
- Phase gate: after the Machine/Fleet phase, `grep -rn "TagRegistry.register" libs/Fleet/` must return 0 lines. The Fleet library must never call the global registry.

**Warning signs:**

- `TagRegistry:duplicateKey` error during fleet setup or while loading a second machine
- Any file in `libs/Fleet/` or the fleet setup script containing `TagRegistry.register`
- `BatchTagPipeline` constructor called without `'Machine'` argument in a fleet context
- `TagRegistry.clear()` being called "to make room" before loading a new machine (the wrong fix — this destroys data for previously loaded machines)

**Phase to address:** Machine/Fleet data model phase (Phase 1). The containment invariant must be designed in from the start; retrofitting it later requires touching every fleet ingestion call site.

---

### Pitfall 2: DashboardSerializer Seam — Machine-Scoped Resolver Not Wired Everywhere

**What goes wrong:**

`DashboardSerializer.configToWidgets(config, resolver)` already accepts a `resolver` function handle for single-machine use. `FastSenseWidget.fromStruct` (lines 1513–1520) calls `TagRegistry.get(s.source.key)` directly via `exist('TagRegistry', 'class')` guard — it does NOT go through the `resolver` parameter. `DashboardEngine.load(filepath, 'SensorResolver', fn)` passes a resolver into `configToWidgets`, but `createWidgetFromStruct` (called from the multi-page JSON path at DashboardEngine.m:4384) does NOT pass it — resolver is silently dropped on the multi-page path.

For a fleet dashboard (machineId + localKey pair), `TagRegistry.get('temperature')` will either return the WRONG machine's tag (if that key was registered globally by mistake — Pitfall 1), or throw `TagRegistry:unknownKey` (if the machine's tags are correctly isolated in the machine's own map). Either way, the tag binding fails silently or crashes.

**Why it happens:**

The `resolver` was a v1.0 compatibility shim added for the legacy Sensor→Tag migration. It was never designed as the primary resolution path. The fast path (and the `fromStruct` default) is still `TagRegistry.get()`. Fleet contexts need a fundamentally different resolution path — `Fleet.getMachine(machineId).getTag(localKey)` — but there is no plumbing for this in the current serializer.

Additionally: `DashboardSerializer.save()` and `linesForWidget` emit `TagRegistry.get('key')` directly into generated `.m` files (lines 44, 47, 793, 796). A fleet `.m` export calls the global registry at load-time, which only works if machine tags happened to be globally registered — i.e., only if Pitfall 1 occurred.

**How to avoid:**

- Add a `FleetResolver` concept: a function handle `@(machineId, localKey) fleet.getMachine(machineId).getTag(localKey)`. This is the injection point for fleet-aware tag resolution.
- `FastSenseWidget.fromStruct(s, resolver)` must accept an optional resolver second argument. When `s.source.machineId` is present, the resolver is called instead of `TagRegistry.get`. The fallback to `TagRegistry.get` is preserved for the no-machineId single-machine case (backward compat).
- `DashboardEngine.load` multi-page path (line 4384: `createWidgetFromStruct(pgWidgets{j})`) must propagate the resolver into each `createWidgetFromStruct` call.
- Fleet `.m` export must NOT emit bare `TagRegistry.get('key')` calls. Instead emit `% Requires: machine.getTag('key') or equivalent setup before running this script` — same as the v2.1 Pitfall 8 strategy (C).
- The serialized fleet dashboard JSON MUST store `"source": {"type": "tag", "key": "temperature", "machineId": "M01"}` — the `machineId` field is the discriminator.

**Warning signs:**

- Generated fleet `.m` export contains `TagRegistry.get(...)` with no `machineId` qualification
- Multi-page JSON fleet dashboard loads with Tag = [] on all widgets (resolver silently not reaching `fromStruct`)
- `DashboardEngine.load` called for a fleet dashboard with no `'SensorResolver'` argument
- Widget `Tag` property is non-empty but points to the wrong machine's Tag object (same key, wrong machine)

**Phase to address:** Serialization/backward-compat phase (Phase 3 or dedicated). The `fromStruct` resolver propagation and fleet `.m` export strategy must be designed before any fleet dashboard is serialized or reloaded.

---

### Pitfall 3: Canonical Mapping False Matches — Silent Wrong Comparisons

**What goes wrong:**

The canonical mapper's automated rules compare sensor keys across machines (edit-distance, pattern matching, or explicit rules). An over-eager rule maps `'temperature_bearing_left'` on Machine 01 to `'temperature_motor_case'` on Machine 03 because both contain `'temperature'` and the edit distance is "close enough." The comparison view happily overlays the two series. No error fires. The chart looks plausible. The user draws engineering conclusions from physically-different sensors.

This is the most dangerous class of failure because it is entirely silent — the code works, the plot renders, the data is wrong.

**Why it happens:**

Edit-distance-based fuzzy matching is the standard first-cut approach to reconciling non-standardized sensor naming. But physical sensors on real machines have names that partially match for non-physical reasons: naming conventions, abbreviation style, underscore vs camelCase, channel numbering. A threshold like "distance ≤ 2" will match `temp_A` → `temp_B` even though A and B are in completely different positions on the machine.

**How to avoid:**

- Every canonical mapping entry must carry a `confidence` field: `HIGH` (exact rule match or explicit override), `MEDIUM` (automated rule with corroborating evidence like unit match), `LOW` (fuzzy match only, no additional signal).
- `LOW`-confidence mappings must be surfaced in a visible "unmapped/ambiguous" tail in the comparison UI — never silently included. The comparison view MUST refuse to overlay a sensor for any machine where that machine's mapping to the logical sensor is `LOW` confidence and unreviewed.
- Automated mapping rules must include a unit-consistency check: if `temperature_bearing_left` is in `°C` and `temperature_motor_case` is in `V` (e.g., because one is actually a voltage-disguised thermal sensor), the mapper must reject the match regardless of key similarity.
- Manual override must always be possible and must supersede any automated rule. The override store persists across Fleet config reloads.
- Mapping MUST be reviewable before first use: a `CanonicalMapper.reviewPending()` method returns all LOW-confidence and unreviewed entries in a table. The fleet setup workflow must include a "review pending mappings" step, not just "run the mapper and trust it."

**Warning signs:**

- Comparison view shows a series for Machine X with a sensor that has LOW confidence and no human review — no warning banner
- `CanonicalMapper` runs and produces zero `LOW`-confidence entries on a 20-machine fleet with inconsistent naming (overconfident mapper)
- Unit field on two mapped sensors differs
- A mapped pair's key suffix diverges significantly beyond a single token difference (e.g., `temp_bearing_left` vs `temp_housing_top`)

**Phase to address:** Canonical mapping phase. The confidence + review-gate architecture must be the first thing built in the mapper, not added later. Comparison view must gate on review status from day one.

---

### Pitfall 4: Canonical Mapping False Misses — Sensors Left Unmapped

**What goes wrong:**

`'sensor_AI_01_temp'` on Machine 01 and `'ai01_temperature'` on Machine 03 are the same physical sensor, but the canonical mapper misses the match entirely because the prefixes differ structurally. The comparison view correctly excludes this pair (no false match), but the user can never compare temperature across M01 and M03 and has no way to know why. The "unmapped" tail shows both keys as unresolved, but the user has no tooling to manually link them.

**Why it happens:**

Purely automated matchers using edit-distance or token overlap fail on naming conventions that mix underscore-separated codes (`sensor_AI_01`) with human-readable tokens (`ai01_temperature`). A single-strategy matcher has systematic blind spots.

**How to avoid:**

- The mapper should have at least two independent strategies: (a) string similarity (edit distance + token overlap), and (b) explicit rule patterns (regex or glob). When (a) misses, (b) allows the user to write `rules: [{pattern: 'sensor_AI_*', canonical: 'ai*_temperature'}]`.
- The "unmapped" tail must be surfaced prominently — every machine sensor that has no canonical assignment for any given Fleet should appear in `CanonicalMapper.unmapped()` output, not quietly ignored.
- The `addManualMapping(localKeyA, machineIdA, localKeyB, machineIdB)` override API must be easy to call from a setup script and must be the first-class way to close misses.

**Warning signs:**

- Comparison view for logical sensor `'temperature'` shows only 12 of 20 machines but no explanation for the missing 8
- `CanonicalMapper.unmapped()` has entries that appear obviously related by name to a canonical sensor
- No mechanism exists to write explicit mapping rules

**Phase to address:** Canonical mapping phase, same as Pitfall 3.

---

### Pitfall 5: localKey vs logicalId vs registry Key Confusion

**What goes wrong:**

Three distinct identifier namespaces are in play:

1. `localKey` — the key used within a machine's private tag map (e.g., `'temperature'` on Machine 01, `'temp_motor'` on Machine 02)
2. `logicalId` — the canonical sensor name shared across machines (e.g., `'canonical/temperature/motor'`)
3. `registry Key` — the global `TagRegistry` key used in single-machine contexts (historically also `'temperature'`)

Code that conflates any two of these produces bugs that are hard to diagnose because the keys are often strings that look plausible in both contexts. Specifically:

- Passing a `logicalId` to `machine.getTag(localKey)` → silent miss (no such local key) or wrong tag
- Storing a `localKey` as the `source.key` in a serialized fleet dashboard JSON that also expects `machineId` → loads against wrong machine or falls through to global `TagRegistry.get` (Pitfall 2)
- Using a global registry key as a `localKey` (works for single-machine by accident, fails when a second machine registers the same key — Pitfall 1)

**Why it happens:**

All three namespaces use `char` keys and the same getter pattern (`TagRegistry.get(key)` vs `machine.getTag(key)`). In the single-machine world they are the same thing. The distinction only materializes at scale, so it is easy to write new fleet code that implicitly treats them as equivalent.

**How to avoid:**

- Enforce the distinction in naming: within `Machine` the parameter is always called `localKey`; within `Fleet` queries the parameter is called `logicalId`; the global registry call always shows up as `TagRegistry.get(registryKey)`.
- The `Machine.getTag(localKey)` signature only accepts local keys.
- The `Fleet.resolveLogical(logicalId, machineId)` API is the ONLY path that converts `logicalId` → `localKey` → Tag via the canonical map. It must not be callable as `machine.getTag(logicalId)`.
- Add an assertion inside `Machine.getTag(localKey)` that errors if the key looks like a canonical key (e.g., contains `/` which is a reasonable canonical namespace separator but never appears in machine-local keys).

**Warning signs:**

- A function parameter named just `key` that is sometimes a localKey and sometimes a logicalId depending on caller
- `machine.getTag(logicalId)` calls in the comparison view (should be `fleet.resolveLogical`)
- Serialized fleet JSON where `"source": {"type": "tag", "key": "canonical/temperature/motor"}` — a logicalId stored where a localKey is expected

**Phase to address:** Machine/Fleet data model phase. The distinct parameter naming and API separation must be in the initial design, not refactored in later.

---

### Pitfall 6: Memory Over-Eager — Loading All 20+ Machines' Tags on Startup

**What goes wrong:**

A naive Fleet setup script loops over all 20 machines and calls `machine.loadAllTags()` before the user has selected any machine. On a 20-machine fleet where each machine has 200 tags and each SensorTag holds a full time-series in memory (e.g., 10,000 × 2 doubles = 160 KB per tag), startup allocates 20 × 200 × 160 KB = 640 MB before the first UI frame renders. On a machine with MATLAB's typical heap pressure, this stalls or crashes.

**Why it happens:**

The single-machine path naturally loads all tags immediately because there is only one machine and the Companion's tag catalog pane displays them all. Generalizing "load all tags" to 20 machines multiplies this work by 20 without any cost signal.

**How to avoid:**

- `Machine` uses lazy loading: tag catalog metadata (key, name, kind, units, labels) is loaded at startup; actual time-series data (`X`, `Y` arrays) is loaded only when `machine.getTag(localKey)` is first called and the tag has not yet resolved its data.
- `Fleet` startup loads only metadata for all machines; no `X`/`Y` arrays are loaded until a machine is selected by the user.
- `Machine.loadMetadata()` (light: loads only key/name/kind/units/labels from a JSON sidecar) vs `Machine.loadTag(localKey)` (heavy: loads the full `.mat` from `DataRoot`). The companion tag catalog pane calls `loadMetadata` on selection; the comparison view calls `loadTag` only for the selected subset.
- `containers.Map` memory: the map itself is small (handles only); the expensive part is the Tag objects' `X`/`Y` arrays. Lazy loading limits this to on-demand.

**Warning signs:**

- Fleet startup takes > 5 seconds on a 10-machine setup
- `whos` in MATLAB after loading a Fleet shows > 200 MB allocated before the companion opens
- `Machine.loadAllTags()` called in `Fleet.addMachine()` constructor path

**Phase to address:** Machine/Fleet data model phase. Lazy-load discipline must be the default architecture; it cannot be retrofitted cheaply.

---

### Pitfall 7: Live-Refresh Performance — Refreshing Inactive Machines on Every Tick

**What goes wrong:**

`DashboardEngine` drives refresh via a MATLAB timer at `LiveInterval` seconds. In fleet context, a user has one machine selected and its dashboard rendered. But if the fleet setup code wires all 20 machine dashboards into a single timer loop, every tick refreshes all 20 machines' widget data — most of which is not visible. On a 20-machine fleet at 5-second intervals, each tick calls `widget.refresh()` on 400+ widgets instead of ~20.

**Why it happens:**

The existing `DashboardEngine.onLiveTick()` refreshes `activePageWidgets()` — only the visible page. But if a developer creates a `DashboardEngine` per machine and calls `engine.render()` on all of them simultaneously, each engine starts its own timer. 20 timers firing every 5 seconds, each doing per-widget data resolution, degrade performance even if widgets are not visible.

**How to avoid:**

- Only the currently-selected machine's `DashboardEngine` should have an active timer. When `FastSenseCompanion` switches machines (via `setProject`), it stops the previous machine's timer and starts the new one.
- The fleet selection event (`MachineSelected`) explicitly calls `oldEngine.stop()` then `newEngine.start()` — timer lifecycle is machine-selection-driven, not always-on.
- Comparison views use their own `FastSense` instances (via `openAdHocPlot` Overlay mode); they do NOT start additional DashboardEngine timers.
- The `LiveTagPipeline` in SharedRoot/cluster mode (v4.0 feature) already manages per-machine write paths. Fleet-layer refresh must not add a second write-polling layer on top.

**Warning signs:**

- `timerfindall` after loading a Fleet returns > 2 timers (one per active machine, one for plant-log tail)
- Dashboard refresh rate degrades as more machines are loaded into the Fleet
- CPU spikes every 5 seconds proportional to the number of registered machines, not the number of visible machines

**Phase to address:** Companion machine selector phase (Phase 4 or 5). The timer lifecycle contract must be specified in that phase's plan. The data model phase (Phase 1) should note the constraint but not implement the UI wiring.

---

### Pitfall 8: Comparison View Re-Resolving on Every Tick

**What goes wrong:**

The comparison view overlays N machines' series for a single logical sensor. A naive implementation re-calls `fleet.resolveLogical(logicalId, machineId)` on every comparison view refresh tick. For a 20-machine comparison at 5-second intervals, this is 20 canonical map lookups + 20 `machine.getTag(localKey)` calls per tick, even though the tag handles are stable (they don't change between ticks — only their `X`/`Y` data changes).

**Why it happens:**

The refresh path in `FastSenseWidget.refresh()` calls `obj.Tag.getXY()` — the Tag object is stable. But comparison view likely rebuilds the Tag list from the logical sensor resolution on each tick rather than caching the Tag handles at comparison-open time.

**How to avoid:**

- At comparison-view open time, resolve all N Tag handles once and hold them in a local cell array. The comparison FastSense instance then calls `fp.addTag(tag)` once per machine — not per tick.
- On each tick, `fp.updateData()` is called (the existing incremental update path), not `fp.addTag()` again.
- The canonical map resolution is entirely outside the tick loop — it runs once at comparison setup.

**Warning signs:**

- Comparison view slows down as more machines are added, proportionally
- `CanonicalMapper.resolve` appears in MATLAB profiler output during steady-state comparison ticks
- Adding a 10th machine to the comparison causes a noticeable per-tick slowdown

**Phase to address:** Cross-machine comparison phase. Cache-at-open is a design decision for that phase.

---

### Pitfall 9: v4.0 SharedRoot Interaction — Multiple Machine LiveTagPipelines on the Same SharedRoot

**What goes wrong:**

v4.0 added `LiveTagPipeline('SharedRoot', root)` cluster mode, which uses `TagWriteCoordinator` + `FileLock` for concurrent multi-user writes. If v5.0 fleet ingestion creates one `LiveTagPipeline` per machine, all pointing to the same `SharedRoot`, the lock-contention pattern from v4.0 multiplies by the number of active machines. The v4.0 concurrency design was for multiple MATLAB sessions writing the same tag from different machines — not for one session writing 20 different machines' tags to the same root.

**Why it happens:**

The natural fleet ingestion pattern is: "for each machine, create a `LiveTagPipeline` pointing to that machine's `DataRoot`." If all machines share a NFS-mounted root, all pipelines contend on the same lock directory.

**How to avoid:**

- Each `Machine` has its own `DataRoot` — a subdirectory within the fleet's shared root, e.g., `/shared/fastsense/machines/M01/`, `/shared/fastsense/machines/M02/`. The SharedRoot lock path (`SharedPaths.locksDir(root)`) is then per-machine, not fleet-wide.
- The `LiveTagPipeline` for Machine M01 uses `SharedRoot = '/shared/fastsense/machines/M01'` — completely independent lock space from M02.
- Never create a `LiveTagPipeline` with a SharedRoot that is the parent directory of multiple machines' DataRoots.

**Warning signs:**

- `FileLock` contention errors (`LiveTagPipeline:lockTimeout`) on fleet with many active machines
- Ingestion latency grows linearly with number of active machines
- Lock directory contains interleaved lock files from multiple machines

**Phase to address:** Per-machine ingestion phase. DataRoot structure must be designed to give each machine an isolated lock space.

---

### Pitfall 10: Serialization Backward-Compat Break — Machine-Scoped Resolver Changes Single-Machine Load

**What goes wrong:**

Adding a `machineId` field to the `DashboardSerializer` resolution path changes the code path that ALL dashboards go through. If the resolver logic is: "if `source.machineId` is present, use fleet resolver; else use `TagRegistry.get`", and the `source.machineId` field is only present in fleet-created dashboards, then existing single-machine JSON and `.m` files continue to work unchanged. But if the resolver is refactored to "always use fleet resolver" (for DRY reasons), then loading an existing single-machine dashboard with `DashboardEngine.load(path)` breaks because there is no Fleet or Machine in context.

**Why it happens:**

The v2.1 Pitfall 9 (source.type `'tag'` vs `'sensor'` ambiguity) showed that the serializer has multiple resolution branches that drift over time. Adding a third branch for fleet introduces the same risk. A developer seeing the two-branch resolution in `fromStruct` may consolidate them into a single "always-fleet-if-fleet-available" path that silently breaks the single-machine load when no fleet is configured.

**How to avoid:**

- The single-machine load path is: `DashboardEngine.load(path)` → `FastSenseWidget.fromStruct(s)` → `TagRegistry.get(s.source.key)`. This path must NOT change. Zero modifications to the no-machineId path.
- The fleet load path is ONLY triggered by the presence of `s.source.machineId` in the struct. It is additive, not a replacement.
- Write a backward-compat regression test: serialize a pre-v5.0 single-machine dashboard, load it with `DashboardEngine.load`, assert all Tags resolve correctly, assert no fleet or Machine objects are required to be present.

**Warning signs:**

- `DashboardEngine.load(singleMachineJsonPath)` requires a `'SensorResolver'` argument that it did not require before v5.0
- `FastSenseWidget.fromStruct` no longer calls `TagRegistry.get` for non-fleet widgets
- Existing `examples/` dashboard scripts break after Fleet library is added to the path

**Phase to address:** Serialization phase (Phase 3). Must include the backward-compat regression test as a phase exit gate.

---

### Pitfall 11: Clone/Remap — Source Dashboard Has Tags the Target Machine Lacks

**What goes wrong:**

User clones Machine 01's dashboard onto Machine 07. Machine 01 has a `'vibration_axial'` sensor; Machine 07 does not. The clone operation iterates the source dashboard's widget structs and calls `fleet.resolveLogical(canonicalMapper.toLogical('M01', 'vibration_axial'), 'M07')` to find the equivalent local key on M07. The canonical map returns an empty result (no mapping for M07). The cloned widget on M07 has `Tag = []`.

The result is a rendered widget with an empty axes — no error, no warning, no indication to the user that a sensor is missing. The user may not notice until they notice the empty chart, which could be never if the dashboard has 20 widgets and only one is problematic.

**Why it happens:**

`FastSenseWidget` already tolerates `Tag = []` gracefully (renders empty axes, no error). This is correct behavior for the single-machine world. In the fleet clone context, `Tag = []` after a remap means the mapping failed — but the widget silently renders empty.

**How to avoid:**

- `FleetDashboardCloner.cloneTo(sourceDashboard, targetMachine, fleetResolver)` must collect all failed remaps (widgets where the canonical map returned empty or LOW confidence) and return them as a list — not silently proceed.
- The clone operation presents the user with: "These N widgets could not be rebound on Machine 07: [list]. Options: (1) Leave them empty, (2) Remove them from the clone, (3) Manually bind them now."
- A `Tag = []` widget produced by a failed remap gets a special `RebindPending = true` property so that when the machine later acquires the sensor and the map is updated, the widget can auto-rebind.

**Warning signs:**

- Cloned dashboard has empty `FastSenseWidget` axes with no explanation text
- Clone operation returns with no warnings despite the source dashboard having sensors not in the target machine's catalog
- `fleet.resolveLogical` returns `[]` silently in the clone path

**Phase to address:** Clone/remap phase. The "collect failures, surface to user" contract must be in the phase plan, not an afterthought.

---

### Pitfall 12: Fleet Config Schema Versioning — Stale JSON After CanonicalMapper Evolution

**What goes wrong:**

Fleet configuration (list of machines, canonical mappings, overrides) is serialized to JSON. Between v5.0 and v5.1, the `CanonicalMapper` rule schema changes: the `confidence` field gains a new value `'VERIFIED'` that wasn't in v5.0. Or a machine's `DataRoot` path is stored as an absolute path that no longer resolves after the files are moved to a new server.

A user's fleet config JSON from v5.0 fails to load in v5.1 with an undecipherable error. Or worse: it loads silently but the `VERIFIED` entries are interpreted as `LOW` (unknown enum value downgraded), and previously-reviewed mappings are silently re-queued for review.

**Why it happens:**

Fleet configuration is a new schema with no prior precedent in this codebase. Dashboard JSON has backward-compat handling (normalizeToCell, missing-field defaults). Fleet config starts from scratch and may not have the same defensive patterns until a compatibility break is experienced.

**How to avoid:**

- Fleet config JSON must include a `"fleetConfigVersion": "1"` field from the first commit. Every loader begins with: `if ~isfield(config, 'fleetConfigVersion'); config.fleetConfigVersion = '1'; end` — default-to-v1 for any file missing the field.
- Unknown enum values (e.g., `confidence` field) are treated as `LOW` AND logged as a warning, not silently downgraded.
- `DataRoot` paths are stored as relative paths from the fleet config file location (not absolute), using `fullfile(fleetConfigDir, machine.DataRoot)` to resolve at load time. Absolute paths are accepted but flagged with a warning at load time.
- Schema changelog is maintained in the Fleet library header comment.

**Warning signs:**

- Fleet config JSON does not have a `fleetConfigVersion` field
- `DataRoot` values are absolute paths like `/Users/hannessuhr/data/machines/M01`
- Unknown field in loaded struct is silently ignored rather than producing a warning

**Phase to address:** Fleet config persistence phase (part of Machine/Fleet data model phase).

---

### Pitfall 13: Octave Parity — UI Assumptions in the Data Model

**What goes wrong:**

The Fleet data model (`Machine`, `Fleet`, `CanonicalMapper`) must run under Octave 7+ because `BatchTagPipeline` and `LiveTagPipeline` — which feed the fleet — already run on Octave. But if the `Machine` constructor calls any uifigure/uipanel API (e.g., to emit a "loading" indicator), or if `Fleet` uses `uitree`, `uigridlayout`, or any component from MATLAB App Designer, it silently fails on Octave.

The companion machine selector UI is MATLAB-only (the FastSenseCompanion already guards with `if ~exist('OCTAVE_VERSION', 'builtin')` before uifigure calls). The risk is that a developer writing `Machine.loadMetadata()` also adds a `fprintf('[Machine] loading...\n')` guarded by `obj.Verbose`, then later replaces that with a `uiprogressdlg` call because "it looks nicer" — which then fails on Octave CI.

**Why it happens:**

Machine and Fleet are new classes. The Octave-safety boundary (data model = Octave-safe; companion UI = MATLAB-only) is a constraint from PROJECT.md that is easy to violate incrementally. There is no enforced separation — it is a convention.

**How to avoid:**

- `libs/Fleet/` may NEVER contain `uifigure`, `uicontrol`, `uitree`, `uigridlayout`, `uipanel` (when used as a UI component), `uiprogressdlg`, `uialert`, `uibutton`, or any App Designer component. These live exclusively in `libs/FastSenseCompanion/`.
- Octave CI must exercise the Fleet data model directly: `tests/suite/TestMachine.m` and `tests/test_machine.m` (flat) run on both platforms.
- Phase exit gate: `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout\|uiprogressdlg\|uialert\|uibutton" libs/Fleet/` returns 0 hits.

**Warning signs:**

- A `Machine` or `Fleet` method calls any `ui*` function
- Fleet tests fail on Octave with "undefined function uifigure"
- `contains()` used in Fleet data model code without a fallback — `contains` is available in Octave 7+ but should be verified; safer to use `~isempty(strfind(...))` when in doubt

**Phase to address:** Machine/Fleet data model phase. The Octave-safety gate must be a phase exit condition from the start.

---

### Pitfall 14: Octave Parity — `contains()`, `jsonencode` of Cells, `**` Glob

**What goes wrong:**

Three concrete Octave parity traps relevant to fleet code:

1. `contains(str, pattern)` — available in Octave 7+, but some Octave CI configurations run 6.x; also `contains` with a cell array of patterns (`contains(str, {'a','b'})`) is not reliably supported across all Octave versions. The `libs/Concurrency/ClusterConfig.m` already uses bare `contains()` (4 call sites). Fleet code in `CanonicalMapper` that does string matching on sensor keys may naturally reach for `contains`.

2. `jsonencode` with cell arrays containing `{}` — Octave's `jsonencode` and MATLAB's differ in how they encode `{}` (empty cell): MATLAB emits `[]`, Octave may emit `null`. Fleet config serialization via `jsonencode` on a `CanonicalMapper` struct with empty override lists may produce subtly different JSON that breaks cross-platform load.

3. `**` glob for recursive file discovery — Octave does not support `**` in `dir('path/**/*.mat')`. Fleet DataRoot scanning that uses recursive glob will silently fail on Octave, returning an empty result that is mistaken for "no data."

**Why it happens:**

Fleet code involves string comparison (canonical key matching), JSON serialization (config persistence), and file system traversal (DataRoot scanning) — all three Octave divergence zones. All three are easy to write correctly on MATLAB and silently wrong on Octave.

**How to avoid:**

1. Use `~isempty(strfind(str, pattern))` instead of `contains()` in Fleet data model code, or add an explicit Octave version check. Do NOT rely on `contains()` being available.
2. Use the `saveJSON`/`loadJSON` pattern from `DashboardSerializer` (manual per-field JSON encoding for complex structures) rather than bare `jsonencode` on structs with cell array fields for fleet config serialization.
3. Use explicit iterative `dir('path/*.mat')` with depth-limited manual recursion (same pattern as `BatchTagPipeline` uses for DataRoot scanning) instead of `**` glob.

**Warning signs:**

- `contains(` in any file under `libs/Fleet/`
- `jsonencode(` called directly on a struct with cell array fields in fleet config serialization
- `dir('**/` patterns in DataRoot scanning code

**Phase to address:** Machine/Fleet data model phase and Fleet config persistence. Flag at code review.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Use global `TagRegistry.register` for machine tags during development "to unblock UI work" | Single-machine code works; can test companion UI | `TagRegistry:duplicateKey` crashes when a second machine is loaded; architectural debt hardened by all the code that now relies on global resolution | Never. Machine tag isolation must be established in Phase 1 before any other fleet feature. |
| Store `DataRoot` as absolute paths in fleet config | No path-translation logic needed | Config files are not portable across machines, servers, or user directories; breaks when data moves | Only as a temporary dev shortcut, never in committed fleet config files. Must be replaced with relative paths before any phase exit. |
| Skip confidence field in CanonicalMapper — all mappings are HIGH by default | Simpler initial implementation | False HIGH-confidence mappings silently include wrong sensors in comparisons; no audit trail | Never. Confidence must be an explicit field from Phase 1 of the mapper. |
| Resolve canonical map on every comparison tick (no cache) | No stale-handle complexity | 20 lookups × 12 ticks/minute × potentially expensive map operations; comparison view slows as fleet grows | Only in unit tests where simplicity matters; never in production comparison view. |
| Single `DashboardEngine` timer for all machines' dashboards | Simpler lifecycle management | All 20 machines' widgets refreshed every tick even when not visible | Never. Timer lifecycle must be machine-selection-driven from the companion machine selector phase. |
| Propagate `machineId` only in fleet-created JSON, silently not in single-machine JSON | Backward compat trivially satisfied | Two code paths for resolution diverge silently; future refactor risk | Acceptable and correct — this is the designed approach. But document it explicitly in the serializer comment so a future developer doesn't "clean up" the divergence. |
| `CanonicalMapper` regex rules over-eager to avoid empty unmapped tail | Good first-impression demo | Silently wrong comparisons (Pitfall 3) | Never. It is better to have 30% unmapped and correct than 100% mapped and subtly wrong. |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| `BatchTagPipeline` with fleet context | Call pipeline without `'Machine'` arg, letting it register to global TagRegistry | Add `'Machine', machineHandle` NV pair; pipeline writes to `machine.Tags_` map; global registry untouched |
| `DashboardEngine.load` for fleet dashboard | Call without resolver; `FastSenseWidget.fromStruct` silently falls back to `TagRegistry.get` (returns wrong tag or errors) | Always pass `'SensorResolver', @(machineId, key) fleet.resolveTag(machineId, key)` when loading fleet dashboards |
| Comparison view Tag handles | Re-resolve `fleet.resolveLogical` on every tick | Resolve all N Tag handles once at comparison-open; pass to `FastSense.addTag` once; subsequent ticks call `fp.updateData()` only |
| v4.0 SharedRoot + fleet | Create one `LiveTagPipeline` with `SharedRoot` = fleet root, shared by all machines | Each machine gets its own `SharedRoot` = `fullfile(fleetRoot, 'machines', machineId)`, giving isolated lock space |
| `CanonicalMapper` override persistence | Store overrides in-memory only | Persist overrides to the fleet config JSON; reload them at Fleet startup; never lose manually-entered overrides |
| Companion `setProject` with machine change | Start new machine's timer without stopping the old one | `oldEngine.stop()` before `newEngine.start()`; or let `setProject` handle timer lifecycle explicitly |
| `Machine.getTag(key)` missing key | `Machine.getTag` throws if key absent (mirrors `TagRegistry.get` hard-error pattern) | Use `machine.hasTag(key)` guard before calling `getTag` in comparison view iteration over machines |
| Fleet config `DataRoot` path validation | Accept path string without checking existence | Validate at load time: `if ~exist(machine.DataRoot, 'dir'); warning(...)`. Never error on missing DataRoot — machines may be temporarily offline; warn and mark machine as `DataRootMissing`. |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Eagerly loading all machine Tag `X`/`Y` data at Fleet startup | Startup takes 10–30 seconds; MATLAB out-of-memory on large fleets | Metadata-only load at startup; lazy-load `X`/`Y` on first `getTag` call or machine selection | At 5+ machines with 200 tags × 10k samples each (~3.2 MB per tag) |
| Canonical map resolution inside live tick loop | Comparison view slows proportionally to fleet size; profiler shows `CanonicalMapper.resolve` in hot path | Cache Tag handles at comparison-open time; resolve once, reuse every tick | At 10+ machines in comparison view with 5-second refresh |
| All-machine DashboardEngine timers always running | CPU baseline rises proportionally to fleet size; each timer fires regardless of visibility | One active timer per selected machine; stop unselected machine timers on machine switch | At 3+ machines simultaneously rendered |
| `containers.Map` growth unbounded across session | Memory creep over a long MATLAB session as machines are loaded and never unloaded | Add `Machine.unload()` that clears the `Tags_` map for an inactive machine; call when machine is deselected and `KeepInMemory` is false | In long-running sessions with frequent machine switching on >5-machine fleets |
| `CanonicalMapper.autoMap()` re-running on every Fleet reload | Full edit-distance comparison across 20×200 keys = 80,000 comparisons at startup | Run `autoMap()` once, persist results to fleet config JSON, reload from JSON on subsequent starts | Immediately on any fleet with > 10 machines if autoMap runs at startup |

---

## "Looks Done But Isn't" Checklist

- [ ] **Machine isolation:** After loading Machine M01 and M02, `TagRegistry.list()` shows 0 machine tags — both machines' tags live only in their own `Tags_` maps. Verify: `TagRegistry.clear(); fleet.load(config); assert(isempty(TagRegistry.catalog().keys()))`.
- [ ] **Resolver propagation:** `DashboardEngine.load(fleetDashboardJson)` without `'SensorResolver'` warns, not silently loads with empty Tags. Verify: load a fleet JSON without resolver; assert all FastSenseWidget.Tag properties are [] AND a warning was issued.
- [ ] **Multi-page resolver propagation:** `DashboardEngine.load` multi-page path (line 4384) propagates resolver to `createWidgetFromStruct`. Verify: load a multi-page fleet dashboard; assert Tags resolved on page 2 widgets.
- [ ] **Backward compat:** Existing pre-v5.0 single-machine JSON loads without change. Verify: load `examples/` dashboard JSON files; assert no new required arguments; assert TagRegistry.get still resolves them.
- [ ] **CanonicalMapper confidence gate:** Comparison view does not overlay any series from a machine with LOW-confidence or unreviewed canonical mapping. Verify: add a LOW-confidence mapping, open comparison view, assert missing machine raises a warning instead of plotting.
- [ ] **Clone/remap failure surfacing:** Cloning a dashboard onto a machine missing one sensor returns a warnings list, not a silent empty widget. Verify: clone a 5-widget dashboard where target machine lacks one sensor; assert returned warning list has 1 entry; assert 4 widgets rebound correctly.
- [ ] **Octave gate:** All files in `libs/Fleet/` pass `grep -rn "uifigure\|uicontrol\|uitree\|uigridlayout" libs/Fleet/` with 0 hits. Verify: run the Fleet data model tests under Octave CI.
- [ ] **Timer count:** After selecting Machine M03 from Machine M01, `numel(timerfindall)` returns the same count as before machine switch (old timer stopped, new timer started). Verify: `t1 = numel(timerfindall); companion.selectMachine(m03); assert(numel(timerfindall) == t1)`.
- [ ] **Fleet config round-trip:** `Fleet.save(path); fleet2 = Fleet.load(path); assert(fleet2.machineCount == fleet.machineCount)`. Verify on both MATLAB and Octave.
- [ ] **Unmapped tail visible:** After `CanonicalMapper.autoMap()`, all sensor keys that could not be matched appear in `mapper.unmapped(machineId)`. Verify: add a machine with a unique sensor key not present on any other machine; assert that key appears in `unmapped`.

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| 1 Machine tags in global registry | HIGH — requires retrofitting `Machine.registerTag` and updating all fleet ingestion call sites | Grep all `TagRegistry.register` calls in `libs/Fleet/`; replace each with `machine.registerTag`; add regression test; clear global registry and re-run fleet load |
| 2 Resolver not propagated in multi-page path | LOW | Find all `createWidgetFromStruct` call sites in DashboardEngine that don't pass resolver; add resolver propagation; add multi-page round-trip test |
| 3 False canonical map match | MEDIUM | Lower confidence threshold; move affected mappings to LOW; add unit-consistency check; re-run comparison with new threshold; user must re-review |
| 5 localKey/logicalId confusion | MEDIUM | Rename all ambiguous `key` parameters to `localKey` or `logicalId`; add assertion in `Machine.getTag` rejecting canonical-format keys; search call sites |
| 6 Eager tag loading performance | HIGH if `X`/`Y` arrays already in memory-bound code | Extract `Machine.loadMetadata()` from `Machine.loadAllTags()`; gate `X`/`Y` loading behind `machine.getTag()` lazy path; may require Tag class change to support deferred data loading |
| 10 Resolver breaks backward compat | LOW | The fix is additive: check `s.source.machineId` presence first; if absent, use existing `TagRegistry.get` path. No existing path modified. |
| 11 Clone/remap silent failure | LOW | Add remap-failure return value; add warning emit for empty rebinding results; update tests |
| 13 UI API in data model | LOW-MEDIUM | Grep `libs/Fleet/` for `ui*` calls; extract to companion layer; run Octave CI to verify clean |
| 14 Octave parity breaks | LOW per item | `contains` → `strfind`; `jsonencode` of cells → manual encoding; `**` glob → iterative `dir` |

---

## Pitfall-to-Phase Mapping

| Pitfall | Primary Phase | Gate Mechanism |
|---------|---------------|----------------|
| 1 Machine tags in global registry | Phase 1: Machine/Fleet data model | `grep -rn "TagRegistry.register" libs/Fleet/` returns 0 |
| 2 Serializer resolver not propagated | Phase 3: Serialization + backward compat | Multi-page fleet JSON load test; resolver-required warning test |
| 3 Canonical mapping false matches | Phase 2: CanonicalMapper | Confidence field required in schema; LOW-confidence comparison-gate test |
| 4 Canonical mapping false misses | Phase 2: CanonicalMapper | `mapper.unmapped(machineId)` returns non-empty for machines with novel keys |
| 5 localKey vs logicalId confusion | Phase 1: Machine/Fleet data model | Naming convention enforced in `Machine` and `Fleet` API signatures |
| 6 Eager memory load at scale | Phase 1: Machine/Fleet data model | Fleet startup with 5-machine test dataset completes in < 2s; whos shows < 50 MB |
| 7 Inactive machine timer refresh | Phase 4/5: Companion machine selector | `timerfindall` count stable across machine switches |
| 8 Comparison view per-tick resolution | Phase 5/6: Cross-machine comparison | Profiler: `CanonicalMapper.resolve` absent from steady-state tick profile |
| 9 SharedRoot lock contention | Phase 1: Per-machine ingestion | Each machine `DataRoot` is a separate subdirectory; lock files are isolated |
| 10 Backward-compat break on load | Phase 3: Serialization + backward compat | Existing single-machine JSON round-trip test passes unchanged |
| 11 Clone/remap silent failure | Phase 6: Clone/remap | Clone with missing sensor returns non-empty warning list |
| 12 Fleet config schema versioning | Phase 1: Fleet config persistence | `fleetConfigVersion` field present; unknown-field warning test |
| 13 Octave UI in data model | Phase 1: Machine/Fleet data model | `grep libs/Fleet/ "ui*"` returns 0; Octave CI green on Fleet tests |
| 14 Octave parity (contains, jsonencode, glob) | All phases touching Fleet code | `grep -rn "contains(" libs/Fleet/` 0 hits; Octave smoke test |

---

## Sources

- `libs/SensorThreshold/TagRegistry.m` — hard-error on duplicate key (line 90), `persistent` catalog (lines 417–420), `eventStoreRef_` persistent slot (lines 424–431). Confirmed: 30 files call `TagRegistry.register` across `libs/`.
- `libs/Dashboard/DashboardSerializer.m` — `linesForWidget` emits `TagRegistry.get(...)` directly (lines 44, 47, 793, 796); `configToWidgets` accepts a `resolver` but does not propagate it into `createWidgetFromStruct`; multi-page path at `DashboardEngine.m:4384` calls `createWidgetFromStruct` without resolver.
- `libs/Dashboard/FastSenseWidget.m` — `fromStruct` (lines 1513–1520) calls `TagRegistry.get(s.source.key)` directly bypassing any external resolver.
- `libs/Dashboard/DashboardEngine.m` — `load()` function (lines 4345–4412) shows the resolver is accepted but not threaded into the multi-page widget construction path.
- `libs/SensorThreshold/LiveTagPipeline.m` — SharedRoot/cluster mode (lines 161, 225–241); `TagWriteCoordinator` wiring; demonstrates per-machine DataRoot isolation requirement.
- `libs/Concurrency/ClusterConfig.m` — uses `contains()` (4 call sites); reference for Octave parity risk.
- `.planning/milestones/v4.0-research/PITFALLS.md` — prior pitfall depth/format; concurrency pitfall patterns for SharedRoot already documented.
- `.planning/PROJECT.md` — v5.0 design decisions: Machine owns isolated tag map, TagRegistry untouched, `DashboardSerializer` fleet resolver seam, backward-compat hard constraint, 20+ machine scale target.
- `.planning/research/FEATURES.md` — fleet feature requirements informing which pitfalls are highest priority.

---
*Pitfalls research for: v5.0 Multi-Machine Fleet addition to FastSense Advanced Dashboard*
*Researched: 2026-06-02*
