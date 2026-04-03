---
phase: 08
slug: widget-improvements-dividerwidget-collapsiblewidget-y-axis-limits
status: draft
nyquist_compliant: false
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
| 08-01-01 | 01 | 1 | DividerWidget | unit | `octave --eval "install(); run('tests/suite/TestDashboardEngine.m')"` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | DividerWidget serialization | integration | `octave --eval "install(); run('tests/suite/TestDashboardSerializerRoundTrip.m')"` | ❌ W0 | ⬜ pending |
| 08-02-01 | 02 | 1 | addCollapsible | unit | `octave --eval "install(); run('tests/suite/TestDashboardEngine.m')"` | ❌ W0 | ⬜ pending |
| 08-03-01 | 03 | 1 | YLimits render | unit | `octave --eval "install(); run('tests/suite/TestDashboardEngine.m')"` | ❌ W0 | ⬜ pending |
| 08-03-02 | 03 | 1 | YLimits serialization | integration | `octave --eval "install(); run('tests/suite/TestDashboardSerializerRoundTrip.m')"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Tests for DividerWidget in TestDashboardEngine or new TestDividerWidget
- [ ] Tests for addCollapsible convenience method
- [ ] Tests for YLimits property on FastSenseWidget

*Existing infrastructure covers test framework — only new test methods needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| DividerWidget visual appearance | DividerWidget | Requires visual inspection of rendered line | Create dashboard with DividerWidget, verify line renders with correct theme color |
| Collapsible collapse/expand visual | CollapsibleWidget | Requires GUI interaction | Create collapsible via addCollapsible, verify collapse/expand toggle works visually |
| YLimits visual axis range | YLimits | Requires visual confirmation of axis bounds | Create FastSenseWidget with YLimits=[0 100], verify Y-axis shows 0-100 range |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
