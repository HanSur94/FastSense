# Phase 1006: Fix MATLAB test failures — Context

**Gathered:** 2026-04-16
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix the MATLAB test failures surfaced by CI quick task 260416-j6e when it enabled MATLAB tests on every push/PR and removed `continue-on-error: true`. The failures are NOT regressions caused by the CI changes — they are pre-existing drift that the CI improvements made honest.

**In scope:**
- Pin MATLAB CI runner to R2020b (decision below reshapes all other scope)
- Fix mksqlite MEX unavailability under MATLAB (~50 tests — MATLABFIX-A)
- Update stale test expectations (~21 tests — MATLABFIX-E)
- Fix headless image export via library change (4 tests — MATLABFIX-F)

**Out of scope after G=pin-R2020b decision:**
- MATLABFIX-B (testCase.TestData migration) — not needed under R2020b
- MATLABFIX-C (test-friend private access) — not enforced under R2020b
- MATLABFIX-D (R2025b API changes) — don't apply under R2020b

These three requirements stay deferred. If the project later decides to test under newer MATLAB releases, a follow-up phase resurrects them.

</domain>

<decisions>
## Implementation Decisions

### MATLAB Version (MATLABFIX-G)
- **D-01:** Pin `matlab-actions/setup-matlab@v3` to `release: R2020b` in all MATLAB CI jobs. Matches documented target in CLAUDE.md (MATLAB R2020b+). This eliminates categories B, C, and D from scope.
- **D-02:** CLAUDE.md doc stays as "R2020b+" — no change needed since the pin aligns CI with the claim.
- **D-03:** Do NOT add a matrix (R2020b + R2025b) at this stage. Can be added later via Phase 1005 or a dedicated phase if users report R2025b-specific issues.

### mksqlite Fix Strategy (MATLABFIX-A)
- **D-04:** Investigate-first approach. Plan 1 adds a diagnostic step to the CI (or runs locally under MATLAB R2020b) to determine:
  1. Does the `build-mex-matlab` artifact contain `libs/FastSense/mksqlite.mexa64`?
  2. If present, why doesn't MATLAB find it? (path, ABI, precedence)
  3. If absent, why isn't `install.m` / `build_mex.m` compiling it under MATLAB?
- **D-05:** Once the root cause is known, plan 2 applies the matching fix. Possible outcomes:
  - **(a)** Fix `install.m` / `build_mex.m` to ensure mksqlite compiles under MATLAB
  - **(b)** Rebuild the CI artifact with a correct cache key
  - **(c)** Add `skipUnless(exist('mksqlite') == 3)` guard mirroring TestMexEdgeCases (fallback if rebuild is blocked)
- **D-06:** Do NOT pre-decide between (a), (b), (c) before investigation — the diagnostic determines which applies.

### Stale Test Expectations (MATLABFIX-E)
- **D-07:** Fix test expectations, not library behavior, for renames/removals the library already completed (`kpi` → `number`, `KpiWidget` removed, warning ID `loadChildFailed` → `unknownChildKey`). The library is the source of truth; stale tests are the bug.
- **D-08:** For E10 (drag/resize grid-snap math, 6 tests), FIRST confirm whether this is a logic bug in `DashboardLayout`/`DashboardBuilder` OR test calibration drift. If a logic bug, fix the library and adjust tests. If calibration drift, update tests only. This sub-decision is deferred to the planner and whoever writes the plan task — add a dedicated diagnostic step.
- **D-09:** For `TestDashboardBugFixes/testKpiWidgetThemeOverrideMerge` (E3) — if `KpiWidget` is fully removed, DELETE the test rather than retargeting to NumberWidget. The test was testing a class that no longer exists; recreating it against a different class is scope creep into a new test.

### Headless Image Export (MATLABFIX-F)
- **D-10:** Fix at the library level: replace `print()` with `exportgraphics()` (MATLAB R2020a+) in `DashboardEngine.exportImage`. This benefits non-CI headless users too.
- **D-11:** Verify `exportgraphics()` output matches `print()` visually — image regression test using `imread` + pixel-tolerance comparison in the affected tests. If output is meaningfully different, document the format change and update any reference images.
- **D-12:** Do NOT add xvfb-run to the MATLAB CI step — the library fix makes it unnecessary. Keep xvfb on the Octave job where Octave's `print` still needs it.
- **D-13:** Do NOT introduce `TestTags = {'RequiresDisplay'}` filtering — the tests should run in CI after the library fix.

