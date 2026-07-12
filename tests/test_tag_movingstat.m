function test_tag_movingstat()
%TEST_TAG_MOVINGSTAT Headless test for Tag.movingStat (#312).
%   mean/max/min/rms/std/median window stats, NaN handling, even windows,
%   and the continuous-only kind guard.
%
%   Run via the matlab MCP: install(); test_tag_movingstat()

    add_tag_analysis_path_();
    TagRegistry.clear();
    nTests = 0;

    t = SensorTag('s', 'X', 1:6, 'Y', [1 2 3 4 5 6]);

    % mean, window 3 (centered, shrinking at edges)
    [~, ym] = t.movingStat(3);
    assert(abs(ym(1) - 1.5) < 1e-9,   'mean edge i=1');    nTests = nTests + 1;
    assert(abs(ym(2) - 2) < 1e-9,     'mean i=2');         nTests = nTests + 1;
    assert(abs(ym(5) - 5) < 1e-9,     'mean i=5');         nTests = nTests + 1;
    assert(abs(ym(6) - 5.5) < 1e-9,   'mean edge i=6');    nTests = nTests + 1;

    % max / min, window 3
    [~, ymax] = t.movingStat(3, 'max');
    assert(abs(ymax(2) - 3) < 1e-9,   'max i=2');          nTests = nTests + 1;
    [~, ymin] = t.movingStat(3, 'min');
    assert(abs(ymin(5) - 4) < 1e-9,   'min i=5');          nTests = nTests + 1;

    % rms / std / median, window 3 at i=2 over [1 2 3]
    [~, yr] = t.movingStat(3, 'rms');
    assert(abs(yr(2) - sqrt(14/3)) < 1e-9, 'rms i=2');     nTests = nTests + 1;
    [~, ys] = t.movingStat(3, 'std');
    assert(abs(ys(2) - 1) < 1e-9,     'std i=2');          nTests = nTests + 1;
    [~, ymd] = t.movingStat(3, 'median');
    assert(abs(ymd(2) - 2) < 1e-9,    'median i=2');       nTests = nTests + 1;
    TagRegistry.clear();

    % NaN handling: excluded from the window
    t2 = SensorTag('s2', 'X', 1:6, 'Y', [1 NaN 3 4 5 6]);
    [~, yn] = t2.movingStat(3);
    assert(abs(yn(1) - 1) < 1e-9,     'nan i=1 -> [1]');   nTests = nTests + 1;
    assert(abs(yn(2) - 2) < 1e-9,     'nan i=2 -> mean[1,3]'); nTests = nTests + 1;
    TagRegistry.clear();

    % Even window: length preserved, sensible edge value
    t3 = SensorTag('s3', 'X', 1:6, 'Y', [1 2 3 4 5 6]);
    [~, ye] = t3.movingStat(2);
    assert(numel(ye) == 6,            'even window length'); nTests = nTests + 1;
    assert(abs(ye(1) - 1.5) < 1e-9,   'even window i=1');    nTests = nTests + 1;
    TagRegistry.clear();

    % Continuous-only guard: StateTag errors
    st = StateTag('st', 'X', 1:4, 'Y', [0 1 0 1]);
    threw = false;
    try
        st.movingStat(3);
    catch err
        threw = strcmp(err.identifier, 'Tag:movingStatNotContinuous');
    end
    assert(threw,                     'discrete kind guard');           nTests = nTests + 1;
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
