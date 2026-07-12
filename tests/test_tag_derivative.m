function test_tag_derivative()
%TEST_TAG_DERIVATIVE Headless test for Tag.derivative (#326).
%   central/forward/backward methods, Range subset, NaN safety,
%   and the discrete-kind warning.
%
%   Run via the matlab MCP: install(); test_tag_derivative()

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    % Y = x^2 on 0:4 -> central-difference derivative is exact at interior (2x).
    t = SensorTag('s', 'X', 0:4, 'Y', [0 1 4 9 16]);
    [tt, d] = t.derivative();
    assert(numel(tt) == 5,                'central length');            nTests = nTests + 1;
    assert(abs(d(2) - 2) < 1e-9,          'central 2x at x=1');         nTests = nTests + 1;
    assert(abs(d(3) - 4) < 1e-9,          'central 2x at x=2');         nTests = nTests + 1;
    assert(abs(d(4) - 6) < 1e-9,          'central 2x at x=3');         nTests = nTests + 1;
    TagRegistry.clear();

    % forward differences
    t2 = SensorTag('s2', 'X', 0:4, 'Y', [0 1 4 9 16]);
    [~, df] = t2.derivative('Method', 'forward');
    assert(abs(df(1) - 1) < 1e-9,         'forward at i=1');            nTests = nTests + 1;
    assert(abs(df(2) - 3) < 1e-9,         'forward at i=2');            nTests = nTests + 1;
    TagRegistry.clear();

    % backward differences
    t3 = SensorTag('s3', 'X', 0:4, 'Y', [0 1 4 9 16]);
    [~, db] = t3.derivative('Method', 'backward');
    assert(abs(db(2) - 1) < 1e-9,         'backward at i=2');           nTests = nTests + 1;
    assert(abs(db(5) - 7) < 1e-9,         'backward at i=5');           nTests = nTests + 1;
    TagRegistry.clear();

    % Range subset (x=1,4,9 over 1:3) -> central [3 4 5]
    t4 = SensorTag('s4', 'X', 0:4, 'Y', [0 1 4 9 16]);
    [tr, dr] = t4.derivative('Range', [1 3]);
    assert(numel(tr) == 3,                'range length');              nTests = nTests + 1;
    assert(abs(dr(2) - 4) < 1e-9,         'range central at x=2');      nTests = nTests + 1;
    TagRegistry.clear();

    % NaN safety: a NaN neighbour poisons the central rate around it
    t5 = SensorTag('s5', 'X', 0:4, 'Y', [0 1 NaN 9 16]);
    [~, dn] = t5.derivative();
    assert(isfinite(dn(1)),               'nan: endpoint finite');      nTests = nTests + 1;
    assert(isnan(dn(2)) && isnan(dn(4)),  'nan: neighbours NaN');       nTests = nTests + 1;
    TagRegistry.clear();

    % Discrete-kind warning
    st = StateTag('st', 'X', 0:4, 'Y', [0 1 0 1 0]);
    lastwarn('');
    st.derivative();
    [~, wid] = lastwarn();
    assert(strcmp(wid, 'Tag:derivativeOnDiscrete'), 'discrete warning'); nTests = nTests + 1;
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
