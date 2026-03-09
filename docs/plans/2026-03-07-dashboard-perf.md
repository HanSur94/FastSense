# Dashboard Performance Optimization — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make dashboard creation (FastPlotFigure with many tiles) faster by eliminating redundant GPU flushes and optional O(n) validation scans.

**Architecture:** Four targeted changes to the hot path: (1) defer drawnow to renderAll, (2) optional AssumeSorted flag in addLine, (3) optional HasNaN flag in addLine, (4) batch set() call in render. All changes are backwards-compatible — default behavior is unchanged.

**Tech Stack:** MATLAB/Octave, no new dependencies.

---

### Task 1: Defer `drawnow` — add `DeferDraw` property to FastPlot

**Files:**
- Modify: `FastPlot.m:51-61` (private properties)
- Modify: `FastPlot.m:650-658` (end of render method)
- Test: `tests/test_render.m`

**Step 1: Write the failing test**

Add to `tests/test_render.m` before the final `fprintf`:

```matlab
    % testDeferDraw
    fig = figure('Visible', 'off');
    ax = axes('Parent', fig);
    fp = FastPlot('Parent', ax);
    fp.addLine(1:100, rand(1,100));
    fp.DeferDraw = true;
    fp.render();
    assert(fp.IsRendered, 'testDeferDraw: should be rendered');
    assert(ishandle(fp.Lines(1).hLine), 'testDeferDraw: line created');
    close(fig);
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_render"`
Expected: FAIL — `DeferDraw` property doesn't exist yet.

**Step 3: Write minimal implementation**

In `FastPlot.m`, add to the private properties block (after line 60, `MetadataFileDate`):

```matlab
        DeferDraw     = false    % when true, render() skips drawnow + visibility
```

In `FastPlot.m`, replace lines 650-658 (the end of `render()`, after `hold off`):

```matlab
            hold(obj.hAxes, 'off');

            % Show figure and flush — unless deferred (dashboard batch render)
            if ~obj.DeferDraw
                if isempty(obj.ParentAxes)
                    set(obj.hFigure, 'Visible', 'on');
                end
                drawnow;
            end
```

This replaces the existing block:
```matlab
            hold(obj.hAxes, 'off');

            % Show figure now that setup is complete
            if isempty(obj.ParentAxes)
                set(obj.hFigure, 'Visible', 'on');
            end
            drawnow;
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_render"`
Expected: PASS — all 9 render tests pass (8 existing + 1 new).

**Step 5: Commit**

```bash
git add FastPlot.m tests/test_render.m
git commit -m "perf: add DeferDraw property to skip per-tile drawnow"
```

---

### Task 2: Defer `drawnow` — wire up `FastPlotFigure.renderAll()`

**Files:**
- Modify: `FastPlotFigure.m:157-166` (renderAll method)
- Test: `tests/test_figure_layout.m`

**Step 1: Write the failing test**

Add to `tests/test_figure_layout.m` before the final `fprintf`:

```matlab
    % testRenderAllDefersDraw
    fig = FastPlotFigure(2, 2);
    for i = 1:4
        fp = fig.tile(i);
        fp.addLine(1:50, rand(1,50));
    end
    fig.renderAll();
    % All tiles should be rendered and visible
    for i = 1:4
        fp = fig.tile(i);
        assert(fp.IsRendered, sprintf('testRenderAllDefersDraw: tile %d rendered', i));
        assert(ishandle(fp.Lines(1).hLine), sprintf('testRenderAllDefersDraw: tile %d line', i));
    end
    assert(strcmp(get(fig.hFigure, 'Visible'), 'on'), 'testRenderAllDefersDraw: visible');
    close(fig.hFigure);
```

**Step 2: Run test to verify it passes (this is a behavioral test, should pass already)**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_figure_layout"`
Expected: PASS — behavior is the same, just faster internally.

**Step 3: Implement renderAll() with DeferDraw**

In `FastPlotFigure.m`, replace the `renderAll` method (lines 157-166):

```matlab
        function renderAll(obj)
            %RENDERALL Render all tiles that haven't been rendered yet.
            for i = 1:numel(obj.Tiles)
                if ~isempty(obj.Tiles{i}) && ~obj.Tiles{i}.IsRendered
                    obj.Tiles{i}.DeferDraw = true;
                    obj.Tiles{i}.render();
                end
            end
            set(obj.hFigure, 'Visible', 'on');
            drawnow;
        end
```

**Step 4: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass.

**Step 5: Commit**

```bash
git add FastPlotFigure.m tests/test_figure_layout.m
git commit -m "perf: defer drawnow in renderAll for single GPU flush"
```

---

### Task 3: `AssumeSorted` flag in `addLine()`

**Files:**
- Modify: `FastPlot.m:94-168` (addLine method)
- Test: `tests/test_add_line.m`

**Step 1: Write the failing test**

Add to `tests/test_add_line.m` before the final `fprintf`:

```matlab
    % testAssumeSortedSkipsValidation
    fp = FastPlot();
    x = linspace(0, 100, 1e5);
    y = rand(1, 1e5);
    fp.addLine(x, y, 'AssumeSorted', true);
    assert(numel(fp.Lines) == 1, 'testAssumeSortedSkipsValidation: line added');
    assert(isequal(fp.Lines(1).X, x), 'testAssumeSortedSkipsValidation: X stored');

    % testAssumeSortedAllowsUnsorted (no error — user's responsibility)
    fp = FastPlot();
    fp.addLine([5 3 1 2 4], rand(1,5), 'AssumeSorted', true);
    assert(numel(fp.Lines) == 1, 'testAssumeSortedAllowsUnsorted: line added');

    % testDefaultStillValidates (existing behavior preserved)
    fp = FastPlot();
    threw = false;
    try
        fp.addLine([5 3 1 2 4], rand(1,5));
    catch
        threw = true;
    end
    assert(threw, 'testDefaultStillValidates: should reject unsorted');
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_add_line"`
Expected: FAIL — `AssumeSorted` is not a recognized parameter.

