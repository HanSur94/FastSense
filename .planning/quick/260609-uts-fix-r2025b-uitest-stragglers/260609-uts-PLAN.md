---
quick_id: 260609-uts
slug: fix-r2025b-uitest-stragglers
date: 2026-06-09
status: complete
mode: quick
---

# Quick Task 260609-uts: Fix 5 R2025b-drift companion UI test stragglers

## Objective

Fix the 5 pre-existing failures in the companion UI suites that were surfaced (not
caused) by the findFig fix (quick task 260609-uif). Make TestTagCatalogPane,
TestInspectorPane, and TestDashboardListPane fully green under R2025b.

## Root cause (per straggler — ALL test issues; production verified correct)

1. **testCATALOG03_headerSelectionRejected** — R2025b ListBox throws
   `MATLAB:ui:ListBox:notASubset` when Value is set to an item not in ItemsData
   (group headers have ItemsData=[]). The throw IS the rejection; the old test
   set the value directly and expected the handler to clear it.
2. **testListenersPropertyExists** — asserted source contains `delete(obj.Listeners_)`.
   TagCatalogPane deliberately does NOT use that (delete() on a CELL array is a
   MATLAB filename-delete bug — there is a source comment saying so); it iterates
   and resets `obj.Listeners_ = {}`. The asserted pattern would itself be a bug.
3. **testBROWSER04_clearButtonRestoresFullList** — `findDashboardClearButton`
   helper picked the WRONG × button. Both the dashboard pane and catalog pane have
   a × / "Clear search" button; the ancestor-walk disambiguation climbed to a
   shared ancestor that also contains the dashboard Open buttons, so the catalog
   clear "saw" an Open sibling and could be selected under R2025b — clearing the
   catalog, leaving the dashboard list narrowed (1 Open button, expected 3).
   Verified via probe: driving the REAL dashboard clear restores 3.
4. **testINSPECT02_metadataRowsCarryTagFields** — tag metadata is rendered in a
   uitable (`hTagTable_`, `buildTagTableData_`) for fast live updates, not uilabels.
   The test searched `Label` widgets for the Key/Criticality values.
5. **testCrossCutting_axesParentUipanelInInspectorFile** — over-escaped regex
   `axes\\('Parent'` (double backslash → requires a literal backslash). The source
   correctly uses `axes('Parent', ...)`. Confirmed in MATLAB: single-backslash
   pattern matches, double does not.

## Tasks

- **TestTagCatalogPane.m**: wrap header-select in try/catch accepting the R2025b
  `notASubset` throw (#1); fix testListenersPropertyExists to assert the real
  cleanup `obj.Listeners_ = {}` (#2).
- **TestInspectorPane.m**: read the uitable Data (+ labels) for metadata (#4);
  fix the axesParent regex to single backslash (#5).
- **TestDashboardListPane.m**: rewrite `findDashboardClearButton` to anchor off
  the dashboard search field and take its sibling × button in the same grid (#3).
- **verify**: run all 3 suites via MATLAB.
- **done**: TagCatalogPane 24/24, InspectorPane 14/14, DashboardListPane 18/18.

## Scope / non-goals

- TEST-only changes. No production code modified (each root cause confirmed to be
  correct production behaviour + a stale/incompatible test).
