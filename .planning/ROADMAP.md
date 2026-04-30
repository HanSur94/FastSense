# Roadmap: FastSense Advanced Dashboard

## Milestones

- ✅ **v1.0 FastSense Advanced Dashboard** — Phases 1-9 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Engine Code Review Fixes** — Phase 1 (shipped 2026-04-03)
- ✅ **v1.0 Dashboard Performance Optimization** — Phase 1 (shipped 2026-04-04)
- ✅ **v1.0 First-Class Thresholds & Composites** — Phases 1000-1003 (shipped 2026-04-15)
- ✅ **v2.0 Tag-Based Domain Model** — Phases 1004-1012 (shipped 2026-04-17)
- 🚧 **v2.1 Tag-API Tech Debt Cleanup** — Phases 1013-1016 (in progress, started 2026-04-22)

## Phases

### v2.1 Tag-API Tech Debt Cleanup (Phases 1013-1016)

- [ ] **Phase 1013: Dead-code deletion** — Delete EventDetector / IncrementalEventDetector / EventConfig classes and ship the legacy-classes-removed contract test
- [ ] **Phase 1014: DashboardSerializer `.m` export for Tag** — Add `case 'tag'` branches so Tag-bound widgets round-trip through the `.m` export path
- [ ] **Phase 1015: Test suite cleanup** — Delete zombie tests + migrate ~73 `Threshold(` constructor refs across ~16 suite files to the Tag API; harden golden test + skip-list parity
- [ ] **Phase 1016: Examples 05-events rewrite** — Rewrite the two stubbed live-event demos as full `MonitorTag + EventStore + EventBinding` pipelines and seal the milestone with a CI grep gate

<details>
<summary>✅ v1.0 FastSense Advanced Dashboard (Phases 1-9) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Infrastructure Hardening (4/4 plans) — completed 2026-04-01
- [x] Phase 2: Collapsible Sections (2/2 plans) — completed 2026-04-01
- [x] Phase 3: Widget Info Tooltips (3/3 plans) — completed 2026-04-01
- [x] Phase 4: Multi-Page Navigation (3/3 plans) — completed 2026-04-01
- [x] Phase 5: Detachable Widgets (3/3 plans) — completed 2026-04-02
- [x] Phase 6: Serialization & Persistence (2/2 plans) — completed 2026-04-02
- [x] Phase 7: Tech Debt Cleanup (1/1 plan) — completed 2026-04-03
- [x] Phase 8: Widget Improvements (3/3 plans) — completed 2026-04-03
- [x] Phase 9: Threshold Mini-Labels (2/2 plans) — completed 2026-04-03

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 Dashboard Engine Code Review Fixes (Phase 1) — SHIPPED 2026-04-03</summary>

- [x] Phase 1: Dashboard Engine Code Review Fixes (4/4 plans) — completed 2026-04-03

</details>

<details>
<summary>✅ v1.0 Dashboard Performance Optimization (Phase 1) — SHIPPED 2026-04-04</summary>

- [x] Phase 1: Dashboard Performance Optimization (3/3 plans) — completed 2026-04-04

Full details: [milestones/v1.0-ROADMAP.md](milestones/v1.0-ROADMAP.md)

</details>

<details>
<summary>✅ v1.0 First-Class Thresholds & Composites (Phases 1000-1003) — SHIPPED 2026-04-15</summary>

- [x] Phase 1000: Dashboard Engine Performance Optimization Phase 2 (3/3 plans)
- [x] Phase 1001: First-Class Threshold Entities (6/6 plans)
- [x] Phase 1002: Direct Widget-Threshold Binding (2/2 plans)
- [x] Phase 1003: Composite Thresholds (3/3 plans)

</details>

<details>
<summary>✅ v2.0 Tag-Based Domain Model (Phases 1004-1012) — SHIPPED 2026-04-17</summary>

- [x] Phase 1004: Tag Foundation + Golden Test (3/3 plans) — completed 2026-04-16
- [x] Phase 1005: SensorTag + StateTag data carriers (3/3 plans) — completed 2026-04-16
- [x] Phase 1006: MonitorTag lazy in-memory (3/3 plans) — completed 2026-04-16
- [x] Phase 1007: MonitorTag streaming + persistence (3/3 plans) — completed 2026-04-16
- [x] Phase 1008: CompositeTag aggregation (3/3 plans) — completed 2026-04-16
- [x] Phase 1009: Consumer migration — one widget at a time (4/4 plans) — completed 2026-04-17
- [x] Phase 1010: Event ↔ Tag binding + FastSense overlay (3/3 plans) — completed 2026-04-17
- [x] Phase 1011: Cleanup — delete legacy classes (5/5 plans) — completed 2026-04-17
- [x] Phase 1012: Migrate examples to Tag API (10/10 plans) — completed 2026-04-17

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md)

