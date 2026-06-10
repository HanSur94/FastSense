---
quick_id: 260610-nwa
status: complete
date: 2026-06-10
---

# Summary: fast-math NaN fix + CI perf-gate policy

See PLAN.md for the full diagnosis. Both tasks landed:
- build_mex.m: -fno-finite-math-only after every -ffast-math (6 sites) + rationale comment.
- to_step_function_mex.c: scalar tails use mxIsNaN; FAST-MATH CONSTRAINT documented.
- Local ARM64 binary rebuilt (FastSense + SensorThreshold copies); CI refresh workflow
  regenerates the other platforms (triggers on build_mex.m / mex_src changes).
- TestTagPerfRegression.invokeBenchOrSkip_: timing gates report-only on CI
  (FASTSENSE_PERF_GATES=strict opts back in), hard locally.

Verified live R2025b: TestToStepFunctionMex 13/13 (was 9 FAIL), TestStateTag 18/18,
flat test_statetag green; gate policy verified in both CI and local modes.
Session gotcha hit again: the fastsense_private_proxy temp dir shadowed the rebuilt
binary — first verification ran the STALE copy; refreshed proxies before retesting
(see memory matlab-session-test-gotchas).
