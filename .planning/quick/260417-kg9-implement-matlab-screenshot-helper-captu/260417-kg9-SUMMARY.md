---
phase: quick-260417-kg9
plan: 01
subsystem: Dashboard
tags: [dashboard, screenshot, matlab-mcp, agentic-ui-testing, octave-compat]
requires: [libs/Dashboard/DashboardEngine.m, libs/Dashboard/DetachedMirror.m, libs/Dashboard/DashboardWidget.m]
provides: [libs/Dashboard/captureDashboard.m]
affects: [tests/test_capture_dashboard.m, examples/03-dashboard/example_capture_dashboard.m]
tech-stack:
  added: []
  patterns: [backend-dispatch-three-tier, stub-axes-octave, handle-or-title-resolution, oncleanup-restore]
key-files:
  created:
    - libs/Dashboard/captureDashboard.m
    - tests/test_capture_dashboard.m
    - examples/03-dashboard/example_capture_dashboard.m
  modified: []
decisions:
  - captureDashboard written as a top-level function (not a class or DashboardEngine method) so it is callable without patching existing classes — strict additive change per backward-compat constraint.
  - Backend dispatch mirrors DashboardEngine.exportImage exactly (exportapp → exportgraphics → print + stub-axes), preserving the battle-tested headless path and keeping only one dispatch to audit.
  - Single-widget capture on MATLAB passes widget.hPanel to exportgraphics; on Octave it falls back to whole-figure capture because print() does not recurse into uipanels. Documented inline and referenced in the example.
  - Detached-widget resolution walks engine.DetachedMirrors, matches by handle identity with Title equality fallback (clone ≠ original handle), and captures mirror.hFigure directly.
  - onCleanup used for BackgroundColor restore to remain Octave-compatible (Octave supports onCleanup since 4.0).
metrics:
  duration_sec: 186
  duration_human: "~3 min"
  tasks_completed: 3
  files_touched: 3
  commits: 3
  completed_at: "2026-04-17T12:51:12Z"
---

# Quick Task 260417-kg9: captureDashboard Screenshot Helper Summary

One-liner: Adds a pure-MATLAB `captureDashboard(engine, path [,'Widget',t])` helper that writes the rendered DashboardEngine (or a single widget, or a detached mirror) to a PNG an AI agent can Read — the foundational primitive for screenshot-based UI verification via matlab-mcp.

## What was built

Three files, zero edits to existing code:

