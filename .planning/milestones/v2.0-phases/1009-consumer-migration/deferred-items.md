# Phase 1009 — Deferred Items

Items discovered during execution but out-of-scope for this phase.

## Pre-existing test failures (not regressions from 1009)

### test_to_step_function: testAllNaN
- **Discovered during:** Plan 1009-01 full suite run
- **Symptom:** `error: testAllNaN: stepX empty`
- **Verified pre-existing:** `git stash && test_to_step_function()` reproduces the failure
  without any 1009 changes.
- **Owner:** SensorThreshold MEX layer (`to_step_function_mex`); unrelated to Tag migration.
- **Action:** Not fixed by Phase 1009. File future ticket or address in a dedicated
  fix plan.
