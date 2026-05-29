---
phase: 1014-dashboardserializer-m-export-for-tag-bound-widgets
verified: 2026-04-28T00:00:00Z
status: gaps_found
score: 0/5 must-haves verified
gaps:
  - truth: "Single-page Tag-bound `save → feval` round-trip preserves `Tag` property (MEXP-01)"
    status: failed
    reason: "Phase 1014 commits never landed on main. `git log main` ends at e87b035; commits 7902a9d (Task 1) and 2487233 (Task 2) live only on branch `feat/1014-01-tag-serializer` (and `fix/release-multiplatform`). On-disk `libs/Dashboard/DashboardSerializer.m` still has the pre-1014 `case 'sensor'` emitter at line 39 reading `ws.source.name`."
    artifacts:
      - path: libs/Dashboard/DashboardSerializer.m
        issue: "On main, the save() inline switch (line 35-58) still has `case 'sensor'` (line 39) — `case 'tag'` branch is missing. `grep -c \"case 'tag'\" libs/Dashboard/DashboardSerializer.m` = 0 on main; expected 2."
    missing:
      - "Merge feat/1014-01-tag-serializer into main (or cherry-pick 7902a9d, 2487233 onto main)"
      - "Recreate or recover the test commit e91b538 — it is currently a dangling commit on no branch (test file does not exist on disk)"
  - truth: "Multi-page `exportScriptPages` emits `TagRegistry.get('key')` per page (MEXP-02)"
    status: failed
    reason: "Same root cause — Task 1 commit (7902a9d) modifies linesForWidget() but is not on main. `linesForWidget()` at line 599 still has the legacy `case 'sensor'` emitter using `ws.source.name`."
    artifacts:
      - path: libs/Dashboard/DashboardSerializer.m
        issue: "linesForWidget() helper (line 596+) still has `case 'sensor'` (line 599) reading `ws.source.name` — `case 'tag'` branch missing, no try/catch, no `TagRegistry.get` emit for tag-bound widgets."
    missing:
      - "Land Task 1 commit (7902a9d) on main"
  - truth: "Generated script errors with clear `DashboardSerializer:tagNotRegistered` if user forgets to register (MEXP-03)"
    status: failed
    reason: "On main, `grep -c \"DashboardSerializer:tagNotRegistered\" libs/Dashboard/DashboardSerializer.m` = 0. The error ID is never emitted because no try/catch guard exists."
    artifacts:
      - path: libs/Dashboard/DashboardSerializer.m
        issue: "Zero occurrences of `DashboardSerializer:tagNotRegistered` on main. Generated scripts would fail with the underlying `TagRegistry:unknownKey` (or undefined-variable) instead of the documented public error ID."
    missing:
      - "Land Tasks 1 & 2 (7902a9d, 2487233)"
  - truth: "Zero `case 'sensor'` artifacts in v2.0-emitted `.m`; `fromStruct` reader retains backward-compat (MEXP-05)"
    status: partial
    reason: "fromStruct legacy reader is correctly retained (`grep -c \"case 'sensor'\" libs/Dashboard/FastSenseWidget.m` = 1 — pass). BUT the emitter side is wrong: `grep -c \"case 'sensor'\" libs/Dashboard/DashboardSerializer.m` = 2 on main; expected 0. Both legacy emitter branches (line 39 save inline, line 599 linesForWidget) still present."
    artifacts:
      - path: libs/Dashboard/DashboardSerializer.m
        issue: "Two `case 'sensor'` emitter branches still present (lines 39 and 599). MEXP-05 emitter-side requirement not satisfied on main."
      - path: libs/Dashboard/FastSenseWidget.m
        issue: "OK — `case 'sensor'` legacy reader retained (line 795). Reader-side MEXP-05 requirement satisfied."
    missing:
      - "Land Tasks 1 & 2 to delete both `case 'sensor'` emitter branches on main"
  - truth: "TestDashboardSerializerTagExport.m exists with 4 test methods covering save/exportScript/multipage/unregistered-error (MEXP-04)"
    status: failed
    reason: "tests/suite/TestDashboardSerializerTagExport.m does NOT exist on main. `git ls-files` returns 'pathspec did not match any file(s)'. `ls` returns 'No such file or directory'. The test commit e91b538 is a dangling commit reachable only by SHA — not on any branch."
    artifacts:
      - path: tests/suite/TestDashboardSerializerTagExport.m
        issue: "File does not exist on disk on main. Auto-discovery via TestSuite.fromFolder will not pick it up. 0 of 4 expected test methods are runnable."
    missing:
      - "Recover the test file from commit e91b538 (still reachable as a commit object — `git cat-file -t e91b538` returns 'commit') OR recreate it from the PLAN skeleton"
      - "Cherry-pick e91b538 onto a real branch and merge to main"
