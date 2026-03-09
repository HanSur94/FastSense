# Lazy Tab Rendering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `FastPlotDock` only render the active tab on startup, deferring other tabs until first viewed.

**Architecture:** Add `IsRendered` tracking to each tab. Extract render logic into `renderTab(idx)`. Gate `selectTab()` on `IsRendered` to trigger lazy rendering on first switch.

**Tech Stack:** MATLAB OOP (handle class), no new dependencies.

---

### Task 1: Add IsRendered field and extract renderTab()

**Files:**
- Modify: `FastPlotDock.m:36` (Tabs struct definition)
- Modify: `FastPlotDock.m:338` (private methods section — add renderTab)

**Step 1: Add IsRendered to Tabs struct initializer**

In `FastPlotDock.m` line 36, change:

```matlab
Tabs = struct('Name', {}, 'Figure', {}, 'Toolbar', {}, 'Panel', {})
```

to:

```matlab
Tabs = struct('Name', {}, 'Figure', {}, 'Toolbar', {}, 'Panel', {}, 'IsRendered', {})
```

**Step 2: Add renderTab() private method**

In `FastPlotDock.m`, add this method inside the `methods (Access = private)` block (after `reparentAxes`):

```matlab
function renderTab(obj, idx)
    %RENDERTAB Render a single tab: figure, axes reparenting, toolbar.
    obj.Tabs(idx).Figure.renderAll();
    obj.reparentAxes(idx);
    obj.Tabs(idx).Toolbar = FastPlotToolbar(obj.Tabs(idx).Figure);
    obj.Tabs(idx).IsRendered = true;
end
```

**Step 3: Commit**

```
feat: add IsRendered tracking and renderTab() helper to FastPlotDock
```

---

### Task 2: Make render() only render the first tab

**Files:**
- Modify: `FastPlotDock.m:107-131` (render method)

**Step 1: Replace the render loop with lazy logic**

Replace the `render()` method body (lines 107-131) with:

```matlab
function render(obj)
    %RENDER Render active tab, create tab bar, show first tab.
    if isempty(obj.Tabs)
        set(obj.hFigure, 'Visible', 'on');
        return;
    end

    % Mark all tabs as not yet rendered
    for i = 1:numel(obj.Tabs)
        obj.Tabs(i).IsRendered = false;
    end

    % Only render the first tab now
    obj.renderTab(1);

    % Hide all tabs (selectTab will show tab 1)
    for i = 1:numel(obj.Tabs)
        obj.setTabVisible(i, false);
    end

    % Create the tab bar buttons
    obj.createTabBar();

    % Show the first tab
    obj.selectTab(1);

    set(obj.hFigure, 'Visible', 'on');
    drawnow;
end
```

**Step 2: Commit**

```
feat: defer non-active tab rendering in FastPlotDock.render()
```

---

### Task 3: Add lazy rendering to selectTab()

**Files:**
- Modify: `FastPlotDock.m:133-150` (selectTab method)

**Step 1: Add lazy render check to selectTab()**

Replace the `selectTab()` method (lines 133-150) with:

```matlab
function selectTab(obj, n)
    %SELECTTAB Switch to tab n, rendering it lazily if needed.
    if n < 1 || n > numel(obj.Tabs)
        error('FastPlotDock:outOfBounds', ...
            'Tab %d is out of range (1-%d).', n, numel(obj.Tabs));
    end

    % Lazy render on first switch
    if ~obj.Tabs(n).IsRendered
        obj.renderTab(n);
    end

    % Hide current tab
    if obj.ActiveTab >= 1 && obj.ActiveTab <= numel(obj.Tabs)
        obj.setTabVisible(obj.ActiveTab, false);
        obj.styleTabButton(obj.ActiveTab, false);
    end

    % Show new tab
    obj.setTabVisible(n, true);
    obj.styleTabButton(n, true);
    obj.ActiveTab = n;
end
```

**Step 2: Commit**

```
feat: lazy-render tabs on first switch in selectTab()
```

---

### Task 4: Update addTab() to set IsRendered correctly

**Files:**
- Modify: `FastPlotDock.m:70-105` (addTab method)

**Step 1: Set IsRendered in addTab()**

In `addTab()`, after line 95 (`obj.Tabs(idx).Panel = panel;`), add:

```matlab
obj.Tabs(idx).IsRendered = false;
```

