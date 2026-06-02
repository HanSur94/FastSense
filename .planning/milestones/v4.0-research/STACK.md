# Stack Research — v2.1 Tag-API Tech Debt Cleanup

**Domain:** Pure-MATLAB sensor-data dashboard engine. v2.0 shipped a unified `Tag` hierarchy. v2.1 closes 4 non-blocking tech-debt items from the v2.0 audit: dead `EventDetector.detect(tag,threshold)` code, `.m` export gap for `source.type='tag'`, 73 `Threshold(` constructor refs in 16 MATLAB-only suite test files, and 2 stubbed `examples/05-events/` live demos.
**Researched:** 2026-04-22
**Confidence:** HIGH (all claims verified directly against the v2.0 codebase; existing APIs read end-to-end for the 4 affected surfaces)

---

## Summary

**No new stack. No new dependencies. Zero new libraries.**

v2.1 is a cleanup milestone inside an already-validated toolchain. The v2.0 audit surfaced these items precisely because the surrounding infrastructure (Tag API, EventBinding, EventStore, LiveEventPipeline, matlab.unittest, MISS_HIT, custom test runner) is already in place and working. Every fix is a *mechanical migration* or *deletion* against APIs that already ship. Any library addition here would be strictly worse than the existing pattern.

Concretely, the research finds:

1. **Item 1 (dead EventDetector.detect):** Delete or stub the 2-arg overload. Zero callers in production. No stack change.
2. **Item 2 (DashboardSerializer `.m` export gap):** Add a `case 'tag'` branch to the existing `linesForWidget` static helper — mirrors the JSON round-trip that already works and the `source.type='sensor'` branch still present from the v2.0 loader (bridges to `TagRegistry.get(key)`). Pure extension of the existing pattern. No codegen library needed.
3. **Item 3 (73 `Threshold(` refs in 16 suite tests):** Rewrite the tests to the Tag API using existing `MonitorTag`/`SensorTag`/`addThreshold(scalar)` primitives. **Important finding:** cross-runtime skipping is already idiomatic via `testCase.assumeTrue(false, 'reason')` on MATLAB (matlab.unittest) and via `exist('OCTAVE_VERSION', 'builtin')` gates on Octave function-tests. Both idioms are in production in this repo. No new test-framework machinery required.
4. **Item 4 (live-demo rewrites):** The v2.0 `MonitorTag` + `EventStore` + `EventBinding` + `LiveEventPipeline` APIs **fully cover** the demo needs. `examples/02-sensors/example_sensor_threshold.m` + `examples/02-sensors/tags/example_tag_monitor.m` are the canonical patterns; the only piece that needs attention is wiring `LiveEventPipeline.MonitorTargets` with `MatFileDataSource` / `MockDataSource` which both already implement `fetchNew()`. No API gaps.
5. **Tooling additions for regression prevention:** ONE low-cost addition is justified — a grep gate in `tests.yml` (Lint job) to fail CI on any new `Threshold(` / `Sensor(` / `CompositeThreshold(` / `StateChannel(` / legacy `*Registry.` references in `libs/` + `tests/suite/` + `examples/`. This is a 5-line bash step, zero new deps, and it prevents tech-debt rebound. Phase 1012 Plan 10 already uses this pattern manually during regression sweeps — promote it to CI.

**Anti-additions for v2.1:** do NOT add a new test framework (matlab.unittest + the custom Octave runner both work). Do NOT add a code-generation library or template engine (string concatenation via `sprintf` in `linesForWidget` is the existing pattern and is trivially testable through the JSON-save → `.m`-save → feval round-trip). Do NOT introduce `matlab.mock` (the dead `detect(tag,threshold)` overload needs deletion, not mocking). Do NOT add Python-side anything (all 4 items are MATLAB-only, no WebBridge touch).

---

## Recommended Stack (unchanged from v2.0)

### Core Language & Runtime
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| MATLAB | R2020b+ (pinned in tests.yml) | Primary target runtime | Existing; CI pins to R2020b to avoid R2025b drift (see Phase 1006-01 decision) |
| GNU Octave | 7+ (Linux 11.x in CI, Windows 9.2.0) | Secondary target runtime | Existing; all examples + function-tests already green on Octave |

