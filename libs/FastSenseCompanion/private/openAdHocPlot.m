function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)
%OPENADHOCPLOT Spawn an ad-hoc multi-tag plot as a live DashboardEngine.
%   [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)
%
%   Replaces the classical-figure path: every "Plot" click in the
%   companion now spawns a fresh DashboardEngine with live refresh
%   running. Mode controls layout:
%     - 'Overlay'    — ONE RawAxesWidget; every tag drawn as an overlaid
%                       line in a single axes. Live tick re-runs the
%                       PlotFcn so lines update in place.
%     - 'LinkedGrid' — ONE FastSenseWidget per tag tiled in a 2-column
%                       grid. Each widget has ShowEventMarkers=true and,
%                       when the tag has a matching MonitorTag in the
%                       registry, the monitor's EventStore is forwarded
%                       so threshold events overlay on the plot.
%
%   Inputs:
%     tags         - 1xN cell of Tag handles (already resolved by caller).
%                    Must contain >= 1 entry.
%     mode         - char: 'Overlay' or 'LinkedGrid'.
%                    When numel(tags) == 1 the mode is coerced to
%                    'LinkedGrid' regardless of caller value (Overlay is
%                    only meaningful for >=2 tags).
%     themePreset  - char: 'dark' or 'light'.
%
%   Outputs:
%     hFig         - DashboardEngine.hFigure (figure window the engine owns)
%     skippedNames - 1xM cellstr of skipped tag names (may be empty).
%
%   Errors:
%     FastSenseCompanion:invalidPlotMode  - mode unknown or numel(tags)<1
%     FastSenseCompanion:plotSpawnFailed  - all tags failed; no figure spawned
%
%   Lifecycle: the engine starts its own live timer. The figure's
%   CloseRequestFcn stops live + deletes the figure so closing the
%   window cleans up.
%
%   See also DashboardEngine, FastSenseWidget, RawAxesWidget,
%            FastSenseCompanion, TagRegistry.

    validModes = {'Overlay', 'LinkedGrid'};
    if ~ischar(mode) || ~any(strcmp(mode, validModes))
        error('FastSenseCompanion:invalidPlotMode', ...
            'openAdHocPlot: mode must be one of: %s. Got: ''%s''.', ...
            strjoin(validModes, ', '), char(mode));
    end
    if ~iscell(tags) || numel(tags) < 1
        error('FastSenseCompanion:invalidPlotMode', ...
            'openAdHocPlot: requires a cell of >= 1 tag. Got %d.', numel(tags));
    end

    % Coerce mode for single-tag case: Overlay only meaningful for >=2 tags.
    if numel(tags) == 1 && strcmp(mode, 'Overlay')
        mode = 'LinkedGrid';
    end

    % Filter tags that have data.
    validTags    = {};
    validNames   = {};
    skippedNames = {};
    for k = 1:numel(tags)
        tg = tags{k};
        try
            nm = tg.Name;
        catch
            nm = sprintf('<tag %d>', k);
        end
        try
            [t, ~] = tg.getXY();
            if isempty(t)
                skippedNames{end+1} = sprintf('%s (no data)', nm); %#ok<AGROW>
                continue;
            end
            validTags{end+1}  = tg;     %#ok<AGROW>
            validNames{end+1} = nm;     %#ok<AGROW>
        catch ME
            skippedNames{end+1} = sprintf('%s (%s)', nm, ME.message); %#ok<AGROW>
        end
    end
    if isempty(validTags)
        error('FastSenseCompanion:plotSpawnFailed', ...
            'openAdHocPlot: no tags produced data. Skipped: %s', ...
            strjoin(skippedNames, '; '));
    end

    figName = buildFigureName_(validNames);

    engine = DashboardEngine(figName, ...
        'Theme', themePreset, 'LiveInterval', 1.0);

    switch mode
        case 'Overlay'
            % One single widget: a RawAxesWidget that overlays every tag.
            % cla() runs in the widget's refresh, then PlotFcn redraws.
            engine.addWidget('rawaxes', ...
                'Title',    figName, ...
                'PlotFcn',  @(ax) plotOverlay_(ax, validTags, validNames), ...
                'Position', [1 1 24 12]);

        case 'LinkedGrid'
            N    = numel(validTags);
            cols = min(N, 2);
            rows = ceil(N / cols);
            unitW = max(1, floor(24 / cols));
            unitH = max(1, floor(12 / rows));
            for k = 1:N
                r = ceil(k / cols);
                c = mod(k - 1, cols) + 1;
                args = { ...
                    'Title',            char(validNames{k}), ...
                    'Tag',              validTags{k}, ...
                    'ShowEventMarkers', true, ...
                    'Position',         [(c-1)*unitW + 1, (r-1)*unitH + 1, unitW, unitH]};
                es = findEventStoreFor_(validTags{k});
                if ~isempty(es)
                    args = [args, {'EventStore', es}]; %#ok<AGROW>
                end
                engine.addWidget('fastsense', args{:});
            end
    end

    engine.render();
    engine.startLive();

    hFig = engine.hFigure;
    if ~isempty(hFig) && ishandle(hFig)
        set(hFig, 'CloseRequestFcn', @(s, ~) closeFcn_(s, engine));
    end
