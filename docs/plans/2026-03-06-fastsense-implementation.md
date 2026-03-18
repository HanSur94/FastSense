# FastSense Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a pure-MATLAB plotting library that renders 100M time series points with fluid zoom/pan via dynamic MinMax downsampling.

**Architecture:** Handle class `FastSense` with builder API. Data lines, thresholds, and violation markers are configured before `render()`. On zoom/pan, an XLim listener triggers binary search → MinMax downsample → XData/YData update on reused line handles. No object recreation, `drawnow limitrate` for frame capping.

**Tech Stack:** Pure MATLAB 2020b, classic `figure()`, OpenGL renderer, `matlab.unittest` for testing.

**Design doc:** `FastSense/docs/2026-03-06-fastsense-design.md`

---

## Task 1: Project Scaffolding

**Files:**
- Create: `FastSense/FastSense.m` (skeleton only)
- Create: `FastSense/private/` (directory)
- Create: `FastSense/tests/` (directory)
- Create: `FastSense/examples/` (directory)

**Step 1: Create the FastSense class skeleton**

Create `FastSense/FastSense.m`:

```matlab
classdef FastSense < handle
    %FASTSENSE Ultra-fast time series plotting with dynamic downsampling.
    %   Handles 1K to 100M data points with fluid zoom/pan.
    %   Uses MinMax downsampling to reduce data to screen resolution.
    %
    %   Usage:
    %     fp = FastSense();
    %     fp.addLine(x, y, 'DisplayName', 'Sensor1');
    %     fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true);
    %     fp.render();

    properties (Access = public)
        ParentAxes = []       % axes handle, empty = create new
        LinkGroup  = ''       % string ID for linked zoom/pan
    end

    properties (SetAccess = private)
        Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                            'DownsampleMethod', {}, 'hLine', {})
        Thresholds = struct('Value', {}, 'Direction', {}, ...
                            'ShowViolations', {}, 'Color', {}, ...
                            'LineStyle', {}, 'Label', {})
        IsRendered = false
    end

    properties (Access = private)
        hFigure       = []
        hAxes         = []
        hThreshLines  = []    % single batched line object for all thresholds
        hViolMarkers  = []    % single scatter object for all violations
        Listeners     = []    % event listeners (XLim, resize)
        CachedXLim    = []    % for lazy recomputation
        PixelWidth    = 1920  % cached axes width in pixels
    end

    properties (Constant, Access = private)
        MIN_POINTS_FOR_DOWNSAMPLE = 5000  % below this, plot raw data
        DOWNSAMPLE_FACTOR = 2             % points per pixel (min + max)
    end

    methods (Access = public)
        function obj = FastSense(varargin)
            % Parse name-value pairs: 'Parent', 'LinkGroup'
            p = inputParser;
            addParameter(p, 'Parent', [], @(x) isempty(x) || isgraphics(x, 'axes'));
            addParameter(p, 'LinkGroup', '', @ischar);
            parse(p, varargin{:});
            obj.ParentAxes = p.Results.Parent;
            obj.LinkGroup  = p.Results.LinkGroup;
        end

        function addLine(obj, x, y, varargin)
        end

        function addThreshold(obj, value, varargin)
        end

        function render(obj)
        end
    end

    methods (Access = private)
        function onXLimChanged(obj, ~, ~)
        end

        function onResize(obj, ~, ~)
        end

        function updateLines(obj)
        end

        function updateViolations(obj)
        end

        function pw = getAxesPixelWidth(obj)
            pw = 1920;
        end
    end
end
```

**Step 2: Create placeholder private functions**

Create empty files so the directory structure exists:

`FastSense/private/binary_search.m`:
```matlab
function idx = binary_search(x, val, direction)
%BINARY_SEARCH Find index in sorted array via binary search.
%   idx = binary_search(x, val, 'left')  — first index where x >= val
%   idx = binary_search(x, val, 'right') — last index where x <= val
    idx = 1;
end
```

`FastSense/private/minmax_downsample.m`:
```matlab
function [xOut, yOut] = minmax_downsample(x, y, numBuckets)
%MINMAX_DOWNSAMPLE Reduce data to min/max pairs per bucket.
    xOut = x;
    yOut = y;
end
```

`FastSense/private/lttb_downsample.m`:
```matlab
function [xOut, yOut] = lttb_downsample(x, y, numOut)
%LTTB_DOWNSAMPLE Largest Triangle Three Buckets downsampling.
    xOut = x;
    yOut = y;
end
```

`FastSense/private/compute_violations.m`:
```matlab
function [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%COMPUTE_VIOLATIONS Find points that violate a threshold.
    xViol = [];
    yViol = [];
end
```

**Step 3: Create test runner helper**

Create `FastSense/tests/run_all_tests.m`:
```matlab
function results = run_all_tests()
%RUN_ALL_TESTS Execute all FastSense unit tests.
    import matlab.unittest.TestSuite;
    suite = TestSuite.fromFolder(fileparts(mfilename('fullpath')));
    results = run(suite);
    disp(results.table());
end
```

**Step 4: Verify structure**

In MATLAB, run:
```matlab
cd FastSense
dir
dir private
dir tests
```
Expected: all files present.

---

## Task 2: Binary Search

**Files:**
- Modify: `FastSense/private/binary_search.m`
- Create: `FastSense/tests/TestBinarySearch.m`

**Step 1: Write the test**

Create `FastSense/tests/TestBinarySearch.m`:
```matlab
classdef TestBinarySearch < matlab.unittest.TestCase

    methods (Test)
        function testLeftBasic(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 4, 'left');
            testCase.verifyEqual(idx, 3); % x(3)=5 is first >= 4
        end

        function testRightBasic(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 6, 'right');
            testCase.verifyEqual(idx, 3); % x(3)=5 is last <= 6
        end

        function testLeftExactMatch(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 5, 'left');
            testCase.verifyEqual(idx, 3);
        end

        function testRightExactMatch(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 5, 'right');
            testCase.verifyEqual(idx, 3);
        end

        function testLeftBelowAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 0, 'left');
            testCase.verifyEqual(idx, 1);
        end

        function testRightAboveAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 100, 'right');
            testCase.verifyEqual(idx, 5);
        end

        function testLeftAboveAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 100, 'left');
            testCase.verifyEqual(idx, 5); % clamp to last
        end

        function testRightBelowAll(testCase)
            x = [1 3 5 7 9];
            idx = binary_search(x, 0, 'right');
            testCase.verifyEqual(idx, 1); % clamp to first
        end

        function testUnevenSpacing(testCase)
            x = [0.1 0.5 1.0 10.0 100.0 100.1];
            idx = binary_search(x, 9.0, 'left');
            testCase.verifyEqual(idx, 4); % x(4)=10.0 is first >= 9.0
        end

        function testLargeArray(testCase)
            x = 1:1e6;
            idx = binary_search(x, 500000.5, 'left');
            testCase.verifyEqual(idx, 500001);
        end

        function testSingleElement(testCase)
            x = [5];
            testCase.verifyEqual(binary_search(x, 3, 'left'), 1);
            testCase.verifyEqual(binary_search(x, 7, 'right'), 1);
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
cd FastSense; runtests('tests/TestBinarySearch');
```
Expected: failures (placeholder returns 1 always).

**Step 3: Implement binary_search**

