# Sensor & Threshold Optimization Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace O(N*R) point-by-point resolve() with segment-based vectorization + SIMD MEX, achieving 100-1000x speedup on 10K-10M point datasets.

**Architecture:** State channels are piecewise-constant — evaluate conditions at segment boundaries (5-50 points), then vectorize threshold comparisons within active segments. MEX+SIMD for the hot violation scan, pure-MATLAB vectorized fallback.

**Tech Stack:** MATLAB/Octave, C with SIMD (NEON/AVX2/SSE2 via simd_utils.h), MEX API

---

### Task 1: Declarative Condition API — ThresholdRule

**Files:**
- Modify: `libs/SensorThreshold/ThresholdRule.m` (full rewrite of properties + constructor)
- Test: `tests/test_threshold_rule.m` (existing, update)

**Step 1: Write the failing test**

Create `tests/test_declarative_condition.m`:

```matlab
function test_declarative_condition()
    add_sensor_path();

    % testStructCondition — single field
    rule = ThresholdRule(struct('machine', 1), 50, 'Direction', 'upper');
    assert(isstruct(rule.Condition), 'struct condition stored');
    assert(rule.Condition.machine == 1, 'field value stored');
    assert(rule.Value == 50, 'threshold value');
    assert(strcmp(rule.Direction, 'upper'), 'direction');

    % testMultiFieldCondition — two state channels
    rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 80);
    assert(rule.Condition.machine == 1, 'multi: machine');
    assert(rule.Condition.vacuum == 2, 'multi: vacuum');

    % testMatchesState — single field match
    rule = ThresholdRule(struct('machine', 1), 50);
    assert(rule.matchesState(struct('machine', 1)) == true, 'match true');
    assert(rule.matchesState(struct('machine', 0)) == false, 'match false');
    assert(rule.matchesState(struct('machine', 1, 'zone', 2)) == true, 'match ignores extra');

    % testMatchesStateMultiField — AND logic
    rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 50);
    assert(rule.matchesState(struct('machine', 1, 'vacuum', 2)) == true, 'multi match');
    assert(rule.matchesState(struct('machine', 1, 'vacuum', 0)) == false, 'multi partial');
    assert(rule.matchesState(struct('machine', 0, 'vacuum', 2)) == false, 'multi other partial');

    % testEmptyCondition — always active (replaces @(st) true)
    rule = ThresholdRule(struct(), 50, 'Direction', 'upper');
    assert(rule.matchesState(struct('machine', 1)) == true, 'empty always true');
    assert(rule.matchesState(struct()) == true, 'empty vs empty');

    % testDefaults
    rule = ThresholdRule(struct('m', 1), 50);
    assert(strcmp(rule.Direction, 'upper'), 'default direction');
    assert(strcmp(rule.LineStyle, '--'), 'default line style');
    assert(isempty(rule.Label), 'default label');
    assert(isempty(rule.Color), 'default color');

    fprintf('    All 6 declarative_condition tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/test_declarative_condition.m')"`
Expected: FAIL — ThresholdRule constructor expects function_handle, not struct

**Step 3: Implement ThresholdRule with declarative conditions**

Rewrite `libs/SensorThreshold/ThresholdRule.m`:

```matlab
classdef ThresholdRule
    %THRESHOLDRULE Defines a condition-value pair for dynamic thresholds.
    %   rule = ThresholdRule(struct('machine', 1), 50)
    %   rule = ThresholdRule(struct('machine', 1, 'vacuum', 2), 50, 'Direction', 'upper')
    %
    %   The condition struct defines required state values (implicit AND).
    %   An empty struct() means the threshold is always active.

    properties (Constant)
        DIRECTIONS = {'upper', 'lower'}
    end

    properties
        Condition   % struct: field names = state channel keys, values = required state
        Value       % numeric: threshold value when condition is true
        Direction   % char: 'upper' or 'lower'
        Label       % char: display label
        Color       % 1x3 double: RGB color (empty = use theme default)
        LineStyle   % char: line style
    end

    methods
        function obj = ThresholdRule(condition, value, varargin)
            if ~isstruct(condition)
                error('ThresholdRule:invalidCondition', ...
                    'Condition must be a struct, got %s.', class(condition));
            end
            obj.Condition = condition;
            obj.Value = value;

            % Defaults
            obj.Direction = 'upper';
            obj.Label = '';
            obj.Color = [];
            obj.LineStyle = '--';

            for i = 1:2:numel(varargin)
                switch varargin{i}
                    case 'Direction'
                        d = varargin{i+1};
                        if ~ismember(d, ThresholdRule.DIRECTIONS)
                            error('ThresholdRule:invalidDirection', ...
                                'Direction must be ''upper'' or ''lower'', got ''%s''.', d);
                        end
                        obj.Direction = d;
                    case 'Label'
                        obj.Label = varargin{i+1};
                    case 'Color'
                        obj.Color = varargin{i+1};
                    case 'LineStyle'
                        obj.LineStyle = varargin{i+1};
                    otherwise
                        error('ThresholdRule:unknownOption', ...
                            'Unknown option ''%s''.', varargin{i});
                end
            end
        end

        function tf = matchesState(obj, st)
            %MATCHESSTATE Check if a state struct satisfies this rule's condition.
            %   All fields in Condition must match (implicit AND).
            %   Empty condition always returns true.
            fields = fieldnames(obj.Condition);
            tf = true;
            for f = 1:numel(fields)
                key = fields{f};
                if ~isfield(st, key) || st.(key) ~= obj.Condition.(key)
                    tf = false;
                    return;
                end
            end
        end
    end
end
```

