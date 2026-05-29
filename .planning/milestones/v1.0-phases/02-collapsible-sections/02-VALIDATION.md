---
phase: 2
slug: collapsible-sections
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | matlab.unittest.TestCase (built-in) |
| **Config file** | none — `tests/run_all_tests.m` discovers suites |
| **Quick run command** | `matlab -batch "addpath('.'); install(); import matlab.unittest.*; r = TestSuite.fromClass(?TestGroupWidget); run(r);"` |
| **Full suite command** | `matlab -batch "addpath('.'); install(); run_all_tests();"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `TestGroupWidget` suite
- **After every plan wave:** Run `TestGroupWidget` + `TestDashboardEngine` + `TestDashboardSerializerRoundTrip`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-T1 | 02-01 | 1 | LAYOUT-01, LAYOUT-02 | unit+integration | `matlab -batch "... TestGroupWidget,TestDashboardEngine"` | Partially | Pending |
| 02-02-T1 | 02-02 | 1 | LAYOUT-07 | integration | `matlab -batch "... TestGroupWidget"` | New | Pending |
| 02-02-T2 | 02-02 | 1 | LAYOUT-08 | unit | `matlab -batch "... TestGroupWidget"` | New | Pending |

---

## Wave 0 Gaps

- [ ] `tests/suite/TestGroupWidget.m` — needs: `testCollapseCallsReflowCallback`, `testExpandCallsReflowCallback`, `testActiveTabPersistsThroughJSONRoundTrip`, `testTabContrastAllThemes`
- [ ] `tests/suite/TestDashboardEngine.m` — needs: `testCollapseGroupWidgetReflowsGrid` (integration)

---

## Requirement Coverage

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAYOUT-01 | Collapsing GroupWidget calls ReflowCallback and triggers grid reflow | unit+integration | `TestGroupWidget` + `TestDashboardEngine` | Partially |
| LAYOUT-02 | Expanding GroupWidget calls ReflowCallback and restores height | unit | `TestGroupWidget` | Partially |
| LAYOUT-07 | ActiveTab survives JSON save/load round-trip | integration | `TestGroupWidget` | New |
| LAYOUT-08 | Tab contrast legible in all themes | unit | `TestGroupWidget` | New |
