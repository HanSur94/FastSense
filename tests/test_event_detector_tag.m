function test_event_detector_tag()
%TEST_EVENT_DETECTOR_TAG Octave flat tests for EventDetector Tag overload.
%   Phase 1009 Plan 03 — mirror of TestEventDetectorTag for Octave.
%
%   See also TestEventDetectorTag, EventDetector, makePhase1009Fixtures.

    add_event_detector_tag_path();

    TagRegistry.clear();
    cleanup_on_exit_ = onCleanup(@() TagRegistry.clear());

    test_tag_overload_detects_events();
    test_legacy_six_arg_unchanged();
    test_non_tag_non_sensor_errors();
    test_tag_overload_with_empty_tag();
    test_pitfall1_no_subclass_isa_in_detect();
    test_legacy_callers_still_work();

    fprintf('    All 6 event_detector_tag tests passed.\n');
end

function add_event_detector_tag_path()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests', 'suite'));
end

function test_tag_overload_detects_events()
    TagRegistry.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_a');
    thr = Threshold('warn', 'Name', 'Warn', 'Direction', 'upper');
    thr.addCondition(struct(), 10);

    det = EventDetector();
    events = det.detect(st, thr);

    assert(numel(events) == 2, ...
        sprintf('Tag overload should yield 2 events, got %d', numel(events)));
    assert(events(1).StartTime == 4, 'e1 start');
    assert(events(1).EndTime   == 7, 'e1 end');
    assert(events(2).StartTime == 13, 'e2 start');
    assert(events(2).EndTime   == 15, 'e2 end');
    assert(strcmp(events(1).SensorName, 'press_a'), 'SensorName carrier');
    assert(strcmp(events(1).ThresholdLabel, 'Warn'), 'ThresholdLabel carrier');
    assert(events(1).ThresholdValue == 10, 'ThresholdValue');
    assert(strcmp(events(1).Direction, 'upper'), 'Direction');
end

function test_legacy_six_arg_unchanged()
    det = EventDetector();
    t      = [1 2 3 4 5 6 7 8 9 10];
    values = [12 13 5 5 5 14 15 5 5 5];
    events = det.detect(t, values, 10, 'upper', 'warn', 'temp');
    assert(numel(events) == 2, 'legacy 6-arg: count');
    assert(events(1).StartTime == 1, 'legacy 6-arg: e1 start');
    assert(events(2).StartTime == 6, 'legacy 6-arg: e2 start');
    assert(strcmp(events(1).SensorName, 'temp'), 'legacy 6-arg: SensorName');
    assert(strcmp(events(1).ThresholdLabel, 'warn'), 'legacy 6-arg: ThresholdLabel');
end

function test_non_tag_non_sensor_errors()
    det = EventDetector();
    threw = false;
    try
        det.detect(42, 'foo');  %#ok<NASGU>
    catch
        threw = true;
    end
    assert(threw, 'malformed input must raise');
end

function test_tag_overload_with_empty_tag()
    TagRegistry.clear();
    st = SensorTag('empty_tag', 'X', [], 'Y', []);
    TagRegistry.register('empty_tag', st);
    thr = Threshold('warn', 'Name', 'Warn', 'Direction', 'upper');
    thr.addCondition(struct(), 10);

    det = EventDetector();
    events = det.detect(st, thr);
    assert(isempty(events), 'empty Tag => empty events');
end

function test_pitfall1_no_subclass_isa_in_detect()
    here = fileparts(mfilename('fullpath'));
    detectorFile = fullfile(here, '..', 'libs', 'EventDetection', 'EventDetector.m');
    src = fileread(detectorFile);
    badKinds = {'SensorTag', 'MonitorTag', 'StateTag', 'CompositeTag'};
    for i = 1:numel(badKinds)
        pat = ['isa\([^,]+,\s*''', badKinds{i}, ''''];
        m   = regexp(src, pat, 'once');
        assert(isempty(m), ...
            sprintf('Pitfall 1 violation: isa(..,''%s'') in EventDetector.m', ...
                badKinds{i}));
    end
end

function test_legacy_callers_still_work()
    s = Sensor('temp');
    s.X = [1 2 3 4 5 6 7 8 9 10];
    s.Y = [12 13 5 5 5 14 15 5 5 5];
    thr = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    thr.addCondition(struct(), 10);
    s.addThreshold(thr);
    s.resolve();

    det = EventDetector();
    events = detectEventsFromSensor(s, det);
    assert(numel(events) == 2, 'bridge helper preserved');
end
