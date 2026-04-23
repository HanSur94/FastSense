# Phase 1013 — CONTEXT

**Phase:** Ship prebuilt MEX binaries for macOS, Windows, Linux so end users skip compilation
**Created:** 2026-04-22
**Status:** Ready for planning

## Domain

Ship the project so `install()` does not compile C code on a fresh end-user machine. After `git clone`, MATLAB or Octave users on the supported platforms load prebuilt MEX binaries directly. Build-on-first-run stays as a fallback for uncovered platforms and for contributors editing C sources.

Scope is packaging/distribution only. No changes to the MEX C sources, kernel behavior, or public MATLAB API.

## Canonical refs

- [install.m](install.m) — current build-on-first-run entry point (`needs_build`, `first_run`, `FASTSENSE_SKIP_BUILD` env)
- [libs/FastSense/build_mex.m](libs/FastSense/build_mex.m) — MEX compile orchestration
- [libs/FastSense/private/mex_src/](libs/FastSense/private/mex_src/) — C sources that define the source-hash stamp input
- [.github/workflows/_build-mex-octave.yml](.github/workflows/_build-mex-octave.yml) — existing reusable Octave-Linux build (template for expansion)
- [.github/workflows/tests.yml](.github/workflows/tests.yml), [benchmark.yml](.github/workflows/benchmark.yml), [examples.yml](.github/workflows/examples.yml), [release.yml](.github/workflows/release.yml) — callers of `_build-mex-octave.yml`, need matrix expansion
- [.gitignore](.gitignore) — currently excludes `*.mex*`; this phase narrows that rule
- [.planning/STATE.md](.planning/STATE.md) — Quick task 260404-gaj ("CI MEX build matrix: macOS ARM64, Windows 10+11, Linux Ubuntu") is the CI precursor

## Decisions

### Distribution

**Binaries are committed to the repo.**
Under the existing `libs/**/private/` and `libs/FastSense/` locations, filename suffix = MATLAB `mexext()` value (e.g. `binary_search_mex.mexmaca64`, `mksqlite.mexw64`). No release-asset fetch, no network on install. Expected repo growth: ~5–10 MB per platform × ~8 MEX files × 4 MATLAB + 3 Octave builds (one-time + occasional refresh).

### Platform matrix (must ship)

MATLAB:
- macOS ARM64 — `.mexmaca64` (primary dev target)
- macOS x86_64 — `.mexmaci64` (Intel Macs on R2023b and earlier)
- Windows x86_64 — `.mexw64`
- Linux x86_64 — `.mexa64`

Octave (all three OSes):
- Linux x86_64
- macOS ARM64 (or universal if build machine permits)
- Windows x86_64

Octave `.mex` files collide by extension across platforms — ship them under platform-tagged subdirectories (`libs/FastSense/private/octave-<platform>/`) and let `install.m` prepend the right one to `path` when `exist('OCTAVE_VERSION','builtin')` is true. MATLAB binaries live alongside sources in `private/` because `mexext()` disambiguates them automatically.

### Staleness check

CI emits a `.mex-version` stamp file next to the binaries containing the hash of `libs/**/mex_src/**` + `libs/FastSense/build_mex.m`. `install.m`:
1. If a binary for the current `mexext()` is missing → rebuild.
2. If `.mex-version` hash does not match the current sources → rebuild.
3. Otherwise trust the shipped binary and skip compilation.

This means contributors editing C sources get an automatic rebuild on next `install()`, while end users who never touch the C sources always hit the fast path.

### Fallback

Current build-on-first-run logic stays. If the shipped binary is missing, stamp mismatches, or `mex`-level load fails, `install.m` falls back to `build_mex()` exactly as today. `FASTSENSE_SKIP_BUILD=1` continues to force the skip for cached-CI scenarios.

### CI flow

A new workflow auto-commits refreshed binaries when MEX sources change on `main`:
- Trigger: push to `main` touching `libs/**/mex_src/**` or `build_mex.m`, plus `workflow_dispatch`.
- Matrix: `macos-14` (ARM), `macos-13` (Intel), `windows-latest`, `ubuntu-latest` for MATLAB; Octave Linux/macOS/Windows for Octave.
- MATLAB builds use `matlab-actions/setup-matlab@v2` (free online batch license for public repos).
- Each runner compiles, verifies, uploads an artifact.
- A final job downloads all artifacts, generates `.mex-version`, commits to a `chore/refresh-mex-binaries` branch, opens/updates a PR. Maintainer merges.

Existing `_build-mex-octave.yml` is refactored/extended to cover all three Octave OSes; test/benchmark/release workflows consume the same artifacts rather than rebuilding.

### Runners

`matlab-actions/setup-matlab` on GitHub-hosted runners for all MATLAB builds. No self-hosted infra. Public-repo MATLAB online batch licensing is sufficient; verify availability of Apple-Silicon MATLAB on `macos-14` at planning time and pick the oldest-still-supported MATLAB release for widest binary compatibility.

### .gitignore

Current blanket `*.mex*` exclusion is removed; replaced with a narrower pattern that keeps shipped binaries tracked while still ignoring any stray `.mex*` produced outside the `private/` and `libs/FastSense/mksqlite.*` locations (or explicitly un-ignore the exact shipped paths).

## Assumptions

- MATLAB online batch license on GitHub-hosted runners covers all MEX compilation needs here (no Toolbox dependencies in the C sources — confirmed by existing build_mex.m).
- Apple Silicon MATLAB runner (`macos-14` + setup-matlab) is available as of today; if not, macOS ARM binary continues to be built from the maintainer's dev machine until CI catches up.
- No symbol-versioning issues across glibc on Linux: building on `ubuntu-latest` gives a binary usable on reasonably current Linux distros. If glibc drift becomes an issue, switch to a manylinux-style container (deferred).
- `.mex-version` file lives next to binaries in `private/`. Untracked changes to C sources on a contributor's machine will trigger local rebuild without committing the stamp.

## Deferred ideas

- GitHub Release asset fallback for shallow clones. Not needed now; revisit if repo growth from committed binaries becomes painful.
- Linux ARM64 / Raspberry Pi target. Not in current user base.
- Per-widget/per-kernel selective rebuild in `install.m` (today it rebuilds all on any hash mismatch). Low value.
- Signing / notarization of macOS binaries. Not required until Gatekeeper starts rejecting them.
- Release-tagged immutable binaries alongside per-commit refresh. Add only if stale-on-main becomes a recurring complaint.

## Non-goals

- Changing MEX kernel behavior, perf, or semantics.
- Packaging the project as a MATLAB Toolbox (`.mltbx`) or File Exchange entry — orthogonal distribution channel.
- Eliminating the local build path entirely — fallback is explicitly kept.

## Success criteria (sketch, planner refines)

1. Fresh clone on each of {macOS ARM, macOS Intel, Windows, Linux} × {MATLAB, Octave} runs `install(); run_all_tests();` green without invoking a compiler.
2. Editing any C source in `libs/**/mex_src/**` and running `install()` triggers a rebuild (stamp mismatch) — verified by test.
3. CI auto-PR refreshes binaries when MEX sources change on `main`; green merge leaves `main` with matching sources and binaries.
4. `FASTSENSE_SKIP_BUILD=1` still short-circuits as today.
5. Repo size growth stays within 1 order of magnitude of current (measure and report at PR time).