Replace `FastSense/private/binary_search.m`:
```matlab
function idx = binary_search(x, val, direction)
%BINARY_SEARCH Find index in sorted array via binary search.
%   idx = binary_search(x, val, 'left')  — first index where x >= val
%   idx = binary_search(x, val, 'right') — last index where x <= val
%
%   Clamps to [1, numel(x)] — never returns out-of-bounds.

    n = numel(x);

    if strcmp(direction, 'left')
        % Find first index where x(idx) >= val
        lo = 1;
        hi = n;
        idx = n; % default if all < val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) >= val
                idx = mid;
                hi = mid - 1;
            else
                lo = mid + 1;
            end
        end
    else
        % Find last index where x(idx) <= val
        lo = 1;
        hi = n;
        idx = 1; % default if all > val
        while lo <= hi
            mid = floor((lo + hi) / 2);
            if x(mid) <= val
                idx = mid;
                lo = mid + 1;
            else
                hi = mid - 1;
            end
        end
    end
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestBinarySearch');
```
Expected: all 11 tests pass.

---

## Task 3: MinMax Downsampling

**Files:**
- Modify: `FastSense/private/minmax_downsample.m`
- Create: `FastSense/tests/TestMinMaxDownsample.m`

**Step 1: Write the test**

Create `FastSense/tests/TestMinMaxDownsample.m`:
```matlab
classdef TestMinMaxDownsample < matlab.unittest.TestCase

    methods (Test)
        function testBasicReduction(testCase)
            x = 1:100;
            y = sin(linspace(0, 4*pi, 100));
            [xOut, yOut] = minmax_downsample(x, y, 10);
            % 10 buckets → 20 output points (min + max each)
            testCase.verifyEqual(numel(xOut), 20);
            testCase.verifyEqual(numel(yOut), 20);
        end

        function testPreservesExtremes(testCase)
            x = 1:1000;
            y = zeros(1, 1000);
            y(500) = 100;  % spike
            y(700) = -50;  % valley
            [~, yOut] = minmax_downsample(x, y, 50);
            testCase.verifyTrue(any(yOut == 100), 'Must preserve spike');
            testCase.verifyTrue(any(yOut == -50), 'Must preserve valley');
        end

        function testNaNGaps(testCase)
            x = 1:20;
            y = [1:8, NaN, NaN, 11:20];
            [xOut, yOut] = minmax_downsample(x, y, 5);
            % Output should contain NaN separators
            testCase.verifyTrue(any(isnan(yOut)), 'Must preserve NaN gaps');
            % Non-NaN values should still be present
            nonNaN = yOut(~isnan(yOut));
            testCase.verifyGreaterThan(numel(nonNaN), 0);
        end

        function testFewPointsPassthrough(testCase)
            % If data has fewer points than 2*numBuckets, pass through
            x = 1:5;
            y = [10 20 30 40 50];
            [xOut, yOut] = minmax_downsample(x, y, 10);
            testCase.verifyEqual(xOut, x);
            testCase.verifyEqual(yOut, y);
        end

        function testOutputIsMonotonicX(testCase)
            x = linspace(0, 10, 10000);
            y = randn(1, 10000);
            [xOut, ~] = minmax_downsample(x, y, 100);
            % X output should be non-decreasing (within NaN groups)
            nonNanIdx = ~isnan(xOut);
            segments = diff([0, find(isnan(xOut)), numel(xOut)+1]);
            pos = 1;
            for i = 1:numel(segments)
                seg = xOut(pos:pos+segments(i)-2);
                seg = seg(~isnan(seg));
                if numel(seg) > 1
                    testCase.verifyTrue(all(diff(seg) >= 0), ...
                        'X within segment must be non-decreasing');
                end
                pos = pos + segments(i);
            end
        end

        function testUnevenSpacing(testCase)
            % Unevenly spaced X — buckets by index, not by X value
            x = [1 2 3 100 200 300 1000 2000 3000];
            y = [1 2 3 4   5   6   7    8    9];
            [xOut, yOut] = minmax_downsample(x, y, 3);
            % 3 buckets of 3 elements each
            testCase.verifyEqual(numel(xOut), 6); % 3 buckets × 2
        end

        function testAllNaN(testCase)
            x = 1:10;
            y = NaN(1, 10);
            [xOut, yOut] = minmax_downsample(x, y, 3);
            testCase.verifyTrue(all(isnan(yOut)));
        end

        function testLargeData(testCase)
            n = 1e6;
            x = 1:n;
            y = randn(1, n);
            tic;
            [xOut, yOut] = minmax_downsample(x, y, 1000);
            elapsed = toc;
            testCase.verifyEqual(numel(xOut), 2000);
            testCase.verifyLessThan(elapsed, 1.0, ...
                'Must downsample 1M points in < 1s');
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestMinMaxDownsample');
```

**Step 3: Implement minmax_downsample**

Replace `FastSense/private/minmax_downsample.m`:
```matlab
function [xOut, yOut] = minmax_downsample(x, y, numBuckets)
%MINMAX_DOWNSAMPLE Reduce time series to min/max pairs per bucket.
%   [xOut, yOut] = minmax_downsample(x, y, numBuckets)
%
%   Splits data at NaN boundaries, downsamples each contiguous segment
%   independently, and rejoins with NaN separators.
%
%   If total non-NaN points <= 2*numBuckets, returns data unchanged.

    n = numel(y);

    % Find NaN boundaries to get contiguous segments
    isNan = isnan(y);

    % If all NaN, return as-is
    if all(isNan)
        xOut = x;
        yOut = y;
        return;
    end

    % Find start/end of contiguous non-NaN segments
    nanMask = [true, isNan, true]; % pad for diff
    edges = diff(nanMask);
    segStarts = find(edges == -1); % transition into non-NaN
    segEnds   = find(edges == 1) - 1; % transition out of non-NaN
    numSegs = numel(segStarts);

    % Count total non-NaN points
    totalValid = sum(~isNan);

    % If too few points, passthrough
    if totalValid <= 2 * numBuckets
        xOut = x;
        yOut = y;
        return;
    end

    % Distribute buckets proportionally across segments
    segLens = segEnds - segStarts + 1;
    segBuckets = max(1, round(numBuckets * segLens / totalValid));

    % Pre-allocate output (2 per bucket per segment + NaN separators)
    maxOut = sum(segBuckets) * 2 + (numSegs - 1);
    xOut = NaN(1, maxOut);
    yOut = NaN(1, maxOut);
    pos = 0;

    for s = 1:numSegs
        si = segStarts(s);
        ei = segEnds(s);
        nb = segBuckets(s);
        segX = x(si:ei);
        segY = y(si:ei);
        segLen = ei - si + 1;

        if segLen <= 2 * nb
            % Too few points in segment, pass through
            xOut(pos+1:pos+segLen) = segX;
            yOut(pos+1:pos+segLen) = segY;
            pos = pos + segLen;
        else
            % Bucket indices
            bucketEdges = round(linspace(1, segLen+1, nb+1));
            for b = 1:nb
                bStart = bucketEdges(b);
                bEnd   = bucketEdges(b+1) - 1;
                bY = segY(bStart:bEnd);
                [minVal, minIdx] = min(bY);
                [maxVal, maxIdx] = max(bY);
                minIdx = minIdx + bStart - 1;
                maxIdx = maxIdx + bStart - 1;
                % Emit in X-order (preserve monotonicity)
                if minIdx <= maxIdx
                    pos = pos + 1;
                    xOut(pos) = segX(minIdx);
                    yOut(pos) = minVal;
                    pos = pos + 1;
                    xOut(pos) = segX(maxIdx);
                    yOut(pos) = maxVal;
                else
                    pos = pos + 1;
                    xOut(pos) = segX(maxIdx);
                    yOut(pos) = maxVal;
                    pos = pos + 1;
                    xOut(pos) = segX(minIdx);
                    yOut(pos) = minVal;
                end
            end
        end

        % Add NaN separator between segments (not after last)
        if s < numSegs
            pos = pos + 1;
            xOut(pos) = NaN;
            yOut(pos) = NaN;
        end
    end

    % Trim unused pre-allocation
    xOut = xOut(1:pos);
    yOut = yOut(1:pos);
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestMinMaxDownsample');
```
Expected: all 8 tests pass.

