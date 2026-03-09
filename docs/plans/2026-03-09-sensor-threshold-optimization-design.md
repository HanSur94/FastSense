# Sensor & Threshold Computation Optimization

**Date:** 2026-03-09
**Status:** Approved

## Problem

`Sensor.resolve()` is O(N x R) function-handle calls where N = sensor points (up to 10M) and R = threshold rules. Each iteration allocates a struct and invokes a function handle. This is the worst possible pattern in MATLAB — millions of interpreted loop iterations with dynamic dispatch.

Additional issues:
- Dynamic array growth (`vX(end+1)`) causes repeated memory reallocation
- `buildStateStruct` creates a fresh struct for every single index
- Merged time grid includes all sensor timestamps unnecessarily

## Key Insight

State channels are **piecewise-constant** (zero-order hold). A state channel with M transitions creates M+1 segments. Within each segment, the condition is either true or false for ALL points. Evaluating per-point is wasteful — evaluate per-segment instead.

## Design

### 1. Declarative Condition API

Replace function handles with introspectable structs. All fields must match (implicit AND).

**Before:**
```matlab
s.addThresholdRule(@(st) st.machine == 1, 50, 'Direction', 'upper');
s.addThresholdRule(@(st) st.machine == 1 && st.phase == 3, 30, 'Direction', 'lower');
```

**After:**
```matlab
s.addThresholdRule(struct('machine', 1), 50, 'Direction', 'upper');
s.addThresholdRule(struct('machine', 1, 'phase', 3), 30, 'Direction', 'lower');
```

Multi-channel conditions combine naturally:
```matlab
% Machine in state 1 AND vacuum in state 2
s.addThresholdRule(struct('machine', 1, 'vacuum', 2), 50, 'Direction', 'upper');
```

Warn/alarm threshold stacking:
```matlab
s.addThresholdRule(struct('machine', 1), 80, 'Direction', 'upper', 'Label', 'Warn Hi');
s.addThresholdRule(struct('machine', 1), 20, 'Direction', 'lower', 'Label', 'Warn Lo');
s.addThresholdRule(struct('machine', 1), 100, 'Direction', 'upper', 'Label', 'Alarm Hi');
s.addThresholdRule(struct('machine', 1), 10, 'Direction', 'lower', 'Label', 'Alarm Lo');
```

**ThresholdRule changes:**
- `ConditionFn` (function_handle) -> `Condition` (struct)
- Add `matchesState(st)` method for struct-field comparison
- Remove function handle storage

### 2. Segment-based Resolution Algorithm

#### Step 1: Find segment boundaries
Collect all state-change timestamps from all state channels. Sort and unique them.

```
State channel "machine":  t=[0, 100, 500]  v=[1, 2, 1]
State channel "vacuum":   t=[0, 200, 400]  v=[0, 1, 0]

Merged boundaries: [0, 100, 200, 400, 500]
-> 5 segments (instead of 10M point-by-point evaluations)
```

#### Step 2: Evaluate condition once per segment
For each segment, look up state values at that segment's start and check if the condition struct matches. Result: a boolean per segment. O(S) where S = number of segments (typically 5-50).

#### Step 3: Build threshold time series
Output values at segment boundaries only — a stepped line with ~2*S points. No N-length array needed.

#### Step 4: Find violations (hot path)
For each active segment:
1. Binary search `sensorX` to find index range `[lo, hi]`
2. Vectorized compare: `sensorY(lo:hi) > threshold` (or `<`)
3. Collect violation indices

#### Condition batching
Rules sharing the same condition struct are **batched**:
1. Compute active segments once for the shared condition
2. Binary search for `[lo, hi]` ranges once
3. Run SIMD comparison for all threshold values on the same data range in a single pass

### 3. MEX Implementation with SIMD

Following existing codebase patterns (`binary_search_mex.c`, `minmax_core_mex.c`, `simd_utils.h`).

#### MEX function signature
```matlab
violIdx = compute_violations_mex(sensorY, segLo, segHi, thresholdValues, directions)
%                                                       [80, 20, 100, 10]  [1,0,1,0]
```

- `sensorY`: double* — full sensor Y data
- `segLo`, `segHi`: int arrays — index ranges for active segments (1-based)
- `thresholdValues`: double array — multiple thresholds to check simultaneously
- `directions`: logical array — 1=upper, 0=lower per threshold

