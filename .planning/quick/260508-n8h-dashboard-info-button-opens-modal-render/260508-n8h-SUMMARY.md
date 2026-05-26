---
phase: 260508-n8h
plan: 01
subsystem: Dashboard/DashboardEngine
tags: [dashboard, info-button, uihtml, modal, in-app-render, ux]
dependency_graph:
  requires: [DashboardEngine.writeAndOpenInfoHtml, MarkdownRenderer.render]
  provides: [in-app-info-modal]
  affects: [DashboardToolbar.onInfo, TestDashboardInfo]
tech_stack:
  added: [uihtml]
  patterns: [modal-uifigure, handle-reuse, autoresize-via-SizeChangedFcn, static-test-helper]
key_files:
  created: []
  modified:
    - libs/Dashboard/DashboardEngine.m
    - tests/suite/TestDashboardInfo.m
decisions:
  - "Reuse a single cached InfoModalFigure_ across repeated Info clicks (refocus + update HTMLSource) rather than stacking new windows — matches how MATLAB Help and Companion behave."
  - "Keep InfoTempFile written every time, even on the modal codepath, so existing TestDashboardInfo assertions and any external consumers reading the file continue to work."
  - "Guard the modal codepath behind ~OCTAVE && usejava('desktop') && ~batchStartupOptionUsed() — Octave keeps the system('open ...') handoff and -batch / -nodisplay simply leaves the temp file on disk (matching the prior CI-safety carve-out for the old web() path)."
  - "AutoResizeChildren='off' + SizeChangedFcn lets the uihtml panel fill the figure on resize; uihtml does not honour normalized Position with auto-resize."
  - "Wrap uifigure construction in try/catch so older MATLAB releases without uihtml degrade silently (warning + temp file remains on disk) instead of crashing the dashboard."
metrics:
  duration: "< 15 min"
  completed: "2026-05-08"
  tasks_completed: 2
  files_modified: 2
---

# Phase 260508-n8h Plan 01: Dashboard Info button opens modal in-app window Summary

Replaced the system-browser handoff (`web(InfoTempFile, '-new')`) with an in-app modal `uifigure` containing a `uihtml` panel, so the dashboard's Info page renders inside MATLAB instead of bouncing the user out to their default browser.

## What Was Built

### DashboardEngine.m

- New private property `InfoModalFigure_ = []` caches the modal figure handle.
- New private helper `showInfoModal_(html)`:
  - If a cached figure is still open: updates the `Name`, replaces the `uihtml.HTMLSource`, brings it to front, and returns.
  - Otherwise creates a new `uifigure` (800x600 centered, `WindowStyle = 'modal'`), embeds a `uihtml` panel filling the figure, sets `AutoResizeChildren = 'off'` plus a `SizeChangedFcn` so the panel keeps filling the figure on resize, and installs a `CloseRequestFcn` that clears the cache and disposes the figure.
  - Wrapped in `try/catch` so older releases without `uihtml` raise a `DashboardEngine:infoModalCreateError` warning instead of crashing — the temp HTML file remains on disk regardless.
- New helpers `onInfoModalResize_` and `onInfoModalClose_` (the latter clears `InfoModalFigure_` so the next click opens a fresh window).
- `writeAndOpenInfoHtml`: replaced the desktop branch's `web(obj.InfoTempFile, '-new')` with `obj.showInfoModal_(html)`. The Octave branch (`system('open ...')` etc.) is unchanged; the headless / `-batch` carve-out is preserved exactly as before.
- `delete(obj)` now also closes the modal figure if it is still open, so engines never leave orphan uifigures behind.
- `InfoTempFile` is still populated unconditionally — backward compatibility for any external code or test that reads it from disk.

### tests/suite/TestDashboardInfo.m

- `testShowInfoOpensModalFigure` — calls `showInfo()` and asserts that `InfoModalFigure_` is populated, is a valid handle, contains a `uihtml` child, and that `InfoTempFile` is still on disk (backward-compat assertion).
- `testShowInfoModalReusesFigure` — calls `showInfo()` twice and verifies the same figure handle is reused (`firstHandle == secondHandle`).
- Both tests skip on headless runs via `testCase.assumeTrue(usejava('desktop'))` — `uihtml` requires the MATLAB desktop, and CI's `-batch -nodisplay` mode does not satisfy the guard.
- Static helper `TestDashboardInfo.tryCloseInfoModal(d)` centralises the teardown logic so `addTeardown` callbacks stay terse and resilient to already-closed handles.
- Existing tests untouched — they still run and the `InfoTempFile` contract they assert (e.g. `testShowInfoReadsFile`, `testShowInfoWithoutInfoFileShowsPlaceholder`) is unaffected.

## Tasks

| # | Task | Commit |
|---|------|--------|
| 1 | Add `showInfoModal_` and route `writeAndOpenInfoHtml` through it | `c8fadf1` |
| 2 | Add modal-coverage tests in `TestDashboardInfo` | `8b525a8` |

## Deviations from Plan

None — plan executed exactly as written.

## Open Risks / Follow-ups

- `WindowStyle = 'modal'` blocks interaction with the dashboard while open. If users want to compare the info page against the dashboard side-by-side, switch to `'normal'` (or add a config option). Logged as a possible follow-up; not changed here because the original `web(...)` path was implicitly modal in the sense that it stole window focus too.
- A few older MATLAB releases (< R2018a) lack `uihtml`. Those releases now log a `DashboardEngine:infoModalCreateError` warning and the user is expected to open the temp HTML file manually. R2020b+ (the project's stated minimum) supports `uihtml`, so this is a soft-degradation path only.

## Self-Check: PASSED

- `libs/Dashboard/DashboardEngine.m` contains `showInfoModal_`, `InfoModalFigure_`, `onInfoModalResize_`, `onInfoModalClose_` (verified via grep).
- `web(obj.InfoTempFile` is no longer present in `DashboardEngine.m` (verified via grep).
- `tests/suite/TestDashboardInfo.m` contains `testShowInfoOpensModalFigure` and `testShowInfoModalReusesFigure` (verified via grep).
- Commit `c8fadf1` (DashboardEngine.m) confirmed in `git log`.
- Commit `8b525a8` (TestDashboardInfo.m) confirmed in `git log`.
- `InfoTempFile` is still written unconditionally (line 814 of DashboardEngine.m: `obj.InfoTempFile = [tempname '.html']`).
- `cleanupInfoTempFile` is unchanged and still called from `delete(obj)`.
- Octave / `-batch` / `-nodisplay` branches are unchanged — verified by reading the conditional in `writeAndOpenInfoHtml`.
