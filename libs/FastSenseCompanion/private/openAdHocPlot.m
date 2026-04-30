function [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)
%OPENADHOCPLOT Spawn an ad-hoc multi-tag plot figure (Overlay or LinkedGrid).
%   [hFig, skippedNames] = openAdHocPlot(tags, mode, themePreset)
%
%   Inputs:
%     tags         - 1xN cell of Tag handles (already resolved by caller).
%                    Must contain >= 2 entries.
%     mode         - char: 'Overlay' or 'LinkedGrid'.
%     themePreset  - char: 'dark' or 'light' (passed verbatim to FastSense).
%
%   Outputs:
%     hFig         - classical figure() handle (Overlay: explicit figure();
%                    LinkedGrid: FastSenseGrid.hFigure).
%     skippedNames - 1xM cellstr of skipped tag names (may be empty).
%
%   Errors:
%     FastSenseCompanion:invalidPlotMode  - mode unknown or numel(tags)<2
%     FastSenseCompanion:plotSpawnFailed  - all tags failed; no figure spawned
%
%   Lifecycle: no companion state, no Listeners_, no timers (ADHOC-04/05).
%   LinkGroup wiring across LinkedGrid tiles deferred to ADHOC-08.
%   See also FastSense, FastSenseGrid, FastSenseCompanion.

    % Mode validation — fail fast before any side effects
    validModes = {'Overlay', 'LinkedGrid'};
    if ~ischar(mode) || ~any(strcmp(mode, validModes))
        error('FastSenseCompanion:invalidPlotMode', ...
            'openAdHocPlot: mode must be one of: %s. Got: ''%s''.', ...
            strjoin(validModes, ', '), char(mode));
    end

    % Tag count guard
    if ~iscell(tags) || numel(tags) < 2
        error('FastSenseCompanion:invalidPlotMode', ...
            'openAdHocPlot: requires a cell of >= 2 tags. Got %d.', numel(tags));
    end

    % Per-tag fetch with failure tolerance — collect BEFORE creating any figure
    % so the all-fail path produces no orphan figure.
    validTags    = {};
    validData    = {};   % parallel cell of struct('t', ..., 'y', ...)
    validNames   = {};
    skippedNames = {};
    for k = 1:numel(tags)
        tg = tags{k};
        nm = '';
        try
            nm = tg.Name;
        catch
            nm = sprintf('<tag %d>', k);
        end
        try
            [t, y] = tg.getXY();
            if isempty(t) || isempty(y)
                skippedNames{end+1} = sprintf('%s (no data)', nm); %#ok<AGROW>
                continue;
            end
            validTags{end+1}  = tg;                         %#ok<AGROW>
            validData{end+1}  = struct('t', t, 'y', y);     %#ok<AGROW>
            validNames{end+1} = nm;                         %#ok<AGROW>
        catch ME
            skippedNames{end+1} = sprintf('%s (%s)', nm, ME.message); %#ok<AGROW>
        end
    end

    % All-fail guard — error BEFORE creating any figure
    if isempty(validTags)
        error('FastSenseCompanion:plotSpawnFailed', ...
            'openAdHocPlot: no tags produced data. Skipped: %s', ...
            strjoin(skippedNames, '; '));
    end

    figName = buildFigureName_(validNames);

    switch mode
        case 'Overlay'
            hFig = figure('Name', figName, 'NumberTitle', 'off', ...
                          'Visible', 'off');
            ax = axes('Parent', hFig);
            fs = FastSense('Parent', ax, 'Theme', themePreset);
            for k = 1:numel(validTags)
                d = validData{k};
                fs.addLine(d.t, d.y, 'DisplayName', validNames{k});
            end
            fs.render();
            hFig.Visible = 'on';

        case 'LinkedGrid'
            N    = numel(validTags);
            rows = ceil(sqrt(N));
            cols = ceil(N / rows);
            % LinkGroup wiring deferred to ADHOC-08; each tile uses own x-axis.
            grid = FastSenseGrid(rows, cols, 'Theme', themePreset, ...
                                 'Name', figName, 'NumberTitle', 'off');
            for k = 1:N
                d = validData{k};
                grid.tile(k).addLine(d.t, d.y, 'DisplayName', validNames{k});
            end
            grid.render();   % FastSenseGrid.render() sets hFigure Visible='on'
            hFig = grid.hFigure;
    end

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
    budget = maxTotal - numel(prefix) - 1;   % 1 char for ellipsis char(8230)
    if budget < 1
        name = [prefix, char(8230)];
        return;
    end
    cut = joined(1:min(budget, numel(joined)));
    lastSep = max(strfind(cut, ', '));   % prefer cut at last ', ' boundary
    if ~isempty(lastSep) && lastSep > 1
        cut = cut(1:lastSep-1);
    end
    name = [prefix, cut, char(8230)];
end
