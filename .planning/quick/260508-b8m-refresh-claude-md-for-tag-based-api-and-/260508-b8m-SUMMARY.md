---
phase: 260508-b8m
plan: 01
subsystem: docs
tags: [claude-md, tag-api, fastsensecompanion, matlab-mcp]
type: quick
dependency_graph:
  requires: []
  provides:
    - CLAUDE.md (refreshed project instructions matching on-disk reality)
    - "## Running MATLAB code" guidance for matlab MCP tools
  affects:
    - CLAUDE.md
tech_stack:
  added: []
  patterns:
    - GSD-style HTML comment markers for new manually-managed CLAUDE.md sections
key_files:
  created: []
  modified:
    - CLAUDE.md
decisions:
  - Use GSD-style markers (`<!-- GSD:matlab-mcp-start -->` / `-end -->`) for the new MATLAB MCP section so future regenerators preserve it.
  - Updated `Public API` example to actual FastSense methods (`addLine/addTag/addThreshold/addBand/render/updateData`) — `addSensor` no longer exists.
  - Updated suite-test naming example to current files (`TestTag`, `TestMonitorTag`, `TestTagRegistry`, `TestDashboardEngine`); `TestSensor.m` and `TestEventDetector.m` are gone.
  - Updated function-test naming example to current files (`test_add_line`, `test_add_threshold`, `test_companion_filter_tags`); `test_sensor.m` / `test_add_sensor.m` were never created or have been removed.
metrics:
  duration_seconds: 209
  completed_date: "2026-05-08"
  tasks_completed: 2
  files_modified: 1
---

# Phase 260508-b8m Plan 01: Refresh CLAUDE.md for Tag-Based API and Add MATLAB MCP Guidance Summary

CLAUDE.md is now in sync with on-disk reality: every class name in Architecture / Layers / Key Abstractions / Entry Points was verified against `ls libs/`, the `FastSenseCompanion` library is documented as the sixth layer, and a new "## Running MATLAB code" section instructs the assistant to use the matlab MCP server tools instead of asking the user to run code manually.

## What Changed

### Architecture block (between `<!-- GSD:architecture-start -->` and `<!-- GSD:architecture-end -->`)

- **Pattern Overview**: "Five independent libraries" → "Six independent libraries" with the actual list (FastSense, SensorThreshold, EventDetection, Dashboard, FastSenseCompanion, WebBridge). Added a bullet describing the FastSenseCompanion role.
- **FastSense layer**: expanded `Contains` to enumerate every top-level `.m` actually present (`FastSenseTheme.m`, `FastSenseDefaults.m`, `FastSenseDataStore.m`, `ConsoleProgressBar.m`, `binary_search.m`, `build_mex.m`, `mex_stamp.m` were missing). Added FastSenseCompanion to `Used by`.
- **SensorThreshold layer**: replaced the entire stale class list (`Sensor.m`, `SensorRegistry.m`, `ThresholdRule.m`, `StateChannel.m`, `loadModuleData.m`, `loadModuleMetadata.m`, `ExternalSensorRegistry.m`) with the Tag-based classes that actually exist: `Tag.m` (abstract), `SensorTag.m`, `MonitorTag.m`, `CompositeTag.m`, `DerivedTag.m`, `StateTag.m`, `TagRegistry.m`, `BatchTagPipeline.m`, `LiveTagPipeline.m`, `readRawDelimitedForTest_.m`. Updated Purpose to match the Tag model. Updated `Used by` to use `FastSense.addTag()` and to add FastSenseCompanion.
- **EventDetection layer**: removed deleted classes (`EventDetector.m`, `IncrementalEventDetector.m`, `EventConfig.m`, `detectEventsFromSensor.m`). Listed the actual files including the newer `EventBinding.m`, `eventLogger.m`, `printEventSummary.m`. Updated `Depends on` to reference `MonitorTag` rather than `Sensor`/`ThresholdRule`.
- **Dashboard layer**: enumerated every widget/file present, including the previously missing `ChipBarWidget`, `DashboardConfigDialog`, `DashboardPage`, `DashboardProgress`, `DetachedMirror`, `DividerWidget`, `IconCardWidget`, `SparklineCardWidget`, `TimeRangeSelector`. Added FastSenseCompanion to `Used by`.
- **FastSenseCompanion layer (NEW)**: full new entry with purpose, location, contents (`FastSenseCompanion.m`, `TagCatalogPane.m`, `DashboardListPane.m`, `InspectorPane.m`, `CompanionTheme.m`, `CompanionSettingsDialog.m`, `companionPrefs.m`, the three `*EventData.m` classes, `runFilterTagsTests.m`, plus `private/`), dependencies (`SensorThreshold/TagRegistry`, `Dashboard/DashboardEngine`, `FastSense/SensorDetailPlot+FastSenseGrid`), and consumers.
- **WebBridge layer**: unchanged — its on-disk file list matched the existing text.
- **Data Flow**: `SensorRegistry is a persistent singleton` → `TagRegistry is a persistent singleton`. Added a bullet describing FastSenseCompanion's selection state and event-based pane communication.
- **Key Abstractions**: replaced `SensorRegistry` example with `TagRegistry`. Added a new `Tag (abstract)` abstraction listing the five concrete subclasses. Expanded the FastSense `add*()` example with the actual method set.
- **Entry Points**: rewrote the `LiveEventPipeline` description (it no longer uses `IncrementalEventDetector`; it now polls `DataSourceMap` and runs `processMonitorTag_`). Added a new `FastSenseCompanion` entry point describing the constructor, three-pane wiring, event names, and live-refresh delegation.
- **Error Handling**: replaced the stale namespaced-error example (`'SensorRegistry:unknownKey'`, `'EventDetector:unknownOption'`) with current ones (`'FastSense:alreadyRendered'`, `'MonitorTag:unknownOption'`, `'FastSenseCompanion:invalidEventData'`) — all three were verified to exist via `grep`. Added a bullet about FastSenseCompanion's try/catch + `uialert` callback wrapping.