Then in the "already rendered" branch (line 97-104), after line 99 (`fig.renderAll();`), the `renderTab` isn't used here because the existing code also calls `setTabVisible(idx, false)` and `addTabButton(idx)` which `renderTab` doesn't do. Instead, just set:

```matlab
obj.Tabs(idx).IsRendered = true;
```

after line 101 (`obj.Tabs(idx).Toolbar = FastPlotToolbar(fig);`).

The full updated addTab:

```matlab
function addTab(obj, fig, name)
    %ADDTAB Register a FastPlotFigure as a tab.
    %   dock.addTab(fig, 'Tab Name')

    % Ensure the figure renders into our window
    if isempty(fig.ParentFigure) || fig.ParentFigure ~= obj.hFigure
        fig.ParentFigure = obj.hFigure;
        fig.hFigure = obj.hFigure;
    end

    % Tiles fill the full panel (panel handles the tab bar offset)
    fig.ContentOffset = [0, 0, 1, 1];

    % Create a panel for this tab's content
    tabH = obj.TabBarHeight;
    panel = uipanel(obj.hFigure, 'Units', 'normalized', ...
        'Position', [0, 0, 1, 1 - tabH], ...
        'BorderType', 'none', ...
        'BackgroundColor', obj.Theme.Background);

    % Append to tabs
    idx = numel(obj.Tabs) + 1;
    obj.Tabs(idx).Name = name;
    obj.Tabs(idx).Figure = fig;
    obj.Tabs(idx).Toolbar = [];
    obj.Tabs(idx).Panel = panel;
    obj.Tabs(idx).IsRendered = false;

    % If already rendered, render this tab immediately
    if obj.ActiveTab >= 1
        fig.renderAll();
        obj.reparentAxes(idx);
        obj.Tabs(idx).Toolbar = FastPlotToolbar(fig);
        obj.Tabs(idx).IsRendered = true;
        obj.setTabVisible(idx, false);
        obj.addTabButton(idx);
    end
end
```

**Step 2: Commit**

```
feat: set IsRendered flag in addTab()
```

---

### Task 5: Handle unrendered tabs in undockTab() and removeTab()

**Files:**
- Modify: `FastPlotDock.m:209-297` (undockTab method)
- Modify: `FastPlotDock.m:152-207` (removeTab method)

**Step 1: Guard undockTab() for unrendered tabs**

In `undockTab()`, after the bounds check (line 216-218), add:

```matlab
% Render if not yet rendered (need axes to reparent)
if ~obj.Tabs(n).IsRendered
    obj.renderTab(n);
end
```

**Step 2: Guard removeTab() for unrendered tabs**

In `removeTab()`, wrap the toolbar deletion (lines 169-172) with an IsRendered check. The panel delete (line 164-166) is fine as-is since the panel always exists. Change the toolbar block to:

```matlab
% Delete toolbar (only exists if tab was rendered)
if obj.Tabs(n).IsRendered
    tb = obj.Tabs(n).Toolbar;
    if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
        delete(tb.hToolbar);
    end
end
```

**Step 3: Commit**

```
feat: handle unrendered tabs in undockTab() and removeTab()
```

---

### Task 6: Manual verification

**Step 1: Test basic lazy rendering**

```matlab
% Create a dock with 3 tabs
dock = FastPlotDock('Theme', 'dark', 'Name', 'Lazy Test');
x = linspace(0, 10, 1e6);

fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fig1.tile(1).addLine(x, sin(x), 'Name', 'Sin');
dock.addTab(fig1, 'Tab 1');

fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fig2.tile(1).addLine(x, cos(x), 'Name', 'Cos');
dock.addTab(fig2, 'Tab 2');

fig3 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
fig3.tile(1).addLine(x, tan(x), 'Name', 'Tan');
dock.addTab(fig3, 'Tab 3');

tic; dock.render(); toc
% Expected: only tab 1 rendered, should be ~3x faster than before
```

**Step 2: Test tab switching**

```
% Click tab 2 — should render on first click
% Click tab 3 — should render on first click
% Click tab 2 again — should be instant (already rendered)
```

**Step 3: Test removeTab on unrendered tab**

```matlab
% Before clicking tab 3, call:
dock.removeTab(3);
% Should not error
```

**Step 4: Test undockTab on unrendered tab**

```matlab
% Before clicking tab 2, call:
dock.undockTab(2);
% Should render then undock into standalone figure
```

**Step 5: Commit**

```
feat: lazy tab rendering in FastPlotDock — render only active tab on startup
```
