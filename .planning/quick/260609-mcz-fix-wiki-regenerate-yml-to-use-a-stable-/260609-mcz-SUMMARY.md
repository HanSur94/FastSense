---
quick_id: 260609-mcz
slug: fix-wiki-regenerate-yml-to-use-a-stable-
date: 2026-06-09
status: complete
commit: fd52a841
---

# Quick Task 260609-mcz: Fix wiki-regenerate.yml branch naming — SUMMARY

## What changed

`.github/workflows/wiki-regenerate.yml` — "Open or update PR" step
(`peter-evans/create-pull-request@v8`):

```diff
-          branch: wiki-update/${{ github.sha }}
+          branch: wiki-update
+          delete-branch: true
```

## Why

The per-commit branch name (`wiki-update/${{ github.sha }}`) meant
`create-pull-request` never found an existing branch to update, so it opened a
fresh "docs: regenerate wiki pages" PR on every qualifying push. 12 duplicates
accumulated (#162–#190). A stable `wiki-update` branch makes each run update a
single rolling PR; `delete-branch: true` cleans it after merge/close. This
mirrors the already-correct `refresh-mex-binaries.yml`. The source-commit SHA is
still recorded in the PR body, so traceability is preserved.

## Verification

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/wiki-regenerate.yml'))"` → valid ✓
- Diff confirmed: `branch: wiki-update` + `delete-branch: true`, `${{ github.sha }}` removed from branch name.
- YAML-only change; no MATLAB/examples/tests touched.

## Companion cleanup (done outside this task, same session)

- Merged PR #179 (Event Viewer subsystem grouping + slider render fix).
- Closed the 11 stale duplicate wiki PRs (#162–#188); kept #190 as the live wiki PR.

## Follow-ups / non-goals

- Did not retroactively rebase #190 onto the new stable branch — the next regen
  run will supersede it on `wiki-update`.
- Effect is not observable until the next push that touches `libs/**/*.m`,
  `examples/**/*.m`, or `scripts/generate_wiki.py` triggers the workflow.
