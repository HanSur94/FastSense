classdef EventsLogPane < handle
%EVENTSLOGPANE Detachable events-log pane for FastSenseCompanion.
%
%   Self-contained handle class that owns the events-half of the FastSense
%   Companion's log strip: the events table, the header search field, the
%   level dropdown filter, the "Updated:" timestamp label, the pop-out
%   icon, and the underlying ring-buffer. The pane can be attached to
%   either a uipanel (inline, embedded in the companion) or directly to
%   a uifigure (detached, in its own window). The buffer persists across
%   attach/detach round-trips so re-attaching restores full history.
%
%   The pane is independent of FastSenseCompanion. The companion
%   instantiates it, listens to the DetachRequested event, and forwards
%   log entries via addLogEntry. Pipeline state (per-tag last-seen sample
%   counter map) does NOT live here — that is FastSenseCompanion's
%   responsibility (see Phase 1027 CONTEXT.md "Live-pipeline integration
%   boundary"). The companion-only per-tag sample-counter map also does
%   not live in this class.
%
%   Usage (called by FastSenseCompanion):
%     pane = EventsLogPane(theme);
%     pane.attach(parent, theme);   % parent: uipanel or uifigure
%     pane.addLogEntry('info', 'msg');
%     pane.setLastUpdated(datetime('now'));
%     pane.detach();                % UI handles released; buffer preserved
%
%   Events fired:
%     DetachRequested — fired when the user clicks the inline pop-out icon.
%                       Carries no payload; listener reads pane state if
%                       needed.
%
%   See also FastSenseCompanion, LiveLogPane, CompanionTheme.

    events
        DetachRequested  % fired when user clicks the inline pop-out icon
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_     = []          % resolved CompanionTheme struct
        hRoot_           = []          % outer uigridlayout (the [2 1] grid)
        hLogTable_       = []          % uitable for events log
        hLogSearch_      = []          % uieditfield (search)
        hLogLevelDD_     = []          % uidropdown level filter
        hLastUpdateLbl_  = []          % "Updated: HH:MM:SS" label
        hPopoutBtn_      = []          % pop-out icon uibutton in header col 5
        LogBuffer_       = cell(0, 3)  % {Time, Level, Message} newest first, capped 500
    end

    methods (Access = public)

        function obj = EventsLogPane(themeStruct)
        %EVENTSLOGPANE Construct with an initial theme. UI is NOT built — call attach().
        %   themeStruct — resolved CompanionTheme struct (must have WidgetBackground,
        %                 WidgetBorderColor, ForegroundColor, PlaceholderTextColor,
        %                 Accent, DashboardBackground fields).
            if nargin < 1 || ~isstruct(themeStruct)
                error('EventsLogPane:invalidTheme', ...
                    'EventsLogPane requires a CompanionTheme struct as first argument.');
            end
            obj.ThemeStruct_ = themeStruct;
            obj.LogBuffer_   = cell(0, 3);
            obj.IsAttached   = false;
        end

        function attach(obj, parent, themeStruct)
        %ATTACH Build the events-log UI inside parent (uipanel or uifigure).
        %   parent      — uipanel (inline) or uifigure (detached). Must be valid.
        %   themeStruct — resolved CompanionTheme struct (optional; uses last
        %                 theme if omitted).
        %   Idempotent: if already attached, detaches first. Re-renders any
        %   buffered entries from the existing buffer.
            if nargin >= 3 && isstruct(themeStruct)
                obj.ThemeStruct_ = themeStruct;
            end
            if obj.IsAttached
                obj.detach();
            end
            if isempty(parent) || ~isvalid(parent)
                error('EventsLogPane:invalidParent', ...
                    'EventsLogPane.attach requires a valid uipanel or uifigure parent.');
            end
            t = obj.ThemeStruct_;

            % --- Outer 2-row layout (header / events table) ---
            obj.hRoot_ = uigridlayout(parent, [2 1]);
            obj.hRoot_.RowHeight   = {28, '1x'};
            obj.hRoot_.ColumnWidth = {'1x'};
            obj.hRoot_.Padding     = [8 4 8 4];
            obj.hRoot_.RowSpacing  = 4;
            obj.hRoot_.BackgroundColor = t.WidgetBackground;

            % --- Header (row 1): Events label | search | level dropdown | last-update | pop-out icon ---
            gHdr = uigridlayout(obj.hRoot_, [1 5]);
            gHdr.Layout.Row    = 1;
            gHdr.Layout.Column = 1;
            gHdr.ColumnWidth   = {40, '1x', 100, 150, 36};
            gHdr.RowHeight     = {'1x'};
            gHdr.Padding       = [0 0 0 0];
            gHdr.ColumnSpacing = 8;
            gHdr.BackgroundColor = t.WidgetBackground;

            hLbl = uilabel(gHdr);
            hLbl.Layout.Row = 1; hLbl.Layout.Column = 1;
            hLbl.Text = 'Events'; hLbl.FontWeight = 'bold'; hLbl.FontSize = 11;
            hLbl.FontColor = t.ForegroundColor;
            hLbl.HorizontalAlignment = 'left'; hLbl.VerticalAlignment = 'center';

            obj.hLogSearch_ = uieditfield(gHdr, 'text');
            obj.hLogSearch_.Layout.Row = 1; obj.hLogSearch_.Layout.Column = 2;
            % Placeholder is R2021a+; tolerated on R2020b.
            try, obj.hLogSearch_.Placeholder = ['Search log', char(8230)]; catch, end
            obj.hLogSearch_.FontSize = 11;
            obj.hLogSearch_.ValueChangedFcn = @(~,~) obj.applyLogFilter_();

            obj.hLogLevelDD_ = uidropdown(gHdr);
            obj.hLogLevelDD_.Layout.Row = 1; obj.hLogLevelDD_.Layout.Column = 3;
            obj.hLogLevelDD_.Items = {'All', 'INFO', 'WARN', 'ERROR'};
            obj.hLogLevelDD_.Value = 'All';
            obj.hLogLevelDD_.FontSize = 11;
            obj.hLogLevelDD_.Tooltip = 'Filter by log level';
            obj.hLogLevelDD_.ValueChangedFcn = @(~,~) obj.applyLogFilter_();

            obj.hLastUpdateLbl_ = uilabel(gHdr);
            obj.hLastUpdateLbl_.Layout.Row = 1; obj.hLastUpdateLbl_.Layout.Column = 4;
            obj.hLastUpdateLbl_.Text = 'Updated: --:--:--';
            obj.hLastUpdateLbl_.FontSize = 11; obj.hLastUpdateLbl_.FontName = 'Menlo';
            obj.hLastUpdateLbl_.FontColor = t.PlaceholderTextColor;
            obj.hLastUpdateLbl_.HorizontalAlignment = 'right';
            obj.hLastUpdateLbl_.VerticalAlignment = 'center';
            obj.hLastUpdateLbl_.Tooltip = 'Time of the last successful live refresh';

            obj.hPopoutBtn_ = uibutton(gHdr, 'push');
            obj.hPopoutBtn_.Layout.Row = 1; obj.hPopoutBtn_.Layout.Column = 5;
            obj.hPopoutBtn_.Text            = char(8689);  % pop-out arrow glyph
            obj.hPopoutBtn_.FontSize        = 14;
            obj.hPopoutBtn_.Tooltip         = 'Detach events log to its own window';
            obj.hPopoutBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hPopoutBtn_.FontColor       = t.ForegroundColor;
            obj.hPopoutBtn_.ButtonPushedFcn = @(~,~) notify(obj, 'DetachRequested');

            % --- Striped table BackgroundColor pair (theme-aware) ---
            isDark = mean(t.DashboardBackground) < 0.5;
            if isDark
                stripePair = [0.13 0.13 0.13; 0.20 0.20 0.20];
            else
                stripePair = [1.00 1.00 1.00; 0.94 0.94 0.94];
            end

            % --- Events table (row 2) ---
            obj.hLogTable_ = uitable(obj.hRoot_);
            obj.hLogTable_.Layout.Row = 2; obj.hLogTable_.Layout.Column = 1;
            obj.hLogTable_.ColumnName     = {'Time', 'Level', 'Message'};
            obj.hLogTable_.ColumnWidth    = {65, 55, 'auto'};
            obj.hLogTable_.ColumnEditable = [false false false];
            obj.hLogTable_.RowName        = {};
            obj.hLogTable_.FontSize       = 10;
            obj.hLogTable_.FontName       = 'Menlo';
            obj.hLogTable_.ForegroundColor = t.ForegroundColor;
            obj.hLogTable_.BackgroundColor = stripePair;

            obj.IsAttached = true;

            % Re-render any buffered history so re-attach is non-destructive.
            obj.applyLogFilter_();
        end

        function detach(obj)
        %DETACH Destroy UI handles. LogBuffer_ preserved.
        %   Safe to call when not attached (no-op).
            if ~obj.IsAttached; return; end
            try
                if ~isempty(obj.hRoot_) && isvalid(obj.hRoot_)
                    delete(obj.hRoot_);
                end
            catch
                % Never propagate teardown errors.
            end
            obj.hRoot_          = [];
            obj.hLogTable_      = [];
            obj.hLogSearch_     = [];
            obj.hLogLevelDD_    = [];
            obj.hLastUpdateLbl_ = [];
            obj.hPopoutBtn_     = [];
            obj.IsAttached      = false;
        end

        function addLogEntry(obj, level, msg)
        %ADDLOGENTRY Append a timestamped log line. Buffers always; renders if attached.
        %   level — 'info' | 'warn' | 'error' (any short tag accepted; uppercased).
        %   msg   — char/string. Anything else is sprintf'd through %s.
        %   Pushes onto LogBuffer_ (newest first, capped at 500). When attached,
        %   re-applies the level + text filter to update the visible uitable rows.
            try
                ts = char(datetime('now', 'Format', 'HH:mm:ss'));
                if isstring(msg) && isscalar(msg); msg = char(msg); end
                if ~ischar(msg); msg = sprintf('%s', msg); end
                row = {ts, upper(char(level)), msg};
                obj.LogBuffer_ = [row; obj.LogBuffer_];
                if size(obj.LogBuffer_, 1) > 500
                    obj.LogBuffer_ = obj.LogBuffer_(1:500, :);
                end
                if obj.IsAttached
                    obj.applyLogFilter_();
                end
            catch
                % Logging must never crash the UI.
            end
        end

        function setLastUpdated(obj, dt)
        %SETLASTUPDATED Update the 'Updated: HH:MM:SS' label.
        %   dt — datetime, char, or string. Anything else falls back to now().
            if ~obj.IsAttached || isempty(obj.hLastUpdateLbl_) || ~isvalid(obj.hLastUpdateLbl_)
                return;
            end
            try
                if isa(dt, 'datetime')
                    txt = char(dt, 'HH:mm:ss');
                elseif ischar(dt) || (isstring(dt) && isscalar(dt))
                    txt = char(dt);
                else
                    txt = char(datetime('now', 'Format', 'HH:mm:ss'));
                end
                obj.hLastUpdateLbl_.Text = sprintf('Updated: %s', txt);
            catch
                % Label update must never crash the UI.
            end
        end

        function applyTheme(obj, themeStruct)
        %APPLYTHEME Live theme switch — restyle existing UI without rebuilding handles.
        %   themeStruct — resolved CompanionTheme struct.
        %   Updates ThemeStruct_, then walks the pane subtree via
        %   applyThemeToChildren_, then re-applies pane-specific accents
        %   (Updated label PlaceholderTextColor, pop-out button colors,
        %   striped uitable BackgroundColor pair). No-op when detached
        %   (next attach() will use the latest ThemeStruct_).
            if ~isstruct(themeStruct); return; end
            obj.ThemeStruct_ = themeStruct;
            if ~obj.IsAttached || isempty(obj.hRoot_) || ~isvalid(obj.hRoot_)
                return;
            end
            try
                t = themeStruct;
                % Walker updates descendants but not the root layout itself.
                obj.hRoot_.BackgroundColor = t.WidgetBackground;
                applyThemeToChildren_(obj.hRoot_, themeStruct);
                % Re-apply EventsLogPane-specific accents that the generic
                % walker overwrites. "Updated: HH:MM:SS" uses the subdued
                % PlaceholderTextColor, not the default ForegroundColor the
                % walker assigns to all labels.
                if ~isempty(obj.hLastUpdateLbl_) && isvalid(obj.hLastUpdateLbl_)
                    obj.hLastUpdateLbl_.FontColor = t.PlaceholderTextColor;
                end
                % Pop-out button uses WidgetBorderColor + ForegroundColor
                % (matches the settings-gear button styling in
                % FastSenseCompanion).
                if ~isempty(obj.hPopoutBtn_) && isvalid(obj.hPopoutBtn_)
                    obj.hPopoutBtn_.BackgroundColor = t.WidgetBorderColor;
                    obj.hPopoutBtn_.FontColor       = t.ForegroundColor;
                end
                % Table: re-assert striped pair so attach() and applyTheme()
                % share the same logic regardless of walker behavior.
                isDark = mean(t.DashboardBackground) < 0.5;
                if isDark
                    stripePair = [0.13 0.13 0.13; 0.20 0.20 0.20];
                else
                    stripePair = [1.00 1.00 1.00; 0.94 0.94 0.94];
                end
                if ~isempty(obj.hLogTable_) && isvalid(obj.hLogTable_)
                    obj.hLogTable_.BackgroundColor = stripePair;
                    obj.hLogTable_.ForegroundColor = t.ForegroundColor;
                end
            catch
                % Theme application must never propagate errors.
            end
        end

        function n = bufferSize(obj)
        %BUFFERSIZE Test helper: row count of LogBuffer_.
        %   Test-only API. Production code uses no such introspection — companion
        %   forwards entries via addLogEntry only.
            n = size(obj.LogBuffer_, 1);
        end

        function row = peekLogRow(obj, idx)
        %PEEKLOGROW Test helper: read row idx (1-based, newest first) from LogBuffer_.
            if idx < 1 || idx > size(obj.LogBuffer_, 1)
                error('EventsLogPane:indexOutOfRange', ...
                    'idx %d out of range [1, %d].', idx, size(obj.LogBuffer_, 1));
            end
            row = obj.LogBuffer_(idx, :);
        end

        function bg = rootBackgroundColor(obj)
        %ROOTBACKGROUNDCOLOR Test helper: read hRoot_.BackgroundColor (or [] if detached).
            if isempty(obj.hRoot_) || ~isvalid(obj.hRoot_)
                bg = [];
            else
                bg = obj.hRoot_.BackgroundColor;
            end
        end

        function requestDetach(obj)
        %REQUESTDETACH Programmatic equivalent of clicking the pop-out icon.
        %   Production path: hPopoutBtn_.ButtonPushedFcn calls
        %   notify(obj, 'DetachRequested') directly. This wrapper exposes the
        %   same fire path for unit tests that cannot reach the private button
        %   handle. Companion code MAY also call this if it ever needs to fire
        %   the event programmatically — semantically identical to a button
        %   click.
            notify(obj, 'DetachRequested');
        end

        function delete(obj)
        %DELETE Handle class destructor — calls detach() for safety.
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

        function applyLogFilter_(obj)
        %APPLYLOGFILTER_ Re-apply level + text filter to LogBuffer_ → uitable.Data.
            if isempty(obj.hLogTable_) || ~isvalid(obj.hLogTable_); return; end
            rows = obj.LogBuffer_;
            if isempty(rows)
                obj.hLogTable_.Data = cell(0, 3); return;
            end
            % Level filter
            lvl = 'All';
            if ~isempty(obj.hLogLevelDD_) && isvalid(obj.hLogLevelDD_)
                lvl = obj.hLogLevelDD_.Value;
            end
            if ~strcmpi(lvl, 'All')
                keep = false(size(rows, 1), 1);
                for i = 1:size(rows, 1)
                    keep(i) = strcmpi(rows{i, 2}, lvl);
                end
                rows = rows(keep, :);
            end
            % Text filter — case-insensitive substring across all 3 columns.
            qry = '';
            if ~isempty(obj.hLogSearch_) && isvalid(obj.hLogSearch_)
                qry = strtrim(obj.hLogSearch_.Value);
            end
            if ~isempty(qry)
                qLow = lower(qry);
                keep = false(size(rows, 1), 1);
                for i = 1:size(rows, 1)
                    line = lower([rows{i, 1}, ' ', rows{i, 2}, ' ', rows{i, 3}]);
                    keep(i) = ~isempty(strfind(line, qLow)); %#ok<STREMP>
                end
                rows = rows(keep, :);
            end
            obj.hLogTable_.Data = rows;
        end

    end
end