### Phase Scope / Boundary
- **D-14:** Keep Phase 1006 as ONE phase covering A + E + F (plus G infrastructure change). Estimated ~75 tests to fix, 3-5 plans total.
- **D-15:** Progress metric: failure count reduction from 137 → target per plan. Planner should create plans with measurable deltas, not vague "fix tests" tasks.

### Claude's Discretion
- Exact file structure of the plans (how to split A investigation + A fix + E cluster + F library)
- Whether E10 diagnostic becomes its own plan or a sub-task within the E plan
- Ordering within wave 1 (G pin can ship first as a standalone plan, or as plan 0 before A/E/F)
- Commit granularity within each plan

### Folded Todos
None — no pending todos matched this phase.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase-specific artifacts
- `.planning/debug/matlab-tests-failures-investigation.md` — **Authoritative categorization** of the 155 failure events. Lists every failing test by category with source-file locations, error excerpts, and fix suggestions. Planner should treat this as the work manifest for requirements A, B, C, D, E, F (B/C/D now out-of-scope per D-01).
- `.planning/phases/1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift/1006-REQUIREMENTS.md` — Per-requirement breakdown with investigation hints and fix options.

### Foundation / CI artifacts
- `.planning/quick/260416-j6e-enable-matlab-ci-on-every-push-pr-upgrad/260416-j6e-SUMMARY.md` — The change that surfaced these failures; source of the CI workflow structure these tests run under.
- `.planning/quick/260416-jfo-ci-quick-wins-bundle-concurrency-groups-/260416-jfo-SUMMARY.md` — Concurrency/timeouts/step-summaries; affects the test environment.
- `.planning/quick/260416-jnp-dry-refactor-extract-duplicated-octave-b/260416-jnp-SUMMARY.md` — The reusable `_build-mex-octave.yml` workflow (Octave side; MATLAB side parallel is in tests.yml).
- `.planning/quick/260416-k23-upgrade-octave-ci-containers-8-4-0-to-11/260416-k23-SUMMARY.md` — Octave 11.1.0 base; irrelevant to MATLAB directly but establishes the CI state.
- `.github/workflows/tests.yml` — Current MATLAB job definition (`setup-matlab@v3`, `build-mex-matlab`, `matlab` test job).
- `.github/workflows/_build-mex-octave.yml` — Reusable workflow pattern; planner may decide to extract a similar `_build-mex-matlab.yml` if needed but NOT required by this phase.

### Source files referenced by plans
- `install.m` — MEX compilation entry; needs verification for mksqlite under MATLAB.
- `libs/FastSense/build_mex.m` — Dual-runtime MEX build; already branches on `exist('OCTAVE_VERSION','builtin')`.
- `libs/FastSense/FastSenseDataStore.m` — uses `mksqlite`; check if it guards for absence.
- `libs/Dashboard/DashboardEngine.m` — `exportImage` method (phase-1004 feature); target for F library fix.
- `libs/Dashboard/DashboardLayout.m` — grid-snap math (relevant for E10 diagnostic).
- `libs/Dashboard/DashboardBuilder.m` — drag/resize handling (relevant for E10 diagnostic).
- `tests/suite/TestMksqliteEdgeCases.m`, `tests/suite/TestMksqliteTypes.m` — primary A targets.
- `tests/suite/TestDashboardBugFixes.m`, `tests/suite/TestDashboardEngine.m`, `tests/suite/TestDashboardBuilder.m`, `tests/suite/TestDashboardBuilderInteraction.m`, `tests/suite/TestDashboardDirtyFlag.m`, `tests/suite/TestCompositeThreshold.m`, `tests/suite/TestNotificationRule.m`, `tests/suite/TestNotificationService.m`, `tests/suite/TestEventTimelineWidget.m`, `tests/suite/TestDashboardToolbarImageExport.m` — E and F targets.
- `CLAUDE.md` — Project conventions (R2020b+ target, Octave 7+ supported).
- `tests/suite/TestMexEdgeCases.m` — Reference pattern for `skipUnless` guard used in MATLABFIX-A fallback.

