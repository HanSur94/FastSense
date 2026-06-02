---
phase: 1040-companion-notification-center
plan: 03
type: execute
wave: 3
depends_on: ["02"]
files_modified:
  - libs/FastSenseCompanion/FastSenseCompanion.m
autonomous: true
requirements: []
must_haves:
  truths:
    - "A bell button sits at toolbar column 8 with an unacked-count badge; it is disabled when there is no EventStore"
    - "Clicking the bell shows/hides a 4th rightmost grid column hosting the NotificationCenterPane; existing 3 columns reflow"
    - "onLiveTick_ refreshes the notification pane (after scanLiveTagUpdates_, before the cluster block) and updates the bell badge count + severity color"
    - "The notification pane is detachable to its own uifigure via DetachRequested (mirrors the EventsLogPane detach flow)"
    - "Single-user dashboards and existing scripts run unchanged; the bell/pane add no new timer"
  artifacts:
    - path: "libs/FastSenseCompanion/FastSenseCompanion.m"
      provides: "Bell button + badge, 4th-column toggle, NotifPane_ wiring, onLiveTick_ refresh hook, detach state"
      contains: "hBellBtn_"
  key_links:
    - from: "FastSenseCompanion.onLiveTick_"
      to: "NotificationCenterPane.refresh"
      via: "inserted call after scanLiveTagUpdates_, before cluster block"
      pattern: "NotifPane_\\.refresh\\("
    - from: "FastSenseCompanion toolbar bell"
      to: "toggleNotificationCenter_ → ColumnWidth{4}"
      via: "ButtonPushedFcn"
      pattern: "ColumnWidth\\{4\\}"
    - from: "FastSenseCompanion"
      to: "NotificationCenterPane DetachRequested"
      via: "addlistener in build + setProject"
      pattern: "addlistener\\(obj\\.NotifPane_, 'DetachRequested'"
---

<objective>
Wire `NotificationCenterPane` into `FastSenseCompanion`: expand the root grid to a 4th
collapsible column, add the toolbar bell button (col 8) with an unacked-count badge, instantiate
and attach the pane, register its `DetachRequested` listener (build + setProject), implement the
show/hide column toggle and the detach-to-uifigure state, and insert the pane refresh + badge
update into the existing `onLiveTick_` loop. NO new timer.

This is the integration seam. Every change is gated so single-user/no-EventStore paths are
unaffected: the bell disables with no store, the column starts hidden (width 0), and the refresh
hook is a guarded try/catch that can never crash the timer.

Purpose: Make the inbox live inside the Companion, toggled by the bell, refreshed on the existing tick.
Output: Updated `libs/FastSenseCompanion/FastSenseCompanion.m` (integration tests land in Plan 04).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/PROJECT.md
@.planning/phases/1040-companion-notification-center/1040-CONTEXT.md
@.planning/phases/1040-companion-notification-center/1040-RESEARCH.md
@.planning/phases/1040-companion-notification-center/1040-UI-SPEC.md

<interfaces>
<!-- All line numbers verified against the live FastSenseCompanion.m on 2026-06-02. -->

Root grid construction (FastSenseCompanion.m):
```matlab
% line 299-301:
obj.hLayout_ = uigridlayout(obj.hFig_, [3 3]);
obj.hLayout_.ColumnWidth   = {220, '1x', 360};
obj.hLayout_.RowHeight     = {32, '1x', 360};
% line 310: obj.hToolbarPanel_.Layout.Column = [1 3];
% panels (~432-439):
%   hLeftPanel_  Row 2 Col 1 ; hMidPanel_ Row 2 Col 2 ; hRightPanel_ Row 2 Col 3
%   hLogPanel_   Row 3 Col [1 3]   (line 439)
```

Toolbar inner grid (lines 320-435):
```matlab
% line 323-324:
hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 9]);
hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, '1x', 36};
% buttons: Events col1, Live col2, Tags col3, PlantLog col4, Tile col5,
%          CloseAll col6, Wiki col7 (line 410), [spacer col8], Gear col9 (line 423)
% The comment block at lines 320-322 documents the 1x9 layout — update it to 1x10.
% Enable/disable rule pattern (hEventsBtn_ lines 340-343):
%   if isempty(obj.EventStore_); btn.Enable='off'; btn.Tooltip='No EventStore registered'; end
```

