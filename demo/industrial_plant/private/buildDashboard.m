function engine = buildDashboard(ctx)
%BUILDDASHBOARD Construct the Phase 1015 demo dashboard.
%   engine = buildDashboard(ctx) creates the DashboardEngine, adds six
%   themed pages, delegates per-page widget composition to the build*Page
%   helpers, renders the figure, starts the live timer, and wires a
%   CloseRequestFcn so closing the figure invokes teardownDemo(ctx).
%   (Earlier revisions auto-detached the reactor pressure plot into its
%   own figure on startup; that was removed on user feedback.)
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
        'Theme', 'light', 'LiveInterval', 1.0);

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

    % (Plan D-09 called for pre-detaching the reactor pressure plot into
    % its own figure on startup; that behaviour was removed on user
    % feedback -- the demo now renders as a single dashboard window. The
    % Re-attach / Detach button on each FastSenseWidget still lets users
    % pop a plot out manually.)

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
