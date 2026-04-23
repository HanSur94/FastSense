# Milestones

## v2.0 Tag-Based Domain Model (Shipped: 2026-04-23)

**Timeline:** 2026-03-06 → 2026-04-23 (48 days)
**Phases:** 18 (8 original Tag rewrite + 10 post-audit additions)
**Plans:** 46/46 complete
**Commits:** ~396 | **MATLAB LOC:** 66,638 | **Git range:** `7751bd9` → `d88e9fe`
**Tag:** v2.0

### Key Accomplishments

1. **Unified Tag domain model** (Phases 1004–1011): Deleted 8 legacy classes (`Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`). New hierarchy: abstract `Tag` base, `TagRegistry` two-phase loader, `SensorTag`/`StateTag` data carriers, `MonitorTag` (lazy in-memory + streaming `appendData` + opt-in `FastSenseDataStore` persistence), `CompositeTag` with AND/OR/MAJORITY/COUNT/WORST/SEVERITY/USER_FN merge-sort aggregation + cycle detection. Every consumer migrated one-widget-per-commit.
2. **First-class Threshold entities + Composite Thresholds** (Phases 1001–1003, preserved as concepts inside v2.0): `Threshold` handle class, `ThresholdRegistry`, `CompositeThreshold` with hierarchical status, direct widget binding for StatusWidget/GaugeWidget/IconCardWidget/MultiStatusWidget/ChipBarWidget.
3. **Dashboard Performance Phase 2** (Phase 1000): Incremental FastSenseWidget refresh with updateData() reuse, O(1) cached time ranges, debounced slider broadcast, lazy page realization, batched switchPage, debounced resize without dirty marking.
4. **Event ↔ Tag binding + FastSense overlay** (Phase 1010): Many-to-many `EventBinding` registry decouples Event from Tag; `Event.TagKeys` + `EventStore.eventsForTag`; toggleable round-marker overlay on FastSense plots theme-colored by severity; separate `renderEventLayer_` keeps line-render hot path clean.
5. **Tag ingestion pipeline** (Phase 1012): `BatchTagPipeline` (synchronous) + `LiveTagPipeline` (timer-driven modTime+lastIndex incremental) ingest arbitrary delimited raw files → per-tag `.mat` keyed off TagRegistry. Shared textscan-based parser (Octave 7+ compatible); per-tag try/catch isolation with `TagPipeline:ingestFailed` aggregation.
6. **Mushroom cards + Image Export + Graph Data Export** (Phases 999.1, 1004 Image, 999.3): IconCardWidget, ChipBarWidget, SparklineCardWidget + DashboardTheme InfoColor; DashboardEngine.exportImage (PNG/JPEG + multi-page + live no-pause); `.mat`/`.csv` export with NaN-filled union + ISO 8601 + datenum.
7. **CI + Prebuilt MEX binaries** (Phases 1006, 1013): Fixed 137 MATLAB test failures from R2025b drift (A+B+C+D+E+F categories); pinned MATLAB CI to R2020b; `.mex-version` source-hash stamp gating; 27 macOS ARM64 binaries tracked; `refresh-mex-binaries.yml` 7-platform matrix workflow with auto-PR; 5 existing CI workflows rewired to reuse committed binaries; release tarball ships MEX.

### Known Gaps (tech debt, carried forward)

- **Phase 1013 HUMAN-UAT (3 pending):** MATLAB fresh-clone `install()` on macOS ARM64 not directly exercised (no MATLAB on dev host); Windows + Linux `install()` deferred until `refresh-mex-binaries.yml` first run produces non-macOS binaries. Fix is analytically identical to the verified Octave path.
- **v2.0 audit tech debt (from 2026-04-17 audit):** `EventDetector.detect(tag, threshold)` references deleted Threshold API — dead code; `DashboardSerializer` `.m` export silently omits Tag-bound widgets (JSON path works); 93 `Threshold(` constructor refs in 42 MATLAB-only suite test files (fail on MATLAB, skip on Octave).
- **Phase 1005 (CI coverage expansion)** was never formally planned; partially superseded by Phase 1006 (MATLAB R2020b + 137 fixes) and Phase 1013 (prebuilt MEX). Remaining: full test suite execution on non-Linux CI runners.
- **4 pre-existing unresolved debug sessions:** `ci-examples-and-lint-failing`, `ci-octave-tests-failing`, `matlab-tests-failures-investigation`, `octave-cleanup-crash-investigation`.

