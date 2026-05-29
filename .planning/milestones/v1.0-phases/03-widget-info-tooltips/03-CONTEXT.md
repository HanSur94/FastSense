# Phase 3: Widget Info Tooltips - Context

**Gathered:** 2026-04-01
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous)

<domain>
## Phase Boundary

Add an info icon to every widget's header when Description is non-empty. Clicking the icon opens a Markdown-rendered popup panel. The popup is dismissable by clicking outside or pressing Escape. This must work on all 20+ widget types without per-widget code changes.

</domain>

<decisions>
## Implementation Decisions

### Info Icon Placement
- Small info icon (ℹ or "i" button) in the widget header chrome area
- Only shown when Description property is non-empty
- Rendered centrally by DashboardWidget base class or DashboardLayout (not per-widget)

### Popup Mechanism
- Click-triggered (not hover) — MATLAB uicontrols don't support reliable hover via WindowButtonMotionFcn
- Use a uipanel overlay positioned near the info icon
- Render Description as Markdown using existing MarkdownRenderer
- Dismiss on click-outside (figure WindowButtonDownFcn) or Escape key (figure KeyPressFcn)

### No Per-Widget Changes
- The info icon and popup must be injected centrally — either:
  - DashboardWidget.render() base class method adds the icon
  - DashboardLayout.realizeWidget() injects the icon when creating widget panels
- Research should determine which approach is cleaner given the existing render lifecycle

### Claude's Discretion
- Exact icon style, size, and positioning
- How MarkdownRenderer output is displayed in the popup panel (HTML via web() component, or plain formatted text)
- Popup sizing and positioning logic

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `DashboardWidget.m` — `Description` property exists on all widgets (line 17), serialized in `toStruct()`
- `MarkdownRenderer.m` — existing class that converts Markdown to formatted output
- `DashboardToolbar.m` — already uses `TooltipString` on uicontrols (pattern reference)
- `DashboardLayout.m` — `realizeWidget()` creates widget panels, potential injection point

### Established Patterns
- Phase 2 established central injection pattern (ReflowCallback via addWidget/load)
- Info icon should follow similar central injection pattern
- uicontrol pushbutton for the icon, callback triggers popup

### Integration Points
- `DashboardWidget.render()` or `DashboardLayout.realizeWidget()` — where icon gets added
- `DashboardEngine.hFigure` — figure handle for WindowButtonDownFcn/KeyPressFcn popup dismissal
- `MarkdownRenderer` — for rendering Description content

</code_context>

<specifics>
## Specific Ideas

No specific requirements beyond ROADMAP success criteria. User wants click-triggered info with Markdown rendering.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>
