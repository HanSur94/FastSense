classdef CompareBuilderDialog < handle
%COMPAREBUILDERDIALOG Modeless cross-machine comparison builder (Phase 1045).
%
%   A non-modal second uifigure owned by FastSenseCompanion (fleet mode only).
%   The user picks a shared logical sensor from a quick-fill dropdown; the
%   dialog assembles one row per fleet machine — color swatch, include
%   checkbox, machine name, per-row override dropdown, action button, and a
%   confidence status badge — and opens a single overlay figure with one
%   line per included machine in that machine's stable color.
%
%   The four row states (auto / confirm_needed / override / none) come from
%   buildCompareResolution_, which applies the confidence gate: LOW+AUTO
%   matches render as 'confirm_needed' and are NOT included by default
%   (invariant #4). Missing sensors render as 'none' and are excluded.
%
%   "Open Comparison" resolves each included tag ONCE into a ResolvedTags_
%   cache and hands the handles + per-series colors/labels to openAdHocPlot;
%   the spawned engine's live tick never re-resolves through the mapper
%   (CMP-05 resolve-once, invariant #5).
%
%   Lifecycle mirrors CompanionSettingsDialog: closing this dialog does not
%   close the Companion; closing the Companion deletes this dialog if open.
%   The class writes `app.CompareBuilderDlg_ = []` on close — FastSenseCompanion
%   declares that property with `SetAccess = ?CompareBuilderDialog` to allow it.
%
%   Usage:
%     dlg = CompareBuilderDialog(app)   % app is a fleet-mode FastSenseCompanion
%     dlg.close()
%
%   Properties (read-only):
%     App_  — the FastSenseCompanion handle (parent)
%     hFig_ — the owned uifigure handle (or [] after close)
%
%   See also CompanionSettingsDialog, openAdHocPlot, buildCompareResolution_,
%            compareSeriesColor_, FastSenseCompanion.

    properties (SetAccess = private)
        App_  = []   % FastSenseCompanion handle (parent)
        hFig_ = []   % owned uifigure handle (or [] after close)
    end

    properties (Access = private)
        hSensorDD_        = []   % quick-fill shared-sensor uidropdown
        hClearBtn_        = []   % "Clear" button (resets the sensor + rows)
        hScrollPanel_     = []   % scrollable uipanel hosting the per-machine rows
        hOuter_           = []   % dialog outer [5 1] uigridlayout
        hCountLabel_      = []   % "N of M machines included" footer label
        hOpenBtn_         = []   % "Open Comparison" CTA
        hCloseBtn_        = []   % "Close" button
        RowHandles_       = {}   % 1xN cell of per-row handle structs
        RowStates_        = {}   % 1xN cell of per-row state structs (augments buildCompareResolution_ rows with .checked/.promoted)
        ResolvedTags_     = {}   % resolve-once cache populated at Open (invariant #5)
        CurrentLogicalId_ = ''   % the quick-fill logical sensor currently resolved
        Theme_            = []   % cached CompanionTheme struct
        NONE_             = ''   % per-row "none" sentinel string (em-dash wrapped)
        CHECK_            = ''   % badge glyph: checkmark / '+'
        WARN_             = ''   % badge glyph: warning triangle / '!'
        PENCIL_           = ''   % badge glyph: pencil / '*'
        DASH_             = ''   % badge glyph: em dash / '-'
    end

    methods (Access = public)

        function obj = CompareBuilderDialog(app)
        %COMPAREBUILDERDIALOG Construct the modeless compare builder bound to app.
            if ~isa(app, 'FastSenseCompanion')
                error('CompareBuilderDialog:invalidApp', ...
                    'CompareBuilderDialog requires a FastSenseCompanion handle.');
            end
            if isempty(app.fleet())
                error('CompareBuilderDialog:notFleetMode', ...
                    'CompareBuilderDialog requires a fleet-mode FastSenseCompanion (no Fleet present).');
            end
            obj.App_   = app;
            t          = CompanionTheme.get(app.Theme);
            obj.Theme_ = t;

            % Badge glyphs with ASCII fallback when no Java desktop (headless).
            if usejava('desktop')
                obj.CHECK_  = char(10003);   % checkmark
                obj.WARN_   = char(9888);    % warning triangle
                obj.PENCIL_ = char(9998);    % pencil
                obj.DASH_   = char(8212);    % em dash
            else
                obj.CHECK_  = '+';
                obj.WARN_   = '!';
                obj.PENCIL_ = '*';
                obj.DASH_   = '-';
            end
            obj.NONE_ = [obj.DASH_ ' none ' obj.DASH_];

            obj.hFig_ = uifigure( ...
                'Name',                'Compare Machines', ...
                'Position',            [100 100 600 480], ...
                'Resize',              'on', ...
                'AutoResizeChildren',  'off', ...
                'Color',               t.DashboardBackground);
            % Non-modal — explicitly do NOT set WindowStyle='modal'.

            obj.hOuter_ = uigridlayout(obj.hFig_, [5 1]);
            obj.hOuter_.RowHeight       = {32, 8, '1x', 8, 40};
            obj.hOuter_.ColumnWidth     = {'1x'};
            obj.hOuter_.Padding         = [16 16 16 16];
            obj.hOuter_.RowSpacing      = 0;
            obj.hOuter_.BackgroundColor = t.DashboardBackground;

            % Row 1 — quick-fill strip.
            gTop = uigridlayout(obj.hOuter_, [1 3]);
            gTop.Layout.Row      = 1;
            gTop.ColumnWidth     = {'fit', '1x', 80};
            gTop.RowHeight       = {'1x'};
            gTop.Padding         = [0 0 0 0];
            gTop.ColumnSpacing   = 8;
            gTop.BackgroundColor = t.DashboardBackground;

            lbl = uilabel(gTop, 'Text', 'Shared sensor:');
            lbl.Layout.Column = 1;
            lbl.FontSize      = 11;
            lbl.FontColor     = t.ForegroundColor;

            obj.hSensorDD_ = uidropdown(gTop);
            obj.hSensorDD_.Layout.Column = 2;
            obj.hSensorDD_.FontSize      = 11;
            obj.hSensorDD_.Items         = app.fleet().mapper().logicalIds();
            try
                obj.hSensorDD_.Searchable = true;        % R2021a+
            catch
            end
            try
                obj.hSensorDD_.Placeholder = 'Select a sensor...';   % R2021a+
                obj.hSensorDD_.Value       = '';
            catch
            end
            obj.hSensorDD_.ValueChangedFcn = @(~,~) obj.onSensorSelected_();

            obj.hClearBtn_ = uibutton(gTop, 'push');
            obj.hClearBtn_.Layout.Column   = 3;
            obj.hClearBtn_.Text            = 'Clear';
            obj.hClearBtn_.FontSize        = 11;
            obj.hClearBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hClearBtn_.FontColor       = t.ForegroundColor;
            obj.hClearBtn_.Tooltip         = 'Clear shared sensor selection';
            obj.hClearBtn_.ButtonPushedFcn = @(~,~) obj.onClearSensor_();

            % Row 3 — scrollable per-machine rows.
            obj.hScrollPanel_ = uipanel(obj.hOuter_);
            obj.hScrollPanel_.Layout.Row      = 3;
            obj.hScrollPanel_.Scrollable      = 'on';
            obj.hScrollPanel_.BorderType      = 'none';
            obj.hScrollPanel_.BackgroundColor = t.WidgetBackground;

            % Row 5 — CTA strip.
            gCta = uigridlayout(obj.hOuter_, [1 3]);
            gCta.Layout.Row      = 5;
            gCta.ColumnWidth     = {'1x', 120, 80};
            gCta.RowHeight       = {'1x'};
            gCta.Padding         = [0 0 0 0];
            gCta.ColumnSpacing   = 8;
            gCta.BackgroundColor = t.DashboardBackground;

            obj.hCountLabel_ = uilabel(gCta);
            obj.hCountLabel_.Layout.Column        = 1;
            obj.hCountLabel_.FontSize             = 11;
            obj.hCountLabel_.FontColor            = t.ToolbarFontColor;
            obj.hCountLabel_.HorizontalAlignment  = 'left';
            obj.hCountLabel_.VerticalAlignment    = 'center';
            obj.hCountLabel_.Text                 = '';

            obj.hOpenBtn_ = uibutton(gCta, 'push');
            obj.hOpenBtn_.Layout.Column   = 2;
            obj.hOpenBtn_.Text            = 'Open Comparison';
            obj.hOpenBtn_.FontSize        = 11;
            obj.hOpenBtn_.FontWeight      = 'bold';
            obj.hOpenBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hOpenBtn_.FontColor       = t.ToolbarFontColor;
            obj.hOpenBtn_.Enable          = 'off';
            obj.hOpenBtn_.Tooltip         = 'Open comparison overlay figure';
            obj.hOpenBtn_.ButtonPushedFcn = @(~,~) obj.onOpenComparison_();

            obj.hCloseBtn_ = uibutton(gCta, 'push');
            obj.hCloseBtn_.Layout.Column   = 3;
            obj.hCloseBtn_.Text            = 'Close';
            obj.hCloseBtn_.FontSize        = 11;
            obj.hCloseBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hCloseBtn_.FontColor       = t.ForegroundColor;
            obj.hCloseBtn_.ButtonPushedFcn = @(~,~) obj.close();

            % Style every child, then re-assert post-walk overrides via rebuild.
            applyThemeToChildren_(obj.hFig_, t);
            obj.hFig_.CloseRequestFcn = @(~,~) obj.close();

            obj.rebuildRows_();
        end

        function close(obj)
        %CLOSE Tear down the dialog. Idempotent.
        %   Notifies the parent app (via the friend-class CompareBuilderDlg_
        %   setter) so the singleton check sees a clean slate next time. The
        %   write-back is guarded so this class can be smoke-tested before
        %   FastSenseCompanion declares the property (Plan 05).
            if isempty(obj.hFig_) || ~isvalid(obj.hFig_)
                obj.hFig_ = [];
                return;
            end
            try
                if ~isempty(obj.App_) && isvalid(obj.App_)
                    obj.App_.CompareBuilderDlg_ = [];
                end
            catch
            end
            try
                delete(obj.hFig_);
            catch
            end
            obj.hFig_ = [];
        end

        function delete(obj)
        %DELETE Handle-class destructor — calls close() for safety.
            obj.close();
        end

        function applyTheme_(obj, themeArg)
        %APPLYTHEME_ Repaint the dialog for a new theme + re-assert post-walk overrides.
        %   Public so the parent FastSenseCompanion can refresh an open builder
        %   when the companion theme changes. Accepts a char preset ('dark' /
        %   'light') or a resolved CompanionTheme struct. Re-asserts the
        %   Open-button background (by includedCount), each row's badge FontColor
        %   (by state), and each per-machine swatch color (a series color, NOT a
        %   theme token) after the recursive walker runs.
            try
                if ischar(themeArg) || (isstring(themeArg) && isscalar(themeArg))
                    t = CompanionTheme.get(char(themeArg));
                else
                    t = themeArg;   % already a resolved theme struct
                end
                obj.Theme_ = t;
                if isempty(obj.hFig_) || ~isvalid(obj.hFig_); return; end
                obj.hFig_.Color = t.DashboardBackground;
                applyThemeToChildren_(obj.hFig_, t);
                % Post-walk overrides: swatch series colors + badge colors + Open button.
                for i = 1:numel(obj.RowHandles_)
                    h  = obj.RowHandles_{i};
                    rs = obj.RowStates_{i};
                    if isfield(h, 'hSwatch') && isvalid(h.hSwatch) && ~isempty(rs.color)
                        h.hSwatch.BackgroundColor = rs.color;
                    end
                    obj.applyBadge_(i);
                end
                obj.updateCountAndOpen_();
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function onConfirm_(obj, i)
        %ONCONFIRM_ Include a confirm_needed row: state -> override, checked.
        %   Public so the class-suite can drive CMP-06 directly. The action
        %   button flips 'Confirm' -> 'Promote' and the badge -> override via
        %   the in-place row refresh (no full rebuild — RESEARCH Pitfall 6).
            try
                if i < 1 || i > numel(obj.RowStates_); return; end
                rs = obj.RowStates_{i};
                rs.state   = 'override';
                rs.checked = true;
                obj.RowStates_{i} = rs;
                obj.refreshRowWidgets_(i);
                obj.updateCountAndOpen_();
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function onPromoteConfirmed_(obj, i, event)
        %ONPROMOTECONFIRMED_ uiconfirm CloseFcn — apply the in-memory override.
        %   Public so the class-suite can invoke it with a synthetic event
        %   (struct('SelectedOption','Promote')) without driving the async
        %   uiconfirm. Only fires on the 'Promote' option; calls
        %   CanonicalMapper.override (in-memory only — never Fleet.save) and
        %   marks the row promoted (badge -> '<check> promoted', no further
        %   Promote button). Honors Pitfall 3: a freshly-deserialized mapper's
        %   promoted entry may carry empty localName/localUnits — accepted.
            try
                if ~strcmp(event.SelectedOption, 'Promote')
                    return;
                end
                % Guard the async-captured row index: a re-resolve between opening
                % the uiconfirm and this CloseFcn firing could shrink or reshape
                % RowStates_. Bounds-check, then re-verify identity — only promote a
                % row still in an unpromoted 'override' state — so a stale i can
                % never write the wrong machine's mapping.
                if i < 1 || i > numel(obj.RowStates_)
                    return;
                end
                rs = obj.RowStates_{i};
                if ~strcmp(rs.state, 'override') || (isfield(rs, 'promoted') && rs.promoted)
                    return;
                end
                obj.App_.fleet().mapper().override(obj.CurrentLogicalId_, rs.machineId, rs.localKey);
                rs.status   = 'OVERRIDDEN';
                rs.promoted = true;   % discriminator: badgeSpec_/buildActionWidget_ test promoted BEFORE state
                rs.checked  = true;
                obj.RowStates_{i} = rs;
                obj.refreshRowWidgets_(i);
                obj.updateCountAndOpen_();
            catch err
                obj.alertError_(err, 'Promote Failed');
            end
        end

    end

    methods (Access = private)

        % ---------------------------------------------------------------
        % Quick-fill resolution + row grid
        % ---------------------------------------------------------------

        function onSensorSelected_(obj)
        %ONSENSORSELECTED_ Quick-fill dropdown ValueChangedFcn.
            try
                val = obj.hSensorDD_.Value;
                if isempty(val)
                    obj.RowStates_        = {};
                    obj.CurrentLogicalId_ = '';
                    obj.rebuildRows_();
                    return;
                end
                obj.resolveAllRows_(val);
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function onClearSensor_(obj)
        %ONCLEARSENSOR_ "Clear" button — reset the sensor selection + all rows.
            try
                try
                    obj.hSensorDD_.Value = '';
                catch
                    % No Placeholder support (pre-R2021a): leave the dropdown
                    % value as-is and just clear the rows.
                end
                obj.RowStates_        = {};
                obj.CurrentLogicalId_ = '';
                obj.rebuildRows_();
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function resolveAllRows_(obj, logicalId)
        %RESOLVEALLROWS_ Resolve every machine row for a logical sensor.
        %   Delegates the confidence gate to buildCompareResolution_ (the
        %   3-arg form computes per-machine swatch colors from the theme),
        %   augments each row with the include flag + promoted flag, then
        %   rebuilds the row grid.
            rows = buildCompareResolution_(obj.App_.fleet(), logicalId, obj.Theme_);
            obj.CurrentLogicalId_ = logicalId;
            n = numel(rows);
            obj.RowStates_ = cell(1, n);
            for i = 1:n
                rs = rows(i);
                rs.checked  = strcmp(rs.state, 'auto');   % only HIGH/auto included by default (invariant #4)
                rs.promoted = false;
                obj.RowStates_{i} = rs;
            end
            obj.rebuildRows_();
        end

        function rebuildRows_(obj)
        %REBUILDROWS_ Rebuild the per-machine row grid from RowStates_.
            % Drop existing children + handles.
            if ~isempty(obj.hScrollPanel_) && isvalid(obj.hScrollPanel_)
                delete(obj.hScrollPanel_.Children);
            end
            obj.RowHandles_ = {};

            fleet = obj.App_.fleet();
            if isempty(fleet) || fleet.machineCount() == 0
                obj.renderCenteredHint_('No machines in fleet', 14, 'bold');
                obj.updateCountAndOpen_();
                return;
            end

            if isempty(obj.RowStates_)
                % No shared sensor picked yet — neutral guidance.
                obj.renderCenteredHint_('Select a shared sensor to compare', 12, 'normal');
                obj.updateCountAndOpen_();
                return;
            end

            n     = numel(obj.RowStates_);
            gRows = uigridlayout(obj.hScrollPanel_, [n 1]);
            gRows.RowHeight       = repmat({36}, 1, n);
            gRows.ColumnWidth     = {'1x'};
            gRows.Padding         = [0 0 0 0];
            gRows.RowSpacing      = 4;
            gRows.BackgroundColor = obj.Theme_.WidgetBackground;

            for i = 1:n
                obj.RowHandles_{i} = obj.buildRow_(gRows, i);
                obj.applyBadge_(i);
            end

            obj.updateCountAndOpen_();
        end

        function h = buildRow_(obj, gRows, i)
        %BUILDROW_ Construct one 1x6 machine-row nested grid; return its handles.
            rs      = obj.RowStates_{i};
            machine = obj.App_.fleet().getMachine(rs.machineId);

            gRow = uigridlayout(gRows, [1 6]);
            gRow.Layout.Row      = i;
            gRow.ColumnWidth     = {8, 24, '1x', '1x', 80, 60};
            gRow.RowHeight       = {'1x'};
            gRow.Padding         = [4 0 4 0];
            gRow.ColumnSpacing   = 4;
            gRow.BackgroundColor = obj.Theme_.WidgetBackground;

            % Col 1 — color swatch.
            hSwatch = uilabel(gRow);
            hSwatch.Layout.Column = 1;
            hSwatch.Text          = '';
            if ~isempty(rs.color)
                hSwatch.BackgroundColor = rs.color;
            end

            % Col 2 — include checkbox.
            hCheck = uicheckbox(gRow);
            hCheck.Layout.Column   = 2;
            hCheck.Text            = '';
            hCheck.Value           = logical(rs.checked);
            hCheck.ValueChangedFcn = @(s,~) obj.onRowCheckChanged_(i, s.Value);

            % Col 3 — machine name.
            hName = uilabel(gRow);
            hName.Layout.Column        = 3;
            hName.Text                 = machine.Name;
            hName.FontSize             = 11;
            hName.FontWeight           = 'bold';
            hName.FontColor            = obj.Theme_.ForegroundColor;
            hName.HorizontalAlignment  = 'left';
            hName.Tooltip              = ['Machine ID: ' machine.Id];

            % Col 4 — per-row override dropdown.
            hDD = uidropdown(gRow);
            hDD.Layout.Column = 4;
            hDD.FontSize      = 11;
            localKeys         = machine.keys();
            hDD.Items         = [{obj.NONE_}, localKeys(:)'];
            if ~isempty(rs.localKey) && any(strcmp(localKeys, rs.localKey))
                hDD.Value = rs.localKey;
            else
                hDD.Value = obj.NONE_;
            end
            hDD.Tooltip         = 'Override tag for this machine';
            hDD.ValueChangedFcn = @(s,~) obj.onRowDropdownChanged_(i, s.Value);

            % Col 5 — context-sensitive action widget (button or empty label).
            hAction = obj.buildActionWidget_(gRow, i, rs);

            % Col 6 — status badge.
            hBadge = uilabel(gRow);
            hBadge.Layout.Column        = 6;
            hBadge.FontSize             = 10;
            hBadge.HorizontalAlignment  = 'right';
            hBadge.VerticalAlignment    = 'center';

            h = struct('hRowGrid', gRow, 'hSwatch', hSwatch, 'hCheck', hCheck, ...
                'hName', hName, 'hRowDD', hDD, 'hActionBtn', hAction, 'hBadge', hBadge);
        end

        function h = buildActionWidget_(obj, gRow, i, rs)
        %BUILDACTIONWIDGET_ Build the col-5 action widget for a row's state.
        %   confirm_needed -> "Confirm" button; override (unpromoted) ->
        %   "Promote" button; auto / none / promoted -> empty placeholder
        %   label (preserves the grid structure). The button dispatches to
        %   onRowAction_ which routes by state (filled in Plan 04).
            switch rs.state
                case 'confirm_needed'
                    h = uibutton(gRow, 'push');
                    h.Layout.Column   = 5;
                    h.Text            = 'Confirm';
                    h.FontSize        = 11;
                    h.BackgroundColor = obj.Theme_.WidgetBorderColor;
                    h.FontColor       = obj.Theme_.ForegroundColor;
                    h.Tooltip         = 'Include this machine (confidence: LOW)';
                    h.ButtonPushedFcn = @(~,~) obj.onRowAction_(i);
                case 'override'
                    if isfield(rs, 'promoted') && rs.promoted
                        h = obj.emptyActionSlot_(gRow);
                    else
                        h = uibutton(gRow, 'push');
                        h.Layout.Column   = 5;
                        h.Text            = 'Promote';
                        h.FontSize        = 11;
                        h.BackgroundColor = obj.Theme_.WidgetBorderColor;
                        h.FontColor       = obj.Theme_.ForegroundColor;
                        h.Tooltip         = 'Promote this override into the canonical map';
                        h.ButtonPushedFcn = @(~,~) obj.onRowAction_(i);
                    end
                otherwise   % auto, none
                    h = obj.emptyActionSlot_(gRow);
            end
        end

        function h = emptyActionSlot_(~, gRow)
        %EMPTYACTIONSLOT_ An empty col-5 placeholder label (no action).
            h = uilabel(gRow);
            h.Layout.Column = 5;
            h.Text          = '';
        end

        function onRowAction_(obj, i)
        %ONROWACTION_ Per-row action button dispatch by row state.
        %   confirm_needed -> onConfirm_ (include the LOW/unreviewed match);
        %   override (unpromoted) -> onPromote_ (push into the canonical map).
        %   auto / none / promoted have no action button, so never reach here.
            try
                if i < 1 || i > numel(obj.RowStates_); return; end
                rs = obj.RowStates_{i};
                switch rs.state
                    case 'confirm_needed'
                        obj.onConfirm_(i);
                    case 'override'
                        if ~(isfield(rs, 'promoted') && rs.promoted)
                            obj.onPromote_(i);
                        end
                end
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function onPromote_(obj, i)
        %ONPROMOTE_ Show the promote-confirmation uiconfirm for an override row.
        %   R2020b-safe async pattern: the override is applied in the CloseFcn
        %   (onPromoteConfirmed_), never inline after uiconfirm (RESEARCH
        %   Pitfall 4), so R2020b cannot fire override before the user responds.
            try
                rs  = obj.RowStates_{i};
                msg = sprintf(['Add "%s" as the canonical mapping for "%s" on machine "%s"? ' ...
                    'This updates the in-memory canonical map. Call Fleet.save() to persist.'], ...
                    rs.localKey, obj.CurrentLogicalId_, rs.machineId);
                uiconfirm(obj.hFig_, msg, 'Promote Override to Canonical Map', ...
                    'Options', {'Promote', 'Cancel'}, ...
                    'DefaultOption', 2, 'CancelOption', 2, ...
                    'CloseFcn', @(~, event) obj.onPromoteConfirmed_(i, event));
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        % ---------------------------------------------------------------
        % In-place row mutation
        % ---------------------------------------------------------------

        function onRowCheckChanged_(obj, i, value)
        %ONROWCHECKCHANGED_ Include-checkbox ValueChangedFcn (in-place).
            try
                rs = obj.RowStates_{i};
                if strcmp(rs.state, 'none')
                    % 'none' rows can never be included — force back to off.
                    rs.checked = false;
                    obj.RowStates_{i} = rs;
                    if numel(obj.RowHandles_) >= i && isvalid(obj.RowHandles_{i}.hCheck)
                        obj.RowHandles_{i}.hCheck.Value = false;
                    end
                    return;
                end
                rs.checked = logical(value);
                obj.RowStates_{i} = rs;
                obj.updateCountAndOpen_();
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function onRowDropdownChanged_(obj, i, value)
        %ONROWDROPDOWNCHANGED_ Per-row override ValueChangedFcn (in-place).
            try
                rs = obj.RowStates_{i};
                if strcmp(value, obj.NONE_)
                    rs.state        = 'none';
                    rs.checked      = false;
                    rs.localKey     = '';
                    rs.localUnits   = '';
                    rs.localName    = '';
                    rs.confidence   = '';
                    rs.status       = '';
                    rs.unitMismatch = false;
                else
                    rs.state        = 'override';
                    rs.checked      = true;
                    rs.localKey     = value;
                    rs.unitMismatch = obj.detectRowUnitMismatch_(rs);
                end
                obj.RowStates_{i} = rs;
                obj.refreshRowWidgets_(i);
                obj.updateCountAndOpen_();
            catch err
                obj.alertError_(err, 'Compare Builder');
            end
        end

        function refreshRowWidgets_(obj, i)
        %REFRESHROWWIDGETS_ Re-assert one row's checkbox/action/badge in place.
        %   The action widget can switch type (button <-> label), so it is
        %   deleted and rebuilt; the rest are updated without a full rebuild
        %   (RESEARCH Pitfall 6).
            h  = obj.RowHandles_{i};
            rs = obj.RowStates_{i};
            if isvalid(h.hCheck)
                h.hCheck.Value = logical(rs.checked);
            end
            if isfield(h, 'hActionBtn') && ~isempty(h.hActionBtn) && isvalid(h.hActionBtn)
                delete(h.hActionBtn);
            end
            h.hActionBtn       = obj.buildActionWidget_(h.hRowGrid, i, rs);
            obj.RowHandles_{i} = h;
            obj.applyBadge_(i);
        end

        function updateCountAndOpen_(obj)
        %UPDATECOUNTANDOPEN_ Refresh the count label + Open-button enable/colors.
            m   = numel(obj.RowStates_);
            inc = obj.includedCount_();
            if ~isempty(obj.hCountLabel_) && isvalid(obj.hCountLabel_)
                if inc == 0
                    obj.hCountLabel_.Text = sprintf('0 of %d machines included — select at least 2', m);
                else
                    obj.hCountLabel_.Text = sprintf('%d of %d machines included', inc, m);
                end
            end
            if ~isempty(obj.hOpenBtn_) && isvalid(obj.hOpenBtn_)
                if inc >= 2
                    obj.hOpenBtn_.Enable = 'on';
                else
                    obj.hOpenBtn_.Enable = 'off';
                end
                if inc >= 1
                    obj.hOpenBtn_.BackgroundColor = obj.Theme_.Accent;
                    obj.hOpenBtn_.FontColor       = obj.Theme_.DashboardBackground;
                else
                    obj.hOpenBtn_.BackgroundColor = obj.Theme_.WidgetBorderColor;
                    obj.hOpenBtn_.FontColor       = obj.Theme_.ToolbarFontColor;
                end
            end
        end

        function inc = includedCount_(obj)
        %INCLUDEDCOUNT_ Number of rows that are checked AND not in 'none' state.
            inc = 0;
            for i = 1:numel(obj.RowStates_)
                if obj.isIncluded_(obj.RowStates_{i})
                    inc = inc + 1;
                end
            end
        end

        function tf = isIncluded_(~, rs)
        %ISINCLUDED_ Single inclusion predicate: checked AND not in 'none' state.
        %   Shared by includedCount_ + includedIndices_ so the count label, the
        %   Open set, and the Open-button gating never drift out of sync.
            tf = rs.checked && ~strcmp(rs.state, 'none');
        end

        % ---------------------------------------------------------------
        % Open path — resolve-once cache + overlay launch
        % ---------------------------------------------------------------

        function onOpenComparison_(obj)
        %ONOPENCOMPARISON_ Resolve included tags ONCE and open the overlay.
        %   Surfaces consolidated, non-blocking unit-mismatch and skipped-machine
        %   alerts, then caches each included tag handle in ResolvedTags_ and
        %   hands the handles + per-series colors/labels to openAdHocPlot. No
        %   CanonicalMapper method is touched after the cache is populated
        %   (invariant #5) — resolution here is a Machine-catalog lookup only.
            try
                includedIdx = obj.includedIndices_();
                if numel(includedIdx) < 2
                    error('CompareBuilderDialog:noMachinesIncluded', ...
                        'Select at least 2 machines to compare.');
                end
                fleet = obj.App_.fleet();

                obj.warnUnitMismatches_(includedIdx, fleet);
                obj.warnSkippedMachines_(fleet);

                % Resolve-once cache (invariant #5).
                obj.ResolvedTags_ = {};
                seriesColors      = {};
                seriesLabels      = {};
                for k = 1:numel(includedIdx)
                    rs      = obj.RowStates_{includedIdx(k)};
                    machine = fleet.getMachine(rs.machineId);
                    try
                        tag = machine.get(rs.localKey);
                    catch innerErr
                        error('CompareBuilderDialog:resolutionError', ...
                            'Failed to resolve tag for machine "%s": %s', ...
                            machine.Name, innerErr.message);
                    end
                    obj.ResolvedTags_{end+1} = tag;
                    seriesColors{end+1}      = rs.color;   %#ok<AGROW>
                    seriesLabels{end+1}      = [machine.Name ': ' obj.sensorDisplayName_(tag, rs.localKey)]; %#ok<AGROW>
                end

                hFig = openAdHocPlot(obj.ResolvedTags_, 'Overlay', obj.App_.Theme, ...
                    'SeriesColors', seriesColors, 'SeriesLabels', seriesLabels);

                if ~isempty(obj.App_) && isvalid(obj.App_) && ismethod(obj.App_, 'trackOpenedFigure')
                    obj.App_.trackOpenedFigure(hFig);
                end
            catch err
                obj.alertError_(err, 'Comparison Failed');
            end
        end

        function idx = includedIndices_(obj)
        %INCLUDEDINDICES_ Indices of rows checked AND not in 'none' state.
            idx = [];
            for i = 1:numel(obj.RowStates_)
                if obj.isIncluded_(obj.RowStates_{i})
                    idx(end+1) = i; %#ok<AGROW>
                end
            end
        end

        function warnUnitMismatches_(obj, includedIdx, fleet)
        %WARNUNITMISMATCHES_ Consolidated non-blocking unit-mismatch alert.
            lines = {};
            for k = 1:numel(includedIdx)
                rs = obj.RowStates_{includedIdx(k)};
                if isfield(rs, 'unitMismatch') && rs.unitMismatch
                    nm = fleet.getMachine(rs.machineId).Name;
                    % Show the diverging TAG unit (the one that differs from the
                    % shared sensor), not the canonical reference unit (rs.localUnits).
                    tagUnits = obj.tagUnits_(fleet, rs.machineId, rs.localKey);
                    lines{end+1} = sprintf('  %s %s: %s (unit: %s)', ...
                        char(8226), nm, rs.localKey, tagUnits); %#ok<AGROW>
                end
            end
            if isempty(lines); return; end
            msg = sprintf('%s\n\n%s\n\n%s', ...
                'The following machines have tags with units that may differ from the shared sensor:', ...
                strjoin(lines, newline), ...
                'The comparison will open. Verify the y-axis scale before analysis.');
            if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                uialert(obj.hFig_, msg, 'Unit Mismatch Warning', 'Icon', 'warning');
            end
        end

        function warnSkippedMachines_(obj, fleet)
        %WARNSKIPPEDMACHINES_ Consolidated skip alert + events-log entry (CMP-03).
            lines = {};
            names = {};
            for i = 1:numel(obj.RowStates_)
                rs = obj.RowStates_{i};
                isSkipped = strcmp(rs.state, 'none') || ...
                    (strcmp(rs.state, 'confirm_needed') && ~rs.checked);
                if isSkipped
                    nm = fleet.getMachine(rs.machineId).Name;
                    names{end+1} = nm; %#ok<AGROW>
                    lines{end+1} = sprintf('  %s %s', char(8226), nm); %#ok<AGROW>
                end
            end
            if isempty(lines); return; end
            msg = sprintf('%s\n\n%s\n\n%s', ...
                'The following machines are not included because the sensor was not found:', ...
                strjoin(lines, newline), ...
                'The comparison opens with the remaining machines.');
            if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                uialert(obj.hFig_, msg, 'Machines Skipped', 'Icon', 'info');
            end
            obj.logSkipped_(names);
        end

        function logSkipped_(obj, names)
        %LOGSKIPPED_ Best-effort events-log entry for skipped machines (never fatal).
            try
                if ~isempty(obj.App_) && isvalid(obj.App_) && ismethod(obj.App_, 'addLogEntry')
                    obj.App_.addLogEntry('warn', sprintf( ...
                        'Compare: skipped %d machine(s) without the shared sensor: %s', ...
                        numel(names), strjoin(names, ', ')));
                end
            catch
            end
        end

        function nm = sensorDisplayName_(~, tag, fallbackKey)
        %SENSORDISPLAYNAME_ Resolved tag Name, falling back to the local key.
            nm = fallbackKey;
            try
                if isprop(tag, 'Name') && ~isempty(tag.Name)
                    nm = tag.Name;
                end
            catch
            end
        end

        % ---------------------------------------------------------------
        % Unit-mismatch + badges + shared helpers
        % ---------------------------------------------------------------

        function tf = detectRowUnitMismatch_(obj, rs)
        %DETECTROWUNITMISMATCH_ True iff the override tag's units differ from canonical.
        %   Mirrors buildCompareResolution_'s guarded rule: both units must be
        %   non-empty and differ case-insensitively. The canonical reference
        %   unit is the resolved entry's localUnits cached on the row.
            tf = false;
            canonicalUnits = rs.localUnits;
            if isempty(canonicalUnits) || isempty(rs.localKey)
                return;
            end
            tagUnits = obj.tagUnits_(obj.App_.fleet(), rs.machineId, rs.localKey);
            if isempty(tagUnits)
                return;
            end
            tf = ~strcmpi(canonicalUnits, tagUnits);
        end

        function u = tagUnits_(~, fleet, machineId, localKey)
        %TAGUNITS_ Best-effort 'Units' of a machine's local tag ('' on any failure).
            u = '';
            try
                tag = fleet.getMachine(machineId).get(localKey);
                if isprop(tag, 'Units')
                    u = tag.Units;
                end
            catch
            end
        end

        function applyBadge_(obj, i)
        %APPLYBADGE_ Set row i's status badge text + FontColor from its state.
            rs = obj.RowStates_{i};
            h  = obj.RowHandles_{i};
            if ~isvalid(h.hBadge); return; end
            [txt, col]     = obj.badgeSpec_(rs);
            h.hBadge.Text      = txt;
            h.hBadge.FontColor = col;
        end

        function [txt, col] = badgeSpec_(obj, rs)
        %BADGESPEC_ Badge text + FontColor for a row state (single source of truth).
        %   Shared by rebuildRows_, the in-place updates, and (Plan 04) applyTheme_,
        %   so a theme change recomputes the same per-state color the rebuild uses.
            t = obj.Theme_;
            switch rs.state
                case 'auto'
                    txt = [obj.CHECK_ ' auto'];
                    col = t.ToolbarFontColor;
                case 'confirm_needed'
                    txt = [obj.WARN_ ' confirm'];
                    col = t.StatusWarnColor;
                case 'override'
                    if isfield(rs, 'promoted') && rs.promoted
                        txt = [obj.CHECK_ ' promoted'];
                        col = t.Accent;
                    elseif isfield(rs, 'unitMismatch') && rs.unitMismatch
                        txt = [obj.WARN_ ' unit mismatch'];
                        col = t.StatusWarnColor;
                    else
                        txt = [obj.PENCIL_ ' override'];
                        col = t.ToolbarFontColor;
                    end
                otherwise   % none
                    txt = obj.NONE_;
                    col = t.ToolbarFontColor;
            end
        end

        function renderCenteredHint_(obj, text, fontSize, weight)
        %RENDERCENTEREDHINT_ Centered placeholder label inside the scroll panel.
            g = uigridlayout(obj.hScrollPanel_, [1 1]);
            g.BackgroundColor = obj.Theme_.WidgetBackground;
            lbl = uilabel(g);
            lbl.Text                = text;
            lbl.FontSize            = fontSize;
            lbl.FontWeight          = weight;
            lbl.FontColor           = obj.Theme_.PlaceholderTextColor;
            lbl.HorizontalAlignment = 'center';
            lbl.VerticalAlignment   = 'center';
        end

        function alertError_(obj, err, titleStr)
        %ALERTERROR_ Non-blocking uialert for a caught callback error.
            if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                uialert(obj.hFig_, err.message, titleStr);
            end
        end

    end
end
