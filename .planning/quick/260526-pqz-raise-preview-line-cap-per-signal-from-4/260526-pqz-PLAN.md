---
phase: quick-260526-pqz
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardEngine.m
  - tests/test_dashboard_preview_overlay.m
autonomous: true
requirements: [PREVIEW-CAP-1000]
must_haves:
  truths:
    - "computePreviewEnvelopeReturning_ clamps nBuckets to at most 1000 (was 400)"
    - "The doc-comment on computePreviewEnvelope reports the new clamp range [50, 1000]"
    - "The inline comment on the clamp expression reports the new clamp range [50, 1000]"
    - "The slider preview lines still render correctly for short and long signals (no shape regression)"
    - "No test hard-asserts the old 400 cap (regression sweep clean)"
  artifacts:
    - path: libs/Dashboard/DashboardEngine.m
      provides: "computePreviewEnvelopeReturning_ with raised per-signal preview cap"
      contains: "max(50, min(1000, floor(axWpx / 2)))"
    - path: tests/test_dashboard_preview_overlay.m
      provides: "Consistent doc-comment about adaptive bucket range"
      contains: "[50, 1000]"
  key_links:
    - from: "libs/Dashboard/DashboardEngine.m::computePreviewEnvelopeReturning_"
      to: "libs/Dashboard/FastSenseWidget.m::getPreviewSeries"
      via: "ws{i}.getPreviewSeries(nBuckets) at line 3582"
      pattern: "ws\\{i\\}\\.getPreviewSeries\\(nBuckets\\)"
---

<objective>
Raise the per-signal slider-preview-line cap from 400 to 1000 datapoints in
`DashboardEngine.computePreviewEnvelopeReturning_`. The cap is the upper
bound of the `nBuckets` derived from the dashboard figure's pixel width;
each bucket produces exactly one (x, yMid) point on the per-widget preview
line drawn into the bottom `TimeRangeSelector` strip.

Purpose: Give users denser preview detail per signal in wide windows. The
old `min(400, floor(axWpx / 2))` clamp meant any window wider than ~800 px
hit the 400-point ceiling. Raising the ceiling to 1000 lets very wide
displays (1440 px / 1920 px / ultrawide) drive proportionally more
pixel-aligned preview detail.

Output:
- `libs/Dashboard/DashboardEngine.m`: three edits in `computePreviewEnvelopeReturning_`
  (the code clamp + two comments that document the clamp range).
- `tests/test_dashboard_preview_overlay.m`: one comment update for consistency
  (range mentioned in a regression test comment, not an assertion).

Out of scope (per task specifics): cache-invalidation logic. The cached
`PreviewNBuckets_` on `DashboardEngine` is intentionally left alone — a
running demo will only pick up the new cap on the next `DashboardEngine`
instantiation (e.g., demo restart, or a resize that triggers the existing
invalidation at line 2241).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@./CLAUDE.md
@.planning/STATE.md

<interfaces>
<!-- The exact site to edit. Executor should make the edit at these line
     numbers; do NOT re-derive by re-reading. Use grep to verify line
     numbers haven't shifted before editing if uncertain. -->

From libs/Dashboard/DashboardEngine.m (current state, ~lines 3516-3560):
```matlab
function computePreviewEnvelope(obj, nBuckets)
%COMPUTEPREVIEWENVELOPE Aggregate per-bucket min/max across the
%   currently active page's widgets (including nested GroupWidget
%   children) and push the result onto the selector's envelope
%   patch (D-07, D-08). Multi-page dashboards therefore reflect
%   only the active tab — switchPage() recomputes the envelope so
%   navigation stays in sync. nBuckets optional; when omitted,
%   defaults to ~200 based on panel axes pixel width, clamped to
%   [50, 400]. Silently no-ops when no selector is wired yet
%   (e.g. before render()).
    if nargin < 2, nBuckets = []; end
    obj.computePreviewEnvelopeReturning_(nBuckets);
end

function env = computePreviewEnvelopeReturning_(obj, nBuckets)
%COMPUTEPREVIEWENVELOPERETURNING_ computePreviewEnvelope + return.
%   ...
    env = [];
    if isempty(obj.TimeRangeSelector_) || ...
            ~isa(obj.TimeRangeSelector_, 'TimeRangeSelector')
        return;
    end
    if isempty(nBuckets)
        % Derive nBuckets from figure pixel width; clamp to [50, 400].
        % Cache the computed value so we avoid get/set Units on every
        % live tick (figure size rarely changes between ticks).
        if obj.PreviewNBuckets_ > 0
            nBuckets = obj.PreviewNBuckets_;
        else
            nBuckets = 200;
            try
                oldU = get(obj.hFigure, 'Units');
                set(obj.hFigure, 'Units', 'pixels');
                figPx = get(obj.hFigure, 'Position');
                set(obj.hFigure, 'Units', oldU);
                axWpx = figPx(3) * 0.94;
                nBuckets = max(50, min(400, floor(axWpx / 2)));
            catch
            end
            obj.PreviewNBuckets_ = nBuckets;
        end
    end
    ...
```

