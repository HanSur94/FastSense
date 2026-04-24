# Phase 1013: Ship Prebuilt MEX Binaries — Research

**Researched:** 2026-04-22
**Domain:** MATLAB/Octave MEX binary packaging, GitHub Actions CI, git binary tracking
**Confidence:** HIGH (code read directly; CI files read directly; action versions confirmed in-repo)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Commit binaries to repo alongside sources (filename suffix = mexext()). No release-asset fetch, no network on install.
- Platform matrix: MATLAB macOS ARM64 (.mexmaca64), macOS x86_64 (.mexmaci64), Windows x86_64 (.mexw64), Linux x86_64 (.mexa64); Octave all three OSes (.mex).
- Octave binaries go under libs/**/private/octave-<platform>/ subdirs; install.m prepends the right one to path when on Octave.
- .mex-version stamp file drives rebuild decision (hash of libs/**/mex_src/** + libs/FastSense/build_mex.m).
- Fallback build-on-first-run stays; FASTSENSE_SKIP_BUILD preserved.
- CI auto-opens PR refreshing binaries when MEX-source changes on main; matlab-actions/setup-matlab on GH-hosted runners.
- .gitignore narrowed to un-ignore shipped paths.

### Claude's Discretion

- Oldest MATLAB release to pin for widest binary compatibility (must verify arm64 constraint).
- Stamp file format (plain text vs JSON, exact fields).
- Exact .gitignore replacement pattern.
- Workflow name and branch name for auto-PR.
- How the existing Octave test CI is updated to consume the new subdir layout.

### Deferred Ideas (OUT OF SCOPE)

- GitHub Release asset fallback for shallow clones.
- Linux ARM64 / Raspberry Pi.
- Per-kernel selective rebuild in install.m.
- macOS binary signing/notarization.
- Release-tagged immutable binaries alongside per-commit refresh.
</user_constraints>

---

## Summary

The project already compiles MEX on nine source files (eight kernels in `private/mex_src/` plus `mksqlite.c`) and currently has `*.mex*` in `.gitignore` so no binary is tracked. The local dev machine already has `.mexmaca64` (MATLAB ARM) and `.mex` (Octave ARM) binaries present and git-ignored.

The CI in `tests.yml` already has: a Linux Octave build via `_build-mex-octave.yml`, a Linux MATLAB build via `matlab-actions/setup-matlab@v3`, macOS Octave verification (`mex-build-macos`), and Windows Octave verification (`mex-build-windows`). None of the macOS/Windows jobs upload artifacts or commit anything — they only verify compilation works. A new dedicated workflow must be added that builds all seven platform×runtime combinations, collects artifacts, generates the stamp, and opens a PR.

The critical MATLAB ARM64 constraint is: **setup-matlab installs Intel MATLAB on ARM runners for releases before R2023b.** To produce native `.mexmaca64` on `macos-14`, the workflow must request R2023b or later. All other platforms can stay at R2020b (the project's stated minimum).

**Primary recommendation:** Build a new `refresh-mex-binaries.yml` workflow that produces all platform artifacts in a matrix, then a collect-and-PR job assembles them. Update `.gitignore`, `install.m`, and `_build-mex-octave.yml`. Update `release.yml` to stop deleting committed binaries.

---

## 1. MEX Source Inventory (Research Question 1)

**File:** `libs/FastSense/build_mex.m` — definitive list (lines 130–141, 144).

| Source file | Output name | Output location | Notes |
|---|---|---|---|
| `private/mex_src/binary_search_mex.c` | `binary_search_mex` | `private/` | No extra sources |
| `private/mex_src/minmax_core_mex.c` | `minmax_core_mex` | `private/` | No extra sources |
| `private/mex_src/lttb_core_mex.c` | `lttb_core_mex` | `private/` | No extra sources |
| `private/mex_src/violation_cull_mex.c` | `violation_cull_mex` | `private/` | No extra sources |
| `private/mex_src/compute_violations_mex.c` | `compute_violations_mex` | `private/` | No extra sources |
| `private/mex_src/resolve_disk_mex.c` | `resolve_disk_mex` | `private/` | + `sqlite3.c` bundled |
| `private/mex_src/build_store_mex.c` | `build_store_mex` | `private/` | + `sqlite3.c` bundled |
| `private/mex_src/to_step_function_mex.c` | `to_step_function_mex` | `private/` | No extra sources |
| `mksqlite.c` (root of FastSense) | `mksqlite` | `libs/FastSense/` | + `sqlite3.c` bundled |

After compilation, `build_mex.m` lines 231–235 copy four files to `libs/SensorThreshold/private/`:
- `violation_cull_mex`
- `compute_violations_mex`
- `resolve_disk_mex`
- `to_step_function_mex`

**Total files per platform: 13** (8 in FastSense/private + 4 in SensorThreshold/private + 1 mksqlite).

Both `sqlite3.c` and `sqlite3.h` live in `private/mex_src/` and are compiled inline — no system SQLite required.

---

## 2. build_mex.m Contract (Research Question 2)

**Source:** `libs/FastSense/build_mex.m` (read in full).

Key behaviours:

- **Atomic loop:** Compiles all 9 MEX files in sequence; no selective-rebuild flag. Each file is individually skipped if the target `.mexEXT` or `.mex` already exists (lines 158–163, 202–205). So "rebuild only stale" is implicit: CI artifacts placed before `install()` cause skipping.
- **Compiler per runtime:**
  - MATLAB: always uses MATLAB's configured compiler (`mex`). On Windows, MSVC. On macOS, Xcode Clang. Compiler cannot be overridden — `CC=` prefix is dead for MATLAB path.
  - Octave: prefers Homebrew GCC (searched via `find_gcc()`), falls back to system default.
- **SIMD flags by arch:**
  - `arm64`: `-O3 -ffast-math` (Clang) or `-O3 -mcpu=apple-m3 -ftree-vectorize -ffast-math` (GCC/Octave).
  - `x86_64`: `-O3 -mavx2 -mfma -ftree-vectorize -ffast-math`, SSE2 fallback on compile error.
  - Windows MSVC: `/O2 /arch:AVX2 /fp:fast`.
- **Env vars honored:** `FASTSENSE_SKIP_BUILD` (checked in `install.m needs_build`, not in `build_mex.m` itself).
- **build_mex.m does NOT read** `FASTSENSE_SKIP_BUILD` — the guard is entirely in `needs_build` (install.m:72).

**Notable:** the `mcpu=apple-m3` flag in build_mex.m is hardcoded to M3 specifically. Binaries built with this flag will run on M1/M2/M3 (NEON is universal ARM), but MATLAB's Clang path uses just `-O3 -ffast-math` which is safer.

---

## 3. install.m Internals (Research Question 3)

**Source:** `install.m` (read in full).

### needs_build (lines 70–85)

```matlab
function yes = needs_build(root)
    if ~isempty(getenv('FASTSENSE_SKIP_BUILD'))
        yes = false; return;
    end
    mex_dir = fullfile(root, 'libs', 'FastSense', 'private');
    probes = {
        fullfile(mex_dir, ['binary_search_mex.' mexext()])
        fullfile(mex_dir, 'binary_search_mex.mex')
    };
    core_ok = exist(probes{1}, 'file') == 3 || exist(probes{2}, 'file') == 3;
    yes = ~core_ok;
end
```

**Current probe logic:** Checks for `binary_search_mex.mexEXT` (MATLAB) OR `binary_search_mex.mex` (Octave flat). Uses `exist(..., 'file') == 3` (MEX file type). Returns `true` (needs build) when neither exists.

**Stamp check insertion point:** After the `FASTSENSE_SKIP_BUILD` check, before the binary existence probe. Logic becomes:
1. `FASTSENSE_SKIP_BUILD` → skip.
2. Binary for current `mexext()` is missing → rebuild (same as now).
3. `.mex-version` hash mismatches current source hash → rebuild.
4. Otherwise → trust shipped binary.

**Octave detection:** `exist('OCTAVE_VERSION', 'builtin')` — used in build_mex.m lines 68, 261. install.m does not currently distinguish Octave. The new Octave path-prepend logic in install.m needs `isOctave = exist('OCTAVE_VERSION', 'builtin')`.

**Path-adds for Octave platform binaries:** Must be inserted before the `needs_build(root)` call, so the probes in `needs_build` (which use `mexext()`) will find the platform binary. On Octave, `mexext()` returns `'mex'`, so the probe `binary_search_mex.mex` already works if the octave-platform dir is on the path — but since `private/` is a special MATLAB/Octave folder, the subdir `private/octave-linux-x86_64/` is NOT automatically searched. **An explicit `addpath` for the octave platform subdir is required.**

---

## 4. Octave Path Handling (Research Question 4)

**Confirmed:** Octave's `mexext()` returns `'mex'` on ALL platforms (Linux, macOS, Windows). This is documented in Octave 4.x through 11.x — it never varies. Source: GNU Octave docs, confirmed across versions.

**Consequence:** All three Octave platforms produce identically-named `*.mex` files. The files must be stored in separate subdirectories to coexist in the same repo checkout.

**Private directory semantics:** Both MATLAB and Octave treat `private/` as a special directory accessible to functions in the parent directory without being on the general path. A subdir of `private/` (e.g., `private/octave-linux-x86_64/`) has NO special meaning — it is NOT automatically searched.

**Required pattern in install.m:**

```matlab
% After addpath(fullfile(root, 'libs', 'FastSense')):
isOctave = exist('OCTAVE_VERSION', 'builtin');
if isOctave
    octPlatDir = octave_platform_dir(root);  % returns platform string
    % Prepend so octave-platform/ .mex files shadow any stale private/ ones
    if ~isempty(octPlatDir) && isfolder(octPlatDir)
        addpath(octPlatDir);
    end
end
```

**Platform tag derivation from `computer('arch')`:**

| Octave `computer('arch')` return | Proposed platform tag | Directory name |
|---|---|---|
| Contains `aarch64` or `arm64` AND contains `darwin` | `macos-arm64` | `octave-macos-arm64` |
| Contains `x86_64` AND contains `darwin` | `macos-x86_64` | `octave-macos-x86_64` |
| Contains `x86_64` AND contains `linux` | `linux-x86_64` | `octave-linux-x86_64` |
| Contains `x86_64` AND contains `mingw` or `w64` | `windows-x86_64` | `octave-windows-x86_64` |

**CRITICAL: `private/` subdir vs `private/` itself.** If we put Octave binaries in `private/octave-linux-x86_64/`, we must `addpath` that dir. The existing CI octave test job (`needs: build-mex`) currently downloads into `libs/FastSense/private/*.mex` (flat). After migration, the workflow must download into `libs/FastSense/private/octave-linux-x86_64/*.mex`, or the octave test job must `addpath` the subdir manually. The stamp check in `needs_build` probes for `binary_search_mex.mex` — with the subdir on path, `exist('binary_search_mex.mex', 'file') == 3` will still find it (MATLAB/Octave `exist` searches the path for MEX). Confirmed safe.

**Alternative considered:** Use `@<arch>` subdirectory convention (Octave does support package subdirs with `@ClassName`). But `@arch` convention is for class directories, not platform binaries. Reject — use explicit `addpath` instead. HIGH confidence.

---

## 5. matlab-actions/setup-matlab Capability Matrix (Research Question 5)

**Source:** GitHub repo README, release notes for v2.2.0 and v3.0.x, confirmed in-repo usage.

**Current repo version:** `matlab-actions/setup-matlab@v3` (v3.0.1 as of April 2026).

| Runner | MATLAB release | Extension produced | Notes |
|---|---|---|---|
| `ubuntu-latest` | R2020b+ | `.mexa64` | Works, used in current CI |
| `macos-13` (Intel) | R2020b+ | `.mexmaci64` | Works |
| `macos-14` (ARM64) | **R2023b+** | `.mexmaca64` | Native ARM. **Pre-R2023b installs Intel MATLAB via Rosetta — produces `.mexmaci64`, NOT `.mexmaca64`.** |
| `macos-14` (ARM64) | R2020b–R2023a | `.mexmaci64` | Rosetta Intel — wrong extension for ARM users |
| `windows-latest` | R2020b+ | `.mexw64` | Works, MSVC |

**Key constraint:** To ship a genuine `.mexmaca64` from CI, must use **R2023b or later on `macos-14`**. The CONTEXT.md says "pick oldest-still-supported for widest binary compatibility" — but for ARM this is R2023b, not R2020b.

**Recommended release matrix:**

| Platform | Runner | MATLAB release | Rationale |
|---|---|---|---|
| macOS ARM64 | `macos-14` | R2023b | Minimum for native `.mexmaca64` |
| macOS Intel | `macos-13` | R2020b | Oldest supported, widest compat |
| Linux x86_64 | `ubuntu-latest` | R2020b | Same as current CI |
| Windows x86_64 | `windows-latest` | R2020b | Oldest supported |

**Licensing:** Public repos get automatic online batch licensing for all products except transformation products (MATLAB Coder, MATLAB Compiler). MEX compilation requires no transformation products — the online license is sufficient. HIGH confidence (confirmed in action README).

**JRE on ARM runners:** The setup-matlab action documentation notes JRE must be installed for ARM macOS. GitHub's `macos-14` runner includes JRE. No extra step needed in workflow.

**macos-13 availability:** `macos-13` is an Intel runner still available as of 2026-04-22. GitHub has not EOL'd it yet. Verify at planning time if still listed as available.

---

## 6. Existing CI Workflow Structure (Research Question 6)

### _build-mex-octave.yml (reusable, Linux only)

```
Trigger: workflow_call (caller passes artifact-name)
Runner: ubuntu-latest, container gnuoctave/octave:11.1.0
Steps:
  1. checkout
  2. cache MEX (key: mex-linux-{hash of mex_src + build_mex.m})
  3. compile: octave --eval "install();"  [if cache miss]
  4. upload-artifact (*.mex from FastSense/private, SensorThreshold/private, mksqlite.mex)
     artifact retention: 1 day
```

**Callers:** `tests.yml` (build-mex job, artifact-name: mex-linux), `benchmark.yml` (artifact-name: mex-linux-bench), `examples.yml` (artifact-name: mex-linux-examples).

### tests.yml jobs

| Job | Dependencies | What it does |
|---|---|---|
| `lint` | none | MISS_HIT style+lint+metric |
| `build-mex` | none | Calls `_build-mex-octave.yml`, artifact: `mex-linux` |
| `build-mex-matlab` | none | MATLAB R2020b on ubuntu, uploads `mex-matlab-linux` artifact |
| `octave` | `build-mex` | Downloads `mex-linux`, runs Octave tests with `FASTSENSE_SKIP_BUILD=1` |
| `mex-build-macos` | none | Octave on `macos-latest` (ARM), **no artifact upload**, no FASTSENSE_SKIP_BUILD=1 |
| `mex-build-windows` | none | Octave on `windows-2022`+`windows-latest`, **no artifact upload** |
| `matlab` | `build-mex-matlab` | Downloads `mex-matlab-linux`, MATLAB tests with `FASTSENSE_SKIP_BUILD=1` |

**Gap analysis:** `mex-build-macos` and `mex-build-windows` verify Octave compilation but do NOT produce artifacts and do NOT have MATLAB variants. The new refresh workflow must fill all gaps.

### benchmark.yml, examples.yml

Use `_build-mex-octave.yml` for MEX then run on Linux only. No change needed for this phase unless we want to also test on macOS (out of scope per deferred items).

### release.yml

Current "Package release" step (lines 59–67): copies `libs/` into the release archive, then explicitly deletes all MEX files (`*.mexmaca64`, `*.mexmaci64`, `*.mexa64`, `*.mexw64`, `*.mex`). **This delete step must be removed** so committed binaries are included in release archives. LOW risk: end users who download archives get the binaries and skip compilation.

---

## 7. .gitignore Surgery (Research Question 7)

**Current .gitignore (lines 1–5):**

```
*.mexmaci64
*.mexmaca64
*.mexa64
*.mexw64
*.mex
```

These are plain filename globs (no leading `/` or path component). Per git documentation: "It is not possible to re-include a file if a parent directory of that file is excluded." Since these rules match FILES (not directories), negation patterns for specific file paths WORK.

**Verified:** `git check-ignore -v libs/FastSense/private/binary_search_mex.mexmaca64` returns `.gitignore:2:*.mexmaca64` — the rule is line 2, filename-only glob. Negation with a path-prefixed pattern overrides it.

**Replacement strategy (two options):**

**Option A — Negate specific paths (narrowest):**
Remove the five `*.mex*` rules. Replace with:

```gitignore
# Ignore MEX binaries everywhere except committed prebuilt locations
*.mexmaci64
*.mexmaca64
*.mexa64
*.mexw64
*.mex

# Un-ignore committed MATLAB prebuilts
!libs/FastSense/private/*.mexmaci64
!libs/FastSense/private/*.mexmaca64
!libs/FastSense/private/*.mexa64
!libs/FastSense/private/*.mexw64
!libs/FastSense/mksqlite.mexmaci64
!libs/FastSense/mksqlite.mexmaca64
!libs/FastSense/mksqlite.mexa64
!libs/FastSense/mksqlite.mexw64
!libs/SensorThreshold/private/*.mexmaci64
!libs/SensorThreshold/private/*.mexmaca64
!libs/SensorThreshold/private/*.mexa64
!libs/SensorThreshold/private/*.mexw64

# Un-ignore committed Octave prebuilts (platform subdirs)
!libs/FastSense/private/octave-linux-x86_64/*.mex
!libs/FastSense/private/octave-macos-arm64/*.mex
!libs/FastSense/private/octave-macos-x86_64/*.mex
!libs/FastSense/private/octave-windows-x86_64/*.mex
!libs/FastSense/octave-linux-x86_64/mksqlite.mex
!libs/FastSense/octave-macos-arm64/mksqlite.mex
!libs/FastSense/octave-macos-x86_64/mksqlite.mex
!libs/FastSense/octave-windows-x86_64/mksqlite.mex
!libs/SensorThreshold/private/octave-linux-x86_64/*.mex
!libs/SensorThreshold/private/octave-macos-arm64/*.mex
!libs/SensorThreshold/private/octave-macos-x86_64/*.mex
!libs/SensorThreshold/private/octave-windows-x86_64/*.mex
```

**Option B — Remove blanket ignore, use path-specific ignore (cleaner):**
Remove the five blanket rules. Replace with rules that ignore stray mex files outside known locations. This is harder to write correctly and creates risk of accidentally tracking mex files built during dev outside the designated locations. Option A is recommended.

**IMPORTANT:** git negation with `!` requires that the negation pattern appears AFTER the ignoring pattern in the file. In Option A the `!` lines follow the `*.mex*` lines. This is correct.

**IMPORTANT for Octave subdirs:** git does not allow re-including a file if a DIRECTORY ancestor is ignored. The `private/` directory itself is NOT ignored (only `*.mex*` files are). The `octave-linux-x86_64/` subdirectory inside `private/` is also not ignored. Therefore negation for files inside `private/octave-linux-x86_64/` works correctly. HIGH confidence.

---

## 8. Stamp File Format (Research Question 8)

### Hashing approach

**Recommended: use `git hash-object` (shell-side in CI) and a pure-MATLAB fallback using file sizes+dates.**

`git hash-object` is always available in any CI environment with a git checkout. It produces a stable SHA-1 for file contents. In CI the stamp is generated by a shell script and committed — no MATLAB-side hashing needed for CI.

For the MATLAB-side check in `install.m`, reading the committed stamp and comparing against a freshly computed hash of the sources requires either:
- `system()` call to `git hash-object` (available on developer machines)
- `system()` call to `shasum -a 256` / `sha256sum` / `Get-FileHash`
- Pure MATLAB: `dir()` on all source files → concat sizes+mtimes → no external tool needed

**Recommended stamp format (plain text):**

```
# FastSense MEX source hash
# Generated by CI on <date>
build_mex_hash: <sha256 of build_mex.m>
sources_hash: <sha256 of concatenated mex_src/*.c files, sorted>
```

The `sources_hash` field is a single hash of all mex source file contents concatenated in sorted filename order. This avoids per-file listing complexity.

In CI (shell):
```bash
find libs/FastSense/private/mex_src -name '*.c' | sort | xargs cat | sha256sum | cut -d' ' -f1
sha256sum libs/FastSense/build_mex.m | cut -d' ' -f1
```

In MATLAB `install.m` (to read and compare):
```matlab
function h = source_hash(root)
    src_dir = fullfile(root, 'libs', 'FastSense', 'private', 'mex_src');
    d = sort_struct(dir(fullfile(src_dir, '*.c')));
    blob = '';
    for i = 1:numel(d)
        fid = fopen(fullfile(src_dir, d(i).name), 'r');
        blob = [blob, fread(fid, inf, 'uint8=>char')'];
        fclose(fid);
    end
    % Cross-platform: use system sha256sum / shasum / certutil
    % Fallback: use file sizes+dates as proxy
```

**Simpler alternative:** Store the hash of `hashFiles(...)` as GitHub Actions computes it (same formula as the cache key in `_build-mex-octave.yml`). But that formula is not reproducible outside Actions. Reject.

**Simplest workable approach:** Store a single `sha256` string. Name the file `.mex-version`. Location: `libs/FastSense/private/.mex-version` (next to the binaries). The stamp is committed alongside the binaries. `install.m` reads it, computes the current hash on-the-fly, and compares.

**MATLAB portable hash without system():**
```matlab
function h = compute_source_fingerprint(root)
    % Use file modification times and sizes as fingerprint (good enough for developer workflow)
    src_dir = fullfile(root, 'libs', 'FastSense', 'private', 'mex_src');
    bm_file = fullfile(root, 'libs', 'FastSense', 'build_mex.m');
    d = [dir(fullfile(src_dir, '*.c')); dir(bm_file)];
    parts = arrayfun(@(x) sprintf('%s:%d:%d', x.name, x.bytes, x.datenum), d, 'UniformOutput', false);
    h = strjoin(sort(parts), '|');
end
```

This approach is reproducible on the same machine and will detect any local edits (mtime changes). It does NOT produce the same value as CI's `sha256sum`. **The stamp file committed by CI must store the sha256, but MATLAB-side can compare using its own fingerprint stored separately OR use `system()` to call sha256sum.** On most dev machines, `shasum` or `sha256sum` is available.

**Final recommendation:**
- Stamp file: `.mex-version` in `libs/FastSense/private/`
- Format: plain text, one line: `sha256:<hex>`
- CI generates: `sha256sum` of `build_mex.m + all mex_src/*.c` (sorted, concatenated)
- install.m reads stamp, calls `system('shasum -a 256 ...')` on macOS/Linux; falls back to mtime fingerprint if system call fails

---

## 9. Auto-PR Workflow Specifics (Research Question 9)

**Action:** `peter-evans/create-pull-request` (canonical, most used). Current latest is v7.x. Stable API since v5.

**Pattern for collecting multi-matrix artifacts into one commit:**

```yaml
collect-and-pr:
  needs: [build-matlab-macos-arm, build-matlab-macos-intel, build-matlab-linux, build-matlab-windows,
          build-octave-linux, build-octave-macos, build-octave-windows]
  runs-on: ubuntu-latest
  permissions:
    contents: write
    pull-requests: write
  steps:
    - uses: actions/checkout@v6
    - uses: actions/download-artifact@v8
      with:
        name: mex-matlab-macos-arm
        # path: defaults to workspace root, preserving relative paths
    - uses: actions/download-artifact@v8
      with:
        name: mex-matlab-macos-intel
    # ... repeat for all 7 artifacts
    - name: Generate stamp
      run: |
        find libs/FastSense/private/mex_src -name '*.c' libs/FastSense/build_mex.m | sort | xargs cat | sha256sum | cut -d' ' -f1 > libs/FastSense/private/.mex-version
    - uses: peter-evans/create-pull-request@v7
      with:
        branch: chore/refresh-mex-binaries
        commit-message: "chore(mex): refresh prebuilt binaries"
        title: "chore: refresh prebuilt MEX binaries"
        body: "Auto-generated by refresh-mex-binaries workflow."
```

**Preventing re-trigger:** Add `paths-ignore: ['libs/**/private/*.mex*', 'libs/**/private/**/*.mex', 'libs/**/private/.mex-version']` to the new workflow's push trigger. Also add `if: github.actor != 'github-actions[bot]'` guard on the matrix jobs.

**`actions/download-artifact@v8` merging:** When multiple `download-artifact` steps run in sequence each downloading to the same workspace, files accumulate. No merge step needed — each download adds its files. Files from different platforms land in their correct relative paths (because upload preserved paths). This is the standard multi-job artifact collection pattern. HIGH confidence.

---

## 10. Repo Size Impact Estimate (Research Question 10)

**Measured locally (macOS ARM, both MATLAB and Octave present):**

| Location | Extension | Size |
|---|---|---|
| FastSense/private (8 files) | `.mexmaca64` | 2.46 MB |
| SensorThreshold/private (4 files) | `.mexmaca64` | 1.23 MB |
| FastSense/mksqlite | `.mexmaca64` | 1.13 MB |
| **MATLAB ARM total (13 files)** | | **4.59 MB** |
| FastSense/private (8 files) | `.mex` (Octave) | 3.34 MB |
| SensorThreshold/private (4 files) | `.mex` (Octave) | 1.67 MB |
| FastSense/mksqlite | `.mex` (Octave) | 1.57 MB |
| **Octave total (13 files)** | | **6.58 MB** |

**Projection for all 7 platform×runtime combinations:**

| Platform | Runtime | Estimated size |
|---|---|---|
| macOS ARM64 | MATLAB | 4.59 MB |
| macOS Intel | MATLAB | ~4.5 MB |
| Linux x86_64 | MATLAB | ~4.5 MB |
| Windows x86_64 | MATLAB | ~5.0 MB (MSVC debug symbols may be larger) |
| Linux x86_64 | Octave | ~6.6 MB |
| macOS ARM64 | Octave | 6.58 MB |
| macOS x86_64 | Octave | ~6.5 MB |
| Windows x86_64 | Octave | ~7.0 MB |

**Estimated total new tracked binary content: ~40–45 MB**

This is a one-time addition. Git stores binary content efficiently (no diff compression benefit, but compression still reduces pack size). Realistic compressed size: 15–25 MB (binaries with SQLite are already well-compressed).

The CONTEXT.md success criterion says "within 1 order of magnitude of current." Current libs/ is 22 MB total. Adding ~40 MB of binaries grows to ~62 MB — within one order of magnitude of the current 22 MB. Acceptable.

---

## 11. Apple Silicon MATLAB Availability (Research Question 11)

**Confirmed (MEDIUM-HIGH confidence, from setup-matlab release notes v2.2.0 + MathWorks docs):**

- `macos-14` GitHub runner is ARM64 (Apple Silicon M1).
- `matlab-actions/setup-matlab@v3` on `macos-14`:
  - **R2023b and later:** installs native ARM MATLAB → produces `.mexmaca64`.
  - **R2020b–R2023a:** installs Intel MATLAB via Rosetta → produces `.mexmaci64`, NOT `.mexmaca64`.
- **Minimum release for genuine `.mexmaca64`: R2023b.**

**Impact on plan:**
- ARM MATLAB build job must request `release: R2023b` (not R2020b).
- This means `.mexmaca64` binaries require MATLAB R2023b+ on the end-user ARM Mac. R2020b–R2023a Intel Mac users load `.mexmaci64` instead (Rosetta will run it). This is correct behavior — MATLAB picks the right binary by extension.
- Intel Mac users with R2020b–R2025a use `.mexmaci64`.

**Rosetta note:** There is no scenario where an `.mexmaca64` built natively on ARM would be loadable on Rosetta/Intel. And vice versa. The extension system handles disambiguation without any MATLAB code change.

---

## 12. Windows MATLAB MEX Caveats (Research Question 12)

**Source:** MathWorks docs, GitHub issues for MATLAB Actions.

**Compiler:** MATLAB on Windows uses MSVC (Visual C++). The `mex` command links against `vcruntime140.dll` and `msvcp140.dll` from the MSVC redistributable.

**End-user runtime dependency:** A `.mexw64` compiled with MSVC requires the matching MSVC redistributable (`vcruntime140.dll`) on the end-user machine. **MATLAB itself ships and installs the MSVC redistributable** — any machine with MATLAB installed already has the correct runtime. This is NOT a problem for FastSense's target users (MATLAB engineers with MATLAB installed).

**Static linking `/MT`:** MATLAB's `mex` command on Windows does NOT support `/MT` static linking out of the box (it links against MATLAB's own import libraries which are DLL-based). Do not attempt static linking. The DLL dependency is fine for MATLAB users.

