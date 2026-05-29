---
phase: 1012-migrate-examples-to-tag-api
plan: 01
subsystem: testing
tags: [octave, matlab, smoke-test, tag-registry, event-binding, ci, examples]

# Dependency graph
requires:
  - phase: 1011
    provides: Final Tag API surface (TagRegistry.clear, EventBinding.clear, SensorTag/StateTag/MonitorTag/CompositeTag constructors, fp.addTag)
  - phase: 1010
    provides: EventBinding singleton with clear() contract
  - phase: 1004
    provides: TagRegistry singleton with clear() contract
provides:
  - tests/test_examples_smoke.m — per-folder Octave smoke harness auto-discovered by tests/run_all_tests.m
  - examples/run_all_examples.m — recursive auto-default walker with shell-friendly exit code
  - Optional 'folder', <name> NV-pair that Wave 2 plans (02-09) use as their per-folder green gate
  - Byte-for-byte identical skip-list block in both files (drift-protected via awk-extracted diff)
affects: [1012-02-basics, 1012-03-sensors, 1012-04-sensor-threshold-rewrite, 1012-05-dashboard, 1012-06-widgets, 1012-07-events, 1012-08-webbridge, 1012-09-advanced, 1012-10-regression-gate]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Recursive dir(**/*.m) walk replaces hand-curated example lists"
    - "Per-example TagRegistry.clear() + EventBinding.clear() cleanup before every feval to prevent duplicate-key cross-contamination (Pitfall 1/10 discipline carried forward from Phase 1004+1010)"
    - "onCleanup-restored DefaultFigureVisible='off' for headless CI figure suppression"
    - "Block-identical skip-list pair between smoke test + runner, verified via awk-extracted diff"

key-files:
  created:
    - tests/test_examples_smoke.m
  modified:
    - examples/run_all_examples.m

key-decisions:
  - "Smoke test is Octave-only as-written (Option A from RESEARCH.md); MATLAB CI already runs examples directly via .github/workflows/examples.yml matlab-examples job, so no wrapping tests/suite/TestExamplesSmoke.m class needed"
  - "Optional 'folder', <name> NV-pair on test_examples_smoke makes Wave 2 per-folder verify blocks deterministic — each Wave 2 plan's <verify> block scopes to the folder it just migrated"
  - "MATLAB-only widget skip entries (chipbar, divider, iconcard, sparkline) chosen by cross-referencing .github/workflows/examples.yml lines 181-195 curated Octave widget list — anything NOT in that list goes to skip"
  - "Skip list block boundaries ('skip = {' / '};') must be byte-for-byte identical in both files — enforced via awk diff in Plan 01 acceptance gate to prevent silent drift across Wave 2 migrations"
  - "run_all_examples default mode changed from 'interactive' to 'auto' per CONTEXT.md — makes it shell-invokable as the CI entry point while preserving the 'interactive' branch for human walk-throughs"

patterns-established:
  - "Skip-list block parity pattern: awk '/^[[:space:]]*skip[[:space:]]*=[[:space:]]*\\{/,/^[[:space:]]*\\};/' extracts the block from both files; diff must produce 0 lines"
  - "Per-example singleton cleanup pattern: `try, TagRegistry.clear(); catch; end` + `try, EventBinding.clear(); catch; end` before every feval, silently swallowing catch so fresh Octave runs (where the classes aren't yet on path) don't abort the harness init"
  - "Shell-exit-on-failure pattern: `if failed > 0 && ~isInteractive, error('run_all_examples:failures', …)` raises a MATLAB error in auto mode only — interactive mode never exits non-zero so humans can keep exploring"

requirements-completed: []

# Metrics
duration: 8min
completed: 2026-04-17
---

# Phase 1012 Plan 01: Example smoke-test + run_all_examples infrastructure Summary

**Octave smoke harness + recursive auto-default run_all_examples.m, both with byte-identical skip-list blocks and TagRegistry/EventBinding singleton-cleanup discipline — deterministic per-folder verification gate that every Wave 2 migration plan consumes**

## Performance

- **Duration:** 8 min
- **Started:** 2026-04-17T13:48:04Z
- **Completed:** 2026-04-17T13:56:53Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `tests/test_examples_smoke.m` — Octave-compatible function-based smoke harness auto-discovered by the existing `tests/run_all_tests.m` `dir(test_*.m)` glob. Supports `test_examples_smoke('folder', '<name>')` to scope to a single folder, which is the idiom every Wave 2 plan's `<verify>` block will use.
- `examples/run_all_examples.m` — rewritten from scratch as a recursive `dir(exDir, '**', 'example_*.m')` walker with a default `auto` mode (raises `run_all_examples:failures` on any error so CI shells get exit=1) and an `interactive` branch preserved for human walk-throughs.
- Both files clear `TagRegistry` and `EventBinding` singletons before every example invocation — prevents the Pitfall 1/10 duplicate-key cascade that would otherwise corrupt any run where two examples register the same tag key.
- The literal `skip = { … };` block is byte-for-byte identical between the two files, verified via `awk`-extracted diff returning 0 lines. Makes Plan 06's acceptance criterion ("smoke test for 04-widgets exits 0 under Octave") deterministic because the Pitfall-8 + MATLAB-only widget skip sets match in both entry points.
- MATLAB-only widget enumeration (`example_widget_chipbar`, `example_widget_divider`, `example_widget_iconcard`, `example_widget_sparkline`) derived directly from cross-referencing `.github/workflows/examples.yml` lines 181-195's curated Octave widget list — anything NOT in that list is skipped here.

## Task Commits

Each task was committed atomically (per Phase 1012 Wave 1 pattern, with `--no-verify` because the orchestrator validates hooks once after all waves complete):

1. **Task 1: Create tests/test_examples_smoke.m** — `cd988ed` (test)
2. **Task 2: Rewrite examples/run_all_examples.m** — `50a322b` (refactor)

**Plan metadata:** _recorded at final commit below_

## Files Created/Modified

- `tests/test_examples_smoke.m` (NEW, 147 lines) — Octave-compatible function-based smoke harness with optional `'folder', <name>` NV-pair. Raises `ExampleSmoke:failures` with per-example `{name, identifier, message}` on any failure. Sets `DefaultFigureVisible='off'` under `onCleanup` for headless CI.
- `examples/run_all_examples.m` (REWRITE, 87 → 125 lines, 93% rewritten) — Recursive `dir(exDir, '**', 'example_*.m')` walker. `mode` defaults to `'auto'` (no interaction, closes figures between runs, raises `run_all_examples:failures` on any error). `'interactive'` mode preserves the prior ENTER-between-examples human walk-through. Returns `struct('passed', p, 'failed', f, 'skipped', s, 'total', t, 'failures', {cell})` for programmatic consumption.

## Decisions Made

- **Skip list block boundaries are load-bearing:** The literal `skip = { … };` block in both files is parity-checked byte-for-byte via `awk '/^[[:space:]]*skip[[:space:]]*=[[:space:]]*\{/,/^[[:space:]]*\};/'` diff. Plan 01's acceptance gate enforces zero-line diff. Silently drifting the two skip lists would break every Wave 2 `<verify>` block that relies on `test_examples_smoke('folder', X)` being semantically equivalent to `run_all_examples` over that folder.
- **Smoke test kept function-based (Option A from RESEARCH.md §598):** Wrapping as `tests/suite/TestExamplesSmoke.m` would require extra boilerplate for zero gain — MATLAB CI already runs examples directly via `matlab-examples` job in `.github/workflows/examples.yml`, so this file is specifically the Octave belt.
- **`DefaultFigureVisible` save/restore via `onCleanup`:** Makes the harness idempotent even when called repeatedly from the same Octave session (matters for `tests/run_all_tests.m` which calls every `test_*.m` in one process).
- **Catch-block SILENT on TagRegistry.clear()/EventBinding.clear():** First invocation in a fresh Octave session may predate `install()` fully wiring the paths. Silent `try, …; catch; end` prevents harness-init failure when classes aren't yet on path; by the second example they always are.

## Deviations from Plan

None — plan executed exactly as written. The RESEARCH.md skeleton (§597-678) and rewritten `run_all_examples` (§686-769) were adopted verbatim with the Plan 01 additions:

1. MATLAB-only widget entries (chipbar, divider, iconcard, sparkline) added to the skip list in both files per Plan 01 Task 1.5 cross-reference rule.
2. Optional `'folder', <name>` NV-pair added to `test_examples_smoke` per Plan 01 Task 1.2 — the RESEARCH skeleton does not show it; it is the key API that Wave 2 plans depend on.
3. Skip list formatted so the parity-check `awk` block extractor works cleanly (contiguous `skip = { ... };` with consistent indentation and literal delimiters).

## Issues Encountered

- **Known Octave segfault at end of large test runs** (`break_closure_cycles` during handle-class cleanup — already documented in `tests/run_all_tests.m` lines 123-131). Affects the full recursive walk but NOT the harness logic itself; our `exit(0)` catches the error path but Octave's final cleanup crashes after. Same symptom observed in Phase 1006 + Phase 1011 tests. Not a regression. Plan 02+ Wave 2 migrations should observe the same pattern.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Wave 2 plans (1012-02 through 1012-09) can now invoke `octave --no-gui --no-init-file --quiet --eval "cd('tests'); test_examples_smoke('folder', '<name>');"` as their per-folder green gate. The `'folder'` NV-pair is the key API contract; every Wave 2 `<verify>` block references it.
- Plan 10 (regression gate) can invoke the full smoke run + `examples/run_all_examples('auto')` for the phase-exit gate.
- Pre-existing Octave incompatibilities (datetime, categorical) in `01-basics` examples will surface as failures during Wave 2 migration — those are legacy issues orthogonal to the Tag API migration and should NOT block Plan 02's acceptance; Plan 02's `<verify>` scopes to its own migrated folder so foreign failures don't contaminate its green gate.

## Self-Check: PASSED

- [x] File `tests/test_examples_smoke.m` exists
- [x] File `examples/run_all_examples.m` exists
- [x] Commit `cd988ed` exists in git log
- [x] Commit `50a322b` exists in git log
- [x] `grep -c 'function test_examples_smoke' tests/test_examples_smoke.m` = 1
- [x] `grep -c 'function results = run_all_examples' examples/run_all_examples.m` = 1
- [x] `grep -c 'TagRegistry.clear()' tests/test_examples_smoke.m` = 1 (≥1)
- [x] `grep -c 'TagRegistry.clear()' examples/run_all_examples.m` = 1 (≥1)
- [x] `grep -c 'EventBinding.clear()' tests/test_examples_smoke.m` = 1 (≥1)
- [x] `grep -c 'EventBinding.clear()' examples/run_all_examples.m` = 1 (≥1)
- [x] `grep -c 'ExampleSmoke:failures' tests/test_examples_smoke.m` = 2 (≥1)
- [x] `grep -c 'run_all_examples:failures' examples/run_all_examples.m` = 2 (≥1)
- [x] `grep -c 'DefaultFigureVisible' tests/test_examples_smoke.m` = 4 (≥2)
- [x] MATLAB-only widget skip entries (chipbar/divider/iconcard/sparkline) present in both files
- [x] Pitfall-8 skip entries (demo_all, run_all_examples, *_live, example_event_viewer_from_file, example_webbridge) present in both files
- [x] Skip-list block parity diff produces 0 lines
- [x] `awk` extracted skip block = 15 lines in each file (≥5)
- [x] Both files parse cleanly on Octave 11.1.0 (`func2str(@run_all_examples)` returns the function name; smoke test parses and runs)

---
*Phase: 1012-migrate-examples-to-tag-api*
*Completed: 2026-04-17*
