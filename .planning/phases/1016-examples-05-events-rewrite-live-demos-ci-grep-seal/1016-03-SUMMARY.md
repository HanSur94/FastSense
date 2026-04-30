---
phase: 1016-examples-05-events-rewrite-live-demos-ci-grep-seal
plan: 03
subsystem: ci
tags: [ci, github-actions, grep-seal, regression-prevention, lint, tag-api, v2.1-cleanup]
requires:
  - .github/workflows/tests.yml
  - scripts/check_skip_list_parity.sh
provides:
  - "CI grep seal locking the v2.1 cleanup forever — `lint` job step in `.github/workflows/tests.yml` that fails CI on re-introduction of any of the 8 Phase-1011 deleted classes"
  - "Inline self-test (1 hit + 3 misses) verifying regex discrimination on every CI run — prevents silent regex drift over time"
affects:
  - "Every future PR / push / nightly schedule run on the repo: any code that re-adds Threshold(, CompositeThreshold(, StateChannel(, ThresholdRule(, Sensor(, SensorRegistry(, ThresholdRegistry(, or ExternalSensorRegistry( bare constructors in libs/ tests/ examples/ benchmarks/ now fails the lint job"
tech-stack:
  added: []
  patterns:
    - "Phase 1015 word-boundary lookbehind regex idiom: `(^|[^.a-zA-Z_])(ClassName)\\(` — discriminates `Sensor(` (HIT) from `SensorTag(` (literal `Sensor(` substring is absent because of the `Tag` between `Sensor` and `(`) and `fp.addThreshold(` (the `.` before `T` is rejected by `[^.a-zA-Z_]`)"
    - "Inline-bash CI step with `set -euo pipefail` + tempdir + `trap rm -rf` + self-test before real scan — drift-resistant"
    - "Step adjacent to existing skip-list parity gate (DIFF-04) for cohesion of v2.1 regression-prevention gates"
key-files:
  created: []
  modified:
    - .github/workflows/tests.yml
key-decisions:
  - "Single grep with alternation (8 classes `|`-separated) rather than 8 separate greps — one CI step, one log block, one exit code"
  - "Self-test uses Phase 1015 P01 idiom for the test-suite cleanup grep gate (TEST-10) — same pattern shape, same verifier mechanism"
  - "Step placed BETWEEN `Run complexity metrics` and `Skip-list parity gate (DIFF-04)` — DIFF-01 is faster (single grep) and more specific than DIFF-04, so it fails first and gives clearer signal when both would fail"
  - "Scope is `libs tests examples benchmarks` — explicitly NOT `.planning/` (planning artifacts are gitignored locally) and NOT `bridge/` (bridge has Python and JS, not the deleted MATLAB classes)"
  - "Self-test exits 2 (regex bug) vs the real-scan failure mode of exit 1 (DIFF-01 regression) — distinguishes regex-drift failures from genuine policy violations"
patterns-established:
  - "DIFF-01 grep seal: `(^|[^.a-zA-Z_])(...)\\(` word-boundary lookbehind for the 8 Phase-1011 classes — cumulative v2.1 milestone seal"
requirements-completed: [DIFF-01]
duration: 2min 11s
completed: 2026-04-30
---

# Phase 1016 Plan 03: Phase-1011 Deleted-Class CI Grep Seal Summary

**Locks the v2.1 cleanup forever via a `.github/workflows/tests.yml` `lint`-job step that grep-fails CI on any re-introduction of the 8 Phase-1011 deleted classes within `libs/`, `tests/`, `examples/`, `benchmarks/`, with an inline self-test (1 hit + 3 misses) that verifies regex discrimination every CI run — silent regex drift impossible.**

## Performance

- **Duration:** 2min 11s
- **Started:** 2026-04-30T08:42:21Z
- **Completed:** 2026-04-30T08:44:32Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added named step `Phase-1011 deleted-class regression seal (DIFF-01)` to the `lint` job in `.github/workflows/tests.yml`
- Single regex covers all 8 Phase-1011 deleted classes via alternation: `(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule|Sensor|SensorRegistry|ThresholdRegistry|ExternalSensorRegistry)\(`
- Inline self-test asserts the regex flags `Sensor(` (HIT) and does NOT flag `fp.addThreshold(`, `SensorTag(`, `MonitorTag(` (3 misses) — runs before the real repo scan
- Step placed immediately after `Run complexity metrics` and immediately before `Skip-list parity gate (DIFF-04)` — adjacent to its sibling regression-prevention gate
- DIFF-01 requirement marked complete in REQUIREMENTS.md traceability

