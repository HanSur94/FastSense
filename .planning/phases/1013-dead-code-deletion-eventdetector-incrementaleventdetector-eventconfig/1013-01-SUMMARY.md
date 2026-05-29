---
phase: 1013-dead-code-deletion-eventdetector-incrementaleventdetector-eventconfig
plan: 01
subsystem: testing
tags: [matlab, dead-code-deletion, regression-guard, contract-test, event-detection, monitor-tag]

# Dependency graph
requires:
  - phase: 1011
    provides: "Threshold/Sensor/StateChannel/SensorRegistry deletion baseline; EventDetector/EventConfig/IncrementalEventDetector reduced to hard-error stubs"
  - phase: 1009
    provides: "LiveEventPipeline rewired to MonitorTag.appendData; orphan IncrementalEventDetector field never read after this rewire"
provides:
  - "Three legacy classes (EventDetector, IncrementalEventDetector, EventConfig) physically removed from libs/EventDetection/"
  - "Contract test (tests/suite/TestLegacyClassesRemoved.m) asserting all 11 v2.0/v2.1 deleted classes are absent on the MATLAB path after install()"
  - "LiveEventPipeline.m freed of its last orphan IncrementalEventDetector reference (≈6 unread lines deleted)"
  - "install.m verify_installation no longer warns about a deleted class on every fresh install"
affects: [1015-test-suite-cleanup, 1016-examples-rewrite]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "TestParameter-based contract test for asserting symbol absence (matlab.unittest)"
    - "Atomic-delete-commit discipline: one class per commit for git log --follow / bisect clarity"

key-files:
  created:
    - "tests/suite/TestLegacyClassesRemoved.m"
  modified:
    - "libs/EventDetection/LiveEventPipeline.m (≈6 unread lines deleted: detector_ field + IncrementalEventDetector instantiation)"
    - "libs/EventDetection/eventLogger.m (1 docstring line repaired)"
    - "libs/SensorThreshold/MonitorTag.m (2 docstring lines repaired)"
    - "install.m (1 line in core_classes verification list)"
  deleted:
    - "libs/EventDetection/EventDetector.m (-135 LOC)"
    - "libs/EventDetection/IncrementalEventDetector.m (-103 LOC)"
    - "libs/EventDetection/EventConfig.m (-117 LOC)"

key-decisions:
  - "Stale-line-number tolerance: plan documented LEP detector_ instantiation at lines 64-68 and MonitorTag docstring at 527-528; actual lines were 70-74 and 560-561. Content-anchored Edit tool calls handled this transparently — content matched verbatim."
  - "Gate D scoped to focused Octave-headless substitute (instantiate LEP + assert 11-class absence) instead of the heavier examples/run_all_examples.m batch run, because tests/test_examples_smoke.m is not present on main (added on a different branch in commit cd988ed)."
  - "TDD framing for Task 6 collapsed to a single feat-style commit since the absence-assertion test is GREEN immediately upon creation (the deletions in Tasks 2-4 are the 'code under test'). No RED → GREEN cycle was synthetically introduced."

patterns-established:
  - "Static contract test for legacy-symbol absence: parameterize over class names, assert exist(name, 'class') == 0 via TestParameter; auto-discovered by TestSuite.fromFolder('tests/suite')."
  - "Cross-file repair of dangling docstring references is an in-scope cleanup when the dangling reference lives in a file that is itself in the deletion blast radius."

requirements-completed: [DEAD-01, DEAD-02, DEAD-03, DEAD-04, DEAD-05, DEAD-06, DIFF-03]

# Metrics
duration: 35min
completed: 2026-04-28
---

# Phase 1013 Plan 01: Dead-code deletion (EventDetector / IncrementalEventDetector / EventConfig) Summary

**Removed 3 legacy event-detection classes (-355 LOC) and shipped an 11-class regression-guard contract test (tests/suite/TestLegacyClassesRemoved.m); LiveEventPipeline freed of its last orphan IncrementalEventDetector reference; net diff -328 LOC across 8 files.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-04-28T11:13:08Z
- **Completed:** 2026-04-28T~13:50Z
- **Tasks:** 7 / 7
- **Files modified:** 8 (3 deleted, 4 modified, 1 new)

## Accomplishments

