# Phase 1: Dashboard Engine Code Review Fixes - Context

**Gathered:** 2026-04-03
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Fix correctness bugs, dead code, and robustness issues identified by code review of the Dashboard engine (`libs/Dashboard/`). All fixes are internal code quality — no new features, no user-facing behavior changes, full backward compatibility preserved.

### Fixes (Priority Order)

**HIGH:**
1. `removeWidget()` silently no-ops in multi-page mode — `DashboardEngine.m:537`: operates on `obj.Widgets` which is empty when pages are active
2. `GroupWidget.refresh()` refreshes collapsed children — `GroupWidget.m:139`: iterates all children even when collapsed, wasting CPU every tick
3. `onResize()` doesn't reflow panels — `DashboardEngine.m:828`: marks dirty but never repositions widgets after figure resize
4. Sensor listeners skipped for page-routed widgets — `DashboardEngine.m:178-206`: `addlistener` on `Sensor.X/Y` is in single-page path only

**MEDIUM:**
5. `GroupWidget` missing `getTimeRange()` override — children's time extents invisible to `updateGlobalTimeRange()`
6. `exportScriptPages()` is lossy — `DashboardSerializer.m:484-549`: multi-page export strips sensor bindings, axis labels, gauge ranges
7. `loadJSON()` doesn't check `fopen` return — `DashboardSerializer.m:202`
8. 4 duplicate widget-type dispatch tables — `addWidget()`, `createWidgetFromStruct()`, `cloneWidget()`, `widgetTypes()`
9. `HeatmapWidget`/`BarChartWidget`/`HistogramWidget` recreate graphics objects on every refresh instead of updating existing handles
10. `removeDetached()` logic bug — `DashboardEngine.m:619-629`: dead code superseded by `removeDetachedByRef()`

**LOW:**
11. `DashboardLayout.stripHtmlTags()` dead code — never called
12. `DashboardLayout.closeInfoPopup()` restores callbacks never saved
13. `DashboardWidget.Realized` should be `SetAccess = private`
14. Document `ForegroundColor`/`AxesColor` as guaranteed theme fields in `DashboardTheme.m`

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/bug-fix phase. Use code review findings as the specification. Preserve backward compatibility. Follow existing codebase patterns and conventions.

</decisions>

<code_context>
## Existing Code Insights

### Key Files
- `libs/Dashboard/DashboardEngine.m` — main orchestrator, multi-page routing, resize, widget lifecycle
- `libs/Dashboard/DashboardWidget.m` — abstract base class
- `libs/Dashboard/DashboardLayout.m` — 24-column grid, info popup, dead code
- `libs/Dashboard/DashboardSerializer.m` — JSON/script export, loadJSON
- `libs/Dashboard/DashboardPage.m` — multi-page navigation
- `libs/Dashboard/GroupWidget.m` — collapsible groups, refresh, getTimeRange
- `libs/Dashboard/DetachedMirror.m` — detachable widget cloning
- `libs/Dashboard/DashboardTheme.m` — theming, field documentation
- `libs/Dashboard/HeatmapWidget.m`, `BarChartWidget.m`, `HistogramWidget.m` — graphics object churn

### Established Patterns
- Handle classes with public/private property sections
- Error IDs: `'ClassName:camelCaseProblem'`
- Lifecycle: create → addWidget → render → refresh/update tick
- Serialization: toStruct/fromStruct round-trip

### Integration Points
- `DashboardEngine.removeWidget()` — called by edit-mode delete button
- `DashboardEngine.onResize()` — figure SizeChangedFcn callback
- `DashboardEngine.addWidget()` — sensor listener registration
- `GroupWidget.refresh()` — called by DashboardEngine.onLiveTick()

</code_context>

<specifics>
## Specific Ideas

No specific requirements — all fixes are specified by code review findings above.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
