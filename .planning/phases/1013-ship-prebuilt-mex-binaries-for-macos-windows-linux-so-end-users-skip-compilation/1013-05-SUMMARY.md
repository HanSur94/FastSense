---
phase: 1013-ship-prebuilt-mex-binaries-for-macos-windows-linux-so-end-users-skip-compilation
plan: 05
subsystem: ci-mex-refresh
tags: [ci, github-actions, mex, binaries, auto-pr]
requires:
  - Plan 1013-01 (.mex-version stamp + mex_stamp.m formula)
  - Plan 1013-03 (Octave subdir routing under libs/.../octave-<tag>/)
  - Plan 1013-04 (initial macOS-ARM binaries committed)
provides:
  - 7-way platform x runtime MEX binary refresh workflow
  - Auto-PR pipeline for backfilling non-ARM platforms
affects:
  - .github/workflows/ (new workflow file only; Plan 06 owns consumer updates)
tech-stack:
  added:
    - peter-evans/create-pull-request@v7 (first use in this repo)
  patterns:
    - matrix-then-aggregator with download-artifact merge-multiple
    - stamp-formula mirror between MATLAB (mex_stamp.m) and bash (sha256sum)
key-files:
  created:
    - .github/workflows/refresh-mex-binaries.yml
  modified: []
decisions:
  - Bash stamp formula concatenates (sorted *.c)(sorted *.h)(build_mex.m)(mksqlite.c) and sha256s the concatenation — byte-for-byte parity with mex_stamp.m
  - macos-13 replaced with macos-15-intel (macos-13 retired by GitHub); R2020b bumped to R2023b on Intel job since the old image is gone (mexmaci64 still produced)
  - workflow_dispatch allowed alongside push so the first run can backfill without a source change
  - belt-and-braces actor guard `github.actor != 'github-actions[bot]'` added on every job in addition to the paths filter
metrics:
  duration: ~8 min
  completed: 2026-04-23
---

# Phase 1013 Plan 05: Refresh MEX Binaries CI Workflow Summary

New GitHub Actions workflow that rebuilds MEX on 4 MATLAB + 3 Octave runners, downloads every artifact into one workspace, regenerates `.mex-version` with the same hash formula as `mex_stamp.m`, and opens a refresh PR on `chore/refresh-mex-binaries` — automating the cross-platform backfill that Plan 04 could only do for macOS-ARM.

## What Changed

Single new file: `.github/workflows/refresh-mex-binaries.yml` (315 lines).

Structure:

| Job | Runner | Runtime | Artifact |
|---|---|---|---|
| `build-matlab` (matrix x4) | macos-14, macos-15-intel, ubuntu-22.04, windows-latest | MATLAB R2023b/R2020b | `mex-matlab-<label>` |
| `build-octave-linux` | ubuntu-22.04 + `gnuoctave/octave:11.1.0` container | Octave 11.1.0 | `mex-octave-linux-x86_64` |
| `build-octave-macos` | macos-14 + brew | Octave (latest brew) | `mex-octave-macos-arm64` |
| `build-octave-windows` | windows-latest + choco Octave 9.2.0 (mirror fallback) | Octave 9.2.0 | `mex-octave-windows-x86_64` |
| `open-refresh-pr` | ubuntu-22.04 | — | opens/updates PR |

Triggers: `push` to `main` with paths under `libs/FastSense/private/mex_src/**`, `libs/FastSense/build_mex.m`, `libs/FastSense/mksqlite.c`; plus `workflow_dispatch`.

Non-retrigger invariant: the auto-PR only touches binaries (`*.mex*`) and `.mex-version`, none of which are in the `paths` filter. Actor guard on every job (`github.actor != 'github-actions[bot]'`) is the belt-and-braces backup.

## Stamp Parity

The aggregator's bash block reproduces `mex_stamp.m` exactly:

```bash
mapfile -t c_files < <(find libs/FastSense/private/mex_src -maxdepth 1 -name '*.c' | LC_ALL=C sort)
mapfile -t h_files < <(find libs/FastSense/private/mex_src -maxdepth 1 -name '*.h' | LC_ALL=C sort)
for f in "${c_files[@]}" "${h_files[@]}" libs/FastSense/build_mex.m libs/FastSense/mksqlite.c; do
    cat "$f" >> "$tmp"
done
hex="$(sha256sum "$tmp" | awk '{print $1}')"
printf 'sha256:%s\n' "$hex" > libs/FastSense/private/.mex-version
```

