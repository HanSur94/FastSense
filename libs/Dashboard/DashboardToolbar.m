classdef DashboardToolbar < handle
%DASHBOARDTOOLBAR Global toolbar for dashboard controls.
%
%   Provides buttons for: Live mode toggle, Edit mode, Save, Image, Export.
%   Sits at the top of the dashboard figure.

    properties (Access = public)
        Height = 0.04
    end

    properties (SetAccess = private)
        hPanel       = []
        hLiveBtn     = []
        hEditBtn     = []
        hSaveBtn     = []
        hExportBtn   = []
        hImageBtn    = []
        hSyncBtn     = []
        hTitleText   = []
        hLastUpdate  = []
        hInfoBtn     = []
        Engine       = []
    end

    methods
        function obj = DashboardToolbar(engine, hFigure, theme)
            obj.Engine = engine;

            obj.hPanel = uipanel('Parent', hFigure, ...
                'Units', 'normalized', ...
                'Position', [0, 1 - obj.Height, 1, obj.Height], ...
                'BorderType', 'none', ...
                'BackgroundColor', theme.ToolbarBackground);

            obj.hTitleText = uicontrol('Parent', obj.hPanel, ...
                'Style', 'edit', ...
                'Units', 'normalized', ...
                'Position', [0.01 0.1 0.3 0.8], ...
                'String', engine.Name, ...
                'FontSize', theme.HeaderFontSize, ...
                'FontWeight', 'bold', ...
                'ForegroundColor', theme.ToolbarFontColor, ...
                'BackgroundColor', theme.ToolbarBackground, ...
                'HorizontalAlignment', 'left', ...
                'Callback', @(src,~) obj.onNameEdit(src));

            btnW = 0.06;
            btnH = 0.7;
            btnY = 0.15;

            % Conditional Info button (only when InfoFile is set)
            if ~isempty(engine.InfoFile)
                % Shorten title to make room
                set(obj.hTitleText, 'Position', [0.01 0.1 0.27 0.8]);

                obj.hInfoBtn = uicontrol('Parent', obj.hPanel, ...
                    'Style', 'pushbutton', ...
                    'Units', 'normalized', ...
                    'Position', [0.29 btnY 0.05 btnH], ...
                    'String', 'Info', ...
                    'Callback', @(~,~) obj.onInfo());
            end

            rightEdge = 0.99;

            rightEdge = rightEdge - btnW - 0.005;
            obj.hExportBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Export', ...
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
                'Callback', @(~,~) obj.onSave());

            rightEdge = rightEdge - btnW - 0.005;
            obj.hEditBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'pushbutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Edit', ...
                'Callback', @(~,~) obj.onEdit());

            rightEdge = rightEdge - btnW - 0.005;
            obj.hLiveBtn = uicontrol('Parent', obj.hPanel, ...
                'Style', 'togglebutton', ...
                'Units', 'normalized', ...
                'Position', [rightEdge btnY btnW btnH], ...
                'String', 'Live', ...
                'Value', 0, ...
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
            if get(src, 'Value')
                obj.Engine.startLive();
            else
                obj.Engine.stopLive();
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

        function onEdit(obj)
            fp = obj.Engine.FilePath;
            if isempty(fp)
                warndlg('No source file associated with this dashboard. Save first or load from a file.', 'Edit');
                return;
            end
            if ~exist(fp, 'file')
                warndlg(sprintf('Source file not found: %s', fp), 'Edit');
                return;
            end
            edit(fp);
        end

        function contentArea = getContentArea(obj)
            timePanelH = obj.Engine.TimePanelHeight;
            contentArea = [0, timePanelH, 1, 1 - obj.Height - timePanelH];
        end
    end
end