**2024 issue (known, low risk):** MATLAB R2024a crashed when MEX compiled with VS2022 17.10+. MathWorks patched this in an update. Using `setup-matlab` with R2020b or R2024b avoids the problematic versions. LOW risk for this project since build_mex.m has no toolbox dependencies.

---

## 13. Glibc Baseline for Linux Binary (Research Question 13)

**Confirmed:** `ubuntu-latest` as of January 2025 refers to Ubuntu 24.04, which has **glibc 2.39**.

**Impact:** A `.mexa64` compiled on Ubuntu 24.04 will NOT load on systems with glibc < 2.39 (e.g., Ubuntu 22.04 has glibc 2.35, CentOS 7 has glibc 2.17).

**Risk assessment for FastSense:** Target users are MATLAB engineers. MATLAB R2023b requires Ubuntu 20.04+ (glibc 2.31+). MATLAB R2024a requires Ubuntu 22.04+ (glibc 2.35+). If we build `.mexa64` on Ubuntu 24.04 (glibc 2.39), users on Ubuntu 20.04 or 22.04 with MATLAB R2020b–R2023a will get a load error.

**Mitigation options:**
1. Pin CI to `ubuntu-22.04` (not `ubuntu-latest`) — produces glibc 2.35 binary, compatible with Ubuntu 22.04+. This covers MATLAB R2020b+ on Ubuntu 22.04. Ubuntu 22.04 runner is still available.
2. Use a manylinux Docker container (more complex, deferred in CONTEXT.md).
3. Keep `ubuntu-latest` and accept glibc 2.39 dependency — users on old Linux can fall back to local build.

