# Phase 1012: Migrate examples to Tag API - Research

**Researched:** 2026-04-17
**Domain:** MATLAB example-script bulk migration (legacy Sensor/Threshold/StateChannel → Tag API) + CI smoke-test wiring
**Confidence:** HIGH (all deltas are code-visible in this worktree; Tag API is stable; CI workflow is already provisioned)

## Summary

Phase 1011 deleted the six legacy SensorThreshold classes (`Sensor`, `Threshold`, `ThresholdRule`, `StateChannel`, `CompositeThreshold`, `SensorRegistry`, `ExternalSensorRegistry`). A large string-level migration has already been applied to `examples/` — **direct constructor calls are all gone** (zero `Sensor(`, `Threshold(`, `StateChannel(`, `CompositeThreshold(`, `ThresholdRule(` in the tree). What remains is (a) a small set of residual legacy-method/property references the string-replace pass did not cover, (b) orphan "threshold setup" comment blocks left behind when `addThresholdRule` calls were deleted without replacement, and (c) a live-fail risk: `EventConfig.addSensor()` is now a stub that hard-errors, so the three event examples will explode at runtime if executed.

The Tag API surface required for migration is small and fully stable: `SensorTag`/`StateTag`/`MonitorTag`/`CompositeTag` + `TagRegistry` + `EventBinding` + `FastSense.addTag`/`addThreshold`/`ShowEventMarkers`. Dashboard widgets already accept `'Tag'` as an NV-pair alias for sensor binding (Phase 1009 shipped this). The `addThreshold(value, 'Label', ...)` visual-overlay API on FastSense is unchanged and must be left alone.