### Test Framework (reuse in place — no additions)
| Technology | Purpose | Why it covers v2.1 needs |
|------------|---------|--------------------------|
| `matlab.unittest` (MATLAB only) | Suite tests in `tests/suite/Test*.m` | `TestClassSetup` + `TestMethodSetup` + `TestMethodTeardown` lifecycle + `testCase.verifyXxx` all already used; runner is `matlab.unittest.TestSuite.fromFolder` + `TestRunner.withTextOutput` in `tests/run_all_tests.m` |
| `testCase.assumeTrue(cond, reason)` | Skip-with-reason idiom | Already in production: 43 assume-calls across 17 suite test files (MEX-absent skip, headless-CI skip, Octave-capability skip at `TestDashboardBugFixes.m:269`). This is the answer to "how do we skip MATLAB-only tests" — it's already there. |
| `exist('OCTAVE_VERSION', 'builtin')` guard | Runtime-branch in Octave function tests | 20+ test files already use this pattern to fork behavior |
| Custom Octave subprocess runner (`run_octave_tests` in `tests/run_all_tests.m`) | Isolates break_closure_cycles crashes | Existing; no change needed |
| Fixture factories (`makePhase1009Fixtures.m` + `MockTag.m` in `tests/suite/`) | Shared test data builders | Existing pattern — reuse for Threshold→MonitorTag rewrites |

### Linting & Style (reuse in place)
| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| MISS_HIT | `pip install miss_hit` (latest) | `mh_style`, `mh_lint`, `mh_metric --ci` | Existing; `miss_hit.cfg` already enforces line_length=160, cyc≤85, function_length≤550. No rule changes needed for v2.1 cleanup. |

### MEX & Native Kernels (untouched)
| Item | Status | v2.1 Impact |
|------|--------|-------------|
| All existing MEX kernels (`lttb_core_mex`, `minmax_core_mex`, `compute_violations_mex`, `violation_cull_mex`, `binary_search_mex`, `to_step_function_mex`, `build_store_mex`, `resolve_disk_mex`) | Production | None. v2.1 touches zero C code. |
| `mksqlite` (bundled) | Production | None. |
| SIMD flags (AVX2/NEON) | Production | None. |

### Tag API Surface (reuse — covers all v2.1 needs)
| API | Location | v2.1 usage |
|-----|----------|-----------|
| `SensorTag(key, 'X', x, 'Y', y)` + `updateData(x,y)` | `libs/SensorThreshold/SensorTag.m` | All 4 items; replaces `Sensor(...)` in tests + live demos |
| `StateTag(key, 'X', x, 'Y', states)` + `valueAt(t)` ZOH | `libs/SensorThreshold/StateTag.m` | Optional — demos that need state-dependent thresholds |
| `MonitorTag(key, parent, conditionFn, 'EventStore', store, 'MinDuration', d)` | `libs/SensorThreshold/MonitorTag.m` | Replaces all `Threshold(..).addCondition(...)` uses in tests; covers debounce + hysteresis + streaming `appendData` |
| `CompositeTag(key, mode)` + `addChild(tag)` | `libs/SensorThreshold/CompositeTag.m` | Drop-in for 16 `TestMultiStatusWidget`-style composite tests |
| `TagRegistry.register/get/clear` | `libs/SensorThreshold/TagRegistry.m` | Already used in setup/teardown — `TagRegistry.clear()` is the standard `TestMethodSetup` hook |
| `EventBinding.attach/getEventsForTag/clear` | `libs/EventDetection/EventBinding.m` | Used for many-to-many event↔tag lookups; `EventBinding.clear()` in teardowns |
| `EventStore(filePath)` + `append/getEvents/getEventsForTag/save/numEvents` + `fromFile` | `libs/EventDetection/EventStore.m` | v2.1 live demos persist + reload via this class (already demonstrated in canonical `example_sensor_threshold.m`) |
| `LiveEventPipeline(monitorsMap, dataSourceMap, 'EventFile', f, 'Interval', i)` + `start/stop/runCycle` | `libs/EventDetection/LiveEventPipeline.m` | Already wired to MonitorTag via `MonitorTargets` containers.Map; `processMonitorTag_` enforces Pitfall-Y ordering |
| `MockDataSource` / `MatFileDataSource` / abstract `DataSource.fetchNew()` | `libs/EventDetection/` | Drop-in sources for the rewritten live demos; `MockDataSource` generates realistic violations for pure-synthetic demo |
| `EventViewer.fromFile(path)` | `libs/EventDetection/EventViewer.m` | Used by `example_event_viewer_from_file.m` rewrite — already the canonical API |

