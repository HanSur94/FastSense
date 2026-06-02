---
phase: 1040-companion-notification-center
plan: 02
type: execute
wave: 2
depends_on: ["01"]
files_modified:
  - libs/FastSenseCompanion/NotificationCenterPane.m
  - tests/suite/TestNotificationCenterPane.m
autonomous: true
requirements: []
must_haves:
  truths:
    - "NotificationCenterPane attaches into a parent (uipanel/uifigure), renders a header + inbox uitable, and detaches cleanly"
    - "refresh(eventStore) shows only UNACKED events newest-first; an EventStore read error keeps the last-good list and shows a (stale) marker"
    - "Clicking the Ack column acknowledges the event; an already-acked event (EventStore:unknownEventId) is a silent no-op, not a crash"
    - "The severity filter narrows the visible rows client-side; the empty state shows 'No unacknowledged events'"
    - "State (LastGoodEvents_, LastIds_, filter) survives detach + reattach"
  artifacts:
    - path: "libs/FastSenseCompanion/NotificationCenterPane.m"
      provides: "Full detachable inbox pane (attach/detach/refresh/applyTheme/ack/bulk-ack)"
      contains: "function attach(obj, parent, themeStruct)"
      min_lines: 250
    - path: "tests/suite/TestNotificationCenterPane.m"
      provides: "Headless class suite for lifecycle/refresh/diff/ack/filter/empty/stale/theme"
      contains: "classdef TestNotificationCenterPane < matlab.unittest.TestCase"
  key_links:
    - from: "libs/FastSenseCompanion/NotificationCenterPane.m"
      to: "EventStore.acknowledgeEvent"
      via: "onAckBtn_ / onAckWithComment_ / onAckAll_ callbacks"
      pattern: "acknowledgeEvent\\("
    - from: "libs/FastSenseCompanion/NotificationCenterPane.m"
      to: "EventGanttCanvas.severityColor"
      via: "row severity dot coloring"
      pattern: "EventGanttCanvas\\.severityColor"
    - from: "tests/suite/TestNotificationCenterPane.m"
      to: "NotificationCenterPane + StubEventStore"
      via: "headless uifigure('Visible','off') + refresh()"
      pattern: "NotificationCenterPane\\("
---

<objective>
Implement the full `NotificationCenterPane` UI on top of Plan 01's static-helper core: the
attach/detach lifecycle, the header strip (label + search + severity dropdown + "Updated:" label
+ pop-out icon), the bulk "Acknowledge all visible" button, the inbox `uitable`, the
`refresh(eventStore)` loop (unacked filter → diff-by-Id → newest-first → table render), the
per-item Ack / Ack-with-comment / bulk-ack callbacks, the stale-on-read-error guard, and
`applyTheme`. Cover it with a headless class suite.

