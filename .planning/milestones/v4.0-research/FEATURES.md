# Feature Research — v2.1 Tag-API Tech Debt Cleanup

**Domain:** Post-v2.0 tech debt closure for a MATLAB Tag-based sensor dashboard (no net-new features). Tag API, TagRegistry, EventBinding, EventStore already exist.
**Researched:** 2026-04-22
**Mode:** Project Research — behavior-shape scoping of 4 audit-flagged cleanup items.
**Confidence:** HIGH (all evidence read directly from the codebase; v2.0 audit is authoritative).

## Scope Statement

This is NOT new-feature research. The 4 items below are scoped cleanups: dead-code deletion, a serializer gap, ~93 test-file constructor references to a deleted class, and 2 stubbed example rewrites. Every referenced API (SensorTag / StateTag / MonitorTag / CompositeTag / TagRegistry / EventBinding / EventStore / `LiveEventPipeline` / `FastSense.addTag`) already ships in v2.0 and must not be re-invented.

---

## Item 1 — `EventDetector.detect(tag, threshold)` dead code

### Current state (verified)

- `libs/EventDetection/EventDetector.m:39-75` — `detect(obj, tag, threshold)` calls `threshold.allValues()`, `.Direction`, `.Name`, `.Key`. **`Threshold` class does not exist** (`libs/**/Threshold.m` glob empty — deleted Phase 1011). First invocation → `MATLAB:undefinedClass` crash before any method call.
- `libs/EventDetection/IncrementalEventDetector.m:31-41` — `process()` already a **hard-error stub** (`IncrementalEventDetector:legacyRemoved`, points to `MonitorTag.appendData`). Clean precedent for the stub shape.
- `libs/EventDetection/EventConfig.m:35-42` — `addSensor()` same stub pattern already applied.
- `libs/EventDetection/EventConfig.m:59-85` — `runDetection()` returns empty events; body no-ops the legacy path. `buildDetector()` still constructs a working `EventDetector` (for the legacy 6-arg `detect_(t, values, thresholdValue, direction, thresholdLabel, sensorName)` path, which uses NONE of the deleted classes).
- `tests/suite/TestEventDetectorTag.m:32-56` still calls `det.detect(st, thr)` where `thr = Threshold(...)` — these tests are broken on MATLAB, skipped on Octave (part of Item 3).

### Production callers of `EventDetector.detect(tag, threshold)`

**Zero.** Grep across `libs/`, `examples/`, `benchmarks/` for the 2-arg `.detect(` on a Tag produced no production hits. Only test code (`TestEventDetectorTag.m`) calls it.

### Still-used pieces of `EventDetector`

- `EventDetector.detect_` private body — called nowhere in production either; the only `.detect(...)` hits in live code are the 6-arg legacy signature inside tests (`TestEventDetectorTag.testLegacySixArgOverloadUnchanged`). `EventConfig.buildDetector()` returns a configured `EventDetector` but no one invokes `.detect` on it in production.
- Conclusion: **the entire `EventDetector` class body is unreachable in production**. Only test code exercises it.

### Table Stakes

| Feature | Why Must-Do | Complexity | Notes |
|---------|-------------|------------|-------|
| Hard-error stub `detect(tag, threshold)` with legacy-removed message | Matches established v2.0 pattern (`IncrementalEventDetector.process`, `EventConfig.addSensor`) — callers get a loud, migration-pointing error instead of `undefinedClass` crash | LOW | Copy the `EventConfig.addSensor` template: `error('EventDetector:legacyRemoved', 'detect(tag, threshold) depended on the deleted Threshold class. Use MonitorTag + EventStore for event detection.')` |
| Delete the 2-arg overload body entirely (no placeholder) — leave only `detect_` + legacy-positional detect | Defensible alternative: v2.0 REQs are all closed, the 2-arg overload was Phase 1009 scaffolding for a carrier pattern Phase 1010 replaced with `EventBinding` | LOW | Requires checking whether any consumer still depends on the method being callable (answer: no — only tests) |
| Keep `detect_` private body callable via a preserved legacy positional `detect(t, values, ...)` | `TestEventDetectorTag.testLegacySixArgOverloadUnchanged` verifies this signature still works; removing it breaks a test we otherwise keep | LOW | Simplest path: rename 6-arg body to be the public `detect` entry; this IS what the test exercises |
| Update `TestEventDetectorTag.m` — delete `testTagOverloadDetectsEvents`, `testTagOverloadWithEmptyTag`, `testPitfall1NoSubclassIsaInDetect` | They all construct `Threshold(...)` and invoke the removed 2-arg overload | LOW | `testLegacySixArgOverloadUnchanged` + `testNonTagNonSensorErrors` are the survivors |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Replace `EventConfig.runDetection()` with a clear hard-error stub | Currently silently returns `[]` — a worse DX than `addSensor`'s hard-error. Consistency win. | LOW | `error('EventConfig:legacyRemoved', ...)` matching `addSensor` |
| Delete `IncrementalEventDetector` class entirely | The stubbed `.process()` cannot be called and its only purpose was to wrap the deleted `Sensor/Threshold` pipeline; `LiveEventPipeline` still constructs one (line 64-68) but never invokes a method on it | MEDIUM | Requires untangling the `obj.detector_` field in `LiveEventPipeline` — low risk since `processMonitorTag_` drives everything now |
| Delete `EventConfig` class entirely | `addSensor` errors, `runDetection` returns empty; the class is unreachable except through `buildDetector` which returns a functioning `EventDetector` no one uses. Full deletion closes a major chunk of Item 3's test cleanup (TestEventConfig + TestEventStore's usage) | MEDIUM-HIGH | Cross-cutting: 11 EventStore/EventConfig tests rely on it. Defer or couple with Item 3. |