onLiveTick_ (line 1665):
```matlab
function onLiveTick_(obj)
    if ~obj.IsLive || isempty(obj.hFig_) || ~isvalid(obj.hFig_); return; end
    try
        obj.InspectorPane_.refreshLive();          % (a)
        obj.scanLiveTagUpdates_();                  % (b)  line 1679
        ... obj.EventsLogPane_.setLastUpdated(...); % (c)  line 1681
        if obj.IsClusterMode_                       % (d)  line 1684
            obj.pollClusterContention_();
            obj.pollShareStatus_();
        end
    catch
    end
end
```
INSERT the notification refresh + badge update AFTER (c) at ~line 1682, BEFORE the cluster block.

Pane wiring pattern (lines 482-495, build) and (lines 768-774, setProject):
```matlab
obj.EventsLogPane_ = EventsLogPane(obj.Theme_);
obj.EventsLogPane_.setCompanion(obj);
obj.Listeners_{end+1} = addlistener(obj.EventsLogPane_, 'DetachRequested', @(~,~) obj.setLogState_('events','Detached'));
```

Detach state machine to MIRROR: setLogState_(which,newState) at line 1407 — uses
uifigure(...) at 1488, pane.attach(newFig, theme), CloseRequestFcn → 'Inline'. The notification
pane is SIMPLER (no Inline/Hidden tri-state — it has the column toggle for show/hide). Implement a
focused `setNotifDetached_(tf)` that pops the pane out to a uifigure (tf=true) or re-attaches into
hNotifPanel_ (tf=false), mirroring the uifigure + CloseRequestFcn dance.

Construction idioms (verified from TestFastSenseCompanion.m lines 1088-1093):
  es  = EventStore(storePath);                      % storePath is a file path (use [tempname '.mat'])
  app = FastSenseCompanion('EventStore', es);       % Registry defaults to the TagRegistry singleton
  app.getEventStore()                                % resolved store (also drives ack + badge)
Existing Hidden test accessors live in a methods block ~line 1320-1361 (getFigForTest_ at 1330).

NotificationCenterPane public contract (Plan 02): NotificationCenterPane(theme), setCompanion(obj),
attach(parent,theme), detach(), refresh(eventStore), applyTheme(theme), requestDetach(),
events DetachRequested, IsAttached (SetAccess private). Plan 01 static helpers for the badge:
NotificationCenterPane.filterUnacked_, .maxSeverity_, .badgeText_, .badgeColor_.

