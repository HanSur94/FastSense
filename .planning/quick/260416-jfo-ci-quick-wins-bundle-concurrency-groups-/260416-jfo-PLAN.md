---
phase: 260416-jfo-ci-quick-wins
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/tests.yml
  - .github/workflows/examples.yml
  - .github/workflows/benchmark.yml
  - .github/dependabot.yml
autonomous: true
requirements:
  - CI-CONCURRENCY
  - CI-TIMEOUTS
  - CI-MATLAB-EXAMPLES-ON-PUSH
  - CI-STEP-SUMMARIES
  - CI-DEPENDABOT
must_haves:
  truths:
    - "Pushing a new commit to an open PR cancels the prior in-flight run of tests.yml/examples.yml/benchmark.yml"
    - "Every job in tests.yml, examples.yml, benchmark.yml has a timeout-minutes cap (no job can hang indefinitely)"
    - "The matlab-examples job runs on every push and pull_request (not just schedule/workflow_dispatch)"
    - "The matlab-examples job uses matlab-actions/setup-matlab@v3 with cache: true"
    - "Octave tests job writes a 'Passed/Failed' line to the GitHub Step Summary panel"
    - "MATLAB tests job writes a completion line to the GitHub Step Summary panel"
    - "Octave examples smoke-test job writes a '<passed>/<total>' line to the GitHub Step Summary panel"
    - "MATLAB examples job appends its fprintf summary to the GitHub Step Summary panel"
    - "Dependabot opens weekly PRs for github-actions updates, labeled 'dependencies' + 'github-actions'"
    - "All four YAML files are syntactically valid (parse with yaml.safe_load)"
  artifacts:
    - path: .github/workflows/tests.yml
      provides: "top-level concurrency block + timeout-minutes on every job + step-summary steps for octave & matlab jobs"
      contains: "concurrency:"
    - path: .github/workflows/examples.yml
      provides: "top-level concurrency block + timeout-minutes + matlab-examples on push/PR + setup-matlab@v3 cache + step summaries"
      contains: "concurrency:"
    - path: .github/workflows/benchmark.yml
      provides: "top-level concurrency block + timeout-minutes on benchmark job"
      contains: "concurrency:"
    - path: .github/dependabot.yml
      provides: "weekly github-actions dependency updates"
      contains: "package-ecosystem: \"github-actions\""
  key_links:
    - from: .github/workflows/tests.yml (octave job)
      to: $GITHUB_STEP_SUMMARY
      via: "post-test bash step reading /tmp/test-results.txt"
      pattern: "GITHUB_STEP_SUMMARY"
    - from: .github/workflows/examples.yml (matlab-examples job)
      to: "push + pull_request triggers"
      via: "removal of schedule/workflow_dispatch guard on job"
      pattern: "matlab-actions/setup-matlab@v3"
---

<objective>
Apply six small, low-risk CI workflow improvements in one atomic plan:
concurrency groups, per-job timeouts, matlab-examples on every push/PR,
GitHub Step Summary blocks, and a Dependabot config for github-actions.

Purpose: Cut wasted runner minutes (concurrency), prevent zombie jobs
(timeouts), surface pass/fail counts at a glance (step summaries),
keep MATLAB examples exercised on every change (not just nightly),
and stay on top of action version bumps (Dependabot).

Output: 3 modified workflow files + 1 new dependabot.yml + this plan's SUMMARY.md
documenting the Octave-Codecov skip rationale.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md
@.github/workflows/tests.yml
@.github/workflows/examples.yml
@.github/workflows/benchmark.yml
@.planning/quick/260416-j6e-enable-matlab-ci-on-every-push-pr-upgrad/260416-j6e-SUMMARY.md

<interfaces>
<!-- Anchors the executor must target exactly. Verified against current files. -->

tests.yml structure (current HEAD):
  - Trigger block: `on:` with push (main) + pull_request (main) — at top
  - Jobs: `lint`, `build-mex` (Octave linux matrix), `test` (Octave test runner), `matlab` (matlab-actions/setup-matlab + run_tests_with_coverage.m), `mex-build-macos`, `mex-build-windows`
  - Octave test job writes `/tmp/test-results.txt` in format "PASSED FAILED" (space-separated). Existing step at ~line 140: `Run tests (Octave)` using `xvfb-run`. Insert step-summary step immediately after.
  - MATLAB job uses `matlab-actions/run-command@v2` with `run('scripts/run_tests_with_coverage.m')`. That script calls `exit(1)` on failure, so a post-step cannot read pass/fail counts easily. Use simplest option (c): step-summary step writes "MATLAB test run completed — see job log for details", guarded by `if: always()`.

