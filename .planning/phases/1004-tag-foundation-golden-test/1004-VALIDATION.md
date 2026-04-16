---
phase: 1004
slug: tag-foundation-golden-test
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1004 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` (MATLAB) + function-style `test_*.m` (Octave) |
| **Config file** | None — auto-discovery in `tests/run_all_tests.m` |
| **Quick run command** | `matlab -batch "install; runtests('tests/suite/TestTag.m'); runtests('tests/suite/TestTagRegistry.m')"` |
| **Full suite command** | `matlab -batch "cd tests; run_all_tests()"` |
| **Estimated runtime** | ~90 seconds (full suite); ~8 seconds (Phase-1004 scope) |

---

## Sampling Rate

- **After every task commit:** Run quick run command (Phase-1004-scoped tests)
- **After every plan wave:** Run full suite command (regression guard — Success Criterion 4)
- **Before `/gsd:verify-work`:** Full suite must be green on both MATLAB and Octave
- **Max feedback latency:** ~8 seconds (per-task); ~90 seconds (full suite)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1004-01-01 | 01 | 0 | Wave 0 stubs | setup | n/a (creates test files) | ❌ — Wave 0 creates | ⬜ pending |
| 1004-02-01 | 02 | 1 | TAG-01, TAG-02 | unit | `runtests('tests/suite/TestTag.m')` | ❌ W0 | ⬜ pending |
| 1004-02-02 | 02 | 1 | META-01, META-03, META-04 | unit | `TestTag.testLabelsDefault/Assign`, `testMetadataOpenStruct`, `testCriticalityValidation` | ❌ W0 | ⬜ pending |
| 1004-03-01 | 03 | 2 | TAG-03, TAG-04 | unit | `runtests('tests/suite/TestTagRegistry.m')` | ❌ W0 | ⬜ pending |
| 1004-03-02 | 03 | 2 | TAG-05 | unit | `TestTagRegistry.testList`, `testPrintTable` | ❌ W0 | ⬜ pending |
| 1004-03-03 | 03 | 2 | TAG-06, TAG-07, META-02 | unit | `TestTagRegistry.testLoadFromStructs*`, `testRoundTripMultipleTags`, `testFindByLabel` | ❌ W0 | ⬜ pending |
| 1004-04-01 | 04 | 3 | MIGRATE-01 | integration | `runtests('tests/suite/TestGoldenIntegration.m')` | ❌ W0 | ⬜ pending |
| 1004-05-01 | 05 | 3 | MIGRATE-02 | static | `git diff --name-only main...HEAD \| wc -l` ≤20; forbidden-path grep returns 0 | ✅ Bash-runnable | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/suite/MockTag.m` — minimal concrete Tag subclass for registry tests (implements all 6 abstract methods with trivial stubs)
- [ ] `tests/suite/TestTag.m` — stubs for TAG-01, TAG-02, META-01, META-03, META-04
- [ ] `tests/suite/TestTagRegistry.m` — stubs for TAG-03, TAG-04, TAG-05, TAG-06, TAG-07, META-02
- [ ] `tests/suite/TestGoldenIntegration.m` — stubs for MIGRATE-01
- [ ] `tests/test_tag.m` — Octave flat-style port
- [ ] `tests/test_tag_registry.m` — Octave flat-style port
- [ ] `tests/test_golden_integration.m` — Octave flat-style port

**No framework install needed** — `matlab.unittest` ships with MATLAB; Octave uses function-style `assert`. Auto-discovery in `tests/run_all_tests.m:34, 77` picks both styles up with zero runner changes.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| `TagRegistry.viewer()` opens an Octave-safe uitable | TAG-05 | GUI dialog requires a display; headless CI cannot assert window content | Run `TagRegistry.viewer()` in MATLAB session; confirm uitable opens with all columns visible and sortable |

---

## Pitfall Gate → Verification Command

| Gate | Verification Command |
|------|----------------------|
| Pitfall 1 (≤6 abstract methods) | `grep -c "notImplemented" libs/SensorThreshold/Tag.m` → ≤6 |
| Pitfall 5 (≤20 files, no legacy edits) | `git diff --name-only main...HEAD \| wc -l` ≤20 AND forbidden-path grep returns 0 |
| Pitfall 7 (hard-error collision) | `TestTagRegistry.testDuplicateRegisterErrors` green |
| Pitfall 8 (two-pass + 3-deep round trip) | `TestTagRegistry.testLoadFromStructsOrderInsensitive` + `testLoadFromStructsMissingRefErrors` green |
| Pitfall 11 (golden test "DO NOT REWRITE" marker) | `grep -c "DO NOT REWRITE" tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` → 2 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