EventStore for verify snippets: Event(startTime, endTime, sensorName, thresholdLabel) then set
.Severity/.IsOpen; es.append(ev) (EventStore.m:84). EventStore() needs a path → EventStore([tempname '.mat']).
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Expand root grid to 4 columns + add toolbar bell button at col 8</name>
  <read_first>
    - libs/FastSenseCompanion/FastSenseCompanion.m lines 296-445 (root grid + toolbar grid + all panel/button column assignments) and lines 340-343 (hEventsBtn_ enable/disable pattern)
    - libs/FastSenseCompanion/FastSenseCompanion.m property block lines 70-110 (declare hBellBtn_, hNotifPanel_, NotifPane_, hDetachedNotifFig_ alongside existing hEventsBtn_/hLogPanel_)
    - libs/FastSenseCompanion/FastSenseCompanion.m lines 1320-1361 (existing *ForTest_ Hidden accessors — add new ones here)
    - .planning/phases/1040-companion-notification-center/1040-UI-SPEC.md "Companion Root Grid Extension", "Companion Toolbar Grid Extension (Bell Button)", "Bell Button States"
    - .planning/phases/1040-companion-notification-center/1040-RESEARCH.md Pattern 3 (column toggle) + Pitfall 3 (build hidden-then-collapse to avoid flicker)
  </read_first>
  <files>libs/FastSenseCompanion/FastSenseCompanion.m</files>
  <action>
    Declare new private properties near the existing toolbar/panel handles (line ~70-110):
    `hBellBtn_ = []`, `hNotifPanel_ = []`, `NotifPane_ = []`, `hDetachedNotifFig_ = []`.

    ROOT GRID (line 299-301): change `uigridlayout(obj.hFig_, [3 3])` → `[3 4]`; change
    `obj.hLayout_.ColumnWidth = {220, '1x', 360}` → `{220, '1x', 360, 0}` (4th col hidden initially,
    per RESEARCH Pattern 3 + Pitfall 3). Leave RowHeight unchanged.

    PANEL SPANS: line 310 `obj.hToolbarPanel_.Layout.Column = [1 3]` → `[1 4]`. Line 439
    `obj.hLogPanel_.Layout.Column = [1 3]` → `[1 4]`. Leave hLeftPanel_(col1)/hMidPanel_(col2)/
    hRightPanel_(col3) unchanged.

    NEW NOTIFICATION PANEL: after the hLogPanel_ block (~line 440), add
    `obj.hNotifPanel_ = uipanel(obj.hLayout_); obj.hNotifPanel_.Layout.Row = 2;
    obj.hNotifPanel_.Layout.Column = 4; obj.hNotifPanel_.BorderType = 'none';
    obj.hNotifPanel_.BackgroundColor = obj.Theme_.WidgetBackground;`

    TOOLBAR GRID (line 323-324): change `[1 9]` → `[1 10]`; change ColumnWidth
    `{110, 110, 110, 130, 70, 90, 70, '1x', 36}` → `{110, 110, 110, 130, 70, 90, 70, 70, '1x', 36}`
    (bell 70 px at col 8, spacer → col 9, gear → col 10). UPDATE the documentation comment block at
    lines 320-322 to list col 8 = Bell (70), col 9 = spacer ('1x'), col 10 = Gear (36).

    GEAR SHIFT: line 423 `obj.hSettingsBtn_.Layout.Column = 9` → `= 10`.

    NEW BELL BUTTON at col 8 (insert after the Wiki button block ~line 419, before the gear):
    ```matlab
    obj.hBellBtn_ = uibutton(hToolbarGrid, 'push');
    obj.hBellBtn_.Layout.Row    = 1;
    obj.hBellBtn_.Layout.Column = 8;
    obj.hBellBtn_.Text          = obj.bellGlyph_();   % helper below: emoji or '[!]' fallback
    obj.hBellBtn_.FontSize      = 12;
    obj.hBellBtn_.FontWeight    = 'bold';
    obj.hBellBtn_.Tag           = 'CompanionBellBtn';
    obj.hBellBtn_.Tooltip       = 'Toggle notification center';
    obj.hBellBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
    obj.hBellBtn_.FontColor       = obj.Theme_.ForegroundColor;
    obj.hBellBtn_.ButtonPushedFcn = @(~,~) obj.toggleNotificationCenter_();
    if isempty(obj.EventStore_)
        obj.hBellBtn_.Enable  = 'off';
        obj.hBellBtn_.Tooltip = 'No EventStore registered';
    end
    ```

    Add a private helper `function g = bellGlyph_(~)` returning `char(128276)` (U+1F514) when
    `usejava('desktop')` is true, else `'[!]'` (RESEARCH Open Question 2 — ASCII fallback for
    headless/Windows). Wrap the usejava check in try/catch defaulting to the ASCII glyph.

    Add two Hidden test accessors in the *ForTest_ methods block (~line 1320), needed by the verify
    snippets here and in Plan 04:
    - `function cw = getRootColumnWidthForTest_(obj); cw = obj.hLayout_.ColumnWidth; end`
    - `function onLiveTickForTest_(obj); obj.onLiveTick_(); end`  (drives the tick without the timer)

    Do NOT yet implement toggleNotificationCenter_ / pane instantiation / refresh — those are Task 2.
    But because ButtonPushedFcn references toggleNotificationCenter_, add a minimal stub method
    `function toggleNotificationCenter_(obj); end` (fleshed out in Task 2) so the class parses. Keep
    the bell Enable='off' when no store. MISS_HIT clean (≤160 cols — break long lines).
  </action>
  <verify>
    <automated>mcp__matlab__evaluate_matlab_code: addpath(pwd); install(); app = FastSenseCompanion(); drawnow; f = app.getFigForTest_(); b = findall(f,'Tag','CompanionBellBtn'); assert(numel(b)==1,'bell missing'); assert(b.Layout.Column==8,'bell not col 8'); cw = app.getRootColumnWidthForTest_(); assert(numel(cw)==4 && isequal(cw{4},0),'col4 not hidden'); app.close(); disp('OK')</automated>
  </verify>
  <acceptance_criteria>
    - `grep -nE "uigridlayout\(obj.hFig_, ?\[3 4\]\)" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -n "{220, '1x', 360, 0}" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -nE "uigridlayout\(obj.hToolbarPanel_, ?\[1 10\]\)" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -n "'CompanionBellBtn'" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -n "obj.hBellBtn_.Layout.Column = 8" libs/FastSenseCompanion/FastSenseCompanion.m` matches AND `grep -n "obj.hSettingsBtn_.Layout.Column = 10" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -nE "obj.hToolbarPanel_.Layout.Column = \[1 4\]" libs/FastSenseCompanion/FastSenseCompanion.m` matches AND `grep -nE "obj.hLogPanel_.Layout.Column = \[1 4\]" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -nE "function (cw = getRootColumnWidthForTest_|onLiveTickForTest_)\(obj\)" libs/FastSenseCompanion/FastSenseCompanion.m` returns 2 matches
    - The matlab MCP snippet prints OK (bell exists at col 8, root grid has 4 columns with width{4}==0)
    - `mcp__matlab__check_matlab_code` clean; `mh_style` + `mh_lint` clean
  </acceptance_criteria>
  <done>Root grid is [3 4] with hidden 4th column; toolbar is [1 10] with bell at col 8, spacer col 9, gear col 10; hNotifPanel_ created at Row 2 Col 4; bell disabled when no EventStore; getRootColumnWidthForTest_/onLiveTickForTest_ accessors added. Companion constructs headlessly. Code Analyzer + MISS_HIT clean.</done>