**Step 3: Implement**

In `FastPlot.m` `addLine()`, modify the name-value parsing block (around lines 128-143). Add `assumeSorted` variable and parse it:

```matlab
            % Parse name-value pairs manually (avoid inputParser overhead)
            dsMethod = 'minmax';
            meta = [];
            assumeSorted = false;
            hasNaNOverride = [];
            opts = struct();
            k = 1;
            while k <= numel(varargin)
                key = varargin{k};
                val = varargin{k+1};
                if strcmpi(key, 'DownsampleMethod')
                    dsMethod = val;
                elseif strcmpi(key, 'Metadata')
                    meta = val;
                elseif strcmpi(key, 'AssumeSorted')
                    assumeSorted = val;
                elseif strcmpi(key, 'HasNaN')
                    hasNaNOverride = val;
                else
                    opts.(key) = val;
                end
                k = k + 2;
            end
```

Then wrap the monotonicity check (lines 116-125) with the flag:

```matlab
            % Monotonicity check (chunked vectorized — limits peak memory)
            if ~assumeSorted
                chunkSize = 1000000;
                nX = numel(x);
                for ci = 1:chunkSize:nX-1
                    ce = min(ci + chunkSize, nX);
                    dx = diff(x(ci:ce));
                    if any(dx(~isnan(dx)) < 0)
                        error('FastPlot:nonMonotonicX', ...
                            'X must be monotonically increasing.');
                    end
                end
            end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_add_line"`
Expected: PASS — all 11 tests pass (8 existing + 3 new).

**Step 5: Commit**

```bash
git add FastPlot.m tests/test_add_line.m
git commit -m "perf: add AssumeSorted flag to skip monotonicity check"
```

---

### Task 4: `HasNaN` flag in `addLine()`

**Files:**
- Modify: `FastPlot.m:94-168` (addLine method — already partially done in Task 3)
- Test: `tests/test_add_line.m`

**Step 1: Write the failing test**

Add to `tests/test_add_line.m` before the final `fprintf`:

```matlab
    % testHasNaNOverride
    fp = FastPlot();
    x = 1:100;
    y = rand(1, 100);
    fp.addLine(x, y, 'HasNaN', false);
    assert(fp.Lines(1).HasNaN == false, 'testHasNaNOverride: stored false');

    % testHasNaNAutoDetect (default behavior)
    fp = FastPlot();
    y_nan = rand(1, 100);
    y_nan(50) = NaN;
    fp.addLine(1:100, y_nan);
    assert(fp.Lines(1).HasNaN == true, 'testHasNaNAutoDetect: detected NaN');
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_add_line"`
Expected: FAIL — `HasNaN` is consumed by opts struct, not used as override.

**Step 3: Implement**

The `hasNaNOverride` variable was already added in Task 3's parsing block. Now modify the line struct creation (around line 160):

```matlab
            % Build line struct
            lineStruct.X = x;
            lineStruct.Y = y;
            lineStruct.DownsampleMethod = dsMethod;
            lineStruct.Options = opts;
            lineStruct.hLine = [];
            lineStruct.Pyramid = {};
            if ~isempty(hasNaNOverride)
                lineStruct.HasNaN = hasNaNOverride;
            else
                lineStruct.HasNaN = any(isnan(y));
            end
            lineStruct.Metadata = meta;
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_add_line"`
Expected: PASS — all 13 tests pass.

**Step 5: Commit**

```bash
git add FastPlot.m tests/test_add_line.m
git commit -m "perf: add HasNaN flag to skip NaN scan in addLine"
```

---

### Task 5: Batch `set(h, opts)` in render loop

**Files:**
- Modify: `FastPlot.m:493-497` (render method, line options loop)
- Test: `tests/test_render.m` (existing tests cover this)

**Step 1: Verify existing tests pass before change**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); test_render"`
Expected: PASS.

**Step 2: Replace per-field set loop with batch set**

In `FastPlot.m`, replace lines 493-497:

```matlab
                % Apply user options
                opts = L.Options;
                fnames = fieldnames(opts);
                for f = 1:numel(fnames)
                    set(h, fnames{f}, opts.(fnames{f}));
                end
```

With:

```matlab
                % Apply user options (batch — single graphics update)
                if ~isempty(fieldnames(L.Options))
                    set(h, L.Options);
                end
```

**Step 3: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass.

**Step 4: Commit**

```bash
git add FastPlot.m
git commit -m "perf: batch set() call for line options in render"
```

---

### Task 6: Run full test suite + benchmark

**Step 1: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "addpath('tests'); run_all_tests"`
Expected: All tests pass, zero regressions.

**Step 2: Run dashboard benchmark**

Run: `cd /Users/hannessuhr/FastPlot && matlab -batch "run('examples/benchmark_dashboard.m')"`
Compare create+render times to baseline (captured before changes).

**Step 3: Update benchmark to use new flags**

Add a third column to the benchmark that uses `'AssumeSorted', true, 'HasNaN', false` to show the additional speedup from skipping validation. This is optional — only if benchmark results are interesting.
