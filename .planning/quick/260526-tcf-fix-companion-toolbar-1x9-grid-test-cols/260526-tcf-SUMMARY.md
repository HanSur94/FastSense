---
phase: 260526-tcf
plan: 01
subsystem: FastSenseCompanion
tags: [tests, fastsensecompanion, toolbar, grid-layout, post-merge-followup]
type: quick
status: ready-for-verification
requirements:
  - TCF-01   # Wiki button assertion matches current 1x9 grid (col 7, not col 6)
  - TCF-02   # Settings gear assertion matches current 1x9 grid (col 9, not col 8)
dependency_graph:
  requires:
    - "FastSenseCompanion.m hToolbarGrid 1x9 layout (lines ~313-324) — Wiki at col 7, gear at col 9"
    - "Commit e2ded77 (post-second-merge cleanup) — established the 1x9 grid expectation in the parallel test file"
  provides:
    - "TestFastSenseCompanion testToolbarHasWikiButton + testToolbarGearMovedToColumn8 in agreement with source-of-truth toolbar layout"
  affects:
    - "tests/suite/TestFastSenseCompanion.m (two verifyEqual assertions and matching diagnostic messages)"
tech_stack:
  added: []
  patterns: []
key_files:
  created:
    - ".planning/quick/260526-tcf-fix-companion-toolbar-1x9-grid-test-cols/260526-tcf-SUMMARY.md"
  modified:
    - "tests/suite/TestFastSenseCompanion.m"
decisions:
  - "Column-value fix only — method name testToolbarGearMovedToColumn8 retained as-is per user choice. Rename to ...AtColumn9 deferred to a separate cleanup task to avoid touching grep-based references in this commit."
  - "Diagnostic-message strings updated alongside the assertion values so a future failure message stays coherent ('should sit in column 7' / 'should now sit in column 9') — these are part of the same verifyEqual call, not the method-name identifier the user asked to leave alone."
  - "Docstrings on the two methods (header comments at lines 1194 + 1207) intentionally left untouched — they contain 'column 6' / 'column 8' literals and will be cleaned up as part of the future method-name rename pass."
metrics:
  duration_minutes: ~5
  completed: "2026-05-26"
---

# Quick Task 260526-tcf: Fix Companion Toolbar 1x9 Grid Test Columns — Summary

One-liner: Two pre-existing column assertions in `TestFastSenseCompanion.m` were stale against the post-PR-#159 1x9 toolbar grid; updated them to expect Wiki at col 7 and Settings gear at col 9 (was 6 / 8), matching the production layout in `FastSenseCompanion.m`.

## What Was Built

A two-line correction to two test assertions:

| Test method                                | Asserted column (before) | Asserted column (after) | Source-of-truth |
| ------------------------------------------ | ------------------------ | ----------------------- | --------------- |
| `testToolbarHasWikiButton`                 | 6                        | **7**                   | `FastSenseCompanion.m:410` (`hWikiBtn_.Layout.Column = 7`) |
| `testToolbarGearMovedToColumn8`            | 8                        | **9**                   | `FastSenseCompanion.m:423` (`hSettingsBtn_.Layout.Column = 9`) |

Diagnostic-message text on the same `verifyEqual` calls was updated in lockstep so any future failure reports a coherent expected-column.

## Root Cause

Commit `e2ded77` ("post-second-merge cleanup — Wiki Browser lint + 1x9 toolbar tests") migrated `TestFastSenseCompanionPlantLogToolbar.m` to the new 1x9 layout established by PR #159, but missed the two matching assertions in `TestFastSenseCompanion.m`. The production source (`FastSenseCompanion.m` lines 313–324) defines the canonical 1x9 grid:

```
col 1 = Events     col 2 = Live        col 3 = Tags    col 4 = Plant Log…
col 5 = Tile       col 6 = Close all   col 7 = Wiki    col 8 = flex spacer (1x)
col 9 = Settings gear
```

