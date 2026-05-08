---
phase: quick-260508-jyh
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardEngine.m
  - libs/Dashboard/DashboardToolbar.m
  - tests/test_dashboard_stale_banner.m
autonomous: true
requirements: [JYH-01]
must_haves:
  truths:
    - "A dedicated reserved strip exists at the very top of the dashboard figure for the stale-data banner."
    - "The banner NEVER overlaps the toolbar, page tabs, or any widget panel — it is no longer an overlay."
    - "When the banner has no message to show (Visible='off'), the reserved strip remains in place; the toolbar/page-bar/content-area positions DO NOT shift between hidden and visible banner states."
    - "Toolbar sits directly below the reserved banner strip; page-bar (when present) sits directly below the toolbar; widget content area starts below all of them."
    - "Existing public API on DashboardEngine and DashboardToolbar is unchanged (BannerHeight is additive)."
    - "All existing tests in tests/test_dashboard_stale_banner.m still pass; the multi-page regression test from quick-260508-jf1 is updated to assert the stronger no-overlap-with-anything invariant."
  artifacts:
    - path: "libs/Dashboard/DashboardEngine.m"
      provides: "BannerHeight public property; banner positioned in reserved top strip; toolbar/pagebar/content-area offsets account for BannerHeight; simplified repositionStaleBanner_."
      contains: "BannerHeight"
    - path: "libs/Dashboard/DashboardToolbar.m"
      provides: "Toolbar panel positioned at [0, 1 - BannerHeight - Height, 1, Height] reading BannerHeight from the engine handle."
      contains: "Engine.BannerHeight"
    - path: "tests/test_dashboard_stale_banner.m"
      provides: "Updated testBannerBelowPageBarMultiPage asserting banner sits ABOVE toolbar and content area never extends into reserved strip; new testReservedStripStableWhenHidden asserting layout doesn't shift between hidden/visible banner."
      contains: "testReservedStripStableWhenHidden"
  key_links:
    - from: "DashboardEngine.render"
      to: "DashboardToolbar constructor"
      via: "Engine handle passed as 1st arg; toolbar reads obj.Engine.BannerHeight when computing its Y."
      pattern: "Engine\\.BannerHeight"
    - from: "DashboardEngine.render content-area calc (~L334-335)"
      to: "DashboardEngine.applyVisibilityAndRelayout (~L1019-1021)"
      via: "Both compute Layout.ContentArea height as 1 - BannerHeight - effToolbarH - effPageBarH - effTimeH (single shared formula)."
      pattern: "1 - obj\\.BannerHeight - effToolbarH - effPageBarH - effTimeH"
    - from: "DashboardEngine.createStaleBanner"
      to: "DashboardEngine.repositionStaleBanner_"
      via: "Both write Position [0, 1 - obj.BannerHeight, 1, obj.BannerHeight] — banner is always in the reserved top strip."
      pattern: "1 - obj\\.BannerHeight, 1, obj\\.BannerHeight"
---

<objective>
Reserve a permanent vertical strip at the very TOP of the dashboard figure for the stale-data banner so it never overlaps toolbar, page tabs, or widgets. All other chrome shifts down by `BannerHeight`. The strip is reserved even when the banner is hidden, keeping geometry stable across visibility transitions.

Purpose: User explicitly requested a dedicated space at the top — "just put the banner atop of all the other elements ( widgets / tabs.. ) make a dedicated space for it". The previous fix (260508-jf1) moved the banner below the tabs but left it as an overlay covering the topmost widget. This plan eliminates the overlay model entirely.

Output: Updated DashboardEngine.m, DashboardToolbar.m, and tests/test_dashboard_stale_banner.m.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@libs/Dashboard/DashboardEngine.m
@libs/Dashboard/DashboardToolbar.m
@libs/Dashboard/DashboardLayout.m
@.planning/quick/260508-jf1-fix-orange-no-data-banner-overlapping-da/260508-jf1-SUMMARY.md
@tests/test_dashboard_stale_banner.m

