---
phase: 1012
slug: tag-pipeline-raw-files-to-per-tag-mat-via-registry-batch-and-live
status: plans_ready
nyquist_compliant: true
wave_0_complete: false
file_budget: 12
file_count_planned: 12
pitfall_5_margin: 0
pitfall_5_margin_rationale: "Revision-1 (Major-1 Option A) added a public test shim libs/SensorThreshold/readRawDelimitedForTest_.m to pierce MATLAB's private-folder scoping for TestRawDelimitedParser.m. This consumed the 12th slot of the Pitfall 5 budget, bringing planned file count to exactly 12 (zero margin). Rationale: the shim is the cleanest resolution of the private-folder scoping problem — it preserves the wave structure (no test rewiring through BatchTagPipeline), keeps the three private helpers private, and adds a grep-auditable production-isolation gate (BatchTagPipeline and LiveTagPipeline MUST NOT import the shim). Alternatives rejected: (B) reroute TestRawDelimitedParser.m assertions through BatchTagPipeline — shifts RED→GREEN from wave 1 to wave 2, blocks parallel parser verification; (C) move helpers out of private/ — loses the encapsulation the private-folder scoping provides to prevent ad-hoc external callers."
created: 2026-04-22
planned: 2026-04-22
last_updated: 2026-04-22
revision: 1
---

# Phase 1012 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> **Revision 1 (2026-04-22):** Updated for checker feedback — wave graph corrected (Plan 03 wave 2→1, Plan 04 3→2, Plan 05 4→3), file budget expanded 11→12 for Major-1 Option A test shim, LastFileParseCount observability added per Major-2, StateTag inline validator duplication committed per Major-3.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | MATLAB `matlab.unittest` suite (`tests/suite/Test*.m`) — auto-discovered by `tests/run_all_tests.m` (flat-function mirrors deferred per Pitfall 9 budget) |
| **Config file** | none — `tests/run_all_tests.m` discovers tests automatically |
| **Quick run command (per-suite)** | `matlab -batch "addpath('.'); install(); runtests('tests/suite/TestBatchTagPipeline.m')"` |
| **Full suite command** | `matlab -batch "addpath('.'); install(); run tests/run_all_tests.m"` |
| **Estimated runtime** | ~30 s (quick), ~4-6 min (full) |

Octave equivalents:
- Per-suite: `octave --no-gui --eval "install; runtests('tests/suite/TestBatchTagPipeline.m')"`
- Full:  `octave --no-gui --eval "install; run tests/run_all_tests.m"`

---

## Sampling Rate

- **After every task commit:** Run the quick targeted test matching the touched component (one `Test*.m` suite).
- **After every plan wave:** Run `tests/run_all_tests.m` on MATLAB AND Octave (parity gate is non-negotiable per CLAUDE.md).
- **Before `/gsd:verify-work`:** Full suite green on both runtimes.
- **Max feedback latency:** 30 s for quick, 6 min for full.

---

## Wave Graph (revision-1)

After Minor-1 fix, the wave graph is:

```
Wave 0: Plan 01 (test infra)
Wave 1: Plan 02 (RawSource on tags) AND Plan 03 (private helpers + test shim) — PARALLEL
Wave 2: Plan 04 (BatchTagPipeline)
Wave 3: Plan 05 (LiveTagPipeline)
```