This pane is a SIBLING to `EventsLogPane` and mirrors its contract exactly. It does NOT own a
timer (the Companion's `onLiveTick_` drives `refresh`, wired in Plan 03).

Purpose: Deliver the self-contained, independently-testable inbox pane.
Output: Completed `NotificationCenterPane.m` + `tests/suite/TestNotificationCenterPane.m`.
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
<!-- Verified against the live codebase 2026-06-02. -->

EventsLogPane.m public contract to MIRROR (libs/FastSenseCompanion/EventsLogPane.m):
```matlab
events
    DetachRequested        % fired by pop-out icon: ButtonPushedFcn = @(~,~) notify(obj,'DetachRequested')
end
properties (SetAccess = private)
    IsAttached logical = false
end
function obj = NotificationCenterPane(themeStruct)   % ctor stores theme, IsAttached=false
function setCompanion(obj, companion)                % stores Companion_ handle
function attach(obj, parent, themeStruct)            % builds UI inside parent; sets IsAttached=true
function detach(obj)                                 % delete(hRoot_); null handles; IsAttached=false (NO buffer loss)
function applyTheme(obj, themeStruct)                % walker + re-assert overrides
function requestDetach(obj)                          % notify(obj,'DetachRequested') — test seam
function delete(obj)                                 % detach() if attached
% EventsLogPane.detach() preserves its data buffer (LogBuffer_) — mirror that: preserve LastGoodEvents_/LastIds_/filter.
```

Theme walker (reuse, do not re-implement): EventsLogPane.applyTheme calls a shared
`applyThemeToChildren_(hRoot, themeStruct)`. Locate how EventsLogPane invokes it and use the
same call. Stripe-pair logic from EventsLogPane.m ~lines 183-188:
```matlab
isDark = mean(themeStruct.DashboardBackground) < 0.5;
if isDark; stripePair = [0.13 0.13 0.13; 0.20 0.20 0.20];
else;      stripePair = [1 1 1; 0.94 0.94 0.94]; end
```

EventStore live handle (from Plan 01 interfaces): getEvents(), numEvents(),
acknowledgeEvent(eventId, opts) — opts.comment char; throws EventStore:unknownEventId on race.

EventGanttCanvas.severityColor(sev) — Static; libs/FastSenseCompanion/EventGanttCanvas.m:285.
  sev 1 → [0.20 0.70 0.30]; 2 → [0.95 0.60 0.10]; 3 → [0.85 0.20 0.20]; else grey. USE BY NAME.

CompanionTheme.get('dark'|'light') fields available: DashboardBackground, WidgetBackground,
  WidgetBorderColor, ForegroundColor, ToolbarFontColor, Accent, StatusOkColor, StatusWarnColor,
  StatusAlarmColor, PlaceholderTextColor.

Plan 01 static helpers (call as NotificationCenterPane.<name>): filterUnacked_, sortNewestFirst_,
  maxSeverity_, idsOf_, diffIds_, badgeText_, badgeColor_.
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Implement attach/detach/applyTheme lifecycle + header + table layout</name>
  <read_first>
    - libs/FastSenseCompanion/EventsLogPane.m IN FULL — constructor, attach() (header [1 6] grid build, RowHeight {28,'1x'}, Padding [8 4 8 4], RowSpacing 4), detach() (delete hRoot_, null handles, preserve buffer), applyTheme() (walker + overrides), requestDetach(), delete(), and how it calls applyThemeToChildren_
    - libs/FastSenseCompanion/NotificationCenterPane.m (Plan 01 shell — extend it; do not recreate the static block)
    - .planning/phases/1040-companion-notification-center/1040-UI-SPEC.md "Component Layout Contract" (root [3 1] grid {28,24,'1x'} to fit the bulk button row; header [1 6] grid ColumnWidth {60,'1x',100,120,36,36}; uitable ColumnName/ColumnWidth) and "Theme Propagation Contract"
  </read_first>
  <files>libs/FastSenseCompanion/NotificationCenterPane.m</files>
  <action>
    Add the instance lifecycle to the Plan 01 shell. Mirror EventsLogPane structure exactly.

    Constructor `NotificationCenterPane(themeStruct)`: store `obj.ThemeStruct_ = themeStruct;`
    `obj.IsAttached = false;` `obj.LastGoodEvents_ = Event.empty;` `obj.LastIds_ = {};`
    `obj.Listeners_ = {};` `obj.IsStale_ = false;`

    `setCompanion(obj, companion)`: `obj.Companion_ = companion;`

    `attach(obj, parent, themeStruct)`: guard `if obj.IsAttached; return; end`. Store theme.
    Build a ROOT `uigridlayout(parent, [3 1])` with `RowHeight = {28, 24, '1x'}`,
    `ColumnWidth = {'1x'}`, `Padding = [8 4 8 4]`, `RowSpacing = 4`,
    `BackgroundColor = themeStruct.WidgetBackground`. (Row 1 = header strip; row 2 = bulk button;
    row 3 = table — per UI-SPEC bulk-button option "rows {28,24,'1x'}".) Store in `obj.hRoot_`.

    ROW 1 header: `uigridlayout(hRoot_, [1 6])`, `Layout.Row=1`,
    `ColumnWidth = {60, '1x', 100, 120, 36, 36}`, `RowHeight={'1x'}`, `Padding=[0 0 0 0]`,
    `ColumnSpacing=8`. Children:
    - Col 1: `uilabel` Text='Notifications', FontSize=11, FontWeight='bold'.
    - Col 2: `uieditfield('text')` → `obj.hSearch_`; FontSize=11; set Placeholder='Filter notifications…' inside try/catch (Placeholder is R2021a+; UI-SPEC notes this); `ValueChangedFcn = @(~,~) obj.applyFilterAndRender_();`.
    - Col 3: `uidropdown` → `obj.hSevDD_`; Items={'All','Alarm','Warn','Info'}; Value='All'; FontSize=11; Tooltip='Filter by severity'; `ValueChangedFcn = @(~,~) obj.applyFilterAndRender_();`.
    - Col 4: `uilabel` → `obj.hLastUpdateLbl_`; Text='Updated: --:--:--'; FontSize=11; FontName='Menlo'; FontColor=themeStruct.PlaceholderTextColor.
    - Col 5: `uibutton('push')` → `obj.hPopoutBtn_`; Text=char(8689); FontSize=14; Tooltip='Detach notification center to its own window'; `ButtonPushedFcn = @(~,~) notify(obj,'DetachRequested');`.
    - Col 6: reserved/empty (keeps symmetry with EventsLogPane [1 6]).

    ROW 2 bulk button: `uibutton('push')` → `obj.hAckAllBtn_`; `Layout.Row=2`; Text='Acknowledge all visible'; FontSize=11; BackgroundColor=themeStruct.WidgetBorderColor (recolored to Accent when count>0 in Task 2); `ButtonPushedFcn = @(~,~) obj.onAckAll_();`.

    ROW 3 inbox table: `uitable(hRoot_)` → `obj.hTable_`; `Layout.Row=3`;
    `ColumnName = {'', 'Sensor', 'Threshold', 'Peak', 'Start', 'Status', '', ''}`;
    `ColumnWidth = {12, 'auto', 'auto', 70, 90, 56, 28, 36}`  % UI-checker fold-in: Status 55→56, Start stays 90 (kept on 2px grid; see note below); Ack 28; comment 36;
    `RowName = {}`; `FontSize=10`; `FontName='Menlo'`; `ForegroundColor=themeStruct.ForegroundColor`;
    set `BackgroundColor` to the stripePair (compute via isDark, see interfaces);
    `CellSelectionChangedFcn = @(src,ev) obj.onCellSelected_(ev);`.
    Add a comment documenting the UI-checker fold-in: Status column 56 px (was 55), and a note
    that `uitable` row height is ~20 px platform default in R2020b and `LineHeight` is NOT settable
    on `uitable` (so no per-row height override is attempted). [Start column: UI-checker suggested
    90→88; keep 90 here because the monospace 'HH:MM:SS dd-mmm' string needs the width — document
    this single intentional deviation in the SUMMARY.]
    Set `obj.IsAttached = true;`. Then call `obj.renderTable_();` so a reattach repaints last-good rows.

    `detach(obj)`: guard `if ~obj.IsAttached; return; end`. try `delete(obj.hRoot_)` (tolerate errors).
    Null ALL handle props (`hRoot_`, header children handles, `hTable_`, `hSevDD_`, `hSearch_`,
    `hAckAllBtn_`, `hLastUpdateLbl_`, `hPopoutBtn_`). `obj.IsAttached = false;`. DO NOT clear
    `LastGoodEvents_`, `LastIds_`, or the filter selection (preserve across reattach — mirror
    EventsLogPane preserving LogBuffer_). NOTE: capture the current `hSevDD_.Value` /
    `hSearch_.Value` into private string props (`SevFilter_`, `SearchText_`) BEFORE nulling, so
    `attach` can restore them (add these two private props if not already present).

    `applyTheme(obj, themeStruct)`: store theme; `if ~obj.IsAttached; return; end`; call the shared
    `applyThemeToChildren_(obj.hRoot_, themeStruct)` (same invocation EventsLogPane uses); then
    re-assert overrides per UI-SPEC: `hLastUpdateLbl_.FontColor` = PlaceholderTextColor (or
    StatusWarnColor if `obj.IsStale_`), `hPopoutBtn_.BackgroundColor`=WidgetBorderColor,
    `hPopoutBtn_.FontColor`=ForegroundColor, `hTable_.BackgroundColor`=recomputed stripePair,
    `hTable_.ForegroundColor`=ForegroundColor.

    `requestDetach(obj)`: `notify(obj,'DetachRequested');`
    `delete(obj)`: `if obj.IsAttached; obj.detach(); end` (tolerate errors).

    Add empty private-method placeholders that Task 2 fills: `renderTable_`, `applyFilterAndRender_`,
    `onCellSelected_`, `onAckBtn_`, `onAckWithComment_`, `onAckAll_`, `refresh`. (Leave bodies minimal
    so the file parses; Task 2 implements them.) All callbacks must be wrapped in try/catch per
    CLAUDE.md when implemented. Errors use `NotificationCenterPane:*` IDs. MISS_HIT clean (≤160 cols).
  </action>
  <verify>
    <automated>mcp__matlab__evaluate_matlab_code: addpath(pwd); install(); f=uifigure('Visible','off'); c=onCleanup(@()delete(f)); p=NotificationCenterPane(CompanionTheme.get('dark')); p.attach(f, CompanionTheme.get('dark')); assert(p.IsAttached); assert(~isempty(findall(f,'Type','uitable'))); p.detach(); assert(~p.IsAttached); disp('OK')</automated>
  </verify>
  <acceptance_criteria>
    - `grep -nE "function (obj = NotificationCenterPane|setCompanion|attach|detach|applyTheme|requestDetach|delete)\(" libs/FastSenseCompanion/NotificationCenterPane.m` returns ≥ 7 matches
    - `grep -n "uigridlayout(parent, \[3 1\])\|uigridlayout(parent,\[3 1\])" libs/FastSenseCompanion/NotificationCenterPane.m` matches (root [3 1] with bulk-button row)
    - `grep -n "ColumnWidth = {12, 'auto', 'auto', 70, 90, 56, 28, 36}" libs/FastSenseCompanion/NotificationCenterPane.m` matches (UI-checker Status 56 fold-in)
    - `grep -n "notify(obj, 'DetachRequested')\|notify(obj,'DetachRequested')" libs/FastSenseCompanion/NotificationCenterPane.m` matches (pop-out + requestDetach)
    - The matlab MCP smoke snippet above prints OK: attach builds a uitable, IsAttached toggles true→false across attach/detach
    - `mcp__matlab__check_matlab_code` clean; `mh_style` + `mh_lint` clean
  </acceptance_criteria>
  <done>Pane attaches (header [1 6] + bulk button + inbox uitable), detaches preserving LastGoodEvents_/filter, applyTheme re-asserts overrides. Headless smoke passes. MISS_HIT + Code Analyzer clean.</done>
</task>

<task type="auto">
  <name>Task 2: Implement refresh/diff/render + ack callbacks + stale guard</name>
  <read_first>
    - libs/FastSenseCompanion/NotificationCenterPane.m (Task 1 lifecycle + Plan 01 static helpers)
    - libs/EventDetection/EventStore.m lines 337-438 (acknowledgeEvent: opts.comment, in-memory AckedAt mutation, EventStore:unknownEventId throw)
    - .planning/phases/1040-companion-notification-center/1040-UI-SPEC.md "Interaction Contract" sections: Inbox Row States (column→content map, CellSelectionChangedFcn column dispatch 7→ack / 8→comment / else→openEventViewer_), Severity Filter Dropdown, Empty State (exact copy), Stale State, Acknowledge Actions (all three), Copywriting Contract (LOCKED strings)
    - libs/FastSenseCompanion/EventGanttCanvas.m:285-298 (severityColor)
  </read_first>
  <files>libs/FastSenseCompanion/NotificationCenterPane.m</files>
  <action>
    Fill the private methods stubbed in Task 1. All callbacks wrapped in try/catch → non-blocking
    `uialert` (resolve the figure via `ancestor(obj.hRoot_,'figure')`); read errors do NOT uialert
    (inline stale marker only). `EventStore:unknownEventId` in any ack path → silent no-op.

    `refresh(obj, eventStore)` (called by Companion.onLiveTick_):
    - `if ~obj.IsAttached; return; end`.
    - If `isempty(eventStore) || ~isvalid(eventStore)`: set last-good empty path → `obj.LastGoodEvents_ = Event.empty;` clear stale; render; return.
    - Wrap `all = eventStore.getEvents();` in try/catch. ON ERROR: set `obj.IsStale_ = true;` keep `obj.LastGoodEvents_` unchanged; update the "Updated:" label to append `' (stale)'` and set its FontColor to StatusWarnColor; if `obj.Companion_` is set and valid, `obj.Companion_.addLogEntry('warn', 'Notification center: EventStore read failed; showing last-good list.')` inside try/catch; return (DO NOT clear inbox; DO NOT uialert). [UI-SPEC Stale State.]
    - ON SUCCESS: `obj.IsStale_ = false;` `unacked = NotificationCenterPane.sortNewestFirst_(NotificationCenterPane.filterUnacked_(all));` cap to 200 rows (`if numel(unacked) > 200; unacked = unacked(1:200); end` — UI-SPEC row cap / RESEARCH Pitfall 5). Compute `newIds = NotificationCenterPane.idsOf_(unacked);`. If `NotificationCenterPane.diffIds_(newIds, obj.LastIds_)` is FALSE, just update the "Updated:" timestamp label and return (no flicker — UI-SPEC badge animates only on diff; also RESEARCH Pitfall 4: never call drawnow here). If TRUE: store `obj.LastGoodEvents_ = unacked; obj.LastIds_ = newIds;` then `obj.applyFilterAndRender_();` and update timestamp label to `datetime('now')` HH:MM:SS.

    `applyFilterAndRender_(obj)`: derive the severity-filtered subset of `obj.LastGoodEvents_`:
    read `obj.hSevDD_.Value` (guard not-attached → use `obj.SevFilter_`); 'All'→all; 'Alarm'→Severity==3; 'Warn'→Severity==2; 'Info'→Severity==1. Also apply `obj.hSearch_.Value` free-text (case-insensitive `contains` over SensorName + ThresholdLabel) if non-empty. Then `obj.renderTable_(filtered);` and recolor the bulk button: `hAckAllBtn_.BackgroundColor = ` Accent if `~isempty(filtered)` else WidgetBorderColor.

    `renderTable_(obj, events)` (default `events = obj.LastGoodEvents_` when called with one arg —
    use `nargin`): if `obj.hTable_` invalid, return. If `isempty(events)`: set EMPTY STATE row exactly
    `obj.hTable_.Data = {'', '', 'No unacknowledged events', '', '', '', '', ''};` and return
    (UI-SPEC empty-state copy LOCKED). Else build an N×8 cell:
    col1 = '' (severity dot — note in a comment that uitable cannot set per-cell BackgroundColor in
    R2020b, so the dot is represented by a unicode bullet `char(9679)` whose color is conveyed via
    the Status column text color convention; render `char(9679)` here and rely on Status text), 
    col2 = SensorName, col3 = ThresholdLabel, col4 = peak value string (use `''` if no peak field
    available on the Event — guard with isprop/try), col5 = `datestr(ev.StartTime,'HH:MM:SS dd-mmm')`,
    col6 = `'LIVE'` if `ev.IsOpen` else `'closed'`, col7 = 'Ack', col8 = '...'. Assign `obj.hTable_.Data`.
    Maintain a parallel `obj.RowEventIds_` cellstr (private prop) mapping row→Event.Id so the cell
    callback can resolve the clicked event id. (Severity color: keep `EventGanttCanvas.severityColor`
    referenced for the row accent in a helper even if uitable limits cell coloring — call it to derive
    the dot intent and store; this satisfies the key_link and keeps Gantt-consistent semantics.)

    `onCellSelected_(obj, ev)`: guard `isempty(obj.LastGoodEvents_)` (empty-state click = no-op) and
    `isempty(ev.Indices)`. `r = ev.Indices(1); cdx = ev.Indices(2);` resolve `eid = obj.RowEventIds_{r}`
    (guard bounds). Dispatch: `cdx==7` → `obj.onAckBtn_(eid)`; `cdx==8` → `obj.onAckWithComment_(eid)`;
    otherwise → if `obj.Companion_` valid and has method, `obj.Companion_.openEventViewer_();`
    (RESEARCH: future-focus-on-event is out of scope; just open the viewer). Wrap in try/catch → uialert.

    `onAckBtn_(obj, eventId)`: try `obj.ackOne_(eventId);` catch ME → if
    `strcmp(ME.identifier,'EventStore:unknownEventId')` return (no-op); else uialert(fig, ME.message,
    'Acknowledge Failed','Icon','error').

    `onAckWithComment_(obj, eventId)`: `answer = inputdlg('Acknowledgement comment:','Acknowledge Event',1,{''});`
    `if isempty(answer); return; end` (cancel). Then `obj.ackOne_(eventId, answer{1});` with the same
    unknownEventId no-op / uialert error handling.

    `onAckAll_(obj)`: snapshot the currently-visible event ids (from `obj.RowEventIds_` reflecting the
    filtered render). Loop: for each id, try `obj.ackOne_(id);` catch ME → if unknownEventId continue
    (no-op per item); else uialert and break. Per UI-SPEC bulk action.

    Private helper `ackOne_(obj, eventId, comment)`: build `opts = struct('comment', '');` and if
    `nargin>2 && ~isempty(comment); opts.comment = comment; end`. Resolve the store via the Companion
    (`store = obj.Companion_.getEventStore();` if Companion set, else error
    `NotificationCenterPane:noEventStore`). Call `store.acknowledgeEvent(eventId, opts);`. In single-user
    mode the in-memory AckedAt is set immediately and the next `refresh()` diff drops the row — do not
    mutate the table here. [RESEARCH Open Question 3: single-user acknowledgeEvent does not auto-save;
    call `store.save()` in try/catch after a successful ack so the ack survives a crash — save failure
    is non-fatal, log via Companion.addLogEntry('warn',...).]

    Update `setLastUpdated_`-style label writes to go through a small private
    `setUpdatedLabel_(obj, dt, isStale)` so stale + normal paths share one code path. MISS_HIT clean.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file: tests/suite/TestNotificationCenterPane.m (created in Task 3 of this plan — all tests green)</automated>
  </verify>
  <acceptance_criteria>
    - `grep -nE "function refresh\(obj, eventStore\)" libs/FastSenseCompanion/NotificationCenterPane.m` matches
    - `grep -n "EventStore:unknownEventId" libs/FastSenseCompanion/NotificationCenterPane.m` matches (race no-op)
    - `grep -n "'No unacknowledged events'" libs/FastSenseCompanion/NotificationCenterPane.m` matches (empty-state copy)
    - `grep -n "(stale)" libs/FastSenseCompanion/NotificationCenterPane.m` matches (stale marker)
    - `grep -nE "inputdlg\('Acknowledgement comment:'" libs/FastSenseCompanion/NotificationCenterPane.m` matches
    - `grep -n "acknowledgeEvent(" libs/FastSenseCompanion/NotificationCenterPane.m` matches; `grep -n "EventGanttCanvas.severityColor" libs/FastSenseCompanion/NotificationCenterPane.m` matches
    - `grep -c "drawnow" libs/FastSenseCompanion/NotificationCenterPane.m` returns 0 (Pitfall 4: no drawnow inside refresh path)
    - `mcp__matlab__check_matlab_code` clean; `mh_style` + `mh_lint` clean
  </acceptance_criteria>
  <done>refresh filters unacked + diffs by Id + caps at 200 + renders newest-first; ack/ack-comment/bulk callbacks route to EventStore.acknowledgeEvent with unknownEventId no-op; read errors keep last-good + show (stale); empty state copy exact; no drawnow in refresh. Code Analyzer + MISS_HIT clean.</done>
</task>

<task type="auto">
  <name>Task 3: Write TestNotificationCenterPane class suite (headless)</name>
  <read_first>
    - tests/suite/TestEventsLogPane.m IN FULL — TestClassSetup addPaths, makePane_ helper (uifigure('Visible','off') + addTeardown(delete)), how lifecycle/theme/detach are asserted headlessly
    - tests/StubEventStore.m (Plan 01)
    - libs/FastSenseCompanion/NotificationCenterPane.m (Tasks 1-2)
    - .planning/phases/1040-companion-notification-center/1040-VALIDATION.md "Phase Requirements → Test Map" (rows mapped to TestNotificationCenterPane)
  </read_first>
  <files>tests/suite/TestNotificationCenterPane.m</files>
  <action>
    Create `tests/suite/TestNotificationCenterPane.m` as `classdef TestNotificationCenterPane <
    matlab.unittest.TestCase`. Mirror `TestEventsLogPane.m`:
    - `methods (TestClassSetup) function addPaths(testCase) addpath(fullfile(...,'..','..')); install(); end` (match the relative path EventsLogPane uses).
    - Private helper `function [p, hFig] = makePane_(testCase, themeName) hFig = uifigure('Visible','off'); testCase.addTeardown(@() delete(hFig)); p = NotificationCenterPane(CompanionTheme.get(themeName)); testCase.addTeardown(@() delete(p)); end`.
    - Private helper `function evs = makeEvents_(testCase)` building a fixed Event array: evt_1(Sev=3,Start=30,IsOpen=true,AckedAt=[]), evt_2(Sev=2,Start=20,AckedAt=[]), evt_3(Sev=1,Start=10,AckedAt=now). Set `.Id` explicitly.

    Test methods (each headless; attach to a Visible='off' uifigure):
    1. `testConstructDetached` — construct pane, assert `~p.IsAttached`.
    2. `testAttachBuildsTable` — `[p,f]=makePane_('dark'); p.attach(f, CompanionTheme.get('dark'));` assert `p.IsAttached` and `~isempty(findall(f,'Type','uitable'))`.
    3. `testDetachReattachPreservesState` — attach; set `p` last-good via `refresh` with a StubEventStore of 2 unacked; detach; assert `~p.IsAttached`; reattach; assert the table repaints with the same 2 rows (read pane's exposed row count — add a tiny Hidden test accessor `numVisibleRows_()` returning size(hTable_.Data,1) excluding empty-state, OR assert `numel(p.LastGoodEvents_)==2` which survives detach).
    4. `testRefreshFiltersUnacked` — StubEventStore with 3 events (one acked); `p.refresh(stub)`; assert `numel(p.LastGoodEvents_)==2` and newest-first (`p.LastGoodEvents_(1).Id` == 'evt_1').
    5. `testDiffNoFlicker` — refresh once; capture `p.LastIds_`; refresh again with identical events; assert `isequal(p.LastIds_, <captured>)` (no spurious change). (diff-by-Id semantics.)
    6. `testAckRemovesOnNextRefresh` — wire pane to a Companion-less ack path: because ackOne_ resolves the store via Companion_, set `p.setCompanion(stubCompanion)` where stubCompanion is a tiny inline double exposing `getEventStore()`→stub and `addLogEntry(varargin)` no-op (define as a local nested test class or a struct-backed handle; simplest: a small `classdef` helper at bottom of the test file, or reuse StubEventStore by adding a `getEventStore` returning self — prefer adding `getEventStore` to the test by wrapping). Simulate clicking Ack on evt_2: call the documented public/Hidden path — expose a Hidden `ackForTest_(eventId)` on the pane that calls `onAckBtn_` so the test can drive it without a real CellSelection event. After ack, `p.refresh(stub)`; assert `numel(p.LastGoodEvents_)==1` and 'evt_2' gone.
    7. `testAckRaceIsNoOp` — `stub.ThrowOnAck_ = true;` drive `ackForTest_('evt_2')`; assert NO error thrown (test passes if the call returns normally) and inbox unchanged.
    8. `testStaleOnReadError` — refresh with a healthy stub (2 rows); then `stub.ThrowOnGet_ = true; p.refresh(stub);` assert `p.LastGoodEvents_` still has 2 (last-good preserved) and the Updated label text contains '(stale)' (read `p` label via a Hidden accessor `lastUpdatedText_()` returning hLastUpdateLbl_.Text).
    9. `testSeverityFilter` — refresh with the 2 unacked (sev 3 + sev 2); set `p.hSevDD_.Value='Alarm'` then call `p.applyFilterAndRender_()`; assert only 1 row visible (sev-3). (Add Hidden accessor for visible row count or assert the filtered render via numVisibleRows_.)
    10. `testEmptyState` — refresh with a stub returning Event.empty; assert table Data is the single empty-state row containing 'No unacknowledged events'.
    11. `testApplyThemeReassertsOverrides` — attach dark; `p.applyTheme(CompanionTheme.get('light'))`; assert no error and `p.IsAttached` still true (smoke that the walker + overrides run).
    12. `testDetachRequestedFires` — `addlistener(p,'DetachRequested', @(~,~) setFlag); p.requestDetach();` assert flag set.

    For any private state the tests must read (visible row count, last-updated text), add the minimal
    `methods (Hidden)` test accessors to `NotificationCenterPane.m` IN THIS TASK (e.g.,
    `numVisibleRows_`, `lastUpdatedText_`, `ackForTest_`) — keep them Hidden so they are not public
    API (mirrors the Phase 1028 Hidden-test-seam pattern noted in STATE.md). Headless guard: if the
    suite cannot create a uifigure (no desktop), follow TestEventsLogPane's guard idiom
    (assumeFail/skip) rather than hard-failing. MISS_HIT clean.
  </action>
  <verify>
    <automated>mcp__matlab__run_matlab_test_file: tests/suite/TestNotificationCenterPane.m (all tests pass; skips allowed only if headless-guarded like TestEventsLogPane)</automated>
  </verify>
  <acceptance_criteria>
    - `exist('tests/suite/TestNotificationCenterPane.m','file') == 2`
    - `grep -n "classdef TestNotificationCenterPane < matlab.unittest.TestCase" tests/suite/TestNotificationCenterPane.m` matches
    - `grep -cE "function test[A-Z]" tests/suite/TestNotificationCenterPane.m` returns ≥ 12
    - `grep -nE "testRefreshFiltersUnacked|testAckRemovesOnNextRefresh|testAckRaceIsNoOp|testStaleOnReadError|testEmptyState|testDetachReattachPreservesState" tests/suite/TestNotificationCenterPane.m` returns 6 matches
    - `mcp__matlab__run_matlab_test_file` on the suite reports 0 failures (skips permitted only via the headless guard)
    - any new Hidden accessors live under `methods (Hidden)` in NotificationCenterPane.m: `grep -n "methods (Hidden)" libs/FastSenseCompanion/NotificationCenterPane.m` matches
    - `mh_style` + `mh_lint` clean on the test file
  </acceptance_criteria>
  <done>TestNotificationCenterPane green headlessly: lifecycle, detach/reattach state preservation, unacked filter, diff-no-flicker, ack→removal, ack-race no-op, stale guard, severity filter, empty state, theme, DetachRequested. MISS_HIT clean.</done>
</task>

</tasks>

<verification>
- `mcp__matlab__run_matlab_test_file tests/suite/TestNotificationCenterPane.m` → all green.
- Re-run Plan 01's `test_notification_center_pane` to confirm no regression in the static helpers.
- `mcp__matlab__check_matlab_code` clean on `NotificationCenterPane.m`.
- `mh_style` + `mh_lint` clean on both files.
- `grep -c "drawnow" libs/FastSenseCompanion/NotificationCenterPane.m` == 0 (Pitfall 4).
- Confirm deferred items absent: `grep -niE "NotificationService|snooze|sound|grouping|mute|seen" libs/FastSenseCompanion/NotificationCenterPane.m` returns NO matches.
</verification>

<success_criteria>
- NotificationCenterPane is a complete, self-contained, detachable inbox pane mirroring EventsLogPane's contract (attach/detach/applyTheme/DetachRequested/setCompanion/delete).
- refresh shows only unacked, newest-first, diffed by Id, capped at 200; read errors keep last-good + (stale); ack paths route to EventStore.acknowledgeEvent with unknownEventId-as-no-op and post-ack save() in single-user; empty-state + LIVE + copy strings match UI-SPEC verbatim.
- TestNotificationCenterPane green headlessly with ≥ 12 tests.
- No timer created in the pane (Companion drives refresh, wired in Plan 03).
- UI-checker fold-ins applied: Status column 56 px; documented uitable row-height note; the single Start-column deviation recorded.
</success_criteria>

<output>
After completion, create `.planning/phases/1040-companion-notification-center/1040-02-SUMMARY.md`.
</output>
