function test_dock()
%TEST_DOCK Tests for FastPlotDock tabbed container.

    add_private_path();
    close all force;
    drawnow;

    % testConstruction
    dock = FastPlotDock('Theme', 'dark', 'Name', 'Test Dock');
    assert(~isempty(dock.hFigure), 'testConstruction: hFigure');
    assert(ishandle(dock.hFigure), 'testConstruction: hFigure valid');
    assert(strcmp(get(dock.hFigure, 'Name'), 'Test Dock'), 'testConstruction: Name');
    close(dock.hFigure);

    % testDefaultTheme
    dock = FastPlotDock();
    assert(~isempty(dock.Theme), 'testDefaultTheme: should have theme');
    close(dock.hFigure);

    % testAddTab
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(2, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    fp = fig1.tile(2); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Dashboard 1');
    assert(numel(dock.Tabs) == 1, 'testAddTab: 1 tab');
    assert(strcmp(dock.Tabs(1).Name, 'Dashboard 1'), 'testAddTab: name');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Dashboard 2');
    assert(numel(dock.Tabs) == 2, 'testAddTab: 2 tabs');
    close(dock.hFigure);

    % testRender
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');

    dock.render();
    assert(dock.ActiveTab == 1, 'testRender: first tab active');
    assert(strcmp(get(dock.hFigure, 'Visible'), 'on'), 'testRender: figure visible');
    assert(numel(dock.hTabButtons) == 2, 'testRender: 2 tab buttons');
    % Tab A panel should be visible, Tab B hidden
    assert(strcmp(get(dock.Tabs(1).Panel, 'Visible'), 'on'), 'testRender: tab A panel visible');
    assert(strcmp(get(dock.Tabs(2).Panel, 'Visible'), 'off'), 'testRender: tab B panel hidden');
    close(dock.hFigure);

    % testSelectTab
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');
    dock.render();

    % Switch to tab 2
    dock.selectTab(2);
    assert(dock.ActiveTab == 2, 'testSelectTab: active is 2');
    assert(strcmp(get(dock.Tabs(1).Panel, 'Visible'), 'off'), 'testSelectTab: tab A hidden');
    assert(strcmp(get(dock.Tabs(2).Panel, 'Visible'), 'on'), 'testSelectTab: tab B visible');

    % Switch back to tab 1
    dock.selectTab(1);
    assert(dock.ActiveTab == 1, 'testSelectTab: active is 1');
    assert(strcmp(get(dock.Tabs(1).Panel, 'Visible'), 'on'), 'testSelectTab: tab A visible again');
    assert(strcmp(get(dock.Tabs(2).Panel, 'Visible'), 'off'), 'testSelectTab: tab B hidden again');
    close(dock.hFigure);

    % testSelectTabOutOfBounds
    dock = FastPlotDock();
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Only Tab');
    dock.render();
    threw = false;
    try
        dock.selectTab(5);
    catch
        threw = true;
    end
    assert(threw, 'testSelectTabOutOfBounds: should error');
    close(dock.hFigure);

    % testResize
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');
    dock.render();
    posBefore = get(fig1.tile(1).hAxes, 'Position');
    % Simulate resize by calling the recompute method
    dock.recomputeLayout();
    posAfter = get(fig1.tile(1).hAxes, 'Position');
    % Positions should remain consistent (no crash)
    assert(abs(posBefore(1) - posAfter(1)) < 0.01, 'testResize: x stable');
    assert(abs(posBefore(2) - posAfter(2)) < 0.01, 'testResize: y stable');
    close(dock.hFigure);

    % testCloseStopsLive
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:100, zeros(1,100));
    dock.addTab(fig1, 'Live Tab');
    dock.render();

    tmpFile = [tempname, '.mat'];
    s.x = 1:100; s.y = rand(1,100);
    save(tmpFile, '-struct', 's');
    fig1.startLive(tmpFile, @(f,d) f.tile(1).updateData(1, d.x, d.y), 'Interval', 1.0);
    assert(fig1.LiveIsActive, 'testCloseStopsLive: live active before close');

    close(dock.hFigure);
    assert(~fig1.LiveIsActive, 'testCloseStopsLive: live stopped after close');
    delete(tmpFile);

    % testAddTabAfterRender
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');
    dock.render();

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');

    assert(numel(dock.Tabs) == 2, 'testAddTabAfterRender: 2 tabs');
    assert(numel(dock.hTabButtons) == 2, 'testAddTabAfterRender: 2 buttons');
    % New tab panel should be hidden (first tab still active)
    assert(strcmp(get(dock.Tabs(2).Panel, 'Visible'), 'off'), 'testAddTabAfterRender: new tab hidden');
    % Switch to it
    dock.selectTab(2);
    assert(strcmp(get(dock.Tabs(2).Panel, 'Visible'), 'on'), 'testAddTabAfterRender: new tab visible');
    close(dock.hFigure);

    % testRemoveTab
    dock = FastPlotDock('Theme', 'dark');
    fig1 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig1.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig1, 'Tab A');

    fig2 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig2.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig2, 'Tab B');

    fig3 = FastPlotFigure(1, 1, 'ParentFigure', dock.hFigure);
    fp = fig3.tile(1); fp.addLine(1:50, rand(1,50));
    dock.addTab(fig3, 'Tab C');
    dock.render();

    assert(numel(dock.Tabs) == 3, 'testRemoveTab: 3 tabs');
    assert(dock.ActiveTab == 1, 'testRemoveTab: tab 1 active');

    % Remove middle tab
    dock.removeTab(2);
    assert(numel(dock.Tabs) == 2, 'testRemoveTab: 2 tabs after remove');
    assert(numel(dock.hTabButtons) == 2, 'testRemoveTab: 2 buttons');
    assert(numel(dock.hCloseButtons) == 2, 'testRemoveTab: 2 close buttons');
    assert(strcmp(dock.Tabs(2).Name, 'Tab C'), 'testRemoveTab: Tab C is now idx 2');

    % Remove active tab
    dock.selectTab(1);
    dock.removeTab(1);
    assert(numel(dock.Tabs) == 1, 'testRemoveTab: 1 tab left');
    assert(dock.ActiveTab == 1, 'testRemoveTab: active adjusted');
    assert(strcmp(dock.Tabs(1).Name, 'Tab C'), 'testRemoveTab: Tab C remains');

    % Remove last tab
    dock.removeTab(1);
    assert(isempty(dock.Tabs), 'testRemoveTab: no tabs left');
    assert(dock.ActiveTab == 0, 'testRemoveTab: active is 0');
    close(dock.hFigure);

    fprintf('    All 10 dock tests passed.\n');
end