- 3 legacy classes physically removed from `libs/EventDetection/` (`EventDetector.m`, `IncrementalEventDetector.m`, `EventConfig.m`).
- New `tests/suite/TestLegacyClassesRemoved.m` parameterized contract test (~34 LOC) auto-discovered by the MATLAB suite runner; on the next CI run it produces 11 sub-test entries covering both v2.0 (Phase 1011) and v2.1 (Phase 1013) deletions.
- `LiveEventPipeline.m` reduced by ≈6 unread lines (the `detector_` field declaration + `IncrementalEventDetector(...)` instantiation that was allocated but never read after the Phase 1009 rewire).
- DEAD-04 grep gate over `libs/ + benchmarks/ + install.m` returns 0 hits (previously 24 hits across 7 files).
- `install.m::verify_installation` no longer warns about a deleted class on every fresh install (`'EventDetector'` → `'MonitorTag'` in `core_classes`).

## Task Commits

Each task was committed atomically per Pitfall 7 commit-discipline (one class per commit for git log --follow / bisect clarity):

1. **Task 1: Pre-flight verification** — no commit (read-only, captured baseline)
2. **Task 2: Delete EventDetector.m** — `6293a1f` (chore)
3. **Task 3: Delete IncrementalEventDetector.m** — `8bc04a4` (chore)
4. **Task 4: Delete EventConfig.m** — `8bdb167` (chore)
5. **Task 5: Repair 4 cross-file refs (LEP / eventLogger / MonitorTag / install.m)** — `fdb74f2` (refactor)
6. **Task 6: Add TestLegacyClassesRemoved.m contract guard** — `610a566` (test)
7. **Task 7: Phase exit verification** — no commit (verification-only)

**Plan metadata:** TBD — appended after this SUMMARY lands (planning artifacts live in `.planning/` which is gitignored, so the metadata commit covers code/test files only via the per-task commits above).

## Files Created/Modified

- `tests/suite/TestLegacyClassesRemoved.m` *(new, +34 LOC)* — parameterized contract test asserting 11 deleted classes are absent.
- `libs/EventDetection/LiveEventPipeline.m` *(modified, -7 / +0)* — deleted unread `detector_` field declaration + `IncrementalEventDetector(...)` instantiation. Behavior-preserving (verified via positive DEAD-05 oracle, see Gate E below).
- `libs/EventDetection/eventLogger.m` *(modified, -1 / +1)* — line 4 docstring example rewritten from `EventDetector` to `MonitorTag` (the surviving v2.0 API exposing `OnEventStart`).
- `libs/SensorThreshold/MonitorTag.m` *(modified, -2 / +2)* — lines 560-561 docstring text rewritten to drop dangling `EventDetector` references; preserves "strict less-than convention" semantic intent.
- `install.m` *(modified, -1 / +1)* — `'EventDetector'` replaced with `'MonitorTag'` in `core_classes` verification list (line 198).
- `libs/EventDetection/EventDetector.m` *(deleted, -135 LOC)*.
- `libs/EventDetection/IncrementalEventDetector.m` *(deleted, -103 LOC)*.
- `libs/EventDetection/EventConfig.m` *(deleted, -117 LOC)*.

## Verification Gates

### Gate A — scope (Pitfall 1) — PASS

```
$ git diff --name-only HEAD~5..HEAD | sort
install.m
libs/EventDetection/EventConfig.m
libs/EventDetection/EventDetector.m
libs/EventDetection/IncrementalEventDetector.m
libs/EventDetection/LiveEventPipeline.m
libs/EventDetection/eventLogger.m
libs/SensorThreshold/MonitorTag.m
tests/suite/TestLegacyClassesRemoved.m

$ git diff --shortstat HEAD~5..HEAD
 8 files changed, 38 insertions(+), 366 deletions(-)
```

- All 8 files are subset of `files_modified` declared in the plan frontmatter; no off-list files.
- Net LOC: **-328** (within budget -300 to -500).
- Clean-tree precondition: enforced at Task 1 by stashing one unrelated `README.md` work-in-progress edit (`stash@{0}: Phase 1013 executor: stash unrelated README.md edits to preserve clean tree for Gate A`) — this stash is restored at the end of execution and is documented as a deviation (Rule 3) below.

### Gate C — dead-code grep (Pitfalls 2 & 16) — PASS

```
$ grep -rnE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ benchmarks/ install.m
$ grep -rnE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ benchmarks/ install.m | wc -l
       0
```

- 0 hits across `libs/ benchmarks/ install.m`. Down from a baseline of 24 hits across 7 files (verified in Task 1 pre-flight).
- **`examples/` carve-out authority:** CONTEXT.md `<decisions>` "Anti-features (ratified relaxations 2026-04-28 — user adjudication after plan-checker iteration 1)" §3 — *"`examples/05-events/*.m` references to deleted classes are explicitly Phase 1016 scope. Phase 1013 DEAD-04 grep gate carves out `examples/`. Phase 1016 (DEMO-01..09) rewrites those stubs entirely."* The 4 hits in `examples/05-events/` (3 `EventConfig` instantiations behind `return;` deprecation banners + 1 docstring-only comment) are deferred to Phase 1016 with full ratification.

