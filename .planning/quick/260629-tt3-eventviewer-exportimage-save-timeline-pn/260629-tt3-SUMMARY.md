---
phase: 260629-tt3
plan: "01"
subsystem: EventDetection
tags: [export, image, EventViewer, cross-platform, matlab, octave]
dependency_graph:
  requires: []
  provides: [EventViewer.exportImage]
  affects: [libs/EventDetection/EventViewer.m, tests/suite/TestEventViewerExtras.m]
tech_stack:
  added: []
  patterns: [port-from-sibling-class, 3-tier-export-backend, stub-axes-pattern]
key_files:
  created: []
  modified:
    - libs/EventDetection/EventViewer.m
    - tests/suite/TestEventViewerExtras.m
decisions:
  - "Port DashboardEngine.exportImage verbatim with error-ID substitution — no reinvention of cross-platform logic"
  - "Stub-axes loop retained for parity/safety even though hTimelineAxes is a direct figure child"
metrics:
  duration: "~8 minutes"
  completed: "2026-06-29T19:34:57Z"
  tasks_completed: 2
  files_modified: 2
---

# Phase 260629-tt3 Plan 01: EventViewer.exportImage Summary

Add `EventViewer.exportImage(filepath[, format])` public method so rendered event-timeline figures can be saved as PNG or JPEG in one call, mirroring `DashboardEngine.exportImage` cross-platform logic retargeted to `obj.hFigure`.

## What Was Built

### Task 1 — EventViewer.exportImage method (libs/EventDetection/EventViewer.m)

Added a public `exportImage(obj, filepath, format)` method to the `methods` block (after `stopAutoRefresh`). Body ported verbatim from `DashboardEngine.exportImage` (lines 1018-1169) with three targeted changes:

- `DashboardEngine:notRendered` -> `EventViewer:notRendered`
- `DashboardEngine:unknownImageFormat` -> `EventViewer:unknownImageFormat`
- `DashboardEngine:imageWriteFailed` -> `EventViewer:imageWriteFailed`

Property name `obj.hFigure` required no change (same name on both classes).

Preserved from source:
- Format inference when `nargin < 3 || isempty(format)`: `.jpg`/`.jpeg` -> `jpeg`, else `png`
- Not-rendered guard: `isempty(obj.hFigure) || ~ishandle(obj.hFigure)` -> `EventViewer:notRendered`
- Format switch mapping with `EventViewer:unknownImageFormat` for unknown formats
- `isOctave` / `useExportApp` (R2024a+) / `useExportGraphics` (R2020a+) backend detection via `exist()`
- Stub-axes insertion when `~useExportApp` and no top-level axes (loop detects `hTimelineAxes` and skips stub in normal EventViewer figures)
- `Visible='off'` -> `'on'` toggle around export and restore (headless R2020b compatibility)
- 3-tier MATLAB path: `exportgraphics` 150 DPI -> `print -r150` -> `getframe+imwrite`
- Octave path: `print(obj.hFigure, devFlag, '-r150', filepath)`
- Catch block -> `EventViewer:imageWriteFailed` with stub/visibility cleanup in both paths

Updated class-header method list (line 7): added `%   viewer.exportImage('events.png')` alongside existing usage lines.

**Commit:** `4dec4731`

### Task 2 — Export tests (tests/suite/TestEventViewerExtras.m)

Added four test methods to the `methods (Test)` block, reusing existing `makeFixtureEvents()`, `safeClose()`, `safeDelete()` helpers with `tempname` + `addTeardown` cleanup:

1. **testExportImagePngRoundtrip** — writes PNG, asserts `exist(tmp,'file')==2` and `d.bytes > 0`
2. **testExportImageJpegRoundtrip** — covers explicit `'jpeg'` format and `.jpeg` extension inference, both asserted non-empty
3. **testExportImageUnknownFormatErrors** — `verifyError(..., 'EventViewer:unknownImageFormat')` for `'gif'`
4. **testExportImageNotRenderedAfterClose** — closes figure via `close(fig)`, then `verifyError(..., 'EventViewer:notRendered')`

No new fixture or cleanup machinery added. No existing test or helper modified.

**Commit:** `fe86982a`

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The method targets `obj.hFigure` which is always populated after `buildFigure()` runs in the constructor. No placeholder values or TODO markers.

## Threat Flags

None. No new network endpoints, auth paths, file access patterns beyond the explicitly scoped `filepath` write. T-tt3-02 mitigated: not-rendered guard fires before any backend call; all backend failures caught and re-raised as `EventViewer:imageWriteFailed` with stub/visibility cleanup.

## Self-Check: PASSED

- libs/EventDetection/EventViewer.m: FOUND
- tests/suite/TestEventViewerExtras.m: FOUND
- Commit 4dec4731 (feat — EventViewer.exportImage): FOUND
- Commit fe86982a (test — exportImage tests): FOUND
