function test_add_sensor()
%TEST_ADD_SENSOR Tests for FastPlot.addSensor() integration.

    add_sensor_path();

    % testAddSensorBasic — adds a line from sensor data
    s = Sensor('pressure', 'Name', 'Chamber Pressure');
    s.X = 1:100;
    s.Y = rand(1, 100) * 10;
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s);
    assert(numel(fp.Lines) == 1, 'testBasic: one line added');
    assert(strcmp(fp.Lines(1).Options.DisplayName, 'Chamber Pressure'), 'testBasic: display name');

    % testAddSensorWithThresholds
    s = Sensor('pressure', 'Name', 'Pressure');
    s.X = 1:100;
    s.Y = [ones(1,50)*5, ones(1,50)*15];

    sc = StateChannel('machine');
    sc.X = [1 50]; sc.Y = [0 1];
    s.addStateChannel(sc);
    s.addThresholdRule(struct('machine', 1), 10, 'Direction', 'upper', 'Label', 'HH');
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s, 'ShowThresholds', true);
    assert(numel(fp.Lines) >= 2, 'testWithThresholds: line + threshold line(s)');

    % testAddSensorNoThresholds — ShowThresholds false
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:50;
    s.Y = rand(1, 50);
    s.addThresholdRule(struct(), 5, 'Direction', 'upper');
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s, 'ShowThresholds', false);
    assert(numel(fp.Lines) == 1, 'testNoThresholds: only data line');

    % testAddSensorUsesKeyAsFallbackName
    s = Sensor('flow_rate');
    s.X = 1:10;
    s.Y = rand(1, 10);
    s.resolve();

    fp = FastPlot();
    fp.addSensor(s);
    assert(strcmp(fp.Lines(1).Options.DisplayName, 'flow_rate'), 'testFallbackName: uses Key');

    fprintf('    All 4 add_sensor tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    run(fullfile(repo_root, 'setup.m'));
end
