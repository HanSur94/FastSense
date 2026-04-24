classdef DashboardToolbar < handle
%DASHBOARDTOOLBAR Global toolbar for dashboard controls.
%
%   Provides buttons for: Sync, Live (toggle with blue border when active),
%   Save, Image, Export, and Info (always present — shows a placeholder
%   page when no InfoFile is configured). Every button has a descriptive
%   tooltip. Sits at the top of the dashboard figure.

    properties (Access = public)
        Height = 0.04
    end

    properties (SetAccess = private)
        hPanel       = []
        hLiveBtn     = []
        hLivePanel   = []
        hSaveBtn     = []
        hExportBtn   = []
        hImageBtn    = []
        hSyncBtn     = []
        hTitleText   = []
        hLastUpdate  = []
        hInfoBtn     = []
        Engine       = []
        Theme_       = []
    end

    methods
        function obj = DashboardToolbar(engine, hFigure, theme)
            obj.Engine = engine;
            obj.Theme_ = theme;

            obj.hPanel = uipanel('Parent', hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - obj.Height, 1, obj.Height], ...
                'BorderType', 'none', ...
                'BackgroundColor', theme.ToolbarBackground);

            % Title: always reserve room for the (now mandatory) Info button
            obj.hTitleText = uicontrol('Parent', obj.hPanel, ...
                'Style', 'edit', ...
                'Units', 'normalized', ...
                'Position', [0.01 0.1 0.27 0.8], ...
                'String', engine.Name, ...
                'FontSize', theme.HeaderFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left', ...
                'TooltipString', 'Dashboard name (click to edit)', ...
                'Callback', @(src,~) obj.onNameEdit(src));

            btnW = 0.06;
            btnH = 0.7;
            btnY = 0.15;

            % Mandatory Info button — opens linked info file or a placeholder page.
            obj.hInfoBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [0.29 btnY 0.05 btnH], ...
                'String', 'Info', ...
                'TooltipString', 'Show dashboard info page', ...
                'Callback', @(~,~) obj.onInfo());

            rightEdge = 0.99;

            rightEdge = rightEdge - btnW - 0.005;
            obj.hExportBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Export', ...
                'TooltipString', 'Export dashboard as MATLAB script (.m)', ...
                'Callback', @(~,~) obj.onExport());

            rightEdge = rightEdge - btnW - 0.005;
            obj.hImageBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Image', ...
                'TooltipString', 'Save dashboard as image (PNG/JPEG)', ...
                'Callback', @(~,~) obj.onImage());

            rightEdge = rightEdge - btnW - 0.005;
            obj.hSaveBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Save', ...
                'TooltipString', 'Save dashboard to JSON file', ...
                'Callback', @(~,~) obj.onSave());

            rightEdge = rightEdge - btnW - 0.005;
            % Wrap Live toggle in a thin panel so we can show a blue border when active.
            obj.hLivePanel = uipanel('Parent', obj.hPanel, ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'BorderType', 'line', ...
                'HighlightColor', theme.ToolbarBackground, ...
                'BorderWidth', 2, ...
                'BackgroundColor', theme.ToolbarBackground);
            obj.hLiveBtn = uicontrol('Parent', obj.hLivePanel, ...
                'Style', 'togglebutton', ...
                'Units', 'normalized', ...
                'Position', [0 0 1 1], ...
                'String', 'Live', ...
                'Value', 0, ...
                'TooltipString', 'Toggle live mode — auto-refresh widgets from data', ...
                'Callback', @(src,~) obj.onLiveToggle(src));

            rightEdge = rightEdge - btnW - 0.005;
            obj.hSyncBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Sync', ...
                'TooltipString', 'Reset all widgets to global time range', ...
                'Callback', @(~,~) obj.Engine.resetGlobalTime());

            % Last update timestamp label
            labelW = 0.12;
            obj.hLastUpdate = uicontrol('Parent', obj.hPanel, ...
                'Style', 'text', ...
                'Units', 'normalized', ...
                'Position', [rightEdge - labelW - 0.01, btnY, labelW, btnH], ...
                'String', 'Last update: —', ...
                'FontSize', 8, ...
                'ForegroundColor', theme.ToolbarFontColor * 0.6 + ...
                    theme.ToolbarBackground * 0.4, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'right');
        end

        function setLastUpdateTime(obj, t)
        %SETLASTUPDATETIME Update the last-update label with a timestamp.
            if ~isempty(obj.hLastUpdate) && ishandle(obj.hLastUpdate)
                set(obj.hLastUpdate, 'String', ...
                    ['Last update: ' datestr(t, 'HH:MM:SS')]);
            end
        end

        function onNameEdit(obj, src)
            newName = get(src, 'String');
            obj.Engine.Name = newName;
            set(obj.Engine.hFigure, 'Name', newName);
        end

        function onLiveToggle(obj, src)
            isOn = logical(get(src, 'Value'));
            if isOn
                obj.Engine.startLive();
            else
                obj.Engine.stopLive();
            end
            obj.setLiveActiveIndicator(isOn);
        end

        function setLiveActiveIndicator(obj, isActive)
        %SETLIVEACTIVEINDICATOR Show a blue surround when live mode is active.
            if isempty(obj.hLivePanel) || ~ishandle(obj.hLivePanel)
                return;
            end
            if isActive
                set(obj.hLivePanel, 'HighlightColor', obj.Theme_.InfoColor);
            else
                set(obj.hLivePanel, 'HighlightColor', obj.Theme_.ToolbarBackground);
            end
        end

        function onSave(obj)
            [file, path] = uiputfile('*.json', 'Save Dashboard');
            if file ~= 0
                obj.Engine.save(fullfile(path, file));
            end
        end

        function onExport(obj)
            [file, path] = uiputfile('*.m', 'Export as Script');
            if file ~= 0
                obj.Engine.exportScript(fullfile(path, file));
            end
        end

        function onImage(obj)
        %ONIMAGE Open save dialog and export dashboard figure as PNG/JPEG.
        %   Pops a uiputfile with PNG+JPEG filters, defaults to the
        %   sanitized dashboard name plus timestamp. On cancel, returns
        %   silently. On engine error, surfaces message via warndlg.
            defName = obj.defaultImageFilename();
            [file, path, idx] = uiputfile( ...
                {'*.png', 'PNG image (*.png)'; ...
                 '*.jpg', 'JPEG image (*.jpg)'}, ...
                'Save Dashboard Image', ...
                defName);
            obj.dispatchImageExport(file, path, idx);
        end

        function dispatchImageExport(obj, file, path, idx)
        %DISPATCHIMAGEEXPORT Post-dialog dispatcher — testable without uiputfile.
        %   file  — filename string, or 0 on user-cancel
        %   path  — directory path from uiputfile
        %   idx   — filter index (1=PNG, 2=JPEG). Defaults to PNG.
            if isequal(file, 0) || isempty(file)
                return;  % user cancelled — silent no-op (IMG-07)
            end
            if nargin < 4 || isempty(idx) || idx == 1
                fmt = 'png';
            else
                fmt = 'jpeg';
            end
            try
                obj.Engine.exportImage(fullfile(path, file), fmt);
            catch ME
                warndlg(ME.message, 'Image Export');
            end
        end

        function fname = defaultImageFilename(obj)
        %DEFAULTIMAGEFILENAME Build sanitized default filename for the dialog.
        %   Pattern: {sanitized Engine.Name}_{yyyymmdd_HHMMSS}.png
        %   Sanitization: replace [/\:*?"<>|] and whitespace with '_'.
        %   NOTE: datestr format 'yyyymmdd_HHMMSS' (lowercase mm=month here,
        %   HHMMSS=seconds). This differs from datetime/ISO notation —
        %   see libs/EventDetection/generateEventSnapshot.m:28 for the
        %   in-codebase precedent.
            rawName = obj.Engine.Name;
            if isempty(rawName)
                rawName = 'Dashboard';
            end
            safeName = regexprep(rawName, '[/\\:*?"<>|\s]', '_');
            stamp = datestr(now, 'yyyymmdd_HHMMSS');
            fname = sprintf('%s_%s.png', safeName, stamp);
        end

        function onInfo(obj)
            obj.Engine.showInfo();
        end

        function contentArea = getContentArea(obj)
            timePanelH = obj.Engine.TimePanelHeight;
            contentArea = [0, timePanelH, 1, 1 - obj.Height - timePanelH];
        end
    end
end
