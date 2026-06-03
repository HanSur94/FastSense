classdef CanonicalMapEditor < handle
    %CANONICALMAPEDITOR Standalone uifigure to review/edit/promote a CanonicalMapper.
    %   ed = CanonicalMapEditor(mapper) opens a non-modal window showing every mapping
    %   entry in a 6-column table (Logical Sensor / Machine / Local Key / Units Match /
    %   Confidence / Status). The user can Promote a LOW-confidence or unit-mismatch entry
    %   to CONFIRMED (gated by a warning dialog), Override a row's local key, filter to
    %   pending entries, and Save the map to JSON.
    %
    %   This is the human review surface for CANON-05 — the only way to promote an
    %   unreviewed match into the comparison-eligible set ("no wrong comparison can happen
    %   silently"). It is a STANDALONE editor (it never modifies or embeds into the
    %   Companion — full Companion embedding is Phase 1044) and is MATLAB-only (uifigure;
    %   Octave is unsupported, exactly like FastSenseCompanion / TagStatusTableWindow).
    %
    %   Usage:
    %     m  = CanonicalMapper(); m.suggest(tagInfos);
    %     ed = CanonicalMapEditor(m);   % opens the window
    %
    %   Properties (read-only):
    %     IsOpen   true while the window is open
    %
    %   Methods:
    %     CanonicalMapEditor - construct + open the editor over a CanonicalMapper
    %     (interaction is via the on-screen buttons; see UI-SPEC 1041-UI-SPEC.md)
    %
    %   See also CanonicalMapper.

    properties (SetAccess = private)
        Mapper_              % CanonicalMapper handle
        hFig_                % uifigure handle
        Table_               % uitable handle
        PromoteBtn_          % uibutton (primary CTA)
        OverrideBtn_         % uibutton
        ShowPendingBtn_      % uibutton (toggle)
        StatusLabel_         % uilabel (count text)
        FilterField_         % uieditfield (text filter)
        SelectedRow_ = []    % index into the current Data / RowEntries_
        RowEntries_  = {}     % cell of entry structs, parallel to table rows
        Theme_               % active CompanionTheme struct (or dark fallback)
        FilePath_ = ''       % assigned on first Save
        IsDirty_ = false     % unsaved confirm/override changes
        ShowPendingOnly_ = false
        FilterText_ = ''
        Listeners_ = {}
    end

    properties
        IsOpen = false       % public — testEditorConstructs asserts this
    end

    methods
        function obj = CanonicalMapEditor(mapper)
            %CANONICALMAPEDITOR Construct and open the editor over a CanonicalMapper.
            if nargin < 1 || ~isa(mapper, 'CanonicalMapper')
                error('CanonicalMapEditor:invalidInput', ...
                    'CanonicalMapEditor requires a CanonicalMapper instance.');
            end
            obj.Mapper_ = mapper;
            obj.Theme_ = resolveTheme_();
            t = obj.Theme_;

            obj.hFig_ = uifigure( ...
                'Name', 'Canonical Sensor Map — FastSense Companion', ...
                'Position', [100 100 1000 580], ...
                'Color', t.WidgetBackground);
            obj.hFig_.CloseRequestFcn = @(~, ~) obj.onCloseRequest_();
            drawnow;   % realize the figure before building child widgets (uifigure idiom)

            root = uigridlayout(obj.hFig_, [3 1]);
            root.RowHeight = {28, '1x', 36};
            root.ColumnWidth = {'1x'};
            root.Padding = [24 24 24 24];
            root.RowSpacing = 8;

            % --- Row 1: toolbar strip ---
            bar = uigridlayout(root, [1 5]);
            bar.Layout.Row = 1;
            bar.ColumnWidth = {180, '1x', 80, 80, 80};
            bar.RowHeight = {'1x'};
            bar.Padding = [0 0 0 0];
            bar.ColumnSpacing = 8;

            titleLbl = uilabel(bar, 'Text', 'Canonical Sensor Map', ...
                'FontSize', 14, 'FontWeight', 'bold', 'FontColor', t.ForegroundColor);
            titleLbl.Layout.Column = 1;

            obj.FilterField_ = uieditfield(bar, 'text', ...
                'Placeholder', 'Filter entries...', 'FontSize', 11, ...
                'ValueChangedFcn', @(~, ~) obj.applyFilter_());
            obj.FilterField_.Layout.Column = 2;

            obj.ShowPendingBtn_ = uibutton(bar, 'Text', 'Show Pending', 'FontSize', 11, ...
                'Tooltip', 'Show only entries needing review (LOW confidence or unit mismatch)', ...
                'ButtonPushedFcn', @(~, ~) obj.togglePendingFilter_());
            obj.ShowPendingBtn_.Layout.Column = 3;
            obj.ShowPendingBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.ShowPendingBtn_.FontColor = t.ForegroundColor;

            refreshBtn = uibutton(bar, 'Text', 'Refresh', 'FontSize', 11, ...
                'Tooltip', 'Reload entries from mapper', ...
                'ButtonPushedFcn', @(~, ~) obj.reload_());
            refreshBtn.Layout.Column = 4;

            saveBtn = uibutton(bar, 'Text', 'Save', 'FontSize', 11, ...
                'Tooltip', 'Save canonical map to file', ...
                'ButtonPushedFcn', @(~, ~) obj.onSave_());
            saveBtn.Layout.Column = 5;

            % --- Row 2: table ---
            obj.Table_ = uitable(root);
            obj.Table_.Layout.Row = 2;
            obj.Table_.ColumnName = ...
                {'Logical Sensor', 'Machine', 'Local Key', 'Units Match', 'Confidence', 'Status'};
            obj.Table_.ColumnWidth = {180, 80, 150, 80, 80, 90};
            obj.Table_.ColumnEditable = false(1, 6);
            obj.Table_.RowName = {};
            obj.Table_.FontName = 'Menlo';
            obj.Table_.FontSize = 10;
            obj.Table_.BackgroundColor = stripePairFromTheme_(t);
            obj.Table_.ForegroundColor = t.ForegroundColor;
            obj.Table_.CellSelectionCallback = @(src, ev) obj.onCellSelected_(ev);
            obj.Table_.Data = cell(0, 6);

            % --- Row 3: action row ---
            act = uigridlayout(root, [1 4]);
            act.Layout.Row = 3;
            act.ColumnWidth = {160, 120, '1x', 200};
            act.RowHeight = {'1x'};
            act.Padding = [0 0 0 0];
            act.ColumnSpacing = 8;

            obj.PromoteBtn_ = uibutton(act, 'Text', 'Promote to Confirmed', ...
                'FontSize', 11, 'FontWeight', 'bold', ...
                'Tooltip', 'Mark the selected mapping as Confirmed', ...
                'ButtonPushedFcn', @(~, ~) obj.onPromote_());
            obj.PromoteBtn_.Layout.Column = 1;
            obj.PromoteBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.PromoteBtn_.FontColor = t.ForegroundColor;

            obj.OverrideBtn_ = uibutton(act, 'Text', 'Override Local Key', 'FontSize', 11, ...
                'Tooltip', 'Manually set the local key for the selected row', ...
                'ButtonPushedFcn', @(~, ~) obj.onOverride_());
            obj.OverrideBtn_.Layout.Column = 2;
            obj.OverrideBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.OverrideBtn_.FontColor = t.ForegroundColor;

            obj.StatusLabel_ = uilabel(act, 'Text', '', 'FontSize', 10, ...
                'FontName', 'Menlo', 'FontColor', t.PlaceholderTextColor, ...
                'HorizontalAlignment', 'left');
            obj.StatusLabel_.Layout.Column = 3;

            closeBtn = uibutton(act, 'Text', 'Close', 'FontSize', 11, ...
                'ButtonPushedFcn', @(~, ~) obj.onCloseRequest_());
            closeBtn.Layout.Column = 4;

            obj.reload_();
            obj.IsOpen = true;
        end

        function delete(obj)
            %DELETE Destructor — close the window if still open.
            if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                delete(obj.hFig_);
            end
            obj.IsOpen = false;
        end
    end

    methods (Access = private)
        function reload_(obj)
            %RELOAD_ Rebuild the table Data from the mapper (sorted, filtered, with display rules).
            try
                list = {};
                logIds = keys(obj.Mapper_.Entries_);
                for i = 1:numel(logIds)
                    bucket = obj.Mapper_.Entries_(logIds{i});
                    for j = 1:numel(bucket)
                        list{end + 1} = bucket{j}; %#ok<AGROW>
                    end
                end
                list = obj.sortEntries_(list);
                list = obj.filterEntries_(list);

                nRows = numel(list);
                data = cell(nRows, 6);
                obj.RowEntries_ = cell(1, nRows);
                for r = 1:nRows
                    e = list{r};
                    data{r, 1} = e.logicalId;
                    data{r, 2} = e.machineId;
                    data{r, 3} = e.localKey;
                    if e.unitMismatch
                        data{r, 4} = 'NO';
                    else
                        data{r, 4} = 'YES';
                    end
                    data{r, 5} = obj.confidenceLabel_(e);
                    data{r, 6} = e.status;
                    obj.RowEntries_{r} = e;
                end
                obj.Table_.Data = data;
                obj.SelectedRow_ = [];
                obj.stylePromote_(false);
                obj.updateStatus_();
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, ...
                        sprintf('Failed to reload entries: %s', err.message), 'Reload');
                end
            end
        end

        function out = sortEntries_(~, list)
            %SORTENTRIES_ Stable sort by logicalId (primary) then machineId (secondary).
            if numel(list) < 2
                out = list;
                return;
            end
            mids = cellfun(@(e) e.machineId, list, 'UniformOutput', false);
            [~, o1] = sort(mids);
            list = list(o1);
            lids = cellfun(@(e) e.logicalId, list, 'UniformOutput', false);
            [~, o2] = sort(lids);   % sort is stable -> machineId order preserved within a logicalId
            out = list(o2);
        end

        function out = filterEntries_(obj, list)
            %FILTERENTRIES_ Apply the pending-only toggle and the text filter.
            out = {};
            f = lower(strtrim(obj.FilterText_));
            for i = 1:numel(list)
                e = list{i};
                if obj.ShowPendingOnly_
                    isPending = strcmp(e.confidence, 'LOW') || e.unitMismatch;
                    if ~isPending
                        continue;
                    end
                end
                if ~isempty(f)
                    hay = lower([e.logicalId ' ' e.localKey ' ' e.machineId]);
                    if isempty(strfind(hay, f)) %#ok<STREMP> Octave-safe idiom (no contains())
                        continue;
                    end
                end
                out{end + 1} = e; %#ok<AGROW>
            end
        end

        function label = confidenceLabel_(~, e)
            %CONFIDENCELABEL_ '[!] ' prefix when unit mismatch or LOW; else plain.
            if e.unitMismatch || strcmp(e.confidence, 'LOW')
                label = ['[!] ' e.confidence];
            else
                label = e.confidence;
            end
        end

        function updateStatus_(obj)
            %UPDATESTATUS_ Refresh the count/status label.
            nEntries = numel(obj.RowEntries_);
            if nEntries == 0
                obj.StatusLabel_.Text = 'No mappings yet — run mapper.suggest(tagInfos) first.';
                return;
            end
            nPending = numel(obj.Mapper_.reviewPending());
            if nPending == 0
                obj.StatusLabel_.Text = sprintf('%d entries — all reviewed', nEntries);
            else
                obj.StatusLabel_.Text = sprintf('%d entries, %d pending review', nEntries, nPending);
            end
        end

        function onCellSelected_(obj, ev)
            %ONCELLSELECTED_ Store the selected row and style the Promote CTA.
            if isempty(ev.Indices)
                obj.SelectedRow_ = [];
                obj.stylePromote_(false);
                return;
            end
            obj.SelectedRow_ = ev.Indices(1);
            obj.stylePromote_(true);
        end

        function stylePromote_(obj, active)
            %STYLEPROMOTE_ Accent the primary CTA when a row is selected.
            if isempty(obj.PromoteBtn_) || ~isvalid(obj.PromoteBtn_)
                return;
            end
            if active
                obj.PromoteBtn_.BackgroundColor = obj.Theme_.Accent;
                obj.PromoteBtn_.FontColor = obj.Theme_.DashboardBackground;
            else
                obj.PromoteBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
                obj.PromoteBtn_.FontColor = obj.Theme_.ForegroundColor;
            end
        end

        function applyFilter_(obj)
            %APPLYFILTER_ Read the filter field and rebuild.
            try
                obj.FilterText_ = obj.FilterField_.Value;
                obj.reload_();
            catch err
                uialert(obj.hFig_, err.message, 'Filter');
            end
        end

        function togglePendingFilter_(obj)
            %TOGGLEPENDINGFILTER_ Flip the pending-only view and restyle the toggle.
            try
                obj.ShowPendingOnly_ = ~obj.ShowPendingOnly_;
                if obj.ShowPendingOnly_
                    obj.ShowPendingBtn_.BackgroundColor = obj.Theme_.Accent;
                    obj.ShowPendingBtn_.FontColor = obj.Theme_.DashboardBackground;
                else
                    obj.ShowPendingBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
                    obj.ShowPendingBtn_.FontColor = obj.Theme_.ForegroundColor;
                end
                obj.reload_();
            catch err
                uialert(obj.hFig_, err.message, 'Show Pending');
            end
        end

        function onPromote_(obj)
            %ONPROMOTE_ Confirm the selected entry, gated by the LOW / unit-mismatch warnings.
            try
                if isempty(obj.SelectedRow_) || obj.SelectedRow_ > numel(obj.RowEntries_)
                    return;
                end
                e = obj.RowEntries_{obj.SelectedRow_};
                proceed = true;
                if e.unitMismatch
                    sel = uiconfirm(obj.hFig_, ...
                        sprintf(['Units mismatch: local key "%s" on machine "%s" uses different units ', ...
                                 'than the canonical sensor "%s".\n\n', ...
                                 'Promoting this mapping may produce physically incomparable results. ', ...
                                 'Confirm you have verified the units are compatible.'], ...
                            e.localKey, e.machineId, e.logicalId), ...
                        'Unit Mismatch Warning', ...
                        'Options', {'Promote Anyway', 'Cancel'}, ...
                        'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', 'Icon', 'warning');
                    proceed = strcmp(sel, 'Promote Anyway');
                elseif strcmp(e.confidence, 'LOW')
                    sel = uiconfirm(obj.hFig_, ...
                        sprintf(['This match has LOW confidence (similarity %.0f%%). ', ...
                                 'Promoting it will include this sensor in comparisons.\n\n', ...
                                 'Confirm that "%s" on machine "%s" correctly maps to logical sensor "%s".'], ...
                            e.similarity * 100, e.localKey, e.machineId, e.logicalId), ...
                        'Low-Confidence Mapping', ...
                        'Options', {'Promote Anyway', 'Cancel'}, ...
                        'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', 'Icon', 'warning');
                    proceed = strcmp(sel, 'Promote Anyway');
                end
                if ~proceed
                    return;
                end
                obj.Mapper_.confirm(e.logicalId, e.machineId);
                obj.IsDirty_ = true;
                obj.reload_();
            catch err
                uialert(obj.hFig_, sprintf('Failed to promote: %s', err.message), 'Promote');
            end
        end

        function onOverride_(obj)
            %ONOVERRIDE_ Prompt for a new local key and override the selected entry.
            try
                if isempty(obj.SelectedRow_) || obj.SelectedRow_ > numel(obj.RowEntries_)
                    return;
                end
                e = obj.RowEntries_{obj.SelectedRow_};
                answer = inputdlg('Enter the correct local key for this machine:', ...
                    'Override Mapping', 1, {e.localKey});
                if isempty(answer)
                    return;   % cancelled
                end
                newKey = strtrim(answer{1});
                if isempty(newKey)
                    uialert(obj.hFig_, ...
                        'Local key cannot be empty. Enter the correct sensor key for this machine.', ...
                        'Override Mapping');
                    return;
                end
                obj.Mapper_.override(e.logicalId, e.machineId, newKey);
                obj.IsDirty_ = true;
                obj.reload_();
            catch err
                uialert(obj.hFig_, sprintf('Failed to override: %s', err.message), 'Override');
            end
        end

        function onSave_(obj)
            %ONSAVE_ Save the map to JSON (prompting for a path on first save).
            try
                if isempty(obj.FilePath_)
                    [f, p] = uiputfile({'*.json', 'Canonical Map JSON'}, 'Save Canonical Map');
                    if isequal(f, 0)
                        return;   % cancelled
                    end
                    obj.FilePath_ = fullfile(p, f);
                end
                obj.Mapper_.save(obj.FilePath_);
                obj.IsDirty_ = false;
                obj.updateStatus_();
            catch err
                uialert(obj.hFig_, ...
                    sprintf('Failed to save: %s. Check file permissions and try again.', err.message), ...
                    'Save');
            end
        end

        function onCloseRequest_(obj)
            %ONCLOSEREQUEST_ Close, gating on unsaved changes.
            try
                if obj.IsDirty_
                    sel = uiconfirm(obj.hFig_, ...
                        'You have unsaved changes to the canonical map. Close without saving?', ...
                        'Unsaved Changes', ...
                        'Options', {'Close Without Saving', 'Cancel'}, ...
                        'DefaultOption', 'Cancel', 'CancelOption', 'Cancel', 'Icon', 'question');
                    if ~strcmp(sel, 'Close Without Saving')
                        return;
                    end
                end
                for k = 1:numel(obj.Listeners_)
                    delete(obj.Listeners_{k});
                end
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    delete(obj.hFig_);
                end
                obj.IsOpen = false;
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'Close');
                end
            end
        end
    end

