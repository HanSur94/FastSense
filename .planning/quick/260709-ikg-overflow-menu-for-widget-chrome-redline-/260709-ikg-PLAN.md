---
phase: 260709-ikg
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/DashboardLayout.m
autonomous: true
requirements:
  - IKG-01
quick: true

must_haves:
  truths:
    - "On a rendered dashboard, each FastSense plot shows only two chrome buttons (Info 'i' and Detach '^') plus one new overflow button (…); the X/V/A/L/+ strip is gone from the visible chrome."
    - "Clicking the … button posts a context menu whose items drive the SAME actions the folded X/V/A/L/+ buttons drove (crosshair link, auto-fit Y visible, auto-fit Y all, plant-log show/hide, create event)."
    - "Menu item check/label state reflects live widget state (CrosshairLinked, YLimitMode, ShowPlantLog) because the menu is rebuilt fresh on every click."
    - "All 7 must-pass suites stay green: the folded buttons remain alive (tags, positions, callbacks, UserData active-state) — only their Visible flag flips to 'off'."
    - "A menu-post failure never crashes the refresh loop (try/catch → namespaced warning DashboardLayout:overflowMenuFailed)."
  artifacts:
    - "libs/Dashboard/DashboardLayout.m — addOverflowMenu_ (private) creates the OverflowMenuButton"
    - "libs/Dashboard/DashboardLayout.m — showOverflowMenu_ (private) builds+posts the fresh uicontextmenu"
    - "libs/Dashboard/DashboardLayout.m — reflowChrome_ (static) anchors OverflowMenuButton"
  key_links:
    - "showOverflowMenu_ uimenu callbacks must route to the existing action methods (onCrosshairLinkTogglePressed_, onYLimitButtonClicked_, onPlantLogTogglePressed_, invokeCreateEventCallback_) so no test/behaviour regresses."
    - "The 5 folded uicontrols must keep Visible='off' through every callback-driven rebuild (addCrosshairLinkToggle / addPlantLogToggle / addYLimitButton_) — the rebuild reuses the same creation code, so the shim is applied once at the creation site."
    - "addOverflowMenu_ must run AFTER all 5 folded buttons are added and BEFORE the reflowChrome_ that anchors it (both in realizeWidget and in each rebuild method)."
---

<objective>
Declutter the per-widget chrome strip on every dashboard plot (redline (e) of docs/design/fastsense-light-1to1-design-spec.md). Fold the five secondary chrome buttons — CrosshairLink ('X'), YLimit-Visible ('V'), YLimit-All ('A'), PlantLog ('L'), CreateEvent ('+') — behind a single overflow "…" button that posts a context menu. Keep Info ('i') and Detach ('^') visible. (IKG-01)

Purpose: The `X V A L +` cluster butts against the Info button (a known 0-px-gap nit) and reads as noise on every plot; the settled design (user chose "Overflow ⋯ menu", compatibility-shim pattern, prototyped live this session) hides the five buttons WITHOUT deleting them so all 130 existing assertions across 7 files stay green.

Output: Modifications to a single file — `libs/Dashboard/DashboardLayout.m`. No test edits, no other files.
</objective>

<execution_context>
@$HOME/.claude/gsd-core/workflows/execute-plan.md
@$HOME/.claude/gsd-core/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md

# The ONLY file to change:
@libs/Dashboard/DashboardLayout.m

# Design authority (redline e, §1 cheap-render budget, §2 tokens):
@docs/design/fastsense-light-1to1-design-spec.md
</context>

<constraints>
- ONLY `libs/Dashboard/DashboardLayout.m` may change. Do NOT edit any test file or any other source file.
- Cheap-render only (spec §1). Theme tokens only — `theme.ToolbarBackground` (bg) and `theme.ToolbarFontColor` (fg). No hardcoded colors.
- Keep the five folded uicontrols fully ALIVE: Tag, Position, FontSize, FontWeight, ForegroundColor/BackgroundColor, Callback, TooltipString, UserData active-state sync all unchanged. The ONLY change to them is adding `'Visible', 'off'`.
- Do NOT touch InfoIconButton or DetachButton in any way — they stay visible.
- Do NOT add any `delete()` of a folded button. Existing idempotent `delete(prior)` calls stay as-is.
- The executor has NO MATLAB tooling. Live MATLAB verification (render `example_dashboard_all_widgets` Theme='light', screenshot showing the folded buttons gone / … present + menu posts, and the 7 must-pass suites) is performed by the HUMAN ORCHESTRATOR, not the executor. Executor <verify> is grep/lint structural only.
- If any test is found to assert a folded button's `Visible` state (grep this session found NONE), flag it in the SUMMARY and do NOT edit the test.
</constraints>

