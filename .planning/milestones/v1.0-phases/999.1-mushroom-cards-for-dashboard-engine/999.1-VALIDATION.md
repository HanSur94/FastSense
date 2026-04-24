---
phase: 999.1
slug: mushroom-cards-for-dashboard-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 999.1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB xUnit (class-based) + Octave function tests |
| **Config file** | `tests/run_all_tests.m` |
| **Quick run command** | `matlab -batch "run tests/suite/TestIconCardWidget.m"` |
| **Full suite command** | `matlab -batch "run_all_tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run relevant TestXxxWidget.m for the widget being modified
- **After every plan wave:** Run `tests/suite/TestDashboard*.m`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 999.1-01-01 | 01 | 0 | Theme InfoColor | unit | `TestDashboardTheme` (extend) | ✅ exists | ⬜ pending |
| 999.1-02-01 | 02 | 1 | IconCardWidget render | unit | `TestIconCardWidget.testRenderNoError` | ❌ W0 | ⬜ pending |
| 999.1-02-02 | 02 | 1 | IconCardWidget state colors | unit | `TestIconCardWidget.testStateColors` | ❌ W0 | ⬜ pending |
| 999.1-02-03 | 02 | 1 | IconCardWidget serialization | unit | `TestDashboardSerializer` (extend) | ✅ exists | ⬜ pending |
| 999.1-03-01 | 03 | 1 | ChipBarWidget render | unit | `TestChipBarWidget.testRenderNoError` | ❌ W0 | ⬜ pending |
| 999.1-03-02 | 03 | 1 | ChipBarWidget chip count | unit | `TestChipBarWidget.testChipCount` | ❌ W0 | ⬜ pending |
| 999.1-04-01 | 04 | 1 | SparklineCardWidget render | unit | `TestSparklineCardWidget.testRenderNoError` | ❌ W0 | ⬜ pending |
| 999.1-04-02 | 04 | 1 | SparklineCardWidget delta | unit | `TestSparklineCardWidget.testDelta` | ❌ W0 | ⬜ pending |
| 999.1-05-01 | 05 | 2 | Serializer registration | unit | `TestDashboardSerializer.testFromStructNewTypes` | ✅ exists | ⬜ pending |
| 999.1-05-02 | 05 | 2 | Builder methods | unit | `TestDashboardBuilder` (extend) | ✅ exists | ⬜ pending |
| 999.1-05-03 | 05 | 2 | DetachedMirror clone | unit | `TestDetachedMirror` (extend) | ✅ exists | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestIconCardWidget.m` — stubs for render, state colors, refresh guard, serialization
- [ ] `tests/suite/TestChipBarWidget.m` — stubs for render, chip count, single axes, serialization
- [ ] `tests/suite/TestSparklineCardWidget.m` — stubs for render, delta, sparkline, serialization

*Existing infrastructure covers test framework — only test files need creation.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual appearance of icon circles | Visual design | Color/size aesthetics require human eye | Open example dashboard, verify icon circles render at correct size with correct colors |
| Sparkline readability at small sizes | Visual design | Perception-based | Verify sparkline is readable in a 2-row-height widget |
| Cross-platform Unicode rendering | Octave compat | Requires visual inspection on Windows | Check CI screenshots or run on Windows Octave |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
