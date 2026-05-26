---
phase: quick-260508-l2k
plan: 01
subsystem: Dashboard
tags: [dashboard, slider-preview, event-markers, group-widget, nested-widgets, regression]
requires: []
provides:
  - DashboardWidget.getNestedWidgets (virtual, returns {})
  - GroupWidget.getNestedWidgets (override returning Children + Tabs widgets)
  - DashboardEngine.flattenWidgetsForPreview_ (private helper, depth-first, depth cap 10)
affects:
  - DashboardEngine.computePreviewEnvelopeReturning_ (now flattens active page's widget list)
  - DashboardEngine.computeEventMarkers (now flattens active page's widget list)
tech-stack:
  added: []
  patterns:
    - virtual-method extension point (open-extension; no isa() type sniffing in engine)
    - depth-first flatten with defensive try/catch + depth cap
key-files:
  created:
    - .planning/quick/260508-l2k-preview-iteration-recurses-into-groupwid/260508-l2k-SUMMARY.md
  modified:
    - libs/Dashboard/DashboardWidget.m
    - libs/Dashboard/GroupWidget.m
    - libs/Dashboard/DashboardEngine.m
    - tests/test_dashboard_preview_overlay.m
    - tests/test_dashboard_engine_event_markers.m
decisions:
  - "Virtual getNestedWidgets() on the base class is the engine's extension point — no isa(GroupWidget) checks. Future container widgets just override the method."
  - "Flatten the *active page's* widget list, never allPageWidgets() — preserves the per-tab semantics restored by 260508-kov."
  - "Defensive depth cap of 10 in flattenWidgetsForPreview_ (GroupWidget enforces maxDepth=2 at addChild, but the engine helper does not assume well-formedness)."
  - "Group itself returns base [] from getPreviewSeries / getEventTimes — flatten makes the engine bypass the Group entirely so we never double-count."
metrics:
  duration: ~10 min
  tasks_completed: 2
  files_modified: 5
  files_created: 1
  completed: 2026-05-08
---

# Quick Task 260508-l2k: Slider preview + event markers recurse into GroupWidget children

## One-liner

Engine now flattens the active page's widget list via a virtual `getNestedWidgets()` method, so FastSenseWidgets nested inside a GroupWidget contribute preview lines and event markers to the time-slider overlay.

## Bug

`DashboardEngine.computePreviewEnvelopeReturning_` and `computeEventMarkers` iterated `obj.activePageWidgets()` — top-level widgets only. They called `getPreviewSeries` / `getEventTimes` on the Group itself; the base implementations return `[]`, so nested FastSenseWidgets contributed nothing. On industrial-demo Pages 2/3/5/6 (data-bearing widgets nested inside a GroupWidget) the slider preview was empty and event markers were missing.

## Fix

Three coordinated edits, then two regression tests:

1. **`libs/Dashboard/DashboardWidget.m`** — added virtual `getNestedWidgets()` returning `{}` (default for leaf widgets).
2. **`libs/Dashboard/GroupWidget.m`** — overrode `getNestedWidgets()` to return `[Children, flatten(Tabs{*}.widgets)]`. Order: Children first, then tabs in declaration order. Mirrors `getTimeRange`'s recursion shape.
3. **`libs/Dashboard/DashboardEngine.m`**:
   - Added private `flattenWidgetsForPreview_(widgets, depth)` after `allPageWidgets`. Depth-first, defensive try/catch around `getNestedWidgets()`, depth cap of 10.
   - Replaced `ws = obj.activePageWidgets();` with `ws = obj.flattenWidgetsForPreview_(obj.activePageWidgets());` at the two iteration sites: inside `computePreviewEnvelopeReturning_` and `computeEventMarkers`.
   - Updated doc headers of `computePreviewEnvelope` and `computeEventMarkers` to mention "including nested GroupWidget children".
4. **Tests** — added two regression cases verified RED before fix, GREEN after.

## Files modified

| File | Change |
| ---- | ------ |
| `libs/Dashboard/DashboardWidget.m` | New virtual `getNestedWidgets()` returning `{}` |
| `libs/Dashboard/GroupWidget.m` | Override of `getNestedWidgets()` returning Children + Tabs widgets |
| `libs/Dashboard/DashboardEngine.m` | New private `flattenWidgetsForPreview_`; both iteration sites updated; two doc headers updated |
| `tests/test_dashboard_preview_overlay.m` | New `case_nested_group_preview_lines` |
| `tests/test_dashboard_engine_event_markers.m` | New `case_nested_group_event_markers` |

## Tests added

- `case_nested_group_preview_lines` — GroupWidget containing two FastSenseWidgets; asserts `sel.hPreviewLines` has exactly 2 handles, each with non-trivial X data inside the dashboard's DataRange.
- `case_nested_group_event_markers` — GroupWidget containing two EventTimelineWidgets with disjoint events; asserts the slider's sorted marker XData equals the union `[5 15 25 35]`.

## Test results (2026-05-08, MATLAB R2025x on macOS ARM64)

| File | Before | After |
| ---- | ------ | ----- |
| `tests/test_dashboard_preview_envelope.m` | 2/2 PASS | 2/2 PASS (no regression) |
| `tests/test_dashboard_preview_overlay.m` | 9/9 PASS | 10/10 PASS (+nested_group_preview_lines) |
| `tests/test_dashboard_engine_event_markers.m` | 8/8 PASS | 9/9 PASS (+nested_group_event_markers) |
| `tests/suite/TestDashboardEngineEventMarkers.m` | 8/8 PASS | 8/8 PASS (no regression) |

RED proof: temporarily reverted Task 1 to HEAD~1 and re-ran the new cases — both failed with the expected diagnostics ("Expected hPreviewLines non-empty when widgets are nested in a GroupWidget"; "expected [5 15 25 35] from nested Group children, got zeros(1,0)"). Task 1 was then restored from HEAD.

## Commits

- `d8dd072` — `fix(quick-260508-l2k): recurse into GroupWidget children for slider preview + event markers` (Task 1: engine + widget changes)
- `5cd3e27` — `test(quick-260508-l2k): regression cases for nested-Group preview lines + event markers` (Task 2: regression tests)

## Per-tab semantics preserved

Both call sites still pass `obj.activePageWidgets()` (NOT `allPageWidgets()`) into the flatten helper — the per-tab scoping restored by 260508-kov is untouched. Multi-page dashboards continue to reflect only the active tab's widgets, now including their nested children.

## Deviations from plan

None. Plan executed exactly as written. The MultiStatusWidget concern flagged in `solution_recap` did not require an override (its UI children are ephemeral handles, not subclassed widgets).

## Self-Check: PASSED

- libs/Dashboard/DashboardWidget.m — `getNestedWidgets` present, returns `{}`. FOUND.
- libs/Dashboard/GroupWidget.m — `getNestedWidgets` overridden. FOUND.
- libs/Dashboard/DashboardEngine.m — `flattenWidgetsForPreview_` defined; called at preview + event-marker sites. FOUND.
- tests/test_dashboard_preview_overlay.m — `case_nested_group_preview_lines` present and registered. FOUND.
- tests/test_dashboard_engine_event_markers.m — `case_nested_group_event_markers` present and registered. FOUND.
- Commit `d8dd072` (Task 1). FOUND.
- Commit `5cd3e27` (Task 2). FOUND.
