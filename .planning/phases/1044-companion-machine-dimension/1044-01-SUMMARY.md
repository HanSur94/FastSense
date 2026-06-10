---
phase: 1044-companion-machine-dimension
plan: "01"
subsystem: Fleet
tags: [accessor, insertion-order, octave-parity]
requirements: [MACH-01]

dependency_graph:
  requires: []
  provides:
    - "Fleet.machineIds() public insertion-order accessor (UI-SPEC planner flag resolved)"
  affects:
    - libs/Fleet/Fleet.m
    - tests/test_fleet.m

tech_stack:
  added: []
  patterns:
    - "one-liner accessor mirroring machineCount() — returns the private MachineIds_ cell"

key_files:
  created: []
  modified:
    - libs/Fleet/Fleet.m
    - tests/test_fleet.m

decisions:
  - "Expose MachineIds_ verbatim (cell of char, insertion order) — no sorting, no copy semantics change"

metrics:
  commit: 8018da16
  tests: "tests/test_fleet.m — 6/6 pass (incl. new insertion-order assertion)"
---

# Plan 1044-01 Summary

`Fleet.machineIds()` public accessor added (+6 lines): returns the insertion-order cell of machine Ids that `MachineSelectorPane` iterates. `test_fleet.m` extended with an insertion-order assertion (add M01/M02/M03 → `machineIds()` returns exactly that order). Executed by the background execution agent; verified in main session: `test_fleet.m` 6/6 pass, MISS_HIT-clean.

**Deviations:** none.
