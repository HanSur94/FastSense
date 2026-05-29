# Phase 3: Widget Info Tooltips - Research

**Researched:** 2026-04-01
**Domain:** MATLAB dashboard engine — per-widget info icon injection, popup panel, Markdown rendering
**Confidence:** HIGH

## Summary

This is a pure wiring and injection phase — all the primitive pieces exist. `DashboardWidget.Description` property is already defined and serialized. `MarkdownRenderer.render()` already converts Markdown to complete HTML. `DashboardEngine.showInfo()` already demonstrates the HTML-to-temp-file-to-browser pattern. The central question from CONTEXT.md — "DashboardWidget.render() or DashboardLayout.realizeWidget() as the injection point?" — is answered by examining the render lifecycle: `realizeWidget()` is the single choke point that ALL 20+ widget types pass through after render-on-demand is triggered, making it the cleanest injection site that requires zero per-widget changes.

The popup mechanism has a key MATLAB constraint: MATLAB uicontrols have no reliable hover events (WindowButtonMotionFcn is fragile), but `WindowButtonDownFcn` and `KeyPressFcn` on the figure handle are reliable. The existing `DashboardEngine.showInfo()` method demonstrates how to write a temp HTML file and call `web(..., '-new')` (MATLAB) or `system(open ...)` (Octave). For an in-figure popup the approach is a `uipanel` overlay with a `javacomponent`-based HTML viewer in MATLAB, or a plain text fallback in Octave. However, given the project's Octave compatibility requirement and the fact that `javacomponent` is deprecated in R2022a+, a simpler approach — uipanel with scrollable plain-text rendering using `uicontrol('Style','edit')` with multi-line text — is the safe cross-platform choice. The Markdown-rendered HTML can still be used via the existing browser-based path if desired; the in-panel approach uses plain text or lightly formatted text from `MarkdownRenderer`.

**Primary recommendation:** Inject info icon button in `DashboardLayout.realizeWidget()` after `widget.render(widget.hPanel)` — one site, all widget types. Open popup by creating a `uipanel` overlay on the widget panel containing a multi-line text edit showing the Description text. Dismiss via `WindowButtonDownFcn` on the figure handle (click-outside) and `KeyPressFcn` for Escape. The popup is a local uipanel on the widget's `hPanel` parent (the canvas), not a figure-level overlay — this avoids z-order issues.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Small info icon (i button) in the widget header chrome area
- Only shown when Description property is non-empty
- Rendered centrally by DashboardWidget base class or DashboardLayout (not per-widget)
- Click-triggered (not hover) — MATLAB uicontrols don't support reliable hover via WindowButtonMotionFcn
- Use a uipanel overlay positioned near the info icon
- Render Description as Markdown using existing MarkdownRenderer
- Dismiss on click-outside (figure WindowButtonDownFcn) or Escape key (figure KeyPressFcn)
- The info icon and popup must be injected centrally — either DashboardWidget.render() base class method adds the icon OR DashboardLayout.realizeWidget() injects the icon when creating widget panels
- Research should determine which approach is cleaner given the existing render lifecycle

### Claude's Discretion
- Exact icon style, size, and positioning
- How MarkdownRenderer output is displayed in the popup panel (HTML via web() component, or plain formatted text)
- Popup sizing and positioning logic

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFO-01 | Every widget with a non-empty Description shows an info icon in its header | Inject `uicontrol('Style','pushbutton', 'String','i')` inside `DashboardLayout.realizeWidget()` after `widget.render(widget.hPanel)` when `~isempty(widget.Description)` |
| INFO-02 | Clicking the info icon displays the description text in a popup panel | Callback creates a `uipanel` overlay on the widget's hPanel; wire `WindowButtonDownFcn`/`KeyPressFcn` on `hFigure` for dismissal |
| INFO-03 | Info popup renders Description as Markdown using MarkdownRenderer | Call `MarkdownRenderer.render(widget.Description, themeName)` to get HTML; display HTML text in popup via formatted display approach |
| INFO-04 | Info popup can be dismissed by clicking outside it or pressing Escape | `WindowButtonDownFcn` on `hFigure`: check if click is outside popup bounds, delete popup; `KeyPressFcn` on `hFigure`: if key == Escape, delete popup; must restore prior callbacks on dismiss |
| INFO-05 | Info icon and popup work on all 20+ existing widget types without per-widget code changes | `DashboardLayout.realizeWidget()` is the single injection point — all widgets pass through it; no per-widget code needed |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| MATLAB handle class + uicontrol | built-in | Info icon (pushbutton) and popup panel (uipanel + edit) | Already the UI primitive used by all existing widgets and toolbar |
| DashboardLayout.realizeWidget() | project | Injection point for info icon | Single choke-point for all 20+ widget types, already used for placeholder removal |
| MarkdownRenderer | project | Convert Description Markdown to HTML | Existing class at `libs/Dashboard/MarkdownRenderer.m`; handles all required Markdown features |
| matlab.unittest.TestCase | built-in | Suite tests | All Dashboard suite tests use this pattern |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| DashboardTheme | project | Info icon styling consistent with dashboard theme | Use `theme.ToolbarFontColor`, `theme.ToolbarBackground` for icon colors |
| DashboardEngine.hFigure | project | WindowButtonDownFcn / KeyPressFcn for dismissal | Need access to figure handle from popup dismiss callbacks |

