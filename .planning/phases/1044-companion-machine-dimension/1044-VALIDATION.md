---
phase: 1044
slug: companion-machine-dimension
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-06-08
---

# Phase 1044 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Derived from 1044-RESEARCH.md `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest.TestCase` (class suites) + Octave function-based (flat `test_*.m`) |
| **Config file** | `tests/run_all_tests.m` (discovery); class suites in `tests/suite/` |
| **Quick run command** | `mcp__matlab__run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` |
| **Full suite command** | `mcp__matlab__run_matlab_file('tests/run_all_tests.m')` |
| **Estimated runtime** | ~30–90 s (single companion suite); full suite minutes |

Pure-logic helpers (machine-list filtering, `Fleet.machineIds()`, implicit-Machine wrapping) are **Octave-flat-testable** headless. uifigure construction, machine switch, active-machine label, and the timer-accumulation invariant require a **MATLAB class suite** with the existing `gateHeadlessLinux` / `skipOnOctave` guards.

---

## Sampling Rate

- **After every task commit:** Run the relevant quick command — `test_machine_selector_pane.m` / `test_fleet.m` (Octave-safe logic) on flat-logic tasks; `TestFastSenseCompanion.m` (MATLAB) on UI tasks
- **After every plan wave:** `test_fleet.m` + `test_machine_selector_pane.m` + `TestFastSenseCompanion.m`
- **Before `/gsd-verify-work`:** Full suite (`run_all_tests.m`) green
- **Max feedback latency:** ~90 s (single suite)

---

## Per-Task Verification Map

> Task IDs assigned during planning (Wave 0 → Wave 4 sequencing from RESEARCH.md). Seeded at requirement granularity; planner/executor refine to task rows.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | W0 accessor | 0 | MACH-01 | — | N/A | unit | `mcp__matlab__run_matlab_file('tests/test_fleet.m')` | ✅ extend | ⬜ pending |
| TBD | selector pane | 1 | MACH-01 | — | N/A | unit | `mcp__matlab__run_matlab_file('tests/test_machine_selector_pane.m')` | ❌ W0 | ⬜ pending |
| TBD | switch wiring | 3 | MACH-02 | — | N/A | integration | `mcp__matlab__run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` | ❌ W4 | ⬜ pending |
| TBD | active indicator | 3 | MACH-03 | — | N/A | integration | same | ❌ W4 | ⬜ pending |
| TBD | timer lifecycle | 3 | MACH-04 | — | `timerfindall` stable across 5 switches (live on) | integration | same | ❌ W4 | ⬜ pending |
| TBD | backward-compat | 2/4 | MACH-05 | — | legacy `[3 3]` grid, no selector panel, `[1 10]` toolbar | integration | same | ❌ W4 extend | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

**Highest-value assertion (MACH-04):** `testMachineSwitch_TimerStable` — construct `FastSenseCompanion('Fleet', fleet)` with 3 machines, `startLiveMode()`, snapshot `numel(timerfindall)`, perform 5 alternating machine switches, assert count unchanged. The timer-accumulation invariant is the phase's core risk and is fully automatable.

---

## Wave 0 Requirements

- [ ] `tests/test_machine_selector_pane.m` — flat Octave-safe test for `filterMachines_` pure logic (empty term = all, term matches Name, term matches Id, no match = empty) — covers MACH-01
- [ ] `tests/test_fleet.m` — extend with `Fleet.machineIds()` insertion-order assertion
- [ ] `tests/suite/TestFastSenseCompanion.m` — extend with ≥4 new methods: `testMachineSwitch_ActiveContext` (MACH-02), `testActiveMachineLabel` (MACH-03), `testMachineSwitch_TimerStable` (MACH-04), `testLegacyConstruction_Unchanged` (MACH-05)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Left-rail column visual placement + hierarchy reads Machines ▸ Tags ▸ Dashboards ▸ Inspector | MACH-01/02 | On-screen layout aesthetics not assertable headless (figure renders on user's MATLAB desktop) | Construct `FastSenseCompanion('Fleet', fleet)` with ≥2 machines; confirm left rail with searchable machine list appears; confirm toolbar shows active-machine label |
| Theme propagation to new selector controls (dark/light) | MACH-01 | Visual color correctness | Toggle theme via settings; confirm machine list + label recolor (walker covers ListBox/EditField/Label automatically) |

*All four success-criteria behaviors have automated verification via the class suite; the above are visual-polish confirmations only.*

---

## Validation Sign-Off

- [ ] All tasks have automated verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (`test_machine_selector_pane.m`, TestFastSenseCompanion extensions)
- [ ] No watch-mode flags
- [ ] Feedback latency < 90s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