### Key Decisions

- **Full rewrite under unified `Tag` root (Option 2)** over interface-shim approach — no-users codebase allowed clean end state while preserving design wins from Phases 1001–1003 as concepts.
- **Lazy-by-default MonitorTag** with opt-in `Persist` + `appendData` streaming — avoids premature persistence (Pitfall 2) while keeping live pipelines fast (>5x speedup vs. full recompute).
- **Zero `Event ↔ Tag` handle cycles** — `EventBinding` is the only write side; `save → clear classes → load` round-trip verifies (Pitfall 4).
- **Separate event render layer** in FastSense — no conditionals added to line-rendering loop; 0-event render benchmark shows no regression (Pitfall 10).
- **`.mex-version` stamp as source-of-truth for shipped binaries**, with `build_mex.m` mtime check as belt-and-suspenders backstop. Prebuilt MEX lives at designated paths only (flat for MATLAB, `octave-<platform>/` subdir for Octave) via `.gitignore` negation allow-list.
- **12 explicit pitfall gates enforced across every v2.0 phase** — over-abstracted Tag, premature persistence, memory blowup, Event↔Tag cycle, big-bang sequencing, semantics drift, registry collisions, serialization order, MEX wrapping cost, render-path pollution, golden test sanctity, feature creep.

---

## v1.0 Dashboard Performance Optimization (Shipped: 2026-04-04)

**Phases completed:** 1 phases, 3 plans, 2 tasks

**Key accomplishments:**

- One-liner:
- Task 1: Consolidated onLiveTick with updateLiveTimeRangeFrom

---

## v1.0 Dashboard Engine Code Review Fixes (Shipped: 2026-04-03)

**Phases completed:** 1 phases, 4 plans, 2 tasks

**Key accomplishments:**

- Four correctness bugs patched in DashboardEngine: multi-page removeWidget, resize reflow, sensor listener parity, and dead removeDetached parameter removed
- One-liner:
- One-liner:

---

## v1.0 FastSense Advanced Dashboard (Shipped: 2026-04-03)

**Phases completed:** 9 phases, 24 plans, 21 tasks

**Key accomplishments:**

- One-liner:
- One-liner:
- DashboardSerializer.save() now correctly emits constructor calls and addChild() for all GroupWidget children in panel, collapsible, and tabbed modes, making .m round-trips reliable for any dashboard using groups
- testTimerContinuesAfterError rewritten to trigger ErrorFcn indirectly via a throwing TimerFcn, giving INFRA-01 runnable automated coverage without calling any private method
- 1. [Pre-existing] TestGroupWidget/testFullDashboardIntegration
- One-liner:
- One-liner:
- One-liner:
- DashboardPage handle class with Name/Widgets/addWidget/toStruct, DashboardEngine.addPage() routing, and 8-method TestDashboardMultiPage scaffold with 3 tests green immediately
- DashboardEngine extended with Pages/ActivePage properties, visible PageBar with themed buttons for multi-page dashboards, switchPage() navigation, and activePageWidgets() scoping for all widget iteration methods
- One-liner:
- testSaveLoadRoundTrip now asserts that ActivePage index 2 is preserved through JSON save/load, closing the LAYOUT-05 coverage gap for DashboardEngine.m lines 1063-1070
- 1. [Rule 1 - Bug] Sensor constructor positional argument
- DetachCallback property + addDetachButton() added to DashboardLayout, injecting a '^' button at [0.82 0.90 0.08 0.08] in every widget panel when callback is wired — DETACH-01 satisfied
- DashboardEngine gains DetachedMirrors registry + detachWidget/removeDetached methods + onLiveTick mirror loop, completing all 7 DETACH tests (DETACH-01 through DETACH-07)
- Multi-page JSON save/load round-trip tests covering SERIAL-01, SERIAL-04, SERIAL-05 with a bug fix for single-named-page save routing to widgetsPagesToConfig
- Multi-page .m export fixed to emit a proper MATLAB function + switchPage routing; 5 new round-trip tests covering SERIAL-02 and SERIAL-03 all pass
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:

---