---

# Phase 1014: DashboardSerializer .m export for Tag-bound widgets - Verification Report

**Phase Goal:** Tag-bound widgets round-trip through `DashboardSerializer.save(d, 'out.m')` / `exportScriptPages` via guarded `TagRegistry.get('key')` lookups (try/catch → `DashboardSerializer:tagNotRegistered`); legacy `case 'sensor'` emitter removed; round-trip test ships.

**Verified:** 2026-04-28
**Status:** gaps_found
**Re-verification:** No — initial verification

## Summary

**The Phase 1014 implementation never landed on `main`.** The three planned commits exist as git objects but are not reachable from `main`:

- `7902a9d` (Task 1, linesForWidget edit): on `feat/1014-01-tag-serializer` and `fix/release-multiplatform`, NOT on main
- `2487233` (Task 2, save inline edit): on `feat/1014-01-tag-serializer` and `fix/release-multiplatform`, NOT on main
- `e91b538` (Task 3, test file): dangling — on no branch at all (only reachable by SHA)

`main` HEAD is `e87b035 ci: unblock multi-platform MEX refresh + delete dead test`. The next commit walking back from main is `2e06766` (Phase 1013 closeout). There is a clean gap where Phase 1014 should be.

The SUMMARY.md "Issues Encountered" section noted a "Mid-execution branch switch" where HEAD was switched from `main` to `fix/release-multiplatform` and the executor "recovered by `git checkout main`" — but that recovery did NOT bring the Phase 1014 commits onto main. The SUMMARY's Self-Check claim "All 3 Phase 1014 commits ... are on `main` as planned" is incorrect.

## Goal Achievement

### Observable Truths

| #   | Truth                                                              | Status   | Evidence                                                                                                                  |
| --- | ------------------------------------------------------------------ | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| 1   | Single-page Tag-bound save→feval round-trip preserves Tag (MEXP-01) | ✗ FAILED | `case 'tag'` count in DashboardSerializer.m = 0 on main; save() inline switch still emits legacy `case 'sensor'` at line 39 |
| 2   | Multi-page exportScriptPages emits TagRegistry.get per page (MEXP-02) | ✗ FAILED | linesForWidget at line 599 still has `case 'sensor'` reading `ws.source.name`                                            |
| 3   | Generated script errors with DashboardSerializer:tagNotRegistered (MEXP-03) | ✗ FAILED | `grep -c "DashboardSerializer:tagNotRegistered" libs/Dashboard/DashboardSerializer.m` = 0 on main                          |
| 4   | Zero `case 'sensor'` emitter; fromStruct retains backward-compat (MEXP-05) | ✗ FAILED | Emitter still has 2 `case 'sensor'` branches; reader correctly retains 1 (FastSenseWidget.fromStruct line 795 OK)         |
| 5   | TestDashboardSerializerTagExport.m exists with 4 methods (MEXP-04) | ✗ FAILED | File does not exist on disk on main; `git ls-files` returns no match                                                       |

**Score:** 0/5 truths verified

### Required Artifacts

| Artifact                                                | Expected                                                          | Status     | Details                                                                                                                                                       |
| ------------------------------------------------------- | ----------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `libs/Dashboard/DashboardSerializer.m`                  | `case 'tag'` branches in BOTH switches; `case 'sensor'` deleted   | ✗ STUB     | File exists but is the pre-1014 state on main (`case 'sensor'` still in both switches at lines 39 + 599; no `case 'tag'`; no try/catch; no tagNotRegistered) |
| `libs/Dashboard/DashboardSerializer.m`                  | Try/catch + DashboardSerializer:tagNotRegistered emitter pattern  | ✗ MISSING  | 0 occurrences of `DashboardSerializer:tagNotRegistered`; 0 occurrences of `try` near a tag emitter                                                            |
| `tests/suite/TestDashboardSerializerTagExport.m`        | New 4-method matlab.unittest round-trip suite                     | ✗ MISSING  | File does not exist on main. Test commit e91b538 is dangling.                                                                                                  |

### Key Link Verification

