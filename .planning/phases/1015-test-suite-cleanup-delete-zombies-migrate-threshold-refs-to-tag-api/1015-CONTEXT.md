# Phase 1015: Test suite cleanup - Context

**Gathered:** 2026-04-30
**Status:** Ready for planning
**Mode:** Auto-generated (smart discuss — infrastructure shortcut: cleanup/migrate phase, all gates technical, no user-facing behavior)

<domain>
## Phase Boundary

User running `tests/run_all_tests.m` on MATLAB R2020b sees a green suite with zero `Threshold(`-family constructor references in the codebase — every zombie test for deleted classes is gone, every still-live widget test is migrated to the Tag API, and the golden test + skip-list parity are now structurally enforced rather than comment-policed.

Depends on Phase 1013 (`TestEventDetectorTag.m` deletion is only meaningful once the production `EventDetector` class is removed — DEAD-01 satisfied).

</domain>

<decisions>
## Implementation Decisions

### Scope (from ROADMAP — locked, no grey areas)

**TEST-01..05 — Delete 5 zombie suites:**
- `tests/suite/TestEventConfig.m`
- `tests/suite/TestIncrementalDetector.m`
- `tests/suite/TestEventDetector.m`
- `tests/suite/TestEventDetectorTag.m`
- `tests/suite/TestCompositeThreshold.m` (if present — Phase 1011 may have already deleted)

**TEST-06..09 — Migrate `Threshold(` constructors in still-live tests:**
- Widget suites: `TestStatusWidget`, `TestGaugeWidget`, `TestIconCardWidget`, `TestMultiStatusWidget`, `TestChipBarWidget`
- Stray refs: `TestEventStore`, `TestLivePipeline`, `TestSensorDetailPlot`, `TestDashboardEngine`, `TestFastSenseWidget`, `TestLiveEventPipelineTag`, `TestIconCardWidgetTag`, `TestMultiStatusWidgetTag`
- Replacement: `MonitorTag` + `makePhase1009Fixtures` / `makeV21Fixtures.makeThresholdMonitor` helper

**TEST-10 — Grep gate:** `(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(` against `tests/` returns 0 hits. `fp.addThreshold(...)` (surviving FastSense plot-annotation API) excluded by leading `[^.a-zA-Z_]` lookbehind.

**TEST-11 — Documented baseline drop:** test-count delta from TEST-01..05 deletions logged in SUMMARY.

**TEST-12 + DIFF-02 — Golden test untouched:** Add `% DO NOT REWRITE — golden test, see PROJECT.md` banner ONCE to `tests/suite/TestGoldenIntegration.m` and `tests/test_golden_integration.m`. After that single commit, every later commit in this phase keeps these files byte-identical.

**DIFF-04 — Skip-list parity script:** Ship `scripts/check_skip_list_parity.sh` that exits non-zero if the skip-list blocks in `tests/test_examples_smoke.m` and `examples/run_all_examples.m` drift apart. Wire into CI.

### Plan Structure

Single plan expected (`1015-01`). May split to 2-3 if the per-file commit discipline (Gate A, Pitfall 4: no commit touches >3 test files unless pure deletion) pushes scope past single-plan budget. Net line budget: -500 to -1500.

### Verification — 6-Gate Exit (from ROADMAP PITFALLS.md)

- **Gate A (scope):** `git diff --name-only` ⊆ PLAN `affected_files`; per-file commits in migration bucket
- **Gate B (golden untouched):** `git diff HEAD~..HEAD -- tests/**/*olden*` = 0 lines except the single banner-addition commit listed in `affected_files`
- **Gate C (dead-code grep):** post-migration `grep -rE '(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(' tests/` → 0 hits
- **Gate D (Octave smoke):** `tests/test_examples_smoke.m` passes; `timerfindall()` empty between examples
- **Gate E (MATLAB CI):** `run_all_tests.m` green on MATLAB R2020b with documented test-count baseline drop
- **Gate F (skip-list parity):** `scripts/check_skip_list_parity.sh` returns 0 in CI

### Claude's Discretion

- Wave/parallelization choice within this phase
- Exact migration helper API surface (`makeV21Fixtures.makeThresholdMonitor` is the placeholder — final shape can be refined during planning, but all migrated tests use the same helper for parity)
- Per-file commit batching within the per-file-commit discipline rule

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `tests/suite/makePhase1009Fixtures.m` — Phase 1009 consumer-migration fixture factory; canonical pattern for Tag-bound test fixtures.
- `tests/run_all_tests.m` — auto-discovers via `TestSuite.fromFolder('tests/suite')` (no manual wiring).
- `tests/test_examples_smoke.m` — Octave-only smoke runner from Phase 1012, optional `'folder', <name>` NV-pair.
- `examples/run_all_examples.m` — auto mode is CI default (Phase 1012 P01).

### Established Patterns
- Test deletions are pure `git rm` — no test-runner edits required (auto-discovery).
- Tag-API migration uses `MonitorTag` + `EventStore` + `EventBinding` chain (Phase 1009 P01-04 precedent).
- Golden tests carry banner discipline; cross-checked by grep.
- CI parity scripts under `scripts/` shell out from `.github/workflows/tests.yml`.

### Integration Points
- `.github/workflows/tests.yml` — needs a new step invoking `scripts/check_skip_list_parity.sh`.
- `tests/run_all_tests.m` — no edits expected (auto-discovery).
- `tests/suite/` — bulk deletion + edits target.

</code_context>

<specifics>
## Specific Ideas

- Banner exact text for Gate B: `% DO NOT REWRITE — golden test, see PROJECT.md`
- Grep regex for Gate C must use `[^.a-zA-Z_]` leading lookbehind to spare `fp.addThreshold(...)` (surviving API).
- Test-count baseline drop: capture `nargout` of `TestSuite.fromFolder` or test-method count before/after; log in SUMMARY.

</specifics>

<deferred>
## Deferred Ideas

- Octave-flat sidecar tests for the migrated suites — TEST-DEFER-01 (Phase 1013 precedent: MATLAB-suite-only is acceptable for class-based tests).
- Wider test infrastructure overhaul (test-helper consolidation beyond the migration helper) — out of v2.1 scope.
- Examples 05-events rewrite — Phase 1016 owns it (MEXP/DEMO requirements).

</deferred>
