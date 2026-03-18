# Unified Threshold API Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Unify the dual threshold/violation rendering paths so `addSensor` routes through `addThreshold` instead of `addLine`+`addMarker`, giving time-varying thresholds the same pixel-culled, dirty-flagged, optimized rendering as scalar thresholds.

**Architecture:** Extend `addThreshold` to accept X/Y arrays (time-varying step functions) in addition to scalar values. Add `compute_violations_dynamic` for comparing data against interpolated thresholds. Rewrite `addSensor` to use `addThreshold` exclusively. Remove `addThresholdConnectors` (step transitions become native).

**Tech Stack:** MATLAB/Octave, existing FastSense private function pattern, `interp1(..., 'previous')` for step-function lookup.

---

### Task 1: Extend Thresholds struct and `addThreshold` to accept X/Y arrays

**Files:**
- Modify: `libs/FastSense/FastSense.m:90-93` (Thresholds struct definition)
- Modify: `libs/FastSense/FastSense.m:395-425` (addThreshold method)
- Test: `tests/test_add_threshold.m`

**Step 1: Write the failing test**

Add to `tests/test_add_threshold.m` before the final fprintf:

```matlab
    % testTimeVaryingThreshold
    fp = FastSense();
    thX = [0 10 20 30];
    thY = [5.0 5.0 7.0 7.0];
    fp.addThreshold(thX, thY, 'Direction', 'upper', 'ShowViolations', true, 'Label', 'StepTh');
    assert(numel(fp.Thresholds) == 1, 'testTimeVarying: count');
    assert(isempty(fp.Thresholds(1).Value), 'testTimeVarying: Value should be empty');
    assert(isequal(fp.Thresholds(1).X, thX), 'testTimeVarying: X');
    assert(isequal(fp.Thresholds(1).Y, thY), 'testTimeVarying: Y');
    assert(strcmp(fp.Thresholds(1).Direction, 'upper'), 'testTimeVarying: direction');
    assert(fp.Thresholds(1).ShowViolations == true, 'testTimeVarying: ShowViolations');

    % testMixedThresholds — scalar and time-varying coexist
    fp = FastSense();
    fp.addThreshold(4.5);
    fp.addThreshold([0 10], [3.0 5.0], 'Direction', 'lower');
    assert(numel(fp.Thresholds) == 2, 'testMixed: count');
    assert(fp.Thresholds(1).Value == 4.5, 'testMixed: scalar Value');
    assert(isempty(fp.Thresholds(2).Value), 'testMixed: tv Value empty');
```

Update fprintf count to 7.

**Step 2: Run test to verify it fails**

Run: `octave --eval "cd tests; addpath('..'); setup; test_add_threshold"`
Expected: FAIL — addThreshold doesn't accept 3+ positional args.

**Step 3: Implement the changes**

In `libs/FastSense/FastSense.m`, modify the Thresholds struct definition (line 90-93) to add X and Y fields:

```matlab
        Thresholds = struct('Value', {}, 'X', {}, 'Y', {}, ...
                            'Direction', {}, ...
                            'ShowViolations', {}, 'Color', {}, ...
                            'LineStyle', {}, 'Label', {}, ...
                            'hLine', {}, 'hMarkers', {})
```

Rewrite `addThreshold` (line 395-425) to detect scalar vs X/Y:

