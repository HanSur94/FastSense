# MATLAB CI Feasibility Research

**Researched:** 2026-04-16
**Domain:** GitHub Actions — MATLAB CI integration, licensing, MEX compatibility
**Confidence:** HIGH (primary sources: github.com/matlab-actions/setup-matlab releases, README, MathWorks docs)

---

## TL;DR

The repo is **public**, so `setup-matlab@v2` (or `v3`) automatically licenses MATLAB at no credential cost — no batch licensing token needed. The existing `matlab:` job in `tests.yml` (lines 194–218) already works correctly for its current scope; to run it on every push/PR requires only two changes: (1) remove the `if:` guard, and (2) add a MATLAB-specific `build-mex-matlab` job that produces `.mexa64` binaries because Octave-compiled `.mex` files are **ABI-incompatible** with MATLAB. The recommended strategy is to keep Octave as the primary push/PR gate and add MATLAB as a parallel job (not a replacement) to validate the MATLAB-specific code path (`run_matlab_suite`) and coverage reporting.

**Primary recommendation:** Add a `build-mex-matlab` job (using `setup-matlab@v3` with `cache: true`) that compiles MATLAB MEX binaries into a separate artifact, then run the MATLAB test job on every push/PR using that artifact and `FASTSENSE_SKIP_BUILD=1`. Remove `continue-on-error: true` once the job proves stable.

---

## Licensing for CI

### License Type Matrix

| License Type | Public Repo | Private Repo | Notes |
|---|---|---|---|
| Any license (individual, campus, professional) | **Auto-licensed** — no credentials needed | Needs Batch Licensing Token | MathWorks provides a hosted license for public project runner sessions |
| Batch Licensing Token | N/A (redundant for public) | Required | Request via MathWorks pilot form; still in pilot as of April 2026 |
| Network license / `MLM_LICENSE_FILE` | Works but complex | Works | Points to your org's FlexLM server; requires VPN or network exposure |
| Transformation products (MATLAB Coder, Compiler) | Always requires Batch Token | Always requires Batch Token | Even on public repos |

**This project is PUBLIC** (`gh repo view --json visibility` returns `PUBLIC`). Therefore:
- No `MLM_LICENSE_TOKEN` secret is needed.
- No `MLM_LICENSE_FILE` configuration is needed.
- `setup-matlab@v3` handles licensing transparently on all three GitHub-hosted runner OSes.

### Batch Licensing Token Status (as of April 2026)

The Batch Licensing Token ("MATLAB Batch Licensing Pilot") remains in **pilot phase** as of March 2025 documentation and the `matlab-dockerfile` alternates README. MathWorks has not announced general availability. For this project (public repo, no Coder/Compiler), the token is irrelevant.

### Concurrent Session Limits

MathWorks' hosted CI licensing (used by public repos) enforces per-job session limits. The exact concurrency cap is not documented publicly, but community reports suggest each workflow run consumes one session slot per simultaneous MATLAB job. Running MATLAB on Linux, macOS, and Windows in a matrix simultaneously would consume three slots — should be fine for a typical OSS project; exceeding limits causes startup failures (MATLAB exits with a license error).

**Confidence:** HIGH for public-repo auto-licensing; MEDIUM for concurrent session ceiling (not officially documented).

---

## matlab-actions Current State

### Action Versions (as of April 2026)

| Action | Latest Version | Notes |
|---|---|---|
| `matlab-actions/setup-matlab` | **v3.0.1** (released 2025-04-07) | Requires Node.js 24; GitHub-hosted runners support automatically |
| `matlab-actions/run-command` | v2 (current) | Runs MATLAB scripts/functions/statements |
| `matlab-actions/run-tests` | v2 (current) | Runs matlab.unittest test suite, generates artifacts |

The existing workflow uses `setup-matlab@v2` and `run-command@v2`. Both still work. Upgrading to `setup-matlab@v3` is safe on GitHub-hosted runners (Node.js 24 is available); it enables the improved cache behavior introduced in v2.6.0 (August 2024).

### Key Inputs for `setup-matlab@v3`