### Anti-Features (explicitly DO NOT do)

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Silent no-op stub (return `[]`) for `detect(tag, threshold)` | Masks bugs; callers think detection ran. `addSensor` already chose hard-error — inconsistency is worse than the noise. | Hard-error stub matching `IncrementalEventDetector.process` precedent |
| Keep `detect(tag, threshold)` working via `MonitorTag` synthesis under the hood | Would require constructing a synthetic `MonitorTag` + `EventStore` from a `Threshold`, defeating the whole cleanup — and would need to re-introduce `Threshold` or a façade | Document that callers must construct a MonitorTag themselves (per `example_sensor_threshold.m`) |
| Re-introduce `Threshold` as a simple value struct for backward compat | Phase 1011 Pitfall 12 (feature creep in cleanup) and Pitfall 11 (test rewrite without golden) explicitly forbid this. TagRegistry is the one-namespace-one-search-surface decision. | MonitorTag + ConditionFn closure (the documented replacement) |
| Add warning-then-delegate shim | v2.0 is a clean break ("no users" codebase per Key Decisions table). Warning tech-debt is worse than hard-error tech-debt. | Hard-error is the decision |

### Complexity estimate

**SIMPLE** (1-2 hours). Two function bodies swapped to error-stubs; ~4 test methods deleted. Worst case with optional `EventConfig`/`IncrementalEventDetector` class deletion = MEDIUM.

### Dependencies on existing Tag API

- `MonitorTag + EventStore + EventBinding` (the pointed-to replacement) — all already ship in v2.0.
- `Event.Id` auto-assigned by `EventStore.append` (line 29) — already shipped Phase 1010.
- No new API needed.

---

## Item 2 — `DashboardSerializer` `.m` export gap for `source.type='tag'`

### Current state (verified)

- `libs/Dashboard/FastSenseWidget.m:257-258` — `toStruct` emits `s.source = struct('type', 'tag', 'key', obj.Tag.Key)`. This is the CURRENT canonical shape.
- `libs/Dashboard/FastSenseWidget.m:374-383` — `fromStruct` correctly handles `case 'tag'` via `TagRegistry.get(s.source.key)`. JSON round-trip works.
- `libs/Dashboard/DashboardSerializer.m:38-55` (in `save()` — the .m function file path) — handles `'sensor'`, `'file'`, `'data'`, but **no `'tag'` case**. Silently falls through to the `otherwise` branch which emits `d.addWidget('fastsense', 'Title', ..., 'Position', ...)` **dropping the Tag binding entirely**.
- `libs/Dashboard/DashboardSerializer.m:598-618` (in `linesForWidget` — the `exportScript` / `exportScriptPages` .m script path) — same gap: `'sensor'` case uses `TagRegistry.get(ws.source.name)`, no `'tag'` case, silently drops the binding via `otherwise`.
- Partial fallback: the `'sensor'` case ALREADY uses `TagRegistry.get(ws.source.name)` — meaning the legacy JSON format with `type='sensor'` already round-trips through the registry. The new `type='tag'` format just needs a parallel case with `ws.source.key` instead of `ws.source.name`.

### Scope — which widgets have this gap?

Only `FastSenseWidget` emits `source.type='tag'` today (verified via grep: exactly one emitter at `FastSenseWidget.m:258`). The `source.type` construct is used by 9 widgets total but only FastSenseWidget serializes a Tag binding through it.

**Question from the prompt:** "Does this include `CompositeTag` / `MonitorTag` / `StateTag`-bound widgets or only `SensorTag`?"

**Answer:** `FastSenseWidget.Tag` accepts any `Tag` subclass (see Phase 1009-01, `FastSense.addTag` dispatch on `tag.getKind()`). `toStruct` stores only `Key`, so the kind is irrelevant to serialization — resolving via `TagRegistry.get(key)` returns the correct polymorphic handle. **The fix is kind-agnostic** — one `case 'tag'` handles all four.

### Convention survey — what do other unknown types do?

- `DashboardSerializer.createWidgetFromStruct` line 353: `warning('DashboardSerializer:unknownType', 'Unknown widget type: %s — skipping', ws.type);` returns `[]`.
- `linesForWidget` `otherwise` (line 728): silent fallback `d.addWidget('%s', 'Title', ..., 'Position', ...)` — lossy but doesn't warn.
- `save()` `switch ws.source.type` `otherwise` branches: silent `d.addWidget('fastsense', 'Title', ..., 'Position', ...)` — silent data loss.

