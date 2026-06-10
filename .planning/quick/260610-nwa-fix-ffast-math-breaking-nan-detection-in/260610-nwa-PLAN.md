---
quick_id: 260610-nwa
description: Fix -ffast-math breaking NaN detection in MEX kernels + make CI perf gates report-only
date: 2026-06-10
mode: quick-inline
---

# Quick Task 260610-nwa: fast-math NaN fix + CI perf-gate policy

## Task 1 — -ffast-math NaN bug (chip task_88d3d685)
Diagnosed 2026-06-09: all 9 TestToStepFunctionMex failures on macOS ARM64 MATLAB.
-ffast-math implies -ffinite-math-only -> compiler assumes no NaNs -> folds the
IEEE self-compare NaN test (v == v) to true, including clang's IR lowering of
NEON/AVX compare intrinsics. to_step_function_mex scanned all-NaN input as fully
active; NaN gaps in StateTag step functions rendered as solid steps.

Audit: only to_step_function_mex.c used the vulnerable idiom. build_store_mex.c
already used isnan() with a comment warning about this exact hazard;
violation_cull_mex.c uses mxIsNaN; minmax/lttb receive pre-segmented NaN-free data.

Fix: (a) build_mex.m appends -fno-finite-math-only after every -ffast-math
(6 sites; keeps reassociation/FMA wins); (b) scalar tails in the kernel use
mxIsNaN (opaque libmx call — survives any fast-math mode incl. MSVC /fp:fast);
(c) fast-math constraint documented in both files. Local mexmaca64 rebuilt
(both FastSense + SensorThreshold copies); refresh-mex-binaries workflow
triggers on this change and regenerates all platforms.

## Task 2 — CI perf gates report-only
All five TestTagPerfRegression benches gate on wall-clock measurements; shared
GitHub runners produced three false failures across two unrelated PRs on
2026-06-10. invokeBenchOrSkip_ now converts gate trips into assume-skips WITH
the measurement diagnostic when CI is set (unless FASTSENSE_PERF_GATES=strict).
Gates stay hard on developer machines.

## Verification
- to_step_function_mex([1 5 10],[NaN NaN NaN],20) -> empty (was 6 elements).
- TestToStepFunctionMex 13/13 (was 9 failures). TestStateTag 18/18; flat statetag green.
- Gate policy: CI=true simulated in-session -> 3 passed / 2 report-only skips / 0 failed;
  CI unset -> hard gates unchanged.
