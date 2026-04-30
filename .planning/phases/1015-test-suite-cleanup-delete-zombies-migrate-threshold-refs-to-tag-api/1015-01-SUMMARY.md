---
phase: 1015-test-suite-cleanup-delete-zombies-migrate-threshold-refs-to-tag-api
plan: 01
status: complete
subsystem: testing
tags: [zombie-deletion, golden-tests, fixture-helper, ci-parity, miss-hit, monitortag]

# Dependency graph
requires:
  - phase: 1011
    provides: legacy SensorThreshold class deletions (DEAD-01) — TestEventDetectorTag is meaningful zombie only after EventDetector is gone
  - phase: 1009
    provides: MakePhase1009Fixtures canonical Tag-fixture pattern that MakeV21Fixtures mirrors

provides:
  - 5 zombie test files deleted (2 suite + 3 sidecar) — net 384 deleted lines
  - DO NOT REWRITE banner on both golden test files (Gate B contract structurally enforced)
  - tests/suite/makeV21Fixtures.m migration-helper classdef with makeThresholdMonitor static method
  - scripts/check_skip_list_parity.sh defensive skip-list parity gate (vacuous-pass when files absent)
  - .github/workflows/tests.yml lint job runs the parity gate after mh_metric

affects: [1015-02, 1015-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "MakeV21Fixtures: companion classdef factory (NOT extension of MakePhase1009Fixtures) — keeps Phase 1009 helper git-blame-stable"
    - "Defensive parity gate: vacuous-pass when either file or block absent so gate ships before harness lands"
    - "Per-file commit discipline: Task 4 split into 4a (script) + 4b (CI wire) so a failed step in either commit is bisect-localizable"

key-files:
  created:
    - tests/suite/makeV21Fixtures.m
    - scripts/check_skip_list_parity.sh
  modified:
    - tests/suite/TestGoldenIntegration.m (banner-only)
    - tests/test_golden_integration.m (banner-only)
    - .github/workflows/tests.yml (one new lint step)
  deleted:
    - tests/suite/TestEventConfig.m
    - tests/suite/TestEventDetectorTag.m
    - tests/test_event_config.m
    - tests/test_event_detector.m
    - tests/test_incremental_detector.m

key-decisions:
  - "Three of five originally-listed zombies (TestIncrementalDetector.m, TestEventDetector.m, TestCompositeThreshold.m on the suite/ side) were already deleted in Phase 1011 — verified absent via ls and skipped with no commit, per plan's explicit guidance"
  - "MakeV21Fixtures docstring scrubbed of `Threshold(`-shaped text so the Gate C grep `(^|[^.a-zA-Z_])(Threshold|...)\\(` returns 0 even on comments — Gate C is regex-strict and does not exempt comments"
  - "scripts/check_skip_list_parity.sh ships with vacuous-pass when smoke harness file is absent — wires CI guard before the smoke harness lands on this branch (Phase 1012 P02 work)"
  - "Per-file commit discipline split Task 4 into 4a (script) + 4b (CI wire) — keeps each commit ≤ 1 file in the non-deletion bucket"

patterns-established:
  - "Golden-test banner discipline: % DO NOT REWRITE — golden test, see PROJECT.md (em dash U+2014, literal)"
  - "Defensive CI gates: ship the gate first, exit 0 vacuously, hard-fail when both required inputs exist"

requirements-completed: [TEST-01, TEST-02, TEST-03, TEST-04, TEST-05, TEST-09, TEST-12, DIFF-02, DIFF-04]

# Metrics
duration: 3min
completed: 2026-04-30
---

# Phase 1015 Plan 01: Zombie Deletion + Golden Banner + Migration Helper + Skip-List Parity Gate Summary

**Deleted 5 zombie tests (2 suite + 3 sidecar = 384 lines), banner-locked both golden tests against rewrite, shipped MakeV21Fixtures.makeThresholdMonitor migration shim, and wired a defensive skip-list parity gate into CI lint — all in 5 commits with Gate B byte-clean.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-30T07:49:29Z
- **Completed:** 2026-04-30T07:52:22Z
- **Tasks:** 4 (Task 4 split into 4a + 4b per per-file commit discipline)
- **Commits:** 5
- **Files modified:** 8 (5 deletions + 2 created + 3 modified)

## Accomplishments

- **TEST-01..05:** Deleted 5 still-present zombie test files for classes already gone in earlier v2.1 phases. Net -384 lines from the test suite.
- **TEST-12 + DIFF-02:** Golden test banner inserted on line 1 of both golden test files. Single banner-only commit (2 files / 2 insertions). Gate B contract now structurally enforced for the rest of Phase 1015.
- **TEST-09:** MakeV21Fixtures.makeThresholdMonitor static helper landed at tests/suite/makeV21Fixtures.m — Plans 02/03 will call this for every legacy threshold-construct migration in still-live tests.
- **DIFF-04:** scripts/check_skip_list_parity.sh + CI lint-job wire — defensive parity gate live and exits 0 on this branch (vacuous; smoke harness not yet present), will fail loudly when the two skip lists drift apart.

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete 5 zombie test files (TEST-01..05)** — `370cc79` (chore)
2. **Task 2: Add DO NOT REWRITE banner to both golden test files (TEST-12, DIFF-02)** — `0387c5e` (docs)
3. **Task 3: Create MakeV21Fixtures.makeThresholdMonitor migration helper (TEST-09)** — `6a2b9aa` (test)
4a. **Task 4a: Create scripts/check_skip_list_parity.sh (DIFF-04)** — `0023399` (feat)
4b. **Task 4b: Wire skip-list parity gate into lint job (DIFF-04)** — `7759322` (ci)

## Files Created/Modified

### Created

- `tests/suite/makeV21Fixtures.m` — MakeV21Fixtures classdef with makeThresholdMonitor static method; companion to MakePhase1009Fixtures
- `scripts/check_skip_list_parity.sh` — bash gate comparing SKIP_LIST_BEGIN/END blocks in tests/test_examples_smoke.m vs examples/run_all_examples.m

### Modified

- `tests/suite/TestGoldenIntegration.m` — banner inserted as line 1 (only change in this plan)
- `tests/test_golden_integration.m` — banner inserted as line 1 (only change in this plan)
- `.github/workflows/tests.yml` — new "Skip-list parity gate (DIFF-04)" step in lint job, after mh_metric

### Deleted

- `tests/suite/TestEventConfig.m` (3 test methods)
- `tests/suite/TestEventDetectorTag.m` (5 test methods)
- `tests/test_event_config.m` (1 test method)
- `tests/test_event_detector.m` (1 test method)
- `tests/test_incremental_detector.m` (1 test method)

**Pre-deletion test-method counts** (for Plan 03's TEST-11 baseline-drop documentation):

```
tests/suite/TestEventConfig.m         : 3
tests/suite/TestEventDetectorTag.m    : 5
tests/test_event_config.m             : 1
tests/test_event_detector.m           : 1
tests/test_incremental_detector.m     : 1
Total removed                         : 11 test methods, 384 LOC
```

### Already Absent (no commit produced)

Three originally-listed zombies were already deleted in Phase 1011 — verified with `ls` and skipped per plan instructions:

- `tests/suite/TestIncrementalDetector.m`
- `tests/suite/TestEventDetector.m`
- `tests/suite/TestCompositeThreshold.m`

Plan 03's TEST-11 baseline-drop entry must reference Phase 1011 commit history for these three files' line counts; this plan removed only the 5 still-present zombies above.

## Decisions Made

- **Three already-absent zombies skipped cleanly.** TestIncrementalDetector.m, TestEventDetector.m, and TestCompositeThreshold.m on the suite side were already deleted in Phase 1011. Verified with `ls` per plan guidance, no commit produced.
- **MakeV21Fixtures docstring scrubbed of `Threshold(`-shaped text.** Initial draft used "legacy `Threshold(key, 'Direction', dir)` + `addCondition(struct(), value)`" in comments. The Gate C grep `(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(` is regex-strict and does not exempt comments — leading whitespace is `[^.a-zA-Z_]`. Comments rephrased to "legacy threshold-API" / "legacy threshold construct" / "legacy threshold value+direction" to keep the helper file Gate C-clean while preserving documentation intent.
- **Per-file commit discipline for Task 4.** Plan explicitly split into 4a (script) + 4b (CI wire), giving each commit ≤ 1 file in the non-deletion bucket and making either step bisect-localizable.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical Documentation Hygiene] Scrubbed `Threshold(`-shaped patterns from MakeV21Fixtures docstring**
- **Found during:** Task 3 (helper creation, acceptance-criteria check)
- **Issue:** Plan-supplied docstring contained literal text like `Threshold(key, 'Direction', dir)` and `Threshold(...)` — these are technically code-comment text but Gate C's grep regex `(^|[^.a-zA-Z_])(Threshold|...)\(` is regex-strict and matches comments. The acceptance criterion `! grep -E ... exits 0` would fail.
- **Fix:** Rephrased docstring lines to "legacy threshold-API", "legacy threshold construct", "legacy threshold value+direction", "legacy addCondition value operand", "legacy Direction NV pair". Documentation intent preserved; zero `Threshold(`-shaped text in the file.
- **Files modified:** tests/suite/makeV21Fixtures.m
- **Verification:** `! grep -E '(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(' tests/suite/makeV21Fixtures.m` exits 0 (Gate C clean).
- **Committed in:** 6a2b9aa (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 missing-critical hygiene)
**Impact on plan:** Auto-fix necessary for Gate C compliance. No scope change — same helper API, same content lines, same acceptance criteria all PASS. No additional commits.

## Issues Encountered

- mh_lint reports a low-severity `filename_primary_entity_name` check on tests/suite/makeV21Fixtures.m (camelCase filename + PascalCase classdef). Confirmed identical low-severity check on the canonical sibling tests/suite/makePhase1009Fixtures.m — accepted per established Phase 1009 pattern. mh_style is fully clean.

## Acceptance-Gate Verdicts

All gates verified pre-push:

- **Gate A (scope):** PASS — `git diff --name-only HEAD~5..HEAD` shows exactly the planned files (5 deletions + 2 created + 3 modified). No commit in the non-deletion bucket touches > 1 file.
- **Gate B (golden untouched across plan):** PASS — only `0387c5e` (Task 2) shows non-zero diff against `tests/**/*olden*` (2 files / 2 insertions, banner-only). Commits `370cc79`, `6a2b9aa`, `0023399`, `7759322` all show `git diff HEAD~..HEAD -- 'tests/**/*olden*' | wc -l == 0`.
- **Gate C (helper file Threshold-free):** PASS — `! grep -E '(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule)\(' tests/suite/makeV21Fixtures.m` exits 0.
- **Gate F (skip-list parity):** PASS (vacuous) — `bash scripts/check_skip_list_parity.sh` exits 0 with message "no skip-list blocks found in either file — parity vacuously holds". Drift detection was sanity-checked locally with synthetic mismatched blocks (exit code 1 + diff hunk on stdout).
- **CI wire:** PASS — `grep -c 'check_skip_list_parity.sh' .github/workflows/tests.yml == 1`, step nested inside the lint job after mh_metric.

Gate D (Octave smoke) and Gate E (MATLAB CI) are evaluated by the CI workflow on push and are out of this plan's scope (no test-runner edits).

## Next Phase Readiness

- **Plan 02 (still-live test migration) ready.** MakeV21Fixtures.makeThresholdMonitor available; Plan 02 tasks call it for every still-live `Threshold(`/`addCondition` site.
- **Banner-locked goldens for the rest of Phase 1015.** Any commit in Plan 02 / Plan 03 that touches `tests/**/*olden*` violates Gate B; verifier must catch.
- **Parity gate live but vacuous.** Once Phase 1012 P02 lands `tests/test_examples_smoke.m` on this branch, the gate flips from vacuous-pass to active-compare without any further code change.

## Self-Check: PASSED

- `tests/suite/makeV21Fixtures.m` — FOUND
- `scripts/check_skip_list_parity.sh` — FOUND, executable
- 5 zombie files — verified absent (`! test -f` exits 0 for each)
- Banner — line 1 of both golden files, em dash U+2014 (literal)
- Commits 370cc79, 0387c5e, 6a2b9aa, 0023399, 7759322 — all FOUND in git log
- Gate B byte-clean across all non-banner commits — VERIFIED

---
*Phase: 1015-test-suite-cleanup-delete-zombies-migrate-threshold-refs-to-tag-api*
*Plan: 01*
*Completed: 2026-04-30*