<tasks>

<task type="auto">
  <name>Task 1: Shim — hide the five folded chrome buttons (Visible off), keep them alive</name>
  <files>libs/Dashboard/DashboardLayout.m</files>
  <action>
Add `'Visible', 'off'` to the `uicontrol(...)` creation of the FIVE folded buttons ONLY, at their four creation sites. Change NOTHING else about those uicontrols (keep Tag, Units, Position, FontSize, FontWeight, ForegroundColor, BackgroundColor, Enable, Callback, TooltipString exactly as-is). The four sites:

1. `addPlantLogToggle` — the `uicontrol('Parent', bar, 'Style', 'pushbutton', 'String', 'L', ...)` (Tag 'PlantLogToggleButton', ~line 712). Add the visibility property to that call.
2. `addCrosshairLinkToggle` — the `uicontrol('Parent', bar, 'Style', 'pushbutton', 'String', 'X', ...)` (Tag 'CrosshairLinkButton', ~line 811). Add it.
3. `addYLimitButton_` — the single shared helper `uicontrol('Parent', bar, 'Style', 'pushbutton', 'String', glyph, ...)` (Tag `tagName`, ~line 1087). This one call constructs BOTH the 'V' (YLimitVisibleBtn) and 'A' (YLimitAllBtn) buttons, so adding it here folds both. Add it.
4. `addCreateEventButton` — the `uicontrol('Parent', bar, 'Style', 'pushbutton', 'String', '+', ...)` (Tag 'CreateEventButton', ~line 1131). Add it.

Do NOT add the visibility property to `addInfoIcon` (Tag 'InfoIconButton', ~line 980) or `addDetachButton` (Tag 'DetachButton', ~line 1004) — those two stay visible.

Rationale to preserve: the folded buttons are re-created on every callback-driven rebuild via these SAME creation methods (addCrosshairLinkToggle self-rebuilds; onPlantLogTogglePressed_ re-calls addPlantLogToggle; the YLimit path re-calls addYLimitButton_). Because the shim lives at the shared creation site, every rebuild automatically re-hides them. Tests assert their Tag/Position/Callback/Enable/active-bg — none assert Visible (grep-confirmed this session), so hiding-but-alive keeps all 7 suites green.
  </action>
  <verify>
    <automated>cd libs/Dashboard && grep -c "'Visible', *'off'" DashboardLayout.m</automated>
    <notes>Expect the count to INCREASE by exactly 4 versus the pre-edit baseline (one per creation site: L, X, YLimit-helper, +). Confirm InfoIconButton and DetachButton blocks are untouched: `grep -n "'Tag', 'InfoIconButton'" DashboardLayout.m` and `grep -n "'Tag', 'DetachButton'" DashboardLayout.m` still resolve, and neither method (addInfoIcon ~968-992, addDetachButton ~994-1015) contains a Visible property. If MISS_HIT is installed: `mh_style libs/Dashboard/DashboardLayout.m` and `mh_lint libs/Dashboard/DashboardLayout.m` report clean.</notes>
  </verify>
  <done>The four folded creation sites (L, X, YLimit-helper covering V+A, +) each carry `'Visible', 'off'`; addInfoIcon and addDetachButton are byte-unchanged; no `delete()` of a folded button was added; MISS_HIT (if present) clean.</done>
</task>

<task type="auto">
  <name>Task 2: Add addOverflowMenu_ + showOverflowMenu_ and wire them in</name>
  <files>libs/Dashboard/DashboardLayout.m</files>
  <action>