<interfaces>
<!-- Key contracts the executor needs. The plan applies these directly — no codebase exploration needed. -->

DashboardEngine (libs/Dashboard/DashboardEngine.m):
- Existing public properties used by chrome geometry: PageBarHeight, TimePanelHeight, Toolbar (DashboardToolbar instance), Pages (cell array), Layout (DashboardLayout), hFigure, hStaleBanner, hStaleBannerText, hStaleBannerClose, hPageBar, hTimePanel
- New public property to add: `BannerHeight = 0.035` (matches the literal currently in createStaleBanner — single source of truth)
- Methods touched: render (~L298-340), applyVisibilityAndRelayout (~L1014-1030), applyChromeVisibility (~L988-1012, contract preserved), createStaleBanner (~L1202-1250), repositionStaleBanner_ (~L1252-1274), renderPageBar (~L1697 — verify Y formula), onResize (~L1559-1565, no change needed)

DashboardToolbar (libs/Dashboard/DashboardToolbar.m):
- Public property: Height = 0.04
- Constructor signature (unchanged): `DashboardToolbar(engine, hFigure, theme)` — toolbar already holds `obj.Engine = engine`
- Constructor pins panel at [0, 1 - obj.Height, 1, obj.Height] (L36-38) — must change to [0, 1 - engine.BannerHeight - obj.Height, 1, obj.Height]
- getContentArea() at L296-299: returns `[0, timePanelH, 1, 1 - obj.Height - timePanelH]`. Must subtract `obj.Engine.BannerHeight` from height. NOTE: grep shows getContentArea is not called from elsewhere in the live render path (DashboardEngine computes ContentArea inline), but update it for consistency.

DashboardLayout (libs/Dashboard/DashboardLayout.m):
- Consumes ContentArea = [x, y, w, h] in normalized figure coords. No changes here — the engine writes to obj.Layout.ContentArea; layout uses what it's given.

Current banner geometry (to be replaced):
```matlab
% In createStaleBanner (~L1222):
bannerY = 1 - toolbarH - effPageBarH - bannerH;  % overlay below toolbar+tabs

% In repositionStaleBanner_ (~L1272-1273):
set(obj.hStaleBanner, 'Position', ...
    [0, 1 - toolbarH - effPageBarH - bannerH, 1, bannerH]);
```

New banner geometry (target):
```matlab
% Banner ALWAYS at top, regardless of chrome state:
[0, 1 - obj.BannerHeight, 1, obj.BannerHeight]
```

