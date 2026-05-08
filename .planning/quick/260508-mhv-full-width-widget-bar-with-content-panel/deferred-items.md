# Deferred Items — quick/260508-mhv

## Pre-existing test failures (out of scope)

`tests/test_dashboard_builder_interaction.m` — 5 tests fail BOTH before and after mhv:

- testDragClampsToRightEdge
- testResizeChangesWidthHeight
- testResizeClampsMaxWidth
- testMouseMoveDragUpdatesPanelPosition
- testMouseMoveResizeUpdatesSize

Verified by stash-then-rerun against pre-mhv baseline: same 5 failures with identical error messages. mhv does not introduce or fix these regressions; they belong to a separate ticket targeting the DashboardBuilder mock-mouse / clamping path.

## Notes

The mhv changes DID need a test-side adjustment in this file: read drag/resize start coordinates from `widget.hCellPanel` instead of `widget.hPanel`, because post-mhv `widget.hPanel` is the WidgetContentPanel sub-panel (pixel units) rather than the canvas-normalized cell panel. The new `getCellPanel_` helper preserves the prior contract for the 18 still-passing tests.
