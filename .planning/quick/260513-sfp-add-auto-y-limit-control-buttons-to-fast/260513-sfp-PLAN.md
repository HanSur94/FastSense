---
phase: 260513-sfp
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - libs/Dashboard/FastSenseWidget.m
  - libs/Dashboard/DashboardLayout.m
  - tests/test_fastsense_widget_ylimit_modes.m
autonomous: false   # ends with a human-verify checkpoint on the live dashboard
requirements:
  - SFP-01   # Y-limit-mode property on FastSenseWidget (auto-visible / auto-all / locked)
  - SFP-02   # 3 buttons rendered on the WidgetButtonBar for FastSenseWidget tiles
  - SFP-03   # Button clicks update YLimitMode and apply Y limits without full rerender
  - SFP-04   # Backward-compat: existing dashboards (no YLimitMode in JSON) behave as before
  - SFP-05   # Resize / SizeChangedFcn re-anchors the new buttons alongside Info/Detach

must_haves:
  truths:
    - "FastSenseWidget exposes a YLimitMode property with values 'auto-visible' | 'auto-all' | 'locked' and default 'auto-visible'"
    - "Three buttons appear on the WidgetButtonBar of every FastSenseWidget tile (left of the existing Info/Detach buttons)"
    - "Clicking the auto-visible button rescales Y to data inside the current X window"
    - "Clicking the auto-all button rescales Y to data across the full tag range, ignoring current X window"
    - "Clicking the locked button freezes the current Y limits; subsequent live ticks do not rescale Y"
    - "The active mode's button shows a distinct (pressed/highlighted) background; the other two are unpressed"
    - "Existing dashboards (no YLimitMode in JSON) load and behave exactly as before"
    - "Other widget types (NumberWidget, StatusWidget, GroupWidget, etc.) do NOT get these buttons"
    - "Widget panel resize keeps the three buttons anchored next to Info/Detach without overlap"
  artifacts:
    - path: "libs/Dashboard/FastSenseWidget.m"
      provides: "YLimitMode property, setYLimitMode public method, mode-dispatching autoScaleY_, toStruct/fromStruct round-trip for YLimitMode"
      contains: "YLimitMode"
    - path: "libs/Dashboard/DashboardLayout.m"
      provides: "addYLimitButtons_ private helper, reflowChrome_ updated to re-anchor YLimit buttons"
      contains: "addYLimitButtons_"
    - path: "tests/test_fastsense_widget_ylimit_modes.m"
      provides: "Function-style test of all three modes + backward-compat default + UserZoomedY clear-on-click"
      contains: "test_fastsense_widget_ylimit_modes"
  key_links:
    - from: "DashboardLayout.realizeWidget"
      to: "addYLimitButtons_"
      via: "duck-typed check (ismethod(widget, 'setYLimitMode'))"
      pattern: "addYLimitButtons_\\(widget\\)"
    - from: "WidgetButtonBar uicontrol callbacks"
      to: "FastSenseWidget.setYLimitMode"
      via: "@(~,~) widget.setYLimitMode('auto-visible'|'auto-all'|'locked')"
      pattern: "setYLimitMode\\('"
    - from: "FastSenseWidget.setYLimitMode"
      to: "autoScaleY_"
      via: "explicit click clears UserZoomedY, then re-dispatches autoScaleY_(y)"
      pattern: "UserZoomedY\\s*=\\s*false"
    - from: "DashboardLayout.reflowChrome_"
      to: "YLimitVisibleBtn / YLimitAllBtn / YLimitLockBtn"
      via: "findobj on bar with new Tags; re-anchor positions on cell resize"
      pattern: "YLimit(Visible|All|Lock)Btn"
---

<objective>
Add a small mutually-exclusive 3-button control group to the WidgetButtonBar (the per-widget grey strip) of every FastSenseWidget tile, exposing Y-axis-limit control modes the user can toggle without dropping out of the dashboard. Behaviour:

- **Auto-fit visible (default)** — rescale Y to cover data inside the current X window (the new mode-routed equivalent of today's autoScaleY_)
- **Auto-fit all** — rescale Y to cover ALL Y data the underlying Tag exposes (regardless of current X window) plus thresholds
- **Locked** — freeze the current Y limits; live ticks do not rescale Y

Purpose: MATLAB engineers want quick Y-limit control inline on the tile without having to detach or pin YLimits in the dashboard script. Lives on the WidgetButtonBar (next to the existing Info / Detach controls) so it's discoverable on every chart tile.

Output:
- New `YLimitMode` public property + `setYLimitMode` method on `FastSenseWidget`
- New `addYLimitButtons_` helper on `DashboardLayout` (and `reflowChrome_` re-anchor support)
- New function-style test file `tests/test_fastsense_widget_ylimit_modes.m`
- Updated `toStruct/fromStruct` round-trip so serialized YLimitMode survives detach + JSON save/load
- Default value `'auto-visible'` reproduces the existing on-tile Y autoscale behaviour, so dashboards built before this change behave identically
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@libs/Dashboard/FastSenseWidget.m
@libs/Dashboard/DashboardLayout.m
@libs/Dashboard/DashboardWidget.m
@libs/Dashboard/DetachedMirror.m
@libs/FastSense/FastSenseToolbar.m
@tests/test_fastsense_follow_toggle.m
@tests/test_fastsense_widget_tag.m

<interfaces>
<!--
  Extracted contracts the executor needs. No codebase exploration required.
  Look HERE first when wiring buttons / callbacks.
-->

From `libs/Dashboard/FastSenseWidget.m` (existing — DO NOT regress):
```matlab
% Public properties already on the widget:
%   YLimits             = []      % EXPLICIT user pin — when non-empty, autoScaleY_ no-ops.
%                                   YLimitMode MUST yield to a non-empty YLimits
%                                   (backward compat with dashboards that pin Y).
%   LiveViewMode = 'preserve'     % Forwarded to FastSenseObj.LiveViewMode on render.
%                                   When inner FastSense.LiveViewMode == 'follow',
%                                   autoScaleY_ already short-circuits (260513-ovt).
%                                   That existing guard stays; YLimitMode adds an
%                                   orthogonal axis ('locked' also short-circuits).
%
% Private state already on the widget:
%   UserZoomedY  = false   % Latched true when user mouse-zooms Y.
%   IsSettingYLim= false   % Guard so autoScaleY_'s own set(ax,'YLim',...) does
%                            NOT trip onYLimChanged into latching UserZoomedY.
%
% Existing method (will be REFACTORED, not removed):
%   autoScaleY_(obj, y)   % Today: rescales to min/max of y + thresholds.
%                         % After this plan: dispatches on YLimitMode:
%                         %   'auto-visible' -> existing behaviour (use y arg as-is)
%                         %   'auto-all'     -> fetch full y from obj.Tag.getXY()
%                         %                     (ignore the y arg)
%                         %   'locked'       -> no-op
%   onYLimChanged(obj)    % YLim PostSet listener; latches UserZoomedY when
%                            change source != IsSettingYLim.
%
% toStruct(obj) already emits s.yLimits when YLimits non-empty.
% fromStruct(s) already reads s.yLimits.
% Both must be extended with s.yLimitMode round-trip in this plan.
```

From `libs/Dashboard/DashboardLayout.m` (existing helpers — pattern to mirror):
```matlab
% --- realizeWidget (line ~337) — entry point for per-widget chrome
%   if needsBar
%       obj.getOrCreateButtonBar_(widget);
%       contentPanel = obj.createContentPanel_(widget);
%       widget.render(contentPanel);
%       if ~isempty(widget.Description),  obj.addInfoIcon(widget);    end
%       if ~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget'),
%                                         obj.addDetachButton(widget); end
%   end
%
% --- getOrCreateButtonBar_(widget)  -> returns the bar uipanel
%       (Tag='WidgetButtonBar', 28px tall, full-width, inset 2px)
%
% --- addInfoIcon(widget)
%       Right-anchored at `xInfo = barPos(3) - 28 - 28 - 4` (Tag='InfoIconButton', 24x24)
% --- addDetachButton(widget)
%       Right-anchored at `xDet  = barPos(3) - 24 - 4`     (Tag='DetachButton',   24x24)
%
% --- reflowChrome_(hCell, barH, inset)  -- STATIC -- SizeChangedFcn handler
%   findobj on Tags 'DetachButton', 'InfoIconButton' and re-anchors to barW-relative
%   positions. Must be extended to also re-anchor YLimitVisibleBtn / YLimitAllBtn /
%   YLimitLockBtn (Tags below).
```

Right-anchor layout AFTER this plan (left to right inside the bar, from far left of the cluster):
```
[ YLimit-Visible ][ YLimit-All ][ YLimit-Lock ]   ...gap...   [ Info ][ Detach ]
       24             24              24                         24       24
```
With a 4 px gap between the YLimit cluster and the existing Info/Detach cluster.

Exact pixel positions inside the bar (barW = bar uipanel Position(3)):
- Detach:            x = barW - 24 - 4                          (UNCHANGED)
- Info:              x = barW - 24 - 24 - 4 - 4                 (UNCHANGED; preserves the 4px gap reflowChrome_ already uses)
- YLimit-Lock:       x = barW - 24 - 24 - 4 - 4 - 4 - 24       (NEW)
- YLimit-All:        x = barW - 24 - 24 - 4 - 4 - 4 - 24 - 24  (NEW)
- YLimit-Visible:    x = barW - 24 - 24 - 4 - 4 - 4 - 24 - 24 - 24 (NEW)
(Y offset = 2 for every button, height = 24, matching Info/Detach.)

NOTE: addInfoIcon already uses `barW - 28 - 28 - 4` (a typo from earlier work that
treats button width as 28). For this plan, use 24+24+4 spacing for the new buttons.
Do NOT "fix" the Info button — that is OUT OF SCOPE.

From `libs/Dashboard/DetachedMirror.m`:
```matlab
% DetachedMirror.render() parents the cloned widget into a full-figure panel
% (no WidgetButtonBar — that's a DashboardLayout concept). The detached mirror
% relies on the figure-level FastSenseToolbar for chrome. ADDING YLIMIT BUTTONS
% TO THE FIGURE-LEVEL TOOLBAR IS OUT OF SCOPE FOR THIS QUICK TASK.
%
% Verification: in the detached figure, the user already has standard MATLAB
% axes-toolbar zoom controls + the FastSenseToolbar's Follow/Live buttons.
% That's enough for v1. We surface this trade-off in the verification checkpoint.
```

Button glyphs (ASCII, since the codebase uses ASCII strings for Info='i' and Detach='^'):
- YLimit-Visible:  `'V'`   (TooltipString: 'Auto-fit Y to visible X range')
- YLimit-All:      `'A'`   (TooltipString: 'Auto-fit Y to all data')
- YLimit-Lock:     `'L'`   (TooltipString: 'Lock Y limits (no rescale on live tick)')

NOTE: choose ASCII because the existing buttons use ASCII strings ('i', '^') and
Octave's font rendering on Linux for unicode glyphs in `String` is inconsistent
across versions; the existing widget toolbar deliberately avoids unicode.

Active-mode visual state:
- Active button:    `BackgroundColor = theme.PressedBg`  if the theme defines it,
                    else `BackgroundColor = theme.SelectedBg`  if defined,
                    else `BackgroundColor = theme.AccentColor` if defined,
                    else fall back to brightening `theme.ToolbarBackground` by 0.15
                    via `min(theme.ToolbarBackground + 0.15, 1)`.
- Inactive buttons: `BackgroundColor = theme.ToolbarBackground` (matches Info/Detach).

(Pick the first theme field that exists; do NOT add new theme fields in this quick task.)

</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Add YLimitMode property + setYLimitMode method + mode-dispatching autoScaleY_ on FastSenseWidget, with tests</name>
  <files>libs/Dashboard/FastSenseWidget.m, tests/test_fastsense_widget_ylimit_modes.m</files>

  <behavior>
    Tests in tests/test_fastsense_widget_ylimit_modes.m must cover (function-style,
    one nested function per case, follow the test_fastsense_follow_toggle.m shape):

    - test_default_y_limit_mode_is_auto_visible:
        w = FastSenseWidget('Tag', sensorTag);
        assert(strcmp(w.YLimitMode, 'auto-visible'))
    - test_set_y_limit_mode_validates:
        w.setYLimitMode('bogus') must error with id 'FastSenseWidget:invalidYLimitMode'
    - test_set_y_limit_mode_visible_rescales_to_window:
        Render widget on a tag with a synthetic step (y in [0,10] for x<5, y in [0,100] for x>=5).
        Pan XLim to [0, 4] (only the [0,10] half visible).
        w.setYLimitMode('auto-visible'); assert(YLim covers ~[0,10] +/- padding, NOT [0,100]).
    - test_set_y_limit_mode_all_rescales_to_full_data:
        Same synthetic tag and panned XLim as above.
        w.setYLimitMode('auto-all'); assert(YLim covers ~[0,100] +/- padding, regardless of XLim).
    - test_set_y_limit_mode_locked_freezes_y:
        Render and grab YLim Y0 = get(ax,'YLim').
        w.setYLimitMode('locked'); call w.update() (or w.autoScaleY_(newY) directly) with
        new y data that would have rescaled in 'auto-visible' mode.
        assert(isequal(get(ax,'YLim'), Y0))
    - test_set_y_limit_mode_clears_user_zoomed_y:
        Render widget; manually set obj.UserZoomedY = true (latch as if user mouse-zoomed).
        Call w.setYLimitMode('auto-visible'); assert(obj.UserZoomedY == false)
        AND assert YLim is the auto-fit value (i.e. explicit click re-engages autoscale).
    - test_y_limits_pin_wins_over_y_limit_mode:
        w = FastSenseWidget('Tag', sensorTag, 'YLimits', [0 1000]);
        w.setYLimitMode('auto-visible');
        Render; YLim must still be exactly [0 1000] (the explicit pin wins).
    - test_to_struct_from_struct_round_trips_y_limit_mode:
        w1.setYLimitMode('locked'); s = w1.toStruct();
        w2 = FastSenseWidget.fromStruct(s); assert(strcmp(w2.YLimitMode, 'locked'))
    - test_legacy_struct_without_y_limit_mode_defaults_to_auto_visible:
        s = struct('type','fastsense','title','t','position',struct('col',1,'row',1,'width',6,'height',2));
        w = FastSenseWidget.fromStruct(s); assert(strcmp(w.YLimitMode, 'auto-visible'))
    - test_follow_mode_still_short_circuits_autoscale:
        260513-ovt regression guard. With FastSenseObj.LiveViewMode='follow' AND
        YLimitMode='auto-visible', a refresh()/autoScaleY_ call must NOT rescale Y.
        (The Follow toggle's explicit "freeze view in X+Y" intent still wins.)

    All tests must:
    - Begin with `addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();`
    - Wrap each case in try/catch and increment nPassed/nFailed counters
    - Close all figures via `cleanupAll = onCleanup(@() close('all','force'))`
    - Print `All N tests passed.` on success
    - Skip gracefully on headless (`if ~usejava('desktop') ... return; end`) if and only if
      uipanel rendering is required — most cases can run headless via offscreen figure.
  </behavior>

  <action>
    Edit libs/Dashboard/FastSenseWidget.m:

    1. Add to the public `properties (Access = public)` block, immediately after `LiveViewMode`:
       ```matlab
       % YLimitMode — Y-axis rescale strategy applied by autoScaleY_:
       %   'auto-visible' (DEFAULT) — rescale to cover data inside the current X
       %                              window. Reproduces the pre-260513-sfp behaviour
       %                              (so old dashboards behave identically).
       %   'auto-all'              — rescale to cover ALL data the bound Tag exposes,
       %                              regardless of current XLim. Equivalent to a
       %                              global "fit Y to the whole timeline" command.
       %   'locked'                — freeze current YLim. Live ticks / refresh /
       %                              update no longer call set(ax,'YLim', ...).
       %
       % Always yields to a non-empty `YLimits` pin (explicit numeric pin wins).
       % Always yields to `FastSenseObj.LiveViewMode == 'follow'` (Follow toggle wins;
       % 260513-ovt).
       YLimitMode = 'auto-visible'
       ```

    2. Add a new public method `setYLimitMode(obj, mode)` near `setEventMarkersVisible`:
       - Validate mode is one of `{'auto-visible','auto-all','locked'}`; else
         `error('FastSenseWidget:invalidYLimitMode', ...)`.
       - Persist `obj.YLimitMode = mode`.
       - **Clear `obj.UserZoomedY = false`** (explicit click re-engages autoscale).
       - If FastSenseObj is rendered, fetch y data appropriate for the new mode
         and call `obj.autoScaleY_(y)`:
           - 'auto-visible': `y = obj.getYInVisibleXWindow_()` (new private helper, below)
           - 'auto-all':     `[~, y] = obj.Tag.getXY()`  (fall back to obj.YData
                             when no Tag bound)
           - 'locked':       call `obj.autoScaleY_([])` — the autoScaleY_ refactor
                             (next step) treats 'locked' mode as a no-op regardless
                             of the y argument.

    3. Refactor `autoScaleY_(obj, y)` to dispatch on `obj.YLimitMode`:
       - Keep the early-return guards in order: `~isempty(YLimits)` -> return;
         `UserZoomedY` -> return; `FastSenseObj.LiveViewMode == 'follow'` -> return;
         not-rendered / no-axes -> return.
       - After those guards, dispatch:
         - `case 'locked'`: return (no rescale).
         - `case 'auto-all'`: replace `y` with full data from `obj.Tag.getXY()`
           (or fall back to `obj.YData` for inline-bound widgets); then run the
           existing min/max/threshold/pad code path against the FULL y.
         - `case 'auto-visible'` (or default): use the `y` argument as-is
           (existing behaviour). Filter `y` to the current XLim window when
           possible: get current XLim from `obj.FastSenseObj.hAxes`, then
           `mask = x >= xl(1) & x <= xl(2); yWin = y(mask);` — but ONLY do this
           if the caller passed BOTH x and y. To avoid changing the function
           signature, extract a small private helper `getYInVisibleXWindow_()`
           that performs the filtering using `obj.Tag.getXY()` directly, and have
           refresh()/update() pass the windowed y into autoScaleY_ when YLimitMode
           == 'auto-visible' (or simply call `obj.getYInVisibleXWindow_()` once at
           the start of autoScaleY_ when mode is auto-visible AND y is "all data"
           — implementation detail: do whichever is simpler without changing
           refresh/update call sites).
       - The threshold-extension code (yMin = min(yMin, threshold.Value), etc.) and
         padding logic stays as today.

    4. Add private helper `getYInVisibleXWindow_(obj)` to the `methods (Access = private)`
       block that returns the y values whose x falls inside the current
       FastSenseObj.hAxes XLim window. Falls back to `obj.Tag.getXY()`'s full y when
       XLim is unavailable.

    5. Extend `toStruct(obj)` to emit `s.yLimitMode` only when `YLimitMode != 'auto-visible'`
       (so we don't write the default into every serialized dashboard — keeps JSON small
       AND keeps old-dashboard diffs invisible).

    6. Extend the `fromStruct(s)` static to read `s.yLimitMode` when present, otherwise
       leave the default 'auto-visible' in place.

    7. **Defensive: do NOT change the public signature of autoScaleY_** — it stays
       `autoScaleY_(obj, y)`. Existing callers (`render`, `rebuildForTag_`) keep working
       unchanged. The new dispatch is purely internal.

    Implementation notes for the executor:
    - Match existing naming conventions: properties PascalCase (`YLimitMode`), public
      methods camelCase (`setYLimitMode`), private helpers trailing-underscore camelCase
      (`getYInVisibleXWindow_`). Error IDs namespaced `FastSenseWidget:*`.
    - All new code stays toolbox-free. No `validatestring` if Octave compatibility is
      shaky — use an explicit `if ~ismember(mode, {...}) error(...); end`.
    - Run `mh_style` / `mh_lint` mentally — keep lines <= 160 chars, 4-space indent.
    - Comments must explain the WHY (interaction with YLimits / LiveViewMode / UserZoomedY),
      not just the WHAT.

    Then create tests/test_fastsense_widget_ylimit_modes.m following the
    test_fastsense_follow_toggle.m shape (see <behavior> for the cases).
  </action>

  <verify>
    <automated>
      Run the new test file via mcp__matlab__run_matlab_test_file:
        tests/test_fastsense_widget_ylimit_modes.m
      Expected: prints "All N tests passed." where N = number of cases above (>= 9).

      Then run two regression suites to confirm no breakage:
        tests/test_fastsense_follow_toggle.m  -> expect 10/10 pass
        tests/test_fastsense_widget_tag.m     -> expect all pass (8 cases)
    </automated>
  </verify>

  <done>
    - FastSenseWidget.YLimitMode property exists with default 'auto-visible'
    - setYLimitMode(mode) validates and updates the property AND clears UserZoomedY
    - autoScaleY_ dispatches correctly:
        - 'auto-visible': rescales to current X window (regression of old behaviour)
        - 'auto-all'   : rescales to full tag data
        - 'locked'     : no-op
    - YLimits pin (non-empty) wins over YLimitMode
    - Follow mode (LiveViewMode=='follow') still short-circuits autoScaleY_
    - toStruct/fromStruct round-trips YLimitMode
    - Old serialized dashboards (no yLimitMode key) default to 'auto-visible'
    - tests/test_fastsense_widget_ylimit_modes.m passes all cases (>= 9)
    - tests/test_fastsense_follow_toggle.m passes (10/10) — no 260513-ovt regression
    - tests/test_fastsense_widget_tag.m passes — no widget-tag-binding regression
  </done>
</task>

<task type="auto">
  <name>Task 2: Add 3-button YLimit cluster to WidgetButtonBar via DashboardLayout.addYLimitButtons_</name>
  <files>libs/Dashboard/DashboardLayout.m</files>

  <action>
    Edit libs/Dashboard/DashboardLayout.m:

    1. In `realizeWidget` (~line 366, inside the `if needsBar` block), AFTER the
       existing `addInfoIcon` / `addDetachButton` calls, add a duck-typed inject:

       ```matlab
       % 260513-sfp — per-widget Y-limit-mode buttons (only widgets that
       % implement setYLimitMode get this cluster; today that is FastSenseWidget
       % but the duck-type check keeps the chrome generic for any future widget
       % that exposes Y-rescale modes).
       if ismethod(widget, 'setYLimitMode')
           obj.addYLimitButtons_(widget);
       end
       ```

       IMPORTANT: this MUST run inside the `needsBar` branch only — when a widget
       skips chrome (no Description AND no DetachCallback) we have no bar to host
       these buttons either. That's acceptable for v1 because every dashboard that
       loads FastSenseWidget through DashboardEngine sets a DetachCallback, so
       `needsBar` is always true for FastSenseWidget in practice.

    2. Update the `needsBar` check (~line 363) to ALSO consider widgets that
       expose setYLimitMode, so a dashboard that someday omits DetachCallback
       still gets a bar for the YLimit buttons:

       ```matlab
       needsBar = ~isempty(widget.Description) || ...
                  (~isempty(obj.DetachCallback) && ~isa(widget, 'DividerWidget')) || ...
                  ismethod(widget, 'setYLimitMode');
       ```

    3. Add private method `addYLimitButtons_(obj, widget)` next to `addDetachButton`,
       mirroring the addInfoIcon shape. Pseudocode:

       ```matlab
       function addYLimitButtons_(obj, widget)
           %ADDYLIMITBUTTONS_ Inject the 3-button Y-limit-mode cluster into the bar.
           %   Only invoked from realizeWidget when ismethod(widget,'setYLimitMode').
           %   Buttons are left-anchored relative to the EXISTING right-anchored
           %   Info/Detach buttons (with a 4-px gap between the clusters).
           if isempty(widget.ParentTheme) || ~isstruct(widget.ParentTheme)
               theme = DashboardTheme('light');
           else
               theme = widget.ParentTheme;
           end
           bar = obj.getOrCreateButtonBar_(widget);
           barPos = get(bar, 'Position');
           barW = barPos(3);

           % Layout: [V][A][L]  ... 4px gap ...  [Info][Detach]
           bw   = 24;
           gap  = 4;
           xLock    = barW - bw - gap - bw - gap - gap - bw;          % Lock leftmost in cluster's right side
           xAll     = xLock - bw;
           xVisible = xAll  - bw;

           % Compute active / inactive backgrounds (see <interfaces>):
           activeBg = chooseActiveBg_(theme);

           obj.addYLimitButton_(bar, widget, 'auto-visible', xVisible, 'V', ...
               'Auto-fit Y to visible X range', activeBg, theme, ...
               'YLimitVisibleBtn');
           obj.addYLimitButton_(bar, widget, 'auto-all',     xAll,     'A', ...
               'Auto-fit Y to all data',         activeBg, theme, ...
               'YLimitAllBtn');
           obj.addYLimitButton_(bar, widget, 'locked',       xLock,    'L', ...
               'Lock Y limits (no rescale)',     activeBg, theme, ...
               'YLimitLockBtn');

           % Persist the active-bg + per-button tags on the bar's UserData so
           % reflowChrome_ can re-anchor + restyle without re-resolving the theme.
           ud = get(bar, 'UserData');
           if ~isstruct(ud), ud = struct(); end
           ud.YLimitActiveBg = activeBg;
           ud.YLimitWidget   = widget;        % weak ref — invalidated by widget delete
           set(bar, 'UserData', ud);

           % Initial pressed state: highlight the button matching widget.YLimitMode.
           obj.syncYLimitButtonsState_(bar, widget.YLimitMode);
       end
       ```

       Helper `addYLimitButton_(bar, widget, mode, x, glyph, tip, activeBg, theme, tag)`:
       creates a uicontrol pushbutton on `bar` with Tag=tag, String=glyph, the standard
       size [x 2 24 24], `Callback = @(~,~) onYLimitButtonClicked_(obj, widget, mode, bar)`.

       Helper `onYLimitButtonClicked_(obj, widget, mode, bar)`:
       - Call `widget.setYLimitMode(mode)` (this clears UserZoomedY and applies Y).
       - Call `obj.syncYLimitButtonsState_(bar, mode)` to update visual pressed state.
       - Wrap in try/catch; on failure, `warning('DashboardLayout:yLimitClickFailed', ...)`.

       Helper `syncYLimitButtonsState_(bar, mode)`:
       - For each Tag in {'YLimitVisibleBtn','YLimitAllBtn','YLimitLockBtn'}:
         - findobj on bar; if its mode matches `mode`, set BackgroundColor to activeBg
           (read from `get(bar,'UserData').YLimitActiveBg`).
         - Else set BackgroundColor to `theme.ToolbarBackground`
           (resolve theme via the bar's parent->widget chain, or stash on UserData too).

       Local nested function `chooseActiveBg_(theme)`:
       - Try fields in order: 'PressedBg', 'SelectedBg', 'AccentColor'.
       - Fallback: `min(theme.ToolbarBackground + 0.15, 1)` per-channel.

    4. Update `reflowChrome_` (~line 754) — the static SizeChangedFcn handler — to
       also re-anchor the three new buttons. Inside the existing
       `if ~isempty(bar) && ishandle(bar(1))` block, after the Info / Detach
       re-anchor lines, add:

       ```matlab
       bw  = 24; gap = 4;
       lockBtn    = findobj(bar(1), 'Tag', 'YLimitLockBtn',    '-depth', 1);
       allBtn     = findobj(bar(1), 'Tag', 'YLimitAllBtn',     '-depth', 1);
       visibleBtn = findobj(bar(1), 'Tag', 'YLimitVisibleBtn', '-depth', 1);
       xLock    = barW - bw - gap - bw - gap - gap - bw;
       xAll     = xLock - bw;
       xVisible = xAll  - bw;
       if ~isempty(lockBtn)    && ishandle(lockBtn(1)),
           set(lockBtn(1),    'Position', [xLock,    2, bw, bw]);
       end
       if ~isempty(allBtn)     && ishandle(allBtn(1)),
           set(allBtn(1),     'Position', [xAll,     2, bw, bw]);
       end
       if ~isempty(visibleBtn) && ishandle(visibleBtn(1)),
           set(visibleBtn(1), 'Position', [xVisible, 2, bw, bw]);
       end
       ```

    5. Extend the `protectedTags` cell array in `DashboardWidget.clearPanelControls`
       (libs/Dashboard/DashboardWidget.m) to preserve the new button tags during
       any uicontrol sweep:
       ```matlab
       protectedTags = {'InfoIconButton', 'DetachButton', 'WidgetButtonBar', ...
                        'YLimitVisibleBtn', 'YLimitAllBtn', 'YLimitLockBtn'};
       ```
       (This is the ONLY edit to DashboardWidget.m. Add this file to files_modified
       for THIS task if not already in the frontmatter at the plan level.)

    Implementation notes:
    - DO NOT modify `addInfoIcon` or `addDetachButton` — they stay byte-identical.
    - DO NOT add new theme fields — fall back via chooseActiveBg_'s lookup chain.
    - DO NOT add the cluster to `DetachedMirror` — out of scope.
    - The duck-type check (`ismethod(widget, 'setYLimitMode')`) lets future widgets
      opt in without modifying DashboardLayout.
  </action>

  <verify>
    <automated>
      Run the test from Task 1 again — it must still pass unchanged:
        tests/test_fastsense_widget_ylimit_modes.m

      Plus a smoke check via mcp__matlab__evaluate_matlab_code:
        ```matlab
        install();
        figVis = false;
        try, figVis = usejava('desktop'); catch, end
        if figVis
            % Build a 1-widget dashboard with a FastSenseWidget and assert the
            % three buttons exist on its WidgetButtonBar.
            x = (1:1000)'; y = sin(x/50)';
            tag = SensorTag('Name','Sm', 'Key','sm', 'XData', x, 'YData', y);
            w = FastSenseWidget('Tag', tag, 'Title', 'Sm', 'Description', 'demo');
            d = DashboardEngine('Widgets', {w}, 'Title', 'sfp-smoke');
            d.render();
            bar = findobj(w.hCellPanel, 'Tag', 'WidgetButtonBar', '-depth', 1);
            assert(~isempty(findobj(bar, 'Tag', 'YLimitVisibleBtn')), 'V button missing');
            assert(~isempty(findobj(bar, 'Tag', 'YLimitAllBtn')),     'A button missing');
            assert(~isempty(findobj(bar, 'Tag', 'YLimitLockBtn')),    'L button missing');
            fprintf('smoke OK\n');
            close(d.hFigure);
        else
            fprintf('smoke skipped (no desktop)\n');
        end
        ```

      Plus regression: tests/test_dashboard_time_sync_all_pages.m must still pass
      (the WidgetButtonBar chrome is exercised on multi-page dashboards), and
      tests/test_dashboard_range_selector_integration.m must still pass.
    </automated>
  </verify>

  <done>
    - DashboardLayout.addYLimitButtons_ exists and is private
    - realizeWidget invokes it when ismethod(widget,'setYLimitMode'), inside the needsBar branch
    - needsBar additionally returns true for widgets exposing setYLimitMode
    - Three 24x24 uicontrol pushbuttons (Tags YLimitVisibleBtn / YLimitAllBtn / YLimitLockBtn)
      render on the WidgetButtonBar of every FastSenseWidget tile
    - Buttons are left-anchored relative to Info/Detach with a 4px gap; do not overlap
    - Clicking a button calls widget.setYLimitMode(mode) AND visually highlights it
      (PressedBg / SelectedBg / AccentColor / brightened ToolbarBackground fallback)
    - reflowChrome_ re-anchors all three new buttons on cell resize
    - DashboardWidget.clearPanelControls preserves all three new tags
    - tests/test_fastsense_widget_ylimit_modes.m still passes (10+ cases)
    - tests/test_dashboard_time_sync_all_pages.m passes (5/5)
    - tests/test_dashboard_range_selector_integration.m passes (2/2)
    - Smoke evaluate confirms the three buttons exist on a live demo dashboard
  </done>
</task>

<task type="checkpoint:human-verify" gate="blocking">
  <what-built>
    Three small buttons (V / A / L) on the grey WidgetButtonBar of every FastSenseWidget
    tile, left of the existing Info ('i') and Detach ('^') buttons.

    - **V** — auto-fit Y to data inside the visible X window (default mode)
    - **A** — auto-fit Y to all data exposed by the bound Tag
    - **L** — lock current Y limits (no further rescale on live tick)

    The active mode is visually highlighted (pressed-style background). The buttons
    re-anchor correctly on widget panel resize. Backward compat: existing dashboards
    (no `YLimitMode` in JSON) behave exactly as before — they default to auto-visible.

    OUT OF SCOPE for this quick task:
    - Adding the cluster to detached-mirror windows (DetachedMirror uses its own
      figure-level FastSenseToolbar; can be a follow-up)
    - Adding a "Symmetric zero" 4th mode
    - Adding the cluster to NumberWidget / StatusWidget / etc. — these don't have
      a setYLimitMode method, so the duck-type check excludes them by design
  </what-built>

  <how-to-verify>
    Run the industrial-plant demo:
      ```matlab
      install();
      demo/industrial_plant/run_demo
      ```

    On any FastSenseWidget tile (e.g. reactor.pressure), the grey strip across the
    top should now show, from left to right: [V][A][L] ... gap ... [i][^]

    Test the modes:

    1. **Default state** — open the demo. Without clicking anything, the V button
       should be pressed/highlighted. The Y axis should auto-scale to data inside
       the current X window as before. (Backward-compat regression check.)

    2. **Auto-fit visible (V)** — pan/zoom the X axis so only a narrow window is
       visible. Click V. Y should snap to fit just that window's data + padding.

    3. **Auto-fit all (A)** — click A. Y should expand to cover the FULL Y range
       of the underlying tag (regardless of current X zoom). Useful for putting
       a value-spike in context.

    4. **Locked (L)** — set a Y range via V or A, then click L. The L button should
       press in. Let live mode tick for ~30 seconds (start Live from the dashboard
       toolbar). The Y limits should NOT rescale even when new data falls outside
       the current Y range. Click V to unlock.

    5. **User mouse-zoom override** — while in V mode, scroll-wheel zoom the Y axis.
       The V button stays visually pressed but autoScale stops (because UserZoomedY
       latched). Click V again — autoScaleY_ re-engages (UserZoomedY cleared on click).

    6. **Resize** — drag the figure window edge. The three buttons should stay
       anchored to the right side of the bar (alongside Info/Detach) without
       overlapping each other.

    7. **Detach** — click the ^ button on a tile. The detached mirror window opens.
       The mirror does NOT need to show these buttons (out of scope, see above).
       Verify nothing crashes and the detached widget still updates on live tick.

    8. **Backward compat** — open an older dashboard (any v3.0 demo). All tiles
       should behave as before. The V mode should be active by default.

    Run tests one more time to be sure:
      ```matlab
      cd tests
      run_matlab_test_file('test_fastsense_widget_ylimit_modes.m');
      run_matlab_test_file('test_fastsense_follow_toggle.m');
      run_matlab_test_file('test_dashboard_time_sync_all_pages.m');
      ```
  </how-to-verify>

  <resume-signal>
    Type "approved" if the three buttons behave as described and all regression
    tests pass, OR describe any issues (visual misalignment, mode misbehavior,
    test failures, resize bugs).
  </resume-signal>
</task>

</tasks>

<verification>
- New property `YLimitMode` exists on `FastSenseWidget` with default `'auto-visible'`
- `setYLimitMode` validates and dispatches; clears `UserZoomedY` on explicit click
- `autoScaleY_` dispatches on mode without changing its public signature
- Backward compat: explicit numeric `YLimits` pin still wins; Follow mode still wins
- Serialization round-trips `YLimitMode`; legacy dashboards default to `'auto-visible'`
- Three uicontrol buttons appear on `WidgetButtonBar` for every `FastSenseWidget` tile
- Active mode button is visually highlighted; only one is active at a time
- Resize re-anchors the new buttons via `reflowChrome_`
- `DashboardWidget.clearPanelControls` protects the three new tags
- Tests pass:
    - tests/test_fastsense_widget_ylimit_modes.m (new, >= 9 cases)
    - tests/test_fastsense_follow_toggle.m (regression, 10/10)
    - tests/test_fastsense_widget_tag.m (regression)
    - tests/test_dashboard_time_sync_all_pages.m (regression, 5/5)
    - tests/test_dashboard_range_selector_integration.m (regression, 2/2)
- Manual demo verification of all 8 scenarios from the checkpoint
</verification>

<success_criteria>
1. The three buttons exist on every FastSenseWidget tile on the embedded dashboard
2. Clicking a button updates `YLimitMode` and immediately reflects on the chart's Y axis
3. The active button is highlighted, the other two are not (single-selection visual)
4. Resize preserves alignment with Info/Detach (no overlap, no gap regression)
5. Old dashboards behave identically (default mode = auto-visible reproduces pre-260513-sfp)
6. Other widget types (NumberWidget, etc.) get no YLimit buttons
7. All test files listed in verification pass
8. No new MATLAB warnings on dashboard render
</success_criteria>

<output>
After completion, create `.planning/quick/260513-sfp-add-auto-y-limit-control-buttons-to-fast/260513-sfp-SUMMARY.md`
with: change summary, file diffs (high level), test results, and explicit out-of-scope
follow-up suggestions (detached-mirror buttons, symmetric-zero mode, theme.PressedBg
token if reviewers want a proper theme field instead of fallback chain).
</output>
