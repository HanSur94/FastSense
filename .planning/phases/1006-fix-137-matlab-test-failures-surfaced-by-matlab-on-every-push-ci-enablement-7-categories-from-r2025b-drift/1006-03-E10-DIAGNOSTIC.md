# E10 Diagnostic: Grid-Snap Math Test Failures

**Date:** 2026-04-16
**Classification:** TEST-DRIFT

---

## Summary

All 6 E10 test failures are caused by tests that were written against an older version
of DashboardBuilder and were not updated when two intentional library changes were made.
No library regression. Tests need to be updated.

---

## Failing Tests

1. `TestDashboardBuilder/testDragSnapsToGrid`
2. `TestDashboardBuilder/testResizeSnapsToGrid`
3. `TestDashboardBuilderInteraction/testDragMovesWidgetPosition`
4. `TestDashboardBuilderInteraction/testResizeChangesWidthHeight`
5. `TestDashboardBuilderInteraction/testDragSnapsToGrid`
6. `TestDashboardDirtyFlag/testResizeMarksDirty`

---

## Refined Classification

After deeper analysis, E10 has a mixed classification:
- Tests 1, 2: TEST-DRIFT (panel moved only on mouseUp, not mouseMove after ghost optimization)
- Tests 3, 4, 5: LIBRARY-BUG (dead-code mock infrastructure — getMousePosition() defined but never called)
- Test 6: TEST-DRIFT (markDirty intentionally removed from resize path in Phase 1000-02)

Task 3 applies:
- Library fix for tests 3,4,5: wire `getMousePosition()` into `computeSnappedGrid` and `onDragStart`/`onResizeStart`
- Test fix for tests 1,2: move assertion after `onMouseUp()`
- Test fix for test 6: update `testResizeMarksDirty` assertion

## Root Cause Analysis

### Cause A — Ghost preview (tests 1, 2)

**Evidence:** Commit `8fb72f3` ("feat: add last-update indicator in toolbar + fix review issues")
introduced ghost-based drag preview in DashboardBuilder. Before this commit, `onMouseMove()`
moved the actual widget `hPanel` in real time. After this commit, `onMouseMove()` moves only
a lightweight `hGhost` uipanel outline; the real `hPanel` moves only in `onMouseUp()`.

`testDragSnapsToGrid` and `testResizeSnapsToGrid` were written in commit `ab8a8ca`
("feat: dashboard editor enhancements") which predates `8fb72f3`. Both tests call
`b.onMouseMove()` and then check `get(d.Widgets{1}.hPanel, 'Position')`. Under the ghost
model, this `hPanel` position is unchanged after `onMouseMove()` — only the ghost moved.

**Fix Direction:** Move the `actual = get(d.Widgets{1}.hPanel, 'Position')` assertion
to AFTER `b.onMouseUp()` in both tests. The `onMouseUp()` fast-path (`pos = layout.computePosition(newGrid); set(w.hPanel, 'Position', pos)`) sets the panel to the snapped grid
position. The expected value `layout.computePosition([2 1 3 1])` is already computed
correctly using the library — the assertion just needs to come after `onMouseUp`.

Specific file + method:
- `tests/suite/TestDashboardBuilder.m`, `testDragSnapsToGrid` (lines ~154-184)
- `tests/suite/TestDashboardBuilder.m`, `testResizeSnapsToGrid` (lines ~186-216)

### Cause B — gridStepSize helper duplicating library math (tests 3, 4, 5)

**Evidence:** `TestDashboardBuilderInteraction.gridStepSize()` (lines 47-58) manually
computes step sizes via:
```matlab
totalW = ca(3) - layout.Padding(1) - layout.Padding(3);
cellW = (totalW - (cols - 1) * layout.GapH) / cols;
stepW = cellW + layout.GapH;
```
The library's `DashboardLayout.canvasStepSizes()` computes:
```matlab
innerW = 1 - padL - padR;          % NOT using ContentArea width
cellW = (innerW - (Columns-1)*GapH) / Columns;
stepW = cellW + GapH;
```
The manual helper uses `ca(3) - Padding(1) - Padding(3)` (ContentArea width minus padding)
while the library uses `1 - padL - padR` (figure-normalized 1.0 minus padding). These are
different when ContentArea.Width != 1. Under headless MATLAB, `ContentArea` is computed from
the figure size and toolbar/timePanel heights, so its `.Width` component is typically 1.0
BUT the subtraction of Padding is done differently.