From libs/Dashboard/FastSenseWidget.m::getPreviewSeries (around line 765-767),
the per-widget downstream consumer — no change needed, included for context:
```matlab
nBucketsEff = max(1, min(nBuckets, floor(numel(x) / 2)));
```
This further clamps `nBuckets` to `floor(numel(x) / 2)` per widget — for
short signals it correctly limits to half the sample count; for long
signals it now allows up to 1000 buckets. No edit required here.
</interfaces>

<grep_verification>
The literal `400` appears in EXACTLY three places in DashboardEngine.m
(all in the same method body), confirmed by `grep -n "\b400\b"`:

```
libs/Dashboard/DashboardEngine.m:3524  %   [50, 400]. Silently no-ops...
libs/Dashboard/DashboardEngine.m:3542  % Derive nBuckets from figure pixel width; clamp to [50, 400].
libs/Dashboard/DashboardEngine.m:3555                          nBuckets = max(50, min(400, floor(axWpx / 2)));
```

One additional occurrence in tests (comment only, not an assertion):
```
tests/test_dashboard_preview_overlay.m:95  %   Default aggregator picks nBuckets in [50, 400]; with 50 samples,
```

No test file contains `assert(... == 400)` or similar value-pinning, so
no test logic changes are required.
</grep_verification>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Raise the cap (DashboardEngine + comment sync)</name>
  <files>libs/Dashboard/DashboardEngine.m, tests/test_dashboard_preview_overlay.m</files>
  <action>
    Make four single-character edits — three in `libs/Dashboard/DashboardEngine.m`
    and one in `tests/test_dashboard_preview_overlay.m`. Change `400` → `1000` at
    each site. Do NOT add cache-invalidation logic and do NOT change anything
    else in `computePreviewEnvelopeReturning_`. Keep edits surgical.

    Use the `Edit` tool four times with unique surrounding context:

    1) **DashboardEngine.m line ~3524 (doc comment in `computePreviewEnvelope`):**
       - Find:    `%   [50, 400]. Silently no-ops when no selector is wired yet`
       - Replace: `%   [50, 1000]. Silently no-ops when no selector is wired yet`

    2) **DashboardEngine.m line ~3542 (inline comment in `computePreviewEnvelopeReturning_`):**
       - Find:    `% Derive nBuckets from figure pixel width; clamp to [50, 400].`
       - Replace: `% Derive nBuckets from figure pixel width; clamp to [50, 1000].`

    3) **DashboardEngine.m line ~3555 (the actual clamp expression):**
       - Find:    `nBuckets = max(50, min(400, floor(axWpx / 2)));`
       - Replace: `nBuckets = max(50, min(1000, floor(axWpx / 2)));`

    4) **tests/test_dashboard_preview_overlay.m line ~95 (test doc-comment for
       consistency — comment text only, not test logic):**
       - Find:    `%   Default aggregator picks nBuckets in [50, 400]; with 50 samples,`
       - Replace: `%   Default aggregator picks nBuckets in [50, 1000]; with 50 samples,`

    Rationale for the test-file comment edit: the comment explains the
    range the aggregator picks from — keeping it stale would mislead future
    readers. The actual assertion below (line ~110: `numel(xd) >= 4`) does
    not depend on the upper bound, so no test logic changes.

    Per the task specifics: **do not** add invalidation of `PreviewNBuckets_`.
    Users on a running demo session must restart the demo for the new cap
    to take effect (or trigger the existing resize-based invalidation at
    DashboardEngine.m line 2241). Note this in the commit message.
  </action>
  <verify>
    <automated>grep -nE "\\b400\\b" libs/Dashboard/DashboardEngine.m tests/test_dashboard_preview_overlay.m</automated>
    Expected output: empty (no matches). If any `400` literal remains in
    these two files, fix and re-grep.

    Additionally, run `mcp__matlab__check_matlab_code` on
    `libs/Dashboard/DashboardEngine.m` and confirm no new lint/syntax issues
    were introduced compared to baseline. Three trivial textual edits in
    constant literals and comments should produce identical diagnostics.
  </verify>
  <done>
    - `grep -n "\\b400\\b" libs/Dashboard/DashboardEngine.m` returns no matches.
    - `grep -n "\\b400\\b" tests/test_dashboard_preview_overlay.m` returns no matches.
    - `grep -n "\\b1000\\b" libs/Dashboard/DashboardEngine.m` returns at least 3 matches in `computePreviewEnvelope` / `computePreviewEnvelopeReturning_` (lines ~3524, ~3542, ~3555).
    - `mcp__matlab__check_matlab_code` on the edited file reports no new errors/warnings vs. baseline.
    - The `nBuckets = max(50, ...)` line in `computePreviewEnvelopeReturning_` now reads `min(1000, floor(axWpx / 2))`.
  </done>
