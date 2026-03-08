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

    fprintf('    All 3 dock tests passed.\n');
end
