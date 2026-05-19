classdef TagStatusTableWindow < handle
%TAGSTATUSTABLEWINDOW Detached classical-figure window showing live status of all TagRegistry tags.
%
%   Standalone classical `figure` (NOT a uifigure -- the companion owns the
%   only uifigure). Constructed by FastSenseCompanion.openTagStatusTable().
%   Pulls the initial row set from TagRegistry, then refreshes rows via TWO
%   complementary mechanisms:
%     1. Push-on-write: companion.scanLiveTagUpdates_ calls markTagsDirty(keys)
%        whenever sample counts grow (zero-cost when window is closed).
%     2. Window-owned RefreshTimer_: ticks every RefreshPeriod_ seconds while
%        the window is open and re-queries every tracked tag. This guarantees
%        the table reflects reality even when the companion is NOT in Live
%        mode (e.g. user just wants to monitor activity without running the
%        full live pipeline). Quick task 260519-bs4 follow-up patch.
%
%   The "Activity" column (between "Last updated" and "Samples") shows
%   "Live" when X(end) is within InactiveThresholdSeconds_ of the current
%   wall-clock time (using the same time-base conversion as
%   formatLastUpdated_ -- datenum or posixtime). Otherwise "Inactive".
%
%   Lifecycle:
%     w = TagStatusTableWindow();
%     w.openWith(registry, theme, companion);   % builds the figure, fills the table, starts timer
%     w.markTagsDirty({'press_a','temp_b'});    % rebuild only those rows; re-apply filter
%     w.applyTheme(theme);                      % live theme switch
%     w.close();                                % programmatic close; stops timer; fires DetachClosed
%
%   Events fired:
%     DetachClosed -- fired exactly once when the window closes (user X click,
%                     programmatic close(), or companion teardown). The
%                     companion listens so it can call detachStatusTable_(w).
%
%   See also FastSenseCompanion, LiveLogPane, TagRegistry, CompanionTheme.

    events
        DetachClosed
    end

    properties (SetAccess = private)
        IsOpen logical = false
    end

    properties (Access = private)
        hFig_         = []        % classical figure handle
        hTable_       = []        % uitable handle (uicontrol-style, in classical figure)
        hSearch_      = []        % uicontrol 'edit' (substring filter)
        hStatusLbl_   = []        % "N tags" footer label
        hSearchLbl_   = []        % "Search:" label
        hHeaderLbl_   = []        % "Tags" right-side header label
        hLastRefreshLbl_ = []     % "Last refreshed: HH:MM:SS" label (260519-bs4-04 patch)
        hPauseBtn_       = []     % "Pause polling"/"Resume polling" uicontrol pushbutton (260519-bs4-05 patch)
        hWikiBtn_        = []     % uicontrol pushbutton: open Wiki -> Tag-Status-Table.md (Phase 1034)
        PollingActive_   = true   % true = RefreshTimer_ running + markTagsDirty live; false = frozen (260519-bs4-05 patch)
        hChipsType_     = []      % 1x5 array of uicontrol pushbuttons (Sensor/Monitor/Composite/State/Derived)
        hChipsCrit_     = []      % 1x4 array of uicontrol pushbuttons (Low/Medium/High/Safety)
        hChipsActivity_ = []      % 1x2 array of uicontrol pushbuttons (Live/Inactive)
        ActiveTypeChips_     = {} % active type keys; subset of TypeChipKeys_; empty = none-selected -> excludes all
        ActiveCritChips_     = {} % active criticality keys; subset of CritChipKeys_
        ActiveActivityChips_ = {} % active activity keys; subset of ActivityChipKeys_
        Registry_     = []        % TagRegistry handle (or class name placeholder)
        Theme_        = []        % resolved CompanionTheme struct
        Companion_    = []        % FastSenseCompanion handle (uialert parent + detach)
        RowBuffer_    = cell(0, 12)
        KeyToRow_     = []        % containers.Map(key -> row index into RowBuffer_)
        Listeners_    = {}        % addlistener handles; deleted in close()
        RefreshTimer_ = []        % timer driving periodic re-query (window-owned; 260519-bs4 patch)
        RefreshErrCount_ = 0      % consecutive errors in onRefreshTick_; auto-stops at 2
    end

    properties (Constant, Access = private)
        RefreshPeriod_           = 1.0    % seconds between RefreshTimer_ ticks
        InactiveThresholdSeconds_ = 300   % >= 5 min since last sample -> Activity = "Inactive"
        % Chip filter dimensions (260519-bs4-04 patch). Keys are stored
        % lower-case (canonical). Labels are display-cased.
        TypeChipKeys_     = {'sensor', 'monitor', 'composite', 'state', 'derived'}
        TypeChipLabels_   = {'Sensor', 'Monitor', 'Composite', 'State', 'Derived'}
        CritChipKeys_     = {'low', 'medium', 'high', 'safety'}
        CritChipLabels_   = {'Low', 'Medium', 'High', 'Safety'}
        ActivityChipKeys_   = {'live', 'inactive'}
        ActivityChipLabels_ = {'Live', 'Inactive'}
    end

    methods (Access = public)

        function obj = TagStatusTableWindow()
            obj.RowBuffer_ = cell(0, 12);
            obj.KeyToRow_  = containers.Map('KeyType', 'char', 'ValueType', 'double');
            % Default chip state: every chip ACTIVE (first-open shows
            % everything). 260519-bs4-04 patch.
            obj.ActiveTypeChips_     = obj.TypeChipKeys_;
            obj.ActiveCritChips_     = obj.CritChipKeys_;
            obj.ActiveActivityChips_ = obj.ActivityChipKeys_;
        end

        function openWith(obj, registry, theme, companion)
        %OPENWITH Build the classical figure + uitable; fill from registry.
        %   registry  -- TagRegistry handle (or any object; only used as a
        %                pass-through for parity with companion patterns).
        %   theme     -- resolved CompanionTheme struct.
        %   companion -- FastSenseCompanion handle (for uialert parent +
        %                programmatic detach calls).
        %   Idempotent: if already open, brings the figure forward and returns.
            if ~isstruct(theme)
                error('FastSenseCompanion:tagStatusTableInvalidTheme', ...
                    'TagStatusTableWindow.openWith requires a CompanionTheme struct.');
            end
            % registry MAY be empty -- buildRow_/rebuildAll_ fall back to the
            % TagRegistry static API. We do not strictly require a handle.
            obj.Registry_  = registry;
            obj.Theme_     = theme;
            obj.Companion_ = companion;
            if obj.IsOpen && ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                figure(obj.hFig_);
                return;
            end

            t = theme;

            % --- Classical figure window (NOT a uifigure). ---
            % Window slightly taller than the original 520px to fit the
            % new last-refreshed label + chip strip introduced by the
            % 260519-bs4-04 patch without squeezing the table. Window
            % stays resizable (no 'Resize','off').
            obj.hFig_ = figure( ...
                'Name',             'Tag Status -- FastSense Companion', ...
                'NumberTitle',      'off', ...
                'MenuBar',           'none', ...
                'ToolBar',           'none', ...
                'Color',             t.WidgetBackground, ...
                'Position',          [100 100 1100 580], ...
                'CloseRequestFcn',   @(~,~) obj.onCloseRequest_());
            movegui(obj.hFig_, 'center');

            % --- Vertical strip layout (top -> bottom):
            %   Last refreshed label  : y=0.945 .. 0.985  (~4%)
            %   Search strip          : y=0.890 .. 0.940  (~5%)
            %   Chip strip            : y=0.840 .. 0.885  (~4.5%)
            %   Table                 : y=0.055 .. 0.835  (~78%)
            %   Footer "N / M tags"   : y=0.005 .. 0.045  (~4%)
            % Adding the label + chip strip leaves enough room for the
            % uitable at the default ~580px window height (260519-bs4-04).

            % --- Last-refreshed label (top-left, small muted text). ---
            % Style mirrors EventsLogPane.setLastUpdated convention:
            % small font, Menlo monospace, PlaceholderTextColor.
            % Width reduced to leave room for the Pause/Resume polling
            % button on the right edge of the same row (260519-bs4-05).
            obj.hLastRefreshLbl_ = uicontrol(obj.hFig_, ...
                'Style',               'text', ...
                'Units',               'normalized', ...
                'Position',            [0.01 0.945 0.85 0.04], ...
                'String',              'Last refreshed: --:--:--', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.PlaceholderTextColor, ...
                'FontName',            'Menlo', ...
                'FontSize',            10);

            % --- Pause/Resume polling button (shifted left to make room
            %     for the new Wiki button on the right edge). 260519-bs4-05
            %     placement; Phase 1034 shifted Position[0] from 0.87 to 0.74.
            obj.hPauseBtn_ = uicontrol(obj.hFig_, ...
                'Style',               'pushbutton', ...
                'Units',               'normalized', ...
                'Position',            [0.74 0.945 0.12 0.04], ...
                'String',              'Pause polling', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10, ...
                'Callback',            @(~,~) obj.setPollingActive(~obj.PollingActive_));

            % --- Wiki button (Phase 1034). ---
            % Sits on the right edge, in the slot previously occupied by
            % Pause/Resume. Routes through the Companion's shared
            % WikiBrowser via the openWiki entry point (Plan 06 task 6.2),
            % defaulting to the Tag-Status-Table.md page.
            obj.hWikiBtn_ = uicontrol(obj.hFig_, ...
                'Style',               'pushbutton', ...
                'Units',               'normalized', ...
                'Position',            [0.87 0.945 0.12 0.04], ...
                'String',              ['Wiki ', char(8689)], ...
                'TooltipString',       'Open Wiki: Tag Status Table', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10, ...
                'Callback',            @(~,~) obj.openWiki_());

            % --- Search strip ---
            obj.hSearchLbl_ = uicontrol(obj.hFig_, ...
                'Style',               'text', ...
                'Units',               'normalized', ...
                'Position',            [0.01 0.89 0.06 0.05], ...
                'String',              'Search:', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10);

            obj.hSearch_ = uicontrol(obj.hFig_, ...
                'Style',               'edit', ...
                'Units',               'normalized', ...
                'Position',            [0.07 0.89 0.43 0.05], ...
                'String',              '', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10, ...
                'Callback',            @(~,~) obj.applyFilter_());

            obj.hHeaderLbl_ = uicontrol(obj.hFig_, ...
                'Style',               'text', ...
                'Units',               'normalized', ...
                'Position',            [0.55 0.89 0.44 0.05], ...
                'String',              'Tags', ...
                'HorizontalAlignment', 'right', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10, ...
                'FontWeight',          'bold');

            % --- Chip strip: Type / Criticality / Activity ---
            obj.buildChipStrip_(t);

            % --- Striped pair derived from theme (mirrors LiveLogPane). ---
            stripePair = obj.stripePairFromTheme_(t);

            % --- Center uitable. ---
            % 12 columns: Activity is col 9, Events is col 10, Samples col 11.
            % Events column (260519-bs4-06 patch) shows the integer count of
            % events attached to each tag via EventStore.getEventsForTag.
            obj.hTable_ = uitable(obj.hFig_, ...
                'Units',           'normalized', ...
                'Position',        [0.01 0.055 0.98 0.78], ...
                'ColumnName',      {'Key', 'Name', 'Type', 'Criticality', 'Units', ...
                                    'Latest', 'Status', 'Last updated', 'Activity', ...
                                    'Events', 'Samples', 'Labels'}, ...
                'ColumnWidth',     {120, 180, 70, 75, 55, 85, 75, 130, 65, 55, 65, 'auto'}, ...
                'ColumnEditable',  false(1, 12), ...
                'RowName',         {}, ...
                'FontName',        'Menlo', ...
                'FontSize',        10, ...
                'BackgroundColor', stripePair, ...
                'ForegroundColor', t.ForegroundColor, ...
                'Data',            cell(0, 12));

            % --- Footer "N tags" label. ---
            obj.hStatusLbl_ = uicontrol(obj.hFig_, ...
                'Style',               'text', ...
                'Units',               'normalized', ...
                'Position',            [0.01 0.005 0.98 0.04], ...
                'String',              '0 / 0 tags', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.PlaceholderTextColor, ...
                'FontSize',            10);

            % --- Reset chip filter state to "show everything" on every
            %     openWith (defensive in case the singleton is reused).
            obj.ActiveTypeChips_     = obj.TypeChipKeys_;
            obj.ActiveCritChips_     = obj.CritChipKeys_;
            obj.ActiveActivityChips_ = obj.ActivityChipKeys_;
            obj.applyChipStyles_();

            % --- Fill from registry + apply (initial empty) filter. ---
            obj.rebuildAll_();
            obj.applyFilter_();

            % --- Seed the "Last refreshed" label to window-open time so
            %     the user immediately sees a concrete HH:MM:SS rather
            %     than the "--:--:--" placeholder.
            obj.setLastRefreshedNow_();

            obj.IsOpen = true;

            % --- Start the window-owned refresh timer. ---
            % Independent of companion Live mode so Activity / Last updated
            % stay accurate even when the companion is idle. 260519-bs4 patch.
            obj.startRefreshTimer_();
        end

        function markTagsDirty(obj, keys)
        %MARKTAGSDIRTY Refresh only rows for the listed tag keys.
        %   keys -- cellstr or single char. No-op when ~IsOpen or when
        %   PollingActive_ is false (paused -> table is frozen, mirroring
        %   the user's "polling off = nothing moves" mental model;
        %   260519-bs4-05 patch). Whole body wrapped in try/catch so a
        %   live tick can never crash via this path.
            if ~obj.IsOpen; return; end
            if ~obj.PollingActive_; return; end
            if isempty(keys); return; end
            if ischar(keys); keys = {keys}; end
            if ~iscell(keys); return; end
            try
                nowSec = TagStatusTableWindow.nowSeconds_();
                % Build a small precomputed event-count map for ONLY the
                % dirty keys -- O(M events * H stores) once, then O(1) per
                % row in the loop below (260519-bs4-06 patch).
                eventCountsByKey = obj.precomputeEventCounts_(keys);
                changed = false;
                for k = 1:numel(keys)
                    key = char(keys{k});
                    if isempty(key); continue; end
                    tag = obj.resolveTag_(key);
                    if isempty(tag); continue; end
                    row = TagStatusTableWindow.buildRow_(tag, nowSec, eventCountsByKey);
                    if obj.KeyToRow_.isKey(key)
                        idx = obj.KeyToRow_(key);
                        obj.RowBuffer_(idx, :) = row;
                    else
                        obj.RowBuffer_ = [obj.RowBuffer_; row];
                        obj.KeyToRow_(key) = size(obj.RowBuffer_, 1);
                    end
                    changed = true;
                end
                if changed
                    obj.applyFilter_();
                end
            catch
                % Never propagate -- caller is the live tick.
            end
        end

        function applyTheme(obj, theme)
        %APPLYTHEME Live theme switch. No-op when ~IsOpen.
            if ~isstruct(theme); return; end
            obj.Theme_ = theme;
            if ~obj.IsOpen || isempty(obj.hFig_) || ~isvalid(obj.hFig_); return; end
            try
                t = theme;
                obj.hFig_.Color = t.WidgetBackground;
                if ~isempty(obj.hSearchLbl_) && isvalid(obj.hSearchLbl_)
                    obj.hSearchLbl_.BackgroundColor = t.WidgetBackground;
                    obj.hSearchLbl_.ForegroundColor = t.ForegroundColor;
                end
                if ~isempty(obj.hSearch_) && isvalid(obj.hSearch_)
                    obj.hSearch_.BackgroundColor = t.WidgetBackground;
                    obj.hSearch_.ForegroundColor = t.ForegroundColor;
                end
                if ~isempty(obj.hHeaderLbl_) && isvalid(obj.hHeaderLbl_)
                    obj.hHeaderLbl_.BackgroundColor = t.WidgetBackground;
                    obj.hHeaderLbl_.ForegroundColor = t.ForegroundColor;
                end
                if ~isempty(obj.hStatusLbl_) && isvalid(obj.hStatusLbl_)
                    obj.hStatusLbl_.BackgroundColor = t.WidgetBackground;
                    obj.hStatusLbl_.ForegroundColor = t.PlaceholderTextColor;
                end
                if ~isempty(obj.hLastRefreshLbl_) && isvalid(obj.hLastRefreshLbl_)
                    obj.hLastRefreshLbl_.BackgroundColor = t.WidgetBackground;
                    obj.hLastRefreshLbl_.ForegroundColor = t.PlaceholderTextColor;
                end
                if ~isempty(obj.hPauseBtn_) && isvalid(obj.hPauseBtn_)
                    obj.hPauseBtn_.BackgroundColor = t.WidgetBackground;
                    obj.hPauseBtn_.ForegroundColor = t.ForegroundColor;
                end
                if ~isempty(obj.hWikiBtn_) && isvalid(obj.hWikiBtn_)
                    obj.hWikiBtn_.BackgroundColor = t.WidgetBackground;
                    obj.hWikiBtn_.ForegroundColor = t.ForegroundColor;
                end
                % Re-apply chip active/inactive styling -- pulls Accent
                % from the freshly-stored theme.
                obj.applyChipStyles_();
                if ~isempty(obj.hTable_) && isvalid(obj.hTable_)
                    stripePair = obj.stripePairFromTheme_(t);
                    obj.hTable_.BackgroundColor = stripePair;
                    obj.hTable_.ForegroundColor = t.ForegroundColor;
                end
            catch
                % Theme propagation must never throw.
            end
        end

        function setPollingActive(obj, tf)
        %SETPOLLINGACTIVE Pause or resume the window's refresh polling.
        %   setPollingActive(true)  -> starts RefreshTimer_ (if not running),
        %                              fires one immediate synchronous
        %                              onRefreshTick_ so the user sees fresh
        %                              data right away, sets the button
        %                              label to 'Pause polling' and drops
        %                              the '(paused)' suffix from the
        %                              header label.
        %   setPollingActive(false) -> stops RefreshTimer_ (without deleting
        %                              it -- close() still cleans up via
        %                              stopRefreshTimer_), sets the button
        %                              label to 'Resume polling' and adds
        %                              the '(paused)' suffix to the header
        %                              label so the user sees WHEN the
        %                              polling stopped.
        %
        %   While paused, markTagsDirty() is a no-op: the table is frozen.
        %   No-op when ~IsOpen. Whole body wrapped in try/catch so a stray
        %   click cannot crash the window. 260519-bs4-05 patch.
            if ~obj.IsOpen; return; end
            if ~islogical(tf) || ~isscalar(tf)
                error('FastSenseCompanion:tagStatusTableInvalidPollingFlag', ...
                    'setPollingActive requires a scalar logical argument.');
            end
            try
                obj.PollingActive_ = tf;
                if tf
                    % Resume: restart timer (if it died, recreate via
                    % startRefreshTimer_; if it just stopped, start() it).
                    if ~isempty(obj.RefreshTimer_) && isvalid(obj.RefreshTimer_)
                        try
                            if strcmp(get(obj.RefreshTimer_, 'Running'), 'off')
                                start(obj.RefreshTimer_);
                            end
                        catch
                            % If start() fails (e.g. timer in a weird state),
                            % rebuild it cleanly.
                            obj.startRefreshTimer_();
                        end
                    else
                        obj.startRefreshTimer_();
                    end
                    % Immediate one-shot refresh on resume so the user sees
                    % freshness right away rather than waiting up to
                    % RefreshPeriod_ seconds for the timer tick.
                    obj.onRefreshTick_();
                else
                    % Pause: stop the timer but DO NOT delete it -- we want
                    % to be able to re-start the same timer on resume.
                    % Close-path teardown still runs stopRefreshTimer_
                    % regardless of paused state.
                    if ~isempty(obj.RefreshTimer_) && isvalid(obj.RefreshTimer_)
                        try
                            if strcmp(get(obj.RefreshTimer_, 'Running'), 'on')
                                stop(obj.RefreshTimer_);
                            end
                        catch
                            % Best-effort; never throw out of a UI click.
                        end
                    end
                end
                obj.refreshPauseUi_();
            catch
                % UI click handler must never throw.
            end
        end

        function close(obj)
        %CLOSE Programmatic close; routes through onCloseRequest_ for parity.
            if obj.IsOpen && ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                obj.onCloseRequest_();
            end
        end

        function delete(obj)
        %DELETE Handle-class destructor; ensure close().
            try
                if obj.IsOpen
                    obj.close();
                end
            catch
                % Destructor must never throw.
            end
        end

        % --- Test helpers (Access=public so unit tests can reach them) ---

        function n = bufferSize(obj)
            n = size(obj.RowBuffer_, 1);
        end

        function row = peekRow(obj, idx)
            row = obj.RowBuffer_(idx, :);
        end

        function tf = isAttached(obj)
            tf = obj.IsOpen;
        end

        function hf = getFigForTest(obj)
            hf = obj.hFig_;
        end

        function s = lastRefreshedLabelForTest(obj)
        %LASTREFRESHEDLABELFORTEST Test helper: read the "Last refreshed:" label String.
        %   Returns '' when the window is detached or the label is invalid.
            s = '';
            if ~isempty(obj.hLastRefreshLbl_) && isvalid(obj.hLastRefreshLbl_)
                s = obj.hLastRefreshLbl_.String;
            end
        end

        function tickForTest(obj)
        %TICKFORTEST Test helper: drive a single onRefreshTick_ synchronously.
        %   Mirrors what the RefreshTimer_ does on its 1s cadence -- used by
        %   the UI test that asserts the "Last refreshed" label updates
        %   after a simulated refresh tick. 260519-bs4-04 patch.
            obj.onRefreshTick_();
        end

        function s = pauseBtnLabelForTest(obj)
        %PAUSEBTNLABELFORTEST Test helper: read the Pause/Resume button text.
        %   Returns '' when the window is detached or the button is invalid.
        %   260519-bs4-05 patch.
            s = '';
            if ~isempty(obj.hPauseBtn_) && isvalid(obj.hPauseBtn_)
                s = obj.hPauseBtn_.String;
            end
        end

        function t = refreshTimerForTest(obj)
        %REFRESHTIMERFORTEST Test helper: return the underlying RefreshTimer_.
        %   Returns [] when the window is detached or the timer is invalid.
        %   260519-bs4-05 patch.
            t = [];
            if ~isempty(obj.RefreshTimer_) && isvalid(obj.RefreshTimer_)
                t = obj.RefreshTimer_;
            end
        end

    end

    methods (Access = private)

        function onCloseRequest_(obj)
        %ONCLOSEREQUEST_ Order: stop+delete timer -> drop listeners -> notify DetachClosed -> delete figure.
            % --- Stop and delete the refresh timer BEFORE listener cleanup. ---
            % stop(t) then delete(t) order is required by the project's
            % cross-cutting engineering constraint (Phase 1018 lock).
            obj.stopRefreshTimer_();
            try
                for ii = 1:numel(obj.Listeners_)
                    try
                        lh = obj.Listeners_{ii};
                        if isobject(lh) && isvalid(lh)
                            delete(lh);
                        end
                    catch
                    end
                end
                obj.Listeners_ = {};
            catch
            end
            try
                notify(obj, 'DetachClosed');
            catch
            end
            try
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    delete(obj.hFig_);
                end
            catch
            end
            obj.hFig_            = [];
            obj.hTable_          = [];
            obj.hSearch_         = [];
            obj.hStatusLbl_      = [];
            obj.hSearchLbl_      = [];
            obj.hHeaderLbl_      = [];
            obj.hLastRefreshLbl_ = [];
            obj.hPauseBtn_       = [];
            obj.hWikiBtn_        = [];
            obj.hChipsType_      = [];
            obj.hChipsCrit_      = [];
            obj.hChipsActivity_  = [];
            obj.IsOpen           = false;
        end

        function rebuildAll_(obj)
        %REBUILDALL_ Replace RowBuffer_ with one row per registered tag (sorted).
            obj.RowBuffer_ = cell(0, 12);
            obj.KeyToRow_  = containers.Map('KeyType', 'char', 'ValueType', 'double');
            try
                tags = TagRegistry.find(@(t) true);
            catch
                tags = {};
            end
            keys = cell(1, numel(tags));
            for k = 1:numel(tags)
                try
                    keys{k} = char(tags{k}.Key);
                catch
                    keys{k} = '';
                end
            end
            % Drop tags without a usable Key.
            mask = ~cellfun('isempty', keys);
            keys = keys(mask);
            tags = tags(mask);
            % Sort by key for deterministic order.
            [keysSorted, ord] = sort(keys);
            tags = tags(ord);
            % Preallocate the buffer up front.
            nTags = numel(tags);
            obj.RowBuffer_ = cell(nTags, 12);
            nowSec = TagStatusTableWindow.nowSeconds_();
            % Bucket events by tag key ONCE for the whole rebuild
            % (260519-bs4-06 patch). O(M events) instead of O(N tags *
            % M events) when each call to getEventsForTag walks the store.
            eventCountsByKey = obj.precomputeEventCounts_(keysSorted);
            for k = 1:nTags
                obj.RowBuffer_(k, :) = TagStatusTableWindow.buildRow_( ...
                    tags{k}, nowSec, eventCountsByKey);
                obj.KeyToRow_(keysSorted{k}) = k;
            end
        end

        function applyFilter_(obj)
        %APPLYFILTER_ Push RowBuffer_ (filtered) into hTable_.Data + update footer.
        %   Combines the case-insensitive substring search with the three
        %   chip groups (Type / Criticality / Activity). 260519-bs4-04 patch.
            if isempty(obj.hTable_) || ~isvalid(obj.hTable_); return; end
            qry = '';
            if ~isempty(obj.hSearch_) && isvalid(obj.hSearch_)
                qry = obj.hSearch_.String;
            end
            rows = TagStatusTableWindow.filterRows_(obj.RowBuffer_, qry, ...
                obj.ActiveTypeChips_, obj.ActiveCritChips_, obj.ActiveActivityChips_);
            obj.hTable_.Data = rows;
            if ~isempty(obj.hStatusLbl_) && isvalid(obj.hStatusLbl_)
                obj.hStatusLbl_.String = sprintf('%d / %d tags', ...
                    size(rows, 1), size(obj.RowBuffer_, 1));
            end
        end

        function tag = resolveTag_(~, key)
        %RESOLVETAG_ Look up a tag by key in the registry singleton.
            try
                tag = TagRegistry.get(key);
            catch
                tag = [];
            end
        end

        function counts = precomputeEventCounts_(obj, keys)
        %PRECOMPUTEEVENTCOUNTS_ Bucket EventStore events by tag key in one pass.
        %   Walks every distinct EventStore reachable through the listed
        %   tag keys, calls obj.EventStore.getEventsForTag(key) ONCE per
        %   key, and totals into a containers.Map. The savings come from
        %   the fact that we resolve each tag at most once per tick and
        %   only count keys we actually need (the keys passed in).
        %
        %   When EventStore.getEventsForTag is O(N events) (current
        %   implementation walks all events), this collapses N tag-row
        %   builds * N events to N keys * N events, which is the same
        %   cost order but ensures the work happens at a single,
        %   debug-friendly call site rather than scattered through
        %   buildRow_.
        %
        %   Returns a containers.Map(char -> double); empty when keys is
        %   empty or when no tag has an EventStore. Wrapped in try/catch;
        %   failure returns an empty map and buildRow_ falls back to the
        %   per-tag query path (still O(M events) but at least correct).
        %   260519-bs4-06 patch.
            counts = containers.Map('KeyType', 'char', 'ValueType', 'double');
            if isempty(keys); return; end
            if ischar(keys); keys = {keys}; end
            if ~iscell(keys); return; end
            try
                for k = 1:numel(keys)
                    key = char(keys{k});
                    if isempty(key); continue; end
                    tag = obj.resolveTag_(key);
                    if isempty(tag); continue; end
                    n = TagStatusTableWindow.countEventsForTag_(tag);
                    counts(key) = n;
                end
            catch
                % Best-effort -- a failure here should not abort the tick.
                % buildRow_ will fall back to per-row queries below.
            end
        end

        function pair = stripePairFromTheme_(~, t)
        %STRIPEPAIRFROMTHEME_ 2x3 stripe pair derived from theme brightness.
            isDark = mean(t.DashboardBackground) < 0.5;
            if isDark
                pair = [0.13 0.13 0.13; 0.20 0.20 0.20];
            else
                pair = [1.00 1.00 1.00; 0.94 0.94 0.94];
            end
        end

        function buildChipStrip_(obj, t)
        %BUILDCHIPSTRIP_ Build the three chip groups (Type / Crit / Activity).
        %   Layout: 5 Type chips on the left, 4 Criticality chips in the
        %   middle, 2 Activity chips on the right -- with small visual
        %   gaps between groups. All chips toggle on click.
        %   Mirrors the multi-toggle pill pattern from TagCatalogPane.
        %   260519-bs4-04 patch.
            nType = numel(obj.TypeChipKeys_);
            nCrit = numel(obj.CritChipKeys_);
            nAct  = numel(obj.ActivityChipKeys_);

            % Strip allocation: 0.01 .. 0.99 = 0.98 wide.
            stripL  = 0.01;
            stripW  = 0.98;
            y       = 0.84;
            h       = 0.045;
            % Groups occupy roughly 5/11, 4/11, 2/11 of the strip width
            % with small inter-group gutters.
            gutter  = 0.012;
            usable  = stripW - 2 * gutter;
            wType   = usable * nType / (nType + nCrit + nAct);
            wCrit   = usable * nCrit / (nType + nCrit + nAct);
            wAct    = usable * nAct  / (nType + nCrit + nAct);

            % --- Type chips ---
            obj.hChipsType_ = obj.makeChipRow_(t, ...
                stripL, y, wType, h, ...
                obj.TypeChipLabels_, obj.TypeChipKeys_, ...
                @(key) obj.onTypeChip_(key));

            % --- Criticality chips ---
            obj.hChipsCrit_ = obj.makeChipRow_(t, ...
                stripL + wType + gutter, y, wCrit, h, ...
                obj.CritChipLabels_, obj.CritChipKeys_, ...
                @(key) obj.onCritChip_(key));

            % --- Activity chips ---
            obj.hChipsActivity_ = obj.makeChipRow_(t, ...
                stripL + wType + wCrit + 2 * gutter, y, wAct, h, ...
                obj.ActivityChipLabels_, obj.ActivityChipKeys_, ...
                @(key) obj.onActivityChip_(key));

            % Apply initial styling (all active).
            obj.applyChipStyles_();
        end

        function btns = makeChipRow_(obj, t, xLeft, yBottom, width, height, ...
                labels, keys, callbackFn)
        %MAKECHIPROW_ Create a row of equally-spaced uicontrol pushbuttons.
        %   Returns a 1xN array of uicontrol handles, one per label.
            n = numel(labels);
            btns = gobjects(1, n);
            chipW = width / n;
            for i = 1:n
                x = xLeft + (i - 1) * chipW;
                btns(i) = uicontrol(obj.hFig_, ...
                    'Style',               'pushbutton', ...
                    'Units',               'normalized', ...
                    'Position',            [x yBottom chipW * 0.96 height], ...
                    'String',              labels{i}, ...
                    'BackgroundColor',     t.WidgetBackground, ...
                    'ForegroundColor',     t.ForegroundColor, ...
                    'FontSize',            10, ...
                    'Callback',            chipCallback_(callbackFn, keys{i}));
            end
        end

        function applyChipStyles_(obj)
        %APPLYCHIPSTYLES_ Apply active/inactive visual style to all chip groups.
        %   Active chips use theme Accent background + bold; inactive chips
        %   use the theme WidgetBackground + normal weight. No-op when the
        %   chip arrays are empty (e.g. window detached).
            if isempty(obj.Theme_); return; end
            t = obj.Theme_;
            obj.applyChipStyleGroup_(obj.hChipsType_,     obj.TypeChipKeys_,     obj.ActiveTypeChips_,     t);
            obj.applyChipStyleGroup_(obj.hChipsCrit_,     obj.CritChipKeys_,     obj.ActiveCritChips_,     t);
            obj.applyChipStyleGroup_(obj.hChipsActivity_, obj.ActivityChipKeys_, obj.ActiveActivityChips_, t);
        end

        function applyChipStyleGroup_(~, hChips, allKeys, activeKeys, t)
        %APPLYCHIPSTYLEGROUP_ Apply per-chip styling for a single group.
            if isempty(hChips); return; end
            % Active-state colors mirror TagCatalogPane.applyPillStyle_:
            % accent bg + dark fg + bold for active; normal otherwise.
            for i = 1:numel(hChips)
                btn = hChips(i);
                if ~isgraphics(btn) || ~isvalid(btn); continue; end
                isActive = any(strcmp(activeKeys, allKeys{i}));
                if isActive
                    btn.BackgroundColor = t.Accent;
                    btn.ForegroundColor = t.DashboardBackground;
                    btn.FontWeight      = 'bold';
                else
                    btn.BackgroundColor = t.WidgetBackground;
                    btn.ForegroundColor = t.ForegroundColor;
                    btn.FontWeight      = 'normal';
                end
            end
        end

        function onTypeChip_(obj, key)
        %ONTYPECHIP_ Toggle a Type chip and re-apply the filter.
            obj.ActiveTypeChips_ = toggleKey_(obj.ActiveTypeChips_, key);
            obj.applyChipStyles_();
            obj.applyFilter_();
        end

        function onCritChip_(obj, key)
        %ONCRITCHIP_ Toggle a Criticality chip and re-apply the filter.
            obj.ActiveCritChips_ = toggleKey_(obj.ActiveCritChips_, key);
            obj.applyChipStyles_();
            obj.applyFilter_();
        end

        function onActivityChip_(obj, key)
        %ONACTIVITYCHIP_ Toggle an Activity chip and re-apply the filter.
            obj.ActiveActivityChips_ = toggleKey_(obj.ActiveActivityChips_, key);
            obj.applyChipStyles_();
            obj.applyFilter_();
        end

        function setLastRefreshedNow_(obj)
        %SETLASTREFRESHEDNOW_ Update the "Last refreshed: HH:MM:SS" label to now.
        %   24h clock, second precision, local time. No-op when the label
        %   is invalid (window detached). When paused, appends " (paused)"
        %   suffix so the user sees the freshness state -- but the timer
        %   does not tick while paused, so this branch is only reached
        %   from the synchronous resume path (where the suffix is dropped
        %   right after by refreshPauseUi_) and from defensive callers.
        %   260519-bs4-04 patch; paused-suffix added in 260519-bs4-05.
            if isempty(obj.hLastRefreshLbl_) || ~isvalid(obj.hLastRefreshLbl_)
                return;
            end
            try
                ts = char(datetime('now', 'Format', 'HH:mm:ss'));
            catch
                % Octave / stripped MATLAB fallback.
                ts = datestr(now, 'HH:MM:SS');  %#ok<DATST,TNOW1>
            end
            if obj.PollingActive_
                obj.hLastRefreshLbl_.String = sprintf('Last refreshed: %s', ts);
            else
                obj.hLastRefreshLbl_.String = sprintf('Last refreshed: %s (paused)', ts);
            end
        end

        function refreshPauseUi_(obj)
        %REFRESHPAUSEUI_ Sync the Pause/Resume button label and header suffix.
        %   Called from setPollingActive after PollingActive_ flips. Does
        %   NOT update the "Last refreshed" timestamp -- it only rewrites
        %   the suffix in-place so the previous HH:MM:SS is preserved
        %   (the user can see WHEN the polling stopped, per the spec).
        %   260519-bs4-05 patch.
            % --- Button label ---
            if ~isempty(obj.hPauseBtn_) && isvalid(obj.hPauseBtn_)
                if obj.PollingActive_
                    obj.hPauseBtn_.String = 'Pause polling';
                else
                    obj.hPauseBtn_.String = 'Resume polling';
                end
            end
            % --- Header label "(paused)" suffix maintenance ---
            if isempty(obj.hLastRefreshLbl_) || ~isvalid(obj.hLastRefreshLbl_)
                return;
            end
            cur = obj.hLastRefreshLbl_.String;
            if ~ischar(cur)
                return;
            end
            hasSuffix = ~isempty(regexp(cur, '\(paused\)\s*$', 'once'));
            if obj.PollingActive_ && hasSuffix
                % Drop the trailing " (paused)".
                obj.hLastRefreshLbl_.String = regexprep(cur, '\s*\(paused\)\s*$', '');
            elseif ~obj.PollingActive_ && ~hasSuffix
                % Add the " (paused)" suffix to the existing timestamp.
                obj.hLastRefreshLbl_.String = [strtrim(cur), ' (paused)'];
            end
        end

        function startRefreshTimer_(obj)
        %STARTREFRESHTIMER_ Create and start the window-owned refresh timer.
        %   Independent of companion Live mode -- guarantees the table
        %   re-queries every tag every RefreshPeriod_ seconds while open,
        %   so Activity / Last updated stay accurate even when the
        %   companion is idle. Wrapped in try/catch; failure to construct
        %   the timer (e.g. on a stripped-down environment) is non-fatal:
        %   the push-on-write path from scanLiveTagUpdates_ still works.
        %   260519-bs4 patch.
            obj.RefreshErrCount_ = 0;
            try
                if ~isempty(obj.RefreshTimer_) && isvalid(obj.RefreshTimer_)
                    stop(obj.RefreshTimer_);
                    delete(obj.RefreshTimer_);
                end
                % Unique name so orphan timers from crashed tests can be
                % discovered via timerfindall and cleaned up.
                tName = sprintf('TagStatusTable-%s', randomTimerSuffix_());
                obj.RefreshTimer_ = timer( ...
                    'Name',          tName, ...
                    'Period',        obj.RefreshPeriod_, ...
                    'ExecutionMode', 'fixedSpacing', ...
                    'BusyMode',      'drop', ...
                    'TimerFcn',      @(~, ~) obj.onRefreshTick_());
                start(obj.RefreshTimer_);
            catch err
                warning('FastSenseCompanion:tagStatusTableTimerStart', ...
                    'TagStatusTableWindow: failed to start refresh timer: %s', ...
                    err.message);
                obj.RefreshTimer_ = [];
            end
        end

        function stopRefreshTimer_(obj)
        %STOPREFRESHTIMER_ Stop and delete the refresh timer in stop+delete order.
            try
                if ~isempty(obj.RefreshTimer_) && isvalid(obj.RefreshTimer_)
                    try
                        stop(obj.RefreshTimer_);
                    catch
                    end
                    delete(obj.RefreshTimer_);
                end
            catch
                % Teardown must never throw.
            end
            obj.RefreshTimer_ = [];
        end

        function openWiki_(obj)
        %OPENWIKI_ Route to the Companion's shared WikiBrowser; fall back to standalone.
        %   Phase 1034 -- Wiki button click handler. Prefers routing through
        %   the parent Companion's openWiki entry point so a single
        %   WikiBrowser handle is reused across the session. Falls back to
        %   constructing a standalone WikiBrowser if the companion handle
        %   is missing / invalid (defensive; under normal use the companion
        %   is always set via openWith()).
            try
                if ~isempty(obj.Companion_) && isvalid(obj.Companion_) && ...
                        isa(obj.Companion_, 'FastSenseCompanion') && ...
                        ismethod(obj.Companion_, 'openWiki')
                    obj.Companion_.openWiki('Tag-Status-Table');
                    return;
                end
                % Fallback (no companion handle): construct a standalone Wiki window.
                WikiBrowser('OpenTo', 'Tag-Status-Table');
            catch ME
                try
                    errordlg(sprintf('Failed to open Wiki: %s', ME.message), 'Wiki');
                catch
                    fprintf(2, '[TagStatusTableWindow] openWiki_ failed: %s\n', ME.message);
                end
            end
        end

        function onRefreshTick_(obj)
        %ONREFRESHTICK_ Re-query every tracked tag; only repaint when data changed.
        %   Wrapped in try/catch; logs via `warning` rather than uialert
        %   (uialert per tick would be noise-storm). After 2 consecutive
        %   ticks throw, the timer self-stops to prevent log flooding.
            if ~obj.IsOpen
                return;
            end
            try
                nowSec = TagStatusTableWindow.nowSeconds_();
                changed = false;
                keys = obj.KeyToRow_.keys();
                % Bucket events by tag key ONCE per tick rather than
                % querying the store N times (one per row). Cheap when
                % store is empty / not bound. 260519-bs4-06 patch.
                eventCountsByKey = obj.precomputeEventCounts_(keys);
                for k = 1:numel(keys)
                    key = keys{k};
                    if ~obj.KeyToRow_.isKey(key); continue; end
                    idx = obj.KeyToRow_(key);
                    tag = obj.resolveTag_(key);
                    if isempty(tag); continue; end
                    newRow = TagStatusTableWindow.buildRow_(tag, nowSec, eventCountsByKey);
                    oldRow = obj.RowBuffer_(idx, :);
                    if ~isequal(newRow, oldRow)
                        obj.RowBuffer_(idx, :) = newRow;
                        changed = true;
                    end
                end
                if changed
                    obj.applyFilter_();
                end
                % Always update the "Last refreshed" label after a clean
                % tick -- even when no rows changed. Proves the polling
                % is alive and matches the user's expectation that the
                % label is a heartbeat indicator. 260519-bs4-04 patch.
                obj.setLastRefreshedNow_();
                obj.RefreshErrCount_ = 0;   % reset on a clean tick
            catch err
                obj.RefreshErrCount_ = obj.RefreshErrCount_ + 1;
                warning('FastSenseCompanion:tagStatusTableTickFailed', ...
                    'TagStatusTableWindow refresh tick failed: %s', err.message);
                if obj.RefreshErrCount_ >= 2
                    warning('FastSenseCompanion:tagStatusTableTickAborted', ...
                        ['TagStatusTableWindow refresh timer self-stopped ' ...
                        'after 2 consecutive failures.']);
                    obj.stopRefreshTimer_();
                end
            end
        end

    end

    methods (Static, Access = public)

        function row = buildRow_(tag, nowSeconds, eventCountsByKey)
        %BUILDROW_ Return a 1x12 cell row describing tag's current status.
        %   Columns: Key, Name, Type, Criticality, Units, Latest, Status,
        %            Last updated, Activity, Events, Samples, Labels.
        %
        %   Inputs:
        %     tag               -- Tag handle (any subclass; tolerant of throws)
        %     nowSeconds        -- (optional) current wall-clock time as posix
        %                          seconds, used for the Activity column. When
        %                          omitted, TagStatusTableWindow.nowSeconds_()
        %                          is queried. Tests pass an explicit value for
        %                          determinism. 260519-bs4 patch.
        %     eventCountsByKey  -- (optional) containers.Map(char -> double)
        %                          giving precomputed per-tag event counts.
        %                          When the tag's Key is present in the map,
        %                          the Events column reads from the map.
        %                          Otherwise falls back to
        %                          countEventsForTag_(tag) which walks the
        %                          tag's bound EventStore. Pass [] or omit
        %                          to force the per-tag query. 260519-bs4-06.
        %
        %   The Activity column is "Live" when X(end) is within
        %   InactiveThresholdSeconds_ (5 minutes) of nowSeconds in the same
        %   time base, else "Inactive". Empty / unconvertible / future X
        %   defensively renders "Inactive".
        %
        %   The Events column shows an integer count of events attached to
        %   the tag (via EventStore.getEventsForTag). Tags with no
        %   EventStore -- or any throw during the count -- render "0".
        %   260519-bs4-06 patch.
        %
        %   Never throws -- a tag whose getXY/valueAt fails renders em-dash
        %   placeholders for the dynamic columns AND "Inactive" for Activity.
            if nargin < 2 || isempty(nowSeconds)
                nowSeconds = TagStatusTableWindow.nowSeconds_();
            end
            if nargin < 3
                eventCountsByKey = [];
            end
            em       = char(8212);
            key      = '';
            name     = '';
            kind     = '';
            crit     = '';
            units    = '';
            labelStr = '';
            try
                key      = char(tag.Key);
                name     = char(tag.Name);
                kind     = char(tag.getKind());
                crit     = char(tag.Criticality);
                units    = char(tag.Units);
                if ~isempty(tag.Labels) && iscell(tag.Labels)
                    labelStr = strjoin(tag.Labels, ', ');
                end
            catch
                % Tag-level metadata read failed; best-effort defaults remain.
            end
            typeLabel = capitalize_(kind);

            latestTxt      = em;
            statusTxt      = em;
            lastUpdatedTxt = em;
            activityTxt    = 'Inactive';
            samplesTxt     = '0';

            try
                [X, Y] = tag.getXY();
                n = numel(Y);
                samplesTxt = sprintf('%d', n);
                if n > 0
                    % --- Latest ---
                    if iscell(Y)
                        latestTxt = char(Y{end});
                    elseif isnumeric(Y) && isfinite(Y(end))
                        latestTxt = formatNumber_(Y(end));
                    end
                    % --- Last updated + Activity ---
                    if isnumeric(X) && isfinite(X(end))
                        lastUpdatedTxt = formatLastUpdated_(X(end));
                        activityTxt    = computeActivity_(X(end), nowSeconds, ...
                            TagStatusTableWindow.InactiveThresholdSeconds_);
                    end
                    % --- Status (kind-aware) ---
                    switch kind
                        case 'monitor'
                            if isnumeric(Y) && Y(end) > 0.5
                                statusTxt = 'ALARM';
                            else
                                statusTxt = 'OK';
                            end
                        case 'state'
                            stateTxt = em;
                            try
                                v = tag.valueAt(X(end));
                                if iscell(v)
                                    if ~isempty(v); stateTxt = char(v{1}); end
                                elseif ischar(v) || (isstring(v) && isscalar(v))
                                    stateTxt = char(v);
                                elseif isnumeric(v) && isscalar(v) && isfinite(v)
                                    stateTxt = formatNumber_(v);
                                end
                            catch
                                if iscell(Y)
                                    stateTxt = char(Y{end});
                                end
                            end
                            statusTxt = stateTxt;
                        otherwise
                            statusTxt = em;
                    end
                end
            catch
                % Leave placeholders; never throw.
            end

            % --- Events count (260519-bs4-06) ---
            %   Bucketed-by-key precomputed map preferred; falls back to a
            %   per-tag query when missing. countEventsForTag_ never throws.
            useBucket = ~isempty(eventCountsByKey) && ...
                isa(eventCountsByKey, 'containers.Map') && ...
                ~isempty(key) && eventCountsByKey.isKey(key);
            if useBucket
                try
                    nEvents = double(eventCountsByKey(key));
                catch
                    nEvents = 0;
                end
            else
                nEvents = TagStatusTableWindow.countEventsForTag_(tag);
            end
            eventsTxt = sprintf('%d', nEvents);

            row = {key, name, typeLabel, crit, units, ...
                   latestTxt, statusTxt, lastUpdatedTxt, activityTxt, ...
                   eventsTxt, samplesTxt, labelStr};
        end

        function n = countEventsForTag_(tag)
        %COUNTEVENTSFORTAG_ Integer count of events attached to a Tag.
        %   Returns 0 for tags with no EventStore, [] EventStore, or any
        %   exception raised while querying. Delegates to tag.eventsAttached
        %   when available (the Tag base class API, which itself wraps
        %   EventStore.getEventsForTag), so tag subclasses that override
        %   the lookup (e.g. MonitorTag binding to a shared store) all
        %   route through the same query path. Pure function -- safe to
        %   call from the refresh loop without side effects.
        %   260519-bs4-06 patch.
            n = 0;
            if isempty(tag); return; end
            try
                % Skip cheap-fail-fast cases without touching the store.
                if ~isprop(tag, 'EventStore') || isempty(tag.EventStore)
                    return;
                end
                if ismethod(tag, 'eventsAttached')
                    events = tag.eventsAttached();
                else
                    events = tag.EventStore.getEventsForTag(char(tag.Key));
                end
                if isempty(events)
                    n = 0;
                else
                    n = numel(events);
                end
            catch
                % EventStore not bound / throws / etc. -> 0
                n = 0;
            end
        end

        function s = nowSeconds_()
        %NOWSECONDS_ Return current wall-clock time as posix seconds.
        %   Used as the reference for the Activity column. Posix-seconds
        %   is chosen because it composes cleanly with both posixtime
        %   (s > 1e9) and datenum (s > 7e5) X bases via computeActivity_.
        %   Falls back to 0 if datetime/posixtime are not available, in
        %   which case all rows render "Inactive" (defensive). 260519-bs4.
            try
                s = posixtime(datetime('now'));
            catch
                try
                    % Octave fallback: compute posix from now() (datenum).
                    s = (now - datenum(1970, 1, 1)) * 86400;
                catch
                    s = 0;
                end
            end
        end

        function out = filterRows_(rows, query, activeTypes, activeCrits, activeActivities)
        %FILTERROWS_ Combined search + chip filter over a buffer of rows.
        %   filterRows_(rows, query) -- search-only (backward-compatible signature).
        %   filterRows_(rows, query, activeTypes, activeCrits, activeActivities)
        %     applies all four dimensions.
        %
        %   Inputs:
        %     rows       -- cell(N, 12) buffer (TagStatusTableWindow.RowBuffer_).
        %     query      -- char/string; empty / whitespace = no search filter.
        %     activeTypes      -- cellstr subset of {sensor, monitor,
        %                         composite, state, derived}. Omitted = all kept.
        %     activeCrits      -- cellstr subset of {low, medium, high, safety}.
        %                         Omitted = all kept.
        %     activeActivities -- cellstr subset of {live, inactive}.
        %                         Omitted = all kept.
        %
        %   Semantics:
        %     -- search: substring match (case-insensitive) on Key, Name,
        %        Units, OR Labels (Labels are stored as a comma-joined string
        %        in column 12; was column 11 pre-260519-bs4-06).
        %     -- chip groups: AND across groups (a row passes only if it
        %        matches the active set of every group), OR within a group
        %        (a row matches if its value is in the active set).
        %     -- A chip group with ZERO active entries excludes ALL rows
        %        for that dimension (the "no selection -> show nothing"
        %        rule called out in the patch spec).
        %
        %   Returns the filtered cell array (preserves row ordering).
        %   260519-bs4-04 patch.
            if nargin < 3, activeTypes      = []; end
            if nargin < 4, activeCrits      = []; end
            if nargin < 5, activeActivities = []; end
            if isempty(rows)
                out = rows;
                return;
            end
            % --- Search query ---
            qry = '';
            if ischar(query)
                qry = strtrim(query);
            elseif isstring(query) && isscalar(query)
                qry = strtrim(char(query));
            end
            qLow = lower(qry);
            haveQuery = ~isempty(qLow);
            % --- Chip-state interpretation ---
            % nargin convention separates "argument omitted (skip chip
            % filter)" from "argument supplied as empty (= zero chips
            % active -> exclude all)". The internal sentinels NaN/[]
            % below encode this.
            applyTypes = ~isempty(activeTypes) || (nargin >= 3 && iscell(activeTypes));
            applyCrits = ~isempty(activeCrits) || (nargin >= 4 && iscell(activeCrits));
            applyAct   = ~isempty(activeActivities) || (nargin >= 5 && iscell(activeActivities));
            % "Zero chips selected" short-circuit: if any group is applied
            % AND empty, the table is empty.
            if (applyTypes && isempty(activeTypes)) || ...
                    (applyCrits && isempty(activeCrits)) || ...
                    (applyAct   && isempty(activeActivities))
                out = cell(0, size(rows, 2));
                return;
            end
            keep = true(size(rows, 1), 1);
            for i = 1:size(rows, 1)
                if haveQuery && ~rowMatchesSearch_(rows(i, :), qLow)
                    keep(i) = false;
                    continue;
                end
                if applyTypes && ~rowMatchesType_(rows(i, :), activeTypes)
                    keep(i) = false;
                    continue;
                end
                if applyCrits && ~rowMatchesCrit_(rows(i, :), activeCrits)
                    keep(i) = false;
                    continue;
                end
                if applyAct && ~rowMatchesActivity_(rows(i, :), activeActivities)
                    keep(i) = false;
                    continue;
                end
            end
            out = rows(keep, :);
        end

    end
