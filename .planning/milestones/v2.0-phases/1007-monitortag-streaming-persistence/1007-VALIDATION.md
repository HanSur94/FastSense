---
phase: 1007
slug: monitortag-streaming-persistence
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-16
---

# Phase 1007 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `matlab.unittest` + Octave flat-assert |
| **Config file** | None — `tests/run_all_tests.m` auto-discovery |
| **Quick run command** | `octave --no-gui --eval "install(); test_monitortag_streaming(); test_monitortag_persistence();"` |
| **Full suite command** | `octave --no-gui --eval "install(); run_all_tests();"` |
| **Benchmark** | `octave --no-gui --eval "install(); bench_monitortag_append();"` |
| **Estimated runtime** | ~15s quick · ~120s full · ~20s bench |

## Sampling Rate
- **After task commit:** Quick run
- **After wave merge:** Full suite + bench
- **Phase gate:** All grep/bench gates pass before verify-work

## Per-Task Verification Map

| Task | Plan | Wave | Req | Automated Command |
|------|------|------|-----|-------------------|
| 1007-01-01 | 01 | 1 | MONITOR-08 RED | `runtests('tests/suite/TestMonitorTagStreaming')` expected red |
| 1007-01-02 | 01 | 1 | MONITOR-08 GREEN | streaming appendData green + hysteresis/debounce continuity green |
| 1007-02-01 | 02 | 2 | MONITOR-09 RED | `runtests('tests/suite/TestMonitorTagPersistence')` expected red |
| 1007-02-02 | 02 | 2 | MONITOR-09 GREEN | Persist round-trip green; opt-in default off |
| 1007-03-01 | 03 | 3 | Pitfall 9 bench | `bench_monitortag_append()` exits 0; ratio ≥ 5 |
| 1007-03-02 | 03 | 3 | Pitfall 2 structural | grep structural check: storeMonitor always inside `if obj.Persist` |

## Wave 0 Requirements

- [ ] `tests/suite/TestMonitorTagStreaming.m` (appendData + boundary state continuity)
- [ ] `tests/test_monitortag_streaming.m` (Octave mirror)
- [ ] `tests/suite/TestMonitorTagPersistence.m` (Persist round-trip + staleness detection)
- [ ] `tests/test_monitortag_persistence.m` (Octave mirror)
- [ ] `benchmarks/bench_monitortag_append.m` (Pitfall 9 5x gate)
- [ ] MonitorTag.m edits (additive — appendData + Persist + 3 new cache fields + load-skip branch)
- [ ] FastSenseDataStore.m edits (additive — storeMonitor/loadMonitor/clearMonitor + monitors table migration)

No new framework install needed.

## Manual-Only Verifications

*None — all behaviors have automated verification.*

## Success Criterion 4 Acknowledgment

**Phase goal Success Criterion #4** ("LiveEventPipeline live-tick path uses appendData and produces correct events at >= the legacy throughput") is **DEFERRED to Phase 1009 (Consumer migration)** per RESEARCH §4. Reason: LEP rewire adds 2-3 files, blowing the ≤8 file budget (Pitfall 5) and belongs naturally in the consumer-migration phase.

**Deferred-to-1009 checkpoint:** Phase 1007 ships appendData as a READY API + bench + tests. Phase 1009 will wire LEP to MonitorTag.appendData when migrating EventDetection consumers. Verified at Phase 1007 exit via a smoke test showing `appendData` works stand-alone; full LEP integration deferred.

## Pitfall Gate → Verification Command

| Gate | Verification |
|------|----|
| Pitfall 2 structural (storeMonitor only when Persist=true) | manual inspection of `if obj.Persist` guard in MonitorTag.m + test `testPersistFalseSkipsSQLite` (assert DataStore sqlite log / table count unchanged) |
| Pitfall 5 file-touch ≤8 | `git diff --name-only <phase-start>..HEAD` count ≤8 |
| Pitfall 9 (appendData ≥5x) | `bench_monitortag_append()` prints `ratio >= 5` or `PASS: >= 5x speedup` |

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify
- [ ] Sampling continuity preserved
- [ ] Wave 0 covers MISSING refs
- [ ] Bench headless
- [ ] `nyquist_compliant: true` in frontmatter after all tasks green

**Approval:** pending
