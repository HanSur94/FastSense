---
quick_id: 260609-uif
slug: fix-findfig-companion-uifigure-locator
date: 2026-06-09
status: planned
mode: quick
---

# Quick Task 260609-uif: Fix findFig companion-uifigure locator in UI test suites

## Objective

Repair the `findFig` test helper in the companion UI suites so the suites can
locate the companion `uifigure`. The helper used `findobj(groot, ...)`, which
cannot see the companion figure (it is `HandleVisibility='off'`), causing a
cascade of `findFig: companion uifigure not found` assertion failures.

## Root Cause (verified empirically, R2025b)

Reproduction probe (build companion exactly as the tests do, then locate):

```
findobj(groot,'Type','figure','Name','FastSense Companion') -> 0  (NOT FOUND)
findall(groot, ...)                                          -> 1
app.getFigForTest_()                                         -> 1  (callable)
FIG  Name="FastSense Companion"  Visible=on  HandleVisibility=off
```

The companion figure ends up `HandleVisibility='off'` (deliberate hardening —
keeps stray `gcf` / `close all` / `findobj` off the app figure). `findobj`
honours `HandleVisibility`, so it returns empty → `findFig`'s
`assertNotEmpty` fails before the real test body runs. Deterministic; fails on
macOS desktop too (`desktop=1, ismac=1`), not just headless CI.

## Decision

Fix the **test**, not production — `HandleVisibility='off'` is correct app
behaviour. Replace the `groot` name-search with the existing public test seam
`testCase.App.getFigForTest_()` (returns `obj.hFig_`): robust to
`HandleVisibility`, name-agnostic (also fixes `TestInspectorPane`, which searched
a different name `'Companion Test'`), and unambiguous (no multi-figure risk).
`findall` would also locate it but keeps the fragile name-search; the direct
seam is the source fix.

## Tasks

**Files:** `tests/suite/TestTagCatalogPane.m`, `tests/suite/TestDashboardListPane.m`,
`tests/suite/TestInspectorPane.m` (each has a private `findFig` helper)

- **action:** Replace each `findFig` body (`findobj(groot,...)` + regexp fallback)
  with `hFig = testCase.App.getFigForTest_();` guarded by `assertNotEmpty(App)`,
  `assertNotEmpty(hFig)`, and `assertTrue(isgraphics(hFig))`.
- **verify:** run each suite via `runtests`; the `findFig`-dependent tests pass.
- **done:** all previously `findFig`-blocked tests run to completion.

Left untouched: `TestFastSenseCompanion`'s `findobj(groot,'Type','figure')` calls
— those are figure-leak counters (different purpose), not figure locators.

## Out of scope (pre-existing failures the findFig bug was MASKING)

These now run-to-completion and fail for unrelated reasons — surfaced, not caused,
by this fix. Each is a separate task:

1. `TestTagCatalogPane/testCATALOG03_headerSelectionRejected` — R2025b ListBox
   `MATLAB:ui:ListBox:notASubset` (setting `Value` ∉ `ItemsData` now throws).
2. `TestTagCatalogPane/testListenersPropertyExists` — source-grep asserts
   `delete(obj.Listeners_)` exists in `TagCatalogPane.m` (it does not).
3. `TestDashboardListPane/testBROWSER04_clearButtonRestoresFullList` — clear
   restores 1 Open button, expected 3.
4. `TestInspectorPane/testINSPECT02_metadataRowsCarryTagFields` — Key/Criticality
   value labels not found.
5. `TestInspectorPane/testCrossCutting_axesParentUipanelInInspectorFile` —
   source-grep asserts `axes('Parent', ...)` in `InspectorPane.m`.

Likely R2025b drift (cf. Phase 1006 "137 failures"). Deferred for a separate pass.