Plan 03's wave was previously mis-labeled as 2 (same depends_on as Plan 02 which is wave 1 — now corrected). Plan 04 and 05 wave labels were chained off Plan 03's wave, so they shift from 3→2 and 4→3 respectively.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Decisions | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-----------|-----------|-------------------|-------------|--------|
| 1012-01-01 | 01 | 0 | D-03 | Fixture helper (unit) | `ls tests/suite/private/makeSyntheticRaw.m` | ❌ W0 | ⬜ pending |
| 1012-01-02 | 01 | 0 | D-03 (placeholders for D-01..D-19) | RED placeholder suites | `matlab -batch "runtests('tests/suite/TestRawDelimitedParser.m')"` | ❌ W0 | ⬜ pending |
| 1012-02-01 | 02 | 1 | D-05, D-06 | unit + error-ID | `matlab -batch "runtests('tests/suite/TestSensorTag.m')"` | ✅ EDIT | ⬜ pending |
| 1012-02-02 | 02 | 1 | D-05, D-11 | unit + error-ID | `matlab -batch "runtests('tests/suite/TestStateTag.m')"` | ✅ EDIT | ⬜ pending |
| 1012-03-01 | 03 | 1 | D-01, D-19 (3 IDs) | unit + error-ID | `matlab -batch "runtests('tests/suite/TestRawDelimitedParser.m')"` | ❌ NEW | ⬜ pending |
| 1012-03-02 | 03 | 1 | D-04, D-06, D-19 (3 IDs) | unit + error-ID | `matlab -batch "runtests('tests/suite/TestRawDelimitedParser.m')"` | ❌ NEW | ⬜ pending |
| 1012-03-03 | 03 | 1 | D-09, D-10, D-11, D-19 (1 ID) | integration (round-trip) | inline MATLAB: construct SensorTag, `writeTagMat_` then `SensorTag.load`, assert equality | ❌ NEW | ⬜ pending |
| 1012-03-04 | 03 | 1 | Major-1 / revision-1 (test-shim dispatch) | shim dispatch + TestRawDelimitedParser GREEN gate | `matlab -batch "runtests('tests/suite/TestRawDelimitedParser.m')"` | ❌ NEW (revision-1) | ⬜ pending |
| 1012-04-01 | 04 | 2 | D-02, D-07, D-08, D-09, D-10, D-12, D-15, D-16, D-17, D-18, D-19 (4 IDs) + Major-2 LastFileParseCount | integration + error-ID + observability property | `matlab -batch "runtests('tests/suite/TestBatchTagPipeline.m')"` | ❌ NEW | ⬜ pending |
| 1012-05-01 | 05 | 3 | D-07, D-12, D-13, D-14, D-15, D-16, D-18, D-19 + Major-2 LastFileParseCount | integration (mtime-bump) + error-ID + observability property | `matlab -batch "runtests('tests/suite/TestLiveTagPipeline.m')"` | ❌ NEW | ⬜ pending |

**New task in revision-1:** `1012-03-04` — the Major-1 Option A test shim (`libs/SensorThreshold/readRawDelimitedForTest_.m`). Verification gate: all 18 `TestRawDelimitedParser.m` tests turn GREEN.