```matlab
        function addThreshold(obj, varargin)
            %ADDTHRESHOLD Add a threshold line (scalar or time-varying).
            %   fp.addThreshold(4.5)
            %   fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true)
            %   fp.addThreshold(thX, thY, 'Direction', 'upper', 'ShowViolations', true)

            if obj.IsRendered
                error('FastSense:alreadyRendered', ...
                    'Cannot add thresholds after render() has been called.');
            end

            % Detect scalar vs time-varying
            if nargin >= 3 && isnumeric(varargin{1}) && isnumeric(varargin{2}) && numel(varargin{1}) > 1
                % Time-varying: addThreshold(thX, thY, ...)
                thX = varargin{1};
                thY = varargin{2};
                if ~isrow(thX); thX = thX(:)'; end
                if ~isrow(thY); thY = thY(:)'; end
                nvPairs = varargin(3:end);
                isTimeVarying = true;
            else
                % Scalar: addThreshold(value, ...)
                thX = [];
                thY = [];
                nvPairs = varargin(2:end);
                isTimeVarying = false;
            end

            defaults.Direction = 'upper';
            defaults.ShowViolations = false;
            defaults.Color = obj.Theme.ThresholdColor;
            defaults.LineStyle = obj.Theme.ThresholdStyle;
            defaults.Label = '';
            [parsed, ~] = parseOpts(defaults, nvPairs, obj.Verbose);

            t.Value          = [];
            t.X              = [];
            t.Y              = [];
            if isTimeVarying
                t.X = thX;
                t.Y = thY;
            else
                t.Value = varargin{1};
            end
            t.Direction      = parsed.Direction;
            t.ShowViolations = parsed.ShowViolations;
            t.Color          = parsed.Color;
            t.LineStyle      = parsed.LineStyle;
            t.Label          = parsed.Label;
            t.hLine          = [];
            t.hMarkers       = [];

            if isempty(obj.Thresholds)
                obj.Thresholds = t;
            else
                obj.Thresholds(end+1) = t;
            end
        end
```

**Step 4: Run test to verify it passes**

Run: `octave --eval "cd tests; addpath('..'); setup; test_add_threshold"`
Expected: All 7 tests pass.

**Step 5: Commit**

```
feat: extend addThreshold to accept time-varying X/Y arrays
```

---

### Task 2: Create `compute_violations_dynamic` for time-varying thresholds

**Files:**
- Create: `libs/FastSense/private/compute_violations_dynamic.m`
- Create: `tests/test_compute_violations_dynamic.m`

**Step 1: Write the failing test**

Create `tests/test_compute_violations_dynamic.m`:

```matlab
function test_compute_violations_dynamic()
%TEST_COMPUTE_VIOLATIONS_DYNAMIC Tests for time-varying threshold violations.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));setup();
    add_fastsense_private_path();

    % testUpperStepFunction: threshold steps from 5 to 8 at x=10
    thX = [0 10 20];
    thY = [5  8  8];
    x = 1:20;
    y = [3 4 6 7 4 5 6 7 8 9   3 4 5 6 7 8 9 10 7 6];
    %    1 2 3 4 5 6 7 8 9 10  11 ...
    % Threshold is 5 for x<10, 8 for x>=10
    % Upper violations: y>5 for x<10 -> x=3(6),4(7),7(6),8(7),9(8),10(9)
    %                   y>8 for x>=10 -> x=18(10),19(7 no),20(6 no) -> wait
    % x=3: y=6>5 yes; x=4: y=7>5 yes; x=5: y=4>5 no; x=6: y=5>5 no (strict)
    % x=7: y=6>5 yes; x=8: y=7>5 yes; x=9: y=8>5 yes; x=10: y=9>8 yes
    % x=11-17: y=3,4,5,6,7,8,9 vs 8 -> only x=17(9>8)
    % x=18: y=10>8 yes; x=19: y=7>8 no; x=20: y=6>8 no
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    expectedX = [3 4 7 8 9 10 17 18];
    expectedY = [6 7 6 7 8  9  9 10];
    assert(isequal(xV, expectedX), 'testUpperStep: xV mismatch, got [%s]', num2str(xV));
    assert(isequal(yV, expectedY), 'testUpperStep: yV mismatch');

    % testLowerStepFunction
    thX = [0 10];
    thY = [3  6];
    x = 1:15;
    y = [1 2 3 4 5 1 2 3 4 5  4 5 6 7 8];
    % Lower violations: y<3 for x<10 -> x=1(1),2(2)
    %                   y<6 for x>=10 -> x=11(4),12(5)
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'lower');
    assert(isequal(xV, [1 2 11 12]), 'testLowerStep: xV');
    assert(isequal(yV, [1 2 4 5]), 'testLowerStep: yV');

    % testNoViolations
    thX = [0 10];
    thY = [100 100];
    x = 1:10;
    y = ones(1, 10);
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    assert(isempty(xV), 'testNoViolations: xV');
    assert(isempty(yV), 'testNoViolations: yV');

    % testWithNaN: NaN data points never violate
    thX = [0 10];
    thY = [5 5];
    x = 1:5;
    y = [6 NaN 7 NaN 8];
    [xV, yV] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    assert(isequal(xV, [1 3 5]), 'testWithNaN: xV');
    assert(isequal(yV, [6 7 8]), 'testWithNaN: yV');

    % testScalarEquivalence: single-segment threshold = scalar behavior
    thX = [0];
    thY = [5];
    x = 1:10;
    y = [1 2 3 4 5 6 7 8 9 10];
    [xV1, yV1] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    [xV2, yV2] = compute_violations(x, y, 5, 'upper');
    assert(isequal(xV1, xV2), 'testScalarEquiv: xV');
    assert(isequal(yV1, yV2), 'testScalarEquiv: yV');

    % testDataOutsideThresholdRange: data before first threshold X
    thX = [5 10];
    thY = [3  6];
    x = 1:12;
    y = [4 4 4 4 4 4 4 4 4 4 7 7];
    % x=1-4 are before thX(1)=5, threshold is 3 (extrapolate left)
    % x=1-4: y=4>3 yes; x=5-9: y=4>3 yes; x=10-12: y vs 6
    % x=10: y=4>6 no; x=11: y=7>6 yes; x=12: y=7>6 yes
    [xV, ~] = compute_violations_dynamic(x, y, thX, thY, 'upper');
    assert(isequal(xV, [1 2 3 4 5 6 7 8 9 11 12]), 'testExtrapolate: xV');

    fprintf('    All 6 compute_violations_dynamic tests passed.\n');
end
```

