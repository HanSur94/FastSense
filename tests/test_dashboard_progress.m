function test_dashboard_progress()
%TEST_DASHBOARD_PROGRESS Tests for DashboardProgress helper.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();

    % testSilentModeProducesNoOutput
    p = DashboardProgress('Demo', 3, 1, 'off');
    w = stubWidget('NumberWidget', 'a');
    tickOut   = evalc('p.tick(w, 1, '''');');
    finishOut = evalc('p.finish();');
    assert(isempty(tickOut), 'testSilentModeProducesNoOutput: tick output nonempty');
    assert(isempty(finishOut), 'testSilentModeProducesNoOutput: finish output nonempty');

    % testInteractiveTickEmitsProgressLine
    p = DashboardProgress('SensorOverview', 3, 1, 'on');
    w = stubWidget('NumberWidget', 'rpm');
    out = evalc('p.tick(w, 1, '''');');
    assert(~isempty(out), 'testInteractiveTickEmitsProgressLine: no output emitted');
    assertContains(out, '[Dashboard ''SensorOverview'']', 'testInteractiveTick: dashboard name missing');
    assertContains(out, '1/3', 'testInteractiveTick: counter missing');
    assertContains(out, 'NumberWidget', 'testInteractiveTick: widget class missing');
    assertContains(out, 'rpm', 'testInteractiveTick: widget key missing');

    % testInteractiveFinishEmitsSummaryWithNewline
    p = DashboardProgress('SensorOverview', 2, 1, 'on');
    w1 = stubWidget('NumberWidget', 'a');
    w2 = stubWidget('GaugeWidget', 'b');
    evalc('p.tick(w1, 1, '''');');
    evalc('p.tick(w2, 1, '''');');
    out = evalc('p.finish();');
    assertContains(out, 'rendered 2 widgets', 'testInteractiveFinish: summary missing');
    assert(out(end) == sprintf('\n'), 'testInteractiveFinish: summary not newline-terminated');
    % single-page dashboards omit the "across N pages" clause
    assert(isempty(strfind(out, 'across')), 'testInteractiveFinish: single-page should omit "across"');

    % testInteractiveFinishMultiPageMentionsPages
    p = DashboardProgress('X', 5, 3, 'on');
    out = evalc('p.finish();');
    assertContains(out, 'across 3 pages', 'testFinishMultiPage: pages missing');

    % testInteractiveTickIncludesPageLabelWhenMultiPage
    p = DashboardProgress('X', 4, 2, 'on');
    w = stubWidget('NumberWidget', 'k');
    out = evalc('p.tick(w, 2, ''Engine'');');
    assertContains(out, 'page 2/2', 'testTickMultiPage: page index missing');
    assertContains(out, 'Engine', 'testTickMultiPage: page name missing');

    % testInteractiveTickOmitsPageLabelWhenSinglePage
    p = DashboardProgress('X', 2, 1, 'on');
    w = stubWidget('NumberWidget', 'k');
    out = evalc('p.tick(w, 1, '''');');
    assert(isempty(strfind(out, 'page ')), 'testTickSinglePage: should not show page label');

    % testTickClampsAtTotal
    p = DashboardProgress('X', 2, 1, 'on');
    w = stubWidget('NumberWidget', 'k');
    evalc('p.tick(w, 1, '''');');
    evalc('p.tick(w, 1, '''');');
    out = evalc('p.tick(w, 1, '''');');  % third tick beyond total
    assertContains(out, '2/2', 'testTickClamps: counter exceeded total');

    % testTickMissingKeyFallsBackToIndex
    p = DashboardProgress('X', 2, 1, 'on');
    w = stubWidget('NumberWidget', '');
    out = evalc('p.tick(w, 1, '''');');
    assertContains(out, '#1', 'testTickMissingKey: index fallback missing');

    % testEngineRenderEmitsProgressSummary
    d = DashboardEngine('EngineProgress');
    d.ProgressMode = 'on';
    d.addWidget('number', 'Title', 'A', 'Position', [1 1 6 2], 'StaticValue', 1);
    d.addWidget('number', 'Title', 'B', 'Position', [7 1 6 2], 'StaticValue', 2);
    out = evalc('d.render();');
    try, set(d.hFigure, 'Visible', 'off'); end
    try, close(d.hFigure); end
    assertContains(out, 'rendered 2 widgets', 'testEngineRender: summary missing');
    assertContains(out, '[Dashboard ''EngineProgress'']', 'testEngineRender: name missing');

    % testEngineRenderSilentByDefault (in headless Octave CI 'auto' resolves to off)
    d = DashboardEngine('SilentDefault');
    d.addWidget('number', 'Title', 'A', 'Position', [1 1 6 2], 'StaticValue', 1);
    out = evalc('d.render();');
    try, set(d.hFigure, 'Visible', 'off'); end
    try, close(d.hFigure); end
    assert(isempty(strfind(out, 'rendered 1 widgets')), ...
        'testEngineRenderSilentByDefault: progress output leaked in auto mode');

    % testRenderPreservesLazyPageRealization — non-active page widgets
    % must remain unrealized after render() so switchPage stays lazy.
    d = DashboardEngine('LazyCheck');
    d.ProgressMode = 'on';
    d.addPage('P1'); d.switchPage(1);
    d.addWidget('number', 'Title', 'P1W', 'Position', [1 1 12 1], 'StaticValue', 1);
    d.addPage('P2'); d.switchPage(2);
    d.addWidget('number', 'Title', 'P2W', 'Position', [1 1 12 1], 'StaticValue', 2);
    d.switchPage(1);
    evalc('d.render();');
    try, set(d.hFigure, 'Visible', 'off'); end
    assert(d.Pages{1}.Widgets{1}.Realized, ...
        'testRenderPreservesLazyPageRealization: active page widget must be realized');
    assert(~d.Pages{2}.Widgets{1}.Realized, ...
        'testRenderPreservesLazyPageRealization: non-active page widget must stay unrealized');
    try, close(d.hFigure); end

    fprintf('    All tests passed.\n');
end

function w = stubWidget(typeName, title)
    w = struct('Title', title, 'ClassName', typeName);
end

function assertContains(haystack, needle, msg)
    if isempty(strfind(haystack, needle))
        error('%s (looking for ''%s'' in ''%s'')', msg, needle, haystack);
    end
end