**Decision coverage check (every D-## must appear ≥1 time):**

| Decision | Plans |
|----------|-------|
| D-01 (shared delimited-text parser) | 03 |
| D-02 (no public registerParser; hidden dispatch) | 03, 04 |
| D-03 (synthetic fixtures) | 01 |
| D-04 (wide + tall dispatch) | 03 |
| D-05 (RawSource on SensorTag + StateTag, not Tag) | 02 |
| D-06 (column required for wide) | 02, 03 |
| D-07 (de-dup file reads) | 04, 05 |
| D-08 (silent skip) | 04 |
| D-09 (data.&lt;KeyName&gt; shape) | 03, 04 |
| D-10 (one .mat per tag) | 03, 04 |
| D-11 (StateTag cellstr Y) | 02, 03 |
| D-12 (two classes, shared helper) | 04, 05 |
| D-13 (modTime + lastIndex) | 05 |
| D-14 (no LiveEventPipeline subclass) | 05 |
| D-15 (OutputDir param + mkdir) | 04, 05 |
| D-16 (Monitor/Composite never written) | 04, 05 |
| D-17 (MonitorTag.Persist path untouched) | 04 |
| D-18 (per-tag try/catch + end-of-run throw) | 04, 05 |
| D-19 (TagPipeline:* error IDs) | 02, 03, 04 |

✅ All 19 decisions appear in at least one plan.

**Error-ID coverage (every ID must have an assertable test):**

| Error ID | Emitted in Plan | Asserted in Suite |
|----------|-----------------|-------------------|
| `TagPipeline:fileNotReadable` | 03 | TestRawDelimitedParser.m::testErrorFileNotReadable |
| `TagPipeline:emptyFile` | 03 | TestRawDelimitedParser.m::testErrorEmptyFile |
| `TagPipeline:delimiterAmbiguous` | 03 | TestRawDelimitedParser.m::testErrorDelimiterAmbiguous |
| `TagPipeline:missingColumn` | 03 | TestRawDelimitedParser.m::testErrorMissingColumn |
| `TagPipeline:noHeadersForNamedColumn` | 03 | TestRawDelimitedParser.m::testErrorNoHeadersForNamedColumn |
| `TagPipeline:insufficientColumns` | 03 | TestRawDelimitedParser.m::testErrorInsufficientColumns |
| `TagPipeline:invalidRawSource` | 02 | TestSensorTag.m::testRawSourceProperty, TestBatchTagPipeline.m::testErrorInvalidRawSource |
| `TagPipeline:invalidOutputDir` | 04 | TestBatchTagPipeline.m::testConstructorRequiresOutputDir, TestLiveTagPipeline.m::testConstructorRequiresOutputDir |
| `TagPipeline:cannotCreateOutputDir` | 04 | TestBatchTagPipeline.m::testErrorCannotCreateOutputDir |
| `TagPipeline:invalidWriteMode` | 03 | TestBatchTagPipeline.m::testErrorInvalidWriteMode |
| `TagPipeline:ingestFailed` | 04 | TestBatchTagPipeline.m::testIngestFailedThrownAtEnd |
| `TagPipeline:unknownExtension` | 04 | TestBatchTagPipeline.m::testDispatchUnknownExtension |
| `TagPipeline:invalidTestDispatch` (revision-1, test-only) | 03 | TestRawDelimitedParser.m (via readRawDelimitedForTest_ dispatch assertion) |

✅ All 11 production error IDs from RESEARCH §Q5 (plus unknownExtension = 12, plus the test-only invalidTestDispatch from the Major-1 shim) are asserted.

---

## Revision-1 Observability Contract (Major-2)

Both `BatchTagPipeline` and `LiveTagPipeline` expose a public `LastFileParseCount` (SetAccess=private) property. It records the number of DISTINCT raw files parsed in the most recent `run()` or tick.

**Where it's set:**
- `BatchTagPipeline.run()` — immediately before the end-of-run `fileCache_` reset
- `LiveTagPipeline.onTick_()` — immediately before the per-tick `tickCache` goes out of scope

**Where it's asserted:**
- `TestBatchTagPipeline.m::testFileCacheDedup` — 2 tags share a file, assert `p.LastFileParseCount == 1` after `p.run()`
- `TestLiveTagPipeline.m::testDedupAcrossTagsPerTick` — 2 tags share a file, assert `p.LastFileParseCount == 1` after `p.tickOnce()`

This replaces the previously-ambiguous approaches (call-counter wrapper blocked by private-folder scoping; post-run `fileCache_.Count` blocked because the cache is cleared at end-of-run; speculative `FileCount` property that was never actually declared). The canonical mechanism is now a direct public property read — no wrapper, no timing, no shim.

---

## Revision-1 Validator Duplication Contract (Major-3)

`StateTag.m` ships its own inline `validateRawSource_` static private method (8 lines, identical body to `SensorTag.validateRawSource_`). This preempts the Octave cross-class static-private call fragility that was previously hedged behind a runtime fallback.

**Enforced by grep in Plan 02 acceptance criteria:**
- `grep -c "SensorTag.validateRawSource_" libs/SensorThreshold/StateTag.m` returns 0
- `grep -c "^\\s*function rs = validateRawSource_" libs/SensorThreshold/StateTag.m` returns 1

The duplication is intentional tradeoff: 8 lines for Octave reliability. Single source of truth is enforced at the BEHAVIOR level — both classes must pass identical assertions on invalid RawSource inputs (TestSensorTag.m + TestStateTag.m cross-check).

**LiveTagPipeline cross-class predicate reuse (NOT pre-committed):** Unlike the validator, the `isIngestable_` predicate is 15 lines — DRY is worth attempting. Plan 05 tells the executor to TRY `@BatchTagPipeline.isIngestable_` first; only duplicate if Octave rejects it at runtime. Outcome documented in SUMMARY.

---

## Validation Dimensions (from RESEARCH.md)

Every plan must contribute tests across these axes:

1. **Functional correctness** — Per-tag .mat output round-trips through `SensorTag.load()` unchanged for wide and tall raw inputs. *(Covered by Plan 04::testRoundTripThroughSensorTagLoad, Plan 04::testTallFileTwoColumn, Plan 04::testWideFileFanOut)*
2. **Error-ID coverage** — Each of the 12 `TagPipeline:*` error IDs has an assertable test. *(Matrix above)*
3. **Octave parity** — Every pipeline-behavior suite runs under both MATLAB and Octave via `runtests`. Flat-function mirrors deferred per Pitfall 9 file-budget; suite classes auto-discovered by `tests/run_all_tests.m` on both runtimes.
4. **Live-mode incrementality** — Append semantics verified by Plan 05::testSecondTickWritesOnlyNewRows + testAppendModePreservesPriorRows (writes rows, ticks, adds rows, ticks again; asserts `[1;2;3;4;5]` after two appends — NOT just `[4;5]`).
5. **mtime-guard handling** — Plan 05 tests that bump mtime use `pause(1.1)` (same pattern as TestMatFileDataSource.m:38). Sub-second filesystem mtime (APFS/ext4/NTFS) still accommodated via the &gt;=1.1s sleep which satisfies the worst case (HFS+ 1s, Windows FAT 2s — the 2s FAT case is tolerated by pipeline re-checking on the next tick; documented in Plan 05 SUMMARY).
6. **De-dup caching (revision-1 observability)** — Plan 04::testFileCacheDedup + Plan 05::testDedupAcrossTagsPerTick assert exactly `LastFileParseCount == 1` per shared file per run/tick. Direct public property read — no wrapping.
7. **Per-tag error isolation** — Plan 04::testPerTagErrorIsolationContinuesToNext + testIngestFailedThrownAtEnd. Plan 05 covers tick-level isolation (failed tag does not abort tick).
8. **Test-shim production isolation (revision-1)** — `grep -rc "readRawDelimitedForTest_" libs/SensorThreshold/BatchTagPipeline.m libs/SensorThreshold/LiveTagPipeline.m` returns 0. Test shim is test-only; production code never imports it.

---

## Wave 0 Requirements (owned by Plan 01)

- [ ] `tests/suite/TestBatchTagPipeline.m` — scaffold with `TestClassSetup addPaths`, 16 RED placeholders covering every D-## decision Plan 04 addresses
- [ ] `tests/suite/TestLiveTagPipeline.m` — scaffold with 11 RED placeholders (mtime-bump + state GC + subclass check)
- [ ] `tests/suite/TestRawDelimitedParser.m` — scaffold with 18 RED placeholders (sniff/detect/parse/select/error IDs)
- [ ] `tests/suite/private/makeSyntheticRaw.m` — generator for wide/tall CSV/TXT/DAT + corrupt/empty/headerOnly/cellstr/missingColumn/sharedFile variants

**Wave 0 does NOT require:**
- ~~Flat-function mirrors (`tests/test_*.m`)~~ → deferred per Pitfall 9 (file-budget); suite classes run under both MATLAB and Octave via `runtests`
- ~~`tests/suite/private/pauseMtime.m`~~ → inlined as `pause(1.1)` in live-mode tests per TestMatFileDataSource precedent

*Budget note (Pitfall 5, revision-1):* This phase ships 12 touched files — EXACTLY at the 12-file cap. Margin = 0. Rationale documented in the frontmatter's `pitfall_5_margin_rationale` field. The 12th slot is consumed by `libs/SensorThreshold/readRawDelimitedForTest_.m` (Major-1 Option A test shim).

---

## Manual-Only Verifications

| Behavior | Decision | Why Manual | Test Instructions |
|----------|----------|------------|-------------------|
| Real-world large-file live polling throughput | D-13 | Filesystem-dependent; CI ext4 / macOS APFS may not surface timing regressions a user hits on an NFS share | After phase ships, optionally run a user script against a 500 MB CSV growing at 1 Hz; watch `LiveTagPipeline.Status` remain `'running'` and output .mat files update within 2× Interval. NOT a CI gate — informational only. |

All other phase behaviors have automated verification via the four test suites.

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify (no MISSING dependencies; Plan 01 produces the placeholders that Plans 02-05 turn GREEN)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every task has a runtests command)
- [x] Wave 0 covers all referenced fixture helpers; flat-function mirror and pauseMtime helper explicitly deferred with rationale
- [x] No watch-mode flags
- [x] Feedback latency < 30 s (quick) / 360 s (full)
- [x] `nyquist_compliant: true` set in frontmatter
- [x] All 12 `TagPipeline:*` error IDs have assertable tests (matrix above; the test-only `invalidTestDispatch` is a 13th test-only ID in revision-1)
- [x] Octave parity: every suite runs under `runtests` on both runtimes (no MATLAB-only APIs in the implementation path)
- [x] All 19 CONTEXT.md decisions (D-01..D-19) mapped to at least one plan
- [x] **Revision-1 specific:** Wave graph corrected (Minor-1), `LastFileParseCount` observability pre-committed on both pipeline classes (Major-2), StateTag inline validator duplication pre-committed (Major-3), Major-1 Option A test shim added with explicit Pitfall 5 margin = 0 rationale

**Approval:** Plans 01-05 ready for execution (revision-1).
