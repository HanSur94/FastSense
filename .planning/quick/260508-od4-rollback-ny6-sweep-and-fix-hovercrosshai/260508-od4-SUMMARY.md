---
phase: quick-260508-od4
plan: 01
subsystem: Dashboard, FastSense
tags: [rollback, switchPage, ny6-supersession, HoverCrosshair, invalid-object-guard, regression-test]
requirements_completed: [OD4-01, OD4-02]
dependency_graph:
  requires:
    - libs/Dashboard/DashboardEngine.m :: switchPage (post-realizeBatch flow)
    - libs/FastSense/HoverCrosshair.m :: onFigureMove_, delete
    - tests/test_hover_crosshair.m :: makeFp_, safeClose_, cases dispatch
  provides:
    - DashboardEngine.switchPage WITHOUT the ny6 markDirty/refresh sweep
    - HoverCrosshair.onFigureMove_ with isvalid + handle guards hoisted to top
    - tests/test_hover_crosshair.m::test_invalid_obj_no_error regression case
  affects:
    - Tab-switch redraw cost (faster — no per-tab flat markDirty + top-level refresh)
    - All FastSense plots embedded in widgets that get rerendered (no more "Invalid or deleted object" stack trace from stale WBMFcn closures)
tech-stack:
  added: []
  patterns:
    - "Forward-fix rollback: delete obsolete code path + supersession marker in STATE.md instead of git revert"
    - "isvalid(obj) guard hoisted above any property access on obj — defensive pattern for any callback bound via @(s,e) obj.method(s,e)"
key-files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - libs/FastSense/HoverCrosshair.m
    - tests/test_hover_crosshair.m
    - .planning/STATE.md
  deleted:
    - tests/test_dashboard_switch_page_refresh.m
    - tests/fixtures/ThrowingTextWidget.m
decisions:
  - "Roll back ny6 by forward-fix (commit 6ef1a86), not git revert, so the rationale lives in the rollback commit's body rather than a generic 'Revert' message. This matches the m52 -> mhv supersession pattern earlier in STATE.md."
  - "Hoist ALL three guards (isvalid + hFigure handle + hAxes handle) to the top of onFigureMove_, not just isvalid. The bug only requires isvalid, but lifting the handle guards too is consistent: any branch where isvalid(obj) holds but the handles are stale should also bail before chaining PrevWBMFcn_ (which itself can fire callbacks that then call back through obj)."
  - "delete() restoration of WBMFcn is left untouched. It already restores PrevWBMFcn_ unconditionally — the guard fix is the only change required to close the user-reported stack trace."
  - "test_invalid_obj_no_error reuses existing makeFp_/safeClose_ helpers; no new helpers, no new fixtures. The test exercises the exact closure-after-delete scenario the user hit."
  - "Pre-existing test_default_on failure on this branch is OUT OF SCOPE for od4 (FastSense.HoverCrosshair_ lifecycle, not onFigureMove_ guard). Documented as deferred — fix in a separate task."
metrics:
  duration_minutes: ~30
  tasks_completed: 2
  completed_at: 2026-05-08
---

# Quick Task 260508-od4: Roll Back ny6 + Fix HoverCrosshair Invalid-Object Guard Summary

Two-part fix executed as two atomic commits: (1) **revert** the ny6 switchPage refresh sweep that did not solve the user-reported "stuck widgets after tab change" symptom and added per-tab redraw cost; (2) **hoist** the HoverCrosshair invalid-object guard so a stale WindowButtonMotionFcn closure cannot trigger an "Invalid or deleted object" error after panel teardown.

## What Changed

### Task 1 — Roll back ny6 (commit 6ef1a86)

**`libs/Dashboard/DashboardEngine.m`** — deleted the 33-line block previously at L226-L258 that:
- re-extracted `activeWs = obj.Pages{obj.ActivePage}.Widgets`,
- flattened it via `flattenWidgetsForPreview_`,
- called `markDirty()` on every flat widget,
- called `refresh()` on every top-level widget with a `DebugPreview_`-gated `DashboardEngine:switchPageRefreshFailed` warning.

The post-rollback `switchPage` flow inside `if ~isempty(obj.hFigure) && ishandle(obj.hFigure)` is now: visibility toggle loop → hasUnrealized check → realizeBatch(5) → end. The downstream `LastSyncedTimeRange_` rebroadcast (260508-llw, unrelated to ny6) is preserved, as are `computePreviewEnvelope` and `computeEventMarkers`.

**`tests/test_dashboard_switch_page_refresh.m`** — deleted (4-case file added solely for ny6).

