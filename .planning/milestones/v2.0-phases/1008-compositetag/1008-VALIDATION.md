---
phase: 1008
slug: compositetag
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1008 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` + Octave flat-assert |
| **Quick run** | `octave --no-gui --eval "install(); test_compositetag(); test_compositetag_align();"` |
| **Full suite** | `octave --no-gui --eval "install(); run_all_tests();"` |
| **Benchmark** | `octave --no-gui --eval "install(); bench_compositetag_merge();"` |

## Per-Task Verification Map

| Task | Plan | Wave | Req | Automated Command |
|------|------|------|-----|-------------------|
| 1008-01-01 | 01 | 1 | COMPOSITE-01..04, 07 RED | test_compositetag expected red |
| 1008-01-02 | 01 | 1 | COMPOSITE-01..04, 07 GREEN | runtests TestCompositeTag exits 0 |
| 1008-02-01 | 02 | 2 | COMPOSITE-05, 06, ALIGN-01..04 RED | test_compositetag_align red |
| 1008-02-02 | 02 | 2 | COMPOSITE-05, 06, ALIGN-01..04 GREEN | merge-sort green + 3-deep round-trip |
| 1008-03-01 | 03 | 3 | Pitfall 3 bench | bench_compositetag_merge asserts output-size ≤ 1.1×Σchild + time ≤ 200ms |
| 1008-03-02 | 03 | 3 | Phase audit | file budget ≤8; all grep gates pass |

## Wave 0 Requirements
- [ ] `libs/SensorThreshold/CompositeTag.m` (new)
- [ ] `libs/SensorThreshold/TagRegistry.m` edit — 'composite' case
- [ ] `libs/FastSense/FastSense.m` edit — 'composite' case
- [ ] `tests/suite/TestCompositeTag.m`
- [ ] `tests/test_compositetag.m`
- [ ] `tests/suite/TestCompositeTagAlign.m`
- [ ] `tests/test_compositetag_align.m`
- [ ] `benchmarks/bench_compositetag_merge.m`

## Pitfall Gate → Verification Command

| Gate | Verification |
|------|--------------|
| Pitfall 3 (no N×M blowup) | `grep -c "union\\|interp1" libs/SensorThreshold/CompositeTag.m` → 0; bench output-size ≤ 1.1 × Σ child samples |
| Pitfall 6 (truth tables in header) | `grep -c "| 0  | 0  |\\|Truth Table" libs/SensorThreshold/CompositeTag.m` ≥ 1 |
| Pitfall 8 (3-deep round-trip) | `testRoundTrip3DeepComposite` green |
| ALIGN-01 (no interp1 linear) | `grep -c "interp1.*'linear'" libs/SensorThreshold/CompositeTag.m` → 0 |
| ALIGN-04 (NaN truth tables) | Tests cover every mode × {0,1,NaN} combination |
| Cycle detection | `testCycleDetectionSelf` + `testCycleDetectionDeeper` green |
| Child-type guard | `testRejectSensorTagChild` + `testRejectStateTagChild` green |

## Validation Sign-Off

- [ ] All tasks have automated verify
- [ ] Wave 0 covers MISSING refs
- [ ] Bench headless
- [ ] `nyquist_compliant: true` after green

**Approval:** pending
