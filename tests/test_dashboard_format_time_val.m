function test_dashboard_format_time_val()
%TEST_DASHBOARD_FORMAT_TIME_VAL Regression tests for DashboardEngine.formatTimeVal.
%
%   Verifies that posix epoch seconds are correctly distinguished from MATLAB
%   datenums and raw numeric values.
%
%   Tests:
%     test_posix_2026_formats_as_2026  - posix seconds ~1.78e9 -> 2026-xx-xx string
%     test_datenum_formats_correctly   - MATLAB datenum(2026,...) -> 2026-04-23 string
%     test_raw_seconds_format          - small raw values use s/m/h/d suffixes
%     test_posix_boundary_year_2096    - posix ~4e9 (year 2096) -> 20xx-xx-xx string

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    passed = 0;
    failed = 0;
    failures = {};

    % DashboardEngine('Title','Fmt') — no render() needed; formatTimeVal is pure
    engine = DashboardEngine('Fmt');

    % ------------------------------------------------------------------
    % Test 2a: posix seconds for 2026 render as a 2026 date (not year > 3000)
    % 2026-04-23 12:00:00 UTC ≈ 1745409600; use 1777507200 (2026-06-XX)
    % ------------------------------------------------------------------
    try
        str = engine.formatTimeVal(1777507200);
        assert(~isempty(strfind(str, '2026-')), ...
            sprintf('expected 2026-xx-xx, got "%s"', str));
        % Guard against the bug: no year > 3000
        assert(isempty(regexp(str, '[3-9]\d{3}-', 'once')) && ...
               isempty(regexp(str, '\d{5,}', 'once')), ...
            sprintf('year must not be > 3000, got "%s"', str));
        passed = passed + 1;
        fprintf('    test_posix_2026_formats_as_2026: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_posix_2026_formats_as_2026: %s', ME.message);
        fprintf('    test_posix_2026_formats_as_2026: FAIL: %s\n', ME.message);
    end

    % ------------------------------------------------------------------
    % Test 2b: modern MATLAB datenum still formats correctly
    % ------------------------------------------------------------------
    try
        d = datenum(2026, 4, 23, 12, 0, 0);   % ~740060.5
        str = engine.formatTimeVal(d);
        assert(~isempty(strfind(str, '2026-04-23')), ...
            sprintf('expected 2026-04-23, got "%s"', str));
        passed = passed + 1;
        fprintf('    test_datenum_formats_correctly: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_datenum_formats_correctly: %s', ME.message);
        fprintf('    test_datenum_formats_correctly: FAIL: %s\n', ME.message);
    end

    % ------------------------------------------------------------------
    % Test 2c: small raw seconds use the "s/m/h/d" branch
    % ------------------------------------------------------------------
    try
        assert(strcmp(engine.formatTimeVal(5), '5.0 s'), ...
            sprintf('expected "5.0 s", got "%s"', engine.formatTimeVal(5)));
        assert(strcmp(engine.formatTimeVal(120), '2.0 m'), ...
            sprintf('expected "2.0 m", got "%s"', engine.formatTimeVal(120)));
        passed = passed + 1;
        fprintf('    test_raw_seconds_format: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_raw_seconds_format: %s', ME.message);
        fprintf('    test_raw_seconds_format: FAIL: %s\n', ME.message);
    end

    % ------------------------------------------------------------------
    % Test 2d: boundary at posix upper limit (5e9 ~ year 2128) still posix
    % ------------------------------------------------------------------
    try
        str = engine.formatTimeVal(4e9);  % year ~2096
        assert(~isempty(regexp(str, '^20\d\d-', 'once')), ...
            sprintf('expected 20xx-xx, got "%s"', str));
        passed = passed + 1;
        fprintf('    test_posix_boundary_year_2096: PASS\n');
    catch ME
        failed = failed + 1;
        failures{end+1} = sprintf('test_posix_boundary_year_2096: %s', ME.message);
        fprintf('    test_posix_boundary_year_2096: FAIL: %s\n', ME.message);
    end

    fprintf('\n    %d/%d tests passed.\n', passed, passed + failed);
    if failed > 0
        error('test_dashboard_format_time_val:failed', ...
            '%d test(s) failed:\n  %s', failed, strjoin(failures, '\n  '));
    end
end