**Convention:** unknown widget *types* warn; unknown `source.type` values silently degrade. The gap here is that `'tag'` is a KNOWN source.type (emitted by our own `toStruct`) that the exporter forgot to implement — this is a bug, not an extension point.

### Table Stakes

| Feature | Why Must-Do | Complexity | Notes |
|---------|-------------|------------|-------|
| Add `case 'tag'` in `DashboardSerializer.save()` (around line 38) | Closes the `.m` function-file export path; emits `'Tag', TagRegistry.get('KEY'))` just like the `'sensor'` case | LOW | Code-shape: `lines{end+1} = sprintf('        ''Tag'', TagRegistry.get(''%s''));', ws.source.key);` — 3 lines matching the existing `'sensor'` block verbatim but with `.key` not `.name` |
| Add `case 'tag'` in `DashboardSerializer.linesForWidget()` (around line 598) | Closes the `.m` script-export path (`exportScript`, `exportScriptPages`) | LOW | Same 3-line pattern with `indent` prefix; copy-paste of the `'sensor'` branch |
| Round-trip test: build dashboard with `FastSenseWidget.Tag=SensorTag`, call `DashboardSerializer.save(config, '/tmp/x.m')`, `feval('x')`, verify widget's `Tag` handle resolves to the same registry entry | Only way to prove the fix works; currently `TestDashboardSerializerRoundTrip.m` exists but does not cover `source.type='tag'` through .m export (verified by grep on existing test file names) | LOW-MEDIUM | Test fixture: `TagRegistry.clear(); TagRegistry.register('k', SensorTag('k', 'X', 1:5, 'Y', 1:5));` construct FastSenseWidget, exportScript, feval, assert `w.Tag.Key == 'k'` |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Require TagRegistry lookup to succeed (don't silently wrap in try/catch) | The `FastSenseWidget.fromStruct` has try/catch + warning today (line 377-382) — that's the JSON path's safety net. The .m export should emit the same `TagRegistry.get(...)` call literally — `TagRegistry.get` hard-errors on unknown keys (Pitfall 7 decision), which is the correct behavior for a round-trip script | LOW | Do NOT wrap emitted code in try/catch — let it error loudly if the registry wasn't pre-populated |
| Emit a header comment in exported .m files reminding users to populate TagRegistry before running | Avoids confusing "TagRegistry:unknownKey" errors when users share scripts | LOW | `%% Note: This script requires the following tags to be registered: <list>` |
| Cover multi-page round-trip (`exportScriptPages` path) in the same test | The two .m export codepaths (`save`/`exportScript` single-page and `exportScriptPages` multi-page) share `linesForWidget`, but `save()` has its own inline switch at line 38 — must exercise BOTH | MEDIUM | Two-test-method pattern mirrors Phase 6 serialization approach |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Emit full SensorTag constructor code in the .m export (`SensorTag('k', 'X', [...], 'Y', [...])`) | Defeats the registry pattern; makes exported scripts huge; loses the singleton identity needed for cross-widget sharing | Emit `TagRegistry.get('key')` — requires registry to be pre-populated, which is how the sibling 'sensor' case already works |
| Bake MonitorTag / CompositeTag construction into the exporter | Kind-specific codepaths violate the Tag abstraction (Pitfall 1 — no subclass isa in dispatch); registry lookup is kind-agnostic | Single `case 'tag'` covering all Tag subclasses |
| Silently skip Tag-bound widgets (current behavior) | That IS the bug — users lose their widget binding on save/load round-trip through .m export | Explicit `case 'tag'` emission |
| Emit a warning on tag miss AT SAVE TIME instead of fixing the emission | The JSON path works fine today; save-time warning would be false-positive noise for the JSON codepath | Fix the .m emission to match the JSON behavior |

### Complexity estimate

**SIMPLE** (2-3 hours). Two switch-cases to extend + 2 round-trip tests. Gap is localized to `DashboardSerializer.m`. No cross-class refactor needed.

### Dependencies on existing Tag API

- `TagRegistry.get(key)` — already shipped Phase 1004.
- `FastSenseWidget.toStruct` / `fromStruct` — already emit/consume `source.type='tag'` (Phase 1009-01).
- `DashboardEngine.addWidget('fastsense', ..., 'Tag', tag)` — the NV-pair accepting a Tag handle already works (Phase 1009-01).

---

## Item 3 — 93 `Threshold(` constructor references across 42 test files

### Current state (verified)