**Step 2: Run test to verify it fails**

Run: `octave --eval "cd tests; addpath('..'); setup; test_compute_violations_dynamic"`
Expected: FAIL — `compute_violations_dynamic` not found.

**Step 3: Implement `compute_violations_dynamic.m`**

Create `libs/FastSense/private/compute_violations_dynamic.m`:

```matlab
function [xViol, yViol] = compute_violations_dynamic(x, y, thX, thY, direction)
%COMPUTE_VIOLATIONS_DYNAMIC Find violations against a time-varying threshold.
%   [xViol, yViol] = compute_violations_dynamic(x, y, thX, thY, direction)
%
%   Compares data (x,y) against a piecewise-constant (step function)
%   threshold defined by (thX, thY). The threshold value at any point
%   is the most recent thY value at or before that X coordinate.
%
%   Inputs:
%     x, y       — data coordinates
%     thX, thY   — threshold step-function knots (must be sorted)
%     direction  — 'upper' (violation when y > threshold)
%                   'lower' (violation when y < threshold)
%
%   See also compute_violations, FastSense.addThreshold.

    if isempty(x)
        xViol = zeros(1, 0);
        yViol = zeros(1, 0);
        return;
    end

    % Interpolate threshold at each data X (piecewise-constant, hold previous)
    % For points before first thX, use first threshold value
    thAtX = interp1(thX, thY, x, 'previous', 'extrap');

    % Handle points before the first threshold knot
    beforeFirst = x < thX(1);
    thAtX(beforeFirst) = thY(1);

    if strcmp(direction, 'upper')
        mask = y > thAtX;
    else
        mask = y < thAtX;
    end
    % NaN > x and NaN < x are both false in IEEE 754

    xViol = x(mask);
    yViol = y(mask);
end
```

**Step 4: Run test to verify it passes**

Run: `octave --eval "cd tests; addpath('..'); setup; test_compute_violations_dynamic"`
Expected: All 6 tests pass.

**Step 5: Commit**

```
feat: add compute_violations_dynamic for time-varying thresholds
```

---

### Task 3: Update threshold rendering for time-varying thresholds

**Files:**
- Modify: `libs/FastSense/FastSense.m:770-834` (render method — threshold section)

**Step 1: Modify threshold line rendering**

In the render method's threshold loop (line 770+), the threshold line rendering currently does:
```matlab
hT = line([xmin, xmax], [T.Value, T.Value], ...
```

Replace the threshold line creation block (lines 774-785) with logic that handles both scalar and time-varying:

```matlab
                % Threshold line
                if isempty(T.X)
                    % Scalar threshold — horizontal line
                    hT = line([xmin, xmax], [T.Value, T.Value], 'Parent', obj.hAxes, ...
                        'Color', T.Color, ...
                        'LineStyle', T.LineStyle, ...
                        'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');
                else
                    % Time-varying threshold — step-function line
                    hT = line(T.X, T.Y, 'Parent', obj.hAxes, ...
                        'Color', T.Color, ...
                        'LineStyle', T.LineStyle, ...
                        'LineWidth', 1.5, ...
                        'HandleVisibility', 'off');
                end
                udT.FastSense = struct( ...
                    'Type', 'threshold', ...
                    'Name', T.Label, ...
                    'LineIndex', [], ...
                    'ThresholdValue', T.Value);
                set(hT, 'UserData', udT);
                obj.Thresholds(t).hLine = hT;
```

**Step 2: Modify violation computation in render**

In the same loop, the violation markers section (line 787+) currently calls `compute_violations(xd, yd, T.Value, T.Direction)`. Add a branch for time-varying:

Replace the inner violation computation loop (the `for i = 1:nLines` block) with:

```matlab
                    for i = 1:nLines
                        if obj.Lines(i).IsStatic; continue; end
                        xd = get(obj.Lines(i).hLine, 'XData');
                        yd = get(obj.Lines(i).hLine, 'YData');
                        if isempty(T.X)
                            [vx, vy] = compute_violations(xd, yd, T.Value, T.Direction);
                        else
                            [vx, vy] = compute_violations_dynamic(xd, yd, T.X, T.Y, T.Direction);
                        end
                        if ~isempty(vx)
                            nViols = nViols + 1;
                            vxCell{nViols} = [vx, NaN];
                            vyCell{nViols} = [vy, NaN];
                        end
                    end
```

Note the `IsStatic` skip — threshold lines themselves are lines in the Lines array and should not be checked for violations against themselves.

For the pixel-density cull, time-varying thresholds need a representative value. Use the median of thY:

Replace the downsample_violations call to handle both cases:

```matlab
                        % Pixel-density cull: keep 1 violation per pixel column
                        xl = get(obj.hAxes, 'XLim');
                        pw = diff(xl) / obj.PixelWidth;
                        if isempty(T.X)
                            thVal = T.Value;
                        else
                            thVal = median(T.Y(~isnan(T.Y)));
                        end
                        [vxAll, vyAll] = downsample_violations(vxAll, vyAll, pw, thVal, xl(1));
```

**Step 3: Run tests**

Run: `octave --eval "cd tests; addpath('..'); setup; test_add_threshold; test_compute_violations; test_compute_violations_dynamic"`
Expected: All pass.

**Step 4: Commit**

```
feat: render time-varying thresholds and their violation markers
```

---

### Task 4: Update `updateViolations` for time-varying thresholds

**Files:**
- Modify: `libs/FastSense/FastSense.m:1977-2015` (updateViolations method)

**Step 1: Modify updateViolations inner loop**

In the `for i = 1:nLines` loop inside `updateViolations`, add the same scalar/time-varying branch:

Replace the violation computation (lines 1989-2000):

```matlab
                for i = 1:nLines
                    if obj.Lines(i).IsStatic; continue; end
                    xd = get(obj.Lines(i).hLine, 'XData');
                    yd = get(obj.Lines(i).hLine, 'YData');

                    if isempty(obj.Thresholds(t).X)
                        [vx, vy] = compute_violations(xd, yd, ...
                            obj.Thresholds(t).Value, obj.Thresholds(t).Direction);
                    else
                        [vx, vy] = compute_violations_dynamic(xd, yd, ...
                            obj.Thresholds(t).X, obj.Thresholds(t).Y, obj.Thresholds(t).Direction);
                    end
                    if ~isempty(vx)
                        nViols = nViols + 1;
                        vxCell{nViols} = [vx, NaN];
                        vyCell{nViols} = [vy, NaN];
                    end
                end
```

Also update the downsample_violations call to handle time-varying threshold value:

```matlab
                    % Remove trailing NaN, then pixel-density cull
                    xl = get(obj.hAxes, 'XLim');
                    pw = diff(xl) / obj.PixelWidth;
                    if isempty(obj.Thresholds(t).X)
                        thVal = obj.Thresholds(t).Value;
                    else
                        thVal = median(obj.Thresholds(t).Y(~isnan(obj.Thresholds(t).Y)));
                    end
                    [vxCulled, vyCulled] = downsample_violations(vxAll(1:end-1), vyAll(1:end-1), pw, thVal, xl(1));
```

**Step 2: Run all tests**