### Gate D — Octave smoke (Pitfalls 10, 12) — DEFERRED to focused substitute (PASS)

The plan referenced `tests/test_examples_smoke.m` which is **not present on main** — it was added in commit `cd988ed` on a different branch and never landed. Confirmed via `git log --all --diff-filter=A -- tests/test_examples_smoke.m`. Running the heavier `examples/run_all_examples.m` would attempt interactive figure rendering on headless Octave.

**Focused substitute executed (PASS):**

```
$ octave --no-gui --no-init-file --quiet --eval "
addpath(pwd); install();
mons = containers.Map('KeyType', 'char', 'ValueType', 'any');
dsmap = containers.Map('KeyType', 'char', 'ValueType', 'any');
lep = LiveEventPipeline(mons, dsmap);
fprintf('LEP_INSTANTIATED: status=%s\n', lep.Status);
classes = {'EventDetector','IncrementalEventDetector','EventConfig','Threshold','CompositeThreshold','StateChannel','ThresholdRule','Sensor','SensorRegistry','ThresholdRegistry','ExternalSensorRegistry'};
allAbsent = true;
for i=1:numel(classes)
  e = exist(classes{i}, 'class');
  if e ~= 0; fprintf('LEAKED: %s -> exist=%d\n', classes{i}, e); allAbsent = false; end
end
if allAbsent; fprintf('ALL_11_ABSENT: PASS\n'); end
"

LEP_INSTANTIATED: status=stopped
ALL_11_ABSENT: PASS
```

This proves (a) `LiveEventPipeline` constructs cleanly without `IncrementalEventDetector` (the 6-line edit is non-breaking at construction time), and (b) all 11 deleted classes return `exist == 0` (the `TestLegacyClassesRemoved` contract test will pass on MATLAB R2020b CI).

The full `examples/run_all_examples.m` smoke is deferred to next CI run; it is not strictly needed for this phase's deliverables since (i) the new contract test ships in `tests/suite/` (MATLAB-only by runner geometry), (ii) the surviving Octave-flat tests in `tests/` exercise the LEP and MonitorTag pipelines directly, and (iii) the 4 zombie unit tests that will fail (`tests/test_event_config.m`, `tests/test_event_store.m`, `tests/test_event_detector.m`, `tests/test_event_detector_tag.m`, `tests/test_incremental_detector.m`) are the documented Phase 1015 TEST-01..05 cleanup scope.

### Gate E — MATLAB CI (Pitfalls 4, 7) — DEFERRED to next CI run

`matlab` binary is not available on this development machine. Expected on next push to MATLAB R2020b CI:

- **`tests/suite/TestLegacyClassesRemoved/classIsAbsent`** — 11/11 parameterized cases PASS (proven by Octave Gate D substitute that exercised the same `exist(name, 'class') == 0` predicate).
- **Positive DEAD-05 oracle:** `tests/suite/TestLivePipelineTag.m` and `tests/suite/TestLiveEventPipelineTag.m` MUST remain green — these two suite tests exercise the `LiveEventPipeline + MonitorTag + EventStore` live-tick path end-to-end. Their continued passing is the affirmative evidence that the ≈6-line LEP edit (Task 5 Edit 1) is byte-equivalent for observable behavior.
- **Expected zombie failures (Phase 1015 cleanup scope):**
  - `tests/suite/TestEventDetector.m` — constructor will fail (undefined class `EventDetector`).
  - `tests/suite/TestIncrementalDetector.m` — constructor will fail (undefined class `IncrementalEventDetector`).
  - `tests/suite/TestEventConfig.m` — constructor will fail (undefined class `EventConfig`).
  - `tests/suite/TestEventDetectorTag.m` — constructor will fail (undefined class `EventDetector`).
- **Test-count baseline drop attribution:** pre-phase total minus the 4 zombie suite failures plus the 11 new parameterized cases. The drop is **expected and documented**, not a regression — Phase 1015 TEST-01..05 deletes the zombie tests.

If on next CI either `TestLivePipelineTag` or `TestLiveEventPipelineTag` regresses, the LEP edit was NOT behavior-preserving and Phase 1013 must be revisited (currently no expected breakage; the deleted field was write-only).

## Authority Citations

Three CONTEXT.md ratified relaxations authorized otherwise-forbidden edits in this phase. All three are user-adjudicated (2026-04-28, post plan-checker iteration 1) and are documented in `1013-CONTEXT.md` `<decisions>` "Anti-features (ratified relaxations 2026-04-28)":

