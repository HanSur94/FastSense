---
phase: quick-260508-llw
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardEngine.m
  - tests/test_dashboard_time_sync_all_pages.m
autonomous: true
requirements:
  - LLW-01  # broadcastTimeRange must apply to widgets on all pages, not just active
  - LLW-02  # resetGlobalTime must re-attach widgets on all pages
  - LLW-03  # newly-realized widgets on tab switch must inherit current synced range
must_haves:
  truths:
    - "Time-range broadcasts (slider drag, sync button, programmatic broadcastTimeRangeNow) update widget xlim on every page, not only the active page"
    - "Switching tabs after a time-sync action shows widgets at the synced range, not their default/construction range"
    - "resetGlobalTime() re-attaches UseGlobalTime=true on widgets across every page"
    - "Per-tab slider PREVIEW visualization (computePreviewEnvelope, computeEventMarkers) remains active-page only — unchanged"
    - "Per-widget UseGlobalTime semantics unchanged: a manually zoomed widget stays detached from global time after broadcast"
  artifacts:
    - path: "libs/Dashboard/DashboardEngine.m"
      provides: "broadcastTimeRange + resetGlobalTime use allPageWidgets(); switchPage re-broadcasts cached range after realizeBatch; LastSyncedTimeRange_ private cache"
      contains: "obj.allPageWidgets()"
    - path: "tests/test_dashboard_time_sync_all_pages.m"
      provides: "Regression coverage for cross-page time sync, resetGlobalTime, and post-tab-switch re-broadcast"
      contains: "test_dashboard_time_sync_all_pages"
  key_links:
    - from: "DashboardEngine.broadcastTimeRange"
      to: "every widget on every page"
      via: "obj.allPageWidgets() iteration + per-widget setTimeRange (Group recursion handled by GroupWidget.setTimeRange)"
      pattern: "ws = obj.allPageWidgets\\(\\)"
    - from: "DashboardEngine.switchPage"
      to: "newly-realized widgets on the now-active page"
      via: "post-realizeBatch re-broadcast of LastSyncedTimeRange_"
      pattern: "LastSyncedTimeRange_"
    - from: "DashboardEngine.resetGlobalTime"
      to: "every widget on every page"
      via: "obj.allPageWidgets() iteration setting UseGlobalTime = true"
      pattern: "ws = obj.allPageWidgets\\(\\)"
---

<objective>
Fix the bug where time-range synchronization (slider drag, "Sync all" toolbar button, zoom-link, programmatic broadcasts) only updates widgets on the currently active tab. After this plan, time sync is dashboard-wide: switching tabs reveals widgets at the synced time window, not their default range.

Purpose: The user expects "the dashboard's time window" to be a dashboard-wide control state. Today, broadcastTimeRange and resetGlobalTime iterate `activePageWidgets()` only, breaking that mental model on multi-page dashboards.

Output:
- DashboardEngine.broadcastTimeRange iterates `allPageWidgets()` instead of `activePageWidgets()`.
- DashboardEngine.resetGlobalTime iterates `allPageWidgets()`.
- DashboardEngine caches the last broadcast range in a new `LastSyncedTimeRange_` private property.
- DashboardEngine.switchPage re-broadcasts the cached range after realizeBatch so widgets realized on tab-switch inherit the current synced window.
- New regression test `tests/test_dashboard_time_sync_all_pages.m` covering the three behaviors.
- Per-tab slider PREVIEW iteration sites (computePreviewEnvelope, computeEventMarkers — fixed in 260508-kov) remain untouched.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/ROADMAP.md

@libs/Dashboard/DashboardEngine.m
@libs/Dashboard/FastSenseWidget.m
@libs/Dashboard/GroupWidget.m
@libs/Dashboard/DashboardWidget.m
@tests/test_dashboard_preview_overlay.m

<interfaces>
<!-- Key contracts the executor needs. Extracted from codebase. -->
<!-- Use these directly — no further exploration required. -->

