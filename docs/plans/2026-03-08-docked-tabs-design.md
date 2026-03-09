# FastPlotDock — Tabbed Dashboard Container

## Goal

A single-window container that docks multiple `FastPlotFigure` dashboards into tabs. Click a tab to switch between dashboards. Only one tab is visible at a time, but all tabs stay alive (live mode keeps polling on hidden tabs).

## API

```matlab
% Build dashboards independently
fig1 = FastPlotFigure(3, 3, 'Theme', 'dark');
fp = fig1.tile(1); fp.addLine(x, y); ...

fig2 = FastPlotFigure(2, 2, 'Theme', 'dark');
fp = fig2.tile(1); fp.addLine(x, y); ...

% Dock into one window
dock = FastPlotDock('Theme', 'dark', 'Name', 'Control Room');
dock.addTab(fig1, 'Temperature Overview');
dock.addTab(fig2, 'Pressure Summary');
dock.render();

% Programmatic switching
dock.selectTab(2);

% Add tab after render
dock.addTab(fig3, 'Vibration');
```

## Architecture

### Approach: Show/Hide Axes

All tabs' axes are pre-rendered into a single `figure()`. On tab switch, the old tab's axes, toolbar, and children are set `Visible='off'`; the new tab's are set `Visible='on'`. This gives instant switching with no re-render cost.

### New Class: `FastPlotDock`

**File:** `FastPlotDock.m`

**Properties:**
- `Theme` — FastPlotTheme struct
- `hFigure` — the shared figure handle
- `Tabs` — cell array of structs: `{Name, Figure, hButtons, IsRendered}`
- `ActiveTab` — index of currently visible tab
- `TabBarHeight` — normalized height reserved for tab buttons (default ~0.04)

**Methods:**
- `FastPlotDock(varargin)` — constructor, creates the figure, parses Theme/Name/Position
- `addTab(fig, name)` — registers a FastPlotFigure, sets its ParentFigure to the dock's figure
- `render()` — renders all tabs (each fig.renderAll()), creates tab bar buttons, shows first tab
- `selectTab(n)` — hides current tab's axes/toolbar, shows tab n's axes/toolbar
- `delete()` — cleanup timers, close figure

**Tab bar:**
- Row of `uicontrol('style','togglebutton')` at the top of the figure
- Active tab highlighted with theme accent color
- Fixed height, tabs evenly distributed or fixed-width

**Visibility toggling:**
- Each `FastPlotFigure` tracks its axes in `TileAxes` and toolbar in `FastPlotToolbar`
- `selectTab` iterates all axes + toolbar controls for the old/new tab and toggles `Visible`
- Line objects, patches, text labels inherit parent axes visibility automatically

### Changes to `FastPlotFigure`

Add a `ParentFigure` option to the constructor:

```matlab
fig = FastPlotFigure(3, 3, 'ParentFigure', dockHandle, 'Theme', 'dark');
```

When `ParentFigure` is set:
- Skip the `figure('Visible','off', ...)` call
- Set `obj.hFigure = parentFigureHandle`
- All tile axes are created in the parent figure as normal

The dock also provides a content area offset so tile positions account for the tab bar height at the top.

**New properties on FastPlotFigure:**
- `ContentOffset` — `[left bottom width height]` normalized region available for tiles (default `[0 0 1 1]`, dock sets it to exclude tab bar)

`computeTilePosition` uses `ContentOffset` to map tile grid positions into the available region.

### Per-Tab Toolbar

Each `FastPlotFigure` already creates its own toolbar via `FastPlotToolbar`. Since each figure renders into the dock's shared window, the toolbar controls are part of that figure's axes/UI objects. On tab switch, the toolbar buttons are shown/hidden along with the axes.

### Live Mode on Hidden Tabs

No changes needed. `FastPlotFigure` live timers update `XData`/`YData` on axes regardless of visibility. When the user switches to that tab, the latest data is already there. The `drawnow` calls in live updates will still work since the axes exist (just not visible).

### Edge Cases

- **Empty dock** — `render()` with no tabs shows empty window
- **Single tab** — tab bar still visible (shows one tab button)
- **Mixed themes** — each tab can have its own theme; tab bar uses the dock's theme
- **Figure resize** — resize callback recomputes all tile positions for all tabs (not just active)
- **Close figure** — dock's `CloseRequestFcn` stops all live timers across all tabs before closing

## Files

| File | Action |
|------|--------|
| `FastPlotDock.m` | Create — new tabbed container class |
| `FastPlotFigure.m` | Modify — add `ParentFigure` and `ContentOffset` support |

## Not In Scope

- Tab close buttons
- Tab reordering / drag
- Split panels within a tab
- Saving/restoring dock layouts
