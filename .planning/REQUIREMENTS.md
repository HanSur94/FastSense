# Requirements: FastSense Advanced Dashboard — v2.1 Tag-API Tech Debt Cleanup

**Defined:** 2026-04-22
**Core Value:** Users can organize complex dashboards into navigable sections and pop out any widget for detailed analysis without losing the dashboard context.

**Milestone goal:** Close the 4 non-blocking tech debt items surfaced by the v2.0 milestone audit so the Tag-API codebase is free of dead code, test-skip gaps, and stubbed example demos.

## Milestone v2.1 Requirements

Categories derived from research scope (4 audit items + cross-cutting differentiators).

### Dead Code Removal

- [ ] **DEAD-01**: User running `EventDetector.detect(tag, threshold)` no longer reaches deleted-class references — the class is removed entirely from `libs/EventDetection/`
- [ ] **DEAD-02**: `IncrementalEventDetector.m` is removed entirely (currently a hard-error stub for `process()`; full delete preferred per user decision)
- [ ] **DEAD-03**: `EventConfig.m` is removed entirely (currently a hard-error stub for `addSensor`; gutted `runDetection`/`escalateEvents`; no production callers)
- [ ] **DEAD-04**: After deletion, `grep -rE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ examples/ benchmarks/` returns zero hits in production code
- [ ] **DEAD-05**: User running existing live pipeline (`LiveEventPipeline + MonitorTag + EventStore`) sees no behavioral change — the deletion is non-disruptive
- [ ] **DEAD-06**: `install.m` no longer references any deleted file path

### Dashboard Serializer .m Export

- [ ] **MEXP-01**: User saves a dashboard containing a Tag-bound widget via `DashboardSerializer.save(d, 'out.m')` and the resulting `.m` file emits a `TagRegistry.get('key')` lookup for that widget (no silent omission)
- [ ] **MEXP-02**: User saves a multi-page dashboard via `DashboardSerializer.exportScriptPages(d, 'out.m')` and Tag-bound widgets on every page emit `TagRegistry.get('key')` lookups
- [ ] **MEXP-03**: Generated `.m` file includes a guarded lookup pattern `if ~TagRegistry.has('key'); error(...); end; TagRegistry.get('key')` so a clear error fires if the user forgets to register the tag before running the script
- [ ] **MEXP-04**: User runs `DashboardSerializer.save → load` round-trip on a Tag-bound dashboard and the reloaded widget has its `Tag` property populated with the correct handle (verified by new `TestDashboardSerializerTagExport.m` suite test)
- [ ] **MEXP-05**: Legacy `case 'sensor'` emitter branch is removed from `linesForWidget` and `save()` switches (no in-memory widget emits `source.type='sensor'` post-v2.0); `fromStruct` reader retains `'sensor'` branch for legacy JSON backward compatibility

### Test Suite Cleanup

- [x] **TEST-01**: `tests/suite/TestEventConfig.m` is deleted (tests deleted `EventConfig.addSensor` pipeline)
- [x] **TEST-02**: `tests/suite/TestIncrementalDetector.m` is deleted (tests deleted `IncrementalEventDetector.process`)
- [x] **TEST-03**: `tests/suite/TestEventDetector.m` is deleted (tests non-existent 6-arg `detect` signature)
- [x] **TEST-04**: `tests/suite/TestCompositeThreshold.m` is deleted if it exists (tests deleted `CompositeThreshold` class)
- [x] **TEST-05**: `tests/suite/TestEventDetectorTag.m` is deleted (test subject — `EventDetector` class — is removed in DEAD-01)
- [ ] **TEST-06**: Widget tests with `Threshold(` constructor refs (`TestStatusWidget`, `TestGaugeWidget`, `TestIconCardWidget`, `TestMultiStatusWidget`, `TestChipBarWidget`) migrate to `MonitorTag` + `makePhase1009Fixtures` — per-file commit for bisect discipline
- [ ] **TEST-07**: `TestEventStore.m`, `TestLivePipeline.m`, `TestSensorDetailPlot.m`, `TestDashboardEngine.m`, `TestFastSenseWidget.m` migrate stray `Threshold(` constructor refs to Tag API equivalents
- [ ] **TEST-08**: New-API tests with stray refs (`TestLiveEventPipelineTag.m`, `TestIconCardWidgetTag.m`, `TestMultiStatusWidgetTag.m`) have stray `Threshold(` refs replaced with `MonitorTag` fixtures
- [x] **TEST-09**: `tests/suite/makePhase1009Fixtures.m` (or extension `makeV21Fixtures.m`) gains a `makeThresholdMonitor(parentSensor, threshold, direction, label)` helper used by all migrated widget tests
- [ ] **TEST-10**: After cleanup, `grep -rE '(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(' tests/` returns zero hits — `fp.addThreshold(...)` (surviving FastSense plot-annotation API) explicitly excluded
- [ ] **TEST-11**: MATLAB R2020b CI passes after cleanup with documented test-count baseline drop (deleted-test count from TEST-01..05) — no surviving regression
- [x] **TEST-12**: `tests/suite/TestGoldenIntegration.m` and `tests/test_golden_integration.m` have **zero diff** across the v2.1 milestone (golden-test creep prevention)

