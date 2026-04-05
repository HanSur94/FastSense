# Hierarchical Progress Bar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the flat single-bar progress with a hierarchical log-style display that shows progress at dock/dashboard/axes levels, where completed levels become permanent log lines and only the deepest active level animates with `\r`.

**Architecture:** `ConsoleProgressBar` gains an `Indent` property and a `freeze()` method. Each render level (Dock, Figure, Plot) creates its own progress bar at increasing indentation. When a level completes it freezes (prints `\n`), becoming a permanent line. The parent level prints a header line, then delegates to children. `FastPlotDock` gets a new `renderAll()` method that eagerly renders all tabs.

**Tech Stack:** MATLAB, `fprintf` with `\r` for animation, `\n` for freezing

---

### Task 1: Refactor ConsoleProgressBar — add Indent and freeze()

**Files:**
- Modify: `ConsoleProgressBar.m`

**Step 1: Rewrite ConsoleProgressBar**

Replace the entire file with:

```matlab
classdef ConsoleProgressBar < handle
%CONSOLEPROGRESSBAR Single-line console progress bar with indentation.
%   Uses fprintf + carriage return to animate a progress bar on one line.
%   Call freeze() to make the current state permanent (prints newline)
%   so the next bar can start on a fresh line below.
%
%   Usage:
%     pb = ConsoleProgressBar(2);   % 2-space indent
%     pb.start();
%     for k = 1:8
%         pb.update(k, 8, 'Tile 1');
%         pause(0.1);
%     end
%     pb.freeze();   % becomes permanent line
%
%   See also FastPlot, FastPlotFigure, FastPlotDock.

    properties (Access = private)
        Label        char = ''
        Current      (1,1) double = 0
        Total        (1,1) double = 0
        BarWidth     (1,1) double = 30
        Indent       (1,1) double = 0    % number of leading spaces
        IsStarted    (1,1) logical = false
        IsFrozen     (1,1) logical = false
        LastLen      (1,1) double = 0
    end

    methods
        function obj = ConsoleProgressBar(indent)
        %CONSOLEPROGRESSBAR Construct a progress bar.
        %   pb = ConsoleProgressBar()       — no indent
        %   pb = ConsoleProgressBar(indent) — indent spaces
            if nargin >= 1
                obj.Indent = indent;
            end
        end

        function start(obj)
        %START Initialize the progress display.
            obj.IsStarted = true;
            obj.IsFrozen  = false;
            obj.LastLen   = 0;
            obj.printBar();
        end

        function update(obj, current, total, label)
        %UPDATE Update progress and redraw.
        %   pb.update(current, total)
        %   pb.update(current, total, label)
            obj.Current = current;
            obj.Total   = total;
            if nargin >= 4
                obj.Label = label;
            end
            if obj.IsStarted && ~obj.IsFrozen
                obj.printBar();
            end
        end

        function freeze(obj)
        %FREEZE Make current bar state permanent (print newline).
        %   After freeze(), this bar no longer updates. A new bar
        %   can start on the next line.
            if ~obj.IsStarted || obj.IsFrozen; return; end
            obj.printBar();
            fprintf('\n');
            obj.IsFrozen = true;
        end

        function finish(obj)
        %FINISH Set to 100%, freeze, and mark done.
            if ~obj.IsStarted; return; end
            obj.Current = obj.Total;
            if ~obj.IsFrozen
                obj.printBar();
                fprintf('\n');
            end
            obj.IsStarted = false;
            obj.IsFrozen  = true;
        end
    end

    methods (Access = private)
        function printBar(obj)
        %PRINTBAR Redraw the bar using carriage return.
            filled = char(9608);
            empty  = char(9617);

            prefix = repmat(' ', 1, obj.Indent);

            lbl = obj.Label;
            if numel(lbl) > 12; lbl = lbl(1:12); end
            lbl = sprintf('%-12s', lbl);

            if obj.Total > 0
                nFilled = round(obj.BarWidth * obj.Current / obj.Total);
            else
                nFilled = 0;
            end
            nFilled = max(0, min(obj.BarWidth, nFilled));
            nEmpty  = obj.BarWidth - nFilled;

            barStr = [repmat(filled, 1, nFilled), repmat(empty, 1, nEmpty)];
            line = sprintf('%s%s [%s] %d/%d', prefix, lbl, barStr, obj.Current, obj.Total);

            padding = max(0, obj.LastLen - numel(line));
            fprintf('\r%s%s', line, repmat(' ', 1, padding));
            obj.LastLen = numel(line);
        end
    end
end
```

