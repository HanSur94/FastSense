# Violation Marker Rendering Optimization

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Optimize violation marker rendering with faster marker style, pixel-density downsampling, and dirty-flag caching to skip redundant recomputation.

**Architecture:** Three independent optimizations applied to `FastSense.m` and its private functions: (1) swap `'o'` → `'.'` marker, (2) cull violations to 1-per-pixel-column via new `downsample_violations.m`, (3) cache `[xlim ylim]` to skip `updateViolations()` when view unchanged.

**Tech Stack:** MATLAB/Octave, existing FastSense private function pattern.

---

### Task 1: Change marker style from `'o'` to `'.'`

**Files:**
- Modify: `libs/FastSense/FastSense.m:813` (render method)

**Step 1: Change marker in render()**

In `libs/FastSense/FastSense.m:811-813`, change the `line()` call marker from `'o'` to `'.'`:

```matlab
hM = line(vxAll, vyAll, 'Parent', obj.hAxes, ...
    'LineStyle', 'none', 'Marker', '.', ...
    'MarkerSize', 6, 'Color', T.Color, ...
    'HandleVisibility', 'off');
```

Note: `MarkerSize` bumped from 4 to 6 because `'.'` renders smaller than `'o'` at the same size. Adjust to taste.

**Step 2: Run existing tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "setup; test_compute_violations"` (or Octave equivalent)
Expected: All 5 tests pass (marker style is a rendering detail, not tested by compute_violations).

**Step 3: Commit**

```
feat: use '.' marker for violation rendering (faster than 'o')
```

---

### Task 2: Pixel-density downsampling of violation markers

**Files:**
- Create: `libs/FastSense/private/downsample_violations.m`
- Create: `tests/test_downsample_violations.m`
- Modify: `libs/FastSense/FastSense.m:785-810` (render — apply downsampling after compute_violations)
- Modify: `libs/FastSense/FastSense.m:1953-2000` (updateViolations — apply downsampling after compute_violations)

**Step 1: Write the test**

Create `tests/test_downsample_violations.m`:

```matlab
function test_downsample_violations()
%TEST_DOWNSAMPLE_VIOLATIONS Tests for violation marker pixel-density culling.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastsense_private_path();

    % testBasicDownsample: 10 violations in 3 pixel columns -> 3 points
    xV = [1.0, 1.1, 1.2, 2.0, 2.1, 2.2, 3.0, 3.1, 3.2, 3.3];
    yV = [5.0, 5.5, 5.2, 6.0, 6.3, 6.1, 7.0, 7.5, 7.2, 7.8];
    pixelWidth = 1.0; % each pixel column spans 1.0 in X
    threshVal = 4.0;  % upper threshold at 4.0
    [xD, yD] = downsample_violations(xV, yV, pixelWidth, threshVal);
    % Should keep 1 point per pixel-column: the one with max |y - threshold|
    assert(numel(xD) == 3, 'testBasicDownsample: expected 3 points, got %d', numel(xD));
    % Pixel col 1 (x=1.0-1.2): max deviation is y=5.5 at x=1.1
    assert(xD(1) == 1.1, 'testBasicDownsample: wrong x for col 1');
    assert(yD(1) == 5.5, 'testBasicDownsample: wrong y for col 1');
    % Pixel col 2 (x=2.0-2.2): max deviation is y=6.3 at x=2.1
    assert(xD(2) == 2.1, 'testBasicDownsample: wrong x for col 2');
    assert(yD(2) == 6.3, 'testBasicDownsample: wrong y for col 2');
    % Pixel col 3 (x=3.0-3.3): max deviation is y=7.8 at x=3.3
    assert(xD(3) == 3.3, 'testBasicDownsample: wrong x for col 3');
    assert(yD(3) == 7.8, 'testBasicDownsample: wrong y for col 3');

    % testLowerThreshold: keep point with max deviation below threshold
    xV = [1.0, 1.1, 2.0, 2.1];
    yV = [3.0, 2.5, 1.0, 1.5];
    pixelWidth = 1.0;
    threshVal = 4.0; % lower threshold
    [xD, yD] = downsample_violations(xV, yV, pixelWidth, threshVal);
    assert(numel(xD) == 2, 'testLowerThreshold: expected 2 points');
    % Col 1: max |y-4| is y=2.5 (deviation 1.5) vs y=3.0 (deviation 1.0)
    assert(yD(1) == 2.5, 'testLowerThreshold: wrong y for col 1');
    % Col 2: max |y-4| is y=1.0 (deviation 3.0) vs y=1.5 (deviation 2.5)
    assert(yD(2) == 1.0, 'testLowerThreshold: wrong y for col 2');

    % testEmpty: no violations
    [xD, yD] = downsample_violations([], [], 1.0, 5.0);
    assert(isempty(xD), 'testEmpty xD');
    assert(isempty(yD), 'testEmpty yD');

    % testSinglePoint: one violation passes through
    [xD, yD] = downsample_violations(5, 10, 1.0, 4.0);
    assert(xD == 5, 'testSinglePoint xD');
    assert(yD == 10, 'testSinglePoint yD');

    % testAlreadySparse: each point in its own pixel column -> no culling
    xV = [1, 3, 5, 7, 9];
    yV = [6, 7, 8, 9, 10];
    [xD, yD] = downsample_violations(xV, yV, 1.0, 5.0);
    assert(numel(xD) == 5, 'testAlreadySparse: expected 5 points');

    % testWithNaN: NaN values in violations (from NaN gaps) are preserved
    xV = [1.0, 1.1, NaN, 3.0, 3.1];
    yV = [5.0, 5.5, NaN, 7.0, 7.5];
    [xD, yD] = downsample_violations(xV, yV, 1.0, 4.0);
    % NaN should act as segment separator; col 1 and col 3 each keep 1
    assert(numel(xD) == 2, 'testWithNaN: expected 2 points, got %d', numel(xD));

    fprintf('    All 6 downsample_violations tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "setup; test_downsample_violations"`
Expected: FAIL — `downsample_violations` not found.

**Step 3: Implement `downsample_violations.m`**

Create `libs/FastSense/private/downsample_violations.m`:

```matlab
function [xOut, yOut] = downsample_violations(xViol, yViol, pixelWidth, thresholdValue)
%DOWNSAMPLE_VIOLATIONS Cull violation markers to one per pixel column.
%   Keeps the point with maximum |y - thresholdValue| per pixel-X bucket.
%   This preserves the visual extremes while eliminating sub-pixel overlap.
%
%   Inputs:
%     xViol, yViol   — violation coordinates (from compute_violations)
%     pixelWidth     — X-axis span per pixel (diff(xlim) / axesWidthPixels)
%     thresholdValue — threshold value (used to pick max-deviation point)
%
%   See also compute_violations, FastSense.updateViolations.

    if isempty(xViol)
        xOut = xViol;
        yOut = yViol;
        return;
    end

    % Remove NaN entries (segment separators) before binning
    nanMask = isnan(xViol) | isnan(yViol);
    xClean = xViol(~nanMask);
    yClean = yViol(~nanMask);

    if isempty(xClean)
        xOut = zeros(1, 0);
        yOut = zeros(1, 0);
        return;
    end

    % Assign each point to a pixel-column bucket
    buckets = floor(xClean / pixelWidth);

    % Find unique buckets and pick max-deviation point in each
    [uBuckets, ~, ic] = unique(buckets);
    nBuckets = numel(uBuckets);
    xOut = zeros(1, nBuckets);
    yOut = zeros(1, nBuckets);

    deviation = abs(yClean - thresholdValue);
    for b = 1:nBuckets
        mask = (ic == b);
        devs = deviation(mask);
        [~, bestIdx] = max(devs);
        bx = xClean(mask);
        by = yClean(mask);
        xOut(b) = bx(bestIdx);
        yOut(b) = by(bestIdx);
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "setup; test_downsample_violations"`
Expected: All 6 tests pass.

**Step 5: Integrate into `render()` and `updateViolations()`**

In `libs/FastSense/FastSense.m`, the `render()` method at lines 785-810 — after computing violations for each line, downsample before rendering. The key change is adding a downsample call after the violation collection loop, before the `line()` call.

In the render section (after line 806, before line 811), add:

```matlab
% Pixel-density cull: keep 1 violation per pixel column
if nViols > 0
    pw = diff(get(obj.hAxes, 'XLim')) / obj.PixelWidth;
    [vxAll, vyAll] = downsample_violations(vxAll, vyAll, pw, T.Value);
end
```

In `updateViolations()` (after line 1987 assembling vxAll/vyAll, before the `set()` call), add:

```matlab
% Pixel-density cull
pw = diff(get(obj.hAxes, 'XLim')) / obj.PixelWidth;
[vxAll, vyAll] = downsample_violations(vxAll(1:end-1), vyAll(1:end-1), pw, obj.Thresholds(t).Value);
```

And update the corresponding `set()` call to use `vxAll, vyAll` directly (no more `1:end-1` since downsample_violations already strips NaN).

**Step 6: Run all tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "setup; test_compute_violations; test_downsample_violations"`
Expected: All tests pass.

**Step 7: Commit**

```
feat: downsample violation markers to pixel density
```

---

### Task 3: Dirty-flag caching to skip redundant `updateViolations()`

**Files:**
- Modify: `libs/FastSense/FastSense.m:113-124` (add `CachedViolationLim` property)
- Modify: `libs/FastSense/FastSense.m:1953-2000` (check cache at top of `updateViolations()`)
- Modify: `libs/FastSense/FastSense.m:892` (invalidate on render)

**Step 1: Add cached property**

In `libs/FastSense/FastSense.m`, properties block at line 117, add after `CachedXLim`:

```matlab
CachedViolationLim = []    % [xmin xmax ymin ymax pw] for violation skip
```

**Step 2: Add early-exit check in `updateViolations()`**

At the top of `updateViolations()` (line 1953), after the function signature and docstring, add:

```matlab
% Dirty-flag: skip if view is unchanged since last violation update
if ~isempty(obj.Thresholds) && ishandle(obj.hAxes)
    xl = get(obj.hAxes, 'XLim');
    yl = get(obj.hAxes, 'YLim');
    currentLim = [xl, yl, obj.PixelWidth];
    if ~isempty(obj.CachedViolationLim) && isequal(currentLim, obj.CachedViolationLim)
        return;
    end
    obj.CachedViolationLim = currentLim;
end
```

This caches `[xlim ylim pixelWidth]`. If any of these change, violations are recomputed. If none change (duplicate call from e.g. resetplotview path), it's skipped.

**Step 3: Invalidate cache when data changes**

In `updateData()` (around line 1121) and `setData()` and anywhere raw data is modified, invalidate the cache by adding:

```matlab
obj.CachedViolationLim = [];
```

before the `obj.updateViolations()` call. This ensures data updates always trigger recomputation. The key locations:
- Line 1121 (`updateData` path) — add `obj.CachedViolationLim = [];` before `obj.updateViolations()`
- Line 249 (`setData` path) — add `obj.CachedViolationLim = [];` before `obj.updateViolations()`

**Step 4: Run all tests**

Run: `cd /Users/hannessuhr/FastSense && matlab -batch "setup; test_compute_violations; test_downsample_violations"`
Expected: All tests pass.

**Step 5: Commit**

```
perf: skip redundant updateViolations when view unchanged
```