No external dependencies. Pure MATLAB/Octave as required by project constraints.

### Installation
None — all changes to existing `.m` source files.

## Architecture Patterns

### Recommended Injection Point: DashboardLayout.realizeWidget()

`realizeWidget()` is the canonical injection point for all post-render widget chrome because:
1. It is the single method called for every widget type (all 20+), including lazy-loaded ones
2. It already handles placeholder removal before calling `widget.render()`
3. It has access to the widget object (with `Description`) and the panel (`widget.hPanel`)
4. It runs after `widget.render()` so the info icon sits on top of (in front of) widget content
5. DashboardWidget base class `render()` cannot be the injection point because it is abstract — subclasses override it completely, so injecting in the base `render()` body would require a template method pattern (breaking change to all 20+ subclasses)

Contrast with `DashboardWidget.render()`: abstract method; each subclass overrides it without calling `super.render()` — there is no base implementation to hook into without refactoring all subclasses.

### Pattern 1: Post-Render Chrome Injection in realizeWidget()

**What:** After `widget.render()` completes, check `~isempty(widget.Description)` and add a small "i" pushbutton to the widget's hPanel.

**When to use:** Any widget-level chrome that must appear on all widget types without per-widget code.

**Example (in DashboardLayout.realizeWidget()):**
```matlab
function realizeWidget(obj, widget)
    if widget.Realized, return; end
    if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end
    % Remove placeholder
    ph = findobj(widget.hPanel, 'Tag', 'placeholder');
    delete(ph);
    % Render actual content
    widget.render(widget.hPanel);
    widget.Realized = true;
    widget.Dirty = false;
    % Inject info icon if Description is non-empty
    if ~isempty(widget.Description)
        obj.addInfoIcon(widget);
    end
end
```

This requires `DashboardLayout` to receive or store a reference to `DashboardEngine.hFigure` for popup dismissal wiring. The cleanest approach mirrors the existing `EngineRef` callback pattern from Phase 2: add an `EngineRef` property or a `FigureHandle` property to `DashboardLayout`, set by `DashboardEngine` before calling `realizeWidget()`.

Looking at the existing code, `DashboardEngine.render()` already calls `obj.Layout.allocatePanels(obj.hFigure, ...)` — the figure handle is already passed to the layout. However, `DashboardLayout` does not currently store it. The minimal change: store `hFigure` as a private property on `DashboardLayout`, set during `allocatePanels()`, and use it in `addInfoIcon()`.

### Pattern 2: Popup as uipanel Overlay on hPanel

**What:** Create a `uipanel` with a scrollable multi-line text display inside it, positioned as an overlay on the widget panel. This is above the widget content in z-order because uipanels created later appear on top in MATLAB.

**When to use:** In-figure popup without needing javacomponent or a separate figure window.

