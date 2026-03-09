# FastPlotToolbar Design

## Overview

A standalone `FastPlotToolbar` class that adds a custom toolbar to any FastPlot or FastPlotFigure figure. Six buttons with embedded pixel-art icons. Works in both MATLAB and GNU Octave.

## API

```matlab
% Single plot
fp = FastPlot();
fp.addLine(x, y);
fp.render();
tb = FastPlotToolbar(fp);

% Dashboard
fig = FastPlotFigure(2, 2, 'Theme', 'dark');
fig.renderAll();
tb = FastPlotToolbar(fig);
```

## Toolbar Buttons (left to right)

| Button | Type | Icon | Behavior |
|--------|------|------|----------|
| Data Cursor | toggle | crosshair + dot | Click on plot -> tooltip with exact (x, y). Snaps to nearest data point. Toggle off to dismiss. |
| Crosshair | toggle | + cross | Mouse motion draws horizontal + vertical dashed lines with (x, y) text in corner. Active on hovered tile only. |
| Toggle Grid | push | grid pattern | Cycles: grid on -> grid off |
| Toggle Legend | push | "L" box | Toggles legend visibility on/off |
| Autoscale Y | push | vertical arrows | Fits Y-axis to min/max of currently visible data (respects current X zoom) |
| Export PNG | push | camera | Opens save dialog, exports current figure view to PNG |

## Architecture

```
FastPlotToolbar.m
  Properties
    Target         - FastPlot or FastPlotFigure handle
    hToolbar       - uitoolbar handle
    hCursorBtn     - uitoggletool handle
    hCrosshairBtn  - uitoggletool handle
    Mode           - 'none' | 'cursor' | 'crosshair'
    hCrosshairH/V  - line handles for crosshair
    hCursorText    - text annotation handle
    hCrosshairText - text annotation handle

  Constructor(target)
    Resolve figure handle from FastPlot or FastPlotFigure
    Create uitoolbar on figure
    Add 6 buttons with generated CData icons
    Install callbacks

  Callbacks
    onDataCursor(toggled)  - install/remove ButtonDownFcn on axes
    onCrosshair(toggled)   - install/remove WindowButtonMotionFcn
    onToggleGrid()         - toggle grid on active axes
    onToggleLegend()       - toggle legend visibility
    onAutoscaleY()         - compute visible Y range, set YLim
    onExportPNG()          - uiputfile -> print -dpng

  Helpers
    getActiveAxes()        - find axes under mouse pointer
    getAllAxes()            - get all FastPlot axes from target
    snapToNearest(ax,x,y)  - find closest data point on any line
    makeIcon(name)         - return 16x16x3 RGB CData
```

## Key Implementation Details

- **Data cursor snap**: Uses binary search on visible X data, then finds the line with the closest Y at that X. Displays a small marker + text box.
- **Crosshair**: Two dashed lines (h/v) updated on WindowButtonMotionFcn. Text readout at top-right of active axes. Cleaned up when toggling off or leaving axes.
- **Autoscale Y**: Iterates all lines in the active FastPlot, finds min/max of Y data within current XLim, adds 5% padding, sets YLim.
- **Mutual exclusion**: Data cursor and crosshair are mutually exclusive toggles -- activating one deactivates the other.
- **Dashboard support**: getActiveAxes() uses pointer position to determine which tile the mouse is over. All actions apply to that tile's FastPlot instance.
- **Icons**: 16x16x3 RGB matrices defined in code. No external file dependencies.
- **Future extension**: LinkedMode property could later broadcast crosshair/cursor to all tiles.

## Files

| File | Action |
|------|--------|
| `FastPlotToolbar.m` | New - the toolbar class |
| `tests/test_toolbar.m` | New - test suite |
| `examples/example_toolbar.m` | New - demo example |
| `README.md` | Update - add toolbar section |
