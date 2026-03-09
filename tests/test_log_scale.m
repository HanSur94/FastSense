function test_log_scale()
%TEST_LOG_SCALE Tests for logarithmic axis support.

    add_private_path();

    % testDefaultScale
    fp = FastPlot();
    assert(strcmp(fp.XScale, 'linear'), 'testDefaultScale: XScale');
    assert(strcmp(fp.YScale, 'linear'), 'testDefaultScale: YScale');

    % testConstructorYScale
    fp = FastPlot('YScale', 'log');
    assert(strcmp(fp.YScale, 'log'), 'testConstructorYScale');
    assert(strcmp(fp.XScale, 'linear'), 'testConstructorYScale: XScale unchanged');

    % testConstructorXScale
    fp = FastPlot('XScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testConstructorXScale');

    % testConstructorBothScales
    fp = FastPlot('XScale', 'log', 'YScale', 'log');
    assert(strcmp(fp.XScale, 'log'), 'testConstructorBothScales: X');
    assert(strcmp(fp.YScale, 'log'), 'testConstructorBothScales: Y');

    fprintf('    All 4 log_scale property tests passed.\n');
end
