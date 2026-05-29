# Milestones

## v2.0 Tag-Based Domain Model (Shipped: 2026-04-17)

**Phases completed:** 10 phases, 37 plans, 26 tasks

**Key accomplishments:**

- FastSenseWidget.refresh() now reuses FastSenseObj via updateData() on sensor-identity match, and getTimeRange() returns O(1) cached CachedXMin/CachedXMax instead of full array scan
- Non-active pages now defer widget realization until first switchPage, with batched drawnow-interleaved realization reducing multi-page startup time proportional to page count.
- One-liner:
- One-liner:
- 1. [Rule 1 - Bug] GaugeWidget.deriveRange had no early return after allVals calculation
- IncrementalEventDetector, LiveEventPipeline, and EventViewer fully migrated from ThresholdRules/addThresholdRule to Thresholds/addThreshold, with zero ThresholdRules references remaining in EventDetection production code
- One-liner:
- Total calls migrated:
- 1. [Rule 2 - Missing Critical Functionality] ThresholdRegistry.clear() added
- Standalone Threshold binding via Threshold property on IconCardWidget, isstruct dispatch in MultiStatusWidget, and per-chip threshold fields in ChipBarWidget resolveChipColor
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- Octave smoke harness + recursive auto-default run_all_examples.m, both with byte-identical skip-list blocks and TagRegistry/EventBinding singleton-cleanup discipline — deterministic per-folder verification gate that every Wave 2 migration plan consumes
- No-op audit pass.
- No-op audit pass.
- InfoColor added to DashboardTheme and IconCardWidget implemented with state-colored circle icon, numeric value display, and three-path data binding
- 1. [Rule 1 - Bug] Fixed testChipColorUpdate using containers.Map for mutable closure
- Sparkline rendering:
- 1. [Rule 3 - Blocking] Wave 1 widget files not yet in worktree
- One-liner:
- One-liner:

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
