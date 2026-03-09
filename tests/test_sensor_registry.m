function test_sensor_registry()
%TEST_SENSOR_REGISTRY Tests for SensorRegistry class.

    add_sensor_path();

    % testGetReturnsASensor
    s = SensorRegistry.get('pressure');
    assert(isa(s, 'Sensor'), 'testGet: returns Sensor');
    assert(strcmp(s.Key, 'pressure'), 'testGet: correct key');

    % testGetUnknownKeyThrows
    threw = false;
    try
        SensorRegistry.get('nonexistent_sensor_xyz');
    catch
        threw = true;
    end
    assert(threw, 'testGetUnknown: should throw');

    % testGetMultiple
    sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
    assert(numel(sensors) == 2, 'testGetMultiple: count');
    assert(isa(sensors{1}, 'Sensor'), 'testGetMultiple: type 1');
    assert(isa(sensors{2}, 'Sensor'), 'testGetMultiple: type 2');

    % testList — should not error
    SensorRegistry.list();

    % testPrintTable — should not error
    SensorRegistry.printTable();

    % testViewer — should open and close without error
    hFig = SensorRegistry.viewer();
    assert(ishandle(hFig), 'testViewer: returns figure handle');
    close(hFig);

    fprintf('    All 6 sensor_registry tests passed.\n');
end

function add_sensor_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);setup();
end
