# Phase 2: Collapsible Sections - Research

**Researched:** 2026-04-01
**Domain:** MATLAB dashboard engine — GroupWidget reflow wiring, tab persistence serialization, theme contrast
**Confidence:** HIGH

## Summary

This is a pure wiring phase. The infrastructure already exists: `GroupWidget.collapse()` and `expand()` update `Position(4)` and toggle child panel visibility, but they contain TODO comments noting that `DashboardLayout.reflow()` must be called — that call is the missing link. `DashboardLayout.reflow()` already exists and already calls `createPanels()`. The pattern for injecting engine-level callbacks without circular references was established in Phase 1 (the `ErrorFcn` approach) and the CONTEXT.md names it explicitly: inject a `ReflowCallback` function handle into `GroupWidget` from `DashboardEngine.addWidget()`.

For tab persistence: `GroupWidget.toStruct()` already serializes `activeTab` and `GroupWidget.fromStruct()` already restores it. The requirement is to verify this round-trip works and write a test confirming it.

For tab contrast: `DashboardTheme.m` already defines `TabActiveBg`, `TabInactiveBg`, and `GroupHeaderFg` for all 6 presets. Visual inspection of the light and default themes reveals the active/inactive luminance delta is sufficient for legibility. The 'scientific' theme is the only one where active and inactive tab backgrounds are swapped (inactive is lighter than active), which is visually unusual but still produces legible text.

**Primary recommendation:** Three targeted edits: (1) add `ReflowCallback` property to `GroupWidget` and call it in `collapse()`/`expand()`; (2) inject the callback in `DashboardEngine.addWidget()`; (3) write integration tests for reflow and tab round-trip. No new files needed.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- GroupWidget needs a callback to trigger DashboardLayout.reflow() on collapse/expand
- Use a function handle callback (EngineRef pattern) rather than a direct object reference to avoid circular references between GroupWidget and DashboardEngine
- DashboardEngine.addWidget() should inject the reflow callback into GroupWidget instances
- ActiveTab field already serializes in toStruct()/fromStruct() — verify round-trip works correctly
- Write integration test confirming active tab survives JSON save/load cycle
- TabActiveBg and TabInactiveBg already defined for all 5 themes in DashboardTheme.m
- Verify contrast ratio between active/inactive tab backgrounds and text color is legible
- Fix any theme where contrast is insufficient

### Claude's Discretion
All detailed implementation choices (exact callback signature, reflow algorithm, test structure) are at Claude's discretion. The collapse/expand methods and reflow() already exist — this is wiring, not new feature development.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| LAYOUT-01 | Collapsing a GroupWidget reclaims screen space by shifting widgets below upward | Add `ReflowCallback` to GroupWidget; call it at end of `collapse()` after updating Position(4)=1; DashboardEngine injects `@(~) obj.reflowAfterCollapse()` |
| LAYOUT-02 | Expanding a collapsed section pushes widgets below downward | Same callback invoked at end of `expand()` after Position(4) is restored from ExpandedHeight |
| LAYOUT-07 | Existing tabbed GroupWidget persists active tab through save/load round-trip | `toStruct()` already emits `activeTab`; `fromStruct()` already reads it; write test that creates tabbed group, saves to .m, loads back, verifies `ActiveTab` matches |
| LAYOUT-08 | Tab visual contrast is legible in both light and dark themes | All 6 theme presets already define `TabActiveBg`, `TabInactiveBg`, `GroupHeaderFg`; write a data-driven test checking each preset; fix 'scientific' preset's inverted active/inactive if contrast is insufficient |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB handle class | built-in | GroupWidget inherits from handle for mutable state | Already the base class of all Dashboard widgets |
| matlab.unittest.TestCase | built-in | Class-based tests in `tests/suite/` | All suite tests use this; TDD pattern established in Phase 1 |
| DashboardLayout.reflow() | project | Grid re-layout after dynamic height change | Method already exists at `libs/Dashboard/DashboardLayout.m:305` |

No new external dependencies. Pure MATLAB as required by project constraints.

### Installation
None required — all changes are to existing `.m` source files.

## Architecture Patterns

### Pattern 1: EngineRef Callback Injection
**What:** Inject a function handle into a sub-object at construction/add time so the sub-object can call back to the engine without holding a direct reference (which would create a circular reference and prevent garbage collection in MATLAB handle class graphs).

**When to use:** Any time a widget or layout component needs to trigger engine-level operations (reflow, refresh, etc.) without knowing about DashboardEngine directly.

