# Phase 08: Widget Improvements — DividerWidget, CollapsibleWidget, Y-Axis Limits - Research

**Researched:** 2026-04-03
**Domain:** MATLAB Dashboard widget system — new widget creation, convenience API, axis configuration
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **DividerWidget:** Horizontal line (1px solid, theme-colored). Configurable Thickness and Color override only. Occupies full grid row (height=1). Horizontal orientation only.
- **CollapsibleWidget:** Reuse existing GroupWidget with Mode='collapsible'. Add DashboardBuilder convenience method `addCollapsible(label, children)` that creates GroupWidget with Mode='collapsible'. No new collapse features needed.
- **Y-Axis Limits:** FastSenseWidget only. Property `YLimits = []` — empty = auto, `[min max]` = fixed range. Serialized via toStruct/fromStruct. Reapplied during refresh() to keep fixed range stable across data updates.

### Claude's Discretion
- DividerWidget render implementation details (line rendering via axes or uipanel)
- Exact DashboardBuilder convenience method signature
- Test structure and coverage scope
- DashboardSerializer type dispatch for DividerWidget

### Deferred Ideas (OUT OF SCOPE)
- Y-axis limits for other chart widgets (BarChartWidget, HistogramWidget, ScatterWidget, HeatmapWidget)
- Vertical divider orientation
</user_constraints>

---

## Summary

Phase 8 adds three focused widget improvements to the existing Dashboard library. All three changes are well-bounded: one is a new leaf widget (DividerWidget), one is a shorthand method on DashboardEngine (addCollapsible), and one is a property addition on an existing widget (YLimits on FastSenseWidget). No new architectural patterns are required — the work follows established widget patterns thoroughly validated across 7 prior phases.

The DividerWidget is the most novel piece: it is a new `DashboardWidget` subclass that renders a horizontal rule. The render implementation can use a `uipanel` with a fixed pixel height and `BackgroundColor` set to the divider color — this is simpler and more reliable cross-platform than embedding MATLAB `axes` for a static line. The widget's `refresh()` is a no-op since dividers carry no live data.

The CollapsibleWidget convenience API resolves to adding `addCollapsible(label, children, varargin)` on `DashboardEngine` (not `DashboardBuilder` — see Architecture Patterns below). The Y-axis limits feature adds a `YLimits` property to `FastSenseWidget` and applies `ylim(ax, obj.YLimits)` after `fp.render()` in both `render()` and `refresh()`.

**Primary recommendation:** Implement as three independent plans in sequence. DividerWidget first (cleanest, requires most integration touchpoints), then CollapsibleWidget convenience method (minimal, additive), then YLimits (local change to FastSenseWidget only).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB uicontrol/uipanel | R2020b+ | GUI primitives for widget rendering | Established in all 15 existing widget render() methods |
| DashboardWidget (abstract base) | project | Contract: render/refresh/getType/toStruct/fromStruct | All widgets subclass this |
| DashboardSerializer | project | JSON/script round-trip serialization | Type dispatch for load + emitChildWidget |
| DetachedMirror.cloneWidget | project | Widget cloning for detach feature | Explicit 15-type switch — new widget types must be added |
| DashboardEngine.addWidget | project | Central widget factory switch | All widget type strings registered here |
| DashboardEngine.widgetTypes | project | Documentation list of supported types | Updated whenever a new type is added |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DashboardTheme | project | Color/font access in render() | Use `obj.getTheme()` (protected base method) then read fields |
| matlab.unittest.TestCase | R2020b+ | Test class base | All suite tests in tests/suite/ |

**Installation:** No external dependencies. Pure MATLAB project.

---

## Architecture Patterns

### Recommended Project Structure for New Widget
```
libs/Dashboard/
├── DividerWidget.m          % new — subclass of DashboardWidget
tests/suite/
├── TestDividerWidget.m      % new — mirrors TestTextWidget.m pattern
```

No new directories needed. DashboardEngine, DashboardSerializer, and DetachedMirror require in-place edits.

### Pattern 1: New Leaf Widget (DividerWidget)

**What:** A DashboardWidget subclass with no live data. render() creates visual chrome; refresh() is a no-op.

**When to use:** Any new widget that renders static UI chrome rather than live data.

**Render approach — uipanel method (RECOMMENDED):**
```matlab
% Source: derived from NumberWidget.render(), TextWidget.render() patterns
function render(obj, parentPanel)
    obj.hPanel = parentPanel;
    theme = obj.getTheme();

    divColor = theme.WidgetBorderColor;   % theme-matched default
    if ~isempty(obj.Color)
        divColor = obj.Color;
    end

    % Full-width thin panel as the divider line
    obj.hLine = uipanel(parentPanel, ...
        'Units', 'normalized', ...
        'Position', [0 0.4 1 0.2], ...   % vertically centered, thin strip
        'BackgroundColor', divColor, ...
        'BorderType', 'none');
end
```

