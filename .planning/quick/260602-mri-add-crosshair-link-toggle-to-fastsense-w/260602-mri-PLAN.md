---
phase: 260602-mri
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/FastSense/HoverCrosshair.m
  - libs/Dashboard/FastSenseWidget.m
  - libs/Dashboard/DashboardEngine.m
  - libs/Dashboard/DashboardLayout.m
  - libs/Dashboard/DashboardWidget.m
  - tests/test_fastsense_crosshair_link.m
autonomous: true
requirements:
  - MRI-01   # CrosshairLinked property + setCrosshairLink on FastSenseWidget (default false), toStruct/fromStruct round-trip (omit default)
  - MRI-02   # HoverCrosshair gains BroadcastFcn_ broadcast hook + suppress-leave guard so a mirrored crosshair shows-instead-of-hides without new figure-WBM closures
  - MRI-03   # DashboardEngine coordinates the active-page link set: hovered widget broadcasts its data-x; every OTHER linked FastSense widget mirrors crosshair + per-series datatip at that x
  - MRI-04   # Crosshair-link toggle button (X glyph) on the FastSenseWidget WidgetButtonBar, duck-typed via ismethod(widget,'setCrosshairLink'); reflow re-anchors it; survives Reset/resize/page-switch
  - MRI-05   # Backward compat: default OFF, legacy serialized dashboards load unchanged; unlink-on-detach; per-active-page scope

must_haves:
  truths:
    - "A FastSenseWidget tile shows a crosshair-link toggle button (X) on its grey WidgetButtonBar, left of V/A and Info/Detach"
    - "Toggling the button ON for >=2 FastSense widgets on the active page links them: hovering ANY linked widget mirrors the crosshair x onto all OTHER linked widgets, each showing its own per-series datatip at that x"
    - "Toggling the button OFF removes that widget from the link set; it no longer mirrors or receives"
    - "When the cursor leaves all linked axes, the mirrored crosshairs hide"
    - "Existing single-widget hover (standalone FastSense, unlinked dashboard widgets) is unchanged"
    - "A legacy serialized dashboard (no crosshairLinked field) loads with all widgets unlinked and identical behaviour + identical JSON"
    - "Linking survives top-toolbar Reset (rerenderWidgets), figure resize, and page switch"
  artifacts:
    - path: "libs/FastSense/HoverCrosshair.m"
      provides: "BroadcastFcn_ property + setBroadcastFcn(fn) + suppress-leave guard (SuppressLeaveUntil_/onMoveExternal)"
      contains: "BroadcastFcn_"
    - path: "libs/Dashboard/FastSenseWidget.m"
      provides: "CrosshairLinked public property (default false) + setCrosshairLink(tf) + toStruct/fromStruct round-trip (omit when false)"
      contains: "CrosshairLinked"
    - path: "libs/Dashboard/DashboardEngine.m"
      provides: "Active-page crosshair-link coordination: onCrosshairLinkToggle, broadcastCrosshairX_, broadcastCrosshairLeave_, collectLinkedCrosshairs_, rewireCrosshairLinks_"
      contains: "collectLinkedCrosshairs_"
    - path: "libs/Dashboard/DashboardLayout.m"
      provides: "addCrosshairLinkToggle button (Tag CrosshairLinkButton) duck-typed via ismethod(widget,'setCrosshairLink'); reflowChrome_ re-anchors it"
      contains: "CrosshairLinkButton"
    - path: "tests/test_fastsense_crosshair_link.m"
      provides: "Pure-logic + headless-render unit tests for property round-trip + collectLinkedCrosshairs_ + suppress-leave guard"
      contains: "test_fastsense_crosshair_link"
  key_links:
    - from: "libs/Dashboard/DashboardLayout.m (CrosshairLinkButton callback)"
      to: "DashboardEngine.onCrosshairLinkToggle (via EngineRef)"
      via: "button callback -> widget.setCrosshairLink(tf) + engine.onCrosshairLinkToggle(widget)"
      pattern: "onCrosshairLinkToggle"
    - from: "libs/FastSense/HoverCrosshair.m (source onMove)"
      to: "DashboardEngine.broadcastCrosshairX_"
      via: "BroadcastFcn_ callback fired at end of onMove"
      pattern: "BroadcastFcn_"
    - from: "DashboardEngine.broadcastCrosshairX_"
      to: "peer HoverCrosshair_.onMoveExternal(x)"
      via: "loop over collectLinkedCrosshairs_(activePageWidgets) excluding source"
      pattern: "onMoveExternal"
    - from: "DashboardEngine.rerenderWidgets / switchPage"
      to: "rewireCrosshairLinks_"
      via: "re-prime BroadcastFcn_ on freshly-rebuilt HoverCrosshair_ handles"
      pattern: "rewireCrosshairLinks_"
---

<objective>
Add a crosshair-link toggle button to the FastSense dashboard widget's grey WidgetButtonBar. When toggled ON for a widget, that widget joins a crosshair-link set scoped to the CURRENTLY ACTIVE dashboard page. Moving the hover crosshair over ANY linked FastSense widget mirrors the crosshair's data-x onto all OTHER linked FastSense widgets on the same page; each mirrored widget shows its own per-series datatip at that same x — so the user compares values at the same x/time across multiple plots. Toggling OFF removes the widget from the set.

