---
quick_id: 260609-mcz
slug: fix-wiki-regenerate-yml-to-use-a-stable-
date: 2026-06-09
status: planned
mode: quick
---

# Quick Task 260609-mcz: Fix wiki-regenerate.yml branch naming

## Objective

Stop the wiki-regenerate workflow from opening a brand-new PR on every qualifying
push. Switch the `peter-evans/create-pull-request` step from a per-commit branch
(`wiki-update/${{ github.sha }}`) to a stable branch (`wiki-update`), so each run
updates a single rolling PR instead of stacking duplicates.

## Root Cause

`.github/workflows/wiki-regenerate.yml` "Open or update PR" step set
`branch: wiki-update/${{ github.sha }}`. Because the SHA is unique per push,
`create-pull-request` never found an existing branch to update and opened a fresh
PR each time. This stacked up 12 duplicate "docs: regenerate wiki pages" PRs
(#162–#190), now closed except #190. The sibling `refresh-mex-binaries.yml`
already does this correctly with a stable `chore/refresh-mex-binaries` branch +
`delete-branch: true`.

## Task

**File:** `.github/workflows/wiki-regenerate.yml` (step "Open or update PR", ~line 107)

- **action:** Change `branch: wiki-update/${{ github.sha }}` → `branch: wiki-update`,
  and add `delete-branch: true` directly beneath it.
- **rationale:** Stable branch name = single rolling PR; `delete-branch: true`
  cleans the branch after merge/close (mirrors refresh-mex-binaries.yml). The
  source-commit SHA is still recorded in the PR body ("Source commit: ${{ github.sha }}"),
  so no traceability is lost.
- **verify:** `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/wiki-regenerate.yml'))"`
  parses clean; `grep` confirms the new `branch: wiki-update` line and `delete-branch: true`.
- **done:** Workflow YAML is valid and the create-pull-request step targets the
  stable branch with delete-branch enabled.

## Scope / Non-goals

- YAML-only infra change. No MATLAB code, no examples, no tests touched.
- Does NOT retroactively touch #190 (the surviving live wiki PR) — left for the
  next regen run to supersede on the new stable branch.
