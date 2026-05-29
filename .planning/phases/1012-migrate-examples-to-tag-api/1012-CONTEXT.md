# Phase 1012: Migrate examples to Tag API - Context

**Gathered:** 2026-04-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Migrate all scripts under `examples/` from the now-deleted legacy API (`Sensor`, `addThresholdRule`, `SensorRegistry`, `ThresholdRule`, `StateChannel`) to the v2.0 Tag API (`SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry`, `EventBinding`).

**Urgency:** Phase 1011 deleted the legacy classes. The 28 example files currently referencing `Sensor(...)`, `addThresholdRule(...)`, `SensorRegistry.*` are broken at load/run time. This phase ships green examples for `examples.yml` CI.

**In scope:**

1. Replace legacy API calls in 28 existing example files (88 occurrences) with the Tag equivalents — preserve each example's narrative, axes, titles, plot intent.
2. Fix half-migrated stubs (e.g. `examples/02-sensors/example_sensor_threshold.m` has orphan `% Idle: threshold at 70` comments without replacement code) — rewrite in place.
3. Add a new showcase folder `examples/02-sensors/tags/` teaching each Tag primitive in isolation (5 scripts).
4. Rewrite `example_sensor_threshold.m` as the canonical **end-to-end event-binding demo** (Sensor → Monitor → EventStore → EventBinding → FastSense round-marker overlay).
5. Add `tests/test_examples_smoke.m` that runs every example non-interactively and reports pass/fail per example. Wire into `tests/run_all_tests.m`.
6. Rewrite `examples/run_all_examples.m` to iterate every `.m` under `examples/**` with per-example `try/catch` and a summary at the end.

**Out of scope:**

- Any change to library code under `libs/` (v2.0 Tag API is shipped; this phase only consumes it).
- Any WebBridge example changes beyond API swap.
- New widget types, new Tag kinds, new tests for Tag classes themselves (those live in `tests/suite/Test*Tag.m`).
- Renaming/renumbering top-level example folders (`01-basics/`, `02-sensors/`, …) — additive only.

</domain>

<decisions>
## Implementation Decisions

### Threshold & Monitor semantics

