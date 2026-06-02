# Phase 1040: Companion Notification Center - Research

**Researched:** 2026-06-02
**Domain:** MATLAB uifigure UI + EventStore read API + FastSenseCompanion extension
**Confidence:** HIGH — all findings from direct source code reads; no inference needed

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- New self-contained handle class `NotificationCenterPane` in `libs/FastSenseCompanion/`, a SIBLING to `EventsLogPane`: `attach(parent, theme)` / `detach()`, fires `DetachRequested`, detachable to its own window, state survives attach/detach.
- Feed source: Pane reads `EventStore.getEvents()` and filters to UNACKED (`isempty(Event.AckedAt)`). NO new timer — live refresh piggybacks on the existing `LiveTimer_` / `onLiveTick_` loop.
- Dismiss == Acknowledge: `EventStore.acknowledgeEvent(eventId, opts)`. Item leaves inbox on next diff. Ack is shared + audited. Ack on already-acked event is NO-OP, not an error.
- Placement: Companion gains a toolbar BELL button with an unacked-count badge; toggling shows/hides a 4th rightmost grid column. Bell DISABLED when no EventStore (mirror `hEventsBtn_` enable/disable rule).
- Error handling: Every callback wrapped try/catch → non-blocking `uialert`. EventStore read failure: keep last-good list + show inline "stale" marker.
- Newest-first ordering; diff by `Event.Id` to prevent flicker.

### Claude's Discretion

- Exact pixel layout of the pane, badge rendering, severity color mapping (within `CompanionTheme`).
- Detached-window title/arrangement.
- Internal diffing / data-structure details.

### Deferred Ideas (OUT OF SCOPE)

- Linking the email `NotificationService` into the app.
- Sounds / desktop / OS notifications.
- Snooze / temporary mute.
- Event grouping or storm-collapsing.
- Per-user local "seen" state separate from shared ack.
</user_constraints>

---

## Summary

Phase 1040 is a UI-surface phase over mature infrastructure. The `EventStore.getEvents()` method (`EventStore.m:97`) already returns all in-memory events with no file I/O in single-user mode — no new accessor is needed for the hot path. The pane simply calls `getEvents()` and filters client-side by `isempty(ev.AckedAt)`. `acknowledgeEvent` (`EventStore.m:337`) mutates the in-memory `Event.AckedAt` immediately in both single-user and cluster modes, so the diff on the next tick naturally removes the item from the inbox.

The Companion's root grid is a `uigridlayout(hFig, [3 3])` with `ColumnWidth = {220, '1x', 360}` (`FastSenseCompanion.m:299-300`). Adding a 4th column means expanding the grid to `[3 4]` and updating `hToolbarPanel_` to span `[1 4]` plus adjusting the log panel span to `[1 4]`. The show/hide mechanism is simply `obj.hLayout_.ColumnWidth{4} = 0` (hidden) vs a real pixel value (visible) — the identical pattern `rebalanceLogStrip_` already uses for row heights. No children need be re-parented.

**Primary recommendation:** Use `EventStore.getEvents()` directly, filter client-side by `isempty(AckedAt)`, diff by `Event.Id`, and wire the refresh into `onLiveTick_` after line 1679. No new EventStore method is needed; the existing API is sufficient.

---

## Standard Stack

| Library | Purpose | Notes |
|---------|---------|-------|
| MATLAB `uigridlayout` | 4th-column toggle | `ColumnWidth` cell assignment at runtime is stable; R2020b+ |
| MATLAB `uitable` | Inbox row list | Used in `EventsLogPane`, `TagStatusTableWindow`; `BackgroundColor` striped pair |
| MATLAB `uibutton` | Bell button + Ack | Same pattern as `hEventsBtn_`, `hLiveBtn_` |
| MATLAB `uidropdown` | Severity filter | Same pattern as `hLogLevelDD_` in `EventsLogPane` |
| `EventStore.getEvents()` | Event feed | Returns `obj.events_` directly in single-user mode |
| `EventStore.acknowledgeEvent()` | Dismiss action | In-memory + persisted; see exact signature below |
| `EventGanttCanvas.severityColor()` | Severity colors | Static method; reuse verbatim |
| `CompanionTheme.get()` | Theming struct | Has `StatusOkColor`, `StatusWarnColor`, `StatusAlarmColor`, `Accent` |

---

## Architecture Patterns

### Recommended Project Structure

```
libs/FastSenseCompanion/
├── NotificationCenterPane.m     ← NEW (sibling to EventsLogPane.m)
tests/suite/
├── TestNotificationCenterPane.m ← NEW class-based suite
tests/
├── test_notification_center_pane.m ← NEW flat pure-logic tests
```

### Pattern 1: EventStore Read API

**What:** `getEvents()` is the public method to obtain all in-memory events. In single-user mode it returns `obj.events_` directly with zero file I/O (`EventStore.m:97-103`). In cluster mode it merges per-tag NDJSON logs but returns an event array of the same shape.