Run: `octave --eval "cd tests; addpath('..'); setup; test_add_threshold; test_compute_violations; test_compute_violations_dynamic; test_downsample_violations"`
Expected: All pass.

**Step 3: Commit**

```
feat: updateViolations supports time-varying thresholds
```

---

### Task 5: Rewrite `addSensor` to use unified `addThreshold` path

**Files:**
- Modify: `libs/FastSense/FastSense.m:344-393` (addSensor method)
- Test: `tests/test_add_sensor.m`

**Step 1: Update test expectations**

In `tests/test_add_sensor.m`, the test `testAddSensorWithThresholds` currently asserts:
```matlab
assert(numel(fp.Lines) >= 2, 'testWithThresholds: line + threshold line(s)');
```

Update it to check Thresholds instead of Lines:

```matlab
    % testAddSensorWithThresholds
    s = Sensor('pressure', 'Name', 'Pressure');
    s.X = 1:100;
    s.Y = [ones(1,50)*5, ones(1,50)*15];

    sc = StateChannel('machine');
    sc.X = [1 50]; sc.Y = [0 1];
    s.addStateChannel(sc);
    s.addThresholdRule(struct('machine', 1), 10, 'Direction', 'upper', 'Label', 'HH');
    s.resolve();

    fp = FastSense();
    fp.addSensor(s, 'ShowThresholds', true);
    assert(numel(fp.Lines) == 1, 'testWithThresholds: only data line');
    assert(numel(fp.Thresholds) >= 1, 'testWithThresholds: threshold(s) added');
    assert(fp.Thresholds(1).ShowViolations == true, 'testWithThresholds: ShowViolations on');
    assert(~isempty(fp.Thresholds(1).X), 'testWithThresholds: time-varying threshold');
```

Also update `testAddSensorNoThresholds`:

```matlab
    fp = FastSense();
    fp.addSensor(s, 'ShowThresholds', false);
    assert(numel(fp.Lines) == 1, 'testNoThresholds: only data line');
    assert(numel(fp.Thresholds) == 0, 'testNoThresholds: no thresholds');
```

Update fprintf count to 4 (same count, updated assertions).

**Step 2: Rewrite `addSensor`**

Replace the threshold section of `addSensor` (lines 369-392) with:

```matlab
            if showThresholds && ~isempty(sensor.ResolvedThresholds)
                resolvedTh = sensor.ResolvedThresholds;
                for i = 1:numel(resolvedTh)
                    th = resolvedTh(i);
                    thLabel = th.Label;
                    if isempty(thLabel)
                        thLabel = sprintf('Threshold %d', i);
                    end
                    [thColor, thStyle] = obj.resolveThresholdStyle(th.Color, th.LineStyle);
                    obj.addThreshold(th.X, th.Y, ...
                        'Direction', th.Direction, ...
                        'ShowViolations', true, ...
                        'Label', thLabel, ...
                        'Color', thColor, ...
                        'LineStyle', thStyle);
                end
            end
```

This removes:
- `obj.addLine(th.X, th.Y, ...)` for threshold lines
- `obj.addMarker(viol.X, viol.Y, ...)` for pre-computed violations
- `obj.addThresholdConnectors(resolvedTh)` for vertical connectors

**Step 3: Run test to verify it passes**

Run: `octave --eval "cd tests; addpath('..'); setup; test_add_sensor"`
Expected: All 4 tests pass.

**Step 4: Run full test suite**

Run: `octave --eval "cd tests; addpath('..'); setup; run_all_tests"`
Expected: No new failures (pre-existing ConsoleProgressBar/MEX failures are OK).

**Step 5: Commit**

```
feat: addSensor uses unified addThreshold path for time-varying thresholds
```

---

### Task 6: Clean up dead code

**Files:**
- Modify: `libs/FastSense/FastSense.m:1438-1477` (remove addThresholdConnectors)

**Step 1: Remove `addThresholdConnectors` method**

Delete the entire `addThresholdConnectors` method (lines 1438-1477). It is no longer called from anywhere — `addSensor` was its only caller and no longer uses it.

**Step 2: Run full test suite**

Run: `octave --eval "cd tests; addpath('..'); setup; run_all_tests"`
Expected: No new failures.

**Step 3: Commit**

```
refactor: remove unused addThresholdConnectors method
```
