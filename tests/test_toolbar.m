function test_toolbar()
%TEST_TOOLBAR Tests for FastPlotToolbar class.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'private'));

    % testConstructorWithFastPlot
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    assert(~isempty(tb.hToolbar), 'testConstructorWithFastPlot: hToolbar');
    assert(ishandle(tb.hToolbar), 'testConstructorWithFastPlot: ishandle');
    close(fp.hFigure);

    % testConstructorWithFastPlotFigure
    fig = FastPlotFigure(1, 2);
    fp1 = fig.tile(1); fp1.addLine(1:100, rand(1,100));
    fp2 = fig.tile(2); fp2.addLine(1:100, rand(1,100));
    fig.renderAll();
    tb = FastPlotToolbar(fig);
    assert(~isempty(tb.hToolbar), 'testConstructorWithFPFigure: hToolbar');
    close(fig.hFigure);

    % testToolbarHasSixButtons
    fp = FastPlot();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    tb = FastPlotToolbar(fp);
    children = get(tb.hToolbar, 'Children');
    assert(numel(children) == 6, ...
        sprintf('testToolbarHasSixButtons: got %d', numel(children)));
    close(fp.hFigure);

    % testIconsAre16x16x3
    icons = FastPlotToolbar.makeIcon('grid');
    assert(isequal(size(icons), [16 16 3]), 'testIconsAre16x16x3');

    % testAllIconNames
    names = {'cursor', 'crosshair', 'grid', 'legend', 'autoscale', 'export'};
    for i = 1:numel(names)
        icon = FastPlotToolbar.makeIcon(names{i});
        assert(isequal(size(icon), [16 16 3]), ...
            sprintf('testAllIconNames: %s', names{i}));
    end

    fprintf('    All 5 toolbar skeleton tests passed.\n');
end