**Recommendation:** Use `ubuntu-22.04` runner for Linux MATLAB MEX build to produce glibc 2.35-compatible `.mexa64`. This gives the widest Linux compatibility without manylinux complexity. Verified: `ubuntu-22.04` is available on GitHub Actions as of 2026-04-22.

**Note:** This does NOT affect the Linux Octave build (which already runs in a Docker container `gnuoctave/octave:11.1.0`). The gnuoctave container is based on Ubuntu 22.04 — glibc 2.35. Already optimal.

---

## 14. Verification Test Design (Research Question 14)

### Test A: Fresh-clone path skips compiler

```matlab
% In tests/suite/TestMexPrebuilt.m or tests/test_mex_prebuilt.m
function testFreshInstallSkipsCompiler()
    % Precondition: binary_search_mex.mexEXT exists (prebuilt is tracked)
    % Verify: needs_build(root) returns false without FASTSENSE_SKIP_BUILD
    % Method: call needs_build via a test shim or verify directly via exist()
    
    root = get_repo_root();
    mex_path = fullfile(root, 'libs', 'FastSense', 'private', ...
                        ['binary_search_mex.' mexext()]);
    % Test: if binary exists, needs_build should be false
    assert(exist(mex_path, 'file') == 3, 'Prebuilt binary should exist on path');
    % The binary existing means install() will skip build
```

