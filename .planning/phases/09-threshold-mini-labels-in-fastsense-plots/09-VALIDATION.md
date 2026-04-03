---
phase: 09
slug: threshold-mini-labels-in-fastsense-plots
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-03
---

# Phase 09 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB test runner (run_all_tests.m) + class-based suites |
| **Config file** | tests/run_all_tests.m |
| **Quick run command** | `matlab -batch "install(); run('tests/suite/TestFastSense.m')"` |
| **Full suite command** | `matlab -batch "install(); run_all_tests"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick suite (TestFastSense)
- **After every plan wave:** Run full test suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 09-01-01 | 01 | 1 | MINILABEL-01 | unit | `grep 'ShowThresholdLabels' libs/FastSense/FastSense.m` | ❌ W0 | ⬜ pending |
| 09-01-02 | 01 | 1 | MINILABEL-02 | unit | `grep 'hText' libs/FastSense/FastSense.m` | ❌ W0 | ⬜ pending |
| 09-01-03 | 01 | 1 | MINILABEL-03 | unit | `grep 'updateThresholdLabels' libs/FastSense/FastSense.m` | ❌ W0 | ⬜ pending |
| 09-02-01 | 02 | 1 | MINILABEL-04 | unit | `grep 'ShowThresholdLabels' libs/Dashboard/FastSenseWidget.m` | ❌ W0 | ⬜ pending |
| 09-02-02 | 02 | 1 | MINILABEL-05 | unit | `grep 'showThresholdLabels' libs/Dashboard/FastSenseWidget.m` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestThresholdLabels.m` — test scaffold for threshold mini-label verification

---

## Validation Architecture

### Feedback Sampling Points
1. After ShowThresholdLabels property addition: verify property exists and defaults to false
2. After hText creation in render(): verify text handles created when ShowThresholdLabels=true
3. After updateThresholdLabels(): verify labels reposition on xlim change
4. After FastSenseWidget integration: verify toStruct/fromStruct round-trip

### Integration Checkpoints
- FastSense.render() creates hText handles alongside hLine
- FastSense.updateThresholdLabels() repositions on zoom/pan/refresh
- FastSenseWidget.ShowThresholdLabels serializes in toStruct/fromStruct
- Backward compatibility: ShowThresholdLabels=false by default, existing dashboards unaffected
