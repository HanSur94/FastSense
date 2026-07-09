function test_add_vline()
%TEST_ADD_VLINE Tests for FastSense.addVLine method (#357).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    % testAddVLine
    fp = FastSense();
    fp.addVLine(10, 'Color', [1 0 0], 'LineStyle', ':', 'LineWidth', 1.5, 'Label', 'trip');
    assert(numel(fp.VLines) == 1, 'testAddVLine: count');
    assert(fp.VLines(1).X == 10, 'testAddVLine: X');
    assert(isequal(fp.VLines(1).Color, [1 0 0]), 'testAddVLine: Color');
    assert(strcmp(fp.VLines(1).LineStyle, ':'), 'testAddVLine: LineStyle');
    assert(fp.VLines(1).LineWidth == 1.5, 'testAddVLine: LineWidth');
    assert(strcmp(fp.VLines(1).Label, 'trip'), 'testAddVLine: Label');

    % testAddMultipleVLines
    fp = FastSense();
    fp.addVLine(5);
    fp.addVLine(15);
    assert(numel(fp.VLines) == 2, 'testAddMultipleVLines');

    % testVLineDefaults
    fp = FastSense();
    fp.addVLine(3);
    assert(fp.VLines(1).LineWidth == 1, 'testVLineDefaults: LineWidth');
    assert(numel(fp.VLines(1).Color) == 3, 'testVLineDefaults: Color');
    assert(strcmp(fp.VLines(1).Label, ''), 'testVLineDefaults: Label');

    % testVLineRejectsNonScalar
    fp = FastSense();
    threw = false;
    try
        fp.addVLine([1 2]);
    catch
        threw = true;
    end
    assert(threw, 'testVLineRejectsNonScalar');

    % testVLineRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addVLine(50, 'Label', 'mark');
    fp.render();
    assert(~isempty(fp.VLines(1).hLine), 'testVLineRendered: hLine created');
    assert(ishandle(fp.VLines(1).hLine), 'testVLineRendered: hLine valid');
    xd = get(fp.VLines(1).hLine, 'XData');
    assert(isequal(xd, [50 50]), 'testVLineRendered: XData spans the x value');
    ud = get(fp.VLines(1).hLine, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'vline'), 'testVLineRendered: UserData type');
    close(fp.hFigure);

    % testVLineRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    threw = false;
    try
        fp.addVLine(10);
    catch
        threw = true;
    end
    assert(threw, 'testVLineRejectsAfterRender');
    close(fp.hFigure);

    fprintf('    All 6 addVLine tests passed.\n');
end