**`tests/fixtures/ThrowingTextWidget.m`** — deleted (TextWidget subclass added solely for ny6's failure-isolation case).

**`.planning/STATE.md`** — ny6 row's Status column changed to `Superseded by od4`; new od4 row appended; `last_activity` and `last_updated` refreshed.

### Task 2 — HoverCrosshair invalid-object guard (commit 936feac)

**`libs/FastSense/HoverCrosshair.m::onFigureMove_`** — moved the three guards

```matlab
if ~isvalid(obj); return; end
if isempty(obj.hFigure) || ~ishandle(obj.hFigure); return; end
if isempty(obj.hAxes) || ~ishandle(obj.hAxes); return; end
```

from below the `obj.PrevWBMFcn_` chain to the very top of the method, BEFORE any property access on `obj`. Updated the doc comment to reflect the new ordering and explicitly call out the Reset / `rerenderWidgets` teardown scenario.

Why this closes the bug: the user-reported stack trace fires at the `obj.PrevWBMFcn_` access on the now-invalid object. Hoisting `~isvalid(obj)` above all property reads forces a silent early return when the closure fires after `delete(hc)` but before the WBMFcn restore takes effect (or after a sibling re-installs the closure).

`delete()` is unchanged — it already unconditionally restores the captured PrevWBMFcn_ when the figure is still valid.

**`tests/test_hover_crosshair.m`** — added `@test_invalid_obj_no_error` to the cases dispatch (between `@test_chain_preserved` and the conditional integration block) and the corresponding test function. The test:
1. Builds a rendered FastSense + HoverCrosshair on a hidden figure.
2. Captures the `WindowButtonMotionFcn` closure (`@(s,e) obj.onFigureMove_(s,e)`).
3. `delete(hc)` — `delete()` restores the previous WBMFcn.
4. **Re-installs** the captured stale closure to simulate the bug condition where a sibling code path re-binds it after teardown.
5. Invokes the closure. Pre-fix: throws `Invalid or deleted object.`. Post-fix: returns silently.

## Verification Evidence

`mh_lint libs/Dashboard/DashboardEngine.m libs/FastSense/HoverCrosshair.m tests/test_hover_crosshair.m` → "everything seems fine" (0 new findings).

Constraint-listed sweep run via `matlab -batch` (logged to `/tmp/od4_sweep.log`):

| Test file                                  | Result                |
| ------------------------------------------ | --------------------- |
| tests/test_dashboard_preview_overlay       | All 10 tests passed   |
| tests/test_dashboard_engine_event_markers  | All 9 tests passed    |
| tests/test_dashboard_time_sync_all_pages   | 5/5 tests passed      |
| tests/test_dashboard_widget_button_bar     | 5 passed, 0 failed    |
| tests/test_dashboard_toolbar_buttons       | 7 passed, 0 failed    |
| tests/test_hover_crosshair (case 7 = new)  | passed (see note)     |

Note on test_hover_crosshair: the suite has a pre-existing failure on `test_default_on` (case 9 in the conditional branch — about `FastSense.HoverCrosshair_` lifecycle, NOT `onFigureMove_` guarding). Cases 1-7 (including `test_invalid_obj_no_error`) all execute and pass before the harness rethrows on case 9. Out of scope for od4; flagged for a follow-up task.

Direct repro of the regression test logic via `matlab -batch` script (writing to `/tmp/test_od4.log`):
- Pre-fix (HoverCrosshair.m stashed to its previous shape): `OUTCOME threw=1 msg=[Invalid or deleted object.]` ← bug reproduces.
- Post-fix (current HEAD): `OUTCOME threw=0 msg=[]` ← bug closed.

This direct A/B confirms `test_invalid_obj_no_error` distinguishes pre- and post-fix behavior, and the post-fix path returns silently as required.

## Deviations from Plan

None. Both tasks executed exactly as specified. The plan-listed verification all passed. The `test_default_on` pre-existing failure is documented (Deferred Issues) per the SCOPE BOUNDARY rule, not auto-fixed.

## Deferred Issues

- **`tests/test_hover_crosshair.m::test_default_on` pre-existing failure** — `assert(~isempty(fp.HoverCrosshair_))` fails after `FastSense('Parent', ax)` + `addLine` + `render()` with default options. Failure is unrelated to `onFigureMove_` guarding (it concerns the `HoverCrosshair_` property being populated on render). Confirmed pre-existing by running `git stash` and the test before any od4 edits. Recommend a separate task investigating why `HoverCrosshair_` is empty after default-on render in the current branch state.
- **Root cause of "widgets stuck after tab change"** — ny6 attempted to fix this and did not. od4 only rolls ny6 back; the underlying symptom remains undiagnosed. Recommend a separate investigation task with the user reproducing the exact widget type and flow that gets stuck (HistogramWidget? embedded in GroupWidget? after live tick? after manual cla?). Without a deterministic repro the diagnosis is guesswork.

## Known Stubs

None. Both fixes are complete and exercised end-to-end:
- The switchPage rollback is a pure deletion — no stub or placeholder.
- The HoverCrosshair guard reorder is functionally complete and covered by the new regression test.

## Self-Check: PASSED

- libs/Dashboard/DashboardEngine.m: switchPage no longer contains `switchPageRefreshFailed`, `260508-ny6`, or `flattenWidgetsForPreview_(activeWs)` (verified by grep).
- libs/FastSense/HoverCrosshair.m: first executable line of onFigureMove_ is `if ~isvalid(obj); return; end` (verified by `awk '/function onFigureMove_/,/^        end$/' | grep -v ^%`).
- tests/test_dashboard_switch_page_refresh.m and tests/fixtures/ThrowingTextWidget.m do not exist (verified via `[ ! -f ... ]`).
- tests/test_hover_crosshair.m contains `@test_invalid_obj_no_error` in the cases dispatch (verified by grep).
- .planning/STATE.md contains both an `od4` row and `Superseded by od4` annotation on ny6 (verified by grep).
- Commit 6ef1a86 (revert) present in `git log --oneline -3` output: `revert(260508-od4-01): roll back ny6 switchPage markDirty+refresh sweep`.
- Commit 936feac (fix) present in `git log --oneline -3` output: `fix(260508-od4-02): guard HoverCrosshair.onFigureMove_ against invalid obj`.
- Constraint-listed dashboard sweep all passed (preview_overlay, event_markers, time_sync_all_pages, widget_button_bar, toolbar_buttons).
- HoverCrosshair guard A/B verified: pre-fix throws "Invalid or deleted object", post-fix returns silently.