---

## Task 4: LTTB Downsampling

**Files:**
- Modify: `FastSense/private/lttb_downsample.m`
- Create: `FastSense/tests/TestLTTBDownsample.m`

**Step 1: Write the test**

Create `FastSense/tests/TestLTTBDownsample.m`:
```matlab
classdef TestLTTBDownsample < matlab.unittest.TestCase

    methods (Test)
        function testOutputSize(testCase)
            x = 1:1000;
            y = sin(linspace(0, 4*pi, 1000));
            [xOut, yOut] = lttb_downsample(x, y, 50);
            testCase.verifyEqual(numel(xOut), 50);
            testCase.verifyEqual(numel(yOut), 50);
        end

        function testPreservesEndpoints(testCase)
            x = 1:1000;
            y = rand(1, 1000);
            [xOut, yOut] = lttb_downsample(x, y, 50);
            testCase.verifyEqual(xOut(1), x(1));
            testCase.verifyEqual(xOut(end), x(end));
            testCase.verifyEqual(yOut(1), y(1));
            testCase.verifyEqual(yOut(end), y(end));
        end

        function testMonotonicX(testCase)
            x = linspace(0, 10, 5000);
            y = randn(1, 5000);
            [xOut, ~] = lttb_downsample(x, y, 100);
            testCase.verifyTrue(all(diff(xOut) > 0));
        end

        function testFewPointsPassthrough(testCase)
            x = 1:5;
            y = [10 20 30 40 50];
            [xOut, yOut] = lttb_downsample(x, y, 10);
            testCase.verifyEqual(xOut, x);
            testCase.verifyEqual(yOut, y);
        end

        function testNaNGaps(testCase)
            x = 1:20;
            y = [1:8, NaN, NaN, 11:20];
            [xOut, yOut] = lttb_downsample(x, y, 8);
            testCase.verifyTrue(any(isnan(yOut)), 'Must preserve NaN gaps');
        end

        function testPerformance(testCase)
            n = 1e6;
            x = 1:n;
            y = randn(1, n);
            tic;
            lttb_downsample(x, y, 1000);
            elapsed = toc;
            testCase.verifyLessThan(elapsed, 2.0, ...
                'Must downsample 1M points in < 2s');
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestLTTBDownsample');
```

**Step 3: Implement lttb_downsample**

Replace `FastSense/private/lttb_downsample.m`:
```matlab
function [xOut, yOut] = lttb_downsample(x, y, numOut)
%LTTB_DOWNSAMPLE Largest Triangle Three Buckets downsampling.
%   [xOut, yOut] = lttb_downsample(x, y, numOut)
%
%   Selects numOut points that best preserve the visual shape of the data
%   by maximizing the triangle area formed between consecutive selected points.
%
%   Handles NaN gaps: splits into segments, distributes output points
%   proportionally, then rejoins with NaN separators.

    n = numel(y);
    isNan = isnan(y);

    % All NaN
    if all(isNan)
        xOut = x;
        yOut = y;
        return;
    end

    % Passthrough if too few
    if n <= numOut
        xOut = x;
        yOut = y;
        return;
    end

    % Find contiguous non-NaN segments
    nanMask = [true, isNan, true];
    edges = diff(nanMask);
    segStarts = find(edges == -1);
    segEnds   = find(edges == 1) - 1;
    numSegs = numel(segStarts);
    segLens = segEnds - segStarts + 1;
    totalValid = sum(segLens);

    % Distribute output points proportionally
    segOuts = max(2, round(numOut * segLens / totalValid));

    % Pre-allocate
    maxOut = sum(segOuts) + (numSegs - 1);
    xOut = NaN(1, maxOut);
    yOut = NaN(1, maxOut);
    pos = 0;

    for s = 1:numSegs
        si = segStarts(s);
        ei = segEnds(s);
        segX = x(si:ei);
        segY = y(si:ei);
        segLen = ei - si + 1;
        nout = segOuts(s);

        if segLen <= nout
            xOut(pos+1:pos+segLen) = segX;
            yOut(pos+1:pos+segLen) = segY;
            pos = pos + segLen;
        else
            [sx, sy] = lttb_core(segX, segY, nout);
            nPts = numel(sx);
            xOut(pos+1:pos+nPts) = sx;
            yOut(pos+1:pos+nPts) = sy;
            pos = pos + nPts;
        end

        if s < numSegs
            pos = pos + 1;
            % NaN separator already in pre-allocated array
        end
    end

    xOut = xOut(1:pos);
    yOut = yOut(1:pos);
end


function [xOut, yOut] = lttb_core(x, y, numOut)
%LTTB_CORE Core LTTB on a contiguous (no NaN) segment.
    n = numel(x);

    % Always keep first and last
    xOut = zeros(1, numOut);
    yOut = zeros(1, numOut);
    xOut(1) = x(1);
    yOut(1) = y(1);
    xOut(numOut) = x(n);
    yOut(numOut) = y(n);

    % Bucket size for interior points
    bucketSize = (n - 2) / (numOut - 2);

    prevSelectedIdx = 1;

    for i = 2:numOut-1
        % Current bucket range
        bStart = floor((i-2) * bucketSize) + 2;
        bEnd   = min(floor((i-1) * bucketSize) + 1, n-1);

        % Next bucket average (for triangle area calculation)
        nStart = floor((i-1) * bucketSize) + 2;
        nEnd   = min(floor(i * bucketSize) + 1, n-1);
        if nEnd < nStart
            nEnd = nStart;
        end
        avgX = mean(x(nStart:nEnd));
        avgY = mean(y(nStart:nEnd));

        % Find point in current bucket that maximizes triangle area
        maxArea = -1;
        bestIdx = bStart;
        pX = x(prevSelectedIdx);
        pY = y(prevSelectedIdx);

        for j = bStart:bEnd
            area = abs((pX - avgX) * (y(j) - pY) - (pX - x(j)) * (avgY - pY));
            if area > maxArea
                maxArea = area;
                bestIdx = j;
            end
        end

        xOut(i) = x(bestIdx);
        yOut(i) = y(bestIdx);
        prevSelectedIdx = bestIdx;
    end
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestLTTBDownsample');
```
Expected: all 6 tests pass.

---

## Task 5: Compute Violations

**Files:**
- Modify: `FastSense/private/compute_violations.m`
- Create: `FastSense/tests/TestComputeViolations.m`

**Step 1: Write the test**

Create `FastSense/tests/TestComputeViolations.m`:
```matlab
classdef TestComputeViolations < matlab.unittest.TestCase

    methods (Test)
        function testUpperViolation(testCase)
            x = 1:10;
            y = [1 2 3 4 5 6 5 4 3 2];
            [xV, yV] = compute_violations(x, y, 4.5, 'upper');
            testCase.verifyEqual(xV, [5 6 7]);
            testCase.verifyEqual(yV, [5 6 5]);
        end

        function testLowerViolation(testCase)
            x = 1:10;
            y = [5 4 3 2 1 0 1 2 3 4];
            [xV, yV] = compute_violations(x, y, 2.5, 'lower');
            testCase.verifyEqual(xV, [5 6 7]);
            testCase.verifyEqual(yV, [1 0 1]);
        end

        function testNoViolations(testCase)
            x = 1:5;
            y = [1 2 3 2 1];
            [xV, yV] = compute_violations(x, y, 10, 'upper');
            testCase.verifyEmpty(xV);
            testCase.verifyEmpty(yV);
        end

        function testWithNaN(testCase)
            x = 1:10;
            y = [1 2 NaN 8 9 10 NaN 3 2 1];
            [xV, yV] = compute_violations(x, y, 5, 'upper');
            % Should find violations at indices 4,5,6 (values 8,9,10)
            testCase.verifyEqual(xV, [4 5 6]);
            testCase.verifyEqual(yV, [8 9 10]);
        end

        function testExactThreshold(testCase)
            x = 1:5;
            y = [1 5 5 5 1];
            % Exact match is NOT a violation (strictly greater/less)
            [xV, ~] = compute_violations(x, y, 5, 'upper');
            testCase.verifyEmpty(xV);
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestComputeViolations');
```