</task>

<task type="auto">
  <name>Task 2: Spot-check the preview test suite still passes</name>
  <files>tests/test_dashboard_preview_envelope.m, tests/test_dashboard_preview_overlay.m</files>
  <action>
    Run the two preview-focused test files via `mcp__matlab__run_matlab_test_file`
    to confirm the cap change doesn't break preview rendering on either the
    short-signal adaptive path or the legacy-shape aggregate path. No edits
    are expected here — this is a verification sweep only.

    Test files to run (in order):

    1. `tests/test_dashboard_preview_envelope.m` — exercises the
       legacy aggregate envelope path; specifically asserts that
       `nBuckets=200` (well below both the old 400 and new 1000 cap) still
       produces shape-stable results. Cap change should be invisible here.

    2. `tests/test_dashboard_preview_overlay.m` — exercises the
       per-widget preview-line path (post-260508-das + 260512-cxc).
       Includes the 50-sample adaptive-buckets regression. Cap change
       should be invisible here too because none of the test cases drive
       the figure wider than ~800 px.

    If either suite fails, capture the failing test name + assertion
    message and stop — do NOT attempt to fix the failure inside this
    quick task. Surface the failure to the user; we'll triage in a
    follow-up. The cap-raise edit should be revertable in isolation.

    Also worth a quick spot-glance (no need to run): `tests/suite/TestDashboardEngine.m`,
    `tests/suite/TestDashboardEngineAttachPlantLog.m`,
    `tests/suite/TestDashboardEngineEventMarkers.m` — grep for `400` in
    these confirmed no matches in the pre-plan sweep, so no run needed.
  </action>
  <verify>
    <automated>Both `mcp__matlab__run_matlab_test_file` invocations return all-pass. Grep regression: `grep -rn "\\b400\\b" tests/ | grep -iE "(preview|bucket|envelope)"` returns no matches.</automated>
  </verify>
  <done>
    - `tests/test_dashboard_preview_envelope.m` runs to completion with 0 failures.
    - `tests/test_dashboard_preview_overlay.m` runs to completion with 0 failures.
    - No preview-related test file contains a stale `400` literal.
  </done>
</task>

</tasks>

<verification>
End-to-end verification (manual, optional — not gating):

The user's running industrial-plant demo will continue to display preview
lines clamped to the OLD cap (`PreviewNBuckets_` is cached on the engine
instance). To see the new cap in action the user must either:

  (a) restart the demo (`run demo/industrial_plant/run_demo.m`), or
  (b) resize the dashboard window (the existing path at
      `DashboardEngine.m:2241` invalidates `PreviewNBuckets_` on resize),

then visually confirm wide windows show denser preview detail (more points
per signal in the bottom slider strip).

This is intentional per task specifics — we deliberately did NOT add cache
invalidation logic to keep the change minimal.
</verification>

<success_criteria>
- Three edits applied in `libs/Dashboard/DashboardEngine.m` (1 code line, 2 comments).
- One comment edit applied in `tests/test_dashboard_preview_overlay.m` for consistency.
- `grep "\\b400\\b" libs/Dashboard/DashboardEngine.m` returns no matches.
- `grep "\\b400\\b" tests/test_dashboard_preview_overlay.m` returns no matches.
- `mcp__matlab__check_matlab_code` on `DashboardEngine.m` reports no new diagnostics.
- `tests/test_dashboard_preview_envelope.m` passes.
- `tests/test_dashboard_preview_overlay.m` passes.
- No cache-invalidation logic was added (running-demo users restart to pick up the new cap).
</success_criteria>

<output>
After completion, create
`.planning/quick/260526-pqz-raise-preview-line-cap-per-signal-from-4/260526-pqz-SUMMARY.md`
documenting:
- The four edit sites and final values.
- Test results (pass/fail with counts).
- Reminder that the cached `PreviewNBuckets_` means a running demo must
  be restarted (or the figure resized) to see the new cap take effect.
- Forward-looking note: if a future user requests "the slider should
  always reflect the configured cap immediately", the fix is to either
  (a) call `obj.PreviewNBuckets_ = 0` in `DashboardEngine` setup or
  (b) bump the cache-invalidation path at line 2241 to also re-derive
  on construct. Out of scope for this quick task.
</output>
</content>
</invoke>