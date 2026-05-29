---
phase: quick
plan: 260416-jnp
type: execute
wave: 1
depends_on: []
files_modified:
  - .github/workflows/_build-mex-octave.yml
  - .github/workflows/tests.yml
  - .github/workflows/examples.yml
  - .github/workflows/benchmark.yml
autonomous: true
requirements:
  - QUICK-260416-jnp
must_haves:
  truths:
    - "A single reusable workflow .github/workflows/_build-mex-octave.yml defines the Octave 8.4.0 build-mex job for Linux"
    - "tests.yml, examples.yml, and benchmark.yml each reference the reusable workflow via `uses:` instead of inlining 30+ lines of steps"
    - "The `if: github.event_name != 'schedule'` guard remains on the caller-side in tests.yml"
    - "Each caller produces a uniquely-named artifact (mex-linux, mex-linux-examples, mex-linux-bench) so downstream consumers keep working"
    - "Downstream jobs (octave, smoke-test, benchmark) still resolve `needs: build-mex` because caller job names are unchanged"
    - "All 4 workflow YAML files parse as valid YAML"
  artifacts:
    - path: .github/workflows/_build-mex-octave.yml
      provides: "Reusable Octave MEX build workflow with artifact-name input"
      contains: "workflow_call"
    - path: .github/workflows/tests.yml
      provides: "Tests workflow with build-mex now delegating to reusable workflow"
      contains: "uses: ./.github/workflows/_build-mex-octave.yml"
    - path: .github/workflows/examples.yml
      provides: "Examples workflow with build-mex now delegating to reusable workflow"
      contains: "uses: ./.github/workflows/_build-mex-octave.yml"
    - path: .github/workflows/benchmark.yml
      provides: "Benchmark workflow with build-mex now delegating to reusable workflow"
      contains: "uses: ./.github/workflows/_build-mex-octave.yml"
  key_links:
    - from: .github/workflows/tests.yml
      to: .github/workflows/_build-mex-octave.yml
      via: "uses: ./.github/workflows/_build-mex-octave.yml with artifact-name: mex-linux"
      pattern: "uses:\\s*\\./.github/workflows/_build-mex-octave\\.yml"
    - from: .github/workflows/examples.yml
      to: .github/workflows/_build-mex-octave.yml
      via: "uses: ./.github/workflows/_build-mex-octave.yml with artifact-name: mex-linux-examples"
      pattern: "mex-linux-examples"
    - from: .github/workflows/benchmark.yml
      to: .github/workflows/_build-mex-octave.yml
      via: "uses: ./.github/workflows/_build-mex-octave.yml with artifact-name: mex-linux-bench"
      pattern: "mex-linux-bench"
    - from: "octave (tests.yml), smoke-test (examples.yml), benchmark (benchmark.yml)"
      to: "caller job named build-mex in each workflow"
      via: "needs: build-mex"
      pattern: "needs:\\s*build-mex"
---

<objective>
DRY refactor: extract the duplicated Octave `build-mex` job (currently inlined 3× across `tests.yml`, `examples.yml`, `benchmark.yml`) into a single reusable workflow at `.github/workflows/_build-mex-octave.yml`, and replace the 3 inline duplicates with `workflow_call` references.

Purpose: eliminate ~60-70 lines of duplication, single source of truth for Octave MEX compilation, easier future maintenance (changing Octave version, cache key, or artifact paths touches one file).

Output: 1 new reusable workflow file + 3 caller workflows with inline `build-mex` jobs replaced by ~5-line `uses:` references. Net reduction ~20-30 lines.

Scope fence (do NOT touch):
- MATLAB jobs: `build-mex-matlab`, `matlab`, `matlab-examples`
- `lint`, `mex-build-macos`, `mex-build-windows`
- `release.yml`, `install.m`, `build_mex.m`, any `.m` files
- Do NOT generalize to `build-mex-matlab` (only 1 caller — premature abstraction)
- Do NOT rename caller jobs — keep them as `build-mex:` so `needs: build-mex` references resolve
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@CLAUDE.md
@.github/workflows/tests.yml
@.github/workflows/examples.yml
@.github/workflows/benchmark.yml

