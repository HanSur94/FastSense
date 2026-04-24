---
phase: 1004
slug: dashboard-image-export-button
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-15
---

# Phase 1004 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` (suite) + function-based Octave tests (flat) |
| **Config file** | `tests/run_all_tests.m` |
| **Quick run command** | `matlab -batch "runtests('tests/suite/TestDashboardToolbarImageExport.m')"` (MATLAB) / `cd tests && octave --eval "test_dashboard_toolbar_image_export()"` (Octave) |
| **Full suite command** | `matlab -batch "cd tests; run_all_tests()"` and `cd tests && octave --eval "run_all_tests()"` |
| **Estimated runtime** | ~10s for the focused suite; ~3–5 min for the full test runner |

---

## Sampling Rate

- **After every task commit:** Run focused suite — `runtests('tests/suite/TestDashboardToolbarImageExport.m')`
- **After every plan wave:** Run full suite — `matlab -batch "cd tests; run_all_tests()"`
- **Before `/gsd:verify-work`:** Full suite must be green in both MATLAB and Octave runners
- **Max feedback latency:** 15 seconds (focused suite)

---

## Per-Task Verification Map

Requirements derived from CONTEXT.md `<decisions>` (no REQ-IDs in ROADMAP — `phase_req_ids` is null). IMG-01..IMG-09 become the must-haves for this phase.

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1004-01-01 | 01 | 1 | IMG-02, IMG-03, IMG-04, IMG-05, IMG-06 | unit | `runtests('tests/suite/TestDashboardToolbarImageExport.m')` | ❌ W0 | ⬜ pending |
| 1004-02-01 | 02 | 2 | IMG-01, IMG-07 | unit | `runtests('tests/suite/TestDashboardToolbarImageExport.m')` | ❌ W0 | ⬜ pending |
| 1004-03-01 | 03 | 2 | IMG-01..IMG-09 (suite completion) | unit + integration | `runtests('tests/suite/TestDashboardToolbarImageExport.m')` + `octave --eval "test_dashboard_toolbar_image_export()"` | ❌ W0 | ⬜ pending |
| 1004-03-02 | 03 | 2 | IMG-08, IMG-09 | integration | same | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

### Requirement Legend (derived from CONTEXT.md)

- **IMG-01** — `hImageBtn` uicontrol created between `hSaveBtn` and `hExportBtn`, label "Image", tooltip "Save dashboard as image (PNG/JPEG)"
- **IMG-02** — `Engine.exportImage(path, 'png')` writes a non-empty PNG file
- **IMG-03** — `Engine.exportImage(path, 'jpeg')` writes a non-empty JPEG file
- **IMG-04** — Filename sanitization replaces `[/\:*?"<>|]` and whitespace with `_`
- **IMG-05** — Unknown format raises `DashboardEngine:unknownImageFormat`
- **IMG-06** — Write failure on unwritable path raises warning captured by `verifyWarning`
- **IMG-07** — `DashboardToolbar.onImage()` with user cancel (`uiputfile` returns 0) is a no-op (no error thrown)
- **IMG-08** — Multi-page active-page capture: after `switchPage(2)`, `exportImage` writes a file (content capture naturally targets the visible page via the visibility-toggle page system)
- **IMG-09** — Live mode active → `exportImage` succeeds without stopping the timer (`IsLive` remains true after call)

---

## Wave 0 Requirements

- [ ] `tests/suite/TestDashboardToolbarImageExport.m` — `matlab.unittest.TestCase` with methods: `testButtonPresent`, `testExportImagePNG`, `testExportImageJPEG`, `testSanitizeFilename`, `testUnknownFormatError`, `testWriteFailureWarns`, `testCancelNoOp`, `testMultiPageActiveOnly`, `testLiveModeNoPause`
- [ ] `tests/test_dashboard_toolbar_image_export.m` — Octave function-based parallel suite covering at minimum IMG-02, IMG-03, IMG-04, IMG-07 (Octave-safe subset; IMG-01 skipped because Octave `print()` excludes uicontrols)
- [ ] No new shared fixtures or framework install needed — uses existing `install()` path setup

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Visual quality of captured image (anti-aliasing, widget rendering) | (user-facing UX) | Pixel-perfect verification is not automated — existing `FastSenseToolbar.testExportPNG` precedent verifies file exists + non-empty, not pixel content | Save dashboard as PNG, open in image viewer, visually confirm toolbar (in MATLAB), widgets, and theme colors render correctly. Repeat on Octave and document platform difference (uicontrols excluded on Octave — expected). |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (both MATLAB suite + Octave flat test)
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s (focused suite)
- [ ] `nyquist_compliant: true` set in frontmatter after plan-checker pass

**Approval:** pending