The two tests still expected the pre-merge layout where Wiki sat at col 6 and gear at col 8.

## Final Commit Hash

- `e321ac7` — `fix(260526-tcf)`: update Wiki/gear column assertions to match 1x9 toolbar grid

## Files Changed

| File                                        | Change   | LOC delta | Purpose                                                                 |
| ------------------------------------------- | -------- | --------- | ----------------------------------------------------------------------- |
| `tests/suite/TestFastSenseCompanion.m`      | Modified | +4 / -4   | Update `verifyEqual` column values (6→7, 8→9) and matching diagnostic messages in `testToolbarHasWikiButton` (lines 1202–1203) and `testToolbarGearMovedToColumn8` (lines 1214–1215) |
| `.planning/quick/260526-tcf-…/SUMMARY.md`   | Created  | —         | This file                                                               |

Total: 1 production-test file touched, ~4 net LOC modified.

## Automated Test Results

⚠️ Verification deferred to the user's local MATLAB session — the `mcp__matlab__*` tools route to the user's MATLAB instance, which is not reachable from this remote sandbox.

Expected outcome when the user runs `mcp__matlab__run_matlab_test_file` on `tests/suite/TestFastSenseCompanion.m`:

- Before this commit: **2 failures** (`testToolbarHasWikiButton`, `testToolbarGearMovedToColumn8`) — both assert outdated columns.
- After this commit: **73/73 PASS** (or 74/74 if the parallel quick task `260526-r9x` PerTag commit landed on this branch first).

## User Verification Result

Pending — user will run the test file locally and confirm the two failures clear without regressing the other 71 cases.

## Design Decisions

1. **Column-value fix only.** Method name `testToolbarGearMovedToColumn8` retained — user explicitly chose the minimum-diff option to avoid grep-based reference churn. Rename to `testToolbarGearAtColumn9` is deferred to a separate cleanup commit.
2. **Diagnostic messages updated alongside the assertion values.** The trailing string arg to `verifyEqual` is part of the same call site as the column literal; leaving `'should sit in column 6'` while asserting `7` would print a misleading failure message. This is not a "method-name identifier" change so it falls inside the user's "two-line verbatim" instruction.
3. **Method-header docstrings (lines 1194, 1207) intentionally not touched.** They contain `column 6` / `column 8` literals that will become misleading, but cleaning them up belongs to the same future pass that renames the method — bundling them into this commit would muddy the "tests vs grep-references" boundary the user drew.

## Out-of-Scope Follow-ups (not done, deliberately)

- **Rename `testToolbarGearMovedToColumn8` → `testToolbarGearAtColumn9`** — explicit user deferral; should ship as a separate cleanup task that also touches the method header docstrings on both methods.
- **Audit `TestFastSenseCompanionPlantLogToolbar.m` and any other companion-toolbar test files** for analogous stale-column literals beyond what `e2ded77` and this commit have covered — the briefing implied these are the only two outliers, but a sweep with `grep -rE "column [0-9]" tests/suite/TestFastSenseCompanion*` would close the loop.

## Deviations from Plan

None. Briefing was followed verbatim; only the line numbers (1261/1273) differed from the current file state (actual: 1202/1214) — content matched exactly and the fix was unambiguous.

## Self-Check: PASSED

Verified all claimed artifacts:

- `tests/suite/TestFastSenseCompanion.m` lines 1202–1203 now expect column 7 — confirmed via `git diff`.
- `tests/suite/TestFastSenseCompanion.m` lines 1214–1215 now expect column 9 — confirmed via `git diff`.
- `libs/FastSenseCompanion/FastSenseCompanion.m` lines 410 and 423 are the source-of-truth — Layout.Column = 7 (Wiki) and Layout.Column = 9 (gear).
- Working tree shows exactly 4 line-pair changes inside a single file, matching the design-decision scope.