examples.yml structure (current HEAD):
  - Jobs: `build-mex` (Octave, linux matrix), `smoke-test` (Octave examples via bash loop exporting $PASSED/$TOTAL/$FAIL_LIST), `matlab-examples` (currently gated with `if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'`)
  - The smoke-test bash loop ends by echoing failures. Append step-summary writes INSIDE the same run: block, before it exits, so $PASSED/$TOTAL are still in scope.
  - The matlab-examples job uses `matlab-actions/setup-matlab@v2` and runs an inline MATLAB script that fprintfs per-example results. Append to step summary from inside that MATLAB script by opening getenv('GITHUB_STEP_SUMMARY') for append.

benchmark.yml structure (current HEAD):
  - Single `benchmark` job. Add timeout-minutes: 60.

run_all_tests.m returns struct: `results.passed` (int), `results.failed` (int). Octave CI reads these and writes "PASSED FAILED" to /tmp/test-results.txt.

Concurrency block to insert (identical in all 3 workflows, AFTER `on:` block, BEFORE `jobs:`):
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add concurrency blocks + timeout-minutes to all three workflows</name>
  <files>.github/workflows/tests.yml, .github/workflows/examples.yml, .github/workflows/benchmark.yml</files>
  <action>
    For EACH of the three workflow files, make two edits:

    (a) Insert a top-level `concurrency:` block between the `on:` block and the `jobs:` block. Use EXACTLY this YAML (same in all three files — per scope item 1):
    ```yaml
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
      cancel-in-progress: true
    ```

    (b) Add `timeout-minutes:` to EVERY job in each workflow. Place `timeout-minutes:` as the first key of each job (above `runs-on:`). Use these values (from scope item 2):

    tests.yml:
      - lint: 10
      - build-mex (Octave linux matrix): 20
      - test (Octave test job): 45
      - matlab: 45
      - mex-build-macos: 20
      - mex-build-windows: 30

    examples.yml:
      - build-mex: 20
      - smoke-test: 45
      - matlab-examples: 60

    benchmark.yml:
      - benchmark: 60

    If a job name in the file differs from the list above, match by function (e.g., an Octave-on-Linux build job == build-mex for timeout purposes). Do NOT touch release.yml, generate-docs.yml, generate-wiki.yml, sync-wiki.yml, or wiki-links.yml.

    Per D-scope: This is a pure metadata change — do NOT modify any `steps:`, `run:`, or env in this task. Step-summary edits are Task 3's job. matlab-examples trigger + v3 upgrade is Task 2's job.
  </action>
  <verify>
    <automated>python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/tests.yml', '.github/workflows/examples.yml', '.github/workflows/benchmark.yml']]; print('yaml ok')" && grep -c '^concurrency:' .github/workflows/tests.yml .github/workflows/examples.yml .github/workflows/benchmark.yml && grep -c 'timeout-minutes:' .github/workflows/tests.yml .github/workflows/examples.yml .github/workflows/benchmark.yml</automated>
  </verify>
  <done>
    - All three files parse as valid YAML.
    - Each of tests.yml, examples.yml, benchmark.yml has exactly one top-level `concurrency:` block matching the canonical form.
    - Every job in all three workflows has a `timeout-minutes:` key at the job level.
    - No `steps:` content changed in this task.
  </done>
</task>

<task type="auto">
  <name>Task 2: Enable matlab-examples on every push/PR + upgrade to setup-matlab@v3</name>
  <files>.github/workflows/examples.yml</files>
  <action>
    Three edits to the `matlab-examples` job in examples.yml (scope item 3):

    (a) REMOVE the job-level guard line:
    ```yaml
    if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'
    ```
    So matlab-examples runs on every push and pull_request trigger (matching pattern established in quick task 260416-j6e for tests.yml matlab job). Do NOT remove the `schedule:` cron from the top-level `on:` block — the scheduled trigger stays as an additional safety-net run.

    (b) Upgrade the setup-matlab action version from `@v2` to `@v3`:
    ```yaml
    - uses: matlab-actions/setup-matlab@v3
    ```

    (c) Add the cache option directly under the setup-matlab step's `with:` block (create `with:` if absent):
    ```yaml
      with:
        cache: true
    ```

    Preserve all other keys already present on the step (products, release, etc.) if they exist.

    Do NOT modify any inline MATLAB script inside the `run-command` step in this task — that's Task 3's job (step summary append).
  </action>
  <verify>
    <automated>python3 -c "import yaml; yaml.safe_load(open('.github/workflows/examples.yml'))" && ! grep -q "if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'" .github/workflows/examples.yml && grep -q 'matlab-actions/setup-matlab@v3' .github/workflows/examples.yml && grep -A2 'setup-matlab@v3' .github/workflows/examples.yml | grep -q 'cache: true'</automated>
  </verify>
  <done>
    - examples.yml parses as valid YAML.
    - The `if: github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'` guard is gone from the matlab-examples job.
    - setup-matlab version is `@v3`.
    - `cache: true` present under the setup-matlab step's `with:`.
    - Schedule cron in the top-level `on:` block is unchanged.
  </done>
