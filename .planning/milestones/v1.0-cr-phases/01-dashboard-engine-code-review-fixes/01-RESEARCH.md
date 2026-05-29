# Phase 01: Dashboard Engine Code Review Fixes - Research

**Researched:** 2026-04-03
**Domain:** MATLAB Dashboard Engine — correctness bugs, dead code, robustness improvements
**Confidence:** HIGH (all findings from direct source inspection)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
None — this is an infrastructure/bug-fix phase. All implementation choices at Claude's discretion.

### Claude's Discretion
All implementation choices are at Claude's discretion — pure infrastructure/bug-fix phase. Use code review findings as the specification. Preserve backward compatibility. Follow existing codebase patterns and conventions.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

## Summary

This phase addresses 14 distinct bugs and code quality issues in `libs/Dashboard/`. All fixes are purely internal — no new features, no user-visible behavior changes, full backward compatibility. The issues were identified by code review and are specified precisely enough that no ambiguity research is needed; the research task is to read the actual source files and document exact fix strategies so the planner can create one plan per logical fix group.

The issues cluster into four natural plan-sized groups: (1) correctness bugs in DashboardEngine (multi-page removeWidget, sensor listener gap, onResize reflow), (2) GroupWidget correctness (collapsed-child refresh, missing getTimeRange), (3) serialization robustness (fopen check, exportScriptPages lossy output), and (4) dead code and encapsulation cleanup (dispatch table consolidation, removeDetached, stripHtmlTags, closeInfoPopup callback restore, Realized access modifier, DashboardTheme documentation).

**Primary recommendation:** Fix HIGH-priority bugs first (plans 1 and 2), then MEDIUM (plans 3 and 4), treating each cluster as one plan wave.

## Standard Stack

No new libraries. All fixes use existing MATLAB handle class patterns already present in the codebase.

| Component | Current Version | Purpose |
|-----------|----------------|---------|
| DashboardEngine.m | existing | Multi-page routing, widget lifecycle, resize |
| GroupWidget.m | existing | Collapsible/tabbed/panel group widget |
| DashboardSerializer.m | existing | JSON + script export/import |
| DashboardLayout.m | existing | 24-column grid, info popup |
| DashboardWidget.m | existing | Abstract base class |
| DashboardTheme.m | existing | Theme struct factory |
| HeatmapWidget/BarChartWidget/HistogramWidget | existing | Graphics-heavy refresh |

## Architecture Patterns

### Established Handle Class Pattern

All Dashboard classes inherit from `handle`. Properties follow the three-tier access pattern:

```matlab
properties (Access = public)        % user-configurable
properties (SetAccess = private)    % readable, not writable externally
properties (Access = private)       % fully internal state
```

### Error ID Convention

```matlab
error('ClassName:camelCaseProblem', 'Message %s', detail);
```

### Multi-Page Widget Routing

When `obj.Pages` is non-empty, `addWidget()` routes to `obj.Pages{obj.ActivePage}`. The `obj.Widgets` list remains empty. Callers that operate on `obj.Widgets` directly (like `removeWidget`) must check for multi-page mode and operate on the active page's `Widgets` list instead.

### Sensor Listener Pattern

```matlab
if ~isempty(w.Sensor) && isprop(w.Sensor, 'X')
    try
        addlistener(w.Sensor, 'X', 'PostSet', @(~,~) w.markDirty());
    catch
        % Octave may not support addlistener on all properties
    end
    try
        addlistener(w.Sensor, 'Y', 'PostSet', @(~,~) w.markDirty());
    catch
    end
end
```

This block currently only runs in the single-page path (after the `return` at line 184). The multi-page path exits early without wiring the listener.

### Graphics Object Reuse vs. Recreation

For `BarChartWidget` and `HistogramWidget`, the existing `refresh()` calls `cla(obj.hAxes)` then recreates the bar/hist objects. For `HeatmapWidget`, it calls `imagesc()` each tick without clearing first. The correct fix for bar charts is to check if `obj.hBars` is valid and use `set(obj.hBars, 'YData', ...)` instead of `cla` + `bar`. For heatmaps, use `set(obj.hImage, 'CData', data)` instead of `imagesc()`.

### onResize / reflow Pattern