| Input | Default | Relevant Value for This Project |
|---|---|---|
| `release` | `latest` | Omit for latest, or pin e.g. `R2024b` |
| `products` | (none) | None needed — no toolboxes required |
| `cache` | `false` | **Set `true`** — caches MATLAB install on successful setup, saving ~2-4 min on cache hit |
| `install-system-dependencies` | `auto` | Leave as default |

### `run-command@v2`

Runs `matlab -batch "command"` under the hood. The `-batch` flag starts MATLAB non-interactively — exactly what `run_tests_with_coverage()` expects. The existing command `"addpath('scripts'); run_tests_with_coverage();"` is correct.

### Alternative: `run-tests@v2`

`matlab-actions/run-tests@v2` can run the test suite and generate JUnit XML and Cobertura coverage in one step, without a custom `run_tests_with_coverage.m`. However, since the project already has `run_tests_with_coverage.m` with fine-grained source file coverage, the existing `run-command` approach is preferable.

**Confidence:** HIGH — verified against github.com/matlab-actions/setup-matlab releases page.

---

## Platform Coverage

### GitHub-Hosted Runner Support

| Platform | Runner | MATLAB Support | Notes |
|---|---|---|---|
| Linux x86_64 | `ubuntu-latest` | Full | Best supported; fastest MATLAB install |
| macOS ARM64 | `macos-latest` | Full | Apple Silicon; requires JRE for MATLAB |
| macOS Intel | `macos-13` | Full | x86_64 legacy runner |
| Windows x86_64 | `windows-latest` | Full | GitHub-hosted only (not self-hosted) |

All three platforms work with `setup-matlab@v3` on GitHub-hosted runners. Self-hosted runners only support UNIX (Linux/macOS).

### Current Project Coverage Gap

The existing CI runs MATLAB tests **only on Linux** (ubuntu-latest). The Octave jobs cover Linux, macOS ARM64, and Windows but use the function-based `test_*.m` files, not the class-based `tests/suite/Test*.m` files. Running MATLAB tests on Linux alone gives full `run_matlab_suite()` coverage of the class-based suite — that is sufficient for a first promotion to every PR.

---

## MEX Compatibility

This is the most important technical constraint.

### The ABI Incompatibility Problem

| Compiled by | Extension | MATLAB loads it? | Octave loads it? |
|---|---|---|---|
| `mkoctfile` | `.mex` | **NO** | YES |
| MATLAB `mex()` on Linux | `.mexa64` | YES | Sometimes, but not reliable |
| MATLAB `mex()` on macOS ARM64 | `.mexmaca64` | YES | NO |
| MATLAB `mex()` on Windows | `.mexw64` | YES | NO |

The existing `build-mex` job (lines 31–61) uses Octave's `mkoctfile` and produces `.mex` files. These **cannot be loaded by MATLAB**. The existing MATLAB job (lines 194–218) therefore hits `needs_build()` at line 62 of `install.m`, finds no MATLAB-extension MEX files (`.mexa64`), and re-runs `build_mex()` from scratch every time. This explains why the MATLAB job is slow and why `FASTSENSE_SKIP_BUILD=1` is not used there.

### What `install.m` / `build_mex.m` Actually Do

`install.m:needs_build()` (lines 70–89) probes for both `binary_search_mex.mexa64` (via `mexext()`) and `binary_search_mex.mex`. The logic at line 87–89 is:
```matlab
core_ok = exist(probes{1}, 'file') == 3 || exist(probes{2}, 'file') == 3;
```
Under MATLAB on Linux, `mexext()` returns `mexa64`, so `probes{1}` is `binary_search_mex.mexa64` and `probes{2}` is `binary_search_mex.mex`. If neither exists, `needs_build()` returns true.

`build_mex.m:compile_mex()` (lines 236–295) correctly branches on `exist('OCTAVE_VERSION', 'builtin')`:
- **Octave path:** uses `mkoctfile --mex` → produces `.mex`
- **MATLAB path:** uses `mex()` with `CFLAGS`/`COMPFLAGS` → produces `.mexa64` / `.mexmaca64` / `.mexw64`

