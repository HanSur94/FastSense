function test_tag_crossings()
%TEST_TAG_CROSSINGS Headless test for Tag.crossings (#328).
%   Interpolated crossing instants + direction, Direction filter, 2-out form,
%   exact-sample hit, plateau-at-level, and NaN gap.
%
%   Run via the matlab MCP: install(); test_tag_crossings()

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    % Y crosses 0 rising at x=1.5, falling at x=3.6667
    t = SensorTag('s', 'X', 0:4, 'Y', [-2 -1 1 2 -1]);
    c = t.crossings(0);
    assert(c.count == 2,                       'count');               nTests = nTests + 1;
    assert(abs(c.times(1) - 1.5) < 1e-9,      'rising instant');      nTests = nTests + 1;
    assert(c.direction(1) == 1,               'rising dir +1');       nTests = nTests + 1;
    assert(c.direction(2) == -1,              'falling dir -1');      nTests = nTests + 1;
    assert(abs(c.times(2) - (3 + 2/3)) < 1e-6, 'falling instant');    nTests = nTests + 1;
    assert(numel(c.periods) == c.count - 1,   'periods length');      nTests = nTests + 1;
    TagRegistry.clear();

    % Direction filters
    t2 = SensorTag('s2', 'X', 0:4, 'Y', [-2 -1 1 2 -1]);
    cr = t2.crossings(0, 'Direction', 'rising');
    assert(cr.count == 1 && cr.direction(1) == 1,  'rising only');     nTests = nTests + 1;
    cf = t2.crossings(0, 'Direction', 'falling');
    assert(cf.count == 1 && cf.direction(1) == -1, 'falling only');    nTests = nTests + 1;
    % 2-out form
    [tt, dd] = t2.crossings(0);
    assert(numel(tt) == 2 && isequal(dd, [1 -1]), '2-out form');       nTests = nTests + 1;
    TagRegistry.clear();

    % Exact-sample hit at x=1 (Y passes through 0 exactly), counted once
    t3 = SensorTag('s3', 'X', 0:3, 'Y', [-1 0 1 2]);
    c3 = t3.crossings(0);
    assert(c3.count == 1 && abs(c3.times(1) - 1) < 1e-9, 'exact sample hit'); nTests = nTests + 1;
    TagRegistry.clear();

    % Plateau at level: single crossing on exit
    t4 = SensorTag('s4', 'X', 0:3, 'Y', [-1 0 0 1]);
    c4 = t4.crossings(0);
    assert(c4.count == 1,                      'plateau one crossing'); nTests = nTests + 1;
    TagRegistry.clear();

    % NaN gap: no crossing across a NaN-bounded segment
    t5 = SensorTag('s5', 'X', 0:2, 'Y', [-2 NaN 2]);
    c5 = t5.crossings(0);
    assert(c5.count == 0,                      'nan gap no crossing');  nTests = nTests + 1;
    TagRegistry.clear();

    fprintf('    All %d tests passed.\n', nTests);
end

function add_tag_analysis_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end