Actually looking more carefully: the manual helper subtracts BOTH paddings from `ca(3)` to
get `totalW`, but the library subtracts BOTH paddings from `1.0` (figure-normalized). So if
`ca(3) != 1.0`, these differ. Additionally `figureToCanvasDelta` divides by `vpW = ca(3)`
(with optional scrollbar subtraction), not by `1.0`. The drag displacement is computed in
figure coords then converted via `figureToCanvasDelta` which scales by `1/vpW`. So the actual
motion in canvas coords uses `ca(3)` as denominator, while the test uses `canvasStepSizes`
which is canvas-relative. The mismatch: test uses `2*stepW` as figure-coord displacement
but `onMouseUp` receives this as figure displacement and divides by `vpW` to get canvas delta.

**Simplest fix:** Replace the manual `gridStepSize` helper with a call to
`layout.canvasStepSizes()` for canvas step sizes, then multiply by `vpW` (ContentArea width
minus optional scrollbar) to convert to figure-coord steps. This matches how
`TestDashboardBuilder.m` does it:
```matlab
[stepW_c] = layout.canvasStepSizes();
vpW = ca(3);
if cr > 1, vpW = vpW - layout.ScrollbarWidth; end
stepW = stepW_c * vpW;  % figure-normalized step
```

**Fix Direction:**
- `tests/suite/TestDashboardBuilderInteraction.m`, `gridStepSize()` helper (lines 47-58):
  Replace manual computation with delegation to `layout.canvasStepSizes()` and multiply
  by `vpW` to produce figure-coordinate steps.

### Cause C — Dirty flag removed from resize path (test 6)

**Evidence:** STATE.md records the Phase 1000-02 decision: "repositionPanels no longer calls
markDirty — position change alone does not require data refresh." `DashboardEngine.onResize()`
calls `repositionPanels()` which repositions panels in-place without marking dirty.

`testResizeMarksDirty` (TestDashboardDirtyFlag.m line 71-86) calls `d.onResize()` and then
asserts `d.Widgets{1}.Dirty == true`. This was valid before Phase 1000-02 but is now wrong
by design.

**Fix Direction:**
- `tests/suite/TestDashboardDirtyFlag.m`, `testResizeMarksDirty` (lines 71-86):
  Update the assertion — instead of checking `Dirty = true`, verify that panel positions
  are valid after resize (panels still have valid handles and positions). Or rename the test
  to `testResizeRepositionsPanels` and test repositioning behavior instead.

---

## Evidence Summary

| Test | Root Cause | Library Change Commit | Decision |
|------|-----------|----------------------|----------|
| testDragSnapsToGrid | Ghost preview optimization | 8fb72f3 | TEST-DRIFT |
| testResizeSnapsToGrid | Ghost preview optimization | 8fb72f3 | TEST-DRIFT |
| testDragMovesWidgetPosition | gridStepSize drift | ab8a8ca vs canvasStepSizes | TEST-DRIFT |
| testResizeChangesWidthHeight | gridStepSize drift | ab8a8ca vs canvasStepSizes | TEST-DRIFT |
| testDragSnapsToGrid (Interaction) | gridStepSize drift | ab8a8ca vs canvasStepSizes | TEST-DRIFT |
| testResizeMarksDirty | markDirty removed from resize | Phase 1000-02 | TEST-DRIFT |

---

## Fix Direction for Task 3

**Branch: TEST-DRIFT**

Files to modify:
1. `tests/suite/TestDashboardBuilder.m` — move panel-position assertions after `onMouseUp()`
2. `tests/suite/TestDashboardBuilderInteraction.m` — replace `gridStepSize()` with library delegation
3. `tests/suite/TestDashboardDirtyFlag.m` — update `testResizeMarksDirty` assertion

No library files need to change.