### Conventions block — small targeted fixes (within preserved markers)

- `Classes:` example: `EventDetector.m` → `MonitorTag.m`, `FastSenseCompanion.m`.
- `Test files (suite):` example: `TestSensor.m`, `TestEventDetector.m` → `TestTag.m`, `TestMonitorTag.m`, `TestTagRegistry.m`, `TestDashboardEngine.m` (all verified via `ls tests/suite/`).
- `Test files (Octave function-based):` example: `test_sensor.m`, `test_add_sensor.m` → `test_add_line.m`, `test_add_threshold.m`, `test_companion_filter_tags.m` (verified via `ls tests/`).
- `Public API:` example: `addSensor(), addThreshold(), addLine(), render()` → `addLine(), addTag(), addThreshold(), addBand(), render(), updateData()` (verified by grepping `function .* = ?add*` on `libs/FastSense/FastSense.m`).
- `Pattern: ClassName:camelCaseProblem` example: `Sensor:unknownOption, EventDetector:unknownOption` → `MonitorTag:unknownOption, FastSenseCompanion:invalidEventData`.

### New "## Running MATLAB code" section

Added between `<!-- GSD:architecture-end -->` and `<!-- GSD:workflow-start -->`, wrapped in `<!-- GSD:matlab-mcp-start -->` / `<!-- GSD:matlab-mcp-end -->`. Contents:

- Names all five matlab MCP tools (`mcp__matlab__check_matlab_code`, `mcp__matlab__evaluate_matlab_code`, `mcp__matlab__run_matlab_file`, `mcp__matlab__run_matlab_test_file`, `mcp__matlab__detect_matlab_toolboxes`) with one-line purposes.
- States that a live MATLAB session is already running on the user's machine and figures appear in the MATLAB UI which is visible to the user — so don't dump base64 PNGs back to chat unsolicited.
- Repo conventions: toolbox-free; run `install` if `which FastSense` is empty; prefer single test files over the full suite.
- Safety: don't run untrusted code that alters filesystem / env / preferences without explicit user consent; avoid `clear all` / `clear classes`; explicit consent required for `delete`, `rmdir`, `setpref`, `system()` / `!`.

### Sections preserved verbatim

`<!-- GSD:project-start -->...<!-- GSD:project-end -->`, `<!-- GSD:stack-start -->...<!-- GSD:stack-end -->`, `<!-- GSD:workflow-start -->...<!-- GSD:workflow-end -->`, `<!-- GSD:profile-start -->...<!-- GSD:profile-end -->` were not modified. The Conventions block kept its markers and structure; only the example-name bullets called out in the plan were changed.