**Conclusion:** `build_mex.m` already supports MATLAB's `mex` command fully. No code changes are needed.

### Cache Key Requirements

The Octave MEX cache key in the workflow is:
```
mex-linux-${{ hashFiles('libs/FastSense/private/mex_src/**', 'libs/FastSense/build_mex.m') }}
```

A MATLAB MEX cache must use a **different cache key** (e.g., `mex-matlab-linux-...`) and cache `.mexa64` files, not `.mex` files. Otherwise the Octave and MATLAB caches would collide and corrupt each other.

### `FASTSENSE_SKIP_BUILD=1` Under MATLAB

`needs_build()` in `install.m` (line 72–75) checks `getenv('FASTSENSE_SKIP_BUILD')` first and returns `false` immediately if the variable is non-empty. This works identically in MATLAB and Octave. Setting `FASTSENSE_SKIP_BUILD: "1"` in the MATLAB job environment will correctly skip `build_mex()` — **provided the MATLAB-compiled `.mexa64` files have been downloaded from the artifact first**.

---

## Cost / Runtime

### Estimated Job Duration (Linux ubuntu-latest)

| Step | First Run (no cache) | Cached Run |
|---|---|---|
| `setup-matlab@v3` install | ~3–5 min | ~30–90 sec |
| MATLAB MEX compilation (9 files) | ~1–2 min | ~5 sec (with `FASTSENSE_SKIP_BUILD=1`) |
| `run_tests_with_coverage()` | ~1–2 min | ~1–2 min |
| **Total** | **~5–9 min** | **~2–4 min** |

These are community-reported estimates for MATLAB CI jobs (not officially benchmarked by MathWorks). Octave jobs typically take ~1–2 min total on the same runner after the `build-mex` artifact download.

### Cost for Public Repos

GitHub-hosted runner minutes are **free for public repositories** on standard runners (`ubuntu-latest`, `macos-latest`, `windows-latest`). Adding a MATLAB job to every push/PR has zero monetary cost for this project.

### macOS runner cost note

macOS runners consume 10x the minute multiplier for **private** repos. Since this repo is public, this is irrelevant, but worth knowing if repo visibility ever changes.

---

## Workflow Diff

Below is the minimal diff to enable MATLAB on every push/PR with a proper MEX build.

### Step 1: Add `build-mex-matlab` job (after the existing `build-mex` job, around line 61)

```yaml
  build-mex-matlab:
    name: Build MEX (MATLAB Linux)
    if: github.event_name != 'schedule'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v3
        with:
          cache: true

      - name: Cache MATLAB MEX binaries
        id: cache-mex-matlab
        uses: actions/cache@v5
        with:
          path: |
            libs/FastSense/private/*.mexa64
            libs/SensorThreshold/private/*.mexa64
            libs/FastSense/mksqlite.mexa64
          key: mex-matlab-linux-${{ hashFiles('libs/FastSense/private/mex_src/**', 'libs/FastSense/build_mex.m') }}

      - name: Compile MEX files (MATLAB)
        if: steps.cache-mex-matlab.outputs.cache-hit != 'true'
        uses: matlab-actions/run-command@v2
        with:
          command: "install();"

      - name: Upload MATLAB MEX artifacts
        uses: actions/upload-artifact@v7
        with:
          name: mex-matlab-linux
          path: |
            libs/FastSense/private/*.mexa64
            libs/SensorThreshold/private/*.mexa64
            libs/FastSense/mksqlite.mexa64
          retention-days: 1
```

### Step 2: Replace the existing `matlab:` job (lines 194–219)

Replace the current job with:

```yaml
  matlab:
    name: MATLAB Tests
    needs: build-mex-matlab
    if: github.event_name != 'schedule'   # removed schedule-only gate
    runs-on: ubuntu-latest
    # continue-on-error: true             # remove once job proves stable (suggest 2-week trial)
    env:
      FASTSENSE_SKIP_BUILD: "1"
    steps:
      - uses: actions/checkout@v6

      - name: Setup MATLAB
        uses: matlab-actions/setup-matlab@v3
        with:
          cache: true

      - name: Download MATLAB MEX binaries
        uses: actions/download-artifact@v8
        with:
          name: mex-matlab-linux

      - name: Run tests with coverage
        uses: matlab-actions/run-command@v2
        with:
          command: "addpath('scripts'); run_tests_with_coverage();"

      - name: Upload coverage to Codecov
        if: always()
        uses: codecov/codecov-action@v4
        with:
          files: coverage.xml
          flags: matlab
          fail_ci_if_error: false
        env:
          CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### What changed and why

| Change | Reason |
|---|---|
| Added `build-mex-matlab` job | Produces `.mexa64` binaries distinct from Octave's `.mex` — required for MATLAB to load MEX files |
| `needs: build-mex-matlab` on matlab job | Ensures MATLAB MEX artifacts exist before tests run |
| Removed `if: github.event_name == 'schedule' \|\| github.event_name == 'workflow_dispatch'` | Enables job on every push/PR |
| Added `FASTSENSE_SKIP_BUILD: "1"` | Tells `install.m` to skip `build_mex()` since MEX files are pre-downloaded |
| `setup-matlab@v2` → `@v3` | Picks up improved caching (v2.6.0+) and latest Node.js runtime |
| `cache: true` on setup-matlab | Avoids 3–5 min MATLAB install on every run after first cache hit |
| Kept `continue-on-error: true` commented out | Suggested 2-week trial period; remove it permanently once flakiness is assessed |

---

## Recommendation

**Enable MATLAB on every push/PR using a separate `build-mex-matlab` job + updated `matlab` job.**

The repo is public, so licensing is completely free and requires zero credentials. The single blocking technical issue — MEX ABI incompatibility — is resolved by adding a dedicated MATLAB MEX build job. `build_mex.m` already handles MATLAB's `mex()` command correctly; no source changes are required.

**Do NOT replace Octave.** Keep Octave as the primary gate because:
1. The codebase explicitly targets "GNU Octave 7+ fully supported" — removing it would break that guarantee.
2. Octave tests (`test_*.m`) cover different code paths than MATLAB tests (`tests/suite/Test*.m`). Both sets run.
3. Octave tests catch Octave-specific regressions (the `break_closure_cycles` workaround is still needed as of Octave 11 based on recent quick task 260416-hau).

**Recommended CI topology after change:**

```
push/PR triggers:
  lint              → always
  build-mex         → Octave .mex (Linux, cached)
  octave            → needs build-mex
  build-mex-matlab  → MATLAB .mexa64 (Linux, cached)
  matlab            → needs build-mex-matlab   ← NEW: now on every push
  mex-build-macos   → Octave .mex ARM64 (verify only)
  mex-build-windows → Octave .mex Windows (verify only)

schedule (weekly):
  (nothing MATLAB-specific; the regular push run covers it)
