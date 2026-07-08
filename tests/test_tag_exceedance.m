function test_tag_exceedance()
%TEST_TAG_EXCEEDANCE Headless test for Tag.exceedance (#316).
%   totalTime/fraction/count/longest/peak, above & below directions,
%   no-exceedance, Range subset, and discrete ZOH.
%
%   Run via the matlab MCP: install(); test_tag_exceedance()

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    % Triangle wave crossing level 1 twice above; each excursion lasts 1.0
    t = SensorTag('s', 'X', 0:4, 'Y', [0 2 0 2 0]);
    s = t.exceedance(1);
    assert(abs(s.totalTime - 2) < 1e-9,   'above totalTime');   nTests = nTests + 1;
    assert(s.count == 2,                  'above count');       nTests = nTests + 1;
    assert(abs(s.longest - 1) < 1e-9,     'above longest');     nTests = nTests + 1;
    assert(abs(s.fraction - 0.5) < 1e-9,  'above fraction');    nTests = nTests + 1;
    assert(abs(s.peak - 2) < 1e-9,        'above peak');        nTests = nTests + 1;
    TagRegistry.clear();

    % Below direction: peak is the minimum reached
    t2 = SensorTag('s2', 'X', 0:4, 'Y', [0 2 0 2 0]);
    sb = t2.exceedance(1, 'Direction', 'below');
    assert(abs(sb.totalTime - 2) < 1e-9,  'below totalTime');   nTests = nTests + 1;
    assert(abs(sb.peak - 0) < 1e-9,       'below peak (min)');  nTests = nTests + 1;
    TagRegistry.clear();

    % No exceedance
    t3 = SensorTag('s3', 'X', 0:4, 'Y', [0 2 0 2 0]);
    sn = t3.exceedance(10);
    assert(sn.totalTime == 0 && sn.count == 0, 'no exceedance'); nTests = nTests + 1;
    TagRegistry.clear();

    % Range subset [0 2]: one excursion of duration 1.0
    t4 = SensorTag('s4', 'X', 0:4, 'Y', [0 2 0 2 0]);
    sr = t4.exceedance(1, 'Range', [0 2]);
    assert(abs(sr.totalTime - 1) < 1e-9 && sr.count == 1, 'range subset'); nTests = nTests + 1;
    TagRegistry.clear();

    % Discrete ZOH (StateTag): value holds across each interval
    st = StateTag('st', 'X', 0:3, 'Y', [0 2 2 0]);
    sd = st.exceedance(1);
    assert(abs(sd.totalTime - 2) < 1e-9,  'zoh totalTime');     nTests = nTests + 1;
    assert(sd.count == 1,                 'zoh count');         nTests = nTests + 1;
    assert(abs(sd.peak - 2) < 1e-9,       'zoh peak');          nTests = nTests + 1;
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
