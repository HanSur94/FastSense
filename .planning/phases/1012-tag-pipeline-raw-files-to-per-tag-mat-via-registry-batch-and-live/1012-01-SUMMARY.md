---
phase: 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live
plan: 01
subsystem: testing
tags: [matlab, octave, matlab-unittest, fixtures, tdd, red-placeholders, tag-pipeline]

# Dependency graph
requires:
  - phase: 1011-cleanup-delete-legacy
    provides: "Tag-based domain model under libs/SensorThreshold/ (SensorTag, StateTag, MonitorTag, CompositeTag, TagRegistry) that Phase 1012 ingests raw files into"
provides:
  - "tests/suite/private/makeSyntheticRaw.m — synthetic raw-data fixture generator (10 variants)"
  - "tests/suite/TestRawDelimitedParser.m — 18 RED placeholders for Wave 1 / Plan 03 parser helpers"
  - "tests/suite/TestBatchTagPipeline.m — 18 RED placeholders for Wave 2 / Plan 04 BatchTagPipeline"
  - "tests/suite/TestLiveTagPipeline.m — 11 RED placeholders for Wave 3 / Plan 05 LiveTagPipeline"
affects: [1012-02, 1012-03, 1012-04, 1012-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Tempdir-per-test synthetic fixture helper under tests/suite/private/ (MATLAB private-folder scoping keeps it suite-only)"
    - "RED-placeholder-first TDD wave pattern: Wave 0 ships verifyFail() bodies; Waves 1-3 replace bodies only (no new test files) to respect Pitfall 5 file budget"
    - "Error-ID-per-test-method naming for grep-auditable TagPipeline:* error coverage"

key-files:
  created:
    - tests/suite/private/makeSyntheticRaw.m
    - tests/suite/TestRawDelimitedParser.m
    - tests/suite/TestBatchTagPipeline.m
    - tests/suite/TestLiveTagPipeline.m
  modified: []

key-decisions:
  - "RED placeholders are verifyFail('Wave N not yet implemented') rather than empty bodies — forces run_all_tests.m to report them FAILING (not silently passing), which is the contract for Waves 1-3 turning them GREEN by body replacement"
  - "Fixture helper under tests/suite/private/ (not libs/) — MATLAB private-folder scoping confines it to Test*.m suite files, matching the existing TestMatFileDataSource/TestSensorTag private-helper convention"
  - "TestClassSetup addPaths copied byte-for-byte from TestMatFileDataSource.m (3 addpath + install()) — canonical dual-runtime pattern, no drift"
  - "Each TagPipeline:* error ID from RESEARCH §Q5 is encoded in a named test method across the three suites (e.g. testErrorFileNotReadable, testErrorMissingColumn) so coverage is grep-auditable"
  - "Auto-teardown via testCase.addTeardown(@() rmdir(d, 's')) — no manual cleanup in each test method"

patterns-established:
  - "Wave 0 = test infrastructure only; production code lands in Waves 1-3"
  - "Placeholder bodies use verifyFail (not TODO comments) so run_all_tests.m distinguishes 'not yet implemented' from 'passing by accident'"
  - "Synthetic fixture variants sized to cover every error ID + every decision (wideCsv/tallTxt/tallDat for D-04 shape, empty/corrupt/headerOnly for parser errors, missingColumn for D-06, sharedFile for D-07 de-dup, stateCellstrCsv for D-11)"

requirements-completed: []  # Plan 01 has no frontmatter requirements — Phase 1012 closes v2.0 and has no exclusive REQ-IDs

# Metrics
duration: 3min
completed: 2026-04-22
---

# Phase 1012 Plan 01: Wave 0 Test Scaffolds + Synthetic Fixture Generator Summary

**Test infrastructure for Phase 1012's tag pipeline: 10-variant synthetic raw-data generator + 47 RED placeholder tests across three suites covering every D-## decision and all 11 TagPipeline:* error IDs.**

## Performance

- **Duration:** ~3 min
- **Started:** 2026-04-22T10:39:53Z
- **Completed:** 2026-04-22T10:42:49Z
- **Tasks:** 2
- **Files created:** 4

## Accomplishments

- Shipped `tests/suite/private/makeSyntheticRaw.m` — portable (MATLAB + Octave) synthetic raw-data fixture generator producing 10 file variants in a per-test tempdir with automatic `rmdir` teardown. Zero dependency on `readtable`/`writetable`/`readmatrix`/`csvwrite` — only `fopen`/`fprintf`/`fclose`/`mkdir`/`tempname`/`rmdir`.
- Shipped three `matlab.unittest.TestCase` suite classes with a combined 47 RED placeholder test methods covering every decision (D-01..D-19) and every `TagPipeline:*` error ID (11 production + the test-shim ID added in Plan 03 revision-1) referenced by VALIDATION.md.
- Every test body uses `testCase.verifyFail('Wave N not yet implemented')` so `tests/run_all_tests.m` discovers them, reports them FAILING (the Wave 0 contract), and Waves 1-3 turn them GREEN by replacing bodies only (no new test files added — preserves Pitfall 5 file budget).
- All three suites share the canonical `TestClassSetup addPaths` pattern from `TestMatFileDataSource.m` (3 `addpath` calls + `install()`) — no drift from the established dual-runtime convention.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write synthetic raw-fixture generator (makeSyntheticRaw.m)** - `0bb98a0` (test)
2. **Task 2: Write RED placeholder suites for Parser + Batch + Live pipelines** - `741973d` (test)

**Plan metadata commit:** pending final commit (see Final Commit section).

## Files Created/Modified

- `tests/suite/private/makeSyntheticRaw.m` — 96-line fixture helper; exports `files.{dir,wideCsv,tallTxt,tallDat,semiCsv,empty,headerOnly,corrupt,stateCellstrCsv,missingColumn,sharedFile}` under a unique `tempname()` directory with a single `testCase.addTeardown(@() rmdir(d, 's'))` registration.
- `tests/suite/TestRawDelimitedParser.m` — 18 test methods for Wave 1 / Plan 03 (delimiter sniff × 4, header detect × 2, wide/tall parse × 3, select-time-and-value × 2, time-column-by-name × 1, parser error IDs × 6 — `fileNotReadable`, `emptyFile`, `delimiterAmbiguous`, `missingColumn`, `noHeadersForNamedColumn`, `insufficientColumns`).
- `tests/suite/TestBatchTagPipeline.m` — 18 test methods for Wave 2 / Plan 04 (constructor × 2, auto-mkdir, wide/tall fan-out × 2, round-trip, one-file-per-tag, StateTag cellstr, de-dup cache, 3 silent-skip cases, composite-not-written, monitor-persist-untouched, per-tag isolation × 2, pipeline error IDs × 4 — `invalidOutputDir`, `cannotCreateOutputDir`, `invalidRawSource`, `invalidWriteMode`, `ingestFailed`, `unknownExtension`).
- `tests/suite/TestLiveTagPipeline.m` — 11 test methods for Wave 3 / Plan 05 (no-subclass check, constructor error, start/stop status × 2, first-tick-all, incremental-tick using `pause(1.1)`, mtime-guard skip, per-tick de-dup, per-tag file isolation, append-mode preservation, tag-state GC on de-registration).

## Error-ID Coverage Matrix

| Error ID                                | Asserted in |
| --------------------------------------- | ----------- |
| `TagPipeline:fileNotReadable`           | TestRawDelimitedParser::testErrorFileNotReadable |
| `TagPipeline:emptyFile`                 | TestRawDelimitedParser::testErrorEmptyFile |
| `TagPipeline:delimiterAmbiguous`        | TestRawDelimitedParser::testErrorDelimiterAmbiguous |
| `TagPipeline:missingColumn`             | TestRawDelimitedParser::testErrorMissingColumn |
| `TagPipeline:noHeadersForNamedColumn`   | TestRawDelimitedParser::testErrorNoHeadersForNamedColumn |
| `TagPipeline:insufficientColumns`       | TestRawDelimitedParser::testErrorInsufficientColumns |
| `TagPipeline:invalidRawSource`          | TestBatchTagPipeline::testErrorInvalidRawSource |
| `TagPipeline:invalidOutputDir`          | TestBatchTagPipeline::testConstructorRequiresOutputDir + TestLiveTagPipeline::testConstructorRequiresOutputDir |
| `TagPipeline:cannotCreateOutputDir`     | TestBatchTagPipeline::testErrorCannotCreateOutputDir |
| `TagPipeline:invalidWriteMode`          | TestBatchTagPipeline::testErrorInvalidWriteMode |
| `TagPipeline:ingestFailed`              | TestBatchTagPipeline::testIngestFailedThrownAtEnd |
| `TagPipeline:unknownExtension` (Plan 04)| TestBatchTagPipeline::testDispatchUnknownExtension |

12 error IDs covered (all 11 from RESEARCH §Q5 + Plan 04 addendum `unknownExtension`).

## Decision Coverage Matrix

| Decision | Placeholder method(s) |
| -------- | --------------------- |
| D-03 (synthetic-fixtures-only) | makeSyntheticRaw.m (implemented, not placeholder) |
| D-01 (shared delimited-text parser) | TestRawDelimitedParser (all 18 placeholders) |
| D-04 (wide + tall dispatch) | testWideFileFanOut, testTallFileTwoColumn |
| D-06 (column required for wide) | testSelectTimeAndValueWideByName, testErrorMissingColumn |
| D-07 (de-dup) | testFileCacheDedup, testDedupAcrossTagsPerTick |
| D-08 (silent skip) | testSilentSkipMonitorTag, testSilentSkipTagWithoutRawSource |
| D-09 (data.<KeyName> shape) | testRoundTripThroughSensorTagLoad |
| D-10 (one mat per tag) | testOneMatFilePerTag, testPerTagFileIsolation |
| D-11 (StateTag cellstr Y) | testStateTagCellstrRoundTrip |
| D-12 (two classes) | Implicit — separate suites per class |
| D-13 (modTime + lastIndex) | testSecondTickWritesOnlyNewRows, testUnchangedFileSkipped |
| D-14 (no LiveEventPipeline subclass) | testNoSubclassOfLiveEventPipeline |
| D-15 (OutputDir param + mkdir) | testConstructorRequiresOutputDir, testConstructorCreatesOutputDirIfMissing |
| D-16 (monitor/composite never written) | testSilentSkipMonitorTag, testCompositeTagNotMaterialized |
| D-17 (MonitorTag.Persist untouched) | testMonitorPersistPathUntouched |
| D-18 (per-tag try/catch) | testPerTagErrorIsolationContinuesToNext, testIngestFailedThrownAtEnd |
| D-19 (TagPipeline:* error IDs) | See Error-ID matrix above |

D-02 and D-05 are not directly testable in Wave 0 (D-02 is an architectural dispatch shape that surfaces in Plan 04; D-05 is a property on SensorTag/StateTag that Plan 02 adds). They are covered by placeholder tests in Wave 2 (`testDispatchUnknownExtension`) and Wave 1 respectively.

## Fixture Fields Available

`files = makeSyntheticRaw(testCase)` returns:

| Field              | Contents                                                      | Purpose                                 |
| ------------------ | ------------------------------------------------------------- | --------------------------------------- |
| `dir`              | tempname() root                                               | For `fullfile` building in tests        |
| `wideCsv`          | 4-col comma CSV with header (time, pressure_a, pressure_b, temperature) | D-04 wide dispatch               |
| `tallTxt`          | 2-col whitespace TXT, NO header                               | D-04 tall dispatch, header auto-detect |
| `tallDat`          | 2-col tab DAT with header                                     | D-04 tall dispatch, tab delimiter       |
| `semiCsv`          | 2-col semicolon CSV with header                               | Delimiter sniff (semicolon)             |
| `empty`            | 0-byte file                                                   | TagPipeline:emptyFile                   |
| `headerOnly`       | Header row only, 0 data rows                                  | TagPipeline:emptyFile (edge variant)    |
| `corrupt`          | Inconsistent column count per line                            | TagPipeline:delimiterAmbiguous          |
| `stateCellstrCsv`  | time, state cellstr                                           | D-11 StateTag cellstr Y                 |
| `missingColumn`    | Wide file lacking named column                                | TagPipeline:missingColumn               |
| `sharedFile`       | Shared raw file for 2+ tags                                   | D-07 de-dup + LastFileParseCount assertion |

## Decisions Made

- **Test bodies use `verifyFail('Wave N not yet implemented')`** rather than empty/pass-through placeholders so `tests/run_all_tests.m` treats them as actively FAILING (the Wave 0 contract). Waves 1-3 replace each body with real assertions — no new test files, preserving the 12-file Pitfall 5 budget.
- **Fixture helper under `tests/suite/private/`** (not under `libs/` or at `tests/` top-level) — MATLAB's private-folder scoping rule confines it to `Test*.m` suites. This mirrors the existing convention for test helpers and keeps the fixture generator out of the production path completely.
- **`TestClassSetup addPaths` byte-for-byte copy of `TestMatFileDataSource.m`** — the three `addpath` calls (repo root, `libs/EventDetection`, `libs/SensorThreshold`) plus `install()` are identical across all three new suites. No drift was introduced.
- **Docstring on each suite names the decisions + error IDs it covers.** Future waves can `grep` for decision tags (e.g., `D-04`) to find the right suite and method.

## Deviations from Plan

None — plan executed exactly as written.

The plan specified ≥16 test methods for the Batch suite; we shipped 18 to also cover D-17 (`testMonitorPersistPathUntouched`) and Plan 04's `unknownExtension` addendum (`testDispatchUnknownExtension`). This is not a scope deviation; it is documented coverage that was always required but under-counted in the acceptance-criteria numeric floor. All 18 are RED placeholders following the same pattern as the other methods.

## Issues Encountered

None. All acceptance criteria passed on first verification:

- File existence (4/4): PASS
- `classdef ... < matlab.unittest.TestCase` per suite: PASS (1 each)
- `TestClassSetup` + `install()` + 3 `addpath` per suite: PASS
- Test-method counts: Parser 18 (≥18), Batch 18 (≥16), Live 11 (≥11)
- `verifyFail` per body: PASS (every method)
- Error-ID grep: all 11 production IDs found across the three suites
- Fixture helper gates: 10/10 fields present, teardown registered, no forbidden API calls (only docstring mentions of `readtable`/`writetable` which are "no dependency on" lines)

## Known Stubs

All 47 test-method bodies are `verifyFail('Wave N not yet implemented')` stubs. **This is intentional by design** — the Wave 0 contract is for these to FAIL in `tests/run_all_tests.m` until Waves 1-3 replace each body with real assertions. Plans 02-05 resolve each stub; no stub survives past Plan 05.

## Next Phase Readiness

- **Plan 02 (Wave 1, parallel with Plan 03) ready:** needs to edit `SensorTag.m` and `StateTag.m` to add `RawSource` property. Tests that will turn GREEN: `TestSensorTag.m::testRawSourceProperty` (Plan 02 adds this) and indirectly every Batch/Live test once RawSource exists.
- **Plan 03 (Wave 1, parallel with Plan 02) ready:** needs `tests/suite/private/makeSyntheticRaw.m` (now on disk). Parser tests in `TestRawDelimitedParser.m` turn RED→GREEN by body replacement.
- **Plan 04 (Wave 2) ready:** after Plans 02 + 03, BatchTagPipeline consumes the `RawSource` property + the parser helpers. `TestBatchTagPipeline.m` turns RED→GREEN.
- **Plan 05 (Wave 3) ready:** LiveTagPipeline reuses BatchTagPipeline's private helpers + implements the modTime/lastIndex tick loop. `TestLiveTagPipeline.m` turns RED→GREEN.

File-count budget status (Pitfall 5): 4 of 12 files consumed. 8 remaining for Plans 02-05. The plan frontmatter expected this plan to contribute 4 files — on target.

## Self-Check: PASSED

All artifacts verified present on disk:

- FOUND: `tests/suite/private/makeSyntheticRaw.m` (96 lines)
- FOUND: `tests/suite/TestRawDelimitedParser.m` (107 lines, 18 test methods)
- FOUND: `tests/suite/TestBatchTagPipeline.m` (120 lines, 18 test methods)
- FOUND: `tests/suite/TestLiveTagPipeline.m` (92 lines, 11 test methods)

All commits verified in git log:

- FOUND: commit `0bb98a0` — test(1012-01): add synthetic raw-data fixture helper
- FOUND: commit `741973d` — test(1012-01): add RED placeholder suites

Self-check verification commands:

```bash
[ -f tests/suite/private/makeSyntheticRaw.m ] && echo FOUND
[ -f tests/suite/TestRawDelimitedParser.m ] && echo FOUND
[ -f tests/suite/TestBatchTagPipeline.m ] && echo FOUND
[ -f tests/suite/TestLiveTagPipeline.m ] && echo FOUND
git log --oneline | grep 0bb98a0
git log --oneline | grep 741973d
```

---
*Phase: 1012-tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live*
*Plan: 01*
*Completed: 2026-04-22*