<interfaces>
<!-- GitHub Actions constraints to honor — critical for correctness -->

1. Reusable workflow jobs CANNOT have `timeout-minutes`, `runs-on`, `container`, `steps`, or `env` alongside `uses:` in the caller. The reusable workflow itself owns those. The caller's job with `uses:` may ONLY carry: `name`, `if`, `needs`, `with`, `secrets`, `permissions`, `strategy` (matrix).

2. Downstream `needs: build-mex` resolves correctly — caller jobs stay named `build-mex`.

3. Artifacts uploaded inside a reusable workflow ARE visible to downstream caller jobs via `actions/download-artifact@v8` because artifacts live at the workflow-run level. No special plumbing needed.

4. The `if: github.event_name != 'schedule'` guard on tests.yml's build-mex MUST remain on the caller (not the reusable), because reusable workflows don't meaningfully evaluate event context for this.

5. The `_` filename prefix is a convention marking the workflow as internal/reusable; not required by GitHub but a clear signal.

<!-- Current inline job shape (all 3 callers are structurally identical apart from the artifact name): -->

```yaml
build-mex:
  name: Build MEX (Linux)            # examples.yml + benchmark.yml use "Build MEX" (no "(Linux)")
  timeout-minutes: 20
  if: github.event_name != 'schedule'  # tests.yml ONLY
  runs-on: ubuntu-latest
  container: gnuoctave/octave:8.4.0
  steps:
    - uses: actions/checkout@v6
    - name: Cache MEX binaries
      id: cache-mex
      uses: actions/cache@v5
      with:
        path: |
          libs/FastSense/private/*.mex
          libs/SensorThreshold/private/*.mex
          libs/FastSense/mksqlite.mex
        key: mex-linux-${{ hashFiles('libs/FastSense/private/mex_src/**', 'libs/FastSense/build_mex.m') }}
    - name: Compile MEX files
      if: steps.cache-mex.outputs.cache-hit != 'true'
      run: octave --eval "install();"
    - name: Upload MEX artifacts
      uses: actions/upload-artifact@v7
      with:
        name: <mex-linux | mex-linux-examples | mex-linux-bench>  # only thing that varies
        path: |
          libs/FastSense/private/*.mex
          libs/SensorThreshold/private/*.mex
          libs/FastSense/mksqlite.mex
        retention-days: 1
```

<!-- Target reusable workflow contract: -->

```yaml
# .github/workflows/_build-mex-octave.yml
name: Reusable — Build Octave MEX (Linux)

on:
  workflow_call:
    inputs:
      artifact-name:
        description: Name for the uploaded MEX artifact (must be unique per caller workflow)
        type: string
        required: false
        default: mex-linux

jobs:
  build-mex:
    name: Build MEX (Linux)
    timeout-minutes: 20
    runs-on: ubuntu-latest
    container: gnuoctave/octave:8.4.0
    steps:
      - uses: actions/checkout@v6
      - name: Cache MEX binaries
        id: cache-mex
        uses: actions/cache@v5
        with:
          path: |
            libs/FastSense/private/*.mex
            libs/SensorThreshold/private/*.mex
            libs/FastSense/mksqlite.mex
          key: mex-linux-${{ hashFiles('libs/FastSense/private/mex_src/**', 'libs/FastSense/build_mex.m') }}
      - name: Compile MEX files
        if: steps.cache-mex.outputs.cache-hit != 'true'
        run: octave --eval "install();"
      - name: Upload MEX artifacts
        uses: actions/upload-artifact@v7
        with:
          name: ${{ inputs.artifact-name }}
          path: |
            libs/FastSense/private/*.mex
            libs/SensorThreshold/private/*.mex
            libs/FastSense/mksqlite.mex
          retention-days: 1
```