The height fraction (0.2 normalized within a height=1 grid row) gives approximately 1px visual line at typical dashboard sizes. Thickness property maps to this fraction — e.g., Thickness=1 maps to ~0.2 normalized, Thickness=2 maps to ~0.4, etc. Exact mapping is at implementer's discretion.

**toStruct/fromStruct:**
```matlab
% toStruct — call superclass first, then add widget-specific fields
function s = toStruct(obj)
    s = toStruct@DashboardWidget(obj);
    % Only serialize non-default values to keep JSON clean
    if obj.Thickness ~= 1
        s.thickness = obj.Thickness;
    end
    if ~isempty(obj.Color)
        s.color = obj.Color;
    end
end

% fromStruct — static, reconstruct from saved struct
function obj = fromStruct(s)   % static method
    obj = DividerWidget();
    if isfield(s, 'title'),    obj.Title = s.title; end
    if isfield(s, 'position')
        obj.Position = [s.position.col, s.position.row, ...
                        s.position.width, s.position.height];
    end
    if isfield(s, 'thickness'), obj.Thickness = s.thickness; end
    if isfield(s, 'color'),     obj.Color = s.color; end
end
```

**Default position:** height=1 (full grid row), width=24 (spans all columns). Override in constructor:
```matlab
function obj = DividerWidget(varargin)
    obj = obj@DashboardWidget(varargin{:});
    if isequal(obj.Position, [1 1 6 2])
        obj.Position = [1 1 24 1];   % full-width, 1-row high
    end
end
```

### Pattern 2: DashboardEngine Convenience Method (addCollapsible)

**What:** A thin wrapper on `addWidget` that pre-populates Mode='collapsible'. Lives on `DashboardEngine`, not `DashboardBuilder` (DashboardBuilder is the edit-mode overlay, not the programmatic API).

**When to use:** Any shorthand method that composes existing widget types.

**Example:**
```matlab
% In DashboardEngine, add as a public method alongside addWidget/addPage:
function w = addCollapsible(obj, label, children, varargin)
%ADDCOLLAPSIBLE Convenience: add a GroupWidget with Mode='collapsible'.
%   w = d.addCollapsible('Sensors', {w1, w2})
%   w = d.addCollapsible('Sensors', {w1, w2}, 'Collapsed', true)
    w = obj.addWidget('group', 'Label', label, 'Mode', 'collapsible', varargin{:});
    for i = 1:numel(children)
        w.addChild(children{i});
    end
end
```

`varargin` passthrough allows `Collapsed`, `Position`, and other GroupWidget properties.

### Pattern 3: YLimits on FastSenseWidget

**What:** Add a public property `YLimits = []` to FastSenseWidget. Apply after `fp.render()` in both `render()` and `refresh()`.

**When to use:** Any FastSenseWidget property that configures the underlying axes after render.

**Application in render():**
```matlab
fp.render();

% Apply fixed Y-axis limits if configured
if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
    ylim(ax, obj.YLimits);
end
```

**Application in refresh():** The refresh() method rebuilds axes from scratch (delete/recreate pattern already in place). Apply `ylim` after the `fp.render()` call at the end of refresh(), same pattern as render().

**Serialization — toStruct:**
```matlab
if ~isempty(obj.YLimits)
    s.yLimits = obj.YLimits;
end
```

**Deserialization — fromStruct:**
```matlab
if isfield(s, 'yLimits')
    obj.YLimits = s.yLimits;
end
```

### Anti-Patterns to Avoid

