classdef InspectorPane < handle
%INSPECTORPANE Adaptive right-pane inspector for FastSenseCompanion (Phase 1021).
%
%   Four states driven by orchestrator InspectorStateChanged event:
%     'welcome'   - project name, counts, three-pane hint
%     'tag'       - single-tag detail: metadata, thresholds, sparkline, Open Detail
%     'dashboard' - dashboard summary + Play/Pause controls
%     'multitag'  - composer shell: chips + mode toggle + Plot CTA
%
%   Usage: pane.attach(parentPanel, hFig, catalogPane, orchestrator, theme)
%          pane.detach()
%          pane.setState(state, payload)   % called by InspectorStateChanged listener
%
%   Sparkline rendered via axes('Parent', uipanel, ...) — REQ-locked by INSPECT-02.
%   Plot button fires OpenAdHocPlotRequested on orchestrator; Phase 1022 spawns figure.
%
%   See also FastSenseCompanion, inspectorResolveState, InspectorStateEventData,
%            AdHocPlotEventData, SensorDetailPlot, CompanionTheme.

    properties (Access = private)
        hPanel_         = []   % parent uipanel
        hFig_           = []   % uifigure handle (for uialert)
        hContent_       = []   % scrollable inner panel; cleared on every state change
        hSparkAxes_     = []   % axes handle (tag state only)
        hSparkPanel_    = []   % sparkline container uipanel (tag state only)
        hOpenDetail_    = []   % "Open Detail" button (tag state only)
        hPlayBtn_       = []   % Play button (dashboard state only)
        hPauseBtn_      = []   % Pause button (dashboard state only)
        hChipsGrid_     = []   % chip list inner grid (multitag state only)
        hModeOverlay_   = []   % "Overlay" mode button (multitag state only)
        hModeLinked_    = []   % "Linked grid" mode button (multitag state only)
        hPlotBtn_       = []   % Plot CTA (multitag state only)
        State_          = 'welcome'
        Payload_        = struct()
        ComposerMode_   = 'Overlay'
        CurrentTagKeys_ = {}
        CatalogPane_    = []
        Orchestrator_   = []
        Theme_          = []
        Listeners_      = {}
    end

    methods (Access = public)

        function attach(obj, parentPanel, hFig, catalogPane, orchestrator, theme)
        %ATTACH Build inspector scaffolding inside parentPanel.
        %   parentPanel - uipanel from FastSenseCompanion.hRightPanel_
        %   hFig        - uifigure handle (for uialert parenting)
        %   catalogPane - TagCatalogPane instance (for deselectKey calls)
        %   orchestrator - FastSenseCompanion instance (for notify)
        %   theme       - resolved CompanionTheme struct
            obj.hPanel_       = parentPanel;
            obj.hFig_         = hFig;
            obj.CatalogPane_  = catalogPane;
            obj.Orchestrator_ = orchestrator;
            obj.Theme_        = theme;
            obj.State_          = 'welcome';
            obj.Payload_        = struct('nTags', 0, 'nDashboards', 0);
            obj.ComposerMode_   = 'Overlay';
            obj.CurrentTagKeys_ = {};
            delete(obj.hPanel_.Children);
            obj.hContent_ = uipanel(obj.hPanel_);
            obj.hContent_.Units           = 'normalized';
            obj.hContent_.Position        = [0 0 1 1];
            obj.hContent_.Scrollable      = 'on';
            obj.hContent_.BorderType      = 'none';
            obj.hContent_.BackgroundColor = obj.Theme_.WidgetBackground;
            obj.renderState_();
        end

        function detach(obj)
        %DETACH Release listeners and clear per-state handles.
            % delete(cellArray) is interpreted as filename-delete by MATLAB
            % ("Name must be a text scalar"). Iterate explicitly.
            for ii = 1:numel(obj.Listeners_)
                lh = obj.Listeners_{ii};
                if isobject(lh) && isvalid(lh)
                    delete(lh);
                end
            end
            obj.Listeners_ = {};
            obj.hSparkAxes_ = []; obj.hSparkPanel_ = []; obj.hOpenDetail_ = [];
            obj.hPlayBtn_   = []; obj.hPauseBtn_   = []; obj.hChipsGrid_  = [];
            obj.hModeOverlay_ = []; obj.hModeLinked_ = []; obj.hPlotBtn_   = [];
        end

        function setState(obj, state, payload)
        %SETSTATE Public mutator called by InspectorStateChanged listener.
        %   state   - char ('welcome'|'tag'|'multitag'|'dashboard')
        %   payload - struct (shape per inspectorResolveState contract)
            try
                if ~strcmp(state, 'multitag') && strcmp(obj.State_, 'multitag')
                    obj.ComposerMode_ = 'Overlay';
                end
                obj.State_   = state;
                obj.Payload_ = payload;
                obj.renderState_();
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'FastSense Companion');
                else
                    rethrow(err);
                end
            end
        end

    end

    methods (Access = private)

        function renderState_(obj)
        %RENDERSTATE_ Clear hContent_.Children and dispatch to per-state renderer.
            try
                if isempty(obj.hContent_) || ~isvalid(obj.hContent_); return; end
                delete(obj.hContent_.Children);
                obj.hSparkAxes_ = []; obj.hSparkPanel_ = []; obj.hOpenDetail_ = [];
                obj.hPlayBtn_   = []; obj.hPauseBtn_   = []; obj.hChipsGrid_  = [];
                obj.hModeOverlay_ = []; obj.hModeLinked_ = []; obj.hPlotBtn_   = [];
                switch obj.State_
                    case 'welcome';   obj.renderWelcome_();
                    case 'tag';       obj.renderTag_();
                    case 'dashboard'; obj.renderDashboard_();
                    case 'multitag';  obj.renderMultitag_();
                    otherwise
                        error('FastSenseCompanion:invalidState', ...
                            'Unknown inspector state: ''%s''.', obj.State_);
                end
            catch err
                if ~isempty(obj.hFig_) && isvalid(obj.hFig_)
                    uialert(obj.hFig_, err.message, 'FastSense Companion');
                end
            end
        end

        function renderWelcome_(obj)
        %RENDERWELCOME_ Render welcome-state content.
            t = obj.Theme_;
            g = uigridlayout(obj.hContent_, [7 1]);
            g.RowHeight = {20, 4, 20, 8, 20, 20, 20};
            g.ColumnWidth = {'1x'}; g.Padding = [16 16 16 16];
            g.RowSpacing = 0; g.BackgroundColor = t.WidgetBackground;
            l1 = uilabel(g); l1.Layout.Row = 1; l1.Layout.Column = 1;
            l1.Text = obj.hFig_.Name; l1.FontSize = 14; l1.FontWeight = 'bold';
            l1.FontColor = t.ForegroundColor; l1.HorizontalAlignment = 'left';
            l1.VerticalAlignment = 'center';
            nT = 0; nD = 0;
            if isfield(obj.Payload_, 'nTags');       nT = obj.Payload_.nTags;       end
            if isfield(obj.Payload_, 'nDashboards'); nD = obj.Payload_.nDashboards; end
            l3 = uilabel(g); l3.Layout.Row = 3; l3.Layout.Column = 1;
            l3.Text = sprintf('%d tags %s %d dashboards', nT, char(183), nD);
            l3.FontSize = 11; l3.FontColor = t.PlaceholderTextColor;
            l3.HorizontalAlignment = 'left'; l3.VerticalAlignment = 'center';
            hints = {'Select a tag for details', 'Click a dashboard row for summary', ...
                     'Select 2+ tags to compose a plot'};
            for i = 1:3
                lh = uilabel(g); lh.Layout.Row = 4 + i; lh.Layout.Column = 1;
                lh.Text = hints{i}; lh.FontSize = 11;
                lh.FontColor = t.PlaceholderTextColor;
                lh.HorizontalAlignment = 'left'; lh.VerticalAlignment = 'center';
            end
        end

        function renderTag_(obj)
        %RENDERTAG_ Render single-tag detail with type-aware metadata,
        %   thresholds, sparkline, and Open Detail button.
            t = obj.Theme_;
            if ~isfield(obj.Payload_, 'tag'); return; end
            tag = obj.Payload_.tag;

            % Identify tag kind (Sensor / State / Monitor / Composite / Tag).
            kindTxt = obj.tagKindLabel_(tag);

            % Common metadata rows
            uTxt = char(8212);
            if isprop(tag, 'Units') && ~isempty(tag.Units); uTxt = char(tag.Units); end
            dTxt = char(8212);
            if isprop(tag, 'Description') && ~isempty(tag.Description); dTxt = char(tag.Description); end
            cTxt = char(8212);
            if isprop(tag, 'Criticality') && ~isempty(tag.Criticality); cTxt = char(tag.Criticality); end
            lblTxt = char(8212);
            if isprop(tag, 'Labels') && ~isempty(tag.Labels)
                try
                    lblTxt = strjoin(cellfun(@char, tag.Labels(:), 'UniformOutput', false), ', ');
                catch
                    lblTxt = char(8212);
                end
            end

            % Type-specific rows (cell of {label, value} pairs)
            extraRows = obj.tagTypeSpecificRows_(tag);

            % Compose grid: 7 base meta rows + N extra + threshold + sparkline + button
            nMeta  = 7;
            nExtra = numel(extraRows);
            nRows  = nMeta + nExtra + 6;  % +gap +threshold-hdr +threshold-content +gap +spark +gap +button
            rowH   = cell(1, nRows);
            for r = 1:(nMeta + nExtra); rowH{r} = 20; end
            r = nMeta + nExtra + 1; rowH{r} = 8;       % gap
            r = r + 1; rowH{r} = 16;                    % threshold header
            r = r + 1; rowH{r} = 'fit';                 % threshold content
            r = r + 1; rowH{r} = 8;                     % gap
            r = r + 1; rowH{r} = 84;                    % sparkline
            r = r + 1; rowH{r} = 32;                    % open detail button

            g = uigridlayout(obj.hContent_, [nRows 1]);
            g.RowHeight = rowH; g.ColumnWidth = {'1x'};
            g.Padding = [16 16 16 16]; g.RowSpacing = 4;
            g.BackgroundColor = t.WidgetBackground;

            % Base meta rows (always shown)
            obj.buildMetaRow_(g, 1, 'Key',         char(tag.Key));
            obj.buildMetaRow_(g, 2, 'Name',        char(tag.Name));
            obj.buildMetaRow_(g, 3, 'Type',        kindTxt);
            obj.buildMetaRow_(g, 4, 'Units',       uTxt);
            obj.buildMetaRow_(g, 5, 'Criticality', cTxt);
            obj.buildMetaRow_(g, 6, 'Labels',      lblTxt);
            obj.buildMetaRow_(g, 7, 'Description', dTxt);

            % Type-specific rows (CompositeTag children, MonitorTag trip, etc.)
            for k = 1:nExtra
                obj.buildMetaRow_(g, nMeta + k, extraRows{k}{1}, extraRows{k}{2});
            end

            % Thresholds section
            rThdr = nMeta + nExtra + 2;  % skip the gap row
            hHdr = uilabel(g); hHdr.Layout.Row = rThdr; hHdr.Layout.Column = 1;
            hHdr.Text = 'Thresholds'; hHdr.FontSize = 11; hHdr.FontWeight = 'bold';
            hHdr.FontColor = t.ForegroundColor;

            rTcontent = rThdr + 1;
            hTh = uipanel(g); hTh.Layout.Row = rTcontent; hTh.Layout.Column = 1;
            hTh.BorderType = 'none'; hTh.BackgroundColor = t.WidgetBackground;
            rules = {};
            if isa(tag, 'SensorTag') || isa(tag, 'MonitorTag')
                if isprop(tag, 'Thresholds'); rules = tag.Thresholds; end
            end
            if isempty(rules)
                lb = uilabel(hTh); lb.Text = 'No thresholds defined'; lb.FontSize = 11;
                lb.FontColor = t.PlaceholderTextColor; lb.HorizontalAlignment = 'left';
                lb.VerticalAlignment = 'center';
            else
                rg = uigridlayout(hTh, [numel(rules) 1]);
                rg.RowHeight = repmat({20}, 1, numel(rules)); rg.ColumnWidth = {'1x'};
                rg.Padding = [0 0 0 0]; rg.RowSpacing = 4; rg.BackgroundColor = t.WidgetBackground;
                for i = 1:numel(rules)
                    rule = rules{i};
                    lb = uilabel(rg); lb.Layout.Row = i; lb.Layout.Column = 1;
                    try
                        lb.Text = sprintf('%s: %s (%s)', char(rule.Name), char(rule.Condition), char(rule.Criticality));
                    catch
                        lb.Text = char(8212);
                    end
                    lb.FontSize = 11; lb.FontColor = t.ForegroundColor; lb.WordWrap = 'on';
                end
            end

            % Sparkline (skips its row gracefully via 'No data' fallback)
            rSpark = rTcontent + 2;  % skip gap
            obj.hSparkPanel_ = uipanel(g);
            obj.hSparkPanel_.Layout.Row = rSpark; obj.hSparkPanel_.Layout.Column = 1;
            obj.hSparkPanel_.BackgroundColor = t.WidgetBackground;
            obj.hSparkPanel_.BorderColor = t.WidgetBorderColor; obj.hSparkPanel_.BorderType = 'line';
            obj.renderSparkline_(tag);

            % Open Detail button
            rBtn = rSpark + 1;
            obj.hOpenDetail_ = uibutton(g, 'push');
            obj.hOpenDetail_.Layout.Row = rBtn; obj.hOpenDetail_.Layout.Column = 1;
            obj.hOpenDetail_.Text = 'Open Detail'; obj.hOpenDetail_.FontSize = 11;
            obj.hOpenDetail_.FontWeight = 'normal'; obj.hOpenDetail_.FontColor = t.ForegroundColor;
            obj.hOpenDetail_.BackgroundColor = t.WidgetBorderColor;
            obj.hOpenDetail_.Tooltip = sprintf('Open SensorDetailPlot for "%s"', char(tag.Name));
            obj.hOpenDetail_.ButtonPushedFcn = @(~,~) obj.onOpenDetail_(tag);
        end

        function kind = tagKindLabel_(~, tag)
        %TAGKINDLABEL_ Return human-readable tag kind (Sensor / State / Monitor / Composite / Tag).
            if     isa(tag, 'SensorTag');    kind = 'Sensor';
            elseif isa(tag, 'StateTag');     kind = 'State';
            elseif isa(tag, 'MonitorTag');   kind = 'Monitor';
            elseif isa(tag, 'CompositeTag'); kind = 'Composite';
            elseif isa(tag, 'Tag');          kind = 'Tag';
            else;                            kind = class(tag);
            end
        end

        function rows = tagTypeSpecificRows_(~, tag)
        %TAGTYPESPECIFICROWS_ Return cell of {label, value} pairs specific
        %   to the tag's class. Defensive — any failure yields {} so the
        %   inspector still renders the base metadata.
            rows = {};
            try
                if isa(tag, 'SensorTag') || isa(tag, 'StateTag')
                    % Sample count + range
                    try
                        [x, ~] = tag.getXY();
                        if isempty(x)
                            rows{end+1} = {'Samples', '0'};
                        else
                            rows{end+1} = {'Samples', sprintf('%d', numel(x))};
                            try
                                rows{end+1} = {'X range', sprintf('%.4g .. %.4g', min(x), max(x))};
                            catch
                            end
                        end
                    catch
                        rows{end+1} = {'Samples', char(8212)};
                    end
                end
                if isa(tag, 'MonitorTag')
                    % Trip / release conditions if exposed
                    if isprop(tag, 'TripCondition') && ~isempty(tag.TripCondition)
                        rows{end+1} = {'Trip', char(string(tag.TripCondition))};
                    end
                    if isprop(tag, 'ReleaseCondition') && ~isempty(tag.ReleaseCondition)
                        rows{end+1} = {'Release', char(string(tag.ReleaseCondition))};
                    end
                    if isprop(tag, 'SourceTagKey') && ~isempty(tag.SourceTagKey)
                        rows{end+1} = {'Source tag', char(tag.SourceTagKey)};
                    end
                end
                if isa(tag, 'CompositeTag')
                    if isprop(tag, 'AggregateMode')
                        rows{end+1} = {'Aggregate', char(tag.AggregateMode)};
                    end
                    % Child keys via the public getChildKeys() accessor
                    if ismethod(tag, 'getChildKeys')
                        try
                            childKeys = tag.getChildKeys();
                            nChild = numel(childKeys);
                            if nChild == 0
                                rows{end+1} = {'Children', '0'};
                            else
                                rows{end+1} = {'Children', sprintf('%d (%s)', nChild, ...
                                    strjoin(cellfun(@char, childKeys(:), 'UniformOutput', false), ', '))};
                            end
                        catch
                            rows{end+1} = {'Children', char(8212)};
                        end
                    end
                end
            catch
                rows = {};
            end
        end

        function renderSparkline_(obj, tag)
        %RENDERSPARKLINE_ Render last-200-sample sparkline via axes('Parent', uipanel).
            t = obj.Theme_;
            try
                if ~ismethod(tag, 'getXY'); obj.renderNoData_('No data'); return; end
                [tv, y] = tag.getXY();
                if isempty(tv) || isempty(y); obj.renderNoData_('No data'); return; end
                if numel(tv) > 200; tv = tv(end-199:end); y = y(end-199:end); end
                obj.hSparkAxes_ = axes('Parent', obj.hSparkPanel_, ...
                    'Units', 'normalized', 'Position', [0 0 1 1], ...
                    'Color', t.WidgetBackground, 'XColor', t.WidgetBackground, ...
                    'YColor', t.WidgetBackground, 'Box', 'off', 'XTick', [], 'YTick', []);
                plot(obj.hSparkAxes_, tv, y, '-', 'Color', t.LineColors{1}, 'LineWidth', 1);
                axis(obj.hSparkAxes_, 'tight');
                xl = obj.hSparkAxes_.XLim; yl = obj.hSparkAxes_.YLim;
                px = (xl(2) - xl(1)) * 0.02; if px > 0; obj.hSparkAxes_.XLim = xl + [-px, px]; end
                py = (yl(2) - yl(1)) * 0.05; if py > 0; obj.hSparkAxes_.YLim = yl + [-py, py]; end
                try; obj.hSparkAxes_.Toolbar.Visible = 'off'; catch; end
                try; obj.hSparkAxes_.Interactions = []; catch; end
            catch
                obj.renderNoData_('Sparkline unavailable');
            end
        end

        function renderNoData_(obj, msgText)
        %RENDERNODATA_ Replace sparkline area with a centered placeholder label.
            if ~isempty(obj.hSparkAxes_) && isvalid(obj.hSparkAxes_)
                delete(obj.hSparkAxes_); obj.hSparkAxes_ = [];
            end
            t = obj.Theme_;
            lb = uilabel(obj.hSparkPanel_); lb.Text = msgText; lb.FontSize = 11;
            lb.FontColor = t.PlaceholderTextColor; lb.HorizontalAlignment = 'center';
            lb.VerticalAlignment = 'center';
                % Note: uilabel has no Units/Position — those are uicontrol
                % properties. Default placement inside the parent uipanel.
        end

        function onOpenDetail_(obj, tag)
        %ONOPENDETAIL_ Open SensorDetailPlot in its own classical figure.
        %   SensorDetailPlot's render() creates its own figure when no
        %   ParentPanel is supplied — do NOT pre-create one with figure(),
        %   that would leave an empty extra window. Just construct + render.
            try
                sd = SensorDetailPlot(tag);
                sd.render();
            catch ME
                uialert(obj.hFig_, sprintf('Failed to open detail: %s', ME.message), ...
                    'FastSense Companion', 'Icon', 'error');
            end
        end

        function renderDashboard_(obj)
        %RENDERDASHBOARD_ Render dashboard summary with full metadata, page
        %   list, referenced tags, Play/Pause buttons, and Open Dashboard CTA.
            t = obj.Theme_;
            if ~isfield(obj.Payload_, 'dashboard'); return; end
            db = obj.Payload_.dashboard;

            % Compute meta values
            wcRoot = numel(db.Widgets);
            wcPages = 0;
            for pp = 1:numel(db.Pages); wcPages = wcPages + numel(db.Pages{pp}.Widgets); end
            wcTotal = wcRoot + wcPages;

            pageLabel = char(8212);
            if ~isempty(db.Pages)
                pageNames = cell(1, numel(db.Pages));
                for pp = 1:numel(db.Pages)
                    p = db.Pages{pp};
                    if isprop(p, 'Name') && ~isempty(p.Name)
                        pageNames{pp} = char(p.Name);
                    else
                        pageNames{pp} = sprintf('Page %d', pp);
                    end
                end
                pageLabel = sprintf('%d (%s)', numel(db.Pages), strjoin(pageNames, ', '));
            end

            themeLabel = char(8212);
            if isprop(db, 'Theme'); themeLabel = char(string(db.Theme)); end

            renderedLabel = 'No';
            if ~isempty(db.hFigure) && ishandle(db.hFigure); renderedLabel = 'Yes'; end

            bindings = obj.collectDashboardTagBindings_(db);

            % Compose grid (variable rows depending on bindings count)
            nMeta = 7;  % Title, gap, Widgets, Pages, Theme, Live interval, Live
            nRows = nMeta + 4;  % +Tags hdr +Tags content +gap +button row
            rowH = cell(1, nRows);
            rowH{1} = 28;       % Title
            rowH{2} = 8;        % gap
            for r = 3:7; rowH{r} = 20; end
            rowH{8} = 16;       % Tags header
            rowH{9} = 'fit';    % Tags content
            rowH{10} = 8;       % gap
            rowH{11} = 32;      % action buttons (Play / Pause / Open)

            g = uigridlayout(obj.hContent_, [nRows 1]);
            g.RowHeight = rowH; g.ColumnWidth = {'1x'};
            g.Padding = [16 16 16 16]; g.RowSpacing = 4;
            g.BackgroundColor = t.WidgetBackground;

            % Title
            lt = uilabel(g); lt.Layout.Row = 1; lt.Layout.Column = 1;
            lt.Text = char(db.Name); lt.FontSize = 14; lt.FontWeight = 'bold';
            lt.FontColor = t.ForegroundColor; lt.WordWrap = 'on';
            lt.HorizontalAlignment = 'left'; lt.VerticalAlignment = 'center';

            % Meta rows
            obj.buildMetaRow_(g, 3, 'Widgets',       sprintf('%d (root: %d, paged: %d)', wcTotal, wcRoot, wcPages));
            obj.buildMetaRow_(g, 4, 'Pages',         pageLabel);
            obj.buildMetaRow_(g, 5, 'Theme',         themeLabel);
            obj.buildMetaRow_(g, 6, 'Live interval', sprintf('%g s', db.LiveInterval));
            if db.IsLive
                obj.buildMetaRow_(g, 7, 'Status', sprintf('Live %s rendered: %s', char(183), renderedLabel));
            else
                obj.buildMetaRow_(g, 7, 'Status', sprintf('Idle %s rendered: %s', char(183), renderedLabel));
            end

            % Tags section
            lh = uilabel(g); lh.Layout.Row = 8; lh.Layout.Column = 1;
            lh.Text = sprintf('Tags (%d)', numel(bindings));
            lh.FontSize = 11; lh.FontWeight = 'bold'; lh.FontColor = t.ForegroundColor;
            hTg = uipanel(g); hTg.Layout.Row = 9; hTg.Layout.Column = 1;
            hTg.BorderType = 'none'; hTg.BackgroundColor = t.WidgetBackground;
            if isempty(bindings)
                lb = uilabel(hTg); lb.Text = 'No tag bindings'; lb.FontSize = 11;
                lb.FontColor = t.PlaceholderTextColor; lb.HorizontalAlignment = 'center';
                lb.VerticalAlignment = 'center';
            else
                tg = uigridlayout(hTg, [numel(bindings) 1]);
                tg.RowHeight = repmat({20}, 1, numel(bindings)); tg.ColumnWidth = {'1x'};
                tg.Padding = [0 0 0 0]; tg.RowSpacing = 4; tg.BackgroundColor = t.WidgetBackground;
                for i = 1:numel(bindings)
                    lb = uilabel(tg); lb.Layout.Row = i; lb.Layout.Column = 1;
                    lb.Text = char(bindings{i}); lb.FontSize = 11; lb.FontColor = t.ForegroundColor;
                end
            end

            % Action button row (Play | Pause | Open Dashboard)
            bg = uigridlayout(g, [1 3]); bg.Layout.Row = 11; bg.Layout.Column = 1;
            bg.ColumnWidth = {'1x', '1x', '1x'}; bg.RowHeight = {'1x'};
            bg.Padding = [0 0 0 0]; bg.ColumnSpacing = 8; bg.BackgroundColor = t.WidgetBackground;

            obj.hPlayBtn_ = uibutton(bg, 'push');
            obj.hPlayBtn_.Layout.Row = 1; obj.hPlayBtn_.Layout.Column = 1;
            obj.hPlayBtn_.Text = [char(9654) ' Play']; obj.hPlayBtn_.FontSize = 11;
            obj.hPlayBtn_.FontWeight = 'normal'; obj.hPlayBtn_.FontColor = t.ForegroundColor;
            obj.hPlayBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hPlayBtn_.Tooltip = 'Start live refresh for this dashboard';
            if db.IsLive; obj.hPlayBtn_.Enable = 'off'; else; obj.hPlayBtn_.Enable = 'on'; end
            obj.hPlayBtn_.ButtonPushedFcn = @(~,~) obj.onPlay_(db);

            obj.hPauseBtn_ = uibutton(bg, 'push');
            obj.hPauseBtn_.Layout.Row = 1; obj.hPauseBtn_.Layout.Column = 2;
            obj.hPauseBtn_.Text = [char(9646) char(9646) ' Pause']; obj.hPauseBtn_.FontSize = 11;
            obj.hPauseBtn_.FontWeight = 'normal'; obj.hPauseBtn_.FontColor = t.ForegroundColor;
            obj.hPauseBtn_.BackgroundColor = t.WidgetBorderColor;
            obj.hPauseBtn_.Tooltip = 'Stop live refresh for this dashboard';
            if db.IsLive; obj.hPauseBtn_.Enable = 'on'; else; obj.hPauseBtn_.Enable = 'off'; end
            obj.hPauseBtn_.ButtonPushedFcn = @(~,~) obj.onPause_(db);

            % Open Dashboard button — brings figure to front (or renders if needed).
            obj.hOpenDetail_ = uibutton(bg, 'push');
            obj.hOpenDetail_.Layout.Row = 1; obj.hOpenDetail_.Layout.Column = 3;
            obj.hOpenDetail_.Text = 'Open'; obj.hOpenDetail_.FontSize = 11;
            obj.hOpenDetail_.FontWeight = 'bold'; obj.hOpenDetail_.FontColor = t.ForegroundColor;
            obj.hOpenDetail_.BackgroundColor = t.WidgetBorderColor;
            obj.hOpenDetail_.Tooltip = sprintf('Open / focus the "%s" figure window', char(db.Name));
            obj.hOpenDetail_.ButtonPushedFcn = @(~,~) obj.onOpenDashboard_(db);
        end

        function onOpenDashboard_(obj, db)
        %ONOPENDASHBOARD_ Render the dashboard if not yet rendered, then bring its
        %   figure to front. Mirrors DashboardListPane.onOpenClicked_ behavior so
        %   the inspector's Open works identically to the row's Open button.
            try
                if isempty(db.hFigure) || ~ishandle(db.hFigure)
                    db.render();
                end
                if ~isempty(db.hFigure) && ishandle(db.hFigure)
                    figure(db.hFigure);  % bring to front / focus
                end
                obj.renderState_();  % refresh the "rendered: Yes/No" status row
            catch ME
                uialert(obj.hFig_, ...
                    sprintf('Failed to open dashboard "%s": %s', char(db.Name), ME.message), ...
                    'FastSense Companion', 'Icon', 'error');
            end
        end

        function bindings = collectDashboardTagBindings_(obj, dashboard) %#ok<INUSL>
        %COLLECTDASHBOARDTAGBINDINGS_ Walk dashboard widgets and collect unique tag bindings.
            collected = {};
            allW = dashboard.Widgets;
            for p = 1:numel(dashboard.Pages); allW = [allW, dashboard.Pages{p}.Widgets]; end %#ok<AGROW>
            for w = 1:numel(allW)
                wid = allW{w};
                for pn = {'Tag', 'TagKey', 'Sensor'}
                    pnm = pn{1};
                    if isprop(wid, pnm)
                        % Defensive read: some widget property getters
                        % internally call TagRegistry.get() which throws
                        % when a tag key has been unregistered or is
                        % stale. The inspector must never crash from a
                        % single widget's bad binding — skip silently.
                        try
                            val = wid.(pnm);
                        catch
                            continue;
                        end
                        str = '';
                        try
                            if ischar(val); str = val;
                            elseif isstring(val) && isscalar(val); str = char(val);
                            elseif isobject(val) && isprop(val, 'Key'); str = val.Key;
                            elseif isobject(val) && isprop(val, 'Name'); str = val.Name; end
                        catch
                            str = '';
                        end
                        if ~isempty(str); collected{end+1} = str; end %#ok<AGROW>
                    end
                end
            end
            bindings = {};
            for i = 1:numel(collected)
                if ~any(strcmp(bindings, collected{i})); bindings{end+1} = collected{i}; end %#ok<AGROW>
            end
        end

        function onPlay_(obj, dashboard)
        %ONPLAY_ Call dashboard.startLive() then re-render to update Enable states.
            try
                dashboard.startLive(); obj.renderState_();
            catch ME
                uialert(obj.hFig_, sprintf('Failed to start live: %s', ME.message), ...
                    'FastSense Companion', 'Icon', 'error');
            end
        end

        function onPause_(obj, dashboard)
        %ONPAUSE_ Call dashboard.stopLive() then re-render to update Enable states.
            try
                dashboard.stopLive(); obj.renderState_();
            catch ME
                uialert(obj.hFig_, sprintf('Failed to pause: %s', ME.message), ...
                    'FastSense Companion', 'Icon', 'error');
            end
        end

        function renderMultitag_(obj)
        %RENDERMULTITAG_ Render composer shell: chips + mode toggle + Plot CTA.
            t = obj.Theme_;
            if ~isfield(obj.Payload_, 'tags') || ~isfield(obj.Payload_, 'tagKeys'); return; end
            tags = obj.Payload_.tags;
            obj.CurrentTagKeys_ = obj.Payload_.tagKeys;
            g = uigridlayout(obj.hContent_, [7 1]);
            g.RowHeight = {16, 'fit', 8, 16, 28, 8, 32};
            g.ColumnWidth = {'1x'}; g.Padding = [16 16 16 16];
            g.RowSpacing = 0; g.BackgroundColor = t.WidgetBackground;
            hHdr = uilabel(g); hHdr.Layout.Row = 1; hHdr.Layout.Column = 1;
            hHdr.Text = 'Tags'; hHdr.FontSize = 11; hHdr.FontWeight = 'bold';
            hHdr.FontColor = t.ForegroundColor;
            hCS = uipanel(g); hCS.Layout.Row = 2; hCS.Layout.Column = 1;
            hCS.BorderType = 'none'; hCS.BackgroundColor = t.WidgetBackground;
            nT = numel(tags);
            obj.hChipsGrid_ = uigridlayout(hCS, [nT 1]);
            obj.hChipsGrid_.RowHeight = repmat({24}, 1, nT); obj.hChipsGrid_.ColumnWidth = {'1x'};
            obj.hChipsGrid_.Padding = [0 0 0 0]; obj.hChipsGrid_.RowSpacing = 4;
            obj.hChipsGrid_.BackgroundColor = t.WidgetBackground;
            for i = 1:nT
                tg = tags{i};
                cr = uigridlayout(obj.hChipsGrid_, [1 2]);
                cr.Layout.Row = i; cr.Layout.Column = 1;
                cr.ColumnWidth = {'1x', 20}; cr.RowHeight = {'1x'};
                cr.Padding = [4 0 4 0]; cr.ColumnSpacing = 4; cr.BackgroundColor = t.WidgetBackground;
                ln = uilabel(cr); ln.Layout.Row = 1; ln.Layout.Column = 1;
                ln.Text = tg.Name; ln.FontSize = 11; ln.FontColor = t.ForegroundColor;
                ln.HorizontalAlignment = 'left'; ln.VerticalAlignment = 'center';
                ln.Tooltip = tg.Key;
                bx = uibutton(cr, 'push'); bx.Layout.Row = 1; bx.Layout.Column = 2;
                bx.Text = char(215); bx.FontSize = 11; bx.FontColor = t.ToolbarFontColor;
                bx.BackgroundColor = t.WidgetBackground;
                bx.Tooltip = sprintf('Remove "%s" from selection', tg.Name);
                bx.ButtonPushedFcn = @(~,~) obj.onChipDeselect_(tg.Key);
            end
            mh = uilabel(g); mh.Layout.Row = 4; mh.Layout.Column = 1;
            mh.Text = 'Mode'; mh.FontSize = 11; mh.FontWeight = 'bold'; mh.FontColor = t.ForegroundColor;
            mg = uigridlayout(g, [1 2]); mg.Layout.Row = 5; mg.Layout.Column = 1;
            mg.ColumnWidth = {'1x', '1x'}; mg.RowHeight = {'1x'};
            mg.Padding = [0 0 0 0]; mg.ColumnSpacing = 4; mg.BackgroundColor = t.WidgetBackground;
            obj.hModeOverlay_ = uibutton(mg, 'push');
            obj.hModeOverlay_.Layout.Row = 1; obj.hModeOverlay_.Layout.Column = 1;
            obj.hModeOverlay_.Text = 'Overlay'; obj.hModeOverlay_.FontSize = 11;
            obj.hModeOverlay_.ButtonPushedFcn = @(~,~) obj.onModeToggle_('Overlay');
            obj.hModeLinked_ = uibutton(mg, 'push');
            obj.hModeLinked_.Layout.Row = 1; obj.hModeLinked_.Layout.Column = 2;
            obj.hModeLinked_.Text = 'Linked grid'; obj.hModeLinked_.FontSize = 11;
            obj.hModeLinked_.ButtonPushedFcn = @(~,~) obj.onModeToggle_('LinkedGrid');
            obj.applyModeToggleStyles_();
            obj.hPlotBtn_ = uibutton(g, 'push');
            obj.hPlotBtn_.Layout.Row = 7; obj.hPlotBtn_.Layout.Column = 1;
            obj.hPlotBtn_.Text = 'Plot'; obj.hPlotBtn_.FontSize = 11; obj.hPlotBtn_.FontWeight = 'bold';
            obj.hPlotBtn_.FontColor = t.DashboardBackground; obj.hPlotBtn_.BackgroundColor = t.Accent;
            obj.hPlotBtn_.Tooltip = 'Open an ad-hoc plot with the selected tags';
            obj.hPlotBtn_.ButtonPushedFcn = @(~,~) obj.onPlot_();
        end

        function applyModeToggleStyles_(obj)
        %APPLYMODETOGGLESTYLES_ Highlight active mode button; style inactive as idle.
            t = obj.Theme_;
            if strcmp(obj.ComposerMode_, 'Overlay')
                obj.hModeOverlay_.BackgroundColor = t.Accent;
                obj.hModeOverlay_.FontColor       = t.DashboardBackground;
                obj.hModeOverlay_.FontWeight      = 'bold';
                obj.hModeLinked_.BackgroundColor  = t.WidgetBackground;
                obj.hModeLinked_.FontColor        = t.ToolbarFontColor;
                obj.hModeLinked_.FontWeight       = 'normal';
            else
                obj.hModeLinked_.BackgroundColor  = t.Accent;
                obj.hModeLinked_.FontColor        = t.DashboardBackground;
                obj.hModeLinked_.FontWeight       = 'bold';
                obj.hModeOverlay_.BackgroundColor = t.WidgetBackground;
                obj.hModeOverlay_.FontColor       = t.ToolbarFontColor;
                obj.hModeOverlay_.FontWeight      = 'normal';
            end
        end

        function onModeToggle_(obj, mode)
        %ONMODETOGGLE_ Switch composer mode and refresh button styling.
            try
                obj.ComposerMode_ = mode; obj.applyModeToggleStyles_();
            catch err
                uialert(obj.hFig_, err.message, 'FastSense Companion');
            end
        end

        function onChipDeselect_(obj, key)
        %ONCHIPDESELECT_ Deselect tag via catalog pane.
        %   deselectKey fires TagSelectionChanged -> orchestrator -> InspectorStateChanged
        %   -> setState rebuilds chip list (idempotent).
            try
                obj.CatalogPane_.deselectKey(key);
            catch ME
                uialert(obj.hFig_, sprintf('Failed to deselect tag: %s', ME.message), ...
                    'FastSense Companion', 'Icon', 'error');
            end
        end

        function onPlot_(obj)
        %ONPLOT_ Fire OpenAdHocPlotRequested on orchestrator (Phase 1022 listens).
        %   Phase 1021 boundary: event is fired only — no figure spawns here.
            try
                ed = AdHocPlotEventData(obj.CurrentTagKeys_, obj.ComposerMode_);
                notify(obj.Orchestrator_, 'OpenAdHocPlotRequested', ed);
            catch ME
                uialert(obj.hFig_, sprintf('Failed to request plot: %s', ME.message), ...
                    'FastSense Companion', 'Icon', 'error');
            end
        end

        function buildMetaRow_(obj, parentGrid, rowIdx, keyTxt, valTxt)
        %BUILDMETAROW_ Build a key/value metadata row inside parentGrid at rowIdx.
            t = obj.Theme_;
            % Coerce non-char values defensively (handles strings, numbers).
            try
                if isstring(valTxt) && isscalar(valTxt); valTxt = char(valTxt);
                elseif ~ischar(valTxt) && ~isstring(valTxt)
                    valTxt = sprintf('%s', valTxt);
                end
            catch
                valTxt = char(8212);
            end
            hr = uigridlayout(parentGrid, [1 2]);
            hr.Layout.Row = rowIdx; hr.Layout.Column = 1;
            hr.ColumnWidth = {80, '1x'}; hr.RowHeight = {'1x'};
            hr.Padding = [0 0 0 0]; hr.ColumnSpacing = 4; hr.BackgroundColor = t.WidgetBackground;
            lk = uilabel(hr); lk.Layout.Row = 1; lk.Layout.Column = 1;
            lk.Text = char(keyTxt); lk.FontSize = 11; lk.FontWeight = 'bold';
            lk.FontColor = t.PlaceholderTextColor; lk.HorizontalAlignment = 'left';
            lk.VerticalAlignment = 'center';
            lv = uilabel(hr); lv.Layout.Row = 1; lv.Layout.Column = 2;
            lv.Text = valTxt; lv.FontSize = 11; lv.FontColor = t.ForegroundColor;
            lv.HorizontalAlignment = 'left'; lv.VerticalAlignment = 'center';
            lv.WordWrap = 'on';
            lv.Tooltip = valTxt;  % full value visible on hover even if visually clipped
        end

    end
end