Purpose: Cross-plot value comparison at a shared x/time without detaching widgets or losing dashboard context.
Output: A new `CrosshairLinked` property + button, a broadcast hook on `HoverCrosshair`, and active-page link coordination on `DashboardEngine` — all backward-compatible, MATLAB+Octave-safe, toolbox-free.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@CLAUDE.md
@.planning/STATE.md

# Precedent — the EXACT pattern to mirror (V/A/L buttons): widget exposes a setter,
# DashboardLayout duck-types via ismethod, toStruct omits the default.
@.planning/quick/260513-sfp-add-auto-y-limit-control-buttons-to-fast/260513-sfp-SUMMARY.md

<decisions>
User chose plain /gsd:quick (no --discuss). The planner locked these defaults — record them in SUMMARY:

- **D-01 Link model — SHARED SET.** Any widget with the toggle ON both broadcasts on hover AND receives mirrors. No master/source role. Matches "mirror across ALL other FastSense widgets".
- **D-02 X mapping — RAW DATA-X.** Sensor dashboards share a time axis and the user said "same x/time position". `HoverCrosshair.onMove(xQuery)` already computes each line's Y at xQuery via `computeYAtX_` (binary_search), so each mirrored widget shows ITS OWN series values for free — no Y is transmitted. Log-x axes: the raw x VALUE is still correct (no pixel/normalized transform); a peer whose data does not span x shows em-dashes, which is the existing OOR behaviour. No special-casing needed.
- **D-03 Coordination owner — DashboardEngine methods + per-widget flag (NO new class).** The link set is derived on demand from `FastSenseWidget.CrosshairLinked` over the flattened active-page widgets (`collectLinkedCrosshairs_`). Least-invasive; the enumeration logic is a pure-testable helper.
- **D-04 Suppress-hide crux — broadcast hook + suppress-leave tic-guard on HoverCrosshair; NO new figure-WBM closures.** The single dashboard-figure WindowButtonMotionFcn already carries a chain of every widget's `HoverCrosshair.onFigureMove_` (newHcN -> ... -> newHc1 -> trs). When the cursor is over widget A, A's `onFigureMove_` resolves "inside" and calls `A.onMove(xQuery)`; B/C/D's `onFigureMove_` resolve "outside" and call `onLeave()` (hide). We make A's `onMove` ALSO drive peers, and make a recently-mirrored peer's `onLeave()` a no-op:
    1. New `BroadcastFcn_` callback on HoverCrosshair, fired at the END of `onMove(xQuery)` (only when set). On a dashboard, the engine sets this to `@(x) engine.broadcastCrosshairX_(thisCrosshair, x)`.
    2. `broadcastCrosshairX_(sourceHc, x)` loops the active-page linked crosshairs, and for each peer != source calls `peer.onMoveExternal(x)`.
    3. `onMoveExternal(x)` sets `SuppressLeaveUntil_ = tic` (window ~= 3*ThrottleSeconds) then calls `onMove(x)` with broadcasting DISABLED (re-entrancy: peers must not re-broadcast). `onLeave()` early-returns while `toc(SuppressLeaveUntil_) < window`. So when peer B's own `onFigureMove_` later fires `onLeave()` in the SAME motion dispatch (cursor not over B), the guard swallows it and B's mirrored crosshair stays visible.
    4. When the cursor leaves ALL linked axes: the source's `onFigureMove_` calls its own `onLeave()` (no suppress on the source) and, if `BroadcastFcn_` is set, the engine also broadcasts `onLeaveExternal()` to peers (clears their suppress + hides). Implement leave-broadcast by having `onLeave()` on a broadcasting crosshair invoke a paired `LeaveBroadcastFcn_` (or fold leave into `BroadcastFcn_` with a sentinel — simplest: a second callback `BroadcastLeaveFcn_`). Peers' `onLeaveExternal()` sets `SuppressLeaveUntil_ = []` then hides.
  This adds ZERO new closures to the figure WBM — the broadcast rides on the EXISTING per-crosshair `onMove`/`onLeave` calls. This is the design constraint that prevents repeating the 260512-egv dangling-closure regression.
- **D-05 Lifecycle — per-active-page set; unlink-on-detach; re-prime after rerender/switchPage.** Each `FastSenseWidget`'s `HoverCrosshair_` is recreated by `FastSense.render()` on every `rerenderWidgets` (Reset) and on page allocation. The engine must RE-PRIME `BroadcastFcn_`/`BroadcastLeaveFcn_` on the fresh crosshair handles after the realizeWidget loop and after switchPage (the 260512-eu2 reinstall-after-rerender lesson). Detaching a linked widget: drop it from the set by leaving `CrosshairLinked=true` but it no longer participates because `collectLinkedCrosshairs_` only walks active-page widgets — the detached widget is no longer in `activePageWidgets()`. Simpler still: clear its broadcast hook on detach. Mirrored crosshairs hide naturally on the next source `onLeave`.
- **D-06 Backward compat — default OFF, toStruct omits, legacy loads unchanged.** Mirror the YLimitMode idiom byte-for-byte.
- **D-07 Button glyph — ASCII 'X'.** Matches existing ASCII Info ('i') / Detach ('^') / V / A / L glyphs (Octave Unicode-in-uicontrol rendering is inconsistent; the WidgetButtonBar deliberately avoids Unicode — see 260513-sfp D-03). Active (linked) state highlighted via the existing `chooseYLimitActiveBg_` helper.
</decisions>

