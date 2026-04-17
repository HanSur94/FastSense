---
phase: 1006
slug: monitortag-lazy-in-memory
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1006 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` (MATLAB) + Octave flat-assert |
| **Config file** | None — auto-discovery in `tests/run_all_tests.m` |
| **Quick run command** | `octave --no-gui --eval "install(); test_monitortag(); test_monitortag_events();"` |
| **Full suite command** | `octave --no-gui --eval "install(); run_all_tests();"` |
| **Benchmark** | `octave --no-gui --eval "install(); bench_monitortag_tick();"` |
| **Estimated runtime** | ~15s quick · ~120s full · ~20s bench |

## Sampling Rate
- **After task commit:** Quick run
- **After wave merge:** Full suite + bench
- **Phase gate:** Full suite GREEN + bench PASS + all grep gates return expected counts

## Per-Task Verification Map

| Task | Plan | Wave | Req | Automated Command |
|------|------|------|-----|-------------------|
| 1006-01-01 | 01 | 1 | MONITOR-01..04, ALIGN-01..04 RED | `runtests('tests/suite/TestMonitorTag')` expected red |
| 1006-01-02 | 01 | 1 | MONITOR-01..04, ALIGN-01..04 GREEN | `runtests('tests/suite/TestMonitorTag')` exits 0 |
| 1006-02-01 | 02 | 2 | MONITOR-05..07, MONITOR-10 RED | `runtests('tests/suite/TestMonitorTagEvents')` expected red |
| 1006-02-02 | 02 | 2 | MONITOR-05..07, MONITOR-10 GREEN | `runtests('tests/suite/TestMonitorTagEvents')` exits 0 |
| 1006-03-01 | 03 | 3 | MONITOR-02 FastSense dispatch + round-trip | `testRoundTripMonitorTag` + FastSense addTag 'monitor' case green |
| 1006-03-02 | 03 | 3 | Pitfall 9 bench | `bench_monitortag_tick()` exits 0; overhead_pct ≤ 10 |
| 1006-03-03 | 03 | 3 | Pitfall gates | grep audits (5 gates) pass |

## Wave 0 Requirements
- [ ] `libs/SensorThreshold/MonitorTag.m` (new)
- [ ] `libs/SensorThreshold/SensorTag.m` additive edits — `addListener`, `listeners_`, `notifyListeners_`
- [ ] `libs/SensorThreshold/StateTag.m` additive edits — same
- [ ] `libs/SensorThreshold/TagRegistry.m` edit — `'monitor'` case in `instantiateByKind`
- [ ] `libs/FastSense/FastSense.m` edit — `'monitor'` case in `addTag`
- [ ] `tests/suite/TestMonitorTag.m`
- [ ] `tests/suite/TestMonitorTagEvents.m`
- [ ] `tests/test_monitortag.m`
- [ ] `tests/test_monitortag_events.m`
- [ ] `benchmarks/bench_monitortag_tick.m`
- [ ] `tests/suite/TestTagRegistry.m` extension (`testRoundTripMonitorTag`)
- [ ] `tests/test_tag_registry.m` extension

## Pitfall Gate → Verification Command

| Gate | Verification Command |
|------|----------------------|
| Pitfall 2 (no persistence) | `grep -c "FastSenseDataStore\\|storeMonitor\\|storeResolved" libs/SensorThreshold/MonitorTag.m` → 0 |
| Pitfall 5 (≤12 files, Sensor.resolve untouched) | File count + `git diff -- libs/SensorThreshold/Sensor.m libs/SensorThreshold/CompositeThreshold.m libs/SensorThreshold/Threshold.m libs/SensorThreshold/ThresholdRule.m libs/SensorThreshold/StateChannel.m libs/SensorThreshold/SensorRegistry.m libs/SensorThreshold/ThresholdRegistry.m` → empty |
| Pitfall 9 (bench ≤10%) | `bench_monitortag_tick()` prints `overhead_pct <= 10` token |
| MONITOR-10 (no per-sample) | `grep -cE "PerSample\\|OnSample\\|onEachSample" libs/SensorThreshold/MonitorTag.m` → 0 |
| ALIGN-01 (no linear interp) | `grep -c "interp1.*'linear'" libs/SensorThreshold/MonitorTag.m` → 0 |

## Special Note — Event TagKeys Carrier

**Critical discovery (research §2):** `Event.TagKeys` field DOES NOT EXIST yet (it's Phase 1010 scope — EVENT-01). Phase 1006 MonitorTag event emission uses the existing `Event.SensorName` and `Event.ThresholdLabel` fields as carriers:
- `Event.SensorName = parent.Key`
- `Event.ThresholdLabel = monitor.Key`

Test `testEventOnRisingEdge` asserts these carriers, not `TagKeys`. Phase 1010 will migrate via `Event.TagKeys = {..., ...}` and add proper EventBinding. Document this in MonitorTag class header.

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify
- [ ] Sampling continuity preserved
- [ ] Wave 0 covers all MISSING references
- [ ] Bench runs headless
- [ ] `nyquist_compliant: true` in frontmatter

**Approval:** pending