- **Using axes for the divider line:** `axes` objects have margin/padding behavior and interact with MATLAB's zoom/pan tools. A `uipanel` with `BorderType='none'` is purely visual and zero-overhead.
- **Skipping DetachedMirror.cloneWidget for DividerWidget:** The 15-type switch in DetachedMirror will hit `otherwise` and throw `DetachedMirror:unknownType`. Must add a `'divider'` case.
- **Skipping DashboardEngine.addWidget switch for DividerWidget:** Same — the switch has no `otherwise` fallthrough to constructors. Must add `case 'divider'`.
- **Making addCollapsible on DashboardBuilder instead of DashboardEngine:** DashboardBuilder is the edit-mode GUI overlay. The programmatic API lives on DashboardEngine (addWidget, addPage, addCollapsible should all be there).
- **Not reapplying ylim after refresh() rebuild:** FastSenseWidget.refresh() deletes and recreates the axes from scratch (see lines 109-147). Any ylim call in render() alone is lost on refresh.
- **YLimits validation in constructor:** Keep validation in render/refresh (where axes exist), not constructor. Defer errors to render time as the rest of the widget layer does.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Theme color for divider | Custom color lookup | `theme.WidgetBorderColor` via `obj.getTheme()` | All 6 presets define this field; `getTheme()` merges ThemeOverride |
| Collapsible grouping | New collapsible widget class | `GroupWidget('Mode','collapsible')` | Phase 2 already built collapse/expand/reflow/serialization |
| Y-axis clamping | Custom data filtering | `ylim(ax, [min max])` | MATLAB's built-in axes property; clamps display, not data |
| Widget serialization dispatch | Custom registry | Add case to existing switches | Three switch statements must be updated in sync |

**Key insight:** The codebase has three parallel type-dispatch switch statements (DashboardEngine.addWidget, DashboardSerializer.createWidgetFromStruct, DetachedMirror.cloneWidget). Any new widget type must be added to all three. Missing one causes silent failures or exceptions at runtime.

---

## Common Pitfalls

### Pitfall 1: Three-Switch Synchronization
**What goes wrong:** New widget type works in render but fails on JSON load or detach.
**Why it happens:** DashboardEngine.addWidget, DashboardSerializer.createWidgetFromStruct, and DetachedMirror.cloneWidget are three separate switch statements. They must all be updated simultaneously.
**How to avoid:** Treat "add DividerWidget" as requiring 3 code sites minimum: the new file, plus three switch additions. Create a checklist in the plan.
**Warning signs:** JSON round-trip test fails with `DashboardSerializer:unknownType`; detach throws `DetachedMirror:unknownType`.

### Pitfall 2: DashboardSerializer.save() and emitChildWidget
**What goes wrong:** DividerWidget inside a GroupWidget serializes to `.m` as a generic fallback, producing `DividerWidget(...)` with potentially wrong constructor call.
**Why it happens:** Both `save()` (top-level) and `emitChildWidget()` (child level) have type dispatch. The `otherwise` fallback in emitChildWidget capitalizes the type name but may produce incorrect code.
**How to avoid:** Add explicit `case 'divider'` in both `save()` and `emitChildWidget()` in DashboardSerializer.
**Warning signs:** Generated `.m` file has `DividerWidget(...)` missing required parameters, or serialization round-trip test fails.

### Pitfall 3: widgetTypes() Documentation List
**What goes wrong:** DividerWidget is not listed in DashboardEngine.widgetTypes(), making it invisible to the edit-mode palette.
**Why it happens:** widgetTypes() is a static documentation helper, not a dispatch table. It is easy to overlook.
**How to avoid:** Add entry alongside addWidget case addition.
**Warning signs:** Edit-mode palette does not show 'divider' as a type option.

### Pitfall 4: YLimits Lost on Live Refresh
**What goes wrong:** Fixed Y-axis limits work initially but reset when the live timer fires.
**Why it happens:** FastSenseWidget.refresh() fully recreates the axes (delete/recreate pattern at lines 109-147). Any state applied only in render() is discarded.
**How to avoid:** Apply `ylim(ax, obj.YLimits)` at the end of BOTH render() and refresh().
**Warning signs:** Y-limits visible after initial render but reset after first live tick.

### Pitfall 5: addCollapsible Not Routing to Active Page
**What goes wrong:** `addCollapsible()` adds a GroupWidget to `obj.Widgets` (flat) instead of `obj.Pages{obj.ActivePage}` when in multi-page mode.
**Why it happens:** The routing logic at lines 170-178 of DashboardEngine lives inside `addWidget()`. If `addCollapsible` calls `addWidget` internally, routing is handled automatically. If it accesses `obj.Widgets` directly, it bypasses multi-page routing.
**How to avoid:** Implement `addCollapsible` to call `obj.addWidget('group', ...)` — routing is automatic.
**Warning signs:** Collapsible group appears on wrong page in multi-page dashboards.

---

## Code Examples

