---
phase: 1044-companion-machine-dimension
plan: "02"
subsystem: FastSenseCompanion
tags: [uilistbox, debounce, octave-parity, left-rail]
requirements: [MACH-01]

dependency_graph:
  requires: []
  provides:
    - "MachineSelectorPane class (attach/detach/refresh/selectById; MachineSelectionChanged event)"
    - "MachineSelectionEventData (immutable MachineId payload)"
    - "private/filterMachines.m (strfind(lower()) over Name+Id, insertion order)"
  affects:
    - libs/FastSenseCompanion/MachineSelectorPane.m
    - libs/FastSenseCompanion/MachineSelectionEventData.m
    - libs/FastSenseCompanion/private/filterMachines.m
    - libs/FastSenseCompanion/runFilterMachinesTests.m
    - tests/test_machine_selector_pane.m

tech_stack:
  added: []
  patterns:
    - "TagCatalogPane idiom copied verbatim: uilistbox Items/ItemsData + search uieditfield + 150ms singleShot debounce timer (StartDelay, stop;delete teardown)"
    - "filterTags.m idiom: strfind(lower(...)), never contains — Octave-safe"
    - "selectById(id) public test seam (mirrors getSelectedKeys precedent)"

key_files:
  created:
    - libs/FastSenseCompanion/MachineSelectorPane.m
    - libs/FastSenseCompanion/MachineSelectionEventData.m
    - libs/FastSenseCompanion/private/filterMachines.m
    - libs/FastSenseCompanion/runFilterMachinesTests.m
    - tests/test_machine_selector_pane.m
  modified: []

decisions:
  - "Per-row label: Name primary + dim Group secondary; Id via control-level tooltip (uilistbox has no per-item tooltips in R2020b — UI-SPEC documented workaround)"
  - "'No machines match' placeholder on zero matches (pane placeholder convention)"

metrics:
  commit: 13a87fb9
  tests: "tests/test_machine_selector_pane.m — 5/5 pass (filterMachines pure logic, Octave-safe)"
---

# Plan 1044-02 Summary

`MachineSelectorPane` (279 lines) — the left-rail machine list: uilistbox + debounced search copied structurally from `TagCatalogPane` minus pill filters/grouping, firing `MachineSelectionChanged(MachineSelectionEventData(MachineId))`. `filterMachines` helper does free-text substring over Name+Id in fleet insertion order. Executed by the background execution agent; verified in main session: flat test 5/5 pass, theme walker covers the new controls with no changes.

**Deviations:** none.
