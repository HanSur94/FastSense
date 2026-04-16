# Phase 1005 — Requirements

**Goal:** Expand CI test coverage so the actual test suites (not just MEX build) run on macOS and Windows for both MATLAB and Octave, and run the performance benchmark under MATLAB too.

## Current state (as of 2026-04-16, after quick tasks j6e/jfo/jnp/k23)

- **Linux:** Full coverage — `octave` test job + `matlab` test job, both run on every push/PR. Container is `gnuoctave/octave:11.1.0`. MATLAB uses `setup-matlab@v3` with `cache: true`.
- **macOS:** Only verifies MEX compiles (`mex-build-macos` job). Octave tests never run here; MATLAB tests never run here.
- **Windows:** Only verifies MEX compiles (`mex-build-windows` job, Chocolatey Octave 9.2.0). Octave tests never run here; MATLAB tests never run here.
- **Benchmark:** Only runs under Octave on Linux. No MATLAB benchmark.
- **Reusable workflows:** `_build-mex-octave.yml` exists and is called by 3 workflows.

## Requirements

### COV-01: MATLAB Tests on macOS ARM64
New job in `.github/workflows/tests.yml`, mirroring the existing Linux `matlab` job:
- `runs-on: macos-latest` (ARM64)
- Uses `matlab-actions/setup-matlab@v3` with `cache: true`
- Needs a companion `build-mex-matlab-macos` job (new) that compiles `.mexmaca64` binaries and uploads as artifact
- Downloads the artifact, sets `FASTSENSE_SKIP_BUILD=1`
- Runs `matlab-actions/run-command@v2` with `addpath('scripts'); run_tests_with_coverage();`
- Uploads Codecov with `flags: matlab-macos` (unique per platform so dashboard separates trends)

### COV-02: MATLAB Tests on Windows
Same pattern as COV-01 but:
- `runs-on: windows-latest`
- Companion `build-mex-matlab-windows` job compiles `.mexw64`
- Flags: `matlab-windows`
- **Cost note:** Windows runners = 2x Linux cost multiplier. Consider keeping on schedule-only initially, promoting to push/PR once stable.

### COV-03: Octave Tests on macOS ARM64
New job:
- `runs-on: macos-latest`
- Installs Octave via `brew install octave` (matches existing `mex-build-macos` pattern)
- Reuses the existing `mex-build-macos` job's MEX output — either refactor `mex-build-macos` to upload an artifact (currently it just verifies the build), or add a new `build-mex-octave-macos` sibling
- Runs: `octave --eval "cd('tests'); r = run_all_tests(); exit(double(r.failed > 0));"`
- Codecov: skip (Octave has no Cobertura exporter — already documented as a deferred item in quick task 260416-jfo)

### COV-04: Octave Tests on Windows
Same pattern as COV-03 but:
- `runs-on: windows-latest`
- Installs Octave via Chocolatey (matches existing `mex-build-windows`)
- **Risk:** Octave on Windows often lacks `xvfb-run` equivalent. May need figure-less test mode, `--no-gui`, or skip plot-bearing tests. Planner should investigate if the test suite can run headless on Windows Octave — if not, this requirement may need a smaller scope (e.g., run only unit tests that don't create figures).
- Cost note: 2x Windows multiplier applies.

### COV-05: MATLAB Benchmark
New `benchmark-matlab` job in `.github/workflows/benchmark.yml`:
- Linux first (cheapest — no urgent reason to multi-platform the benchmark itself)
- Runs `scripts/run_ci_benchmark.m` under MATLAB (same script runs under Octave today — verify script is dual-runtime compatible; if not, create a MATLAB-specific equivalent)
- Feeds `benchmark-action/github-action-benchmark` with `name: FastSense Performance (MATLAB)` so MATLAB vs Octave trend lines are separate

### COV-06: Reusable Workflow Extraction (conditional)
If wave 1 creates 4+ MATLAB jobs or 3+ Octave jobs with duplicated setup, extract a `_matlab-test.yml` and/or `_octave-test.yml` reusable workflow parameterized on `runs-on`, `artifact-name`, and `codecov-flags`. If duplication is manageable, keep inline.

**Planner decision point:** Should be evaluated AFTER COV-01..COV-05 are drafted, not upfront.

## Constraints

1. **No regressions** to existing Linux coverage — all current jobs must continue to pass.
2. **Runner cost awareness** — Windows is 2x, macOS is 10x Linux cost per minute. For each new MATLAB job, planner should decide:
   - Push/PR (every commit) → highest signal, highest cost
   - Schedule (weekly) + workflow_dispatch → low cost, slower feedback
   - Recommended default: Mac/Win MATLAB start on schedule-only, graduate to push/PR after a couple weeks of stable runs
3. **Codecov flags must be unique** per platform/runtime combo so the Codecov dashboard shows separate trends:
   - `matlab` (existing Linux) → keep as-is
   - `matlab-macos` (new)
   - `matlab-windows` (new)
4. **Do not touch `install.m`, `build_mex.m`, or any `.m` source files** unless platform-specific gaps are discovered. Two known possible gaps:
   - Windows Octave figure-less test mode (COV-04)
   - Dual-runtime benchmark script (COV-05) — `scripts/run_ci_benchmark.m` may need an `if exist('OCTAVE_VERSION','builtin')` branch for MATLAB compatibility
5. **MEX caching consistency:** each new platform × runtime combo needs its own cache key. No cross-contamination between Octave `.mex` and MATLAB `.mexa64`/`.mexw64`/`.mexmaca64` — same rule that gave us the `mex-matlab-linux-` prefix in quick task 260416-j6e.

## Related context

- Quick task 260416-j6e enabled MATLAB on Linux push/PR and added `build-mex-matlab` (Linux only)
- Quick task 260416-jfo added concurrency/timeouts/Dependabot + MATLAB examples on push
- Quick task 260416-jnp extracted `_build-mex-octave.yml` reusable workflow — good foundation for COV-06
- Quick task 260416-k23 upgraded all Octave containers to 11.1.0 (fixes upstream bug #67749)
- Debug session `.planning/debug/octave-cleanup-crash-investigation.md` has the upstream bug analysis

## Next step

`/gsd:plan-phase 1005`