### Examples 05-events Rewrite

- [ ] **DEMO-01**: User runs `examples/05-events/example_event_detection_live.m` and observes a 3-sensor live-data demo using `SensorTag + MonitorTag + EventStore + LiveEventPipeline + DashboardEngine` with timer bounded to `TasksToExecute=5` and `onCleanup` cleanup wrapper
- [ ] **DEMO-02**: `example_event_detection_live.m` wires `NotificationService(DryRun=true)` to demonstrate event → notification pedagogical parity with `example_live_pipeline.m`
- [ ] **DEMO-03**: User runs `examples/05-events/example_event_viewer_from_file.m` and observes a batch-build → `EventStore.save` → `EventViewer.fromFile` → click-to-plot detail flow with no live timer (persistence narrative)
- [ ] **DEMO-04**: `examples/05-events/example_live_pipeline.m` orphan comment blocks are removed and the `monitors` map is rebuilt with `MonitorTag` (not `SensorTag`) values so `pipeline.runCycle()` actually fires events
- [ ] **DEMO-05**: All three `examples/05-events/*.m` scripts call `TagRegistry.clear(); EventBinding.clear();` at top to prevent cross-example singleton pollution
- [ ] **DEMO-06**: All three scripts use only Octave-portable APIs (no `datetime` / `table` / `categorical` / `duration`) — match `example_sensor_threshold.m` `linspace` pattern
- [ ] **DEMO-07**: Each rewritten demo's file header documents its distinct pedagogical purpose (live-detection vs viewer-from-file vs full-pipeline-cycle) — no duplication of `example_sensor_threshold.m`
- [ ] **DEMO-08**: `tests/test_examples_smoke.m` skip list and `examples/run_all_examples.m` skip list maintain byte-identical entries for these 3 demos (parity-preserved)
- [ ] **DEMO-09**: No `persistent` variables and no unbounded MATLAB timers remain in any rewritten demo (timer leak gate)

### Differentiators (Regression Prevention)

