classdef MachineSelectorPane < handle
%MACHINESELECTORPANE Searchable single-select machine list for FastSenseCompanion.
%
%   Left-rail component (added only when a Fleet is supplied): a debounced
%   search field, a single-select uilistbox of the fleet's machines in
%   insertion order, and a count badge. A deliberately reduced copy of
%   TagCatalogPane — no filter pills, no group headers, one active machine
%   at a time.
%
%   Per-row label is 'Name (Group)' when Group is non-empty, else 'Name';
%   the listbox ItemsData carries each machine's Id so selection recovers
%   the machine without string parsing.
%
%   Usage (called by FastSenseCompanion):
%     pane.attach(parentPanel, hFig, fleet, theme)
%     pane.detach()              — cleanup before panel rebuild / on close
%     pane.selectById(id)        — programmatic select (test seam)
%     pane.setTheme(themeStruct) — live theme switch
%
%   Events fired:
%     MachineSelectionChanged — payload: MachineSelectionEventData(selectedId)
%
%   See also FastSenseCompanion, filterMachines, MachineSelectionEventData,
%            Fleet, TagCatalogPane, CompanionTheme.

    events
        MachineSelectionChanged
    end

    properties (Access = private)
        hPanel_        = []   % uipanel (set by attach)
        hFig_          = []   % uifigure handle (for uialert)
        hSearchField_  = []   % uieditfield (search)
        hSearchClear_  = []   % uibutton (x clear)
        hListbox_      = []   % uilistbox (single-select)
        hCountLabel_   = []   % uilabel (count badge / placeholder)
        Listeners_     = {}   % addlistener returns; deleted on detach
        AllMachines_   = {}   % snapshot cell of Machine handles (full fleet)
        SearchTerm_    = ''   % current search string
        DebounceTimer_ = []   % timer or []; nil until first keystroke
        Theme_         = []   % resolved CompanionTheme struct
        Fleet_         = []   % Fleet handle (data source)
    end

    methods (Access = public)

        function attach(obj, parentPanel, hFig, fleet, theme)
        %ATTACH Build the machine selector UI inside parentPanel.
        %   parentPanel — uipanel from FastSenseCompanion.hMachineSelectorPanel_
        %   hFig        — uifigure handle (for uialert parenting)
        %   fleet       — Fleet reference (data source, insertion order)
        %   theme       — resolved CompanionTheme struct
            obj.hPanel_ = parentPanel;
            obj.hFig_   = hFig;
            obj.Fleet_  = fleet;
            obj.Theme_  = theme;

            % Clear existing children
            delete(obj.hPanel_.Children);

            % Snapshot machines from the fleet in insertion order
            obj.AllMachines_ = {};
            if ~isempty(fleet) && isa(fleet, 'Fleet')
                ids = fleet.machineIds();
                obj.AllMachines_ = cell(1, numel(ids));
                for i = 1:numel(ids)
                    obj.AllMachines_{i} = fleet.getMachine(ids{i});
                end
            end

            % Reset filter state
            obj.SearchTerm_ = '';

            % --- Build 5-row x 1-col uigridlayout per UI-SPEC ---
            hGrid = uigridlayout(obj.hPanel_, [5 1]);
            hGrid.RowHeight     = {28, 8, '1x', 4, 24};
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
            % Placeholder is R2021a+; tolerated on R2020b.
            try, obj.hSearchField_.Placeholder = ['Search machines', char(8230)]; catch, end
            obj.hSearchField_.FontSize        = 11;
            obj.hSearchField_.FontColor       = obj.Theme_.ForegroundColor;
            obj.hSearchField_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hSearchField_.ValueChangedFcn = @(~,~) obj.onSearchChanged_();

            obj.hSearchClear_ = uibutton(hSearchGrid, 'push');
            obj.hSearchClear_.Layout.Row      = 1;
            obj.hSearchClear_.Layout.Column   = 2;
            obj.hSearchClear_.Text            = char(215);
            obj.hSearchClear_.Tooltip         = 'Clear search';
            obj.hSearchClear_.FontSize        = 11;
            obj.hSearchClear_.FontColor       = obj.Theme_.ToolbarFontColor;
            obj.hSearchClear_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hSearchClear_.ButtonPushedFcn = @(~,~) obj.onClearSearch_();

            % --- Row 3: Machine listbox (single-select) ---
            obj.hListbox_ = uilistbox(hGrid);
            obj.hListbox_.Layout.Row      = 3;
            obj.hListbox_.Layout.Column   = 1;
            obj.hListbox_.Multiselect     = 'off';   % single-select: one active machine
            obj.hListbox_.FontSize        = 11;
            obj.hListbox_.FontColor       = obj.Theme_.ForegroundColor;
            obj.hListbox_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.hListbox_.ValueChangedFcn = @(src,~) obj.onMachineSelected_(src.Value);

            % --- Row 5: Count badge / placeholder ---
            obj.hCountLabel_ = uilabel(hGrid);
            obj.hCountLabel_.Layout.Row          = 5;
            obj.hCountLabel_.Layout.Column       = 1;
            obj.hCountLabel_.FontSize            = 11;
            obj.hCountLabel_.FontColor           = obj.Theme_.PlaceholderTextColor;
            obj.hCountLabel_.HorizontalAlignment = 'left';
            obj.hCountLabel_.VerticalAlignment   = 'center';
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
            % delete(cellArray) is interpreted as filename-delete by MATLAB
            % ("Name must be a text scalar"). Iterate explicitly.
            for ii = 1:numel(obj.Listeners_)
                lh = obj.Listeners_{ii};
                if isobject(lh) && isvalid(lh)
                    delete(lh);
                end
            end
            obj.Listeners_ = {};
        end

        function selectById(obj, id)
        %SELECTBYID Programmatically select a machine by Id — public test seam.
        %   Sets the listbox Value and fires the same MachineSelectionChanged
        %   event a real click would. Used by TestFastSenseCompanion's
        %   timer-stability and active-context tests (Plan 05).
            if ~isempty(obj.hListbox_) && isvalid(obj.hListbox_)
                obj.hListbox_.Value = id;
            end
            obj.onMachineSelected_(id);
        end

        function setTheme(obj, t)
        %SETTHEME Live theme switch — recolor children in place.
        %   t — resolved CompanionTheme struct. Walks the pane subtree via
        %   applyThemeToChildren_ (covers ListBox/EditField/Button/Label/
        %   GridLayout), then re-applies the pane-specific subdued accents the
        %   walker overwrote.
            if ~isstruct(t); return; end
            try
                obj.Theme_ = t;
                if ~isempty(obj.hPanel_) && isvalid(obj.hPanel_)
                    applyThemeToChildren_(obj.hPanel_, t);
                end
                % Post-walk pane-specific overrides.
                if ~isempty(obj.hSearchClear_) && isvalid(obj.hSearchClear_)
                    obj.hSearchClear_.FontColor = t.ToolbarFontColor;
                end
                if ~isempty(obj.hCountLabel_) && isvalid(obj.hCountLabel_)
                    obj.hCountLabel_.FontColor = t.PlaceholderTextColor;
                end
            catch err
                warning('FastSenseCompanion:setThemeFailed', ...
                    'MachineSelectorPane.setTheme failed: %s', err.message);
            end
        end

    end

    methods (Access = private)

        function applyFilter_(obj)
        %APPLYFILTER_ Rebuild listbox content from AllMachines_ using SearchTerm_.
        %   Items = 'Name (Group)' / 'Name'; ItemsData = machine Id.
        %   Badge = 'N machines' or 'No machines match'.
            try
                filtered  = filterMachines(obj.AllMachines_, obj.SearchTerm_);
                items     = cell(1, numel(filtered));
                itemsData = cell(1, numel(filtered));
                for i = 1:numel(filtered)
                    m = filtered{i};
                    if ~isempty(m.Group)
                        items{i} = [m.Name ' (' m.Group ')'];
                    else
                        items{i} = m.Name;
                    end
                    itemsData{i} = m.Id;
                end
                obj.hListbox_.Items     = items;
                obj.hListbox_.ItemsData = itemsData;
                n = numel(filtered);
                if n == 0
                    obj.hCountLabel_.Text = 'No machines match';
                else
                    obj.hCountLabel_.Text = sprintf('%d machines', n);
                end
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onSearchChanged_(obj)
        %ONSEARCHCHANGED_ Handle search field value change — debounced (150 ms).
            try
                obj.SearchTerm_ = obj.hSearchField_.Value;
                % Lazy-create timer on first keystroke
                if isempty(obj.DebounceTimer_)
                    obj.DebounceTimer_ = timer();
                    obj.DebounceTimer_.ExecutionMode = 'singleShot';
                    % singleShot timers fire StartDelay seconds after start();
                    % Period only applies to the fixed* execution modes.
                    obj.DebounceTimer_.StartDelay    = 0.150;
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

        function onMachineSelected_(obj, selectedId)
        %ONMACHINESELECTED_ Fire MachineSelectionChanged carrying the selected Id.
        %   selectedId — char machine Id (from the listbox ItemsData).
        %   The orchestrator (FastSenseCompanion) listens and performs the
        %   stop-live -> setProject -> restart-live switch (Plan 04).
            try
                if isempty(selectedId)
                    return;
                end
                notify(obj, 'MachineSelectionChanged', ...
                    MachineSelectionEventData(selectedId));
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'FastSense Companion');
                else
                    rethrow(err);
                end
            end
        end

    end
end
