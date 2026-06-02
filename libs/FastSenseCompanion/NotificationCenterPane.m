classdef NotificationCenterPane < handle
%NOTIFICATIONCENTERPANE Acknowledgeable notification inbox pane for FastSenseCompanion.
%
%   Self-contained handle class that owns a live "inbox" of UNACKED
%   threshold-violation events read from the shared EventStore. A sibling to
%   EventsLogPane: it attaches into either a uipanel (inline, embedded in the
%   companion's collapsible 4th column) or a uifigure (detached, its own
%   window), fires DetachRequested on the pop-out icon, and preserves its
%   last-good event set + filter selection across attach/detach round-trips.
%
%   Unlike the append-only EventsLogPane, this pane is ack-driven: each row is
%   one unacked Event; acknowledging it (EventStore.acknowledgeEvent) removes
%   it from the inbox on the next refresh and decrements the toolbar bell
%   badge. The pane does NOT own a timer — FastSenseCompanion.onLiveTick_
%   drives refresh (wired in Plan 03).
%
%   Usage (called by FastSenseCompanion):
%     pane = NotificationCenterPane(theme);
%     pane.setCompanion(companion);
%     pane.attach(parent, theme);          % parent: uipanel or uifigure
%     pane.refresh(companion.getEventStore());
%     pane.detach();                        % UI released; last-good list preserved
%
%   Events fired:
%     DetachRequested — fired when the user clicks the inline pop-out icon.
%
%   Static helpers (pure; no UI, no EventStore calls):
%     filterUnacked_ / sortNewestFirst_ / maxSeverity_ / idsOf_ / diffIds_ /
%     badgeText_ / badgeColor_
%
%   See also EventsLogPane, EventStore, Event, CompanionTheme, EventGanttCanvas.

    events
        DetachRequested  % fired when user clicks the inline pop-out icon
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_    = []           % resolved CompanionTheme struct
        hRoot_          = []           % outer uigridlayout ([3 1] grid)
        hTable_         = []           % uitable for the inbox rows
        hSevDD_         = []           % uidropdown severity filter
        hSearch_        = []           % uieditfield (free-text filter)
        hAckAllBtn_     = []           % "Acknowledge all visible" uibutton
        hLastUpdateLbl_ = []           % "Updated: HH:MM:SS" label
        hPopoutBtn_     = []           % pop-out icon uibutton
        Companion_      = []           % FastSenseCompanion handle (or [])
        LastGoodEvents_ = Event.empty  % last successfully-read unacked set (survives detach)
        LastIds_        = {}           % cellstr of LastGoodEvents_ ids (diff key)
        Listeners_      = {}           % addlistener handles; deleted on teardown
        IsStale_        = false        % true when the last EventStore read failed
        SevFilter_      = 'All'        % preserved severity-dropdown selection
        SearchText_     = ''           % preserved free-text filter
        RowEventIds_    = {}           % row -> Event.Id map for the current render
        RowSevColors_   = []           % Nx3 severity dot colors (Gantt-consistent)
    end

    methods (Access = public)

        function obj = NotificationCenterPane(themeStruct)
        %NOTIFICATIONCENTERPANE Construct with an initial theme. UI is NOT built — call attach().
        %   themeStruct — resolved CompanionTheme struct.
            if nargin < 1 || ~isstruct(themeStruct)
                error('NotificationCenterPane:invalidTheme', ...
                    'NotificationCenterPane requires a CompanionTheme struct as first argument.');
            end
            obj.ThemeStruct_    = themeStruct;
            obj.IsAttached      = false;
            obj.LastGoodEvents_ = Event.empty;
            obj.LastIds_        = {};
            obj.Listeners_      = {};
            obj.IsStale_        = false;
        end

        function setCompanion(obj, companion)
        %SETCOMPANION Cache the FastSenseCompanion handle (drives ack store + log routing).
            obj.Companion_ = companion;
        end

        function attach(obj, parent, themeStruct)
        %ATTACH Build the inbox UI inside parent (uipanel or uifigure).
        %   Idempotent: returns early if already attached. Restores the
        %   preserved filter selection and repaints last-good rows.
            if obj.IsAttached; return; end
            if nargin >= 3 && isstruct(themeStruct)
                obj.ThemeStruct_ = themeStruct;
            end
            if isempty(parent) || ~isvalid(parent)
                error('NotificationCenterPane:invalidParent', ...
                    'NotificationCenterPane.attach requires a valid uipanel or uifigure parent.');
            end
            t = obj.ThemeStruct_;

            % --- Root [3 1] layout: header / bulk button / inbox table ---
            obj.hRoot_ = uigridlayout(parent, [3 1]);
            obj.hRoot_.RowHeight       = {28, 24, '1x'};
            obj.hRoot_.ColumnWidth     = {'1x'};
            obj.hRoot_.Padding         = [8 4 8 4];
            obj.hRoot_.RowSpacing      = 4;
            obj.hRoot_.BackgroundColor = t.WidgetBackground;

            % --- Row 1: header strip [1 6] ---
            gHdr = uigridlayout(obj.hRoot_, [1 6]);
            gHdr.Layout.Row    = 1;
            gHdr.Layout.Column = 1;
            gHdr.ColumnWidth   = {60, '1x', 100, 120, 36, 36};
            gHdr.RowHeight     = {'1x'};
            gHdr.Padding       = [0 0 0 0];
            gHdr.ColumnSpacing = 8;
            gHdr.BackgroundColor = t.WidgetBackground;

            hLbl = uilabel(gHdr);
            hLbl.Layout.Row = 1; hLbl.Layout.Column = 1;
            hLbl.Text = 'Notifications'; hLbl.FontWeight = 'bold'; hLbl.FontSize = 11;
            hLbl.FontColor = t.ForegroundColor;
            hLbl.HorizontalAlignment = 'left'; hLbl.VerticalAlignment = 'center';

            obj.hSearch_ = uieditfield(gHdr, 'text');
            obj.hSearch_.Layout.Row = 1; obj.hSearch_.Layout.Column = 2;
            % Placeholder is R2021a+; tolerated on R2020b.
            try
                obj.hSearch_.Placeholder = ['Filter notifications', char(8230)];
            catch
            end
            obj.hSearch_.FontSize = 11;
            obj.hSearch_.Value = obj.SearchText_;            % restore preserved filter
            obj.hSearch_.ValueChangedFcn = @(~,~) obj.applyFilterAndRender_();

            obj.hSevDD_ = uidropdown(gHdr);
            obj.hSevDD_.Layout.Row = 1; obj.hSevDD_.Layout.Column = 3;
            obj.hSevDD_.Items = {'All', 'Alarm', 'Warn', 'Info'};
            obj.hSevDD_.Value = obj.SevFilter_;              % restore preserved filter
            obj.hSevDD_.FontSize = 11;
            obj.hSevDD_.Tooltip = 'Filter by severity';
            obj.hSevDD_.ValueChangedFcn = @(~,~) obj.applyFilterAndRender_();

            obj.hLastUpdateLbl_ = uilabel(gHdr);
            obj.hLastUpdateLbl_.Layout.Row = 1; obj.hLastUpdateLbl_.Layout.Column = 4;
            obj.hLastUpdateLbl_.Text = 'Updated: --:--:--';
            obj.hLastUpdateLbl_.FontSize = 11; obj.hLastUpdateLbl_.FontName = 'Menlo';
            obj.hLastUpdateLbl_.FontColor = t.PlaceholderTextColor;
            obj.hLastUpdateLbl_.HorizontalAlignment = 'right';
            obj.hLastUpdateLbl_.VerticalAlignment = 'center';

            obj.hPopoutBtn_ = uibutton(gHdr, 'push');
            obj.hPopoutBtn_.Layout.Row = 1; obj.hPopoutBtn_.Layout.Column = 5;
            obj.hPopoutBtn_.Text            = char(8689);    % pop-out arrow glyph
            obj.hPopoutBtn_.FontSize        = 14;
            obj.hPopoutBtn_.Tooltip         = 'Detach notification center to its own window';
            obj.hPopoutBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hPopoutBtn_.FontColor       = t.ForegroundColor;
            obj.hPopoutBtn_.ButtonPushedFcn = @(~,~) notify(obj, 'DetachRequested');
            % Col 6 reserved/empty (keeps symmetry with EventsLogPane [1 6]).

            % --- Row 2: bulk "Acknowledge all visible" button ---
            obj.hAckAllBtn_ = uibutton(obj.hRoot_, 'push');
            obj.hAckAllBtn_.Layout.Row      = 2;
            obj.hAckAllBtn_.Text            = 'Acknowledge all visible';
            obj.hAckAllBtn_.FontSize        = 11;
            obj.hAckAllBtn_.BackgroundColor = t.WidgetBorderColor;  % -> Accent when count > 0
            obj.hAckAllBtn_.FontColor       = t.ForegroundColor;
            obj.hAckAllBtn_.ButtonPushedFcn = @(~,~) obj.onAckAll_();

            % --- Row 3: inbox uitable ---
            % UI-checker fold-in: Status column is 56 px (was 55). Start stays 90 px because the
            % monospace 'HH:MM:SS dd-mmm' string needs the width (UI-checker suggested 88; single
            % intentional deviation, recorded in the SUMMARY). uitable row height is ~20 px platform
            % default in R2020b and LineHeight is NOT settable on uitable, so no per-row override.
            isDark = mean(t.DashboardBackground) < 0.5;
            if isDark
                stripePair = [0.13 0.13 0.13; 0.20 0.20 0.20];
            else
                stripePair = [1.00 1.00 1.00; 0.94 0.94 0.94];
            end
            obj.hTable_ = uitable(obj.hRoot_);
            obj.hTable_.Layout.Row     = 3;
            obj.hTable_.ColumnName     = {'', 'Sensor', 'Threshold', 'Peak', 'Start', 'Status', '', ''};
            obj.hTable_.ColumnWidth    = {12, 'auto', 'auto', 70, 90, 56, 28, 36};
            obj.hTable_.ColumnEditable = false(1, 8);
            obj.hTable_.RowName        = {};
            obj.hTable_.FontSize       = 10;
            obj.hTable_.FontName       = 'Menlo';
            obj.hTable_.ForegroundColor = t.ForegroundColor;
            obj.hTable_.BackgroundColor = stripePair;
            % NOTE: the uifigure uitable cell-selection property is CellSelectionCallback
            % (matches EventViewer.m); the planning docs' CellSelectionChangedFcn does not exist.
            obj.hTable_.CellSelectionCallback = @(src, ev) obj.onCellSelected_(ev);

            obj.IsAttached = true;
            obj.renderTable_();   % repaint last-good rows so re-attach is non-destructive
        end

        function detach(obj)
        %DETACH Destroy UI handles. LastGoodEvents_/LastIds_/filter preserved.
            if ~obj.IsAttached; return; end
            % Capture the filter selection BEFORE nulling handles (survives reattach).
            try
                if ~isempty(obj.hSevDD_) && isvalid(obj.hSevDD_)
                    obj.SevFilter_ = obj.hSevDD_.Value;
                end
                if ~isempty(obj.hSearch_) && isvalid(obj.hSearch_)
                    obj.SearchText_ = obj.hSearch_.Value;
                end
            catch
                % Filter capture is best-effort.
            end
            try
                if ~isempty(obj.hRoot_) && isvalid(obj.hRoot_)
                    delete(obj.hRoot_);
                end
            catch
                % Never propagate teardown errors.
            end
            obj.hRoot_          = [];
            obj.hTable_         = [];
            obj.hSevDD_         = [];
            obj.hSearch_        = [];
            obj.hAckAllBtn_     = [];
            obj.hLastUpdateLbl_ = [];
            obj.hPopoutBtn_     = [];
            obj.IsAttached      = false;
            % LastGoodEvents_, LastIds_, SevFilter_, SearchText_ deliberately preserved.
        end

        function refresh(obj, eventStore)
        %REFRESH Pull unacked events, diff by Id, render newest-first.
        %   Driven by FastSenseCompanion.onLiveTick_ (no timer in this pane).
        %   On an EventStore read error: keep the last-good list + show a
        %   (stale) marker; never clear the inbox and never uialert.
            if ~obj.IsAttached; return; end
            if isempty(eventStore) || ~isvalid(eventStore)
                obj.LastGoodEvents_ = Event.empty;
                obj.LastIds_        = {};
                obj.IsStale_        = false;
                obj.applyFilterAndRender_();
                obj.setUpdatedLabel_(datetime('now'), false);
                return;
            end
            allEvents = Event.empty;
            readOk = true;
            try
                allEvents = eventStore.getEvents();
            catch
                readOk = false;
            end
            if ~readOk
                % Stale path — keep last-good, mark stale, no uialert, no clear.
                obj.IsStale_ = true;
                obj.setUpdatedLabel_(datetime('now'), true);
                if ~isempty(obj.Companion_) && isvalid(obj.Companion_) && ...
                        ismethod(obj.Companion_, 'addLogEntry')
                    try
                        obj.Companion_.addLogEntry('warn', ...
                            'Notification center: EventStore read failed; showing last-good list.');
                    catch
                    end
                end
                return;
            end
            obj.IsStale_ = false;
            unacked = NotificationCenterPane.sortNewestFirst_( ...
                NotificationCenterPane.filterUnacked_(allEvents));
            if numel(unacked) > 200
                unacked = unacked(1:200);   % row cap (RESEARCH Pitfall 5)
            end
            newIds = NotificationCenterPane.idsOf_(unacked);
            if ~NotificationCenterPane.diffIds_(newIds, obj.LastIds_)
                % No change — refresh the timestamp only (no flicker; no forced redraw — Pitfall 4).
                obj.setUpdatedLabel_(datetime('now'), false);
                return;
            end
            obj.LastGoodEvents_ = unacked;
            obj.LastIds_        = newIds;
            obj.applyFilterAndRender_();
            obj.setUpdatedLabel_(datetime('now'), false);
        end

        function applyTheme(obj, themeStruct)
        %APPLYTHEME Live theme switch — restyle existing UI, re-assert pane accents.
            if ~isstruct(themeStruct); return; end
            obj.ThemeStruct_ = themeStruct;
            if ~obj.IsAttached || isempty(obj.hRoot_) || ~isvalid(obj.hRoot_)
                return;
            end
            try
                t = themeStruct;
                obj.hRoot_.BackgroundColor = t.WidgetBackground;
                applyThemeToChildren_(obj.hRoot_, themeStruct);
                % Re-assert pane-specific accents the generic walker overwrites.
                if ~isempty(obj.hLastUpdateLbl_) && isvalid(obj.hLastUpdateLbl_)
                    if obj.IsStale_
                        obj.hLastUpdateLbl_.FontColor = t.StatusWarnColor;
                    else
                        obj.hLastUpdateLbl_.FontColor = t.PlaceholderTextColor;
                    end
                end
                if ~isempty(obj.hPopoutBtn_) && isvalid(obj.hPopoutBtn_)
                    obj.hPopoutBtn_.BackgroundColor = t.WidgetBorderColor;
                    obj.hPopoutBtn_.FontColor       = t.ForegroundColor;
                end
                isDark = mean(t.DashboardBackground) < 0.5;
                if isDark
                    stripePair = [0.13 0.13 0.13; 0.20 0.20 0.20];
                else
                    stripePair = [1.00 1.00 1.00; 0.94 0.94 0.94];
                end
                if ~isempty(obj.hTable_) && isvalid(obj.hTable_)
                    obj.hTable_.BackgroundColor = stripePair;
                    obj.hTable_.ForegroundColor = t.ForegroundColor;
                end
                obj.applyFilterAndRender_();   % recolor bulk button under new tokens
            catch
                % Theme application must never propagate errors.
            end
        end

        function requestDetach(obj)
        %REQUESTDETACH Programmatic equivalent of clicking the pop-out icon.
            notify(obj, 'DetachRequested');
        end

        function delete(obj)
        %DELETE Handle destructor — detach() for safety.
            try
                if obj.IsAttached
                    obj.detach();
                end
            catch
                % Destructor must never throw.
            end
        end

    end

    methods (Access = private)

        function applyFilterAndRender_(obj)
        %APPLYFILTERANDRENDER_ Apply severity + text filter to LastGoodEvents_, render, recolor.
            events = obj.LastGoodEvents_;
            % Severity filter (client-side; does not re-fetch).
            sev = obj.SevFilter_;
            if ~isempty(obj.hSevDD_) && isvalid(obj.hSevDD_)
                sev = obj.hSevDD_.Value;
            end
            if ~isempty(events) && ~strcmp(sev, 'All')
                switch sev
                    case 'Alarm', wanted = 3;
                    case 'Warn',  wanted = 2;
                    case 'Info',  wanted = 1;
                    otherwise,    wanted = [];
                end
                if ~isempty(wanted)
                    events = events([events.Severity] == wanted);
                end
            end
            % Free-text filter over SensorName + ThresholdLabel (case-insensitive).
            qry = obj.SearchText_;
            if ~isempty(obj.hSearch_) && isvalid(obj.hSearch_)
                qry = obj.hSearch_.Value;
            end
            qry = strtrim(qry);
            if ~isempty(events) && ~isempty(qry)
                qLow = lower(qry);
                mask = false(1, numel(events));
                for i = 1:numel(events)
                    line = lower([events(i).SensorName, ' ', events(i).ThresholdLabel]);
                    mask(i) = ~isempty(strfind(line, qLow)); %#ok<STREMP>
                end
                events = events(mask);
            end
            obj.renderTable_(events);
            % Recolor the bulk button: Accent when something is visible, else idle.
            if ~isempty(obj.hAckAllBtn_) && isvalid(obj.hAckAllBtn_)
                if ~isempty(events)
                    obj.hAckAllBtn_.BackgroundColor = obj.ThemeStruct_.Accent;
                else
                    obj.hAckAllBtn_.BackgroundColor = obj.ThemeStruct_.WidgetBorderColor;
                end
            end
        end

        function renderTable_(obj, events)
        %RENDERTABLE_ Paint the inbox uitable (default events = LastGoodEvents_).
            if isempty(obj.hTable_) || ~isvalid(obj.hTable_); return; end
            if nargin < 2
                events = obj.LastGoodEvents_;
            end
            if isempty(events)
                % Empty-state copy LOCKED (UI-SPEC). Ack columns blank to avoid clicks.
                obj.hTable_.Data = {'', '', 'No unacknowledged events', '', '', '', '', ''};
                obj.RowEventIds_  = {};
                obj.RowSevColors_ = [];
                return;
            end
            n = numel(events);
            data      = cell(n, 8);
            ids       = cell(1, n);
            sevColors = zeros(n, 3);
            bullet    = char(9679);   % severity dot glyph (uitable can't set per-cell bg in R2020b)
            for i = 1:n
                ev = events(i);
                data{i, 1} = bullet;
                data{i, 2} = ev.SensorName;
                data{i, 3} = ev.ThresholdLabel;
                pk = '';
                try
                    if ~isempty(ev.PeakValue)
                        pk = sprintf('%.3g', ev.PeakValue);
                    end
                catch
                    % Peak is optional; leave blank if unavailable.
                end
                data{i, 4} = pk;
                data{i, 5} = datestr(ev.StartTime, 'HH:MM:SS dd-mmm'); %#ok<DATST>
                if ev.IsOpen
                    data{i, 6} = 'LIVE';
                else
                    data{i, 6} = 'closed';
                end
                data{i, 7} = 'Ack';
                data{i, 8} = '...';
                ids{i} = ev.Id;
                % Gantt-consistent severity color (stored; uitable limits per-cell coloring).
                sevColors(i, :) = EventGanttCanvas.severityColor(ev.Severity);
            end
            obj.hTable_.Data  = data;
            obj.RowEventIds_  = ids;
            obj.RowSevColors_ = sevColors;
        end

        function onCellSelected_(obj, ev)
        %ONCELLSELECTED_ Dispatch a table cell click: col 7 ack, col 8 ack-with-comment, else viewer.
            try
                if isempty(obj.LastGoodEvents_); return; end   % empty-state click = no-op
                if isempty(ev.Indices); return; end
                r   = ev.Indices(1);
                cdx = ev.Indices(2);
                if r < 1 || r > numel(obj.RowEventIds_); return; end
                eid = obj.RowEventIds_{r};
                if cdx == 7
                    obj.onAckBtn_(eid);
                elseif cdx == 8
                    obj.onAckWithComment_(eid);
                else
                    % Best-effort row-click -> Event Viewer. openEventViewer_ is private on
                    % FastSenseCompanion today, so this is guarded: a benign row-click must
                    % never alert. Becomes active once a public entry point exists.
                    try
                        if ~isempty(obj.Companion_) && isvalid(obj.Companion_) && ...
                                ismethod(obj.Companion_, 'openEventViewer_')
                            obj.Companion_.openEventViewer_();
                        end
                    catch
                        % Private-access or viewer errors must not disrupt selection.
                    end
                end
            catch ME
                obj.alertSafe_(ME, 'Acknowledge Failed');
            end
        end

        function onAckBtn_(obj, eventId)
        %ONACKBTN_ One-click acknowledge; EventStore:unknownEventId race -> silent no-op.
            try
                obj.ackOne_(eventId);
            catch ME
                if strcmp(ME.identifier, 'EventStore:unknownEventId')
                    return;   % already acked elsewhere — no-op
                end
                obj.alertSafe_(ME, 'Acknowledge Failed');
            end
        end

        function onAckWithComment_(obj, eventId)
        %ONACKWITHCOMMENT_ Prompt for a comment then acknowledge.
            answer = inputdlg('Acknowledgement comment:', 'Acknowledge Event', 1, {''});
            if isempty(answer); return; end   % cancel
            try
                obj.ackOne_(eventId, answer{1});
            catch ME
                if strcmp(ME.identifier, 'EventStore:unknownEventId')
                    return;
                end
                obj.alertSafe_(ME, 'Acknowledge Failed');
            end
        end

        function onAckAll_(obj)
        %ONACKALL_ Acknowledge every currently-visible event; per-item race -> no-op.
            try
                ids = obj.RowEventIds_;
                for i = 1:numel(ids)
                    try
                        obj.ackOne_(ids{i});
                    catch ME
                        if strcmp(ME.identifier, 'EventStore:unknownEventId')
                            continue;   % per-item race — skip
                        end
                        obj.alertSafe_(ME, 'Acknowledge Failed');
                        break;
                    end
                end
            catch ME
                obj.alertSafe_(ME, 'Acknowledge Failed');
            end
        end

        function ackOne_(obj, eventId, comment)
        %ACKONE_ Resolve the store via the Companion and acknowledge one event.
        %   Single-user acknowledgeEvent does not auto-save; save() after a
        %   successful ack so it survives a crash (save failure is non-fatal).
            opts = struct('comment', '');
            if nargin > 2 && ~isempty(comment)
                opts.comment = comment;
            end
            if isempty(obj.Companion_) || ~isvalid(obj.Companion_)
                error('NotificationCenterPane:noEventStore', ...
                    'No Companion/EventStore available to acknowledge the event.');
            end
            store = obj.Companion_.getEventStore();
            store.acknowledgeEvent(eventId, opts);
            try
                store.save();
            catch
                if ~isempty(obj.Companion_) && isvalid(obj.Companion_) && ...
                        ismethod(obj.Companion_, 'addLogEntry')
                    try
                        obj.Companion_.addLogEntry('warn', ...
                            'Notification center: ack saved in memory but EventStore.save() failed.');
                    catch
                    end
                end
            end
        end

        function setUpdatedLabel_(obj, dt, isStale)
        %SETUPDATEDLABEL_ Shared path for the "Updated:" label (normal + stale).
            if isempty(obj.hLastUpdateLbl_) || ~isvalid(obj.hLastUpdateLbl_); return; end
            try
                if isa(dt, 'datetime')
                    txt = char(dt, 'HH:mm:ss');
                elseif ischar(dt) || (isstring(dt) && isscalar(dt))
                    txt = char(dt);
                else
                    txt = char(datetime('now', 'Format', 'HH:mm:ss'));
                end
                if isStale
                    obj.hLastUpdateLbl_.Text      = sprintf('Updated: %s (stale)', txt);
                    obj.hLastUpdateLbl_.FontColor = obj.ThemeStruct_.StatusWarnColor;
                else
                    obj.hLastUpdateLbl_.Text      = sprintf('Updated: %s', txt);
                    obj.hLastUpdateLbl_.FontColor = obj.ThemeStruct_.PlaceholderTextColor;
                end
            catch
                % Label update must never crash the UI.
            end
        end

        function alertSafe_(obj, ME, title)
        %ALERTSAFE_ Non-blocking uialert resolving the figure via ancestor(hRoot_).
            if nargin < 3; title = 'Notification Center'; end
            try
                fig = ancestor(obj.hRoot_, 'figure');
                if ~isempty(fig) && isvalid(fig)
                    uialert(fig, ME.message, title, 'Icon', 'error');
                end
            catch
                % Alert is best-effort; never throw from an error handler.
            end
        end

    end

    methods (Static)

        function evs = filterUnacked_(allEvents)
        %FILTERUNACKED_ Keep only events that are still unacknowledged.
        %   An event is unacked iff AckedAt is empty OR all-NaN (mirrors
        %   Event.computeDisplayState). Empty input returns an empty Event array.
            if isempty(allEvents)
                evs = Event.empty;
                return;
            end
            mask = false(1, numel(allEvents));
            for i = 1:numel(allEvents)
                a = allEvents(i).AckedAt;
                mask(i) = isempty(a) || (isnumeric(a) && all(isnan(a)));
            end
            evs = allEvents(mask);
        end

        function evs = sortNewestFirst_(events)
        %SORTNEWESTFIRST_ Order events by StartTime, newest first.
            if numel(events) > 1
                [~, ord] = sort([events.StartTime], 'descend');
                evs = events(ord);
            else
                evs = events;
            end
        end

        function s = maxSeverity_(events)
        %MAXSEVERITY_ Highest Severity across events (0 for an empty set).
            if isempty(events)
                s = 0;
            else
                s = max([events.Severity]);
            end
        end

        function ids = idsOf_(events)
        %IDSOF_ Return a cellstr of the events' Id fields ({} for empty input).
            if isempty(events)
                ids = {};
            else
                ids = arrayfun(@(e) e.Id, events, 'UniformOutput', false);
            end
        end

        function changed = diffIds_(newIds, oldIds)
        %DIFFIDS_ True when the two id sets differ (order-insensitive).
        %   {} vs {} -> false. Reordering the same ids -> false.
            if isempty(newIds), newIds = {}; end
            if isempty(oldIds), oldIds = {}; end
            changed = ~isequal(sort(newIds(:)), sort(oldIds(:)));
        end

        function txt = badgeText_(count, glyph)
        %BADGETEXT_ Bell glyph alone for zero, else 'glyph (N)'.
            if count <= 0
                txt = glyph;
            else
                txt = sprintf('%s (%d)', glyph, count);
            end
        end

        function rgb = badgeColor_(maxSev, theme)
        %BADGECOLOR_ Map the highest active severity to a theme color token.
        %   Idle/zero-count recoloring to WidgetBorderColor is handled by the
        %   caller (Plan 03); this returns the active-severity color.
            switch maxSev
                case 3
                    rgb = theme.StatusAlarmColor;
                case 2
                    rgb = theme.StatusWarnColor;
                case {0, 1}
                    rgb = theme.Accent;
                otherwise
                    rgb = theme.Accent;
            end
        end

    end
end
