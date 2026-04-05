# FastPlot → FastSense Rename Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rename the project from "FastPlot" to "FastSense" — all classes, files, docs, CI, Python bridge, MEX sources, and infrastructure.

**Architecture:** Pure find-and-replace rename with no functional changes. Rename files/directories first, then bulk-replace content, then verify. Single atomic commit.

**Tech Stack:** MATLAB/Octave, C (MEX), Python, GitHub Actions, Markdown

**Spec:** `docs/superpowers/specs/2026-03-16-fastplot-to-fastsense-rename-design.md`

---

## Chunk 1: Core Library Rename

### Task 1: Rename `libs/FastPlot/` directory and all FastPlot*.m files

**Files:**
- Rename directory: `libs/FastPlot/` → `libs/FastSense/`
- Rename: `libs/FastSense/FastPlot.m` → `libs/FastSense/FastSense.m`
- Rename: `libs/FastSense/FastPlotDataStore.m` → `libs/FastSense/FastSenseDataStore.m`
- Rename: `libs/FastSense/FastPlotDefaults.m` → `libs/FastSense/FastSenseDefaults.m`
- Rename: `libs/FastSense/FastPlotDock.m` → `libs/FastSense/FastSenseDock.m`
- Rename: `libs/FastSense/FastPlotGrid.m` → `libs/FastSense/FastSenseGrid.m`
- Rename: `libs/FastSense/FastPlotTheme.m` → `libs/FastSense/FastSenseTheme.m`
- Rename: `libs/FastSense/FastPlotToolbar.m` → `libs/FastSense/FastSenseToolbar.m`
- Rename: `libs/Dashboard/FastPlotWidget.m` → `libs/Dashboard/FastSenseWidget.m`

- [ ] **Step 1: Rename the directory**

```bash
git mv libs/FastPlot libs/FastSense
```