### DividerWidget Minimal Implementation
```matlab
% Source: derived from TextWidget.m pattern
classdef DividerWidget < DashboardWidget

    properties (Access = public)
        Thickness = 1    % Line thickness (relative units: 1=thin, 2=medium, 3=thick)
        Color     = []   % RGB override; empty = use theme WidgetBorderColor
    end

    properties (SetAccess = private)
        hLine = []       % uipanel handle for the divider line
    end

    methods
        function obj = DividerWidget(varargin)
            obj = obj@DashboardWidget(varargin{:});
            if isequal(obj.Position, [1 1 6 2])
                obj.Position = [1 1 24 1];
            end
        end

        function render(obj, parentPanel)
            obj.hPanel = parentPanel;
            theme = obj.getTheme();
            divColor = theme.WidgetBorderColor;
            if ~isempty(obj.Color)
                divColor = obj.Color;
            end
            % Map Thickness to normalized panel fraction (height=1 grid row)
            thickFrac = min(1, obj.Thickness * 0.1);
            yPos = (1 - thickFrac) / 2;
            obj.hLine = uipanel(parentPanel, ...
                'Units', 'normalized', ...
                'Position', [0 yPos 1 thickFrac], ...
                'BackgroundColor', divColor, ...
                'BorderType', 'none');
        end

        function refresh(~)
            % No-op: divider is static
        end

        function t = getType(~)
            t = 'divider';
        end

        function s = toStruct(obj)
            s = toStruct@DashboardWidget(obj);
            if obj.Thickness ~= 1, s.thickness = obj.Thickness; end
            if ~isempty(obj.Color), s.color = obj.Color; end
        end
    end

    methods (Static)
        function obj = fromStruct(s)
            obj = DividerWidget();
            if isfield(s, 'title'),     obj.Title = s.title; end
            if isfield(s, 'position')
                obj.Position = [s.position.col, s.position.row, ...
                                s.position.width, s.position.height];
            end
            if isfield(s, 'description'), obj.Description = s.description; end
            if isfield(s, 'thickness'), obj.Thickness = s.thickness; end
            if isfield(s, 'color'),     obj.Color = s.color; end
        end
    end
end
```

### DashboardEngine Switches — Required Additions

**addWidget switch (line ~124):**
```matlab
case 'divider'
    w = DividerWidget(varargin{:});
```

**widgetTypes() list (line ~1087):**
```matlab
'divider', 'Horizontal divider line (DividerWidget)'
```

**DashboardSerializer.createWidgetFromStruct (line ~287):**
```matlab
case 'divider'
    w = DividerWidget.fromStruct(ws);
```

**DashboardSerializer.save() main switch:**
```matlab
case 'divider'
    lines{end+1} = sprintf('    d.addWidget(''divider'', ''Position'', %s);', pos);
```

**DashboardSerializer.emitChildWidget switch:**
```matlab
case 'divider'
    varName = sprintf('c%d', groupCount);
    groupCount = groupCount + 1;
    childLines{end+1} = sprintf('    %s = DividerWidget(''Position'', %s);', varName, cpos);
```

**DetachedMirror.cloneWidget switch (line ~141):**
```matlab
case 'divider'
    w = DividerWidget.fromStruct(s);
```

### YLimits Application in FastSenseWidget.render()
```matlab
% After fp.render() at the end of render():
if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
    ylim(ax, obj.YLimits);
end
```

### YLimits Application in FastSenseWidget.refresh()
```matlab
% After fp.render() and before the xlim restore block in refresh():
if ~isempty(obj.YLimits) && numel(obj.YLimits) == 2
    ylim(ax, obj.YLimits);
end
```

---

## Integration Checklist for DividerWidget

All 6 sites require changes for DividerWidget to be fully integrated:

| Site | File | Change |
|------|------|--------|
| 1 | `libs/Dashboard/DividerWidget.m` | NEW FILE |
| 2 | `libs/Dashboard/DashboardEngine.m` | `addWidget` switch + `widgetTypes()` list |
| 3 | `libs/Dashboard/DashboardSerializer.m` | `createWidgetFromStruct` + `save()` + `emitChildWidget` |
| 4 | `libs/Dashboard/DetachedMirror.m` | `cloneWidget` switch |
| 5 | `tests/suite/TestDividerWidget.m` | NEW FILE |

**Note:** DashboardLayout.realizeWidget() does NOT need changes — it is generic (creates a uipanel for any widget, then calls widget.render()).

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (built-in, R2020b+) |
| Config file | `tests/run_all_tests.m` (discovers tests/suite/Test*.m) |
| Quick run command | `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('.'); install(); results = runtests('tests/suite/TestDividerWidget'); display(results)"` |
| Full suite command | `cd /Users/hannessuhr/FastPlot && matlab -batch "run_all_tests"` |