| From                                          | To                                       | Via                          | Status      | Details                                                                                  |
| --------------------------------------------- | ---------------------------------------- | ---------------------------- | ----------- | ---------------------------------------------------------------------------------------- |
| DashboardSerializer.save() inline switch       | TagRegistry.get('key') in emitted .m     | sprintf with ws.source.key   | ✗ NOT_WIRED | Line 42 still emits `TagRegistry.get('%s')` but reads `ws.source.name` (legacy field)      |
| DashboardSerializer.linesForWidget() helper    | TagRegistry.get('key') in emitted .m     | sprintf with indent + key    | ✗ NOT_WIRED | Line 602 still emits via `ws.source.name`; never reads `ws.source.key`                    |
| Emitted try/catch guard                        | DashboardSerializer:tagNotRegistered     | try-catch wrapper            | ✗ NOT_WIRED | No try/catch is emitted; no rethrow; no `DashboardSerializer:tagNotRegistered` literal     |
| TestDashboardSerializerTagExport               | save/exportScript/exportScriptPages/load | tempfile + verifyEqual       | ✗ NOT_WIRED | Test file does not exist                                                                  |

### Data-Flow Trace (Level 4)

Not applicable in the failing direction — the emitter outputs strings (not dynamic data); since the emitter is missing entirely on main, there is no data flow to trace.

For the existing legacy `case 'sensor'` path on main: the emitter reads `ws.source.name`, but `FastSenseWidget.toStruct` (Phase 1009+) emits `s.source.key` (not `name`). So a Tag-bound widget on main would emit a script using a non-existent field — undefined behavior. This is exactly the gap Phase 1014 was designed to fix; the fact that the fix did not land means the gap remains open.

### Behavioral Spot-Checks