From libs/Dashboard/DashboardEngine.m (existing methods, DO NOT modify their bodies — only their callers):

```matlab
% ~L1706-1715  (active page only — used by preview, markers, live tick, scroll-realize)
function ws = activePageWidgets(obj)
    if ~isempty(obj.Pages) && obj.ActivePage >= 1
        ws = obj.Pages{obj.ActivePage}.Widgets;
    else
        ws = obj.Widgets;
    end
end

% ~L1717-1728  (all pages — fall-through to obj.Widgets when single-page)
function ws = allPageWidgets(obj)
    if isempty(obj.Pages)
        ws = obj.Widgets;
        return;
    end
    ws = {};
    for i = 1:numel(obj.Pages)
        ws = [ws, obj.Pages{i}.Widgets]; %#ok<AGROW>
    end
end
```

From libs/Dashboard/DashboardEngine.m (CURRENT buggy bodies — to be patched):

```matlab
% ~L1370-1382  (BUG: uses activePageWidgets — must use allPageWidgets)
function broadcastTimeRange(obj, tStart, tEnd)
    ws = obj.activePageWidgets();   % <-- change to allPageWidgets()
    for i = 1:numel(ws)
        try
            ws{i}.setTimeRange(tStart, tEnd);
        catch ME
            warning('DashboardEngine:timeRangeError', ...
                'Widget "%s" setTimeRange failed: %s', ws{i}.Title, ME.message);
        end
    end
end

% ~L1384-1391  (BUG: same)
function resetGlobalTime(obj)
    ws = obj.activePageWidgets();   % <-- change to allPageWidgets()
    for i = 1:numel(ws)
        ws{i}.UseGlobalTime = true;
    end
    obj.onTimeSlidersChanged();
end
```

From libs/Dashboard/DashboardEngine.m (Hidden test hook — driven by the new test):

```matlab
% ~L1608-1615
function broadcastTimeRangeNow(obj, tStart, tEnd)
    obj.updateTimeLabels(tStart, tEnd);
    obj.broadcastTimeRange(tStart, tEnd);
end
```

From libs/Dashboard/FastSenseWidget.m (~L393-409):
```matlab
function setTimeRange(obj, tStart, tEnd)
    if ~obj.UseGlobalTime
        return;  % manually-zoomed widget stays detached
    end
    if ~isempty(obj.FastSenseObj)
        try
            ax = obj.FastSenseObj.hAxes;
            if ~isempty(ax) && ishandle(ax)
                obj.IsSettingTime = true;
                xlim(ax, [tStart tEnd]);
                obj.IsSettingTime = false;
            end
        catch
            obj.IsSettingTime = false;
        end
    end
end
```
Guards on `~isempty(FastSenseObj)` and `ishandle(ax)` make this a safe no-op for unrealized widgets — calling broadcastTimeRange on hidden-page widgets does NOT crash.

