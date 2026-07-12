function test_add_text()
%TEST_ADD_TEXT Tests for FastSense.addText method (#347).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    % testAddText
    fp = FastSense();
    fp.addText(10, 5, 'callout', 'Color', [1 0 0], 'FontSize', 12, ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
    assert(numel(fp.Texts) == 1, 'testAddText: count');
    assert(fp.Texts(1).X == 10, 'testAddText: X');
    assert(fp.Texts(1).Y == 5, 'testAddText: Y');
    assert(strcmp(fp.Texts(1).String, 'callout'), 'testAddText: String');
    assert(fp.Texts(1).FontSize == 12, 'testAddText: FontSize');
    assert(strcmp(fp.Texts(1).HorizontalAlignment, 'center'), 'testAddText: HAlign');

    % testAddMultipleTexts
    fp = FastSense();
    fp.addText(1, 1, 'a');
    fp.addText(2, 2, 'b');
    assert(numel(fp.Texts) == 2, 'testAddMultipleTexts');

    % testTextDefaults
    fp = FastSense();
    fp.addText(0, 0, 'x');
    assert(fp.Texts(1).FontSize == 10, 'testTextDefaults: FontSize');
    assert(strcmp(fp.Texts(1).HorizontalAlignment, 'left'), 'testTextDefaults: HAlign');
    assert(numel(fp.Texts(1).Color) == 3, 'testTextDefaults: Color');

    % testTextRejectsBadArgs
    fp = FastSense();
    threw = false;
    try
        fp.addText([1 2], 5, 'x');
    catch
        threw = true;
    end
    assert(threw, 'testTextRejectsBadArgs: non-scalar x');
    threw = false;
    try
        fp.addText(1, 5, 42);
    catch
        threw = true;
    end
    assert(threw, 'testTextRejectsBadArgs: non-char str');

    % testTextRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addText(50, 0.5, 'peak here', 'Color', [0 0 1]);
    fp.render();
    assert(~isempty(fp.Texts(1).hText), 'testTextRendered: hText created');
    assert(ishandle(fp.Texts(1).hText), 'testTextRendered: hText valid');
    assert(strcmp(get(fp.Texts(1).hText, 'String'), 'peak here'), 'testTextRendered: String');
    ud = get(fp.Texts(1).hText, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'text'), 'testTextRendered: UserData type');
    close(fp.hFigure);

    % testTextRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    threw = false;
    try
        fp.addText(10, 1, 'x');
    catch
        threw = true;
    end
    assert(threw, 'testTextRejectsAfterRender');
    close(fp.hFigure);

    fprintf('    All 6 addText tests passed.\n');
end
