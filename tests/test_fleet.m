function test_fleet()
%TEST_FLEET Octave flat-style coverage for Fleet (FLEET-04/FLEET-06 critical paths).
%   Covers: JSON save/load round-trip on Octave (FLEET-04),
%           fleetConfigVersion:1 present in saved JSON (FLEET-04),
%           filterByName / filterByGroup return expected subsets (FLEET-06).
%
%   All tests are RED until Plan 04 delivers libs/Fleet/Fleet.m.
%   Uses SensorTag (Octave-safe) for catalog content; no suite-only mocks.
%
%   See also TestFleet, test_machine.

    add_fleet_path_();
    TagRegistry.clear();

    tmp = tempname();
    if exist(tmp, 'dir') ~= 7; mkdir(tmp); end
    jsonPath = fullfile(tmp, 'fleet.json');

    % --- FLEET-04: save a 2-machine fleet, load, assert round-trip ---
    fleet = Fleet();
    fleet.addMachine('Id', 'M01', 'Name', 'Alpha', 'DataRoot', tmp, 'Group', 'pumps');
    fleet.addMachine('Id', 'M02', 'Name', 'Beta',  'DataRoot', tmp, 'Group', 'motors');
    fleet.save(jsonPath);

    fleet2 = Fleet.load(jsonPath);
    assert(fleet2.machineCount() == 2, ...
        'test_fleet: machineCount must be 2 after round-trip (FLEET-04)');
    assert(strcmp(fleet2.getMachine('M01').Name, 'Alpha'), ...
        'test_fleet: M01 Name must be Alpha after round-trip');
    assert(strcmp(fleet2.getMachine('M02').Name, 'Beta'), ...
        'test_fleet: M02 Name must be Beta after round-trip');

    % --- FLEET-04: fleetConfigVersion:1 must appear in saved JSON ---
    fid = fopen(jsonPath, 'r');
    raw = fread(fid, '*char')';
    fclose(fid);
    assert(~isempty(strfind(raw, '"fleetConfigVersion":1')), ...
        'test_fleet: saved JSON must contain "fleetConfigVersion":1 (FLEET-04)');

    % --- FLEET-06: filterByName case-insensitive substring match ---
    fleet3 = Fleet();
    fleet3.addMachine('Id', 'A1', 'Name', 'Pump Station Alpha', 'Group', 'pumps');
    fleet3.addMachine('Id', 'A2', 'Name', 'Pump Station Beta',  'Group', 'pumps');
    fleet3.addMachine('Id', 'A3', 'Name', 'Compressor One',     'Group', 'motors');

    byPump = fleet3.filterByName('pump');
    assert(numel(byPump) == 2, ...
        'test_fleet: filterByName(pump) must return 2 machines (FLEET-06)');

    byComp = fleet3.filterByName('compressor');
    assert(numel(byComp) == 1, ...
        'test_fleet: filterByName(compressor) must return 1 machine');

    % --- FLEET-06: filterByGroup case-insensitive ---
    byPumps = fleet3.filterByGroup('pumps');
    assert(numel(byPumps) == 2, ...
        'test_fleet: filterByGroup(pumps) must return 2 machines (FLEET-06)');

    byMotors = fleet3.filterByGroup('MOTORS');
    assert(numel(byMotors) == 1, ...
        'test_fleet: filterByGroup(MOTORS) must return 1 machine (case-insensitive)');

    % --- MACH-01: machineIds() preserves insertion order (NOT alphabetical) ---
    fleet4 = Fleet();
    fleet4.addMachine('Id', 'M03', 'Name', 'Press Line 3', 'Group', 'presses');
    fleet4.addMachine('Id', 'M01', 'Name', 'Pump Station 1', 'Group', 'pumps');
    fleet4.addMachine('Id', 'M02', 'Name', 'Motor A',        'Group', 'motors');
    ids = fleet4.machineIds();
    assert(isequal(ids, {'M03', 'M01', 'M02'}), ...
        'test_fleet: machineIds() must preserve insertion order M03,M01,M02 (not alphabetical) (MACH-01)');

    TagRegistry.clear();
    fprintf('    All 6 tests passed.\n');
end

function add_fleet_path_()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
end
