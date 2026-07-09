function test_tag_resampleuniform()
%TEST_TAG_RESAMPLEUNIFORM Headless test for Tag.resampleUniform (#308).
%   Continuous-linear grid, uniform spacing, Method override (ZOH),
%   Range subset, and kind-aware discrete (StateTag) ZOH default.
%
%   Run via the matlab MCP: install(); test_tag_resampleuniform()

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    % --- Continuous linear default ----------------------------------------
    t = SensorTag('s', 'X', 0:4, 'Y', [0 10 20 30 40]);
    [Xu, Yu] = t.resampleUniform(0.5);
    assert(numel(Xu) == 9,                    'grid length');            nTests = nTests + 1;
    assert(all(abs(diff(Xu) - 0.5) < 1e-12), 'uniform spacing');        nTests = nTests + 1;
    assert(abs(Yu(1) - 0) < 1e-9,            'first value');            nTests = nTests + 1;
    assert(abs(Yu(end) - 40) < 1e-9,         'last value');             nTests = nTests + 1;
    assert(abs(Yu(2) - 5) < 1e-9,            'linear interp at x=0.5'); nTests = nTests + 1;
    TagRegistry.clear();

    % --- Method override: previous (ZOH) ----------------------------------
    t2 = SensorTag('s2', 'X', 0:4, 'Y', [0 10 20 30 40]);
    [~, Yp] = t2.resampleUniform(0.5, 'Method', 'previous');
    assert(abs(Yp(2) - 0) < 1e-9,            'previous hold at x=0.5');  nTests = nTests + 1;
    TagRegistry.clear();

    % --- Range subset ------------------------------------------------------
    t3 = SensorTag('s3', 'X', 0:4, 'Y', [0 10 20 30 40]);
    [Xr, Yr] = t3.resampleUniform(1, 'Range', [1 3]);
    assert(isequal(Xr, [1 2 3]),             'range grid');              nTests = nTests + 1;
    assert(all(abs(Yr - [10 20 30]) < 1e-9), 'range values');           nTests = nTests + 1;
    TagRegistry.clear();

    % --- Kind-aware discrete default (StateTag -> ZOH) ---------------------
    st = StateTag('st', 'X', 0:4, 'Y', [0 1 0 1 0]);
    [Xs, Ys] = st.resampleUniform(0.5);
    % Xs = 0,0.5,1,1.5,...; previous hold => Ys(2)=prev(0)=0, Ys(4)=prev(x=1)=1
    assert(abs(Ys(2) - 0) < 1e-9,            'state ZOH at x=0.5');      nTests = nTests + 1;
    assert(abs(Ys(4) - 1) < 1e-9,            'state ZOH at x=1.5');      nTests = nTests + 1;
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
