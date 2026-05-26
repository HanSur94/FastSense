---
phase: 260508-kau-slider-preview-aggregates-all-pages-widg
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardEngine.m
  - tests/test_dashboard_preview_overlay.m
  - tests/test_dashboard_engine_event_markers.m
  - tests/suite/TestDashboardEngineEventMarkers.m
autonomous: true
requirements:
  - KAU-01  # Slider preview aggregates lines + markers across ALL pages, not just active page

must_haves:
  truths:
    - "When a multi-page dashboard renders, the time-slider preview lines fold in widgets from EVERY page, not just the active page."
    - "When a multi-page dashboard renders, the time-slider event markers include events from EVERY page's widgets."
    - "Switching pages does not drop or re-scope preview lines or event markers — they continue to reflect all pages."
    - "Single-page dashboards (no Pages added) behave exactly as before — no behavior change."
    - "Existing preview-envelope shape contract (numel == nBuckets when widgets honor the requested bucket count) is preserved."
  artifacts:
    - path: "libs/Dashboard/DashboardEngine.m"
      provides: "computePreviewEnvelopeReturning_ and computeEventMarkers iterating allPageWidgets()"
      contains: "ws = obj.allPageWidgets()"
    - path: "tests/test_dashboard_preview_overlay.m"
      provides: "Regression test asserting multi-page preview lines aggregate across pages"
      contains: "case_multipage_preview_aggregates_all_pages"
    - path: "tests/test_dashboard_engine_event_markers.m"
      provides: "Updated case_switch_page reflecting all-pages contract"
    - path: "tests/suite/TestDashboardEngineEventMarkers.m"
      provides: "Updated testEventMarkersUpdateOnSwitchPage reflecting all-pages contract"
  key_links:
    - from: "DashboardEngine.computePreviewEnvelopeReturning_"
      to: "DashboardEngine.allPageWidgets"
      via: "direct method call"
      pattern: "ws = obj\\.allPageWidgets\\(\\)"
    - from: "DashboardEngine.computeEventMarkers"
      to: "DashboardEngine.allPageWidgets"
      via: "direct method call"
      pattern: "ws = obj\\.allPageWidgets\\(\\)"
---

<objective>
Fix the multi-page dashboard time-slider preview so that the faint preview lines and event markers aggregate widgets from ALL pages, not just the currently active page.

Purpose: Users with multi-page dashboards (e.g. the 6-page industrial-plant demo) currently lose the cross-page picture in the slider preview every time they switch tabs. The slider should show the full envelope of activity across the entire dashboard so users can navigate to interesting time windows regardless of which tab is in front.

Output:
- libs/Dashboard/DashboardEngine.m updated to call `allPageWidgets()` from the two preview iteration sites (and DOC headers updated).
- A new regression test in test_dashboard_preview_overlay.m that builds a multi-page dashboard and asserts the inactive page's widget contributes to the slider preview.
- The two existing switch_page tests updated to reflect the new all-pages-aggregation contract (markers from BOTH pages stay visible after a switch).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@libs/Dashboard/DashboardEngine.m
@libs/Dashboard/TimeRangeSelector.m
@libs/Dashboard/DashboardWidget.m
@libs/Dashboard/FastSenseWidget.m
@tests/test_dashboard_preview_overlay.m
@tests/test_dashboard_engine_event_markers.m
@tests/suite/TestDashboardEngineEventMarkers.m
@tests/test_dashboard_preview_envelope.m

<bug_summary>
`DashboardEngine.computePreviewEnvelopeReturning_` (~L1915) and `DashboardEngine.computeEventMarkers` (~L2020) both iterate `obj.activePageWidgets()`. In multi-page dashboards this restricts the slider preview to just the visible tab. The existing helper `obj.allPageWidgets()` (L1717-1728) already does the correct concatenation but isn't used at these two sites.
</bug_summary>

<interfaces>
From libs/Dashboard/DashboardEngine.m (L1706-1728):

