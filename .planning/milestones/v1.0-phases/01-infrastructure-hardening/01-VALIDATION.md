---
phase: 1
slug: infrastructure-hardening
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | matlab.unittest.TestCase (built-in) |
| **Config file** | none — discovered via `TestSuite.fromFolder(tests/suite/)` |
| **Quick run command** | `matlab -batch "addpath('.'); install(); import matlab.unittest.*; r = TestSuite.fromFolder('tests/suite/'); run(r);"` |
| **Full suite command** | `matlab -batch "addpath('.'); install(); run_all_tests();"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run targeted test class (`TestDashboardEngine`, `TestGroupWidget`, or `TestDashboardMSerializer` depending on which file was changed)
- **After every plan wave:** Full suite `run_all_tests()`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-T1 | 01-01 | 1 | INFRA-01 | unit | `matlab -batch "... TestDashboardEngine"` | Partially | Pending |
| 01-02-T1 | 01-02 | 1 | INFRA-03 | unit | `matlab -batch "... TestDashboardSerializer"` | New | Pending |
| 01-02-T2 | 01-02 | 1 | INFRA-03, COMPAT-02 | unit | `matlab -batch "... TestDashboardSerializer"` | Existing | Pending |
| 01-03-T1 | 01-03 | 2 | INFRA-02 | unit | `matlab -batch "... TestDashboardMSerializer"` | New | Pending |
| 01-03-T2 | 01-03 | 2 | INFRA-02 | unit | `matlab -batch "... TestDashboardMSerializer"` | New | Pending |
| 01-03-T3 | 01-03 | 2 | COMPAT-01..04 | integration | Full suite | Existing | Pending |

---

## Wave 0 Gaps

- [ ] `tests/suite/TestDashboardEngine.m` — add `testTimerContinuesAfterError` method (covers INFRA-01)
- [ ] `tests/suite/TestDashboardMSerializer.m` — add `testGroupWithChildrenRoundTrip` and `testGroupTabbedRoundTrip` methods (covers INFRA-02)
- [ ] `tests/suite/TestDashboardSerializer.m` — add `testNormalizeToCellHelper` method (covers INFRA-03)

---

## Requirement Coverage

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFRA-01 | Timer continues running after TimerFcn error | unit | `matlab -batch "... TestDashboardEngine"` | Partially |
| INFRA-02 | GroupWidget .m export round-trip preserves children | unit | `matlab -batch "... TestDashboardMSerializer"` | Partially |
| INFRA-03 | normalizeToCell handles struct array, cell array, empty | unit | `matlab -batch "... TestDashboardSerializer"` | New |
| COMPAT-01 | DashboardEngine addWidget/startLive API unchanged | unit | `matlab -batch "... TestDashboardEngine"` | Yes |
| COMPAT-02 | JSON dashboards load correctly | unit | `matlab -batch "... TestDashboardSerializerRoundTrip"` | Yes |
| COMPAT-03 | .m dashboards without children load correctly | unit | `matlab -batch "... TestDashboardMSerializer"` | Yes |
| COMPAT-04 | DashboardBuilder API unchanged | unit | `matlab -batch "... TestDashboardBuilder"` | Yes |