- Grep `=\s*Threshold\(` in `tests/` → **93 occurrences across 22 files**. (The audit's "42 files" count includes parallel flat-script `tests/test_*.m` + suite `tests/suite/Test*.m`, so ~22 pairs = ≤44 files. 93 constructor refs is exact.)
- All 22 files instantiate `Threshold(key, 'Name', 'X', 'Direction', 'upper'|'lower')`, call `t.addCondition(struct(), <value>)`, and pass to `sensor.addThreshold(t)`. **`Threshold` class deleted in Phase 1011; `SensorTag` has no `addThreshold` method** (verified by `ls libs/SensorThreshold/` — only Tag, SensorTag, StateTag, MonitorTag, CompositeTag, TagRegistry remain).
- State today: these tests CRASH on MATLAB (`Undefined function 'Threshold'`) and silently SKIP on Octave (implicit try/catch in test runner).

### Classification of the 22 files

Reading the test bodies (TestEventConfig, TestEventStore, TestStatusWidget, TestIncrementalDetector, TestEventDetectorTag, TestLiveEventPipelineTag, TestGaugeWidget, TestMultiStatusWidget, TestIconCardWidget samples):

**Category A — Test dead code (DELETE):**
- `TestEventConfig.m` — every test body calls `Threshold(...) + addCondition + addThreshold + cfg.addTag + cfg.runDetection`. All paths hit stubbed hard-errors. Tests are dead; function under test is dead.
- `TestEventStore.m` — 7 refs inside tests that use `cfg.runDetection()` to produce events before asserting save/load. Event production is dead; save/load itself still works. **Rewrite** with `EventStore.append(Event(...))` direct fixtures, don't delete.
- `TestIncrementalDetector.m` — every test calls `det.process(...)` which is stubbed to hard-error. Entire class is dead (Item 1 candidate for deletion). DELETE.
- `TestEventDetectorTag.m` — testTagOverloadDetectsEvents/EmptyTag/Pitfall1 exercise the deleted 2-arg detect. DELETE those 3 methods; keep testLegacySixArgOverloadUnchanged + testNonTagNonSensorErrors.
- `TestLiveEventPipelineTag.m:113-115, 135-137, 165-167` — use `Threshold(...) + addCondition + sensor.addThreshold` purely to construct a "legacy sensor target" for the pipeline. But `LiveEventPipeline` no longer detects via that path; the `Threshold` construction is noise that doesn't affect the tested assertion (testLegacySensorPathUnchanged verifies Status='stopped'). **Rewrite:** drop the Threshold scaffolding, use bare SensorTag.

**Category B — Test LIVE behavior through DEAD constructor (REWRITE):**
- `TestStatusWidget.m` (12 refs), `TestGaugeWidget.m` (8 refs), `TestIconCardWidget.m` (6 refs), `TestChipBarWidget.m` (3 refs), `TestMultiStatusWidget.m` (11 refs), `TestIconCardWidgetTag.m` (2 refs), `TestMultiStatusWidgetTag.m` (1 ref), `TestDashboardEngine.m` (1 ref), `TestFastSenseWidget.m` (1 ref), `TestSensorDetailPlot.m` (1 ref) — these test widget-threshold binding (Status/Gauge/IconCard threshold property), which still exists in the v2.0 codebase. The WIDGETS are alive; the construction fixture is dead. **Rewrite** using MonitorTag + ConditionFn closure as the new "threshold" (matches `example_sensor_threshold.m` pattern).
- Check: grep `obj.Threshold` in widget source → widgets likely reference Threshold-handle properties still. Needs quick audit during execution.

**Category C — Parallel flat-script copies (MIRROR Category A/B):**
- `tests/test_SensorDetailPlot.m`, `tests/test_multistatus_widget_tag.m`, `tests/test_gauge_widget.m`, `tests/test_event_store.m`, `tests/test_icon_card_widget_tag.m`, `tests/test_event_config.m`, `tests/test_add_threshold.m`, `tests/test_multi_threshold.m`, `tests/test_toolbar.m` — Octave-safe duplicates of Category B suite tests. Apply identical treatment in parallel.

### Migration pattern (canonical)

From `example_sensor_threshold.m:43-46`:

```matlab
% OLD (deleted):
t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
t_warn.addCondition(struct(), 10);
sensor.addThreshold(t_warn);

% NEW (Tag API):
conditionFn = @(x, y) y > 10;   % upper direction, static value 10
warn = MonitorTag('warn', sensor, conditionFn, ...
    'Name', 'warn', ...
    'EventStore', store);
TagRegistry.register('warn', warn);
```

For widget-threshold binding (StatusWidget, GaugeWidget), the equivalent is: the MonitorTag IS the threshold. Pass the MonitorTag handle to widget's `Tag` property (Phase 1009-02 direct-tag-binding).

**Reference fixture:** `tests/suite/makePhase1009Fixtures.m` already provides `makeSensorTag`, `makeMonitorTag`, `makeCompositeTag`, `makeEventStoreTmp`. All new migrated tests should use this.

### Table Stakes

| Feature | Why Must-Do | Complexity | Notes |
|---------|-------------|------------|-------|
| DELETE TestEventConfig.m + test_event_config.m | Entirely dead; EventConfig.addSensor + runDetection both stubbed | LOW | 2 files, ~150 LOC total |
| DELETE TestIncrementalDetector.m | `IncrementalEventDetector.process` stubbed; class is dead | LOW | 1 file, 120 LOC |
| REWRITE TestEventStore.m + test_event_store.m event-production fixtures to use `EventStore.append(Event(...))` directly or via MonitorTag emission | EventStore save/load/backup/atomic-write behavior is still live and shipped; must preserve coverage | MEDIUM | 21 refs across 2 files; rewrite sticks to EventStore public API |
| REWRITE TestStatusWidget/TestGaugeWidget/TestIconCardWidget/TestChipBarWidget/TestMultiStatusWidget (and the 2 *Tag variants) to use `MonitorTag` (or direct struct source) instead of `Threshold` | Widget-threshold binding is active production code; deleting the tests loses real coverage | MEDIUM | 37 refs across 7 files; use `makePhase1009Fixtures.makeMonitorTag` as the fixture factory |
| TRIM TestEventDetectorTag.m to the 6-arg-legacy + error-path methods; delete 3 tag-overload methods | Consistent with Item 1 stub; leaves legacy positional signature coverage intact | LOW | 4 refs to drop |
| TRIM TestLiveEventPipelineTag.m: remove `Threshold(...) + addCondition + addThreshold` boilerplate from testLegacySensorPathUnchanged / testMonitorsNVPairOptional / testMixedSensorsAndMonitors — the Threshold construction is scaffolding for dead code | Test assertions don't depend on the Threshold object; removing clarifies intent | LOW | 9 refs to drop; keep MonitorTag-based assertions intact |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| Move Category-A-equivalent integration tests to a single consolidated `TestLegacyEventDetectionRemoved.m` | Single doc file asserts `error('EventConfig:legacyRemoved', ...)` + `error('IncrementalEventDetector:legacyRemoved', ...)` + `error('EventDetector:legacyRemoved', ...)` fire correctly | LOW | Replaces 3 deleted suites with one focused deprecation-contract test |
| Add a grep-based "no Threshold( in tests/" regression gate to `tests/run_all_tests.m` | Prevents the debt from being re-introduced in future test PRs (parallels Phase 1011's `grep -rE 'Sensor\('` gate) | LOW | 5-line regex check at the top of the runner |
| Audit parallel `tests/test_*.m` files for equivalence with `tests/suite/Test*.m` and collapse duplicates | 42 files → 22 distinct concerns; the flat-script versions predate the suite migration and are mostly Octave-parity copies. Post-cleanup is a good moment to consolidate | HIGH | Out of scope for this milestone — flag as v2.2 candidate |
| Standardize TestMethodSetup to call `TagRegistry.clear()` + `EventBinding.clear()` | Phase 1010 Pitfall 7 hard-errors on duplicate `.register()`; rerun in same session crashes — already applied in 4 suite tests (TestEventDetectorTag, TestLiveEventPipelineTag, etc.), should be universal | LOW | Pattern exists at `tests/suite/TestEventDetectorTag.m:18-28` — copy to all migrated tests |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| Find-and-replace `Threshold(key, ...)` with `MonitorTag(key, parent, @(x,y) y > V)` without understanding the test assertions | Many tests assert on `ThresholdValue`, `ThresholdLabel`, `Direction` fields of the resulting `Event` — MonitorTag sets these via Parent.Key/monitor.Key carriers, NOT via a `Threshold.Name/.Direction`. Mechanical rewrite will produce silently-wrong assertions. | Read each test body, identify what's asserted, pick MonitorTag vs EventStore-direct fixture per case |
| Re-introduce `Threshold` as a deprecated thin wrapper just to unblock the tests | Exact Phase 1011 Pitfall 12 (feature creep in cleanup). Tests must be adapted to the shipped API, not the reverse. | Rewrite the tests |
| Add a try/catch Octave-skip guard to every failing MATLAB test to "hide" the failures | Keeps skip on Octave but turns a MATLAB crash into an error-message-check. Neither test the actual behavior. | Delete + rewrite properly |
| Defer Category B rewrites to v2.2 and only delete Category A | Leaves widget-threshold binding without any test coverage on MATLAB for another milestone — binding is user-facing and recently refactored (Phases 1001-1003 then 1009-02) | Do Category A deletion AND Category B rewrite in the same milestone |

### Complexity estimate

**MEDIUM** (2-3 days). The volume (22 files, 93 refs) is the cost driver. No architectural work — just focused, per-file rewrites against `example_sensor_threshold.m` + `makePhase1009Fixtures`.

### Dependencies on existing Tag API

- `MonitorTag + EventStore + EventBinding` — shipped v2.0.
- `makePhase1009Fixtures` test-fixture factory — shipped Phase 1009.
- `TagRegistry.clear()` / `EventBinding.clear()` reset protocol — shipped Phase 1010.
- Widget `Tag` property on Status/Gauge/IconCard/MultiStatus — shipped Phase 1009-02.
- No new API required.

---

## Item 4 — Live-demo rewrites (`example_event_detection_live.m` + `example_event_viewer_from_file.m`)

### Current state (verified)

Both files have the Phase 1012-07 deprecation banner + `return;` early-out, with the original body retained below for reference. The bodies call `EventConfig()`, `cfg.addSensor(s)` (hard-errors now), `cfg.runDetection()` (returns empty), and `cfg.ThresholdColors` (still works but unused).

Pre-existing working reference:
- `examples/02-sensors/example_sensor_threshold.m` — canonical MonitorTag + EventStore + EventBinding pipeline (85 LOC, reads like a tutorial).
- `examples/02-sensors/tags/example_tag_monitor.m` — 3-MonitorTag primitive showcase (108 LOC, state-dependent / hysteresis / debounce).
- `examples/05-events/example_live_pipeline.m` — already-live-migrated v2.0 demo that uses `LiveEventPipeline` with `MonitorTargets` + `MockDataSource` + `EventStore.loadFile` + `EventViewer.fromFile`. This is the strongest template for the live-refresh file.

### What must the rewrites demonstrate?

**`example_event_detection_live.m` — live detection + live dashboard:**
- 2-3 `SensorTag` instances with synthetic data (temperature/pressure/vibration — preserve the narrative from the current deprecated body).
- `MonitorTag` per sensor with `MinDuration` (debounce) + bound `EventStore`.
- `TagRegistry.register` for each.
- `LiveEventPipeline` with `MonitorTargets` map (key→MonitorTag), `DataSourceMap` with `MockDataSource` per key.
- `pipeline.start()` (timer-driven) OR `for cycle = 1:N; pipeline.runCycle(); end` (manual, matches `example_live_pipeline.m`).
- FastSense figure with `addTag(sensor)` + `addTag(monitor)` — `ShowEventMarkers=true` (default) draws Phase 1010 event overlays live.
- Stop-flow: close figure → delete timer; OR bounded cycle count for smoke-test-safe.

**`example_event_viewer_from_file.m` — persistence + EventViewer:**
- Generate events into an `EventStore` via MonitorTag emission (offline batch, no live timer).
- `store.save()` — persist to `.mat`.
- `EventViewer.fromFile(eventFile)` — reload and display. (EventViewer is still alive per `libs/EventDetection/EventViewer.m` existence — verified via `TestEventViewer.m` in suite.)
- Show backup-rotation behavior (`MaxBackups` → run detection twice → list backup files).
- Optional: a `LiveEventPipeline` or raw timer that appends new events to the file every N seconds + `EventViewer.startAutoRefresh` for live-refresh demonstration.

### Idiomatic choice — `LiveEventPipeline` vs raw pipeline?

**`LiveEventPipeline`** is the idiom for both rewrites. Evidence:
1. `example_live_pipeline.m` (the already-working sibling) uses it.
2. `LiveEventPipeline.processMonitorTag_` (lines 160-244 of `LiveEventPipeline.m`) enforces the critical Pitfall Y parent-before-child ordering for MonitorTag.appendData — hand-rolling this in the examples would duplicate a ~40-LOC correctness-critical snippet.
3. The class is part of the shipped v2.0 API (`Phase 1009-03 SC#4`).

One exception: `example_event_viewer_from_file.m` Part 1 (detect-and-save) does NOT need a live pipeline — `store.append(Event(...))` or a one-shot `MonitorTag.getXY()` (which fires events on first read, per `example_sensor_threshold.m:54`) is simpler. Only Part 4 (background updates) benefits from `LiveEventPipeline`.

### Table Stakes — `example_event_detection_live.m`

| Feature | Why Must-Do | Complexity | Notes |
|---------|-------------|------------|-------|
| SensorTag + MonitorTag + EventStore setup for 3 sensors (temperature/pressure/vibration, matching current banner narrative) | Replaces the deleted EventConfig scaffold; preserves the example's pedagogical arc | LOW | Template: `example_sensor_threshold.m` x 3 sensors |
| LiveEventPipeline with MonitorTargets map + DataSourceMap(MockDataSource per key) | The canonical live-detection idiom; copies from `example_live_pipeline.m` | LOW | ~30 LOC; MockDataSource already supports StateValues for state-dependent thresholds if desired |
| FastSense figure with `addTag(sensor)` + `addTag(monitor)` per sensor — event markers auto-appear via Phase 1010 overlay | Shows the full end-to-end pipeline visually; replaces the deprecated startLive + mat-file plumbing | LOW | 3 subplots matching current layout; no `startLive` — pipeline.runCycle inside timer updates the MonitorTag.EventStore, and FastSense's renderEventLayer_ picks it up on refresh |
| Manual N-cycle loop (for demos) + optional timer-driven mode (commented) | Smoke-test-safe; matches `example_live_pipeline.m` convention | LOW | `for cycle = 1:3; pipeline.runCycle(); end` first, `% pipeline.start()` block below |
| Clean TagRegistry.clear + EventBinding.clear at top | Required for re-run safety (Pitfall 7 hard-error on duplicate register) | LOW | 2-liner matching `example_sensor_threshold.m:17-18` |

### Table Stakes — `example_event_viewer_from_file.m`

| Feature | Why Must-Do | Complexity | Notes |
|---------|-------------|------------|-------|
| Part 1: Offline detect-and-save via MonitorTag.getXY() with bound EventStore | Simpler than a pipeline for a one-shot batch run; matches `example_sensor_threshold.m` | LOW | 6 sensors × MonitorTag × store.save(); no timer |
| Part 2: `EventViewer.fromFile(eventFile)` — verify viewer opens with persisted events | Viewer is live v2.0 code; demonstrates load path | LOW | 1-liner |
| Part 3: Re-run detection → observe backup file created (`<file>_backup_*.mat`) | Demonstrates `EventStore.MaxBackups` (shipped feature) | LOW | Re-call MonitorTag.appendData with new tail, then store.save; list backup files via dir |
| Part 4 (optional): Background timer that appends new MonitorTag.appendData samples + EventViewer.startAutoRefresh | Shows live-refresh narrative from the original example | MEDIUM | Requires LiveEventPipeline OR a raw MATLAB timer calling pipeline.runCycle; viewer polls file |

### Differentiators

| Feature | Value | Complexity | Notes |
|---------|-------|------------|-------|
| State-dependent thresholds (MonitorTag ConditionFn closing over a StateTag) | Showcases `example_sensor_threshold.m`'s most-compelling pattern — thresholds that vary by machine mode | LOW | One sensor gets this treatment; others stay static; matches existing tag_monitor showcase |
| Use `EventBinding.getEventsForTag('sensor_key', store)` to query events by tag, not by carrier-field match | Demonstrates Phase 1010 EVENT-01 binding explicitly | LOW | 1 line in the print-summary section |
| Show the `FastSense.ShowEventMarkers` toggle (round-marker overlay from Phase 1010) | Demonstrates a flagship v2.0 feature | LOW | Comment + one-line toggle; visual payoff |
| Wire NotificationService (DryRun=true) like `example_live_pipeline.m` does | Consolidates the two live demos' narratives — 05-events becomes the obvious place to see notifications | LOW | Copy the NotificationRule block from `example_live_pipeline.m` |

### Anti-Features

| Anti-Feature | Why Avoid | Alternative |
|--------------|-----------|-------------|
| `startLive` + `fp.addLine` + `.mat`-file round-trip from the old example | That whole codepath is the deprecated `Sensor.resolve()`-era plumbing. FastSense now renders Tags directly via `addTag`; event overlays are automatic via Phase 1010; no mat-file poll loop needed | `fp.addTag(sensor); fp.addTag(monitor); pipeline.runCycle` + `drawnow` in the timer |
| `EventConfig`, `EventConfig.addSensor`, `EventConfig.runDetection`, `EventConfig.setColor` | All stubbed/no-op after Phase 1011 and Item 1 cleanup | `MonitorTag.EventStore = store` + `LiveEventPipeline` |
| `IncrementalEventDetector.process` (called in old example bodies) | Stubbed hard-error since Phase 1011 | `MonitorTag.appendData` via `LiveEventPipeline.processMonitorTag_` |
| Per-sample violation callbacks or `OnEventPerSample` | Explicit Phase 1006 anti-pattern (MONITOR-10) | `MonitorTag.OnEventStart` / `OnEventEnd` |
| `addThreshold` with a raw numeric value on FastSense as the PRIMARY detection mechanism | `addThreshold` still exists on FastSense for visual threshold LINES, but it is NOT the v2.0 detection mechanism (it draws a horizontal line; no events are produced) | Detection via MonitorTag; `addThreshold` only for visual reference lines (matches `example_sensor_threshold.m:76-78` usage) |
| Leave the deprecated banner + `return;` in place with longer body below | Clean break — Phase 1012-07 summary explicitly flagged this as deferred for "a small dedicated phase" (i.e., v2.1) | Full rewrite, delete legacy body |
| Use `Sensor`, `StateChannel`, `Threshold`, `CompositeThreshold`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry` — any of the 8 deleted classes | All deleted Phase 1011 | `SensorTag`, `StateTag`, `MonitorTag`, `CompositeTag`, `TagRegistry` |
| Return from inside timer callbacks without flushing EventStore | `LiveEventPipeline.stop()` already handles this; raw-timer rewrites must replicate it | Always end demos with `pipeline.stop()` or equivalent `store.save()` |

### Complexity estimate

**MEDIUM** (1-2 days). Both files need full rewrites (~150-200 LOC each) but the templates (`example_sensor_threshold.m`, `example_tag_monitor.m`, `example_live_pipeline.m`) cover every required pattern. No new API, no novel design.

### Dependencies on existing Tag API

- `SensorTag`, `StateTag`, `MonitorTag`, `TagRegistry` — shipped Phase 1004-1007.
- `EventBinding`, `EventStore.eventsForTag`, `FastSense.ShowEventMarkers` — shipped Phase 1010.
- `LiveEventPipeline.MonitorTargets`, `MonitorTag.appendData` — shipped Phase 1007/1009-03.
- `EventViewer.fromFile` — pre-v2.0, still active.
- `MockDataSource`, `DataSourceMap`, `NotificationService`, `NotificationRule` — pre-v2.0, still active.
- Smoke-test harness `tests/test_examples_smoke.m` — shipped Phase 1012-01; must either include the rewritten examples OR keep them on the skip list with justification.
- No new API required.

---

## Feature Dependencies — v2.1 cleanup items

```
[Item 1 — EventDetector stub]
       └── precedent for ──> [Item 3 — test cleanup]
                                    ├── delete TestEventConfig ────> (independent)
                                    ├── delete TestIncrementalDetector ──> (independent)
                                    ├── trim TestEventDetectorTag ──> (depends on Item 1)
                                    └── trim TestLiveEventPipelineTag ──> (independent of Item 1)

[Item 2 — DashboardSerializer .m export]
       └── depends on ──> [existing FastSenseWidget toStruct] (already ships)
       └── independent of all other items

[Item 4 — example rewrites]
       ├── depends on ──> [MonitorTag + EventStore + EventBinding] (ships)
       ├── depends on ──> [LiveEventPipeline.MonitorTargets] (ships)
       ├── template from ──> [example_sensor_threshold.m + example_live_pipeline.m] (ships)
       └── independent of Items 1/2/3 — can run in parallel
```

### Dependency Notes

- **Items 1/2/3/4 are mostly independent.** Item 3's trim of `TestEventDetectorTag.m` depends on Item 1's stub being in place (otherwise the test would fail differently), but the 4 items can plausibly ship in 1-2 commits each.
- **No item depends on a new API.** Every referenced replacement (MonitorTag / EventStore / EventBinding / LiveEventPipeline / TagRegistry) is already shipping v2.0 code.
- **Item 3 is the long pole** — 22 files of rewrite volume, even though each individual rewrite is simple.

## Complexity Summary

| Item | Complexity | Rough LOC | Rough duration | Notes |
|------|------------|-----------|----------------|-------|
| 1. EventDetector stub + IncrementalEventDetector assessment | SIMPLE | ~30 LOC net | 1-2 hours | Pattern already set by `EventConfig.addSensor` stub |
| 2. DashboardSerializer .m export `case 'tag'` | SIMPLE | ~20 LOC + 2 tests | 2-3 hours | Copy-paste existing `'sensor'` branch with `.key` not `.name` |
| 3. 93 Threshold( refs in 22 test files (Category A delete + B rewrite + C parallel) | MEDIUM | ~500 LOC churn | 2-3 days | Volume-driven, not complexity-driven |
| 4. Rewrite 2 `examples/05-events/` live demos | MEDIUM | ~300-400 LOC | 1-2 days | Follow `example_live_pipeline.m` template |

**Total milestone effort:** 3-5 days for one engineer; parallel-friendly since items are mostly independent.

## Out of Scope (defer to v2.2 or later)

- **Asset hierarchy** (Asset tree, templates, tag-to-asset binding, browse rollups) — per PROJECT.md explicit deferral.
- **Custom event GUI** (click-drag region selection → label dialog) — per PROJECT.md.
- **Calc tags / formula evaluator** for arbitrary derived tags — per PROJECT.md.
- **Tri-state / continuous severity MonitorTag output** — per PROJECT.md.
- **WebBridge parity for Tag API** — per PROJECT.md.
- **Consolidate 42 parallel `tests/test_*.m` + `tests/suite/Test*.m` files into one canonical layout** — legitimate follow-on but out of scope; this milestone migrates, doesn't restructure.
- **Delete `EventConfig` + `IncrementalEventDetector` classes entirely** — flagged as Item 1 "Differentiator"; aggressive but saves ~250 LOC. Keep as a stretch goal inside Item 1 if test-file cleanup (Item 3 Category A) makes the classes fully orphaned.
- **Add grep-based regression gate** (`grep -rE 'Threshold\(' tests/` → zero hits) — flagged as Item 3 differentiator; low-cost nice-to-have.

## Sources

| Source | Files | Confidence |
|--------|-------|------------|
| Direct code read (libs/EventDetection/*) | EventDetector.m, IncrementalEventDetector.m, EventConfig.m, LiveEventPipeline.m, EventStore.m, EventBinding.m | HIGH |
| Direct code read (libs/Dashboard/) | DashboardSerializer.m, FastSenseWidget.m | HIGH |
| Direct code read (examples/) | example_sensor_threshold.m, example_tag_{sensor,state,monitor,composite,registry}.m, example_live_pipeline.m, 05-events/{live,viewer} stubs | HIGH |
| Direct code read (tests/suite/) | TestEventConfig.m, TestEventStore.m, TestIncrementalDetector.m, TestEventDetectorTag.m, TestLiveEventPipelineTag.m, TestStatusWidget.m, TestAddThreshold.m, makePhase1009Fixtures.m | HIGH |
| Audit & roadmap | .planning/milestones/v2.0-MILESTONE-AUDIT.md, v2.0-ROADMAP.md, PROJECT.md, Phase 1012-07-SUMMARY.md | HIGH |
| Grep counts | `=\s*Threshold\(` → 93 refs in 22 files (audit's 42 counted flat-script mirrors) | HIGH |
| Grep negative (no `libs/**/Threshold.m` or `libs/**/Sensor.m`) | Confirms legacy classes deleted | HIGH |
