# Phase 1008 — Deferred Items

Out-of-scope discoveries during execution. Do NOT fix in Phase 1008.

## Pre-existing Test Failure

- **Test:** `tests/test_to_step_function.m :: testAllNaN`
- **Symptom:** `error: testAllNaN: stepX empty` — all-NaN input produces empty stepX where an assertion expects non-empty.
- **Status:** Pre-existing at Phase 1008 baseline commit `a19a80b` (verified via `git stash`-based pre-edit re-run during Plan 03 execution).
- **Scope:** Not caused by any Plan 01/02/03 change — touches `libs/FastSense/private/to_step_function.m` (or its MEX sibling), unrelated to CompositeTag or TagRegistry wiring.
- **Owner:** Defer to a dedicated bug-fix plan; NOT Phase 1008's responsibility (MIGRATE-02 strangler-fig discipline — Phase 1008 must not touch unrelated files).
