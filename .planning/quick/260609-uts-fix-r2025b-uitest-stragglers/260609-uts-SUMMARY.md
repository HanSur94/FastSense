---
quick_id: 260609-uts
slug: fix-r2025b-uitest-stragglers
date: 2026-06-09
status: complete
---

# Quick Task 260609-uts: Fix 5 R2025b-drift companion UI test stragglers — SUMMARY

## Outcome

All 3 companion UI suites fully green under R2025b (macOS, live MATLAB):

| Suite | Before | After |
|-------|--------|-------|
| TestTagCatalogPane | 22 ✓ / 2 ✗ | **24 ✓ / 0 ✗** |
| TestInspectorPane | 12 ✓ / 2 ✗ | **14 ✓ / 0 ✗** |
| TestDashboardListPane | 17 ✓ / 1 ✗ | **18 ✓ / 0 ✗** |

**Every fix was test-side. Production code was confirmed correct in all 5 cases** —
no application changes. These were R2025b API drift (1), stale assertions (2, 5),
a refactor the test missed (4), and a fragile test locator (3).

## Fixes

1. **testCATALOG03_headerSelectionRejected** (TestTagCatalogPane) — wrapped the
   header-select simulation in try/catch; R2025b's `MATLAB:ui:ListBox:notASubset`
   throw is accepted as the rejection, older releases still exercise the handler.
2. **testListenersPropertyExists** (TestTagCatalogPane) — assertion now checks the
   real cleanup `obj.Listeners_ = {}` instead of the impossible `delete(obj.Listeners_)`
   (delete on a cell is a MATLAB filename-delete bug — the pane iterates by design).
3. **testBROWSER04_clearButtonRestoresFullList** (TestDashboardListPane) —
   `findDashboardClearButton` rewritten to anchor off the dashboard search field
   and take its sibling × button in the same grid, instead of an ancestor-walk that
   could resolve to the catalog pane's identical × button. Diagnosed by probe:
   driving the real dashboard clear restored 3 (hOpenButtons_=3); 2 "Clear search"
   × buttons exist in the figure.
4. **testINSPECT02_metadataRowsCarryTagFields** (TestInspectorPane) — reads the
   metadata uitable Data (+ title label) for Key/Criticality/Name, since the
   inspector renders metadata in a uitable (`hTagTable_`) for fast live updates.
5. **testCrossCutting_axesParentUipanelInInspectorFile** (TestInspectorPane) —
   fixed over-escaped regex `axes\\('Parent'` → `axes\('Parent'`. Source correctly
   uses `axes('Parent', ...)` (lines 558, 1230).

## Verification

- 3 suites run individually via `run_matlab_test_file`: 24/24, 14/14, 18/18.
- `checkcode` on the 3 files: only pre-existing advisory style findings
  (`verLessThan`, `isempty(strfind)` — patterns already in the files); no new
  violation classes. `%#ok<AGROW>` added to the metadata-table accumulation.
- Probe confirmed production clear restores all 3 dashboards (the bug was the
  test's button locator, not `onClearSearch_`).

## Notes

- Closes the follow-up flagged by quick task 260609-uif. No production regressions.