- [ ] **DIFF-01**: GitHub Actions `.github/workflows/tests.yml` `lint` job includes a grep gate that fails CI on any new reference to the 8 classes deleted in Phase 1011 (`Threshold`, `CompositeThreshold`, `StateChannel`, `ThresholdRule`, `Sensor`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`) scoped to `libs/ tests/ examples/ benchmarks/` — `fp.addThreshold(` and `obj.addThreshold(` surviving API explicitly allow-listed
- [x] **DIFF-02**: `tests/suite/TestGoldenIntegration.m` and `tests/test_golden_integration.m` have a `% DO NOT REWRITE — golden test, see PROJECT.md` file-header banner enforcing Pitfall 3 in-file (currently only documented in STATE.md)
- [ ] **DIFF-03**: New `tests/suite/TestLegacyClassesRemoved.m` asserts `exist('EventDetector','class') == 0`, `exist('IncrementalEventDetector','class') == 0`, `exist('EventConfig','class') == 0`, plus the 8 Phase-1011 deleted classes — a single focused contract test guarding against accidental re-introduction
- [x] **DIFF-04**: `scripts/check_skip_list_parity.sh` callable from CI compares skip-list blocks in `tests/test_examples_smoke.m` and `examples/run_all_examples.m`, exiting non-zero on diff (script-enforce parity that's currently only comment-enforced)

## Future Requirements

Deferred to future milestones. Acknowledged but not in v2.1 scope.

### v2.2+ candidates (from PROJECT.md)

- **ASSET-01..**: Asset hierarchy — Asset tree, templates, tag-to-asset binding, browse rollups
- **EVENT-GUI-01..**: Custom event GUI — click-drag region selection in FastSense → label dialog
- **CALC-01..**: Calc tags / formula evaluator for arbitrary derived tags
- **MONITOR-TRI-01..**: Tri-state / continuous severity MonitorTag output
- **WB-TAG-01..**: WebBridge parity for Tag API features

### v2.1+ Deferred (low priority)

- **MEXP-DEFER-01**: GroupWidget children with Tag bindings in `.m` export (`emitChildWidget` does not currently support Tag-bound children — out of scope for v2.1; only top-level widgets covered by MEXP-01..05)
- **TEST-DEFER-01**: Add Octave-flat sidecar tests under `tests/test_*.m` for migrated MATLAB-only suite tests (gain Octave coverage for widget-threshold tests; out of scope for v2.1 because suite tests are MATLAB-only by runner geometry)
- **R2025B-DEFER-01..**: R2025b drift fixes — explicit out-of-scope per `.planning/debug/matlab-tests-failures-investigation.md` (Phase 1006 territory)

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Re-introduce `Threshold` as a thin deprecation shim | Phase 1011 Pitfall 12 violation; clean break preferred |
| Bulk `sed -i 's/Threshold(/MonitorTag(/g'` | Breaks `fp.addThreshold(` surviving API + drifts assertion semantics; per-file review required |
| Warning-then-delegate shim for `EventDetector.detect` | No external callers exist; hard-delete is the decision (DEAD-01) |
| Inline `SensorTag('k', 'X', [...], 'Y', [...])` data in `.m` export | Produces 10k-line scripts for large datasets; guarded `TagRegistry.get` + register-before-run contract chosen instead (MEXP-03) |
| Refactor `linesForWidget` switch into a dispatch table while in the neighborhood | Scope creep; cleanup, not refactor |
| Fix R2025b MATLAB drift failures | Catalogued in `.planning/debug/matlab-tests-failures-investigation.md`; that's a separate phase/milestone |
| Delete `wiki/API-Reference:-Event-Detection.md` legacy mentions | Doc update, not code; out of v2.1 cleanup scope |
| Add new MATLAB toolbox dependencies | Pure MATLAB / Octave constraint — non-negotiable |
| Add `matlab.mock` framework | Deletion (DEAD-01..03) beats mocking for dead code |
| Codegen / template library for `.m` export | Existing `sprintf`-based `linesForWidget` pattern works; new tooling = scope creep |
| GroupWidget children with Tag bindings (`.m` export) | Deferred — see MEXP-DEFER-01 |
| Octave-flat sidecar tests for migrated suite tests | Deferred — see TEST-DEFER-01 |

## Traceability

Populated by `gsd-roadmapper` during ROADMAP.md creation (2026-04-22).

| Requirement | Phase | Status |
|-------------|-------|--------|
| DEAD-01 | Phase 1013 | Pending |
| DEAD-02 | Phase 1013 | Pending |
| DEAD-03 | Phase 1013 | Pending |
| DEAD-04 | Phase 1013 | Pending |
| DEAD-05 | Phase 1013 | Pending |
| DEAD-06 | Phase 1013 | Pending |
| MEXP-01 | Phase 1014 | Pending |
| MEXP-02 | Phase 1014 | Pending |
| MEXP-03 | Phase 1014 | Pending |
| MEXP-04 | Phase 1014 | Pending |
| MEXP-05 | Phase 1014 | Pending |
| TEST-01 | Phase 1015 | Complete |
| TEST-02 | Phase 1015 | Complete |
| TEST-03 | Phase 1015 | Complete |
| TEST-04 | Phase 1015 | Complete |
| TEST-05 | Phase 1015 | Complete |
| TEST-06 | Phase 1015 | Pending |
| TEST-07 | Phase 1015 | Pending |
| TEST-08 | Phase 1015 | Pending |
| TEST-09 | Phase 1015 | Complete |
| TEST-10 | Phase 1015 | Pending |
| TEST-11 | Phase 1015 | Pending |
| TEST-12 | Phase 1015 | Complete |
| DEMO-01 | Phase 1016 | Pending |
| DEMO-02 | Phase 1016 | Pending |
| DEMO-03 | Phase 1016 | Pending |
| DEMO-04 | Phase 1016 | Pending |
| DEMO-05 | Phase 1016 | Pending |
| DEMO-06 | Phase 1016 | Pending |
| DEMO-07 | Phase 1016 | Pending |
| DEMO-08 | Phase 1016 | Pending |
| DEMO-09 | Phase 1016 | Pending |
| DIFF-01 | Phase 1016 | Pending |
| DIFF-02 | Phase 1015 | Complete |
| DIFF-03 | Phase 1013 | Pending |
| DIFF-04 | Phase 1015 | Complete |

**Coverage:**
- v2.1 requirements: 36 total (DEAD: 6, MEXP: 5, TEST: 12, DEMO: 9, DIFF: 4)
- Mapped: 36 / Unmapped: 0 ✓
- Per-phase distribution: Phase 1013 = 7 (DEAD-01..06 + DIFF-03), Phase 1014 = 5 (MEXP-01..05), Phase 1015 = 14 (TEST-01..12 + DIFF-02 + DIFF-04), Phase 1016 = 10 (DEMO-01..09 + DIFF-01)

---
*Requirements defined: 2026-04-22*
*Last updated: 2026-04-22 — Traceability populated by gsd-roadmapper after ROADMAP.md creation (Phases 1013-1016)*