<interfaces>
<!-- Contracts extracted from the codebase. Use these directly — do NOT re-explore. -->

From libs/FastSense/HoverCrosshair.m (verified):
- `properties (SetAccess = private)`: Target, hFigure, hAxes, hLineV, hTipBox  (GetAccess public — tests read fp.HoverCrosshair_)
- `properties (Access = private)`: PrevWBMFcn_, LastUpdateTime, IsBusy, FigDeleteListener, AxDeleteListener, ThrottleSeconds=0.025
- `onMove(obj, xQuery)` — PUBLIC. Updates+shows the vertical line + datatip at data-x xQuery. Computes per-line Y at xQuery internally (computeYAtX_). THIS is the external-drive entry point.
- `onLeave(obj)` — PUBLIC. Hides line + datatip. Already guarded by `if ~isvalid(obj); return; end`.
- `onFigureMove_(obj, src, evt)` — PRIVATE chained WBM handler. Lines 295-297: validity/handle guards FIRST. Line ~342-346: when cursor is OUTSIDE hAxes pixel bounds it calls `obj.onLeave()`. Line 366: when inside, `obj.onMove(xQuery)`.
- `delete(obj)` restores PrevWBMFcn_ unconditionally.

From libs/FastSense/FastSense.m (verified):
- `HoverCrosshair` PUBLIC property (line 91, default true) — opt-out flag.
- `HoverCrosshair_` property, `SetAccess = private` (line 174) -> GetAccess is PUBLIC. Created in render() at lines 1622-1631 (only when interactive desktop). So from a widget: `widget.FastSenseObj.HoverCrosshair_` is the reachable per-widget crosshair handle (may be [] under -batch/headless — guard with isempty + isvalid).

From libs/Dashboard/FastSenseWidget.m (verified — mirror the YLimitMode pattern exactly):
- `properties (Access = public)`: ... LiveViewMode='preserve', YLimitMode='auto-visible' (line 66). ADD `CrosshairLinked = false` here.
- `FastSenseObj` (SetAccess=private, line 71): the FastSense handle (.hAxes, .IsRendered, .HoverCrosshair_).
- `setYLimitMode(obj, mode)` (line 545) — public setter precedent.
- toStruct (line 1194): `if ~strcmp(obj.YLimitMode,'auto-visible'); s.yLimitMode = obj.YLimitMode; end` (line 1205-1207). ADD `if obj.CrosshairLinked; s.crosshairLinked = true; end`.
- fromStruct (line 1501): `if isfield(s,'yLimitMode'); try obj.setYLimitMode(s.yLimitMode); catch; end; end` (line 1566-1572). ADD analogous `if isfield(s,'crosshairLinked'); obj.CrosshairLinked = logical(s.crosshairLinked); end` (do NOT call a setter that touches graphics here — fromStruct runs pre-render; just set the flag, the engine wires broadcast at render/realize time).

From libs/Dashboard/DashboardLayout.m (verified):
- `EngineRef` property (line 28) — back-reference to DashboardEngine; set at DashboardEngine.m:164 `obj.Layout.EngineRef = obj;`.
- `realizeWidget` (line ~352-428): chrome injected when `needsBar`. `needsBar` (line 370-373) already includes `ismethod(widget,'setYLimitMode')`. The crosshair-link button is FastSenseWidget-only and FastSenseWidget already triggers needsBar via setYLimitMode, so NO needsBar change is required — but the new button injection block must be added INSIDE the `if needsBar` body, after `addYLimitButtons_` (line 401-403) and after `addPlantLogToggle` (line 405-413), BEFORE the final `reflowChrome_(widget.hCellPanel, 28, 2)` (line 420).
- Button precedent to copy: `addPlantLogToggle(obj, widget, engine)` (line 627) — reaches engine via EngineRef, idempotent (deletes prior by Tag), builds uicontrol with a Tag, callback toggles state + rebuilds + reflows. `onPlantLogTogglePressed_` (line 723) wraps in try/catch + non-blocking uialert.
- `addYLimitButton_` (line 988) — the simplest uicontrol-button template (Position [x 2 24 24], FontSize 9, FontWeight bold, theme.ToolbarFontColor / theme.ToolbarBackground, Tag, TooltipString, Callback).
- `reflowChrome_(hCell, barH, inset)` STATIC (line 1068) — re-anchors right cluster. Right-to-left order today: Detach (barW-24-4) ... Create ... Info ... PlantLog (xPl) ... then V/A cluster LEFT of PlantLog (xAll/xVisible at lines 1130-1146). ADD CrosshairLink as the LEFTMOST button: place it to the LEFT of the V/A cluster (i.e. `xLink = xVisible - gap - bw`). Find it via `findobj(bar(1),'Tag','CrosshairLinkButton','-depth',1)` and set its Position. Keep the same bw=24, gap=4 convention.
- `chooseYLimitActiveBg_(theme)` STATIC (line 1155) — reuse for the linked (active) highlight.

