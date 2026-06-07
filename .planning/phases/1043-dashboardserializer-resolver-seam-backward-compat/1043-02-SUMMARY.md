---
phase: 1043-dashboardserializer-resolver-seam-backward-compat
plan: "02"
subsystem: Dashboard
tags: [resolver, serializer, backward-compat, fleet]
dependency_graph:
  requires: ["1043-01"]
  provides: ["resolver-threading-load-path"]
  affects: ["libs/Dashboard/FastSenseWidget.m", "libs/Dashboard/DashboardSerializer.m", "libs/Dashboard/DashboardEngine.m"]
tech_stack:
  added: []
  patterns: ["optional-arg nargin guard", "resolver DI threading", "dual NV key alias"]
key_files:
  created: []
  modified:
    - libs/Dashboard/FastSenseWidget.m
    - libs/Dashboard/DashboardSerializer.m
    - libs/Dashboard/DashboardEngine.m
decisions:
  - "Resolver call left unwrapped — throwing resolver propagates as error (programming error / wrong resolver injected); graceful partial-bind deferred to Phase 1046 DASH-04"
  - "Both 'TagResolver' (v5.0 canonical) and 'SensorResolver' (legacy alias) accepted in DashboardEngine.load varargin parse; last-wins semantics"
  - "Warning ID changed from FastSenseWidget:tagNotFound to FastSenseWidget:tagResolverMissing on the no-resolver registry-miss path (more actionable for fleet users)"
  - "configToWidgets now passes resolver into createWidgetFromStruct for the tag path; legacy source.type='sensor' post-hoc block retained unchanged"
metrics:
  duration: "~15 minutes"
  completed: "2026-06-07T19:49:13Z"
  tasks_completed: 3
  tasks_total: 3
  files_changed: 3
---

# Phase 1043 Plan 02: Resolver Threading Load Path Summary

**One-liner:** Optional machine-scoped `tagResolver` function handle threaded from `DashboardEngine.load` through `DashboardSerializer.createWidgetFromStruct` and `configToWidgets` into `FastSenseWidget.fromStruct`, closing the multi-page resolver drop gap and adding `FastSenseWidget:tagResolverMissing` warning on no-resolver fleet-tag miss.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | fromStruct gains optional tagResolver arg | f74d5971 | libs/Dashboard/FastSenseWidget.m |
| 2 | createWidgetFromStruct + configToWidgets thread resolver | 86f971b7 | libs/Dashboard/DashboardSerializer.m |
| 3 | DashboardEngine.load accepts TagResolver+SensorResolver + passes resolver into multi-page loop | a8a0c51b | libs/Dashboard/DashboardEngine.m |

## What Was Built

Three surgical edits across three files completing the half-built resolver seam:

1. **FastSenseWidget.fromStruct(s, tagResolver)** — 2nd optional arg added with `nargin < 2` guard. `~isempty(tagResolver)` branch calls `tagResolver(s.source.key)` directly (no try/catch — wrong resolver propagates as error). `elseif exist('TagRegistry', 'class')` fallback preserves Octave-safe legacy try/catch: hit binds tag with no warning; miss emits `FastSenseWidget:tagResolverMissing` and leaves `obj.Tag = []`.

2. **DashboardSerializer.createWidgetFromStruct(ws, tagResolver)** — 2nd optional arg with `nargin < 2` guard. `case 'fastsense'` forwards resolver to `FastSenseWidget.fromStruct(ws, tagResolver)`. All other widget cases unchanged. **configToWidgets** now calls `createWidgetFromStruct(ws, resolver)` so the resolver reaches `fromStruct` during construction. Legacy `source.type='sensor'` post-hoc block retained.

3. **DashboardEngine.load** — varargin parse loop now accepts `'TagResolver'` (v5.0 canonical) OR `'SensorResolver'` (legacy alias). Multi-page loop at former `:4384` changed from `createWidgetFromStruct(pgWidgets{j})` to `createWidgetFromStruct(pgWidgets{j}, resolver)`. Single-page `configToWidgets(config, resolver)` path unchanged.

## Success Criteria Status

| Criterion | Status | Notes |
|-----------|--------|-------|
| SC1 (DASH-01): page-2 tag widgets resolve via injected resolver | IMPL | Multi-page `:4384` gap closed; grep verified |
| SC2 (DASH-02): legacy load unchanged, no new warning on hit | IMPL | nargin guards preserve default path exactly |
| SC3 (DASH-02): no-resolver fleet-tag miss → tagResolverMissing + Tag=[] | IMPL | New warning id, no crash |
| Both 'TagResolver' and 'SensorResolver' NV keys accepted | IMPL | grep: 4 + 2 occurrences in DashboardEngine |
| Resolver-path try/catch deliberately omitted | IMPL | Programming error propagates; 1046 adds graceful bind |
| SC4 (.m export with machineVar) | NOT IN SCOPE | Plan 03 |

## Grep Self-Checks (All Pass)

- `fromStruct(s, tagResolver)` signature: 1 match
- `if nargin < 2, tagResolver = []; end` in FastSenseWidget: 1 match
- `tagResolver(s.source.key)` in FastSenseWidget: 1 match
- `FastSenseWidget:tagResolverMissing` in FastSenseWidget: 1 match
- `FastSenseWidget:tagNotFound` in fromStruct tag case: 0 matches (removed)
- `exist('TagRegistry', 'class')` on legacy path: 2 matches (tag case + sensor case)
- `createWidgetFromStruct(ws, tagResolver)` signature: 1 match
- `FastSenseWidget.fromStruct(ws, tagResolver)` in serializer: 1 match
- `createWidgetFromStruct(ws, resolver)` in configToWidgets: 1 match
- `DashboardSerializer:sensorNotFound` retained: 1 match
- `'TagResolver'` in DashboardEngine: 4 matches
- `'SensorResolver'` in DashboardEngine: 2 matches
- `createWidgetFromStruct(pgWidgets{j}, resolver)`: 1 match
- `createWidgetFromStruct(pgWidgets{j});` (old resolver-less call): 0 matches
- `contains(` in all 3 files: 0 matches (Octave parity preserved)

## MATLAB Execution

MATLAB test execution (TestFleetDashboardResolver SC1/SC2/SC3 green, TestDashboardSerializerRoundTrip regression, test_dashboard_resolver flat Octave test) is the orchestrator's responsibility. This executor has no `mcp__matlab__*` tools per the plan's `<critical_runtime_constraint>`. All grep acceptance criteria pass.

## Deviations from Plan

None — plan executed exactly as specified. Three-way `if ~isempty(tagResolver) / elseif exist(...) / end` structure in fromStruct matches the RESEARCH seam diagram exactly. No new files created, no test files touched, no export paths modified (Plan 03 scope).

## Known Stubs

None — all three changes are complete functional implementations, not stubs.

## Threat Flags

No new security-relevant surface introduced. The resolver is a trusted function handle supplied by the load caller (companion/clone code), not parsed from the dashboard JSON. Threat model T-1043-02-01 through T-1043-02-04 addressed as specified in the plan's `<threat_model>` section.

## Self-Check: PASSED

- libs/Dashboard/FastSenseWidget.m: exists, modified
- libs/Dashboard/DashboardSerializer.m: exists, modified
- libs/Dashboard/DashboardEngine.m: exists, modified
- Commits f74d5971, 86f971b7, a8a0c51b: verified in git log
