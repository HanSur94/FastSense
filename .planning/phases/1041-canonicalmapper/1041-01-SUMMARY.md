---
phase: 1041-canonicalmapper
plan: 01
subsystem: testing
tags: [matlab, octave, unittest, nyquist, fleet, canonical-mapper]

requires: []
provides:
  - "tests/suite/TestCanonicalMapper.m — 30-method RED Nyquist suite (feedback harness for Plans 02-04)"
  - "libs/Fleet/ directory registered on the MATLAB path via install.m"
  - "Locked clustering/confidence/units algorithm contract (encoded in test assertions)"
affects: [1041-02, 1041-03, 1041-04]

tech-stack:
  added: []
  patterns:
    - "fileread+regexp grep gates (no shell system()), guarded by assumeTrue file-exists"
    - "assumeTrue(exist('OCTAVE_VERSION','builtin')==0) to skip MATLAB-only uifigure tests on Octave"

key-files:
  created:
    - tests/suite/TestCanonicalMapper.m
    - libs/Fleet/.gitkeep
  modified:
    - install.m
    - .planning/phases/1041-canonicalmapper/1041-VALIDATION.md

key-decisions:
  - "ATTACH_THRESHOLD_ = 0.15 for seed-then-assign clustering (resolves a real contradiction between testConfidenceLowThreshold and testUnmappedReturnsUnresolved that the plan's 'no floor' rule could not satisfy)"
  - "Per-member confidence scored against the cluster centroid (longest normalized key; tie -> lexicographically smallest)"
  - "Canonical unit = centroid member's unit; mismatch (case-insensitive, both non-empty) downgrades confidence one level and sets unitMismatch"
  - "Added a 30th test (testNormalizeCollapsesRepeats) to reconcile the docs' '30' count with the 29 enumerated names; synced VALIDATION.md map"

patterns-established:
  - "TestCanonicalMapper is the per-task feedback command (runtests('tests/suite/TestCanonicalMapper'), ~1.1 s) for all of Phase 1041"

requirements-completed: [CANON-01, CANON-02, CANON-03, CANON-04, CANON-05]

duration: ~20min
completed: 2026-06-03
---

# Phase 1041-01: Test Scaffold + Bootstrap Summary

**30-method RED Nyquist suite for CanonicalMapper plus `libs/Fleet` path registration — the feedback harness every Phase 1041 plan runs.**

## Performance

- **Duration:** ~20 min
- **Tasks:** 2
- **Files created:** 2 (TestCanonicalMapper.m, libs/Fleet/.gitkeep)
- **Files modified:** 2 (install.m, 1041-VALIDATION.md)

## Accomplishments
- `libs/Fleet/` registered on the MATLAB path (10 libs paths total; `install` makes the dir reachable, `exist(...)==7`).
- `tests/suite/TestCanonicalMapper.m`: 30 test methods with real assertion bodies covering CANON-01..05 + the two Octave-safety/no-toolbox grep gates.
- Suite runs RED end-to-end: 28 errored (CanonicalMapper not yet implemented), 2 grep gates filtered cleanly (assumeTrue file-exists guard). Harness is wired and stable at ~1.1 s.
- Locked the clustering/confidence/units algorithm contract in assertions so Plans 02-03 have an unambiguous GREEN target.

## Task Commits

1. **Task 1: Register libs/Fleet on path + create directory** — `98b3bb55` (chore)
2. **Task 2: Write TestCanonicalMapper.m (30 RED methods)** — `01bc8128` (test)

## Files Created/Modified
- `install.m` — added `addpath(fullfile(root,'libs','Fleet'))` after the libs/Help entry
- `libs/Fleet/.gitkeep` — tracks the new Fleet library directory
- `tests/suite/TestCanonicalMapper.m` — 30-method RED Nyquist suite
- `.planning/phases/1041-canonicalmapper/1041-VALIDATION.md` — added the testNormalizeCollapsesRepeats map row (count 29 → 30)

## Decisions Made
- **ATTACH_THRESHOLD_ = 0.15** (clustering): see deviation below.
- **Centroid-scored confidence**: each member's confidence is computed from its similarity to the cluster centroid (the centroid member scores 1.0 → HIGH). Required for `testConfidenceLowThreshold` (M03 lands LOW at sim 0.20 to the centroid).
- **Canonical unit = centroid member's unit**; a non-empty member unit that differs case-insensitively flags `unitMismatch` and downgrades confidence one level.

## Deviations from Plan

### 1. [Plan logic gap — corrected] Introduced `ATTACH_THRESHOLD_ = 0.15`
- **Found during:** Task 2 (designing the test assertions that define the algorithm)
- **Issue:** The plan/checker locked "non-seed members attach to the nearest centroid with **no floor**." That is internally inconsistent: `testConfidenceLowThreshold` requires `M03 'abzzzzzzzz'` (sim **0.20** to centroid `abcdefghij`) to **attach** as LOW, while `testUnmappedReturnsUnresolved` requires `M03 'pressure'` to stay **unmapped**. I hand-computed `editDistance('pressure','temp_motor')=9` → sim **0.10**. With truly no floor, 'pressure' would attach and the unmapped test would fail.
- **Fix:** A leftover attaches only if simToCentroid ≥ `ATTACH_THRESHOLD_ = 0.15` (0.05 margin on each side of 0.10/0.20). With zero seed clusters, nothing attaches (preserves `testSuggestNoMatches`).
- **Carried to:** Plan 1041-02 (must implement this exact rule).

### 2. [Doc reconciliation] Added a 30th test
- **Found during:** Task 2 acceptance check (`grep -c "function test"` returned 29).
- **Issue:** VALIDATION.md / Plan 01 say "30 test methods" but enumerate only 29 distinct names.
- **Fix:** Added `testNormalizeCollapsesRepeats` (CANON-01; exercises the `normalize_` collapse-repeats + trim rules, otherwise untested) and added the matching VALIDATION.md map row. Suite and map now both = 30.

---

**Total deviations:** 2 (1 algorithm-contract correction, 1 doc reconciliation). No scope creep — both keep the 30-method contract internally consistent.

## Issues Encountered
None beyond the deviations above. Static analysis (`check_matlab_code`) reports only 2 benign `info` diagnostics (unnecessary `%#ok<NASGU>` on onCleanup vars — kept for older-MATLAB/Octave cross-version safety).

## Next Phase Readiness
- Plan 1041-02 can now implement `libs/Fleet/CanonicalMapper.m` against a stable RED suite.
- Plan 02 MUST honor: similarity formula, HIGH/MEDIUM = 0.90/0.60, **ATTACH_THRESHOLD_ = 0.15**, centroid-scored confidence, centroid = longest-key/lex-smallest tie-break, unit downgrade rule. When `CanonicalMapper.m` exists the 2 grep gates stop skipping and begin enforcing Octave-safety.

---
*Phase: 1041-canonicalmapper*
*Completed: 2026-06-03*