end

function t = resolveTheme_()
    %RESOLVETHEME_ Active CompanionTheme (dark) with a self-contained fallback.
    try
        t = CompanionTheme.get('dark');
    catch
        t = struct();
    end
    t = fillThemeDefaults_(t);
end

function t = fillThemeDefaults_(t)
    %FILLTHEMEDEFAULTS_ Ensure every field the editor reads exists (dark defaults from UI-SPEC).
    defaults = struct( ...
        'WidgetBackground',     [0.09 0.13 0.24], ...
        'DashboardBackground',  [0.10 0.10 0.18], ...
        'ForegroundColor',      [0.90 0.92 0.95], ...
        'WidgetBorderColor',    [0.20 0.24 0.34], ...
        'Accent',               [0.31 0.80 0.64], ...
        'PlaceholderTextColor', [0.66 0.73 0.78]);
    f = fieldnames(defaults);
    for i = 1:numel(f)
        if ~isfield(t, f{i}) || isempty(t.(f{i}))
            t.(f{i}) = defaults.(f{i});
        end
    end
end

function pair = stripePairFromTheme_(t)
    %STRIPEPAIRFROMTHEME_ 2x3 uitable stripe pair derived from theme brightness.
    if mean(t.DashboardBackground) < 0.5
        pair = [0.13 0.13 0.13; 0.20 0.20 0.20];
    else
        pair = [1.00 1.00 1.00; 0.94 0.94 0.94];
    end
end