**Step 4: Run test to verify it passes**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/test_declarative_condition.m')"`
Expected: PASS — All 6 tests

**Step 5: Commit**

```bash
git add libs/SensorThreshold/ThresholdRule.m tests/test_declarative_condition.m
git commit -m "feat: replace function-handle conditions with declarative struct API in ThresholdRule"
```

---

### Task 2: Update Sensor.addThresholdRule() for struct conditions

**Files:**
- Modify: `libs/SensorThreshold/Sensor.m:66-71` (addThresholdRule signature)
- Modify: `libs/SensorThreshold/Sensor.m:176-200` (getThresholdsAt — use matchesState)
- Modify: `libs/SensorThreshold/Sensor.m:203-218` (remove buildStateStruct)
- Test: `tests/test_sensor.m` (update to use struct conditions)

**Step 1: Update addThresholdRule to accept struct**

In `libs/SensorThreshold/Sensor.m`, change `addThresholdRule`:

```matlab
function addThresholdRule(obj, condition, value, varargin)
    %ADDTHRESHOLDRULE Add a dynamic threshold rule.
    %   s.addThresholdRule(struct('machine', 1), 50, 'Direction', 'upper')
    rule = ThresholdRule(condition, value, varargin{:});
    obj.ThresholdRules{end+1} = rule;
end
```

**Step 2: Update getThresholdsAt to use matchesState**

In `libs/SensorThreshold/Sensor.m`, replace `getThresholdsAt` (lines 176-200):

```matlab
function active = getThresholdsAt(obj, t)
    %GETTHRESHOLDSAT Evaluate all rules at a single time point.
    active = [];
    st = struct();
    for i = 1:numel(obj.StateChannels)
        sc = obj.StateChannels{i};
        st.(sc.Key) = sc.valueAt(t);
    end

    for r = 1:numel(obj.ThresholdRules)
        rule = obj.ThresholdRules{r};
        if rule.matchesState(st)
            entry.Value = rule.Value;
            entry.Direction = rule.Direction;
            entry.Label = rule.Label;
            if isempty(active)
                active = entry;
            else
                active(end+1) = entry;
            end
        end
    end
end
```

**Step 3: Remove buildStateStruct private method** (lines 203-218)

Delete the entire `methods (Access = private)` block with `buildStateStruct`.

**Step 4: Update test_sensor.m to use struct conditions**

Replace all `@(st) st.xxx == N` with `struct('xxx', N)` in `tests/test_sensor.m`:
- Line 35: `@(st) st.machine == 1` → `struct('machine', 1)`
- Line 42: `@(st) st.m == 1` → `struct('m', 1)`
- Line 43: `@(st) st.m == 2` → `struct('m', 2)`
- Line 44: `@(st) st.m == 1` → `struct('m', 1)`

**Step 5: Run tests**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/test_sensor.m')"`
Expected: PASS — All 5 tests

**Step 6: Commit**

```bash
git add libs/SensorThreshold/Sensor.m tests/test_sensor.m
git commit -m "feat: update Sensor.addThresholdRule and getThresholdsAt for struct conditions"
```

---

### Task 3: Rewrite Sensor.resolve() — segment-based algorithm

**Files:**
- Modify: `libs/SensorThreshold/Sensor.m:73-174` (complete resolve() rewrite)
- Test: `tests/test_sensor_resolve.m` (update to struct conditions)
- Create: `tests/test_resolve_segments.m` (new segment-specific tests)

**Step 1: Write the failing test for segments**

Create `tests/test_resolve_segments.m`:

```matlab
function test_resolve_segments()
    add_sensor_path();

    % testSegmentBoundaries — correct segment discovery
    s = Sensor('pressure');
    s.X = 1:100;
    s.Y = rand(1, 100) * 50 + 25;  % values between 25-75

    sc1 = StateChannel('machine');
    sc1.X = [1 30 60]; sc1.Y = [0 1 2];
    sc2 = StateChannel('vacuum');
    sc2.X = [1 20 50 80]; sc2.Y = [0 1 0 1];
    s.addStateChannel(sc1);
    s.addStateChannel(sc2);

    % Rule active when machine==1 AND vacuum==1 (segment [30,50) only)
    s.addThresholdRule(struct('machine', 1, 'vacuum', 1), 40, ...
        'Direction', 'upper', 'Label', 'Combo');

    s.resolve();

    % Violations should only exist in t=[30,49]
    viol = s.ResolvedViolations(1);
    if ~isempty(viol.X)
        assert(all(viol.X >= 30 & viol.X < 50), 'violations only in active segment');
        assert(all(viol.Y > 40), 'violations exceed threshold');
    end

    % testConditionBatching — rules with same condition share segments
    s = Sensor('temp');
    s.X = 1:100;
    s.Y = linspace(0, 100, 100);

    sc = StateChannel('mode');
    sc.X = [1 50]; sc.Y = [0 1];
    s.addStateChannel(sc);

    % Two rules, same condition — should be batched internally
    s.addThresholdRule(struct('mode', 1), 80, 'Direction', 'upper', 'Label', 'Warn');
    s.addThresholdRule(struct('mode', 1), 90, 'Direction', 'upper', 'Label', 'Alarm');

    s.resolve();

    assert(numel(s.ResolvedThresholds) == 2, 'batched: two thresholds');
    assert(numel(s.ResolvedViolations) == 2, 'batched: two violation sets');

    % Alarm violations must be subset of warn violations
    warnV = s.ResolvedViolations(1);
    alarmV = s.ResolvedViolations(2);
    assert(numel(alarmV.X) <= numel(warnV.X), 'alarm subset of warn');

    % testNoStateChannels — always-active threshold
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = [1 2 3 4 5 6 7 8 9 10];
    s.addThresholdRule(struct(), 5, 'Direction', 'upper', 'Label', 'Static');
    s.resolve();
    viol = s.ResolvedViolations(1);
    assert(isequal(viol.X, [6 7 8 9 10]), 'static: violation X');
    assert(isequal(viol.Y, [6 7 8 9 10]), 'static: violation Y');

    % testLowerDirection
    s = Sensor('pressure');
    s.X = 1:10;
    s.Y = [10 9 8 7 6 5 4 3 2 1];
    s.addThresholdRule(struct(), 5, 'Direction', 'lower', 'Label', 'LL');
    s.resolve();
    viol = s.ResolvedViolations(1);
    assert(isequal(viol.X, [6 7 8 9 10]), 'lower: violation X');
    assert(isequal(viol.Y, [4 3 2 1], 'err') || isequal(sort(viol.Y), [1 2 3 4]), 'lower: violation Y');

    fprintf('    All 4 resolve_segments tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Run test to verify it fails**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/test_resolve_segments.m')"`
Expected: FAIL — addThresholdRule still expects old API in resolve()

**Step 3: Rewrite resolve() in Sensor.m**

Replace `resolve()` method (lines 73-174) in `libs/SensorThreshold/Sensor.m`:

```matlab
function resolve(obj)
    %RESOLVE Precompute threshold time series, violations, and state bands.
    %   Segment-based algorithm: evaluates conditions at state-change
    %   boundaries, then vectorizes violation detection within active segments.

    nRules = numel(obj.ThresholdRules);

    if nRules == 0
        obj.ResolvedThresholds = [];
        obj.ResolvedViolations = [];
        obj.ResolvedStateBands = [];
        return;
    end

    sensorX = obj.X;
    sensorY = obj.Y;

    % --- Step 1: Find segment boundaries from state channels ---
    nChannels = numel(obj.StateChannels);

    if nChannels == 0
        % No state channels — single segment spanning all data
        segBounds = [sensorX(1), sensorX(end)];
    else
        % Merge all state-change timestamps
        allChanges = [];
        for i = 1:nChannels
            allChanges = [allChanges, obj.StateChannels{i}.X(:)'];
        end
        segBounds = unique(allChanges);

        % Ensure we cover the full sensor data range
        if segBounds(1) > sensorX(1)
            segBounds = [sensorX(1), segBounds];
        end
        if segBounds(end) < sensorX(end)
            segBounds = [segBounds, sensorX(end)];
        end
    end

    nSegs = numel(segBounds);

    % --- Step 2: Evaluate state at each segment boundary ---
    % Build state struct for each segment (use midpoint to avoid edge issues)
    segStates = cell(1, nSegs);
    for s = 1:nSegs
        st = struct();
        for i = 1:nChannels
            sc = obj.StateChannels{i};
            st.(sc.Key) = sc.valueAt(segBounds(s));
        end
        segStates{s} = st;
    end

    % --- Step 3: Group rules by condition for batching ---
    % Rules with identical condition structs share segment evaluation
    condKeys = cell(1, nRules);
    for r = 1:nRules
        condKeys{r} = conditionKey(obj.ThresholdRules{r}.Condition);
    end

    [uniqueKeys, ~, groupIdx] = unique(condKeys);
    nGroups = numel(uniqueKeys);

    % --- Step 4: For each condition group, find active segments once ---
    resolvedTh = [];
    resolvedViol = [];

    for g = 1:nGroups
        ruleIndices = find(groupIdx == g);
        refRule = obj.ThresholdRules{ruleIndices(1)};

        % Evaluate condition at each segment boundary
        segActive = false(1, nSegs);
        for s = 1:nSegs
            segActive(s) = refRule.matchesState(segStates{s});
        end

        % Find [lo, hi] index ranges in sensorX for each active segment
        activeSegs = find(segActive);
        nActive = numel(activeSegs);

        if nActive == 0
            % No active segments — all rules in this group have no violations
            for ri = 1:numel(ruleIndices)
                r = ruleIndices(ri);
                rule = obj.ThresholdRules{r};
                th = buildThresholdEntry(segBounds, NaN(1, nSegs), rule);
                viol = struct('X', [], 'Y', [], 'Direction', rule.Direction, 'Label', rule.Label);
                [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
            end
            continue;
        end

        segLo = zeros(1, nActive);
        segHi = zeros(1, nActive);
        for a = 1:nActive
            si = activeSegs(a);
            segStart = segBounds(si);
            if si < nSegs
                segEnd = segBounds(si + 1);
            else
                segEnd = sensorX(end);
            end

            segLo(a) = binary_search(sensorX, segStart, 'left');
            if si < nSegs
                % Exclusive end: last point strictly before next segment
                segHi(a) = binary_search(sensorX, segEnd, 'left') - 1;
                if segHi(a) < segLo(a)
                    segHi(a) = segLo(a);
                end
            else
                segHi(a) = numel(sensorX);
            end
        end

        % --- Step 5: Vectorized violation detection for each rule in group ---
        nBatchRules = numel(ruleIndices);
        thresholdValues = zeros(1, nBatchRules);
        directions = zeros(1, nBatchRules);
        for ri = 1:nBatchRules
            rule = obj.ThresholdRules{ruleIndices(ri)};
            thresholdValues(ri) = rule.Value;
            directions(ri) = strcmp(rule.Direction, 'upper');
        end

        % Try MEX path, fall back to vectorized MATLAB
        batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, ...
            thresholdValues, directions);

        % Build output for each rule in the group
        for ri = 1:nBatchRules
            r = ruleIndices(ri);
            rule = obj.ThresholdRules{r};

            % Build threshold time series (stepped line at boundaries)
            thY = NaN(1, nSegs);
            for s = 1:nSegs
                if segActive(s)
                    thY(s) = rule.Value;
                end
            end
            th = buildThresholdEntry(segBounds, thY, rule);

            % Build violation output
            vIdx = batchViolIdx{ri};
            viol.X = sensorX(vIdx);
            viol.Y = sensorY(vIdx);
            viol.Direction = rule.Direction;
            viol.Label = rule.Label;

            [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol);
        end
    end

    obj.ResolvedThresholds = resolvedTh;
    obj.ResolvedViolations = resolvedViol;
    obj.ResolvedStateBands = struct();
end
```

Add these as private static helpers at the bottom of `Sensor.m` (before the final `end`), as local functions won't work in a classdef. Instead, create a private helper file:

Create `libs/SensorThreshold/private/conditionKey.m`:

```matlab
function key = conditionKey(condStruct)
%CONDITIONKEY Generate a unique string key for a condition struct.
%   Used to group rules with identical conditions for batching.
    fields = sort(fieldnames(condStruct));
    parts = cell(1, numel(fields));
    for i = 1:numel(fields)
        parts{i} = sprintf('%s=%g', fields{i}, condStruct.(fields{i}));
    end
    if isempty(parts)
        key = '__empty__';
    else
        key = strjoin(parts, '&');
    end
end
```

Create `libs/SensorThreshold/private/buildThresholdEntry.m`:

```matlab
function th = buildThresholdEntry(segBounds, thY, rule)
%BUILDTHRESHOLDENTRY Build resolved threshold struct from segment data.
    th.X = segBounds;
    th.Y = thY;
    th.Direction = rule.Direction;
    th.Label = rule.Label;
    th.Color = rule.Color;
    th.LineStyle = rule.LineStyle;
    th.Value = rule.Value;
end
```

Create `libs/SensorThreshold/private/appendResults.m`:

```matlab
function [resolvedTh, resolvedViol] = appendResults(resolvedTh, resolvedViol, th, viol)
%APPENDRESULTS Append threshold and violation to result arrays.
    if isempty(resolvedTh)
        resolvedTh = th;
        resolvedViol = viol;
    else
        resolvedTh(end+1) = th;
        resolvedViol(end+1) = viol;
    end
end
```

**Step 4: Create pure-MATLAB vectorized violation detection**

Create `libs/SensorThreshold/private/compute_violations_batch.m`:

