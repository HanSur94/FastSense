function runFilterMachinesTests()
%RUNFILTERMACHINESTESTS Execute unit tests for the filterMachines helper.
%   Called by tests/test_machine_selector_pane.m. Lives here (inside
%   libs/FastSenseCompanion) so that MATLAB's private-directory mechanism
%   makes filterMachines visible (private functions are accessible to
%   callers in the same folder). Mirrors runFilterTagsTests.
%
%   Covers MACH-01: filterMachines(machines, term) pure substring logic
%   over Machine Name + Id. Octave-safe (no uifigure, no contains).
%
%   See also filterMachines, MachineSelectorPane, runFilterTagsTests.

    nPassed = 0;

    % --- Build Machine stubs via the real constructor (Octave-safe) ---
    m1 = Machine('Id', 'M01', 'Name', 'Press Line 3', 'Group', 'Presses');
    m2 = Machine('Id', 'M02', 'Name', 'Pump Station 1');
    machines = {m1, m2};

    % (a) empty term returns all machines, order preserved
    r = filterMachines(machines, '');
    assert(numel(r) == 2, 'filterMachines: empty term must return all machines (MACH-01)');
    assert(r{1} == m1 && r{2} == m2, 'filterMachines: empty term must preserve insertion order');
    nPassed = nPassed + 1;

    % (b) term matches by Name (case-insensitive)
    r = filterMachines(machines, 'press');
    assert(numel(r) == 1 && r{1} == m1, ...
        'filterMachines: ''press'' must match Press Line 3 by Name (case-insensitive) (MACH-01)');
    nPassed = nPassed + 1;

    % (c) term matches by Id (case-insensitive on both cases)
    r = filterMachines(machines, 'M02');
    assert(numel(r) == 1 && r{1} == m2, ...
        'filterMachines: ''M02'' must match by Id');
    r = filterMachines(machines, 'm02');
    assert(numel(r) == 1 && r{1} == m2, ...
        'filterMachines: ''m02'' must match by Id (case-insensitive) (MACH-01)');
    nPassed = nPassed + 1;

    % (d) no match returns empty
    r = filterMachines(machines, 'zzz');
    assert(isempty(r) && iscell(r), 'filterMachines: no match must return {} (MACH-01)');
    nPassed = nPassed + 1;

    % (e) empty machinesCell returns empty
    r = filterMachines({}, 'x');
    assert(isempty(r) && iscell(r), 'filterMachines: empty input must return {}');
    nPassed = nPassed + 1;

    fprintf('    All %d tests passed.\n', nPassed);
end
