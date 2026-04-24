---
phase: 1012
slug: live-event-markers-and-click-to-details-on-fastsense-and-fastsensewidget
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-04-24
---

# Phase 1012 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Dual: MATLAB test suite (`tests/suite/Test*.m`) + Octave function-based (`tests/test_*.m`) — mirrored, both must pass |
| **Config file** | `tests/run_all_tests.m` (custom runner, no pytest-style config) |
| **Quick run command** | `matlab -batch "install; runTestsMatching('Event')"` (subset of tests touching `Event`/`EventStore`/`MonitorTag` + the new FastSense/FastSenseWidget tests) |
| **Full suite command** | `matlab -batch "install; cd tests; run_all_tests"` (MATLAB) and `octave --no-gui --eval "addpath('tests'); run_all_tests"` (Octave) |
| **Estimated runtime** | Quick: ~30s · Full: ~5-8min (MATLAB) · Full: ~8-12min (Octave) |

---

## Sampling Rate

- **After every task commit:** Run quick subset (touching files in the task's `files_modified`).
- **After every plan wave:** Run full suite in MATLAB AND Octave — dual runtime parity is a project-level non-negotiable (CLAUDE.md lists both as primary targets).
- **Before `/gsd:verify-work`:** Full suite green in both MATLAB and Octave.
- **Max feedback latency:** 60s per-task, 12min per-wave.

---

## Per-Task Verification Map

*Filled by planner after task breakdown. Every task must declare an `<automated>` verify command OR depend on Wave 0 test-infrastructure tasks.*

| Task ID | Plan | Wave | Area | Test Type | Automated Command | File Exists | Status |
|---------|------|------|------|-----------|-------------------|-------------|--------|
| TBD — planner fills | | | | | | | |

---

## Wave 0 Requirements

Wave 0 must land before any production code in later waves. Requirements:

- [ ] `tests/suite/TestEventIsOpen.m` — schema test stubs: `Event` has `IsOpen` property default `false`; `EventStore.closeEvent(id,endT,stats)` updates in place; `IsOpen` round-trips through `save`/`load` on a Phase-1010-era `.mat` file without migration.
- [ ] `tests/suite/TestMonitorTagOpenEvent.m` — stubs: rising edge on `MonitorTag.appendData` emits an `IsOpen=true` Event with `EndTime=NaN`; falling edge calls `closeEvent` with updated running stats.
- [ ] `tests/suite/TestFastSenseEventClick.m` — stubs: per-marker `ButtonDownFcn` wires `UserData.eventId`; click opens a `uipanel`; ESC / click-outside / X-button all dismiss; open-event marker is hollow.
- [ ] `tests/suite/TestFastSenseWidgetEventMarkers.m` — stubs: `ShowEventMarkers` + `EventStore` properties; round-trip `toStruct`/`fromStruct` (omit when default); `refresh()` diffs `LastEventIds_` cache.
- [ ] `tests/test_event_is_open.m`, `tests/test_monitortag_open_event.m`, `tests/test_fastsense_event_click.m`, `tests/test_fastsense_widget_event_markers.m` — Octave-parallel function-based stubs (same assertions, Octave-compat idioms: bare `catch`, no `arguments`, `try` for `uipanel` property quirks).
- [ ] `bench_event_marker_regression.m` — Pitfall-10 guard: 12-line FastSense plot, zero attached events, median render time across 20 iterations vs. pre-phase baseline (≤5% regression gate).

*None of these test files should exist yet — Wave 0's job is to create them.*

---

## Manual-Only Verifications

| Behavior | Why Manual | Test Instructions |
|----------|------------|-------------------|
| Click-details `uipanel` visually anchors near the clicked marker without clipping the figure edge | Rendering geometry is figure-size-dependent; automation would require screenshot diff infrastructure the project doesn't have | Open `example_event_markers.m`, trigger an event in live mode, click the marker, verify the panel appears adjacent and readable on both a 1440×900 and a 2560×1440 figure |
| ESC closes the panel while `zoom`/`pan` axes-interaction mode is active | MATLAB's pan/zoom captures `WindowKeyPressFcn`; proving the hook still fires needs human input | In the example above, click the zoom toolbar, click an event marker, press ESC — panel must close, zoom cursor must remain |
| Open-event marker visibly transitions to filled on close (live demo) | Timing-sensitive live behavior | Run `example_event_markers.m` with an intentionally long simulated threshold violation; watch the hollow marker appear at rising edge and fill on fall |
| Octave `uipanel` click-outside detection does not regress when multiple FastSense widgets share a figure | Octave 7+ `WindowButtonDownFcn` has known edge cases with nested panels | Two-widget dashboard in Octave; click event in widget A; click in widget B's axes; widget A's panel must close |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify commands OR explicit Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verification
- [ ] Wave 0 covers all MISSING test files, benchmarks, and example scripts
- [ ] No watch-mode flags in any test invocation
- [ ] Feedback latency < 60s per-task, < 12min per-wave
- [ ] Both MATLAB and Octave runs green in the phase-exit bundle
- [ ] Pitfall-10 bench (zero-event render) ≤5% regression
- [ ] `nyquist_compliant: true` set in frontmatter after planner fills the verification map

**Approval:** pending