## v1.0 Advanced Dashboard (Shipped: 2026-04-03)

**Phases completed:** 8 phases, 22 plans, 21 tasks

**Key accomplishments:**

- One-liner:
- One-liner:
- DashboardSerializer.save() now correctly emits constructor calls and addChild() for all GroupWidget children in panel, collapsible, and tabbed modes, making .m round-trips reliable for any dashboard using groups
- testTimerContinuesAfterError rewritten to trigger ErrorFcn indirectly via a throwing TimerFcn, giving INFRA-01 runnable automated coverage without calling any private method
- 1. [Pre-existing] TestGroupWidget/testFullDashboardIntegration
- One-liner:
- One-liner:
- One-liner:
- DashboardPage handle class with Name/Widgets/addWidget/toStruct, DashboardEngine.addPage() routing, and 8-method TestDashboardMultiPage scaffold with 3 tests green immediately
- DashboardEngine extended with Pages/ActivePage properties, visible PageBar with themed buttons for multi-page dashboards, switchPage() navigation, and activePageWidgets() scoping for all widget iteration methods
- One-liner:
- testSaveLoadRoundTrip now asserts that ActivePage index 2 is preserved through JSON save/load, closing the LAYOUT-05 coverage gap for DashboardEngine.m lines 1063-1070
- 1. [Rule 1 - Bug] Sensor constructor positional argument
- DetachCallback property + addDetachButton() added to DashboardLayout, injecting a '^' button at [0.82 0.90 0.08 0.08] in every widget panel when callback is wired — DETACH-01 satisfied
- DashboardEngine gains DetachedMirrors registry + detachWidget/removeDetached methods + onLiveTick mirror loop, completing all 7 DETACH tests (DETACH-01 through DETACH-07)
- Multi-page JSON save/load round-trip tests covering SERIAL-01, SERIAL-04, SERIAL-05 with a bug fix for single-named-page save routing to widgetsPagesToConfig
- Multi-page .m export fixed to emit a proper MATLAB function + switchPage routing; 5 new round-trip tests covering SERIAL-02 and SERIAL-03 all pass
- One-liner:
- One-liner:
- One-liner:
- One-liner:

---

## v1.0 Advanced Dashboard (Shipped: 2026-04-03)

**Phases completed:** 7 phases, 19 plans, 21 tasks

**Key accomplishments:**

- One-liner:
- One-liner:
- DashboardSerializer.save() now correctly emits constructor calls and addChild() for all GroupWidget children in panel, collapsible, and tabbed modes, making .m round-trips reliable for any dashboard using groups
- testTimerContinuesAfterError rewritten to trigger ErrorFcn indirectly via a throwing TimerFcn, giving INFRA-01 runnable automated coverage without calling any private method
- 1. [Pre-existing] TestGroupWidget/testFullDashboardIntegration
- One-liner:
- One-liner:
- One-liner:
- DashboardPage handle class with Name/Widgets/addWidget/toStruct, DashboardEngine.addPage() routing, and 8-method TestDashboardMultiPage scaffold with 3 tests green immediately
- DashboardEngine extended with Pages/ActivePage properties, visible PageBar with themed buttons for multi-page dashboards, switchPage() navigation, and activePageWidgets() scoping for all widget iteration methods
- One-liner:
- testSaveLoadRoundTrip now asserts that ActivePage index 2 is preserved through JSON save/load, closing the LAYOUT-05 coverage gap for DashboardEngine.m lines 1063-1070
- 1. [Rule 1 - Bug] Sensor constructor positional argument
- DetachCallback property + addDetachButton() added to DashboardLayout, injecting a '^' button at [0.82 0.90 0.08 0.08] in every widget panel when callback is wired — DETACH-01 satisfied
- DashboardEngine gains DetachedMirrors registry + detachWidget/removeDetached methods + onLiveTick mirror loop, completing all 7 DETACH tests (DETACH-01 through DETACH-07)
- Multi-page JSON save/load round-trip tests covering SERIAL-01, SERIAL-04, SERIAL-05 with a bug fix for single-named-page save routing to widgetsPagesToConfig
- Multi-page .m export fixed to emit a proper MATLAB function + switchPage routing; 5 new round-trip tests covering SERIAL-02 and SERIAL-03 all pass
- One-liner:

---