```matlab
function batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, thresholdValues, directions)
%COMPUTE_VIOLATIONS_BATCH Vectorized batch violation detection.
%   batchViolIdx = compute_violations_batch(sensorY, segLo, segHi, thresholdValues, directions)
%
%   For each threshold, finds indices where sensorY violates the threshold
%   within the given segment ranges [segLo(s), segHi(s)].
%
%   Uses MEX if available, otherwise pure-MATLAB vectorized fallback.
%
%   Inputs:
%     sensorY         — 1xN double, sensor Y data
%     segLo, segHi    — 1xS int, active segment index ranges (1-based)
%     thresholdValues  — 1xT double, threshold values
%     directions       — 1xT logical, true=upper (y > th), false=lower (y < th)
%
%   Output:
%     batchViolIdx    — 1xT cell, each cell contains violation indices

    persistent useMex;
    if isempty(useMex)
        useMex = (exist('compute_violations_mex', 'file') == 3);
    end

    if useMex
        batchViolIdx = compute_violations_mex(sensorY, segLo, segHi, ...
            thresholdValues, directions);
        return;
    end

    % Pure-MATLAB vectorized fallback
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolIdx = cell(1, nThresholds);

    % Pre-compute total capacity upper bound
    totalPoints = sum(segHi - segLo + 1);

    for t = 1:nThresholds
        thVal = thresholdValues(t);
        isUpper = directions(t);
        idx = zeros(1, totalPoints);
        count = 0;

        for s = 1:nSegs
            lo = segLo(s);
            hi = segHi(s);
            chunk = sensorY(lo:hi);

            if isUpper
                mask = chunk > thVal;
            else
                mask = chunk < thVal;
            end

            hits = find(mask) + lo - 1;
            nHits = numel(hits);
            idx(count+1:count+nHits) = hits;
            count = count + nHits;
        end

        batchViolIdx{t} = idx(1:count);
    end
end
```

**Step 5: Update test_sensor_resolve.m to struct conditions**

In `tests/test_sensor_resolve.m`, replace all function-handle conditions:
- Line 17: `@(st) st.machine == 1` → `struct('machine', 1)`
- Line 41: `@(st) st.mode == 0` → `struct('mode', 0)`
- Line 42: `@(st) st.mode == 1` → `struct('mode', 1)`
- Line 60: `@(st) st.machine == 1 && st.zone == 1` → `struct('machine', 1, 'zone', 1)`
- Line 78: `@(st) true` → `struct()`
- Line 91: `@(st) st.machine == 0` → `struct('machine', 0)`
- Line 92: `@(st) st.machine == 1` → `struct('machine', 1)`

**Step 6: Run all sensor tests**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/test_sensor_resolve.m'); run('tests/test_resolve_segments.m'); run('tests/test_declarative_condition.m')"`
Expected: PASS — All tests

**Step 7: Commit**

```bash
git add libs/SensorThreshold/Sensor.m libs/SensorThreshold/private/conditionKey.m \
    libs/SensorThreshold/private/buildThresholdEntry.m \
    libs/SensorThreshold/private/appendResults.m \
    libs/SensorThreshold/private/compute_violations_batch.m \
    tests/test_sensor_resolve.m tests/test_resolve_segments.m
git commit -m "feat: rewrite Sensor.resolve() with segment-based vectorized algorithm"
```

---

### Task 4: SIMD MEX — compute_violations_mex.c

**Files:**
- Create: `libs/FastPlot/private/mex_src/compute_violations_mex.c`
- Modify: `libs/FastPlot/build_mex.m:61-65` (add to mex_files list)
- Create: `tests/test_violations_mex_parity.m`

**Step 1: Write MEX parity test**

Create `tests/test_violations_mex_parity.m`:

```matlab
function test_violations_mex_parity()
    add_sensor_path();

    if exist('compute_violations_mex', 'file') ~= 3
        fprintf('    SKIPPED: compute_violations_mex not compiled.\n');
        return;
    end

    % Test 1: single threshold, upper direction
    rng(42);
    N = 100000;
    sensorY = randn(1, N) * 20 + 50;
    segLo = [1, 50001];
    segHi = [50000, N];
    thresholdValues = 60;
    directions = true;  % upper

    result_mex = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions);
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isequal(result_mex{1}, result_mat{1}), 'parity: single upper');

    % Test 2: multiple thresholds, mixed directions (batched)
    thresholdValues = [60, 40, 70, 30];
    directions = [true, false, true, false];  % upper, lower, upper, lower

    result_mex = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions);
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    for t = 1:4
        assert(isequal(result_mex{t}, result_mat{t}), sprintf('parity: batch threshold %d', t));
    end

    % Test 3: edge case — single element segments
    sensorY = [1 2 3 4 5];
    segLo = [1 3 5];
    segHi = [1 3 5];
    thresholdValues = 3;
    directions = true;

    result_mex = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions);
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isequal(result_mex{1}, result_mat{1}), 'parity: single element');

    % Test 4: no violations
    sensorY = ones(1, 100);
    segLo = [1];
    segHi = [100];
    thresholdValues = 5;
    directions = true;

    result_mex = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isempty(result_mex{1}), 'parity: no violations');

    % Test 5: large dataset (1M)
    N = 1000000;
    sensorY = randn(1, N) * 20 + 50;
    segLo = [1, 250001, 500001, 750001];
    segHi = [250000, 500000, 750000, N];
    thresholdValues = [60, 40];
    directions = [true, false];

    result_mex = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions);
    result_mat = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions);
    assert(isequal(result_mex{1}, result_mat{1}), 'parity: 1M upper');
    assert(isequal(result_mex{2}, result_mat{2}), 'parity: 1M lower');

    fprintf('    All 5 violations_mex_parity tests passed.\n');
end

function batchViolIdx = compute_violations_matlab(sensorY, segLo, segHi, thresholdValues, directions)
    %Reference MATLAB implementation for parity checking
    nThresholds = numel(thresholdValues);
    nSegs = numel(segLo);
    batchViolIdx = cell(1, nThresholds);
    totalPoints = sum(segHi - segLo + 1);
    for t = 1:nThresholds
        thVal = thresholdValues(t);
        isUpper = directions(t);
        idx = zeros(1, totalPoints);
        count = 0;
        for s = 1:nSegs
            lo = segLo(s);
            hi = segHi(s);
            chunk = sensorY(lo:hi);
            if isUpper
                mask = chunk > thVal;
            else
                mask = chunk < thVal;
            end
            hits = find(mask) + lo - 1;
            nHits = numel(hits);
            idx(count+1:count+nHits) = hits;
            count = count + nHits;
        end
        batchViolIdx{t} = idx(1:count);
    end
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
```

**Step 2: Write compute_violations_mex.c**

Create `libs/FastPlot/private/mex_src/compute_violations_mex.c`:

```c
/*
 * compute_violations_mex.c — SIMD-accelerated batch threshold violation detection.
 *
 * Usage from MATLAB:
 *   violIdx = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions)
 *
 *   sensorY:          1xN double — sensor Y data
 *   segLo, segHi:     1xS double — active segment ranges (1-based MATLAB indices)
 *   thresholdValues:   1xT double — threshold values to check
 *   directions:        1xT double — 1=upper (y>th), 0=lower (y<th)
 *
 *   Returns: 1xT cell array, each cell is a 1xK double of violation indices (1-based)
 *
 * SIMD strategy: for each segment, load SIMD_WIDTH doubles from sensorY,
 * compare against threshold, extract matching indices. Processes multiple
 * thresholds per segment pass when batched.
 */

#include "mex.h"
#include "simd_utils.h"
#include <string.h>
#include <stdlib.h>

/* Compare SIMD_WIDTH doubles against threshold, store matching 1-based indices */
static size_t scan_upper(const double *y, size_t lo, size_t hi,
                          double threshold, double *out) {
    size_t count = 0;
    size_t i = lo;

#if SIMD_WIDTH > 1
    simd_double vth = simd_set1(threshold);
    size_t simd_end = lo + ((hi - lo + 1) / SIMD_WIDTH) * SIMD_WIDTH;

    for (; i < simd_end; i += SIMD_WIDTH) {
        simd_double vy = simd_load(&y[i]);
        /* Compare: need y > threshold */
        /* Use max trick: if max(vy, vth) != vth, then vy > vth for that lane */
        double buf[SIMD_WIDTH];
        simd_store(buf, vy);
        size_t j;
        for (j = 0; j < SIMD_WIDTH; j++) {
            if (buf[j] > threshold) {
                out[count++] = (double)(i + j + 1); /* 1-based */
            }
        }
    }
#endif

    /* Scalar tail */
    for (; i <= hi; i++) {
        if (y[i] > threshold) {
            out[count++] = (double)(i + 1); /* 1-based */
        }
    }
    return count;
}

static size_t scan_lower(const double *y, size_t lo, size_t hi,
                          double threshold, double *out) {
    size_t count = 0;
    size_t i = lo;

#if SIMD_WIDTH > 1
    simd_double vth = simd_set1(threshold);
    size_t simd_end = lo + ((hi - lo + 1) / SIMD_WIDTH) * SIMD_WIDTH;

    for (; i < simd_end; i += SIMD_WIDTH) {
        simd_double vy = simd_load(&y[i]);
        double buf[SIMD_WIDTH];
        simd_store(buf, vy);
        size_t j;
        for (j = 0; j < SIMD_WIDTH; j++) {
            if (buf[j] < threshold) {
                out[count++] = (double)(i + j + 1); /* 1-based */
            }
        }
    }
#endif

    for (; i <= hi; i++) {
        if (y[i] < threshold) {
            out[count++] = (double)(i + 1);
        }
    }
    return count;
}

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[])
{
    if (nrhs != 5) {
        mexErrMsgIdAndTxt("FastPlot:compute_violations_mex:nrhs",
                          "Five inputs required: sensorY, segLo, segHi, thresholdValues, directions.");
    }

    const double *sensorY = mxGetPr(prhs[0]);
    const size_t N = mxGetNumberOfElements(prhs[0]);

    const double *segLoD = mxGetPr(prhs[1]);
    const double *segHiD = mxGetPr(prhs[2]);
    const size_t nSegs = mxGetNumberOfElements(prhs[1]);

    const double *thresholds = mxGetPr(prhs[3]);
    const double *dirs = mxGetPr(prhs[4]);
    const size_t nThresh = mxGetNumberOfElements(prhs[3]);

    /* Compute total points across all active segments (upper bound for output) */
    size_t totalPoints = 0;
    size_t s;
    for (s = 0; s < nSegs; s++) {
        size_t lo = (size_t)segLoD[s] - 1; /* convert to 0-based */
        size_t hi = (size_t)segHiD[s] - 1;
        if (hi >= lo) {
            totalPoints += (hi - lo + 1);
        }
    }

    /* Allocate output cell array */
    plhs[0] = mxCreateCellMatrix(1, nThresh);

    /* Temporary buffer for violation indices */
    double *buf = (double *)mxMalloc(totalPoints * sizeof(double));

    size_t t;
    for (t = 0; t < nThresh; t++) {
        double thVal = thresholds[t];
        int isUpper = (dirs[t] != 0.0);
        size_t count = 0;

        for (s = 0; s < nSegs; s++) {
            size_t lo = (size_t)segLoD[s] - 1;
            size_t hi = (size_t)segHiD[s] - 1;

            if (hi < lo || lo >= N) continue;
            if (hi >= N) hi = N - 1;

            size_t found;
            if (isUpper) {
                found = scan_upper(sensorY, lo, hi, thVal, buf + count);
            } else {
                found = scan_lower(sensorY, lo, hi, thVal, buf + count);
            }
            count += found;
        }

        /* Create output array for this threshold */
        mxArray *result = mxCreateDoubleMatrix(1, count, mxREAL);
        if (count > 0) {
            memcpy(mxGetPr(result), buf, count * sizeof(double));
        }
        mxSetCell(plhs[0], t, result);
    }

    mxFree(buf);
}
```