**Step 2: Smoke-test**

```matlab
pb = ConsoleProgressBar(0);
pb.start();
for k = 1:3; pb.update(k, 3, 'Level 0'); pause(0.2); end
pb.freeze();
pb2 = ConsoleProgressBar(2);
pb2.start();
for k = 1:5; pb2.update(k, 5, 'Level 1'); pause(0.2); end
pb2.finish();
```

Expected:
```
Level 0      [██████████████████████████████] 3/3
  Level 1      [██████████████████████████████] 5/5
```

**Step 3: Commit**

```bash
git add ConsoleProgressBar.m
git commit -m "refactor: add indent and freeze() to ConsoleProgressBar"
```

---

### Task 2: Update FastPlot.render() for hierarchical progress

**Files:**
- Modify: `FastPlot.m:530-539` (standalone progress bar creation)
- Modify: `FastPlot.m:696-698` (per-line update)
- Modify: `FastPlot.m:937-940` (finish)

**Step 1: Update render() to accept indent level and use freeze**

Change the progress bar section at lines 530-539 from the current code to:

```matlab
            if nargin < 2; progressBar = []; end

            % Create local progress bar for standalone render
            ownProgressBar = false;
            if isempty(progressBar) && obj.ShowProgress && numel(obj.Lines) > 0
                progressBar = ConsoleProgressBar(0);
                progressBar.update(0, numel(obj.Lines), 'Rendering');
                progressBar.start();
                ownProgressBar = true;
            end
```

The per-line update at line 696-698 stays the same — it already calls `progressBar.update(i, numel(obj.Lines))`.

Change the finish at lines 937-940 from:
```matlab
            if ownProgressBar
                progressBar.finish();
            end
```
to:
```matlab
            if ownProgressBar
                progressBar.finish();
            elseif ~isempty(progressBar)
                progressBar.freeze();
            end
```

This way: standalone render finishes (100% + newline), but when called from a dashboard the bar freezes (permanent line) and control returns to the parent.

**Step 2: Commit**

```bash
git add FastPlot.m
git commit -m "feat: FastPlot.render freezes progress bar when called from parent"
```

---

### Task 3: Update FastPlotFigure.renderAll() for hierarchical progress

**Files:**
- Modify: `FastPlotFigure.m:192-241` (renderAll method)

**Step 1: Rewrite renderAll to create per-tile progress bars**

Replace the renderAll method (lines 192-243) with:

```matlab
        function renderAll(obj, parentProgressBar)
            %RENDERALL Render all tiles that haven't been rendered yet.
            if nargin < 2; parentProgressBar = []; end

            % Collect tiles that need rendering
            tilesToRender = [];
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
                    tilesToRender(end+1) = i; %#ok<AGROW>
                end
            end
            nTiles = numel(tilesToRender);

            % Determine indent level (0 standalone, 2 from dock)
            if ~isempty(parentProgressBar)
                tileIndent = 2;
            else
                tileIndent = 0;
            end

            % Determine if we show progress
            showProg = obj.ShowProgress && nTiles > 0;

            try
                for k = 1:nTiles
                    i = tilesToRender(k);
                    nLines = numel(obj.Tiles{i}.Lines);

                    % Create per-tile progress bar
                    if showProg
                        cpb = ConsoleProgressBar(tileIndent);
                        cpb.update(0, max(nLines, 1), sprintf('Tile %d/%d', k, nTiles));
                        cpb.start();
                    else
                        cpb = [];
                    end

                    obj.Tiles{i}.DeferDraw = true;
                    obj.Tiles{i}.ShowProgress = false;
                    obj.Tiles{i}.render(cpb);
                    obj.Tiles{i}.DeferDraw = false;
                end
            catch err
                if showProg && ~isempty(cpb); cpb.finish(); end
                rethrow(err);
            end

            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end
```

Key changes:
- Accepts optional `parentProgressBar` arg to detect nesting depth
- Creates a fresh `ConsoleProgressBar` per tile at the right indent
- Each tile's render() calls `freeze()` when done (from Task 2), so completed tiles become permanent lines
- Suppresses tile's own standalone progress (`ShowProgress = false`)

**Step 2: Commit**

```bash
git add FastPlotFigure.m
git commit -m "feat: FastPlotFigure.renderAll creates per-tile hierarchical progress bars"
```

---