`DashboardEngine.onResize()` currently calls `markAllDirty()` and `realizeBatch(5)`. It does NOT call `rerenderWidgets()` or any layout reflow. The fix requires calling `rerenderWidgets()` (which exists and deletes+recreates all panels with correct positions) so panels actually reposition after a figure resize. The `markAllDirty()` call can be retained as a belt-and-suspenders measure.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Widget type registry | Custom lookup struct | Consolidate to `DashboardSerializer.createWidgetFromStruct()` — already the most complete and authoritative dispatch table |
| Graphics update for bar charts | New axes recreation | `set(hBars, 'XData', ..., 'YData', ...)` in MATLAB R2020b+ (graphics handle property update) |
| Graphics update for heatmaps | `imagesc()` call | `set(hImage, 'CData', data)` after checking handle validity |

## Bug Analysis: Exact Findings

### Bug 1: removeWidget() silently no-ops in multi-page mode

**File:** `libs/Dashboard/DashboardEngine.m:537`

**Root cause:** `removeWidget()` operates on `obj.Widgets` (line 539: `numel(obj.Widgets)`). When pages are active, `obj.Widgets` is always empty — every widget was routed to a `DashboardPage.Widgets` list instead. The index check `idx >= 1 && idx <= numel(obj.Widgets)` evaluates to false immediately for any index, so the method silently no-ops.

**Fix strategy:**
- If `~isempty(obj.Pages)`: operate on `obj.Pages{obj.ActivePage}.Widgets` instead of `obj.Widgets`.
- After removal, call `rerenderWidgets()` as the single-page path already does.
- Keep existing single-page path unchanged.

**Pattern reference:** `addWidget()` uses exactly this two-path pattern (lines 178-193): checks `~isempty(obj.Pages)` and routes accordingly.

### Bug 2: GroupWidget.refresh() refreshes collapsed children

**File:** `libs/Dashboard/GroupWidget.m:139`

**Root cause:** The non-tabbed branch of `refresh()` (lines 147-151) iterates `obj.Children` unconditionally even when `obj.Collapsed == true`. Every live-timer tick calls `refresh()` on all children even though they are invisible.

**Fix strategy:**
- Add a guard at the top of the non-tabbed branch: `if obj.Collapsed, return; end`
- The tabbed branch does not need this guard since tabbed mode has no collapsed state.

```matlab
function refresh(obj)
    if strcmp(obj.Mode, 'tabbed')
        idx = obj.findTab(obj.ActiveTab);
        if idx > 0
            for i = 1:numel(obj.Tabs{idx}.widgets)
                obj.Tabs{idx}.widgets{i}.refresh();
            end
        end
    else
        if obj.Collapsed
            return;
        end
        for i = 1:numel(obj.Children)
            obj.Children{i}.refresh();
        end
    end
end
```

### Bug 3: onResize() doesn't reflow panels

**File:** `libs/Dashboard/DashboardEngine.m:828`

**Root cause:** `onResize()` calls `markAllDirty()` (marks widgets dirty) and `realizeBatch(5)` (renders up to 5 dirty widgets). Neither operation repositions the uipanel containers. After a figure resize, panels remain at their original pixel positions.

**Fix strategy:**
- Replace the current body with a call to `rerenderWidgets()`, which already correctly deletes all panels and recreates them with normalized positions.
- `rerenderWidgets()` calls `obj.Layout.createPanels()` which computes normalized positions (immune to figure size), so no additional math is needed.
- Guard on `~isempty(obj.hFigure) && ishandle(obj.hFigure)` to be safe.

```matlab
function onResize(obj)
%ONRESIZE Handle figure resize: reposition all widget panels.
    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
        obj.rerenderWidgets();
    end
end
```

Note: `markAllDirty()` can be dropped — `rerenderWidgets()` resets `Realized = false` on all widgets and calls `createPanels()` which re-renders, so dirty flags are effectively reset.

### Bug 4: Sensor listeners skipped for page-routed widgets

**File:** `libs/Dashboard/DashboardEngine.m:178-206`

**Root cause:** The `addlistener` block at lines 196-206 is inside the single-page path only. The multi-page path (lines 178-184) calls `obj.Pages{obj.ActivePage}.addWidget(w)` and immediately returns before reaching the listener wiring block.

**Fix strategy:**
- Extract the listener wiring block into a private helper `wireListeners(obj, w)`.
- Call `wireListeners(w)` before the multi-page `return` statement.

```matlab
% Route to active page when in multi-page mode
if ~isempty(obj.Pages)
    ...
    obj.Pages{obj.ActivePage}.addWidget(w);
    obj.wireListeners(w);   % ADD THIS
    return;
end
...
obj.Widgets{end+1} = w;
obj.wireListeners(w);       % REPLACE existing inline block
```