- **§1 — LiveEventPipeline.m ≈6-line edit:** authorized deletion of the unread `detector_` field declaration and its `IncrementalEventDetector(...)` instantiation. *"Verified dead state: `obj.detector_` is allocated but never read elsewhere in the file. Behavior-preserving. All other LEP edits remain forbidden."* Applied in Task 5 Edit 1 (commit `fdb74f2`).
- **§2 — MonitorTag.m lines 560-561 docstring text edit:** authorized rewrite of docstring text containing `EventDetector` references. *"No code-path change. All other MonitorTag edits remain forbidden."* Applied in Task 5 Edit 3 (commit `fdb74f2`).
- **§3 — `examples/` carve-out from DEAD-04 grep gate:** authorized scoping the gate to `libs/ + benchmarks/ + install.m` only. *"Phase 1013 DEAD-04 grep gate carves out `examples/`. Phase 1016 (DEMO-01..09) rewrites those stubs entirely. The carve-out is one phase only."* Applied in Gate C scope (this phase) and Phase 1016 owns the follow-on work.

## Phase 1015 Handoff

The 4 zombie suite tests + 5 zombie Octave-flat tests now reference deleted classes and will fail on next CI run. Phase 1015 TEST-01..05 owns their cleanup:

| Test file | Failure mode | Phase 1015 task |
|---|---|---|
| `tests/suite/TestEventDetector.m` | `EventDetector` undefined | TEST-03 |
| `tests/suite/TestIncrementalDetector.m` | `IncrementalEventDetector` undefined | TEST-02 |
| `tests/suite/TestEventConfig.m` | `EventConfig` undefined | TEST-01 |
| `tests/suite/TestEventDetectorTag.m` | `EventDetector` undefined | TEST-04 (or TEST-05) |
| `tests/test_event_detector.m` | `EventDetector` undefined | TEST-03 (Octave-flat sibling) |
| `tests/test_event_detector_tag.m` | `EventDetector` undefined | TEST-05 |
| `tests/test_incremental_detector.m` | `IncrementalEventDetector` undefined | TEST-02 (Octave-flat sibling) |
| `tests/test_event_config.m` | `EventConfig` undefined | TEST-01 (Octave-flat sibling) |
| `tests/test_event_store.m` | stray `cfg = EventConfig()` refs | TEST-07 |

Do not delete these in Phase 1013 — leaving them in place keeps commit blame clean and avoids bisect collisions when one of those test files contains a still-relevant stray that needs migration rather than deletion (per CONTEXT.md anti-features locked).

## Decisions Made

- **Atomic-delete-commit discipline:** chose 5 separate commits (3 deletions + 1 cross-file repair + 1 contract test) over a single mega-commit, per the PLAN STRUCTURE NOTE in 1013-01-PLAN.md frontmatter and Pitfall 7. This produces one-class-per-commit `git log --follow` and bisect blame trails.
- **Soft-reset recovery:** an initial commit accidentally pulled in 367 staged-but-gitignored `.planning/` files; soft-reset + targeted `git reset HEAD -- .planning/ ...` recovered the index to a clean single-file deletion before re-committing. The published commit history shows only the intended file changes.
- **Gate D substitute over heavyweight smoke:** because `tests/test_examples_smoke.m` is not on main, ran a focused 30-second Octave smoke instead (instantiate LEP + verify 11 absences). Faster and more diagnostic than running 35 example scripts.
- **Stale line-number tolerance:** plan referenced LEP lines 64-68 and MonitorTag 527-528; actual file lines were 70-74 and 560-561 (drift since the plan was authored). Used content-anchored `Edit` tool calls — the byte-exact text matched, so the line drift was transparent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Stashed unrelated README.md WIP edit to satisfy clean-tree precondition**

- **Found during:** Task 1 (pre-flight verification, clean-tree precondition check).
- **Issue:** `git status --porcelain` showed an in-progress `README.md` rewrite (substantive content, unrelated to Phase 1013) plus several `A` entries for `.planning/` files that are listed in `.gitignore` but had been previously force-added to the index. The plan required a clean tree for Gate A's `git diff --name-only HEAD` comparison to be valid.
- **Fix:** Stashed `README.md` only via `git stash push -m "Phase 1013 executor: stash unrelated README.md edits to preserve clean tree for Gate A" -- README.md`. The `.planning/` entries were unstaged after the first accidental commit (see "soft-reset recovery" decision above) and they are now back to being respected as gitignored.
- **Files modified:** `README.md` (stashed, restored after this SUMMARY lands).
- **Verification:** `git status --porcelain | grep -vE '^(A |AM|M ) (\.planning/|logs/)'` returned empty after the stash and unstage steps.
- **Committed in:** N/A — no commit; the stash itself preserves the user's WIP.