## Deviations from Plan

### Auto-fixed issues

**1. [Rule 1 — staleness] Updated suite-test and function-test naming examples**

- **Found during:** Task 1 (post-`ls tests/suite/` and `ls tests/`).
- **Issue:** The plan said to leave the `Test files (suite)` example alone "unless an `ls tests/suite/` shows clear renames". The audit-time list showed `TestSensor.m`, `TestEventDetector.m` — neither exists. Today's `tests/suite/` contains `TestTag.m`, `TestMonitorTag.m`, `TestTagRegistry.m`, etc. Same for the function-based test example (`test_sensor.m`, `test_add_sensor.m` — neither exists; current files include `test_add_line.m`, `test_add_threshold.m`, `test_companion_filter_tags.m`).
- **Fix:** Updated both example bullets to current file names so future Claude sessions don't try to open non-existent test files.
- **Files modified:** CLAUDE.md (Conventions block).
- **Commit:** 8c6a0c4 (rolled into Task 1).

### Deviations from `verified_on_disk_state` snapshot

The audit memo's snapshot of libs/ was accurate. The only differences I found while re-listing on disk:

- **libs/FastSense/** contains additional files not enumerated in the snapshot (irrelevant — the snapshot focused on the migrated libraries): `ConsoleProgressBar.m`, `FastSenseDefaults.m`, `FastSenseTheme.m`, `binary_search.m`, `build_mex.m`, `mex_stamp.m`. These were already in the previous CLAUDE.md text or are infrastructure files and were folded into the new `Contains:` list.
- **libs/EventDetection/** matches the snapshot exactly (no `EventDetector`, no `IncrementalEventDetector`, no `EventConfig`, no `detectEventsFromSensor`; current files include the newer `EventBinding.m`, `eventLogger.m`, `printEventSummary.m`).
- **libs/SensorThreshold/** matches the snapshot exactly.
- **libs/FastSenseCompanion/** matches the snapshot exactly (all eleven files plus `private/` were present).
- **libs/Dashboard/** matches the snapshot exactly — the nine "additions vs current CLAUDE.md" widgets all exist on disk.

No surprises; no architectural escalation needed.

## Authentication Gates

None.

## Verification Results

```
$ grep -c "SensorRegistry|ThresholdRule|EventDetector|IncrementalEventDetector|EventConfig|detectEventsFromSensor|StateChannel|ExternalSensorRegistry" CLAUDE.md
0

$ grep -c "TagRegistry|MonitorTag|FastSenseCompanion" CLAUDE.md
24

$ grep -c "GSD:project-start|GSD:project-end|GSD:stack-start|GSD:stack-end|GSD:conventions-start|GSD:conventions-end|GSD:architecture-start|GSD:architecture-end|GSD:matlab-mcp-start|GSD:matlab-mcp-end|GSD:workflow-start|GSD:workflow-end|GSD:profile-start|GSD:profile-end" CLAUDE.md
14

$ grep -c "^## Running MATLAB code$" CLAUDE.md
1

$ grep -c "mcp__matlab__check_matlab_code|mcp__matlab__evaluate_matlab_code|mcp__matlab__run_matlab_file|mcp__matlab__run_matlab_test_file|mcp__matlab__detect_matlab_toolboxes" CLAUDE.md
8

# Section ordering
ORDER_OK  (architecture-end < matlab-mcp-start < workflow-start)

# HTML comment balance
BALANCED
```

All success criteria from the plan satisfied.

## Self-Check: PASSED

- **CLAUDE.md** — verified present and modified (`git log --oneline -3` shows commits 8c6a0c4 and 90d9c03).
- **Commit 8c6a0c4** — `docs(260508-b8m-01): refresh CLAUDE.md architecture for Tag-based API` — found in `git log`.
- **Commit 90d9c03** — `docs(260508-b8m-02): add Running MATLAB code section to CLAUDE.md` — found in `git log`.
- All grep verification commands above return the expected values.
- No stale class names remain. All preserved GSD markers still bracketed correctly. The new MATLAB MCP section is correctly positioned between architecture and workflow blocks.