### FastSense Integration (reuse)
| API | v2.1 usage |
|-----|-----------|
| `fp.addTag(tag)` — polymorphic dispatch on `tag.getKind()` | Primary render path in rewritten demos |
| `fp.addThreshold(scalarValue, 'Label', 'foo')` | Scalar-only; NOT related to deleted `Threshold` class — this is the FastSense plot-annotation API |
| `fp.ShowEventMarkers = true/false` | Event overlay toggle (Phase 1010 renderEventLayer_) |
| `fp.startLive(mat, updateFcn, 'Interval', s, 'ViewMode', 'follow')` | Live scrolling; used by `example_event_detection_live.m` rewrite |

### Serialization (reuse + ONE extension)
| API | v2.1 usage |
|-----|-----------|
| `DashboardSerializer.save(config, path)` — emits `.m` function | Item 2: add `'tag'` branch to `linesForWidget` — mirrors the `case 'sensor'` branch that already emits `'Tag', TagRegistry.get(''%s'')` |
| `DashboardSerializer.saveJSON(config, path)` | Already handles `source.type='tag'` via `jsondecode`/`jsonencode` on widget structs |
| `DashboardSerializer.linesForWidget(ws, pos, indent)` static helper | Item 2 fix lives here (single choke-point per v1.0 shared-helper decision) |

### CI & Tooling (one recommended addition)
| Technology | Version | Purpose | v2.1 Recommendation |
|------------|---------|---------|---------------------|
| GitHub Actions | existing | CI/CD | No workflow additions |
| MISS_HIT | existing | Style + complexity | No rule additions |
| **NEW: grep regression gate** (bash step in `tests.yml` `lint` job) | n/a (pure shell) | Fail CI on any new reference to deleted classes | **RECOMMENDED** — see "New Tooling" section below |

---

## Alternatives Considered (and rejected)

| Alternative | Rejected because |
|-------------|------------------|
| Add `matlab.mock` for the dead `EventDetector.detect(tag,threshold)` overload | Item 1 is dead code with no callers — deletion beats mocking. Added dependency with zero value. |
| Pull in a template engine (e.g. hand-written in MATLAB, or a codegen library) for `.m` export | `linesForWidget` already works for 15+ widget types via `sprintf`. Adding templates for 1 new case would require refactoring all existing cases for parity. Not worth it. |
| Migrate suite tests to a parametric test framework (e.g. `matlab.unittest.TestParameter`) | The 73 `Threshold(` refs sit across heterogeneous setups — parameterization offers no leverage and would force rewriting passing tests. Pure find-and-replace pattern wins. |
| Adopt `dictionary` (R2022b) in place of `containers.Map` | Pinned MATLAB is R2020b; Octave has no `dictionary`. Would break both runtimes. Already rejected in v2.0 research for same reason. |
| Introduce a dedicated "example runner" test harness (e.g. `pytest`-style discovery) | `test_examples_smoke.m` already exists from Phase 1012 — does exactly this, with skip list for live/interactive scripts. Reuse. |
| Replace `MockDataSource` with a lightweight mocking library | Existing `MockDataSource` is 167 LOC, generates realistic industrial-sensor signals with violation episodes + state transitions. Domain-specific, better than any generic mock lib. |
| Add `datetime`-aware tests specifically for Octave | Octave lacks `datetime` fully; existing test strategy is "function-test + skip-on-Octave" — no new framework needed. |

