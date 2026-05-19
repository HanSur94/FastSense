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
        Registry_     = []        % TagRegistry handle (or class name placeholder)
        Theme_        = []        % resolved CompanionTheme struct
        Companion_    = []        % FastSenseCompanion handle (uialert parent + detach)
        RowBuffer_    = cell(0, 11)
        KeyToRow_     = []        % containers.Map(key -> row index into RowBuffer_)
        Listeners_    = {}        % addlistener handles; deleted in close()
        RefreshTimer_ = []        % timer driving periodic re-query (window-owned; 260519-bs4 patch)
        RefreshErrCount_ = 0      % consecutive errors in onRefreshTick_; auto-stops at 2
    end

    properties (Constant, Access = private)
        RefreshPeriod_           = 1.0    % seconds between RefreshTimer_ ticks
        InactiveThresholdSeconds_ = 300   % >= 5 min since last sample -> Activity = "Inactive"
    end

    methods (Access = public)

        function obj = TagStatusTableWindow()
            obj.RowBuffer_ = cell(0, 11);
            obj.KeyToRow_  = containers.Map('KeyType', 'char', 'ValueType', 'double');
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
            obj.hFig_ = figure( ...
                'Name',             'Tag Status -- FastSense Companion', ...
                'NumberTitle',      'off', ...
                'MenuBar',           'none', ...
                'ToolBar',           'none', ...
                'Color',             t.WidgetBackground, ...
                'Position',          [100 100 1100 520], ...
                'CloseRequestFcn',   @(~,~) obj.onCloseRequest_());
            movegui(obj.hFig_, 'center');

            % --- Top search strip (normalized units) ---
            obj.hSearchLbl_ = uicontrol(obj.hFig_, ...
                'Style',               'text', ...
                'Units',               'normalized', ...
                'Position',            [0.01 0.93 0.06 0.05], ...
                'String',              'Search:', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10);

            obj.hSearch_ = uicontrol(obj.hFig_, ...
                'Style',               'edit', ...
                'Units',               'normalized', ...
                'Position',            [0.07 0.93 0.43 0.055], ...
                'String',              '', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10, ...
                'Callback',            @(~,~) obj.applyFilter_());

            obj.hHeaderLbl_ = uicontrol(obj.hFig_, ...
                'Style',               'text', ...
                'Units',               'normalized', ...
                'Position',            [0.55 0.93 0.44 0.05], ...
                'String',              'Tags', ...
                'HorizontalAlignment', 'right', ...
                'BackgroundColor',     t.WidgetBackground, ...
                'ForegroundColor',     t.ForegroundColor, ...
                'FontSize',            10, ...
                'FontWeight',          'bold');

            % --- Striped pair derived from theme (mirrors LiveLogPane). ---
            stripePair = obj.stripePairFromTheme_(t);

            % --- Center uitable. ---
            % 11 columns: Activity is column 9 (between Last updated and Samples).
            obj.hTable_ = uitable(obj.hFig_, ...
                'Units',           'normalized', ...
                'Position',        [0.01 0.06 0.98 0.86], ...
                'ColumnName',      {'Key', 'Name', 'Type', 'Criticality', 'Units', ...
                                    'Latest', 'Status', 'Last updated', 'Activity', ...
                                    'Samples', 'Labels'}, ...
                'ColumnWidth',     {130, 200, 75, 80, 60, 90, 80, 140, 70, 70, 'auto'}, ...
                'ColumnEditable',  false(1, 11), ...
                'RowName',         {}, ...
                'FontName',        'Menlo', ...
                'FontSize',        10, ...
                'BackgroundColor', stripePair, ...
                'ForegroundColor', t.ForegroundColor, ...
                'Data',            cell(0, 11));

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

            % --- Fill from registry + apply (initial empty) filter. ---
            obj.rebuildAll_();
            obj.applyFilter_();

            obj.IsOpen = true;

            % --- Start the window-owned refresh timer. ---
            % Independent of companion Live mode so Activity / Last updated
            % stay accurate even when the companion is idle. 260519-bs4 patch.
            obj.startRefreshTimer_();
        end

        function markTagsDirty(obj, keys)
        %MARKTAGSDIRTY Refresh only rows for the listed tag keys.
        %   keys -- cellstr or single char. No-op when ~IsOpen. Whole body
        %   wrapped in try/catch so a live tick can never crash via this path.
            if ~obj.IsOpen; return; end
            if isempty(keys); return; end
            if ischar(keys); keys = {keys}; end
            if ~iscell(keys); return; end
            try
                nowSec = TagStatusTableWindow.nowSeconds_();
                changed = false;
                for k = 1:numel(keys)
                    key = char(keys{k});
                    if isempty(key); continue; end
                    tag = obj.resolveTag_(key);
                    if isempty(tag); continue; end
                    row = TagStatusTableWindow.buildRow_(tag, nowSec);
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
                if ~isempty(obj.hTable_) && isvalid(obj.hTable_)
                    stripePair = obj.stripePairFromTheme_(t);
                    obj.hTable_.BackgroundColor = stripePair;
                    obj.hTable_.ForegroundColor = t.ForegroundColor;
                end
            catch
                % Theme propagation must never throw.
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
            obj.hFig_       = [];
            obj.hTable_     = [];
            obj.hSearch_    = [];
            obj.hStatusLbl_ = [];
            obj.hSearchLbl_ = [];
            obj.hHeaderLbl_ = [];
            obj.IsOpen      = false;
        end

        function rebuildAll_(obj)
        %REBUILDALL_ Replace RowBuffer_ with one row per registered tag (sorted).
            obj.RowBuffer_ = cell(0, 11);
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
            obj.RowBuffer_ = cell(nTags, 11);
            nowSec = TagStatusTableWindow.nowSeconds_();
            for k = 1:nTags
                obj.RowBuffer_(k, :) = TagStatusTableWindow.buildRow_(tags{k}, nowSec);
                obj.KeyToRow_(keysSorted{k}) = k;
            end
        end

        function applyFilter_(obj)
        %APPLYFILTER_ Push RowBuffer_ (filtered) into hTable_.Data + update footer.
            if isempty(obj.hTable_) || ~isvalid(obj.hTable_); return; end
            qry = '';
            if ~isempty(obj.hSearch_) && isvalid(obj.hSearch_)
                qry = obj.hSearch_.String;
            end
            rows = TagStatusTableWindow.filterRows_(obj.RowBuffer_, qry);
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

        function pair = stripePairFromTheme_(~, t)
        %STRIPEPAIRFROMTHEME_ 2x3 stripe pair derived from theme brightness.
            isDark = mean(t.DashboardBackground) < 0.5;
            if isDark
                pair = [0.13 0.13 0.13; 0.20 0.20 0.20];
            else
                pair = [1.00 1.00 1.00; 0.94 0.94 0.94];
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
                for k = 1:numel(keys)
                    key = keys{k};
                    if ~obj.KeyToRow_.isKey(key); continue; end
                    idx = obj.KeyToRow_(key);
                    tag = obj.resolveTag_(key);
                    if isempty(tag); continue; end
                    newRow = TagStatusTableWindow.buildRow_(tag, nowSec);
                    oldRow = obj.RowBuffer_(idx, :);
                    if ~isequal(newRow, oldRow)
                        obj.RowBuffer_(idx, :) = newRow;
                        changed = true;
                    end
                end
                if changed
                    obj.applyFilter_();
                end
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

        function row = buildRow_(tag, nowSeconds)
        %BUILDROW_ Return a 1x11 cell row describing tag's current status.
        %   Columns: Key, Name, Type, Criticality, Units, Latest, Status,
        %            Last updated, Activity, Samples, Labels.
        %
        %   Inputs:
        %     tag        -- Tag handle (any subclass; tolerant of throws)
        %     nowSeconds -- (optional) current wall-clock time as posix
        %                   seconds, used for the Activity column. When
        %                   omitted, TagStatusTableWindow.nowSeconds_() is
        %                   queried (slightly more expensive). Tests pass
        %                   an explicit value for determinism. 260519-bs4 patch.
        %
        %   The Activity column is "Live" when X(end) is within
        %   InactiveThresholdSeconds_ (5 minutes) of nowSeconds in the same
        %   time base, else "Inactive". Empty / unconvertible / future X
        %   defensively renders "Inactive".
        %
        %   Never throws -- a tag whose getXY/valueAt fails renders em-dash
        %   placeholders for the dynamic columns AND "Inactive" for Activity.
            if nargin < 2 || isempty(nowSeconds)
                nowSeconds = TagStatusTableWindow.nowSeconds_();
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

            row = {key, name, typeLabel, crit, units, ...
                   latestTxt, statusTxt, lastUpdatedTxt, activityTxt, ...
                   samplesTxt, labelStr};
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

        function out = filterRows_(rows, query)
        %FILTERROWS_ Case-insensitive substring filter on columns Key + Name.
        %   Empty/whitespace query returns rows unchanged.
            if isempty(rows)
                out = rows;
                return;
            end
            qry = '';
            if ischar(query)
                qry = strtrim(query);
            elseif isstring(query) && isscalar(query)
                qry = strtrim(char(query));
            end
            if isempty(qry)
                out = rows;
                return;
            end
            qLow = lower(qry);
            keep = false(size(rows, 1), 1);
            for i = 1:size(rows, 1)
                k = '';
                n = '';
                try
                    k = lower(rows{i, 1});
                    n = lower(rows{i, 2});
                catch
                    % Row missing string columns -- skip without crashing.
                end
                if ~isempty(strfind(k, qLow)) || ~isempty(strfind(n, qLow)) %#ok<STREMP>
                    keep(i) = true;
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