**Established pattern from Phase 1 (DashboardEngine.m:174):**
```matlab
obj.LiveTimer = timer('ExecutionMode', 'fixedRate', ...
    'Period', obj.LiveInterval, ...
    'TimerFcn', @(~,~) obj.onLiveTick(), ...
    'ErrorFcn', @(t, e) obj.onLiveTimerError(t, e));
```

**Apply same pattern in DashboardEngine.addWidget():**
```matlab
% After creating the widget w:
if isa(w, 'GroupWidget') && strcmp(w.Mode, 'collapsible')
    w.ReflowCallback = @() obj.reflowAfterCollapse();
end
```

**GroupWidget.collapse() / expand() after wiring:**
```matlab
function collapse(obj)
    if ~strcmp(obj.Mode, 'collapsible'), return; end
    if obj.Collapsed, return; end
    obj.ExpandedHeight = obj.Position(4);
    obj.Position(4) = 1;
    obj.Collapsed = true;
    if ~isempty(obj.hChildPanel) && ishandle(obj.hChildPanel)
        set(obj.hChildPanel, 'Visible', 'off');
    end
    if ~isempty(obj.ReflowCallback)
        obj.ReflowCallback();
    end
end
```

### Pattern 2: reflow() Call Chain
**What:** `DashboardLayout.reflow()` tears down and recreates all widget panels. It is the correct method for post-collapse layout updates because `DashboardEngine.rerenderWidgets()` uses the same pattern.

**Existing reflow() signature (DashboardLayout.m:305):**
```matlab
function reflow(obj, hFigure, widgets, theme)
% Re-run layout after dynamic changes (e.g., group collapse/expand).
% Tears down and recreates all panels, calling render() on each widget.
    if isempty(hFigure) || ~ishandle(hFigure)
        return;
    end
    obj.createPanels(hFigure, widgets, theme);
end
```

**New private engine method needed:**
```matlab
function reflowAfterCollapse(obj)
    if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
        return;
    end
    theme = DashboardTheme(obj.Theme);
    obj.Layout.reflow(obj.hFigure, obj.Widgets, theme);
end
```

This can also call `obj.rerenderWidgets()` which already exists and does the same thing (`DashboardEngine.m:459-470`). In fact, `rerenderWidgets()` already resets `Realized` flags and calls `Layout.createPanels()`, which internally calls `reflow()`. The simplest implementation of `reflowAfterCollapse()` is just to delegate to `rerenderWidgets()`.

### Pattern 3: Tab Persistence Round-Trip
**What:** `GroupWidget.toStruct()` serializes `activeTab` at line 215 (tabbed path). `GroupWidget.fromStruct()` restores it at line 480. The `.m` save path (`DashboardSerializer.save()`) does not serialize `activeTab` for the group widget — it only emits the outer `addWidget('group', ...)` call. The `.m` export must be verified to check if it emits the `activeTab`.

**Gap found (from DashboardSerializer.save(), line 83-114):** The `case 'group'` branch emits `Mode` but does NOT emit `ActiveTab`. After load, `ActiveTab` will default to the first tab name (set in `GroupWidget.fromStruct()` line 518-520). This means: for JSON round-trip, the active tab is preserved. For `.m` export round-trip, the active tab is reset to the first tab.

**LAYOUT-07 scope:** The requirement says "JSON save/load round-trip" — JSON path works. The `.m` path gap is a pre-existing limitation. Do not fix the `.m` path in this phase unless explicitly required (it is not listed in the requirements).

### Recommended Project Structure
No new files or directories needed. All changes confined to:
```
libs/Dashboard/
├── GroupWidget.m       — add ReflowCallback property; call it in collapse()/expand()
├── DashboardEngine.m   — inject ReflowCallback in addWidget(); add reflowAfterCollapse()
tests/suite/
├── TestGroupWidget.m   — add reflow callback tests
├── TestDashboardEngine.m — add reflow integration test (or TestDashboardBugFixes.m)
```

### Anti-Patterns to Avoid
- **Direct DashboardEngine reference in GroupWidget:** Do not add an `EngineRef` property of type `DashboardEngine`. This creates a circular MATLAB handle reference that may prevent objects from being deleted. Use a function handle instead.
- **Calling reflow() directly from GroupWidget:** `GroupWidget` is in `libs/Dashboard/` and should not call `DashboardLayout.reflow()` directly because that would require GroupWidget to know about the figure handle and widget list — engine concerns.
- **Rebuilding the toggle arrow in-place:** `toggleCollapse()` currently creates the button label as 'v' or '>' at render time. If reflow destroys and recreates the button, the arrow state comes from `obj.Collapsed`. This is already correct — no special handling needed.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Grid re-layout | Custom position recalculation | `DashboardLayout.reflow()` | Already handles scroll state, canvas ratio, panel teardown, and visible-row calculation |
| Widget panel teardown | Loop deleting hPanel manually | `DashboardEngine.rerenderWidgets()` | Handles `Realized` flag reset and batch re-rendering |
| Tab color contrast calculation | Custom luminance math | Compare values directly in test; fix values in theme | MATLAB is not a browser — WCAG thresholds are a guide, visual inspection + empirical values sufficient |

