---
phase: 260416-jfo-ci-quick-wins
plan: 01
type: quick
subsystem: ci
tags: [ci, github-actions, concurrency, timeouts, step-summary, dependabot]
dependency_graph:
  requires: []
  provides: [CI-CONCURRENCY, CI-TIMEOUTS, CI-MATLAB-EXAMPLES-ON-PUSH, CI-STEP-SUMMARIES, CI-DEPENDABOT]
  affects: [.github/workflows/tests.yml, .github/workflows/examples.yml, .github/workflows/benchmark.yml, .github/dependabot.yml]
tech_stack:
  added: [dependabot (github-actions ecosystem)]
  patterns: [concurrency groups, per-job timeouts, GITHUB_STEP_SUMMARY writes]
key_files:
  created: [.github/dependabot.yml]
  modified: [.github/workflows/tests.yml, .github/workflows/examples.yml, .github/workflows/benchmark.yml]
decisions:
  - "MATLAB step-summary uses simple 'completed' message (option c) — run_tests_with_coverage.m calls exit(1) on failure so pass/fail counts are not reliably accessible from a post-step"
  - "Smoke-test step-summary written inline inside the bash run block before exit 1 so PASSED/TOTAL/FAIL_LIST are still in scope"
  - "MATLAB examples step-summary wrapped in try/catch so a write failure can never mask a real test failure"
  - "matlab-examples schedule cron retained as an additional safety-net run even after removing the job-level event guard"
metrics:
  duration: 8min
  completed_date: "2026-04-16"
  tasks: 4
  files_modified: 4
---

# Quick Task 260416-jfo: CI Quick Wins — Concurrency Groups, Timeouts, Step Summaries, Dependabot

**One-liner:** Added concurrency cancellation, per-job timeout caps, GitHub Step Summary pass/fail output for all four test/example jobs, and a Dependabot config for github-actions weekly updates.

**Related quick task:** `260416-j6e` — enabled MATLAB tests on every push/PR in tests.yml; this task extends that pattern to examples.yml and adds the remaining CI improvements.

## Items Implemented

### 1. Concurrency Groups (CI-CONCURRENCY)

Added to `tests.yml`, `examples.yml`, and `benchmark.yml`:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Runner-minute implication:** On force-push to an open PR, the prior in-flight run is cancelled immediately. This eliminates wasted minutes from redundant runs — particularly valuable for the longer Octave and MATLAB jobs (~45-60 min each).

### 2. Per-Job Timeout Caps (CI-TIMEOUTS)

Every job in all three workflows now has a `timeout-minutes:` key at the job level. No job can hang indefinitely. Values:

| Workflow | Job | timeout-minutes |
|---|---|---|
| tests.yml | lint | 10 |
| tests.yml | build-mex | 20 |
| tests.yml | octave | 45 |
| tests.yml | matlab | 45 |
| tests.yml | mex-build-macos | 20 |
| tests.yml | mex-build-windows | 30 |
| examples.yml | build-mex | 20 |
| examples.yml | smoke-test | 45 |
| examples.yml | matlab-examples | 60 |
| benchmark.yml | build-mex | 20 |
| benchmark.yml | benchmark | 60 |

### 3. MATLAB Examples on Every Push/PR (CI-MATLAB-EXAMPLES-ON-PUSH)

Removed the job-level guard from `matlab-examples` in `examples.yml`:

```yaml
# removed:
if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
```

The `schedule:` cron in the top-level `on:` block is retained as an additional safety-net run.

Also upgraded `matlab-actions/setup-matlab` from `@v2` to `@v3` and added `cache: true` for faster runner startup.

**Runner-minute implication:** matlab-examples will now run on every push and PR, increasing monthly MATLAB runner minutes. The trade-off is a tighter feedback loop — example breakage is caught in hours rather than the next weekly cron. This matches the pattern established by `260416-j6e` for the MATLAB tests job.

### 4. GitHub Step Summary Writes (CI-STEP-SUMMARIES)

Four jobs now write to `$GITHUB_STEP_SUMMARY`:

**(A) tests.yml — octave job:** New `Write test summary` step (`if: always()`) reads `/tmp/test-results.txt` and emits Passed/Failed counts as a Markdown list.

**(B) tests.yml — matlab job:** New `Write MATLAB test summary` step (`if: always()`) writes a completion notice. Pass/fail counts are not available post-step because `run_tests_with_coverage.m` calls `exit(1)` on failure — see Decisions.

**(C) examples.yml — smoke-test job:** Step-summary block appended inside the bash run block (before `exit 1`) while `$PASSED`/`$TOTAL`/`$FAIL_LIST` are still in scope. Writes `X/Y passed` with optional failure list.

**(D) examples.yml — matlab-examples job:** Step-summary MATLAB block appended at end of inline script, wrapped in `try/catch` so a write failure cannot mask a real test failure. Uses `passed`/`numel(examples)`/`failList` variables already present in the script.

### 5. Dependabot for github-actions (CI-DEPENDABOT)

Created `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    commit-message:
      prefix: "ci"
      include: "scope"
    labels:
      - "dependencies"
      - "github-actions"
```

Opens weekly PRs for github-actions version bumps, labeled `dependencies` + `github-actions`, with commit-message prefix `ci`.

## Deferred / TODO

### Octave Codecov Coverage — deferred (TODO)

**Octave Codecov — deferred (TODO).** Octave has no Cobertura XML exporter. MATLAB's `matlab.unittest.plugins.CodeCoveragePlugin` writes Cobertura format but is MATLAB-only. No Octave equivalent exists in the core distribution, nor via a maintained Octave package. Shipping Octave coverage would require either hand-rolling an instrumentation pass over `libs/**/*.m` or porting a tool like `mcov` — both out of scope for a CI quick-wins bundle. Reconsider if/when Octave gains a Cobertura exporter upstream.

## Commits

| Task | Commit | Message |
|---|---|---|
| 1 — concurrency + timeouts | `766620b` | ci(260416-jfo): add concurrency groups + timeout-minutes to all three workflows |
| 2 — matlab-examples on every push | `4ed041c` | ci(260416-jfo): enable matlab-examples on every push/PR + upgrade to setup-matlab@v3 |
| 3 — step summaries | `79f3ade` | ci(260416-jfo): add GitHub Step Summary writes for all four test/example jobs |
| 4 — dependabot | `3670dc3` | ci(260416-jfo): add dependabot.yml for weekly github-actions updates |

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

- `.github/workflows/tests.yml` — exists, parses, has concurrency block, 7 timeout entries, 5 GITHUB_STEP_SUMMARY references
- `.github/workflows/examples.yml` — exists, parses, has concurrency block, 3 timeout entries, 3 GITHUB_STEP_SUMMARY references, setup-matlab@v3 with cache, no event_name guard
- `.github/workflows/benchmark.yml` — exists, parses, has concurrency block, 2 timeout entries
- `.github/dependabot.yml` — exists, parses, version=2, github-actions weekly
