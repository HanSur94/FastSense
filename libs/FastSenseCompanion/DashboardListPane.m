classdef DashboardListPane < handle
%DASHBOARDLISTPANE Searchable list of DashboardEngine instances for FastSenseCompanion.
%
%   Middle pane: per-row container with name (clickable row-area button),
%   widget count, IsLive status dot, and Open button. Search field narrows
%   rows by case-insensitive substring on engine.Name (150 ms debounce).
%
%   Usage (called by FastSenseCompanion):
%     pane.attach(parentPanel, hFig, engines, theme)
%     pane.detach()              % cleanup before panel rebuild
%     pane.refresh(engines)      % rebuild row list from updated engines snapshot
%
%   Events fired:
%     DashboardSelected         payload: DashboardEventData(engine, idx)
%     OpenDashboardRequested    payload: DashboardEventData(engine, idx)
%
%   See also FastSenseCompanion, filterDashboards, DashboardEventData,
%            CompanionTheme.

    events
        DashboardSelected
        OpenDashboardRequested
    end

    properties (Access = private)
        hPanel_           = []   % parent uipanel
        hFig_             = []   % uifigure handle (for uialert)
        hSearchField_     = []   % uieditfield
        hSearchClear_     = []   % uibutton ('x')
        hScroll_          = []   % uipanel Scrollable='on'
        hRowGrid_         = []   % uigridlayout (rows x 1)
        hRowButtons_      = {}   % cell, per-row row-area uibutton
        hOpenButtons_     = {}   % cell, per-row 'Open' uibutton
        hDotLabels_       = {}   % cell, per-row status-dot uilabel
        hRowCountLabels_  = {}   % cell, per-row '(N)' uilabel
        hCountLabel_      = []   % bottom count badge uilabel
        Listeners_        = {}   % addlistener returns; deleted on detach
        Engines_          = {}   % snapshot of orchestrator's Engines_
        SearchTerm_       = ''   % current search string
        SelectedIdx_      = 0    % 1-based index of currently selected row (0 = none)
        DebounceTimer_    = []   % lazily-created 150 ms timer
        Theme_            = []   % resolved CompanionTheme struct
    end

    methods (Access = public)

        function attach(obj, parentPanel, hFig, engines, theme)
        %ATTACH Build the dashboard list UI inside parentPanel.
        %   parentPanel — uipanel from FastSenseCompanion.hMidPanel_
        %   hFig        — uifigure handle (for uialert parenting)
        %   engines     — cell array of DashboardEngine handles (snapshot)
        %   theme       — resolved CompanionTheme struct
            obj.hPanel_   = parentPanel;
            obj.hFig_     = hFig;
            obj.Engines_  = engines;
            obj.Theme_    = theme;

            % Reset state
            obj.SearchTerm_ = '';
            obj.SelectedIdx_ = 0;

            % Clear any prior content
            delete(obj.hPanel_.Children);

            % --- Build 5-row x 1-col uigridlayout per UI-SPEC ---
            hOuter = uigridlayout(obj.hPanel_, [5 1]);
            hOuter.RowHeight       = {28, 8, '1x', 4, 24};
            hOuter.ColumnWidth     = {'1x'};
            hOuter.Padding         = [16 16 16 16];
            hOuter.RowSpacing      = 0;
            hOuter.BackgroundColor = obj.Theme_.WidgetBackground;

            % --- Row 1: Search field + clear button (nested 1x2 grid) ---
            hSearchGrid = uigridlayout(hOuter, [1 2]);
            hSearchGrid.Layout.Row      = 1;
            hSearchGrid.Layout.Column   = 1;
            hSearchGrid.ColumnWidth     = {'1x', 24};
            hSearchGrid.RowHeight       = {'1x'};
            hSearchGrid.Padding         = [0 0 0 0];
            hSearchGrid.ColumnSpacing   = 4;
            hSearchGrid.BackgroundColor = obj.Theme_.WidgetBackground;

            obj.hSearchField_ = uieditfield(hSearchGrid, 'text');
            obj.hSearchField_.Layout.Row      = 1;
            obj.hSearchField_.Layout.Column   = 1;
            obj.hSearchField_.Placeholder     = ['Search dashboards', char(8230)];
            obj.hSearchField_.FontSize        = 11;
            obj.hSearchField_.FontColor       = obj.Theme_.ForegroundColor;
            obj.hSearchField_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hSearchField_.ValueChangedFcn = @(~,~) obj.onSearchChanged_();
            % Note: uieditfield has no KeyPressFcn (only uifigure has
            % WindowKeyPressFcn). Esc-to-clear deferred — the × clear
            % button satisfies BROWSER-04's keyboard-reachable clear.

            obj.hSearchClear_ = uibutton(hSearchGrid, 'push');
            obj.hSearchClear_.Layout.Row       = 1;
            obj.hSearchClear_.Layout.Column    = 2;
            obj.hSearchClear_.Text             = char(215);
            obj.hSearchClear_.Tooltip          = 'Clear search';
            obj.hSearchClear_.FontSize         = 11;
            obj.hSearchClear_.FontColor        = obj.Theme_.ToolbarFontColor;
            obj.hSearchClear_.BackgroundColor  = obj.Theme_.WidgetBackground;
            obj.hSearchClear_.ButtonPushedFcn  = @(~,~) obj.onClearSearch_();

            % --- Row 3: Scrollable container for row list ---
            obj.hScroll_ = uipanel(hOuter);
            obj.hScroll_.Layout.Row      = 3;
            obj.hScroll_.Layout.Column   = 1;
            obj.hScroll_.Scrollable      = 'on';
            obj.hScroll_.BorderType      = 'none';
            obj.hScroll_.BackgroundColor = obj.Theme_.WidgetBackground;

            % --- Row 5: Count badge ---
            obj.hCountLabel_ = uilabel(hOuter);
            obj.hCountLabel_.Layout.Row          = 5;
            obj.hCountLabel_.Layout.Column       = 1;
            obj.hCountLabel_.FontSize            = 11;
            obj.hCountLabel_.FontColor           = obj.Theme_.PlaceholderTextColor;
            obj.hCountLabel_.HorizontalAlignment = 'left';
            obj.hCountLabel_.VerticalAlignment   = 'middle';
            obj.hCountLabel_.BackgroundColor     = obj.Theme_.WidgetBackground;

            % Populate initial row list
            obj.applyFilter_();
        end

        function detach(obj)
        %DETACH Release listeners and debounce timer. Does not delete the panel.
            if ~isempty(obj.DebounceTimer_) && isvalid(obj.DebounceTimer_)
                stop(obj.DebounceTimer_);
                delete(obj.DebounceTimer_);
            end
            obj.DebounceTimer_ = [];
            delete(obj.Listeners_);
            obj.Listeners_ = {};
        end

        function refresh(obj, engines)
        %REFRESH Rebuild row list from updated engines snapshot.
        %   engines (optional) — updated cell of DashboardEngine handles.
        %   Preserves SearchTerm_ across rebuild.
            if nargin >= 2
                obj.Engines_ = engines;
            end
            % Clamp SelectedIdx_ if it points past end of (possibly shorter) list
            if obj.SelectedIdx_ > numel(obj.Engines_)
                obj.SelectedIdx_ = 0;
            end
            obj.applyFilter_();
        end

    end

    methods (Access = private)

        function applyFilter_(obj)
        %APPLYFILTER_ Single rebuild path — filter engines and recreate rows.
            try
                filteredIdx = filterDashboards(obj.Engines_, obj.SearchTerm_);
                nTotal = numel(obj.Engines_);

                % Delete old row grid + reset per-row handle caches
                if ~isempty(obj.hRowGrid_) && isvalid(obj.hRowGrid_)
                    delete(obj.hRowGrid_);
                end
                obj.hRowGrid_         = [];
                obj.hRowButtons_      = {};
                obj.hOpenButtons_     = {};
                obj.hDotLabels_       = {};
                obj.hRowCountLabels_  = {};

                % Also clear any stray children of hScroll_ (e.g., empty-state labels)
                if ~isempty(obj.hScroll_) && isvalid(obj.hScroll_)
                    delete(obj.hScroll_.Children);
                end

                if nTotal == 0
                    % Empty state — no dashboards loaded at all
                    obj.renderEmptyState_('No dashboards loaded');
                    obj.hCountLabel_.Text = '0 of 0 visible';
                    return;
                end

                if isempty(filteredIdx)
                    % Search active but no matches
                    obj.renderEmptyState_('No dashboards match');
                    obj.hCountLabel_.Text = sprintf('0 of %d visible', nTotal);
                    return;
                end

                % Create row grid inside scroll container
                nRows = numel(filteredIdx);
                obj.hRowGrid_ = uigridlayout(obj.hScroll_, [nRows 1]);
                obj.hRowGrid_.RowHeight     = repmat({32}, 1, nRows);
                obj.hRowGrid_.ColumnWidth   = {'1x'};
                obj.hRowGrid_.Padding       = [0 0 0 0];
                obj.hRowGrid_.RowSpacing    = 4;
                obj.hRowGrid_.BackgroundColor = obj.Theme_.WidgetBackground;

                % Build one row per matched engine
                for k = 1:nRows
                    obj.buildRow_(k, filteredIdx(k));
                end

                % Update count badge
                obj.hCountLabel_.Text = sprintf('%d of %d visible', nRows, nTotal);
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function buildRow_(obj, rowSlot, engineIdx)
        %BUILDROW_ Construct one dashboard row at the given rowSlot in the grid.
            try
                engine = obj.Engines_{engineIdx};

                % 1x4 row grid: [name-btn | count | dot | open-btn]
                hRow = uigridlayout(obj.hRowGrid_, [1 4]);
                hRow.Layout.Row      = rowSlot;
                hRow.Layout.Column   = 1;
                hRow.ColumnWidth     = {'1x', 'fit', 16, 52};
                hRow.RowHeight       = {32};
                hRow.Padding         = [8 0 8 0];
                hRow.ColumnSpacing   = 4;
                hRow.BackgroundColor = obj.Theme_.WidgetBackground;

                % Column 1 — row-area button (clickable, fires DashboardSelected)
                btn = uibutton(hRow, 'push');
                btn.Layout.Row    = 1;
                btn.Layout.Column = 1;
                btn.Text          = engine.Name;
                btn.FontSize      = 11;
                btn.FontWeight    = 'bold';
                btn.FontColor     = obj.Theme_.ForegroundColor;
                if engineIdx == obj.SelectedIdx_
                    btn.BackgroundColor = obj.Theme_.WidgetBorderColor;
                else
                    btn.BackgroundColor = obj.Theme_.WidgetBackground;
                end
                btn.HorizontalAlignment = 'left';
                btn.Tooltip             = engine.Name;
                btn.ButtonPushedFcn     = @(~,~) obj.onRowClicked_(engineIdx);
                obj.hRowButtons_{end+1} = btn;

                % Column 2 — widget count label
                widgetCount = numel(engine.Widgets);
                for pp = 1:numel(engine.Pages)
                    widgetCount = widgetCount + numel(engine.Pages{pp}.Widgets);
                end
                lbl = uilabel(hRow);
                lbl.Layout.Row          = 1;
                lbl.Layout.Column       = 2;
                lbl.Text                = sprintf('(%d)', widgetCount);
                lbl.FontSize            = 11;
                lbl.FontColor           = obj.Theme_.PlaceholderTextColor;
                lbl.HorizontalAlignment = 'left';
                obj.hRowCountLabels_{end+1} = lbl;

                % Column 3 — status dot (Unicode U+25CF)
                dot = uilabel(hRow);
                dot.Layout.Row    = 1;
                dot.Layout.Column = 3;
                dot.Text          = char(9679);
                dot.FontSize      = 11;
                if engine.IsLive
                    dot.FontColor = obj.Theme_.Accent;
                    dot.Tooltip   = 'Live';
                else
                    dot.FontColor = obj.Theme_.PlaceholderTextColor;
                    dot.Tooltip   = 'Idle';
                end
                dot.HorizontalAlignment = 'center';
                obj.hDotLabels_{end+1} = dot;

                % Column 4 — Open button
                openBtn = uibutton(hRow, 'push');
                openBtn.Layout.Row       = 1;
                openBtn.Layout.Column    = 4;
                openBtn.Text             = 'Open';
                openBtn.FontSize         = 11;
                openBtn.FontColor        = obj.Theme_.ForegroundColor;
                openBtn.BackgroundColor  = obj.Theme_.WidgetBorderColor;
                openBtn.Tooltip          = sprintf('Open "%s" in its own figure', engine.Name);
                openBtn.ButtonPushedFcn  = @(~,~) obj.onOpenClicked_(engineIdx);
                obj.hOpenButtons_{end+1} = openBtn;
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function renderEmptyState_(obj, msgText)
        %RENDEREMPTYSTATE_ Render a centered label inside hScroll_ when no rows to show.
            % Clear prior grid (safety — applyFilter_ also deletes, but be defensive)
            if ~isempty(obj.hRowGrid_) && isvalid(obj.hRowGrid_)
                delete(obj.hRowGrid_);
            end
            obj.hRowGrid_         = [];
            obj.hRowButtons_      = {};
            obj.hOpenButtons_     = {};
            obj.hDotLabels_       = {};
            obj.hRowCountLabels_  = {};
            lbl = uilabel(obj.hScroll_);
            lbl.Text                = msgText;
            lbl.FontSize            = 11;
            lbl.FontColor           = obj.Theme_.PlaceholderTextColor;
            lbl.HorizontalAlignment = 'center';
            lbl.VerticalAlignment   = 'middle';
            lbl.Units               = 'normalized';
            lbl.Position            = [0 0 1 1];
        end

        function onSearchChanged_(obj)
        %ONSEARCHCHANGED_ Handle search field value change with 150 ms debounce.
            try
                obj.SearchTerm_ = obj.hSearchField_.Value;
                % Lazy-create timer on first keystroke
                if isempty(obj.DebounceTimer_)
                    obj.DebounceTimer_ = timer();
                    obj.DebounceTimer_.ExecutionMode = 'singleShot';
                    obj.DebounceTimer_.Period        = 0.150;
                    obj.DebounceTimer_.BusyMode      = 'drop';
                    obj.DebounceTimer_.TimerFcn      = @(~,~) obj.applyFilter_();
                end
                % Reset countdown on each keystroke
                if strcmp(obj.DebounceTimer_.Running, 'on')
                    stop(obj.DebounceTimer_);
                end
                start(obj.DebounceTimer_);
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onSearchKeyPress_(obj, event)
        %ONSEARCHKEYPRESS_ Handle Esc key — immediate clear and filter.
            try
                if strcmp(event.Key, 'escape')
                    obj.hSearchField_.Value = '';
                    obj.SearchTerm_         = '';
                    obj.applyFilter_();
                end
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onClearSearch_(obj)
        %ONCLEARSEARCH_ Handle clear button press — synchronous filter update.
            try
                obj.hSearchField_.Value = '';
                obj.SearchTerm_         = '';
                obj.applyFilter_();
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onRowClicked_(obj, engineIdx)
        %ONROWCLICKED_ Handle row-area button press — update selection and fire event.
            try
                obj.SelectedIdx_ = engineIdx;
                % Rebuild to apply selection highlight (updates BackgroundColor via applyFilter_)
                obj.applyFilter_();
                % Fire DashboardSelected event
                notify(obj, 'DashboardSelected', ...
                    DashboardEventData(obj.Engines_{engineIdx}, engineIdx));
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onOpenClicked_(obj, engineIdx)
        %ONOPENCLICKED_ Handle Open button press — fire event and call engine.render().
            try
                obj.SelectedIdx_ = engineIdx;
                % Fire OpenDashboardRequested
                notify(obj, 'OpenDashboardRequested', ...
                    DashboardEventData(obj.Engines_{engineIdx}, engineIdx));
                engine = obj.Engines_{engineIdx};
                % Attempt render in inner try/catch so companion stays alive on error
                try
                    engine.render();
                catch ME
                    uialert(obj.hFig_, ...
                        sprintf('Failed to open dashboard "%s": %s', engine.Name, ME.message), ...
                        'FastSense Companion');
                end
                % Refresh highlight (row is now selected)
                obj.applyFilter_();
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

    end
end