### Bug 5: GroupWidget missing getTimeRange() override

**File:** `libs/Dashboard/GroupWidget.m` (no getTimeRange method)

**Root cause:** `DashboardWidget` base class defines `getTimeRange()` returning `[inf, -inf]`. `GroupWidget` holds children that may have actual data time extents, but `updateGlobalTimeRange()` in `DashboardEngine` calls `getTimeRange()` on top-level widgets and the group returns `[inf, -inf]`, hiding all children's ranges.

`setTimeRange()` already correctly propagates to all children and tabs (lines 182-191), so the pattern is established.

**Fix strategy:**
- Add `getTimeRange()` override to `GroupWidget` that aggregates children and tabs:

```matlab
function [tMin, tMax] = getTimeRange(obj)
    tMin = inf; tMax = -inf;
    for i = 1:numel(obj.Children)
        [cMin, cMax] = obj.Children{i}.getTimeRange();
        tMin = min(tMin, cMin);
        tMax = max(tMax, cMax);
    end
    for i = 1:numel(obj.Tabs)
        for j = 1:numel(obj.Tabs{i}.widgets)
            [cMin, cMax] = obj.Tabs{i}.widgets{j}.getTimeRange();
            tMin = min(tMin, cMin);
            tMax = max(tMax, cMax);
        end
    end
end
```

### Bug 6: exportScriptPages() is lossy

**File:** `libs/Dashboard/DashboardSerializer.m:484-549`

**Root cause:** `exportScriptPages()` only emits `Title` and `Position` for most widget types. It drops:
- Sensor bindings (no `source` field emitted for fastsense/number/gauge/status in the pages path)
- Axis labels
- Gauge ranges
- GroupWidget children

Contrast with the single-page `exportScript()` (lines ~355-482) which handles sensor bindings, units, ranges, and group children correctly.

**Fix strategy:**
- For each widget in the pages loop, delegate to the same widget-type emit logic already present in `exportScript()`. This is essentially a refactor: extract the per-widget emit block from `exportScript()` into a private static helper `linesForWidget(ws)`, then call it from both `exportScript()` and `exportScriptPages()`.
- This eliminates the duplication and ensures both paths are equally faithful.

**Constraint:** Must preserve the existing `addPage`/`switchPage` two-pass structure of `exportScriptPages()`.

### Bug 7: loadJSON() doesn't check fopen return

**File:** `libs/Dashboard/DashboardSerializer.m:202`

**Root cause:**
```matlab
fid = fopen(filepath, 'r');
jsonStr = fread(fid, '*char')';   % crashes if fid == -1
fclose(fid);
```
If `fopen` fails (file missing, permission denied), `fid = -1` and `fread(-1, ...)` crashes with an unhelpful system error.

**Fix strategy:**
```matlab
fid = fopen(filepath, 'r');
if fid == -1
    error('DashboardSerializer:fileNotFound', ...
        'Cannot open JSON file: %s', filepath);
end
jsonStr = fread(fid, '*char')';
fclose(fid);
```

This matches the error-handling pattern already used in `exportScript()` (line 476: `if fid == -1, error(...)`).

### Bug 8: 4 duplicate widget-type dispatch tables

**Files:**
- `DashboardEngine.m:125` — `addWidget()` switch (creates widgets from type string)
- `DashboardSerializer.m:289` — `createWidgetFromStruct()` switch (most complete, 16 types + mock)
- `DashboardEngine.m:1097` — `widgetTypes()` static method (display list only)
- `DashboardSerializer.m:~363` — `exportScript()` inline switch (single-page export)
- `DashboardSerializer.m:~529` — `exportScriptPages()` inline switch (multi-page export, lossy — see Bug 6)
- `DetachedMirror.m:131` — `cloneWidget()` static switch (15 types)

The authoritative dispatch for instantiation is `DashboardSerializer.createWidgetFromStruct()` (most complete, handles all 16 types including 'mock'). The `addWidget()` table creates objects differently (from type+varargin, not struct), so it cannot be fully replaced by `createWidgetFromStruct`.

