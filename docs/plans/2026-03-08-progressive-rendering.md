# Progressive Rendering Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make `FastPlot.render()` show data instantly via stride-based preview, then refine with proper minmax downsample asynchronously.

**Architecture:** Replace the synchronous downsample in `render()` with a fast stride operation. Start a one-shot timer that performs the real downsample and swaps line data. Cancel the timer on any user interaction (zoom/pan) since the interaction callback already downsamples properly.

**Tech Stack:** MATLAB OOP (handle class), MATLAB timer objects (already used in live mode).

---

### Task 1: Add new properties for progressive rendering

**Files:**
- Modify: `FastPlot.m:98-111` (private properties block)

**Step 1: Add properties**

In the `properties (Access = private)` block (after line 107, `ColorIndex`), add:

```matlab
hRefineTimer  = []    % one-shot timer for deferred minmax refinement
IsRefined     = true  % false while showing coarse stride preview
```

**Step 2: Commit**

```
feat: add hRefineTimer and IsRefined properties to FastPlot
```

---

### Task 2: Replace downsample with stride preview in render()

**Files:**
- Modify: `FastPlot.m:542-594` (line rendering loop in render())

**Step 1: Replace the downsample block with stride-based preview**

In `render()`, replace the downsample block inside the line loop (lines 548-553):

```matlab
                % Downsample
                if numel(L.X) > obj.MinPointsForDownsample
                    if strcmp(L.DownsampleMethod, 'lttb')
                        [xd, yd] = lttb_downsample(L.X, L.Y, numBuckets);
                    else
                        [xd, yd] = minmax_downsample(L.X, L.Y, numBuckets, L.HasNaN);
                    end
                else
                    xd = L.X;
                    yd = L.Y;
                end
```

with:

```matlab
                % Fast stride preview for large datasets (refined async)
                if numel(L.X) > obj.MinPointsForDownsample
                    K = max(1, floor(numel(L.X) / (2 * numBuckets)));
                    xd = L.X(1:K:end);
                    yd = L.Y(1:K:end);
                else
                    xd = L.X;
                    yd = L.Y;
                end
```

**Step 2: Start refinement timer at the end of render()**

After the line `obj.IsRendered = true;` (line 752) and before the verbose logging block, add:

```matlab
            % Start async refinement if any line used stride preview
            hasLargeLines = false;
            for i = 1:numel(obj.Lines)
                if numel(obj.Lines(i).X) > obj.MinPointsForDownsample
                    hasLargeLines = true;
                    break;
                end
            end
            if hasLargeLines
                obj.IsRefined = false;
                try
                    obj.hRefineTimer = timer('ExecutionMode', 'singleShot', ...
                        'StartDelay', 0.01, ...
                        'TimerFcn', @(~,~) obj.refineLines());
                    start(obj.hRefineTimer);
                catch
                    % Octave or timer unavailable: refine synchronously
                    obj.refineLines();
                end
            end
```

**Step 3: Commit**

```
feat: stride-based preview in render(), start async refinement timer
```

---

### Task 3: Implement refineLines() private method

**Files:**
- Modify: `FastPlot.m` (add method in private methods section, near `onXLimChanged`)

**Step 1: Add refineLines() method**

Add this method inside the `methods (Access = private)` block (after the `applyTheme` method around line 1211):

```matlab
        function refineLines(obj)
            %REFINELINES Replace stride preview with proper downsampled data.
            if ~obj.IsRendered || ~ishandle(obj.hAxes)
                return;
            end

            pw = obj.getAxesPixelWidth();
            for i = 1:numel(obj.Lines)
                L = obj.Lines(i);
                if numel(L.X) <= obj.MinPointsForDownsample
                    continue;
                end
                if ~ishandle(L.hLine)
                    continue;
                end

                if strcmp(L.DownsampleMethod, 'lttb')
                    [xd, yd] = lttb_downsample(L.X, L.Y, pw);
                else
                    [xd, yd] = minmax_downsample(L.X, L.Y, pw, L.HasNaN);
                end
                set(L.hLine, 'XData', xd, 'YData', yd);

                if obj.Verbose
                    fprintf('[FastPlot] refine: line %d: %d pts -> %d displayed\n', ...
                        i, numel(L.X), numel(xd));
                end
            end

            obj.IsRefined = true;
            obj.stopRefineTimer();
            drawnow;
        end
```