end

% --------------------------- helpers --------------------------------

function plotOverlay_(ax, tags, names)
%PLOTOVERLAY_ Draw every tag as a line in the same axes; called on every refresh.
    hold(ax, 'on');
    for k = 1:numel(tags)
        try
            [tv, y] = tags{k}.getXY();
            if isempty(tv); continue; end
            plot(ax, tv, y, 'DisplayName', char(names{k}), 'LineWidth', 1.2);
        catch
        end
    end
    hold(ax, 'off');
    try; legend(ax, 'show', 'Location', 'best'); catch; end
    grid(ax, 'on');
    xlabel(ax, 'Time');
end

function es = findEventStoreFor_(tag)
%FINDEVENTSTOREFOR_ Locate an EventStore via a MonitorTag whose Parent.Key matches.
%   Returns [] when no matching monitor or no EventStore is registered.
    es = [];
    try
        if ~isobject(tag) || ~isvalid(tag) || ~isprop(tag, 'Key'); return; end
        monitors = TagRegistry.find(@(tt) isa(tt, 'MonitorTag') ...
            && ~isempty(tt.Parent) && isprop(tt.Parent, 'Key') ...
            && strcmp(tt.Parent.Key, tag.Key));
        for k = 1:numel(monitors)
            m = monitors{k};
            if isprop(m, 'EventStore') && ~isempty(m.EventStore) && isvalid(m.EventStore)
                es = m.EventStore;
                return;
            end
        end
    catch
    end
end

function closeFcn_(fig, engine)
%CLOSEFCN_ Stop live + delete figure on close.
    try
        if ~isempty(engine) && isvalid(engine) && ismethod(engine, 'stopLive')
            engine.stopLive();
        end
    catch
    end
    try; delete(fig); catch; end
end

function name = buildFigureName_(tagNames)
%BUILDFIGURENAME_ Compose figure title with 80-char total truncation.
    prefix   = 'FastSense Companion — ';
    maxTotal = 80;
    joined   = strjoin(tagNames, ', ');
    full     = [prefix, joined];
    if numel(full) <= maxTotal
        name = full;
        return;
    end
    budget = maxTotal - numel(prefix) - 1;
    if budget < 1
        name = [prefix, char(8230)];
        return;
    end
    cut = joined(1:min(budget, numel(joined)));
    lastSep = max(strfind(cut, ', '));
    if ~isempty(lastSep) && lastSep > 1
        cut = cut(1:lastSep-1);
    end
    name = [prefix, cut, char(8230)];
end