**Key insight:** This phase is almost entirely wiring. The entire collapse/expand/reflow pipeline exists; only the callback connection is missing.

## Common Pitfalls

### Pitfall 1: ReflowCallback Not Injected for Pre-Existing Widgets
**What goes wrong:** If the callback is only injected in `addWidget()` for `Mode == 'collapsible'`, a widget loaded from JSON that was created via `fromStruct()` will have no callback — `fromStruct()` bypasses `addWidget()`.
**Why it happens:** `DashboardEngine.load()` uses `DashboardSerializer.configToWidgets()` then directly appends to `obj.Widgets` — it does not call `addWidget()` for loaded widgets.
**How to avoid:** In `DashboardEngine.load()` (or in `configToWidgets`), after populating `obj.Widgets`, iterate over the widget list and inject the callback for any `GroupWidget` with `Mode == 'collapsible'`. Or inject the callback lazily in `render()` before `allocatePanels()`.
**Warning signs:** Collapse button appears but grid does not reflow after loading a saved dashboard.

### Pitfall 2: reflow() Called Before Figure Is Rendered
**What goes wrong:** If `reflowAfterCollapse()` is called before `render()` (e.g., in a test that calls `collapse()` on an un-rendered widget), `obj.hFigure` is empty and `reflow()` will silently no-op.
**Why it happens:** `GroupWidget.collapse()` changes `Position(4)` regardless of render state; the callback fires immediately.
**How to avoid:** Guard `reflowAfterCollapse()` with `if isempty(obj.hFigure) || ~ishandle(obj.hFigure), return; end` — already shown in the pattern above. Also acceptable: check in the callback lambda: `@() obj.safeReflow()`.
**Warning signs:** Tests that call `g.collapse()` without a rendered figure throw handle errors.

### Pitfall 3: Stale hChildPanel Handle After Reflow
**What goes wrong:** After `reflow()` deletes and recreates all panels, `GroupWidget.hChildPanel` still points to the deleted panel handle. Subsequent `expand()` calls `set(obj.hChildPanel, 'Visible', 'on')` on a deleted handle, which throws.
**Why it happens:** `reflow()` → `createPanels()` → `allocatePanels()` deletes `hViewport` and `hCanvas` at the layout level, but each widget's `hPanel` is also deleted (via `delete(widget.hPanel)` implied by `delete(hViewport)` parenting). However, `GroupWidget.hChildPanel` is a child of `hPanel` and is deleted as a cascade. After `render()` is called again, `hChildPanel` is re-assigned. The problem is that between the delete and the re-render, the stale handle is dangling.
**How to avoid:** In `GroupWidget.collapse()` and `expand()`, guard the `set(obj.hChildPanel, ...)` call with `~isempty(obj.hChildPanel) && ishandle(obj.hChildPanel)` — this is already done at lines 238 and 257. The reflow recreates the widget, so the next render re-assigns `hChildPanel`. No fix needed if the existing guards are in place.
**Warning signs:** `Error using set: Invalid or deleted object` after collapse followed by expand.

### Pitfall 4: ActiveTab Not Restored in .m Export Load
**What goes wrong:** Loading a dashboard saved via `.m` export does not preserve `ActiveTab` for tabbed GroupWidgets — the first tab is always shown.
**Why it happens:** `DashboardSerializer.save()` does not emit `ActiveTab` in the `case 'group'` branch.
**How to avoid:** This is a known pre-existing gap. LAYOUT-07 only requires JSON round-trip. If the `.m` path needs fixing, it requires adding `'ActiveTab', 'tabName'` to the emitted GroupWidget constructor in `DashboardSerializer.save()` — deferred unless requirements expand.
**Warning signs:** Test failing because loaded `.m` dashboard shows wrong active tab.

### Pitfall 5: Toggle Button String Not Updated After Reflow
**What goes wrong:** After collapse + reflow, the toggle button string shows 'v' (expanded) but the widget is collapsed, or vice versa.
**Why it happens:** `reflow()` calls `render()` on each widget again. `GroupWidget.render()` determines the button label from `obj.Collapsed` at line 103-107: `if obj.Collapsed, btnStr = '>'; else btnStr = 'v'; end`. Since `obj.Collapsed` is correctly set before `reflow()` fires, the button is re-created with the correct label.
**How to avoid:** No action needed — the existing render logic is correct as long as reflow triggers re-render.