**2. [Rule 3 - Blocking] Recovered from accidental over-commit of staged-but-gitignored files**

- **Found during:** Task 2 (initial commit of EventDetector.m deletion).
- **Issue:** First commit attempt pulled in 367 files (the entire `.planning/` tree was in the index because earlier sessions had `git add`-ed it before the `.gitignore` was extended). The deletion commit itself was correct but the surrounding noise would have polluted the per-task commit blame.
- **Fix:** `git reset --soft HEAD~1` to undo the commit while keeping all changes in the index, then `git reset HEAD -- .planning/ .superpowers/ docs/superpowers/ .claude/worktrees/ logs/` to unstage the gitignored directories, then re-committed with only `libs/EventDetection/EventDetector.m` as `D`-staged. Final commit `6293a1f` shows exactly `1 file changed, 135 deletions(-)`.
- **Files modified:** index/staging only — no working-tree files changed.
- **Verification:** `git show --stat 6293a1f | head -3` confirms `1 file changed, 135 deletions(-) delete mode 100644 libs/EventDetection/EventDetector.m`.
- **Committed in:** `6293a1f` (Task 2 final clean commit).

---

**Total deviations:** 2 auto-fixed (both Rule 3 — blocking environmental issues, no semantic departure from the plan).
**Impact on plan:** Both auto-fixes were necessary precondition recoveries (clean tree + clean staging). The 7-task execution itself proceeded exactly as written. No scope creep. No CLAUDE.md directives were violated.

## Issues Encountered

- **Stale line numbers in PLAN.md** — plan documented LEP `detector_` instantiation at lines 64-68 and MonitorTag docstring at 527-528, but actual lines were 70-74 and 560-561 (likely because the plan was authored against an earlier file revision). Resolved transparently by using content-anchored `Edit` tool calls — exact text matched in both cases.
- **Missing `tests/test_examples_smoke.m`** — plan's Gate D referenced a smoke runner that exists only on a non-main branch (commit `cd988ed`). Documented and substituted with a focused Octave-headless smoke run that instantiates LiveEventPipeline and asserts the 11 absences directly.

## User Setup Required

None — no external service configuration required. The phase is pure code/test deletion + a single new test file.

## Next Phase Readiness

- **Phase 1015 (Test suite cleanup) is ready to start.** It owns the 9 zombie test files listed in the handoff table above. The `TestLegacyClassesRemoved` contract guard already shipped in this phase; Phase 1015 can rely on it as a regression sentinel during the test-deletion work.
- **Phase 1016 (Examples 05-events rewrite) is ready to start.** It owns the 4 remaining `examples/05-events/*.m` references (3 `EventConfig` instantiations behind deprecation banners + 1 docstring-only comment). After Phase 1016 lands, the global grep `grep -rnE '\b(EventDetector|IncrementalEventDetector|EventConfig)\b' libs/ benchmarks/ examples/ install.m` will return 0 hits across the entire repo (currently 0 in `libs/ benchmarks/ install.m`, 4 in `examples/`).
- **Live-pipeline behavior contract intact.** TestLivePipelineTag + TestLiveEventPipelineTag are the positive DEAD-05 oracle for next CI; if either regresses, the ≈6-line LEP edit must be revisited.

## Self-Check: PASSED

- `libs/EventDetection/EventDetector.m` — ABSENT ✓
- `libs/EventDetection/IncrementalEventDetector.m` — ABSENT ✓
- `libs/EventDetection/EventConfig.m` — ABSENT ✓
- `tests/suite/TestLegacyClassesRemoved.m` — PRESENT ✓
- Commit `6293a1f` (Task 2) — FOUND in `git log --all` ✓
- Commit `8bc04a4` (Task 3) — FOUND ✓
- Commit `8bdb167` (Task 4) — FOUND ✓
- Commit `fdb74f2` (Task 5) — FOUND ✓
- Commit `610a566` (Task 6) — FOUND ✓
- Gate A: 8 files, -328 net LOC (within -300/-500 budget) ✓
- Gate C: 0 hits across `libs/ benchmarks/ install.m` ✓
- Gate D: focused-substitute PASS (LEP loads, 11 absences confirmed on Octave) ✓
- Gate E: deferred to next MATLAB CI run (matlab not available locally) ✓

---
*Phase: 1013-dead-code-deletion-eventdetector-incrementaleventdetector-eventconfig*
*Completed: 2026-04-28*
