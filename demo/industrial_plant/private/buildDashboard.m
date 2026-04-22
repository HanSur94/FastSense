function engine = buildDashboard(ctx)
%BUILDDASHBOARD Construct the Phase 1015 demo dashboard.
%   engine = buildDashboard(ctx) creates the DashboardEngine, adds six
%   themed pages, delegates per-page widget composition to the build*Page
%   helpers, renders the figure, attempts to pre-detach the main reactor
%   pressure plot, starts the live timer, and wires a CloseRequestFcn so
%   closing the figure invokes teardownDemo(ctx).
%
%   Plan-vs-API notes (deviations documented in 1015-02-SUMMARY.md):
%     - DashboardEngine has no 'Live' NV-pair; startLive() starts the timer.
%     - render() takes no args -- engine creates its own figure.
%     - allPageWidgets() is private; we iterate engine.Pages{i}.Widgets
%       directly (Pages has SetAccess=private but is publicly readable).
%     - Widget kinds 'collapsible', 'sparklinecard', 'eventtimeline' are
%       not in the WidgetTypeMap_; we use the real kinds ('group' with
%       Mode='collapsible', 'sparkline', 'timeline') while keeping the
%       plan's literal kind strings in adjacent comments for traceability.
%
%   See also: run_demo, teardownDemo, buildOverviewPage, buildFeedLinePage,
%             buildReactorPage, buildCoolingPage, buildEventsPage,
%             buildDiagnosticsPage.

    engine = DashboardEngine('FastSense Industrial Plant Demo', ...
        'Theme', 'dark', 'LiveInterval', 1.0);

    engine.addPage('Overview');
    engine.addPage('Feed Line');
    engine.addPage('Reactor');
    engine.addPage('Cooling');
    engine.addPage('Events');
    engine.addPage('Diagnostics');

    engine.switchPage(1); buildOverviewPage(engine, ctx);
    engine.switchPage(2); buildFeedLinePage(engine, ctx);
    engine.switchPage(3); buildReactorPage(engine, ctx);
    engine.switchPage(4); buildCoolingPage(engine, ctx);
    engine.switchPage(5); buildEventsPage(engine, ctx);
    engine.switchPage(6); buildDiagnosticsPage(engine, ctx);

    engine.switchPage(1);
    engine.render();

    % D-09 pre-detach the main reactor pressure plot on Overview.
    % Helper walks engine.Pages{i}.Widgets (public readable) rather than
    % the private allPageWidgets() method referenced in the plan body.
    try
        mainPlot = firstWidgetByTag_(engine, 'reactor.pressure', 'fastsense');
        if ~isempty(mainPlot)
            engine.detachWidget(mainPlot);
        end
    catch detachErr
        warning('IndustrialPlant:detachFailed', ...
            'Pre-detach of main plot failed: %s', detachErr.message);
    end

    % Start live refresh timer.
    engine.startLive();

    % Update ctx in caller's scope via the fig's UserData so CloseRequestFcn
    % can reach the updated engine handle. Also store on fig directly.
    ctx.engine = engine;
    fig = engine.hFigure;
    if ~isempty(fig) && ishandle(fig)
        set(fig, 'Name', 'FastSense Industrial Plant Demo');
        set(fig, 'CloseRequestFcn', @(src, ~) demoClose_(src, ctx));
    end
end

function w = firstWidgetByTag_(engine, tagKey, kindHint)
%FIRSTWIDGETBYTAG_ Search all pages for a widget bound to the given Tag.
%   Walks engine.Pages{i}.Widgets directly. Pages is SetAccess=private but
%   publicly readable; DashboardPage.Widgets is a public cell. This avoids
%   calling the engine's private allPageWidgets() method.
%
%   When kindHint is provided, matches only widgets whose Type matches.
    w = [];
    if isempty(engine.Pages)
        pools = {engine.Widgets};
    else
        pools = cell(1, numel(engine.Pages));
        for i = 1:numel(engine.Pages)
            pools{i} = engine.Pages{i}.Widgets;
        end
    end
    for p = 1:numel(pools)
        ws = pools{p};
        for i = 1:numel(ws)
            wi = ws{i};
            if nargin >= 3 && ~isempty(kindHint)
                try
                    if ~strcmpi(wi.Type, kindHint)
                        continue;
                    end
                catch
                    continue;
                end
            end
            if ~isempty(wi.Tag) && isprop(wi.Tag, 'Key') && ...
                    strcmp(wi.Tag.Key, tagKey)
                w = wi;
                return;
            end
        end
    end
end

function demoClose_(fig, ctx)
%DEMOCLOSE_ Figure CloseRequestFcn callback -- tears down timers then deletes fig.
    try
        teardownDemo(ctx);
    catch
    end
    try
        delete(fig);
    catch
    end
end
