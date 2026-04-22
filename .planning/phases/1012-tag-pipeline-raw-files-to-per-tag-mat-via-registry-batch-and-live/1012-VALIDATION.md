---
phase: 1012
slug: tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-22
---

# Phase 1012 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` suite (`tests/suite/Test*.m`) + Octave flat-function tests (`tests/test_*.m`) |
| **Config file** | none — `tests/run_all_tests.m` discovers tests automatically |
| **Quick run command** | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestBatchTagPipeline.m')"` |
| **Full suite command** | `matlab -batch "addpath('.'); install(); run tests/run_all_tests.m"` |
| **Estimated runtime** | ~30 s (quick), ~4-6 min (full) |

Octave equivalents:
- Quick: `octave --no-gui --eval "install; test test_batch_tag_pipeline"`
- Full:  `octave --no-gui --eval "install; run tests/run_all_tests.m"`

---

## Sampling Rate

- **After every task commit:** Run the quick targeted test matching the touched component (one `Test*.m` suite or `test_*.m` file).
- **After every plan wave:** Run `tests/run_all_tests.m` on MATLAB AND Octave (parity gate is non-negotiable per CLAUDE.md).
- **Before `/gsd:verify-work`:** Full suite green on both runtimes.
- **Max feedback latency:** 30 s for quick, 6 min for full.

---

## Per-Task Verification Map

To be filled by gsd-planner per plan. Every task in every PLAN.md must map to one row here with:
- Task ID (from plan frontmatter)
- Plan # (01, 02, …)
- Wave #
- Requirement / Decision ID (D-01..D-19 from CONTEXT.md — phase has no REQ-IDs)
- Test type (unit / integration / error-ID / benchmark)
- Automated command
- File-exists marker
- Status

| Task ID | Plan | Wave | Decision | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|-----------|-------------------|-------------|--------|
| 1012-01-01 | 01 | 0 | D-03 | Wave-0 fixture helper | _pending planner_ | ❌ W0 | ⬜ pending |
| _etc._ | | | | | | | |

The planner fills this table; the plan-checker verifies every task is present.

---

## Validation Dimensions (from RESEARCH.md)

Every plan must contribute tests across these axes:

1. **Functional correctness** — Per-tag .mat output round-trips through `SensorTag.load()` unchanged for wide and tall raw inputs.
2. **Error-ID coverage** — Each of the 11 proposed `TagPipeline:*` error IDs (from RESEARCH Q5) must have at least one assertable test (`verifyError` / `assert_error_raised`).
3. **Octave parity** — Every pipeline-behavior test has both a MATLAB suite form and an Octave flat-function form OR is explicitly marked runtime-skipped with justification.
4. **Live-mode incrementality** — Append semantics (`load → concat → save`, NOT `-append`) verified by writing rows, ticking, adding rows, ticking again; assertion that no data is lost.
5. **mtime-guard handling** — Tests that bump `modTime` use `pause(1.1)` or explicit touch to survive filesystem mtime resolution (macOS HFS+ 1s, APFS 1ns, Linux ext4 1ns, Windows NTFS 100ns, Windows FAT 2s).
6. **De-dup caching** — Two tags sharing the same RawSource file produce exactly one `fopen`/parse invocation per run (assert via mock or counter).
7. **Per-tag error isolation** — One failing tag does not abort the batch; at-end `TagPipeline:ingestFailed` reports every failure with cause.

---

## Wave 0 Requirements

- [ ] `tests/suite/TestBatchTagPipeline.m` — test scaffold with `TestClassSetup addPaths`, tempdir fixture factory, one failing placeholder test per decision covered by Plan 01.
- [ ] `tests/suite/TestLiveTagPipeline.m` — ditto for Plan LiveTag.
- [ ] `tests/test_batch_tag_pipeline.m` (flat-function mirror for Octave).
- [ ] `tests/test_live_tag_pipeline.m` (flat-function mirror for Octave).
- [ ] `tests/suite/private/makeSyntheticRaw.m` (or shared helper in an accessible location) — generator for wide/tall CSV/TXT/DAT fixtures in a tempdir.
- [ ] `tests/suite/private/pauseMtime.m` — portable `pause(1.1)` wrapper that's skipped where filesystem supports sub-second mtime (APFS/ext4/NTFS).

*Budget note (Pitfall 5):* Fixture helpers count toward the ≤12-file phase budget. Research proposes 10-11 touched files; trim flat-function mirrors if the budget tightens.

---

## Manual-Only Verifications

| Behavior | Decision | Why Manual | Test Instructions |
|----------|----------|------------|-------------------|
| Real-world large-file live polling throughput | D-13 | Filesystem-dependent; CI ext4 / macOS APFS may not surface timing regressions a user hits on an NFS share | Run `examples/example_tag_pipeline_live.m` (to be added) against a 500 MB CSV growing at 1 Hz; watch `LiveTagPipeline.Status` remain `'running'` and output .mat files update within 2× Interval |

(If none applicable at plan-resolve time, this table may collapse to: "All phase behaviors have automated verification.")

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (fixture helper, mtime helper, suite scaffolds)
- [ ] No watch-mode flags
- [ ] Feedback latency < 30 s (quick) / 360 s (full)
- [ ] `nyquist_compliant: true` set in frontmatter
- [ ] All 11 `TagPipeline:*` error IDs have assertable tests
- [ ] Octave parity confirmed for every functional behavior

**Approval:** pending