- **Threshold lines in examples** — keep using `fp.addThreshold(value, 'Label', 'Upper')`. This is a visual overlay on FastSense, unrelated to the deleted `Sensor.addThresholdRule` API; no migration needed beyond leaving it alone.
- **State-dependent thresholds** (the legacy `addThresholdRule('Condition','state==1','Value',55)` pattern) — replace with a `MonitorTag` whose `ConditionFn` closes over a `StateTag`, e.g. `@(x,y) y > thresholdForState(stateTag.valueAt(x))`. Single canonical demo in the rewritten `example_sensor_threshold.m`.
- **Event-binding end-to-end demo** — lives in the rewritten `example_sensor_threshold.m`: pressure `SensorTag` → state-dependent `MonitorTag` with `EventStore` attached → `EventBinding` registry → FastSense overlay round markers. This replaces the old "threshold violation" narrative with the marquee v2.0 flow.
- **Half-migrated `example_sensor_threshold.m`** — rewrite in place (don't delete); preserve the "dynamic pressure / machine state" narrative.

### Tag showcase folder

- **Location:** `examples/02-sensors/tags/` — subfolder of the existing sensors examples; no top-level renumbering.
- **Scripts (5 files, one per primitive):**
  - `example_tag_sensor.m` — `SensorTag` basics: construct, inline data, `TagRegistry.register`, plot via `fp.addTag(tag)`.
  - `example_tag_state.m` — `StateTag` ZOH lookup, numeric + cellstr Y forms, `valueAt` demo.
  - `example_tag_monitor.m` — `MonitorTag` lazy binary signal from a `SensorTag` parent; `ConditionFn`, `MinDuration`, `AlarmOffConditionFn` (hysteresis); parent-driven `invalidate()`.
  - `example_tag_composite.m` — 3-child `CompositeTag` (`and` / `or` / `majority` / `worst`) aggregating two `MonitorTag`s on different parents; show merge-sort streaming ZOH aggregation.
  - `example_tag_registry.m` — `TagRegistry` CRUD: `register`, `get`, `findByLabel`, `findByKind`, `printTable`, `loadFromStructs`, `unregister`, `clear`. Matches the existing `example_sensor_registry.m` shape but uses Tag API exclusively.
- **Registry usage** — every showcase constructs tags **and** registers them via `TagRegistry.register(key, tag)` so learners see both the direct-handle and registry-lookup patterns in the same file.

### Migration mechanics

- **Migration style** — minimal textual diff per file: preserve narrative, titles, axes, plot shape. Don't refresh examples opportunistically. Keep reviews focused on API-surface substitution.
- **Commit granularity** — one commit per example folder (`01-basics/`, `02-sensors/`, `02-sensors/tags/` as its own commit, `03-dashboard/`, `04-widgets/`, `05-events/`, `06-webbridge/`, `07-advanced/`). ~8 atomic commits. Bisectable and reviewable. Matches Phase 1009 "per-widget commit" precedent.
- **`run_all_examples.m`** — rewrite to recursively walk `examples/**/*.m`, run each in a `try/catch`, and print a summary `{passed, failed, skipped}` with failing script paths. Failure is non-fatal to the loop; fatal to the script's own exit code (exit 1 if any failure). This keeps the script the primary human entry point while also being CI-driveable.

### Verification

- **Smoke test** — new `tests/test_examples_smoke.m`:
  - Runs every `examples/**/*.m` file non-interactively (`close all`, headless figure windows).
  - Collect-all-errors: one failing example does not stop the others.
  - Fail at end if any example errored; report `{file, error.identifier, error.message}` for each failure.
  - Wire into `tests/run_all_tests.m` so it runs in the main CI test job.
- **Platform** — Run on both MATLAB and Octave in CI (matches existing `examples.yml` matrix — no need for a new workflow).

### Claude's Discretion

- Exact internal structure of showcase scripts (comment density, section headers, amount of `fprintf` progress output) — use existing `examples/02-sensors/example_sensor_registry.m` as style template.
- Whether `example_sensor_threshold.m` event demo uses numeric `StateTag.Y` or cellstr states — pick whichever reads more naturally in a ~120-line demo.
- Whether the smoke test skips examples that require user input (if any such still exist after migration — inspect during planning).
- Exact wording/format of the migration commit messages — follow Phase 1009 conventions (`refactor(examples): migrate 01-basics to Tag API`, etc.).

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets

- **Tag API surface** (all shipped, stable after Phase 1011):
  - `SensorTag(key, 'Name', …, 'Units', …, 'X', t, 'Y', y)` — drop-in for legacy `Sensor(key, ...)` + `.updateData(t,y)`.
  - `StateTag(key, 'X', [...], 'Y', [...])` — drop-in for legacy `StateChannel`.
  - `MonitorTag(parent, 'ConditionFn', fn, 'MinDuration', d, 'AlarmOffConditionFn', fn, 'EventStore', store)` — replaces the violation side-effects that used to live in `Sensor.resolve()`.
  - `CompositeTag('AggregateMode', mode, 'Children', {...})` — replaces any `CompositeThreshold` usage.
  - `TagRegistry.register / get / findByLabel / findByKind / printTable / list / loadFromStructs / unregister / clear` — direct analog of legacy `SensorRegistry`, but HARD-ERRORS on duplicate key (Pitfall 7).
  - `EventBinding.bind(eventStore, tagKey, monitorKey)` — Phase 1010 many-to-many binding registry for the event overlay.
- **FastSense API:**
  - `fp.addTag(tag)` — replaces legacy `fp.addSensor(sensor)`; accepts any Tag subclass (SensorTag for lines, MonitorTag/CompositeTag for binary overlays).
  - `fp.addThreshold(value, 'Label', label)` — unchanged, visual-only; keep as-is.

### Established Patterns

- **Example file header** — all existing examples open with the same 3-line path-setup preamble; preserve verbatim:
  ```matlab
  projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
  run(fullfile(projectRoot, 'install.m'));
  ```
- **Example style template** — `examples/02-sensors/example_sensor_registry.m` is a well-structured, already-migrated example demonstrating section headers, progressive disclosure, and explicit learning objectives at the top. Use as template for the new showcase scripts.
- **Test harness** — `tests/run_all_tests.m` already discovers `test_*.m` + `suite/Test*.m`; the new smoke test just needs to follow that naming convention.

### Integration Points

- `examples/run_all_examples.m` — already exists, rewrite in place.
- `tests/run_all_tests.m` — new `test_examples_smoke.m` auto-picked up by existing discovery.
- `.github/workflows/examples.yml` — already runs example scripts in CI; confirm the new smoke test slots in (may be sufficient without workflow changes).
- `examples/02-sensors/` — receives the new `tags/` subfolder.

</code_context>

<specifics>
## Specific Ideas

- The rewritten `example_sensor_threshold.m` should tell an unambiguously v2.0 story:
  1. Create `SensorTag('pressure', …)` with 10k-point synthetic chamber pressure.
  2. Create `StateTag('mode', …)` with 4 state transitions.
  3. Create `MonitorTag` whose `ConditionFn` closes over the state tag to pick the active threshold.
  4. Attach an `EventStore` so violations emit events.
  5. Bind the store to the monitor via `EventBinding`.
  6. Render on `FastSense` with `addTag(sensorTag)` + `addTag(monitorTag)` + `addThreshold(...)` overlay lines + event round-markers.
  7. Print a summary: "Detected N violations across M state transitions."
- The showcase `example_tag_composite.m` should demonstrate **at least two `AggregateMode`s** side by side — `and` and `majority` — so the truth-table intuition is immediate.
- `example_tag_registry.m` should explicitly demonstrate the v2.0 behaviour delta vs. `SensorRegistry`: **duplicate-key HARD-ERROR on `register`** (Pitfall 7). Wrap one register-twice in a `try/catch` and `fprintf` the error identifier to show the contract.

</specifics>

<deferred>
## Deferred Ideas

- Migrating WebBridge (`examples/06-webbridge/example_webbridge.m`) to consume Tag API over the wire — only swap the MATLAB-side construction; bridge protocol changes, if any, are a separate phase.
- A `docs/MIGRATION-v1-to-v2.md` cheat sheet summarising every legacy→Tag rename — would live in `docs/` not `examples/`; track as a separate todo (candidate for `/gsd:add-todo` post-phase).
- Interactive tag browser GUI (`TagRegistry.viewer()`) example — already exists as a method; a dedicated demo script is nice-to-have, not blocking.
- Rewriting the golden integration test (`tests/test_golden_integration.m`) — was touched in Phase 1011; not in this phase's scope.
- Deleting or archiving any example that is now redundant with a new showcase script — defer until after migration: first pass is API-swap only, a second pass can prune duplicates.

</deferred>
