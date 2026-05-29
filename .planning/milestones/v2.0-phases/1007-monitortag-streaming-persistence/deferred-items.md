# Deferred Items — Phase 1007

Items discovered during Phase 1007 execution that are OUT OF SCOPE
per Rule 4 (SCOPE BOUNDARY) of the execution workflow.

## Pre-existing failures (not caused by this phase)

- `test_to_step_function` — `testAllNaN: stepX empty` — pre-existing,
  reproduced on HEAD before any Plan 02 edits (verified via `git stash`).
- `test_toolbar` — `PostSet undefined` + `base_graphics_object::set:
  invalid graphics object` Octave graphics abort. Pre-existing Octave
  PostSet-listener incompatibility; headless CI only.

Both unrelated to MonitorTag / FastSenseDataStore scope. Left as-is.