Returns cell array of violation index arrays, one per threshold.

#### SIMD inner loop
For each active segment `[lo, hi]`:
1. Load 4 doubles (AVX2) or 2 doubles (NEON) from `sensorY`
2. Compare against threshold using `_mm256_cmp_pd` / `vcgtq_f64`
3. Extract mask bits, store matching indices into output buffer
4. Scalar cleanup for tail elements

#### Architecture dispatch
Reuses existing `simd_utils.h` abstraction:
- **arm64**: NEON `float64x2_t` (2-wide)
- **x86_64 AVX2**: `__m256d` (4-wide)
- **x86_64 SSE2**: `__m128d` (2-wide, fallback)

### 4. Pure-MATLAB Fallback

Same segment-based algorithm, vectorized with `find()`:
```matlab
function violIdx = compute_violations_vec(sensorY, loHi, thresholdValue, isUpper)
    violIdx = zeros(1, numel(sensorY));  % pre-allocate upper bound
    count = 0;
    for s = 1:size(loHi, 1)
        chunk = sensorY(loHi(s,1):loHi(s,2));
        if isUpper
            idx = find(chunk > thresholdValue);
        else
            idx = find(chunk < thresholdValue);
        end
        violIdx(count+1:count+numel(idx)) = loHi(s,1) - 1 + idx;
        count = count + numel(idx);
    end
    violIdx = violIdx(1:count);
end
```

### 5. Benchmarking: Before vs After

A dedicated benchmark script compares old `resolve()` vs new at multiple data scales.

#### `benchmark_resolve.m`
- Data sizes: 10K, 100K, 1M, 10M points
- Configuration: 2 state channels, 4 threshold rules (warn/alarm upper/lower)
- Measurements per size:
  - Old `resolve()` time (current implementation)
  - New `resolve()` pure-MATLAB fallback time
  - New `resolve()` MEX+SIMD time
  - Speedup ratios (old/new-matlab, old/new-mex)
- Output: console table with times and speedup factors
- Runs each configuration 5 times, reports median

#### Expected performance targets
| Data Size | Old (estimated) | New MATLAB | New MEX+SIMD |
|-----------|----------------|------------|--------------|
| 10K       | ~50 ms         | < 1 ms     | < 0.5 ms     |
| 100K      | ~500 ms        | < 5 ms     | < 1 ms       |
| 1M        | ~5 s           | < 20 ms    | < 5 ms       |
| 10M       | ~50 s          | < 200 ms   | < 30 ms      |

## File Changes

| File | Change |
|------|--------|
| `libs/SensorThreshold/ThresholdRule.m` | `ConditionFn` -> `Condition` (struct), add `matchesState()` |
| `libs/SensorThreshold/Sensor.m` | Rewrite `resolve()` with segment algorithm + condition batching |
| `libs/FastPlot/private/compute_violations_mex.c` | New: SIMD multi-threshold violation scan |
| `libs/FastPlot/private/compute_violations_vec.m` | New: vectorized pure-MATLAB fallback |
| `libs/FastPlot/private/compute_violations.m` | Keep for standalone FastPlot thresholds (no sensor) |
| `libs/FastPlot/build_mex.m` | Add `compute_violations_mex` target |
| `examples/*.m` | Update to new struct condition API |
| `examples/benchmark_resolve.m` | New: before/after benchmark comparison |

## Tests

| Test | Purpose |
|------|---------|
| `test_resolve_segments` | Segment boundaries computed correctly from multiple state channels |
| `test_resolve_violations` | Violations match brute-force reference for upper/lower/batched |
| `test_resolve_empty` | Edge cases: no state channels, no rules, empty data |
| `test_resolve_mex_parity` | MEX output matches pure-MATLAB fallback exactly |
| `test_declarative_condition` | Struct-based condition API for single and multi-channel |
| `test_threshold_batching` | Rules sharing same condition batched correctly |
| `benchmark_resolve` | Timing comparison old vs new at 10K/100K/1M/10M |

## Complexity Summary

| Operation | Old | New |
|-----------|-----|-----|
| Condition evaluations | O(N x R) | O(S x R) where S << N |
| Struct allocations | O(N x R) | O(S x R) |
| Violation detection | O(N x R) interpreted loop | O(N) SIMD vectorized |
| Threshold time series | O(N) per rule | O(S) per rule |
| Memory (violations) | Dynamic growth | Pre-allocated |
