---
phase: 1044-companion-machine-dimension
plan: "05"
subsystem: tests
tags: [class-suite, timer-invariant, backward-compat]
requirements: [MACH-02, MACH-03, MACH-04, MACH-05]

dependency_graph:
  requires: ["1044-04"]
  provides:
    - "testMachineSwitch_ActiveContext (MACH-02)"
    - "testActiveMachineLabel (MACH-03)"
    - "testMachineSwitch_TimerStable (MACH-04 — 5 live switches, timerfindall flat)"
    - "testLegacyConstruction_Unchanged (MACH-05 — [3 3], no selector/label, [1 10] toolbar)"
  affects:
    - tests/suite/TestFastSenseCompanion.m

tech_stack:
  added: []
  patterns:
    - "struct(app) private-field access + closeIfOpen_ teardown + inherited gateModernMatlab/gateHeadlessLinux/skipOnOctave guards"

key_files:
  created: []
  modified:
    - tests/suite/TestFastSenseCompanion.m

decisions:
  - "Label assertion tolerant of prefix glyph (asserts 'Name [Id]' substring, not char(9658)) — survives ASCII fallback"

metrics:
  commit: 48ea44ad
  tests: "suite 82/84 — all 4 new tests GREEN; the 2 failures are the pre-existing PerTag/ADHOC05 orphan-timer flake pair (each passes in isolation; they alternate across full runs; ad-hoc plot path only, no Fleet involvement)"
---

# Plan 1044-05 Summary

Four class-suite tests convert all four phase success criteria from manually-verified to automatically-verified, including the highest-value MACH-04 timer-accumulation invariant. Suite: 82/84 with all new tests green; flat companions `test_fleet.m` 6/6 and `test_machine_selector_pane.m` 5/5.

**Deviations:** none. Phase-gate note: the full-repo `run_all_tests.m` pass was scoped to the affected suites per CLAUDE.md ("full runs only when the user asks" — MATLAB desktop is live on the user's screen); the companion suite + both flat tests + the documented flake-isolation evidence stand in as the gate.
