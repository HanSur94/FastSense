# GSD Inbox Triage — HanSur94/FastSense — 2026-07-08

Scope: **issues only** (`--issues`). Report-only run — no labels applied, nothing closed.

## Summary

| Metric | Value |
|---|---|
| Open issues | **149** |
| Closed issues (all time) | **0** |
| Auto-generated enhancements (feature-scout) | 147 |
| Good-first-issue | 2 (#321, #327) |
| Unlabeled outliers | 2 (#71, #151) |
| Created in last 8 days | 29 (~3.6/day) |
| Older than 30 days | 2 (#71, #151) |

Age buckets: <7d: 29 · 7–14d: 109 · 14–30d: 9 · >30d: 2

## Headline finding: the backlog is write-only

149 issues have ever been filed; **zero have ever been closed**. feature-scout files
~3–4 enhancement issues per day and nothing consumes them — no merged PR references
any open issue, and feature-build (the consumer) is gated on human approval that has
never been granted. At the current rate the backlog doubles roughly every 6 weeks.

Compounding this: **the approval gate has no vocabulary.** The label taxonomy has no
`approved` / `approved-feature` label, so there is no mechanism to mark an issue as
picked for feature-build. The pipeline is structurally stuck.

## Duplicates (action: close one of each pair)

1. **#363 duplicates #291** — both propose `TagRegistry.toStructs()` (serialize the
   whole catalog, inverse of `loadFromStructs`). #363 (2026-07-06) is the newer,
   better-evidenced write-up (cites the hand-rolled inline version in
   `tests/test_compositetag.m:408`). Recommend: close **#291** as duplicate, keep #363.
2. **#344 duplicates #221** — both propose exporting *all pages* of a multi-page
   dashboard as images (#221 `exportImagePages`, 2026-06-24; #344 `exportReport(dir)`,
   2026-07-03). Same feature, different name. Recommend: close **#221** as duplicate,
   keep #344 (stronger milestone-tied motivation).

feature-scout's dedup missed both pairs — likely because the titles share few words.

## Stale / administrative closures

- **#71** "smoke test: claude-agent workflow" (2026-04-24, 75 days) — a test issue for
  the `claude-agent.yml` workflow. Served its purpose. Close as completed.
- **#151** "Discussion: v3.1 Live Tag Pipeline architectural exploration" (2026-05-19,
  50 days) — `LiveTagPipeline.m` has since shipped in `libs/SensorThreshold/` (49 KB).
  Close as completed, or convert to a GitHub Discussion if the remaining ideas matter.

## Already-implemented check

Extracted the proposed API name from all 120 titles that contain one and cross-checked
against every function defined in `libs/**/*.m` (1,463 definitions). 14 raw hits, all
false positives (same method name on a *different* class — e.g. widgets have
`setTimeRange` but #224 asks for it on `DashboardEngine`). **No open issue is already
implemented.** Issue quality from feature-scout is genuinely good: bodies consistently
carry problem/motivation with file:line evidence, proposed API with examples, scope,
and alternatives.

## Template compliance

Not applicable — the repo has **no `.github/ISSUE_TEMPLATE/`, no PR templates, and no
CONTRIBUTING.md**. If the issue-first/approval-gated flow is intended to be real,
these are the missing enforcement artifacts.

## Label taxonomy gaps

Current labels: bug, documentation, duplicate, enhancement, good first issue,
help wanted, invalid, question, wontfix, auto-generated, docs.

Missing for the intended pipeline:
- `approved` (or `approved-feature`) — the gate feature-build needs to pick work
- `needs-triage` — for unclassified human-filed issues
- Optional: per-library labels (lib:Dashboard, lib:FastSense, lib:SensorThreshold,
  lib:EventDetection) — with 149 issues, component filtering is the only way to
  navigate; the current spread is Tag 18, DashboardEngine 13, widgets ~40, etc.

## Component distribution (top)

Tag 18 · DashboardEngine 13 · FastSense 7 · ScatterWidget 7 · EventDetection 7 ·
PlantLogStore 5 · EventStore 5 · EventViewer 5 · FastSenseWidget 5 · MonitorTag 4

## Recommended actions (in order)

1. Close the 2 duplicates (#291, #221) with a duplicate label + pointer comment.
2. Close #71 (done) and #151 (shipped as LiveTagPipeline).
3. Create the `approved` label and approve a first small batch — the two
   `good first issue` items (#321 EventViewer.exportImage, #327 Tag.cumulativeIntegral)
   are ideal starters — so feature-build has something to consume.
4. Consider throttling feature-scout (e.g. weekly instead of ~daily) until the
   consume rate is nonzero; otherwise the backlog is pure noise accumulation.
5. Add per-library labels if the backlog will stay >100 items.

Re-run with `/gsd-inbox --issues --label` to auto-apply recommended labels, or
`--close-incomplete` (not needed — nothing scores below threshold).