## Task Commits

1. **Task 1: Add Phase-1011 deleted-class regression seal step to .github/workflows/tests.yml lint job + self-test the regex against hit and miss cases** — `a116b0b` (ci)

**Plan metadata:** to be added below in `<final_commit>` step.

## Files Created/Modified

- `.github/workflows/tests.yml` — Added 59-line inline-bash step in the `lint` job that runs the 8-class grep seal with self-test; placed at line 146-203 between `Run complexity metrics` and `Skip-list parity gate (DIFF-04)`

## Pre-Flight Verification

```
=== Pre-flight check: real-repo regex pass ===
$ grep -rE '(^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule|Sensor|SensorRegistry|ThresholdRegistry|ExternalSensorRegistry)\(' libs tests examples benchmarks
EXIT=1   # exit 1 = no matches found = clean repo

=== Self-test (regex discrimination) ===
HIT  test (s = Sensor(...)):              FOUND 1 match (correct)
MISS test (fp.addThreshold(50)):          0 matches (correct — `.` rejected by [^.a-zA-Z_])
MISS test (s = SensorTag(...)):           0 matches (correct — no literal `Sensor(` substring)
MISS test (m = MonitorTag(...)):          0 matches (correct — class not in alternation)
MISS test (e = EventStore(...)):          0 matches (correct — class not in alternation)

=== End-to-end simulation of the CI step ===
$ bash -c '<inline step body>'
Searching for Phase-1011 deleted-class references...
Pattern: (^|[^.a-zA-Z_])(Threshold|CompositeThreshold|StateChannel|ThresholdRule|Sensor|SensorRegistry|ThresholdRegistry|ExternalSensorRegistry)\(
Scope:   libs/ tests/ examples/ benchmarks/

Regex self-test passed (1 hit + 3 misses).

DIFF-01 GATE PASSED: no Phase-1011 deleted-class re-introductions.
EXIT=0

=== YAML structural sanity ===
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/tests.yml'))"
YAML OK
```

## Decisions Made

- **Single-regex alternation over 8 separate greps.** One CI step, one log block, one exit code; failure points at one of 8 classes via the literal match in the output
- **Step ordering:** between `Run complexity metrics` and `Skip-list parity gate (DIFF-04)`. DIFF-01 is faster (single grep over 4 directories) and more specific than DIFF-04 (which compares two skip-list blocks) — when both would fail, DIFF-01 surfaces first with a clearer signal
- **Scope is `libs tests examples benchmarks`.** Excludes `.planning/` (gitignored locally; not a code path) and `bridge/` (Python + JS, not the deleted MATLAB classes). Matches REQUIREMENTS.md DIFF-01 wording exactly
- **Self-test exit code disambiguation:** regex-drift failure exits with code 2; genuine DIFF-01 regression exits with code 1. CI runners surface these as different failure messages

## Deviations from Plan

None — plan executed exactly as written. The exact regex, the exact step text, and the exact placement match the plan body verbatim. The only adjustment was a minor cosmetic improvement to the inline comment block (line-up of `# Self-test below` reference text) — folded into the same task commit.

**Total deviations:** 0
**Impact on plan:** Plan was complete and unambiguous; no auto-fixes triggered.

## Authentication Gates

None.

## Known Stubs

None — every artifact is wired end-to-end. The CI step runs the real grep against the real repo on every push, PR, and nightly schedule.

## Next Phase Readiness

Phase 1016 is now complete (3/3 plans executed). The CI grep seal locks the cumulative v2.1 cleanup. Forward to phase rollup `1016-SUMMARY.md` for milestone-level verdicts.

## Self-Check: PASSED

- `.github/workflows/tests.yml`: FOUND, contains the new step at line 146-203
- Step name `Phase-1011 deleted-class regression seal (DIFF-01)`: FOUND
- Regex with all 8 classes: FOUND
- `(^|[^.a-zA-Z_])` lookbehind idiom: FOUND
- Inline self-test (1 hit + 3 misses): FOUND
- Step adjacent to `Skip-list parity gate (DIFF-04)`: VERIFIED (lines 205-206 follow lines 146-203)
- Commit `a116b0b`: FOUND
- YAML well-formed: VERIFIED (`yaml.safe_load` parses)
- Local hit-case test (`Sensor(`): grep exit 0 ✓
- Local miss-case test (real repo): grep exit 1 ✓ (negated to 0 for the bash `if`)

---
*Phase: 1016-examples-05-events-rewrite-live-demos-ci-grep-seal*
*Plan: 03*
*Completed: 2026-04-30*