**Fix strategy:**
- The `addWidget()` and `createWidgetFromStruct()` tables serve fundamentally different purposes (constructor vs. deserialization) and cannot be merged.
- The `cloneWidget()` table in `DetachedMirror` can delegate to `createWidgetFromStruct(w.toStruct())` for most widget types, removing the duplicate. However, this adds a serialize-then-deserialize round-trip cost; verify round-trip fidelity for all cloneable types before switching.
- The `exportScript()`/`exportScriptPages()` tables are code-generation dispatchers and are structurally different from instantiation tables; extract to a shared `linesForWidget(ws)` helper (see Bug 6 fix).
- `widgetTypes()` is a display-only list; leave as-is but keep in sync.
- **Minimum safe scope:** Consolidate `exportScript()` and `exportScriptPages()` widget emit logic (Bug 6 fix already achieves this). Document the remaining dispatch tables as intentionally separate in a header comment.

### Bug 9: HeatmapWidget/BarChartWidget/HistogramWidget recreate graphics on every refresh

**Files:** `libs/Dashboard/HeatmapWidget.m:58`, `BarChartWidget.m:54-58`, `HistogramWidget.m:56-57`

**HeatmapWidget:** Calls `imagesc(obj.hAxes, data)` every tick. `imagesc()` deletes and creates a new `Image` object. Fix: check if `obj.hImage` is valid, then `set(obj.hImage, 'CData', data)`.

**BarChartWidget:** Calls `cla(obj.hAxes)` then `bar(...)`. Fix: check if `obj.hBars` is valid; if so, compute `set(obj.hBars, 'YData', data)` or `set(obj.hBars(1), 'YData', data)`. If categories changed (size mismatch), fall back to `cla` + `bar`.

**HistogramWidget:** Same `cla` + `bar` pattern. Histogram bins can change size if `data` changes length significantly. Fix strategy: recompute `[counts, edges]` and if `numel(counts) == numel(obj.hBars.XData)`, update in-place; otherwise fall back to recreate. For simplicity, since histograms are rarely live-refreshed, `cla` + `bar` is acceptable but add an early-exit guard on `~obj.Dirty` to avoid unnecessary redraws.

### Bug 10: removeDetached() logic bug / dead code

**File:** `libs/Dashboard/DashboardEngine.m:619-629`

**Root cause:** `removeDetached(obj, widget)` checks `~isvalid(widget)` to decide whether to keep a mirror. This is inverted logic — it removes a mirror if the *original widget* is invalid, which makes no sense for the stale-scan cleanup use case. The `widget` argument is described as "accepted for API compatibility" but the actual removal criterion should be `m.isStale()` only.

Furthermore, `removeDetachedByRef()` (private method, line 844) is the identity-based removal path actually called by the close callback. `removeDetached()` is called during `onLiveTick()` for stale-scan cleanup.

**Actual code (lines 619-628):**
```matlab
keep = true(1, numel(obj.DetachedMirrors));
for i = 1:numel(obj.DetachedMirrors)
    m = obj.DetachedMirrors{i};
    if m.isStale()
        keep(i) = false;
    elseif ~isvalid(widget)   % BUG: wrong condition
        keep(i) = false;
    end
end
obj.DetachedMirrors = obj.DetachedMirrors(keep);
```

The `elseif ~isvalid(widget)` branch marks ALL non-stale mirrors as dead if the passed-in widget has been deleted — incorrect mass removal.

**Fix strategy:**
- Remove the `elseif ~isvalid(widget)` branch entirely. The stale-scan should only use `m.isStale()`.
- Remove the `widget` parameter from `removeDetached()` (it is unused after this fix). Update all callers.
- If no callers pass a widget argument, verify in `onLiveTick()` that `removeDetached()` is called with no widget argument (or update the call site).

### Bug 11: DashboardLayout.stripHtmlTags() dead code

**File:** `libs/Dashboard/DashboardLayout.m:597`

**Root cause:** `stripHtmlTags` is a `methods (Static)` private method. A search across all Dashboard files confirms it is never called anywhere in the codebase. It was added during Phase 3 development but the implementation shifted to passing raw text directly to `uicontrol` edit boxes without HTML stripping.

**Fix strategy:** Remove the `stripHtmlTags()` static private method entirely. No callers to update.

**Verification:** Confirmed by `grep -rn "stripHtmlTags"` finding only the definition in DashboardLayout.m.

### Bug 12: DashboardLayout.closeInfoPopup() restores callbacks never saved

**File:** `libs/Dashboard/DashboardLayout.m:469-484`

