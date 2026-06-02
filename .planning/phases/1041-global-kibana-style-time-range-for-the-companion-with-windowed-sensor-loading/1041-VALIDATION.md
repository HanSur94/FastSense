---
phase: 1041
slug: global-kibana-style-time-range-for-the-companion-with-windowed-sensor-loading
status: draft
nyquist_compliant: true
wave_0_complete: false
created: 2026-06-02
---

# Phase 1041 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 1041-RESEARCH.md "## Validation Architecture". Per-task map is filled by the planner / nyquist-auditor.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` class suites (`tests/suite/Test*.m`) + Octave-style function tests (`tests/test_*.m`) |
| **Config file** | none — `tests/run_all_tests.m` discovers tests |
| **Quick run command** | single file via MATLAB MCP: `run_matlab_test_file` for `Test*.m`; `evaluate_matlab_code` calling the function for `test_*.m` |
| **Full suite command** | `tests/run_all_tests.m` (via `run_matlab_file`) |
| **Estimated runtime** | single file ~seconds; full suite minutes (avoid full runs while iterating) |

**Runtime split (from RESEARCH Q7):**
- **Octave-safe (run in both MATLAB + Octave):** `getXYRange` (disk + RAM), `getTimeRange` disk-backed fix, `FastSenseDataStore` extent. Use binary_search + slicing + mksqlite.
- **MATLAB-only (uifigure):** `CompanionTimeBar`, `CompanionTimeRange` event firing, companion integration. Guard function-style tests with `if exist('OCTAVE_VERSION', 'builtin') ~= 0; return; end` (existing companion env-skip pattern).

---

## Sampling Rate

- **After every task commit:** Run the quick command for the test file(s) touching that task.
- **After every plan wave:** Run the affected suite files (data-layer suite, companion suite).
- **Before `/gsd:verify-work`:** Full suite must be green in MATLAB; Octave-safe subset green in Octave.
- **Max feedback latency:** < 60 seconds for the single-file quick run.

---

## Per-Task Verification Map

> Populated by the planner from the tasks it creates. Each task must map to an automated MATLAB/Octave test or a Wave 0 stub. Validation targets (from RESEARCH "## Validation Architecture"):
>
> - Windowed read returns only in-range points — disk-backed (`getRange`) AND in-RAM (slice).
> - Boundary / empty / inverted / out-of-extent ranges handled (empty result, no error).
> - `SensorTag.getTimeRange()` disk-backed returns non-NaN `[XMin, XMax]`.
> - `Tag` base `getXYRange` default slices full `getXY()` output for derived/composite/state/monitor tags.
> - `CompanionTimeRange` relative→absolute resolution (Last N units → now in datenum) + `RangeChanged` fires once per edit.
> - Opened plot/sensor-detail loads a **bounded** point count (assert << full series for a disk-backed sensor).
> - `RangeChanged` re-queries tracked open views (ad-hoc via `getappdata(hFig,'DashboardEngine')`, managed via `Engines_`).
> - Mixed-extent tag (data outside the window) → "no data in selected range" empty-state, no crash.

| Task ID | Plan | Wave | Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|----------|-----------|-------------------|-------------|--------|
| P01-T1 | 01 | 1 | `Tag.getXYRange` default slice + `SensorTag` override (disk + RAM) | unit | `test_sensor_tag_range()` | `tests/test_sensor_tag_range.m` | ⬜ |
| P01-T2 | 01 | 1 | `SensorTag.getTimeRange()` disk returns `[XMin, XMax]` (not `[NaN NaN]`) | unit | `test_sensor_tag_range()` | `tests/test_sensor_tag_range.m` | ⬜ |
| P02-T1 | 02 | 2 | `CompanionTimeRange.resolve()` relative + absolute + all; `RangeChanged` fires once per edit | unit | `test_companion_time_range()` | `tests/test_companion_time_range.m` | ⬜ |
| P03-T1 | 03 | 3 | `DashboardEngine.setTimeWindow` fans window to all widgets | unit | `test_dashboard_time_window()` | `tests/test_dashboard_time_window.m` | ⬜ |
| P03-T2 | 03 | 3 | `FastSenseWidget` windowed pull + empty-state label | unit | `test_dashboard_time_window()` | `tests/test_dashboard_time_window.m` | ⬜ |
| P04-T1 | 04 | 4 | `CompanionTimeBar` range button (Tag, col 9, label, color) | UI/integration | `run_matlab_test_file('tests/suite/TestCompanionTimeBar.m')` | `tests/suite/TestCompanionTimeBar.m` | ⬜ |
| P04-T2 | 04 | 4 | Picker singleton 400x280, preset fires RangeChanged + closes | UI/integration | `run_matlab_test_file('tests/suite/TestCompanionTimeBar.m')` | `tests/suite/TestCompanionTimeBar.m` | ⬜ |
| P05-T1 | 05 | 4 | `RangeChanged` re-queries managed + ad-hoc engines via spy | integration | `run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` | `tests/suite/TestFastSenseCompanion.m` | ⬜ |
| P05-T2 | 05 | 4 | `currentTimeWindow()` returns correct resolved window at open-site seam | integration | `run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` | `tests/suite/TestFastSenseCompanion.m` | ⬜ |
| P05-T3 | 05 | 4 | Picker visuals + relative-slide on live tick | MANUAL | See `1041-MANUAL-VERIFY.md` | `1041-MANUAL-VERIFY.md` | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] Data-layer test file(s) for `getXYRange` / `getTimeRange` disk-fix (`tests/test_*.m` Octave-safe + `tests/suite/Test*.m`)
- [ ] `CompanionTimeRange` resolution test (`tests/suite/TestCompanionTimeRange.m`, MATLAB-only)
- [ ] Reuse existing fixtures/data-builders where present (no new framework — repo is toolbox-free)

*Planner refines exact file names.*

---

## Manual-Only Verifications

| Behavior | Why Manual | Test Instructions |
|----------|------------|-------------------|
| `CompanionTimeBar` picker visuals + popup interaction (presets/relative/absolute) | uifigure rendering on-screen; not headless-assertable | Open companion in MATLAB, click the range button, exercise each tab, confirm label updates and open views re-query |
| Relative-window slide on live tick | timing/visual | Open a live-to-today sensor with "Last 7 days", let live ticks advance, confirm the window slides |

*Data-layer behaviors all have automated verification.*

---

## Validation Sign-Off

- [x] All tasks have an automated verify or a manual-checklist entry (P05-T3)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (test files created Plans 01-05)
- [x] No watch-mode flags
- [x] Feedback latency < 60s (single-file quick runs)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** pending human run of 1041-MANUAL-VERIFY.md