---

## Per-Item API Coverage Check

**Item 1 — `EventDetector.detect(tag, threshold)` dead code**

Current implementation (`libs/EventDetection/EventDetector.m:39-75`) references `threshold.allValues()`, `threshold.Direction`, `threshold.Name`, `threshold.Key` on a `Threshold` handle — that class was deleted in Phase 1011. Any call path dies with an "undefined class" error. Scan confirms:

- No `libs/` caller uses this 2-arg overload. `LiveEventPipeline.processMonitorTag_` uses `monitor.appendData` + `monitor.EventStore` — not the detector overload.
- `IncrementalEventDetector` and the 6-arg `detect_` private body are live and used.
- `TestEventDetectorTag.m` contains one test (`testTagOverloadDetectsEvents`) that still references `Threshold('warn', ...)` — this test is itself the dead code it exercises.

**Resolution:** delete the 2-arg overload + delete `TestEventDetectorTag.m` tests that depend on it. Keep the legacy 6-arg signature + `TestEventDetector.m` untouched. No stack change.

**Item 2 — DashboardSerializer `.m` export gap for `source.type='tag'`**

- `DashboardSerializer.save` (single-page path at line 38): has `case 'sensor'`, `case 'file'`, `case 'data'` branches for `ws.source.type`. **No `case 'tag'` branch.** → Silent fallthrough to `otherwise` branch which emits `addWidget('fastsense', 'Title', ..., 'Position', ...)` with **no Tag binding**.
- `DashboardSerializer.exportScriptPages` + `exportScript`: both delegate to the static `linesForWidget(ws, pos, indent)` helper (lines 588+). Same gap: `case 'sensor'`, `case 'file'`, `case 'data'` branches present, `case 'tag'` missing.
- **But** the existing `'sensor'` branch at line 602 already emits `'Tag', TagRegistry.get(''%s'')` — meaning v2.0 partially migrated this by reinterpreting `source.type='sensor'` to resolve via `TagRegistry` rather than the deleted `SensorRegistry`. So: fix by adding a parallel `case 'tag'` branch that emits the same code shape, and ensure `FastSenseWidget.toStruct()` populates `source.type = 'tag'` (not `'sensor'`) going forward.
- JSON path works because `jsonencode`/`jsondecode` is schemaless — struct fields round-trip verbatim.

**Resolution:** extend `linesForWidget` with a `case 'tag'` branch. Add a single round-trip test to `TestDashboardSerializerRoundTrip.m` covering a dashboard with a Tag-bound FastSenseWidget → save to `.m` → feval → verify widget has `Tag` property set. No stack change.

**Item 3 — 73 `Threshold(` refs in 16 suite test files**

Verified count (regex `=\s*Threshold\s*\(` in `tests/suite/Test*.m`): **73 occurrences across 16 files** (not 93/42 as the audit states — the audit number included function-tests at `tests/test_*.m`, which are Octave-only and already not affected by this class since `Threshold` is MATLAB-only / deleted).

The 16 MATLAB-suite files fall into 3 rewrite patterns:

- **Pattern A — threshold-attached-to-sensor (most common, ~45 uses):** `thr = Threshold(key, 'Direction', 'upper'); thr.addCondition(struct(), val); sensor.addThreshold(thr);` → rewrite as `MonitorTag(key, parent, @(x,y) y > val, 'EventStore', store)` — directly covered by v2.0 API.
- **Pattern B — standalone threshold for widget binding (~18 uses in `TestStatusWidget`, `TestGaugeWidget`, `TestIconCardWidget`, `TestMultiStatusWidget`):** `thr = Threshold(...); widget.Threshold = thr;` → widget-threshold binding from Phase 1002 was superseded in v2.0 by tag binding. Rewrite as `widget.Tag = MonitorTag(...)` using the already-migrated widget Tag property.
- **Pattern C — composite aggregation (~10 uses):** `CompositeThreshold` / children aggregation → `CompositeTag(mode)` + `addChild` per Phase 1008.