**Root cause:** `closeInfoPopup()` (lines 479-480) calls:
```matlab
set(obj.hFigure, 'WindowButtonDownFcn', obj.PrevButtonDownFcn);
set(obj.hFigure, 'KeyPressFcn', obj.PrevKeyPressFcn);
```

But `openInfoPopup()` never saves the current figure callbacks to `PrevButtonDownFcn`/`PrevKeyPressFcn`. The `PrevButtonDownFcn` property is declared (line 40) and initialized to `[]`. So `closeInfoPopup()` restores `[]` — effectively clearing any existing figure-level callbacks that were there before the popup.

The existing `wasOpen` guard correctly prevents the restore from running on a guard call at the start of `openInfoPopup()`, but after an actual popup open-and-close cycle, the figure callbacks are cleared.

**Fix strategy:**
- In `openInfoPopup()`, before creating the popup figure, save the current figure callbacks:
```matlab
if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
    obj.PrevButtonDownFcn = get(obj.hFigure, 'WindowButtonDownFcn');
    obj.PrevKeyPressFcn   = get(obj.hFigure, 'KeyPressFcn');
end
```
- `closeInfoPopup()` already restores them correctly once they are saved.

### Bug 13: DashboardWidget.Realized should be SetAccess = private

**File:** `libs/Dashboard/DashboardWidget.m:20`

**Root cause:** `Realized = false` is declared in `properties (Access = public)`. This allows any external code to accidentally set `w.Realized = true` without actually calling `render()`, which could cause `realizeBatch()` to skip rendering a widget.

The `Realized` property is only legitimately written by: `render()` (sets to true), `rerenderWidgets()` (resets to false). Both are in `DashboardEngine` (private methods) or in `DashboardWidget` subclass `render()` methods.

**Fix strategy:**
- Change the property block so `Realized` has `SetAccess = private` (or `SetAccess = protected` if subclass render methods set it directly).
- Audit all `w.Realized = ...` write sites: confirmed in `DashboardEngine.rerenderWidgets()` (line 645) and widget `render()` methods. Since `DashboardEngine` is not a subclass of `DashboardWidget`, it cannot write a `protected` property — use `SetAccess = public` on the property but add a note, OR provide a `markRealized()` method, OR accept that `DashboardEngine` sets it via direct assignment and change to `SetAccess = protected` only if widget subclasses set it in their own `render()`.

**Verified write sites:**
- `DashboardEngine.rerenderWidgets()`: `w.Realized = false;`
- `DashboardEngine` render path: `w.Realized = true;` (via `Layout.createPanels` which calls `widget.render()` which sets `Realized`)
- Widget subclasses do NOT set `Realized` directly — `DashboardLayout.createPanels()` calls `render()` and then sets `Realized = true` on the widget externally.

Since `DashboardEngine` (non-subclass) writes `Realized`, `SetAccess = private` on the property in `DashboardWidget` would prevent this. The clean fix is: add a `markRealized(obj)` public method to `DashboardWidget` that sets `obj.Realized = true`, and a `markUnrealized(obj)` that sets it to false. Then change `Realized` to `SetAccess = private`. All write sites in `DashboardEngine` call the methods instead.

### Bug 14: Document ForegroundColor/AxesColor as guaranteed theme fields

**File:** `libs/Dashboard/DashboardTheme.m`

**Root cause:** `ForegroundColor` and `AxesColor` are fields defined in `FastSenseTheme` (the base theme) and are available in every `DashboardTheme` result. However, the `DashboardTheme.m` header comment does not list them as guaranteed fields. Widget code uses `isfield(theme, 'ForegroundColor')` defensively (e.g., `openInfoPopup` line 427), suggesting uncertainty about availability.

`FastSenseTheme` guarantees `ForegroundColor` and `AxesColor` across all presets (verified: lines 95-96, 114-115, 133-134, 152-153, 171-172, 190-191 of `FastSenseTheme.m`).

**Fix strategy:**
- Add `ForegroundColor` and `AxesColor` to the `DashboardTheme.m` header comment's field list.
- Remove the defensive `isfield(theme, 'ForegroundColor')` check in `openInfoPopup()` and use `theme.ForegroundColor` directly (it is always present).
- This is a documentation + minor cleanup fix, not a behavioral change.

## Common Pitfalls