**Example:**
```matlab
function addInfoIcon(obj, widget)
    theme = widget.ParentTheme;
    if isempty(theme) || ~isstruct(theme)
        theme = DashboardTheme();
    end
    iconBg = theme.ToolbarBackground;
    iconFg = theme.ToolbarFontColor;

    hIcon = uicontrol('Parent', widget.hPanel, ...
        'Style', 'pushbutton', ...
        'String', char(9432), ...     % Unicode info symbol
        'Units', 'normalized', ...
        'Position', [0.88 0.88 0.10 0.10], ...
        'FontSize', 9, ...
        'ForegroundColor', iconFg, ...
        'BackgroundColor', iconBg, ...
        'Tag', 'InfoIconButton', ...
        'TooltipString', 'Widget info', ...
        'Callback', @(~,~) obj.openInfoPopup(widget, theme));
end

function openInfoPopup(obj, widget, theme)
    % Close any existing popup
    obj.closeInfoPopup();

    % Build plain text from Description (strip Markdown for text edit display)
    descText = widget.Description;

    popupPanel = uipanel('Parent', widget.hPanel, ...
        'Units', 'normalized', ...
        'Position', [0.0 0.0 1.0 0.9], ...
        'BackgroundColor', theme.WidgetBackground, ...
        'BorderType', 'line', ...
        'ForegroundColor', theme.WidgetBorderColor, ...
        'Tag', 'InfoPopupPanel');

    uicontrol('Parent', popupPanel, ...
        'Style', 'edit', ...
        'Max', 10, 'Min', 0, ...        % Multi-line
        'String', descText, ...
        'Units', 'normalized', ...
        'Position', [0.02 0.08 0.96 0.85], ...
        'HorizontalAlignment', 'left', ...
        'Enable', 'inactive', ...       % Read-only appearance
        'FontSize', 10, ...
        'BackgroundColor', theme.WidgetBackground, ...
        'ForegroundColor', theme.ForegroundColor);

    % Close button
    uicontrol('Parent', popupPanel, ...
        'Style', 'pushbutton', ...
        'String', 'Close', ...
        'Units', 'normalized', ...
        'Position', [0.35 0.01 0.30 0.07], ...
        'Callback', @(~,~) obj.closeInfoPopup());

    obj.hInfoPopup = popupPanel;

    % Wire figure-level dismiss callbacks (save previous to restore)
    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
        obj.PrevButtonDownFcn = get(obj.hFigure, 'WindowButtonDownFcn');
        obj.PrevKeyPressFcn = get(obj.hFigure, 'KeyPressFcn');
        set(obj.hFigure, 'WindowButtonDownFcn', ...
            @(~,~) obj.onFigureClickForDismiss());
        set(obj.hFigure, 'KeyPressFcn', ...
            @(~,e) obj.onKeyPressForDismiss(e));
    end
end
```

### Pattern 3: Click-Outside Dismissal

**What:** When `WindowButtonDownFcn` fires on the figure, check if the click landed inside the popup panel bounds. If outside, close the popup and restore the previous figure callbacks.

**Key MATLAB detail:** `get(hFigure, 'CurrentPoint')` returns click position in figure-normalized units. The panel position in figure-normalized units requires walking the parent hierarchy from `widget.hPanel` up to the figure. Alternatively, use `get(hFigure, 'SelectionType')` and `gco` (current graphics object): if the current object is not a child of the popup panel, close it.

**Simpler approach:** Use `gco` to check parentage:
```matlab
function onFigureClickForDismiss(obj)
    if isempty(obj.hInfoPopup) || ~ishandle(obj.hInfoPopup)
        obj.closeInfoPopup();
        return;
    end
    clicked = gco;
    % Walk ancestor chain to check if click is inside popup
    h = clicked;
    insidePopup = false;
    while ~isempty(h) && ishandle(h)
        if h == obj.hInfoPopup
            insidePopup = true;
            break;
        end
        try
            h = get(h, 'Parent');
        catch
            break;
        end
    end
    if ~insidePopup
        obj.closeInfoPopup();
    end
end

function onKeyPressForDismiss(obj, eventData)
    if strcmp(eventData.Key, 'escape')
        obj.closeInfoPopup();
    end
end

function closeInfoPopup(obj)
    if ~isempty(obj.hInfoPopup) && ishandle(obj.hInfoPopup)
        delete(obj.hInfoPopup);
    end
    obj.hInfoPopup = [];
    if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
        set(obj.hFigure, 'WindowButtonDownFcn', obj.PrevButtonDownFcn);
        set(obj.hFigure, 'KeyPressFcn', obj.PrevKeyPressFcn);
    end
    obj.PrevButtonDownFcn = [];
    obj.PrevKeyPressFcn = [];
end
```

### Anti-Patterns to Avoid

