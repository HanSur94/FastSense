function test_tag_cumulativeintegral()
%TEST_TAG_CUMULATIVEINTEGRAL Headless test for Tag.cumulativeIntegral (#327).
%   Constant + ramp integrands, 1-out grand total, Range subset,
%   NaN-gap policy, and the discrete-kind warning.
%
%   Run via the matlab MCP: install(); test_tag_cumulativeintegral()

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    % Constant 1 over 0:4 -> running integral = x; total = 4
    t = SensorTag('s', 'X', 0:4, 'Y', [1 1 1 1 1]);
    [tt, cum] = t.cumulativeIntegral();
    assert(numel(tt) == 5,                       'length');             nTests = nTests + 1;
    assert(abs(cum(1) - 0) < 1e-12,             'starts at 0');        nTests = nTests + 1;
    assert(all(abs(cum(:).' - [0 1 2 3 4]) < 1e-9), 'running integral'); nTests = nTests + 1;
    tot = t.cumulativeIntegral();
    assert(abs(tot - 4) < 1e-9,                 '1-out grand total');  nTests = nTests + 1;
    TagRegistry.clear();

    % Ramp 0,1,2 over 0:2 -> trapezoid total = 2
    t2 = SensorTag('s2', 'X', 0:2, 'Y', [0 1 2]);
    tot2 = t2.cumulativeIntegral();
    assert(abs(tot2 - 2) < 1e-9,                'ramp total');         nTests = nTests + 1;
    TagRegistry.clear();

    % Range subset (constant 1 over x=1..3) -> total 2
    t3 = SensorTag('s3', 'X', 0:4, 'Y', [1 1 1 1 1]);
    totr = t3.cumulativeIntegral('Range', [1 3]);
    assert(abs(totr - 2) < 1e-9,                'range total');        nTests = nTests + 1;
    TagRegistry.clear();

    % NaN gap: segments touching NaN contribute 0 (no poisoning)
    t4 = SensorTag('s4', 'X', 0:4, 'Y', [1 1 NaN 1 1]);
    tot4 = t4.cumulativeIntegral();
    assert(isfinite(tot4) && abs(tot4 - 2) < 1e-9, 'nan-gap total');   nTests = nTests + 1;
    TagRegistry.clear();

    % Discrete-kind warning
    st = StateTag('st', 'X', 0:4, 'Y', [0 1 0 1 0]);
    lastwarn('');
    st.cumulativeIntegral();
    [~, wid] = lastwarn();
    assert(strcmp(wid, 'Tag:integralOnDiscrete'), 'discrete warning'); nTests = nTests + 1;
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