</details>

## Phase Details

> v2.0 phase details (1004–1012) are archived in [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md).

### Phase 1013: Dead-code deletion (EventDetector / IncrementalEventDetector / EventConfig)

**Goal**: User running anything against `EventDetector`, `IncrementalEventDetector`, or `EventConfig` no longer reaches deleted-class references — the three classes are removed entirely from `libs/EventDetection/` and a focused contract test guards against accidental re-introduction.
**Depends on**: None (Tag API + LiveEventPipeline + EventStore + MonitorTag are already the production replacements; v2.0 shipped them in Phases 1006–1010)
**Requirements**: DEAD-01, DEAD-02, DEAD-03, DEAD-04, DEAD-05, DEAD-06, DIFF-03
**Success Criteria** (what must be TRUE):
  1. User running existing live pipelines (`LiveEventPipeline + MonitorTag + EventStore`) sees no behavioral change — every shipped example and end-to-end test still ticks events through the same observable surface (DEAD-05)
  2. User browsing `libs/EventDetection/` no longer sees `EventDetector.m`, `IncrementalEventDetector.m`, or `EventConfig.m` — the three files are gone (DEAD-01..03)
  3. `install.m` runs clean with no path entries pointing at deleted files; a fresh clone + `install()` + `run_all_tests.m` is green on MATLAB R2020b CI (DEAD-06)
  4. Repo-wide grep for `\b(EventDetector|IncrementalEventDetector|EventConfig)\b` across `libs/`, `examples/`, and `benchmarks/` returns zero hits in production code (DEAD-04)
  5. New `tests/suite/TestLegacyClassesRemoved.m` runs green and asserts `exist('EventDetector','class') == 0` plus the same for `IncrementalEventDetector`, `EventConfig`, and the 8 Phase-1011 deleted classes (DIFF-03)
**Verification gates** (from PITFALLS.md — 6-gate exit pattern):
  - **Gate A — scope (Pitfall 1):** `git diff --name-only` ⊆ PLAN `affected_files`; net-line budget declared and respected (target: ≈-300 to -500 net LOC)
  - **Gate C — dead-code grep (Pitfalls 2 & 16):** `grep -rE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ examples/ benchmarks/` → 0 hits in production code; `install.m` references no deleted file path
  - **Gate D — Octave smoke (Pitfalls 10, 12):** `tests/test_examples_smoke.m` passes; `timerfindall()` empty between examples
  - **Gate E — MATLAB CI (Pitfalls 4, 7):** `tests/run_all_tests.m` green on MATLAB R2020b with documented test-count baseline (deleted-test count from any same-commit test deletions explicitly logged)
  - **Gate B (Pitfall 3) and Gate F (Pitfall 18):** N/A this phase — golden test untouched is implied; skip-list parity not yet in scope (Phase 1015 owns DIFF-04)
**Plans**: 1 plan

Plans:
- [ ] 1013-01-PLAN.md — Delete EventDetector.m / IncrementalEventDetector.m / EventConfig.m; repair 4 cross-file refs (LiveEventPipeline, eventLogger, MonitorTag, install); ship TestLegacyClassesRemoved.m contract test (DEAD-01..06 + DIFF-03)

**UI hint**: no

### Phase 1014: DashboardSerializer `.m` export for Tag-bound widgets

**Goal**: User saving a Tag-bound dashboard via `DashboardSerializer.save(d, 'out.m')` or `exportScriptPages(d, 'out.m')` gets a `.m` script that round-trips the Tag binding via `TagRegistry.get('key')` lookups — no silent omission, with a clear error if the user forgets to register the tag before running.
**Depends on**: None (orthogonal to Phase 1013; relies only on `TagRegistry.get` and `linesForWidget` switch shapes that already ship in v2.0)
**Requirements**: MEXP-01, MEXP-02, MEXP-03, MEXP-04, MEXP-05
**Success Criteria** (what must be TRUE):
  1. User saves a single-page dashboard containing a Tag-bound `FastSenseWidget` via `DashboardSerializer.save(d, 'out.m')`, runs `feval('out')` in a fresh session with the tag pre-registered, and observes the reloaded widget's `Tag` property populated with the correct registry handle (MEXP-01, MEXP-04)
  2. User saves a multi-page dashboard via `DashboardSerializer.exportScriptPages(d, 'out.m')` and Tag-bound widgets on every page emit `TagRegistry.get('key')` lookups in the generated script (MEXP-02)
  3. User runs the generated `.m` script without first registering the required tag and observes a clear `TagRegistry:unknownKey`-style error from the guarded lookup pattern `if ~TagRegistry.has('key'); error(...); end; TagRegistry.get('key')` — never a silent broken widget (MEXP-03)
  4. User inspects the generated `.m` script for a v2.0 in-memory dashboard and finds no legacy `case 'sensor'` emitter output — only `'tag'` branches are written; the `fromStruct` reader retains its `'sensor'` branch for legacy JSON backward compatibility (MEXP-05)
  5. `tests/suite/TestDashboardSerializerTagExport.m` exists, exercises both single-page and multi-page round-trips for Tag-bound widgets, and is green on MATLAB R2020b CI (MEXP-04)
