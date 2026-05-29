---
phase: 1012
slug: migrate-examples-to-tag-api
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-17
---

# Phase 1012 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` (class-based suite in `tests/suite/`) + Octave custom function-based runner (`tests/run_all_tests.m` globs `test_*.m`) |
| **Config file** | None (harness logic lives in `tests/run_all_tests.m`) |
| **Quick run command** | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke();"` |
| **Full suite command** | `octave --no-gui --eval "cd('tests'); run_all_tests();"` and `matlab -batch "cd tests; run_all_tests"` |
| **Estimated runtime** | ~120 seconds (Octave smoke test across ~35 example files) |

---

## Sampling Rate

- **After every task commit:** Run `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke();"` — scoped to the migrated folder when possible
- **After every plan wave:** Run full suite (both MATLAB and Octave entry points above)
- **Before `/gsd:verify-work`:** Full suite must be green on both runtimes via `.github/workflows/examples.yml` + `.github/workflows/tests.yml`
- **Max feedback latency:** ~30 seconds per-folder smoke run; ~120 seconds full smoke run

---

## Per-Task Verification Map

> Plan-ID alignment matches the actual 10-plan split. Plan 04 owns the `example_sensor_threshold.m` rewrite as its own dedicated plan.

| Task ID | Plan | Wave | Scope | Test Type | Automated Command |
|---------|------|------|-------|-----------|-------------------|
| 1012-01-01 | 01 (infrastructure) | 1 | Smoke harness + run_all_examples rewrite | smoke harness | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke();"` |
| 1012-02-01 | 02 (01-basics) | 2 | 01-basics migration | smoke (Octave) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','01-basics');"` |
| 1012-03-01 | 03 (02-sensors + tags/) | 2 | 02-sensors migration + 5 new tag showcases | smoke (Octave) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','02-sensors');"` |
| 1012-04-01 | 04 (example_sensor_threshold rewrite) | 2 | Canonical end-to-end EventBinding demo rewrite | smoke (Octave) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','02-sensors');"` |
| 1012-05-01 | 05 (03-dashboard) | 2 | 03-dashboard migration | smoke (MATLAB) | `matlab -batch "cd tests; test_examples_smoke('folder','03-dashboard')"` |
| 1012-06-01 | 06 (04-widgets) | 2 | 04-widgets migration (5 X/Y hazard fixes) | smoke (Octave) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','04-widgets');"` |
| 1012-07-01 | 07 (05-events) | 2 | 05-events live pipeline rewrites | smoke (Octave parse) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','05-events');"` |
| 1012-08-01 | 08 (06-webbridge) | 2 | 06-webbridge MATLAB-side migration | smoke (Octave) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','06-webbridge');"` |
| 1012-09-01 | 09 (07-advanced) | 2 | 07-advanced migration | smoke (Octave) | `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder','07-advanced');"` |
| 1012-10-01 | 10 (regression gate) | 3 | Phase exit grep gates A/B/C/D/E/F + full smoke | grep gate + regression | `bash -c '...A&&B&&C&&D&&E&&F&&...'` (Plan 10 Task 1) and `octave ... test_examples_smoke();` (Plan 10 Task 2) |

*Status legend: pending / green / red / flaky*

---

## Wave 0 Requirements

- [x] `tests/test_examples_smoke.m` — created by Plan 01 Task 1; auto-picked up by `tests/run_all_tests.m`. Takes optional `'folder', <name>` NV-pair to scope runs; defaults to all folders. Wraps each example in `try/catch` with `close all` + `TagRegistry.clear()` + `EventBinding.clear()` between runs. Sets `set(0, 'DefaultFigureVisible', 'off')` for headless execution.
- [x] No new `tests/suite/Test*.m` class wrapper required (MATLAB `matlab-examples` CI job already covers MATLAB-only scripts).
- [x] No framework install needed — `matlab.unittest` ships with MATLAB; Octave function tests use native Octave.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Rewritten `example_sensor_threshold.m` visually shows EventBinding overlay round-markers on FastSense plot | — structural goal 6 | Rendering correctness is visual; smoke test asserts "runs without error" + "emits ≥1 event", but marker appearance is eyeball-only | Run `matlab -batch "cd examples/02-sensors; example_sensor_threshold"` interactively; confirm (a) plot window opens, (b) pressure trace + threshold lines visible, (c) round markers appear at violation timestamps, (d) fprintf summary lists ≥1 event |
| Showcase `example_tag_composite.m` correctly visualises AND vs MAJORITY side-by-side | — structural goal 7 | Dual-subplot layout correctness is visual | Run interactively; confirm two subplots render with different binary traces corresponding to the two aggregation modes |

*All other phase behaviors have automated verification via the smoke harness.*

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify via smoke harness or Wave 0 dependency on `test_examples_smoke.m`
- [x] Sampling continuity: smoke test runs after every folder-commit (no 3 consecutive tasks without automated verify)
- [x] Wave 0 covers all MISSING references (`test_examples_smoke.m` is the only missing harness file; created by Plan 01 Task 1)
- [x] No watch-mode flags
- [x] Feedback latency < 120s (full smoke) / < 30s (per-folder smoke)
- [x] `nyquist_compliant: true` set in frontmatter — every code-producing task has an `<automated>` verify per its plan

**Approval:** pending