### Phase Requirements to Test Map
| Feature | Behavior | Test Type | File |
|---------|----------|-----------|------|
| DividerWidget construction | Default position [1 1 24 1] | unit | TestDividerWidget — Wave 0 |
| DividerWidget render | Creates hLine uipanel in parentPanel | unit | TestDividerWidget — Wave 0 |
| DividerWidget refresh | No-op, no error | unit | TestDividerWidget — Wave 0 |
| DividerWidget toStruct/fromStruct | Round-trip preserves Thickness, Color | unit | TestDividerWidget — Wave 0 |
| DividerWidget in DashboardSerializer | JSON round-trip via createWidgetFromStruct | unit | TestDividerWidget or existing TestDashboardBugFixes |
| addCollapsible method | Creates GroupWidget with Mode='collapsible' | unit | TestDashboardEngine or new TestCollapsibleConvenience |
| addCollapsible children | Children added to returned group | unit | same |
| addCollapsible routes to active page | Multi-page mode routing correct | unit | same |
| YLimits default empty | No ylim call, auto-scaling | unit | TestFastSenseWidget |
| YLimits fixed range | ylim applied after render | unit | TestFastSenseWidget |
| YLimits survives refresh | ylim re-applied after live refresh rebuild | unit | TestFastSenseWidget |
| YLimits toStruct/fromStruct | Round-trip preserves yLimits | unit | TestFastSenseWidget |

### Wave 0 Gaps
- [ ] `tests/suite/TestDividerWidget.m` — covers construction, render, refresh, toStruct/fromStruct

*(TestFastSenseWidget.m and DashboardEngine tests already exist — extend in-place)*

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| Line rendering via `axes` | `uipanel` with `BorderType='none'` | uipanel avoids axes overhead, zoom/pan interaction, margin handling |
| Convenience methods on DashboardBuilder | Convenience methods on DashboardEngine | DashboardBuilder is the edit-mode overlay; programmatic API lives on DashboardEngine |
| Y-axis auto-scaling only | YLimits = [] (auto) or [min max] (fixed) | Consistent with MATLAB xlim/ylim convention |

---

## Open Questions

1. **DividerWidget inside GroupWidget as a child**
   - What we know: GroupWidget.renderChildren() calls child.render(hp) generically for all children. DividerWidget's render() is a no-op on data — should work fine as a child.
   - What's unclear: Whether the thickness fraction logic (based on normalized height within parent panel) yields visually correct results when the parent panel is a GroupWidget's child area rather than a full grid row.
   - Recommendation: Accept the result; can be tuned by the implementer based on visual testing.

2. **Color property serialization — RGB array vs named color**
   - What we know: MATLAB allows both `[r g b]` arrays and named strings ('red', etc.) for colors. `toStruct` will serialize whatever is in `obj.Color`.
   - What's unclear: `jsondecode`/`jsonencode` handle numeric arrays natively; named strings are also fine. No issue expected.
   - Recommendation: Accept both; fromStruct assigns directly without type checking (consistent with other widget color handling).

---

## Environment Availability

Step 2.6: SKIPPED — this phase is purely code changes within the existing MATLAB project. No external tools, services, or runtimes beyond the project's installed MATLAB environment are introduced.

---

## Sources

### Primary (HIGH confidence)
- Direct source code inspection: `libs/Dashboard/DashboardWidget.m` — base class contract
- Direct source code inspection: `libs/Dashboard/GroupWidget.m` — collapsible mode implementation
- Direct source code inspection: `libs/Dashboard/FastSenseWidget.m` — render/refresh pattern, toStruct/fromStruct
- Direct source code inspection: `libs/Dashboard/DashboardEngine.m` — addWidget switch, widgetTypes()
- Direct source code inspection: `libs/Dashboard/DashboardSerializer.m` — createWidgetFromStruct, emitChildWidget
- Direct source code inspection: `libs/Dashboard/DetachedMirror.m` — cloneWidget 15-type switch
- Direct source code inspection: `libs/Dashboard/TextWidget.m`, `NumberWidget.m` — minimal widget patterns
- Direct source code inspection: `tests/suite/TestTextWidget.m`, `TestNumberWidget.m`, `TestFastSenseWidget.m` — test patterns

### Secondary (MEDIUM confidence)
- None — all findings are based on direct codebase inspection (HIGH).

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — directly read from project source files
- Architecture patterns: HIGH — derived from direct inspection of all 6 integration sites
- Pitfalls: HIGH — identified by tracing code paths, not from external sources
- Integration checklist: HIGH — enumerated by reading all dispatch switches

**Research date:** 2026-04-03
**Valid until:** 2026-05-03 (stable codebase, no fast-moving dependencies)