Test file pattern (Octave function-based, try/catch nPassed/nFailed):
- See tests/test_dashboard_stale_banner.m for the established style (7 scenarios currently)
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Reserve top banner strip; shift all chrome down by BannerHeight</name>
  <files>
    libs/Dashboard/DashboardEngine.m,
    libs/Dashboard/DashboardToolbar.m,
    tests/test_dashboard_stale_banner.m
  </files>
  <behavior>
    Test invariants (added/updated in tests/test_dashboard_stale_banner.m):

    UPDATED `testBannerBelowPageBarMultiPage` → rename to `testBannerInReservedStripAboveAllChrome`:
    - Build a 2-page dashboard with one widget; render; hide figure.
    - Snapshot `caBefore = d.Layout.ContentArea` BEFORE showStaleBanner.
    - Call `d.showStaleBanner({'X'})`.
    - Read `bannerPos = get(d.hStaleBanner,'Position')`, `toolbarPos = get(d.Toolbar.hPanel,'Position')`, `pageBarPos = get(d.hPageBar,'Position')`.
    - Assert banner Y (`bannerPos(2)`) ≈ `1 - d.BannerHeight` (within 1e-6).
    - Assert banner top (`bannerPos(2) + bannerPos(4)`) ≈ 1.0 (within 1e-6).
    - Assert banner bottom (`bannerPos(2)`) ≥ toolbar top (`toolbarPos(2) + toolbarPos(4)`) within -1e-6 tolerance — i.e. banner sits ABOVE toolbar.
    - Assert toolbar top ≈ `1 - d.BannerHeight` and toolbar bottom = `1 - d.BannerHeight - d.Toolbar.Height`.
    - Assert page-bar top ≤ toolbar bottom (page-bar sits below toolbar).
    - Assert `d.Layout.ContentArea(2) + d.Layout.ContentArea(4) <= 1 - d.BannerHeight + 1e-6` — content area never extends into reserved strip.
    - Assert `isequal(d.Layout.ContentArea, caBefore)` — banner visibility doesn't change content area (overlay-free).

    NEW `testReservedStripStableWhenHidden`:
    - Build a single-page dashboard with one widget; render; hide figure.
    - Snapshot toolbar/pagebar/content-area positions while banner is hidden.
    - Call `d.showStaleBanner({'A'})` then `d.hideStaleBanner()`.
    - Assert toolbar position is byte-identical (`isequal`) to the snapshot — geometry must not shift between hidden/visible banner.
    - Assert `d.Layout.ContentArea` is byte-identical to the snapshot.
    - Assert banner panel Position is `[0, 1 - d.BannerHeight, 1, d.BannerHeight]` — strip is reserved even when Visible='off'.

    NEW `testBannerHeightProperty`:
    - Assert `d.BannerHeight` is a public property with default value `0.035`.
    - Assert `d.BannerHeight > 0` and `d.BannerHeight < 0.1`.

    All 6 existing scenarios (testBannerCreatedHidden, testShowListsStaleTitles, testShowCollapsesLongList, testDetectStaleWithFrozenSensor, testCloseButtonDismisses, testStopLiveHidesBannerAndClearsDismissal) MUST continue to pass unchanged.
  </behavior>
  <action>
    Goal: Eliminate the banner-as-overlay model. Reserve `BannerHeight` (default 0.035) at the figure top permanently; banner lives there in its own strip; toolbar/page-bar/content-area all shift down by `BannerHeight`.

    --- Step A: DashboardEngine.m — add BannerHeight public property ---

    In the public `properties (Access = public)` block (find existing block declaring `PageBarHeight`, `TimePanelHeight`, `Theme`, etc.), add:

    ```matlab
    BannerHeight = 0.035   % Reserved vertical strip at figure top for stale-data banner (normalized units)
    ```

    Rationale: matches the literal `bannerH = 0.035` currently in createStaleBanner. Public property = single source of truth, themeable later.

    --- Step B: DashboardEngine.m — render() chrome positioning (~L298-340) ---

    Update content-area calculation to account for BannerHeight. After the existing `[effToolbarH, effPageBarH, effTimeH] = obj.applyChromeVisibility(...)` line:

    ```matlab
    % Reserve BannerHeight at the TOP for the stale-data banner strip.
    % The banner is no longer an overlay — its space is permanently
    % reserved, so toolbar/pagebar/content-area all shift down.
    obj.Layout.ContentArea = [0, effTimeH, ...
        1, 1 - obj.BannerHeight - effToolbarH - effPageBarH - effTimeH];
    ```

    Update the hidden-PageBar placeholder branch (~L317-322) to start below the toolbar AND banner:

    ```matlab
    obj.hPageBar = uipanel('Parent', obj.hFigure, ...
        'Units', 'normalized', ...
        'Position', [0, 1 - obj.BannerHeight - toolbarH - obj.PageBarHeight, 1, obj.PageBarHeight], ...
        ...);
    ```

    --- Step C: DashboardEngine.m — applyVisibilityAndRelayout (~L1014-1030) ---

    Update Layout.ContentArea formula to subtract BannerHeight:

    ```matlab
    obj.Layout.ContentArea = [0, effTimeH, ...
        1, 1 - obj.BannerHeight - effToolbarH - effPageBarH - effTimeH];
    ```

    Keep the `obj.repositionStaleBanner_();` call — body is simplified in Step E.

    --- Step D: DashboardEngine.m — createStaleBanner (~L1202-1250) ---

    Replace the body's geometry block:

    OLD:
    ```matlab
    bannerH = 0.035;
    ...
    if numel(obj.Pages) > 1
        effPageBarH = obj.PageBarHeight;
    else
        effPageBarH = 0;
    end
    bannerY = 1 - toolbarH - effPageBarH - bannerH;
    ```

    NEW:
    ```matlab
    bannerH = obj.BannerHeight;
    bannerY = 1 - bannerH;  % Reserved strip at the very top of the figure
    ```

    The `toolbarH` argument to `createStaleBanner(theme, toolbarH)` is now unused inside this method; KEEP the parameter for backward compat with existing callers (no signature change). Add a comment: `% toolbarH retained for signature compat; banner now lives in reserved top strip independent of toolbar height.`

    Update header comment from "below the toolbar AND below the page-tab strip" to "Permanent reserved strip at the very TOP of the figure. Toolbar, page tabs, and content area all sit BELOW this strip — banner is never an overlay."

    Keep the `uipanel(...'Visible','off',...)` and `warnColor` BackgroundColor as-is. When `Visible='off'`, MATLAB and Octave both hide the panel cleanly — the figure background shows through the reserved space.

    --- Step E: DashboardEngine.m — repositionStaleBanner_ (~L1252-1274) ---

    Simplify body — banner Y no longer depends on chrome heights:

    ```matlab
    function repositionStaleBanner_(obj)
    %REPOSITIONSTALEBANNER_ Park banner in the reserved top strip.
    %   Banner now lives in a permanent strip at the figure top;
    %   no chrome-height dependence. Safe to call before render or
    %   after teardown — no-ops when handle is empty/invalid.
        if isempty(obj.hStaleBanner) || ~ishandle(obj.hStaleBanner)
            return;
        end
        set(obj.hStaleBanner, 'Position', ...
            [0, 1 - obj.BannerHeight, 1, obj.BannerHeight]);
    end
    ```

    Remove the `toolbarH`/`effPageBarH`/`pos = get(...,'Position')` reads — no longer needed.

    --- Step F: DashboardEngine.m — renderPageBar (~L1697) ---

    Find the `set(obj.hPageBar, 'Position', ...)` or `'Position', [...]` literal in renderPageBar. Update Y to `1 - obj.BannerHeight - toolbarH - obj.PageBarHeight`. Read renderPageBar carefully — if it computes toolbarH via `obj.Toolbar.Height`, the formula is `[0, 1 - obj.BannerHeight - obj.Toolbar.Height - obj.PageBarHeight, 1, obj.PageBarHeight]`.

    --- Step G: DashboardToolbar.m — toolbar panel Y (L36-38) ---

    Replace:
    ```matlab
    'Position', [0, 1 - obj.Height, 1, obj.Height], ...
    ```

    With:
    ```matlab
    'Position', [0, 1 - engine.BannerHeight - obj.Height, 1, obj.Height], ...
    ```

    `engine` is the constructor's first arg; safe to read `engine.BannerHeight` directly.

    --- Step H: DashboardToolbar.m — getContentArea (L296-299) ---

    Update to subtract BannerHeight:
    ```matlab
    function contentArea = getContentArea(obj)
        timePanelH = obj.Engine.TimePanelHeight;
        contentArea = [0, timePanelH, 1, 1 - obj.Engine.BannerHeight - obj.Height - timePanelH];
    end
    ```

    --- Step I: tests/test_dashboard_stale_banner.m ---

    1. RENAME `testBannerBelowPageBarMultiPage` → `testBannerInReservedStripAboveAllChrome` and replace its body with the assertions listed in <behavior> above. Use the same try/catch + nPassed/nFailed pattern as siblings. Reference `d.Toolbar.hPanel` for the toolbar position read.

    2. APPEND new scenario `testReservedStripStableWhenHidden` (single-page dashboard; snapshot positions; show then hide; assert byte-identical positions and reserved-strip math). Use `isequal()` for byte-identity comparisons.

    3. APPEND new scenario `testBannerHeightProperty` (assert `d.BannerHeight == 0.035` default, assert it's a public property, assert reasonable bounds).

    4. Update final summary fprintf — count remains accurate (was 7, now 9).

    --- Step J: Verify (run tests) ---

    Run `tests/test_dashboard_stale_banner.m` via Octave (Octave's the project default and CI environment). MUST output `9 passed, 0 failed.`. If not, fix and re-run. Do NOT modify the existing 6 scenarios' assertions — they should pass unchanged because banner Visible state, text content, dismissal flag, and stopLive behaviors are all geometry-independent.

    --- Per CLAUDE.md MATLAB conventions ---

    - PascalCase property name `BannerHeight` (matches `PageBarHeight`, `TimePanelHeight`).
    - Header comments updated as noted.
    - Octave-compatible — no `matlab.unittest` usage; function-based tests with try/catch.
    - Line length ≤ 160 chars.
    - No new error IDs introduced.

    --- Avoid these traps ---

    - DO NOT change the BackgroundColor swap logic. Keeping the panel `warnColor` always + `Visible='off'` to hide is the established pattern (testBannerCreatedHidden depends on it). The reserved strip will show figure background through the invisible panel — that's correct.
    - DO NOT remove the `uistack(obj.hStaleBanner, 'top')` call in showStaleBanner if it exists — it's harmless and provides defense-in-depth even though we're no longer overlaying. (Verify by reading showStaleBanner ~L1276+ if needed.)
    - DO NOT change DashboardToolbar constructor signature. Read BannerHeight from `engine` arg already passed.
    - DO NOT modify applyChromeVisibility — its contract (returning effective heights) is unchanged; only the formulas that CONSUME its output change.
    - DO NOT shrink Layout.ContentArea conditionally based on banner Visible state. The whole point of this fix is geometric stability: reserved space is reserved whether banner is showing or not.
  </action>
  <verify>
    <automated>octave --no-gui --eval "addpath(pwd); install(); test_dashboard_stale_banner();"</automated>
  </verify>
  <done>
    - `d.BannerHeight` exists as public property with default 0.035.
    - Banner panel Position is `[0, 1 - 0.035, 1, 0.035]` after render, regardless of single-page/multi-page or banner Visible state.
    - Toolbar panel Position is `[0, 1 - 0.035 - 0.04, 1, 0.04]` (Y shifted down by BannerHeight).
    - Page bar (when present) sits below the toolbar.
    - `d.Layout.ContentArea` height is `1 - BannerHeight - effToolbarH - effPageBarH - effTimeH`; never extends into reserved strip.
    - Toggling banner visibility does NOT change toolbar/pagebar/content-area positions (geometric stability).
    - `octave --no-gui --eval "addpath(pwd); install(); test_dashboard_stale_banner();"` outputs `9 passed, 0 failed.`
    - All 6 pre-existing scenarios still pass; 1 renamed scenario passes with stronger assertions; 2 new scenarios pass.
  </done>
</task>

</tasks>

<verification>
1. Run `octave --no-gui --eval "addpath(pwd); install(); test_dashboard_stale_banner();"` — expect `9 passed, 0 failed.`
2. Visual sanity (manual, optional): launch any example dashboard, trigger stale state, observe banner sits at very top and never overlaps toolbar/tabs/widgets. Toggle banner — toolbar/widgets must NOT shift.
3. Static-check `libs/Dashboard/DashboardEngine.m` and `libs/Dashboard/DashboardToolbar.m` parse cleanly in Octave (no syntax errors).
</verification>

<success_criteria>
- Banner has its own dedicated strip at the very top of the dashboard figure.
- Banner never overlaps toolbar, page tabs, or any widget panel.
- All other chrome (toolbar, page bar, widgets, time panel) shifts down by `BannerHeight` to make room.
- Reserved strip persists when banner is hidden — no layout shift between hidden and visible states.
- Public API unchanged (BannerHeight is additive); existing dashboard scripts continue to work.
- All 9 scenarios in tests/test_dashboard_stale_banner.m pass.
</success_criteria>

<output>
After completion, create `.planning/quick/260508-jyh-stale-banner-reserved-strip-atop-dashboa/260508-jyh-SUMMARY.md` per template.
</output>
