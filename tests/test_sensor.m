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

    % testAddThreshold — attach Threshold object
    s = Sensor('pressure');
    t = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
    t.addCondition(struct('machine', 1), 50);
    s.addThreshold(t);
    assert(numel(s.Thresholds) == 1, 'testAddThreshold: count');
    assert(strcmp(s.Thresholds{1}.Key, 'hh'), 'testAddThreshold: key');
    assert(s.Thresholds{1}.conditions_{1}.Value == 50, 'testAddThreshold: value');
    assert(strcmp(s.Thresholds{1}.Name, 'HH'), 'testAddThreshold: name');

    % testAddThresholdMultiple
    s = Sensor('pressure');
    t1 = Threshold('hh', 'Direction', 'upper');
    t1.addCondition(struct('m', 1), 50);
    t2 = Threshold('h', 'Direction', 'upper');
    t2.addCondition(struct('m', 2), 80);
    t3 = Threshold('ll', 'Direction', 'lower');
    t3.addCondition(struct('m', 1), 10);
    s.addThreshold(t1);
    s.addThreshold(t2);
    s.addThreshold(t3);
    assert(numel(s.Thresholds) == 3, 'testMultipleThresholds: count');

    % testAddThresholdDuplicate — warns and does not add
    s = Sensor('pressure');
    td = Threshold('dup', 'Direction', 'upper');
    td.addCondition(struct(), 50);
    s.addThreshold(td);
    warning('off', 'Sensor:duplicateThreshold');
    s.addThreshold(td);
    warning('on', 'Sensor:duplicateThreshold');
    assert(numel(s.Thresholds) == 1, 'testDuplicate: count unchanged');

    % testRemoveThreshold
    s = Sensor('pressure');
    tr1 = Threshold('hh', 'Direction', 'upper');
    tr1.addCondition(struct(), 50);
    tr2 = Threshold('ll', 'Direction', 'lower');
    tr2.addCondition(struct(), 10);
    s.addThreshold(tr1);
    s.addThreshold(tr2);
    assert(numel(s.Thresholds) == 2, 'testRemove: before');
    s.removeThreshold('hh');
    assert(numel(s.Thresholds) == 1, 'testRemove: after');
    assert(strcmp(s.Thresholds{1}.Key, 'll'), 'testRemove: remaining key');

    % testAddThresholdByKey — registry lookup
    tk = Threshold('press_hh_octave', 'Direction', 'upper');
    tk.addCondition(struct(), 75);
    ThresholdRegistry.register('press_hh_octave', tk);
    s = Sensor('pressure');
    s.addThreshold('press_hh_octave');
    assert(numel(s.Thresholds) == 1, 'testByKey: count');
    assert(strcmp(s.Thresholds{1}.Key, 'press_hh_octave'), 'testByKey: key');
    ThresholdRegistry.unregister('press_hh_octave');

    fprintf('    All 8 sensor tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