**Verified signatures (from `EventStore.m`):**

```matlab
% Get all events (in-memory, O(1) single-user):
events = obj.getEvents();                         % line 97

% Filter client-side for unacked:
mask = arrayfun(@(ev) isempty(ev.AckedAt), events);
unacked = events(mask);

% Acknowledge one event:
ack = obj.acknowledgeEvent(eventId, opts);        % line 337
%   eventId — char
%   opts    — struct with optional fields:
%               opts.comment  char (default '')
%               opts.user     char (default ClusterIdentity)
%               opts.host     char
%               opts.epoch    double (datenum)
%   Returns ack struct: {eventId, by_user, by_host, epoch, comment, action='ack'}

% In-memory effect: acknowledgeEvent mutates ev.AckedAt, ev.AckedBy,
%   ev.AckComment on the Event handle object IMMEDIATELY (line 405-411).
%   The next getEvents()+filter call will exclude the event from unacked list.

% numEvents (count only, no allocation):
n = obj.numEvents();                              % line 280

% Ack records for a specific event (single-user or cluster):
rows = obj.getAckRecordsForEvent(eventId);        % line 440

% Static: loadFile (used by EventViewer, NOT recommended for pane)
[events, meta, changed] = EventStore.loadFile(filePath);   % line 463
%   Has mtime-based cache — returns stale data if file unchanged.
%   Reads the .mat on change. EventViewer uses this for its independent refresh.
%   The pane SHOULD NOT use loadFile — use getEvents() on the live handle.
```

**How existing consumers get events:**
- `CompanionEventViewer.refresh()` (`CompanionEventViewer.m:214`) calls `obj.Store_.getEvents()` — the live handle.
- `FastSense.m:2617` calls `es.getEventsForTag(tag.Key)` — tag-scoped query.
- `EventViewer.m` (standalone, not the Companion viewer) uses `EventStore.loadFile()` — reads the `.mat` directly. This is the "old" pattern; the Companion version calls `getEvents()`.

**Recommendation:** Call `obj.EventStore_.getEvents()` on each tick. Filter `isempty(ev.AckedAt)` client-side. Diff by `ev.Id`. No new EventStore method needed.

**Ack propagation:** Single-user: `acknowledgeEvent` mutates in-memory + appends to `obj.acks_`; persisted only when `save()` is called next. Cluster: also calls `appendAckRecord` (SQLite INSERT); propagation to other Companions ~5s (ACK-01). A race where another Companion acks first: `acknowledgeEvent` in single-user throws `EventStore:unknownEventId` if the eventId is not in `events_`; in cluster mode it silently continues. The pane callback should catch `unknownEventId` and treat it as a no-op (event already acked).

### Pattern 2: NotificationCenterPane Class Structure

Mirror `EventsLogPane.m` exactly:

```matlab
classdef NotificationCenterPane < handle

    events
        DetachRequested   % fired by inline pop-out icon click
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_   = []    % CompanionTheme struct
        hRoot_         = []    % outer uigridlayout
        hTable_        = []    % uitable: inbox rows
        hBadgeLbl_     = []    % uilabel in detached header (redundant badge)
        hSevDD_        = []    % uidropdown severity filter
        hAckAllBtn_    = []    % uibutton "Ack all visible"
        hLastUpdateLbl_ = []   % "Updated: HH:MM:SS"
        hStaleMarker_  = []    % uilabel "(stale)" — shown on EventStore read error
        hPopoutBtn_    = []    % pop-out icon
        Companion_     = []    % FastSenseCompanion handle (for openEventViewer_)
        LastGoodEvents_ = []   % Event array: last successful fetch (stale guard)
        LastIds_        = {}   % cellstr: Id set from last diff
    end

    methods (Access = public)
        function obj = NotificationCenterPane(themeStruct) ... end
        function setCompanion(obj, companion) ... end
        function attach(obj, parent, themeStruct) ... end
        function detach(obj) ... end
        function refresh(obj, eventStore) ... end   % called by Companion.onLiveTick_
        function applyTheme(obj, themeStruct) ... end
        function requestDetach(obj) ... end         % test seam
        function delete(obj) ... end
    end
end
```

### Pattern 3: Companion Grid Extension (4th Column)

The root grid is constructed at `FastSenseCompanion.m:299`:

```matlab
% CURRENT (line 299-300):
obj.hLayout_ = uigridlayout(obj.hFig_, [3 3]);
obj.hLayout_.ColumnWidth = {220, '1x', 360};

% NEW (expand to 4 columns; 4th starts hidden):
obj.hLayout_ = uigridlayout(obj.hFig_, [3 4]);
obj.hLayout_.ColumnWidth = {220, '1x', 360, 0};   % 0 = hidden initially
```

Existing panel column assignments stay identical (cols 1-3). New assignments:

```matlab
% Toolbar spans all 4 cols (was [1 3]):
obj.hToolbarPanel_.Layout.Column = [1 4];

% Log panel spans all 4 cols (was [1 3]):
obj.hLogPanel_.Layout.Column = [1 4];

% New notification pane panel:
obj.hNotifPanel_ = uipanel(obj.hLayout_);
obj.hNotifPanel_.Layout.Row    = 2;
obj.hNotifPanel_.Layout.Column = 4;
```

**Show/hide toggle** (no children re-parenting, no grid rebuild):

```matlab
function toggleNotificationCenter_(obj)
    cw = obj.hLayout_.ColumnWidth;
    if isnumeric(cw{4}) && cw{4} == 0
        cw{4} = 320;   % show: ~320 px (Claude's discretion)
    else
        cw{4} = 0;     % hide
    end
    obj.hLayout_.ColumnWidth = cw;
end
```

This is the identical mechanism `rebalanceLogStrip_` uses for `RowHeight` (`FastSenseCompanion.m:1519-1555`). It is proven safe in this codebase.

**Known pitfall:** uifigure grid reflows can flicker on first expand if the column has never been visible. Mitigate by setting `ColumnWidth{4} = 320` once during construction with `Visible='off'` on the figure, then collapsing to 0 before `Visible='on'`. (Identical to how the companion shows the full figure only after building all panels at `FastSenseCompanion.m:532`.)

### Pattern 4: Toolbar Bell Button + Badge

The toolbar inner grid is a `[1 9]` grid (`FastSenseCompanion.m:323`):

```
Col 1  Events 110px    Col 2  Live 110px    Col 3  Tags 110px
Col 4  PlantLog 130px  Col 5  Tile 70px     Col 6  CloseAll 90px
Col 7  Wiki 70px       Col 8  spacer '1x'   Col 9  Gear 36px
```

Add the bell as **col 8** (shifting the spacer to col 9 and gear to col 10), expanding the grid to `[1 10]`:

```matlab
% NEW [1 10] grid:
hToolbarGrid = uigridlayout(obj.hToolbarPanel_, [1 10]);
hToolbarGrid.ColumnWidth = {110, 110, 110, 130, 70, 90, 70, 70, '1x', 36};

% Bell button at col 8:
obj.hBellBtn_ = uibutton(hToolbarGrid, 'push');
obj.hBellBtn_.Layout.Column = 8;
obj.hBellBtn_.Text = char(128276);   % bell glyph U+1F514, or use '(!)' ASCII fallback
obj.hBellBtn_.Tag  = 'CompanionBellBtn';
obj.hBellBtn_.ButtonPushedFcn = @(~,~) obj.toggleNotificationCenter_();
if isempty(obj.EventStore_)
    obj.hBellBtn_.Enable  = 'off';
    obj.hBellBtn_.Tooltip = 'No EventStore registered';
end
```

