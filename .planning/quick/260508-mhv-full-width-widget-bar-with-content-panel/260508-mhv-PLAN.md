---
phase: quick-260508-mhv
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardLayout.m
  - libs/Dashboard/DashboardWidget.m
  - tests/test_dashboard_widget_button_bar.m
autonomous: true
requirements:
  - MHV-01  # Restore full-width per-widget button bar (revert m52 shrink)
  - MHV-02  # Widget content must render below the bar — no truncation/overlap
must_haves:
  truths:
    - "WidgetButtonBar renders as a full-width opaque strip across the top of each widget cell (panel-width minus 2*inset)"
    - "Widget body content (titles, axes, status text, group headers) renders entirely below the bar with no overlap"
    - "Widgets without Description AND without DetachCallback (e.g. DividerWidget) render directly into the outer cell panel — no bar, no content sub-panel — preserving zero-chrome behavior"
    - "Resizing the widget cell keeps the bar full-width and the content panel correctly sized below it"
    - "Widget refresh, reflow, relayout_ paths still work after content-panel introduction (operate on the panel they were given)"
    - "Detached mirror windows still render the cloned widget correctly"
  artifacts:
    - path: "libs/Dashboard/DashboardLayout.m"
      provides: "realizeWidget creates bar+content panel BEFORE widget.render; getOrCreateButtonBar_ full-width formula; reflowChrome_ static handler; createContentPanel_ helper"
      contains: "createContentPanel_"
    - path: "libs/Dashboard/DashboardWidget.m"
      provides: "hCellPanel property exposing the outer cell panel separately from hPanel (which now points at the content sub-panel when chrome is present)"
      contains: "hCellPanel"
    - path: "tests/test_dashboard_widget_button_bar.m"
      provides: "Updated regression test asserting full-width bar + content panel below + no-chrome path for DividerWidget"
      contains: "WidgetContentPanel"
  key_links:
    - from: "DashboardLayout.realizeWidget"
      to: "widget.render(contentPanel)"
      via: "passes the new content sub-panel as parentPanel when chrome is needed"
      pattern: "widget\\.render\\("
    - from: "DashboardLayout.getOrCreateButtonBar_ / addInfoIcon / addDetachButton"
      to: "widget.hCellPanel"
      via: "lookup of outer cell panel for bar parenting and Position calc"
      pattern: "widget\\.hCellPanel"
    - from: "widget.hPanel SizeChangedFcn"
      to: "DashboardLayout.reflowChrome_"
      via: "reflow handler resizes both bar and content panel on outer cell resize"
      pattern: "reflowChrome_"
---

