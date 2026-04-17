function absPath = captureDashboard(target, filepath, varargin)
%CAPTUREDASHBOARD Programmatic screenshot of a DashboardEngine or widget.
%
%   absPath = captureDashboard(target, filepath)
%   absPath = captureDashboard(target, filepath, 'Widget', wOrTitle)
%   absPath = captureDashboard(..., 'Resolution', 150)
%   absPath = captureDashboard(..., 'BackgroundColor', [1 1 1])
%
%   Writes the rendered dashboard (or a specific widget panel) to a PNG file
%   and returns the absolute path to the written file. Designed for
%   agentic UI inspection (matlab-mcp workflows): an AI agent can build a
%   DashboardEngine, call captureDashboard, and then Read the returned
%   path via its file system tool to visually verify the rendered layout.
%
%   Inputs:
%     target   - DashboardEngine instance, OR a figure handle
%                (numeric or matlab.ui.Figure).
%     filepath - char/string output path. Relative paths are resolved
%                against pwd. Parent directory must already exist.
%
%   Name-value options:
%     'Widget'          DashboardWidget handle OR widget Title (char).
%                       Default [] captures the entire dashboard figure.
%                       When the named widget is currently detached (a
%                       DetachedMirror exists for it), its standalone
%                       figure window is captured instead.
%     'Resolution'      Integer DPI. Default 150.
%     'BackgroundColor' RGB triplet or 'none'. Default = current figure
%                       Color; if provided, temporarily overrides the
%                       figure Color and restores it via onCleanup.
%
%   Output:
%     absPath  - absolute char path to the written PNG.
%
%   Behaviour cases:
%     A. Engine + no Widget         : capture target.hFigure.
%     B. Figure handle + no Widget  : capture that figure directly.
%     C. Engine + 'Widget' embedded :
%          - MATLAB : capture just the widget's uipanel via
%                     exportgraphics(uipanel, ...).
%          - Octave : capture the whole dashboard figure. Octave's print()
%                     does not recurse into uipanels, so cropping to a
%                     single widget panel is not supported in v1 — the
%                     whole figure is returned instead. Documented caveat.
%     D. Engine + 'Widget' detached : capture the DetachedMirror.hFigure.
%
%   Errors (all namespaced):
%     captureDashboard:invalidTarget  - target not Engine or figure
%     captureDashboard:notRendered    - engine.hFigure empty/invalid
%     captureDashboard:widgetNotFound - 'Widget' matches no widget
%     captureDashboard:unknownOption  - unrecognised name-value key
%     captureDashboard:writeFailed    - backend raised an error (wraps it)
%
%   Backend dispatch (mirrors DashboardEngine.exportImage):
%     * MATLAB R2024a+       : exportapp(hFig, path) for whole-figure
%                              capture; exportgraphics(uipanel, ...) for
%                              single-widget capture.
%     * MATLAB R2020a-R2023b : exportgraphics(target, path, ...).
%     * Octave               : print(hFig, '-dpng', '-r<dpi>', path) with
%                              stub-axes insertion when no top-level axes.
%
%   See also: DashboardEngine, DashboardEngine.exportImage, DetachedMirror.

    % 1. Positional arg validation -------------------------------------------
    if nargin < 2
        error('captureDashboard:invalidTarget', ...
            'captureDashboard requires at least (target, filepath).');
    end
    if ~(ischar(filepath) || (isstring(filepath) && isscalar(filepath)))
        error('captureDashboard:invalidTarget', ...
            'filepath must be a char or scalar string.');
    end
    filepath = char(filepath);
    if isempty(filepath)
        error('captureDashboard:invalidTarget', ...
            'filepath must be non-empty.');
    end

    % 2. Name-value parsing --------------------------------------------------
    opts = struct('Widget', [], 'Resolution', 150, 'BackgroundColor', []);
    validKeys = {'Widget', 'Resolution', 'BackgroundColor'};
    if mod(numel(varargin), 2) ~= 0
        error('captureDashboard:unknownOption', ...
            'Name-value pairs must come in pairs.');
    end
    for k = 1:2:numel(varargin)
        key = varargin{k};
        if ~ischar(key) && ~(isstring(key) && isscalar(key))
            error('captureDashboard:unknownOption', ...
                'Option name at position %d must be a char or string.', k);
        end
        key = char(key);
        if ~any(strcmp(key, validKeys))
            error('captureDashboard:unknownOption', ...
                'Unknown option ''%s''. Valid options: %s', ...
                key, strjoin(validKeys, ', '));
        end
        opts.(key) = varargin{k+1};
    end

    % 3. Resolve target -> (hFig, targetObj) ---------------------------------
    isOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;

    if isa(target, 'DashboardEngine')
        engine = target;
        if isempty(opts.Widget)
            if isempty(engine.hFigure) || ~ishandle(engine.hFigure)
                error('captureDashboard:notRendered', ...
                    'captureDashboard requires render() to have been called first.');
            end
            hFig = engine.hFigure;
            targetObj = hFig;
        else
            % Resolve widget reference -----------------------------------
            wRef = opts.Widget;
            resolvedWidget = [];
            if ischar(wRef) || (isstring(wRef) && isscalar(wRef))
                wTitle = char(wRef);
                resolvedWidget = engine.getWidgetByTitle(wTitle);
            elseif isa(wRef, 'DashboardWidget')
                resolvedWidget = wRef;
                wTitle = resolvedWidget.Title;
            else
                error('captureDashboard:widgetNotFound', ...
                    '''Widget'' must be a DashboardWidget handle or a Title string.');
            end

            % Check detached mirrors first ---------------------------------
            detachedHit = [];
            for i = 1:numel(engine.DetachedMirrors)
                mirror = engine.DetachedMirrors{i};
                if isempty(mirror) || mirror.isStale()
                    continue;
                end
                % Identity match on widget handle first, Title fallback
                match = false;
                if ~isempty(resolvedWidget) && ...
                        isa(mirror.Widget, 'DashboardWidget') && ...
                        isa(resolvedWidget, 'DashboardWidget')
                    % Handle identity (safe for live original widgets) or
                    % Title equality (the clone has the same Title).
                    try
                        if mirror.Widget == resolvedWidget
                            match = true;
                        end
                    catch
                        % == may error on cloned vs original; fall through
                    end
                end
                if ~match && ~isempty(wTitle) && ...
                        isa(mirror.Widget, 'DashboardWidget') && ...
                        strcmp(mirror.Widget.Title, wTitle)
                    match = true;
                end
                if match
                    detachedHit = mirror;
                    break;
                end
            end

            if ~isempty(detachedHit)
                hFig = detachedHit.hFigure;
                targetObj = hFig;
            else
                % Embedded: need the widget to resolve to a panel in hFigure
                if isempty(resolvedWidget)
                    error('captureDashboard:widgetNotFound', ...
                        'No widget found matching Widget argument.');
                end
                if isempty(engine.hFigure) || ~ishandle(engine.hFigure)
                    error('captureDashboard:notRendered', ...
                        'captureDashboard requires render() to have been called first.');
                end
                hFig = engine.hFigure;
                if isOctave
                    % Octave: print() can't target a uipanel — whole figure
                    targetObj = hFig;
                else
                    % MATLAB: exportgraphics accepts a uipanel handle
                    if ~isempty(resolvedWidget.hPanel) && ishandle(resolvedWidget.hPanel)
                        targetObj = resolvedWidget.hPanel;
                    else
                        targetObj = hFig;
                    end
                end
            end
        end
    elseif isa(target, 'matlab.ui.Figure') || ...
            (isnumeric(target) && isscalar(target) && ishandle(target) && ...
             strcmp(get(target, 'type'), 'figure'))
        hFig = target;
        targetObj = hFig;
    else
        error('captureDashboard:invalidTarget', ...
            'target must be a DashboardEngine or a figure handle.');
    end

    % 4. BackgroundColor override (temporary) --------------------------------
    restoreBg = [];  %#ok<NASGU>
    if ~isempty(opts.BackgroundColor)
        savedColor = get(hFig, 'Color');
        set(hFig, 'Color', opts.BackgroundColor);
        restoreBg = onCleanup(@() safeSetColor(hFig, savedColor));
    end

    % 5. Resolve absolute path ------------------------------------------------
    isAbsPath = (numel(filepath) > 0 && (filepath(1) == '/' || filepath(1) == '\')) || ...
                (numel(filepath) > 1 && filepath(2) == ':');
    if isAbsPath
        absPath = filepath;
    else
        absPath = fullfile(pwd, filepath);
    end

    % Ensure parent directory exists (helpful error rather than silent mkdir)
    parentDir = fileparts(absPath);
    if ~isempty(parentDir) && ~exist(parentDir, 'dir')
        error('captureDashboard:writeFailed', ...
            'Parent directory does not exist: %s', parentDir);
    end

    % 6. Backend dispatch -----------------------------------------------------
    useExportApp      = ~isOctave && exist('exportapp') ~= 0;       %#ok<EXIST>
    useExportGraphics = ~isOctave && exist('exportgraphics') ~= 0;  %#ok<EXIST>

    stubAxes = [];
    try
        targetIsFigure = ishandle(targetObj) && strcmp(get(targetObj, 'type'), 'figure');
        targetIsPanel  = ishandle(targetObj) && strcmp(get(targetObj, 'type'), 'uipanel');
        if useExportApp && targetIsFigure
            % MATLAB R2024a+: exportapp handles UI-component figures.
            exportapp(hFig, absPath);
        elseif useExportApp && targetIsPanel
            % Widget-only path on MATLAB R2024a+: render the whole figure with
            % exportapp (robust across axes + uicontrols) and crop to the
            % panel's pixel bounds. exportgraphics(uipanel, ...) fails on
            % panels that contain only uicontrols (e.g. NumberWidget), so we
            % avoid that path entirely when exportapp is available.
            cropPanelViaExportApp(hFig, targetObj, absPath);
        elseif useExportGraphics
            % MATLAB R2020a-R2023b (no exportapp): exportgraphics handles
            % figures and axes-bearing panels. Panels containing only
            % uicontrols will fall to the catch branch below and be handled
            % via whole-figure fallback.
            exportgraphics(targetObj, absPath, ...
                'ContentType', 'image', 'Resolution', opts.Resolution);
        else
            % Octave path — stub-axes fallback for figures with no top-level axes.
            topLevelChildren = get(hFig, 'children');
            hasTopAxes = false;
            for k = 1:numel(topLevelChildren)
                if strcmp(get(topLevelChildren(k), 'type'), 'axes')
                    hasTopAxes = true;
                    break;
                end
            end
            if ~hasTopAxes
                stubAxes = axes('Parent', hFig, ...
                    'Units', 'pixels', 'Position', [0 0 1 1], ...
                    'Visible', 'off', 'HitTest', 'off');
            end
            print(hFig, '-dpng', sprintf('-r%d', opts.Resolution), absPath);
        end
        if ~isempty(stubAxes) && ishandle(stubAxes)
            delete(stubAxes);
        end
    catch ME
        if ~isempty(stubAxes) && ishandle(stubAxes)
            delete(stubAxes);
        end
        % Widget-only fallback: if exportgraphics(panel) failed (typically
        % "Figure must contain graphics" for uicontrol-only panels) and we
        % have exportapp, retry via whole-figure + crop.
        if targetIsPanel && useExportApp
            try
                cropPanelViaExportApp(hFig, targetObj, absPath);
                return;
            catch ME2
                error('captureDashboard:writeFailed', ...
                    'Failed to write image ''%s'': %s (fallback: %s)', ...
                    absPath, ME.message, ME2.message);
            end
        end
        error('captureDashboard:writeFailed', ...
            'Failed to write image ''%s'': %s', absPath, ME.message);
    end
end

function cropPanelViaExportApp(hFig, hPanel, absPath)
%CROPPANELVIAEXPORTAPP Render hFig via exportapp, then crop to hPanel's pixel bounds.
%   Writes the cropped image to absPath. Assumes exportapp is available.
%
%   Implementation notes:
%     * getpixelposition(hPanel, true) returns the panel's bounds in
%       figure-relative pixels by walking the parent chain — required
%       because dashboard widgets are nested uipanels inside a content panel.
%     * exportapp renders a slightly taller image than get(hFig,'Position')
%       reports (figure chrome such as the menubar is included in the
%       exported content). We horizontally scale by width ratio and shift
%       vertically by the height delta so panel bounds land in the
%       content area of the exported image.

    % Render full figure to a temp PNG
    tempPng = [tempname() '.png'];
    cleanupTmp = onCleanup(@() safeDelete(tempPng));
    exportapp(hFig, tempPng);

    img = imread(tempPng);  % H x W x 3 uint8
    imH = size(img, 1); imW = size(img, 2);

    % Figure size in pixels (client area, no OS window chrome)
    savedFigUnits = get(hFig, 'Units');
    restoreFigU = onCleanup(@() safeSetUnits(hFig, savedFigUnits));
    set(hFig, 'Units', 'pixels');
    figPos = get(hFig, 'Position');
    figW = figPos(3); figH = figPos(4);

    % Panel bounds in figure-relative pixels (handles nested parents)
    panelPos = getpixelposition(hPanel, true);  % [x y w h]
    px = panelPos(1); py = panelPos(2);
    pw = panelPos(3); ph = panelPos(4);

    % Horizontal scale: exportapp width matches figure width on this system,
    % but scale defensively in case of HiDPI on other platforms.
    sx = imW / figW;
    % Vertical: the exported image may be taller than the figure (extra
    % chrome rendered at the top). Compute the chrome offset and shift
    % the panel's top-edge row down by that amount.
    chromeTop = max(0, imH - figH);

    px = round(px * sx);  pw = round(pw * sx);
    py = round(py);       ph = round(ph);

    % MATLAB Position origin is bottom-left of the figure client area;
    % image rows index from top. The figure client spans image rows
    % (chromeTop + 1) ... imH, so a panel at figure-y = py has its TOP
    % row at chromeTop + (figH - (py + ph)) + 1.
    rowTop  = max(1,  chromeTop + (figH - (py + ph)) + 1);
    rowBot  = min(imH, chromeTop + (figH - py));
    colLeft = max(1,  px + 1);
    colRight = min(imW, px + pw);

    if rowBot <= rowTop || colRight <= colLeft
        error('captureDashboard:writeFailed', ...
            'Panel crop bounds degenerate (panel %dx%d at [%d %d], img %dx%d, figH=%d).', ...
            pw, ph, px, py, imW, imH, figH);
    end

    cropped = img(rowTop:rowBot, colLeft:colRight, :);
    imwrite(cropped, absPath);
end

function safeDelete(path)
%SAFEDELETE Best-effort temp-file cleanup.
    if ~isempty(path) && exist(path, 'file')
        try
            delete(path);
        catch
            % Ignore — temp file, will be cleaned by OS eventually
        end
    end
end

function safeSetUnits(h, units)
%SAFESETUNITS Restore Units, ignoring closed handles.
    if ~isempty(h) && ishandle(h)
        try
            set(h, 'Units', units);
        catch
            % Handle may have been closed during capture
        end
    end
end

function safeSetColor(hFig, color)
%SAFESETCOLOR Restore figure Color, ignoring invalid handles (onCleanup helper).
    if ~isempty(hFig) && ishandle(hFig)
        try
            set(hFig, 'Color', color);
        catch
            % Figure may have been closed during capture — harmless
        end
    end
end