## Code Examples

### ReflowCallback Injection in addWidget()
```matlab
% Source: DashboardEngine.addWidget() — add after w.Position is set
if isa(w, 'GroupWidget') && strcmp(w.Mode, 'collapsible')
    localObj = obj;  % capture for lambda
    w.ReflowCallback = @() localObj.reflowAfterCollapse();
end
```
Note: In MATLAB, `obj` inside a method is already accessible via closure in anonymous functions — `@() obj.reflowAfterCollapse()` is sufficient and does not require the `localObj` alias. However, verify with Octave compatibility — Octave anonymous function capture semantics are the same.

### ReflowCallback Injection After Load
```matlab
% Source: DashboardEngine.load() — add after obj.Widgets is populated
for i = 1:numel(obj.Widgets)
    w = obj.Widgets{i};
    if isa(w, 'GroupWidget') && strcmp(w.Mode, 'collapsible')
        w.ReflowCallback = @() obj.reflowAfterCollapse();
    end
end
```

### reflowAfterCollapse() Private Method
```matlab
function reflowAfterCollapse(obj)
%REFLOWAFTERCOLLAPSE Recompute grid layout after a GroupWidget changes height.
    if isempty(obj.hFigure) || ~ishandle(obj.hFigure)
        return;
    end
    obj.rerenderWidgets();
end
```
`rerenderWidgets()` already exists (DashboardEngine.m:459) and handles Realized flag reset + panel recreation.

### Tab Round-Trip Test Pattern
```matlab
function testActiveTabPersistsThroughJSONRoundTrip(testCase)
    d = DashboardEngine('TabTest');
    g = d.addWidget('group', 'Label', 'Analysis', 'Mode', 'tabbed', ...
        'Position', [1 1 24 4]);
    g.addChild(TextWidget('Title', 'W1'), 'Overview');
    g.addChild(TextWidget('Title', 'W2'), 'Detail');
    g.switchTab('Detail');
    testCase.verifyEqual(g.ActiveTab, 'Detail');

    tmpFile = [tempname '.json'];
    cleanupFile = onCleanup(@() delete(tmpFile));
    DashboardSerializer.saveJSON( ...
        DashboardSerializer.widgetsToConfig('TabTest', 'dark', 5, d.Widgets), ...
        tmpFile);

    loaded = DashboardSerializer.loadJSON(tmpFile);
    widgets = DashboardSerializer.configToWidgets(loaded);
    testCase.verifyClass(widgets{1}, 'GroupWidget');
    testCase.verifyEqual(widgets{1}.ActiveTab, 'Detail');
end
```

