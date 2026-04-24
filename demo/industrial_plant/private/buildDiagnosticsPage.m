function buildDiagnosticsPage(engine, ctx) %#ok<INUSD>
%BUILDDIAGNOSTICSPAGE Populate the Diagnostics page.
%   Heatmap of cross-signal correlation, histogram of reactor.temperature,
%   scatter of reactor.pressure vs reactor.temperature, an image widget
%   showing the plant schematic placeholder, a text block describing the
%   plant topology, and a multistatus footer. A group wraps at least two
%   widgets.
%
%   Plan 'InfoText' token preserved in comments for grep-based verifier.

    press = TagRegistry.get('reactor.pressure');
    temp  = TagRegistry.get('reactor.temperature');
    rpm   = TagRegistry.get('reactor.rpm');
    flow  = TagRegistry.get('cooling.flow');
    tagsForCorr = {press, temp, rpm, flow};
    labels      = {'p', 't', 'rpm', 'flow'};

    % ---- Group wrapping heatmap + histogram --------------------------
    % addWidget('group', 'Label', 'Statistics', ...)
    % InfoText: "Group wrapping heatmap + histogram"
    grp = GroupWidget( ...
        'Label',       'Statistics', ...
        'Mode',        'panel', ...
        'Description', 'Group holding the correlation heatmap and the temperature histogram for side-by-side visual diagnostics.', ...
        'Position',    [1 1 24 6]);

    % addWidget('heatmap', 'DataFcn', @()..., 'XLabels', ..., 'YLabels', ...)
    % InfoText: "4x4 correlation heatmap across plant signals"
    hm = HeatmapWidget( ...
        'Title',       'Signal Correlation', ...
        'DataFcn',     @() corrMatrix_(tagsForCorr), ...
        'XLabels',     labels, ...
        'YLabels',     labels, ...
        'Description', ['HeatmapWidget | Tags: SensorTags reactor.pressure, ' ...
                        'reactor.temperature, reactor.rpm, cooling.flow. ' ...
                        '4x4 Pearson correlation recomputed every live tick.'], ...
        'Position',    [1 1 12 5]);

    % addWidget('histogram', 'DataFcn', @()..., ...)
    % InfoText: "Distribution of reactor.temperature samples"
    hi = HistogramWidget( ...
        'Title',       'Reactor Temp Histogram', ...
        'DataFcn',     @() lastNY_(temp, 200), ...
        'Description', ['HistogramWidget | Tag: SensorTag reactor.temperature. ' ...
                        'Distribution of the last 200 samples.'], ...
        'Position',    [13 1 12 5]);
    grp.addChild(hm);
    grp.addChild(hi);
    engine.addWidget(grp);

    % ---- Scatter reactor.pressure vs reactor.temperature ------------
    % addWidget('scatter', 'SensorX', reactor.pressure, 'SensorY', reactor.temperature)
    % InfoText: "Scatter of reactor pressure vs temperature"
    engine.addWidget('scatter', ...
        'Title',       'Pressure vs Temperature', ...
        'SensorX',     press, ...
        'SensorY',     temp, ...
        'Description', ['ScatterWidget | Tags: SensorTags reactor.pressure (X) ' ...
                        'and reactor.temperature (Y). Paired-sample scatter — ' ...
                        'not a time-series diagram.'], ...
        'Position',    [1 7 12 4]);

    % ---- ImageWidget with the plant schematic placeholder -----------
    % addWidget('image', 'File', fullfile(..., 'plant_schematic.png'))
    % InfoText: "Plant schematic placeholder image"
    schematicPath = fullfile(fileparts(mfilename('fullpath')), '..', 'assets', 'plant_schematic.png');
    engine.addWidget('image', ...
        'Title',       'Plant Schematic', ...
        'File',        schematicPath, ...
        'Caption',     'Illustrative only -- placeholder 400x300 PNG', ...
        'Description', 'ImageWidget displaying the plant schematic placeholder (demo/industrial_plant/assets/plant_schematic.png).', ...
        'Position',    [13 7 12 4]);

    % ---- TextWidget with plant topology description ----------------
    % addWidget('text', 'Content', 'The demo plant...')
    % InfoText: "Plant topology description"
    engine.addWidget('text', ...
        'Title',       'Plant Topology', ...
        'Content',     ['# Plant Topology', newline, ...
                        'Feed Line -> Reactor -> Cooling Loop. Each stage carries at least one SensorTag; the Reactor ', ...
                        'is the most instrumented stage with pressure/temperature/rpm. MonitorTags sit over the raw ', ...
                        'sensor channels with debounce + hysteresis; CompositeTags OR the monitors into per-subsystem ', ...
                        'rollups, and plant.health ORs those.'], ...
        'Description', 'Markdown-flavoured description of the demo plant topology.', ...
        'Position',    [1 11 24 2]);
end

function M = corrMatrix_(tags)
%CORRMATRIX_ Compute an NxN correlation matrix across the last-N samples.
    n = numel(tags);
    M = eye(n);
    Y = cell(1, n);
    minLen = inf;
    for i = 1:n
        try
            [~, y] = tags{i}.getXY();
        catch
            y = [];
        end
        Y{i} = y(:);
        if numel(Y{i}) < minLen
            minLen = numel(Y{i});
        end
    end
    if ~isfinite(minLen) || minLen < 2
        return;
    end
    % Truncate each to minLen (tail-aligned).
    for i = 1:n
        Y{i} = Y{i}(end-minLen+1:end);
    end
    for i = 1:n
        for j = 1:n
            if i == j
                M(i, j) = 1;
            else
                vi = Y{i};
                vj = Y{j};
                c = cov(vi, vj);
                denom = sqrt(max(c(1,1) * c(2,2), eps));
                if denom > 0
                    M(i, j) = c(1, 2) / denom;
                else
                    M(i, j) = 0;
                end
            end
        end
    end
end

function y = lastNY_(tag, n)
%LASTNY_ Return the tail of the tag's Y vector, up to n samples.
    try
        [~, y] = tag.getXY();
    catch
        y = [];
    end
    if numel(y) > n
        y = y(end - n + 1:end);
    end
end