From libs/Dashboard/GroupWidget.m (~L214-223):
```matlab
function setTimeRange(obj, tStart, tEnd)
    for i = 1:numel(obj.Children)
        obj.Children{i}.setTimeRange(tStart, tEnd);
    end
    for i = 1:numel(obj.Tabs)
        for j = 1:numel(obj.Tabs{i}.widgets)
            obj.Tabs{i}.widgets{j}.setTimeRange(tStart, tEnd);
        end
    end
end
```
Group already recurses into Children + Tabs — top-level iteration with allPageWidgets() is sufficient. Do NOT use flattenWidgetsForPreview_ here (it's for series-level extraction, a different contract).

From libs/Dashboard/DashboardEngine.m (~L165-224, switchPage — to be augmented):
- Sets ActivePage, toggles panel Visible, calls realizeBatch(5) if hasUnrealized, then computePreviewEnvelope + computeEventMarkers.
- Currently does NOT re-broadcast time range → newly-realized widgets sit at construction default.

From libs/Dashboard/DashboardEngine.m (SetAccess = private properties block ~L39-78):
- Add new property `LastSyncedTimeRange_ = []` alongside existing time-control properties (after `TimeRangeSelector_`, before `Progress_`).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Broadcast time range across all pages + cache last synced range</name>
  <files>libs/Dashboard/DashboardEngine.m</files>
  <behavior>
    Test cases (verified by Task 3's test file):
    - Test 1.1: After `d.broadcastTimeRangeNow(tStart, tEnd)` on a 2-page dashboard, the active-page FastSenseWidget axes have `xlim == [tStart tEnd]`.
    - Test 1.2: After the same call, switching to page 2 reveals its FastSenseWidget axes ALSO have `xlim == [tStart tEnd]` (NOT the default).
    - Test 1.3: Single-page dashboard (Pages empty) — broadcast still updates all widgets via the obj.Widgets fallback in allPageWidgets().
    - Test 1.4: A widget that has `UseGlobalTime = false` (manually zoomed) keeps its old xlim after broadcast — per-widget detach contract preserved.
    - Test 1.5: After `d.resetGlobalTime()`, every widget on every page has `UseGlobalTime == true`. (Set one widget's UseGlobalTime=false on page 1, one on page 2; verify both flip back to true.)
    - Test 1.6: `LastSyncedTimeRange_` property is populated with `[tStart tEnd]` after a broadcast call.
  </behavior>
  <action>
    Make three surgical changes to libs/Dashboard/DashboardEngine.m. Do NOT touch activePageWidgets() or allPageWidgets() themselves — they are stable accessors. Do NOT touch the preview / event-marker iteration sites (computePreviewEnvelope, computeEventMarkers) — those correctly use activePageWidgets per 260508-kov.

    Change A — Add private cache property (in the `properties (SetAccess = private)` block, ~L39-78, alongside existing time-control fields after `TimeRangeSelector_` line ~L70):

    ```matlab
    LastSyncedTimeRange_ = []   % [tStart tEnd] cache of most recent broadcast (260508-llw); used by switchPage to re-apply current synced window to widgets realized on tab-switch
    ```

    Change B — Patch `broadcastTimeRange` (~L1370-1382). Replace `obj.activePageWidgets()` with `obj.allPageWidgets()`, populate the cache at the top, and update the doc header. Final body:

    ```matlab
    function broadcastTimeRange(obj, tStart, tEnd)
    %BROADCASTTIMERANGE Push time range to widgets across ALL pages (not just active).
    %   Time sync is a dashboard-wide control: dragging the slider, clicking
    %   "Sync all", or calling broadcastTimeRangeNow updates every page's
    %   widgets so switching tabs preserves the synced window. Per-widget
    %   UseGlobalTime=false (manually zoomed) widgets opt out via their own
    %   setTimeRange guard. (260508-llw — was activePageWidgets, caused a
    %   per-tab desync bug.)
        obj.LastSyncedTimeRange_ = [tStart tEnd];
        ws = obj.allPageWidgets();
        for i = 1:numel(ws)
            try
                ws{i}.setTimeRange(tStart, tEnd);
            catch ME
                warning('DashboardEngine:timeRangeError', ...
                    'Widget "%s" setTimeRange failed: %s', ...
                    ws{i}.Title, ME.message);
            end
        end
    end
    ```

    Change C — Patch `resetGlobalTime` (~L1384-1391). Replace `obj.activePageWidgets()` with `obj.allPageWidgets()` and update the doc header. Final body:

    ```matlab
    function resetGlobalTime(obj)
    %RESETGLOBALTIME Re-attach all widgets across ALL pages to global time and apply.
    %   (260508-llw — was activePageWidgets, leaving widgets on inactive
    %   pages still detached after a "Reset" toolbar action.)
        ws = obj.allPageWidgets();
        for i = 1:numel(ws)
            ws{i}.UseGlobalTime = true;
        end
        obj.onTimeSlidersChanged();
    end
    ```

    Constraints:
    - Pure MATLAB / Octave compatible. No new external deps.
    - Follow MISS_HIT line-length (160 max) and existing comment style.
    - Use the namespaced warning ID `DashboardEngine:timeRangeError` already present.
    - Per LLW-01 / LLW-02: every widget on every page receives the broadcast / reset.
    - Do NOT modify `activePageWidgets()`, `allPageWidgets()`, `computePreviewEnvelope`, `computeEventMarkers`, `flattenWidgetsForPreview_`, `onLiveTick`, `onScrollRealize`, or `realizeBatch` — those iteration sites are correct as-is (some are intentionally per-tab per 260508-kov).
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/happy-ramanujan-7d436a &amp;&amp; grep -n "LastSyncedTimeRange_\|allPageWidgets" libs/Dashboard/DashboardEngine.m | head -20 &amp;&amp; matlab -batch "install; addpath('tests'); test_dashboard_preview_overlay" 2>&amp;1 | tail -30</automated>
  </verify>
  <done>
    - `LastSyncedTimeRange_ = []` declared in the private properties block.
    - `broadcastTimeRange` body iterates `allPageWidgets()` AND assigns `obj.LastSyncedTimeRange_ = [tStart tEnd]` at the top.
    - `resetGlobalTime` body iterates `allPageWidgets()`.
    - Doc headers on both methods explicitly say "across all pages, not just active".
    - Existing `test_dashboard_preview_overlay.m` (the 260508-kov per-tab preview regression) still passes — confirming we did not break per-tab preview.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Re-broadcast cached range from switchPage after realizeBatch</name>
  <files>libs/Dashboard/DashboardEngine.m</files>
  <behavior>
    Test cases (verified by Task 3's test file):
    - Test 2.1: 2-page dashboard, page 2 widget unrealized at start. On page 1, call `d.broadcastTimeRangeNow(tStart, tEnd)`. Then `d.switchPage(2)` realizes the page-2 widget; assert its xlim equals `[tStart tEnd]`, NOT its construction default.
    - Test 2.2: When `LastSyncedTimeRange_` is empty (no broadcast has happened yet), `switchPage` does NOT call broadcastTimeRange — widgets render at their construction default. (Guards against re-broadcasting an unset range and clobbering construction-time xlim with a stale default.)
    - Test 2.3: When LastSyncedTimeRange_ is populated but `hasUnrealized == false`, switchPage still calls broadcastTimeRange (idempotent — cheap given FastSenseWidget guards). [Optional; can collapse to "always re-broadcast when cache is set" for simplicity.]
  </behavior>
  <action>
    Augment `switchPage` (~L165-224 in libs/Dashboard/DashboardEngine.m) to re-apply the cached synced time range after `realizeBatch`. This closes LLW-03 — without it, widgets realized on tab-switch sit at their construction default until the next slider event.

    Locate `switchPage` and find the block that ends with the `if hasUnrealized; obj.realizeBatch(5); end` (~L213-215). Immediately after that block, before the existing `% Refresh the preview envelope on the newly active page (D-07).` comment (~L217), insert:

    ```matlab
            % Re-apply the current synced time range so widgets that just
            % realized on this tab inherit the dashboard-wide window
            % instead of their construction default. (260508-llw)
            if ~isempty(obj.LastSyncedTimeRange_)
                rng = obj.LastSyncedTimeRange_;
                obj.broadcastTimeRange(rng(1), rng(2));
            end
    ```

    Notes:
    - Always re-broadcast when the cache is set (don't gate on hasUnrealized) — the broadcast is cheap and idempotent. FastSenseWidget.setTimeRange guards on FastSenseObj non-emptiness and ishandle(ax), so already-realized widgets at the same xlim are a no-op. Simplifies the condition and ensures correctness if a widget got reset somehow.
    - Empty-cache guard prevents re-broadcasting a never-set range, which would clobber widgets' construction xlim with `[]`.
    - Place BEFORE the preview/markers refresh so the re-broadcast triggers FastSense pyramid resolves first; preview computation then sees the consistent state.

    Constraints:
    - Pure MATLAB / Octave compatible.
    - Do NOT introduce new public methods or change `switchPage` signature.
    - Do NOT touch the existing visibility-toggle, button-color, or preview/markers blocks.
    - Comment must reference `260508-llw` so future readers can trace the rationale.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/happy-ramanujan-7d436a &amp;&amp; awk '/function switchPage/,/^        end$/' libs/Dashboard/DashboardEngine.m | grep -n "LastSyncedTimeRange_\|broadcastTimeRange" &amp;&amp; matlab -batch "install; mh_lint libs/Dashboard/DashboardEngine.m" 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - `switchPage` body contains an `if ~isempty(obj.LastSyncedTimeRange_)` block that calls `obj.broadcastTimeRange(rng(1), rng(2))` after `realizeBatch(5)`.
    - The block sits between the unrealized-batch handling and the existing `computePreviewEnvelope` call.
    - Comment references 260508-llw.
    - mh_lint produces no NEW errors on DashboardEngine.m vs. baseline.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Add cross-page time-sync regression test</name>
  <files>tests/test_dashboard_time_sync_all_pages.m</files>
  <behavior>
    New Octave-style function test file with the following test cases. Each subtest constructs a minimal headless dashboard (use `'figure', 'invisible'` or wrap in try/catch around figure creation per existing test patterns).

    Test layout: 2 pages, each with one FastSenseWidget bound to a Sensor with synthetic `(X, Y)` covering overlapping time ranges (e.g., page-1 sensor t=[0,100], page-2 sensor t=[20,120]).

    - case_active_and_inactive_pages_receive_broadcast (LLW-01)
        - Render dashboard, ActivePage = 1.
        - Call `d.broadcastTimeRangeNow(30, 70)`.
        - Assert page-1 widget axes xlim == [30 70].
        - Call `d.switchPage(2)`.
        - Assert page-2 widget axes xlim == [30 70] (NOT page-2 sensor's [20 120] default).

    - case_reset_global_time_reattaches_all_pages (LLW-02)
        - Render. Set page-1 widget UseGlobalTime = false; switch to page 2; set page-2 widget UseGlobalTime = false.
        - Call `d.resetGlobalTime()`.
        - Assert BOTH widgets have UseGlobalTime == true.

    - case_unrealized_widget_on_tab_switch_inherits_synced_range (LLW-03)
        - Render dashboard with page-2 widget unrealized (do not pre-realize page 2; hasUnrealized=true on switchPage(2)).
        - On page 1, `d.broadcastTimeRangeNow(40, 60)`.
        - Call `d.switchPage(2)`. realizeBatch fires, then re-broadcast triggers.
        - Assert page-2 widget is now Realized AND its axes xlim == [40 60].

    - case_manual_zoom_widget_opts_out_of_broadcast (per-widget contract preserved)
        - Render. Set page-2 widget UseGlobalTime = false BEFORE the broadcast.
        - Call `d.broadcastTimeRangeNow(30, 70)`.
        - Switch to page 2.
        - Assert page-2 widget xlim != [30 70] (UseGlobalTime guard short-circuits in FastSenseWidget.setTimeRange).

    - case_single_page_dashboard_unaffected
        - Build a no-Pages dashboard with two widgets in obj.Widgets directly.
        - Call `d.broadcastTimeRangeNow(30, 70)`.
        - Assert both widgets' axes xlim == [30 70] (allPageWidgets() falls through to obj.Widgets).
  </behavior>
  <action>
    Create `tests/test_dashboard_time_sync_all_pages.m` following the project's Octave-style function test pattern (see `tests/test_dashboard_preview_overlay.m` for a near-identical reference: 2-page dashboard construction, FastSenseWidget binding, headless figure handling).

    File skeleton:

    ```matlab
    function test_dashboard_time_sync_all_pages()
    %TEST_DASHBOARD_TIME_SYNC_ALL_PAGES Regression for cross-page time
    %   broadcast (260508-llw). broadcastTimeRange and resetGlobalTime
    %   must apply to widgets on every page, not just the active one.
    %   Newly-realized widgets on tab-switch must inherit the current
    %   synced range. Manually-zoomed widgets (UseGlobalTime=false)
    %   remain detached.
        add_paths_();
        nPassed = 0; nFailed = 0;
        tests = { ...
            @case_active_and_inactive_pages_receive_broadcast, ...
            @case_reset_global_time_reattaches_all_pages, ...
            @case_unrealized_widget_on_tab_switch_inherits_synced_range, ...
            @case_manual_zoom_widget_opts_out_of_broadcast, ...
            @case_single_page_dashboard_unaffected};
        for i = 1:numel(tests)
            try
                tests{i}();
                nPassed = nPassed + 1;
            catch err
                nFailed = nFailed + 1;
                fprintf('  FAIL: %s\n    %s\n', func2str(tests{i}), err.message);
            end
        end
        fprintf('    %d/%d tests passed.\n', nPassed, nPassed + nFailed);
        if nFailed > 0
            error('test_dashboard_time_sync_all_pages:failed', '%d test(s) failed', nFailed);
        end
    end

    function add_paths_()
        thisDir = fileparts(mfilename('fullpath'));
        rootDir = fileparts(thisDir);
        run(fullfile(rootDir, 'install.m'));
    end

    function d = build_two_page_dashboard_(realizePage2)
        %BUILD_TWO_PAGE_DASHBOARD_ Construct a 2-page dashboard with one
        %   FastSenseWidget per page, each backed by a synthetic sensor.
        %   When realizePage2 is false, page 2 is left unrealized (we never
        %   switchPage to it before returning).
        % ... (mirror tests/test_dashboard_preview_overlay.m construction)
    end

    function case_active_and_inactive_pages_receive_broadcast()
        d = build_two_page_dashboard_(true);
        cleanupObj = onCleanup(@() safe_close_(d));
        d.broadcastTimeRangeNow(30, 70);
        ax1 = d.Pages{1}.Widgets{1}.FastSenseObj.hAxes;
        assert_xlim_(ax1, [30 70], 'page 1 active broadcast');
        d.switchPage(2);
        ax2 = d.Pages{2}.Widgets{1}.FastSenseObj.hAxes;
        assert_xlim_(ax2, [30 70], 'page 2 inactive broadcast');
    end

    % ... remaining case_* functions ...

    function assert_xlim_(ax, expected, label)
        actual = get(ax, 'XLim');
        if abs(actual(1) - expected(1)) > 1e-9 || abs(actual(2) - expected(2)) > 1e-9
            error('xlim mismatch (%s): got [%g %g], expected [%g %g]', ...
                label, actual(1), actual(2), expected(1), expected(2));
        end
    end

    function safe_close_(d)
        try delete(d); catch, end
        try close all force; catch, end
    end
    ```

    Implementation requirements:
    - Mirror the headless figure / Sensor / FastSenseWidget construction from `tests/test_dashboard_preview_overlay.m`. DO NOT reinvent — copy the working pattern (Sensor with X/Y arrays, addWidget('fastsense', ...), DashboardEngine with addPage).
    - Use `d.broadcastTimeRangeNow(...)` (the Hidden test hook) — NOT direct `broadcastTimeRange` — to bypass debounce.
    - For case_unrealized_widget_on_tab_switch_inherits_synced_range: the construction must leave page 2 widgets with `Realized == false`. Verify by checking `d.Pages{2}.Widgets{1}.Realized` BEFORE switchPage. (If the engine eagerly realizes both pages on render, file a follow-up — but per the orchestrator's reading of switchPage, off-screen pages stay unrealized until first switch.)
    - For case_manual_zoom_widget_opts_out_of_broadcast: setting UseGlobalTime=false on a widget on a hidden page may require pre-realizing it. If so, switchPage(2) → set UseGlobalTime=false → switchPage(1) → broadcast → switchPage(2) → assert. Document inline if you take this path.
    - Use `1e-9` numerical tolerance for xlim comparisons.
    - Ensure `onCleanup` deletes the dashboard so timers don't leak (matches existing test patterns — see `test_dashboard_preview_overlay.m`).
    - Pure MATLAB / Octave compatible (no `matlab.unittest`).

    Honor CLAUDE.md conventions:
    - File name `test_` + snake_case (Octave-style function test).
    - Local helper functions with trailing underscore.
    - Namespaced error ID `test_dashboard_time_sync_all_pages:failed`.
    - MISS_HIT-friendly: line length ≤ 160, no exotic syntax.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/happy-ramanujan-7d436a &amp;&amp; matlab -batch "install; addpath('tests'); test_dashboard_time_sync_all_pages" 2>&amp;1 | tail -20</automated>
  </verify>
  <done>
    - File `tests/test_dashboard_time_sync_all_pages.m` exists.
    - All 5 case functions present and pass when run via `matlab -batch test_dashboard_time_sync_all_pages`.
    - The previous regression `tests/test_dashboard_preview_overlay.m` still passes (per-tab preview unchanged).
    - Test output ends with `    5/5 tests passed.`
    - No timer leaks (running the file twice in the same MATLAB session does not accumulate `timerfindall()` entries).
  </done>
</task>

</tasks>

<verification>
End-to-end manual smoke (optional, after automated passes):
1. Open a 2-page demo dashboard with FastSense widgets on each page.
2. On page 1, drag the time slider to a sub-range. Switch to page 2. Page-2 widget xlim should match page 1's selection.
3. On page 2, click the time-panel "Reset" button. Switch to page 1. Both pages back to full data range.
4. On page 1, manually zoom one FastSense widget (mouse zoom). Drag the slider. The zoomed widget keeps its zoom (UseGlobalTime=false); other widgets follow the slider on both pages.
5. Verify per-tab slider preview (the envelope shading inside the time-range selector) still reflects the active page's data — NOT the union — confirming 260508-kov was not regressed.
</verification>

<success_criteria>
- `grep -n "obj.activePageWidgets()" libs/Dashboard/DashboardEngine.m | grep -E "broadcastTimeRange|resetGlobalTime"` returns ZERO matches (both call sites converted).
- `grep -n "LastSyncedTimeRange_" libs/Dashboard/DashboardEngine.m` returns ≥ 3 matches (declaration + 2 uses: assignment in broadcastTimeRange, read in switchPage).
- `matlab -batch "install; addpath('tests'); test_dashboard_time_sync_all_pages"` exits 0 with `5/5 tests passed.`
- `matlab -batch "install; addpath('tests'); test_dashboard_preview_overlay"` still exits 0 (no regression on the 260508-kov per-tab preview).
- `mh_lint libs/Dashboard/DashboardEngine.m` produces no new errors versus pre-change baseline.
- Doc headers on `broadcastTimeRange` and `resetGlobalTime` explicitly mention "across all pages, not just active" so future readers don't re-introduce the bug.
</success_criteria>

<output>
After completion, create `.planning/quick/260508-llw-broadcast-time-range-across-all-pages-wi/260508-llw-SUMMARY.md` summarizing:
- Three changes to DashboardEngine.m (property add, two body patches, switchPage augmentation).
- New test file with 5 cases.
- Confirmation that the 260508-kov per-tab preview path was untouched.
- Any deviations from the plan (e.g., if pre-realization was required for the manual-zoom case).
</output>
