classdef LogPane < handle
%LOGPANE Detachable log strip for FastSenseCompanion (events log + live-updates log).
%
%   Self-contained handle class that owns the FastSense Companion's log strip:
%   events table, live-updates table, header controls (search, level filter,
%   updated-time label, pop-out icon), and the underlying buffers. The pane
%   can be attached to either a uipanel (inline, embedded in the companion)
%   or directly to a uifigure (detached, in its own window). Buffers persist
%   across attach/detach round-trips so re-attaching restores full history.
%
%   The pane is independent of FastSenseCompanion. The companion instantiates
%   it, listens to the DetachRequested event, and forwards log entries via
%   addLogEntry / addLiveLogEntry. Pipeline state (per-tag last-seen sample
%   counter map) does NOT live here — that is FastSenseCompanion's
%   responsibility (see Phase 1027 CONTEXT.md "Live-pipeline integration
%   boundary").
%
%   Usage (called by FastSenseCompanion):
%     pane = LogPane(theme);
%     pane.attach(parent, theme);   % parent: uipanel or uifigure
%     pane.addLogEntry('info', 'msg');
%     pane.addLiveLogEntry('tag.a', 5, 1.234);
%     pane.detach();                % UI handles released; buffers preserved
%
%   Events fired:
%     DetachRequested — fired when the user clicks the inline pop-out icon.
%                       Carries no payload; listener reads pane state if
%                       needed.
%
%   See also FastSenseCompanion, TagCatalogPane, CompanionTheme.

    events
        DetachRequested  % fired when user clicks the inline pop-out icon
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_     = []          % resolved CompanionTheme struct
        hRoot_           = []          % outer uigridlayout (the [4 1] grid)
        hLogTable_       = []          % uitable for events log
        hLogSearch_      = []          % uieditfield (search)
        hLogLevelDD_     = []          % uidropdown level filter
        hLastUpdateLbl_  = []          % "Updated: HH:MM:SS" label
        hPopoutBtn_      = []          % pop-out icon uibutton in header col 5
        hLiveLogTable_   = []          % uitable for live updates log
        LogBuffer_       = cell(0, 3)  % {Time, Level, Message} newest first, capped 500
        LiveLogBuffer_   = cell(0, 4)  % {Time, Tag, +Samples, Latest} newest first, capped 500
    end

    methods (Access = public)

        function obj = LogPane(themeStruct)
        %LOGPANE Construct a LogPane with an initial theme. UI is NOT built — call attach().
        %   themeStruct — resolved CompanionTheme struct (must have WidgetBackground,
        %                 WidgetBorderColor, ForegroundColor, PlaceholderTextColor,
        %                 Accent, DashboardBackground fields).
            if nargin < 1 || ~isstruct(themeStruct)
                error('LogPane:invalidTheme', ...
                    'LogPane requires a CompanionTheme struct as first argument.');
            end
            obj.ThemeStruct_   = themeStruct;
            obj.LogBuffer_     = cell(0, 3);
            obj.LiveLogBuffer_ = cell(0, 4);
            obj.IsAttached     = false;
        end

        function attach(obj, parent, themeStruct)
        %ATTACH Build the log-strip UI inside parent (uipanel or uifigure).
        %   parent      — uipanel (inline) or uifigure (detached). Must be valid.
        %   themeStruct — resolved CompanionTheme struct (optional; uses last
        %                 theme if omitted).
        %   Idempotent: if already attached, detaches first. Re-renders any
        %   buffered log + live entries from the existing buffers.
            if nargin >= 3 && isstruct(themeStruct)
                obj.ThemeStruct_ = themeStruct;
            end
            if obj.IsAttached
                obj.detach();
            end
            if isempty(parent) || ~isvalid(parent)
                error('LogPane:invalidParent', ...
                    'LogPane.attach requires a valid uipanel or uifigure parent.');
            end
            t = obj.ThemeStruct_;

            % --- Outer 4-row layout (events header / events table / live header / live table) ---
            obj.hRoot_ = uigridlayout(parent, [4 1]);
            obj.hRoot_.RowHeight   = {28, 150, 28, '1x'};
            obj.hRoot_.ColumnWidth = {'1x'};
            obj.hRoot_.Padding     = [8 4 8 4];
            obj.hRoot_.RowSpacing  = 4;
            obj.hRoot_.BackgroundColor = t.WidgetBackground;

            % --- Header (row 1): Log label | search | level dropdown | last-update | pop-out icon ---
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
            hLbl.Text = 'Log'; hLbl.FontWeight = 'bold'; hLbl.FontSize = 11;
            hLbl.FontColor = t.ForegroundColor;
            hLbl.HorizontalAlignment = 'left'; hLbl.VerticalAlignment = 'center';

            obj.hLogSearch_ = uieditfield(gHdr, 'text');
            obj.hLogSearch_.Layout.Row = 1; obj.hLogSearch_.Layout.Column = 2;
            obj.hLogSearch_.Placeholder = ['Search log', char(8230)];
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
            obj.hPopoutBtn_.Tooltip         = 'Detach log to its own window';
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

            % --- Live updates header (row 3): label + Clear button ---
            gLive = uigridlayout(obj.hRoot_, [1 2]);
            gLive.Layout.Row = 3; gLive.Layout.Column = 1;
            gLive.ColumnWidth = {'1x', 80};
            gLive.RowHeight   = {'1x'};
            gLive.Padding     = [0 0 0 0];
            gLive.ColumnSpacing = 8;
            gLive.BackgroundColor = t.WidgetBackground;

            hLiveLbl = uilabel(gLive);
            hLiveLbl.Layout.Row = 1; hLiveLbl.Layout.Column = 1;
            hLiveLbl.Text = 'Live updates'; hLiveLbl.FontWeight = 'bold'; hLiveLbl.FontSize = 11;
            hLiveLbl.FontColor = t.ForegroundColor;
            hLiveLbl.HorizontalAlignment = 'left'; hLiveLbl.VerticalAlignment = 'center';

            hLiveClear = uibutton(gLive, 'push');
            hLiveClear.Layout.Row = 1; hLiveClear.Layout.Column = 2;
            hLiveClear.Text = 'Clear'; hLiveClear.FontSize = 11;
            hLiveClear.Tooltip = 'Clear the live updates log';
            hLiveClear.ButtonPushedFcn = @(~,~) obj.clearLiveLog();

            % --- Live updates table (row 4) ---
            obj.hLiveLogTable_ = uitable(obj.hRoot_);
            obj.hLiveLogTable_.Layout.Row = 4; obj.hLiveLogTable_.Layout.Column = 1;
            obj.hLiveLogTable_.ColumnName     = {'Time', 'Tag', char([8710, ' samples']), 'Latest'};
            obj.hLiveLogTable_.ColumnWidth    = {65, 'auto', 90, 90};
            obj.hLiveLogTable_.ColumnEditable = [false false false false];
            obj.hLiveLogTable_.RowName        = {};
            obj.hLiveLogTable_.FontSize       = 10;
            obj.hLiveLogTable_.FontName       = 'Menlo';
            obj.hLiveLogTable_.ForegroundColor = t.ForegroundColor;
            obj.hLiveLogTable_.BackgroundColor = stripePair;
            obj.hLiveLogTable_.Data = cell(0, 4);

            obj.IsAttached = true;

            % Re-render any buffered history so re-attach is non-destructive.
            obj.applyLogFilter_();
            obj.renderLiveTable_();
        end

        function detach(obj)
        %DETACH Destroy UI handles. LogBuffer_ + LiveLogBuffer_ preserved.
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
            obj.hLiveLogTable_  = [];
            obj.IsAttached      = false;
        end

        function addLogEntry(obj, level, msg)
        %ADDLOGENTRY Append a timestamped log line. Buffers always; renders if attached.
            % TODO Task 3
        end

        function addLiveLogEntry(obj, tagKey, deltaSamples, latestY)
        %ADDLIVELOGENTRY Push a row into the live-updates log; cap at 500.
            % TODO Task 3
        end

        function clearLiveLog(obj)
        %CLEARLIVELOG Wipe the live-updates buffer + table.
            % TODO Task 3
        end

        function setLastUpdated(obj, dt)
        %SETLASTUPDATED Update the 'Updated: HH:MM:SS' label.
            % TODO Task 3
        end

        function applyTheme(obj, themeStruct)
        %APPLYTHEME Live theme switch — restyle existing UI without rebuilding handles.
            % TODO Task 4
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
        %APPLYLOGFILTER_ Re-apply level + text filter to LogBuffer_ then render.
            % TODO Task 3
        end

        function renderLiveTable_(obj)
        %RENDERLIVETABLE_ Push LiveLogBuffer_ into hLiveLogTable_.Data.
            % TODO Task 3
        end

        function styleTables_(obj)
        %STYLETABLES_ Pick striped uitable BackgroundColor pair from theme darkness.
            % TODO Task 4 (helper) — currently inlined into attach() and applyTheme().
        end

    end
end
