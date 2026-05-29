---
phase: 1003
slug: composite-thresholds
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 1003 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB test runner (run_all_tests.m) + class-based suites (TestClassSetup) + Octave function tests |
| **Config file** | tests/run_all_tests.m |
| **Quick run command** | `matlab -batch "install; run(TestCompositeThreshold)"` |
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
| 01-T1 | 01 | 1 | COMP-01..07,09 | unit (TDD) | `matlab -batch "install; run(TestCompositeThreshold)"` | No (W0) | pending |
| 01-T1 | 01 | 1 | COMP-01..07 | octave func | `octave --eval "install; test_composite_threshold"` | No (W0) | pending |
| 02-T1 | 02 | 2 | COMP-04,08 | unit | `matlab -batch "install; run(TestMultiStatusWidget)"` | Yes | pending |
| 02-T2 | 02 | 2 | COMP-08 | unit (TDD) | `matlab -batch "install; run(TestMultiStatusWidget)"` | Yes | pending |
| 03-T1 | 03 | 2 | COMP-09 | unit (TDD) | `matlab -batch "install; run(TestCompositeThreshold)"` | No (W0) | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/TestCompositeThreshold.m` — CompositeThreshold class unit tests (created by Plan 01)
- [ ] `tests/test_composite_threshold.m` — Octave function-based tests (created by Plan 01)
- [ ] Existing `tests/suite/TestMultiStatusWidget.m` — extended by Plan 02
- [ ] Existing test infrastructure covers framework needs

*Existing infrastructure covers framework requirements — only new test files needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| (none) | — | — | All behaviors are automatable |

---

## Requirement Coverage

| Requirement | Plan(s) | Test File(s) |
|-------------|---------|--------------|
| COMP-01: CompositeThreshold inherits Threshold | 01 | TestCompositeThreshold, test_composite_threshold |
| COMP-02: AND/OR/MAJORITY aggregation | 01 | TestCompositeThreshold, test_composite_threshold |
| COMP-03: Nested composites | 01 | TestCompositeThreshold, test_composite_threshold |
| COMP-04: computeStatus method | 01, 02 | TestCompositeThreshold, test_composite_threshold |
| COMP-05: addChild dual-input | 01 | TestCompositeThreshold, test_composite_threshold |
| COMP-06: Per-child ValueFcn/Value | 01 | TestCompositeThreshold |
| COMP-07: Shared handle references | 01 | TestCompositeThreshold |
| COMP-08: MultiStatusWidget expansion | 02 | TestMultiStatusWidget |
| COMP-09: ThresholdRegistry + serialization | 01, 03 | TestCompositeThreshold, test_composite_threshold |