**Step 3: Add to build_mex.m**

In `libs/FastPlot/build_mex.m`, add to the `mex_files` cell array (line 61-65):

```matlab
mex_files = {
    'binary_search_mex.c',          'binary_search_mex'
    'minmax_core_mex.c',            'minmax_core_mex'
    'lttb_core_mex.c',              'lttb_core_mex'
    'compute_violations_mex.c',     'compute_violations_mex'
};
```

**Step 4: Compile MEX**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('setup.m'); build_mex()"`
Expected: All 4 MEX files compile, including compute_violations_mex

**Step 5: Run parity test**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/test_violations_mex_parity.m')"`
Expected: PASS — All 5 parity tests

**Step 6: Commit**

```bash
git add libs/FastPlot/private/mex_src/compute_violations_mex.c \
    libs/FastPlot/build_mex.m tests/test_violations_mex_parity.m
git commit -m "feat: add SIMD MEX for batch threshold violation detection"
```

---

### Task 5: Update examples to new struct condition API

**Files:**
- Modify: `examples/example_sensor_threshold.m` (3 rules)
- Modify: `examples/example_sensor_static.m` (2 rules)
- Modify: `examples/example_sensor_dashboard.m` (8 rules)
- Modify: `examples/example_sensor_multi_state.m` (5 rules)
- Modify: `examples/example_sensor_registry.m` (3 rules)

**Step 1: Update all examples**

Search-and-replace pattern in each file:
- `@(st) st.machine_state == N` → `struct('machine_state', N)`
- `@(st) st.machine == N` → `struct('machine', N)`
- `@(st) st.mode == N` → `struct('mode', N)`
- `@(st) true` → `struct()`
- `@(st) st.machine == N && strcmp(st.zone, 'B')` → `struct('machine', N, 'zone', 'B')` (note: this one uses string comparison — verify `matchesState` handles `strcmp` for cell/char values)

**Important:** The multi_state example at line 57 uses `strcmp(st.zone, 'B')` — this is a string state channel. The `matchesState` method uses `~=` which won't work for strings. We need to update `matchesState` to handle both numeric and string comparisons:

In `libs/SensorThreshold/ThresholdRule.m`, update `matchesState`:

```matlab
function tf = matchesState(obj, st)
    fields = fieldnames(obj.Condition);
    tf = true;
    for f = 1:numel(fields)
        key = fields{f};
        if ~isfield(st, key)
            tf = false;
            return;
        end
        condVal = obj.Condition.(key);
        stVal = st.(key);
        if ischar(condVal) || isstring(condVal)
            if ~strcmp(condVal, stVal)
                tf = false;
                return;
            end
        else
            if stVal ~= condVal
                tf = false;
                return;
            end
        end
    end
end
```

Also update `conditionKey.m` to handle string values:

```matlab
function key = conditionKey(condStruct)
    fields = sort(fieldnames(condStruct));
    parts = cell(1, numel(fields));
    for i = 1:numel(fields)
        val = condStruct.(fields{i});
        if ischar(val) || isstring(val)
            parts{i} = sprintf('%s=%s', fields{i}, val);
        else
            parts{i} = sprintf('%s=%g', fields{i}, val);
        end
    end
    if isempty(parts)
        key = '__empty__';
    else
        key = strjoin(parts, '&');
    end
end
```

**Step 2: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/run_all_tests.m')"`
Expected: All 31+ tests pass

**Step 3: Commit**

```bash
git add examples/example_sensor_*.m libs/SensorThreshold/ThresholdRule.m \
    libs/SensorThreshold/private/conditionKey.m
git commit -m "feat: migrate all examples and string support to declarative condition API"
```

---

### Task 6: Before/After Benchmark

**Files:**
- Create: `examples/benchmark_resolve.m`

**Step 1: Write benchmark script**

Create `examples/benchmark_resolve.m`:

```matlab
function benchmark_resolve()
%BENCHMARK_RESOLVE Compare old vs new Sensor.resolve() performance.
%   Runs at 10K, 100K, 1M, 10M points with 2 state channels, 4 rules.

    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));

    sizes = [1e4, 1e5, 1e6, 1e7];
    nRuns = 5;

    fprintf('\n=== Sensor.resolve() Benchmark ===\n\n');
    fprintf('%-12s  %-14s  %-14s  %-10s\n', ...
        'Data Size', 'resolve() [ms]', 'MEX avail?', 'Violations');
    fprintf('%s\n', repmat('-', 1, 60));

    hasMex = (exist('compute_violations_mex', 'file') == 3);
    mexStr = 'no';
    if hasMex; mexStr = 'yes'; end

    for si = 1:numel(sizes)
        N = sizes(si);

        % Create sensor with realistic data
        x = linspace(0, 1000, N);
        y = sin(x * 0.01) * 40 + 50 + randn(1, N) * 5;

        % Two state channels with transitions
        sc1 = StateChannel('machine');
        sc1.X = [0, 200, 400, 600, 800];
        sc1.Y = [0, 1, 2, 1, 0];

        sc2 = StateChannel('vacuum');
        sc2.X = [0, 300, 700];
        sc2.Y = [0, 1, 0];

        % 4 threshold rules (warn/alarm upper/lower)
        % Batched: first two share condition, second two share condition
        times = zeros(1, nRuns);
        nViol = 0;

        for run = 1:nRuns
            s = Sensor('bench');
            s.X = x;
            s.Y = y;
            s.addStateChannel(sc1);
            s.addStateChannel(sc2);

            s.addThresholdRule(struct('machine', 1), 80, ...
                'Direction', 'upper', 'Label', 'Warn Hi');
            s.addThresholdRule(struct('machine', 1), 20, ...
                'Direction', 'lower', 'Label', 'Warn Lo');
            s.addThresholdRule(struct('machine', 1, 'vacuum', 1), 90, ...
                'Direction', 'upper', 'Label', 'Alarm Hi');
            s.addThresholdRule(struct('machine', 1, 'vacuum', 1), 10, ...
                'Direction', 'lower', 'Label', 'Alarm Lo');

            tic;
            s.resolve();
            times(run) = toc * 1000;

            if run == 1
                for v = 1:numel(s.ResolvedViolations)
                    nViol = nViol + numel(s.ResolvedViolations(v).X);
                end
            end
        end

        medTime = median(times);

        if N >= 1e6
            sizeStr = sprintf('%.0fM', N / 1e6);
        elseif N >= 1e3
            sizeStr = sprintf('%.0fK', N / 1e3);
        else
            sizeStr = sprintf('%.0f', N);
        end

        fprintf('%-12s  %10.2f ms   %-14s  %d\n', ...
            sizeStr, medTime, mexStr, nViol);
    end

    fprintf('\nDone.\n');
end
```

**Step 2: Run benchmark**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('examples/benchmark_resolve.m')"`
Expected: Sub-second times for all data sizes (vs multi-second for old implementation)

**Step 3: Commit**

```bash
git add examples/benchmark_resolve.m
git commit -m "feat: add before/after benchmark for Sensor.resolve() optimization"
```

---

### Task 7: Run full test suite and verify

**Files:** None (verification only)

**Step 1: Compile MEX**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('setup.m'); build_mex()"`
Expected: All 4 MEX files compiled

**Step 2: Run all tests**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('tests/run_all_tests.m')"`
Expected: All tests pass (31 original + 3 new = 34 tests)

**Step 3: Run benchmark**

Run: `cd /Users/hannessuhr/FastPlot && octave --eval "run('examples/benchmark_resolve.m')"`
Expected: Performance table printed with sub-second resolve times

**Step 4: Final commit (if any fixups needed)**

```bash
git add -A && git commit -m "fix: test suite fixups for sensor threshold optimization"
```
