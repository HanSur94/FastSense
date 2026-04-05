# Mixed Tile Types (Raw Axes in FastPlotFigure) Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow FastPlotFigure tiles to contain either optimized FastPlot instances or raw MATLAB axes for any plot type (bar, scatter, histogram, etc.).

**Architecture:** Add a `RawAxesTiles` logical array to FastPlotFigure. New `axes(n)` method creates a themed raw axes at the tile position. Existing `tile(n)` and `axes(n)` are mutually exclusive per slot. `renderAll()`, `reapplyTheme()`, label methods, and live mode skip/adapt for raw axes tiles.

**Tech Stack:** MATLAB/Octave, FastPlot library

---

## Chunk 1: Core Implementation

### Task 1: Add RawAxesTiles property and axes() method

**Files:**
- Modify: `libs/FastPlot/FastPlotFigure.m:88-100` (add property)
- Modify: `libs/FastPlot/FastPlotFigure.m:159-193` (add guard to tile(), add axes() method)

- [ ] **Step 1: Add RawAxesTiles property**

In `FastPlotFigure.m`, add to the `properties (SetAccess = private)` block (after line 92):

```matlab
RawAxesTiles = []     % logical array: true = raw axes, false = FastPlot
```

And in the constructor, after `obj.TileYLabels = cell(1, nTiles);` (line 135), add:

```matlab
obj.RawAxesTiles = false(1, nTiles);
```

- [ ] **Step 2: Add guard to tile() method**

In `tile()`, after the bounds check (after line 176), add a guard before the lazy-creation block:

```matlab
if obj.RawAxesTiles(n)
    error('FastPlotFigure:tileConflict', ...
        'Tile %d is a raw axes tile. Use axes(%d) to access it.', n, n);
end
```

- [ ] **Step 3: Add axes() method**

Add the `axes()` method in the `methods (Access = public)` block, after the `tile()` method (after line 193):

```matlab
function ax = axes(obj, n)
    %AXES Get or create a raw MATLAB axes for tile n.
    %   ax = fig.axes(n) returns a themed MATLAB axes handle at the
    %   position for tile n. Use for non-FastPlot plot types (bar,
    %   scatter, histogram, stem, etc.). The axes gets theme colors
    %   applied but no FastPlot optimization.
    %
    %   Mutually exclusive with tile(n) — a tile cannot be both a
    %   FastPlot and a raw axes.
    %
    %   Input:
    %     n — tile index (1 to rows*cols, row-major order)
    %
    %   Output:
    %     ax — MATLAB axes handle
    %
    %   Example:
    %     ax = fig.axes(2);
    %     bar(ax, [1 2 3], [10 20 15]);
    %
    %   See also tile, setTileSpan.
    nTiles = obj.Grid(1) * obj.Grid(2);
    if n < 1 || n > nTiles
        error('FastPlotFigure:outOfBounds', ...
            'Tile %d is out of range (1-%d).', n, nTiles);
    end

    if ~isempty(obj.Tiles{n})
        error('FastPlotFigure:tileConflict', ...
            'Tile %d is a FastPlot tile. Use tile(%d) to access it.', n, n);
    end

    if isempty(obj.TileAxes{n})
        ax = obj.createTileAxes(n);
        obj.TileAxes{n} = ax;
        obj.RawAxesTiles(n) = true;
        obj.applyThemeToAxes(ax);
    else
        ax = obj.TileAxes{n};
    end
end
```

- [ ] **Step 4: Add applyThemeToAxes() private method**

Add a private helper in the `methods (Access = private)` block (after `createTileAxes`, around line 680):

```matlab
function applyThemeToAxes(obj, ax)
    %APPLYTHEMETOAXES Apply figure theme colors to a raw axes.
    set(ax, 'Color', obj.Theme.AxesColor, ...
            'XColor', obj.Theme.ForegroundColor, ...
            'YColor', obj.Theme.ForegroundColor, ...
            'GridColor', obj.Theme.GridColor);
    if ~isempty(obj.Theme.GridAlpha)
        set(ax, 'GridAlpha', obj.Theme.GridAlpha);
    end
    set(ax, 'FontSize', obj.Theme.FontSize);
end
```

- [ ] **Step 5: Commit**

```bash
git add libs/FastPlot/FastPlotFigure.m
git commit -m "feat: add axes() method for raw MATLAB axes tiles in FastPlotFigure"
```

### Task 2: Update renderAll() to skip raw axes tiles

**Files:**
- Modify: `libs/FastPlot/FastPlotFigure.m:302-383` (renderAll method)

- [ ] **Step 1: Update tile collection loop in renderAll()**

In `renderAll()`, the loop at lines 320-324 collects tiles to render. Replace:

```matlab
% Collect tiles that need rendering
tilesToRender = [];
for i = 1:numel(obj.Tiles)
    if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
        tilesToRender(end+1) = i; %#ok<AGROW>
    end
end
```

With:

```matlab
% Collect FastPlot tiles that need rendering (skip raw axes tiles)
tilesToRender = [];
for i = 1:numel(obj.Tiles)
    if obj.RawAxesTiles(i)
        continue;
    end
    if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
        tilesToRender(end+1) = i; %#ok<AGROW>
    end
end
```

- [ ] **Step 2: Update label application loop in renderAll()**

In `renderAll()`, the label loop at lines 361-376 accesses `obj.Tiles{i}.IsRendered` and `obj.Tiles{i}.hAxes`. Add a raw-axes branch. Replace:

```matlab
% Apply buffered titles and labels now that axes exist
for i = 1:numel(obj.Tiles)
    if isempty(obj.Tiles{i}) || ~obj.Tiles{i}.IsRendered
        continue;
    end
    ax = obj.Tiles{i}.hAxes;
    if ~isempty(obj.TileTitles{i})
        title(ax, obj.TileTitles{i}, 'FontSize', obj.Theme.TitleFontSize, ...
            'Color', obj.Theme.ForegroundColor);
    end
    if ~isempty(obj.TileXLabels{i})
        xlabel(ax, obj.TileXLabels{i}, 'Color', obj.Theme.ForegroundColor);
    end
    if ~isempty(obj.TileYLabels{i})
        ylabel(ax, obj.TileYLabels{i}, 'Color', obj.Theme.ForegroundColor);
    end
end
```

With:

```matlab
% Apply buffered titles and labels now that axes exist
for i = 1:numel(obj.Tiles)
    % Determine the axes handle for this tile
    if obj.RawAxesTiles(i)
        if isempty(obj.TileAxes{i}); continue; end
        ax = obj.TileAxes{i};
    else
        if isempty(obj.Tiles{i}) || ~obj.Tiles{i}.IsRendered
            continue;
        end
        ax = obj.Tiles{i}.hAxes;
    end
    if ~isempty(obj.TileTitles{i})
        title(ax, obj.TileTitles{i}, 'FontSize', obj.Theme.TitleFontSize, ...
            'Color', obj.Theme.ForegroundColor);
    end
    if ~isempty(obj.TileXLabels{i})
        xlabel(ax, obj.TileXLabels{i}, 'Color', obj.Theme.ForegroundColor);
    end
    if ~isempty(obj.TileYLabels{i})
        ylabel(ax, obj.TileYLabels{i}, 'Color', obj.Theme.ForegroundColor);
    end
end
```

- [ ] **Step 3: Commit**

```bash
git add libs/FastPlot/FastPlotFigure.m
git commit -m "feat: renderAll skips raw axes tiles and applies labels to both tile types"
```

### Task 3: Update reapplyTheme() and label methods for raw axes tiles

**Files:**
- Modify: `libs/FastPlot/FastPlotFigure.m:393-414` (reapplyTheme)
- Modify: `libs/FastPlot/FastPlotFigure.m:247-300` (tileTitle, tileXLabel, tileYLabel)

- [ ] **Step 1: Update reapplyTheme()**

Replace the reapplyTheme method:

```matlab
function reapplyTheme(obj)
    set(obj.hFigure, 'Color', obj.Theme.Background);
    for i = 1:numel(obj.Tiles)
        if obj.RawAxesTiles(i)
            % Raw axes: apply theme colors directly
            if ~isempty(obj.TileAxes{i}) && ishandle(obj.TileAxes{i})
                obj.applyThemeToAxes(obj.TileAxes{i});
            end
        elseif ~isempty(obj.Tiles{i}) && obj.Tiles{i}.IsRendered
            if ~isempty(obj.TileThemes) && i <= numel(obj.TileThemes) && ~isempty(obj.TileThemes{i})
                obj.Tiles{i}.Theme = mergeTheme(obj.Theme, obj.TileThemes{i});
            else
                obj.Tiles{i}.Theme = obj.Theme;
            end
            obj.Tiles{i}.reapplyTheme();
        end
    end
end
```

- [ ] **Step 2: Update tileTitle()**

Replace the tileTitle method:

```matlab
function tileTitle(obj, n, str)
    obj.TileTitles{n} = str;
    ax = obj.getTileAxesHandle(n);
    if ~isempty(ax)
        title(ax, str, 'FontSize', obj.Theme.TitleFontSize, ...
            'Color', obj.Theme.ForegroundColor);
    end
end
```

- [ ] **Step 3: Update tileXLabel()**

Replace the tileXLabel method:

```matlab
function tileXLabel(obj, n, str)
    obj.TileXLabels{n} = str;
    ax = obj.getTileAxesHandle(n);
    if ~isempty(ax)
        xlabel(ax, str, 'Color', obj.Theme.ForegroundColor);
    end
end
```

- [ ] **Step 4: Update tileYLabel()**

Replace the tileYLabel method:

```matlab
function tileYLabel(obj, n, str)
    obj.TileYLabels{n} = str;
    ax = obj.getTileAxesHandle(n);
    if ~isempty(ax)
        ylabel(ax, str, 'Color', obj.Theme.ForegroundColor);
    end
end
```

- [ ] **Step 5: Add getTileAxesHandle() private helper**

Add in the `methods (Access = private)` block:

```matlab
function ax = getTileAxesHandle(obj, n)
    %GETTILEAXESHANDLE Get the axes handle for tile n (FastPlot or raw).
    if obj.RawAxesTiles(n)
        ax = obj.TileAxes{n};
        if ~isempty(ax) && ~ishandle(ax); ax = []; end
    else
        fp = obj.Tiles{n};
        if ~isempty(fp) && ~isempty(fp.hAxes) && ishandle(fp.hAxes)
            ax = fp.hAxes;
        else
            % Tile exists but not rendered yet — call tile() to create axes
            if ~isempty(fp)
                ax = [];
            else
                fp = obj.tile(n);
                if ~isempty(fp.hAxes) && ishandle(fp.hAxes)
                    ax = fp.hAxes;
                else
                    ax = [];
                end
            end
        end
    end
end
```

- [ ] **Step 6: Commit**

```bash
git add libs/FastPlot/FastPlotFigure.m
git commit -m "feat: reapplyTheme and label methods support raw axes tiles"
```

### Task 4: Update live mode to skip raw axes tiles

**Files:**
- Modify: `libs/FastPlot/FastPlotFigure.m:457-462` (startLive view mode loop)

- [ ] **Step 1: Guard live view mode propagation**

In `startLive()`, the loop at lines 458-462 sets LiveViewMode on all tiles. Replace:

```matlab
% Set view mode on all tiles
for i = 1:numel(obj.Tiles)
    if ~isempty(obj.Tiles{i})
        obj.Tiles{i}.LiveViewMode = obj.LiveViewMode;
    end
end
```

With:

```matlab
% Set view mode on FastPlot tiles only (raw axes tiles are unmanaged)
for i = 1:numel(obj.Tiles)
    if ~obj.RawAxesTiles(i) && ~isempty(obj.Tiles{i})
        obj.Tiles{i}.LiveViewMode = obj.LiveViewMode;
    end
end
```

- [ ] **Step 2: Guard setViewMode()**

In `setViewMode()`, update the loop similarly. Replace:

```matlab
for i = 1:numel(obj.Tiles)
    if ~isempty(obj.Tiles{i})
        obj.Tiles{i}.LiveViewMode = mode;
    end
end
```

With:

```matlab
for i = 1:numel(obj.Tiles)
    if ~obj.RawAxesTiles(i) && ~isempty(obj.Tiles{i})
        obj.Tiles{i}.LiveViewMode = mode;
    end
end
```

- [ ] **Step 3: Commit**

```bash
git add libs/FastPlot/FastPlotFigure.m
git commit -m "feat: live mode skips raw axes tiles"
```

### Task 5: Update class documentation

**Files:**
- Modify: `libs/FastPlot/FastPlotFigure.m:1-67` (class docstring)

- [ ] **Step 1: Update class docstring**

Add to the methods list in the class docstring (after `tile` entry, around line 38):

```matlab
%     axes              — get or create a raw MATLAB axes for tile n
```

Add a new example block after the existing tile spanning example (around line 63):

```matlab
%   Example — mixed tile types:
%     fig = FastPlotFigure(2, 2, 'Theme', 'dark');
%     fig.tile(1).addLine(t, y1);           % FastPlot (optimized)
%     ax = fig.axes(2); bar(ax, x, y2);     % raw axes (bar chart)
%     ax = fig.axes(3); scatter(ax, x, y3); % raw axes (scatter)
%     fig.tile(4).addLine(t, y4);           % FastPlot (optimized)
%     fig.renderAll();
```

- [ ] **Step 2: Commit**

```bash
git add libs/FastPlot/FastPlotFigure.m
git commit -m "docs: update FastPlotFigure docstring for axes() method"
```

## Chunk 2: Tests

### Task 6: Write tests for mixed tile types

**Files:**
- Modify: `tests/test_figure_layout.m` (add new test cases)

- [ ] **Step 1: Add test for axes() basic usage**

Append before the final `fprintf` line in `test_figure_layout.m`:

```matlab
% testAxesReturnsRawAxes
fig = FastPlotFigure(2, 2);
ax = fig.axes(1);
assert(ishandle(ax), 'testAxesReturnsRawAxes: valid handle');
assert(strcmp(get(ax, 'Type'), 'axes'), 'testAxesReturnsRawAxes: is axes');
close(fig.hFigure);
```

- [ ] **Step 2: Add test for axes() lazy instantiation**

```matlab
% testAxesLazy
fig = FastPlotFigure(2, 1);
ax1 = fig.axes(1);
ax2 = fig.axes(1);
assert(isequal(ax1, ax2), 'testAxesLazy: same handle on repeat call');
close(fig.hFigure);
```

- [ ] **Step 3: Add test for mutual exclusion (tile then axes)**

```matlab
% testTileThenAxesErrors
fig = FastPlotFigure(2, 1);
fig.tile(1);
threw = false;
try
    fig.axes(1);
catch
    threw = true;
end
assert(threw, 'testTileThenAxesErrors');
close(fig.hFigure);
```

- [ ] **Step 4: Add test for mutual exclusion (axes then tile)**

```matlab
% testAxesThenTileErrors
fig = FastPlotFigure(2, 1);
fig.axes(1);
threw = false;
try
    fig.tile(1);
catch
    threw = true;
end
assert(threw, 'testAxesThenTileErrors');
close(fig.hFigure);
```

- [ ] **Step 5: Add test for mixed dashboard renderAll**

```matlab
% testMixedRenderAll
fig = FastPlotFigure(2, 2);
fig.tile(1).addLine(1:50, rand(1,50));
ax2 = fig.axes(2); bar(ax2, [1 2 3], [10 20 15]);
fig.tile(3).addLine(1:50, rand(1,50));
ax4 = fig.axes(4); plot(ax4, 1:10, rand(1,10));
fig.renderAll();
assert(fig.tile(1).IsRendered, 'testMixedRenderAll: tile 1 rendered');
assert(fig.tile(3).IsRendered, 'testMixedRenderAll: tile 3 rendered');
% Raw axes tiles should still have valid handles
assert(ishandle(ax2), 'testMixedRenderAll: ax2 valid');
assert(ishandle(ax4), 'testMixedRenderAll: ax4 valid');
close(fig.hFigure);
```

- [ ] **Step 6: Add test for axes theme application**

```matlab
% testAxesThemeApplied
fig = FastPlotFigure(1, 1, 'Theme', 'dark');
ax = fig.axes(1);
bgColor = get(ax, 'Color');
assert(all(bgColor < [0.3 0.3 0.3]), 'testAxesThemeApplied: dark background');
close(fig.hFigure);
```

- [ ] **Step 7: Add test for labels on raw axes tiles**

```matlab
% testLabelsOnRawAxes
fig = FastPlotFigure(2, 1);
ax = fig.axes(1);
bar(ax, [1 2 3], [10 20 15]);
fig.tileTitle(1, 'Bar Chart');
fig.tileXLabel(1, 'Category');
fig.tileYLabel(1, 'Value');
% No error = pass; verify title text
titleObj = get(ax, 'Title');
assert(strcmp(get(titleObj, 'String'), 'Bar Chart'), 'testLabelsOnRawAxes: title');
close(fig.hFigure);
```

- [ ] **Step 8: Add test for axes out of bounds**

```matlab
% testAxesOutOfBounds
fig = FastPlotFigure(2, 2);
threw = false;
try
    fig.axes(5);
catch
    threw = true;
end
assert(threw, 'testAxesOutOfBounds');
close(fig.hFigure);
```

- [ ] **Step 9: Add test for tile spanning on raw axes**

```matlab
% testAxesTileSpanning
fig = FastPlotFigure(2, 2);
fig.setTileSpan(1, [1 2]);
ax = fig.axes(1);
pos = get(ax, 'Position');
assert(pos(3) > 0.4, 'testAxesTileSpanning: wide enough');
close(fig.hFigure);
```

- [ ] **Step 10: Update test count in fprintf**

Change the final line from:
```matlab
fprintf('    All 12 figure layout tests passed.\n');
```
To:
```matlab
fprintf('    All 21 figure layout tests passed.\n');
```

- [ ] **Step 11: Commit**

```bash
git add tests/test_figure_layout.m
git commit -m "test: add tests for raw axes tiles in FastPlotFigure"
```

### Task 7: Run tests and verify

- [ ] **Step 1: Run the figure layout tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_figure_layout()"`

Expected: `All 21 figure layout tests passed.`

- [ ] **Step 2: Run full test suite**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); run_all_tests()"`

Expected: All existing tests still pass, no regressions.

- [ ] **Step 3: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: address test failures from mixed tile type feature"
```
