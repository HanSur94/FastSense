classdef TagCatalogPane < handle
%TAGCATALOGPANE Searchable, filterable tag catalog for FastSenseCompanion.
%
%   Left-pane component: debounced search field, kind + criticality filter
%   pills, grouped uilistbox with multi-select, count badge.
%   Selection is stored in SelectedKeys_ (separate from uilistbox.Value)
%   so it survives filter changes.
%
%   Usage (called by FastSenseCompanion):
%     pane.attach(parentPanel, hFig, registry, theme)
%     pane.detach()   — cleanup before panel rebuild
%     pane.refresh()  — re-snapshot registry; rebuild listbox in place
%
%   Events fired:
%     TagSelectionChanged — payload: SelectedKeys_ cellstr
%
%   See also FastSenseCompanion, filterTags, groupByLabel, CompanionTheme.

    events
        TagSelectionChanged
    end

    properties (Access = private)
        hPanel_            = []   % uipanel (set by attach)
        hFig_              = []   % uifigure handle (for uialert)
        hSearchField_      = []   % uieditfield (search)
        hSearchClear_      = []   % uibutton (x clear)
        hPillsKind_        = {}   % 1x4 cell of uibutton
        hPillsCriticality_ = {}   % 1x4 cell of uibutton
        hListbox_          = []   % uilistbox
        hCountLabel_       = []   % uilabel (count badge)
        Listeners_         = {}   % addlistener returns; deleted on detach
        SelectedKeys_      = {}   % source-of-truth selection (cellstr)
        ActiveKindPills_   = {}   % active kind keys e.g. {'sensor','monitor'}
        ActiveCritPills_   = {}   % active crit keys e.g. {'high','safety'}
        AllTags_           = {}   % snapshot cell of Tag handles
        SearchTerm_        = ''   % current search string
        DebounceTimer_     = []   % timer or []; nil until first keystroke
        Theme_             = []   % resolved CompanionTheme struct
        Registry_          = []   % TagRegistry reference for refresh()
    end

    methods (Access = public)

        function attach(obj, parentPanel, hFig, registry, theme)
        %ATTACH Build the tag catalog UI inside parentPanel.
        %   parentPanel — uipanel from FastSenseCompanion.hLeftPanel_
        %   hFig        — uifigure handle (for uialert parenting)
        %   registry    — TagRegistry reference
        %   theme       — resolved CompanionTheme struct
            obj.hPanel_   = parentPanel;
            obj.hFig_     = hFig;
            obj.Registry_ = registry;
            obj.Theme_    = theme;

            % Clear existing children
            delete(obj.hPanel_.Children);

            % Snapshot tags from registry
            obj.AllTags_ = TagRegistry.find(@(t) true);

            % Reset filter state
            obj.SelectedKeys_    = {};
            obj.ActiveKindPills_ = {};
            obj.ActiveCritPills_ = {};
            obj.SearchTerm_      = '';

            % --- Build 9-row x 1-col uigridlayout per UI-SPEC ---
            hGrid = uigridlayout(obj.hPanel_, [9 1]);
            hGrid.RowHeight     = {28, 8, 24, 4, 24, 8, '1x', 4, 24};
            hGrid.ColumnWidth   = {'1x'};
            hGrid.Padding       = [16 16 16 16];
            hGrid.RowSpacing    = 0;
            hGrid.BackgroundColor = obj.Theme_.WidgetBackground;

            % --- Row 1: Search field + clear button (nested 1x2 grid) ---
            hSearchGrid = uigridlayout(hGrid, [1 2]);
            hSearchGrid.Layout.Row    = 1;
            hSearchGrid.Layout.Column = 1;
            hSearchGrid.ColumnWidth   = {'1x', 24};
            hSearchGrid.RowHeight     = {'1x'};
            hSearchGrid.Padding       = [0 0 0 0];
            hSearchGrid.ColumnSpacing = 4;
            hSearchGrid.BackgroundColor = obj.Theme_.WidgetBackground;

            obj.hSearchField_ = uieditfield(hSearchGrid, 'text');
            obj.hSearchField_.Layout.Row      = 1;
            obj.hSearchField_.Layout.Column   = 1;
            obj.hSearchField_.Placeholder     = ['Search tags', char(8230)];
            obj.hSearchField_.FontSize        = 11;
            obj.hSearchField_.FontColor       = obj.Theme_.ForegroundColor;
            obj.hSearchField_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hSearchField_.ValueChangedFcn = @(~,~) obj.onSearchChanged_();
            obj.hSearchField_.KeyPressFcn     = @(~,e) obj.onSearchKeyPress_(e);

            obj.hSearchClear_ = uibutton(hSearchGrid, 'push');
            obj.hSearchClear_.Layout.Row      = 1;
            obj.hSearchClear_.Layout.Column   = 2;
            obj.hSearchClear_.Text            = char(215);
            obj.hSearchClear_.Tooltip         = 'Clear search';
            obj.hSearchClear_.FontSize        = 11;
            obj.hSearchClear_.FontColor       = obj.Theme_.ToolbarFontColor;
            obj.hSearchClear_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hSearchClear_.ButtonPushedFcn = @(~,~) obj.onClearSearch_();

            % --- Row 3: Kind pill row (nested 1x4 grid) ---
            hKindGrid = uigridlayout(hGrid, [1 4]);
            hKindGrid.Layout.Row    = 3;
            hKindGrid.Layout.Column = 1;
            hKindGrid.ColumnWidth   = {'1x', '1x', '1x', '1x'};
            hKindGrid.RowHeight     = {'1x'};
            hKindGrid.Padding       = [0 0 0 0];
            hKindGrid.ColumnSpacing = 4;
            hKindGrid.BackgroundColor = obj.Theme_.WidgetBackground;

            kindLabels = {'Sensor', 'State', 'Monitor', 'Composite'};
            kindKeys   = {'sensor', 'state', 'monitor', 'composite'};
            obj.hPillsKind_ = cell(1, 4);
            for i = 1:4
                btn = uibutton(hKindGrid, 'push');
                btn.Layout.Row       = 1;
                btn.Layout.Column    = i;
                btn.Text             = kindLabels{i};
                btn.FontSize         = 11;
                btn.ButtonPushedFcn  = @(~,~) obj.onKindPill_(kindKeys{i});
                obj.hPillsKind_{i}   = btn;
            end
            obj.applyPillStyle_(obj.hPillsKind_, {});

            % --- Row 5: Criticality pill row (nested 1x4 grid) ---
            hCritGrid = uigridlayout(hGrid, [1 4]);
            hCritGrid.Layout.Row    = 5;
            hCritGrid.Layout.Column = 1;
            hCritGrid.ColumnWidth   = {'1x', '1x', '1x', '1x'};
            hCritGrid.RowHeight     = {'1x'};
            hCritGrid.Padding       = [0 0 0 0];
            hCritGrid.ColumnSpacing = 4;
            hCritGrid.BackgroundColor = obj.Theme_.WidgetBackground;

            critLabels = {'Low', 'Medium', 'High', 'Safety'};
            critKeys   = {'low', 'medium', 'high', 'safety'};
            obj.hPillsCriticality_ = cell(1, 4);
            for i = 1:4
                btn = uibutton(hCritGrid, 'push');
                btn.Layout.Row          = 1;
                btn.Layout.Column       = i;
                btn.Text                = critLabels{i};
                btn.FontSize            = 11;
                btn.ButtonPushedFcn     = @(~,~) obj.onCritPill_(critKeys{i});
                obj.hPillsCriticality_{i} = btn;
            end
            obj.applyPillStyle_(obj.hPillsCriticality_, {});

            % --- Row 7: Tag listbox ---
            obj.hListbox_ = uilistbox(hGrid);
            obj.hListbox_.Layout.Row       = 7;
            obj.hListbox_.Layout.Column    = 1;
            obj.hListbox_.Multiselect      = 'on';
            obj.hListbox_.FontSize         = 11;
            obj.hListbox_.FontColor        = obj.Theme_.ForegroundColor;
            obj.hListbox_.BackgroundColor  = obj.Theme_.WidgetBackground;
            obj.hListbox_.ValueChangedFcn  = @(~,~) obj.onListboxChanged_();

            % --- Row 9: Count badge ---
            obj.hCountLabel_ = uilabel(hGrid);
            obj.hCountLabel_.Layout.Row          = 9;
            obj.hCountLabel_.Layout.Column       = 1;
            obj.hCountLabel_.FontSize            = 11;
            obj.hCountLabel_.FontColor           = obj.Theme_.PlaceholderTextColor;
            obj.hCountLabel_.HorizontalAlignment = 'left';
            obj.hCountLabel_.VerticalAlignment   = 'middle';
            obj.hCountLabel_.BackgroundColor     = obj.Theme_.WidgetBackground;

            % Build initial listbox content
            obj.applyFilter_();
        end

        function detach(obj)
        %DETACH Release listeners and debounce timer. Does not delete the panel.
            % Stop and delete debounce timer (ALWAYS stop before delete)
            if ~isempty(obj.DebounceTimer_) && isvalid(obj.DebounceTimer_)
                stop(obj.DebounceTimer_);
                delete(obj.DebounceTimer_);
            end
            obj.DebounceTimer_ = [];
            % Release listeners
            delete(obj.Listeners_);
            obj.Listeners_ = {};
        end

        function refresh(obj)
        %REFRESH Re-snapshot all tags from TagRegistry and rebuild the listbox.
        %   Preserves SelectedKeys_ (drops keys no longer in snapshot).
        %   Call after externally registering or unregistering tags.
            obj.AllTags_ = TagRegistry.find(@(t) true);
            % Prune SelectedKeys_ to only those still present in snapshot
            allKeys = cellfun(@(t) t.Key, obj.AllTags_, 'UniformOutput', false);
            obj.SelectedKeys_ = intersect(obj.SelectedKeys_, allKeys);
            % Rebuild listbox with current filter state
            obj.applyFilter_();
        end

    end

    methods (Access = private)

        function applyFilter_(obj)
        %APPLYFILTER_ Rebuild listbox content from AllTags_ using current filter state.
            try
                filteredTags = filterTags(obj.AllTags_, obj.SearchTerm_, ...
                                           obj.ActiveKindPills_, obj.ActiveCritPills_);
                [items, itemsData] = groupByLabel(filteredTags);

                % Collect visible tag keys (non-header rows have char itemsData)
                visibleKeys = {};
                for i = 1:numel(itemsData)
                    if ischar(itemsData{i}) && ~isempty(itemsData{i})
                        visibleKeys{end+1} = itemsData{i}; %#ok<AGROW>
                    end
                end

                % Apply to listbox
                obj.hListbox_.Items     = items;
                obj.hListbox_.ItemsData = itemsData;

                % Restore selection: only show selected keys that are currently visible
                selectedVisible = intersect(obj.SelectedKeys_, visibleKeys);
                if isempty(selectedVisible)
                    obj.hListbox_.Value = {};
                else
                    obj.hListbox_.Value = selectedVisible;
                end

                % Update count badge
                nVisible = numel(visibleKeys);
                nTotal   = numel(obj.AllTags_);
                nSel     = numel(obj.SelectedKeys_);
                if nSel > 0
                    obj.hCountLabel_.Text = sprintf('%d of %d visible %s %d selected', ...
                        nVisible, nTotal, char(183), nSel);
                else
                    obj.hCountLabel_.Text = sprintf('%d of %d visible', nVisible, nTotal);
                end
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onSearchChanged_(obj)
        %ONSEARCHCHANGED_ Handle search field value change — debounced.
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
        %ONSEARCHKEYPRESS_ Handle Esc key in search field — immediate clear + filter.
            try
                if strcmp(event.Key, 'escape')
                    obj.hSearchField_.Value = '';
                    obj.SearchTerm_ = '';
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
                obj.SearchTerm_ = '';
                obj.applyFilter_();
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onKindPill_(obj, key)
        %ONKINDPILL_ Toggle kind pill and refilter.
            try
                if any(strcmp(obj.ActiveKindPills_, key))
                    obj.ActiveKindPills_ = obj.ActiveKindPills_(~strcmp(obj.ActiveKindPills_, key));
                else
                    obj.ActiveKindPills_{end+1} = key;
                end
                obj.applyPillStyle_(obj.hPillsKind_, obj.ActiveKindPills_);
                obj.applyFilter_();
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onCritPill_(obj, key)
        %ONCRITPILL_ Toggle criticality pill and refilter.
            try
                if any(strcmp(obj.ActiveCritPills_, key))
                    obj.ActiveCritPills_ = obj.ActiveCritPills_(~strcmp(obj.ActiveCritPills_, key));
                else
                    obj.ActiveCritPills_{end+1} = key;
                end
                obj.applyPillStyle_(obj.hPillsCriticality_, obj.ActiveCritPills_);
                obj.applyFilter_();
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onListboxChanged_(obj)
        %ONLISTBOXCHANGED_ Handle listbox selection — reject headers, update SelectedKeys_.
            try
                selected = obj.hListbox_.Value;
                if ~iscell(selected)
                    selected = {selected};
                end
                % Filter out group-header rows (ItemsData == [] means header)
                validKeys = {};
                for i = 1:numel(selected)
                    if ischar(selected{i}) && ~isempty(selected{i})
                        validKeys{end+1} = selected{i}; %#ok<AGROW>
                    end
                end
                obj.SelectedKeys_ = validKeys;
                % Re-apply to reject header selections
                obj.hListbox_.Value = validKeys;
                % Update count badge
                nVisible = sum(cellfun(@(d) ischar(d) && ~isempty(d), obj.hListbox_.ItemsData));
                nTotal   = numel(obj.AllTags_);
                nSel     = numel(obj.SelectedKeys_);
                if nSel > 0
                    obj.hCountLabel_.Text = sprintf('%d of %d visible %s %d selected', ...
                        nVisible, nTotal, char(183), nSel);
                else
                    obj.hCountLabel_.Text = sprintf('%d of %d visible', nVisible, nTotal);
                end
                % Fire event for orchestrator (Phase 1021 will listen)
                notify(obj, 'TagSelectionChanged');
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function applyPillStyle_(obj, pillHandles, activeKeys)
        %APPLYPILLSTYLE_ Apply active/inactive visual state to pill buttons.
            for i = 1:numel(pillHandles)
                btn    = pillHandles{i};
                btnKey = lower(btn.Text);
                if any(strcmp(activeKeys, btnKey))
                    btn.BackgroundColor = obj.Theme_.Accent;
                    btn.FontColor       = obj.Theme_.DashboardBackground;
                    btn.FontWeight      = 'bold';
                else
                    btn.BackgroundColor = obj.Theme_.WidgetBackground;
                    btn.FontColor       = obj.Theme_.ToolbarFontColor;
                    btn.FontWeight      = 'normal';
                end
            end
        end

    end
end