Cross-runtime handling: **no change needed.** MATLAB runs these tests via `matlab.unittest`; Octave never touched them (function-test sidecar under `tests/test_*.m` covers what Octave needs). Some test methods may still be MATLAB-only legitimately (e.g. PostSet listeners — see `TestDashboardBugFixes.m:269` for the existing `testCase.assumeTrue(false, 'Octave lacks PostSet')` idiom). The existing `assumeTrue(false, reason)` pattern is the skip-with-reason mechanism — 43 usages across 17 suite files prove it's the project convention.

**Resolution:** mechanical rewrite pass, file-by-file. No new test framework, no new skip mechanism. Leverage `assumeTrue(false, 'reason')` for any MATLAB-only capability the Tag API surfaces (unlikely given v2.0 Octave parity).

**Item 4 — Live demo rewrites**

API coverage check for `example_event_detection_live.m` + `example_event_viewer_from_file.m`:

| Demo need | v2.0 API |
|-----------|----------|
| Multiple sensors with time series | `SensorTag(key, 'X', x, 'Y', y)` — ✓ ready |
| Threshold rules with per-sensor upper/lower + debounce | `MonitorTag(key, parent, @(x,y) y > v, 'MinDuration', d)` — ✓ ready |
| Persistent event store with atomic write + backups | `EventStore(path, 'MaxBackups', 3)` — ✓ ready (see `example_sensor_threshold.m`) |
| Auto-save on detection | `MonitorTag(..., 'EventStore', store)` auto-emits on rising edges — ✓ ready (MONITOR-05) |
| Live refresh (FastSense `startLive` + `updateData`) | `fp.startLive(matFile, @(fp,d) fp.updateData(1, d.x, d.y), 'Interval', 2, 'ViewMode', 'follow')` — ✓ ready (untouched by v2.0) |
| Event viewer with refresh-from-file | `EventViewer.fromFile(path)` — ✓ ready |
| Mock data source for live pipeline | `MockDataSource` with `BaseValue/NoiseStd/ViolationProbability` — ✓ ready |
| Live pipeline orchestration | `LiveEventPipeline(containers.Map({'k1'}, {monitor1}), dataSourceMap, 'EventFile', path, 'Interval', 15)` — ✓ ready |
| State-dependent thresholds | `StateTag` + closure over `stateTag.valueAt(x)` in `conditionFn` — ✓ ready (see `example_sensor_threshold.m`) |
| Colors per threshold label | `fp.addThreshold(value, 'Color', c, 'Label', s)` + `EventViewer` threshold-color arg — ✓ ready |

**Every demo need maps to an existing v2.0 API.** The canonical migration pattern is already demonstrated in `examples/02-sensors/example_sensor_threshold.m` (SensorTag + StateTag + MonitorTag + EventStore + EventBinding + FastSense overlay) and in `examples/02-sensors/tags/example_tag_monitor.m` (debounce + hysteresis variants). The live demos need to compose these same primitives with `LiveEventPipeline` + `MockDataSource` / `MatFileDataSource`.

No API gap. No missing primitive. No stack change.

**Resolution:** mechanical rewrite as substantive new scripts — drop the `return;` guards, replace the legacy `EventConfig.addSensor` + `cfg.runDetection()` loop with `LiveEventPipeline.runCycle()` driven by `MonitorTargets` containers.Map keyed to `MonitorTag` instances. Validate via `test_examples_smoke.m` (already exists).

---

## New Tooling — Grep Regression Gate (recommended)

**Scope:** ONE tiny addition, no new deps.

**What:** bash step in the `lint` job of `.github/workflows/tests.yml` that fails CI on any newly introduced reference to deleted legacy classes in production code.

**Why:**

- v2.0 Phase 1011 deleted 8 classes (`Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`).
- Phase 1012 Plan 10 ran a manual `grep -rE` audit as part of the regression sweep.
- Item 3 of v2.1 audit exists *specifically because* stray references slipped through. This is a rebound-prevention signal worth automating.
- Phase 1012 Plan 10's grep audit is literally the candidate command — promote from one-time plan action to standing CI gate.

