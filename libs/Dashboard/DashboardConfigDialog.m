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
            oldTheme      = obj.Engine.Theme;
            oldName       = obj.Engine.Name;
            oldLive       = obj.Engine.LiveInterval;
            oldShowTb     = obj.Engine.ShowToolbar;
            oldShowTp     = obj.Engine.ShowTimePanel;

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
            obj.propagateChanges(oldTheme, oldName, oldLive, oldShowTb, oldShowTp);
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
            tooltips = obj.tooltipMap();
            filePickerProps = {'InfoFile'};

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
                elseif islogical(cur) || (isnumeric(cur) && isscalar(cur) ...
                        && ismember(cur, [0 1]) && obj.isKnownBoolProp(n))
                    s.type = 'bool';
                elseif isnumeric(cur)
                    s.type = 'numeric';
                else
                    s.type = 'text';
                end
                if ismember(n, filePickerProps)
                    s.filePicker = true;
                    s.fileFilter = '*.md';
                else
                    s.filePicker = false;
                end
                if isfield(tooltips, n)
                    s.tooltip = tooltips.(n);
                else
                    s.tooltip = '';
                end
                specs{end+1} = s; %#ok<AGROW>
            end
        end

        function tf = isKnownBoolProp(obj, name) %#ok<INUSL>
        %ISKNOWNBOOLPROP True when the named property is a logical toggle we expose.
            tf = ismember(name, {'ShowToolbar', 'ShowTimePanel'});
        end

        function m = tooltipMap(obj) %#ok<MANU>
        %TOOLTIPMAP Explanations shown as tooltips on each config control.
            m = struct( ...
                'Name',          'Dashboard title shown in the window and toolbar.', ...
                'Theme',         'Color scheme preset. Apply re-themes the whole dashboard.', ...
                'LiveInterval',  'Seconds between live-mode refresh ticks.', ...
                'InfoFile',      'Path to a Markdown file opened by the Info button. Empty = built-in placeholder. Relative paths resolve against the loaded .json directory (or pwd if unsaved).', ...
                'ProgressMode',  'Render-progress bar visibility: ''auto'' = only for slow renders, ''on'' = always, ''off'' = never.', ...
                'ShowToolbar',   'Show the top toolbar. Uncheck for presenter or embed mode; the content area expands to fill.', ...
                'ShowTimePanel', 'Show the bottom time-slider panel. Uncheck when widgets manage their own time range.');
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
            tip = '';
            if isfield(spec, 'tooltip'), tip = spec.tooltip; end
            switch spec.type
                case 'popup'
                    choices = spec.choices;
                    idx = find(strcmp(choices, cur), 1);
                    if isempty(idx), idx = 1; end
                    h = uicontrol('Parent', obj.hFigure, ...
                        'Style', 'popupmenu', ...
                        'String', choices, ...
                        'Value', idx, ...
                        'Position', pos, ...
                        'TooltipString', tip);
                case 'numeric'
                    if isempty(cur), txt = ''; else, txt = num2str(cur); end
                    h = uicontrol('Parent', obj.hFigure, ...
                        'Style', 'edit', ...
                        'String', txt, ...
                        'Position', pos, ...
                        'HorizontalAlignment', 'left', ...
                        'TooltipString', tip);
                case 'bool'
                    h = uicontrol('Parent', obj.hFigure, ...
                        'Style', 'checkbox', ...
                        'String', '', ...
                        'Value', double(logical(cur)), ...
                        'Position', pos, ...
                        'TooltipString', tip);
                otherwise  % 'text' (optionally with a browse button)
                    if isempty(cur), cur = ''; end
                    hasPicker = isfield(spec, 'filePicker') && spec.filePicker;
                    if hasPicker
                        browseW = 70;
                        editPos = [pos(1), pos(2), pos(3) - browseW - 4, pos(4)];
                        browsePos = [pos(1) + editPos(3) + 4, pos(2), browseW, pos(4)];
                        h = uicontrol('Parent', obj.hFigure, ...
                            'Style', 'edit', ...
                            'String', cur, ...
                            'Position', editPos, ...
                            'HorizontalAlignment', 'left', ...
                            'TooltipString', tip);
                        uicontrol('Parent', obj.hFigure, ...
                            'Style', 'pushbutton', ...
                            'String', 'Browse…', ...
                            'Position', browsePos, ...
                            'TooltipString', sprintf('Pick a file for %s', spec.name), ...
                            'Callback', @(~,~) obj.onBrowseFor(h, spec));
                    else
                        h = uicontrol('Parent', obj.hFigure, ...
                            'Style', 'edit', ...
                            'String', cur, ...
                            'Position', pos, ...
                            'HorizontalAlignment', 'left', ...
                            'TooltipString', tip);
                    end
            end
        end

        function onBrowseFor(obj, hEdit, spec) %#ok<INUSL>
        %ONBROWSEFOR Pop a uigetfile dialog and write the result into hEdit.
            filter = '*.md';
            if isfield(spec, 'fileFilter') && ~isempty(spec.fileFilter)
                filter = spec.fileFilter;
            end
            [file, path] = uigetfile(filter, sprintf('Select %s', spec.name));
            if isequal(file, 0) || isempty(file)
                return;  % user cancelled
            end
            set(hEdit, 'String', fullfile(path, file));
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
                case 'bool'
                    v = logical(get(h, 'Value'));
                otherwise  % text
                    v = get(h, 'String');
            end
        end

        function propagateChanges(obj, oldTheme, oldName, oldLive, oldShowTb, oldShowTp)
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

            % Theme → restyle chrome, rerender widgets.
            % getCachedTheme() auto-invalidates when ThemeCachePreset_ != Theme,
            % so no manual cache clear is needed here.
            if ~strcmp(eng.Theme, oldTheme)
                if ~isempty(eng.hFigure) && ishandle(eng.hFigure)
                    eng.applyThemeToChrome();
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

            % Chrome visibility toggles → hide/show panels + re-layout widgets
            if ~isequal(logical(eng.ShowToolbar), logical(oldShowTb)) ...
                    || ~isequal(logical(eng.ShowTimePanel), logical(oldShowTp))
                eng.applyVisibilityAndRelayout();
            end
        end

        function s = safeName(obj)
            s = obj.Engine.Name;
            if isempty(s), s = 'Dashboard'; end
        end
    end
end
