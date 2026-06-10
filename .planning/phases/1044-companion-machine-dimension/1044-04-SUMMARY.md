---
phase: 1044-companion-machine-dimension
plan: "04"
subsystem: FastSenseCompanion
tags: [redirect, machine-switch, timer-lifecycle, listener-hygiene]
requirements: [MACH-02, MACH-03, MACH-04]

dependency_graph:
  requires: ["1044-03"]
  provides:
    - "four TagRegistry.find sites redirected to active machine (explicit conditionals; legacy static path intact)"
    - "onMachineSelected_: stop-live -> setProject(machine.Dashboards, machine) -> indicator -> restart-live"
    - "updateActiveMachineIndicator_: char(9658)/'>' prefix + 'Name [Id]' + tooltip"
    - "auto-select first machine at construction (Step 6 context override)"
    - "setProject re-wires the MachineSelectionChanged listener"
  affects:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - libs/FastSenseCompanion/TagCatalogPane.m

tech_stack:
  added: []
  patterns:
    - "explicit conditional redirect (RESEARCH Pitfall 3): isa(obj.Registry_,'TagRegistry') branch in panes; isempty(obj.Fleet_) branch in companion"
    - "stop-before-start with timer reuse (stopLiveMode stops-not-deletes) — timerfindall flat"

key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m
    - libs/FastSenseCompanion/TagCatalogPane.m

decisions:
  - "DEVIATION (justified): auto-select-first implemented as a Step 6 context override (Registry_/Engines_/Dashboards set to machine 1 BEFORE panes attach) instead of the plan's constructor setProject call. Rationale: setProject mid-construction re-wires its fixed listener set and the constructor then wires the same listeners again -> double handlers. Same truths (active context never empty; indicator populated; selector highlighted via selectById before its listener exists -> no redundant rebuild)."
  - "setProject extended to re-wire MachineSelectionChanged (its clear-all would otherwise kill the selector after the first switch) — gap not covered by the plan, required for repeated switches"

metrics:
  commit: de07e98a
  tests: "live smoke 7/7 (indicator, per-machine catalog scoping 1->2 tags, 5 live switches timer-flat, IsLive preserved, clean close); check_matlab_code clean on both files"
---

# Plan 1044-04 Summary

The machine dimension goes live: all four `TagRegistry.find` sites (`TagCatalogPane.m:63/213`, `FastSenseCompanion.m` onLiveTick_ pair) branch to the active machine's `.find()` in fleet mode while preserving the byte-identical legacy static path. `onMachineSelected_` performs the locked switch sequence; `updateActiveMachineIndicator_` renders `▶ Name [Id]` with ASCII fallback; construction auto-selects machine 1.

**Deviations:** two, both listener-hygiene-driven (documented above) — the plan's literal construction order would have double-wired listeners, and the plan missed that `setProject`'s clear-all kills the selector listener. Both verified by the 5-switch smoke (selector stayed live across all switches).