**Primary recommendation:** Organize the plan as seven per-folder commits (matching Phase 1009's "one commit per consumer cluster" precedent): `01-basics/`, `02-sensors/` (existing files), `02-sensors/tags/` (new showcase), `03-dashboard/`, `04-widgets/`, `05-events/` (rewrite-heavy — `EventConfig.addSensor` is dead; swap to `MonitorTag+EventStore+EventBinding`), `06-webbridge/` + `07-advanced/` (tiny touch-ups), and `examples/` root (`run_all_examples.m` rewrite + `demo_all.m` audit + new `tests/test_examples_smoke.m`). The event-binding showcase (`example_sensor_threshold.m` rewrite) and five Tag-primitive showcase scripts are landed in their respective folder commits.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Threshold & Monitor semantics**
- Threshold lines in examples — keep using `fp.addThreshold(value, 'Label', 'Upper')`. This is a visual overlay on FastSense, unrelated to the deleted `Sensor.addThresholdRule` API; no migration needed beyond leaving it alone.
- State-dependent thresholds (the legacy `addThresholdRule('Condition','state==1','Value',55)` pattern) — replace with a `MonitorTag` whose `ConditionFn` closes over a `StateTag`, e.g. `@(x,y) y > thresholdForState(stateTag.valueAt(x))`. Single canonical demo in the rewritten `example_sensor_threshold.m`.
- Event-binding end-to-end demo — lives in the rewritten `example_sensor_threshold.m`: pressure `SensorTag` → state-dependent `MonitorTag` with `EventStore` attached → `EventBinding` registry → FastSense overlay round markers. This replaces the old "threshold violation" narrative with the marquee v2.0 flow.
- Half-migrated `example_sensor_threshold.m` — rewrite in place (don't delete); preserve the "dynamic pressure / machine state" narrative.

**Tag showcase folder**
- Location: `examples/02-sensors/tags/` — subfolder of the existing sensors examples; no top-level renumbering.
- Scripts (5 files, one per primitive):
  - `example_tag_sensor.m` — `SensorTag` basics: construct, inline data, `TagRegistry.register`, plot via `fp.addTag(tag)`.
  - `example_tag_state.m` — `StateTag` ZOH lookup, numeric + cellstr Y forms, `valueAt` demo.
  - `example_tag_monitor.m` — `MonitorTag` lazy binary signal from a `SensorTag` parent; `ConditionFn`, `MinDuration`, `AlarmOffConditionFn` (hysteresis); parent-driven `invalidate()`.
  - `example_tag_composite.m` — 3-child `CompositeTag` (`and` / `or` / `majority` / `worst`) aggregating two `MonitorTag`s on different parents; show merge-sort streaming ZOH aggregation.
  - `example_tag_registry.m` — `TagRegistry` CRUD: `register`, `get`, `findByLabel`, `findByKind`, `printTable`, `loadFromStructs`, `unregister`, `clear`. Matches the existing `example_sensor_registry.m` shape but uses Tag API exclusively.
- Registry usage — every showcase constructs tags **and** registers them via `TagRegistry.register(key, tag)` so learners see both the direct-handle and registry-lookup patterns in the same file.

**Migration mechanics**
- Migration style — minimal textual diff per file: preserve narrative, titles, axes, plot shape. Don't refresh examples opportunistically. Keep reviews focused on API-surface substitution.
- Commit granularity — one commit per example folder (`01-basics/`, `02-sensors/`, `02-sensors/tags/` as its own commit, `03-dashboard/`, `04-widgets/`, `05-events/`, `06-webbridge/`, `07-advanced/`). ~8 atomic commits. Bisectable and reviewable. Matches Phase 1009 "per-widget commit" precedent.
- `run_all_examples.m` — rewrite to recursively walk `examples/**/*.m`, run each in a `try/catch`, and print a summary `{passed, failed, skipped}` with failing script paths. Failure is non-fatal to the loop; fatal to the script's own exit code (exit 1 if any failure). This keeps the script the primary human entry point while also being CI-driveable.

**Verification**
- Smoke test — new `tests/test_examples_smoke.m`:
  - Runs every `examples/**/*.m` file non-interactively (`close all`, headless figure windows).
  - Collect-all-errors: one failing example does not stop the others.
  - Fail at end if any example errored; report `{file, error.identifier, error.message}` for each failure.
  - Wire into `tests/run_all_tests.m` so it runs in the main CI test job.
- Platform — Run on both MATLAB and Octave in CI (matches existing `examples.yml` matrix — no need for a new workflow).

### Claude's Discretion

- Exact internal structure of showcase scripts (comment density, section headers, amount of `fprintf` progress output) — use existing `examples/02-sensors/example_sensor_registry.m` as style template.
- Whether `example_sensor_threshold.m` event demo uses numeric `StateTag.Y` or cellstr states — pick whichever reads more naturally in a ~120-line demo.
- Whether the smoke test skips examples that require user input (if any such still exist after migration — inspect during planning).
- Exact wording/format of the migration commit messages — follow Phase 1009 conventions (`refactor(examples): migrate 01-basics to Tag API`, etc.).

### Deferred Ideas (OUT OF SCOPE)

- Migrating WebBridge (`examples/06-webbridge/example_webbridge.m`) to consume Tag API over the wire — only swap the MATLAB-side construction; bridge protocol changes, if any, are a separate phase.
- A `docs/MIGRATION-v1-to-v2.md` cheat sheet summarising every legacy→Tag rename — would live in `docs/` not `examples/`; track as a separate todo (candidate for `/gsd:add-todo` post-phase).
- Interactive tag browser GUI (`TagRegistry.viewer()`) example — already exists as a method; a dedicated demo script is nice-to-have, not blocking.
- Rewriting the golden integration test (`tests/test_golden_integration.m`) — was touched in Phase 1011; not in this phase's scope.
- Deleting or archiving any example that is now redundant with a new showcase script — defer until after migration: first pass is API-swap only, a second pass can prune duplicates.
</user_constraints>

<phase_requirements>
## Phase Requirements

Phase 1012 owns **no exclusive REQ-IDs**. This mirrors Phase 1009's structural-consumer-migration precedent (STATE.md: "Phase 1009 owns no exclusive REQ-IDs (structural consumer-migration phase)"). All 45 v2.0 REQs already marked `[x]` in `.planning/milestones/v2.0-REQUIREMENTS.md`. This phase is maintenance downstream of MIGRATE-03 (legacy-class deletion), making the examples re-executable.

| ID | Description | Research Support |
|----|-------------|------------------|
| — (structural) | Migrate 28 example files from deleted legacy API to v2.0 Tag API; add 5 Tag-primitive showcase scripts + rewritten end-to-end event-binding demo + smoke test + runner rewrite | Tag API (§Standard Stack), Inventory (§Inventory table), Event-binding pipeline (§Code Examples — End-to-end event-binding demo) |

The planner should **not** try to backfill REQ-IDs; the work is purely consumer-side regreening after Phase 1011's destructive change. Verification gates come from two sources: (1) every example runs green under both MATLAB and Octave in `.github/workflows/examples.yml`; (2) `tests/test_examples_smoke.m` passes inside `tests/run_all_tests.m`.
</phase_requirements>

## Project Constraints (from CLAUDE.md)

| Constraint | Implication for this phase |
|------------|----------------------------|
| Pure MATLAB, no external deps | Examples must not introduce new toolbox/package requirements |
| MATLAB R2020b+ AND GNU Octave 7+ | Every migrated example must run on both; avoid MATLAB-only syntax where the existing example already worked on both |
| Backward compatibility for existing dashboard scripts | `fp.addThreshold(...)` visual-overlay API stays; `addLine`/`addBand`/`addMarker` unchanged |
| Widget contract through `DashboardWidget` | Widget NV-pair `'Tag', sensorTag` already accepted (Phase 1009); do not change widget call shape |
| Naming — `test_` prefix + snake_case for Octave function tests, `Test` prefix + PascalCase for MATLAB-suite tests | New `tests/test_examples_smoke.m` follows the Octave function-based pattern (auto-discovered by `run_all_tests.m`) |
| Error IDs format `ClassName:camelCaseProblem` | New helper code should use `ExampleSmoke:...` if errors are needed |
| Tests run via `tests/run_all_tests.m` (not pytest) | Smoke test is a plain `.m` file; no pytest involvement |
| GSD workflow enforcement — no direct edits outside GSD commands | This phase must execute through `/gsd:execute-phase`; Edit/Write tool usage is scoped to planned tasks |
| MISS_HIT 160-char line limit | New showcase scripts must satisfy MISS_HIT style; inspect `miss_hit.cfg` suppress rules for precedents |

## Standard Stack

### Core (Tag API — all in `libs/SensorThreshold/`)

| Class | Purpose | Why Standard |
|-------|---------|--------------|
| `SensorTag(key, 'Name', ..., 'Units', ..., 'X', t, 'Y', y)` | Time-series carrier; drop-in for legacy `Sensor(key, ...)` + `updateData` | Ships since Phase 1005; used in 41 files already; all Phase 1011 internal consumers upgraded |
| `StateTag(key, 'X', ..., 'Y', ...)` | Piecewise-constant ZOH state signal; drop-in for legacy `StateChannel` | Ships since Phase 1005; byte-for-byte valueAt parity with StateChannel |
| `MonitorTag(key, parentTag, conditionFn, NV...)` | Lazy-memoized 0/1 derived signal; replaces `Sensor.addThresholdRule` + `Sensor.resolve` + violation pipeline | Ships since Phase 1006 (plus 1007 streaming + opt-in persist); carrier-pattern events emit to bound EventStore |
| `CompositeTag(key, aggregateMode, NV...)` + `addChild(tagOrKey, 'Weight', w)` | Merge-sort ZOH aggregation of MonitorTag/CompositeTag children | Ships since Phase 1008; 7 AggregateModes: `and`/`or`/`majority`/`count`/`worst`/`severity`/`user_fn` |
| `TagRegistry.{register,get,find*,printTable,viewer,loadFromStructs,unregister,clear}` | Singleton catalog of Tags | Ships since Phase 1004; **HARD-ERRORS on duplicate key** (Pitfall 7; departs from SensorRegistry's silent-overwrite) |
| `EventBinding.{attach,getTagKeysForEvent,getEventsForTag,clear}` | Many-to-many eventId↔tagKey registry with O(1) bidirectional lookup | Ships since Phase 1010; idempotent on duplicate attach |

### Supporting (stable, unchanged by migration)

| API | Purpose | When to Use |
|-----|---------|-------------|
| `fp.addTag(tag)` | Polymorphic tag plot dispatcher — accepts SensorTag/StateTag/MonitorTag/CompositeTag | Replaces legacy `fp.addSensor(sensor)` everywhere |
| `fp.addThreshold(value, 'Label', ..., 'Direction', 'upper'\|'lower', 'ShowViolations', true, ...)` | Visual horizontal-line overlay with optional violation highlight | **Leave as-is** — unchanged visual API; not the deleted `Sensor.addThresholdRule` |
| `fp.addLine(x, y, ...)`, `addBand`, `addFill`, `addShaded`, `addMarker`, `addNavigator` | Primitive FastSense rendering methods | Unchanged |
| `fp.ShowEventMarkers` (Phase 1010) | Toggle round-marker overlay layer | Default true; renderEventLayer runs after renderLines |
| `EventStore(filename, 'MaxBackups', n)` | Atomic-write event persistence | Used by rewritten `example_sensor_threshold.m` |
| `EventStore.getEvents()` / `EventStore.getEventsForTag(key)` | Query events by bound tag | Phase 1009 path; used by EventTimelineWidget |
| `DashboardEngine`, widget NV-pair `'Tag', tag` | Phase 1009 already wired `'Tag'` acceptance on FastSenseWidget / NumberWidget / StatusWidget / GaugeWidget / MultiStatusWidget / IconCardWidget / HistogramWidget / TableWidget | All 30+ widget example files already use `'Tag', sTemp` — migration mainly changes how `sTemp` is *constructed*, not how it's bound |

### Alternatives Considered (and rejected)

| Instead of | Could Use | Why Rejected |
|------------|-----------|--------------|
| `MonitorTag + EventStore + EventBinding` for event pipeline | Leaving `EventConfig.addSensor` / `cfg.runDetection` calls in place | `EventConfig.addSensor` **throws** `EventConfig:legacyRemoved` (verified in `libs/EventDetection/EventConfig.m:39`); `runDetection` is now a no-op returning empty events. Calling path is dead. |
| `SensorTag` + manual sample append via `[s.X, new]; [s.Y, new]; s.updateData(X,Y)` | `s.addData(newT, newY)` | **`SensorTag` has no `addData` method** (verified via grep). `example_webbridge.m` calls `sTemp.addData(...)` which will error; rewrite with append-via-updateData pattern or keep the `updateData([s.X,newT], [s.Y,newY])` idiom already used in `example_event_detection_live.m`. |
| `TagRegistry` | Keeping `SensorRegistry.register` in comment strings of `run_all_examples.m` | `SensorRegistry.m` is deleted; even comment references in strings mislead new contributors. |

**Installation:**

No new packages. All examples rely on `install.m` (which is unchanged):

```matlab
projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));
```

**Version verification:** Not applicable — this is a pure-MATLAB first-party migration; all referenced classes live in `libs/SensorThreshold/` and `libs/EventDetection/` of the same repo. No package registry involved.

## Architecture Patterns

### Example file structure (canonical, from `example_sensor_registry.m`)

```
%% Section Header — One-Line Summary
% Multi-line description explaining what this example demonstrates:
%   - Bullet 1 of API surface exercised
%   - Bullet 2 ...
%   - ...

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. <Step one label>
<code>
fprintf('<progress message>\n');

%% 2. <Step two label>
<code>
fprintf('<progress message>\n');

...

%% N. Plot / render
fp = FastSense();
fp.addTag(s);
fp.render();
title('...');
xlabel('...');
ylabel('...');
```

**Key invariants for every example:**
1. Line 1 is a `%% Section Header` starting with `%%` (used by MATLAB section navigator).
2. Path setup is the same 3-line preamble (projectRoot + `run(install.m)`) — preserve verbatim when editing existing examples.
3. `%% N. ...` section headers use 1-based numeric prefixes.
4. `fprintf(...)` lines provide progress narration during execution (not `disp`).
5. Final step renders at least one figure via `fp.render()` or `engine.render()` or `fig.renderAll()`.
6. No `close all` inside the script unless it's an interactive `close all force; clear functions;` prologue for dashboard examples (observed in `03-dashboard/*.m` and `04-widgets/*.m`).

### Pattern 1: Direct-handle Tag construction + plot

**What:** Construct a Tag directly with inline X/Y; plot via `fp.addTag`.
**When to use:** All `01-basics/`, `07-advanced/` examples; any example not exercising the registry.
**Example:**

```matlab
% Source: examples/02-sensors/example_sensor_dashboard.m (already migrated)
s1 = SensorTag('pressure', 'Name', 'Chamber Pressure', 'Units', 'mbar', ...
    'X', t1, 'Y', 40 + 20*sin(2*pi*t1/25) + 4*randn(1, numel(t1)));

fp = FastSense();
fp.addTag(s1);
fp.render();
```

### Pattern 2: Registry-backed Tag lookup

**What:** Register a Tag, retrieve by key later (or from loadFromStructs after JSON load).
**When to use:** Multi-widget dashboards where widgets reference Tags by string key; showcase scripts.
**Example:**

```matlab
% Source: examples/02-sensors/example_sensor_registry.m
t = linspace(0, 80, 15000);
pressure = SensorTag('pressure', 'Name', 'Pressure Sensor', 'Units', 'bar', ...
    'X', t, 'Y', 45 + 18*sin(2*pi*t/20) + 4*randn(1, numel(t)));
TagRegistry.register('pressure', pressure);

s = TagRegistry.get('pressure');   % retrieve later
```

**CRITICAL:** `TagRegistry.register` HARD-ERRORS on duplicate key. Examples that run twice in the same session (or get picked up by the smoke test after a previous run already registered keys) must defensively call `TagRegistry.unregister('key')` or `TagRegistry.clear()` first — OR the smoke test must clear the registry between runs. See Pitfall 1 below.

### Pattern 3: Dashboard widget with `'Tag'` NV-pair (Phase 1009)

**What:** DashboardEngine widgets accept `'Tag', sensorTag` NV-pair for uniform binding.
**When to use:** All `03-dashboard/*.m` and `04-widgets/*.m` examples.
**Example:**

```matlab
% Source: examples/03-dashboard/example_dashboard_engine.m (already migrated)
d.addWidget('fastsense', ...
    'Position', [1 1 16 8], ...
    'Tag', sTemp);
```

This shape is already present in every migrated widget example. No changes needed here.

### Pattern 4: MonitorTag for state-dependent thresholds (replaces `addThresholdRule` with Condition)

**What:** Close `ConditionFn` over a `StateTag` to implement mode-dependent threshold logic.
**When to use:** State-dependent threshold demos (`example_sensor_threshold.m`, `example_sensor_multi_state.m`).
**Example:**

```matlab
% Source: libs/SensorThreshold/MonitorTag.m (class header example, adapted)
sensor = SensorTag('pressure', 'X', t, 'Y', y);
stateTag = StateTag('mode', 'X', [0 25 50 75], 'Y', [0 1 2 1]);

% Per-state thresholds: idle=70, running=55, evacuated=45
thresholdAt = @(s) (s==0)*70 + (s==1)*55 + (s==2)*45;
conditionFn = @(x, y) y > thresholdAt(stateTag.valueAt(x));

m = MonitorTag('pressure_alarm', sensor, conditionFn);
[mx, my] = m.getXY();  % lazy computes 0/1 on parent's grid
```

### Pattern 5: End-to-end event-binding (MonitorTag → EventStore → EventBinding → FastSense marker overlay)

**What:** Emit events from MonitorTag; render as round markers on FastSense via `ShowEventMarkers`.
**When to use:** Rewritten `example_sensor_threshold.m` (the canonical marquee demo).
**Example:** See "Code Examples — End-to-end event-binding demo" below.

### Anti-Patterns to Avoid

- **Do not register with reused keys across example runs** — TagRegistry hard-errors on duplicate. Either (a) use unique per-script keys (namespace them, e.g. `'ex_tag_sensor:pressure'`), (b) call `TagRegistry.unregister(key)` defensively at end-of-script, or (c) rely on smoke-test harness to `TagRegistry.clear()` + `EventBinding.clear()` between runs. Showcase scripts should demonstrate (b) so learners see the cleanup idiom.
- **Do not use `cfg.addSensor(...)` / `EventConfig.runDetection()`** — these are dead code paths (hard-error or no-op). Event pipeline goes through `MonitorTag` + `EventStore.append` + `EventBinding.attach` now.
- **Do not assign through `tag.X = ...` / `tag.Y = ...` on SensorTag** — legacy `Sensor` exposed settable `X`/`Y` as public. `SensorTag.X`/`.Y` are read-only dependent properties (get.X/get.Y only). **Current issue:** `examples/04-widgets/example_widget_fastsense.m` lines 36 & 45 do `sTemp.X = t; sTemp.Y = baseTemp + ...` — these **will error at runtime**. Replace with `sTemp.updateData(t, baseTemp + ...)` or pass via constructor `'X', t, 'Y', baseTemp + ...`.
- **Do not use `.ResolvedViolations` / `.ResolvedThresholds` / `.countViolations()` / `.currentStatus`** — Sensor properties/methods removed in Phase 1011. Replacement: run a `MonitorTag`, read `EventStore.getEventsForTag(sensor.Key)`, count its length.
- **Do not use `.addData(t, y)` for point-wise append** — method never existed on SensorTag (only `updateData(X, Y)` with full arrays). Rewrite live-update loops as `sensor.updateData([sensor.X, newT], [sensor.Y, newY])` (the existing `example_event_detection_live.m` does this correctly).
- **Do not leave orphan "threshold per state" comment blocks without code** — e.g. `example_sensor_threshold.m` currently has `% Idle: threshold at 70` and `% Running: stricter threshold at 55` with nothing under them. Either replace with real MonitorTag code or delete the comment.
- **Do not call `cfg.runDetection()` expecting events** — it returns `[]`; any downstream `if ~isempty(events)` block will silently skip. Examples should use `MonitorTag + EventStore.append` directly.
- **Do not include `pause()`, `input()`, or `waitfor()` in smoke-test-exercised examples** — they hang CI. `demo_all.m` (`input('', 's')`) and `run_all_examples.m` interactive mode (`input(...)`) must be in the smoke test's skip-list OR the script must detect non-interactive mode (e.g. `getenv('CI')` or a `'auto'` arg).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| State-dependent threshold checker | `for k=1:N; if state(k)==1 && y(k)>55; ... end; end` | `MonitorTag` with `ConditionFn = @(x,y) y > thresholdForState(stateTag.valueAt(x))` | Debounce, hysteresis, event emission, listener-driven invalidation all for free |
| Registry for custom-keyed sensor lookup | `containers.Map('keyType','char','valueType','any')` | `TagRegistry.register`/`get`/`find*` | Singleton semantics, introspection (printTable/viewer), two-phase load, duplicate-key safety |
| Event persistence + backup rotation | Manual `save(file, 'events')` + file rename loops | `EventStore(file, 'MaxBackups', n)` + `store.append(ev)` + `store.save()` | Atomic temp-file write, backup rotation, round-trip tested |
| Many-to-many event↔tag lookup | Parallel cells of event-ids and tag-keys | `EventBinding.attach(ev.Id, tagKey)` + `EventBinding.getEventsForTag(key, store)` | Forward+reverse index gives O(1) bidirectional lookup; idempotent on duplicate |
| Round markers on plots at event timestamps | Manual `line(...,'Marker','o',...)` calls after `fp.render()` | `fp.ShowEventMarkers = true` with events bound via `EventBinding.attach` | Theme-driven severity color, separate render layer (Pitfall 10); works through live-tick refresh |
| "Run all examples with try/catch" harness | Shell loop | MATLAB function that walks `dir('examples/**/*.m')` and `feval` each | Native MATLAB error objects, per-example `{file, error.identifier, error.message}` structured report |

**Key insight:** Every concern the migration touches has a first-class Tag/EventStore/EventBinding replacement. If a plan draft looks like it's reinventing state-dependent alarms, event persistence, or bidirectional event↔tag indices, stop and check the shipped v2.0 API — it's there.

## Runtime State Inventory

> This is a rename / refactor / migration phase. Every category below is answered explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **`TagRegistry` singleton** uses a persistent `containers.Map` (see `TagRegistry.m:375-384`). `EventBinding` uses two persistent `containers.Map`s (see `EventBinding.m:108-126`). Examples that `.register(key, ...)` and leave keys in place pollute subsequent runs in the same MATLAB session. | Smoke test must call `TagRegistry.clear()` + `EventBinding.clear()` between examples. Each showcase script should also defensively `unregister` keys it creates (see `example_sensor_registry.m:59-62` precedent with `TagRegistry.unregister('my_custom_ph')`). No persisted on-disk data to worry about (registries are in-memory only). |
| Live service config | **None.** The only live services in this project are the WebBridge Python server (started by `example_webbridge.m`) and MATLAB timers inside `example_event_detection_live.m` / `example_event_viewer_from_file.m` / `example_live_pipeline.m` / `example_dashboard_live.m`. None persist configuration outside the MATLAB session. | No live-config migration. |
| OS-registered state | **None.** No Windows Task Scheduler, launchd, pm2, systemd, etc. registrations in this project. | No action. |
| Secrets and env vars | **None referencing the renamed APIs.** Env vars used: `FASTSENSE_SKIP_BUILD`, `FASTSENSE_RESULTS_FILE`, `ANTHROPIC_API_KEY` — none reference `Sensor`/`Threshold`/etc. by name. | No action. |
| Build artifacts / installed packages | **Compiled MEX binaries** live in `libs/FastSense/private/*.mex*` — they implement `binary_search`, `minmax_core`, etc. None reference renamed classes (they operate on numeric arrays). **JSON-exported dashboard configs** could reference `{"kind":"sensor",...}` tag structs; these live under `tempdir` by convention (e.g. `example_dashboard_engine.m` writes to `fullfile(tempdir, 'example_dashboard.json')`) and are runtime-ephemeral. **No Python egg-info / npm global installs / Docker tags** affected — Python bridge uses only generic APIs. | No build-artifact migration needed. Stale JSONs that users saved in prior sessions **may** reference the old `{"kind":"sensor"}` schema — but those are user-local and outside this phase's scope. |

**The canonical question — after every file in the repo is updated, what runtime systems still have the old string cached, stored, or registered?** Only the TagRegistry/EventBinding persistent-Map state within a running MATLAB/Octave session. Mitigated by smoke-test `.clear()` calls and defensive per-script `unregister` patterns.

## Common Pitfalls

### Pitfall 1: TagRegistry hard-error on duplicate key pollutes across example runs
**What goes wrong:** Running `example_tag_registry` twice in the same MATLAB session (or during the smoke test after another example already registered `'pressure'`) errors with `TagRegistry:duplicateKey`.
**Why it happens:** `TagRegistry` is a singleton backed by a persistent `containers.Map`; state survives across `.m` file executions in the same MATLAB/Octave process. Unlike `SensorRegistry` (which silently overwrote), `TagRegistry.register` throws on collision (deliberate — Pitfall 7 from Phase 1004).
**How to avoid:**
- Smoke test harness: `TagRegistry.clear(); EventBinding.clear();` at start of each example iteration.
- Per-example defensive pattern (from `example_sensor_registry.m`): `TagRegistry.unregister(key)` near end-of-script.
- Showcase scripts: demonstrate the HARD-ERROR behavior explicitly via `try/catch` (per CONTEXT §specifics).
**Warning signs:** Second invocation in same session throws `TagRegistry:duplicateKey`; error message mentions "existing kind" vs "new kind".

### Pitfall 2: `EventConfig.addSensor()` / `cfg.runDetection()` are dead stubs
**What goes wrong:** `example_event_detection_live.m` lines 56-58 call `cfg.addSensor(sTemp)` — this **throws** `EventConfig:legacyRemoved`. The script dies there; nothing renders. `example_event_viewer_from_file.m` line 83 has the same call. `example_live_pipeline.m` uses `LiveEventPipeline` (which is live), but if it routes through EventConfig, same hazard.
**Why it happens:** Phase 1011 stubbed the methods; they raise an error deliberately to flag dead-code-path usage. `runDetection` was changed to return `[]` silently instead of throwing, so code paths can "appear to work" but produce no events.
**How to avoid:** Rewrite event examples to use `MonitorTag + EventStore + EventBinding`:
1. Build one `MonitorTag` per (sensor × threshold-level) pair, with `ConditionFn` closing over the threshold value.
2. Bind an `EventStore` via `MonitorTag` constructor NV-pair `'EventStore', store`.
3. Pull events via `store.getEvents()` or `EventBinding.getEventsForTag(tagKey, store)`.
4. For live updates, call `monitor.appendData(newX, newY)` after `sensor.updateData(...)` (Phase 1007).
**Warning signs:** Error ID `EventConfig:legacyRemoved`; OR silent zero-events from `runDetection()`.

### Pitfall 3: `SensorTag.X` / `.Y` are read-only dependent properties
**What goes wrong:** `examples/04-widgets/example_widget_fastsense.m:36` does `sTemp.X = t;` then `:45` does `sTemp.Y = baseTemp + ...` — these **error** ("You cannot set the read-only property 'X'").
**Why it happens:** SensorTag exposes `X`/`Y` as backward-compat dependent getters (get.X returns `obj.X_`) but no setter. Legacy `Sensor` had public settable `X`/`Y`.
**How to avoid:** Use `updateData(X, Y)` or constructor `'X', ..., 'Y', ...` NV-pair.
**Warning signs:** Runtime error mentioning "read-only property" or "SetAccess"; script dies before `fp.render()`.

### Pitfall 4: `SensorTag.addData(t, y)` method does not exist
**What goes wrong:** `examples/06-webbridge/example_webbridge.m:108-110` calls `sTemp.addData(tNow, ...)` for point-wise live append. **Method does not exist.**
**Why it happens:** Legacy `Sensor` had (or was believed to have) an `addData` append method. SensorTag only has `updateData(X, Y)` which takes full arrays.
**How to avoid:** Replace with `sensor.updateData([sensor.X, newT], [sensor.Y, newY])` — the idiom already used by `example_event_detection_live.m` lines 176-180.
**Warning signs:** Runtime error "Undefined function or method 'addData' for class 'SensorTag'".

### Pitfall 5: Legacy properties on Sensor still referenced in examples
**What goes wrong:** `example_widget_table.m:32`, `example_widget_status.m:64`, `example_dashboard_all_widgets.m:98-102,251,295`, `example_dashboard_advanced.m:98-102`, and `example_sensor_todisk.m:39` reference `sensor.ResolvedViolations`, `.ResolvedThresholds`, and `.countViolations()`. These properties/methods were removed.
**Why it happens:** The bulk migration caught direct constructor names (`Sensor(`, `Threshold(`) but not property/method accesses. These surface only at runtime.
**How to avoid:**
- For `ResolvedViolations` loops: construct a `MonitorTag` alongside the sensor; iterate `EventBinding.getEventsForTag(sensor.Key, eventStore)` or `eventStore.getEvents()` and filter.
- For `countViolations()`: replace with `numel(eventStore.getEvents())` or query `EventBinding`.
- For `ResolvedThresholds`: this data no longer exists per-sensor; a rewritten example should just drop the line or show `numel(monitors)` instead.
**Warning signs:** "Reference to non-existent field 'ResolvedViolations'" or "Undefined function 'countViolations'".

### Pitfall 6: Orphan "% Idle: threshold at 70" comments without code
**What goes wrong:** `example_sensor_threshold.m:17-21` has three comment lines describing per-state thresholds with no code between them. Script runs but produces no thresholds / no violations / no events.
**Why it happens:** String-replace pass deleted `addThresholdRule(...)` calls without adding replacement MonitorTag code.
**How to avoid:** The CONTEXT.md explicit decision is to **rewrite `example_sensor_threshold.m` in place** as the canonical v2.0 event-binding demo. Don't surgically replace the missing thresholds — replace the whole narrative with the marquee MonitorTag + EventStore + EventBinding flow (see Code Examples below).
**Warning signs:** Plan section with "%% 2. ... thresholds per state" has no code after migration.

### Pitfall 7: Octave-incompatible patterns in new showcase scripts
**What goes wrong:** Certain MATLAB idioms (e.g. `isa(x, 'Tag')` with handle-identity chains, `Abstract` method blocks, `categorical`, `datetime`, `disableDefaultInteractivity`) are Octave-incompatible. Showcase scripts introduced by this phase must run on Octave 11.1.0 (per `.github/workflows/examples.yml`).
**Why it happens:** Octave's classdef support is narrower. Phase 1006 hit this with `isequal` on handles causing SIGILL through listener cycles.
**How to avoid:**
- Use `strcmp(a.Key, b.Key)` for Tag handle identity checks (Phase 1006/1008 established pattern).
- Prefer numeric `StateTag.Y` over cellstr — cellstr Y works in StateTag.valueAt but its interaction with MonitorTag.ConditionFn requires the user's ConditionFn to handle cells. Numeric state codes read simpler in a showcase.
- Construct MonitorTag's `ConditionFn` as a simple `@(x,y) y > f(x)` with a scalar-returning `f`; avoid closures over large cell arrays that Octave's anonymous-function captures may miscopy.
- Don't use `abstract` method blocks; base classes use Phase 1004's throw-from-base pattern.
- Don't use `categorical(...)` (MATLAB-only; already flagged in `examples.yml` skip-list for `example_mixed_tiles`).
- For `close all force;` at script top: Octave variant `close all` is fine, `force` is ignored on Octave but accepted.
**Warning signs:** MATLAB-only but passing; Octave reports "feval: function does not exist" or SIGILL on exit.

### Pitfall 8: `demo_all.m` and `run_all_examples.m` default to interactive mode (hang in CI)
**What goes wrong:** `run_all_examples.m` default `mode='interactive'` calls `input(...)` between every example. `demo_all.m` calls `input('', 's')` at the end. Both hang CI.
**Why it happens:** Designed as a manual demo tool, not a CI runner.
**How to avoid:**
- `run_all_examples.m` rewrite: default to `'auto'` when `getenv('CI')` or `~isinteractive()` detected; keep interactive opt-in. Alternative (CONTEXT decision): "rewrite to recursively walk `examples/**/*.m`, run each in a try/catch, print summary" — if the rewrite is purely non-interactive, the `'interactive'` mode goes away entirely.
- `demo_all.m`: excluded from the smoke-test harness (has `input()`; path listed in CI skip-list already). Can stay as a human-only entry point.
**Warning signs:** Smoke test times out at 45 min or sits forever on a specific example.

### Pitfall 9: Figure windows accumulate during smoke test
**What goes wrong:** 50+ examples each open figure windows. Without cleanup between runs, memory climbs and Octave's `break_closure_cycles` crash (known bug, tolerated by `run_all_tests.m`) becomes more frequent.
**Why it happens:** Examples legitimately open figures — that's the point of a visualization library. Without `close all` between runs, handles accumulate.
**How to avoid:** Smoke test wraps each `feval(exampleName)` with `close all force; TagRegistry.clear(); EventBinding.clear();` between calls. For headless CI, set `set(0, 'DefaultFigureVisible', 'off')` at harness start. Matches the `close all force` call already present in `examples.yml:114`.
**Warning signs:** Octave SIGILL in `break_closure_cycles` during later examples; memory exhaustion.

### Pitfall 10: Inter-example dependency via registry pollution
**What goes wrong:** If `example_sensor_dashboard` registers `'pressure'` and `example_sensor_registry` also registers `'pressure'` (different handles, same key), the second hard-errors — NOT because the examples are buggy in isolation, but because the smoke-test execution order creates implicit coupling.
**Why it happens:** TagRegistry is a singleton per process.
**How to avoid:** Smoke test `.clear()` between runs (Pitfall 9's remedy solves this too). Individual examples should **not** assume isolation; showcase scripts that explicitly demonstrate registry behavior should call `TagRegistry.clear()` at start defensively.
**Warning signs:** Example A passes alone, example B passes alone, A-then-B fails with duplicateKey.

### Pitfall 11: Inter-folder dependencies (false alarm — none exist)
**What we checked:** `examples/03-dashboard/*` do not source fixtures from `examples/02-sensors/`. Each example is self-contained (inlines its own data generation). Verified by grep: no `run(fullfile(... '02-sensors' ...))` or `addpath(fullfile(... '02-sensors' ...))` in `03-dashboard`.
**Implication:** CONTEXT.md's "one commit per folder" decision is safe — folders are independently migratable and testable.

## Code Examples

### Mapping table: legacy → Tag API calls

This is the authoritative table the planner needs to allocate tasks. All rows verified by class-file reading or documented in STATE.md / phase summaries.

| Legacy call | v2.0 Tag replacement | Notes |
|-------------|----------------------|-------|
| `s = Sensor('key', 'Name', n, 'Units', u, 'ID', id)` | `s = SensorTag('key', 'Name', n, 'Units', u, 'ID', id)` | Drop-in rename. Full NV-pair parity for Name/Units/Description/Labels/Metadata/Criticality/SourceRef + SensorTag extras (ID/Source/MatFile/KeyName). Additional: SensorTag accepts inline `'X', t, 'Y', y` in the constructor. |
| `s = Sensor('key'); s.updateData(t, y)` | `s = SensorTag('key'); s.updateData(t, y)` | `updateData(X, Y)` is the ONLY legal mutator — no `addData(t, y)` append. Preserved. |
| `s.X = t; s.Y = y` | `s = SensorTag('k', 'X', t, 'Y', y)` OR `s.updateData(t, y)` | `SensorTag.X`/`.Y` are **read-only** dependent properties. Direct assignment errors. |
| `s.addData(newT, newY)` (if it ever existed) | `s.updateData([s.X, newT], [s.Y, newY])` | SensorTag has no `addData`. Append idiom lives in `example_event_detection_live.m:176-180`. |
| `s.toDisk()` | `s.toDisk()` | Unchanged — SensorTag has the same method forwarding to inner FastSenseDataStore. |
| `s.toMemory()` / `s.isOnDisk()` / `s.DataStore` | Same | All three preserved. |
| `s.load('file.mat')` | `s.load('file.mat')` | Same; reads into `X_`/`Y_` private. |
| `s.ResolvedViolations` | Not available. | Deleted. Use `eventStore.getEvents()` or `EventBinding.getEventsForTag(s.Key, eventStore)` from a `MonitorTag` that ran on this sensor. |
| `s.ResolvedThresholds` | Not available. | Deleted. No 1:1 replacement — a sensor no longer "has" thresholds; thresholds are attached to a separate `MonitorTag`. |
| `s.countViolations()` | `numel(eventStore.getEventsForTag(s.Key))` (when `EventStore` has a `getEventsForTag` method) OR `numel(EventBinding.getEventsForTag(s.Key, eventStore))` | Phase 1009 added `getEventsForTag` to EventStore; Phase 1010 added EventBinding.getEventsForTag as the canonical path. |
| `s.currentStatus` | Build a MonitorTag + check `monitor.valueAt(now)` (or `monitor.valueAt(s.X(end))`) against the desired threshold. | No built-in "status" concept on SensorTag. |
| `s.addThreshold(t)` (adding a `Threshold` object to a Sensor) | `MonitorTag('mon_key', s, @(x,y) y > value, 'EventStore', store)` | Thresholds-as-objects (with addCondition etc.) are deleted; the state-dependent check moves into the `ConditionFn`. `fp.addThreshold(value, 'Label', ...)` remains as the **visual overlay** API and is unrelated. |
| `s.addThresholdRule('Condition', 'state==1', 'Value', 55, 'Label', 'Hi')` | `MonitorTag('pressure_hi_running', s, @(x,y) y > thresholdForState(stateTag.valueAt(x)), 'EventStore', store)` | State-dependent threshold. Close over `stateTag` via a scalar-returning helper. |
| `sc = StateChannel('mode'); sc.setStates(X, Y)` | `sc = StateTag('mode', 'X', X, 'Y', Y)` | Byte-for-byte valueAt parity. Numeric or cellstr Y. StateTag has **`emptyState` guard** error; StateChannel silently returned garbage. |
| `sc.valueAt(t)` | `sc.valueAt(t)` | Identical; scalar or vector `t`; numeric or cellstr Y. |
| `r = ThresholdRule('Condition', 'state==1', 'Value', 55)` then `s.addThresholdRule(r)` | Same pattern collapses into a MonitorTag with ConditionFn — no ThresholdRule object needed. | See above. |
| `SensorRegistry.register(key, sensor)` | `TagRegistry.register(key, tag)` | **Behavior difference:** `TagRegistry` HARD-ERRORS on duplicate key (raises `TagRegistry:duplicateKey`); `SensorRegistry.register` silently overwrote. Examples that re-register in-session must `unregister` first OR use `TagRegistry.clear()`. |
| `SensorRegistry.get(key)` | `TagRegistry.get(key)` | Same signature; raises `TagRegistry:unknownKey` instead of `SensorRegistry:unknownKey`. |
| `SensorRegistry.list()` | `TagRegistry.list()` | Same. |
| `SensorRegistry.printTable()` | `TagRegistry.printTable()` | Same. |
| `SensorRegistry.viewer()` | `TagRegistry.viewer()` | Same (uitable-based). |
| `SensorRegistry.findByTag('critical')` | `TagRegistry.findByLabel('critical')` | **Renamed** (field is `Labels` not `Tags` on the v2.0 model — META-01 disambiguates from the new `Tag` class name). |
| `SensorRegistry.unregister(key)` | `TagRegistry.unregister(key)` | Same. |
| `SensorRegistry.loadFromStructs(structs)` | `TagRegistry.loadFromStructs(structs)` | Two-phase deserialization (Pass 1 instantiate+register, Pass 2 resolveRefs). **Each struct must carry a `kind` field** (`'sensor'`/`'state'`/`'monitor'`/`'composite'`) for dispatch via `TagRegistry.instantiateByKind`. |
| `CompositeThreshold('key', 'AggregateMode', 'and')` + `.addChild(threshold)` | `CompositeTag('key', 'and')` + `.addChild(monitorTag, 'Weight', w)` | Modes expanded: `and`/`or`/`majority`/`count`/`worst`/`severity`/`user_fn`. Children must be MonitorTag or CompositeTag (SensorTag/StateTag rejected). Cycle detection via Key-equality DFS. |
| `fp.addSensor(s)` | `fp.addTag(s)` | Polymorphic accepts SensorTag/StateTag/MonitorTag/CompositeTag. Internal dispatch by `tag.getKind()` (verified in Phase 1005-03 note "NO isa branches"). |
| `fp.addLine(x, y, 'DisplayName', n)` | Unchanged | Not a Tag API — primitive rendering path. |
| `fp.addThreshold(value, 'Label', 'Upper', 'Direction', 'upper', 'ShowViolations', true)` | Unchanged | FastSense visual overlay — NOT related to the deleted `Sensor.addThresholdRule`. Survives verbatim. |
| `fp.addBand(lo, hi, 'FaceColor', ...)` / `addFill` / `addShaded` / `addMarker` | Unchanged | Primitive rendering; unaffected. |
| `cfg.addSensor(s)` (on `EventConfig`) | Replace with `MonitorTag(key, s, conditionFn, 'EventStore', store)` | `EventConfig.addSensor` hard-errors (`EventConfig:legacyRemoved`). Full event-pipeline rewrite required. |
| `cfg.runDetection()` | Replace with explicit `MonitorTag.getXY()` reads OR `LiveEventPipeline.runCycle()` for live examples | `runDetection` is now a no-op returning `[]`. |

### Inventory: 28 files (+ `run_all_examples.m` + `demo_all.m`) to touch

Counts are specific legacy-API occurrences (residual method/property references and orphan comments **after** the Phase 1011 bulk text-replace). `Legacy Count` includes: `ResolvedViolations`, `ResolvedThresholds`, `countViolations`, `EventConfig.addSensor`, `addData` on SensorTag, direct `X=`/`Y=` assignment on SensorTag, orphan thresholds-per-state comments, and string mentions of deleted class names in comments/docstrings.

| File | Folder | Legacy Count | Migration Complexity |
|------|--------|--------------|----------------------|
| `examples/01-basics/example_basic.m` | 01-basics | 0 | trivial (verify only) |
| `examples/01-basics/example_alarm_bands.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_datetime.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_disk_storage.m` | 01-basics | 0 | trivial (no tag API used) |
| `examples/01-basics/example_dock.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_dock_disk.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_dock_many_tabs.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_ecg.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_linked.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_mixed_tiles.m` | 01-basics | 0 | trivial (MATLAB-only; skipped by Octave CI) |
| `examples/01-basics/example_multi.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_nan_gaps.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_navigator_overlay.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_themes.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_toolbar.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_uneven_sampling.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_vibration.m` | 01-basics | 0 | trivial |
| `examples/01-basics/example_visual_features.m` | 01-basics | 0 | trivial |
| `examples/02-sensors/example_dynamic_thresholds_100M.m` | 02-sensors | verify (uses Tag) | trivial |
| `examples/02-sensors/example_multi_sensor_linked.m` | 02-sensors | verify (uses Tag) | trivial |
| `examples/02-sensors/example_sensor_dashboard.m` | 02-sensors | 0 | trivial |
| `examples/02-sensors/example_sensor_detail.m` | 02-sensors | verify | trivial |
| `examples/02-sensors/example_sensor_detail_basic.m` | 02-sensors | verify | trivial |
| `examples/02-sensors/example_sensor_detail_dashboard.m` | 02-sensors | 0 | trivial |
| `examples/02-sensors/example_sensor_detail_datetime.m` | 02-sensors | verify | trivial |
| `examples/02-sensors/example_sensor_detail_dock.m` | 02-sensors | verify | trivial |
| `examples/02-sensors/example_sensor_multi_state.m` | 02-sensors | 2 (orphan comments + 1 StateChannel comment-reference) | moderate (kill orphan `% Idle threshold 70` comment block; update docstring comment `--- StateChannel.valueAt ---` to say StateTag) |
| `examples/02-sensors/example_sensor_registry.m` | 02-sensors | 0 | trivial (style template — do not modify) |
| `examples/02-sensors/example_sensor_static.m` | 02-sensors | verify (mentions countViolations in comment) | moderate (remove docstring reference to `countViolations`) |
| **`examples/02-sensors/example_sensor_threshold.m`** | 02-sensors | 5 (orphan comment blocks) | **rewrite** (canonical end-to-end MonitorTag+EventStore+EventBinding demo — CONTEXT decision) |
| `examples/02-sensors/example_sensor_todisk.m` | 02-sensors | 2 (`ResolvedThresholds`, `ResolvedViolations` on line 39 + dangling `resolve()` docstring) | moderate (remove resolve-count fprintf or replace with monitor-event count) |
| **`examples/02-sensors/tags/example_tag_sensor.m`** | 02-sensors/tags | NEW | new (showcase) |
| **`examples/02-sensors/tags/example_tag_state.m`** | 02-sensors/tags | NEW | new (showcase) |
| **`examples/02-sensors/tags/example_tag_monitor.m`** | 02-sensors/tags | NEW | new (showcase) |
| **`examples/02-sensors/tags/example_tag_composite.m`** | 02-sensors/tags | NEW | new (showcase) |
| **`examples/02-sensors/tags/example_tag_registry.m`** | 02-sensors/tags | NEW | new (showcase; explicit duplicate-key HARD-ERROR demo via try/catch) |
| `examples/03-dashboard/example_dashboard.m` | 03-dashboard | 0 (uses primitives only) | trivial |
| `examples/03-dashboard/example_dashboard_9tile.m` | 03-dashboard | verify | trivial |
| `examples/03-dashboard/example_dashboard_engine.m` | 03-dashboard | 1 (comment string `Sensor-Driven` in header) | trivial (optional rewording to `Tag-driven`) |
| `examples/03-dashboard/example_dashboard_all_widgets.m` | 03-dashboard | 4 (`ResolvedViolations` loop lines 98-102, `countViolations` lines 251 & 295) | moderate (remove alarm-log loop, or reconstruct from EventStore; `countViolations` in fprintf → fixed string) |
| `examples/03-dashboard/example_dashboard_advanced.m` | 03-dashboard | 3 (`ResolvedViolations` loop lines 98-102) | moderate (same as above) |
| `examples/03-dashboard/example_dashboard_groups.m` | 03-dashboard | verify | trivial |
| `examples/03-dashboard/example_dashboard_info.m` | 03-dashboard | verify | trivial |
| `examples/03-dashboard/example_dashboard_live.m` | 03-dashboard | verify (skipped in CI — live timer) | trivial |
| `examples/03-dashboard/example_mushroom_cards.m` | 03-dashboard | verify | trivial |
| `examples/04-widgets/example_widget_barchart.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_chipbar.m` | 04-widgets | 0 (uses `sensor:` chip NV on ChipBarWidget) | trivial (docstring mentions `ThresholdRules` — reword) |
| `examples/04-widgets/example_widget_divider.m` | 04-widgets | 0 | trivial |
| `examples/04-widgets/example_widget_fastsense.m` | 04-widgets | 2 (**direct `sTemp.X = t` / `sTemp.Y = ...` — runtime error on line 36 & 45**) | moderate (swap to `updateData` or constructor inline) |
| `examples/04-widgets/example_widget_gauge.m` | 04-widgets | 1 (`sTemp.Y(end) = 76` — depends on SensorTag.Y setter; currently read-only) | moderate (replace with `updateData(sTemp.X, [... y(1:end-1), 76])`) |
| `examples/04-widgets/example_widget_group.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_heatmap.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_histogram.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_iconcard.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_image.m` | 04-widgets | 0 | trivial |
| `examples/04-widgets/example_widget_multistatus.m` | 04-widgets | 8 (multiple `.Y(end-50:end) = ...` direct assignments on read-only Y) | moderate (swap each to `updateData` with pre-built array) |
| `examples/04-widgets/example_widget_number.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_rawaxes.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_scatter.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_sparkline.m` | 04-widgets | verify | trivial |
| `examples/04-widgets/example_widget_status.m` | 04-widgets | 4 (`.Y(end-200:end) =` assign + `countViolations()` × 3 in fprintf) | moderate |
| `examples/04-widgets/example_widget_table.m` | 04-widgets | 3 (`ResolvedViolations` loop lines 32-44) | moderate (reconstruct alarm log from MonitorTag+EventStore) |
| `examples/04-widgets/example_widget_text.m` | 04-widgets | 0 | trivial |
| `examples/04-widgets/example_widget_timeline.m` | 04-widgets | verify | trivial |
| `examples/05-events/example_event_detection_live.m` | 05-events | 3 (`cfg.addSensor` × 3 — **runtime error**) | **rewrite** pipeline to use MonitorTag+EventStore |
| `examples/05-events/example_event_viewer_from_file.m` | 05-events | 1 (`cfg.addSensor` loop — **runtime error**) | **rewrite** pipeline |
| `examples/05-events/example_live_pipeline.m` | 05-events | multiple orphan threshold comments + `LiveEventPipeline(sensors,...)` path is unverified post-1011 | **rewrite** pipeline construction (uses `LiveEventPipeline` with MonitorTargets per Phase 1009) |
| `examples/06-webbridge/example_webbridge.m` | 06-webbridge | 3 (`.addData(...)` × 3 on SensorTag — **runtime error**) | moderate (swap to append-via-updateData) |
| `examples/07-advanced/example_100M.m` | 07-advanced | 0 | trivial |
| `examples/07-advanced/example_lttb_vs_minmax.m` | 07-advanced | 0 | trivial |
| `examples/07-advanced/example_stress_test.m` | 07-advanced | 0 (already uses Tag) | trivial |
| `examples/run_all_examples.m` | examples/ | 2 (description strings: "SensorRegistry: ...", "Multi-sensor ... with SensorRegistry") + list is stale (missing `example_sensor_threshold`, `example_sensor_todisk`, `example_sensor_dashboard`, etc.) | **rewrite** (CONTEXT decision: recursive walk + try/catch + summary) |
| `examples/demo_all.m` | examples/ | 0 (uses only primitives) + `input()` call | leave as interactive-only; exclude from smoke test |
| **`tests/test_examples_smoke.m`** | tests/ | NEW | new (function-based Octave-style test; picked up by `run_all_tests.m` auto-discovery) |

**Total:**
- Existing files to touch: 30 (trivial verification ~18; moderate edits ~9; rewrite ~3)
- NEW files: 6 (5 showcase + 1 smoke test)
- Updated/rewritten: `run_all_examples.m`

**Plan-allocation hint:** seven per-folder commits + one test-infrastructure commit matches CONTEXT.md's "~8 atomic commits" target exactly:
1. `01-basics/` — trivial pass (verify 18 files run; fix any hidden legacy-isms discovered in execution)
2. `02-sensors/` (existing) — moderate edits to 4 files + rewrite of `example_sensor_threshold.m`
3. `02-sensors/tags/` — 5 NEW showcase scripts
4. `03-dashboard/` — moderate edits to 2 files (alarm-log loops), trivial elsewhere
5. `04-widgets/` — moderate edits to 5 files (read-only-Y assigns + countViolations fprintf), trivial elsewhere
6. `05-events/` — rewrite 3 event-pipeline files
7. `06-webbridge/` + `07-advanced/` — small touch-ups (3 `.addData` lines)
8. Infra — `run_all_examples.m` rewrite + `tests/test_examples_smoke.m` new file + `demo_all.m` skip-list addition

### End-to-end event-binding demo (rewrite of `example_sensor_threshold.m`)

The exact API signature chain the planner needs, all cross-referenced to source files:

```matlab
%% Chamber Pressure — End-to-End Event-Binding Demo
% Demonstrates the full v2.0 Tag event pipeline:
%   - SensorTag with synthetic chamber pressure
%   - StateTag with 4 machine-state transitions
%   - MonitorTag with state-dependent ConditionFn + EventStore
%   - EventBinding.attach (fires automatically inside MonitorTag)
%   - FastSense.addTag + addThreshold visual overlays + round-marker events

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

% Defensive: this example uses named keys in TagRegistry / EventBinding;
% clear so re-runs in the same session don't hit duplicateKey.
TagRegistry.clear();
EventBinding.clear();

%% 1. SensorTag — 10k points of chamber pressure
t = linspace(0, 100, 10000);
y = 40 + 20*sin(2*pi*t/30) + 5*randn(1, numel(t));
s = SensorTag('pressure', 'Name', 'Chamber Pressure', 'Units', 'mbar', ...
    'X', t, 'Y', y);

%% 2. StateTag — 4 machine-state transitions (0=idle, 1=running, 2=evacuated)
stateTag = StateTag('mode', 'X', [0 25 50 75], 'Y', [0 1 2 1]);

%% 3. Per-state upper threshold lookup
thresholdForState = @(st) (st == 0)*70 + (st == 1)*55 + (st == 2)*45;

%% 4. EventStore — persistent, atomic-write, with backup rotation
eventFile = fullfile(tempdir, 'example_sensor_threshold_events.mat');
store = EventStore(eventFile, 'MaxBackups', 3);

%% 5. MonitorTag — state-dependent ConditionFn closing over stateTag
conditionFn = @(x, y) y > thresholdForState(stateTag.valueAt(x));
m = MonitorTag('pressure_alarm', s, conditionFn, ...
    'MinDuration', 0.2, ...                 % debounce sub-second transients
    'EventStore', store);                   % events auto-emit on rising edge

%% 6. Register tags so loadFromStructs round-trip works
TagRegistry.register('pressure', s);
TagRegistry.register('mode',     stateTag);
TagRegistry.register('pressure_alarm', m);

%% 7. Force evaluation (MonitorTag is lazy)
[mx, my] = m.getXY();   % recomputes 0/1 on parent's grid + fires events
fprintf('MonitorTag produced %d samples, %d alarm points.\n', numel(my), sum(my));

%% 8. Query events via EventBinding (many-to-many reverse index)
events = EventBinding.getEventsForTag('pressure', store);
fprintf('Detected %d events on ''pressure''.\n', numel(events));
if ~isempty(events)
    for k = 1:numel(events)
        ev = events(k);
        fprintf('  [%d] t=%.1f..%.1f  peak=%s\n', ...
            k, ev.StartTime, ev.EndTime, num2str(ev.PeakValue));
    end
end

%% 9. FastSense overlay — lines + visual threshold + round-marker events
fp = FastSense();
fp.addTag(s);                                           % pressure line
fp.addTag(m);                                           % 0/1 alarm step (optional)
fp.addThreshold(70, 'Direction', 'upper', 'Label', 'Idle limit', 'LineStyle', '--');
fp.addThreshold(55, 'Direction', 'upper', 'Label', 'Running limit', 'LineStyle', '--');
fp.addThreshold(45, 'Direction', 'upper', 'Label', 'Evac limit', 'LineStyle', '--');
% ShowEventMarkers defaults to true — events from the bound EventStore
% render as round markers automatically (Phase 1010 renderEventLayer).
fp.render();
title('Chamber Pressure — State-Dependent Thresholds + Event Overlay');
xlabel('Time [s]');
ylabel('Pressure [mbar]');
```

Key signature confirmations (all verified against the class files this phase depends on):
- `SensorTag(key, 'X', t, 'Y', y, 'Name', n, 'Units', u)` — `libs/SensorThreshold/SensorTag.m:41-71`
- `StateTag(key, 'X', X, 'Y', Y)` — `libs/SensorThreshold/StateTag.m:46-55`
- `EventStore(filename, 'MaxBackups', n)` — `libs/EventDetection/EventStore.m`
- `MonitorTag(key, parentTag, conditionFn, 'MinDuration', d, 'EventStore', store)` — `libs/SensorThreshold/MonitorTag.m:125-198`
- `TagRegistry.register(key, tag)` — `libs/SensorThreshold/TagRegistry.m:67-95`
- `EventBinding.getEventsForTag(key, store)` — `libs/EventDetection/EventBinding.m:70-93`
- `fp.addTag(tag)` — polymorphic by `tag.getKind()` — `libs/FastSense/FastSense.m` (Phase 1005-03 "NO isa branches" note)
- `fp.addThreshold(value, 'Direction', 'upper', 'Label', label)` — unchanged visual API
- `fp.ShowEventMarkers` (default true, round markers via `renderEventLayer_`) — Phase 1010 — automatic once an EventStore is bound to a Tag that's been `addTag`'d

### Smoke-test skeleton (`tests/test_examples_smoke.m`)

Auto-discovered by `tests/run_all_tests.m` (which globs `test_*.m`). Follows the repo's Octave-style function-based test pattern.

```matlab
function test_examples_smoke()
%TEST_EXAMPLES_SMOKE Run every examples/**/*.m non-interactively; collect errors.
%   Runs each example in a try/catch, captures {file, error.identifier,
%   error.message} on failure, closes figures + clears registries between
%   runs, fails at end if any example errored.
%
%   Skip list: interactive scripts or live-timer scripts that can't run
%   in a batch CI context.

    test_dir   = fileparts(mfilename('fullpath'));
    repo_root  = fileparts(test_dir);
    ex_root    = fullfile(repo_root, 'examples');
    addpath(repo_root); install();

    % Auto-add example folders to path so feval works
    folders = {'01-basics', '02-sensors', fullfile('02-sensors','tags'), ...
               '03-dashboard', '04-widgets', '05-events', ...
               '06-webbridge', '07-advanced'};
    for i = 1:numel(folders)
        p = fullfile(ex_root, folders{i});
        if isfolder(p), addpath(p); end
    end

    % Skip list: scripts that block or require an external service
    skip = { ...
        'demo_all', ...                         % input() — hangs
        'run_all_examples', ...                 % itself a runner
        'example_dashboard_live', ...           % live timer
        'example_event_detection_live', ...     % live timer + EventViewer
        'example_event_viewer_from_file', ...   % background timer
        'example_live_pipeline', ...            % 15s timer
        'example_webbridge', ...                % starts Python subprocess
    };

    files = dir(fullfile(ex_root, '**', 'example_*.m'));
    figVis = get(0, 'DefaultFigureVisible');
    cleaner = onCleanup(@() set(0, 'DefaultFigureVisible', figVis));
    set(0, 'DefaultFigureVisible', 'off');

    failures = {};
    nPassed = 0; nFailed = 0; nSkipped = 0;
    for i = 1:numel(files)
        [~, name, ~] = fileparts(files(i).name);
        if any(strcmp(name, skip))
            nSkipped = nSkipped + 1;
            fprintf('  SKIP  %s\n', name);
            continue;
        end
        % Per-example cleanup: no cross-contamination via singletons
        try, TagRegistry.clear(); catch; end
        try, EventBinding.clear(); catch; end
        try
            feval(name);
            nPassed = nPassed + 1;
            fprintf('  PASS  %s\n', name);
        catch err
            nFailed = nFailed + 1;
            failures{end+1, 1} = name;            %#ok<AGROW>
            failures{end,   2} = err.identifier;
            failures{end,   3} = err.message;
            fprintf('  FAIL  %s  [%s]  %s\n', name, err.identifier, err.message);
        end
        close all force;
    end

    fprintf('\n%d passed / %d failed / %d skipped (of %d total)\n', ...
        nPassed, nFailed, nSkipped, numel(files));

    if nFailed > 0
        msg = sprintf('%d examples failed:', nFailed);
        for k = 1:size(failures, 1)
            msg = sprintf('%s\n  %s [%s]  %s', msg, failures{k,1}, failures{k,2}, failures{k,3});
        end
        error('ExampleSmoke:failures', msg);
    end
end
```

Integration check: `tests/run_all_tests.m` lines 77 globs `dir(fullfile(test_dir, 'test_*.m'))` — a new `test_examples_smoke.m` is auto-discovered without any harness change. On MATLAB, `run_all_tests.m` runs the class-based suite instead, **so `test_examples_smoke.m` is Octave-only as-written.** Two options:
- **Option A (recommended):** Leave it function-based; it runs in the Octave CI job. MATLAB CI already has `.github/workflows/examples.yml:153-253` (`matlab-examples` job) running examples directly. The smoke-test-inside-unit-tests is therefore an Octave belt.
- **Option B:** Also add a wrapping class `tests/suite/TestExamplesSmoke.m` that calls the function. More boilerplate; only needed if you want MATLAB's unit-test framework reports.

CONTEXT.md's decision "wire into `tests/run_all_tests.m`" is satisfied by Option A; the MATLAB side already has coverage via `matlab-examples` job.

### Rewritten `run_all_examples.m` — recursive walk with per-file try/catch

```matlab
function results = run_all_examples(mode)
%RUN_ALL_EXAMPLES Recursively run every examples/**/example_*.m non-interactively.
%   results = run_all_examples() runs in 'auto' mode (no interaction).
%   results = run_all_examples('interactive') pauses between examples.
%
%   Returns a struct with fields: passed, failed, skipped, total, failures.
%   Exits with status 1 if any example fails (useful for shell invocation).

    if nargin < 1, mode = 'auto'; end
    isInteractive = strcmp(mode, 'interactive');

    projectRoot = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(projectRoot);
    run(fullfile(projectRoot, 'install.m'));

    exDir = fullfile(projectRoot, 'examples');
    folders = {'01-basics', '02-sensors', fullfile('02-sensors','tags'), ...
               '03-dashboard', '04-widgets', '05-events', ...
               '06-webbridge', '07-advanced'};
    for i = 1:numel(folders)
        p = fullfile(exDir, folders{i});
        if isfolder(p), addpath(p); end
    end

    % Interactive + blocking scripts (never in auto-run):
    skip = {'demo_all', 'run_all_examples', ...
            'example_dashboard_live', 'example_event_detection_live', ...
            'example_event_viewer_from_file', 'example_live_pipeline', ...
            'example_webbridge'};

    files = dir(fullfile(exDir, '**', 'example_*.m'));
    fprintf('\n========================================\n');
    fprintf('  FastSense Examples (%d total, mode=%s)\n', numel(files), mode);
    fprintf('========================================\n\n');

    passed = 0; failed = 0; skipped = 0; failures = {};
    for i = 1:numel(files)
        [~, name, ~] = fileparts(files(i).name);
        rel = strrep(fullfile(files(i).folder, files(i).name), ...
            [exDir filesep], '');
        if any(strcmp(name, skip))
            skipped = skipped + 1;
            fprintf('[%d/%d] SKIP  %s\n', i, numel(files), rel);
            continue;
        end
        fprintf('[%d/%d] RUN   %s\n', i, numel(files), rel);
        try, TagRegistry.clear(); catch; end
        try, EventBinding.clear(); catch; end
        try
            feval(name);
            passed = passed + 1;
        catch err
            failed = failed + 1;
            failures{end+1} = sprintf('%s [%s] %s', rel, err.identifier, err.message); %#ok<AGROW>
            fprintf('        ERROR: %s\n', err.message);
        end
        if isInteractive && i < numel(files)
            reply = input('\nENTER for next, q to quit: ', 's');
            if strcmpi(reply, 'q'), break; end
        else
            close all force;
        end
    end

    results = struct('passed', passed, 'failed', failed, 'skipped', skipped, ...
                     'total', numel(files), 'failures', {failures});
    fprintf('\n=== %d passed / %d failed / %d skipped (of %d) ===\n', ...
        passed, failed, skipped, numel(files));
    if failed > 0
        fprintf('\nFailures:\n');
        for k = 1:numel(failures)
            fprintf('  - %s\n', failures{k});
        end
    end

    % Shell exit status: non-zero on any failure
    if failed > 0 && ~isInteractive
        error('run_all_examples:failures', '%d examples failed', failed);
    end
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Sensor + ThresholdRule + Sensor.resolve()` pipeline | `SensorTag + MonitorTag + EventStore + EventBinding` | Phase 1011 deleted legacy classes | Examples must construct a MonitorTag separately from the SensorTag; violations are events, not a Sensor property |
| `SensorRegistry.register(key, sensor)` silent overwrite | `TagRegistry.register(key, tag)` HARD-ERROR on duplicate | Phase 1004 (TagRegistry) | Examples need unregister/clear discipline across sessions |
| `fp.addSensor(sensor)` | `fp.addTag(tag)` polymorphic by `getKind()` | Phase 1005-03 | Same shape; different method name |
| `StateChannel.valueAt(t)` | `StateTag.valueAt(t)` | Phase 1005-02 | Byte-for-byte parity; new `StateTag:emptyState` guard error |
| `CompositeThreshold('key', 'AggregateMode', 'and')` | `CompositeTag('key', 'and')` | Phase 1008 | 7 modes (was 3); children must be Monitor/Composite; merge-sort streaming (not N×M materialization) |
| `Event.SensorName` + `Event.ThresholdLabel` as foreign keys | `Event.TagKeys` (cell) + `EventBinding` many-to-many registry | Phase 1010 | Legacy fields preserved for back-compat; new code uses `EventBinding.attach`/`getEventsForTag` |
| `cfg = EventConfig(); cfg.addSensor(s); cfg.runDetection()` | `m = MonitorTag(key, s, fn, 'EventStore', store); [mx,my] = m.getXY();` | Phase 1011 | EventConfig path is a stub (hard-errors or no-ops) |
| `sensor.ResolvedViolations` / `.countViolations()` | Query via `EventBinding.getEventsForTag(sensor.Key, store)` and count | Phase 1011 | Examples that iterate violation cells must rebuild via EventStore |
| `sensor.X = t; sensor.Y = y;` direct assignment | `sensor.updateData(t, y)` OR constructor `'X', t, 'Y', y` | Phase 1011 (read-only dependent properties) | Any write-to-X-or-Y fails silently or errors |

**Deprecated/outdated:**
- `example_sensor_threshold.m` mid-migration state (orphan comments without code) — must be completely rewritten as canonical event-binding demo
- `run_all_examples.m` hard-coded example list (stale — missing 30+ files) — must be replaced with recursive walker
- `demo_all.m` — still usable as a human-only interactive tour; not touched by smoke test

## Open Questions

1. **Should the smoke test run MATLAB-only examples on MATLAB CI?**
   - What we know: Existing `.github/workflows/examples.yml:153-253` runs MATLAB-only examples (DashboardEngine group, widget examples) in a separate job. The new `tests/test_examples_smoke.m` runs under Octave via `tests/run_all_tests.m`; MATLAB unit-test suite would skip it.
   - What's unclear: Do we also want a `tests/suite/TestExamplesSmoke.m` class so the MATLAB CI job (`matlab-examples`) exercises the same harness?
   - Recommendation: **Keep it Octave-only.** The MATLAB smoke-test coverage already exists in `examples.yml` `matlab-examples` job. Duplicating it as a unit test adds noise without new coverage. If the planner disagrees, a thin class wrapper is trivial.

2. **Does `run_all_examples.m` stay interactive or become purely auto?**
   - What we know: CONTEXT.md says "recursively walk `examples/**/*.m`, run each in a try/catch, print a summary" — no mention of preserving interactive mode.
   - What's unclear: Is the interactive mode still valuable for humans who want to step through examples?
   - Recommendation: **Keep an interactive opt-in.** Default mode should be `'auto'` (CI-safe) but support `run_all_examples('interactive')` for the human path. My skeleton above does this; 7 lines of code to preserve the human workflow.

3. **Should showcase scripts demonstrate `TagRegistry.loadFromStructs` two-phase deserialization?**
   - What we know: `loadFromStructs` is a substantial feature (two-pass resolveRefs, `TagRegistry:unresolvedRef` on failure). The existing `example_sensor_registry.m` does NOT exercise it.
   - What's unclear: Is a 5th/6th showcase script worth adding? CONTEXT locks the set at 5.
   - Recommendation: **Include a section in `example_tag_registry.m`** that exercises `loadFromStructs` round-trip, demonstrating the two-pass pattern. Keeps showcase count at 5; adds high-value coverage to the registry showcase.

4. **How should `example_sensor_todisk.m`'s `.ResolvedThresholds` / `.ResolvedViolations` references be handled?**
   - What we know: Lines 37-39 print "Thresholds: %d, Violations: %d" using deleted properties. Script is MATLAB-only (CI already skips on Octave).
   - What's unclear: Should the reporting lines be deleted, or rebuilt via MonitorTag?
   - Recommendation: **Delete the fprintf and add a MonitorTag** with a static threshold so the disk-backed SensorTag has a companion that exercises `monitor.getXY()` over disk data (demonstrates end-to-end disk + monitor interaction — a genuinely valuable test).

5. **CI workflow — does the new smoke test need `examples.yml` update?**
   - What we know: `.github/workflows/examples.yml` has a hand-curated `EXAMPLES=(...)` list for Octave (lines 45-95). Missing entries from this list are not exercised.
   - What's unclear: Does the smoke test inside `run_all_tests.m` obviate the curated list, or complement it?
   - Recommendation: **Leave `examples.yml` mostly as-is** (known-good curated list + explicit per-example output for fast debug). The new smoke test is an orthogonal belt inside `tests.yml` (or whatever runs `run_all_tests.m` in CI). They can coexist; the smoke test catches regressions in NEW examples added between workflow edits.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| MATLAB | MATLAB CI job; widget examples | ✓ (in CI via matlab-actions/setup-matlab) | R2020b | — |
| GNU Octave | Octave CI job; primary smoke-test target | ✓ (CI container: gnuoctave/octave:11.1.0) | 11.1.0 | — |
| MEX binaries (compiled from `libs/FastSense/private/mex_src/`) | Every example touching FastSense | ✓ (built by `_build-mex-octave.yml`; cached across jobs via artifact `mex-linux-examples`) | repo-local | Pure-MATLAB fallback exists (`FASTSENSE_SKIP_BUILD=1`) |
| Xvfb (virtual X display) | Octave CI job; headless figure rendering | ✓ (started in `examples.yml:98`) | system default | `DefaultFigureVisible='off'` at harness start |
| Python 3.11+ | `example_webbridge.m` only | ✓ (not on smoke-test path; webbridge is in CI skip list) | — | N/A — webbridge is interactive-only |
| FastAPI/uvicorn (Python bridge) | `example_webbridge.m` only | N/A | — | Skip in smoke test |
| `containers.Map` | `TagRegistry`, `EventBinding`, smoke-test harness | ✓ | native | N/A |
| `datetime`/`categorical` (MATLAB-only) | `example_dock*`, `example_mixed_tiles`, `example_disk_storage`, `example_sensor_detail_*` | ✓ on MATLAB; ✗ on Octave | — | Already in Octave CI skip list |

**Missing dependencies with no fallback:** none block this phase.

**Missing dependencies with fallback:** none block this phase.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | MATLAB: `matlab.unittest` (class-based suite in `tests/suite/`); Octave: custom function-based runner in `tests/run_all_tests.m` that globs `test_*.m` and shells each into a subprocess |
| Config file | None (no `pytest.ini`); harness logic lives in `tests/run_all_tests.m` |
| Quick run command | `matlab -batch "cd tests; run_all_tests"` (MATLAB) or `octave --no-gui --eval "cd('tests'); run_all_tests();"` (Octave) |
| Full suite command | Same as quick — MATLAB discovers all classes in `tests/suite/`; Octave discovers all `tests/test_*.m` |

### Phase Requirements → Test Map

Phase owns no REQ-IDs; success is behavioral: every example runs green on both runtimes.

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| — (structural goal 1) | Every `examples/01-basics/**/*.m` runs without error on Octave | smoke | `octave --eval "cd tests; test_examples_smoke()"` — filter to 01-basics via dir() | ❌ Wave 0 |
| — (structural goal 2) | Every `examples/02-sensors/**/*.m` (including new `tags/` showcase) runs without error on Octave (and MATLAB for MATLAB-only ones) | smoke | same harness | ❌ Wave 0 |
| — (structural goal 3) | Every `examples/03-dashboard/*.m` not in skip list runs without error (MATLAB-only in CI) | smoke | `matlab-examples` job in `examples.yml` (existing) | ✅ |
| — (structural goal 4) | Every `examples/04-widgets/*.m` runs under MATLAB | smoke | `matlab-examples` job in `examples.yml` (existing) | ✅ |
| — (structural goal 5) | Event-pipeline examples in `05-events/` that are not in the live-timer skip list run without error | smoke | same harness | ❌ Wave 0 |
| — (structural goal 6) | Rewritten `example_sensor_threshold.m` emits ≥ 1 event (MonitorTag + EventStore wired correctly) | integration | Assertion inside `tests/suite/TestExamplesSmoke.m` (MATLAB) or a dedicated `tests/test_sensor_threshold_demo.m` (Octave) | ❌ Wave 0 |
| — (structural goal 7) | 5 new Tag showcase scripts each demonstrate at least one Tag API primitive without error | smoke | same harness (auto-picks up new scripts via recursive dir glob) | ❌ Wave 0 |
| — (structural goal 8) | `run_all_examples('auto')` completes with exit status 0 in CI | integration | Can be called as a sanity check inside the smoke test | ❌ Wave 0 |
| — (regression guard) | No occurrence of `Sensor(`, `Threshold(`, `StateChannel(`, `CompositeThreshold(`, `ThresholdRule(`, `SensorRegistry.`, `ExternalSensorRegistry.` in `examples/**/*.m` | grep gate | `grep -rE '\\b(Sensor|Threshold|StateChannel|CompositeThreshold|ThresholdRule|SensorRegistry|ExternalSensorRegistry)\\(' examples/ ; rc=1 if any hit` | — (test can be a one-liner inside the smoke test's teardown) |

### Sampling Rate
- **Per task commit:** `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke();"` (or a folder-scoped variant running just that folder's examples)
- **Per wave merge:** `tests/run_all_tests.m` (full suite — includes smoke test + all unit tests)
- **Phase gate:** Full suite green (MATLAB + Octave via `.github/workflows/examples.yml` + `tests.yml`) before `/gsd:verify-work`; smoke test reports 0 failures

### Wave 0 Gaps
- [ ] `tests/test_examples_smoke.m` — new function-based test; auto-picked up by `tests/run_all_tests.m` on Octave
- [ ] (optional, for MATLAB CI redundancy) `tests/suite/TestExamplesSmoke.m` — class wrapper; skip per Open Question #1
- [ ] `tests/suite/Test*.m` — NO new class-based tests required; existing Tag suite (`TestSensorTag.m`, `TestStateTag.m`, `TestMonitorTag.m`, `TestCompositeTag.m`, etc.) already covers the library surface the examples exercise

No framework install needed — `matlab.unittest` ships with MATLAB; Octave function tests use native Octave.

## Sources

### Primary (HIGH confidence)
- `libs/SensorThreshold/Tag.m` — Tag base class, universals, abstract-by-convention contract (6 methods + 2 event convenience methods)
- `libs/SensorThreshold/SensorTag.m` — SensorTag full API: constructor NV-pairs, X/Y read-only getters, updateData, toDisk/toMemory/isOnDisk, listeners
- `libs/SensorThreshold/StateTag.m` — StateTag ZOH valueAt byte-for-byte parity with deleted StateChannel, `emptyState` guard
- `libs/SensorThreshold/MonitorTag.m` — MonitorTag constructor / NV-pairs / ConditionFn contract / EventStore binding / event emission via EventBinding.attach
- `libs/SensorThreshold/CompositeTag.m` — CompositeTag addChild (type guard + cycle DFS), 7 AggregateModes, merge-sort streaming
- `libs/SensorThreshold/TagRegistry.m` — static methods, HARD-ERROR on duplicate key, two-phase loadFromStructs, instantiateByKind dispatch
- `libs/EventDetection/EventBinding.m` — attach/getTagKeysForEvent/getEventsForTag/clear; forward+reverse index
- `libs/EventDetection/Event.m` — TagKeys/Severity/Category fields
- `libs/EventDetection/EventConfig.m` — confirms addSensor and runDetection are stubbed (hard-error / no-op respectively)
- `libs/EventDetection/EventStore.m` — atomic write + MaxBackups
- `tests/run_all_tests.m` — harness discovery pattern (`test_*.m` glob, subprocess isolation on Octave)
- `.github/workflows/examples.yml` — curated Octave example list + MATLAB-only list
- `.planning/phases/1012-migrate-examples-to-tag-api/1012-CONTEXT.md` — locked decisions
- `.planning/milestones/v2.0-REQUIREMENTS.md` — 45 REQ-IDs, all `[x]` done
- `.planning/STATE.md` — Phase 1011 summary lines (lines 115-119, 237-239) confirming what was deleted
- `examples/02-sensors/example_sensor_registry.m` — style template (already migrated; use as canonical shape for new showcase scripts)

### Secondary (MEDIUM confidence)
- `examples/02-sensors/example_sensor_threshold.m` — direct inspection showing 5 orphan comment blocks
- `examples/05-events/example_event_detection_live.m`, `example_event_viewer_from_file.m`, `example_live_pipeline.m` — direct inspection confirming EventConfig.addSensor usage
- `examples/06-webbridge/example_webbridge.m` — direct inspection confirming `sensor.addData(t, y)` calls that will fail
- `examples/04-widgets/example_widget_fastsense.m` — direct inspection confirming `sTemp.X =`, `sTemp.Y =` direct-assignment failures
- `examples/03-dashboard/example_dashboard_all_widgets.m`, `example_dashboard_advanced.m` — direct inspection of `ResolvedViolations` / `countViolations` loops
- Phase 1009 CONTEXT.md — consumer-migration precedent (one commit per consumer, `'Tag'` NV-pair on widgets)
- Phase 1010 CONTEXT.md — EventBinding API signatures + renderEventLayer pattern

### Tertiary (LOW confidence)
- None — all claims traced to primary source files or explicit STATE.md entries. No WebSearch required; this is a first-party codebase migration with every API and every example directly readable.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all Tag API surfaces verified against class source files in this worktree
- Architecture: HIGH — CONTEXT.md locks structure; 28-file inventory verified by grep + per-file read of representative samples (8 files read end-to-end; remaining via grep count)
- Pitfalls: HIGH — every pitfall is traced to a specific file:line in this worktree OR a Phase summary line in STATE.md
- Legacy→Tag mapping: HIGH — verified against Tag subclass source; additional `ResolvedViolations` / `addData` / direct-X/Y-assignment hazards discovered during inventory (not in original CONTEXT list of 5 top-level APIs)

**Research date:** 2026-04-17
**Valid until:** 2026-05-17 (stable first-party API; expiry is soft — re-verify only if a new phase modifies `libs/SensorThreshold/` or `libs/EventDetection/` surface)
