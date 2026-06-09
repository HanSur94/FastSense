---
quick_id: 260609-uif
slug: fix-findfig-companion-uifigure-locator
date: 2026-06-09
status: complete
---

# Quick Task 260609-uif: Fix findFig companion-uifigure locator — SUMMARY

## What changed

Replaced the `findFig` helper body in three companion UI test suites
(`TestTagCatalogPane.m`, `TestDashboardListPane.m`, `TestInspectorPane.m`) —
from a `findobj(groot, 'Type','figure', 'Name', ...)` name-search to the existing
public test seam `testCase.App.getFigForTest_()`:

```matlab
testCase.assertNotEmpty(testCase.App, 'findFig: App not constructed');
hFig = testCase.App.getFigForTest_();
testCase.assertNotEmpty(hFig, 'companion uifigure not found');
testCase.assertTrue(isgraphics(hFig), 'findFig: companion uifigure handle invalid');
hFig = hFig(1);
```

No production code changed. `TestFastSenseCompanion`'s `findobj(groot,'Type','figure')`
figure-leak counters were intentionally left alone.

## Root cause (verified, R2025b on macOS)

The companion figure is `HandleVisibility='off'` (deliberate hardening). `findobj`
honours that and returned empty, so `findFig`'s `assertNotEmpty` failed before any
real test body ran. Probe: `findobj=0, findall=1, getFigForTest_=1`. Deterministic,
fails on desktop too — not purely environmental.

## Verification (runtests, R2025b)

| Suite | Before | After |
|-------|--------|-------|
| TestTagCatalogPane | 5 pass / 19 fail | **22 pass / 2 fail** |
| TestDashboardListPane | (most failing at findFig) | **17 pass / 1 fail** |
| TestInspectorPane | (most failing at findFig) | **12 pass / 2 fail** |

~35 previously findFig-blocked tests now run and pass. The remaining failures are
pre-existing, unrelated issues the findFig failure had been masking (see below).

## Surfaced (NOT caused) — deferred follow-ups

The fix un-masked 5 distinct pre-existing failures (likely R2025b drift, cf. Phase
1006). Each is a separate root cause, NOT bundled into this fix:

1. `testCATALOG03_headerSelectionRejected` — R2025b ListBox `notASubset` on `Value` ∉ `ItemsData`.
2. `testListenersPropertyExists` — source-grep: `delete(obj.Listeners_)` missing in `TagCatalogPane.m`.
3. `testBROWSER04_clearButtonRestoresFullList` — clear restores 1 Open button, expected 3.
4. `testINSPECT02_metadataRowsCarryTagFields` — Key/Criticality value labels not present.
5. `testCrossCutting_axesParentUipanelInInspectorFile` — source-grep: `axes('Parent',...)` in `InspectorPane.m`.

## Notes

- GSD tooling migrated mid-session (`get-shit-done/` → `~/.claude/gsd-core/`); quick
  id `260609-uif` hand-assigned (init.quick path had moved). Non-blocking.