**Step 3: Implement compute_violations**

Replace `FastSense/private/compute_violations.m`:
```matlab
function [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%COMPUTE_VIOLATIONS Find data points that strictly violate a threshold.
%   [xViol, yViol] = compute_violations(x, y, thresholdValue, direction)
%
%   direction: 'upper' — violation when y > thresholdValue
%              'lower' — violation when y < thresholdValue
%
%   NaN values in y are never violations.

    if strcmp(direction, 'upper')
        mask = y > thresholdValue;
    else
        mask = y < thresholdValue;
    end

    % NaN is never a violation
    mask(isnan(y)) = false;

    xViol = x(mask);
    yViol = y(mask);
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestComputeViolations');
```
Expected: all 5 tests pass.

---

## Task 6: FastSense.addLine()

**Files:**
- Modify: `FastSense/FastSense.m` — `addLine` method
- Create: `FastSense/tests/TestAddLine.m`

**Step 1: Write the test**

Create `FastSense/tests/TestAddLine.m`:
```matlab
classdef TestAddLine < matlab.unittest.TestCase

    methods (Test)
        function testAddSingleLine(testCase)
            fp = FastSense();
            x = 1:100;
            y = rand(1, 100);
            fp.addLine(x, y);
            testCase.verifyEqual(numel(fp.Lines), 1);
            testCase.verifyEqual(fp.Lines(1).X, x);
            testCase.verifyEqual(fp.Lines(1).Y, y);
        end

        function testAddMultipleLines(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.addLine(1:20, rand(1,20));
            fp.addLine(1:5, rand(1,5));
            testCase.verifyEqual(numel(fp.Lines), 3);
        end

        function testLineOptions(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10), 'Color', 'r', 'DisplayName', 'S1');
            testCase.verifyEqual(fp.Lines(1).Options.Color, 'r');
            testCase.verifyEqual(fp.Lines(1).Options.DisplayName, 'S1');
        end

        function testDownsampleMethodDefault(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            testCase.verifyEqual(fp.Lines(1).DownsampleMethod, 'minmax');
        end

        function testDownsampleMethodOverride(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10), 'DownsampleMethod', 'lttb');
            testCase.verifyEqual(fp.Lines(1).DownsampleMethod, 'lttb');
        end

        function testRejectsNonMonotonicX(testCase)
            fp = FastSense();
            testCase.verifyError(@() fp.addLine([1 3 2 4], rand(1,4)), ...
                'FastSense:nonMonotonicX');
        end

        function testRejectsMismatchedLengths(testCase)
            fp = FastSense();
            testCase.verifyError(@() fp.addLine(1:10, rand(1,5)), ...
                'FastSense:sizeMismatch');
        end

        function testRejectsAfterRender(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.render();
            testCase.verifyError(@() fp.addLine(1:5, rand(1,5)), ...
                'FastSense:alreadyRendered');
            close(fp.hFigure);
        end

        function testColumnVectorsAccepted(testCase)
            fp = FastSense();
            fp.addLine((1:10)', rand(10,1));
            testCase.verifyEqual(numel(fp.Lines(1).X), 10);
            testCase.verifyTrue(isrow(fp.Lines(1).X));
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestAddLine');
```

**Step 3: Implement addLine in FastSense.m**

Replace the `addLine` method in `FastSense.m`:
```matlab
function addLine(obj, x, y, varargin)
    %ADDLINE Add a data line to the plot.
    %   fp.addLine(x, y)
    %   fp.addLine(x, y, 'Color', 'r', 'DisplayName', 'Sensor1')
    %   fp.addLine(x, y, 'DownsampleMethod', 'lttb')

    if obj.IsRendered
        error('FastSense:alreadyRendered', ...
            'Cannot add lines after render() has been called.');
    end

    % Force row vectors
    x = x(:)';
    y = y(:)';

    % Validate sizes match
    if numel(x) ~= numel(y)
        error('FastSense:sizeMismatch', ...
            'X and Y must have the same number of elements.');
    end

    % Validate monotonically increasing X (ignoring NaN)
    xValid = x(~isnan(x));
    if any(diff(xValid) < 0)
        error('FastSense:nonMonotonicX', ...
            'X must be monotonically increasing.');
    end

    % Parse name-value pairs
    p = inputParser;
    p.KeepUnmatched = true;
    addParameter(p, 'DownsampleMethod', 'minmax', ...
        @(s) ismember(s, {'minmax', 'lttb'}));
    parse(p, varargin{:});

    % Build line struct
    lineStruct.X = x;
    lineStruct.Y = y;
    lineStruct.DownsampleMethod = p.Results.DownsampleMethod;
    lineStruct.Options = p.Unmatched;  % Color, LineWidth, etc.
    lineStruct.hLine = [];             % populated at render

    % Append
    if isempty(obj.Lines)
        obj.Lines = lineStruct;
    else
        obj.Lines(end+1) = lineStruct;
    end
end
```

Also update the `hFigure` property visibility so the test can close it. Change in properties:
```matlab
properties (SetAccess = private)
    Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                        'DownsampleMethod', {}, 'hLine', {})
    Thresholds = struct('Value', {}, 'Direction', {}, ...
                        'ShowViolations', {}, 'Color', {}, ...
                        'LineStyle', {}, 'Label', {})
    IsRendered = false
    hFigure    = []
end
```