### External references
- MATLAB `exportgraphics()` docs — R2020a+ replacement for `print()` with headless support. No URL; use MATLAB docs (`help exportgraphics`) or https://www.mathworks.com/help/matlab/ref/exportgraphics.html
- `matlab-actions/setup-matlab@v3` GitHub Action — `release:` input syntax for pinning versions. https://github.com/matlab-actions/setup-matlab

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`build_mex.m` dual-runtime branch:** Already handles MATLAB vs Octave via `exist('OCTAVE_VERSION','builtin')`. Any library fix must preserve this pattern.
- **`TestMexEdgeCases` skipUnless guard:** Template for the A-fallback path if mksqlite rebuild proves infeasible.
- **`_build-mex-octave.yml` reusable workflow:** Model for potential `_build-mex-matlab.yml` extraction (not required but available).
- **Octave job xvfb-run pattern:** Reference for how display-requiring code is handled; NOT being replicated on MATLAB side per D-10.

### Established Patterns
- **Octave-function tests vs MATLAB-class tests:** Two separate test trees. `tests/test_*.m` (Octave) and `tests/suite/Test*.m` (MATLAB). Phase 1006 touches only the MATLAB tree.
- **Dual-runtime guards:** Use `exist('OCTAVE_VERSION','builtin')` or equivalent. Never branch on assumed MATLAB version.
- **Test results file convention:** `/tmp/test-results.txt` contains `PASSED FAILED` — respected by the `Write test summary` CI step in tests.yml.

### Integration Points
- **CI:** `.github/workflows/tests.yml` MATLAB job steps — D-01 pin goes in the `Setup MATLAB` step's `with:` block (both build-mex-matlab and matlab jobs).
- **Library:** `DashboardEngine.exportImage` — D-10 library change; callers in tests use `d.exportImage(path, format)` API.
- **Tests:** No new test files created; existing test files edited.

</code_context>

<specifics>
## Specific Ideas

- **Diagnostic-first for mksqlite (D-04):** Don't guess the fix. The investigation doc says the artifact is 2.3MB and succeeds in download — that's a signal but not proof that mksqlite is inside. Add `ls libs/FastSense/mksqlite.*` as an actual CI diagnostic step in plan 1.
- **`exportgraphics` visual parity check (D-11):** Take one existing image export test, run it under R2020b locally with the library fix, compare against a `print()`-produced reference. If pixel-different, decide whether to accept the change or add a `'Resolution'` / `'BackgroundColor'` option to restore visual parity.
- **E10 is a real question mark:** The investigation noted normalized positions of 0.02 vs expected 0.06 — that's a 3x delta, not floating-point noise. Either grid config changed or `DashboardLayout.getColumnPosition` behavior changed. Plan task needs to bisect.

</specifics>

<deferred>
## Deferred Ideas

- **Newer MATLAB support (B/C/D reinstated):** If users report issues on R2025b, a future phase can resurrect MATLABFIX-B (TestData → properties), -C (test-friend access), and -D (R2025b API changes). Investigation doc already has the details.
- **Matrix CI (R2020b + R2025b):** Option G4 from the original REQUIREMENTS — runs both. Deferred pending real user demand.
- **`_build-mex-matlab.yml` reusable workflow:** Only 1 caller today (tests.yml). Extract if/when Phase 1005 adds more (macOS/Windows MATLAB jobs).
- **MATLAB Lint pre-existing failures:** 17 `spurious_row_comma` issues in example files. Out of scope for 1006 (it's lint, not tests) — separate quick task.
- **Codecov for Octave:** Deferred in quick task 260416-jfo pending research on Octave Cobertura exporter availability.
- **`TestNumberWidget/testComputeTrend`:** Not categorized (flat data produces non-flat trend) — might be genuine logic bug independent of MATLAB version. Flag for review in plan 1 / 2 as a potential extra fix.

### Reviewed Todos (not folded)
None — no todos matched this phase.

</deferred>

---

*Phase: 1006-fix-137-matlab-test-failures-surfaced-by-matlab-on-every-push-ci-enablement-7-categories-from-r2025b-drift*
*Context gathered: 2026-04-16*