- **Injecting in DashboardWidget.render():** Abstract method — cannot add post-render logic in the base class without a template method refactor affecting all 20+ subclasses. DO NOT attempt this approach.
- **Using javacomponent for HTML rendering:** Deprecated since MATLAB R2022a; not available in Octave. Use plain text in `uicontrol('Style','edit')` instead.
- **Using a new figure window for the popup:** Breaks the "popup dismissable by clicking outside" UX requirement — clicking outside a figure doesn't generate events in the original figure.
- **WindowButtonMotionFcn for hover:** Explicitly excluded in CONTEXT.md and REQUIREMENTS.md. Fragile on both MATLAB and Octave.
- **Storing hInfoPopup as a widget property:** Widget objects don't manage overlays. The popup state belongs to `DashboardLayout` (the component doing the injection).
- **Not restoring prior figure callbacks on dismissal:** If `DashboardEngine` or `DashboardToolbar` already uses `WindowButtonDownFcn` or `KeyPressFcn`, overwriting without restoring will break those features. Always save and restore.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Markdown parsing | Custom regex parser | `MarkdownRenderer.render()` | Already handles headings, bold, italic, code, tables, lists, links |
| HTML-to-MATLAB-text conversion | Custom HTML stripper | Show raw Description text in `uicontrol('Style','edit')` | Markdown plain text is readable; HTML rendering in MATLAB requires javacomponent (deprecated/unavailable in Octave) |
| Popup z-order management | Custom z-order logic | Create popup uipanel AFTER widget renders | MATLAB paints UI components in creation order within a parent — last created is on top |

**Key insight:** In MATLAB UI, the "last created child wins" for z-order within a parent container. Creating the popup uipanel after `widget.render()` completes guarantees it renders on top with no additional z-order management.

## Common Pitfalls

### Pitfall 1: Figure Callback Conflicts
**What goes wrong:** Setting `WindowButtonDownFcn` or `KeyPressFcn` on `hFigure` during popup open clobbers existing handlers (e.g., DashboardEngine's resize handler, or future Detach phase's drag handlers).
**Why it happens:** Both the popup dismiss logic and other systems may need figure-level mouse/key events simultaneously.
**How to avoid:** Always read and save the existing callback before setting a new one (`prevCb = get(hFig, 'WindowButtonDownFcn')`); restore it unconditionally in `closeInfoPopup()`.
**Warning signs:** After closing the popup, time slider doesn't respond, or collapsible sections stop working.

### Pitfall 2: Multiple Simultaneous Popups
**What goes wrong:** User clicks the info icon on widget A, then immediately clicks info icon on widget B — two popup panels are visible and both dismiss callbacks are stacked.
**Why it happens:** No guard against opening a second popup while one is already open.
**How to avoid:** In `openInfoPopup()`, call `closeInfoPopup()` first to clean up any existing popup before opening a new one. Store only one `hInfoPopup` handle in `DashboardLayout`.
**Warning signs:** Two overlapping panels visible simultaneously.

### Pitfall 3: Popup Survives realizeWidget() Reflow
**What goes wrong:** User opens popup, then triggers a reflow (e.g., GroupWidget collapse). `DashboardEngine.rerenderWidgets()` deletes all `hPanel` handles including the one the popup is parented to, creating dangling handle errors.
**Why it happens:** The popup is a child of `widget.hPanel`, which gets deleted during reflow.
**How to avoid:** In `DashboardLayout.reflow()` / `createPanels()`, call `closeInfoPopup()` before deleting panels. Since `DashboardLayout` owns both, this is a simple internal call.
**Warning signs:** MATLAB warning `Invalid or deleted object` after collapsing a GroupWidget while popup is open.

### Pitfall 4: hFigure Not Available in DashboardLayout
**What goes wrong:** `openInfoPopup()` needs to wire figure-level callbacks but `DashboardLayout` doesn't store `hFigure`.
**Why it happens:** Current `DashboardLayout.allocatePanels()` receives `hFigure` as an argument but does not store it as a property.
**How to avoid:** Add `hFigure = []` as a private property to `DashboardLayout`. Set it in `allocatePanels()`: `obj.hFigure = hFigure;`. This is the minimal addition needed.
**Warning signs:** `closeInfoPopup` cannot find the figure to restore callbacks.