### Pitfall 1: Multi-page vs. single-page obj.Widgets confusion
**What goes wrong:** Methods operating on `obj.Widgets` silently no-op in multi-page mode because `obj.Widgets` is always empty when pages are active.
**How to avoid:** Always check `~isempty(obj.Pages)` and use `obj.Pages{obj.ActivePage}.Widgets` in multi-page mode. Use `activePageWidgets()` helper which already handles both paths.

### Pitfall 2: cla() performance cost
**What goes wrong:** `cla(hAxes)` deletes ALL children of the axes and forces a full redraw. For widgets refreshed every 2-5 seconds, this creates unnecessary flicker and GC pressure.
**How to avoid:** Check handle validity and update `CData`/`YData` properties in-place. Only fall back to `cla` + recreate when data dimensions change.

### Pitfall 3: exportScriptPages() missing fields
**What goes wrong:** When a multi-page dashboard is saved as `.m`, loaded elsewhere, and re-rendered, widget sensor bindings are absent.
**How to avoid:** Extract the per-widget emit logic into a shared helper so both single-page and multi-page code generation use the same path.

### Pitfall 4: fopen(-1) crash
**What goes wrong:** On Octave, `fread(-1, ...)` throws a different error than MATLAB, leading to confusing stack traces.
**How to avoid:** Always check `fid == -1` immediately after `fopen` and throw a descriptive error.

### Pitfall 5: Realized access modifier — subclass vs. external write
**What goes wrong:** If `Realized` is set to `SetAccess = private`, then `DashboardEngine.rerenderWidgets()` (which is NOT a subclass) can no longer write it directly.
**How to avoid:** Provide explicit `markRealized()` / `markUnrealized()` public methods on `DashboardWidget` rather than using direct property assignment from outside the class.

## Code Examples

### Multi-page removeWidget pattern (from addWidget — existing correct pattern)
```matlab
% Source: DashboardEngine.m:178-184
if ~isempty(obj.Pages)
    if obj.ActivePage < 1
        error('DashboardEngine:noActivePage', ...
            'Pages is non-empty but ActivePage is 0.');
    end
    obj.Pages{obj.ActivePage}.addWidget(w);
    return;
end
```

### Heatmap in-place update
```matlab
% Source: HeatmapWidget.m refresh() — current (buggy):
obj.hImage = imagesc(obj.hAxes, data);
% Fix: update CData in-place
if ~isempty(obj.hImage) && ishandle(obj.hImage)
    set(obj.hImage, 'CData', data);
else
    obj.hImage = imagesc(obj.hAxes, data);
end
```

