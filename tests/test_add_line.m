function test_add_line()
%TEST_ADD_LINE Tests for FastPlot.addLine method.

    run(fullfile(fileparts(mfilename('fullpath')), '..', 'setup.m'));

    % testAddSingleLine
    fp = FastPlot();
    x = 1:100;
    y = rand(1, 100);
    fp.addLine(x, y);
    assert(numel(fp.Lines) == 1, 'testAddSingleLine: expected 1 line');
    assert(isequal(fp.Lines(1).X, x), 'testAddSingleLine: X mismatch');
    assert(isequal(fp.Lines(1).Y, y), 'testAddSingleLine: Y mismatch');

    % testAddMultipleLines
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    fp.addLine(1:20, rand(1,20));
    fp.addLine(1:5, rand(1,5));
    assert(numel(fp.Lines) == 3, 'testAddMultipleLines: expected 3 lines');

    % testLineOptions
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10), 'Color', 'r', 'DisplayName', 'S1');
    assert(strcmp(fp.Lines(1).Options.Color, 'r'), 'testLineOptions: Color');
    assert(strcmp(fp.Lines(1).Options.DisplayName, 'S1'), 'testLineOptions: DisplayName');

    % testDownsampleMethodDefault
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10));
    assert(strcmp(fp.Lines(1).DownsampleMethod, 'minmax'), 'testDownsampleMethodDefault');

    % testDownsampleMethodOverride
    fp = FastPlot();
    fp.addLine(1:10, rand(1,10), 'DownsampleMethod', 'lttb');
    assert(strcmp(fp.Lines(1).DownsampleMethod, 'lttb'), 'testDownsampleMethodOverride');

    % testRejectsNonMonotonicX
    fp = FastPlot();
    threw = false;
    try
        fp.addLine([1 3 2 4], rand(1,4));
    catch e
        threw = true;
        assert(~isempty(strfind(e.message, 'monotonically')), 'Wrong error message');
    end
    assert(threw, 'testRejectsNonMonotonicX: should have thrown');

    % testRejectsMismatchedLengths
    fp = FastPlot();
    threw = false;
    try
        fp.addLine(1:10, rand(1,5));
    catch e
        threw = true;
        assert(~isempty(strfind(e.message, 'same number')), 'Wrong error message');
    end
    assert(threw, 'testRejectsMismatchedLengths: should have thrown');

    % testColumnVectorsAccepted
    fp = FastPlot();
    fp.addLine((1:10)', rand(10,1));
    assert(numel(fp.Lines(1).X) == 10, 'testColumnVectors: numel');
    assert(isrow(fp.Lines(1).X), 'testColumnVectors: must be row');

    fprintf('    All 8 addLine tests passed.\n');
end
