function runFilterDashboardsTests()
%RUNFILTERDASHBOARDSTESTS Test runner for filterDashboards (sibling-folder pattern).
%   Lives inside libs/FastSenseCompanion/private/ so MATLAB's private-folder
%   visibility makes filterDashboards reachable. Called by
%   tests/test_companion_filter_dashboards.m via add_companion_path().
%
%   Octave-compatible -- no uifigure, no DashboardEngine constructor required;
%   uses lightweight stub structs as engines (filterDashboards only reads .Name).
%   See also filterDashboards, runFilterTagsTests.

    nPassed = 0;

    % --- Stub engine factory (filterDashboards only reads .Name) ---
    mk = @(nm) struct('Name', nm);

    % Test 1: empty engines cell -> zeros(1,0)
    r = filterDashboards({}, '');
    assert(isequal(size(r), [1 0]), 'T1: empty engines must return zeros(1,0)');
    nPassed = nPassed + 1;

    % Test 2: one engine, empty searchTerm -> [1]
    r = filterDashboards({mk('Solo')}, '');
    assert(isequal(r, 1), 'T2: one engine, empty search must return [1]');
    nPassed = nPassed + 1;

    % Test 3: three engines, empty searchTerm -> [1 2 3]
    eng = {mk('Alpha'), mk('Beta'), mk('Gamma')};
    r = filterDashboards(eng, '');
    assert(isequal(r, [1 2 3]), 'T3: empty search must return all indices');
    nPassed = nPassed + 1;

    % Test 4: substring on Name (lowercase)
    r = filterDashboards(eng, 'beta');
    assert(isequal(r, 2), 'T4: substring match on Beta must return [2]');
    nPassed = nPassed + 1;

    % Test 5: case-insensitive
    r = filterDashboards(eng, 'BETA');
    assert(isequal(r, 2), 'T5: case-insensitive match must return [2]');
    nPassed = nPassed + 1;

    % Test 6: substring inside name
    r = filterDashboards(eng, 'amm');
    assert(isequal(r, 3), 'T6: substring amm must match Gamma at index 3');
    nPassed = nPassed + 1;

    % Test 7: no match -> zeros(1,0)
    r = filterDashboards(eng, 'xyzzy');
    assert(isequal(size(r), [1 0]), 'T7: no match must return zeros(1,0)');
    nPassed = nPassed + 1;

    % Test 8: ordering preserved across non-contiguous matches
    r = filterDashboards(eng, 'a');
    assert(isequal(r, [1 3]), 'T8: ordering must be preserved (Alpha=1, Gamma=3)');
    nPassed = nPassed + 1;

    % Test 9: engine with empty Name is NOT matched by non-empty search
    eng2 = {mk('Alpha'), mk(''), mk('Gamma')};
    r = filterDashboards(eng2, 'a');
    assert(isequal(r, [1 3]), 'T9: empty-Name engine must not match non-empty search');
    nPassed = nPassed + 1;

    % Test 10: engine with empty Name IS included on empty search
    r = filterDashboards(eng2, '');
    assert(isequal(r, [1 2 3]), 'T10: empty search includes all engines incl empty Name');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
