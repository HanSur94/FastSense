---
phase: 01
slug: dashboard-engine-code-review-fixes
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB test runner (run_all_tests.m) + class-based suites |
| **Config file** | tests/run_all_tests.m |
| **Quick run command** | `cd tests && octave --eval "run_all_tests"` |
| **Full suite command** | `cd tests && octave --eval "run_all_tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick suite for affected test files
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01 | 1 | FIX-01,03,04,10 tests | unit | runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-01-T2 | 01 | 1 | FIX-01,03,04,10 fixes | unit | runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-02-T1 | 02 | 1 | FIX-02,05 tests | unit | runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-02-T2 | 02 | 1 | FIX-02,05 fixes | unit | runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-03-T1 | 03 | 1 | FIX-06,07,08 tests | unit | runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-03-T2 | 03 | 1 | FIX-06,07,08 fixes | unit | runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-04-T1 | 04 | 2 | FIX-11,12,13,14 | grep+test | grep + runtests TestDashboardBugFixes | ✅ | ⬜ pending |
| 01-04-T2 | 04 | 2 | FIX-09 | grep+test | grep + runtests TestDashboardBugFixes | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test framework needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Widget panel repositioning on resize | onResize reflow | Requires MATLAB GUI interaction | Resize dashboard figure, verify widgets reposition |
| Collapsed group visual state | GroupWidget refresh guard | Requires visual inspection | Collapse group, verify children not flickering |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