**Step 2: Add stopRefineTimer() helper method**

Add this method in the same private methods block:

```matlab
        function stopRefineTimer(obj)
            %STOPrefinetimer Stop and delete the refinement timer.
            if ~isempty(obj.hRefineTimer)
                try
                    stop(obj.hRefineTimer);
                    delete(obj.hRefineTimer);
                catch
                end
                obj.hRefineTimer = [];
            end
        end
```

**Step 3: Commit**

```
feat: add refineLines() and stopRefineTimer() to FastPlot
```

---

### Task 4: Cancel refinement on zoom/pan and lifecycle events

**Files:**
- Modify: `FastPlot.m:1213-1241` (onXLimChanged method)
- Modify: `FastPlot.m:977-987` (stopLive method)

**Step 1: Cancel refinement at the top of onXLimChanged()**

In `onXLimChanged()`, after the existing guard check (line 1214-1216) and before `newXLim = get(...)`, add:

```matlab
            % Cancel pending refinement — zoom/pan triggers proper downsample
            if ~obj.IsRefined
                obj.stopRefineTimer();
                obj.IsRefined = true;
            end
```

**Step 2: Cancel refinement in stopLive()**

In `stopLive()`, before line 979 (`if ~isempty(obj.LiveTimer)`), add:

```matlab
            obj.stopRefineTimer();
```

**Step 3: Add delete() method to FastPlot for timer cleanup**

Add this as a public method (inside the `methods (Access = public)` block, after `stopLive`):

```matlab
        function delete(obj)
            %DELETE Clean up timers.
            obj.stopRefineTimer();
            try obj.stopLive(); catch; end
        end
```

**Step 4: Commit**

```
feat: cancel refinement on zoom/pan/live/delete
```

---

### Task 5: Tests

**Files:**
- Modify: `tests/test_render.m`

**Step 1: Add progressive rendering tests**

Before the final `fprintf` line in `test_render.m`, add these tests:

```matlab
    % testStridePreviewLargeData
    fp = FastPlot();
    x = 1:100000;
    y = sin(x/1000);
    fp.addLine(x, y, 'DisplayName', 'Big');
    fp.render();
    % After render, line exists with stride-based data (fewer points)
    xd = get(fp.Lines(1).hLine, 'XData');
    assert(numel(xd) < numel(x), 'testStridePreview: should be downsampled');
    assert(numel(xd) > 100, 'testStridePreview: should have reasonable points');
    % IsRefined should be false immediately (timer pending)
    close(fp.hFigure);

    % testSmallDataNoStride
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100), 'DisplayName', 'Small');
    fp.render();
    xd = get(fp.Lines(1).hLine, 'XData');
    assert(numel(xd) == 100, 'testSmallDataNoStride: all points shown');
    close(fp.hFigure);

    % testRefineTimerCleanupOnDelete
    fp = FastPlot();
    fp.addLine(1:100000, rand(1,100000));
    fp.render();
    fig = fp.hFigure;
    delete(fp);
    close(fig);
    % No error means timer was cleaned up properly
```

**Step 2: Update the test count**

Change the fprintf line from:
```matlab
    fprintf('    All 9 render tests passed.\n');
```
to:
```matlab
    fprintf('    All 12 render tests passed.\n');
```

**Step 3: Run tests**

Run: `/Applications/MATLAB_R2025b.app/bin/matlab -batch "addpath(pwd); addpath(fullfile(pwd,'tests')); run_all_tests()"`

Expected: All tests pass.

**Step 4: Commit**

```
test: add progressive rendering tests
```