And move `hFigure` out of the private properties block accordingly.

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestAddLine');
```
Expected: all 9 tests pass (the `testRejectsAfterRender` will fail until render() is implemented — skip it for now by commenting out, and revisit after Task 8).

---

## Task 7: FastSense.addThreshold()

**Files:**
- Modify: `FastSense/FastSense.m` — `addThreshold` method
- Create: `FastSense/tests/TestAddThreshold.m`

**Step 1: Write the test**

Create `FastSense/tests/TestAddThreshold.m`:
```matlab
classdef TestAddThreshold < matlab.unittest.TestCase

    methods (Test)
        function testAddUpperThreshold(testCase)
            fp = FastSense();
            fp.addThreshold(4.5, 'Direction', 'upper');
            testCase.verifyEqual(numel(fp.Thresholds), 1);
            testCase.verifyEqual(fp.Thresholds(1).Value, 4.5);
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'upper');
        end

        function testAddLowerThreshold(testCase)
            fp = FastSense();
            fp.addThreshold(-2.0, 'Direction', 'lower');
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'lower');
        end

        function testDefaults(testCase)
            fp = FastSense();
            fp.addThreshold(5.0);
            testCase.verifyEqual(fp.Thresholds(1).Direction, 'upper');
            testCase.verifyEqual(fp.Thresholds(1).ShowViolations, false);
            testCase.verifyEqual(fp.Thresholds(1).LineStyle, '--');
            testCase.verifyEqual(fp.Thresholds(1).Label, '');
        end

        function testCustomOptions(testCase)
            fp = FastSense();
            fp.addThreshold(3.0, 'Direction', 'lower', ...
                'ShowViolations', true, 'Color', [1 0 0], ...
                'LineStyle', ':', 'Label', 'LowerBound');
            t = fp.Thresholds(1);
            testCase.verifyEqual(t.ShowViolations, true);
            testCase.verifyEqual(t.Color, [1 0 0]);
            testCase.verifyEqual(t.LineStyle, ':');
            testCase.verifyEqual(t.Label, 'LowerBound');
        end

        function testMultipleThresholds(testCase)
            fp = FastSense();
            fp.addThreshold(1.0);
            fp.addThreshold(2.0);
            fp.addThreshold(3.0);
            testCase.verifyEqual(numel(fp.Thresholds), 3);
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestAddThreshold');
```

**Step 3: Implement addThreshold in FastSense.m**

Replace the `addThreshold` method:
```matlab
function addThreshold(obj, value, varargin)
    %ADDTHRESHOLD Add a horizontal threshold line.
    %   fp.addThreshold(4.5)
    %   fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true)

    if obj.IsRendered
        error('FastSense:alreadyRendered', ...
            'Cannot add thresholds after render() has been called.');
    end

    p = inputParser;
    addParameter(p, 'Direction', 'upper', @(s) ismember(s, {'upper','lower'}));
    addParameter(p, 'ShowViolations', false, @islogical);
    addParameter(p, 'Color', [0.8 0 0], @(c) ischar(c) || (isnumeric(c) && numel(c)==3));
    addParameter(p, 'LineStyle', '--', @ischar);
    addParameter(p, 'Label', '', @ischar);
    parse(p, varargin{:});

    t.Value          = value;
    t.Direction      = p.Results.Direction;
    t.ShowViolations = p.Results.ShowViolations;
    t.Color          = p.Results.Color;
    t.LineStyle      = p.Results.LineStyle;
    t.Label          = p.Results.Label;

    if isempty(obj.Thresholds)
        obj.Thresholds = t;
    else
        obj.Thresholds(end+1) = t;
    end
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestAddThreshold');
```
Expected: all 5 tests pass.

---

## Task 8: FastSense.render() — Core Rendering

**Files:**
- Modify: `FastSense/FastSense.m` — `render`, `getAxesPixelWidth`, private helpers
- Create: `FastSense/tests/TestRender.m`

**Step 1: Write the test**

Create `FastSense/tests/TestRender.m`:
```matlab
classdef TestRender < matlab.unittest.TestCase

    methods (Test)
        function testCreatesNewFigure(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'Test');
            fp.render();
            testCase.verifyTrue(isgraphics(fp.hFigure, 'figure'));
            testCase.verifyTrue(isgraphics(fp.hAxes, 'axes'));
            close(fp.hFigure);
        end

        function testUsesExistingAxes(testCase)
            fig = figure('Visible', 'off');
            ax = axes(fig);
            fp = FastSense('Parent', ax);
            fp.addLine(1:100, rand(1,100));
            fp.render();
            testCase.verifyEqual(fp.hAxes, ax);
            close(fig);
        end

        function testCreatesLineObjects(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'L1');
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'L2');
            fp.render();
            testCase.verifyEqual(numel(fp.Lines), 2);
            testCase.verifyTrue(isgraphics(fp.Lines(1).hLine, 'line'));
            testCase.verifyTrue(isgraphics(fp.Lines(2).hLine, 'line'));
            close(fp.hFigure);
        end

        function testUserDataTagging(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100), 'DisplayName', 'Sensor1');
            fp.addThreshold(0.5, 'Label', 'UpperLim');
            fp.render();
            % Check data line tag
            ud = fp.Lines(1).hLine.UserData;
            testCase.verifyEqual(ud.FastSense.Type, 'data_line');
            testCase.verifyEqual(ud.FastSense.Name, 'Sensor1');
            testCase.verifyEqual(ud.FastSense.LineIndex, 1);
            close(fp.hFigure);
        end

        function testThresholdLineCreated(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.addThreshold(0.5, 'Direction', 'upper', 'Label', 'UL');
            fp.render();
            testCase.verifyTrue(isgraphics(fp.hThreshLines, 'line'));
            ud = fp.hThreshLines.UserData;
            testCase.verifyEqual(ud.FastSense.Type, 'threshold');
            close(fp.hFigure);
        end

        function testViolationMarkersCreated(testCase)
            fp = FastSense();
            y = [0.1 0.2 0.8 0.9 0.3 0.1];
            fp.addLine(1:6, y);
            fp.addThreshold(0.5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();
            testCase.verifyTrue(isgraphics(fp.hViolMarkers, 'line'));
            % Markers should exist at indices 3,4 (y=0.8, 0.9)
            vx = fp.hViolMarkers.XData;
            vx = vx(~isnan(vx));
            testCase.verifyTrue(ismember(3, vx));
            testCase.verifyTrue(ismember(4, vx));
            close(fp.hFigure);
        end

        function testDoubleRenderError(testCase)
            fp = FastSense();
            fp.addLine(1:10, rand(1,10));
            fp.render();
            testCase.verifyError(@() fp.render(), 'FastSense:alreadyRendered');
            close(fp.hFigure);
        end

        function testStaticAxisLimits(testCase)
            fp = FastSense();
            fp.addLine(1:100, rand(1,100));
            fp.render();
            ax = fp.hAxes;
            testCase.verifyEqual(ax.XLimMode, 'manual');
            testCase.verifyEqual(ax.YLimMode, 'manual');
            close(fp.hFigure);
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestRender');
```

**Step 3: Implement render and helper methods in FastSense.m**

Update the `hAxes` and `hThreshLines` and `hViolMarkers` to `SetAccess = private` (public read):
```matlab
properties (SetAccess = private)
    Lines      = struct('X', {}, 'Y', {}, 'Options', {}, ...
                        'DownsampleMethod', {}, 'hLine', {})
    Thresholds = struct('Value', {}, 'Direction', {}, ...
                        'ShowViolations', {}, 'Color', {}, ...
                        'LineStyle', {}, 'Label', {})
    IsRendered    = false
    hFigure       = []
    hAxes         = []
    hThreshLines  = []
    hViolMarkers  = []
end
```

Implement `render`:
```matlab
function render(obj)
    %RENDER Create the plot with all configured lines and thresholds.

    if obj.IsRendered
        error('FastSense:alreadyRendered', ...
            'render() has already been called on this FastSense.');
    end
    if isempty(obj.Lines)
        error('FastSense:noLines', 'Add at least one line before render().');
    end

    % Create or use axes
    if isempty(obj.ParentAxes)
        obj.hFigure = figure();
        obj.hAxes = axes(obj.hFigure);
    else
        obj.hAxes = obj.ParentAxes;
        obj.hFigure = ancestor(obj.hAxes, 'figure');
    end

    hold(obj.hAxes, 'on');
    obj.PixelWidth = obj.getAxesPixelWidth();

    % --- Render data lines ---
    for i = 1:numel(obj.Lines)
        L = obj.Lines(i);
        numBuckets = obj.PixelWidth;

        % Downsample
        if numel(L.X) > obj.MIN_POINTS_FOR_DOWNSAMPLE
            if strcmp(L.DownsampleMethod, 'lttb')
                [xd, yd] = lttb_downsample(L.X, L.Y, numBuckets);
            else
                [xd, yd] = minmax_downsample(L.X, L.Y, numBuckets);
            end
        else
            xd = L.X;
            yd = L.Y;
        end

        % Create line object
        h = line(obj.hAxes, xd, yd);

        % Apply user options
        opts = L.Options;
        fnames = fieldnames(opts);
        for f = 1:numel(fnames)
            h.(fnames{f}) = opts.(fnames{f});
        end

        % Tag with UserData
        displayName = '';
        if isfield(opts, 'DisplayName')
            displayName = opts.DisplayName;
        end
        h.UserData.FastSense = struct( ...
            'Type', 'data_line', ...
            'Name', displayName, ...
            'LineIndex', i, ...
            'ThresholdValue', []);

        obj.Lines(i).hLine = h;
    end

    % --- Compute full X range ---
    xAll = [];
    for i = 1:numel(obj.Lines)
        xValid = obj.Lines(i).X(~isnan(obj.Lines(i).X));
        xAll = [xAll, xValid(1), xValid(end)]; %#ok<AGROW>
    end
    xmin = min(xAll);
    xmax = max(xAll);

    % --- Render threshold lines (NaN-batched) ---
    if ~isempty(obj.Thresholds)
        nT = numel(obj.Thresholds);
        txAll = NaN(1, nT * 3 - 1);
        tyAll = NaN(1, nT * 3 - 1);
        pos = 0;
        for t = 1:nT
            pos = pos + 1; txAll(pos) = xmin; tyAll(pos) = obj.Thresholds(t).Value;
            pos = pos + 1; txAll(pos) = xmax; tyAll(pos) = obj.Thresholds(t).Value;
            if t < nT
                pos = pos + 1; % NaN separator (already NaN)
            end
        end

        % Use first threshold's style for the batched line
        obj.hThreshLines = line(obj.hAxes, txAll, tyAll, ...
            'Color', obj.Thresholds(1).Color, ...
            'LineStyle', obj.Thresholds(1).LineStyle, ...
            'HandleVisibility', 'off');
        obj.hThreshLines.UserData.FastSense = struct( ...
            'Type', 'threshold', ...
            'Name', 'thresholds', ...
            'LineIndex', [], ...
            'ThresholdValue', [obj.Thresholds.Value]);
    end

    % --- Render violation markers ---
    vxAll = [];
    vyAll = [];
    for t = 1:numel(obj.Thresholds)
        if ~obj.Thresholds(t).ShowViolations
            continue;
        end
        for i = 1:numel(obj.Lines)
            [vx, vy] = compute_violations( ...
                obj.Lines(i).X, obj.Lines(i).Y, ...
                obj.Thresholds(t).Value, obj.Thresholds(t).Direction);
            if ~isempty(vx)
                vxAll = [vxAll, vx, NaN]; %#ok<AGROW>
                vyAll = [vyAll, vy, NaN]; %#ok<AGROW>
            end
        end
    end
    if ~isempty(vxAll)
        % Remove trailing NaN
        vxAll = vxAll(1:end-1);
        vyAll = vyAll(1:end-1);
        obj.hViolMarkers = line(obj.hAxes, vxAll, vyAll, ...
            'LineStyle', 'none', 'Marker', 'o', ...
            'MarkerSize', 4, 'Color', 'r', ...
            'HandleVisibility', 'off');
        obj.hViolMarkers.UserData.FastSense = struct( ...
            'Type', 'violation_marker', ...
            'Name', 'violations', ...
            'LineIndex', [], ...
            'ThresholdValue', []);
    end

    % --- Set static axis limits ---
    yAll = [];
    for i = 1:numel(obj.Lines)
        yValid = obj.Lines(i).Y(~isnan(obj.Lines(i).Y));
        if ~isempty(yValid)
            yAll = [yAll, min(yValid), max(yValid)]; %#ok<AGROW>
        end
    end
    ymin = min(yAll);
    ymax = max(yAll);
    yPad = (ymax - ymin) * 0.05;
    if yPad == 0; yPad = 1; end

    obj.hAxes.XLim = [xmin, xmax];
    obj.hAxes.YLim = [ymin - yPad, ymax + yPad];
    obj.hAxes.XLimMode = 'manual';
    obj.hAxes.YLimMode = 'manual';

    obj.CachedXLim = obj.hAxes.XLim;

    % --- Install listeners ---
    obj.Listeners = [ ...
        addlistener(obj.hAxes, 'XLim', 'PostSet', @(s,e) obj.onXLimChanged(s,e)), ...
        addlistener(obj.hFigure, 'SizeChangedFcn', 'PostSet', @(s,e) obj.onResize(s,e)) ...
    ];

    % Enable zoom and pan
    zoom(obj.hFigure, 'on');

    obj.IsRendered = true;
    hold(obj.hAxes, 'off');
    drawnow;
end
```

Implement `getAxesPixelWidth`:
```matlab
function pw = getAxesPixelWidth(obj)
    oldUnits = obj.hAxes.Units;
    obj.hAxes.Units = 'pixels';
    pos = obj.hAxes.Position;
    obj.hAxes.Units = oldUnits;
    pw = max(100, floor(pos(3)));
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestRender');
```
Expected: all 8 tests pass. (Note: `SizeChangedFcn` listener may need adjustment for 2020b — if it errors, replace with a `ResizeFcn` callback on the figure.)

---

## Task 9: Zoom/Pan Callbacks

**Files:**
- Modify: `FastSense/FastSense.m` — `onXLimChanged`, `updateLines`, `updateViolations`, `onResize`
- Create: `FastSense/tests/TestZoomPan.m`

**Step 1: Write the test**

Create `FastSense/tests/TestZoomPan.m`:
```matlab
classdef TestZoomPan < matlab.unittest.TestCase

    methods (Test)
        function testZoomUpdatesPlottedData(testCase)
            fp = FastSense();
            n = 100000;
            x = linspace(0, 100, n);
            y = sin(x);
            fp.addLine(x, y, 'DisplayName', 'sine');
            fp.render();

            % Initial: full range, heavily downsampled
            initialPoints = numel(fp.Lines(1).hLine.XData);

            % Simulate zoom to [10, 20]
            fp.hAxes.XLim = [10 20];
            drawnow;
            pause(0.1); % let listener fire

            zoomedPoints = numel(fp.Lines(1).hLine.XData);
            % After zoom, we see ~10% of data but still downsampled
            % Points should be similar count (pixel-based) but different data
            testCase.verifyGreaterThan(zoomedPoints, 0);

            close(fp.hFigure);
        end

        function testLazySkipsRedundantUpdate(testCase)
            fp = FastSense();
            fp.addLine(1:1000, rand(1,1000));
            fp.render();

            % Set same XLim — should not crash, should be lazy no-op
            currentXLim = fp.hAxes.XLim;
            fp.hAxes.XLim = currentXLim;
            drawnow;
            pause(0.1);

            % Just verify it didn't crash
            testCase.verifyTrue(fp.IsRendered);
            close(fp.hFigure);
        end

        function testViolationsUpdateOnZoom(testCase)
            fp = FastSense();
            y = [zeros(1,500), ones(1,500)*10, zeros(1,500)];
            x = 1:1500;
            fp.addLine(x, y);
            fp.addThreshold(5, 'Direction', 'upper', 'ShowViolations', true);
            fp.render();

            % Zoom to region with violations
            fp.hAxes.XLim = [400 1100];
            drawnow;
            pause(0.1);

            vx = fp.hViolMarkers.XData;
            vx = vx(~isnan(vx));
            testCase.verifyGreaterThan(numel(vx), 0, ...
                'Should show violations in zoomed region');

            % Zoom to region without violations
            fp.hAxes.XLim = [1 200];
            drawnow;
            pause(0.1);

            vx = fp.hViolMarkers.XData;
            vx = vx(~isnan(vx));
            testCase.verifyEqual(numel(vx), 0, ...
                'Should show no violations outside violation region');

            close(fp.hFigure);
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestZoomPan');
```

**Step 3: Implement zoom/pan callbacks in FastSense.m**

Replace `onXLimChanged`:
```matlab
function onXLimChanged(obj, ~, ~)
    if ~obj.IsRendered || ~isgraphics(obj.hAxes)
        return;
    end

    newXLim = obj.hAxes.XLim;

    % Lazy: skip if unchanged
    if ~isempty(obj.CachedXLim) && all(abs(newXLim - obj.CachedXLim) < eps)
        return;
    end
    obj.CachedXLim = newXLim;

    obj.updateLines();
    obj.updateViolations();

    % Propagate to linked axes
    if ~isempty(obj.LinkGroup)
        obj.propagateXLim(newXLim);
    end

    drawnow limitrate;
end
```

Replace `updateLines`:
```matlab
function updateLines(obj)
    pw = obj.getAxesPixelWidth();
    xlims = obj.hAxes.XLim;

    for i = 1:numel(obj.Lines)
        L = obj.Lines(i);

        % Binary search for visible range
        idxStart = binary_search(L.X, xlims(1), 'left');
        idxEnd   = binary_search(L.X, xlims(2), 'right');

        % Pad by 1 on each side for line continuity at edges
        idxStart = max(1, idxStart - 1);
        idxEnd   = min(numel(L.X), idxEnd + 1);

        xVis = L.X(idxStart:idxEnd);
        yVis = L.Y(idxStart:idxEnd);

        % Downsample if needed
        nVis = idxEnd - idxStart + 1;
        if nVis > obj.MIN_POINTS_FOR_DOWNSAMPLE
            if strcmp(L.DownsampleMethod, 'lttb')
                [xd, yd] = lttb_downsample(xVis, yVis, pw);
            else
                [xd, yd] = minmax_downsample(xVis, yVis, pw);
            end
        else
            xd = xVis;
            yd = yVis;
        end

        % Update line (no recreation)
        L.hLine.XData = xd;
        L.hLine.YData = yd;
    end
end
```

Replace `updateViolations`:
```matlab
function updateViolations(obj)
    if isempty(obj.hViolMarkers) || ~isgraphics(obj.hViolMarkers)
        return;
    end

    xlims = obj.hAxes.XLim;
    vxAll = [];
    vyAll = [];

    for t = 1:numel(obj.Thresholds)
        if ~obj.Thresholds(t).ShowViolations
            continue;
        end
        for i = 1:numel(obj.Lines)
            L = obj.Lines(i);
            idxStart = binary_search(L.X, xlims(1), 'left');
            idxEnd   = binary_search(L.X, xlims(2), 'right');
            xVis = L.X(idxStart:idxEnd);
            yVis = L.Y(idxStart:idxEnd);

            [vx, vy] = compute_violations(xVis, yVis, ...
                obj.Thresholds(t).Value, obj.Thresholds(t).Direction);
            if ~isempty(vx)
                vxAll = [vxAll, vx, NaN]; %#ok<AGROW>
                vyAll = [vyAll, vy, NaN]; %#ok<AGROW>
            end
        end
    end

    if ~isempty(vxAll)
        vxAll = vxAll(1:end-1);
        vyAll = vyAll(1:end-1);
        obj.hViolMarkers.XData = vxAll;
        obj.hViolMarkers.YData = vyAll;
    else
        obj.hViolMarkers.XData = NaN;
        obj.hViolMarkers.YData = NaN;
    end
end
```

Replace `onResize`:
```matlab
function onResize(obj, ~, ~)
    if ~obj.IsRendered || ~isgraphics(obj.hAxes)
        return;
    end
    newPW = obj.getAxesPixelWidth();
    if newPW ~= obj.PixelWidth
        obj.PixelWidth = newPW;
        obj.updateLines();
        drawnow limitrate;
    end
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestZoomPan');
```
Expected: all 3 tests pass.

---

## Task 10: Linked Axes

**Files:**
- Modify: `FastSense/FastSense.m` — add `propagateXLim` method, class-level registry
- Create: `FastSense/tests/TestLinkedAxes.m`

**Step 1: Write the test**

Create `FastSense/tests/TestLinkedAxes.m`:
```matlab
classdef TestLinkedAxes < matlab.unittest.TestCase

    methods (Test)
        function testLinkedZoomPropagates(testCase)
            fig = figure('Visible', 'off');
            ax1 = subplot(2,1,1, 'Parent', fig);
            ax2 = subplot(2,1,2, 'Parent', fig);

            fp1 = FastSense('Parent', ax1, 'LinkGroup', 'testgroup');
            fp1.addLine(1:1000, rand(1,1000));
            fp1.render();

            fp2 = FastSense('Parent', ax2, 'LinkGroup', 'testgroup');
            fp2.addLine(1:1000, rand(1,1000));
            fp2.render();

            % Zoom fp1
            fp1.hAxes.XLim = [200 400];
            drawnow;
            pause(0.2);

            % fp2 should follow
            testCase.verifyEqual(fp2.hAxes.XLim, [200 400], 'AbsTol', 1);

            close(fig);
        end

        function testUnlinkedDoesNotPropagate(testCase)
            fig = figure('Visible', 'off');
            ax1 = subplot(2,1,1, 'Parent', fig);
            ax2 = subplot(2,1,2, 'Parent', fig);

            fp1 = FastSense('Parent', ax1);
            fp1.addLine(1:1000, rand(1,1000));
            fp1.render();

            fp2 = FastSense('Parent', ax2);
            fp2.addLine(1:1000, rand(1,1000));
            fp2.render();

            originalXLim = fp2.hAxes.XLim;
            fp1.hAxes.XLim = [200 400];
            drawnow;
            pause(0.2);

            testCase.verifyEqual(fp2.hAxes.XLim, originalXLim);

            close(fig);
        end
    end
end
```

**Step 2: Run test — expect FAIL**

```matlab
runtests('tests/TestLinkedAxes');
```

**Step 3: Implement linked axes**

Add a persistent registry. Add to `FastSense.m` a static method section:
```matlab
methods (Static, Access = private)
    function registry = getLinkRegistry(action, group, obj)
        %GETLINKREGISTRY Persistent registry for linked FastSense instances.
        persistent reg;
        if isempty(reg)
            reg = struct();
        end

        switch action
            case 'register'
                safeGroup = matlab.lang.makeValidName(group);
                if ~isfield(reg, safeGroup)
                    reg.(safeGroup) = {};
                end
                reg.(safeGroup){end+1} = obj;

            case 'get'
                safeGroup = matlab.lang.makeValidName(group);
                if isfield(reg, safeGroup)
                    registry = reg.(safeGroup);
                else
                    registry = {};
                end
                return;

            case 'cleanup'
                % Remove dead handles
                safeGroup = matlab.lang.makeValidName(group);
                if isfield(reg, safeGroup)
                    alive = cellfun(@(o) isvalid(o), reg.(safeGroup));
                    reg.(safeGroup) = reg.(safeGroup)(alive);
                end
        end
        registry = [];
    end
end
```

Add `propagateXLim` to private methods:
```matlab
function propagateXLim(obj, newXLim)
    members = FastSense.getLinkRegistry('get', obj.LinkGroup, []);
    for i = 1:numel(members)
        other = members{i};
        if other ~= obj && isvalid(other) && isgraphics(other.hAxes)
            other.CachedXLim = newXLim;
            other.hAxes.XLim = newXLim;
            other.updateLines();
            other.updateViolations();
        end
    end
end
```

In `render()`, after setting `obj.IsRendered = true`, add registration:
```matlab
% Register in link group
if ~isempty(obj.LinkGroup)
    FastSense.getLinkRegistry('register', obj.LinkGroup, obj);
end
```

**Step 4: Run test — expect PASS**

```matlab
runtests('tests/TestLinkedAxes');
```
Expected: both tests pass.

---

## Task 11: Resize Handling Fix

**Files:**
- Modify: `FastSense/FastSense.m` — fix resize listener for 2020b

**Step 1: Fix resize listener**

In MATLAB 2020b, `SizeChangedFcn` PostSet listener may not work on classic figures. Replace the listener setup in `render()`:

Change:
```matlab
obj.Listeners = [ ...
    addlistener(obj.hAxes, 'XLim', 'PostSet', @(s,e) obj.onXLimChanged(s,e)), ...
    addlistener(obj.hFigure, 'SizeChangedFcn', 'PostSet', @(s,e) obj.onResize(s,e)) ...
];
```

To:
```matlab
obj.Listeners = addlistener(obj.hAxes, 'XLim', 'PostSet', @(s,e) obj.onXLimChanged(s,e));
obj.hFigure.ResizeFcn = @(s,e) obj.onResize(s,e);
```

**Step 2: Run all tests**

```matlab
cd FastSense; runtests('tests');
```
Expected: all tests pass.

---

## Task 12: Example Scripts

**Files:**
- Create: `FastSense/examples/example_basic.m`
- Create: `FastSense/examples/example_multi.m`
- Create: `FastSense/examples/example_100M.m`
- Create: `FastSense/examples/example_linked.m`

**Step 1: Create example_basic.m**

```matlab
%% FastSense Basic Example — 10M points single line
% Demonstrates basic usage with a large time series

n = 10e6;
x = linspace(0, 100, n);
y = sin(x * 2 * pi / 10) + 0.5 * randn(1, n);

fprintf('Creating FastSense with %d points...\n', n);
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Noisy Sine', 'Color', [0 0.4470 0.7410]);
fp.addThreshold(1.5, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', 'r', 'Label', 'Upper');
fp.addThreshold(-1.5, 'Direction', 'lower', 'ShowViolations', true, ...
    'Color', [0.8 0.4 0], 'Label', 'Lower');
fp.render();

fprintf('Rendered in %.3f seconds. Try zooming and panning!\n', toc);
title(fp.hAxes, 'FastSense — 10M Points');
legend(fp.hAxes, 'show');
```

**Step 2: Create example_multi.m**

```matlab
%% FastSense Multi-Line Example — 5 sensors, 1M points each
% Demonstrates multiple lines with thresholds

n = 1e6;
x = linspace(0, 60, n); % 60 seconds

fprintf('Creating 5 lines x %d points = %d total...\n', n, 5*n);
tic;

fp = FastSense();
colors = lines(5);
for i = 1:5
    y = sin(x * 2 * pi * i / 10) + 0.3 * randn(1, n) + i * 2;
    fp.addLine(x, y, 'DisplayName', sprintf('Sensor %d', i), ...
        'Color', colors(i,:), 'LineWidth', 1);
end
fp.addThreshold(10, 'Direction', 'upper', 'ShowViolations', true, ...
    'Color', 'r', 'LineStyle', '--');
fp.render();

fprintf('Rendered in %.3f seconds.\n', toc);
title(fp.hAxes, 'FastSense — 5 Lines x 1M Points');
legend(fp.hAxes, 'show');
```

**Step 3: Create example_100M.m**

```matlab
%% FastSense Stress Test — 100M points
% Demonstrates performance at maximum scale

n = 100e6;
fprintf('Generating %d data points (~800 MB)...\n', n);
tic;
x = linspace(0, 1000, n);
y = cumsum(randn(1, n)) / sqrt(n);  % random walk
fprintf('Data generated in %.1f seconds.\n', toc);

fprintf('Rendering...\n');
tic;

fp = FastSense();
fp.addLine(x, y, 'DisplayName', '100M Random Walk', 'Color', [0 0.4 0.8]);
fp.addThreshold(3, 'Direction', 'upper', 'ShowViolations', true);
fp.addThreshold(-3, 'Direction', 'lower', 'ShowViolations', true);
fp.render();

fprintf('Rendered in %.3f seconds. Zoom in to see detail!\n', toc);
title(fp.hAxes, 'FastSense — 100M Points Stress Test');
```

**Step 4: Create example_linked.m**

```matlab
%% FastSense Linked Axes Example
% Demonstrates synchronized zoom/pan across subplots

n = 5e6;
x = linspace(0, 100, n);

fig = figure('Name', 'FastSense Linked Axes', 'Position', [100 100 1200 600]);

% Top plot
ax1 = subplot(3,1,1, 'Parent', fig);
fp1 = FastSense('Parent', ax1, 'LinkGroup', 'sync');
fp1.addLine(x, sin(x * 2 * pi / 5) + 0.2*randn(1,n), ...
    'DisplayName', 'Pressure', 'Color', 'b');
fp1.addThreshold(1.2, 'Direction', 'upper', 'ShowViolations', true);
fp1.render();
title(ax1, 'Pressure');

% Middle plot
ax2 = subplot(3,1,2, 'Parent', fig);
fp2 = FastSense('Parent', ax2, 'LinkGroup', 'sync');
fp2.addLine(x, cos(x * 2 * pi / 8) + 0.3*randn(1,n), ...
    'DisplayName', 'Temperature', 'Color', [0.8 0.3 0]);
fp2.render();
title(ax2, 'Temperature');

% Bottom plot
ax3 = subplot(3,1,3, 'Parent', fig);
fp3 = FastSense('Parent', ax3, 'LinkGroup', 'sync');
fp3.addLine(x, cumsum(randn(1,n))/sqrt(n), ...
    'DisplayName', 'Vibration', 'Color', [0 0.6 0]);
fp3.render();
title(ax3, 'Vibration');

fprintf('All 3 plots linked. Zoom one — all follow!\n');
```

---

## Task 13: Final Assembly and README

**Files:**
- Create: `FastSense/README.md`
- Verify full test suite passes

**Step 1: Create README.md**

```markdown
# FastSense

Ultra-fast time series plotting for MATLAB 2020b. Plot 100M+ data points with fluid zoom and pan.

## Features

- **Dynamic MinMax downsampling** — reduces data to screen resolution (~4000 points for 1920px)
- **Fluid zoom/pan** — O(log n) binary search + instant re-downsample on every interaction
- **NaN gaps** — handled natively, no preprocessing needed
- **Unevenly sampled data** — no uniform spacing assumption
- **Threshold lines** with violation markers
- **Linked axes** — synchronized zoom/pan across subplots (opt-in)
- **UserData tagging** — programmatically identify all plot elements
- **Pure MATLAB** — no MEX, no toolbox dependencies

## Quick Start

```matlab
addpath('FastSense');

fp = FastSense();
fp.addLine(x, y, 'DisplayName', 'Sensor1', 'Color', 'b');
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true);
fp.render();
```

## Requirements

- MATLAB R2020b

## Examples

See `examples/` folder for complete demos.
```

**Step 2: Run full test suite**

```matlab
cd FastSense; runtests('tests');
```
Expected: all tests pass across all test files.

---

## Summary

| Task | Description | Files | Est. Complexity |
|------|-------------|-------|-----------------|
| 1 | Project scaffolding | 6 files | Low |
| 2 | Binary search | 2 files | Low |
| 3 | MinMax downsampling | 2 files | Medium |
| 4 | LTTB downsampling | 2 files | Medium |
| 5 | Compute violations | 2 files | Low |
| 6 | addLine() | 2 files | Low |
| 7 | addThreshold() | 2 files | Low |
| 8 | render() | 2 files | High |
| 9 | Zoom/Pan callbacks | 2 files | High |
| 10 | Linked axes | 2 files | Medium |
| 11 | Resize fix for 2020b | 1 file | Low |
| 12 | Example scripts | 4 files | Low |
| 13 | README + final test | 1 file | Low |

**Dependencies:** Task 1 first. Tasks 2-5 are independent (parallel). Tasks 6-7 depend on 1. Task 8 depends on 2-7. Task 9 depends on 8. Task 10 depends on 9. Tasks 11-13 depend on 10.