### Test B: Stamp mismatch triggers rebuild

```matlab
function testStampMismatchTriggersRebuild()
    % Write a corrupted stamp, verify needs_build returns true
    stamp_path = fullfile(get_repo_root(), 'libs', 'FastSense', 'private', '.mex-version');
    old_content = fileread(stamp_path);
    fid = fopen(stamp_path, 'w'); fprintf(fid, 'sha256:0000000000000000'); fclose(fid);
    result = needs_build(get_repo_root());
    fid = fopen(stamp_path, 'w'); fprintf(fid, '%s', old_content); fclose(fid);
    assert(result == true, 'Stamp mismatch should trigger rebuild');
end
```

### Test C: FASTSENSE_SKIP_BUILD still short-circuits

```matlab
function testSkipBuildEnvVarWorks()
    setenv('FASTSENSE_SKIP_BUILD', '1');
    result = needs_build(get_repo_root());
    setenv('FASTSENSE_SKIP_BUILD', '');
    assert(result == false, 'SKIP_BUILD should always return false');
end
```

**Where to add:** `tests/suite/TestMexPrebuilt.m` (MATLAB class-based) paired with `tests/test_mex_prebuilt.m` (Octave function-based). The test requires `needs_build` to be accessible — it is currently a local function in `install.m`. Two options:
1. Extract `needs_build` to `libs/FastSense/private/mex_needs_build.m` (private helper, testable).
2. Test indirectly: verify the binary exists, modify a source file mtime, re-run install(), verify that a re-compile does NOT happen (since we'd need to call mex which we can't do in CI without a compiler).