### Task 4: Add renderAll() to FastPlotDock with tab-level progress

**Files:**
- Modify: `FastPlotDock.m:29-31` (properties — add ShowProgress)
- Modify: `FastPlotDock.m:106-136` (after render method — add renderAll)
- Modify: `FastPlotDock.m:374-384` (renderTab — accept progress bar)

**Step 1: Add ShowProgress property**

In `FastPlotDock.m`, add to the public properties block (after line 31):

```matlab
        ShowProgress = true   % show console progress bar during renderAll
```

**Step 2: Add renderAll method**

Add after the existing `render()` method (after line 136):

```matlab
        function renderAll(obj)
            %RENDERALL Eagerly render all tabs with hierarchical progress.
            %   dock.renderAll()
            %
            %   Renders every tab upfront (not lazily). Shows hierarchical
            %   console progress: tab headers + per-tile progress bars.
            if isempty(obj.Tabs)
                set(obj.hFigure, 'Visible', 'on');
                return;
            end

            nTabs = numel(obj.Tabs);

            try
                for t = 1:nTabs
                    % Print tab header line
                    if obj.ShowProgress
                        fprintf('Tab %d/%d: %s\n', t, nTabs, obj.Tabs(t).Name);
                    end

                    % Suppress figure-level standalone progress (we manage it)
                    obj.Tabs(t).Figure.ShowProgress = obj.ShowProgress;

                    % Render the tab (figure + reparent + toolbar)
                    tb = obj.Tabs(t).Toolbar;
                    if ~isempty(tb) && ~isempty(tb.hToolbar) && ishandle(tb.hToolbar)
                        delete(tb.hToolbar);
                    end
                    obj.Tabs(t).Figure.renderAll(true);  % pass truthy to signal nesting
                    obj.reparentAxes(t);
                    obj.Tabs(t).Toolbar = FastPlotToolbar(obj.Tabs(t).Figure);
                    obj.Tabs(t).IsRendered = true;
                end
            catch err
                rethrow(err);
            end

            % Hide all tabs, create tab bar, show first tab
            for i = 1:nTabs
                obj.setTabVisible(i, false);
            end
            obj.createTabBar();
            obj.selectTab(1);

            set(obj.hFigure, 'Visible', 'on');
            w = warning('off', 'MATLAB:callback:error');
            drawnow;
            warning(w);
        end
```

**Step 3: Update FastPlotFigure.renderAll parentProgressBar check**

In Task 3 we used `~isempty(parentProgressBar)` to detect nesting. The dock passes `true` (a truthy value). Update the check in FastPlotFigure.renderAll — the `parentProgressBar` arg just needs to be truthy (non-empty), so passing `true` works since `~isempty(true)` is `true`. The indent becomes 2 when nested. This is already handled.

**Step 4: Commit**

```bash
git add FastPlotDock.m
git commit -m "feat: add FastPlotDock.renderAll with tab-level hierarchical progress"
```

---

### Task 5: Test all three levels

**Step 1: Test standalone FastPlot**

```matlab
fp = FastPlot();
for i = 1:5
    x = linspace(0, 10, 1e6);
    y = sin(x * i) + randn(1, 1e6) * 0.1;
    fp.addLine(x, y, 'DisplayName', sprintf('Line %d', i));
end
fp.render();
```

Expected:
```
Rendering    [██████████████████████████████] 5/5
```

**Step 2: Test FastPlotFigure dashboard**

```matlab
example_dashboard
```

Expected:
```
Tile 1/4:    [██████████████████████████████] 3/3
Tile 2/4:    [██████████████████████████████] 2/2
Tile 3/4:    [██████████████████████████████] 1/1
Tile 4/4:    [██████████████████████████████] 1/1
```

**Step 3: Test FastPlotDock**

```matlab
example_docked_tabs
```

Expected:
```
Tab 1/3: Temperature
  Tile 1/2:    [██████████████████████████████] 3/3
  Tile 2/2:    [██████████████████████████████] 2/2
Tab 2/3: Pressure
  Tile 1/1:    [██████████████████████████████] 4/4
Tab 3/3: Vibration
  Tile 1/2:    [██████████████████████████████] 1/1
  Tile 2/2:    [██████████████████████████████] 2/2
```

**Step 4: Test ShowProgress=false**

```matlab
fig = FastPlotFigure(2, 2);
fig.ShowProgress = false;
% ... add lines ...
fig.renderAll();
```

Expected: no progress output.

**Step 5: Commit any fixes**
