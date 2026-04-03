# Milestones

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