**Badge rendering:** `uibutton` has no native badge. Options (Claude's discretion):
- **Recommended:** Include unacked count in the button label text: `sprintf('(%d)', n)` when `n > 0`, plain bell glyph when 0. Simple, robust, no overlay z-order issues.
- Alternative: A `uilabel` overlay positioned absolutely — requires `Units='pixels'` + `Position` — fragile on resize.
- Color signaling: `BackgroundColor` shifts to `theme.StatusAlarmColor` when alarm-severity events are unacked, `theme.StatusWarnColor` for warn-only, `theme.Accent` for info-only.

**Enable/disable rule** (`hEventsBtn_` at `FastSenseCompanion.m:340-343` is the pattern):
```matlab
if isempty(obj.EventStore_)
    obj.hBellBtn_.Enable  = 'off';
    obj.hBellBtn_.Tooltip = 'No EventStore registered';
end
```

### Pattern 5: Live Refresh Hook

`onLiveTick_` is at `FastSenseCompanion.m:1665`. Current body:

```matlab
function onLiveTick_(obj)
    if ~obj.IsLive || isempty(obj.hFig_) || ~isvalid(obj.hFig_); return; end
    try
        % (a) InspectorPane refresh
        obj.InspectorPane_.refreshLive();
        % (b) Tag sample scan → live log + status table push
        obj.scanLiveTagUpdates_();
        % (c) EventsLogPane timestamp
        obj.EventsLogPane_.setLastUpdated(datetime('now'));
        % (d) Cluster-mode polling (dormant in single-user)
        if obj.IsClusterMode_; obj.pollClusterContention_(); obj.pollShareStatus_(); end
    catch
    end
end
```

**Insert notification pane refresh AFTER (c), before the cluster block:**

```matlab
% (d) Notification center refresh
if ~isempty(obj.NotifPane_) && isvalid(obj.NotifPane_) && obj.NotifPane_.IsAttached
    try
        obj.NotifPane_.refresh(obj.EventStore_);
    catch
        % Must never crash the timer.
    end
end
```

**LiveEventPipelines_ observation for lower latency:** `LiveEventPipelines_` are stored at `FastSenseCompanion.m:110` and walked in `pollClusterContention_` (`line 2207-2218`) for contention polling. There is no existing event-emission hook from these pipelines into the companion's tick. The CONTEXT.md says "its tick also nudges a refresh for lower latency" — the cleanest way is to `addlistener` on `LiveEventPipeline`'s `EventDetected` event (if it exists) or simply rely on the LiveTimer_ tick (which is already at 1s period). Check `LiveEventPipeline.m` for any `notify` calls — if there is a `CycleComplete` or `EventEmitted` event, add a listener in the constructor; otherwise the 1s tick is sufficient.

### Pattern 6: Severity Colors

Two authoritative sources in the codebase:

**`EventGanttCanvas.severityColor(sev)`** (`EventGanttCanvas.m:285-298`):
```matlab
% Sev 1 (info/ok):   [0.20 0.70 0.30]  — green
% Sev 2 (warn):      [0.95 0.60 0.10]  — orange
% Sev 3 (alarm):     [0.85 0.20 0.20]  — red
% otherwise:         [0.50 0.50 0.50]  — grey
```

**`DashboardTheme`** fields (available via `CompanionTheme.get()`):
```matlab
theme.StatusOkColor    = [0.31 0.80 0.64]   % green (teal)
theme.StatusWarnColor  = [0.91 0.63 0.27]   % orange
theme.StatusAlarmColor = [0.91 0.27 0.38]   % red
```

**Recommendation:** Use `EventGanttCanvas.severityColor()` for row `BackgroundColor` accent (matches the existing event rendering convention). Use `DashboardTheme.StatusAlarmColor` / `StatusWarnColor` for the bell badge color (matches the StatusWidget convention). Both are available in the same session with no import needed.

### Pattern 7: Event Model (confirmed from Event.m)

```matlab
% Key properties:
ev.AckedAt    % numeric epoch (datenum); [] = unacked — CHECK: isempty(ev.AckedAt)
ev.AckedBy    % struct {user, host, epoch, comment}
ev.AckComment % char: convenience alias
ev.Severity   % 1=info, 2=warn, 3=alarm
ev.IsOpen     % logical: true = condition still active
ev.Id         % char: unique id (format 'evt_N')
ev.SensorName % char: tag key
ev.ThresholdLabel % char: threshold label
ev.StartTime  % numeric: datenum
ev.EndTime    % numeric: datenum (NaN if still open)

% ISA-18.2 four-state:
s = ev.computeDisplayState()
%   'unacked-active'   — needs immediate attention
%   'acked-active'     — operator acknowledged but alarm persists
%   'acked-cleared'    — normal closure
%   'unacked-cleared'  — closed but never acked (audit anomaly)
```

The inbox shows only states where `isempty(ev.AckedAt)` — i.e., `'unacked-active'` and `'unacked-cleared'`. The `IsOpen == true` "LIVE" tag applies to `'unacked-active'` events. `computeDisplayState()` (`Event.m:125-151`) is the canonical check — use it for row styling.

### Anti-Patterns to Avoid

- **Using `EventStore.loadFile()` inside the pane:** This reads the `.mat` file on mtime change, bypasses the live in-memory `events_`, and is the "old" pattern used only by the standalone `EventViewer`. Use `getEvents()` on the live handle instead.
- **Creating a new timer in NotificationCenterPane:** CONTEXT.md explicitly forbids this. Refresh must hook into `onLiveTick_`.
- **Re-parenting the notification pane panel on hide/show:** Setting `ColumnWidth{4} = 0` is sufficient — no `detach()`/`attach()` cycle needed for the column toggle. The pane stays attached to `hNotifPanel_`.
- **Iterating over the raw event array during `acknowledgeEvent`:** In cluster mode the event may not be in `events_` (it lives only in NDJSON). The pane should call `acknowledgeEvent` and catch `EventStore:unknownEventId` — treat as no-op (already acked by another Companion).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Severity → RGB color | Custom color map | `EventGanttCanvas.severityColor(sev)` | Already in codebase; consistent with Gantt |
| Theme-aware stripe colors | Manual light/dark branch | Copy the `isDark = mean(t.DashboardBackground) < 0.5` + `stripePair` block from `EventsLogPane.m:183-188` | Already proven; don't duplicate logic |
| Detach-to-uifigure pattern | Custom window manager | Mirror `setLogState_('events', 'Detached')` in `FastSenseCompanion.m:1484-1498` exactly | The CloseRequestFcn dance prevents recursion |
| Event ack record | Custom persistence | `EventStore.acknowledgeEvent(id, opts)` | Shared + audited; cluster-mode retry included |
| Unacked count | Custom traversal | `sum(arrayfun(@(ev) isempty(ev.AckedAt), events))` | One-liner using Event.AckedAt |
| Theme walker | Custom recursion | `applyThemeToChildren_(hRoot_, themeStruct)` from EventsLogPane.applyTheme | Already in codebase; handles all uifigure widget types |

---

## Runtime State Inventory

This is a new UI surface, not a rename/refactor. No runtime state migration required.

- **Stored data:** None — no new persistent state. `EventStore` data pre-exists.
- **Live service config:** None.
- **OS-registered state:** None.
- **Secrets/env vars:** None.
- **Build artifacts:** None — pure `.m` file additions.

---

## Common Pitfalls

### Pitfall 1: Grid Column Count Mismatch in Tests
**What goes wrong:** `TestFastSenseCompanion` has hard-coded assertions on toolbar column positions (`testToolbarHasWikiButton` asserts Wiki at col 7; `testToolbarGearMovedToColumn8` asserts gear at col 9). Expanding the toolbar from `[1 9]` to `[1 10]` shifts gear to col 10 and the existing tests fail.
**Why it happens:** Column indices are asserted literally.
**How to avoid:** Update both test assertions when adding the bell at col 8. The method name `testToolbarGearMovedToColumn8` is intentionally kept mis-named per STATE.md — only update the `verifyEqual` value, not the method name.
**Warning signs:** CI `TestFastSenseCompanion` failures on `testToolbarGearMovedToColumn8`.

### Pitfall 2: acknowledgeEvent Race (cluster mode)
**What goes wrong:** User A clicks Ack on an event that User B already acked. In single-user mode `acknowledgeEvent` throws `EventStore:unknownEventId` if `events_` was refreshed. In cluster mode it silently continues even if the event isn't in `events_`.
**Why it happens:** Single-user strict check at `EventStore.m:418-425`; cluster tolerates missing event.
**How to avoid:** In the pane's `onAckBtn_` callback, catch `EventStore:unknownEventId` and treat as a no-op (log an info entry; do not uialert — not an error). Let the next `refresh()` call update the list.

### Pitfall 3: uifigure Column Reflow Flicker on First Expand
**What goes wrong:** Setting `ColumnWidth{4}` from 0 to a real value while the uifigure is visible causes a momentary reflow that can flash the panel before the pane is rendered inside it.
**Why it happens:** MATLAB uifigure redraws synchronously on `ColumnWidth` change.
**How to avoid:** Build `hNotifPanel_` and attach `NotificationCenterPane` to it during construction (while `hFig_` is `Visible='off'`), then set `ColumnWidth{4} = 0`. On first expand, `drawnow` after the width change ensures a clean render.

### Pitfall 4: Timer Re-entrancy During Refresh
**What goes wrong:** `onLiveTick_` fires while a previous tick's `refresh()` is still executing (e.g., a slow `getEvents()` merge in cluster mode).
**Why it happens:** `BusyMode='drop'` on `LiveTimer_` (`FastSenseCompanion.m:855`) drops incoming ticks when the timer callback is running — so this should not occur in practice. But `drawnow` inside the callback can release MATLAB's event queue and allow re-entry.
**How to avoid:** Never call `drawnow` inside `NotificationCenterPane.refresh()`. Use lazy update — only update `hTable_.Data` when the diff has changes. Do not call `drawnow` explicitly.

### Pitfall 5: Large Event Arrays (Event Storms)
**What goes wrong:** Thousands of rapid threshold violations produce a huge `events_` array. `getEvents()` in cluster mode reads all NDJSON files on each tick.
**Why it happens:** No server-side filtering; all filtering is client-side.
**How to avoid:** CONTEXT.md defers grouping/storm-collapsing. Mitigate by: (a) cap the displayed inbox at N=200 (configurable); (b) skip `getEvents()` if `numEvents() == 0` (zero-cost check); (c) in cluster mode, consider calling `getEventsForTag(key)` per-tag rather than `getEvents()` if the full merge is too slow (measure first).

### Pitfall 6: MISS_HIT Line Length (160 chars)
**What goes wrong:** Long inline lambdas or sprintf format strings exceed 160 chars.
**How to avoid:** Break at 130 chars when writing callbacks. `mh_style` will catch violations. Run `mh_style --fix` before commit.

### Pitfall 7: Octave Compatibility
**What:** `NotificationCenterPane` uses `uifigure`, `uitable`, `uibutton` — all MATLAB-only (`FastSenseCompanion.m:134-137` already has the Octave error guard). The pane itself does NOT need an Octave guard because the Companion constructor already throws on Octave.
**Warning signs:** Never reference `exist('OCTAVE_VERSION', 'builtin')` inside the pane — trust the Companion's guard.

---

## Code Examples

### Get Unacked Events (verified pattern)

```matlab
% Source: EventStore.m:97-103 (getEvents) + Event.m:43 (AckedAt property)
function evs = getUnackedEvents_(obj, eventStore)
    if isempty(eventStore) || ~isvalid(eventStore)
        evs = Event.empty;
        return;
    end
    all = eventStore.getEvents();
    if isempty(all)
        evs = Event.empty;
        return;
    end
    % Filter: unacked = AckedAt is empty
    mask = false(1, numel(all));
    for i = 1:numel(all)
        ev = all(i);
        if isa(ev, 'Event')
            mask(i) = isempty(ev.AckedAt);
        end
    end
    evs = all(mask);
    % Newest-first by StartTime
    if numel(evs) > 1
        [~, ord] = sort([evs.StartTime], 'descend');
        evs = evs(ord);
    end
end
```

### Acknowledge One Event (verified pattern)

```matlab
% Source: EventStore.m:337-438 (acknowledgeEvent)
function onAckBtn_(obj, eventId)
    try
        opts = struct('comment', '');
        obj.EventStore_.acknowledgeEvent(eventId, opts);
        % In-memory AckedAt is set immediately; next refresh() will remove the row.
    catch ME
        if strcmp(ME.identifier, 'EventStore:unknownEventId')
            % Race: already acked by another Companion. Treat as no-op.
            return;
        end
        rethrow(ME);
    end
end
```

### Ack with Comment Dialog

```matlab
% Source: uiinputdlg pattern used by CompanionEventViewer notes dialog
function onAckWithComment_(obj, eventId, hFig)
    try
        answer = inputdlg('Acknowledgement comment:', 'Acknowledge Event', 1, {''});
        if isempty(answer); return; end
        opts = struct('comment', answer{1});
        obj.EventStore_.acknowledgeEvent(eventId, opts);
    catch ME
        if strcmp(ME.identifier, 'EventStore:unknownEventId'); return; end
        if ~isempty(hFig) && isvalid(hFig)
            uialert(hFig, ME.message, 'Acknowledge Failed', 'Icon', 'error');
        end
    end
end
```

### Severity Color for Badge

```matlab
% Source: EventGanttCanvas.m:285-298 (severityColor) +
%         DashboardTheme (StatusAlarmColor etc.)
function updateBellBadge_(obj, unackedCount, maxSeverity)
    t = obj.Theme_;
    if unackedCount == 0
        obj.hBellBtn_.Text            = char(128276);   % plain bell
        obj.hBellBtn_.BackgroundColor = t.WidgetBorderColor;
        obj.hBellBtn_.FontColor       = t.ForegroundColor;
    else
        obj.hBellBtn_.Text = sprintf('%s (%d)', char(128276), unackedCount);
        switch maxSeverity
            case 3,    obj.hBellBtn_.BackgroundColor = t.StatusAlarmColor;
            case 2,    obj.hBellBtn_.BackgroundColor = t.StatusWarnColor;
            otherwise, obj.hBellBtn_.BackgroundColor = t.Accent;
        end
        obj.hBellBtn_.FontColor = t.DashboardBackground;
    end
end
```

### Column Toggle (show/hide)

```matlab
% Source: rebalanceLogStrip_ pattern (FastSenseCompanion.m:1519-1555)
function setNotifColumnVisible_(obj, tf)
    cw = obj.hLayout_.ColumnWidth;
    if tf
        cw{4} = 320;   % show (Claude's discretion on width)
    else
        cw{4} = 0;     % hide
    end
    obj.hLayout_.ColumnWidth = cw;
end
```

---

## State of the Art

| Old Approach | Current Approach | Notes |
|--------------|------------------|-------|
| `EventStore.loadFile()` for event reads | `EventStore.getEvents()` on live handle | `loadFile` is for standalone tools; Companion uses handle directly |
| `EventViewer` reads `.mat` directly | `CompanionEventViewer.refresh()` calls `store_.getEvents()` | Confirmed at `CompanionEventViewer.m:214` |
| 3-column root grid | Expanding to 4 columns with `{4}=0` hide | `rebalanceLogStrip_` proves this pattern is safe |
| 9-column toolbar grid | 10-column grid (bell at col 8, spacer col 9, gear col 10) | Tests must update col 9→10 gear assertion |

---

## Open Questions

1. **`LiveEventPipeline` EventEmitted/CycleComplete event existence**
   - What we know: `LiveEventPipelines_` are stored and walked in `pollClusterContention_` (`FastSenseCompanion.m:2207`).
   - What's unclear: Whether `LiveEventPipeline` fires a MATLAB `notify` event on detection so the pane can listen for sub-tick latency.
   - Recommendation: Before Wave 1, `grep -n "events\|notify" libs/EventDetection/LiveEventPipeline.m`. If a suitable event exists, add a listener in the Companion constructor. If not, the 1s LiveTimer_ tick is sufficient for v1.

2. **Bell glyph Octave/cross-platform rendering**
   - What we know: Unicode `char(128276)` (U+1F514 BELL) renders on macOS. Windows MATLAB and headless CI may not render emoji glyphs in `uibutton.Text`.
   - Recommendation: Use an ASCII fallback glyph (e.g., `'[!]'`) if `usejava('desktop')` returns false or if CI reports rendering issues. Alternatively use `char(9665)` (a simpler bell-adjacent glyph). This is Claude's discretion.

3. **`acknowledgeEvent` single-user no-save behavior**
   - What we know: In single-user mode, `acknowledgeEvent` mutates in-memory and appends to `acks_`, but does NOT call `save()` (`EventStore.m:428-436`). Persistence requires an explicit `save()` call.
   - What's unclear: Whether the pane should call `obj.EventStore_.save()` after each ack, or leave persistence to the pipeline's natural `save()` rhythm.
   - Recommendation: Call `save()` after each ack in single-user mode to ensure the ack survives a crash. Wrap in try/catch — save failure is non-fatal for the UI but should log an entry.

---

## Environment Availability

This phase is pure MATLAB code additions — no external tools, databases, or CLIs beyond what already runs in the project. Step 2.6 SKIPPED (no external dependencies identified).

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | MATLAB `matlab.unittest.TestCase` (class-based) + flat `test_*.m` scripts |
| Config file | `tests/run_all_tests.m` (discovers both) |
| Quick run command | `run_matlab_test_file('tests/suite/TestNotificationCenterPane.m')` |
| Full suite command | `run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` then `run_matlab_test_file('tests/suite/TestNotificationCenterPane.m')` |

**Note on execution (from project memory):** Class suites (`Test*.m`) use `mcp__matlab__run_matlab_test_file`; flat `test_*.m` use `mcp__matlab__evaluate_matlab_code` with the file path.

### Phase Requirements → Test Map

| Behavior | Test Type | Test File | Automated Command |
|----------|-----------|-----------|-------------------|
| `NotificationCenterPane` construct/attach/detach lifecycle | unit | `TestNotificationCenterPane.m` | `run_matlab_test_file('tests/suite/TestNotificationCenterPane.m')` |
| `IsAttached` state machine + `DetachRequested` event | unit | `TestNotificationCenterPane.m` | (same) |
| Buffer preserved across detach/reattach | unit | `TestNotificationCenterPane.m` | (same) |
| `refresh(eventStore)` filters unacked correctly | unit (stub ES) | `test_notification_center_pane.m` | `evaluate_matlab_code('run(''tests/test_notification_center_pane.m'')')` |
| Diff by Event.Id — no flicker on unchanged list | unit (stub ES) | `test_notification_center_pane.m` | (same) |
| Ack call dispatched to EventStore | unit (stub ES) | `test_notification_center_pane.m` | (same) |
| Ack race (`unknownEventId`) handled as no-op | unit (stub ES) | `test_notification_center_pane.m` | (same) |
| Bell badge count + color reflects unacked set | unit (stub ES) | `test_notification_center_pane.m` | (same) |
| Column 4 show/hide via ColumnWidth toggle | integration | `TestFastSenseCompanion.m` | `run_matlab_test_file('tests/suite/TestFastSenseCompanion.m')` |
| Bell button at new toolbar col 8; gear at col 10 | integration | `TestFastSenseCompanion.m` | (same) |
| Bell disabled when EventStore_ is [] | integration | `TestFastSenseCompanion.m` | (same) |
| `onLiveTick_` calls `NotifPane_.refresh()` | integration | `TestFastSenseCompanion.m` | (same) |
| Theme propagated to pane on `applyTheme` | unit | `TestNotificationCenterPane.m` | (same) |

### Recommended Stub: `StubEventStore`

Model on `CaptureNotificationService.m` (`tests/CaptureNotificationService.m`). The stub is a pure-logic helper that allows testing the pane without a real EventStore:

```matlab
classdef StubEventStore < handle
    properties
        Events_       = Event.empty   % configure in test setup
        AckedIds_     = {}            % track which Ids were acked
        ThrowOnAck_   = false         % inject unknownEventId error
    end
    methods
        function evs = getEvents(obj); evs = obj.Events_; end
        function n = numEvents(obj);   n = numel(obj.Events_); end
        function ack = acknowledgeEvent(obj, eventId, ~)
            if obj.ThrowOnAck_
                error('EventStore:unknownEventId', 'stub throw');
            end
            obj.AckedIds_{end+1} = eventId;
            % Mutate the in-memory Event (mirror real EventStore behavior):
            for i = 1:numel(obj.Events_)
                if strcmp(obj.Events_(i).Id, eventId)
                    obj.Events_(i).AckedAt = now;
                    break;
                end
            end
            ack = struct('eventId', eventId, 'action', 'ack');
        end
    end
end
```

Location: `tests/suite/StubEventStore.m` (or `tests/StubEventStore.m` — match project convention for flat tests).

### Wave 0 Gaps

- [ ] `tests/suite/TestNotificationCenterPane.m` — class-based lifecycle suite (covers attach/detach/DetachRequested/theme)
- [ ] `tests/test_notification_center_pane.m` — flat pure-logic tests (covers refresh/diff/ack/badge using `StubEventStore`)
- [ ] `tests/suite/StubEventStore.m` (or `tests/StubEventStore.m`) — test double for EventStore
- [ ] Update `tests/suite/TestFastSenseCompanion.m`: `testToolbarGearMovedToColumn8` assert value `9 → 10`; add bell-col-8 assertion; add notification-pane integration tests

---

## Project Constraints (from CLAUDE.md)

| Directive | Impact on This Phase |
|-----------|---------------------|
| Pure MATLAB (no external dependencies) | No new libraries; all UI via MATLAB `uifigure` primitives |
| MATLAB R2020b+ (no Octave for Companion) | Companion constructor already throws on Octave; pane inherits this guard |
| Naming: PascalCase classes, camelCase methods | `NotificationCenterPane.m`, `attach()`, `detach()`, `refresh()` |
| Properties: `SetAccess = private` internal state | Follow `EventsLogPane.m` property block layout exactly |
| Error IDs: `FastSenseCompanion:*` | All errors from the Companion layer; pane uses `NotificationCenterPane:*` |
| Callbacks: try/catch + non-blocking `uialert` | Every button callback, refresh, ack must be wrapped |
| `Listeners_` cell array on every class with `addlistener` | `NotificationCenterPane` must have `Listeners_` + delete in `detach()` |
| `stop(t); delete(t)` in that order for timers | No new timers in this phase |
| Companion is the only `uifigure`; spawned figures are classical `figure` | The detached notification window is a `uifigure` (matches EventsLogPane detach pattern — `setLogState_` at `FastSenseCompanion.m:1488` uses `uifigure`) |
| `axes(uipanel)` not `uiaxes(uipanel)` | Not applicable — pane is table-based, no axes |
| MISS_HIT: 160 char max, tab=4, cyclomatic ≤80, max fn ≤520 lines | Enforce on `NotificationCenterPane.m` |
| Tests run via MCP: class suites via `run_matlab_test_file`; flat via `evaluate_matlab_code` | Follow per project memory note |

---

## Sources

### Primary (HIGH confidence)

| Source | Lines/Topics Verified |
|--------|----------------------|
| `libs/EventDetection/EventStore.m` | Full file read: `getEvents()` L97, `acknowledgeEvent()` L337, `numEvents()` L280, `getAckRecordsForEvent()` L440, `loadFile()` L463, `busyRetryWrap_()` L511, in-memory mutation L405-411, single-user acks_ L428-436 |
| `libs/EventDetection/Event.m` | Full file read: `AckedAt` L43, `AckedBy` L44, `AckComment` L45, `Severity` L36, `IsOpen` L38, `Id` L37, `computeDisplayState()` L125-151, `fromStructSafe()` L154 |
| `libs/FastSenseCompanion/FastSenseCompanion.m` | Lines 1-534 (constructor + grid + toolbar), 1665-1691 (`onLiveTick_`), 1519-1555 (`rebalanceLogStrip_`), 1821-1851 (`openEventViewer_`), 1665 (`onLiveTick_` hook point), 298-439 (full grid construction) |
| `libs/FastSenseCompanion/EventsLogPane.m` | Full file read: constructor, `attach()`, `detach()`, `addLogEntry()`, `applyTheme()`, `DetachRequested` event, `LogPaneRoot` tag rule, `bufferSize()`/`peekLogRow()` test helpers |
| `libs/FastSenseCompanion/EventGanttCanvas.m` | `severityColor()` L285-298: green/orange/red RGB values |
| `libs/FastSenseCompanion/CompanionTheme.m` | Full file: `StatusOkColor`, `StatusWarnColor`, `StatusAlarmColor`, `Accent` fields |
| `libs/FastSenseCompanion/CompanionEventViewer.m` | `refresh()` L211-222: calls `Store_.getEvents()`, confirming correct pattern |
| `tests/suite/TestEventsLogPane.m` | Full file: test helper pattern (`makePane_`), `uifigure('Visible','off')` idiom, `addTeardown`, headless guard |
| `tests/suite/TestFastSenseCompanion.m` | L1252-1281: toolbar column assertions; L1086-1161: EventStore DI tests; L1-40: suite setup/guards |
| `tests/CaptureNotificationService.m` | Full file: stub pattern to replicate for `StubEventStore` |
| `.planning/config.json` | `nyquist_validation: true` → Validation Architecture section required |

### Secondary (MEDIUM confidence)

- STATE.md: confirmed v4.0 phases 1029-1033 shipped; toolbar is now 1x9 post-PR-#159 (260526-tcf entry confirming Wiki at col 7, gear at col 9); Phase 1040 added 2026-06-02.
- REQUIREMENTS.md: ACK-01 (~5s propagation), ACK-02 (three-state visual), ACK-03 (comment), IDENT-02 (audit trail) — all implemented in Phase 1032.

---

## Metadata

**Confidence breakdown:**
- EventStore API: HIGH — full source read, all method signatures verified
- Companion grid layout: HIGH — constructor source read line by line
- Pane detach pattern: HIGH — EventsLogPane + setLogState_ both read in full
- Severity colors: HIGH — EventGanttCanvas.severityColor + DashboardTheme both read
- Test infrastructure: HIGH — TestEventsLogPane + TestFastSenseCompanion both read
- Toolbar badge (no native MATLAB badge): MEDIUM — Unicode glyph rendering on non-macOS is LOW confidence; recommend ASCII fallback

**Research date:** 2026-06-02
**Valid until:** 2026-07-02 (stable MATLAB API; 30 days)
