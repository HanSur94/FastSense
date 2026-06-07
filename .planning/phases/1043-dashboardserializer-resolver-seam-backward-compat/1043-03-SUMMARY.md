---
phase: 1043-dashboardserializer-resolver-seam-backward-compat
plan: "03"
subsystem: Dashboard
tags: [serializer, export, fleet, machineVar, backward-compat]
dependency_graph:
  requires: ["1043-01", "1043-02"]
  provides: ["DashboardSerializer.linesForWidget(machineVar)", "exportScript(machineVar)", "exportScriptPages(machineVar)", "save()_tag_case"]
  affects: ["libs/Dashboard/DashboardSerializer.m"]
tech_stack:
  added: []
  patterns: ["nargin<N optional arg guard", "machineVar conditional sprintf emission"]
key_files:
  modified:
    - libs/Dashboard/DashboardSerializer.m
decisions:
  - "RESEARCH Open Question 3 resolved: 'tag' case added to save() inline switch using registry form (machineVar='') — no save() signature change, legacy output byte-for-byte unchanged"
  - "linesForWidget gains optional 4th positional arg machineVar (nargin<4 guard) — consistent with existing 3-arg pattern, avoids named-arg complexity"
  - "save() 'tag' case emits TagRegistry.get(ws.source.key) — correct for single-machine legacy path; fleet export uses exportScript/exportScriptPages with machineVar"
  - "machineVar conditional belongs only in 'tag' case; 'sensor' case unchanged (legacy sensor widgets are not fleet widgets)"
metrics:
  duration_minutes: 8
  completed: "2026-06-07"
  tasks_completed: 2
  files_modified: 1
---

# Phase 1043 Plan 03: .m Export Machine Scoping Summary

**.m export path now emits `<machineVar>.get('key')` for fleet tag widgets and `TagRegistry.get('key')` for legacy tag widgets across all three export entry points.**

## What Was Built

Three coordinated edits to `DashboardSerializer.m`, all in scope of plan 03:

### Task 1: linesForWidget + exportScript + exportScriptPages

**`linesForWidget(ws, pos, indent, machineVar)`** — optional 4th arg added with `nargin < 4` guard defaulting to `''`. New `'tag'` case inserted before `otherwise` in the inner `switch ws.source.type`:

- Uses `ws.source.key` (the tag field) not `ws.source.name` (legacy sensor field)
- `~isempty(machineVar)` branch: emits `sprintf('%s.get(''%s'')', machineVar, ws.source.key)` (fleet form)
- Empty machineVar branch: emits `sprintf('TagRegistry.get(''%s'')', ws.source.key)` (legacy form)
- Honors `showPlantLog` conditional mirroring the existing `'sensor'` case pattern

**`exportScript(config, filepath, machineVar)`** — optional 3rd arg, nargin<3 defaults to `''`. Threads machineVar into `linesForWidget(ws, pos, '', machineVar)`.

**`exportScriptPages(config, filepath, machineVar)`** — optional 3rd arg, nargin<3 defaults to `''`. Threads machineVar into `linesForWidget(ws, pos, '    ', machineVar)`.

### Task 2: save() inline switch 'tag' case

Added `case 'tag'` to `save()`'s own inline `switch ws.source.type` block (lines ~71-88), placed before `otherwise`. Emits registry-scoped binding using `ws.source.key`:

- `save()` is the legacy function-form export with no machine context — registry form is correct
- `save()` signature unchanged (`function save(config, filepath)`)
- Legacy non-tag save output is byte-for-byte unchanged

**Rationale for fixing in 1043 (not deferring to 1046):** Without this fix, any tag-type widget exported via `save()` would fall through to `otherwise` and export as an unbound widget (no Tag). This is a silent data-loss bug affecting all `.m` export entry points, not just fleet exports. Fixed for consistency.

## Commits

| Hash | Message |
|------|---------|
| 3c6d9189 | feat(1043-03): linesForWidget gains 'tag' case + machineVar arg; exportScript/exportScriptPages thread machineVar |

Note: Both tasks committed atomically in one commit — the edits were made together before the first commit opportunity.

## Grep Acceptance Criteria Results

All self-checks passed before committing:

| Check | Result |
|-------|--------|
| `linesForWidget(ws, pos, indent, machineVar)` signature | 1 match |
| `nargin < 4, machineVar = ''` guard | 1 match |
| `case 'tag'` occurrences (save + linesForWidget) | 2 matches |
| `%s.get(''%s'')` machine-scoped pattern | 1 match |
| `exportScript(config, filepath, machineVar)` | 1 match |
| `linesForWidget(ws, pos, '', machineVar)` in exportScript | 1 match |
| `exportScriptPages(config, filepath, machineVar)` | 1 match |
| `linesForWidget(ws, pos, '    ', machineVar)` in exportScriptPages | 1 match |
| No `contains(` introduced (Octave parity) | 0 matches |
| `save(config, filepath)` signature unchanged | 1 match |

## Deviations from Plan

None — plan executed exactly as written. Both tasks (linesForWidget+exportScript+exportScriptPages in Task 1; save() tag case in Task 2) were committed in a single atomic commit since they constitute a single logical change to one file.

## Threat Surface Scan

No new network endpoints, auth paths, file access patterns, or schema changes introduced. The sprintf-embedded `ws.source.key` follows the same pattern as the existing `ws.source.name` in the `'sensor'` case — no new escaping risk introduced (threat T-1043-03-01 documented in plan threat model, disposition: document and accept for 1043 scope).

## Known Stubs

None. The tag emission is fully wired: linesForWidget emits the correct form based on machineVar, and both exportScript and exportScriptPages thread it correctly.

## MATLAB Execution Note

MATLAB test execution (`mcp__matlab__*` tools) is not available to the executor. The SC4 test methods `testExportScriptMachineVarEmitsMachineVar` and `testExportScriptNoMachineVarEmitsRegistry` in `tests/suite/TestFleetDashboardResolver.m` rely purely on `fileread()` string search — no rendering, no TagRegistry, no Machine objects required. All grep acceptance criteria were verified via Bash. MATLAB test execution is the orchestrator's responsibility.

## Self-Check: PASSED

- libs/Dashboard/DashboardSerializer.m: FOUND
- .planning/phases/1043-dashboardserializer-resolver-seam-backward-compat/1043-03-SUMMARY.md: FOUND
- Task commit 3c6d9189: FOUND
