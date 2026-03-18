function files = generateEventSnapshot(event, sensorData, varargin)
    % generateEventSnapshot  Create two FastSense PNG snapshots for an event.
    %
    %   files = generateEventSnapshot(event, sensorData, ...)
    %
    %   Returns cell array {detailPath, contextPath}.
    %
    %   Options:
    %     OutputDir      — directory for PNGs (default: tempdir)
    %     SnapshotSize   — [width, height] pixels (default: [800, 400])
    %     Padding        — fraction of event duration for detail padding (default: 0.1)
    %     ContextHours   — hours before event for context plot (default: 2)

    p = inputParser();
    p.addParameter('OutputDir', tempdir, @ischar);
    p.addParameter('SnapshotSize', [800, 400], @isnumeric);
    p.addParameter('Padding', 0.1, @isnumeric);
    p.addParameter('ContextHours', 2, @isnumeric);
    p.parse(varargin{:});

    outDir   = p.Results.OutputDir;
    figSize  = p.Results.SnapshotSize;
    padding  = p.Results.Padding;
    ctxHours = p.Results.ContextHours;

    [~,~] = mkdir(outDir);  % idempotent — no error if exists

    stamp = datestr(event.StartTime, 'yyyymmdd_HHMMSS');
    baseName = sprintf('%s_%s_%s', event.SensorName, event.ThresholdLabel, stamp);

    detailFile  = fullfile(outDir, [baseName '_detail.png']);
    contextFile = fullfile(outDir, [baseName '_context.png']);

    X = sensorData.X;
    Y = sensorData.Y;
    thVal = sensorData.thresholdValue;
    thDir = sensorData.thresholdDirection;

    evStart = event.StartTime;
    evEnd   = event.EndTime;
    evDur   = evEnd - evStart;

    % --- Plot 1: Event Detail ---
    padAmount = max(evDur * padding, 30/86400);  % at least 30 seconds
    xMin1 = evStart - padAmount;
    xMax1 = evEnd + padAmount;
    renderSnapshot(X, Y, thVal, thDir, evStart, evEnd, xMin1, xMax1, ...
        figSize, detailFile, sprintf('%s — Event Detail', event.SensorName));

    % --- Plot 2: Event Context (2h before) ---
    xMin2 = evStart - ctxHours/24;
    xMax2 = evEnd + padAmount;
    renderSnapshot(X, Y, thVal, thDir, evStart, evEnd, xMin2, xMax2, ...
        figSize, contextFile, sprintf('%s — %dh Context', event.SensorName, ctxHours));

    files = {detailFile, contextFile};
end

function renderSnapshot(X, Y, thVal, thDir, evStart, evEnd, xMin, xMax, figSize, outFile, titleStr)
    fig = figure('Visible', 'off', 'Position', [100 100 figSize]);
    ax = axes(fig);

    % Clip data to view
    mask = X >= xMin & X <= xMax;
    if any(mask)
        plot(ax, X(mask), Y(mask), 'b-', 'LineWidth', 1);
    end
    hold(ax, 'on');

    % Shaded violation region
    yLims = get(ax, 'YLim');
    patch(ax, [evStart evEnd evEnd evStart], ...
        [yLims(1) yLims(1) yLims(2) yLims(2)], ...
        [1 0 0], 'FaceAlpha', 0.15, 'EdgeColor', 'none');

    % Threshold line
    line(ax, [xMin xMax], [thVal thVal], 'Color', [0.8 0 0], ...
        'LineStyle', '--', 'LineWidth', 1.5);

    % Violation markers
    vMask = mask;
    if strcmp(thDir, 'upper')
        vMask = vMask & Y > thVal;
    else
        vMask = vMask & Y < thVal;
    end
    if any(vMask)
        plot(ax, X(vMask), Y(vMask), 'r.', 'MarkerSize', 8);
    end

    xlim(ax, [xMin xMax]);
    datetick(ax, 'x', 'HH:MM:SS', 'keeplimits');
    title(ax, titleStr, 'Interpreter', 'none');
    ylabel(ax, 'Value');
    grid(ax, 'on');
    hold(ax, 'off');

    % Export
    print(fig, outFile, '-dpng', sprintf('-r%d', 150));
    close(fig);
end