From libs/Dashboard/DashboardWidget.m (verified):
- `clearPanelControls(hPanel)` (line 133): `protectedTags` (line 145-147) lists InfoIconButton, DetachButton, WidgetButtonBar, YLimitVisibleBtn, YLimitAllBtn, CreateEventButton, PlantLogToggleButton. ADD `'CrosshairLinkButton'` so the toggle survives re-render sweeps.

From libs/Dashboard/DashboardEngine.m (verified):
- `Layout.EngineRef = obj` set at line 164.
- `activePageWidgets()` (line 2834) and `allPageWidgets()` (line 2845) — PUBLIC.
- `flattenWidgetsForPreview_(obj, widgets, depth)` (line 3390) — depth-first flatten that unwraps GroupWidget children via getNestedWidgets(); depth cap 10. USE THIS to flatten active-page widgets so FastSense widgets nested in a GroupWidget participate. THIS feature is ACTIVE-PAGE scoped -> `flattenWidgetsForPreview_(activePageWidgets())`.
- `rerenderWidgets` (lines 1742-1805): deletes each widget's outer cell panel (1742-1769), reinstalls TRS callbacks (1782-1790), re-allocates + `realizeWidget` loop (1794-1799 — this recreates each FastSense + a FRESH HoverCrosshair_), re-wires DetachCallback (1802) + CreateEventCallback (1804). ADD a `rewireCrosshairLinks_()` call at the END of this method (after line 1804) so the fresh HoverCrosshair_ handles get their BroadcastFcn_ re-primed.
- `switchPage(obj, pageIdx)` (line 243) — after the page becomes active, call `rewireCrosshairLinks_()` so the now-active page's linked widgets are wired (and the previously-active page's are dropped, since collectLinkedCrosshairs_ only walks the active page).
- `detachWidget(obj, widget)` (line 1535) — on detach, clear that widget's crosshair broadcast hook (best-effort) so a detached widget stops participating.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: CrosshairLinked property + HoverCrosshair broadcast hook (pure-testable core)</name>
  <files>libs/Dashboard/FastSenseWidget.m, libs/FastSense/HoverCrosshair.m, tests/test_fastsense_crosshair_link.m</files>
  <behavior>
    FastSenseWidget (per MRI-01, mirror YLimitMode idiom):
    - New public property `CrosshairLinked = false` (declare in the `properties (Access = public)` block beside YLimitMode at line 66, with a header comment).
    - New public method `setCrosshairLink(obj, tf)`: validate `logical scalar` (accept logical or 0/1 numeric scalar; else error 'FastSenseWidget:invalidCrosshairLink'); set `obj.CrosshairLinked = logical(tf)`. Do NOT touch graphics here — the engine owns broadcast wiring. (Setter is the duck-type hook DashboardLayout checks via ismethod.)
    - toStruct (line ~1205): after the yLimitMode block, add `if obj.CrosshairLinked; s.crosshairLinked = true; end` (omit when false -> legacy JSON byte-identical).
    - fromStruct (line ~1566): after the yLimitMode block, add `if isfield(s,'crosshairLinked'); obj.CrosshairLinked = logical(s.crosshairLinked); end`. Absent -> stays false.

    HoverCrosshair (per MRI-02, the suppress-hide mechanism — D-04):
    - Add `properties (Access = private)`: `BroadcastFcn_ = []`, `BroadcastLeaveFcn_ = []`, `SuppressLeaveUntil_ = []`, `SuppressWindow_ = 0.075` (~3*ThrottleSeconds).
    - New public `setBroadcastFcn(obj, moveFn, leaveFn)`: store the two callbacks (each a function_handle or []). Tolerate nargin<3 (leaveFn defaults []).
    - New public `onMoveExternal(obj, xQuery)`: guard `if ~isvalid(obj); return; end`; set `obj.SuppressLeaveUntil_ = tic`; then drive the crosshair WITHOUT re-broadcasting — call the existing `onMove` body but suppress the broadcast tail (simplest: set a private `InBroadcast_=true` flag, call `obj.onMove(xQuery)`, reset flag; `onMove`'s broadcast tail is gated on `~obj.InBroadcast_`). Add `InBroadcast_ = false` to the private props.
    - New public `onLeaveExternal(obj)`: guard isvalid; set `obj.SuppressLeaveUntil_ = []`; call `obj.onLeave()` (which will now hide since the guard is cleared).
    - Modify `onMove(obj, xQuery)`: at the very END (after the tip box is shown), add the broadcast tail:
        `if ~obj.InBroadcast_ && isa(obj.BroadcastFcn_,'function_handle'); try obj.BroadcastFcn_(xQuery); catch; end; end`
    - Modify `onLeave(obj)`: at the TOP, add the suppress guard:
        `if ~isempty(obj.SuppressLeaveUntil_); try; if toc(obj.SuppressLeaveUntil_) < obj.SuppressWindow_; return; end; catch; obj.SuppressLeaveUntil_ = []; end; end`
      AND at the END (after hiding), if this crosshair is a broadcaster (not currently being externally driven) and has a leave callback, broadcast leave:
        `if ~obj.InBroadcast_ && isempty(obj.SuppressLeaveUntil_) && isa(obj.BroadcastLeaveFcn_,'function_handle'); try obj.BroadcastLeaveFcn_(); catch; end; end`
      NOTE on ordering: the source crosshair has `SuppressLeaveUntil_` empty (it is the hovered one), so its onLeave runs the hide + leave-broadcast. A peer being mirrored has `SuppressLeaveUntil_` set, so its own onLeave (fired by its own onFigureMove_ later in the same dispatch) early-returns. This is the crux — verify carefully.
    - delete(obj): also clear the callbacks (set BroadcastFcn_/BroadcastLeaveFcn_ to []) before/after restoring PrevWBMFcn_ (defensive — avoid a dangling engine ref firing post-delete; the existing isvalid guards already protect, but null the handles too).

    Tests (tests/test_fastsense_crosshair_link.m — function-style, mirror test_fastsense_widget_ylimit_modes.m structure: addpath+install, nPassed/nFailed counters, per-case try/catch, em-dash-free messages, a canRenderFigures_() helper, final `assert(nFailed==0)` + `fprintf('    All %d tests passed.\n', nPassed)`):
      - PURE (no figure): default `CrosshairLinked == false`.
      - PURE: setCrosshairLink(true) -> true; setCrosshairLink(false) -> false; setCrosshairLink('bad') throws 'FastSenseWidget:invalidCrosshairLink'.
      - PURE: toStruct omits crosshairLinked when false (`~isfield(toStruct,'crosshairLinked')`); emits `true` when set.
      - PURE: fromStruct restores true when present; legacy struct (no field) -> false.
      - RENDER-GUARDED (canRenderFigures_): build a FastSense on an offscreen axes, attach a HoverCrosshair, call `setBroadcastFcn`; assert `onMoveExternal(x)` makes the crosshair line Visible='on' AND that an immediately-following `onLeave()` is SUPPRESSED (line still Visible='on') because SuppressLeaveUntil_ is fresh; then `onLeaveExternal()` hides it (Visible='off'). This is the direct unit proof of the suppress-leave crux.
      - RENDER-GUARDED: a broadcaster's `onMove(x)` invokes BroadcastFcn_ exactly once (capture via a counter closure); `onMoveExternal(x)` does NOT re-invoke it (InBroadcast_ gate).
  </behavior>
  <action>
    Implement FastSenseWidget property/setter/round-trip first (RED: write the PURE test cases, watch them fail, then GREEN). Then implement the HoverCrosshair broadcast hook + suppress-leave guard (RED render-guarded cases, then GREEN). Keep all new error IDs namespaced. Octave-safe: HoverCrosshair already documents it is MATLAB-only for the render path (test_hover_crosshair skips on Octave) — gate the render cases behind canRenderFigures_() and an Octave skip exactly like test_hover_crosshair.m. The PURE FastSenseWidget cases MUST run on both MATLAB and Octave (no graphics).
    Follow MISS_HIT style: 160-col lines, 4-space tabs, PascalCase props, camelCase methods, trailing-underscore private state.
  </action>
  <verify>
    <automated>MISSING — orchestrator runs live MATLAB. Executor cannot run MATLAB (no MCP). Static check: `grep -n "CrosshairLinked" libs/Dashboard/FastSenseWidget.m` shows property + toStruct + fromStruct; `grep -n "BroadcastFcn_\|onMoveExternal\|onLeaveExternal\|SuppressLeaveUntil_" libs/FastSense/HoverCrosshair.m` shows all four; `grep -c "nPassed = nPassed + 1" tests/test_fastsense_crosshair_link.m` >= 8. Orchestrator will run: `mcp__matlab__run_matlab_test_file tests/test_fastsense_crosshair_link.m` (expect all pass) + `tests/test_fastsense_widget_ylimit_modes.m` + `tests/test_hover_crosshair.m` as regression.</automated>
  </verify>
  <done>FastSenseWidget has CrosshairLinked (default false) + setCrosshairLink + JSON round-trip (omit default). HoverCrosshair has BroadcastFcn_/BroadcastLeaveFcn_ + setBroadcastFcn + onMoveExternal + onLeaveExternal + suppress-leave guard, with onMove broadcasting once at its tail and onLeave honoring the suppress window. test_fastsense_crosshair_link.m exists with >=8 cases (PURE + render-guarded suppress-leave proof). No new figure-WBM closures introduced.</done>
</task>

<task type="auto">
  <name>Task 2: DashboardEngine active-page link coordination + lifecycle re-wiring</name>
  <files>libs/Dashboard/DashboardEngine.m, tests/test_fastsense_crosshair_link.m</files>
  <action>
    Implement the coordination layer (MRI-03, MRI-05) on DashboardEngine. Add a `methods` block (public where tests need it):

    1. `collectLinkedCrosshairs_(obj, widgets)` — PURE-ENUMERATION helper (make it public or Hidden so the test can drive it with a synthetic widget list). Flatten `widgets` via `obj.flattenWidgetsForPreview_(widgets)` (unwraps GroupWidget children). Return a cell array of structs `{struct('widget',w,'hc',hc), ...}` for every flattened widget that (a) `isa(w,'FastSenseWidget')`, (b) `w.CrosshairLinked` is true, (c) `~isempty(w.FastSenseObj)` and the FastSense is rendered, (d) `~isempty(w.FastSenseObj.HoverCrosshair_)` and `isvalid` (Octave: skip isvalid). Skip any widget failing a guard — never throw. KEEP THIS PURE (no side effects) so it is unit-testable against a hand-built widget list.

    2. `rewireCrosshairLinks_(obj)` — the wiring driver. Compute `linked = obj.collectLinkedCrosshairs_(obj.activePageWidgets())`. FIRST clear BroadcastFcn_ on ALL active-page FastSense crosshairs (so a widget toggled OFF, or the previously-active page, stops broadcasting) — walk the flattened active page, and for each FastSenseWidget with a valid HoverCrosshair_ call `hc.setBroadcastFcn([], [])`. THEN, for each entry in `linked`, set `entry.hc.setBroadcastFcn(@(x) obj.broadcastCrosshairX_(entry.hc, x), @() obj.broadcastCrosshairLeave_(entry.hc))`. Wrap per-handle in try/catch. Only meaningful when >=1 linked widget, but clearing must always run. Guard: if `obj.HoverCrosshair_`-style headless (no crosshairs) it is a no-op.

    3. `broadcastCrosshairX_(obj, sourceHc, xQuery)` — re-collect `linked = obj.collectLinkedCrosshairs_(obj.activePageWidgets())` (cheap; active page only; respects the 0.025s throttle upstream because this only fires from a source onMove which is itself throttled). For each entry where `entry.hc ~= sourceHc` (handle inequality), call `entry.hc.onMoveExternal(xQuery)` in try/catch. AVOID per-tick allocations beyond the small cell — acceptable per perf constraint (broadcast path runs at most ~40Hz, N widgets small).

    4. `broadcastCrosshairLeave_(obj, sourceHc)` — re-collect linked; for each peer `~= sourceHc` call `entry.hc.onLeaveExternal()` in try/catch.

    5. `onCrosshairLinkToggle(obj, widget)` — PUBLIC. Called by the DashboardLayout button callback AFTER `widget.setCrosshairLink(tf)` flips the flag. Just calls `obj.rewireCrosshairLinks_()` (re-derives the whole active-page set from current flags — idempotent, simplest correct behaviour). Wrap in try/catch + namespaced warning 'DashboardEngine:crosshairLinkToggleFailed'.

    6. Lifecycle hooks (the 260512-eu2 re-establishment lesson):
       - In `rerenderWidgets`, add `obj.rewireCrosshairLinks_();` at the END (after the CreateEventCallback re-wire at line ~1804), wrapped in try/catch warning 'DashboardEngine:crosshairRewireFailed'. The fresh HoverCrosshair_ handles created by the realizeWidget loop get their broadcast hooks (re-)primed here.
       - In `switchPage`, after the page is made active + widgets realized/refreshed, call `obj.rewireCrosshairLinks_();` (try/catch). This drops the previously-active page's wiring (those widgets are no longer in activePageWidgets) and primes the now-active page.
       - In `detachWidget`, best-effort clear the detaching widget's broadcast hook before/while detaching: `if isa(widget,'FastSenseWidget') && ~isempty(widget.FastSenseObj) && ~isempty(widget.FastSenseObj.HoverCrosshair_); try widget.FastSenseObj.HoverCrosshair_.setBroadcastFcn([],[]); catch; end; end`. Then call `obj.rewireCrosshairLinks_()` after detach completes so the remaining active-page set is consistent. (The detached widget keeps CrosshairLinked=true in its serialized state but no longer participates because it left activePageWidgets.)

    Tests — APPEND to tests/test_fastsense_crosshair_link.m:
      - PURE: build a DashboardEngine with 3 FastSenseWidgets on one page (use the existing makeTag_/widget helpers from test_fastsense_widget_ylimit_modes.m as a model; render headless via canRenderFigures_ or, for the PURE enumeration case, hand-build a fake widget list of structs that duck-type .CrosshairLinked/.FastSenseObj so collectLinkedCrosshairs_ can be exercised WITHOUT a figure). Assert `collectLinkedCrosshairs_` returns only the widgets with CrosshairLinked==true and a valid rendered crosshair; flipping a flag changes the count; a GroupWidget-nested linked FastSenseWidget IS included (flatten works).
      - RENDER-GUARDED end-to-end: render a 2-widget dashboard, setCrosshairLink(true) on both, call rewireCrosshairLinks_, then simulate hover by calling widgetA.FastSenseObj.HoverCrosshair_.onMove(xMid) and assert widgetB's crosshair line became Visible='on' at xMid (mirror works); then call onLeave on A and assert B hides. This is the integration proof.
      Keep the render cases behind canRenderFigures_() + Octave skip; keep the collectLinkedCrosshairs_ enumeration case PURE (runs everywhere).
  </action>
  <verify>
    <automated>MISSING — orchestrator runs live MATLAB. Static check: `grep -n "collectLinkedCrosshairs_\|broadcastCrosshairX_\|broadcastCrosshairLeave_\|onCrosshairLinkToggle\|rewireCrosshairLinks_" libs/Dashboard/DashboardEngine.m` shows all five; `grep -n "rewireCrosshairLinks_" libs/Dashboard/DashboardEngine.m` appears in rerenderWidgets, switchPage, detachWidget AND the method def (>=4 hits). Orchestrator runs: `mcp__matlab__run_matlab_test_file tests/test_fastsense_crosshair_link.m` (expect all pass) + regression `tests/test_time_range_selector_reinstall_after_rerender.m` (the eu2/egv guard — must stay green) + `tests/test_dashboard_time_sync_all_pages.m`.</automated>
  </verify>
  <done>DashboardEngine derives the active-page link set on demand from CrosshairLinked flags (flattening GroupWidget children), broadcasts a hovered widget's data-x to all OTHER linked widgets' crosshairs via onMoveExternal, broadcasts leave via onLeaveExternal, and re-primes the broadcast hooks after rerenderWidgets, switchPage, and detachWidget. collectLinkedCrosshairs_ is pure and unit-tested. No new figure-WBM closures; the TRS reinstall regression test stays green.</done>
</task>

<task type="auto">
  <name>Task 3: Crosshair-link toggle button on the WidgetButtonBar (duck-typed) + protect from re-render sweep</name>
  <files>libs/Dashboard/DashboardLayout.m, libs/Dashboard/DashboardWidget.m</files>
  <action>
    Add the toggle button (MRI-04), mirroring addPlantLogToggle/addYLimitButtons_ exactly.

    1. In `DashboardLayout.realizeWidget` (inside the `if needsBar` body): after the `addYLimitButtons_` block (line ~401-403) and after the `addPlantLogToggle` block (line ~405-413), and BEFORE the final `reflowChrome_(widget.hCellPanel, 28, 2)` (line ~420), add:
         `if ismethod(widget, 'setCrosshairLink'); try obj.addCrosshairLinkToggle(widget); catch ME; warning('DashboardLayout:crosshairToggleFailed', 'addCrosshairLinkToggle failed during realizeWidget: %s', ME.message); end; end`
       (No needsBar change needed — FastSenseWidget already triggers needsBar via setYLimitMode.)

    2. New method `addCrosshairLinkToggle(obj, widget)` (model on addPlantLogToggle):
       - Resolve theme: `if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme); theme = DashboardTheme('light'); else; theme = widget.ParentTheme; end`.
       - `bar = obj.getOrCreateButtonBar_(widget);`
       - Idempotent: delete any prior `findobj(bar,'Tag','CrosshairLinkButton','-depth',1)`.
       - Position: this is the LEFTMOST chrome button. Compute its x as LEFT of the V/A cluster. The initial x can be a best-effort (the final position is settled by reflowChrome_): mirror addYLimitButtons_'s left-anchored math and subtract one more `(bw+gap)`. Simplest robust approach: place it provisionally (e.g. `xLink = 2`) and rely on the realizeWidget-tail reflowChrome_ to anchor it correctly — but PREFER computing it consistently with reflowChrome_ (xVisible - gap - bw) using the same hasCreate/hasPlantLog detection so the very first paint is right. 24x24, FontSize 9, FontWeight bold.
       - Glyph 'X', Tag 'CrosshairLinkButton', TooltipString: linked -> 'Unlink crosshair (stop mirroring)'; unlinked -> 'Link crosshair across page'. ForegroundColor theme.ToolbarFontColor. BackgroundColor: when `widget.CrosshairLinked` use `DashboardLayout.chooseYLimitActiveBg_(theme)` (highlighted), else `theme.ToolbarBackground`.
       - Callback: `@(s,~) obj.onCrosshairLinkTogglePressed_(s, widget)`.
       - After creating, call `DashboardLayout.reflowChrome_(widget.hCellPanel, 28, 2)` in try/catch (matches addPlantLogToggle's tail so callback-driven rebuilds re-anchor).

    3. New method `onCrosshairLinkTogglePressed_(obj, src, widget)` (model on onPlantLogTogglePressed_):
       - try: `widget.setCrosshairLink(~widget.CrosshairLinked);` then notify the engine: `if ~isempty(obj.EngineRef) && isa(obj.EngineRef,'DashboardEngine'); obj.EngineRef.onCrosshairLinkToggle(widget); end`. Then rebuild the button look: `obj.addCrosshairLinkToggle(widget);`.
       - catch ME: `warning('DashboardLayout:crosshairToggleFailed', 'Crosshair-link toggle callback failed: %s', ME.message);` + best-effort non-blocking uialert if a uifigure ancestor exists (copy the onPlantLogTogglePressed_ uialert block).

    4. In `reflowChrome_` (STATIC, line 1068): after the V/A cluster re-anchor block (lines ~1130-1146), add the CrosshairLink re-anchor as the LEFTMOST button:
         `link = findobj(bar(1),'Tag','CrosshairLinkButton','-depth',1);`
         `if ~isempty(link) && ishandle(link(1)); xLink = xVisible - gap - bw; set(link(1),'Position',[xLink,2,bw,bw]); end`
       (xVisible is already computed for the V/A cluster just above; reuse it. If V/A absent for some future duck-typed widget, fall back to anchoring left of the right-cluster — but FastSenseWidget always has V/A, so the simple `xVisible - gap - bw` is correct for the only consumer today. Add a brief comment noting the leftmost-button assumption.)

    5. In `DashboardWidget.clearPanelControls` (line 145-147): append `'CrosshairLinkButton'` to `protectedTags` so the button survives the depth-1 uicontrol sweep on re-render.
  </action>
  <verify>
    <automated>MISSING — orchestrator runs live MATLAB. Static check: `grep -n "CrosshairLinkButton\|addCrosshairLinkToggle\|onCrosshairLinkTogglePressed_" libs/Dashboard/DashboardLayout.m` shows the button Tag + both methods + reflow re-anchor (>=5 hits); `grep -n "CrosshairLinkButton" libs/Dashboard/DashboardWidget.m` shows it in protectedTags; `grep -n "setCrosshairLink\|onCrosshairLinkToggle" libs/Dashboard/DashboardLayout.m` shows the realizeWidget duck-type + the EngineRef callback. Orchestrator will smoke-test on the live demo: button renders with Tag CrosshairLinkButton on the WidgetButtonBar left of V/A, clicking it toggles widget.CrosshairLinked + highlight, and after a top-toolbar Reset + figure resize the button stays anchored and linking still mirrors.</automated>
  </verify>
  <done>Every FastSenseWidget tile shows an 'X' crosshair-link toggle on its WidgetButtonBar (leftmost chrome button, left of V/A), duck-typed via ismethod(widget,'setCrosshairLink'). Clicking flips CrosshairLinked, highlights when linked, and calls EngineRef.onCrosshairLinkToggle to (re)wire the active-page link set. reflowChrome_ re-anchors it on resize; clearPanelControls protects it from re-render sweeps. The callback never throws into the refresh loop (try/catch + warning + non-blocking uialert).</done>
</task>

</tasks>

<verification>
Overall checks (orchestrator runs these in live MATLAB — executor cannot):

1. `mcp__matlab__run_matlab_test_file tests/test_fastsense_crosshair_link.m` — all cases pass (PURE on MATLAB+Octave; render cases on MATLAB desktop).
2. Regression (MUST stay green):
   - `tests/test_fastsense_widget_ylimit_modes.m` (V/A/L untouched)
   - `tests/test_hover_crosshair.m` (standalone hover unchanged)
   - `tests/test_time_range_selector_reinstall_after_rerender.m` (the 260512-egv/eu2 chained-WBM regression guard — proves no dangling-closure regression)
   - `tests/test_dashboard_time_sync_all_pages.m` (multi-page sweep)
3. MISS_HIT clean on all 5 edited files + the new test: `mh_style` + `mh_lint` report no new findings (`mcp__matlab__check_matlab_code` on each).
4. Live demo smoke (orchestrator, on `demo/industrial_plant/run_demo.m`):
   - Two FastSense widgets on the active page, click X on both -> hovering one mirrors the crosshair + per-series datatip onto the other at the same x; cursor leave hides both.
   - Click X off on one -> it stops mirroring/receiving; the other keeps its own hover.
   - Top-toolbar Reset, then re-hover -> mirroring still works (re-wire after rerender).
   - Drag-resize the figure -> X stays anchored left of V/A; mirroring still works.
   - Switch page (multi-page demo) -> link set scoped to the now-active page; previous page's widgets dropped.
   - Open an existing v3.0 serialized dashboard -> all widgets unlinked, behaviour + JSON identical.
</verification>

<success_criteria>
- FastSenseWidget.CrosshairLinked (public, default false) + setCrosshairLink(tf) + toStruct (omit when false) + fromStruct (restore when present). Legacy dashboards load unchanged with identical JSON.
- HoverCrosshair.onMove broadcasts data-x via BroadcastFcn_ exactly once; onMoveExternal mirrors without re-broadcasting; onLeave honors a suppress-leave tic-window so a mirrored peer is not hidden by its own same-dispatch onLeave; onLeaveExternal hides cleanly. ZERO new figure WindowButtonMotionFcn closures.
- DashboardEngine derives the active-page link set from CrosshairLinked over flattened active-page widgets (GroupWidget children included), broadcasts hover-x to all OTHER linked widgets, and re-primes broadcast hooks after rerenderWidgets / switchPage / detachWidget.
- An 'X' toggle on the WidgetButtonBar (leftmost chrome button) flips the flag, highlights when linked, re-anchors on resize, survives Reset, and is protected from clearPanelControls sweeps.
- tests/test_fastsense_crosshair_link.m: >=8 cases incl. the suppress-leave unit proof + a 2-widget mirror integration proof + a pure collectLinkedCrosshairs_ enumeration test (with a GroupWidget-nested case). Existing hover + V/A/L + TRS-reinstall + multi-page tests stay green.
- All errors namespaced (FastSenseWidget:* / DashboardLayout:* / DashboardEngine:*); MISS_HIT clean; MATLAB+Octave-safe (render paths gated, pure paths run everywhere).
</success_criteria>

<output>
After completion, create `.planning/quick/260602-mri-add-crosshair-link-toggle-to-fastsense-w/260602-mri-SUMMARY.md`.
Record: the locked design decisions (D-01..D-07), files changed with LOC deltas, the suppress-leave mechanism explanation, test results (filled in by the orchestrator's live MATLAB run), and any deferred items (e.g. detached-mirror crosshair-link parity is OUT OF SCOPE — DetachedMirror uses a figure-level FastSenseToolbar, not a WidgetButtonBar, matching the 260513-sfp detached-V/A/L precedent).
</output>
