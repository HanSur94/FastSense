---
phase: 1017
plan: 06
subsystem: examples
tags: [example-migration, registry-default, event-auto-wiring, tag-system]
dependency_graph:
  requires: ["1017-01", "1017-02", "1017-03"]
  provides: ["canonical user-facing example of the registry-default event-marker pattern"]
  affects: ["examples/example_event_markers.m"]
tech_stack:
  added: []
  patterns: ["registry-default EventStore via TagRegistry.setEventStore"]
key_files:
  created: []
  modified:
    - examples/example_event_markers.m
decisions:
  - "Single TagRegistry.setEventStore(es) call after EventStore construction replaces four per-instance 'EventStore', es NV-pairs (2 MonitorTag + 2 addWidget)"
  - "Both SensorTags AND both MonitorTags registered in TagRegistry so the example is the textbook registry pattern"
  - "TagRegistry.clear(); EventBinding.clear(); added at top per RESEARCH Open Question 3 to prevent cross-example singleton pollution"
metrics:
  duration: "verification-only session (~10 minutes)"
  completed: "2026-06-10"
  tasks_completed: 1
  files_modified: 1
---

# Phase 1017 Plan 06: example_event_markers.m Registry-Default Migration Summary

**One-liner:** `examples/example_event_markers.m` migrated to the registry-default pattern — `TagRegistry.clear()`/`EventBinding.clear()` at top, one `TagRegistry.setEventStore(es)` after EventStore construction, four `TagRegistry.register` calls, and zero per-instance `'EventStore', es` NV-pairs — verified by acceptance greps and a headless MATLAB smoke run.

## Bookkeeping Note

The code change itself shipped in commit `4bff427e` ("Phase 1017: Tag/Event auto-wiring (registry-default + dual-key)", PR #99) — the plan's edits were executed at that time but this SUMMARY was never written, leaving 1017-06 as the lone plan-without-summary that made phase 1017 report `in_progress`. This session re-verified every acceptance criterion against the current file and ran the plan's headless smoke gate, then closed the bookkeeping. No new code changes were needed.

## Tasks Completed

| # | Task | Commit | Files Modified |
|---|------|--------|----------------|
| 1 | Migrate examples/example_event_markers.m to registry-default pattern (clear + setEventStore + register + drop NV-pairs) | 4bff427e (PR #99) | examples/example_event_markers.m |

## Verification (re-run 2026-06-10)

Acceptance criteria — all pass against the current file:

- `'EventStore'` NV-pairs: **0** (required 0)
- `TagRegistry.setEventStore(es)`: **1** (required 1)
- `TagRegistry.register('pump_a_pressure', ...)`: **1**; `TagRegistry.register('motor_b_temperature', ...)`: **1**
- `TagRegistry.clear()`: **1**; `EventBinding.clear()`: **1**
- `MonitorTag(` constructions: **2** (pump + motor)
- `ShowEventMarkers` in code: **2** (both addWidget calls preserve the flag; a third match is the docstring)
- Ordering: `es = EventStore(storePath)` → `TagRegistry.setEventStore(es)` → first `MonitorTag` construction — verified by awk line-order checks

Headless smoke (plan's `<automated>` gate): `matlab -batch` with `DefaultFigureVisible off` ran `example_event_markers` end-to-end — all three live ticks executed, `SMOKE_PASS`, exit 0 (2026-06-10, MATLAB R2025b).

## Deviations

None from the plan's specified end state. The only deviation is procedural: execution and bookkeeping happened in different sessions (see Bookkeeping Note).