</task>

<task type="auto">
  <name>Task 3: Add GitHub Step Summary writes for all four test/example jobs</name>
  <files>.github/workflows/tests.yml, .github/workflows/examples.yml</files>
  <action>
    Add step-summary writes per scope item 5. All additions must be `if: always()` (or equivalent inline write that runs regardless of prior step success) so summaries appear on failure too.

    (A) tests.yml — octave `test` job:
    AFTER the `Run tests (Octave)` xvfb-run step (which writes `/tmp/test-results.txt` in "PASSED FAILED" format), add a new step:
    ```yaml
    - name: Write test summary
      if: always()
      shell: bash
      run: |
        if [ -f /tmp/test-results.txt ]; then
          read PASSED FAILED < /tmp/test-results.txt
          {
            echo "### Octave Tests"
            echo ""
            echo "- Passed: ${PASSED:-0}"
            echo "- Failed: ${FAILED:-0}"
          } >> "$GITHUB_STEP_SUMMARY"
        else
          echo "### Octave Tests" >> "$GITHUB_STEP_SUMMARY"
          echo "" >> "$GITHUB_STEP_SUMMARY"
          echo "_Results file not produced (test job likely crashed before completion)._" >> "$GITHUB_STEP_SUMMARY"
        fi
    ```

    (B) tests.yml — `matlab` job:
    AFTER the `matlab-actions/run-command@v2` step (which runs `run('scripts/run_tests_with_coverage.m')`), add simplest option (c) from scope:
    ```yaml
    - name: Write MATLAB test summary
      if: always()
      shell: bash
      run: |
        {
          echo "### MATLAB Tests"
          echo ""
          echo "MATLAB test run completed — see job log for details."
        } >> "$GITHUB_STEP_SUMMARY"
    ```

    (C) examples.yml — `smoke-test` job:
    INSIDE the existing bash shell block that runs the examples loop, APPEND lines at the END (while $PASSED/$TOTAL/$FAIL_LIST are still in scope — scope item 5 recommendation (i)):
    ```bash
    # --- GitHub Step Summary ---
    if [ -n "$GITHUB_STEP_SUMMARY" ]; then
      {
        echo "### Octave Example Smoke Tests"
        echo ""
        echo "- ${PASSED:-0}/${TOTAL:-0} passed"
        if [ -n "$FAIL_LIST" ]; then
          echo ""
          echo "**Failures:**"
          echo ""
          echo "$FAIL_LIST" | sed 's/^/- /'
        fi
      } >> "$GITHUB_STEP_SUMMARY"
    fi
    ```
    Place this BEFORE any `exit 1` that the script issues on failure so the summary is written even when the job fails.

    (D) examples.yml — `matlab-examples` job:
    INSIDE the inline MATLAB script that runs the examples (the same one Task 2 touched in terms of trigger/version), APPEND lines that mirror the existing fprintf summary to the step-summary file. Put this at the very end of the MATLAB script, wrapped in a try so it never masks a real failure:
    ```matlab
    try
      summaryFile = getenv('GITHUB_STEP_SUMMARY');
      if ~isempty(summaryFile)
        fid = fopen(summaryFile, 'a');
        if fid > 0
          fprintf(fid, '### MATLAB Examples\n\n');
          fprintf(fid, '- %d/%d passed\n', nPassed, nTotal);
          if nTotal - nPassed > 0 && exist('failList', 'var') && ~isempty(failList)
            fprintf(fid, '\n**Failures:**\n\n');
            for k = 1:numel(failList)
              fprintf(fid, '- %s\n', failList{k});
            end
          end
          fclose(fid);
        end
      end
    catch
      % never fail the job because of a step-summary write
    end
    ```
    Match the variable names already used in the existing MATLAB script (e.g., if it uses `passed`/`total`/`fails`, adapt accordingly — inspect the current script and reuse its exact names). Do NOT add new top-level variables; only read from what's already there.

    Do NOT change any other steps or job-level keys in this task.
  </action>
  <verify>
    <automated>python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/tests.yml', '.github/workflows/examples.yml']]; print('yaml ok')" && grep -c 'GITHUB_STEP_SUMMARY' .github/workflows/tests.yml && grep -c 'GITHUB_STEP_SUMMARY' .github/workflows/examples.yml</automated>
  </verify>
  <done>
    - Both YAML files still parse.
    - tests.yml has ≥2 occurrences of `GITHUB_STEP_SUMMARY` (one for octave, one for matlab job).
    - examples.yml has ≥2 occurrences of `GITHUB_STEP_SUMMARY` (one inside smoke-test shell block, one inside matlab-examples MATLAB script).
    - All newly added standalone shell steps are guarded by `if: always()`.
    - MATLAB step-summary append is wrapped in try/catch so a write failure cannot fail the job.
  </done>
