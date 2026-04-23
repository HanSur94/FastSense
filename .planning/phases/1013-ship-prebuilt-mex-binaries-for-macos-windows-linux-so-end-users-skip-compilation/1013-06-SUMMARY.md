---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
plan: 06
subsystem: ci-release-packaging
tags: [ci, github-actions, mex, release, workflow]
requires: ['1013-01', '1013-02', '1013-03', '1013-04']
provides:
  - reusable-octave-workflow-honors-subdir-layout
  - ci-cache-invalidation-on-mex-version-bump
  - release-tarball-ships-committed-mex
  - macos-windows-smoke-tests-retained-and-documented
affects:
  - .github/workflows/_build-mex-octave.yml
  - .github/workflows/tests.yml
  - .github/workflows/release.yml
tech-stack:
  added: []
  patterns:
    - "stamp-file-hashed-in-cache-key"
    - "inherit-cache-config-via-workflow_call"
key-files:
  created: []
  modified:
    - .github/workflows/_build-mex-octave.yml
    - .github/workflows/tests.yml
    - .github/workflows/release.yml
decisions:
  - "benchmark.yml and examples.yml required no edits — both consume _build-mex-octave.yml via workflow_call and inherit the stamp-aware cache key automatically"
  - "Kept mex-build-macos and mex-build-windows jobs as smoke tests (not artifact producers) so a PR that breaks the compile path fails CI even after binaries are committed"
metrics:
  duration: "~2min"
  completed: "2026-04-23"
---

# Phase 1013 Plan 06: Rewire existing CI workflows to trust committed MEX binaries Summary

CI workflows and release packaging now honor committed prebuilt MEX binaries: the reusable Octave build caches the new platform-subdir layout and invalidates on stamp bumps, tests.yml mirrors the same cache-key pattern for MATLAB, benchmark.yml/examples.yml inherit the fix via `workflow_call`, and release tarballs no longer strip MEX binaries — prebuilt artifacts ship in the archive so end users skip compilation.

## Tasks Completed

| Task | Name                                                                       | Commit  | Files                                             |
| ---- | -------------------------------------------------------------------------- | ------- | ------------------------------------------------- |
| 1    | Update `_build-mex-octave.yml` artifact paths + cache key for subdir layout | 2348911 | `.github/workflows/_build-mex-octave.yml`         |
| 2    | Update `tests.yml` MATLAB cache key + smoke-test job comments              | 0e3495d | `.github/workflows/tests.yml`                     |
| 3    | Audit `benchmark.yml` + `examples.yml` — no change needed (inherited)       | (no-op) | (audit only; no local cache steps to update)      |
| 4    | Stop deleting MEX files from release tarball; update body text              | ac47f47 | `.github/workflows/release.yml`                   |
| 5    | Human-verify checkpoint (auto-approved per `workflow.auto_advance: true`)    | (n/a)   | (verification deferred to CI run on next push)    |

## Changes by File

### `.github/workflows/_build-mex-octave.yml`

- Cache `path:` and artifact `path:` now capture the new Octave platform subdirs:
  - `libs/FastSense/private/octave-linux-x86_64/*.mex`
  - `libs/FastSense/octave-linux-x86_64/*.mex`
  - `libs/SensorThreshold/private/octave-linux-x86_64/*.mex`
- Legacy flat `libs/FastSense/private/*.mex` globs retained for backward compat during rollout.
- Cache key now hashes `libs/FastSense/private/.mex-version`, so bumping the stamp invalidates the cache and forces a fresh build.
- Compile step (`install();`) unchanged; install.m's `needs_build` probe (Plan 01/03) short-circuits when a committed, stamp-matched binary is already present.

### `.github/workflows/tests.yml`

- MATLAB MEX cache key extended to hash `.mex-version` (matches Linux Octave key).
- Added header comment to `mex-build-macos` and `mex-build-windows` jobs: authoritative prebuilt binaries are produced by `refresh-mex-binaries.yml` (Plan 05); these matrix jobs are now pure smoke tests for the compile path.
- `FASTSENSE_SKIP_BUILD: "1"` env remains on all test jobs — test jobs never rebuild.
- No logic changes to octave / matlab test jobs.

### `.github/workflows/release.yml`

- Removed the `find "${DIRNAME}/libs" -type f \( -name "*.mexmaca64" ... \) -delete` block.
- `cp -r libs` now preserves committed `.mexmaca64`, `.mexmaci64`, `.mexa64`, `.mexw64`, `.mex` files.
- Release body updated: `"Prebuilt MEX binaries are bundled — compilation only happens on unsupported platforms."`
- Gate test job unchanged (still runs full Octave test suite before publishing).

### `.github/workflows/benchmark.yml` (no changes — audited)

Uses `uses: ./.github/workflows/_build-mex-octave.yml` via `workflow_call` and downloads the resulting `mex-linux-bench` artifact. Inherits the updated cache key and subdir-aware artifact paths from Task 1. No local `actions/cache` step exists.

### `.github/workflows/examples.yml` (no changes — audited)

Same pattern as benchmark.yml — calls `_build-mex-octave.yml` via `workflow_call` with `artifact-name: mex-linux-examples`. No local cache step. Inherited.

## Verification Results

### Static validation (actionlint)

- `_build-mex-octave.yml`: PASS (clean)
- `tests.yml`: PASS on our changes; 2 pre-existing shellcheck `style` hints on the unrelated `Write test summary` step (SC2129, SC2162) — out of scope
- `release.yml`: PASS on our changes; 1 pre-existing shellcheck `style` hint on the `Generate changelog` step (SC2129) — out of scope
- `benchmark.yml` + `examples.yml`: PASS (clean)
- `grep -q mexmaca64 .github/workflows/release.yml` → no match (delete block removed)

### Dynamic validation (deferred to next CI run)

Task 5 checkpoint defers end-to-end green to the human-verify step, which is auto-approved per `workflow.auto_advance: true`. Observed on next push:

1. `tests.yml::build-mex` (Linux Octave) — uses cache or rebuilds, octave tests green
2. `tests.yml::build-mex-matlab` — matlab tests green
3. `tests.yml::mex-build-macos` / `mex-build-windows` — smoke-test jobs complete
4. `release.yml` (on tag push): tarball should contain `libs/**/*.mex*` (verified via `tar tzf | grep mex`)

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed as written, with one planned no-op (Task 3).

### Notable Non-Deviations

- **actionlint not available locally** initially — installed via `brew install actionlint` (no source files changed by this; just dev-env setup). Verification then ran per plan.
- **Pre-existing shellcheck style hints** in `tests.yml` (Write test summary step) and `release.yml` (Generate changelog step) — SCOPE BOUNDARY rule applied; these are unrelated to our changes and tracked only as observations.

## Known Stubs

None. All edits are final workflow logic; no placeholder/TODO values introduced.

## Self-Check: PASSED

**Files verified on disk:**

```
FOUND: .github/workflows/_build-mex-octave.yml  (contains octave-linux-x86_64 + .mex-version)
FOUND: .github/workflows/tests.yml              (MATLAB cache key hashes .mex-version; smoke-test comments present)
FOUND: .github/workflows/release.yml            (no mexmaca64 delete block; prebuilt-bundled body text)
```

**Commits verified in git log:**

```
FOUND: 2348911  chore(1013-06): update _build-mex-octave.yml for subdir layout + stamp key
FOUND: 0e3495d  chore(1013-06): tests.yml cache key + smoke-test job comments
FOUND: ac47f47  feat(1013-06): ship committed MEX binaries in release tarball
```