</task>

<task type="auto">
  <name>Task 2: Instantiate + wire NotificationCenterPane; implement column toggle, detach state, and badge update</name>
  <read_first>
    - libs/FastSenseCompanion/FastSenseCompanion.m lines 482-495 (pane instantiation + setCompanion + addlistener DetachRequested in build) and 768-774 (re-register listeners in setProject) and 1407-1505 (setLogState_ detach-to-uifigure dance to mirror)
    - libs/FastSenseCompanion/FastSenseCompanion.m lines 640-655 (teardown of EventsLogPane_ in close — mirror for NotifPane_) and 960-975 (applyTheme walks panes — add NotifPane_)
    - libs/FastSenseCompanion/NotificationCenterPane.m (Plan 02 public contract + static badge helpers from Plan 01)
    - .planning/phases/1040-companion-notification-center/1040-UI-SPEC.md "Column Show/Hide", "Detach Behavior", "Bell Button States"
  </read_first>
  <files>libs/FastSenseCompanion/FastSenseCompanion.m</files>
  <action>
    INSTANTIATE + ATTACH the pane in the build sequence, right after the EventsLogPane/LiveLogPane
    wiring (~line 495), and AFTER hNotifPanel_ exists:
    ```matlab
    obj.NotifPane_ = NotificationCenterPane(obj.Theme_);
    obj.NotifPane_.setCompanion(obj);
    obj.NotifPane_.attach(obj.hNotifPanel_, obj.Theme_);
    obj.Listeners_{end+1} = addlistener(obj.NotifPane_, 'DetachRequested', ...
        @(~,~) obj.setNotifDetached_(true));
    ```
    (Attach while hFig_ is still Visible='off' during construction — RESEARCH Pitfall 3 — so the
    first column expand renders cleanly. The pane is attached but the column width is 0, so it is
    built yet not visible until the bell toggles it.)

    SETPROJECT re-register (~line 774, alongside the EventsLogPane re-register): re-add the
    NotifPane_ DetachRequested listener after detach clears Listeners_:
    ```matlab
    if ~isempty(obj.NotifPane_) && isvalid(obj.NotifPane_)
        obj.Listeners_{end+1} = addlistener(obj.NotifPane_, 'DetachRequested', ...
            @(~,~) obj.setNotifDetached_(true));
    end
    ```

    CLOSE teardown (~line 645, mirror EventsLogPane_): clear CloseRequestFcn on hDetachedNotifFig_
    before delete (prevent recursion), delete it, null it; then
    `if ~isempty(obj.NotifPane_) && isvalid(obj.NotifPane_); obj.NotifPane_.detach(); delete(obj.NotifPane_); end; obj.NotifPane_ = [];`

    IMPLEMENT `toggleNotificationCenter_(obj)` (replacing the Task 1 stub): wrap in try/catch →
    on error `uialert(obj.hFig_, ME.message, 'Notification Center', 'Icon','error')` with id
    `FastSenseCompanion:bellToggleFailed` semantics. Body — flip the 4th column width and refresh:
    ```matlab
    cw = obj.hLayout_.ColumnWidth;
    if isnumeric(cw{4}) && isequal(cw{4}, 0)
        cw{4} = 320;                 % show (UI-SPEC width)
        obj.hLayout_.ColumnWidth = cw;
        drawnow;                     % clean first-expand render (Pitfall 3) — OK HERE (not inside pane.refresh)
        obj.NotifPane_.refresh(obj.getEventStore());   % populate immediately on open
        obj.updateBellBadge_();
    else
        cw{4} = 0;                   % hide
        obj.hLayout_.ColumnWidth = cw;
    end
    ```

    IMPLEMENT `setNotifDetached_(obj, tf)` mirroring setLogState_'s uifigure dance (try/catch):
    - tf==true: if `obj.NotifPane_.IsAttached`, `obj.NotifPane_.detach();` then
      `newFig = uifigure('Name','Notification Center — FastSenseCompanion','Position',[0 0 420 600],'Color',obj.Theme_.DashboardBackground); movegui(newFig,'center'); newFig.CloseRequestFcn = @(~,~) obj.setNotifDetached_(false); obj.hDetachedNotifFig_ = newFig; obj.NotifPane_.attach(newFig, obj.Theme_);`
      Then collapse the inline column (`cw{4}=0`) so the pane is not duplicated, then refresh + badge.
    - tf==false (re-inline): if `hDetachedNotifFig_` valid, clear its CloseRequestFcn + delete it + null it; if `obj.NotifPane_.IsAttached`, detach; `obj.NotifPane_.attach(obj.hNotifPanel_, obj.Theme_);` Show the inline column (`cw{4}=320`); refresh + badge.
    Use the EXACT title `'Notification Center — FastSenseCompanion'` (UI-SPEC Copywriting, em-dash
    char(8212)) and 420×600 initial size.

    IMPLEMENT `updateBellBadge_(obj)` (try/catch, never crash). Guard every hBellBtn_ access with
    `~isempty(obj.hBellBtn_) && isvalid(obj.hBellBtn_)`. Resolve `store = obj.getEventStore();`.
    If empty/invalid → set idle bell (Text=bellGlyph_, BackgroundColor=WidgetBorderColor,
    FontColor=ForegroundColor) and return. Else:
    ```matlab
    all = Event.empty; try; all = store.getEvents(); catch; end   % stale-safe; badge tolerates read fail
    unacked = NotificationCenterPane.filterUnacked_(all);
    n = numel(unacked);
    obj.hBellBtn_.Text = NotificationCenterPane.badgeText_(n, obj.bellGlyph_());
    if n == 0
        obj.hBellBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
        obj.hBellBtn_.FontColor       = obj.Theme_.ForegroundColor;
    else
        obj.hBellBtn_.BackgroundColor = NotificationCenterPane.badgeColor_( ...
            NotificationCenterPane.maxSeverity_(unacked), obj.Theme_);
        obj.hBellBtn_.FontColor       = obj.Theme_.DashboardBackground;
    end
    ```

    APPLYTHEME (~line 970): after the existing EventsLogPane_.applyTheme call, add
    `if ~isempty(obj.NotifPane_) && isvalid(obj.NotifPane_); obj.NotifPane_.applyTheme(obj.Theme_); end`
    then `obj.updateBellBadge_();` (badge recolor with new theme tokens — UI-SPEC Theme Propagation).

    ENABLE/DISABLE on store change: grep for every place hEventsBtn_.Enable is set from EventStore
    presence (notably after setProject resolves a store, and at construction lines 340-343); mirror
    the same Enable on/off + Tooltip ('Toggle notification center' / 'No EventStore registered') for
    hBellBtn_ so the bell tracks store presence. Also call `obj.updateBellBadge_();` once after the
    initial build (with the figure still Visible='off') so the badge reflects any pre-loaded events.
    MISS_HIT clean.
  </action>
  <verify>
    <automated>mcp__matlab__evaluate_matlab_code: addpath(pwd); install(); es = EventStore([tempname '.mat']); app = FastSenseCompanion('EventStore', es); drawnow; f = app.getFigForTest_(); b = findall(f,'Tag','CompanionBellBtn'); assert(strcmp(b.Enable,'on'),'bell should enable with store'); app.toggleNotificationCenter_(); drawnow; cw = app.getRootColumnWidthForTest_(); assert(isequal(cw{4},320),'col not shown'); app.toggleNotificationCenter_(); drawnow; cw2 = app.getRootColumnWidthForTest_(); assert(isequal(cw2{4},0),'col not hidden'); app.close(); disp('OK')</automated>
  </verify>
  <acceptance_criteria>
    - `grep -n "obj.NotifPane_ = NotificationCenterPane(obj.Theme_)" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -nE "addlistener\(obj.NotifPane_, 'DetachRequested'" libs/FastSenseCompanion/FastSenseCompanion.m` returns ≥ 2 matches (build + setProject)
    - `grep -nE "function toggleNotificationCenter_\(obj\)" libs/FastSenseCompanion/FastSenseCompanion.m` matches AND `grep -n "cw{4}" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -nE "function setNotifDetached_\(obj, tf\)" libs/FastSenseCompanion/FastSenseCompanion.m` matches AND `grep -n "Notification Center" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - `grep -nE "function updateBellBadge_\(obj\)" libs/FastSenseCompanion/FastSenseCompanion.m` matches AND `grep -nE "NotificationCenterPane.(badgeText_|badgeColor_|maxSeverity_|filterUnacked_)" libs/FastSenseCompanion/FastSenseCompanion.m` returns ≥ 4 matches
    - The matlab MCP snippet prints OK: bell enables with a store; toggle shows (320) then hides (0) column 4
    - `mcp__matlab__check_matlab_code` clean; `mh_style` + `mh_lint` clean
  </acceptance_criteria>
  <done>NotifPane_ instantiated + attached + DetachRequested-wired (build + setProject); toggleNotificationCenter_ shows/hides col 4 with a single drawnow; setNotifDetached_ pops out to a 420×600 uifigure titled 'Notification Center — FastSenseCompanion' with CloseRequestFcn re-inline; updateBellBadge_ reflects count + severity color and tolerates read failure; applyTheme + close teardown updated; bell tracks EventStore presence. Headless smoke passes. Code Analyzer + MISS_HIT clean.</done>
</task>

<task type="auto">
  <name>Task 3: Hook notification refresh + badge into onLiveTick_</name>
  <read_first>
    - libs/FastSenseCompanion/FastSenseCompanion.m lines 1665-1691 (onLiveTick_ — the (a)/(b)/(c)/(d) structure; insert AFTER c, BEFORE the cluster block)
    - .planning/phases/1040-companion-notification-center/1040-RESEARCH.md Pattern 5 (exact insertion snippet) + Pitfall 4 (no drawnow; lazy update)
  </read_first>
  <files>libs/FastSenseCompanion/FastSenseCompanion.m</files>
  <action>
    In `onLiveTick_` (line 1665), insert the notification refresh + badge update AFTER the
    `obj.EventsLogPane_.setLastUpdated(...)` call (~line 1681, the (c) block) and BEFORE the
    `if obj.IsClusterMode_` cluster block (~line 1684). Per RESEARCH Pattern 5 — wrap in its own
    try/catch so it can never crash the timer; only refresh when the pane is attached:
    ```matlab
    % Phase 1040 — Notification center refresh (no new timer; piggybacks this tick).
    if ~isempty(obj.NotifPane_) && isvalid(obj.NotifPane_) && obj.NotifPane_.IsAttached
        try
            obj.NotifPane_.refresh(obj.getEventStore());
            obj.updateBellBadge_();
        catch
            % Must never crash the live timer.
        end
    end
    ```
    Note: the pane's `refresh` already no-ops when there is no diff and never calls drawnow
    (Plan 02 / Pitfall 4), so this is cheap. `updateBellBadge_` is also read-error-tolerant
    (Task 2). Do NOT add any `drawnow` here. Keep the surrounding (a)/(b)/(c)/(d) ordering intact.
    MISS_HIT clean.
  </action>
  <verify>
    <automated>mcp__matlab__evaluate_matlab_code: addpath(pwd); install(); es = EventStore([tempname '.mat']); e = Event(now-0.01, NaN, 'P-101', 'HighPressure'); e.Severity = 3; e.IsOpen = true; es.append(e); app = FastSenseCompanion('EventStore', es); drawnow; app.toggleNotificationCenter_(); drawnow; app.onLiveTickForTest_(); drawnow; b = findall(app.getFigForTest_(),'Tag','CompanionBellBtn'); assert(~isempty(strfind(b.Text,'1')),'badge should show count 1'); app.close(); disp('OK')</automated>
  </verify>
  <acceptance_criteria>
    - `grep -nE "obj.NotifPane_.refresh\(obj.getEventStore\(\)\)" libs/FastSenseCompanion/FastSenseCompanion.m` matches AND it appears BETWEEN the `scanLiveTagUpdates_`/`setLastUpdated` lines and the `if obj.IsClusterMode_` line (confirm with `grep -n` line numbers: refresh line > setLastUpdated line AND < IsClusterMode_ poll line)
    - `grep -n "Phase 1040 — Notification center refresh" libs/FastSenseCompanion/FastSenseCompanion.m` matches
    - The matlab MCP snippet prints OK: after appending one sev-3 open event + a tick, the bell text contains '1'
    - `mcp__matlab__check_matlab_code` clean; `mh_style` + `mh_lint` clean
  </acceptance_criteria>
  <done>onLiveTick_ refreshes the attached notification pane and updates the bell badge between scanLiveTagUpdates_/setLastUpdated and the cluster block, guarded so it never crashes the timer; no drawnow added. Headless tick smoke shows the badge counting a live event. Code Analyzer + MISS_HIT clean.</done>
</task>

</tasks>

<verification>
- Headless smokes in each task's `<automated>` block pass via the matlab MCP.
- `mcp__matlab__check_matlab_code` clean on `FastSenseCompanion.m`.
- `mh_style` + `mh_lint` clean.
- Regression: `mcp__matlab__run_matlab_test_file tests/suite/TestFastSenseCompanion.m` — NOTE the two
  toolbar-column assertions (`testToolbarHasWikiButton` col 7, `testToolbarGearMovedToColumn8` col 9→10)
  will FAIL here until Plan 04 updates them. This is EXPECTED and is Plan 04's job; do not fix the
  tests in this plan. Confirm any *new* failures are only those two assertions (gear column) and not
  regressions elsewhere.
- `grep -c "drawnow" ` inside the pane refresh path is unaffected (Pitfall 4 is enforced in Plan 02);
  the single `drawnow` in `toggleNotificationCenter_` / `setNotifDetached_` is the intended first-expand fix.
- Confirm no new timer: `grep -nE "timer\(|TimerFcn" libs/FastSenseCompanion/FastSenseCompanion.m` shows
  no NEW timer added by this plan (only the pre-existing LiveTimer_).
</verification>

<success_criteria>
- Bell button at toolbar col 8 with unacked badge; disabled with no EventStore; spacer col 9, gear col 10.
- Root grid [3 4]; bell toggles the 4th column (320 ↔ 0); NotifPane_ hosted in hNotifPanel_; existing 3 columns reflow.
- onLiveTick_ refreshes the pane + badge (after scanLiveTagUpdates_/setLastUpdated, before cluster block), guarded.
- Pane detachable to a 420×600 uifigure via DetachRequested; CloseRequestFcn re-inlines; listener re-registered in setProject; close() tears down pane + detached fig.
- No new timer; single-user/no-store paths unaffected (bell disabled, column hidden, hook guarded).
- Honors 1040-CONTEXT.md deferred items (no NotificationService linkage, sounds, snooze, grouping added).
</success_criteria>

<output>
After completion, create `.planning/phases/1040-companion-notification-center/1040-03-SUMMARY.md`.
</output>