end

% =================== Local helper subfunctions ===================

function s = capitalize_(str)
%CAPITALIZE_ ASCII first-letter capitalize; empty in/out unchanged.
    if isempty(str)
        s = '';
        return;
    end
    str = char(str);
    s = [upper(str(1)), lower(str(2:end))];
end

function s = formatNumber_(v)
%FORMATNUMBER_ Mirror LiveLogPane.addLiveLogEntry number-formatting rules.
    s = '0';
    if ~isnumeric(v) || ~isscalar(v) || ~isfinite(v)
        return;
    end
    a = abs(v);
    if a == 0
        s = '0';
    elseif a >= 1000 || a < 0.01
        s = sprintf('%.3g', v);
    elseif a >= 100
        s = sprintf('%.0f', v);
    elseif a >= 10
        s = sprintf('%.2f', v);
    else
        s = sprintf('%.3f', v);
    end
end

function s = formatLastUpdated_(x)
%FORMATLASTUPDATED_ Treat x as MATLAB datenum if in [1971, 2100], else %.3f.
    s = sprintf('%.3f', x);
    try
        dt = datetime(x, 'ConvertFrom', 'datenum');
        y = year(dt);
        if y >= 1971 && y <= 2100
            s = char(dt, 'yyyy-MM-dd HH:mm:ss');
        end
    catch
        % Keep numeric fallback.
    end