```

**Migration path:**

1. Apply the YAML diff above.
2. On first push after the change, `build-mex-matlab` will run `install()` without `FASTSENSE_SKIP_BUILD`, compile `.mexa64` files, cache them, and upload them as an artifact. Expect ~5–9 min total for the first run.
3. Subsequent runs: MATLAB setup uses the cache (~30–90 sec), MEX files skip compilation (cache hit), tests run (~1–2 min). Total: ~2–4 min.
4. After 2 weeks of stable runs, remove `continue-on-error: true` from the matlab job so failures actually block merges.

---

## What Could Go Wrong

### 1. MEX artifact path mismatch
**Risk:** The `download-artifact` step places files in the workspace root, not `libs/FastSense/private/`. If the artifact path structure doesn't match the expected directory, `needs_build()` won't find the `.mexa64` files and will re-run compilation.
**Mitigation:** Verify artifact paths on first run; use `find libs -name '*.mexa64'` as a debug step. The `copy_mex_to()` call in `build_mex.m` (line 229–233) copies shared files to `SensorThreshold/private/` at compile time — the upload step must capture those too (the diff above includes them).

### 2. MATLAB startup failure due to concurrent session limit
**Risk:** If many contributors push simultaneously and each run spawns a MATLAB job, MathWorks' hosted license pool may exhaust. MATLAB will print a license error and exit non-zero.
**Mitigation:** GitHub queues concurrent jobs; the effective concurrency for a typical OSS project is low. If this becomes a real problem, add `concurrency: { group: matlab-ci, cancel-in-progress: false }` to the matlab job.

### 3. `setup-matlab@v3` vs `@v2` on self-hosted runners
**Risk:** v3 requires Node.js 24, which is not on older self-hosted runners. The project has no self-hosted runners in CI so this is not an immediate concern.
**Mitigation:** If a self-hosted runner is added later, pin to `setup-matlab@v2` for it.

### 4. MATLAB version mismatch with Xcode/compiler on macOS
**Risk:** If MATLAB CI is later extended to macOS, MATLAB's bundled Clang must match the system Xcode CLT. Setup-matlab handles system dependencies on GitHub-hosted runners (`install-system-dependencies: auto`), but version mismatch errors have been reported in community forums after macOS runner upgrades.
**Mitigation:** Pin `release: R2024b` (or current stable) rather than using `latest` when adding macOS MATLAB jobs, to avoid surprise upgrades.

### 5. `jit_warmup()` failure in headless MATLAB
**Risk:** `install.m:jit_warmup()` (lines 179–228) calls `figure('Visible', 'off')` and `axes()`. On Linux CI runners, MATLAB's `-batch` flag typically supports offscreen rendering, but if the display setup is wrong it may silently fail (the try/catch at line 225 absorbs errors).
**Mitigation:** Already mitigated by the existing try/catch. No action needed.

### 6. `run_tests_with_coverage()` exits non-zero on any test failure
**Risk:** `run_tests_with_coverage.m` calls `error('Tests failed: %d', nFailed)` (line 38). MATLAB `-batch` propagates this as a non-zero exit code, which will fail the CI step correctly. But if the test runner itself crashes (not a test failure), the coverage XML may not be written and the Codecov upload will silently skip.
**Mitigation:** The `if: always()` guard on the Codecov step handles this. Consider adding a step to assert `coverage.xml` exists before the upload step if coverage reporting accuracy matters.

### 7. Cache thrash from MEX source changes
**Risk:** Any change to `libs/FastSense/private/mex_src/**` or `build_mex.m` invalidates both the Octave and MATLAB caches, requiring full recompilation on the next run.
**Mitigation:** Expected behavior; not a bug. MEX compilation is fast (~1–2 min), so cache misses are acceptable.

---

## Sources

### Primary (HIGH confidence)
- `github.com/matlab-actions/setup-matlab` (README + releases page) — licensing model, platform support, v3.0.1 release notes, cache: true behavior
- `tests/run_all_tests.m` (this repo, read directly) — MATLAB vs Octave dispatch, `run_matlab_suite()` uses `matlab.unittest`
- `libs/FastSense/build_mex.m` (this repo, read directly) — MATLAB `mex()` branch, `mkoctfile` branch, `.mexa64` extension via `mexext()`
- `install.m` (this repo, read directly) — `needs_build()` probes both `.mexa64` and `.mex`, `FASTSENSE_SKIP_BUILD` check
- `.github/workflows/tests.yml` (this repo, read directly) — existing job structure

### Secondary (MEDIUM confidence)
- `github.com/mathworks-ref-arch/matlab-dockerfile/blob/main/alternates/non-interactive/MATLAB-BATCH.md` — batch token still in pilot as of 2025
- WebSearch: MathWorks batch licensing pilot form references — confirms pilot status, no GA announcement found
- WebSearch: setup-matlab v2.6.0 cache improvement (August 2024) — caches on successful setup, not only on job completion

### Tertiary (LOW confidence)
- Community estimates for MATLAB startup time (3–5 min without cache, 30–90 sec with cache) — not officially benchmarked by MathWorks
- Concurrent session limit for MathWorks hosted CI licensing — not documented publicly; based on community reports

**Research date:** 2026-04-16
**Valid until:** ~2026-07-16 (setup-matlab releases frequently; re-verify if major version bump occurs)
