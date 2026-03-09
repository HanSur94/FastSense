# Render Progress Bar Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a two-level console progress bar to `FastPlotFigure.renderAll()` showing overall tile progress and per-tile line progress.

**Architecture:** A lightweight private helper class `ConsoleProgressBar` uses `fprintf` with ANSI escape codes to render two progress bars in the MATLAB command window. `FastPlotFigure` owns the progress bar and passes it into each tile's `render()` call for per-line updates.

**Tech Stack:** MATLAB, ANSI escape codes (`\r`, `\033[1A`)

---

### Task 1: Create ConsoleProgressBar helper class

**Files:**
- Create: `private/ConsoleProgressBar.m`

**Step 1: Create the progress bar class**

```matlab
classdef ConsoleProgressBar < handle
    %CONSOLEPROGRESSBAR Lightweight two-line console progress bar.
    %   Uses fprintf + ANSI escape codes to render two progress bars
    %   that overwrite themselves in the MATLAB command window.

    properties (Access = private)
        NumBars     = 0       % number of bar slots (1 or 2)
        Labels      = {}      % cell array of label strings per bar
        Currents    = []      % current values per bar
        Totals      = []      % total values per bar
        BarWidth    = 30      % character width of the bar
        IsStarted   = false
        LinesWritten = 0     % how many lines we've printed
    end

    methods
        function obj = ConsoleProgressBar(numBars)
            %CONSOLEPROGRESSBAR Create progress bar with numBars slots.
            if nargin < 1; numBars = 1; end
            obj.NumBars = numBars;
            obj.Labels = repmat({''}, 1, numBars);
            obj.Currents = zeros(1, numBars);
            obj.Totals = ones(1, numBars);
        end

        function start(obj)
            %START Initialize the progress bar display.
            obj.IsStarted = true;
            obj.LinesWritten = 0;
            obj.printBars();
        end

        function update(obj, barIndex, current, total, label)
            %UPDATE Update a specific bar slot.
            %   update(barIdx, current, total, label)
            if ~obj.IsStarted; return; end
            obj.Currents(barIndex) = current;
            obj.Totals(barIndex) = total;
            if nargin >= 5
                obj.Labels{barIndex} = label;
            end
            obj.printBars();
        end

        function finish(obj)
            %FINISH Finalize — leave bars at 100% and move cursor below.
            if ~obj.IsStarted; return; end
            fprintf('\n');
            obj.IsStarted = false;
        end
    end

    methods (Access = private)
        function printBars(obj)
            % Move cursor up to overwrite previous output
            if obj.LinesWritten > 0
                fprintf('\033[%dA\r', obj.LinesWritten);
            end

            obj.LinesWritten = 0;
            for i = 1:obj.NumBars
                frac = 0;
                if obj.Totals(i) > 0
                    frac = obj.Currents(i) / obj.Totals(i);
                end
                frac = min(max(frac, 0), 1);

                filled = round(frac * obj.BarWidth);
                empty  = obj.BarWidth - filled;

                barStr = [repmat(char(9608), 1, filled), ...
                          repmat(char(9617), 1, empty)];

                label = obj.Labels{i};
                if isempty(label)
                    label = sprintf('Bar %d', i);
                end

                % Pad label to 12 chars for alignment
                label = pad(label, 12);

                line = sprintf('%s [%s] %d/%d', ...
                    label, barStr, ...
                    obj.Currents(i), obj.Totals(i));

                % Clear rest of line and print
                fprintf('\033[2K%s\n', line);
                obj.LinesWritten = obj.LinesWritten + 1;
            end
        end
    end
end
```

**Step 2: Smoke-test in MATLAB console**

Run:
```matlab
cpb = ConsoleProgressBar(2);
cpb.start();
for i = 1:5
    cpb.update(1, i, 5, 'Overall');
    for j = 1:3
        cpb.update(2, j, 3, sprintf('Step %d', i));
        pause(0.1);
    end
end
cpb.finish();
```

Expected: Two progress bars animate in the console, finishing at 5/5 and 3/3.

**Step 3: Commit**

```bash
git add private/ConsoleProgressBar.m
git commit -m "feat: add ConsoleProgressBar helper for render progress display"
```

---

### Task 2: Add ShowProgress property to FastPlotFigure

**Files:**
- Modify: `FastPlotFigure.m:31-46` (public properties block)

**Step 1: Add the property**

Add `ShowProgress = true` to the public properties block in `FastPlotFigure.m`, after line 45 (MetadataTileIndex):

```matlab
        ShowProgress   = true         % show console progress bar during renderAll
```

**Step 2: Commit**

```bash
git add FastPlotFigure.m
git commit -m "feat: add ShowProgress property to FastPlotFigure"
```

---

### Task 3: Wire progress bar into FastPlotFigure.renderAll()

**Files:**
- Modify: `FastPlotFigure.m:191-202` (renderAll method)

**Step 1: Update renderAll to use ConsoleProgressBar**

Replace the `renderAll` method body (lines 191-202) with:

```matlab
        function renderAll(obj)
            %RENDERALL Render all tiles that haven't been rendered yet.

            % Count tiles that need rendering
            tilesToRender = [];
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
                    tilesToRender(end+1) = i; %#ok<AGROW>
                end
            end

            nTiles = numel(tilesToRender);

            % Create progress bar if enabled and there's work to do
            if obj.ShowProgress && nTiles > 0
                cpb = ConsoleProgressBar(2);
                cpb.start();
            else
                cpb = [];
            end

            for k = 1:nTiles
                i = tilesToRender(k);
                if ~isempty(cpb)
                    cpb.update(1, k-1, nTiles, 'Overall');
                    cpb.update(2, 0, max(numel(obj.Tiles{i}.Lines), 1), sprintf('Tile %d', i));
                end
                obj.Tiles{i}.DeferDraw = true;
                obj.Tiles{i}.render(cpb);
                obj.Tiles{i}.DeferDraw = false;
                if ~isempty(cpb)
                    cpb.update(1, k, nTiles, 'Overall');
                end
            end

            if ~isempty(cpb)
                cpb.finish();
            end

            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end
```

**Step 2: Commit**

```bash
git add FastPlotFigure.m
git commit -m "feat: integrate ConsoleProgressBar into renderAll"
```

---

### Task 4: Accept progress bar in FastPlot.render() and update per-line

**Files:**
- Modify: `FastPlot.m:513` (render method signature)
- Modify: `FastPlot.m:619-680` (lines rendering loop)

**Step 1: Add optional progress bar argument to render()**

Change line 513 from:
```matlab
        function render(obj)
```
to:
```matlab
        function render(obj, progressBar)
            if nargin < 2; progressBar = []; end
```

**Step 2: Add progress update inside the lines loop**

After line 679 (the `end` of the verbose fprintf block, still inside the `for i = 1:numel(obj.Lines)` loop), add:

```matlab
                if ~isempty(progressBar)
                    progressBar.update(2, i, numel(obj.Lines), sprintf('Tile lines'));
                end
```

**Step 3: Commit**

```bash
git add FastPlot.m
git commit -m "feat: update FastPlot.render to report per-line progress"
```

---

### Task 5: Test with example dashboard

**Step 1: Run existing example_dashboard.m**

Run:
```matlab
example_dashboard
```

Expected: Two-line progress bar appears showing tile and line progress, stays visible at 100% when done.

**Step 2: Test with ShowProgress disabled**

```matlab
fig = FastPlotFigure(2, 2);
fig.ShowProgress = false;
% ... add lines ...
fig.renderAll();
```

Expected: No progress bar output.

**Step 3: Commit any fixes if needed**