</task>

<task type="auto">
  <name>Task 4: Create .github/dependabot.yml</name>
  <files>.github/dependabot.yml</files>
  <action>
    Create a new file at `.github/dependabot.yml` with EXACTLY this content (scope item 6):
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

    Do NOT add additional ecosystems (pip, npm, etc.) in this task — scope explicitly limits it to github-actions. If additional ecosystems are needed later, that's a separate plan.
  </action>
  <verify>
    <automated>test -f .github/dependabot.yml && python3 -c "import yaml; d = yaml.safe_load(open('.github/dependabot.yml')); assert d['version'] == 2; assert d['updates'][0]['package-ecosystem'] == 'github-actions'; assert d['updates'][0]['schedule']['interval'] == 'weekly'; print('dependabot ok')"</automated>
  </verify>
  <done>
    - `.github/dependabot.yml` exists and parses as valid YAML.
    - `version: 2`, `package-ecosystem: github-actions`, `interval: weekly`, labels include both `dependencies` and `github-actions`.
    - Commit-message prefix is `ci` with scope inclusion enabled.
  </done>
</task>

</tasks>

<verification>
Combined verify (ALL must pass before writing SUMMARY.md):

```bash
python3 -c "
import yaml
files = [
  '.github/workflows/tests.yml',
  '.github/workflows/examples.yml',
  '.github/workflows/benchmark.yml',
  '.github/dependabot.yml',
]
for f in files:
  with open(f) as fh:
    yaml.safe_load(fh)
print('All 4 YAML files parse.')
"
```

Structural spot-checks (each grep must match):
- `grep -l '^concurrency:' .github/workflows/{tests,examples,benchmark}.yml` — 3 files
- `grep -c 'timeout-minutes:' .github/workflows/{tests,examples,benchmark}.yml` — ≥1 per file (multiple for tests/examples)
- `grep 'matlab-actions/setup-matlab@v3' .github/workflows/examples.yml` — match
- `! grep "github.event_name == 'schedule' || github.event_name == 'workflow_dispatch'" .github/workflows/examples.yml` — no match on the matlab-examples job
- `grep 'GITHUB_STEP_SUMMARY' .github/workflows/tests.yml` — ≥2 matches
- `grep 'GITHUB_STEP_SUMMARY' .github/workflows/examples.yml` — ≥2 matches
- `test -f .github/dependabot.yml`
</verification>

<success_criteria>
1. All four YAML files parse with `yaml.safe_load` (Python).
2. Concurrency blocks present in tests.yml, examples.yml, benchmark.yml with the canonical `${{ github.workflow }}-${{ github.ref }}` group + `cancel-in-progress: true`.
3. Every job in those three workflows has a `timeout-minutes:` key.
4. matlab-examples job in examples.yml runs unconditionally on push/PR (no event-name guard), uses setup-matlab@v3 with `cache: true`.
5. Step summaries wire up for: octave tests, matlab tests, octave example smoke tests, matlab examples. All are `always()`-guarded or equivalent.
6. `.github/dependabot.yml` exists with the specified github-actions weekly config.
7. No changes outside the four listed files. No changes to install.m, build_mex.m, any .m source under libs/, release.yml, generate-docs.yml, generate-wiki.yml, sync-wiki.yml, or wiki-links.yml.
</success_criteria>

<output>
After completion, create `.planning/quick/260416-jfo-ci-quick-wins-bundle-concurrency-groups-/260416-jfo-SUMMARY.md` that:

1. Lists the six items, five implemented + one deferred.
2. For the deferred Octave Codecov item, explicitly states:
   > **Octave Codecov — deferred (TODO).** Octave has no Cobertura XML exporter. MATLAB's `matlab.unittest.plugins.CodeCoveragePlugin` writes Cobertura format but is MATLAB-only. No Octave equivalent exists in the core distribution, nor via a maintained Octave package. Shipping Octave coverage would require either hand-rolling an instrumentation pass over `libs/**/*.m` or porting a tool like `mcov` — both out of scope for a CI quick-wins bundle. Reconsider if/when Octave gains a Cobertura exporter upstream.
3. References the related quick task `260416-j6e` (matlab tests enabled on every push) so the chain is traceable.
4. Notes the runner-minute implications: concurrency cancellation saves duplicate runs on force-push; unguarded matlab-examples increases monthly minutes but tightens the feedback loop on example breakage.
5. Commits are created incrementally per task (ci: concurrency + timeouts, ci: matlab-examples on every push, ci: step summaries, ci: add dependabot) — but merged into one /gsd:quick submission.
</output>
