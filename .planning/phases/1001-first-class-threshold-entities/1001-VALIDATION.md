---
phase: 1001
slug: first-class-threshold-entities
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 1001 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB test runner (run_all_tests.m) + class-based suites (TestClassSetup) |
| **Config file** | tests/run_all_tests.m |
| **Quick run command** | `matlab -batch "install; run('tests/suite/TestThreshold.m')"` |
| **Full suite command** | `matlab -batch "install; run('tests/run_all_tests.m')"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test for the modified class
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | TBD | unit | TBD | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestThreshold.m` — Threshold class unit tests
- [ ] `tests/suite/TestThresholdRegistry.m` — ThresholdRegistry unit tests
- [ ] Existing test infrastructure covers framework needs

*Existing infrastructure covers framework requirements — only new test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Shared threshold propagation | Handle class sharing | Visual verification of live update across sensors | Create threshold, attach to 2 sensors, modify threshold value, verify both sensors see new value |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
