function test_event_config()
    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (known Octave classdef limitation)\n');
        return;
    end
%TEST_EVENT_CONFIG Tests for EventConfig configuration class.

    add_event_path();

    % testConstructorDefaults
    cfg = EventConfig();
    assert(isempty(cfg.Sensors), 'defaults: Sensors empty');
    assert(isempty(cfg.SensorData), 'defaults: SensorData empty');
    assert(cfg.MinDuration == 0, 'defaults: MinDuration');
    assert(cfg.MaxCallsPerEvent == 1, 'defaults: MaxCallsPerEvent');
    assert(isempty(cfg.OnEventStart), 'defaults: OnEventStart');
    assert(cfg.AutoOpenViewer == false, 'defaults: AutoOpenViewer');

    % testAddSensor
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    assert(numel(cfg.Sensors) == 1, 'addSensor: count');
    assert(numel(cfg.SensorData) == 1, 'addSensor: data count');
    assert(strcmp(cfg.SensorData(1).name, 'Temperature'), 'addSensor: data name');
    assert(isequal(cfg.SensorData(1).t, s.X), 'addSensor: data t');
    assert(isequal(cfg.SensorData(1).y, s.Y), 'addSensor: data y');

    % testSetColor
    cfg = EventConfig();
    cfg.setColor('warn', [1 0 0]);
    assert(isequal(cfg.ThresholdColors('warn'), [1 0 0]), 'setColor: stored');

    % testBuildDetector
    cfg = EventConfig();
    cfg.MinDuration = 5;
    cfg.MaxCallsPerEvent = 3;
    cfg.OnEventStart = @(e) disp(e);
    det = cfg.buildDetector();
    assert(isa(det, 'EventDetector'), 'buildDetector: class');
    assert(det.MinDuration == 5, 'buildDetector: MinDuration');
    assert(det.MaxCallsPerEvent == 3, 'buildDetector: MaxCallsPerEvent');
    assert(~isempty(det.OnEventStart), 'buildDetector: OnEventStart');

    % testRunDetection
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.addSensor(s);
    events = cfg.runDetection();
    assert(numel(events) >= 1, 'runDetection: found events');
    assert(strcmp(events(1).SensorName, 'Temperature'), 'runDetection: sensor name');

    % testEscalateSeverity
    cfg = EventConfig();
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 86 96 88 87 5 5 5 5];
    s.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'warn');
    s.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'critical');
    cfg.addSensor(s);
    events = cfg.runDetection();
    % The warning event should be escalated to critical because peak=96 > 95
    warnEvents = events(arrayfun(@(e) strcmp(e.ThresholdLabel, 'warn'), events));
    critEvents = events(arrayfun(@(e) strcmp(e.ThresholdLabel, 'critical'), events));
    assert(numel(critEvents) >= 1, 'escalate: critical event exists');
    assert(critEvents(1).PeakValue >= 95, 'escalate: peak above critical threshold');

    % testEscalateDisabled
    cfg2 = EventConfig();
    cfg2.EscalateSeverity = false;
    s2 = Sensor('temp', 'Name', 'Temperature');
    s2.X = 1:10;
    s2.Y = [5 5 86 96 88 87 5 5 5 5];
    s2.addThresholdRule(struct(), 85, 'Direction', 'upper', 'Label', 'warn');
    s2.addThresholdRule(struct(), 95, 'Direction', 'upper', 'Label', 'critical');
    cfg2.addSensor(s2);
    events2 = cfg2.runDetection();
    warnEvents2 = events2(arrayfun(@(e) strcmp(e.ThresholdLabel, 'warn'), events2));
    assert(numel(warnEvents2) >= 1, 'escalate disabled: warn event preserved');

    % testEscalateLowDirection
    cfg3 = EventConfig();
    s3 = Sensor('pres', 'Name', 'Pressure');
    s3.X = 1:10;
    s3.Y = [6 6 3.5 1.5 3.8 3.9 6 6 6 6];
    s3.addThresholdRule(struct(), 4, 'Direction', 'lower', 'Label', 'low');
    s3.addThresholdRule(struct(), 2, 'Direction', 'lower', 'Label', 'critical low');
    cfg3.addSensor(s3);
    events3 = cfg3.runDetection();
    critLow = events3(arrayfun(@(e) strcmp(e.ThresholdLabel, 'critical low'), events3));
    assert(numel(critLow) >= 1, 'escalate low: critical low event exists');
    assert(critLow(1).PeakValue <= 2, 'escalate low: peak below critical threshold');

    % testSaveViaEventStore
    tmpFile = fullfile(tempdir, 'test_cfg_store_save.mat');
    if exist(tmpFile, 'file'); delete(tmpFile); end
    cfg = EventConfig();
    cfg.EventFile = tmpFile;
    cfg.MaxBackups = 0;
    s = Sensor('temp', 'Name', 'Temperature');
    s.X = 1:10;
    s.Y = [5 5 12 14 11 13 5 5 5 5];
    s.addThresholdRule(struct(), 10, 'Direction', 'upper', 'Label', 'warn');
    cfg.setColor('warn', [1 0 0]);
    cfg.addSensor(s);
    events = cfg.runDetection();
    % File should exist and contain events, sensorData, thresholdColors, timestamp
    assert(exist(tmpFile, 'file') == 2, 'save: file exists');
    data = load(tmpFile);
    assert(isfield(data, 'events'), 'save: has events');
    assert(isfield(data, 'sensorData'), 'save: has sensorData');
    assert(isfield(data, 'thresholdColors'), 'save: has thresholdColors');
    assert(isfield(data, 'timestamp'), 'save: has timestamp');
    assert(numel(data.events) == numel(events), 'save: event count matches');
    delete(tmpFile);

    fprintf('    All 9 event_config tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
