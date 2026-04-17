function test_event_detector_tag()
%TEST_EVENT_DETECTOR_TAG Octave flat tests for EventDetector Tag-based detection.
%   Rewritten in Phase 1011 -- legacy Threshold/6-arg paths removed.
%
%   See also TestEventDetectorTag, EventDetector, makePhase1009Fixtures.

    add_event_detector_tag_path();

    TagRegistry.clear();
    EventBinding.clear();
    cleanup_on_exit_ = onCleanup(@() cleanup_registries()); %#ok<NASGU>

    test_tag_overload_detects_events();
    test_non_tag_errors();
    test_tag_overload_with_empty_tag();
    test_pitfall1_no_subclass_isa_in_detect();

    fprintf('    All 4 event_detector_tag tests passed.\n');
end

function add_event_detector_tag_path()
    here = fileparts(mfilename('fullpath'));
    repo = fileparts(here);
    addpath(repo);
    install();
    addpath(fullfile(repo, 'tests', 'suite'));
end

function cleanup_registries()
    TagRegistry.clear();
    EventBinding.clear();
end

function test_tag_overload_detects_events()
    TagRegistry.clear(); EventBinding.clear();
    st = makePhase1009Fixtures.makeSensorTag('press_a');
    es = EventStore('');
    mon = MonitorTag('warn', st, @(x, y) y > 10, 'EventStore', es);
    mon.getXY();
    events = es.getEvents();

    assert(numel(events) == 2, ...
        sprintf('Tag MonitorTag should yield 2 events, got %d', numel(events)));
    assert(events(1).StartTime == 4, 'e1 start');
    assert(events(1).EndTime   == 7, 'e1 end');
    assert(events(2).StartTime == 13, 'e2 start');
    assert(events(2).EndTime   == 15, 'e2 end');
    assert(strcmp(events(1).SensorName, 'press_a'), 'SensorName carrier');
    assert(strcmp(events(1).ThresholdLabel, 'warn'), 'ThresholdLabel carrier');
end

function test_non_tag_errors()
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
    TagRegistry.clear(); EventBinding.clear();
    st = SensorTag('empty_tag', 'X', [], 'Y', []);
    TagRegistry.register('empty_tag', st);
    es = EventStore('');
    mon = MonitorTag('warn_empty', st, @(x, y) y > 10, 'EventStore', es);
    mon.getXY();
    assert(isempty(es.getEvents()), 'empty Tag => empty events');
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