### Reflow Triggered on Collapse Test Pattern
```matlab
function testCollapseTriggersReflowCallback(testCase)
    d = DashboardEngine('ReflowTest');
    g = d.addWidget('group', 'Label', 'Collapsible', 'Mode', 'collapsible', ...
        'Position', [1 1 24 4]);

    reflowCalled = false;
    % Override the injected callback for test verification
    g.ReflowCallback = @() setappdata(0, 'reflowCalled', true);

    g.collapse();
    testCase.verifyTrue(getappdata(0, 'reflowCalled'));
    rmappdata(0, 'reflowCalled');
end
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Direct engine reference in sub-component | Function handle callback (EngineRef pattern) | Phase 1 established | No circular reference; Octave-compatible |
| reflow() was a stub (just called createPanels) | reflow() is wired but not called on collapse | Current state | Phase 2 completes the wiring |

**Pre-existing gaps (not bugs, known before this phase):**
- `GroupWidget.collapse()`/`expand()`: lines 241/260 have explicit TODO comments noting reflow is missing
- `DashboardSerializer.save()` .m path: does not emit `ActiveTab` for tabbed groups

## Open Questions

1. **Should ReflowCallback be injected for all GroupWidget modes, or only `collapsible`?**
   - What we know: Only `collapsible` mode calls `collapse()`/`expand()`. Panel and tabbed modes have no collapse behavior.
   - What's unclear: Whether future tab-switching should also trigger a reflow (it should not — tab switching changes visibility, not grid positions).
   - Recommendation: Inject only for `Mode == 'collapsible'`. The property should exist on all GroupWidgets (initialized to `[]`) to avoid errors, but only populated for collapsible mode.

2. **Does rerenderWidgets() break any widget state (e.g., FastSenseWidget zoom/pan)?**
   - What we know: `rerenderWidgets()` calls `render()` again on all widgets, which recreates axes. FastSenseWidget.render() sets up axes from scratch. Any interactive state (zoom level, cursor position) is lost.
   - What's unclear: Whether this is acceptable UX for collapse/expand.
   - Recommendation: Accept this limitation for v1. The CONTEXT.md and requirements do not mention preserving interactive state across reflow. Document it as a known limitation.

## Environment Availability

Step 2.6: SKIPPED — this phase has no external dependencies. All changes are to MATLAB source files in `libs/Dashboard/`. No new tools, services, CLIs, or runtimes required beyond existing MATLAB R2020b+/Octave 7+ environment.

## Validation Architecture

nyquist_validation is enabled in `.planning/config.json`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (built-in) |
| Config file | none — `tests/run_all_tests.m` discovers suites |
| Quick run command | `cd /path/to/FastPlot && matlab -batch "run('tests/suite/TestGroupWidget.m')"` or Octave equivalent |
| Full suite command | `cd /path/to/FastPlot && matlab -batch "run('tests/run_all_tests.m')"` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LAYOUT-01 | Collapsing GroupWidget calls ReflowCallback | unit | Run `TestGroupWidget` | Partially (collapse tests exist; callback test needs adding) |
| LAYOUT-01 | Collapse triggers grid reflow via engine | integration | Run `TestDashboardEngine` or `TestDashboardBugFixes` | No — Wave 0 gap |
| LAYOUT-02 | Expand calls ReflowCallback and restores height | unit | Run `TestGroupWidget` | Partially (expand test exists; callback test needs adding) |
| LAYOUT-07 | ActiveTab survives JSON save/load round-trip | integration | Run `TestGroupWidget` or `TestDashboardSerializerRoundTrip` | No — Wave 0 gap |
| LAYOUT-08 | Tab contrast legible in all themes (data-driven) | unit | Run `TestGroupWidget.testThemeHasGroupFields` (existing) + new contrast test | Partial — field presence tested, contrast ratio not |

### Sampling Rate
- **Per task commit:** Run `TestGroupWidget` suite (fast, no figure required for unit tests)
- **Per wave merge:** Run `TestGroupWidget` + `TestDashboardEngine` + `TestDashboardSerializerRoundTrip`
- **Phase gate:** Full `tests/run_all_tests.m` green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestGroupWidget.m` — needs new test methods: `testCollapseInjectsCallback`, `testCollapseCallsReflowCallback`, `testExpandCallsReflowCallback`, `testActiveTabPersistsThroughJSONRoundTrip`, `testTabContrastAllThemes`
- [ ] `tests/suite/TestDashboardEngine.m` — needs new test method: `testCollapseGroupWidgetReflowsGrid` (integration test with rendered figure)

*(All other infrastructure is in place — no new test files or framework setup needed)*

## Sources

### Primary (HIGH confidence)
- Direct source code inspection: `libs/Dashboard/GroupWidget.m` — collapse/expand/toStruct/fromStruct reviewed line by line
- Direct source code inspection: `libs/Dashboard/DashboardLayout.m` — reflow() at line 305, createPanels/allocatePanels reviewed
- Direct source code inspection: `libs/Dashboard/DashboardEngine.m` — addWidget(), rerenderWidgets(), load() reviewed
- Direct source code inspection: `libs/Dashboard/DashboardSerializer.m` — save() case 'group' at line 83 reviewed; .m path gap confirmed
- Direct source code inspection: `libs/Dashboard/DashboardTheme.m` — all 6 theme presets, all tab color values confirmed
- Direct source code inspection: `tests/suite/TestGroupWidget.m` — all 18 existing test methods reviewed
- `.planning/phases/02-collapsible-sections/02-CONTEXT.md` — locked decisions read

### Secondary (MEDIUM confidence)
- MATLAB documentation pattern: MATLAB anonymous function closures capture `obj` by reference in handle class methods — standard behavior used throughout the codebase

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all code is project-internal; no external libraries; confirmed by direct inspection
- Architecture patterns: HIGH — existing patterns confirmed directly in source; Phase 1 established the callback pattern
- Pitfalls: HIGH — identified by reading the actual code paths and tracing execution; not speculative
- Serialization gap: HIGH — confirmed `.m` export does not emit ActiveTab by reading DashboardSerializer.save() case 'group'

**Research date:** 2026-04-01
**Valid until:** 2026-05-01 (stable codebase; only invalidated by changes to GroupWidget, DashboardEngine, or DashboardSerializer)