- [ ] **Step 2: Rename all FastPlot*.m class files in libs/FastSense/**

```bash
git mv libs/FastSense/FastPlot.m libs/FastSense/FastSense.m
git mv libs/FastSense/FastPlotDataStore.m libs/FastSense/FastSenseDataStore.m
git mv libs/FastSense/FastPlotDefaults.m libs/FastSense/FastSenseDefaults.m
git mv libs/FastSense/FastPlotDock.m libs/FastSense/FastSenseDock.m
git mv libs/FastSense/FastPlotGrid.m libs/FastSense/FastSenseGrid.m
git mv libs/FastSense/FastPlotTheme.m libs/FastSense/FastSenseTheme.m
git mv libs/FastSense/FastPlotToolbar.m libs/FastSense/FastSenseToolbar.m
```

- [ ] **Step 3: Rename FastPlotWidget in Dashboard lib**

```bash
git mv libs/Dashboard/FastPlotWidget.m libs/Dashboard/FastSenseWidget.m
```

### Task 2: Find-and-replace `FastPlot` → `FastSense` in all core library .m files

**Files:**
- Modify: all `.m` files under `libs/FastSense/` (including `private/` and `build_mex.m`)
- Modify: all `.m` files under `libs/Dashboard/` that reference FastPlot
- Modify: all `.m` files under `libs/SensorThreshold/` that reference FastPlot
- Modify: all `.m` files under `libs/EventDetection/` that reference FastPlot
- Modify: all `.m` files under `libs/WebBridge/` that reference FastPlot

This covers ~447 occurrences in core library files.

- [ ] **Step 1: Replace in all .m files under libs/**

```bash
find libs/ -name '*.m' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
```

- [ ] **Step 2: Replace lowercase `fastplot` → `fastsense` in libs/ .m files**

The widget type string `'fastplot'` in `FastSenseWidget.getType()` and dispatch sites:

```bash
find libs/ -name '*.m' -exec sed -i '' 's/fastplot/fastsense/g' {} +
```

- [ ] **Step 3: Verify no FastPlot references remain in libs/**

```bash
grep -ri "fastplot" libs/ --include='*.m'
```

Expected: zero results.

### Task 3: Update MEX C/H source files

**Files:**
- Modify: `libs/FastSense/private/mex_src/binary_search_mex.c` (4 occurrences)
- Modify: `libs/FastSense/private/mex_src/build_store_mex.c` (14 occurrences)
- Modify: `libs/FastSense/private/mex_src/compute_violations_mex.c` (1 occurrence)
- Modify: `libs/FastSense/private/mex_src/lttb_core_mex.c` (2 occurrences)
- Modify: `libs/FastSense/private/mex_src/minmax_core_mex.c` (2 occurrences)
- Modify: `libs/FastSense/private/mex_src/resolve_disk_mex.c` (5 occurrences)
- Modify: `libs/FastSense/private/mex_src/violation_cull_mex.c` (1 occurrence)
- Modify: `libs/FastSense/private/mex_src/simd_utils.h` (1 occurrence)

- [ ] **Step 1: Replace in all C and H files**

```bash
find libs/FastSense/private/mex_src/ \( -name '*.c' -o -name '*.h' \) -exec sed -i '' 's/FastPlot/FastSense/g' {} +
```

- [ ] **Step 2: Verify**

```bash
grep -r "FastPlot" libs/FastSense/private/mex_src/
```

Expected: zero results.

---

## Chunk 2: Tests, Examples, Benchmarks

### Task 4: Rename test files and helper

**Files:**
- Rename: `tests/add_fastplot_private_path.m` → `tests/add_fastsense_private_path.m`
- Rename: `tests/test_fastplot_theme.m` → `tests/test_fastsense_theme.m`
- Rename: `tests/suite/TestFastPlotWidget.m` → `tests/suite/TestFastSenseWidget.m`
- Rename: `tests/suite/TestFastplotTheme.m` → `tests/suite/TestFastSenseTheme.m`

- [ ] **Step 1: Rename test files**

```bash
git mv tests/add_fastplot_private_path.m tests/add_fastsense_private_path.m
git mv tests/test_fastplot_theme.m tests/test_fastsense_theme.m
git mv tests/suite/TestFastPlotWidget.m tests/suite/TestFastSenseWidget.m
git mv tests/suite/TestFastplotTheme.m tests/suite/TestFastSenseTheme.m
```

### Task 5: Find-and-replace in all test files

**Files:**
- Modify: all `.m` files under `tests/` (~644 occurrences across ~40 files)

- [ ] **Step 1: Replace FastPlot → FastSense in all test .m files**

```bash
find tests/ -name '*.m' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
```

- [ ] **Step 2: Replace lowercase fastplot → fastsense (function names, paths)**

```bash
find tests/ -name '*.m' -exec sed -i '' 's/fastplot/fastsense/g' {} +
```

- [ ] **Step 3: Also handle mixed-case `Fastplot` (TestFastplotTheme uses this casing)**

```bash
find tests/ -name '*.m' -exec sed -i '' 's/Fastplot/FastSense/g' {} +
```

- [ ] **Step 4: Verify**

```bash
grep -ri "fastplot" tests/ --include='*.m'
```

Expected: zero results.

### Task 6: Rename example file and replace in all examples

**Files:**
- Rename: `examples/example_widget_fastplot.m` → `examples/example_widget_fastsense.m`
- Modify: all `.m` files under `examples/` (~196 occurrences across ~35 files)

- [ ] **Step 1: Rename example file**

```bash
git mv examples/example_widget_fastplot.m examples/example_widget_fastsense.m
```

- [ ] **Step 2: Replace in all example files**

```bash
find examples/ -name '*.m' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
find examples/ -name '*.m' -exec sed -i '' 's/fastplot/fastsense/g' {} +
```

- [ ] **Step 3: Verify**

```bash
grep -ri "fastplot" examples/ --include='*.m'
```

Expected: zero results.

### Task 7: Replace in all benchmark files

**Files:**
- Modify: all `.m` files under `benchmarks/` (~56 occurrences)

- [ ] **Step 1: Replace in benchmarks**

```bash
find benchmarks/ -name '*.m' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
```

- [ ] **Step 2: Verify**

```bash
grep -ri "fastplot" benchmarks/ --include='*.m'
```

Expected: zero results.

---

## Chunk 3: Python Bridge, Web Bridge, Scripts

### Task 8: Rename Python bridge package

**Files:**
- Rename directory: `bridge/python/fastplot_bridge/` → `bridge/python/fastsense_bridge/`
- Modify: `bridge/python/pyproject.toml`
- Modify: `bridge/python/fastsense_bridge/__init__.py`
- Modify: `bridge/python/fastsense_bridge/__main__.py`
- Modify: `bridge/python/fastsense_bridge/server.py`
- Modify: `bridge/python/fastsense_bridge/sqlite_reader.py`
- Modify: `bridge/python/tests/test_sqlite_reader.py`
- Modify: `bridge/python/tests/test_server.py`
- Modify: `bridge/python/tests/test_blob_decoder.py`
- Modify: `bridge/python/tests/test_tcp_client.py`

- [ ] **Step 1: Rename Python package directory**

```bash
git mv bridge/python/fastplot_bridge bridge/python/fastsense_bridge
```

- [ ] **Step 2: Replace in all Python files and pyproject.toml**

```bash
find bridge/python/ \( -name '*.py' -o -name '*.toml' \) -exec sed -i '' 's/fastplot_bridge/fastsense_bridge/g' {} +
find bridge/python/ \( -name '*.py' -o -name '*.toml' \) -exec sed -i '' 's/fastplot-bridge/fastsense-bridge/g' {} +
find bridge/python/ \( -name '*.py' -o -name '*.toml' \) -exec sed -i '' 's/FastPlot/FastSense/g' {} +
```

- [ ] **Step 3: Verify**

```bash
grep -ri "fastplot" bridge/python/
```

Expected: zero results.

### Task 9: Update web bridge files

**Files:**
- Modify: `bridge/web/index.html` (2 occurrences)
- Modify: `bridge/web/js/chart.js` (1 occurrence)
- Modify: `bridge/web/js/widgets.js` (2 occurrences)

- [ ] **Step 1: Replace in web files**

```bash
find bridge/web/ \( -name '*.html' -o -name '*.js' -o -name '*.css' \) -exec sed -i '' 's/FastPlot/FastSense/g' {} +
find bridge/web/ \( -name '*.html' -o -name '*.js' -o -name '*.css' \) -exec sed -i '' 's/fastplot/fastsense/g' {} +
```

- [ ] **Step 2: Verify**

```bash
grep -ri "fastplot" bridge/web/
```

Expected: zero results.

### Task 10: Update `scripts/generate_api_docs.py`

**Files:**
- Modify: `scripts/generate_api_docs.py` (13 occurrences — class name tables, lib folder list, print statements)

- [ ] **Step 1: Replace in generate_api_docs.py**

```bash
sed -i '' 's/FastPlot/FastSense/g' scripts/generate_api_docs.py
sed -i '' 's/fastplot/fastsense/g' scripts/generate_api_docs.py
```

- [ ] **Step 2: Verify**

```bash
grep -i "fastplot" scripts/generate_api_docs.py
```

Expected: zero results.

---

## Chunk 4: Documentation, CI, Metadata

### Task 11: Update setup.m

**Files:**
- Modify: `setup.m` (6 occurrences)

- [ ] **Step 1: Replace in setup.m**

```bash
sed -i '' 's/FastPlot/FastSense/g' setup.m
sed -i '' 's/fastplot/fastsense/g' setup.m
```

### Task 12: Update README.md

**Files:**
- Modify: `README.md` (20+ occurrences)

- [ ] **Step 1: Replace in README**

```bash
sed -i '' 's/FastPlot/FastSense/g' README.md
sed -i '' 's/fastplot/fastsense/g' README.md
```

Note: GitHub badge URLs containing `HanSur94/FastPlot` will be updated. After the GitHub repo rename, these will resolve correctly.

### Task 13: Update CITATION.cff

**Files:**
- Modify: `CITATION.cff` (3 occurrences)

- [ ] **Step 1: Replace in CITATION.cff**

```bash
sed -i '' 's/FastPlot/FastSense/g' CITATION.cff
sed -i '' 's/fastplot/fastsense/g' CITATION.cff
```

### Task 14: Update CI workflows

**Files:**
- Modify: `.github/workflows/release.yml` (3 occurrences — artifact naming)
- Modify: `.github/workflows/generate-docs.yml` (1 occurrence — wiki clone URL)

- [ ] **Step 1: Replace in CI workflows**

```bash
find .github/workflows/ -name '*.yml' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
find .github/workflows/ -name '*.yml' -exec sed -i '' 's/fastplot/fastsense/g' {} +
```

### Task 15: Update wiki pages

**Files:**
- Rename: `wiki/API-Reference:-FastPlot.md` → `wiki/API-Reference:-FastSense.md`
- Modify: all `.md` files under `wiki/` (~217 occurrences)

Note: Wiki files are auto-generated by `generate_api_docs.py`, but updating them here keeps them consistent until the next CI run.

- [ ] **Step 1: Rename wiki API reference file**

```bash
git mv "wiki/API-Reference:-FastPlot.md" "wiki/API-Reference:-FastSense.md"
```

- [ ] **Step 2: Clean up stale FastPlotFigure references FIRST**

```bash
find wiki/ -name '*.md' -exec sed -i '' 's/FastPlotFigure/FastSenseGrid/g' {} +
```

Note: `FastPlotFigure` was the old name for `FastPlotGrid`. This MUST run before the general FastPlot→FastSense replace, otherwise `FastPlotFigure` becomes `FastSenseFigure` (a non-existent class) and is never corrected.

- [ ] **Step 3: Replace all remaining FastPlot references**

```bash
find wiki/ -name '*.md' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
find wiki/ -name '*.md' -exec sed -i '' 's/fastplot/fastsense/g' {} +
```

### Task 16: Update docs/ markdown and MATLAB files

**Files:**
- Rename: `docs/2026-03-06-fastplot-design.md` → `docs/2026-03-06-fastsense-design.md`
- Rename: `docs/plans/2026-03-06-fastplot-implementation.md` → `docs/plans/2026-03-06-fastsense-implementation.md`
- Modify: all `.md` files under `docs/` (excluding the rename spec itself)
- Modify: `docs/generate_readme_images.m`

- [ ] **Step 1: Rename doc files**

```bash
git mv docs/2026-03-06-fastplot-design.md docs/2026-03-06-fastsense-design.md
git mv docs/plans/2026-03-06-fastplot-implementation.md docs/plans/2026-03-06-fastsense-implementation.md
```

- [ ] **Step 2: Replace in all doc files (excluding the rename spec)**

```bash
find docs/ -name '*.md' ! -name '*fastsense-rename*' -exec sed -i '' 's/FastPlot/FastSense/g' {} +
find docs/ -name '*.md' ! -name '*fastsense-rename*' -exec sed -i '' 's/fastplot/fastsense/g' {} +
sed -i '' 's/FastPlot/FastSense/g' docs/generate_readme_images.m
```

---

## Chunk 5: Final Verification and Commit

### Task 17: Full grep audit

- [ ] **Step 1: Case-insensitive grep for any remaining references**

```bash
grep -ri "fastplot" --include='*.m' --include='*.c' --include='*.h' --include='*.py' --include='*.toml' --include='*.md' --include='*.yml' --include='*.html' --include='*.js' --include='*.cff' . | grep -v '.git/' | grep -v '.worktrees/' | grep -v '.superpowers/' | grep -v 'fastsense-rename'
```

Expected: zero results. If any remain, fix them.

- [ ] **Step 2: Also check for `FastPlotFigure` (stale name)**

```bash
grep -ri "FastPlotFigure" --include='*.m' --include='*.md' . | grep -v '.git/' | grep -v '.worktrees/'
```

Expected: zero results.

### Task 18: Run test suite

- [ ] **Step 1: Run setup and tests**

```bash
cd /Users/hannessuhr/FastPlot && octave --eval "setup; run('tests/run_all_tests.m')"
```

Expected: all tests pass. If any fail, diagnose and fix — likely a missed rename.

### Task 19: Commit

- [ ] **Step 1: Stage all changes**

```bash
git add -A
```

- [ ] **Step 2: Review staged changes**

```bash
git diff --cached --stat
```

Verify the file count and renames look correct.

- [ ] **Step 3: Commit**

```bash
git commit -m "rename: FastPlot → FastSense

Rename project from FastPlot to FastSense to better reflect the
sensor monitoring and dashboarding platform it has become.

- Rename all FastPlot* classes to FastSense*
- Rename libs/FastPlot/ directory to libs/FastSense/
- Rename Python bridge package fastplot_bridge to fastsense_bridge
- Update MEX C source error identifiers
- Update all tests, examples, benchmarks, docs, wiki, CI
- Update runtime string keys (UserData, appdata, tags)
- Update setup.m, README.md, CITATION.cff

No functional changes — pure rename operation."
```

### Task 20: Post-commit manual steps

These are NOT automated — document for the user:

- [ ] **Step 1: Rename GitHub repo** — Go to `github.com/HanSur94/FastPlot` → Settings → Repository name → change to `FastSense`
- [ ] **Step 2: Rebuild MEX binaries** — Run `build_mex` in MATLAB/Octave to update pre-built binaries with new error identifiers
- [ ] **Step 3: Push to remote** — `git push` (after repo rename is done)
- [ ] **Step 4: Verify CI** — Check that GitHub Actions tests pass on the new repo name