| Behavior                                        | Command                                                               | Result                                                          | Status |
| ----------------------------------------------- | --------------------------------------------------------------------- | --------------------------------------------------------------- | ------ |
| `case 'tag'` count in DashboardSerializer.m     | `grep -c "case 'tag'" libs/Dashboard/DashboardSerializer.m`           | 0 (expected 2)                                                  | ✗ FAIL |
| `case 'sensor'` count in DashboardSerializer.m  | `grep -c "case 'sensor'" libs/Dashboard/DashboardSerializer.m`        | 2 (expected 0)                                                  | ✗ FAIL |
| `case 'sensor'` count in FastSenseWidget.m      | `grep -c "case 'sensor'" libs/Dashboard/FastSenseWidget.m`            | 1 (expected 1 — backward-compat reader retained)                 | ✓ PASS |
| DashboardSerializer:tagNotRegistered count       | `grep -c "DashboardSerializer:tagNotRegistered" libs/.../DashboardSerializer.m` | 0 (expected 2)                                                  | ✗ FAIL |
| TagRegistry.has count (must be 0)                | `grep -c "TagRegistry\.has" libs/Dashboard/DashboardSerializer.m`     | 0                                                                | ✓ PASS (vacuously — no emitter exists) |
| TagRegistry.get( count                           | `grep -c "TagRegistry\.get(" libs/Dashboard/DashboardSerializer.m`    | 2 (legacy emitters, reading `ws.source.name`)                    | ⚠️ — wrong field |
| `ws.source.name` count                           | `grep -c "ws\.source\.name" libs/Dashboard/DashboardSerializer.m`     | 4 (expected 2 max — emitter sites should be 0; 2 in configToWidgets resolver path are pre-existing) | ✗ FAIL |
| Test file presence                               | `ls tests/suite/TestDashboardSerializerTagExport.m`                   | "No such file or directory"                                      | ✗ FAIL |
| Test file tracked by git                         | `git ls-files --error-unmatch tests/suite/TestDashboardSerializerTagExport.m` | "pathspec did not match"                                          | ✗ FAIL |
| Phase 1014 commits on main                       | `git branch --contains 7902a9d` (filter for main)                     | `feat/1014-01-tag-serializer`, `fix/release-multiplatform` (NOT main) | ✗ FAIL |
| Test commit e91b538 on any branch                | `git branch --contains e91b538`                                       | empty (dangling commit)                                          | ✗ FAIL |
| Phase 1013 regression (legacy class refs)        | `grep -rE 'EventDetector\|IncrementalEventDetector\|EventConfig' libs/ benchmarks/ install.m` | 0 hits                                                           | ✓ PASS |
| Golden test untouched (Gate B)                   | `git diff main HEAD -- tests/suite/TestGoldenIntegration.m tests/test_golden_integration.m` | 0 lines                                                          | ✓ PASS (vacuously — no Phase 1014 changes on main at all) |

### Requirements Coverage

| Requirement | Source Plan        | Description                                                                                          | Status     | Evidence                                                                                                            |
| ----------- | ------------------ | ---------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------- |
| MEXP-01     | 1014-01-PLAN.md    | save(d, 'out.m') emits TagRegistry.get('key') for Tag-bound widget                                    | ✗ BLOCKED  | save() inline switch on main still emits legacy `case 'sensor'`; no `case 'tag'` branch                              |
| MEXP-02     | 1014-01-PLAN.md    | exportScriptPages emits TagRegistry.get('key') per page                                              | ✗ BLOCKED  | linesForWidget on main still emits legacy `case 'sensor'`; no `case 'tag'` branch                                    |
| MEXP-03     | 1014-01-PLAN.md    | Generated .m has guarded lookup that errors clearly if tag missing                                    | ✗ BLOCKED  | Zero `DashboardSerializer:tagNotRegistered` and zero try/catch guard in emitter on main                              |
| MEXP-04     | 1014-01-PLAN.md    | save → load round-trip Tag-bound dashboard preserves Tag handle (verified by new suite test)         | ✗ BLOCKED  | Test file does not exist on main; round-trip cannot be verified                                                      |
| MEXP-05     | 1014-01-PLAN.md    | Legacy `case 'sensor'` emitter removed; fromStruct retains 'sensor' reader for backward-compat       | ✗ BLOCKED  | Emitter side: 2 `case 'sensor'` branches still present (FAIL). Reader side: 1 retained correctly (PASS).            |

REQUIREMENTS.md marks MEXP-01..05 as `[x] Complete` and the requirements ledger lists them as "Phase 1014: Complete". This is misaligned with main: the implementation is on a feature branch, not main. The ledger is documenting the SUMMARY's claim, not the verifiable state of main.

No orphaned requirements: all five MEXP-01..05 IDs are declared in 1014-01-PLAN.md frontmatter, and REQUIREMENTS.md maps them to Phase 1014 with no additions.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| libs/Dashboard/DashboardSerializer.m | 39, 42 | Legacy `case 'sensor'` emitter reading `ws.source.name` (toStruct emits `source.key` post-Phase-1009) | 🛑 Blocker | Tag-bound widgets cannot round-trip; emitter reads field that doesn't exist on toStruct output |
| libs/Dashboard/DashboardSerializer.m | 599, 602 | Same legacy `case 'sensor'` pattern in linesForWidget helper | 🛑 Blocker | Multi-page export silently produces broken scripts |
| (Branch hygiene) | — | `feat/1014-01-tag-serializer` branch has work that was never merged; `e91b538` is a dangling commit | 🛑 Blocker | Phase considered "Complete" in REQUIREMENTS.md ledger but main does not reflect the work |

### Human Verification Required

None — the gaps are programmatically detectable via `git log` + `grep` and require no human judgment.

### Gaps Summary

The phase was planned, executed (commits exist as git objects), and a SUMMARY.md was written claiming success — but the work was never integrated into `main`. Recovery actions required, in order:

1. **Verify commit chain on `feat/1014-01-tag-serializer`:** `git log feat/1014-01-tag-serializer` shows `2487233` → `7902a9d` → `2e06766` (Phase 1013 closeout). Tasks 1 & 2 are intact and on top of the correct base.
2. **Recover the test commit (`e91b538`):** It is a dangling commit reachable only by SHA. Confirm with `git cat-file -p e91b538` that the patch contains the planned 4-method test file. If lost, recreate from the PLAN skeleton (the SUMMARY confirms the file was 174 LOC matching the plan).
3. **Land all three commits on main:** Either (a) cherry-pick `7902a9d`, `2487233`, then `e91b538` onto main; or (b) merge `feat/1014-01-tag-serializer` and separately cherry-pick `e91b538`. Option (a) is cleaner because `feat/1014-01-tag-serializer` was based on the same `2e06766` that main branched from, so cherry-pick should apply without conflicts.
4. **Re-run the verification gates:** `case 'tag'` = 2, `case 'sensor'` = 0, `tagNotRegistered` = 2 in DashboardSerializer.m; test file present with 4 methods.
5. **(Deferred to CI / reverifier with MATLAB)** Run `TestDashboardSerializerTagExport` on MATLAB R2020b — Octave smoke per the SUMMARY claims it passed locally on the feature branch, but Gate E (MATLAB CI green) was deferred per the SUMMARY itself.

After recovery, re-verify by re-running this verification with `--gaps`. Expected outcome: all 5 truths VERIFIED, all 3 artifacts pass levels 1-3, all 4 key links WIRED.

---

_Verified: 2026-04-28_
_Verifier: Claude (gsd-verifier)_
