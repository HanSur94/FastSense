classdef FastPlotToolbar < handle
    %FASTPLOTTOOLBAR Interactive toolbar for FastPlot and FastPlotFigure.
    %   Adds a uitoolbar with data cursor, crosshair, grid/legend toggles,
    %   Y-axis autoscale, PNG export, live mode controls, and metadata
    %   display. Integrates with MATLAB's built-in datacursormode for
    %   enhanced tooltips.
    %
    %   tb = FastPlotToolbar(fp)   — attach to a FastPlot instance
    %   tb = FastPlotToolbar(fig)  — attach to a FastPlotFigure instance
    %
    %   Toolbar buttons:
    %     Data Cursor  — click to snap to nearest data point, shows value
    %     Crosshair    — tracks mouse position with coordinate readout
    %     Grid         — toggle grid on/off (active axes or all)
    %     Legend        — toggle legend visibility
    %     Autoscale Y  — fit Y-axis to visible data range
    %     Export PNG   — save figure as PNG with file dialog
    %     Refresh      — manual one-shot data reload
    %     Live Mode    — toggle automatic file polling
    %     Metadata     — show/hide metadata in data cursor tooltips
    %
    %   See also FastPlot, FastPlotFigure, FastPlotDock.

    % ========================= PUBLIC STATE ==============================
    properties (SetAccess = private, GetAccess = public)
        MetadataEnabled = false  % whether metadata is shown in tooltips
    end

    % ====================== INTERNAL STATE ===============================
    % Graphics handles, mode tracking, and saved callbacks.
    properties (SetAccess = private)
        Target        = []    % FastPlot or FastPlotFigure
        hFigure       = []    % figure handle
        hToolbar      = []    % uitoolbar handle
        FastPlots     = {}    % cell array of all FastPlot instances
        Mode          = 'none'  % 'none' | 'cursor' | 'crosshair'
        hCursorBtn    = []    % uitoggletool handle
        hCrosshairBtn = []    % uitoggletool handle
        hCrosshairH   = []    % horizontal crosshair line
        hCrosshairV   = []    % vertical crosshair line
        hCrosshairTxt = []    % crosshair text annotation
        hCursorDot    = []    % data cursor marker
        hCursorTxt    = []    % data cursor text box
        SavedCallbacks = struct() % saved figure callbacks to restore
        hLiveBtn      = []    % uitoggletool handle for live mode
        hRefreshBtn   = []    % uipushtool handle for refresh
        hMetadataBtn  = []    % uitoggletool handle for metadata
        hThemeBtn     = []    % uipushtool handle for theme selector
    end

    methods (Access = public)
        function obj = FastPlotToolbar(target)
            %FASTPLOTTOOLBAR Construct and attach a toolbar to a plot target.
            %   tb = FastPlotToolbar(fp)   — FastPlot instance
            %   tb = FastPlotToolbar(fig)  — FastPlotFigure instance
            %
            %   Resolves the figure handle, collects all FastPlot instances,
            %   creates the uitoolbar, and installs the datacursor callback.
            obj.Target = target;

            % Resolve figure handle and FastPlot instances
            if isa(target, 'FastPlotFigure')
                obj.hFigure = target.hFigure;
                obj.FastPlots = {};
                for i = 1:numel(target.Tiles)
                    if ~isempty(target.Tiles{i})
                        obj.FastPlots{end+1} = target.Tiles{i};
                    end
                end
            elseif isa(target, 'FastPlot')
                obj.hFigure = target.hFigure;
                obj.FastPlots = {target};
            else
                error('FastPlotToolbar:invalidTarget', ...
                    'Target must be a FastPlot or FastPlotFigure instance.');
            end

            obj.createToolbar();
            obj.installDataCursorCallback();
        end

        function toggleGrid(obj)
            %TOGGLEGRID Toggle grid visibility on all managed axes.
            for i = 1:numel(obj.FastPlots)
                obj.toggleGridOnAxes(obj.FastPlots{i}.hAxes);
            end
        end

        function toggleLegend(obj)
            %TOGGLELEGEND Toggle legend visibility on all managed axes.
            for i = 1:numel(obj.FastPlots)
                obj.toggleLegendOnAxes(obj.FastPlots{i}.hAxes);
            end
        end

        function autoscaleY(obj)
            %AUTOSCALEY Fit Y-axis limits to visible data on all axes.
            for i = 1:numel(obj.FastPlots)
                obj.autoscaleYOnAxes(obj.FastPlots{i});
            end
        end

        function exportPNG(obj, filepath)
            %EXPORTPNG Save figure as PNG image at 150 DPI.
            %   tb.exportPNG()          — opens file dialog
            %   tb.exportPNG(filepath)  — saves directly to path
            if nargin < 2
                obj.onExportPNG();
                return;
            end
            print(obj.hFigure, '-dpng', '-r150', filepath);
        end

        function setCrosshair(obj, on)
            %SETCROSSHAIR Enable or disable crosshair tracking mode.
            %   tb.setCrosshair(true)  — activate crosshair, disable zoom
            %   tb.setCrosshair(false) — deactivate, re-enable zoom
            if on
                if strcmp(obj.Mode, 'cursor')
                    obj.cleanupCursor();
                    set(obj.hCursorBtn, 'State', 'off');
                end
                obj.Mode = 'crosshair';
                set(obj.hCrosshairBtn, 'State', 'on');
                try zoom(obj.hFigure, 'off'); catch; end
                obj.SavedCallbacks.WindowButtonMotionFcn = get(obj.hFigure, 'WindowButtonMotionFcn');
                obj.SavedCallbacks.WindowButtonDownFcn = get(obj.hFigure, 'WindowButtonDownFcn');
                set(obj.hFigure, 'WindowButtonMotionFcn', @(s,e) obj.onMouseMove());
                set(obj.hFigure, 'WindowButtonDownFcn', @(s,e) obj.onMouseClick());
            else
                obj.cleanupCrosshair();
                obj.Mode = 'none';
                set(obj.hCrosshairBtn, 'State', 'off');
                try zoom(obj.hFigure, 'on'); catch; end
            end
        end

        function setCursor(obj, on)
            %SETCURSOR Enable or disable data cursor snap mode.
            %   tb.setCursor(true)  — activate cursor, disable zoom
            %   tb.setCursor(false) — deactivate, re-enable zoom
            if on
                if strcmp(obj.Mode, 'crosshair')
                    obj.cleanupCrosshair();
                    set(obj.hCrosshairBtn, 'State', 'off');
                end
                obj.Mode = 'cursor';
                set(obj.hCursorBtn, 'State', 'on');
                try zoom(obj.hFigure, 'off'); catch; end
                obj.SavedCallbacks.WindowButtonDownFcn = get(obj.hFigure, 'WindowButtonDownFcn');
                set(obj.hFigure, 'WindowButtonDownFcn', @(s,e) obj.onMouseClick());
            else
                obj.cleanupCursor();
                obj.Mode = 'none';
                set(obj.hCursorBtn, 'State', 'off');
                try zoom(obj.hFigure, 'on'); catch; end
            end
        end

        function refresh(obj)
            %REFRESH Trigger a manual data refresh.
            obj.Target.refresh();
        end

        function toggleLive(obj)
            %TOGGLELIVE Toggle live mode on/off.
            target = obj.Target;

            if target.LiveIsActive
                target.stopLive();
                set(obj.hLiveBtn, 'State', 'off');
            else
                if ~isempty(target.LiveFile) && ~isempty(target.LiveUpdateFcn)
                    args = {'Interval', target.LiveInterval, ...
                            'ViewMode', target.LiveViewMode};
                    if ~isempty(target.MetadataFile)
                        args = [args, 'MetadataFile', target.MetadataFile];
                    end
                    if ~isempty(target.MetadataVars)
                        args = [args, 'MetadataVars', {target.MetadataVars}];
                    end
                    if isprop(target, 'MetadataLineIndex')
                        args = [args, 'MetadataLineIndex', target.MetadataLineIndex];
                    end
                    if isprop(target, 'MetadataTileIndex') && isa(target, 'FastPlotFigure')
                        args = [args, 'MetadataTileIndex', target.MetadataTileIndex];
                    end
                    target.startLive(target.LiveFile, target.LiveUpdateFcn, args{:});
                    set(obj.hLiveBtn, 'State', 'on');
                end
            end
        end

        function setMetadata(obj, on)
            %SETMETADATA Enable or disable metadata display in tooltips.
            %   tb.setMetadata(true)  — show metadata fields in cursor
            %   tb.setMetadata(false) — hide metadata
            obj.MetadataEnabled = on;
            setappdata(obj.hFigure, 'FastPlotMetadataEnabled', on);
            if on
                set(obj.hMetadataBtn, 'State', 'on');
            else
                set(obj.hMetadataBtn, 'State', 'off');
            end
            obj.refreshDataCursors();
        end

        function rebind(obj, target)
            %REBIND Switch toolbar to a new target without recreating HG objects.
            %   tb.rebind(newTarget)
            %
            %   Cleans up any active mode, updates the target and figure
            %   references, and syncs toggle button states.

            % Clean up active interactive mode
            if strcmp(obj.Mode, 'crosshair')
                obj.cleanupCrosshair();
            elseif strcmp(obj.Mode, 'cursor')
                obj.cleanupCursor();
            end
            obj.Mode = 'none';
            set(obj.hCursorBtn, 'State', 'off');
            set(obj.hCrosshairBtn, 'State', 'off');

            % Update target references
            obj.Target = target;
            if isa(target, 'FastPlotFigure')
                obj.hFigure = target.hFigure;
                obj.FastPlots = {};
                for i = 1:numel(target.Tiles)
                    if ~isempty(target.Tiles{i})
                        obj.FastPlots{end+1} = target.Tiles{i};
                    end
                end
            elseif isa(target, 'FastPlot')
                obj.hFigure = target.hFigure;
                obj.FastPlots = {target};
            end

            % Sync toggle states to new target
            if target.LiveIsActive
                set(obj.hLiveBtn, 'State', 'on');
            else
                set(obj.hLiveBtn, 'State', 'off');
            end
            setappdata(obj.hFigure, 'FastPlotMetadataEnabled', obj.MetadataEnabled);

            % Clear stale saved callbacks and reinstall datacursor
            obj.SavedCallbacks = struct();
            obj.installDataCursorCallback();
        end

        function label = buildCursorLabel(obj, fp, sx, sy, lineIdx)
            %BUILDCURSORLABEL Build the text label for data cursor.
            label = sprintf('(%.4g, %.4g)', sx, sy);
            if obj.MetadataEnabled && ~isempty(lineIdx)
                result = fp.lookupMetadata(lineIdx, sx);
                if ~isempty(result)
                    fields = fieldnames(result);
                    metaLines = {};
                    for i = 1:numel(fields)
                        val = result.(fields{i});
                        if isnumeric(val)
                            valStr = sprintf('%.4g', val);
                        else
                            valStr = char(val);
                        end
                        metaLines{end+1} = sprintf('%s: %s', fields{i}, valStr); %#ok<AGROW>
                    end
                    label = [label, char(10), '--------', char(10), strjoin(metaLines, char(10))];
                end
            end
        end

        function [sx, sy, lineIdx] = snapToNearest(~, fp, xClick, yClick)
            %SNAPTONEAREST Find the closest data point to a click position.
            %   [sx, sy, lineIdx] = tb.snapToNearest(fp, xClick, yClick)
            %
            %   Uses binary search on X and normalized distance metric to
            %   find the nearest point across all lines. Returns coordinates
            %   and line index of the closest match.
            sx = []; sy = []; lineIdx = [];
            bestDist = Inf;
            ax = fp.hAxes;
            xlims = get(ax, 'XLim');
            ylims = get(ax, 'YLim');
            xRange = xlims(2) - xlims(1);
            yRange = ylims(2) - ylims(1);
            if xRange == 0; xRange = 1; end
            if yRange == 0; yRange = 1; end
            for i = 1:numel(fp.Lines)
                xData = fp.Lines(i).X;
                yData = fp.Lines(i).Y;
                idx = binary_search(xData, xClick, 'left');
                idx = max(1, min(idx, numel(xData)));
                for j = max(1, idx-1):min(numel(xData), idx+1)
                    if isnan(yData(j)); continue; end
                    dx = (xData(j) - xClick) / xRange;
                    dy = (yData(j) - yClick) / yRange;
                    d = dx^2 + dy^2;
                    if d < bestDist
                        bestDist = d;
                        sx = xData(j);
                        sy = yData(j);
                        lineIdx = i;
                    end
                end
            end
        end
    end

    % ======================== PRIVATE METHODS ============================
    % Mouse event handlers, crosshair/cursor drawing, and cleanup.
    methods (Access = private)
        function createToolbar(obj)
            FastPlotToolbar.initIcons();
            obj.hToolbar = uitoolbar(obj.hFigure);

            % Buttons: cursor, crosshair, grid, legend, autoscale, export
            obj.hCursorBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('cursor'), ...
                'TooltipString', 'Data Cursor', ...
                'OnCallback',  @(s,e) obj.onCursorOn(), ...
                'OffCallback', @(s,e) obj.onCursorOff());

            obj.hCrosshairBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('crosshair'), ...
                'TooltipString', 'Crosshair', ...
                'OnCallback',  @(s,e) obj.onCrosshairOn(), ...
                'OffCallback', @(s,e) obj.onCrosshairOff());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('grid'), ...
                'TooltipString', 'Toggle Grid', ...
                'ClickedCallback', @(s,e) obj.onToggleGrid());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('legend'), ...
                'TooltipString', 'Toggle Legend', ...
                'ClickedCallback', @(s,e) obj.onToggleLegend());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('autoscale'), ...
                'TooltipString', 'Autoscale Y', ...
                'ClickedCallback', @(s,e) obj.onAutoscaleY());

            uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('export'), ...
                'TooltipString', 'Export PNG', ...
                'ClickedCallback', @(s,e) obj.onExportPNG());

            obj.hRefreshBtn = uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('refresh'), ...
                'TooltipString', 'Refresh Data', ...
                'ClickedCallback', @(s,e) obj.onRefresh());

            obj.hLiveBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('live'), ...
                'TooltipString', 'Live Mode', ...
                'OnCallback',  @(s,e) obj.onLiveOn(), ...
                'OffCallback', @(s,e) obj.onLiveOff());

            obj.hMetadataBtn = uitoggletool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('metadata'), ...
                'TooltipString', 'Metadata', ...
                'OnCallback',  @(s,e) obj.onMetadataOn(), ...
                'OffCallback', @(s,e) obj.onMetadataOff());

            obj.hThemeBtn = uipushtool(obj.hToolbar, ...
                'CData', FastPlotToolbar.makeIcon('theme'), ...
                'TooltipString', 'Change Theme', ...
                'ClickedCallback', @(s,e) obj.onThemeClick());
        end

        function onRefresh(obj)
            obj.refresh();
        end

        function onLiveOn(obj)
            obj.toggleLive();
        end

        function onLiveOff(obj)
            obj.toggleLive();
        end

        function onMetadataOn(obj)
            obj.setMetadata(true);
        end

        function onMetadataOff(obj)
            obj.setMetadata(false);
        end

        function onThemeClick(obj)
            %ONTHEMECLICK Open a popup with available themes.

            builtins = {'default', 'dark', 'light', 'industrial', 'scientific'};

            % Get custom themes
            cfg = getDefaults();
            if isfield(cfg, 'CustomThemes')
                customNames = fieldnames(cfg.CustomThemes);
            else
                customNames = {};
            end
            allNames = [builtins, customNames(:)'];

            % Determine current theme name for highlighting
            currentTheme = obj.getCurrentThemeName();
            currentIdx = find(strcmpi(allNames, currentTheme), 1);
            if isempty(currentIdx); currentIdx = 1; end

            % Build display labels (prefix active theme with a checkmark)
            labels = allNames;
            for i = 1:numel(labels)
                if i == currentIdx
                    labels{i} = [char(10003) ' ' labels{i}];  % ✓ prefix
                else
                    labels{i} = ['   ' labels{i}];
                end
            end
            % Add separator label before custom themes
            if ~isempty(customNames)
                sepIdx = numel(builtins) + 1;
                labels = [labels(1:sepIdx-1), {'───────────'}, labels(sepIdx:end)];
                allNames = [allNames(1:sepIdx-1), {''}, allNames(sepIdx:end)];
                % Adjust currentIdx if after separator
                if currentIdx >= sepIdx
                    currentIdx = currentIdx + 1;
                end
            end

            % Position popup near the toolbar button
            screenPos = get(0, 'PointerLocation');
            itemH = 22;  % pixels per list item
            listH = numel(labels) * itemH + 4;
            listW = 140;
            popupPos = [screenPos(1) - listW/2, screenPos(2) - listH, listW, listH];

            % Create popup figure
            hPopup = figure('MenuBar', 'none', 'ToolBar', 'none', ...
                'NumberTitle', 'off', 'Name', '', ...
                'Position', popupPos, 'Resize', 'off', ...
                'WindowStyle', 'modal', 'Color', [0.96 0.96 0.96]);

            % Create listbox
            hList = uicontrol(hPopup, 'Style', 'listbox', ...
                'String', labels, 'Value', currentIdx, ...
                'Units', 'normalized', 'Position', [0 0 1 1], ...
                'FontSize', 11, ...
                'Callback', @(s,e) onSelect(s));

            function onSelect(src)
                idx = get(src, 'Value');
                name = allNames{idx};
                if isempty(name)
                    return;  % separator clicked
                end
                delete(hPopup);
                obj.applyThemeByName(name);
            end
        end

        function name = getCurrentThemeName(obj)
            %GETCURRENTTHEMENAME Return the name of the current theme, or ''.
            name = '';
            target = obj.Target;
            if isa(target, 'FastPlotFigure') || isa(target, 'FastPlot')
                currentTheme = target.Theme;
            else
                return;
            end
            if isempty(currentTheme); return; end

            % Check built-in presets
            presets = {'default', 'dark', 'light', 'industrial', 'scientific'};
            for i = 1:numel(presets)
                ref = FastPlotTheme(presets{i});
                if obj.themesEqual(currentTheme, ref)
                    name = presets{i};
                    return;
                end
            end

            % Check custom themes
            cfg = getDefaults();
            if isfield(cfg, 'CustomThemes')
                customs = fieldnames(cfg.CustomThemes);
                for i = 1:numel(customs)
                    ref = mergeTheme(FastPlotTheme('default'), cfg.CustomThemes.(customs{i}));
                    if obj.themesEqual(currentTheme, ref)
                        name = customs{i};
                        return;
                    end
                end
            end
        end

        function eq = themesEqual(~, a, b)
            %THEMESEQUAL Compare two theme structs by key visual fields.
            eq = false;
            if ~isstruct(a) || ~isstruct(b); return; end
            fields = {'Background', 'AxesColor', 'ForegroundColor', 'GridColor', ...
                      'GridAlpha', 'GridStyle', 'FontName', 'FontSize'};
            for i = 1:numel(fields)
                f = fields{i};
                if ~isfield(a, f) || ~isfield(b, f); return; end
                if isnumeric(a.(f))
                    if ~isequal(round(a.(f)*1000), round(b.(f)*1000)); return; end
                else
                    if ~strcmp(a.(f), b.(f)); return; end
                end
            end
            eq = true;
        end

        function applyThemeByName(obj, name)
            %APPLYTHEMEBYNAME Resolve theme by name and apply to hierarchy.
            cfg = getDefaults();

            % Resolve: check custom themes first, then built-in
            if isfield(cfg, 'CustomThemes') && isfield(cfg.CustomThemes, name)
                newTheme = mergeTheme(FastPlotTheme('default'), cfg.CustomThemes.(name));
            else
                newTheme = FastPlotTheme(name);
            end

            target = obj.Target;
            if isa(target, 'FastPlotFigure')
                % Check if the figure belongs to a dock (via AppData)
                dock = getappdata(obj.hFigure, 'FastPlotDock');
                if ~isempty(dock) && isa(dock, 'FastPlotDock')
                    dock.Theme = newTheme;
                    dock.reapplyTheme();
                else
                    target.Theme = newTheme;
                    target.reapplyTheme();
                end
            elseif isa(target, 'FastPlot')
                target.Theme = newTheme;
                target.reapplyTheme();
            end
        end

        function onCursorOn(obj)
            obj.setCursor(true);
        end

        function onCursorOff(obj)
            obj.setCursor(false);
        end

        function onCrosshairOn(obj)
            obj.setCrosshair(true);
        end

        function onCrosshairOff(obj)
            obj.setCrosshair(false);
        end

        function onMouseMove(obj)
            if ~strcmp(obj.Mode, 'crosshair'); return; end
            [~, ax] = obj.getActiveTarget();
            if isempty(ax)
                obj.hideCrosshairLines();
                return;
            end
            cp = get(ax, 'CurrentPoint');
            xp = cp(1,1); yp = cp(1,2);
            xlims = get(ax, 'XLim');
            ylims = get(ax, 'YLim');
            if xp < xlims(1) || xp > xlims(2) || yp < ylims(1) || yp > ylims(2)
                obj.hideCrosshairLines();
                return;
            end
            if isempty(obj.hCrosshairH) || ~ishandle(obj.hCrosshairH)
                hold(ax, 'on');
                obj.hCrosshairH = line(xlims, [yp yp], 'Parent', ax, ...
                    'Color', [0.5 0.5 0.5], 'LineStyle', ':', ...
                    'HandleVisibility', 'off', 'HitTest', 'off');
                obj.hCrosshairV = line([xp xp], ylims, 'Parent', ax, ...
                    'Color', [0.5 0.5 0.5], 'LineStyle', ':', ...
                    'HandleVisibility', 'off', 'HitTest', 'off');
                obj.hCrosshairTxt = text(xlims(2), ylims(2), '', 'Parent', ax, ...
                    'FontSize', 8, 'HorizontalAlignment', 'right', ...
                    'VerticalAlignment', 'top', 'BackgroundColor', 'w', ...
                    'EdgeColor', [0.5 0.5 0.5], 'Margin', 2, ...
                    'HandleVisibility', 'off', 'HitTest', 'off');
            else
                set(obj.hCrosshairH, 'Parent', ax, 'XData', xlims, 'YData', [yp yp]);
                set(obj.hCrosshairV, 'Parent', ax, 'XData', [xp xp], 'YData', ylims);
                set(obj.hCrosshairTxt, 'Parent', ax, ...
                    'Position', [xlims(2), ylims(2), 0], ...
                    'String', sprintf('x=%.4g  y=%.4g', xp, yp));
            end
        end

        function onMouseClick(obj)
            % Double-click opens loupe regardless of mode
            if strcmp(get(obj.hFigure, 'SelectionType'), 'open')
                [fp, ~] = obj.getActiveTarget();
                if ~isempty(fp); fp.openLoupe(); end
                return;
            end
            if ~strcmp(obj.Mode, 'cursor'); return; end
            [fp, ax] = obj.getActiveTarget();
            if isempty(fp); return; end
            cp = get(ax, 'CurrentPoint');
            xp = cp(1,1); yp = cp(1,2);
            [sx, sy, lineIdx] = obj.snapToNearest(fp, xp, yp);
            if isempty(sx); return; end
            if ~isempty(obj.hCursorDot) && ishandle(obj.hCursorDot)
                delete(obj.hCursorDot);
                delete(obj.hCursorTxt);
            end
            hold(ax, 'on');
            lineColor = get(fp.Lines(lineIdx).hLine, 'Color');
            obj.hCursorDot = line(sx, sy, 'Parent', ax, ...
                'LineStyle', 'none', 'Marker', 'o', 'MarkerSize', 8, ...
                'Color', lineColor, 'MarkerFaceColor', lineColor, ...
                'HandleVisibility', 'off', 'HitTest', 'off');
            label = obj.buildCursorLabel(fp, sx, sy, lineIdx);
            obj.hCursorTxt = text(sx, sy, label, 'Parent', ax, ...
                'FontSize', 8, 'VerticalAlignment', 'bottom', ...
                'HorizontalAlignment', 'left', ...
                'BackgroundColor', 'w', 'EdgeColor', [0.5 0.5 0.5], ...
                'Margin', 3, 'HandleVisibility', 'off', 'HitTest', 'off');
        end

        function hideCrosshairLines(obj)
            if ~isempty(obj.hCrosshairH) && ishandle(obj.hCrosshairH)
                set(obj.hCrosshairH, 'Visible', 'off');
                set(obj.hCrosshairV, 'Visible', 'off');
                set(obj.hCrosshairTxt, 'Visible', 'off');
            end
        end

        function cleanupCrosshair(obj)
            if ~isempty(obj.hCrosshairH) && ishandle(obj.hCrosshairH)
                delete(obj.hCrosshairH);
                delete(obj.hCrosshairV);
                delete(obj.hCrosshairTxt);
            end
            obj.hCrosshairH = [];
            obj.hCrosshairV = [];
            obj.hCrosshairTxt = [];
            if isfield(obj.SavedCallbacks, 'WindowButtonMotionFcn')
                set(obj.hFigure, 'WindowButtonMotionFcn', obj.SavedCallbacks.WindowButtonMotionFcn);
            end
            if isfield(obj.SavedCallbacks, 'WindowButtonDownFcn')
                set(obj.hFigure, 'WindowButtonDownFcn', obj.SavedCallbacks.WindowButtonDownFcn);
            end
        end

        function cleanupCursor(obj)
            if ~isempty(obj.hCursorDot) && ishandle(obj.hCursorDot)
                delete(obj.hCursorDot);
                delete(obj.hCursorTxt);
            end
            obj.hCursorDot = [];
            obj.hCursorTxt = [];
            if isfield(obj.SavedCallbacks, 'WindowButtonDownFcn')
                set(obj.hFigure, 'WindowButtonDownFcn', obj.SavedCallbacks.WindowButtonDownFcn);
            end
        end

    end

    % ================ PRIVATE HELPERS (grid/legend/export) ===============
    methods (Access = private)
        function onToggleGrid(obj)
            [~, ax] = obj.getActiveTarget();
            if isempty(ax)
                for i = 1:numel(obj.FastPlots)
                    obj.toggleGridOnAxes(obj.FastPlots{i}.hAxes);
                end
            else
                obj.toggleGridOnAxes(ax);
            end
        end

        function toggleGridOnAxes(~, ax)
            if strcmp(get(ax, 'XGrid'), 'on')
                grid(ax, 'off');
            else
                grid(ax, 'on');
            end
        end

        function onToggleLegend(obj)
            [~, ax] = obj.getActiveTarget();
            if isempty(ax)
                for i = 1:numel(obj.FastPlots)
                    obj.toggleLegendOnAxes(obj.FastPlots{i}.hAxes);
                end
            else
                obj.toggleLegendOnAxes(ax);
            end
        end

        function toggleLegendOnAxes(~, ax)
            hLeg = legend(ax);
            if strcmp(get(hLeg, 'Visible'), 'on')
                set(hLeg, 'Visible', 'off');
            else
                set(hLeg, 'Visible', 'on');
            end
        end

        function onAutoscaleY(obj)
            [fp, ~] = obj.getActiveTarget();
            if isempty(fp)
                for i = 1:numel(obj.FastPlots)
                    obj.autoscaleYOnAxes(obj.FastPlots{i});
                end
            else
                obj.autoscaleYOnAxes(fp);
            end
        end

        function autoscaleYOnAxes(~, fp)
            ax = fp.hAxes;
            xlims = get(ax, 'XLim');
            ymin = Inf; ymax = -Inf;
            for i = 1:numel(fp.Lines)
                xData = fp.Lines(i).X;
                yData = fp.Lines(i).Y;
                idxStart = binary_search(xData, xlims(1), 'left');
                idxEnd   = binary_search(xData, xlims(2), 'right');
                idxStart = max(1, idxStart);
                idxEnd   = min(numel(xData), idxEnd);
                ySlice = yData(idxStart:idxEnd);
                ySlice = ySlice(~isnan(ySlice));
                if ~isempty(ySlice)
                    lo = min(ySlice);
                    hi = max(ySlice);
                    if lo < ymin; ymin = lo; end
                    if hi > ymax; ymax = hi; end
                end
            end
            if isfinite(ymin) && isfinite(ymax)
                yPad = (ymax - ymin) * 0.05;
                if yPad == 0; yPad = 1; end
                set(ax, 'YLim', [ymin - yPad, ymax + yPad]);
            end
        end

        function onExportPNG(obj)
            [fname, fpath] = uiputfile('*.png', 'Export as PNG');
            if isequal(fname, 0); return; end
            fullpath = fullfile(fpath, fname);
            obj.exportPNG(fullpath);
        end

        function [fp, ax] = getActiveTarget(obj)
            %GETACTIVETARGET Find the FastPlot instance under the mouse.
            fp = [];
            ax = [];
            cp = get(obj.hFigure, 'CurrentPoint');
            for i = 1:numel(obj.FastPlots)
                a = obj.FastPlots{i}.hAxes;
                if ~ishandle(a); continue; end
                oldUnits = get(a, 'Units');
                set(a, 'Units', 'pixels');
                pos = get(a, 'Position');
                set(a, 'Units', oldUnits);
                if cp(1) >= pos(1) && cp(1) <= pos(1)+pos(3) && ...
                   cp(2) >= pos(2) && cp(2) <= pos(2)+pos(4)
                    fp = obj.FastPlots{i};
                    ax = a;
                    return;
                end
            end
        end

        function installDataCursorCallback(obj)
            %INSTALLDATACURSORCALLBACK Set UpdateFcn on MATLAB datacursormode.
            try
                dcm = datacursormode(obj.hFigure);
                set(dcm, 'UpdateFcn', @(tip, evt) obj.dataCursorUpdateFcn(tip, evt));
            catch
                % Octave may not support datacursormode
            end
        end

        function refreshDataCursors(obj)
            %REFRESHDATACURSORS Force existing data tips to re-evaluate.
            try
                dcm = datacursormode(obj.hFigure);
                updateDataCursors(dcm);
            catch
            end
        end

        function txt = dataCursorUpdateFcn(obj, ~, evt)
            %DATACURSORUPDATEFCN Custom tooltip for MATLAB data cursor.
            try
                pos = get(evt, 'Position');
            catch
                pos = evt.Position;
            end
            xVal = pos(1);
            yVal = pos(2);

            % Find the line handle that was clicked
            try
                hTarget = get(evt, 'Target');
            catch
                hTarget = evt.Target;
            end

            % Look up which FastPlot and line index from the line's UserData
            fp = [];
            lineIdx = [];
            ud = get(hTarget, 'UserData');
            if isstruct(ud) && isfield(ud, 'FastPlot') && isfield(ud.FastPlot, 'LineIndex')
                lineIdx = ud.FastPlot.LineIndex;
            end
            if isstruct(ud) && isfield(ud, 'FastPlotInstance')
                fp = ud.FastPlotInstance;
            end

            % Format X value (datetime-aware)
            if ~isempty(fp) && fp.IsDatetime
                try
                    xStr = datestr(xVal);
                catch
                    xStr = sprintf('%.6g', xVal);
                end
            else
                xStr = sprintf('%.6g', xVal);
            end

            % Start with coordinate display
            txt = {sprintf('X: %s', xStr), sprintf('Y: %.6g', yVal)};

            % Add display name
            if ~isempty(fp) && ~isempty(lineIdx) && lineIdx <= numel(fp.Lines)
                if isfield(fp.Lines(lineIdx).Options, 'DisplayName')
                    txt = [{fp.Lines(lineIdx).Options.DisplayName}, txt];
                end
            end

            % Add metadata if available (use figure AppData for dock compatibility)
            metaOn = false;
            try
                hFig = ancestor(hTarget, 'figure');
                metaOn = getappdata(hFig, 'FastPlotMetadataEnabled');
            catch
            end
            if isempty(metaOn); metaOn = false; end
            if metaOn && ~isempty(fp) && ~isempty(lineIdx)
                % Use raw X for metadata lookup (downsampled point maps to raw range)
                result = fp.lookupMetadata(lineIdx, xVal);
                if ~isempty(result)
                    txt{end+1} = '--------';
                    fields = fieldnames(result);
                    for i = 1:numel(fields)
                        val = result.(fields{i});
                        if isnumeric(val)
                            valStr = sprintf('%.4g', val);
                        else
                            valStr = char(val);
                        end
                        txt{end+1} = sprintf('%s: %s', fields{i}, valStr); %#ok<AGROW>
                    end
                end
            end
        end
    end

    % ======================== STATIC METHODS =============================
    % Icon generation for toolbar buttons.
    methods (Static)
        function icon = makeIcon(name)
            %MAKEICON Generate a 16x16x3 RGB icon for toolbar buttons.
            %   icon = FastPlotToolbar.makeIcon(name)
            %
            %   Draws simple pixel-art icons on a light gray background.
            %   Available names: 'cursor', 'crosshair', 'grid', 'legend',
            %   'autoscale', 'export', 'refresh', 'live', 'metadata', 'theme'.
            persistent cache
            if isempty(cache)
                cache = containers.Map();
            end
            if cache.isKey(name)
                icon = cache(name);
                return
            end
            bg = 0.94;  % light gray background
            icon = ones(16, 16, 3) * bg;
            fg = [0.2 0.2 0.2];  % dark foreground

            switch name
                case 'cursor'
                    % Crosshair with center dot
                    icon(8, 3:13, :) = repmat(reshape(fg,1,1,3), 1, 11, 1);
                    icon(3:13, 8, :) = repmat(reshape(fg,1,1,3), 11, 1, 1);
                    for dr = -1:1
                        for dc = -1:1
                            icon(8+dr, 8+dc, :) = reshape(fg,1,1,3);
                        end
                    end

                case 'crosshair'
                    % Thin + cross
                    icon(8, 2:14, :) = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(2:14, 8, :) = repmat(reshape(fg,1,1,3), 13, 1, 1);

                case 'grid'
                    % Grid lines
                    icon(4, 2:14, :)  = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(8, 2:14, :)  = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(12, 2:14, :) = repmat(reshape(fg,1,1,3), 1, 13, 1);
                    icon(2:14, 4, :)  = repmat(reshape(fg,1,1,3), 13, 1, 1);
                    icon(2:14, 8, :)  = repmat(reshape(fg,1,1,3), 13, 1, 1);
                    icon(2:14, 12, :) = repmat(reshape(fg,1,1,3), 13, 1, 1);

                case 'legend'
                    % Box with lines
                    icon(3, 3:13, :)  = repmat(reshape(fg,1,1,3), 1, 11, 1);
                    icon(13, 3:13, :) = repmat(reshape(fg,1,1,3), 1, 11, 1);
                    icon(3:13, 3, :)  = repmat(reshape(fg,1,1,3), 11, 1, 1);
                    icon(3:13, 13, :) = repmat(reshape(fg,1,1,3), 11, 1, 1);
                    icon(6, 5:7, :)   = repmat(reshape([0.8 0.2 0.2],1,1,3), 1, 3, 1);
                    icon(6, 9:11, :)  = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(10, 5:7, :)  = repmat(reshape([0.2 0.2 0.8],1,1,3), 1, 3, 1);
                    icon(10, 9:11, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);

                case 'autoscale'
                    % Vertical double arrow
                    icon(2:14, 8, :) = repmat(reshape(fg,1,1,3), 13, 1, 1);
                    % Up arrow
                    icon(3, 7:9, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(4, 6:10, :) = repmat(reshape(fg,1,1,3), 1, 5, 1);
                    % Down arrow
                    icon(13, 7:9, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(12, 6:10, :) = repmat(reshape(fg,1,1,3), 1, 5, 1);

                case 'export'
                    % Camera shape
                    icon(5, 5:11, :)  = repmat(reshape(fg,1,1,3), 1, 7, 1);
                    icon(12, 4:12, :) = repmat(reshape(fg,1,1,3), 1, 9, 1);
                    icon(5:12, 4, :)  = repmat(reshape(fg,1,1,3), 8, 1, 1);
                    icon(5:12, 12, :) = repmat(reshape(fg,1,1,3), 8, 1, 1);
                    icon(4, 6:8, :)   = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    % Lens circle (approximate)
                    for r = [7 8 9]
                        for c = [7 8 9]
                            if (r-8)^2 + (c-8)^2 <= 2
                                icon(r, c, :) = reshape(fg,1,1,3);
                            end
                        end
                    end

                case 'refresh'
                    % Circular arrow
                    icon(4, 7:11, :) = repmat(reshape(fg,1,1,3), 1, 5, 1);
                    icon(12, 5:9, :) = repmat(reshape(fg,1,1,3), 1, 5, 1);
                    icon(5:7, 5, :)  = repmat(reshape(fg,1,1,3), 3, 1, 1);
                    icon(9:11, 11, :) = repmat(reshape(fg,1,1,3), 3, 1, 1);
                    icon(5, 6, :) = reshape(fg,1,1,3);
                    icon(11, 10, :) = reshape(fg,1,1,3);
                    % Arrow heads
                    icon(3, 11:13, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(4, 12, :) = reshape(fg,1,1,3);
                    icon(5, 13, :) = reshape(fg,1,1,3);
                    icon(13, 3:5, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(12, 4, :) = reshape(fg,1,1,3);
                    icon(11, 3, :) = reshape(fg,1,1,3);

                case 'live'
                    % Filled circle (recording dot)
                    for r = 5:11
                        for c = 5:11
                            if (r-8)^2 + (c-8)^2 <= 9
                                icon(r, c, :) = reshape([0.8 0.1 0.1],1,1,3);
                            end
                        end
                    end

                case 'metadata'
                    % "M" letter icon
                    icon(4:12, 3, :) = repmat(reshape(fg,1,1,3), 9, 1, 1);
                    icon(4:12, 13, :) = repmat(reshape(fg,1,1,3), 9, 1, 1);
                    icon(4, 4:5, :) = repmat(reshape(fg,1,1,3), 1, 2, 1);
                    icon(5, 5:6, :) = repmat(reshape(fg,1,1,3), 1, 2, 1);
                    icon(6, 6:7, :) = repmat(reshape(fg,1,1,3), 1, 2, 1);
                    icon(7, 7:9, :) = repmat(reshape(fg,1,1,3), 1, 3, 1);
                    icon(6, 9:10, :) = repmat(reshape(fg,1,1,3), 1, 2, 1);
                    icon(5, 10:11, :) = repmat(reshape(fg,1,1,3), 1, 2, 1);
                    icon(4, 11:12, :) = repmat(reshape(fg,1,1,3), 1, 2, 1);

                case 'theme'
                    % Paint palette shape
                    cx = 8; cy = 8;
                    for r = 3:13
                        for c = 3:13
                            dx = (c - cx) / 5.5;
                            dy = (r - cy) / 5;
                            d = dx^2 + dy^2;
                            if d <= 1.0 && d >= 0.72
                                icon(r, c, :) = reshape(fg, 1, 1, 3);
                            end
                        end
                    end
                    % Thumb hole
                    for r = 10:12
                        for c = 5:7
                            dx = (c - 6); dy = (r - 11);
                            if dx^2 + dy^2 <= 1.5
                                icon(r, c, :) = reshape([bg bg bg], 1, 1, 3);
                            end
                        end
                    end
                    % Paint dots (4 colors)
                    colors = {[0.85 0.2 0.2], [0.2 0.6 0.2], [0.2 0.3 0.85], [0.9 0.7 0.1]};
                    positions = {[5 8], [5 11], [7 12], [9 11]};
                    for i = 1:4
                        pr = positions{i}(1); pc = positions{i}(2);
                        clr = colors{i};
                        icon(pr, pc, :) = reshape(clr, 1, 1, 3);
                        icon(pr, pc+1, :) = reshape(clr, 1, 1, 3);
                        icon(pr+1, pc, :) = reshape(clr, 1, 1, 3);
                        icon(pr+1, pc+1, :) = reshape(clr, 1, 1, 3);
                    end
            end
            cache(name) = icon;
        end

        function initIcons()
            %INITICONS Pre-warm the icon cache for all toolbar buttons.
            names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', ...
                     'export', 'refresh', 'live', 'metadata', 'theme'};
            for i = 1:numel(names)
                FastPlotToolbar.makeIcon(names{i});
            end
        end
    end
end
