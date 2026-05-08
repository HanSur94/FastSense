classdef LiveLogPane < handle
%LIVELOGPANE Detachable live-updates pane for FastSenseCompanion.
%
%   Self-contained handle class that owns the FastSense Companion's
%   live-updates strip: a uitable showing recent per-tag sample deltas, a
%   Clear button, and a pop-out icon. The pane can be attached to either a
%   uipanel (inline, embedded in the companion) or directly to a uifigure
%   (detached, in its own window). The buffer persists across attach/detach
%   round-trips so re-attaching restores full history.
%
%   The pane is independent of FastSenseCompanion. The companion
%   instantiates it, listens to the DetachRequested event, and forwards
%   per-tick rows via addLiveLogEntry. Per-tag pipeline-cursor state — the
%   containers.Map of last-seen sample counts — does NOT live here; that
%   is FastSenseCompanion's responsibility (see Phase 1027 CONTEXT.md
%   "Live-pipeline integration boundary"). This pane is a passive
%   renderer of the rows the companion hands it.
%
%   Usage (called by FastSenseCompanion):
%     pane = LiveLogPane(theme);
%     pane.attach(parent, theme);   % parent: uipanel or uifigure
%     pane.addLiveLogEntry('tag.a', 5, 1.234);
%     pane.clearLiveLog();
%     pane.detach();                % UI handles released; buffer preserved
%
%   Events fired:
%     DetachRequested — fired when the user clicks the inline pop-out icon.
%                       Carries no payload; listener reads pane state if
%                       needed.
%
%   See also FastSenseCompanion, EventsLogPane, CompanionTheme.

    events
        DetachRequested  % fired when user clicks the inline pop-out icon
    end

    properties (SetAccess = private)
        IsAttached  logical = false
    end

    properties (Access = private)
        ThemeStruct_     = []          % resolved CompanionTheme struct
        hRoot_           = []          % outer uigridlayout (the [2 1] grid)
        hLiveLogTable_   = []          % uitable for live updates log
        hPopoutBtn_      = []          % pop-out icon uibutton in header col 3
        LiveLogBuffer_   = cell(0, 4)  % {Time, Tag, +Samples, Latest} newest first, capped 500
    end

    methods (Access = public)

        function obj = LiveLogPane(themeStruct)
        %LIVELOGPANE Construct a LiveLogPane with an initial theme. UI is NOT built — call attach().
        %   themeStruct — resolved CompanionTheme struct (must have WidgetBackground,
        %                 WidgetBorderColor, ForegroundColor, ForegroundColor,
        %                 DashboardBackground fields).
            if nargin < 1 || ~isstruct(themeStruct)
                error('LiveLogPane:invalidTheme', ...
                    'LiveLogPane requires a CompanionTheme struct as first argument.');
            end
            obj.ThemeStruct_   = themeStruct;
            obj.LiveLogBuffer_ = cell(0, 4);
            obj.IsAttached     = false;
        end

        function attach(obj, parent, themeStruct)
        %ATTACH Build the live-updates UI inside parent (uipanel or uifigure).
        %   parent      — uipanel (inline) or uifigure (detached). Must be valid.
        %   themeStruct — resolved CompanionTheme struct (optional; uses last
        %                 theme if omitted).
        %   Idempotent: if already attached, detaches first. Re-renders any
        %   buffered live entries from the existing buffer.
            if nargin >= 3 && isstruct(themeStruct)
                obj.ThemeStruct_ = themeStruct;
            end
            if obj.IsAttached
                obj.detach();
            end
            if isempty(parent) || ~isvalid(parent)
                error('LiveLogPane:invalidParent', ...
                    'LiveLogPane.attach requires a valid uipanel or uifigure parent.');
            end
            t = obj.ThemeStruct_;

            % --- Outer 2-row layout (header / live table) ---
            obj.hRoot_ = uigridlayout(parent, [2 1]);
            obj.hRoot_.RowHeight   = {28, '1x'};
            obj.hRoot_.ColumnWidth = {'1x'};
            obj.hRoot_.Padding     = [8 4 8 4];
            obj.hRoot_.RowSpacing  = 4;
            obj.hRoot_.BackgroundColor = t.WidgetBackground;

            % --- Header (row 1): "Live updates" label | Clear button | pop-out icon ---
            gHdr = uigridlayout(obj.hRoot_, [1 3]);
            gHdr.Layout.Row    = 1;
            gHdr.Layout.Column = 1;
            gHdr.ColumnWidth   = {'1x', 80, 36};
            gHdr.RowHeight     = {'1x'};
            gHdr.Padding       = [0 0 0 0];
            gHdr.ColumnSpacing = 8;
            gHdr.BackgroundColor = t.WidgetBackground;

            hLbl = uilabel(gHdr);
            hLbl.Layout.Row = 1; hLbl.Layout.Column = 1;
            hLbl.Text = 'Live updates'; hLbl.FontWeight = 'bold'; hLbl.FontSize = 11;
            hLbl.FontColor = t.ForegroundColor;
            hLbl.HorizontalAlignment = 'left'; hLbl.VerticalAlignment = 'center';

            hClearBtn = uibutton(gHdr, 'push');
            hClearBtn.Layout.Row = 1; hClearBtn.Layout.Column = 2;
            hClearBtn.Text = 'Clear'; hClearBtn.FontSize = 11;
            hClearBtn.Tooltip = 'Clear the live updates log';
            hClearBtn.ButtonPushedFcn = @(~,~) obj.clearLiveLog();

            obj.hPopoutBtn_ = uibutton(gHdr, 'push');
            obj.hPopoutBtn_.Layout.Row = 1; obj.hPopoutBtn_.Layout.Column = 3;
            obj.hPopoutBtn_.Text            = char(8689);  % pop-out arrow glyph
            obj.hPopoutBtn_.FontSize        = 14;
            obj.hPopoutBtn_.Tooltip         = 'Detach live log to its own window';
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

            % --- Live updates table (row 2) ---
            obj.hLiveLogTable_ = uitable(obj.hRoot_);
            obj.hLiveLogTable_.Layout.Row = 2; obj.hLiveLogTable_.Layout.Column = 1;
            obj.hLiveLogTable_.ColumnName     = {'Time', 'Tag', char([8710, ' samples']), 'Latest'};
            obj.hLiveLogTable_.ColumnWidth    = {65, 'auto', 90, 90};
            obj.hLiveLogTable_.ColumnEditable = [false false false false];
            obj.hLiveLogTable_.RowName        = {};
            obj.hLiveLogTable_.FontSize       = 10;
            obj.hLiveLogTable_.FontName       = 'Menlo';
            obj.hLiveLogTable_.ForegroundColor = t.ForegroundColor;
            obj.hLiveLogTable_.BackgroundColor = stripePair;
            obj.hLiveLogTable_.Data            = cell(0, 4);

            obj.IsAttached = true;

            % Re-render any buffered history so re-attach is non-destructive.
            obj.renderLiveTable_();
        end

        function detach(obj)
        %DETACH Destroy UI handles. LiveLogBuffer_ preserved.
        %   Safe to call when not attached (no-op).
            if ~obj.IsAttached; return; end
            try
                if ~isempty(obj.hRoot_) && isvalid(obj.hRoot_)
                    delete(obj.hRoot_);
                end
            catch
                % Never propagate teardown errors.
            end
            obj.hRoot_         = [];
            obj.hLiveLogTable_ = [];
            obj.hPopoutBtn_    = [];
            obj.IsAttached     = false;
        end

        function addLiveLogEntry(obj, tagKey, deltaSamples, latestY)
        %ADDLIVELOGENTRY Push a row into the live-updates log; cap at 500.
        %   tagKey       — char tag key.
        %   deltaSamples — number of new samples since the last log entry
        %                  (caller computes via its own pipeline-cursor map —
        %                  this pane does NOT track per-tag sample counts).
        %   latestY      — latest Y value (numeric, or char/string for state tags).
            try
                ts = char(datetime('now', 'Format', 'HH:mm:ss'));
                latestTxt = char(8212);  % em-dash placeholder
                if ~isempty(latestY) && isnumeric(latestY) && isfinite(latestY)
                    a = abs(latestY);
                    if a == 0;       latestTxt = '0';
                    elseif a >= 1000 || a < 0.01; latestTxt = sprintf('%.3g', latestY);
                    elseif a >= 100;  latestTxt = sprintf('%.0f', latestY);
                    elseif a >= 10;   latestTxt = sprintf('%.2f', latestY);
                    else;             latestTxt = sprintf('%.3f', latestY);
                    end
                elseif ischar(latestY) || (isstring(latestY) && isscalar(latestY))
                    latestTxt = char(latestY);
                end
                row = {ts, char(tagKey), sprintf('+%d', deltaSamples), latestTxt};
                obj.LiveLogBuffer_ = [row; obj.LiveLogBuffer_];
                if size(obj.LiveLogBuffer_, 1) > 500
                    obj.LiveLogBuffer_ = obj.LiveLogBuffer_(1:500, :);
                end
                if obj.IsAttached
                    obj.renderLiveTable_();
                end
            catch
                % Live logging must never crash the UI.
            end
        end

        function clearLiveLog(obj)
        %CLEARLIVELOG Wipe the live-updates buffer + table.
        %   NOTE: does NOT reset any companion-side pipeline-cursor map. If the
        %   companion needs that reset (e.g. on project switch), it does so itself.
            obj.LiveLogBuffer_ = cell(0, 4);
            if obj.IsAttached && ~isempty(obj.hLiveLogTable_) && isvalid(obj.hLiveLogTable_)
                obj.hLiveLogTable_.Data = cell(0, 4);
            end
        end

        function applyTheme(obj, themeStruct)
        %APPLYTHEME Live theme switch — restyle existing UI without rebuilding handles.
        %   themeStruct — resolved CompanionTheme struct.
        %   Updates ThemeStruct_, then walks the pane subtree via
        %   applyThemeToChildren_, then re-applies pane-specific accents
        %   (pop-out button colors, striped uitable BackgroundColor pair).
        %   No-op when detached (next attach() will use the latest
        %   ThemeStruct_).
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
                % Re-apply LiveLogPane-specific accents that the generic walker overwrites.
                % Pop-out button uses WidgetBorderColor + ForegroundColor (matches
                % the settings-gear button styling in FastSenseCompanion).
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
                if ~isempty(obj.hLiveLogTable_) && isvalid(obj.hLiveLogTable_)
                    obj.hLiveLogTable_.BackgroundColor = stripePair;
                    obj.hLiveLogTable_.ForegroundColor = t.ForegroundColor;
                end
            catch
                % Theme application must never propagate errors.
            end
        end

        function n = bufferSize(obj)
        %BUFFERSIZE Test helper: row count of LiveLogBuffer_.
        %   Test-only API. Production code uses no such introspection — companion
        %   forwards entries via addLiveLogEntry only.
            n = size(obj.LiveLogBuffer_, 1);
        end

        function row = peekLiveRow(obj, idx)
        %PEEKLIVEROW Test helper: read row idx (1-based, newest first) from LiveLogBuffer_.
            if idx < 1 || idx > size(obj.LiveLogBuffer_, 1)
                error('LiveLogPane:indexOutOfRange', ...
                    'idx %d out of range [1, %d].', idx, size(obj.LiveLogBuffer_, 1));
            end
            row = obj.LiveLogBuffer_(idx, :);
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
        %   Production path: hPopoutBtn_.ButtonPushedFcn calls notify(obj,'DetachRequested')
        %   directly. This wrapper exposes the same fire path for unit tests that
        %   cannot reach the private button handle. Companion code MAY also call
        %   this if it ever needs to fire the event programmatically — semantically
        %   identical to a button click.
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

        function renderLiveTable_(obj)
        %RENDERLIVETABLE_ Push LiveLogBuffer_ into hLiveLogTable_.Data (newest first).
            if isempty(obj.hLiveLogTable_) || ~isvalid(obj.hLiveLogTable_); return; end
            if isempty(obj.LiveLogBuffer_)
                obj.hLiveLogTable_.Data = cell(0, 4);
            else
                obj.hLiveLogTable_.Data = obj.LiveLogBuffer_;
            end
        end

    end
end