<objective>
Restore the full-width per-widget button bar (revert m52's right-anchored 64px shrink) AND eliminate the content-truncation bug it was masking by rendering all widget content into a sub-panel that sits BELOW the bar.

Purpose: User explicitly requested full-width visual band restored ("nope.. it must be full widht..") while keeping widget titles, axes, status text, and group headers fully visible ("just make sure all widget info and displa si bwlow it and tehre is no truncation").

Output:
- `DashboardLayout.realizeWidget` reordered to create chrome (bar + content sub-panel) BEFORE calling widget.render, so widgets render into the content area, never under the bar.
- `getOrCreateButtonBar_` and `reflowButtonBar_` revert to full-width left-anchored geometry; reflow extended to also resize the content panel.
- New `DashboardWidget.hCellPanel` property holds the outer cell panel so layout helpers can find it after widget.render reassigns hPanel to the content sub-panel.
- Existing regression test (m52) updated in place to assert the new contract: bar full-width AND `WidgetContentPanel` below it.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@libs/Dashboard/DashboardLayout.m
@libs/Dashboard/DashboardWidget.m
@libs/Dashboard/DividerWidget.m
@libs/Dashboard/DetachedMirror.m
@tests/test_dashboard_widget_button_bar.m
@.planning/quick/260508-m52-shrink-widget-button-bar-to-right-anchor/260508-m52-SUMMARY.md

<interfaces>
<!-- Critical contracts the executor must preserve -->

DashboardWidget render contract (every concrete widget follows this):
```matlab
function render(obj, parentPanel)
    obj.hPanel = parentPanel;            % FIRST LINE — every widget
    % ...creates uipanel/axes/uicontrol children with 'Parent', parentPanel
end
```
=> Widgets reassign their own hPanel to whatever panel realizeWidget passes them. If we pass the content sub-panel, `obj.hPanel` becomes the content sub-panel after render(). This is acceptable for refresh/relayout_ paths (they want to operate on the panel where their children live), but BREAKS getOrCreateButtonBar_/addInfoIcon/addDetachButton which currently look up `widget.hPanel` to find the outer cell. Fix: introduce DashboardWidget.hCellPanel as the canonical outer-cell handle.

Refresh paths to verify still work after change (they re-render into hPanel):
- TextWidget.refresh / .relayout_ — calls obj.render(obj.hPanel) — will re-render into content panel (correct)
- SparklineCardWidget.refresh — same pattern
- MultiStatusWidget.refresh — same pattern
- ChipBarWidget.relayout_ — same pattern
- NumberWidget.relayout_ — same pattern
- FastSenseWidget — uses obj.hPanel for findobj/axes lookups (line 944, 947) — must keep working with content panel

DetachedMirror lifecycle (libs/Dashboard/DetachedMirror.m:60-69):
```matlab
obj.hPanel = uipanel(...);          % standalone figure panel
cloned.render(obj.hPanel);          % clone widget renders directly — NO chrome
```
=> DetachedMirror does NOT go through DashboardLayout.realizeWidget; it renders the clone directly. No content-panel needed there. Cloned widget still gets obj.hPanel assigned to the mirror panel, which is fine. Do NOT add chrome inside DetachedMirror.

DividerWidget no-chrome contract (libs/Dashboard/DividerWidget.m:48-68):
- DividerWidget.Description is empty by default; realizeWidget already skips addDetachButton via `~isa(widget, 'DividerWidget')` guard.
- Goal: realizeWidget should also skip the bar AND content panel for dividers — render directly into hPanel as today.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Refactor DashboardLayout.realizeWidget — chrome-first rendering with content sub-panel + full-width bar revert + DashboardWidget.hCellPanel property</name>
  <files>libs/Dashboard/DashboardWidget.m, libs/Dashboard/DashboardLayout.m, tests/test_dashboard_widget_button_bar.m</files>

  <behavior>
    Test 1 (full-width bar): For a TextWidget realized into a panel of width W, after render: bar Position(1) ≈ 2 (inset), bar Position(3) ≈ W - 4 (full width minus 2*inset).
    Test 2 (content panel below bar): A `WidgetContentPanel` uipanel exists as a child of widget.hCellPanel. Its Position(2) == 0, and Position(2)+Position(4) <= bar Position(2). Its Position(3) == panel width (no horizontal inset on content panel).
    Test 3 (widget renders into content panel): After realizeWidget, widget.hPanel handle points at the WidgetContentPanel — not at the outer cell. widget.hCellPanel points at the outer cell. The widget's own children (e.g. TextWidget's title uicontrol) are parented to the content panel, not the cell panel directly.
    Test 4 (reflow keeps full-width + resizes content): After resizing the cell panel and calling DashboardLayout.reflowChrome_, bar width tracks new panel width minus 2*inset, content panel width tracks new panel width, content height = newPanelHeight - barH - inset.
    Test 5 (no-chrome path for DividerWidget): A DividerWidget realized with no DetachCallback wired produces NO WidgetButtonBar and NO WidgetContentPanel — divider renders directly into the outer cell panel as today. (Acceptance: findobj for those tags returns empty under the divider's panel.)
    Test 6 (info+detach buttons still fit): Buttons exist inside the bar; Position(1)+Position(3) <= barW (existing m52 invariant — preserved).
  </behavior>

  <action>
    PART A — DashboardWidget.m: add `hCellPanel` property.

    1. In libs/Dashboard/DashboardWidget.m, in the `properties (SetAccess = public)` block (~L26-28) add a sibling to `hPanel`:

       ```matlab
       hPanel     = []   % Handle to the panel where this widget's content lives.
                          % When DashboardLayout creates a per-widget chrome bar,
                          % hPanel points at the content sub-panel BELOW the bar
                          % (so widget.render's child-creation lands in the
                          % visible content area, not under the bar). When no
                          % chrome is needed (e.g. DividerWidget), hPanel == hCellPanel.
       hCellPanel = []   % Handle to the outer grid-cell uipanel that owns
                          % this widget. Set by DashboardLayout BEFORE render().
                          % Layout helpers (getOrCreateButtonBar_, addInfoIcon,
                          % addDetachButton, reflowChrome_) parent and size the
                          % chrome relative to hCellPanel — never relative to
                          % hPanel, because hPanel may be the content sub-panel.
       ```

       Keep the existing comment that hPanel is set by `widget.render(parentPanel)` accurate by also documenting the DetachedMirror case ("when rendered standalone via DetachedMirror, hCellPanel is empty and hPanel == the mirror's standalone panel").

    2. Update `delete(obj)` (~L88-92): keep deletion of hPanel as-is. Do NOT delete hCellPanel separately — DashboardLayout owns the cell panel lifecycle and will delete it.

    PART B — DashboardLayout.m realizeWidget refactor (~L337-356):

    Replace the current body with:

    ```matlab
    function realizeWidget(obj, widget)
    %REALIZEWIDGET Render a single widget into its pre-allocated panel.
    %   Creates the chrome (full-width WidgetButtonBar + WidgetContentPanel
    %   sub-panel below the bar) BEFORE calling widget.render so the widget's
    %   own graphics children (titles, axes, status text, group headers)
    %   land in the visible content area, never under the bar.
    %
    %   Widgets that don't need chrome (no Description AND no DetachCallback,
    %   or DividerWidget) skip both the bar and the content sub-panel and
    %   render directly into the outer cell panel as before — preserving
    %   zero-chrome behavior for visual-only widgets.
        if widget.Realized, return; end
        if isempty(widget.hPanel) || ~ishandle(widget.hPanel), return; end

        % The outer grid-cell panel was assigned to widget.hPanel by
        % allocatePanels. Pin that handle as hCellPanel so chrome helpers
        % can find it after widget.render reassigns hPanel to the content
        % sub-panel below.
        widget.hCellPanel = widget.hPanel;

        % Remove placeholder
        ph = findobj(widget.hCellPanel, 'Tag', 'placeholder');
        delete(ph);

        % Decide whether this widget needs chrome.
        needsBar = ~isempty(widget.Description) || ...
                   (~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget'));

        if needsBar
            % 1. Create the full-width bar at the top of the cell panel.
            obj.getOrCreateButtonBar_(widget);
            % 2. Create the content sub-panel that fills the cell BELOW the bar.
            contentPanel = obj.createContentPanel_(widget);
            % 3. Render widget content into the content sub-panel.
            %    The widget's render() will assign obj.hPanel = contentPanel,
            %    which is intentional: subsequent refresh/relayout_/findobj
            %    operations on hPanel target the content area, not the cell.
            widget.render(contentPanel);
            % 4. Inject buttons into the existing bar.
            if ~isempty(widget.Description)
                obj.addInfoIcon(widget);
            end
            if ~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget')
                obj.addDetachButton(widget);
            end
        else
            % No chrome — render directly into the cell panel as before.
            widget.render(widget.hCellPanel);
        end

        widget.markRealized();
        widget.Dirty = false;
    end
    ```

    Note: addInfoIcon/addDetachButton are still called AFTER render in the chrome path (preserves the original ordering for those subsystems' theme lookups), but the BAR is created before render so the content panel can size itself relative to bar height.

    PART C — DashboardLayout.m: add createContentPanel_ helper (in `methods (Access = private)` block, immediately after `getOrCreateButtonBar_`):

    ```matlab
    function panel = createContentPanel_(obj, widget) %#ok<INUSL>
    %CREATECONTENTPANEL_ Create the WidgetContentPanel sub-panel that
    %   widgets render their content into. Sized to fill the cell panel
    %   BELOW the WidgetButtonBar so widget content never overlaps chrome.
    %   Idempotent: returns the existing panel if already created.
    %   Tag = 'WidgetContentPanel' (protected by sweepUserChildren_).
        cell = widget.hCellPanel;
        existing = findobj(cell, 'Tag', 'WidgetContentPanel', '-depth', 1);
        if ~isempty(existing) && ishandle(existing(1))
            panel = existing(1);
            return;
        end
        if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
            theme = DashboardTheme('light');
        else
            theme = widget.ParentTheme;
        end
        contentBg = theme.WidgetBackground;
        barH = 28;
        inset = 2;
        oldUnits = get(cell, 'Units');
        set(cell, 'Units', 'pixels');
        pp = get(cell, 'Position');
        set(cell, 'Units', oldUnits);
        contentH = max(1, pp(4) - barH - inset);
        panel = uipanel('Parent', cell, ...
            'Units', 'pixels', ...
            'Position', [0, 0, pp(3), contentH], ...
            'BackgroundColor', contentBg, ...
            'BorderType', 'none', ...
            'Tag', 'WidgetContentPanel');
    end
    ```

    Note: Content panel is full-width (no horizontal inset) and bottom-anchored. Bar uses 2px horizontal inset for visual margin, but content fills the cell horizontally so widget's own padding logic continues to work.

    Add `sweepUserChildren_` protection if such a helper exists in the file: search for the function and add `'WidgetContentPanel'` to its protected-Tags list alongside `'WidgetButtonBar'`. (If sweepUserChildren_ doesn't enumerate Tags explicitly, this step is a no-op.)

    PART D — DashboardLayout.m: revert getOrCreateButtonBar_ to full-width (~L600-614).

    Replace the m52 lines:
    ```matlab
    barW = min(64, max(1, pp(3) - 2 * inset));
    x = max(inset, pp(3) - barW - inset);
    ```
    with:
    ```matlab
    barW = max(1, pp(3) - 2 * inset);
    x = inset;
    ```

    Update the doc-comment block (~L569-575) — replace "small opaque strip in the top-right corner of widget.hPanel" with:

    ```matlab
    %GETORCREATEBUTTONBAR_ Return the per-widget button bar uipanel,
    %   creating it the first time. The bar is a full-width opaque header
    %   strip across the top of widget.hCellPanel (28px tall, inset 2px
    %   from cell edges) that hosts the info + detach buttons.
    %   Widgets render into a sibling WidgetContentPanel sub-panel BELOW
    %   the bar (created by DashboardLayout.realizeWidget via
    %   createContentPanel_) so widget content is never overlapped by the
    %   bar. Tag = 'WidgetButtonBar' (protected by sweepUserChildren_).
    ```

    Also replace `widget.hPanel` references INSIDE getOrCreateButtonBar_ with `widget.hCellPanel`. Specifically:
    - existing-lookup: `findobj(widget.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1)`
    - Position read (the `oldUnits = get(widget.hPanel, ...)` block): swap to widget.hCellPanel.
    - uipanel creation: `'Parent', widget.hCellPanel`.
    - SizeChangedFcn binding: `set(widget.hCellPanel, 'SizeChangedFcn', @(src, ~) DashboardLayout.reflowChrome_(src, barH, inset))` (renamed handler — see PART F).

    PART E — DashboardLayout.m: addInfoIcon / addDetachButton (~L636-683): swap any `widget.hPanel` → `widget.hCellPanel` in `getOrCreateButtonBar_(widget)` callers. The button-position math (xInfo, xDet, barPos(3) - ...) is already barW-relative — it auto-adapts to the new full width with no edits needed.

    PART F — DashboardLayout.m: rename reflowButtonBar_ → reflowChrome_ and extend (~L686-715).

    Replace the body with:

    ```matlab
    function reflowChrome_(hCell, barH, inset)
    %REFLOWCHROME_ SizeChangedFcn handler — re-anchor the WidgetButtonBar
    %   AND resize the WidgetContentPanel after the parent cell panel
    %   resizes. Public so tests can drive a deterministic resize without
    %   relying on SizeChangedFcn firing under -batch.
    %   No-op when the cell has been deleted or chrome isn't there yet.
        if ~ishandle(hCell), return; end
        bar     = findobj(hCell, 'Tag', 'WidgetButtonBar',    '-depth', 1);
        content = findobj(hCell, 'Tag', 'WidgetContentPanel', '-depth', 1);
        oldUnits = get(hCell, 'Units');
        set(hCell, 'Units', 'pixels');
        pp = get(hCell, 'Position');
        set(hCell, 'Units', oldUnits);
        if ~isempty(bar) && ishandle(bar(1))
            barW = max(1, pp(3) - 2 * inset);
            set(bar(1), 'Units', 'pixels', ...
                'Position', [inset, pp(4) - barH - inset, barW, barH]);
            % Re-anchor right-aligned buttons inside the bar.
            det  = findobj(bar(1), 'Tag', 'DetachButton',   '-depth', 1);
            info = findobj(bar(1), 'Tag', 'InfoIconButton', '-depth', 1);
            if ~isempty(det) && ishandle(det(1))
                set(det(1), 'Position', [barW - 24 - 4, 2, 24, 24]);
            end
            if ~isempty(info) && ishandle(info(1))
                set(info(1), 'Position', [barW - 24 - 24 - 4 - 4, 2, 24, 24]);
            end
        end
        if ~isempty(content) && ishandle(content(1))
            contentH = max(1, pp(4) - barH - inset);
            set(content(1), 'Units', 'pixels', ...
                'Position', [0, 0, pp(3), contentH]);
        end
    end
    ```

    Keep a backward-compat shim if any external code (tests, scripts) still calls the old name:

    ```matlab
    function reflowButtonBar_(hCell, barH, inset)
    %REFLOWBUTTONBAR_ Deprecated alias — forwards to reflowChrome_.
        DashboardLayout.reflowChrome_(hCell, barH, inset);
    end
    ```

    (Keep this shim only if grep across the repo finds external callers; otherwise delete reflowButtonBar_ and update all internal references.)

    PART G — Update tests/test_dashboard_widget_button_bar.m for the new contract.

    Rewrite as follows (preserve file location, function name, and the path-helper pattern from the existing file):

    Header:
    ```matlab
    %TEST_DASHBOARD_WIDGET_BUTTON_BAR Regression: bar is full-width with
    %   widget content rendered into a sub-panel BELOW it (no overlap).
    %
    %   Asserts the per-widget button bar (Tag='WidgetButtonBar') is rendered
    %   as a full-width opaque header strip and a sibling WidgetContentPanel
    %   sub-panel hosts the widget's own content. Replaces the m52
    %   right-anchored-strip contract with the mhv full-width-with-content-
    %   panel contract per user instruction "must be full widht .. just
    %   make sure all widget info and displa si bwlow it".
    %
    %   Covers (mhv):
    %     1. bar Position(1) == inset (left-anchored)
    %     2. bar Position(3) ≈ panelWidth - 2*inset (full width)
    %     3. WidgetContentPanel exists, bottom-anchored, full-width
    %     4. content panel top edge <= bar bottom edge (no overlap)
    %     5. info + detach buttons still fit inside the bar (preserved)
    %     6. reflowChrome_ keeps full-width invariant after resize
    %     7. DividerWidget gets NO chrome (no bar, no content panel)
    ```

    Test 1 — full-width left-anchored bar (replaces old "small + right-anchored" assertion):
    ```matlab
    bar = findobj(d.hFigure, 'Tag', 'WidgetButtonBar');
    assert(~isempty(bar), 'WidgetButtonBar uipanel not found');
    bar = bar(1);
    [barPos, panelPos] = getPixelPositions_(bar);
    inset = 2;
    expectedW = panelPos(3) - 2 * inset;
    assert(abs(barPos(3) - expectedW) <= 1, ...
        sprintf('bar width %g != expected full width %g (full-width regression)', ...
        barPos(3), expectedW));
    assert(abs(barPos(1) - inset) <= 1, ...
        sprintf('bar not left-anchored: x=%g (expected ~%g)', barPos(1), inset));
    ```

    Test 2 — content panel exists, sized below bar, full-width:
    ```matlab
    content = findobj(d.hFigure, 'Tag', 'WidgetContentPanel');
    assert(~isempty(content), 'WidgetContentPanel uipanel not found');
    content = content(1);
    [contentPos, cellPos] = getPixelPositions_(content);
    assert(contentPos(2) == 0 || abs(contentPos(2)) <= 1, ...
        sprintf('content panel not bottom-anchored: y=%g', contentPos(2)));
    assert(abs(contentPos(3) - cellPos(3)) <= 1, ...
        sprintf('content panel width %g != cell width %g', contentPos(3), cellPos(3)));
    % Bar bottom in cell-relative pixels:
    barBottom = barPos(2);
    contentTop = contentPos(2) + contentPos(4);
    assert(contentTop <= barBottom + 0.5, ...
        sprintf('content panel overlaps bar (contentTop=%g > barBottom=%g)', ...
        contentTop, barBottom));
    ```

    Test 3 — buttons fit (preserved verbatim from existing Test 2 of the m52 file).

    Test 4 — reflowChrome_ keeps full-width + resizes content panel:
    ```matlab
    % After resize and reflowChrome_:
    set(widgetPanel, 'Position', [pp(1) pp(2) pp(3) - 30 pp(4)]);
    DashboardLayout.reflowChrome_(widgetPanel, 28, 2);
    [barPos, panelPos] = getPixelPositions_(bar);
    assert(abs(barPos(3) - (panelPos(3) - 2*inset)) <= 1, ...
        'bar lost full-width after reflow');
    contentPos = getPixelPositions_(content);
    assert(abs(contentPos(3) - panelPos(3)) <= 1, ...
        'content panel did not resize on reflow');
    assert(contentPos(2) + contentPos(4) <= barPos(2) + 0.5, ...
        'content panel overlaps bar after reflow');
    ```

    Test 5 — DividerWidget has no chrome:
    ```matlab
    d = DashboardEngine('WidgetButtonBarDividerTest');
    d.addWidget('divider', 'Position', [1 1 6 1]);
    d.render();
    set(d.hFigure, 'Visible', 'off');
    % Find the divider's outer cell panel — heuristic: the first uipanel
    % under hCanvas that has no WidgetButtonBar child.
    dividers = findobj(d.hFigure, 'Type', 'uipanel');
    barUnderDivider = false;
    contentUnderDivider = false;
    for k = 1:numel(dividers)
        if ~isempty(findobj(dividers(k), 'Tag', 'WidgetButtonBar', '-depth', 1))
            % skip — this is some other widget's cell
        end
    end
    % Simpler: assert that the engine's widgets list contains a DividerWidget
    % whose hCellPanel has no WidgetButtonBar child.
    w = d.Widgets{1};
    assert(isa(w, 'DividerWidget'), 'expected DividerWidget');
    cell = w.hCellPanel;
    if isempty(cell) || ~ishandle(cell)
        cell = w.hPanel;  % fallback (no-chrome path leaves hCellPanel set anyway)
    end
    assert(isempty(findobj(cell, 'Tag', 'WidgetButtonBar', '-depth', 1)), ...
        'DividerWidget unexpectedly got a WidgetButtonBar');
    assert(isempty(findobj(cell, 'Tag', 'WidgetContentPanel', '-depth', 1)), ...
        'DividerWidget unexpectedly got a WidgetContentPanel');
    close(d.hFigure);
    ```

    (Adapt the divider lookup to whatever public accessor DashboardEngine exposes — `d.Widgets`, `d.getWidgets()`, etc. — verify by reading DashboardEngine.m.)

    Replace existing Test 3 (reflow right-anchor) with the new reflowChrome_ test. Keep `getPixelPositions_` helper and `add_dashboard_path` helper unchanged.

    PART H — Verify and run.

    1. Run the updated regression test: `tests/run_all_tests.m` or directly `test_dashboard_widget_button_bar()`. All assertions must pass.
    2. Spot-check the run_demo industrial dashboard interactively (Page 2 "Feed Line"): GroupWidget header label, StatusWidget title, TextWidget bottom title, BarChartWidget axes title — all visible, none clipped by bar.
    3. Spot-check Page 1 "Overview": Plant Health, Reactor Pressure (live), etc. — all titles visible below their bars.
    4. Verify detached widgets (click detach button) — DetachedMirror still renders correctly with no chrome inside the popout.
    5. Verify dividers render unchanged.

    Reference m52 SUMMARY for context on what's being partially reverted.
  </action>

  <verify>
    <automated>cd /Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/happy-ramanujan-7d436a && matlab -batch "addpath(pwd); install(); cd tests; test_dashboard_widget_button_bar()"</automated>
  </verify>

  <done>
    - DashboardLayout.realizeWidget creates chrome BEFORE calling widget.render when needsBar is true; widget.render receives the WidgetContentPanel as parentPanel.
    - getOrCreateButtonBar_ formula reverted to full-width (`barW = pp(3) - 2*inset; x = inset`); doc-comment updated to reflect "full-width opaque header strip".
    - createContentPanel_ helper exists; produces a bottom-anchored full-width sub-panel sized to (panelWidth, panelHeight - 28 - 2).
    - reflowChrome_ static handler resizes both bar and content panel on cell-panel resize; backward-compat reflowButtonBar_ alias only kept if external callers exist.
    - DashboardWidget.hCellPanel property exists and is set by realizeWidget before render(); chrome helpers use it instead of hPanel for outer-cell lookups.
    - DividerWidget (and any widget with no Description and no DetachCallback) renders directly into the cell panel — no bar, no content panel.
    - tests/test_dashboard_widget_button_bar.m updated in place with all 5 new assertions; full-width assertion replaces the old "<= 64" check; runs green.
    - Manual demo spot-check: Feed Line group header, Feedline Pressure High status title, About Feed Line text title, BarChart axes title — all fully visible, no clipping.
    - DetachedMirror behavior unchanged.
  </done>
</task>

</tasks>

<verification>
1. Automated regression: `test_dashboard_widget_button_bar()` passes all 5 sub-tests including the new full-width contract and DividerWidget no-chrome path.
2. Manual visual check: run `examples/run_demo` (or whatever launches the industrial demo), navigate Page 2 "Feed Line" — confirm:
   - Group header "Feed Line Signals" visible (not covered by bar above)
   - StatusWidget "Feedline Pressure High" title visible
   - TextWidget "About Feed Line" header visible
   - BarChartWidget axes title visible
3. Manual visual check Page 1 "Overview": all top-level widget titles fully visible below their full-width bars.
4. Click any detach button — confirm DetachedMirror window opens and renders the widget correctly (no chrome inside the mirror).
5. Resize the figure — confirm bars stay full-width and content stays below them.
</verification>

<success_criteria>
- User-visible: full-width bar is back AND no widget content is clipped by it.
- Tests: `test_dashboard_widget_button_bar()` passes (3 → 5 sub-tests, with full-width and content-panel-below contracts).
- Code: DashboardLayout.realizeWidget reordered; getOrCreateButtonBar_/reflowChrome_ use full-width formula; DashboardWidget.hCellPanel introduced; createContentPanel_ helper added; DividerWidget no-chrome path preserved.
- No regressions in DetachedMirror, widget refresh/relayout_, or scrollbar behavior.
</success_criteria>

<output>
After completion, create `.planning/quick/260508-mhv-full-width-widget-bar-with-content-panel/260508-mhv-SUMMARY.md` documenting:
- Problem (full-width bar overlaid widget content; m52 fixed by shrinking, user wants full-width restored without truncation).
- Fix (chrome-first realizeWidget; new content sub-panel; new hCellPanel property; bar geometry reverted; reflow extended).
- Files modified.
- Test contract change (m52 right-anchored → mhv full-width-with-content-below).
- Provides/affects/decisions per the SUMMARY template (mirror m52's frontmatter shape).
</output>
