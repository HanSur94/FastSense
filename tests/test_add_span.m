function test_add_span()
%TEST_ADD_SPAN Tests for FastSense.addSpan method (#377).

    addpath(fullfile(fileparts(mfilename('fullpath')), '..')); install();
    add_fastsense_private_path();

    % testAddSpan
    fp = FastSense();
    fp.addSpan(10, 20, 'FaceColor', [1 0.95 0.8], 'FaceAlpha', 0.25, 'Label', 'startup');
    assert(numel(fp.Spans) == 1, 'testAddSpan: count');
    assert(fp.Spans(1).T0 == 10, 'testAddSpan: T0');
    assert(fp.Spans(1).T1 == 20, 'testAddSpan: T1');
    assert(strcmp(fp.Spans(1).Label, 'startup'), 'testAddSpan: Label');

    % testAddMultipleSpans
    fp = FastSense();
    fp.addSpan(0, 5);
    fp.addSpan(10, 15);
    assert(numel(fp.Spans) == 2, 'testAddMultipleSpans');

    % testSpanDefaults
    fp = FastSense();
    fp.addSpan(1, 2);
    assert(fp.Spans(1).FaceAlpha > 0, 'testSpanDefaults: FaceAlpha');
    assert(numel(fp.Spans(1).FaceColor) == 3, 'testSpanDefaults: FaceColor');

    % testSpanRejectsInverted
    fp = FastSense();
    threw = false;
    try
        fp.addSpan(20, 10);
    catch
        threw = true;
    end
    assert(threw, 'testSpanRejectsInverted');

    % testSpanRendered
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.addSpan(30, 60, 'FaceColor', [0 1 0], 'FaceAlpha', 0.2);
    fp.render();
    assert(~isempty(fp.Spans(1).hPatch), 'testSpanRendered: hPatch created');
    assert(ishandle(fp.Spans(1).hPatch), 'testSpanRendered: hPatch valid');
    xd = get(fp.Spans(1).hPatch, 'XData');
    assert(min(xd) == 30 && max(xd) == 60, 'testSpanRendered: XData spans [t0,t1]');
    ud = get(fp.Spans(1).hPatch, 'UserData');
    assert(strcmp(ud.FastSense.Type, 'span'), 'testSpanRendered: UserData type');
    close(fp.hFigure);

    % testSpanRejectsAfterRender
    fp = FastSense();
    fp.addLine(1:100, rand(1,100));
    fp.render();
    threw = false;
    try
        fp.addSpan(10, 20);
    catch
        threw = true;
    end
    assert(threw, 'testSpanRejectsAfterRender');
    close(fp.hFigure);

    fprintf('    All 6 addSpan tests passed.\n');
end