### fopen guard pattern (from exportScript — existing correct pattern)
```matlab
% Source: DashboardSerializer.m:476-479
fid = fopen(filepath, 'w');
if fid == -1
    error('DashboardSerializer:fileError', 'Cannot open file: %s', filepath);
end
```

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (MATLAB) + function-based (Octave) |
| Config file | none — test runner is `tests/run_all_tests.m` |
| Quick run command | `cd /Users/hannessuhr/FastPlot && matlab -batch "install(); results = run(TestDashboardBugFixes); exit(any([results.Failed]))"` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "run_all_tests"` |

### Existing Test Coverage
- `tests/suite/TestDashboardBugFixes.m` — existing bug fix regression tests (6 existing tests for different bugs)
- `tests/suite/TestDashboardEngine.m` — general engine tests
- `tests/suite/TestDashboardMultiPage.m` — multi-page routing tests
- `tests/suite/TestDashboardSerializer.m` — serialization tests
- `tests/suite/TestDashboardLayout.m` — layout tests

### Phase Requirements to Test Map

| Fix | Behavior Under Test | Test Type | Where |
|-----|---------------------|-----------|-------|
| removeWidget multi-page | removeWidget on page-routed widget removes it | unit | New test in TestDashboardBugFixes or TestDashboardMultiPage |
| GroupWidget collapsed refresh | refresh() skips children when Collapsed=true | unit | New test in TestDashboardBugFixes |
| onResize reflow | Panels repositioned after figure resize | unit | New test in TestDashboardBugFixes |
| Sensor listeners multi-page | Sensor X/Y PostSet fires markDirty on page widget | unit | New test in TestDashboardBugFixes |
| GroupWidget getTimeRange | Returns correct min/max from children | unit | New test in TestDashboardBugFixes |
| exportScriptPages fidelity | Sensor binding present in exported .m | unit | New test in TestDashboardMSerializer or TestDashboardSerializer |
| loadJSON fopen guard | loadJSON on missing file throws DashboardSerializer:fileNotFound | unit | New test in TestDashboardSerializer |
| HeatmapWidget in-place update | refresh() does not recreate image object | unit | New test in TestDashboardBugFixes |
| removeDetached logic | Stale-only scan removes only stale mirrors | unit | New test in TestDashboardDetach |
| Realized SetAccess | External code cannot set Realized directly | unit | New test in TestDashboardWidget |
| closeInfoPopup callback restore | Figure callbacks preserved after popup close | unit | New test in TestDashboardInfo |

### Wave 0 Gaps
All new tests should be added to `TestDashboardBugFixes.m` (for engine/widget tests) or existing suite files where thematically appropriate. No new test files need to be created — existing structure is sufficient.

## Environment Availability

Step 2.6: SKIPPED (no external dependencies identified — all fixes are pure MATLAB code changes to existing files)

## Runtime State Inventory

Step 2.5: NOT APPLICABLE (this is not a rename/refactor/migration phase — no runtime state affected by these fixes)

## Open Questions

1. **removeDetached() callers after widget parameter removal**
   - What we know: `removeDetached(obj, widget)` is called during `onLiveTick()`. Need to confirm exact call site.
   - What's unclear: Whether removing the `widget` parameter breaks `onLiveTick()` call site.
   - Recommendation: Read `onLiveTick()` before writing the plan. If call site passes widget, update it to pass nothing or remove the arg.

2. **BarChartWidget YData in-place update compatibility**
   - What we know: MATLAB R2020b+ supports `set(hBar, 'YData', ...)`. Octave 7+ also supports this for bar objects.
   - What's unclear: Whether `bar()` returns a single handle or a vector in all cases (multiple data series).
   - Recommendation: Check if `obj.hBars` is scalar or vector. Use `set(obj.hBars(1), 'YData', ...)` for single-series case. Fall back to cla+bar when series count changes.

3. **Realized SetAccess — DashboardLayout.createPanels write site**
   - What we know: `DashboardEngine` writes `w.Realized = false` in `rerenderWidgets()`. Need to verify if `DashboardLayout.createPanels()` also sets `w.Realized = true`.
   - Recommendation: Grep for all `Realized =` assignments before implementing the markRealized() approach.

## Sources

### Primary (HIGH confidence)
- Direct source inspection: `libs/Dashboard/DashboardEngine.m` — all multi-page, resize, listener, removeDetached code
- Direct source inspection: `libs/Dashboard/GroupWidget.m` — refresh, getTimeRange, setTimeRange
- Direct source inspection: `libs/Dashboard/DashboardSerializer.m` — exportScriptPages, loadJSON, dispatch tables
- Direct source inspection: `libs/Dashboard/DashboardLayout.m` — closeInfoPopup, openInfoPopup, stripHtmlTags
- Direct source inspection: `libs/Dashboard/DashboardWidget.m` — Realized property, getTimeRange base
- Direct source inspection: `libs/Dashboard/HeatmapWidget.m`, `BarChartWidget.m`, `HistogramWidget.m` — graphics churn
- Direct source inspection: `libs/Dashboard/DashboardTheme.m`, `libs/FastSense/FastSenseTheme.m` — ForegroundColor/AxesColor guarantees

## Project Constraints (from CLAUDE.md)

These directives are extracted from `CLAUDE.md` and must be honored by the planner:

- **Pure MATLAB** — no external dependencies; all fixes must be plain `.m` code
- **Backward compatibility** — existing dashboard scripts and serialized dashboards must continue to work after every fix
- **Widget contract** — fixes must not change the public interface of `DashboardWidget` subclasses without preserving the existing call signature
- **Error IDs** — all `error()` calls use `'ClassName:camelCaseProblem'` format
- **Handle classes** — all Dashboard classes inherit from `handle`; `SetAccess` changes must not break handle semantics
- **MISS_HIT compliance** — line length max 160, tab width 4, cyclomatic complexity target <= 80
- **Test pattern** — new tests go in `tests/suite/Test*.m` using `matlab.unittest.TestCase`; `TestClassSetup` method named `addPaths` calling `install()`
- **GSD workflow** — all edits must go through `/gsd:execute-phase`, not direct file edits

## Metadata

**Confidence breakdown:**
- Bug root causes: HIGH — all verified by direct source code inspection
- Fix strategies: HIGH — all follow existing patterns in the same files
- Test locations: HIGH — test infrastructure already established

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable codebase, no external dependencies)