Add two new PRIVATE instance methods in the `methods (Access = private)` block, next to the sibling chrome builders (after `invokeCreateEventCallback_`, before the block's closing `end` at ~line 1159), then wire them into `realizeWidget` and the three callback-driven rebuild methods.

(A) `addOverflowMenu_(obj, widget)`:
  - Resolve theme: `if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme), theme = DashboardTheme('light'); else theme = widget.ParentTheme; end` (same pattern as the neighbors).
  - `bar = obj.getOrCreateButtonBar_(widget);`
  - Idempotent cleanup: `findobj(bar, 'Tag', 'OverflowMenuButton', '-depth', 1)` and delete any prior (guarded `try delete(prior); catch, end`); likewise delete any prior `findobj(ancestor(bar,'figure'), 'Tag', 'OverflowContextMenu')` so stale context menus do not accumulate.
  - GUARD: findobj the bar for the five folded tags (CrosshairLinkButton, YLimitVisibleBtn, YLimitAllBtn, PlantLogToggleButton, CreateEventButton). If NONE are present, `return` (non-fold widgets get no … button).
  - Create ONE `uicontrol('Parent', bar, 'Style', 'pushbutton', ...)`: String `char(8230)` (the '…' glyph — use char(8230), not a literal multibyte char, for Octave/MISS_HIT safety), Units 'pixels', provisional Position `[2 2 24 24]` (reflowChrome_ re-anchors), FontSize 11, FontWeight 'bold', ForegroundColor `theme.ToolbarFontColor`, BackgroundColor `theme.ToolbarBackground`, Tag 'OverflowMenuButton', TooltipString 'More chart controls', Callback `@(~,~) obj.showOverflowMenu_(widget, bar)`.
  - End with a best-effort self-anchor mirroring the siblings: `try DashboardLayout.reflowChrome_(widget.hCellPanel, 28, 2); catch, end`.

(B) `showOverflowMenu_(obj, widget, bar)`:
  - Wrap the entire body in try/catch; on error `warning('DashboardLayout:overflowMenuFailed', 'Overflow menu failed: %s', ME.message)` and return (never crash the refresh loop).
  - `fig = ancestor(bar, 'figure');` guard non-empty + ishandle.
  - Delete any prior `findobj(fig, 'Tag', 'OverflowContextMenu')`, then build a FRESH `cm = uicontextmenu('Parent', fig, 'Tag', 'OverflowContextMenu');` (fresh each click so Checked/label state is current).
  - Add one `uimenu` per PRESENT folded button (findobj the bar by tag; skip absent):
      * CrosshairLinkButton present → label 'Link crosshair across page' when `~widget.CrosshairLinked`, else 'Unlink crosshair (stop mirroring)'; set 'Checked' 'on' when `widget.CrosshairLinked` else 'off'; Callback `@(~,~) obj.onCrosshairLinkTogglePressed_(hLink, widget)` where hLink is the hidden CrosshairLinkButton handle.
      * YLimitVisibleBtn present → label 'Auto-fit Y to visible X range'; Checked 'on' when `strcmp(widget.YLimitMode,'auto-visible')`; Callback `@(~,~) obj.onYLimitButtonClicked_(widget, 'auto-visible', bar)`.
      * YLimitAllBtn present → label 'Auto-fit Y to all data'; Checked 'on' when `strcmp(widget.YLimitMode,'auto-all')`; Callback `@(~,~) obj.onYLimitButtonClicked_(widget, 'auto-all', bar)`.
      * PlantLogToggleButton present AND its `Enable` is 'on' → label 'Hide plant log lines' when `widget.ShowPlantLog` else 'Show plant log lines'; Callback `@(~,~) obj.onPlantLogTogglePressed_(hPlant, widget, obj.EngineRef)` where hPlant is the hidden PlantLogToggleButton handle. (When Enable is 'off' — no store — omit the item.)
      * CreateEventButton present → label 'Create event from selection / current view'; Callback `@(~,~) obj.invokeCreateEventCallback_(widget)`.
  - Post it: `cp = get(fig, 'CurrentPoint'); set(cm, 'Position', cp); set(cm, 'Visible', 'on');` (Position/Visible are settable on a classic-figure uicontextmenu; confirmed live this session).

(C) Wiring — call `obj.addOverflowMenu_(widget)` guarded (`try ... catch ME, warning('DashboardLayout:overflowMenuFailed', ...); end`) at these points, each AFTER the folded buttons exist and BEFORE the following reflowChrome_:
  - `realizeWidget`: immediately after the `addCrosshairLinkToggle` try/catch block (~line 425), before the `DashboardLayout.reflowChrome_(widget.hCellPanel, 28, 2)` at ~line 432. (Crosshair is the last folded button added, so all five exist.)
  - `addCrosshairLinkToggle`: right before its closing `try DashboardLayout.reflowChrome_(...)` (~line 823).
  - `addPlantLogToggle`: right before its closing `try DashboardLayout.reflowChrome_(...)` (~line 736).
  - `addYLimitButtons_`: after `syncYLimitButtonsState_(bar, widget.YLimitMode)` (~line 1080), at the method end.
  Keep every call idempotent (addOverflowMenu_ deletes its prior button first, so repeated calls are safe).

Do not embed fenced code in the file beyond normal MATLAB. All callbacks route to EXISTING methods so no downstream behaviour changes.
  </action>
  <verify>
    <automated>cd libs/Dashboard && grep -c "function addOverflowMenu_\|function showOverflowMenu_\|obj.addOverflowMenu_(widget)\|'OverflowMenuButton'\|DashboardLayout:overflowMenuFailed" DashboardLayout.m</automated>
    <notes>Expect >= 8 matches: 2 function defs + >= 4 call-sites (realizeWidget + 3 rebuilds) + the Tag literal (button create + idempotent findobj) + the warning id. Confirm the menu routes to existing actions: `grep -c "onCrosshairLinkTogglePressed_\|onYLimitButtonClicked_\|onPlantLogTogglePressed_\|invokeCreateEventCallback_" DashboardLayout.m` increased (new uimenu callbacks reference them). Confirm the glyph is `char(8230)` (not a literal ellipsis): `grep -n "char(8230)" DashboardLayout.m`. If MISS_HIT present: `mh_style` + `mh_lint` on the file report clean.</notes>
  </verify>
  <done>addOverflowMenu_ and showOverflowMenu_ exist as private methods; addOverflowMenu_ is called from realizeWidget and the 3 rebuild methods (each before its reflow); showOverflowMenu_ builds a fresh 'OverflowContextMenu' whose items route to the four existing action methods with correct Checked/label state; button uses char(8230), theme tokens only; all failures caught to DashboardLayout:overflowMenuFailed; MISS_HIT (if present) clean.</done>
</task>

<task type="auto">
  <name>Task 3: Anchor OverflowMenuButton in reflowChrome_</name>
  <files>libs/Dashboard/DashboardLayout.m</files>
  <action>
In the static `reflowChrome_` (~line 1163), inside the `if ~isempty(bar) && ishandle(bar(1))` block, after the existing CrosshairLinkButton anchor block (~line 1247-1251), add anchoring for the OverflowMenuButton so it lands at the leftmost slot the folded cluster used to occupy (left of the visible Info/Detach right cluster):

  - The folded buttons keep valid handles when hidden, so `findobj(...,'Tag','CrosshairLinkButton'/'YLimitVisibleBtn'/'YLimitAllBtn',...)` still resolve and `xLink`, `xVisible`, `xAll` remain computed exactly as today.
  - Hoist the `xLink` computation so it is available outside the CrosshairLinkButton `if` block: compute `xLink = xVisible - gap - bw;` once (it is currently assigned only inside that if). Reuse it for both the CrosshairLinkButton set and the new OverflowMenuButton set.
  - Add:
      `overflow = findobj(bar(1), 'Tag', 'OverflowMenuButton', '-depth', 1);`
      `if ~isempty(overflow) && ishandle(overflow(1))`
        pick `xOverflow = xLink` when the CrosshairLinkButton handle is present, else `xVisible` when the YLimitVisibleBtn handle is present, else `xAll`;
        `set(overflow(1), 'Position', [xOverflow, 2, bw, bw]);`
      `end`
    (`bw` and `gap` are the locals already defined earlier in the block; `bw = 24`.)

Add a one-line comment noting the overflow button reuses the leftmost folded slot (per redline (e) design). Change nothing about how Detach/Create/Info/PlantLog/V/A/CrosshairLink are anchored — the invisible folded buttons keep their computed slots (invisible → no visual conflict with the … button).
  </action>
  <verify>
    <automated>cd libs/Dashboard && grep -c "'Tag', 'OverflowMenuButton'\|xOverflow" DashboardLayout.m</automated>
    <notes>Expect the OverflowMenuButton Tag to appear in reflowChrome_ (findobj) plus `xOverflow` used in the set(). Confirm `xLink` is now referenced by both the CrosshairLink anchor and the overflow anchor (single hoisted assignment): `grep -n "xLink" DashboardLayout.m`. If MISS_HIT present: `mh_style` + `mh_lint` clean.</notes>
  </verify>
  <done>reflowChrome_ resolves OverflowMenuButton and sets its Position to the leftmost folded slot (xLink → xVisible → xAll fallback); xLink is hoisted and reused; no other anchor logic changed; MISS_HIT (if present) clean.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| user click → chrome callback | A left-click on the … button posts a context menu; menu items invoke existing dashboard action methods. No external/untrusted input crosses; all data is in-process widget state. |

## STRIDE Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation Plan |
|-----------|----------|-----------|----------|-------------|-----------------|
| T-ikg-01 | Denial of Service | showOverflowMenu_ posting on the figure | low | mitigate | Entire body wrapped in try/catch → namespaced warning DashboardLayout:overflowMenuFailed; a menu-post failure can never crash the DashboardEngine refresh loop (mirrors existing addPlantLogToggle / addCrosshairLinkToggle guards). |
| T-ikg-02 | Tampering | Folded buttons hidden but still callable via menu | low | accept | Menu items route to the SAME existing action methods (onCrosshairLinkTogglePressed_ / onYLimitButtonClicked_ / onPlantLogTogglePressed_ / invokeCreateEventCallback_); no new privilege or code path — behaviour is identical to clicking the (now hidden) buttons. |
| T-ikg-03 | Resource leak | Accumulated uicontextmenu objects across clicks | low | mitigate | showOverflowMenu_ deletes any prior 'OverflowContextMenu' before building a fresh one; addOverflowMenu_ also clears prior button + context menu (idempotent). |

No package-manager installs in this task (pure MATLAB edit to one existing file) — Package Legitimacy Gate not applicable.
</threat_model>

<verification>
Executor (no MATLAB) — structural only:
- `grep -c "'Visible', *'off'"` increased by exactly 4 (Task 1 folded sites) and neither addInfoIcon nor addDetachButton gained a Visible property.
- addOverflowMenu_ / showOverflowMenu_ exist and are wired into realizeWidget + the 3 rebuild methods; menu callbacks reference the four existing action methods; button glyph is char(8230); theme tokens only.
- reflowChrome_ anchors OverflowMenuButton; xLink hoisted and reused.
- MISS_HIT (`mh_style` + `mh_lint`) clean on `libs/Dashboard/DashboardLayout.m` if the tools are installed.

Human orchestrator (live MATLAB) — must-pass, NOT run by executor:
- Render `example_dashboard_all_widgets` with Theme='light'; screenshot confirms the X/V/A/L/+ strip is gone from every plot and a single … sits left of Info/Detach; clicking … posts a menu; each item performs its action (crosshair link, auto-fit Y visible/all, plant-log show/hide, create event).
- Suites all green: tests/test_dashboard_widget_button_bar.m, tests/test_dashboard_layout_plant_log_toggle.m, tests/suite/TestDashboardDetach.m, tests/suite/TestDashboardWidget.m, tests/suite/TestInfoTooltip.m, tests/suite/TestDashboardLayoutPlantLogToggle.m, tests/suite/TestIndustrialPlantDemoCompanion.m.
</verification>

<success_criteria>
- Only `libs/Dashboard/DashboardLayout.m` changed; no test or other source file touched.
- Five folded buttons (X/V/A/L/+) are Visible='off' but otherwise byte-equivalent (tags/positions/callbacks/state intact); Info + Detach untouched and visible.
- A single OverflowMenuButton (…) is created for fold-eligible widgets, anchored left of the right cluster, posting a fresh state-accurate context menu that routes to the existing action methods.
- All 7 must-pass suites remain green under the human orchestrator's live MATLAB run; the light-mode dashboard screenshot matches redline (e).
</success_criteria>

<output>
Create `.planning/quick/260709-ikg-overflow-menu-for-widget-chrome-redline-/260709-ikg-SUMMARY.md` when done.
In the SUMMARY, note explicitly: (a) the exact 4 creation sites that received 'Visible','off'; (b) that Info/Detach were left untouched; (c) any test that unexpectedly asserts a folded button's Visible state (none expected — flag, do NOT edit); (d) that live MATLAB verification + the 7 suites are deferred to the human orchestrator.
</output>
