---
phase: 1044-companion-machine-dimension
plan: "03"
subsystem: FastSenseCompanion
tags: [conditional-layout, backward-compat, toolbar]
requirements: [MACH-01, MACH-03, MACH-05]

dependency_graph:
  requires: ["1044-01", "1044-02"]
  provides:
    - "'Fleet' NV pair (validated; FastSenseCompanion:invalidFleet on wrong type)"
    - "conditional [3 4] root grid {170,220,'1x',360} (fleet) vs byte-identical [3 3] (legacy)"
    - "[1 11] toolbar with hActiveMachineLabel_ slot col 10 + gear col 11 (fleet) vs [1 10] (legacy)"
    - "MachineSelectorPane attach in col-1 panel + close() detach"
  affects:
    - libs/FastSenseCompanion/FastSenseCompanion.m

tech_stack:
  added: []
  patterns:
    - "conditional construction branch on ~isempty(obj.Fleet_) — Phase 1040 grid-extension precedent"
    - "EventStore NV-pair validation idiom reused for 'Fleet'"

key_files:
  created: []
  modified:
    - libs/FastSenseCompanion/FastSenseCompanion.m

decisions:
  - "stylePanels cell extended conditionally so the left-rail panel joins the themed-panel loop without duplicating the loop"

metrics:
  commit: 7b9d0e63
  tests: "TestFastSenseCompanion 79/80 — sole failure = pre-existing PerTag flake (passes in isolation with AND without this change); all legacy structural tests green; check_matlab_code clean (pre-existing warnings only)"
---

# Plan 1044-03 Summary

Structural layout surgery: `'Fleet'` NV pair parsed/validated/stored; fleet mode builds the `[3 4]` grid with the 170px left rail hosting `MachineSelectorPane`, panes shifted right, toolbar `[1 11]` with the active-machine label slot; legacy path byte-identical (`[3 3]`, `{220,'1x',360}`, `[1 10]`, no selector/label). `close()` detaches the selector pane.

Implemented by the background execution agent (interrupted mid-verification — work recovered from its working tree); verified and committed in main session.

**Deviations:** none from plan scope. Verification note: the agent's full-suite failure (`testPerTagModeSpawnsNFigures`) was proven a pre-existing load-dependent flake via a 4-cell evidence matrix (isolation/baseline ✓, isolation/plan-03 ✓, full-suite ✗ both with and without plan-03).