Matches mex_stamp.m:
1. Non-recursive `dir(src_dir, '*.c')` sorted by name → `find -maxdepth 1 -name '*.c' | sort`.
2. Then `*.h` under the same rules.
3. Then `build_mex.m` if present.
4. Then `mksqlite.c` if present.
5. Concatenate raw bytes into one temp file; sha256 it once; prefix `sha256:`.

The plan's `find ... -o ...` one-liner was replaced because `-o` does not group or preserve the C-then-H ordering. Treated as Rule 1 (bug) — fixed silently while writing the YAML.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Stamp formula in aggregator step**
- **Found during:** Task 1 (YAML authoring)
- **Issue:** plan snippet used `find libs/FastSense/private/mex_src -name '*.c' -o -name '*.h' | sort` which does not preserve mex_stamp.m's (C first, then H) order and would drift the stamp on any repo that adds a `.h` file.
- **Fix:** split into two explicit `mapfile` reads, concatenated in the exact order mex_stamp.m enforces. Added `LC_ALL=C` for locale-stable sort.
- **File:** `.github/workflows/refresh-mex-binaries.yml` aggregator step
- **Commit:** 999ef5d

**2. [Rule 3 - Blocker] macos-13 runner retired**
- **Found during:** actionlint static check
- **Issue:** `os: macos-13` is no longer in the GitHub-hosted runner fleet (`macos-14`, `macos-15`, `macos-15-intel`, `macos-26` are available; `macos-13` is removed).
- **Fix:** swapped `macos-13` → `macos-15-intel` which still produces `mexmaci64`; bumped `R2020b` → `R2023b` on that job because `matlab-actions/setup-matlab@v3` no longer has R2020b images for `macos-15-intel`. mexext stays `mexmaci64` so no downstream consumer changes.
- **File:** `.github/workflows/refresh-mex-binaries.yml` `build-matlab` matrix entry
- **Commit:** 999ef5d

**3. [Rule 2 - Missing fortification] Windows find(1) fallback**
- **Found during:** Task 1 (YAML authoring)
- **Issue:** plan snippet used `find libs -type f -name "*.<mexext>" -delete` on Windows which relies on Git-bash being on PATH at that exact step. Safer to allow that step to continue on empty fs rather than fail the job.
- **Fix:** appended `|| true` to delete steps so a first-run clean tree (no stale binaries) does not fail; verification steps still gate correctness at the end of each build job.
- **Files:** all Delete-stale-binaries steps
- **Commit:** 999ef5d

### Auth Gates

None — no secrets required. `peter-evans/create-pull-request@v7` uses the workflow's default `GITHUB_TOKEN` via `contents: write + pull-requests: write`.

## Verification

**Automated (gate passed):**

```
$ actionlint .github/workflows/refresh-mex-binaries.yml
(no output — exit 0)
```

**End-to-end (deferred):**

The `checkpoint:human-verify` in Task 2 was auto-approved under `workflow.auto_advance: true`. Live CI dispatch and PR review must be performed by a human against the pushed branch. Expected outcome on first dispatch:

- 7 green build jobs (one per matrix row + 3 Octave).
- `open-refresh-pr` opens `chore/refresh-mex-binaries` with ~91 binary changes + `.mex-version` update.
- Merging the PR does NOT retrigger `refresh-mex-binaries.yml` (paths filter excludes `.mex*` and `.mex-version`).

Known first-run risks flagged in the plan that remain to be exercised:
- R2023b availability for `matlab-actions/setup-matlab@v3` on `macos-14` (primary runner).
- Chocolatey Octave install hitting `ftp.gnu.org` outages on Windows (mirror fallback is in place).
- Octave subdir verification assumes Plan 03's routing — already landed (`libs/FastSense/private/octave-<tag>/`).

## Known Stubs

None.

## Commits

| Task | Hash | Message |
|---|---|---|
| 1 | 999ef5d | feat(1013-05): add refresh-mex-binaries workflow with 7-platform matrix + auto-PR |

## Self-Check: PASSED

- `.github/workflows/refresh-mex-binaries.yml` exists (315 lines).
- `actionlint .github/workflows/refresh-mex-binaries.yml` → exit 0.
- Commit `999ef5d` is in `git log`.
- Stamp bash block mirrors `libs/FastSense/private/mex_stamp.m` ordering.
- `add-paths` whitelist covers all 7 platform binary sets + Octave subdirs + `.mex-version`.