**Pragmatic approach:** The "fresh clone skips compiler" test can be done by checking `FASTSENSE_SKIP_BUILD=1` is NOT set, the binary exists, and `install()` completes without printing "Compiling..." to stdout. Use `evalc('install()')` to capture output. LOW overhead.

---

## Architecture Patterns

### Recommended File Layout (post-phase)

```
libs/
├── FastSense/
│   ├── build_mex.m
│   ├── mksqlite.c
│   ├── mksqlite.mexmaca64         (MATLAB ARM — tracked)
│   ├── mksqlite.mexmaci64         (MATLAB Intel — tracked)
│   ├── mksqlite.mexa64            (MATLAB Linux — tracked)
│   ├── mksqlite.mexw64            (MATLAB Windows — tracked)
│   ├── octave-linux-x86_64/
│   │   └── mksqlite.mex           (Octave Linux — tracked)
│   ├── octave-macos-arm64/
│   │   └── mksqlite.mex           (Octave macOS ARM — tracked)
│   ├── octave-macos-x86_64/
│   │   └── mksqlite.mex           (Octave macOS Intel — tracked)
│   ├── octave-windows-x86_64/
│   │   └── mksqlite.mex           (Octave Windows — tracked)
│   └── private/
│       ├── .mex-version            (stamp — tracked)
│       ├── mex_src/                (C sources)
│       ├── binary_search_mex.mexmaca64  (tracked)
│       ├── binary_search_mex.mexmaci64  (tracked)
│       ├── binary_search_mex.mexa64     (tracked)
│       ├── binary_search_mex.mexw64     (tracked)
│       ├── [other 7 kernels].mex*       (tracked, 4 extensions each)
│       ├── octave-linux-x86_64/
│       │   └── [8 kernels].mex     (tracked)
│       ├── octave-macos-arm64/
│       │   └── [8 kernels].mex     (tracked)
│       ├── octave-macos-x86_64/
│       │   └── [8 kernels].mex     (tracked)
│       └── octave-windows-x86_64/
│           └── [8 kernels].mex     (tracked)
└── SensorThreshold/
    └── private/
        ├── [4 kernels].mexmaca64   (tracked)
        ├── [4 kernels].mexmaci64   (tracked)
        ├── [4 kernels].mexa64      (tracked)
        ├── [4 kernels].mexw64      (tracked)
        ├── octave-linux-x86_64/   (4 kernels, tracked)
        ├── octave-macos-arm64/    (4 kernels, tracked)
        ├── octave-macos-x86_64/   (4 kernels, tracked)
        └── octave-windows-x86_64/ (4 kernels, tracked)
```