<!-- Target caller shape (strip everything that conflicts with `uses:`): -->

```yaml
# tests.yml — KEEP the `if:` guard on the caller
build-mex:
  name: Build MEX (Linux)
  if: github.event_name != 'schedule'
  uses: ./.github/workflows/_build-mex-octave.yml
  with:
    artifact-name: mex-linux

# examples.yml
build-mex:
  name: Build MEX
  uses: ./.github/workflows/_build-mex-octave.yml
  with:
    artifact-name: mex-linux-examples

# benchmark.yml
build-mex:
  name: Build MEX
  uses: ./.github/workflows/_build-mex-octave.yml
  with:
    artifact-name: mex-linux-bench
```
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create reusable workflow `.github/workflows/_build-mex-octave.yml`</name>
  <files>.github/workflows/_build-mex-octave.yml</files>
  <action>
    Create a NEW file at `.github/workflows/_build-mex-octave.yml` with the exact content shown in the `<interfaces>` block above (the "Target reusable workflow contract" YAML).

    Key points:
    - Top-level `on: workflow_call:` with a single `inputs.artifact-name` (type: string, required: false, default: mex-linux).
    - Single job `build-mex` with `name: Build MEX (Linux)`, `timeout-minutes: 20`, `runs-on: ubuntu-latest`, `container: gnuoctave/octave:8.4.0`.
    - Steps are a verbatim copy of the current inline job (checkout@v6, cache@v5, compile with `octave --eval "install();"`, upload-artifact@v7 with `name: ${{ inputs.artifact-name }}`, retention-days: 1).
    - Cache key remains `mex-linux-${{ hashFiles('libs/FastSense/private/mex_src/**', 'libs/FastSense/build_mex.m') }}` (unchanged across all 3 callers, so no need to parametrize).
    - Artifact paths are the same three globs across all 3 callers (no need to parametrize).
    - Do NOT add an `if:` at the job level — that guard stays in the caller.
    - Do NOT add push/pull_request triggers — only `workflow_call`.

    Use the Write tool to create the file. Preserve 2-space YAML indentation consistent with the other workflows in the repo.
  </action>
  <verify>
    <automated>python3 -c "import yaml; d=yaml.safe_load(open('.github/workflows/_build-mex-octave.yml')); assert 'workflow_call' in d.get(True, d.get('on', {})) or 'workflow_call' in (d.get(True) or {}) or 'workflow_call' in (d.get('on') or {}); assert 'build-mex' in d['jobs']; assert d['jobs']['build-mex']['container'] == 'gnuoctave/octave:8.4.0'; print('OK')"</automated>
  </verify>
  <done>
    - File `.github/workflows/_build-mex-octave.yml` exists and is valid YAML.
    - Contains `on: workflow_call:` with `artifact-name` input.
    - Contains a `build-mex` job with container `gnuoctave/octave:8.4.0` and the 4 expected steps (checkout, cache, compile, upload).
    - Upload step uses `name: ${{ inputs.artifact-name }}`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Replace inline `build-mex` jobs in tests.yml, examples.yml, benchmark.yml with workflow_call references</name>
  <files>.github/workflows/tests.yml, .github/workflows/examples.yml, .github/workflows/benchmark.yml</files>
  <action>
    Use the Edit tool on each of the 3 caller workflows. For each, replace the ENTIRE inline `build-mex:` job block (from the `build-mex:` line through the last line of the `Upload MEX artifacts` step, i.e. the `retention-days: 1` line) with the thin `uses:` caller block shown in the interfaces section above.

    **File 1: `.github/workflows/tests.yml`**
    - Currently lines 36-67 (the `build-mex:` job, starting `build-mex:\n    name: Build MEX (Linux)\n    timeout-minutes: 20\n    if: github.event_name != 'schedule'\n    runs-on: ubuntu-latest\n    container: gnuoctave/octave:8.4.0\n    steps:` through `retention-days: 1`).
    - Replace with:
      ```yaml
        build-mex:
          name: Build MEX (Linux)
          if: github.event_name != 'schedule'
          uses: ./.github/workflows/_build-mex-octave.yml
          with:
            artifact-name: mex-linux
      ```
    - CRITICAL: preserve the `if: github.event_name != 'schedule'` on the caller (it must NOT move into the reusable).
    - Do NOT change `lint`, `build-mex-matlab`, `octave`, `mex-build-macos`, `mex-build-windows`, or `matlab` jobs.
    - Leave `needs: build-mex` on the `octave` job untouched — it still resolves.

    **File 2: `.github/workflows/examples.yml`**
    - Currently lines 17-47 (the `build-mex:` job through `retention-days: 1`).
    - Replace with:
      ```yaml
        build-mex:
          name: Build MEX
          uses: ./.github/workflows/_build-mex-octave.yml
          with:
            artifact-name: mex-linux-examples
      ```
    - No `if:` guard needed (original didn't have one).
    - Do NOT change `smoke-test` or `matlab-examples` jobs.
    - Leave `needs: build-mex` on `smoke-test` untouched.

    **File 3: `.github/workflows/benchmark.yml`**
    - Currently lines 18-48 (the `build-mex:` job through `retention-days: 1`).
    - Replace with:
      ```yaml
        build-mex:
          name: Build MEX
          uses: ./.github/workflows/_build-mex-octave.yml
          with:
            artifact-name: mex-linux-bench
      ```
    - No `if:` guard needed.
    - Do NOT change the `benchmark` job.
    - Leave `needs: build-mex` on `benchmark` untouched.

    Indentation: all 3 callers use 2-space YAML with the `jobs:` children indented by 2 spaces (so the `build-mex:` line is at column 3 / 2 spaces in). Match existing file style exactly.

    After editing, confirm no caller-side `uses:` block carries `timeout-minutes`, `runs-on`, `container`, `steps`, or `env` keys (those are illegal alongside `uses:` and would cause workflow validation errors).
  </action>
  <verify>
    <automated>python3 -c "
import yaml
files = ['.github/workflows/tests.yml', '.github/workflows/examples.yml', '.github/workflows/benchmark.yml', '.github/workflows/_build-mex-octave.yml']
for f in files:
    yaml.safe_load(open(f))
# Confirm all 3 callers now reference the reusable
for f in ['.github/workflows/tests.yml', '.github/workflows/examples.yml', '.github/workflows/benchmark.yml']:
    d = yaml.safe_load(open(f))
    bm = d['jobs']['build-mex']
    assert bm.get('uses') == './.github/workflows/_build-mex-octave.yml', f'{f}: build-mex not using reusable workflow'
    # Confirm no illegal keys alongside uses:
    for illegal in ('timeout-minutes', 'runs-on', 'container', 'steps', 'env'):
        assert illegal not in bm, f'{f}: build-mex still has illegal key {illegal!r} alongside uses:'
# Confirm tests.yml preserves the if: guard
tests = yaml.safe_load(open('.github/workflows/tests.yml'))
assert tests['jobs']['build-mex'].get('if') == \"github.event_name != 'schedule'\", 'tests.yml lost the schedule guard'
# Confirm artifact names per caller
assert yaml.safe_load(open('.github/workflows/tests.yml'))['jobs']['build-mex']['with']['artifact-name'] == 'mex-linux'
assert yaml.safe_load(open('.github/workflows/examples.yml'))['jobs']['build-mex']['with']['artifact-name'] == 'mex-linux-examples'
assert yaml.safe_load(open('.github/workflows/benchmark.yml'))['jobs']['build-mex']['with']['artifact-name'] == 'mex-linux-bench'
print('OK')
"</automated>
  </verify>
  <done>
    - All 4 workflow YAML files parse as valid YAML.
    - Each of tests.yml, examples.yml, benchmark.yml has a `build-mex:` job that uses `./.github/workflows/_build-mex-octave.yml` with the correct `artifact-name` input.
    - None of the 3 caller `build-mex:` blocks carry `timeout-minutes`, `runs-on`, `container`, `steps`, or `env` (all illegal alongside `uses:`).
    - tests.yml's `build-mex:` still carries `if: github.event_name != 'schedule'`.
    - `needs: build-mex` references on downstream jobs (octave, smoke-test, benchmark) remain intact.
    - Untouched: lint, build-mex-matlab, matlab, mex-build-macos, mex-build-windows, matlab-examples, smoke-test, benchmark job bodies.
  </done>
</task>

</tasks>

<verification>
Run all three verification commands after both tasks complete:

```bash
# 1. All 4 workflow files parse as YAML
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/tests.yml', '.github/workflows/examples.yml', '.github/workflows/benchmark.yml', '.github/workflows/_build-mex-octave.yml']]; print('YAML OK')"

# 2. All 3 downstream consumers still reference `needs: build-mex`
grep -n 'needs: build-mex' .github/workflows/tests.yml .github/workflows/examples.yml .github/workflows/benchmark.yml
# Expect at minimum:
#   tests.yml:    `octave` job with `needs: build-mex`
#   examples.yml: `smoke-test` job with `needs: build-mex`
#   benchmark.yml: `benchmark` job with `needs: build-mex`

# 3. Confirm download-artifact names line up per caller
grep -A1 'download-artifact' .github/workflows/tests.yml | grep -E 'name: mex-linux($| )'        # expect: name: mex-linux
grep -A1 'download-artifact' .github/workflows/examples.yml | grep 'mex-linux-examples'           # expect: name: mex-linux-examples
grep -A1 'download-artifact' .github/workflows/benchmark.yml | grep 'mex-linux-bench'             # expect: name: mex-linux-bench

# 4. Net line reduction sanity-check (informational, not blocking)
wc -l .github/workflows/_build-mex-octave.yml .github/workflows/tests.yml .github/workflows/examples.yml .github/workflows/benchmark.yml
```

Optional (if `actionlint` is installed): `actionlint .github/workflows/*.yml` — should pass with no errors about the new reusable workflow.
</verification>

<success_criteria>
- `.github/workflows/_build-mex-octave.yml` exists, parses as YAML, declares `on: workflow_call:` with `artifact-name` input, and contains a `build-mex` job with the Octave 8.4.0 container + 4 steps (checkout, cache, compile, upload).
- `tests.yml`, `examples.yml`, `benchmark.yml` each have a `build-mex:` job that is a thin `uses:` caller referencing `./.github/workflows/_build-mex-octave.yml` with a unique `artifact-name`.
- `tests.yml`'s build-mex retains `if: github.event_name != 'schedule'`.
- No caller-side `build-mex:` job carries `timeout-minutes`, `runs-on`, `container`, `steps`, or `env` alongside `uses:`.
- Downstream jobs (`octave`, `smoke-test`, `benchmark`) still resolve `needs: build-mex` (job name unchanged).
- Artifact names per caller unchanged: `mex-linux`, `mex-linux-examples`, `mex-linux-bench` — so existing `download-artifact` steps keep working.
- Net line count decreases (~20-30 lines removed across the 4 files).
- Untouched: MATLAB jobs, lint, macOS/Windows MEX builds, release.yml, install.m, build_mex.m, all .m files.
</success_criteria>

<output>
After completion, create `.planning/quick/260416-jnp-dry-refactor-extract-duplicated-octave-b/260416-jnp-SUMMARY.md` documenting:
- Files touched (paths + brief "what changed")
- Line delta (before/after)
- Any GitHub Actions constraints encountered during the edit
- Commit hash
</output>
