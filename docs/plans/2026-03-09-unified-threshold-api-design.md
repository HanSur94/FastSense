# Unified Threshold API Design

**Goal:** Eliminate the dual rendering path for threshold violations by extending `addThreshold` to accept time-varying thresholds (X/Y arrays), then routing `addSensor` through it.

**Architecture:** Sensor/resolve handles domain logic (which threshold value at which time). FastSense handles rendering logic (what to show on screen now). Pre-computed violations are no longer fed to the renderer.

**Tech Stack:** MATLAB/Octave, existing FastSense private function pattern.

---

## Changes

### 1. `addThreshold` accepts scalar OR X/Y arrays

```matlab
% Scalar (existing, unchanged):
fp.addThreshold(4.5, 'Direction', 'upper', 'ShowViolations', true)

% Time-varying (new):
fp.addThreshold(thX, thY, 'Direction', 'upper', 'ShowViolations', true)
```

Thresholds struct gets new fields: `X` (empty for scalar), `Y` (empty for scalar). `Value` kept for scalar, empty for time-varying.

### 2. Threshold rendering

- Scalar: draw `[xmin, xmax], [value, value]` (current)
- Time-varying: draw step-function from X/Y arrays

### 3. `compute_violations_dynamic`

New private function for time-varying thresholds. Compares data Y against interpolated threshold at each data X using `interp1(..., 'previous')` for piecewise-constant step functions.

### 4. `updateViolations` dispatches

- Scalar: existing `compute_violations` (compare vs constant)
- Time-varying: `compute_violations_dynamic` (compare vs interpolated step function)
- Both feed into pixel-density culling + dirty flag

### 5. `addSensor` simplified

Replaces `addLine` + `addMarker` with single `addThreshold(thX, thY, ...)` call per threshold. Removes `addThresholdConnectors` call (step function transitions are native now).

### 6. Unchanged

- Sensor/resolve pipeline
- ResolvedViolations (still computed, for export/inspection)
- Scalar addThreshold API (backward compatible)