### install.m Revision Skeleton

```matlab
function install()
    root = fileparts(mfilename('fullpath'));
    isOctave = exist('OCTAVE_VERSION', 'builtin');

    % 1. Add library paths
    addpath(fullfile(root, 'libs', 'FastSense'));
    % ... other libs ...

    % 2. For Octave: prepend platform-specific MEX subdir
    if isOctave
        octPlatDir = get_octave_platform_dirs(root);
        for k = 1:numel(octPlatDir)
            if isfolder(octPlatDir{k})
                addpath(octPlatDir{k});
            end
        end
    end

    % 3. Conditional build
    if needs_build(root)
        first_run(root);
    end

    jit_warmup();
end

function dirs = get_octave_platform_dirs(root)
    arch = computer('arch');
    if ~isempty(strfind(arch, 'aarch64')) || ~isempty(strfind(arch, 'arm'))
        tag = 'octave-macos-arm64';
    elseif ~isempty(strfind(arch, 'darwin'))
        tag = 'octave-macos-x86_64';
    elseif ~isempty(strfind(arch, 'mingw')) || ~isempty(strfind(arch, 'w64'))
        tag = 'octave-windows-x86_64';
    else
        tag = 'octave-linux-x86_64';
    end
    dirs = {
        fullfile(root, 'libs', 'FastSense', 'private', tag)
        fullfile(root, 'libs', 'FastSense', tag)
        fullfile(root, 'libs', 'SensorThreshold', 'private', tag)
    };
end
```

### needs_build Revision Skeleton

```matlab
function yes = needs_build(root)
    if ~isempty(getenv('FASTSENSE_SKIP_BUILD'))
        yes = false; return;
    end
    mex_dir = fullfile(root, 'libs', 'FastSense', 'private');
    isOctave = exist('OCTAVE_VERSION', 'builtin');
    if isOctave
        probe = fullfile(mex_dir, 'binary_search_mex.mex');
    else
        probe = fullfile(mex_dir, ['binary_search_mex.' mexext()]);
    end
    if exist(probe, 'file') ~= 3
        yes = true; return;  % binary missing -> rebuild
    end
    % Stamp check
    stamp = fullfile(mex_dir, '.mex-version');
    if ~check_stamp(root, stamp)
        yes = true; return;  % sources changed -> rebuild
    end
    yes = false;
end
```

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---|---|---|---|
| PR creation from CI | Custom git push + gh pr create | `peter-evans/create-pull-request@v7` | Handles branch management, duplicate PR detection, re-push on force |
| Artifact collection | Custom artifact download scripts | `actions/download-artifact@v8` with sequential steps | Handles path preservation, retries |
| MATLAB CI setup | Self-hosted runner management | `matlab-actions/setup-matlab@v3` | Handles licensing, JRE, version matrix automatically |
| Cross-platform hash | Custom parser | `sha256sum` / `shasum -a 256` on shell side | Available everywhere in CI |

---

## Common Pitfalls