**Proposed step (drop into `tests.yml` `lint` job after `mh_metric`):**

```yaml
      - name: Regression grep — legacy class references
        run: |
          set -e
          # Pattern: constructor invocations + static-method lookups of
          # 8 classes deleted in Phase 1011. EXCLUDE test files that
          # intentionally exercise legacy-migration pathways (currently 0;
          # if needed, use --exclude-dir).
          PATTERN='Threshold\(|CompositeThreshold\(|StateChannel\(|SensorRegistry\.|ThresholdRegistry\.|ExternalSensorRegistry\.'
          # Allow-list: scalar fp.addThreshold in FastSense.m is NOT this
          # class — filter it explicitly.
          HITS=$(grep -rEn "$PATTERN" libs/ tests/ examples/ benchmarks/ \
                 --include='*.m' \
                 | grep -vE 'fp\.addThreshold|obj\.addThreshold|addThreshold\s*\(' \
                 || true)
          if [ -n "$HITS" ]; then
            echo "FAIL: Found references to legacy v1 classes deleted in Phase 1011:"
            echo "$HITS"
            exit 1
          fi
          echo "OK: no legacy-class references."
```

**Note:** `fp.addThreshold(scalarValue, ...)` on `FastSense` is NOT the deleted class — the grep filter explicitly excludes it. The `Sensor(` bare constructor is intentionally NOT matched because `SensorTag(...)` / `SensorRegistry.` false-positives would dominate; the discriminating patterns above are sufficient.

**Integration cost:** 15 lines of YAML + 0 new dependencies + runs in <5 seconds. Adds exactly one CI lane.

---

## Installation

No additional installation. v2.1 uses the same `install()` + existing toolchain.

```bash
# (unchanged from v2.0)
git clone ...
cd FastPlot
matlab -batch "install(); run_all_tests()"
# or Octave:
octave --eval "install(); run_all_tests()"
```

---

## Verification (Context7 + official)

Context7 consultation: **skipped** — no new libraries proposed, so nothing to verify. The only "library" touched is matlab.unittest, which is a first-party MATLAB toolbox shipped with every supported release and already in production use across 97+ test files in this repo (`tests/suite/Test*.m`).

MATLAB `matlab.unittest.TestCase.assumeTrue(cond, diagnostic)` semantics (marks test Incomplete / skipped with a reason) confirmed from in-repo usage at:
- `tests/suite/TestMksqliteEdgeCases.m:23` — MEX-absent skip
- `tests/suite/TestFastSenseWidget.m:149` — headless-display skip
- `tests/suite/TestDashboardBugFixes.m:269` — Octave-capability skip (`testCase.assumeTrue(false, 'Octave lacks PostSet')`)

These are the exact idioms v2.1 should reuse for any MATLAB-only test that can't reasonably be made Octave-green. Source: [MathWorks matlab.unittest.qualifications.Assumable.assumeTrue](https://www.mathworks.com/help/matlab/ref/matlab.unittest.qualifications.assumable.assumetrue.html) (R2020b+).

---

## Sources

- Codebase: `libs/SensorThreshold/` (Tag, SensorTag, StateTag, MonitorTag, CompositeTag, TagRegistry)
- Codebase: `libs/EventDetection/` (EventDetector, EventStore, EventBinding, LiveEventPipeline, MockDataSource, MatFileDataSource, EventViewer)
- Codebase: `libs/Dashboard/DashboardSerializer.m`
- Codebase: `libs/FastSense/FastSense.m` (addTag, addThreshold scalar, startLive)
- Codebase: `tests/run_all_tests.m`, `tests/test_examples_smoke.m`, 97 files under `tests/suite/`
- Codebase: `examples/02-sensors/example_sensor_threshold.m`, `examples/02-sensors/tags/example_tag_*.m` (canonical v2.0 patterns)
- CI: `.github/workflows/tests.yml`, `miss_hit.cfg`
- Audit: `.planning/milestones/v2.0-MILESTONE-AUDIT.md`
- MathWorks: matlab.unittest.qualifications.Assumable reference (R2020b+) — HIGH confidence (in-repo production usage)
