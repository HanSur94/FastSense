---
phase: 1005
slug: sensortag-statetag-data-carriers
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1005 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` (MATLAB) + Octave flat-assert |
| **Config file** | None — auto-discovery in `tests/run_all_tests.m` |
| **Quick run command** | `octave --eval "install(); test_sensortag(); test_statetag(); test_fastsense_addtag();"` |
| **Full suite command** | `octave --eval "install(); cd tests; run_all_tests()"` |
| **Benchmark** | `octave --eval "install(); bench_sensortag_getxy()"` |
| **Estimated runtime** | ~30s quick · ~90s full · ~10s bench |

## Sampling Rate

- **After every task commit:** Quick run
- **After every plan wave:** Full suite + bench
- **Before `/gsd:verify-work`:** Full suite green on MATLAB + Octave; bench shows ≤5% regression
- **Max feedback latency:** ~30s per-task · ~90s full

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1005-01-01 | 01 | 1 | TAG-08 | unit RED | `runtests('tests/suite/TestSensorTag')` expected red | ❌ W0 | ⬜ |
| 1005-01-02 | 01 | 1 | TAG-08 | unit GREEN | `runtests('tests/suite/TestSensorTag')` exits 0 | ❌ W0 | ⬜ |
| 1005-02-01 | 02 | 1 | TAG-09 | unit RED | `runtests('tests/suite/TestStateTag')` expected red | ❌ W0 | ⬜ |
| 1005-02-02 | 02 | 1 | TAG-09 | unit GREEN | `runtests('tests/suite/TestStateTag')` exits 0 | ❌ W0 | ⬜ |
| 1005-03-01 | 03 | 2 | TAG-10 | integration RED | `runtests('tests/suite/TestFastSenseAddTag')` red | ❌ W0 | ⬜ |
| 1005-03-02 | 03 | 2 | TAG-10 | integration GREEN | `runtests('tests/suite/TestFastSenseAddTag')` exits 0 | ❌ W0 | ⬜ |
| 1005-03-03 | 03 | 2 | TAG-10 | registry extension | `TestTagRegistry.testRoundTripSensorTag`, `...StateTag` green | ❌ W0 | ⬜ |
| 1005-04-01 | 04 | 3 | Pitfall 9 | benchmark | `bench_sensortag_getxy()` exits 0 with overhead_pct ≤ 5 | ❌ W0 | ⬜ |
| 1005-04-02 | 04 | 3 | Pitfall 1, 5 | static | grep checks + file-budget verification | ✅ Bash | ⬜ |

## Wave 0 Requirements

- [ ] `tests/suite/TestSensorTag.m` (covers TAG-08, ~16 tests)
- [ ] `tests/suite/TestStateTag.m` (covers TAG-09, ~14 tests)
- [ ] `tests/suite/TestFastSenseAddTag.m` (covers TAG-10, ~8 tests)
- [ ] `tests/test_sensortag.m` (Octave flat mirror)
- [ ] `tests/test_statetag.m` (Octave flat mirror)
- [ ] `tests/test_fastsense_addtag.m` (Octave flat mirror)
- [ ] `benchmarks/bench_sensortag_getxy.m` (Pitfall 9 gate)
- [ ] Extend `tests/suite/TestTagRegistry.m` with 2 round-trip tests for `'sensor'` + `'state'` kinds
- [ ] Extend `tests/test_tag_registry.m` with matching Octave assertions

Framework already installed. No new install step.

## Manual-Only Verifications

*None — all behaviors have automated verification.*

## Pitfall Gate → Verification Command

| Gate | Verification Command |
|------|----------------------|
| Pitfall 1 (no `isa` on subclass names in addTag) | `grep -c "isa(.*SensorTag\\|isa(.*StateTag" libs/FastSense/FastSense.m` → 0 |
| Pitfall 5 (legacy untouched, ≤15 file budget) | `git diff --name-only <phase-start>..HEAD -- libs/SensorThreshold/Sensor.m libs/SensorThreshold/StateChannel.m` → empty; total touched ≤ 15 |
| Pitfall 9 (≤5% perf regression on getXY) | `bench_sensortag_getxy()` reports `overhead_pct ≤ 5` |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity preserved
- [ ] Wave 0 covers all MISSING references
- [ ] Bench runs headless (no GUI)
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