### Pitfall 1: Wrong MATLAB release for ARM produces mexmaci64 not mexmaca64

**What goes wrong:** Using `release: R2020b` on `macos-14` causes setup-matlab to install Intel MATLAB via Rosetta. The build succeeds, but produces `.mexmaci64`. Git commit adds the wrong extension. ARM end users can't load it.

**How to avoid:** Always use `release: R2023b` (or later) on `macos-14` runners. Verified by checking `mexext()` output in the CI step before uploading artifacts.

**Detection step:** Add a CI step: `matlab-actions/run-command: "assert(strcmp(mexext(), 'mexmaca64'), 'Expected mexmaca64 on ARM runner')"`.

### Pitfall 2: Octave binary landing in wrong location breaks path lookup

**What goes wrong:** Octave build job puts `*.mex` in `private/` (flat, as existing Linux CI does). When committed, `install.m`'s Octave subdir logic doesn't find it. All other platforms' `.mex` files collide.

**How to avoid:** The new build workflow for Octave must output to `private/octave-<platform>/`, not `private/`. This requires changing the mkoctfile invocation in build_mex.m OR post-processing the built files to move them to the subdir before artifact upload.

**Cleanest approach:** Modify build_mex.m to accept an optional `outDir` override (currently hardcoded to `private/`). OR: add a post-build shell script in CI to move files to the subdir. Do NOT modify build_mex.m for this — keep it simple. Use CI shell step: `mv libs/FastSense/private/*.mex libs/FastSense/private/octave-linux-x86_64/`.

### Pitfall 3: .gitignore negation blocked by directory exclusion

**What goes wrong:** If a parent directory was excluded in `.gitignore`, negation for files inside it won't work. In our case, the `private/` directory is NOT excluded, but `private/octave-linux-x86_64/` is a new subdir — it is also not excluded. Negation for `!libs/FastSense/private/octave-linux-x86_64/*.mex` will work.

**Would fail if:** Someone added `private/` or `*/private/` to `.gitignore`. Verify no such rule exists. Current `.gitignore` has no directory rules affecting these paths.

### Pitfall 4: Re-triggering the binary refresh CI workflow

**What goes wrong:** The refresh workflow commits binary files and opens a PR. The PR commit triggers the same workflow again, creating an infinite loop.

**How to avoid:**
1. Use `paths-ignore` on the workflow's push trigger to exclude the binary file paths.
2. Add `if: github.actor != 'github-actions[bot]'` to the workflow trigger.
3. `peter-evans/create-pull-request` by default uses the `github-actions[bot]` actor for the commit, which is detectable.

### Pitfall 5: release.yml continues deleting MEX files

**What goes wrong:** After binaries are committed to repo and the gitignore is fixed, the release workflow's "package release" step (line 67) still deletes `*.mex*` from the tarball. End users who download the release zip/tar still can't skip compilation.

**How to avoid:** Remove or conditionally skip the mex-delete step in `release.yml`. After this phase, the release tarball should include prebuilt binaries.

### Pitfall 6: glibc mismatch on Linux

**What goes wrong:** Building `.mexa64` on `ubuntu-latest` (Ubuntu 24.04, glibc 2.39) makes it incompatible with Ubuntu 22.04 systems.

**How to avoid:** Use `ubuntu-22.04` runner for the MATLAB Linux build job. Produces glibc 2.35 binary, compatible with Ubuntu 22.04+. Ubuntu 22.04 is still available as of 2026-04-22.

### Pitfall 7: build_mex.m skips compilation if binary already exists

**What goes wrong:** If the workflow checks out the repo after the `.gitignore` fix, the committed `.mexmaca64` files are present. `build_mex.m` skips them (lines 158–163). The "build" step does nothing. No artifact is uploaded.