end

function s = computeActivity_(xLast, nowSec, thresholdSec)
%COMPUTEACTIVITY_ Return 'Live' or 'Inactive' based on xLast vs nowSec.
%   Time-base inference mirrors InspectorPane.formatXTick_:
%     xLast > 1e9 -> posixtime seconds (compare directly to nowSec)
%     xLast > 7e5 -> MATLAB datenum days (convert to posix seconds)
%     else        -> "seconds-since-something" we cannot anchor; Inactive.
%   Defensive cases: NaN / non-finite / future timestamp -> Inactive.
%   260519-bs4 patch.
    s = 'Inactive';
    if ~isnumeric(xLast) || ~isscalar(xLast) || ~isfinite(xLast)
        return;
    end
    if ~isnumeric(nowSec) || ~isscalar(nowSec) || ~isfinite(nowSec) || nowSec <= 0
        return;
    end
    xPosix = NaN;
    if xLast > 1e9
        xPosix = xLast;
    elseif xLast > 7e5
        % datenum days -> posix seconds.
        xPosix = (xLast - datenum(1970, 1, 1)) * 86400;
    end
    if ~isfinite(xPosix)
        return;
    end
    deltaSec = nowSec - xPosix;
    % Negative delta = future timestamp (clock skew or test fixture);
    % treat defensively as Inactive.
    if deltaSec < 0
        return;
    end
    if deltaSec < thresholdSec
        s = 'Live';
    end
