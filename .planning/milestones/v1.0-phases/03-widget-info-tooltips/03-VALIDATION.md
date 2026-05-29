---
phase: 3
slug: widget-info-tooltips
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-01
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | matlab.unittest.TestCase (built-in) |
| **Config file** | `tests/run_all_tests.m` |
| **Quick run command** | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestInfoTooltip');"` |
| **Full suite command** | `matlab -batch "addpath('.'); install(); run_all_tests();"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `TestInfoTooltip` suite
- **After every plan wave:** Full test suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-T1 | 03-01 | 1 | INFO-01..05 | unit | `runtests('tests/suite/TestInfoTooltip')` | No — Wave 0 | Pending |
| 03-01-T2 | 03-01 | 1 | INFO-01..05 | unit+integration | Same | New after T1 | Pending |

---

## Wave 0 Gaps

- [ ] `tests/suite/TestInfoTooltip.m` — covers INFO-01 through INFO-05
- [ ] Verify `TestDashboardLayout.m` still passes (realizeWidget() modified)
- [ ] Verify `TestDashboardEngine.m` still passes (hFigure property flow)

---

## Requirement Coverage

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFO-01 | Widget with Description gets info icon; without does not | unit | `TestInfoTooltip` | No — Wave 0 |
| INFO-02 | Click info icon creates popup panel | unit | `TestInfoTooltip` | No — Wave 0 |
| INFO-03 | MarkdownRenderer renders Description in popup | unit | `TestInfoTooltip` | No — Wave 0 |
| INFO-04 | Escape/click-outside dismisses popup; restores prior callbacks | unit | `TestInfoTooltip` | No — Wave 0 |
| INFO-05 | All 20+ widget types get info icon without per-widget changes | integration | `TestInfoTooltip` | No — Wave 0 |