**How to avoid:** The CI workflow must delete existing binaries for the current platform before running `install()`. Add a step: `find libs -name '*.mexmaca64' -delete` (on the ARM runner). OR use `FASTSENSE_SKIP_BUILD=0` (not a thing — it's checked by `~isempty`). Best: explicitly delete the binaries for the current platform in the CI job before compilation.

### Pitfall 8: mksqlite location vs kernel location mismatch

**What goes wrong:** MATLAB kernels go in `libs/FastSense/private/`. mksqlite goes in `libs/FastSense/` (root, not private/). The Octave subdir for mksqlite must ALSO be in `libs/FastSense/octave-<platform>/`, NOT in `libs/FastSense/private/octave-<platform>/`. Confusing the two causes `mksqlite` to be unfindable by MATLAB/Octave after install().

**How to avoid:** The install.m `get_octave_platform_dirs` must include `fullfile(root, 'libs', 'FastSense', tag)` separately from the `private/` subdir.

---

## Validation Architecture

nyquist_validation is enabled in `.planning/config.json`.

### Test Framework

| Property | Value |
|---|---|
| Framework | MATLAB unittest (suite/) + Octave function-based (test_*.m) |
| Config file | `tests/run_all_tests.m` (auto-discovery) |
| Quick run | `cd tests; run_all_tests()` |
| Full suite | `cd tests; run_all_tests()` (same) |

### Phase Requirements → Test Map

| Behavior | Test Type | Automated Command | File Exists? |
|---|---|---|---|
| Fresh clone: install() does not invoke mex when binary exists | unit | `cd tests; run_all_tests()` (TestMexPrebuilt) | Wave 0 |
| Stamp mismatch triggers rebuild | unit | `cd tests; run_all_tests()` (TestMexPrebuilt) | Wave 0 |
| FASTSENSE_SKIP_BUILD=1 still short-circuits | unit | `cd tests; run_all_tests()` (TestMexPrebuilt) | Wave 0 |
| Octave path-loading finds platform subdir binary | unit/smoke | `cd tests; run_all_tests()` | Wave 0 |

### Wave 0 Gaps

- [ ] `tests/suite/TestMexPrebuilt.m` — covers stamp check and no-compile fast path
- [ ] `tests/test_mex_prebuilt.m` — Octave counterpart
- [ ] `needs_build` may need extraction to a testable private helper

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|---|---|---|---|---|
| `matlab-actions/setup-matlab@v3` | MATLAB CI builds | Yes (public repo) | v3.0.1 | None needed |
| `macos-14` runner | ARM mexmaca64 | Yes | macOS 14 ARM64 | Maintainer builds manually |
| `macos-13` runner | Intel mexmaci64 | Yes (verify at plan time) | macOS 13 Intel | `macos-12` if needed |
| `ubuntu-22.04` runner | Linux mexa64 (glibc 2.35) | Yes | Ubuntu 22.04 | `ubuntu-latest` with compat warning |
| `windows-latest` runner | Windows mexw64 | Yes | Windows Server 2022 | — |
| `gnuoctave/octave:11.1.0` container | Octave Linux build | Yes (in CI now) | 11.1.0 | — |
| `brew install octave` on macOS | Octave macOS build | Yes (used in mex-build-macos now) | varies | — |
| Octave on Windows | Octave Windows build | Yes (Chocolatey 9.2.0, in CI now) | 9.2.0 | Mirror download fallback |
| `peter-evans/create-pull-request` | Auto-PR | Yes (public action) | v7.x | `gh pr create` shell step |
| `sha256sum` / `shasum` | Stamp generation | Yes (Linux/macOS CI) | system | `certutil` on Windows |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Compile MEX on every install | Ship prebuilt, compile only on stamp mismatch | This phase | Eliminates compiler requirement for end users |
| `ubuntu-latest` = Ubuntu 22.04 | `ubuntu-latest` = Ubuntu 24.04 | Jan 2025 | Must use `ubuntu-22.04` for glibc 2.35 compat |
| setup-matlab@v2 | setup-matlab@v3 (Node.js 24) | April 2026 | Already upgraded in repo |
| R2022b as oldest ARM | R2023b minimum for native mexmaca64 | R2023b release | Affects ARM CI release choice |

---

## Open Questions

1. **macos-13 (Intel) runner availability**
   - What we know: Available as of 2026-04-22 per GitHub docs
   - Unclear: Whether GitHub will EOL it before this phase executes
   - Recommendation: Add a fallback `macos-12` in the matrix if `macos-13` fails

2. **Octave macOS ARM binary portability**
   - What we know: Octave on macOS ARM (via Homebrew) compiles `.mex` with NEON flags; build works per `mex-build-macos` CI job
   - Unclear: Whether an Octave macOS ARM `.mex` compiled on GitHub `macos-latest` (M1) runs on M2/M3 Macs without recompilation
   - Recommendation: Should work (NEON is universal ARM64), but add a CI verification step

3. **build_mex.m hardcoded `mcpu=apple-m3` flag**
   - What we know: Line 104 uses `-mcpu=apple-m3` for Octave GCC on ARM
   - Unclear: Whether a binary compiled with M3 CPU flags loads on M1/M2 runners
   - Recommendation: Change to `-mcpu=apple-m1` or `-march=armv8-a` for the CI build to maximize compatibility; `-mcpu=apple-m3` enables instructions not on M1

4. **Windows Octave .mex MSVC compatibility**
   - What we know: Octave on Windows uses MinGW-w64 (not MSVC)
   - Unclear: Does the resulting `.mex` load in Octave when end-user's Octave was built with a different MinGW version?
   - Recommendation: Should work — Octave's MEX interface is C ABI, MinGW CRT is statically linked

---

## Planner Brief — 7 Most Important Findings

1. **ARM MATLAB requires R2023b, not R2020b.** `setup-matlab@v3` on `macos-14` installs Intel MATLAB for R2020b–R2023a, producing `.mexmaci64` (wrong extension). Only R2023b+ produces native `.mexmaca64`. The ARM job must specify `release: R2023b`. All other platforms can stay at R2020b.

2. **13 files per platform, two output locations.** 8 kernels in `FastSense/private/`, 4 copies in `SensorThreshold/private/`, 1 mksqlite in `FastSense/`. Total 52 MATLAB files (13 × 4 platforms) + 39 Octave files (13 × 3 platforms) = 91 new tracked binaries.

3. **Octave always returns `'mex'` from `mexext()`.** Platform disambiguation requires new subdirs (`private/octave-linux-x86_64/`, etc.) and explicit `addpath()` in `install.m`. The subdirs do NOT benefit from MATLAB/Octave's `private/` magic — they need explicit path registration.

4. **Existing CI gaps:** `mex-build-macos` and `mex-build-windows` jobs verify Octave compilation but upload no artifacts and make no commits. Only `_build-mex-octave.yml` (Linux Octave) and `build-mex-matlab` (Linux MATLAB) upload artifacts. A new workflow covers the 5 missing platform combinations.

5. **Linux glibc: use `ubuntu-22.04`, not `ubuntu-latest`.** `ubuntu-latest` is Ubuntu 24.04 (glibc 2.39) since Jan 2025. Binaries built there won't load on Ubuntu 22.04 systems. Use `ubuntu-22.04` (glibc 2.35) to match MATLAB's own Ubuntu 22.04 requirement baseline.

6. **release.yml must be updated.** It currently deletes all MEX files from the release tarball (line 67). After this phase, committed binaries must be included in releases so tarball users also skip compilation.

7. **build_mex.m skips existing binaries — CI must delete before building.** `build_mex.m` lines 158–163 skip compilation if a binary already exists. Once binaries are committed to the repo, the CI refresh workflow must delete the current-platform binaries before calling `install()`, or the build step is a no-op.

---

## Sources

### Primary (HIGH confidence)
- `install.m` lines 70–85 — `needs_build` implementation, probe path, `FASTSENSE_SKIP_BUILD` behavior
- `libs/FastSense/build_mex.m` lines 130–235 — full source file inventory, compiler flags, copy_mex_to destinations
- `.github/workflows/tests.yml` — full existing CI structure, job names, artifact flow
- `.github/workflows/_build-mex-octave.yml` — reusable workflow, artifact naming, cache key
- `.github/workflows/release.yml` — MEX delete step (lines 64–67)
- `.gitignore` — confirmed five blanket MEX rules; `git check-ignore -v` confirmed which line fires

### Secondary (MEDIUM confidence)
- GitHub release notes for `matlab-actions/setup-matlab` v2.2.0: "Install Intel version of MATLAB on Apple silicon runners when a release prior to R2023b is requested"
- GNU Octave documentation (multiple versions): mexext() returns `'mex'` on all platforms
- GitHub Actions runner-images issue #10636: `ubuntu-latest` switched to Ubuntu 24.04 in Jan 2025 (glibc 2.39)

### Tertiary (LOW confidence)
- MathWorks community posts re: MSVC runtime in mexw64 — stated MATLAB ships vcruntime, end-user doesn't need to install separately
- OpenFAST/openfast #1308 re: mexmaci64 vs mexmaca64 on Apple Silicon (corroborates the extension distinction)

---

**Research date:** 2026-04-22
**Valid until:** 2026-05-22 (stable domain, but verify macos-13 runner availability at plan time)

## RESEARCH COMPLETE