end

function s = randomTimerSuffix_()
%RANDOMTIMERSUFFIX_ Short unique suffix for the refresh timer name.
%   Used so multiple concurrent windows / orphans from crashed tests can
%   be discovered via `timerfindall('Name','TagStatusTable-*')`.
    try
        s = char(java.util.UUID.randomUUID().toString());
    catch
        % Fallback: timestamp + random digits (no Java).
        s = sprintf('%.0f-%d', now * 86400, randi(1e6));
    end
end

function fn = chipCallback_(callbackFn, key)
%CHIPCALLBACK_ Build a 2-arg uicontrol Callback that closes over a chip key.
%   Captures `key` at chip-construction time so a single chip-handler
%   method on the class can route per-chip clicks via a closure. Mirrors
%   the closure trick used in TagCatalogPane's loop over kindKeys/critKeys.
    fn = @(~, ~) callbackFn(key);
end

function out = toggleKey_(activeKeys, key)
%TOGGLEKEY_ Add `key` to `activeKeys` if absent, else remove it.
    if any(strcmp(activeKeys, key))
        out = activeKeys(~strcmp(activeKeys, key));
    else
        out = [activeKeys, {key}];
    end
end

function tf = rowMatchesSearch_(row, qLow)
%ROWMATCHESSEARCH_ Case-insensitive substring match on Key+Name+Units+Labels.
%   row -- 1x12 cell. Columns 1 (Key), 2 (Name), 5 (Units), 12 (Labels).
%   (Labels column moved 11 -> 12 in 260519-bs4-06 when Events was inserted.)
%   qLow -- already-lowercased query.
%   Tolerates rows with missing / non-char columns (defensive try/catch).
    tf = false;
    try
        for c = [1, 2, 5, 12]
            val = row{c};
            if ~ischar(val); continue; end
            if ~isempty(strfind(lower(val), qLow)) %#ok<STREMP>
                tf = true;
                return;
            end
        end
    catch
        % Malformed row -- treat as non-match.
    end
end

function tf = rowMatchesType_(row, activeTypes)
%ROWMATCHESTYPE_ Column 3 (Type, e.g. 'Sensor') in activeTypes (lowercase)?
    tf = false;
    try
        tf = any(strcmpi(activeTypes, row{3}));
    catch
    end
end

function tf = rowMatchesCrit_(row, activeCrits)
%ROWMATCHESCRIT_ Column 4 (Criticality, lowercase) in activeCrits?
    tf = false;
    try
        tf = any(strcmpi(activeCrits, row{4}));
    catch
    end
end

function tf = rowMatchesActivity_(row, activeActivities)
%ROWMATCHESACTIVITY_ Column 9 (Activity, 'Live'/'Inactive') in activeActivities?
    tf = false;
    try
        tf = any(strcmpi(activeActivities, row{9}));
    catch
    end
end