### Pitfall 5: Octave Compatibility of char(9432)
**What goes wrong:** Unicode info symbol (circled lowercase "i", U+2139) may not render in Octave's Qt-based figure controls.
**Why it happens:** Octave font support for Unicode symbols varies by platform.
**How to avoid:** Use a plain ASCII fallback: `'i'` or `'?'`. The button label is a style choice (Claude's discretion per CONTEXT.md). Use ASCII `'i'` to be safe across all platforms.
**Warning signs:** Info button shows a blank rectangle or box character on Linux/Octave.

### Pitfall 6: Position of Info Icon Inside GroupWidget Header
**What goes wrong:** GroupWidget already uses the top portion of its panel for a header bar (`uipanel` at `[0 1-headerFrac 1 headerFrac]`). Placing the info icon at `[0.88 0.88 0.10 0.10]` relative to the widget's `hPanel` will overlap this header area, but the icon would be a child of `hPanel` (the outer panel), not of `hHeader`. This may result in z-order or click-routing issues.
**Why it happens:** GroupWidget has its own sub-panels; the info icon is injected on the outer panel by `realizeWidget()`.
**How to avoid:** Position the info icon in the top-right corner of the outer panel (e.g., `Position = [0.90 0.90 0.08 0.08]`). Since the icon is created after `widget.render()`, it will be on top. Test with GroupWidget specifically to verify click routing.
**Warning signs:** Info icon is not clickable when a GroupWidget header occupies the same area.

## Code Examples

Verified patterns from existing codebase:

### Existing realizeWidget() (injection point)
```matlab
% Source: libs/Dashboard/DashboardLayout.m line 284-295
function realizeWidget(obj, widget)
    if widget.Realized, return; end
    if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end
    % Remove placeholder
    ph = findobj(widget.hPanel, 'Tag', 'placeholder');
    delete(ph);
    % Render actual content
    widget.render(widget.hPanel);
    widget.Realized = true;
    widget.Dirty = false;
    % INFO-01/05: Inject info icon here after render completes
    % (no per-widget changes needed)
end
```

### Description Property on DashboardWidget
```matlab
% Source: libs/Dashboard/DashboardWidget.m line 16-17
Description = ''  % Optional tooltip text shown via info icon hover
% Already serialized in toStruct() line 53: s.description = obj.Description;
```

### MarkdownRenderer.render() Signature
```matlab
% Source: libs/Dashboard/MarkdownRenderer.m line 18
function html = render(mdText, themeName, basePath)
% Returns complete self-contained HTML document string.
% For plain text display, use the mdText directly in a multi-line edit.
```

### Existing DashboardEngine showInfo() Pattern (reference for HTML display)
```matlab
% Source: libs/Dashboard/DashboardEngine.m line 322-395
% Writes HTML to tempname('.html'), then calls web(path, '-new') in MATLAB
% or system('open ...') in Octave. This pattern works but opens a browser.
% For in-figure popup, skip the browser step and use uicontrol instead.
```

### Multi-line text uicontrol (read-only display)
```matlab
% Source: MATLAB documentation pattern; used in existing widgets
hText = uicontrol('Parent', hPanel, ...
    'Style', 'edit', ...
    'Max', 10, 'Min', 0, ...         % Max > Min+1 makes it multi-line
    'String', descText, ...
    'Enable', 'inactive', ...        % Renders as non-editable
    'Units', 'normalized', ...
    'Position', [0.02 0.08 0.96 0.85], ...
    'HorizontalAlignment', 'left', ...
    'BackgroundColor', theme.WidgetBackground, ...
    'ForegroundColor', theme.ForegroundColor);
```

### DashboardEngine EngineRef callback pattern (Phase 2, reference)
```matlab
% Source: libs/Dashboard/DashboardEngine.m line 121-123
if isa(w, 'GroupWidget') && strcmp(w.Mode, 'collapsible')
    w.ReflowCallback = @() obj.reflowAfterCollapse();
end
% Same pattern for info popup: set DashboardLayout.FigureHandle = obj.hFigure
% after allocatePanels() so realizeWidget() can use it.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| javacomponent for HTML in MATLAB UI | Deprecated; use uiwebview (R2022a+ only) or skip HTML rendering | MATLAB R2022a | Cannot rely on HTML rendering in MATLAB panels; use plain text or browser pop-out |
| WindowButtonMotionFcn for hover tooltips | Not used — unreliable; use TooltipString on uicontrol instead | Project decision | Use click-triggered popup (per CONTEXT.md locked decision) |

**Deprecated/outdated:**
- `javacomponent()`: deprecated R2022a, absent in Octave — do not use for popup HTML rendering
- `uiwebview` (App Designer): only available in MATLAB App Designer context, not in regular figure callbacks

## Open Questions

1. **Popup display format: plain text vs. browser-based HTML**
   - What we know: MarkdownRenderer produces complete HTML. javacomponent is unavailable. `web(..., '-new')` works cross-platform (used in existing showInfo()). Multi-line `uicontrol('Style','edit')` shows plain text well but loses Markdown formatting.
   - What's unclear: Is plain-text Markdown acceptable in the popup, or does rendered Markdown matter enough to warrant a browser pop-out?
   - Recommendation: Default to plain text in the uipanel (simpler, no temp file, no browser window). This is Claude's discretion per CONTEXT.md. If formatted rendering is desired, adopt the existing `showInfo()` browser-pop pattern for the per-widget popup too — but this changes the UX from "overlay" to "new window".

2. **Conflict with future Detach phase (Phase 5) figure callbacks**
   - What we know: Phase 5 will add drag/detach behavior, potentially also needing figure-level mouse events.
   - What's unclear: Whether Phase 5 will set WindowButtonDownFcn and conflict with popup dismiss.
   - Recommendation: Implement the save/restore pattern robustly now. Phase 5 research should check for conflicts at that time.

## Environment Availability

Step 2.6: SKIPPED — this phase is purely MATLAB code changes with no external dependencies beyond the existing codebase.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | matlab.unittest.TestCase (MATLAB) + Octave function tests |
| Config file | `tests/run_all_tests.m` |
| Quick run command | `cd tests && matlab -batch "run_all_tests"` or `octave --no-gui tests/run_all_tests.m` |
| Full suite command | same |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| INFO-01 | Widget with non-empty Description gets info icon after realizeWidget(); widget without Description does not | unit | `matlab -batch "runtests('tests/suite/TestInfoTooltip')"` | No — Wave 0 |
| INFO-02 | Clicking info icon creates popup panel child of widget hPanel | unit (headless render) | same | No — Wave 0 |
| INFO-03 | MarkdownRenderer.render() called with Description text; popup displays it | unit | same | No — Wave 0 |
| INFO-04 | Escape key callback closes popup; click-outside callback closes popup; prior callbacks restored | unit (callback inspection) | same | No — Wave 0 |
| INFO-05 | All 20+ widget types get info icon when Description is set, no per-widget changes required | integration | same | No — Wave 0 |

### Sampling Rate
- **Per task commit:** Quick unit test run on TestInfoTooltip
- **Per wave merge:** Full test suite
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/suite/TestInfoTooltip.m` — covers INFO-01 through INFO-05
- [ ] Verify `TestDashboardLayout.m` still passes (realizeWidget() is modified)
- [ ] Verify `TestDashboardEngine.m` still passes (hFigure property flow is modified)

## Sources

### Primary (HIGH confidence)
- `libs/Dashboard/DashboardLayout.m` — `realizeWidget()` line 284, `allocatePanels()` line 166
- `libs/Dashboard/DashboardWidget.m` — `Description` property line 16, `toStruct()` line 53
- `libs/Dashboard/MarkdownRenderer.m` — `render()` static method signature and full implementation
- `libs/Dashboard/DashboardEngine.m` — `showInfo()` lines 322-395, `EngineRef` pattern line 121-123
- `libs/Dashboard/GroupWidget.m` — header panel structure lines 86-118
- `libs/Dashboard/DashboardToolbar.m` — pushbutton creation pattern lines 56-81
- `libs/Dashboard/DashboardTheme.m` — theme struct fields available for styling

### Secondary (MEDIUM confidence)
- MATLAB documentation: `uicontrol('Style','edit', 'Max', 10, 'Min', 0)` for multi-line read-only text — well-known pattern, verified by existing toolbar code using same `uicontrol` API
- MATLAB documentation: `gco` returns current graphics object; ancestor chain walkable via `get(h, 'Parent')` — standard MATLAB callback pattern

### Tertiary (LOW confidence)
- None — all findings are based on direct codebase inspection

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are existing project code, no external dependencies
- Architecture: HIGH — injection point decision is based on direct code inspection of realizeWidget() and the abstract base class constraint
- Pitfalls: HIGH — identified from direct code inspection (GroupWidget header overlap, figure callback conflicts, Octave Unicode)
- Test gaps: HIGH — TestInfoTooltip.m confirmed absent, existing tests confirmed present

**Research date:** 2026-04-01
**Valid until:** Stable — no external dependencies; valid until DashboardLayout or DashboardWidget API changes