**Verification gates** (from PITFALLS.md — 6-gate exit pattern):
  - **Gate A — scope (Pitfall 1):** `git diff --name-only` ⊆ PLAN `affected_files`; net-line budget ≈+40 to +80 (Pitfall 1 file-touch budget — typical surface is `DashboardSerializer.m` + new test file)
  - **Gate B — golden test untouched (Pitfall 3):** `git diff -- tests/**/*olden*` → 0 lines across the phase
  - **Gate C — dead-code grep (Pitfall 9):** generated `.m` scripts emit zero `case 'sensor'` artifacts for Tag-bound widgets; legacy emitter branch fully removed (MEXP-05)
  - **Gate D — Octave smoke (Pitfalls 10, 12):** `tests/test_examples_smoke.m` passes
  - **Gate E — MATLAB CI:** `run_all_tests.m` green; new round-trip test (MEXP-04) added without regressing any sibling DashboardSerializer test
**Plans**: 1 plan
**UI hint**: no

### Phase 1015: Test suite cleanup (delete zombies + migrate Threshold( refs to Tag API)

**Goal**: User running `tests/run_all_tests.m` on MATLAB R2020b sees a green suite with zero `Threshold(`-family constructor references in the codebase — every zombie test for deleted classes is gone, every still-live widget test is migrated to the Tag API, and the golden test + skip-list parity are now structurally enforced rather than comment-policed.
**Depends on**: Phase 1013 (TEST-05 deletes `TestEventDetectorTag.m`, which only makes sense once the `EventDetector` class is gone in DEAD-01)
**Requirements**: TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-06, TEST-07, TEST-08, TEST-09, TEST-10, TEST-11, TEST-12, DIFF-02, DIFF-04
**Success Criteria** (what must be TRUE):
  1. User browsing `tests/suite/` no longer sees `TestEventConfig.m`, `TestIncrementalDetector.m`, `TestEventDetector.m`, `TestEventDetectorTag.m`, or `TestCompositeThreshold.m` (if it existed) — the 5 zombie suites are deleted (TEST-01..05)
  2. User running widget tests (`TestStatusWidget`, `TestGaugeWidget`, `TestIconCardWidget`, `TestMultiStatusWidget`, `TestChipBarWidget`, plus stray refs in `TestEventStore`, `TestLivePipeline`, `TestSensorDetailPlot`, `TestDashboardEngine`, `TestFastSenseWidget`, `TestLiveEventPipelineTag`, `TestIconCardWidgetTag`, `TestMultiStatusWidgetTag`) sees them green on MATLAB R2020b — every `Threshold(` constructor in those files now uses `MonitorTag` + `makePhase1009Fixtures`/`makeV21Fixtures.makeThresholdMonitor` instead (TEST-06..09)
  3. Repo-wide grep `(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(` against `tests/` returns zero hits — `fp.addThreshold(...)` (the surviving FastSense plot-annotation API) is explicitly excluded by the regex (TEST-10)
  4. User opening `tests/suite/TestGoldenIntegration.m` or `tests/test_golden_integration.m` sees a `% DO NOT REWRITE — golden test, see PROJECT.md` banner at the top of the file; `git diff` over both files across Phase 1015 is byte-empty (TEST-12, DIFF-02)
  5. `scripts/check_skip_list_parity.sh` exists, is callable from CI, and exits non-zero if `tests/test_examples_smoke.m` and `examples/run_all_examples.m` skip-list blocks ever drift apart (DIFF-04)
  6. `tests/run_all_tests.m` test-count baseline drop from the deleted suites (TEST-01..05) is documented in the phase summary; no surviving regression (TEST-11)
