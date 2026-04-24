# Milestones

## v2.0 Tag-Based Domain Model (Shipped: 2026-04-24)

**Phases completed:** 9 phases (1004-1011 + 1012 extension), 30 plans, ~45 tasks
**Status:** `tech_debt` — 45/45 requirements satisfied, 9/9 flows complete, 7 non-blocking debt items tracked

**Key accomplishments:**

- **Tag hierarchy established** (Phase 1004): abstract `Tag` base + `TagRegistry` with two-phase loader + golden integration test guarding the rewrite
- **SensorTag + StateTag** (Phase 1005): legacy `Sensor`/`StateChannel` ported to Tag subclasses; `FastSense.addTag()` dispatches by `getKind()` without `isa` branches
- **MonitorTag** (Phases 1006-1008): lazy-by-default derived binary signals with debounce + hysteresis (1006), `appendData` streaming + opt-in `FastSenseDataStore` persistence (1007), cycle-detected `CompositeTag` with AND/OR/MAJORITY/COUNT/WORST aggregation via merge-sort streaming (1008)
- **Consumer migration** (Phase 1009): 9 widgets + `EventDetection` pipeline migrated to Tag API across 4 wave-ordered plans; zero `isa` branches shipped on hot paths
- **Event ↔ Tag binding** (Phase 1010): many-to-many `EventBinding` registry + `Event.TagKeys` denormalization removed + `FastSense.renderEventLayer_` toggleable round-marker overlay with Pitfall-10 zero-event regression gate PASSED
- **Legacy cleanup** (Phase 1011): 8 legacy classes deleted (`Sensor`, `Threshold`, `ThresholdRule`, `CompositeThreshold`, `StateChannel`, `SensorRegistry`, `ThresholdRegistry`, `ExternalSensorRegistry`); golden test rewritten to Tag API; full suite green
- **Live event markers + click-to-details** (Phase 1012 extension): `Event.IsOpen`/`closeEvent` open-event schema, `MonitorTag` rising-edge emission with running stats, per-event per-marker `ButtonDownFcn`, standalone-figure click-details popup with editable persistent `Notes`, severity-colored badge markers with drop shadow + section-grouped `uitable` field listing

**Tech debt tracked for v2.1 or cleanup phase:** 3 items from Phase 1011 (dead `EventDetector.detect` API, `DashboardSerializer .m` export for Tag widgets, 93 `Threshold(` refs in MATLAB-only test files) + 4 items from Phase 1012 (unused private props after popup refit, `formatEventFields_` back-compat footer, deferred UI surfaces, `autoscaleY` → public widget method).

Full details: [milestones/v2.0-ROADMAP.md](milestones/v2.0-ROADMAP.md) · Audit: [milestones/v2.0-MILESTONE-AUDIT.md](milestones/v2.0-MILESTONE-AUDIT.md)

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
