---
phase: 999.3
slug: graph-data-export-mat-csv
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-05
---

# Phase 999.3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB TestCase suite + Octave function-based tests |
| **Config file** | `tests/run_all_tests.m` |
| **Quick run command** | `cd /Users/hannessuhr/FastPlot && octave --eval "install; run('tests/test_toolbar.m')"` |
| **Full suite command** | `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/run_all_tests.m')"` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick run command (test_toolbar.m)
- **After every plan wave:** Run full suite command (run_all_tests.m)
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 999.3-01-01 | 01 | 1 | EXPORT-01..06 | unit | `octave --eval "install; run('tests/test_toolbar.m')"` | ✅ extend | ⬜ pending |
| 999.3-01-02 | 01 | 1 | EXPORT-01..06 | unit | `octave --eval "install; run('tests/test_toolbar.m')"` | ✅ extend | ⬜ pending |
| 999.3-02-01 | 02 | 2 | EXPORT-05 | unit | `octave --eval "install; run('tests/test_toolbar.m')"` | ✅ update | ⬜ pending |
| 999.3-02-02 | 02 | 2 | EXPORT-05 | unit | `octave --eval "install; run('tests/test_toolbar.m')"` | ✅ update | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed — extend existing `tests/test_toolbar.m`.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Toolbar Export Data button opens file dialog | EXPORT-05 | uiputfile is interactive | Click Export Data button, verify dialog appears with CSV/MAT filter |
| Export Data icon is visually distinct from Export PNG | EXPORT-05 | Visual appearance | Inspect toolbar buttons side by side |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
