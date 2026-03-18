function test_sensor()
%TEST_SENSOR Tests for Sensor class.

    add_sensor_path();

    % testConstructorDefaults
    s = Sensor('pressure');
    assert(strcmp(s.Key, 'pressure'), 'testConstructor: Key');
    assert(strcmp(s.KeyName, 'pressure'), 'testConstructor: KeyName defaults to Key');
    assert(isempty(s.Name), 'testConstructor: Name default');
    assert(isempty(s.ID), 'testConstructor: ID default');
    assert(isempty(s.X), 'testConstructor: X default');
    assert(isempty(s.Y), 'testConstructor: Y default');

    % testConstructorWithOptions
    s = Sensor('pressure', 'Name', 'Chamber Pressure', 'ID', 101, ...
        'MatFile', 'data.mat', 'KeyName', 'press_ch1', ...
        'Source', 'raw/pressure.dta');
    assert(strcmp(s.Name, 'Chamber Pressure'), 'testOptions: Name');
    assert(s.ID == 101, 'testOptions: ID');
    assert(strcmp(s.MatFile, 'data.mat'), 'testOptions: MatFile');
    assert(strcmp(s.KeyName, 'press_ch1'), 'testOptions: KeyName');
    assert(strcmp(s.Source, 'raw/pressure.dta'), 'testOptions: Source');

    % testAddStateChannel
    s = Sensor('pressure');
    sc = StateChannel('machine_state');
    sc.X = [1 5 10]; sc.Y = [0 1 2];
    s.addStateChannel(sc);
    assert(numel(s.StateChannels) == 1, 'testAddStateChannel: count');
    assert(strcmp(s.StateChannels{1}.Key, 'machine_state'), 'testAddStateChannel: key');

    % testAddThresholdRule
    s = Sensor('pressure');
    s.addThresholdRule(struct('machine', 1), 50, 'Direction', 'upper', 'Label', 'HH');
    assert(numel(s.ThresholdRules) == 1, 'testAddThresholdRule: count');
    assert(s.ThresholdRules{1}.Value == 50, 'testAddThresholdRule: value');
    assert(strcmp(s.ThresholdRules{1}.Label, 'HH'), 'testAddThresholdRule: label');

    % testAddMultipleRules
    s = Sensor('pressure');
    s.addThresholdRule(struct('m', 1), 50, 'Direction', 'upper');
    s.addThresholdRule(struct('m', 2), 80, 'Direction', 'upper');
    s.addThresholdRule(struct('m', 1), 10, 'Direction', 'lower');
    assert(numel(s.ThresholdRules) == 3, 'testMultipleRules: count');

    fprintf('    All 5 sensor tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); setup();
end
