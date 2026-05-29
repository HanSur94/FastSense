---
phase: 08
slug: widget-improvements-dividerwidget-collapsiblewidget-y-axis-limits
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-04-03
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB test runner (run_all_tests.m) + class-based TestCase suites |
| **Config file** | tests/run_all_tests.m |
| **Quick run command** | `octave --eval "install(); run('tests/suite/TestDashboardEngine.m')"` |
| **Full suite command** | `octave --eval "install(); run_all_tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (TestDashboardEngine suite)
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | DividerWidget class | unit | `octave --eval "install(); run('tests/suite/TestDividerWidget.m')"` | W0 (TestDividerWidget.m created in this task) | pending |
| 08-01-02 | 01 | 1 | DividerWidget wiring + serializer round-trip | integration | `octave --eval "install(); run('tests/suite/TestDividerWidget.m'); run('tests/suite/TestDashboardSerializerRoundTrip.m')"` | YES (TestDashboardSerializerRoundTrip.m exists, extended in this task) | pending |
| 08-02-01 | 02 | 1 | addCollapsible | unit | `octave --eval "install(); run('tests/suite/TestDashboardEngine.m')"` | YES (TestDashboardEngine.m exists, extended in this task) | pending |
| 08-03-01 | 03 | 1 | YLimits property + render/serialization | unit | `octave --eval "install(); run('tests/suite/TestFastSenseWidget.m')"` | YES (TestFastSenseWidget.m exists, extended in this task) | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestDividerWidget.m` -- NEW file created by Plan 01 Task 1

*Existing test files that are EXTENDED (not created):*
- `tests/suite/TestDashboardSerializerRoundTrip.m` -- exists, extended by Plan 01 Task 2 with DividerWidget round-trip case
- `tests/suite/TestDashboardEngine.m` -- exists, extended by Plan 02 Task 1 with addCollapsible tests
- `tests/suite/TestFastSenseWidget.m` -- exists, extended by Plan 03 Task 1 with YLimits tests

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DividerWidget visual appearance | DividerWidget | Requires visual inspection of rendered line | Create dashboard with DividerWidget, verify line renders with correct theme color |
| Collapsible collapse/expand visual | CollapsibleWidget | Requires GUI interaction | Create collapsible via addCollapsible, verify collapse/expand toggle works visually |
| YLimits visual axis range | YLimits | Confirms axis bounds visually (automated test covers ylim() value but visual confirmation is complementary) | Create FastSenseWidget with YLimits=[0 100], verify Y-axis shows 0-100 range |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