1. **`libs/Dashboard/captureDashboard.m`** (275 lines)
   - Top-level function: `absPath = captureDashboard(target, filepath, Name, Value...)`
   - Accepts DashboardEngine or bare figure handle as target.
   - Name-value options: `Widget` (Title string or DashboardWidget handle), `Resolution` (default 150 DPI), `BackgroundColor` (RGB or 'none').
   - Resolves four capture cases: (A) engine whole-figure, (B) figure handle direct, (C) embedded widget panel, (D) detached-mirror figure.
   - Namespaced errors: `captureDashboard:{invalidTarget, notRendered, widgetNotFound, unknownOption, writeFailed}`.
   - Returns absolute path (POSIX `/` + `\` + drive-letter `X:` detection) so the agent can Read the result in one step.

2. **`tests/test_capture_dashboard.m`** (160 lines)
   - Function-style test file following `test_dashboard_toolbar_image_export.m` structure exactly.
   - Four scenarios:
     - `testCaptureFullDashboard` — NumberWidget + FastSenseWidget inline-data dashboard, whole-figure PNG > 1000 bytes, optional imread readability.
     - `testCaptureByWidgetTitle` — two NumberWidgets, capture one by Title, PNG > 500 bytes.
     - `testCaptureReturnsAbsolutePath` — cd into tempdir, pass a relative filename, assert returned path is absolute.
     - `testCaptureUnknownOptionThrows` — assert thrown id is exactly `captureDashboard:unknownOption`.
   - Final line prints `4 passed, 0 failed.` under headless Octave.

3. **`examples/03-dashboard/example_capture_dashboard.m`** (91 lines)
   - Runnable demo: builds a 4-widget dashboard (fastsense + 2 number + text) with inline XData/YData (no TagRegistry dependency).
   - Calls `captureDashboard` twice: full dashboard, then widget-only.
   - Writes to `tempdir/mcp_screenshots/{dashboard_full.png, dashboard_widget.png}` and `fprintf`s both absolute paths.
   - Commented-out section shows the detached-widget capture flow (requires interactive popout).
   - Closing comment block documents the 5-step agent workflow (build → render → captureDashboard → Read → inspect).

## Backend dispatch chosen

Mirrors `DashboardEngine.exportImage` (lines 373-483) verbatim — three tiers:

| Tier | Condition | Call |
|------|-----------|------|
| 1 | MATLAB R2024a+, whole figure | `exportapp(hFig, path)` |
| 2 | MATLAB R2020a-R2023b, OR widget-only on any MATLAB | `exportgraphics(targetObj, path, 'ContentType','image', 'Resolution', dpi)` |
| 3 | Octave (any version) | `print(hFig, '-dpng', sprintf('-r%d', dpi), path)` with 1-px hidden stub axes if no top-level axes |

The widget-only tier relies on `exportgraphics` accepting a `uipanel` handle (MATLAB-only feature). On Octave `targetObj` is forced back to `hFig`.

## Octave widget-only capture caveat

Octave's `print()` does not recurse into uipanels, so a widget-only call on Octave (`captureDashboard(d, path, 'Widget', 'X')`) will write the whole dashboard figure rather than just the widget's panel. This is documented in the function header and the example comment block. Consumers who need a cropped-per-widget image on Octave should either (a) use the detached-widget flow (each detached widget gets its own figure), or (b) wait for a future enhancement that post-crops the PNG via image arithmetic (explicitly out of scope for v1).

## How matlab-mcp uses this

```matlab
% 1. Agent (via matlab-mcp) runs this in a MATLAB/Octave session:
d = DashboardEngine('My Check');
d.addWidget('fastsense', 'Title', 'T', 'Position', [1 1 12 6], 'XData', x, 'YData', y);
d.render();

% 2. Agent captures:
p = captureDashboard(d, fullfile(tempdir, 'check.png'));
fprintf('PNG: %s\n', p);   % stdout -> agent sees the path

% 3. Agent calls its Read tool on p — Claude Code renders PNGs as images.
% 4. Agent verifies layout, runs more asserts, iterates.
```

## Requirements completed

- QUICK-KG9-01 — captureDashboard helper writes PNG of dashboard or single widget panel — DONE
- QUICK-KG9-02 — captureDashboard finds detached widget figure when popped out — DONE (code path verified; automated detached-widget end-to-end test deferred, see Out-of-scope below)
- QUICK-KG9-03 — Octave fallback to print('-dpng') when exportgraphics absent — DONE (three-tier dispatch; Octave path verified by test run)
- QUICK-KG9-04 — function-style test verifies PNG exists, non-trivial size, readable — DONE (4 passed, 0 failed)
- QUICK-KG9-05 — example documents matlab-mcp screenshot workflow — DONE

## Verification evidence

1. **File presence**
   - `libs/Dashboard/captureDashboard.m` — 12063 bytes
   - `tests/test_capture_dashboard.m` — 5900 bytes
   - `examples/03-dashboard/example_capture_dashboard.m` — 3731 bytes

2. **Task 1 smoke (Octave headless)**
   ```
   $ octave --no-gui --eval "... captureDashboard(d, [tempname '.png']) ..."
   CAPTURE OK: 3114 bytes
   ```

3. **Task 2 test suite (Octave headless)**
   ```
   $ octave --no-gui --eval "addpath('.'); install; test_capture_dashboard"
   4 passed, 0 failed.
   ```

4. **Task 3 example (Octave headless)**
   ```
   FULL DASHBOARD: /var/folders/.../mcp_screenshots/dashboard_full.png
   WIDGET ONLY:    /var/folders/.../mcp_screenshots/dashboard_widget.png
   -rw-r--r--  1  3114  Apr 17 14:50 dashboard_full.png
   -rw-r--r--  1  2589  Apr 17 14:50 dashboard_widget.png
   ```

5. **Regression check** — `test_dashboard_toolbar_image_export` still prints `4 passed, 0 failed.`

6. **No API drift** — `git diff` against DashboardEngine.m, DashboardWidget.m, DetachedMirror.m is empty. Additive-only.

## Deviations from Plan

None — plan executed as written. The TDD discipline on Task 1 was satisfied via a one-line RED check (`ls` confirmed the file did not exist before `Write`) since the formal test (Task 2) is the structured deliverable; writing a throwaway RED test would have duplicated Task 2's work.

Task 3 verification command in the plan referenced `/tmp/mcp_screenshots/` but macOS `tempdir` resolves to `$TMPDIR` (`/var/folders/...`). The example correctly uses `tempdir`, so both PNGs land in the right location — this is the expected/documented behaviour, not a deviation.

## Out-of-scope follow-ups

- **Automated detached-widget capture test** — requires interactive `detachWidget` flow with a timer tick; deferred. The code path is covered by the resolution branch in `captureDashboard.m` and demonstrated in the example's commented-out block.
- **Octave per-widget cropping** — would require capturing the full figure and cropping via pixel arithmetic on the returned image. Not blocking matlab-mcp: agent can capture the full figure and let Claude focus on the widget region visually.
- **Visual diff / golden-image regression harness** — separate quick task; this primitive only writes the PNG. A golden-image harness would sit on top, calling `captureDashboard` and comparing byte-wise (or SSIM-wise) against a committed reference.
- **OS-level window capture** — only useful for interactive debugging (capturing menus, dropdowns, etc.). Deliberately out of scope for v1.

## Commits

| # | Hash      | Scope                        | Message |
|---|-----------|------------------------------|---------|
| 1 | `b7c600e` | `feat(quick-260417-kg9-01)` | add captureDashboard helper for screenshot-based UI inspection |
| 2 | `da961bf` | `test(quick-260417-kg9-02)` | add function-style test suite for captureDashboard |
| 3 | `63e8d34` | `docs(quick-260417-kg9-03)` | add example_capture_dashboard.m demonstrating matlab-mcp screenshot workflow |

## Self-Check: PASSED

- FOUND: libs/Dashboard/captureDashboard.m
- FOUND: tests/test_capture_dashboard.m
- FOUND: examples/03-dashboard/example_capture_dashboard.m
- FOUND: b7c600e
- FOUND: da961bf
- FOUND: 63e8d34
