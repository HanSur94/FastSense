# Phase 1004: Dashboard Image Export Button - Context

**Gathered:** 2026-04-15
**Status:** Ready for planning
**Mode:** Smart discuss (batch proposals, all accepted)

<domain>
## Phase Boundary

Add an image export capability to the dashboard toolbar that captures the entire dashboard figure as a PNG or JPEG file. A new "Image" button sits in the global `DashboardToolbar`, opens a `uiputfile` save dialog, and delegates to `print()` on the dashboard figure. Single-page semantics: capture the currently visible/active page only. Pure additive change — no existing toolbar behavior modified, no new external dependencies.

**In scope:**
- New `Image` button on `DashboardToolbar`
- PNG + JPEG format support via `uiputfile` filter
- `print(hFigure, ...)` capture at 150 DPI
- Default filename = `{Engine.Name}_{yyyyMMdd_HHmmss}.{ext}`, sanitized
- Error surfacing via `warndlg`
- Works in both MATLAB and Octave

**Out of scope (deferred):**
- Multi-page capture (all pages at once)
- Detached mirror capture (mirrors are independent figures)
- PDF / SVG / other vector formats
- Configurable DPI as a public property
- Content-area-only capture (excluding toolbar)
- Pausing live mode during capture
- Non-interactive programmatic `exportImage(path)` API (can be added later; this phase focuses on toolbar UX)

</domain>

<decisions>
## Implementation Decisions

### Button Integration
- New dedicated "Image" button — distinct semantics from existing "Export" (which saves `.m` script). Follows 999.3 "Export Data" alongside "Export PNG" precedent.
- Button label: **"Image"** (short, matches existing single-word toolbar style).
- Position: **between `Save` and `Export`** in the right-to-left button strip, keeping file-output actions grouped.
- Tooltip: **"Save dashboard as image (PNG/JPEG)"**.

### Format, Dialog & Filename
- Formats: **PNG + JPEG** (per phase goal).
- Dialog: `uiputfile({'*.png';'*.jpg'}, 'Save Dashboard Image')`. Filter index (1=PNG, 2=JPEG) drives the `print` device flag (`-dpng` / `-djpeg`).
- Default filename: `{sanitized Engine.Name}_{yyyyMMdd_HHmmss}.png`. Sanitization replaces filesystem-unsafe characters `[/\:*?"<>|]` and whitespace with `_`.
- Resolution: **150 DPI** (`-r150`), matching `FastSenseToolbar` PNG export precedent.

### Capture Scope & Edge Cases
- Capture target: **whole `Engine.hFigure`** via `print()` — includes the toolbar. Simplest path; matches `FastSenseToolbar` precedent at libs/FastSense/FastSenseToolbar.m:143.
- Multi-page dashboards: **active page only**. `DashboardEngine` uses page-visibility toggling (per v1.0 performance optimization), so `print()` naturally captures the active page.
- Live mode: **capture as-is**; no pause/resume to avoid coordinating timer state.
- Error handling: `warndlg` on write failure, consistent with `DashboardToolbar.onEdit`.

### Claude's Discretion
- Method placement on `DashboardEngine` vs private toolbar helper: decide during plan based on reuse potential. A thin `DashboardEngine.exportImage(filepath, [format])` delegate is likely — parallels the existing `DashboardEngine.save(path)` and `DashboardEngine.exportScript(path)` pattern used by `DashboardToolbar.onSave`/`onExport`.
- Exact method name: `exportImage` recommended (verb-noun, matches `exportScript`).
- Filename sanitization implementation (regex vs char replacement loop): whichever is Octave-safe and shortest.
- Test file placement: new `tests/test_dashboard_toolbar_image_export.m` + suite equivalent, or extend existing toolbar test(s). Decide during plan.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`libs/Dashboard/DashboardToolbar.m`** — existing toolbar class with `hExportBtn`, `hSaveBtn` button pattern (text uicontrol, right-to-left placement via `rightEdge` accumulator). Add `hImageBtn` following this pattern.
- **`libs/FastSense/FastSenseToolbar.m:143`** — proven single-line PNG export: `print(obj.hFigure, '-dpng', '-r150', filepath)`. Directly adaptable.
- **`libs/FastSense/FastSenseToolbar.m` (Export Data, Phase 999.3)** — dual-format `uiputfile` pattern using filter index to dispatch (`idx=1→csv`, `idx=2→mat`). Directly reusable for PNG/JPEG dispatch.
- **`DashboardEngine.save(path)` / `exportScript(path)`** — engine-level method pattern invoked by toolbar buttons. Suggests a new `DashboardEngine.exportImage(filepath, format)` delegate.
- **`DashboardEngine.Name`** property — source for default filename prefix.

### Established Patterns
- Toolbar buttons are plain text uicontrols (no CData icons) in `DashboardToolbar`. Contrast with `FastSenseToolbar` which uses pixel-art icons. Stick with text for consistency within `DashboardToolbar`.
- `uiputfile` is called from toolbar on-handlers; file path check `if file ~= 0` guards the cancel case. See `DashboardToolbar.onSave` / `onExport`.
- Engine delegate methods are invoked with `obj.Engine.methodName(args)`. Keep toolbar callbacks thin.
- `warndlg(message, title)` for recoverable UI errors (see `onEdit`).
- `print(hFigure, '-d<format>', '-r<dpi>', filepath)` works in both MATLAB and Octave; `exportgraphics` is MATLAB-only (R2020a+) and should be avoided for Octave compatibility.

### Integration Points
- **`DashboardToolbar` constructor** — button placement in the right-edge button strip (libs/Dashboard/DashboardToolbar.m:63-106).
- **`DashboardEngine`** — new `exportImage(filepath, format)` method, peer to `save(path)` and `exportScript(path)`.
- **Property additions** — `hImageBtn` on `DashboardToolbar` (handle storage).
- **No serializer changes** — image export is a runtime action, not persisted in dashboard JSON/`.m`.
- **No theme changes** — uses existing figure background / widget rendering.

</code_context>

<specifics>
## Specific Ideas

- Default filename follows `{name}_{yyyyMMdd_HHmmss}.{ext}` pattern — readable, sortable, unique per second.
- Filter index from `uiputfile` drives format (not extension re-parsing), matching `FastSenseToolbar.onExportData` precedent.
- 150 DPI resolution — same as existing `FastSenseToolbar` PNG export so captured dashboard and single-plot exports are visually consistent.

</specifics>

<deferred>
## Deferred Ideas

- **Multi-page image export** — capture all pages as separate files or stitched into one image. Future phase if user demand emerges.
- **Detached mirror capture** — include pop-out widgets in export. Would require iterating `DashboardEngine.DetachedMirrors` and producing multiple images; out of scope.
- **PDF / SVG vector output** — wider format support; defer until requested.
- **Configurable DPI property** (e.g., `Engine.ImageExportDPI`) — expose if users request higher/lower resolution control.
- **Programmatic `DashboardEngine.exportImage(path)` public API** — this phase focuses on toolbar UX. A public method will naturally exist as the toolbar delegate; further polish/docs/tests for standalone programmatic use could be a follow-up if used from scripts.
- **Content-area-only capture** (excluding the toolbar itself) — a "clean screenshot" variant. Deferred as a future option.
- **Pause-and-resume during live capture** — avoid visual glitches if refresh fires mid-capture. Only needed if users report artifacts.

</deferred>
