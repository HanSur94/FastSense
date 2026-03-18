function test_state_channel()
%TEST_STATE_CHANNEL Tests for StateChannel class.

    add_sensor_path();

    % testConstructorDefaults
    sc = StateChannel('machine_state', 'MatFile', 'data/states.mat');
    assert(strcmp(sc.Key, 'machine_state'), 'testConstructor: Key');
    assert(strcmp(sc.MatFile, 'data/states.mat'), 'testConstructor: MatFile');
    assert(strcmp(sc.KeyName, 'machine_state'), 'testConstructor: KeyName defaults to Key');

    % testConstructorCustomKeyName
    sc = StateChannel('ms', 'MatFile', 'data/states.mat', 'KeyName', 'machine_state');
    assert(strcmp(sc.Key, 'ms'), 'testCustomKeyName: Key');
    assert(strcmp(sc.KeyName, 'machine_state'), 'testCustomKeyName: KeyName');

    % testValueAtNumeric — zero-order hold with numeric states
    sc = StateChannel('state');
    sc.X = [1 5 10 20];
    sc.Y = [0 1 2 3];
    assert(sc.valueAt(0) == 0, 'testValueAt: before first -> first value');
    assert(sc.valueAt(1) == 0, 'testValueAt: at first timestamp');
    assert(sc.valueAt(3) == 0, 'testValueAt: between 1 and 5');
    assert(sc.valueAt(5) == 1, 'testValueAt: at second timestamp');
    assert(sc.valueAt(7) == 1, 'testValueAt: between 5 and 10');
    assert(sc.valueAt(15) == 2, 'testValueAt: between 10 and 20');
    assert(sc.valueAt(100) == 3, 'testValueAt: after last');

    % testValueAtString — zero-order hold with cell string states
    sc = StateChannel('mode');
    sc.X = [1 5 10];
    sc.Y = {'off', 'running', 'evacuated'};
    assert(strcmp(sc.valueAt(3), 'off'), 'testValueAtString: before change');
    assert(strcmp(sc.valueAt(7), 'running'), 'testValueAtString: after change');
    assert(strcmp(sc.valueAt(15), 'evacuated'), 'testValueAtString: last');

    % testValueAtBulk — vectorized lookup
    sc = StateChannel('state');
    sc.X = [1 5 10];
    sc.Y = [0 1 2];
    vals = sc.valueAt([0 3 5 7 15]);
    assert(isequal(vals, [0 0 1 1 2]), 'testValueAtBulk');

    fprintf('    All 5 state_channel tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); setup();
end