**Verification gates** (from PITFALLS.md — 6-gate exit pattern):
  - **Gate A — scope (Pitfall 1):** `git diff --name-only` ⊆ PLAN `affected_files`; per-file commit discipline for the migration bucket (Pitfall 4 — no commit touches > 3 test files unless it's pure deletion); net-line budget ≈-500 to -1500
  - **Gate B — golden untouched (Pitfall 3):** `git diff HEAD~..HEAD -- tests/**/*olden*` → 0 lines across every commit in the phase; banner addition (DIFF-02) is the ONLY exception, fired by a single commit explicitly listed in `affected_files`
  - **Gate C — dead-code/legacy grep (Pitfall 4):** post-migration `grep -rE '(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(' tests/` → 0 non-surviving-API hits
  - **Gate D — Octave smoke (Pitfalls 10, 12):** `tests/test_examples_smoke.m` passes; `timerfindall()` empty between examples
  - **Gate E — MATLAB CI (Pitfalls 4, 7):** `run_all_tests.m` green on MATLAB R2020b with documented test-count baseline drop (TEST-11)
  - **Gate F — skip-list parity (Pitfall 18):** `scripts/check_skip_list_parity.sh` returns 0 against `tests/test_examples_smoke.m` and `examples/run_all_examples.m`; CI lane wires the script (DIFF-04)
**Plans**: 3 plans

Plans:
- [x] 1015-01-PLAN.md — Zombie deletion + golden banner + makeV21Fixtures helper + skip-list parity script + CI wire (TEST-01..05, TEST-09, TEST-12, DIFF-02, DIFF-04)
- [x] 1015-02-PLAN.md — Threshold→MonitorTag migration in 5 still-live sidecar tests, per-file commits (TEST-06..08, TEST-10)
- [x] 1015-03-PLAN.md — 6-gate exit verification + test-count baseline drop documentation in 1015-SUMMARY.md (TEST-11)

**UI hint**: no

### Phase 1016: Examples 05-events rewrite (live demos + CI grep seal)

**Goal**: User running `examples/05-events/example_event_detection_live.m` and `example_event_viewer_from_file.m` sees full `SensorTag + MonitorTag + EventStore + LiveEventPipeline + EventBinding` pipelines (no deprecation stubs, no `EventConfig` references), and CI fails on any future re-introduction of the 8 Phase-1011 deleted classes via a grep gate baked into `.github/workflows/tests.yml`.
**Depends on**: None within v2.1 (independent of 1013/1014/1015 — every replacement API ships in v2.0; placement at the end of the milestone is so the CI grep gate seals the cumulative cleanup)
**Requirements**: DEMO-01, DEMO-02, DEMO-03, DEMO-04, DEMO-05, DEMO-06, DEMO-07, DEMO-08, DEMO-09, DIFF-01
**Success Criteria** (what must be TRUE):
  1. User runs `examples/05-events/example_event_detection_live.m` and observes a 3-sensor live demo using `SensorTag + MonitorTag + EventStore + LiveEventPipeline + DashboardEngine` with the timer bounded to `TasksToExecute=5` and an `onCleanup` cleanup wrapper; the demo also wires `NotificationService(DryRun=true)` for event → notification pedagogical parity with `example_live_pipeline.m` (DEMO-01, DEMO-02)
  2. User runs `examples/05-events/example_event_viewer_from_file.m` and observes a batch-build → `EventStore.save` → `EventViewer.fromFile` → click-to-plot detail flow with no live timer (DEMO-03)
  3. User opens `examples/05-events/example_live_pipeline.m` and finds no orphan comment blocks; the `monitors` map is rebuilt with `MonitorTag` values (not `SensorTag`) so `pipeline.runCycle()` actually fires events (DEMO-04)
  4. All three `examples/05-events/*.m` scripts call `TagRegistry.clear(); EventBinding.clear();` at the top, use only Octave-portable APIs (no `datetime`/`table`/`categorical`/`duration`), and each file header documents its distinct pedagogical purpose with no duplication of `example_sensor_threshold.m` (DEMO-05, DEMO-06, DEMO-07)
  5. `tests/test_examples_smoke.m` and `examples/run_all_examples.m` skip lists have byte-identical entries for the 3 demos; no rewritten demo holds `persistent` variables or unbounded MATLAB timers (DEMO-08, DEMO-09)
  6. `.github/workflows/tests.yml` `lint` job fails CI on any new reference to the 8 classes deleted in Phase 1011 (`Threshold`, `CompositeThreshold`, `StateChannel`, `ThresholdRule`, `Sensor`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`) within `libs/`, `tests/`, `examples/`, `benchmarks/`; `fp.addThreshold(` and `obj.addThreshold(` surviving API are explicitly allow-listed (DIFF-01)
**Verification gates** (from PITFALLS.md — 6-gate exit pattern):
  - **Gate A — scope (Pitfall 1):** `git diff --name-only` ⊆ PLAN `affected_files`; net-line budget ≈+300 to +450 across the three demos plus ≈15 lines of YAML for the CI gate
  - **Gate B — golden untouched (Pitfall 3):** `git diff -- tests/**/*olden*` → 0 lines across the phase
  - **Gate C — dead-code grep (Pitfalls 2, 16, 11):** the new CI grep gate (DIFF-01) is itself the canonical Gate C for the milestone close — running it locally over the v2.1 tip returns 0 hits; rewritten demos contain zero references to `EventConfig`, `EventDetector`, `IncrementalEventDetector`, or any of the 8 Phase-1011 classes
  - **Gate D — Octave smoke (Pitfalls 10, 12):** `tests/test_examples_smoke.m` passes with the 3 demos either still skip-listed (initial commit) or executed (post-rewrite); `timerfindall()` empty between examples (DEMO-09); no `datetime`/`table`/`categorical`/`duration` in rewritten demos (DEMO-06)
  - **Gate E — MATLAB CI:** `run_all_tests.m` green on MATLAB R2020b; `examples.yml` matrix runs the rewritten demos green on the curated Octave widget list
  - **Gate F — skip-list parity (Pitfall 18):** `scripts/check_skip_list_parity.sh` (added in Phase 1015 via DIFF-04) returns 0 over the rewritten demos' skip-list state (DEMO-08)
**Plans**: 3 plans

Plans:
- [x] 1016-01-PLAN.md — Rewrite example_event_detection_live.m + example_event_viewer_from_file.m as full Tag-API demos with bounded timer + NotificationService(DryRun=true) + EventViewer.fromFile (DEMO-01..03, DEMO-05..07, DEMO-09)
- [x] 1016-02-PLAN.md — Rebuild example_live_pipeline.m monitors map with MonitorTag values + add SKIP_LIST_BEGIN/END block to examples/run_all_examples.m (DEMO-04..09)
- [x] 1016-03-PLAN.md — Add Phase-1011 deleted-class regression grep seal to .github/workflows/tests.yml lint job (DIFF-01)

**UI hint**: no

## Progress

| Phase | Milestone | Plans Complete | Status | Completed |
|-------|-----------|----------------|--------|-----------|
| 1-9 | v1.0 Advanced Dashboard | 24/24 | Complete | 2026-04-03 |
| 01. Code Review Fixes | v1.0 Code Review | 4/4 | Complete | 2026-04-03 |
| 01. Performance Optimization | v1.0 Performance | 3/3 | Complete | 2026-04-04 |
| 1000-1003 | v1.0 First-Class Thresholds | 14/14 | Complete | 2026-04-15 |
| 1004. Tag Foundation + Golden Test | v2.0 | 3/3 | Complete    | 2026-04-16 |
| 1005. SensorTag + StateTag | v2.0 | 3/3 | Complete    | 2026-04-16 |
| 1006. MonitorTag (lazy, in-memory) | v2.0 | 3/3 | Complete    | 2026-04-16 |
| 1007. MonitorTag streaming + persistence | v2.0 | 3/3 | Complete    | 2026-04-16 |
| 1008. CompositeTag | v2.0 | 3/3 | Complete    | 2026-04-16 |
| 1009. Consumer migration | v2.0 | 4/4 | Complete    | 2026-04-17 |
| 1010. Event ↔ Tag binding + overlay | v2.0 | 3/3 | Complete    | 2026-04-17 |
| 1011. Cleanup + delete legacy | v2.0 | 5/5 | Complete    | 2026-04-17 |
| 1012. Migrate examples to Tag API | v2.0 | 10/10 | Complete | 2026-04-17 |
| 1013. Dead-code deletion | v2.1 | 0/1 | Not started | - |
| 1014. DashboardSerializer .m export Tag | v2.1 | 0/1 | Not started | - |
| 1015. Test suite cleanup | v2.1 | 4/3 | Complete    | 2026-04-30 |
| 1016. Examples 05-events rewrite | v2.1 | 4/3 | Complete   | 2026-04-30 |

## Backlog

### Phase 999.1: Mushroom Cards for Dashboard Engine (BACKLOG)

**Goal:** Add Home Assistant-style Mushroom Card widgets to the dashboard engine — minimal, icon-driven cards with clean visual design for sensor status, controls, and quick glance data. Three new widget classes: IconCardWidget, ChipBarWidget, SparklineCardWidget, plus theme additions and full serializer/builder/detach integration.
**Requirements:** [MUSH-01: DashboardTheme InfoColor, MUSH-02: IconCardWidget, MUSH-03: ChipBarWidget, MUSH-04: SparklineCardWidget, MUSH-05: DashboardEngine type registration, MUSH-06: DashboardSerializer integration, MUSH-07: DetachedMirror + DashboardBuilder integration]
**Plans:** 4/3 plans complete

Plans:
- [ ] 999.1-01-PLAN.md — DashboardTheme InfoColor + IconCardWidget implementation
- [ ] 999.1-02-PLAN.md — ChipBarWidget implementation
- [ ] 999.1-03-PLAN.md — SparklineCardWidget implementation
- [x] 999.1-04-PLAN.md — Infrastructure wiring (Engine, Serializer, DetachedMirror, Builder)

### Phase 999.3: Graph Data Export (.mat / .csv) (BACKLOG)

**Goal:** Enable exporting any graph's underlying data as .mat or .csv files, so users can easily extract plotted data for further analysis in MATLAB or external tools.
**Requirements:** [EXPORT-01: CSV export with time + Y columns, EXPORT-02: MAT export with lines + thresholds structs, EXPORT-03: NaN-filled union for mismatched X arrays, EXPORT-04: Datetime ISO 8601 + datenum columns, EXPORT-05: Toolbar Export Data button, EXPORT-06: Empty plot error guard]
**Plans:** 2/2 plans complete

Plans:
- [x] 999.3-01-PLAN.md — Core exportData method + private helpers + tests
- [x] 999.3-02-PLAN.md — Toolbar button, icon, callbacks + test updates

### Phase 1000: Dashboard Engine Performance Optimization Phase 2

**Goal:** Fix 6 identified performance bottlenecks in DashboardEngine: (1) FastSenseWidget.refresh() full teardown → incremental update reusing axes/FastSense, (2) broadcastTimeRange synchronous slider → debounced/coalesced updates, (3) All-page panel creation at startup → lazy page realization on first switchPage(), (4) getTimeRange full-array scan per widget per tick → cached min/max with incremental update, (5) switchPage synchronous realize → batched with drawnow, (6) Resize marks all dirty → debounced resize without dirty marking. Goal: 10-50x faster live ticks, 2-5x faster startup, smooth slider interactivity.
**Requirements**: [PERF2-01: Incremental FastSenseWidget refresh, PERF2-02: Debounced time slider broadcast, PERF2-03: Lazy page panel realization, PERF2-04: Cached widget time ranges, PERF2-05: Batched switchPage realize, PERF2-06: Debounced resize without dirty]
**Depends on:** None
**Plans:** 3/3 plans complete

Plans:
- [x] 1000-01-PLAN.md — Incremental FastSenseWidget refresh + cached time ranges
- [x] 1000-02-PLAN.md — Debounced slider broadcast + resize without dirty marking
- [x] 1000-03-PLAN.md — Lazy page panel realization + batched switchPage realize

### Phase 1001: First-Class Threshold Entities

**Goal:** Make thresholds independent, reusable entities with ThresholdRegistry and shared-reference semantics (TrendMiner-style). Breaking change: replace ThresholdRules/addThresholdRule with Threshold handle class + addThreshold across all libraries.
**Requirements**: [THR-01: Threshold handle class, THR-02: ThresholdRegistry singleton, THR-03: Sensor integration (addThreshold/removeThreshold), THR-04: Resolve adaptation, THR-05: Downstream consumer migration, THR-06: Test migration]
**Depends on:** Phase 1000
**Plans:** 6/6 plans complete

Plans:
- [x] 1001-01-PLAN.md — Threshold handle class + ThresholdRegistry singleton + tests
- [x] 1001-02-PLAN.md — Sensor.m refactor (Thresholds property, addThreshold, resolve adaptation) + sensor test migration
- [x] 1001-03-PLAN.md — Dashboard widgets, SensorRegistry display, loadModuleMetadata migration + widget tests
- [x] 1001-04-PLAN.md — EventDetection migration (IncrementalEventDetector, LiveEventPipeline, EventViewer) + EventDetection tests
- [x] 1001-05-PLAN.md — Gap closure: migrate 10 core sensor + consumer widget test files from addThresholdRule
- [x] 1001-06-PLAN.md — Gap closure: migrate 5 EventDetection test files from addThresholdRule

### Phase 1002: Direct Widget-Threshold Binding — StatusWidget, GaugeWidget, and other widgets can reference Threshold objects directly without requiring a Sensor. Enables standalone threshold-driven status indicators.

**Goal:** Add Threshold + Value/ValueFcn properties to StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget, and ChipBarWidget so they can display threshold-driven status without requiring a Sensor object. Purely additive — existing Sensor-bound behavior unchanged.
**Requirements**: [THRBIND-01: StatusWidget + GaugeWidget threshold binding, THRBIND-02: IconCardWidget + MultiStatusWidget + ChipBarWidget threshold binding, THRBIND-03: Serialization round-trip for threshold-bound widgets, THRBIND-04: Backward compatibility, THRBIND-05: ValueFcn live tick support]
**Depends on:** Phase 1001
**Plans:** 2/2 plans complete

Plans:
- [x] 1002-01-PLAN.md — StatusWidget + GaugeWidget threshold binding + serialization + tests
- [x] 1002-02-PLAN.md — IconCardWidget + MultiStatusWidget + ChipBarWidget threshold binding + serialization + tests

### Phase 1003: Composite Thresholds — CompositeThreshold class that aggregates child Threshold objects for hierarchical status. Component A is green only if children A.A and A.B are both green. Enables system health trees and nested status monitoring.

**Goal:** Create CompositeThreshold class that aggregates child Threshold objects with AND/OR/MAJORITY logic for hierarchical system health monitoring. Wire into all dashboard widgets (StatusWidget, GaugeWidget, IconCardWidget, MultiStatusWidget) with isa-guards and auto-expansion. Add serialization for save/load persistence.
**Requirements**: [COMP-01: CompositeThreshold inherits Threshold, COMP-02: AND/OR/MAJORITY aggregation, COMP-03: Nested composites, COMP-04: computeStatus method, COMP-05: addChild dual-input, COMP-06: Per-child ValueFcn/Value, COMP-07: Shared handle references, COMP-08: MultiStatusWidget expansion, COMP-09: ThresholdRegistry + serialization]
**Depends on:** Phase 1002
**Plans:** 3/3 plans complete

Plans:
- [x] 1003-01-PLAN.md — CompositeThreshold class + TDD test suite (AND/OR/MAJORITY, addChild, computeStatus, nesting)
- [x] 1003-02-PLAN.md — Widget isa-guards (StatusWidget, GaugeWidget, IconCardWidget) + MultiStatusWidget composite expansion
- [x] 1003-03-PLAN.md — CompositeThreshold toStruct/fromStruct serialization + round-trip tests

### Phase 1004: Dashboard Image Export Button

**Goal:** Add an image export button to the dashboard toolbar that captures the entire dashboard layout as a single image (PNG/JPEG), enabling users to share or document their dashboard state with one click.
**Requirements**: [IMG-01: Image button present (label/tooltip/order), IMG-02: PNG export via Engine.exportImage, IMG-03: JPEG export via Engine.exportImage, IMG-04: Filename sanitization regex, IMG-05: Unknown format error ID, IMG-06: Write-failure error ID, IMG-07: uiputfile cancel no-op, IMG-08: Multi-page active-page capture, IMG-09: Live mode no-pause]
**Depends on:** Phase 1003
**Plans:** 3/3 plans complete

Plans:
- [x] 1004-01-PLAN.md — DashboardEngine.exportImage delegate + RED/GREEN test scaffold (IMG-02..IMG-06)
- [x] 1004-02-PLAN.md — DashboardToolbar Image button + onImage/dispatch/defaultFilename (IMG-01, IMG-07)
- [x] 1004-03-PLAN.md — MATLAB suite extension + Octave parallel tests (IMG-01, IMG-07, IMG-08, IMG-09)

### Phase 1005: Expand CI coverage: MATLAB + Octave tests on macOS and Windows, MATLAB benchmark

**Goal:** Expand CI test coverage so the actual test suites (not just MEX build) run on macOS and Windows for both MATLAB and Octave, and run the performance benchmark under MATLAB too. Today Linux has full coverage; macOS/Windows only verify MEX compiles via `mex-build-macos` / `mex-build-windows`. This phase closes that gap.
**Requirements**: [COV-01: MATLAB tests on macOS ARM64, COV-02: MATLAB tests on Windows, COV-03: Octave tests on macOS ARM64, COV-04: Octave tests on Windows, COV-05: MATLAB benchmark job, COV-06: Reusable workflow extraction (conditional)]
**Depends on:** Phase 1004 (complete) + quick tasks 260416-j6e / jfo / jnp / k23 (all complete — provide the DRY'd reusable-workflow foundation and Octave 11.1.0 base)
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd:plan-phase 1005 to break down)

### Phase 1006: Fix 137 MATLAB test failures surfaced by MATLAB-on-every-push CI enablement (7 categories from R2025b drift)

**Goal:** Fix the 137 MATLAB test failures surfaced when quick task 260416-j6e enabled MATLAB tests on every push/PR and removed `continue-on-error: true`. Pre-existing failures, now honest CI signal. Root-cause categorization in [.planning/debug/matlab-tests-failures-investigation.md](.planning/debug/matlab-tests-failures-investigation.md): 6 test-level categories + 1 infrastructure decision. Fixing A + B + F alone recovers ~95 tests (62%); A+B+C+D+E = ~92%.
**Requirements**: [MATLABFIX-A: mksqlite.mexa64 availability (~50 tests), MATLABFIX-B: testCase.TestData → properties migration (~41 tests), MATLABFIX-C: test-friend private access for 4 methods (~12 tests), MATLABFIX-D: R2025b API changes — table/OnOffSwitchState/jsondecode/fread (~18 tests), MATLABFIX-E: stale test expectations — KpiWidget/kpi-type rename/warning IDs/etc. (~21 tests), MATLABFIX-F: headless image export CI (4 tests), MATLABFIX-G: MATLAB version pinning policy (infrastructure decision — may reshape B/C/D)]
**Depends on:** Phase 1004 (complete) + quick tasks 260416-j6e / jfo / jnp / k23 (all complete — provide the CI foundation that surfaced these failures) + debug session `octave-cleanup-crash-investigation.md` (unrelated, already resolved) + debug session `matlab-tests-failures-investigation.md` (source of this phase's scope). **NOT** dependent on Phase 1005 (parallel work).
**Plans:** 4/4 plans executed

Plans:
- [x] 1006-01-PLAN.md — Pin MATLAB CI to R2020b in tests.yml + examples.yml (MATLABFIX-G; wave 1; reshapes scope of A/E/F)
- [x] 1006-02-PLAN.md — mksqlite diagnostic-first + fix branch (A/B/C) for TestMksqliteEdgeCases + TestMksqliteTypes (MATLABFIX-A; wave 2)
- [x] 1006-03-PLAN.md — Stale test expectations E1-E9 cluster + E10 grid-snap diagnostic+fix (MATLABFIX-E; wave 2)
- [x] 1006-04-PLAN.md — DashboardEngine.exportImage → exportgraphics() for headless MATLAB CI (MATLABFIX-F; wave 2)

### Phase 1012: Migrate examples to Tag API

**Goal:** Migrate all `examples/` scripts to the v2.0 Tag API. Replace remaining legacy API references (constructors swept by Phase 1011 bulk text-replace; this phase closes residual `.ResolvedViolations` / `.countViolations` / `.X = ...` / `.Y = ...` / `.addData(...)` / `cfg.addSensor` / orphan-comment hazards) with the v2.0 `SensorTag` / `StateTag` / `MonitorTag` / `CompositeTag` / `TagRegistry` / `EventBinding` API. Rewrite `example_sensor_threshold.m` as the canonical end-to-end event-binding demo. Add a 5-script Tag-primitive showcase under `examples/02-sensors/tags/`. Wire a per-folder smoke test into `tests/run_all_tests.m` and rewrite `run_all_examples.m` as a recursive auto-mode walker. Each example folder commits independently per the Phase 1009 "per-widget commit" precedent.
**Requirements**: [] (structural consumer-migration phase; mirrors Phase 1009 — owns no exclusive REQ-IDs; all 45 v2.0 REQs already marked [x] after Phase 1011)
**Depends on:** Phase 1011 (Cleanup — delete legacy)
**Plans:** 10/10 plans complete

Plans:
- [x] 1012-01-PLAN.md — Smoke-test harness (tests/test_examples_smoke.m) + run_all_examples.m recursive rewrite (Wave 1, infra)
- [x] 1012-02-PLAN.md — Migrate examples/01-basics (18 files, audit-pass) (Wave 2)
- [x] 1012-03-PLAN.md — Migrate examples/02-sensors (11 existing files) + create 5 Tag-primitive showcases under examples/02-sensors/tags/ (Wave 2)
- [x] 1012-04-PLAN.md — Rewrite example_sensor_threshold.m as canonical end-to-end event-binding demo (Wave 2, dedicated plan)
- [x] 1012-05-PLAN.md — Migrate examples/03-dashboard (9 files; 2 alarm-log loop rebuilds) (Wave 2)
- [x] 1012-06-PLAN.md — Migrate examples/04-widgets (19 files; 5 read-only X/Y hazard fixes) (Wave 2)
- [x] 1012-07-PLAN.md — Rewrite examples/05-events (3 files; eliminate dead EventConfig.addSensor; wire LiveEventPipeline.MonitorTargets) (Wave 2)
- [x] 1012-08-PLAN.md — Migrate examples/06-webbridge/example_webbridge.m (.addData → updateData append) (Wave 2)
- [x] 1012-09-PLAN.md — Migrate examples/07-advanced (3 files, audit-pass) (Wave 2)
- [x] 1012-10-PLAN.md — Regression grep gates + smoke full sweep + phase exit (Wave 3)