```matlab
function ws = activePageWidgets(obj)
    if ~isempty(obj.Pages) && obj.ActivePage >= 1
        ws = obj.Pages{obj.ActivePage}.Widgets;
    else
        ws = obj.Widgets;
    end
end

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

Critical parity property: when `obj.Pages` is empty, `allPageWidgets()` returns the same set as `activePageWidgets()` (both return `obj.Widgets`). Single-page dashboards see zero behavior change.
</interfaces>

<existing_test_assertions>
Two existing tests currently encode the OLD (active-page-only) contract for switchPage and MUST be updated:

1. `tests/test_dashboard_engine_event_markers.m` -> `case_switch_page` (L57-80):
   - Asserts after `d.switchPage(2)`: `markerXData == [100 200 300]` (P2 only)
   - Asserts after `d.switchPage(1)`: `markerXData == [5 15]` (P1 only)
   - Comment: "Reverse navigation must restore P1 markers, not leak P2's events."

2. `tests/suite/TestDashboardEngineEventMarkers.m` -> `testEventMarkersUpdateOnSwitchPage` (L27-51):
   - Same assertions as above (mirror of the function-based test).

Under the new contract, the slider should show events from BOTH pages regardless of active page. New expected value after either switch: `[5 15 100 200 300]` (sorted union).

All other existing tests are unaffected:
- test_dashboard_preview_envelope.m — single-page dashboards
- test_dashboard_preview_overlay.m — all cases single-page
- TestDashboardEngineEventMarkers other test methods — single-page
</existing_test_assertions>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Switch preview iteration to all-pages and update existing switchPage tests</name>
  <files>
    libs/Dashboard/DashboardEngine.m,
    tests/test_dashboard_engine_event_markers.m,
    tests/suite/TestDashboardEngineEventMarkers.m
  </files>
  <action>
    Implements KAU-01 — the core two-line fix plus DOC updates plus the two existing-test updates that previously encoded the active-page-only contract.

    **Edit A — DashboardEngine.m line ~1915 (`computePreviewEnvelopeReturning_`):**

    Change:
    ```matlab
        ws = obj.activePageWidgets();
    ```
    To:
    ```matlab
        % 260508-kau (KAU-01): aggregate across ALL pages so the slider
        % preview reflects the entire dashboard, not just the active tab.
        % allPageWidgets() returns obj.Widgets unchanged when Pages is
        % empty, preserving single-page behavior bit-for-bit.
        ws = obj.allPageWidgets();
    ```

    **Edit B — DashboardEngine.m line ~1880-1886 (DOC header for `computePreviewEnvelope`):**

    Change the existing comment block from "across active-page widgets" to "across ALL widgets on every page". Specifically:
    ```matlab
    %COMPUTEPREVIEWENVELOPE Aggregate per-bucket min/max across
    %   active-page widgets and push the result onto the selector's
    %   envelope patch (D-07, D-08). nBuckets optional; ...
    ```
    becomes:
    ```matlab
    %COMPUTEPREVIEWENVELOPE Aggregate per-bucket min/max across ALL widgets
    %   on EVERY page and push the result onto the selector's envelope
    %   patch (D-07, D-08). Multi-page dashboards therefore show the full
    %   cross-tab envelope (260508-kau / KAU-01); single-page dashboards
    %   are unaffected because allPageWidgets() returns obj.Widgets when
    %   Pages is empty. nBuckets optional; ...
    ```
    (Keep the rest of the DOC body — the part about default nBuckets clamp [50,400] and "Silently no-ops" — verbatim.)

    **Edit C — DashboardEngine.m line ~2020 (`computeEventMarkers`):**

    Change:
    ```matlab
        ws = obj.activePageWidgets();
    ```
    To:
    ```matlab
        % 260508-kau (KAU-01): aggregate event markers across ALL pages,
        % matching computePreviewEnvelope's all-pages contract. Dedup
        % below already collapses duplicates by Time with max-severity
        % tiebreaker, so cross-page events at identical Times stay safe.
        ws = obj.allPageWidgets();
    ```

    **Edit D — DashboardEngine.m line ~1986-2005 (DOC header for `computeEventMarkers`):**

    Change the opening line:
    ```matlab
    %COMPUTEEVENTMARKERS Aggregate event markers across active-page widgets
    %   and push them onto the TimeRangeSelector's marker overlay.
    ```
    to:
    ```matlab
    %COMPUTEEVENTMARKERS Aggregate event markers across ALL widgets on EVERY
    %   page and push them onto the TimeRangeSelector's marker overlay.
    %   Multi-page dashboards therefore show the full cross-tab marker set
    %   (260508-kau / KAU-01); single-page dashboards are unaffected.
    ```
    (Keep the rest of the DOC — "Mirrors computePreviewEnvelope's guard...", the modern-vs-legacy preference, and the "tiebreaker on duplicate event Times" explanation — verbatim.)

    Do NOT remove or alter the recompute call at `switchPage` — recomputing on switch is now harmless (output is page-agnostic) and keeps the contract uniform across hook sites. Do NOT change any other code; the bucketing/normalization/dedup math is unaffected because it operates on whatever widget set is passed in.

    **Edit E — tests/test_dashboard_engine_event_markers.m, function `case_switch_page` (L57-80):**

    Update assertions to reflect the new all-pages contract. Replace the function body with:
    ```matlab
    function case_switch_page()
        e1 = struct('startTime', {5, 15}, 'endTime', {6, 16}, ...
                    'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
        e2 = struct('startTime', {100, 200, 300}, ...
                    'endTime',   {110, 210, 310}, ...
                    'label',     {'X','Y','Z'}, ...
                    'color',     {[1 0 0],[0 1 0],[0 0 1]});
        d = DashboardEngine('EvtMarkSwitch');
        d.addPage('P1');
        d.addWidget(EventTimelineWidget('Title', 'T1', 'Events', e1));
        d.addPage('P2');
        d.switchPage(2);
        d.addWidget(EventTimelineWidget('Title', 'T2', 'Events', e2));
        d.switchPage(1);
        d.render();
        cleanup = onCleanup(@() closeDashboard(d));
        % 260508-kau / KAU-01: slider preview now aggregates events from
        % ALL pages regardless of which tab is active. The expected marker
        % set is therefore the sorted union of P1 and P2 events.
        expected = sort([5 15 100 200 300]);
        assert(isequal(markerXData(d.TimeRangeSelector_), expected), ...
            sprintf('initial render: expected %s, got %s', mat2str(expected), ...
                    mat2str(markerXData(d.TimeRangeSelector_))));
        d.switchPage(2);
        assert(isequal(markerXData(d.TimeRangeSelector_), expected), ...
            'switchPage must keep all-pages markers visible (KAU-01).');
        d.switchPage(1);
        assert(isequal(markerXData(d.TimeRangeSelector_), expected), ...
            'reverse switchPage must keep all-pages markers visible (KAU-01).');
    end
    ```
    Use `cleanup` even though it is unused — that's the existing convention in this file (cleanup is held by onCleanup so removing the binding would defeat the teardown).

    **Edit F — tests/suite/TestDashboardEngineEventMarkers.m, method `testEventMarkersUpdateOnSwitchPage` (L27-51):**

    Update the same way:
    ```matlab
    function testEventMarkersUpdateOnSwitchPage(testCase)
        e1 = struct('startTime', {5, 15}, 'endTime', {6, 16}, ...
                    'label', {'A','B'}, 'color', {[1 0 0],[0 1 0]});
        e2 = struct('startTime', {100, 200, 300}, ...
                    'endTime',   {110, 210, 310}, ...
                    'label',     {'X','Y','Z'}, ...
                    'color',     {[1 0 0],[0 1 0],[0 0 1]});
        d = DashboardEngine('EvtMarkSwitch');
        d.addPage('P1');
        d.addWidget(EventTimelineWidget('Title', 'T1', 'Events', e1));
        d.addPage('P2');
        d.switchPage(2);
        d.addWidget(EventTimelineWidget('Title', 'T2', 'Events', e2));
        d.switchPage(1);
        d.render();
        testCase.addTeardown(@() close(d.hFigure));
        % 260508-kau / KAU-01: slider preview aggregates across ALL pages,
        % so markers are the sorted union of every page's events
        % regardless of which tab is currently active.
        expected = sort([5 15 100 200 300]);
        testCase.verifyEqual(markerXData(d.TimeRangeSelector_), expected, ...
            'Initial render must show union of all pages'' markers.');
        d.switchPage(2);
        testCase.verifyEqual(markerXData(d.TimeRangeSelector_), expected, ...
            'switchPage must keep all-pages markers visible (KAU-01).');
        d.switchPage(1);
        testCase.verifyEqual(markerXData(d.TimeRangeSelector_), expected, ...
            'reverse switchPage must keep all-pages markers visible (KAU-01).');
    end
    ```

    Important constraints:
    - Pure MATLAB / Octave-compatible — no toolbox calls. The `markerXData` helper at the bottom of each test file already works on both runtimes.
    - Do not touch any other test method or helper.
    - Do not modify the bucketing/dedup math, the cache, or any other engine method.
    - Honor MISS_HIT line-length limit (160 chars) in the new comment blocks.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/happy-ramanujan-7d436a && matlab -batch "addpath(pwd); install(); test_dashboard_engine_event_markers; test_dashboard_preview_envelope; test_dashboard_preview_overlay; disp('OK')"</automated>
  </verify>
  <done>
    - DashboardEngine.m line ~1915 reads `ws = obj.allPageWidgets();` (was `activePageWidgets`).
    - DashboardEngine.m line ~2020 reads `ws = obj.allPageWidgets();` (was `activePageWidgets`).
    - DOC headers for `computePreviewEnvelope` (~L1880) and `computeEventMarkers` (~L1986) reference "ALL widgets on every page" instead of "active-page widgets".
    - `case_switch_page` in tests/test_dashboard_engine_event_markers.m asserts `expected = sort([5 15 100 200 300])` for both initial render and after each switchPage call.
    - `testEventMarkersUpdateOnSwitchPage` in tests/suite/TestDashboardEngineEventMarkers.m mirrors the same expected union and KAU-01 messages.
    - All three existing tests pass: test_dashboard_engine_event_markers, test_dashboard_preview_envelope, test_dashboard_preview_overlay.
  </done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Add multi-page preview-aggregation regression test</name>
  <files>tests/test_dashboard_preview_overlay.m</files>
  <behavior>
    - Build a 2-page dashboard. P1 has one FastSenseWidget on the LOW range (sin(x*0.1) over x in [0, 10]).
      P2 has one FastSenseWidget on the HIGH range (cos(x*0.1) over x in [200, 210]).
    - After `d.render()` (active page = P1), `d.TimeRangeSelector_.hPreviewLines` MUST be non-empty.
    - At least ONE preview line MUST have its XData entirely (or majority) inside [200, 210]
      — proving P2's widget contributed despite being on the inactive page.
    - At least ONE preview line MUST have its XData inside [0, 10] — proving P1's widget contributed.
    - After `d.switchPage(2)`, the same union assertions still hold (preview is page-agnostic).
    - On Octave runtimes where TimeRangeSelector cannot be constructed, the case skips cleanly using
      the existing `probeTimeRangeSelectorAvailable_()` gate at the top of the file.
  </behavior>
  <action>
    Adds a regression test that locks in the KAU-01 contract: multi-page dashboards aggregate slider preview lines across every page.

    1. Open tests/test_dashboard_preview_overlay.m.

    2. In the dispatch list inside the main `test_dashboard_preview_overlay` function (currently L33-41), append one new line BEFORE the `try close(...)` cleanup. The block currently ends at:
    ```matlab
        nPassed = nPassed + runCase_(@() case_preview_cache_short_circuit(),          'preview_cache_short_circuit');
    ```
    Add immediately after it:
    ```matlab
        nPassed = nPassed + runCase_(@() case_multipage_preview_aggregates_all_pages(), 'multipage_preview_aggregates_all_pages');
    ```

    3. After the existing `case_preview_cache_short_circuit` function (ends near L350) and BEFORE the `% --- ` separator + `probeTimeRangeSelectorAvailable_` helper, append the new case function:

    ```matlab
    function case_multipage_preview_aggregates_all_pages()
        %CASE_MULTIPAGE_PREVIEW_AGGREGATES_ALL_PAGES KAU-01 regression.
        %   Build a 2-page dashboard with disjoint X ranges per page; assert
        %   the slider preview folds in BOTH pages' widgets regardless of
        %   which tab is currently active.
        x1 = linspace(0,   10,  500);
        y1 = sin(x1 * 0.1);
        x2 = linspace(200, 210, 500);
        y2 = cos(x2 * 0.1);

        d = DashboardEngine('preview-multipage');
        d.addPage('P1');
        d.addWidget('fastsense', 'Title', 'wP1', 'XData', x1, 'YData', y1);
        d.addPage('P2');
        d.switchPage(2);
        d.addWidget('fastsense', 'Title', 'wP2', 'XData', x2, 'YData', y2);
        d.switchPage(1);
        d.render();
        cleanup = onCleanup(@() closeDashboard_(d));  %#ok<NASGU>
        drawnow;

        sel = d.TimeRangeSelector_;
        assert(~isempty(sel.hPreviewLines), ...
            'KAU-01: hPreviewLines must be non-empty on multi-page dashboard');

        % Each preview line carries the X centers of one widget's buckets.
        % Classify each line by which range its X data falls into.
        nLow  = 0;
        nHigh = 0;
        for k = 1:numel(sel.hPreviewLines)
            xd = get(sel.hPreviewLines(k), 'XData');
            xd = xd(:)';
            if isempty(xd), continue; end
            if all(xd >= -1) && all(xd <= 12)
                nLow = nLow + 1;
            elseif all(xd >= 199) && all(xd <= 211)
                nHigh = nHigh + 1;
            end
        end
        assert(nLow  >= 1, ...
            sprintf('KAU-01: expected >=1 preview line in [0,10] (P1 widget), got %d', nLow));
        assert(nHigh >= 1, ...
            sprintf('KAU-01: expected >=1 preview line in [200,210] (P2 widget, inactive page), got %d', nHigh));

        % Switch to P2 and re-assert: preview is page-agnostic.
        d.switchPage(2);
        drawnow;
        sel = d.TimeRangeSelector_;
        nLow2  = 0;
        nHigh2 = 0;
        for k = 1:numel(sel.hPreviewLines)
            xd = get(sel.hPreviewLines(k), 'XData');
            xd = xd(:)';
            if isempty(xd), continue; end
            if all(xd >= -1) && all(xd <= 12)
                nLow2 = nLow2 + 1;
            elseif all(xd >= 199) && all(xd <= 211)
                nHigh2 = nHigh2 + 1;
            end
        end
        assert(nLow2  >= 1, 'KAU-01: after switchPage(2), P1 widget line must still appear');
        assert(nHigh2 >= 1, 'KAU-01: after switchPage(2), P2 widget line must still appear');
    end
    ```

    Constraints:
    - Use `'fastsense'` widget type via `addWidget(...)` to match style of the existing cases in this file (case_two_widgets_have_preview_lines etc.).
    - Use existing `closeDashboard_` helper at the bottom of the file for cleanup; do not introduce new helpers.
    - Octave-safe: assertions use `assert(...)` with sprintf messages, no `verifyEqual`.
    - The probe at the top of `test_dashboard_preview_overlay` already returns early on stock Octave with no TimeRangeSelector, so this case will be skipped together with the others.
    - Honor MISS_HIT line-length limit (160 chars).
    - Do not modify any existing case function. The new case is purely additive aside from the one extra dispatch line.
  </action>
  <verify>
    <automated>cd /Users/hannessuhr/PARA/10_Projects/FastPlot/.claude/worktrees/happy-ramanujan-7d436a && matlab -batch "addpath(pwd); install(); test_dashboard_preview_overlay; disp('OK')"</automated>
  </verify>
  <done>
    - tests/test_dashboard_preview_overlay.m contains a new function `case_multipage_preview_aggregates_all_pages` registered in the runCase dispatch list.
    - The new case asserts at least one preview line in [0,10] AND at least one in [200,210], on initial render AND after switchPage(2).
    - All cases in test_dashboard_preview_overlay pass (the file announces the new total count via `All N tests passed.` — N increased by 1).
  </done>
</task>

</tasks>

<verification>
After both tasks complete:

1. **Static check (DashboardEngine.m):**
   ```bash
   grep -n "activePageWidgets\(\)\|allPageWidgets\(\)" libs/Dashboard/DashboardEngine.m
   ```
   Expected: the two iteration sites in `computePreviewEnvelopeReturning_` and `computeEventMarkers` both call `allPageWidgets()`. The `activePageWidgets()` calls remaining elsewhere (rendering, layout, etc.) are unrelated and must NOT have been changed.

2. **Run all preview/marker tests:**
   ```bash
   matlab -batch "addpath(pwd); install(); test_dashboard_preview_envelope; test_dashboard_preview_overlay; test_dashboard_engine_event_markers; disp('ALL OK')"
   ```
   All three must report `All N tests passed.` and the final `ALL OK` line must print.

3. **Run the class-based suite for the marker tests** (MATLAB only):
   ```bash
   matlab -batch "addpath(pwd); install(); addpath('tests/suite'); results = runtests('TestDashboardEngineEventMarkers'); disp(results)"
   ```
   All test methods must pass — particularly `testEventMarkersUpdateOnSwitchPage` (now reflecting the all-pages contract).

4. **Manual repro (optional, not required for sign-off):**
   Run `demo/industrial_plant/run_demo.m`, switch tabs, confirm the bottom slider preview lines + event markers show every tab's contribution at all times.
</verification>

<success_criteria>
- `git diff libs/Dashboard/DashboardEngine.m` touches ONLY the two iteration lines and their associated DOC headers + new comment lines. No bucketing/normalization/dedup math changes.
- All three test files (`test_dashboard_preview_envelope.m`, `test_dashboard_preview_overlay.m`, `test_dashboard_engine_event_markers.m`) plus the class suite (`TestDashboardEngineEventMarkers.m`) pass on the dev runtime.
- Single-page dashboards exhibit zero behavior change (validated by the unchanged single-page test cases continuing to pass).
- Multi-page regression case (`case_multipage_preview_aggregates_all_pages`) passes and proves the new contract.
- The two updated switchPage cases assert the union of all pages' events as the expected marker set.
</success_criteria>

<output>
After completion, create `.planning/quick/260508-kau-slider-preview-aggregates-all-pages-widg/260508-kau-SUMMARY.md` summarizing:
- The two-line core change in DashboardEngine.m
- DOC header updates
- New regression test (case_multipage_preview_aggregates_all_pages)
- Updates to the two switchPage tests (function + suite)
- Test results (all three test scripts + class suite passing)
</output>
