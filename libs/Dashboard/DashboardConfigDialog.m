classdef DashboardConfigDialog < handle
%DASHBOARDCONFIGDIALOG Config editor for a DashboardEngine.
%
%   Opens a figure listing every public DashboardEngine property with
%   an editable control. Apply writes values back to the engine and
%   propagates visible changes (figure title, theme re-render, live
%   timer restart). Close dismisses without additional changes.
%
%   Enum-like properties get a popup menu:
%     Theme         — {'light', 'dark'}
%     ProgressMode  — {'auto', 'on', 'off'}
%   Numeric properties get a numeric edit control. Everything else
%   gets a plain text edit.
%
%   Usage (usually invoked by the toolbar Config button):
%     dlg = DashboardConfigDialog(engine);
%     % ...user edits fields, clicks Apply/Close...

    properties (SetAccess = private)
        Engine      = []
        hFigure     = []
        PropSpecs   = {}
        hEditCtrls  = {}
    end

    methods
        function obj = DashboardConfigDialog(engine)
            obj.Engine = engine;
            obj.PropSpecs = obj.buildPropertySpecs();
            obj.buildUI();
        end

        function close(obj)
        %CLOSE Destroy the dialog figure.
            if ~isempty(obj.hFigure) && ishandle(obj.hFigure)
                delete(obj.hFigure);
            end
            obj.hFigure = [];
        end

        function apply(obj)
        %APPLY Write all control values back to the engine and propagate.
            oldTheme = obj.Engine.Theme;
            oldName  = obj.Engine.Name;
            oldLive  = obj.Engine.LiveInterval;

            for i = 1:numel(obj.PropSpecs)
                spec = obj.PropSpecs{i};
                h = obj.hEditCtrls{i};
                try
                    newVal = obj.readControl(h, spec);
                    obj.Engine.(spec.name) = newVal;
                catch ME
                    warndlg(sprintf('Could not set %s: %s', spec.name, ME.message), ...
                        'Dashboard Config');
                end
            end
            obj.propagateChanges(oldTheme, oldName, oldLive);
        end
    end

    methods (Access = private)
        function specs = buildPropertySpecs(obj)
        %BUILDPROPERTYSPECS Introspect engine for public props + pick editor types.
            eng = obj.Engine;
            specs = {};
            knownChoices = struct( ...
                'Theme',        {{{'light', 'dark'}}}, ...
                'ProgressMode', {{{'auto', 'on', 'off'}}});

            names = obj.discoverPublicPropertyNames(eng);
            for i = 1:numel(names)
                n = names{i};
                s = struct();
                s.name = n;
                cur = eng.(n);
                if isfield(knownChoices, n)
                    s.type = 'popup';
                    choicePair = knownChoices.(n);
                    s.choices = choicePair{1};
                elseif isnumeric(cur)
                    s.type = 'numeric';
                else
                    s.type = 'text';
                end
                specs{end+1} = s; %#ok<AGROW>
            end
        end

        function names = discoverPublicPropertyNames(obj, eng) %#ok<INUSL>
        %DISCOVERPUBLICPROPERTYNAMES Return list of public get+set, non-hidden props.
            names = {};
            % Try meta-introspection first; fall back to hardcoded list
            % if the runtime (e.g. some Octave builds) rejects it.
            try
                mc = metaclass(eng);
                pList = mc.PropertyList;
                for i = 1:numel(pList)
                    p = pList(i);
                    if ~(ischar(p.SetAccess) && strcmp(p.SetAccess, 'public'))
                        continue;
                    end
                    if ~(ischar(p.GetAccess) && strcmp(p.GetAccess, 'public'))
                        continue;
                    end
                    if p.Hidden
                        continue;
                    end
                    names{end+1} = p.Name; %#ok<AGROW>
                end
                if ~isempty(names)
                    return;
                end
            catch
                % fall through
            end
            % Fallback — the known public property set.
            fallback = {'Name', 'Theme', 'LiveInterval', 'InfoFile', 'ProgressMode'};
            for i = 1:numel(fallback)
                if isprop(eng, fallback{i})
                    names{end+1} = fallback{i}; %#ok<AGROW>
                end
            end
        end

        function buildUI(obj)
        %BUILDUI Create the dialog figure and populate it with controls.
            nProps  = numel(obj.PropSpecs);
            rowH    = 30;
            padding = 16;
            btnArea = 60;
            figH    = rowH * max(nProps, 1) + 2*padding + btnArea;
            figW    = 420;

            obj.hFigure = figure( ...
                'Name', sprintf('Config — %s', obj.safeName()), ...
                'NumberTitle', 'off', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none', ...
                'Units', 'pixels', ...
                'Position', [120 120 figW figH], ...
                'Resize', 'off', ...
                'CloseRequestFcn', @(~,~) obj.close());

            labelW = 140;
            ctrlX  = padding + labelW + 8;
            ctrlW  = figW - ctrlX - padding;
            y = figH - padding - rowH;
            for i = 1:nProps
                spec = obj.PropSpecs{i};
                uicontrol('Parent', obj.hFigure, ...
                    'Style', 'text', ...
                    'String', spec.name, ...
                    'Position', [padding, y+4, labelW, rowH-8], ...
                    'HorizontalAlignment', 'left');
                pos = [ctrlX, y+2, ctrlW, rowH-4];
                obj.hEditCtrls{i} = obj.createControl(spec, pos);
                y = y - rowH;
            end

            btnY = padding;
            btnW = 80;
            uicontrol('Parent', obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', 'Apply', ...
                'Position', [figW - padding - 2*btnW - 10, btnY, btnW, 30], ...
                'TooltipString', 'Apply changes to the dashboard', ...
                'Callback', @(~,~) obj.apply());
            uicontrol('Parent', obj.hFigure, ...
                'Style', 'pushbutton', ...
                'String', 'Close', ...
                'Position', [figW - padding - btnW, btnY, btnW, 30], ...
                'TooltipString', 'Close this dialog without further changes', ...
                'Callback', @(~,~) obj.close());
        end

        function h = createControl(obj, spec, pos)
            eng = obj.Engine;
            cur = eng.(spec.name);
            switch spec.type
                case 'popup'
                    choices = spec.choices;
                    idx = find(strcmp(choices, cur), 1);
                    if isempty(idx), idx = 1; end
                    h = uicontrol('Parent', obj.hFigure, ...
                        'Style', 'popupmenu', ...
                        'String', choices, ...
                        'Value', idx, ...
                        'Position', pos);
                case 'numeric'
                    if isempty(cur), txt = ''; else, txt = num2str(cur); end
                    h = uicontrol('Parent', obj.hFigure, ...
                        'Style', 'edit', ...
                        'String', txt, ...
                        'Position', pos, ...
                        'HorizontalAlignment', 'left');
                otherwise  % 'text'
                    if isempty(cur), cur = ''; end
                    h = uicontrol('Parent', obj.hFigure, ...
                        'Style', 'edit', ...
                        'String', cur, ...
                        'Position', pos, ...
                        'HorizontalAlignment', 'left');
            end
        end

        function v = readControl(obj, h, spec) %#ok<INUSL>
            switch spec.type
                case 'popup'
                    idx = get(h, 'Value');
                    v = spec.choices{idx};
                case 'numeric'
                    str = get(h, 'String');
                    v = str2double(str);
                    if isnan(v)
                        error('DashboardConfigDialog:invalidNumber', ...
                            '%s must be numeric (got %s)', spec.name, str);
                    end
                otherwise  % text
                    v = get(h, 'String');
            end
        end

        function propagateChanges(obj, oldTheme, oldName, oldLive)
        %PROPAGATECHANGES Reflect engine changes back into the live figure.
            eng = obj.Engine;

            % Name → figure title + toolbar title edit
            if ~strcmp(eng.Name, oldName)
                if ~isempty(eng.hFigure) && ishandle(eng.hFigure)
                    set(eng.hFigure, 'Name', eng.Name);
                end
                if ~isempty(eng.Toolbar) ...
                        && ~isempty(eng.Toolbar.hTitleText) ...
                        && ishandle(eng.Toolbar.hTitleText)
                    set(eng.Toolbar.hTitleText, 'String', eng.Name);
                end
            end

            % Theme → invalidate cache, restyle chrome, rerender widgets
            if ~strcmp(eng.Theme, oldTheme)
                if ~isempty(eng.hFigure) && ishandle(eng.hFigure)
                    eng.ThemeCache_ = [];
                    theme = eng.getCachedTheme();
                    set(eng.hFigure, 'Color', theme.DashboardBackground);
                    if ~isempty(eng.Toolbar)
                        if ~isempty(eng.Toolbar.hPanel) ...
                                && ishandle(eng.Toolbar.hPanel)
                            set(eng.Toolbar.hPanel, ...
                                'BackgroundColor', theme.ToolbarBackground);
                        end
                        if ~isempty(eng.Toolbar.hTitleText) ...
                                && ishandle(eng.Toolbar.hTitleText)
                            set(eng.Toolbar.hTitleText, ...
                                'BackgroundColor', theme.ToolbarBackground, ...
                                'ForegroundColor', theme.ToolbarFontColor);
                        end
                    end
                    try
                        eng.rerenderWidgets();
                    catch
                        % rerender may require an active layout; ignore if not.
                    end
                end
            end

            % LiveInterval changed while live is running → restart to pick up
            if eng.IsLive && eng.LiveInterval ~= oldLive
                eng.stopLive();
                eng.startLive();
            end
        end

        function s = safeName(obj)
            s = obj.Engine.Name;
            if isempty(s), s = 'Dashboard'; end
        end
    end
end
