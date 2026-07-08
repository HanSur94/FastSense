function test_tag_getstats()
%TEST_TAG_GETSTATS Headless test for Tag.getStats (#223).
%   Verifies the keystone statistics primitive on the Tag base class:
%     - Basic numeric series: field set + values on a known series
%     - NaN exclusion (omitnan semantics via masking)
%     - Windowing narrows the reduction via getXYRange
%     - Empty window (outside data extent) -> N=0, NaN reductions
%     - Non-numeric (cellstr) StateTag -> N + time bounds, NaN reductions
%
%   Toolbox-free / Octave-safe. Run via the matlab MCP:
%       install(); test_tag_getstats()
%
%   See also Tag.getStats, test_derivedtag.

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    % --- Basic numeric series ---------------------------------------------
    % Y = [2 4 6 8 10] over X = 1:5.
    %   N=5, Min=2, Max=10, Mean=6
    %   Rms = sqrt(mean([4 16 36 64 100])) = sqrt(220/5) = sqrt(44)
    %   Std = sqrt( (16+4+0+4+16)/(5-1) ) = sqrt(40/4) = sqrt(10)
    t = SensorTag('s', 'X', 1:5, 'Y', [2 4 6 8 10]);
    s = t.getStats();
    assert(s.N == 5,                              'basic N');                nTests = nTests + 1;
    assert(s.Min == 2,                            'basic Min');              nTests = nTests + 1;
    assert(s.Max == 10,                           'basic Max');              nTests = nTests + 1;
    assert(abs(s.Mean - 6) < 1e-12,              'basic Mean');             nTests = nTests + 1;
    assert(abs(s.Rms - sqrt(44)) < 1e-9,         'basic Rms');              nTests = nTests + 1;
    assert(abs(s.Std - sqrt(10)) < 1e-9,         'basic Std');              nTests = nTests + 1;
    assert(s.First == 2,                          'basic First');            nTests = nTests + 1;
    assert(s.Last == 10,                          'basic Last');             nTests = nTests + 1;
    assert(s.TimeStart == 1,                      'basic TimeStart');        nTests = nTests + 1;
    assert(s.TimeEnd == 5,                        'basic TimeEnd');          nTests = nTests + 1;
    % Field set is exactly the pinned 10, in order.
    assert(isequal(fieldnames(s), {'N';'Min';'Max';'Mean';'Rms';'Std'; ...
        'First';'Last';'TimeStart';'TimeEnd'}), 'field set + order');        nTests = nTests + 1;
    TagRegistry.clear();

    % --- NaN exclusion -----------------------------------------------------
    % Y = [2 NaN 6 8 10] -> yv = [2 6 8 10], N=4, Mean = 26/4 = 6.5
    t2 = SensorTag('s2', 'X', 1:5, 'Y', [2 NaN 6 8 10]);
    s2 = t2.getStats();
    assert(s2.N == 4,                             'nan N');                  nTests = nTests + 1;
    assert(abs(s2.Mean - 6.5) < 1e-12,           'nan Mean (omitnan)');     nTests = nTests + 1;
    assert(isfinite(s2.Rms) && isfinite(s2.Std), 'nan Rms/Std finite');     nTests = nTests + 1;
    TagRegistry.clear();

    % --- Windowing narrows the reduction ----------------------------------
    t3 = SensorTag('s3', 'X', 1:10, 'Y', 1:10);
    sFull = t3.getStats();
    sWin  = t3.getStats(4, 6);
    assert(sWin.N < sFull.N,                      'window narrows N');       nTests = nTests + 1;
    assert(sWin.TimeStart >= 1 && sWin.TimeEnd <= 10, 'window bounds');      nTests = nTests + 1;
    assert(sWin.Mean >= 4 && sWin.Mean <= 6,     'window Mean in-range');   nTests = nTests + 1;
    TagRegistry.clear();

    % --- Empty window (outside data extent) -------------------------------
    t4 = SensorTag('s4', 'X', 1:10, 'Y', 1:10);
    sEmpty = t4.getStats(100, 200);
    assert(sEmpty.N == 0,                         'empty N==0');             nTests = nTests + 1;
    assert(isnan(sEmpty.Mean),                    'empty Mean NaN');         nTests = nTests + 1;
    assert(isnan(sEmpty.Std),                     'empty Std NaN');          nTests = nTests + 1;
    TagRegistry.clear();

    % --- Non-numeric StateTag ---------------------------------------------
    st = StateTag('st', 'X', [0 1 2], 'Y', {'a', 'b', 'c'});
    sSt = st.getStats();
    assert(sSt.N == 3,                            'state N');                nTests = nTests + 1;
    assert(isnan(sSt.Mean),                       'state Mean NaN');         nTests = nTests + 1;
    assert(sSt.TimeStart == 0 && sSt.TimeEnd == 2, 'state time bounds');     nTests = nTests + 1;
    TagRegistry.clear();

    fprintf('    All %d tests passed.\n', nTests);
end

function add_tag_analysis_path_()
    %ADD_TAG_ANALYSIS_PATH_ Ensure repo root + tests/suite are on the path.
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    addpath(fullfile(here, 'suite'));
    install();
end
