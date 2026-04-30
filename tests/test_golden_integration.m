% DO NOT REWRITE — golden test, see PROJECT.md
function test_golden_integration()
% GOLDEN INTEGRATION TEST -- v2.0 Tag API (rewritten from legacy Sensor API in Phase 1011).
%
% Regression guard for the Tag-based domain model.  Exercises the full
% SensorTag -> MonitorTag -> CompositeTag -> EventStore -> FastSense
% pipeline with the same fixture data and equivalent assertion semantics
% as the original Phase 1003 legacy test.
%
% See also SensorTag, MonitorTag, CompositeTag, EventStore, FastSense.

    add_golden_path();
    TagRegistry.clear();
    EventBinding.clear();

    % ===== Fixture: synthetic sensor crossing threshold twice =====
    % Same Y pattern as the legacy test — violations at indices 4-7
    % (Y=12,14,16,14) and 13-15 (Y=18,20,22).
    X = 1:20;
    Y = [5 5 5 12 14 16 14 5 5 5 5 5 18 20 22 5 5 5 5 5];
    st = SensorTag('press_a', 'Name', 'Pressure A', 'Units', 'bar', ...
        'X', X, 'Y', Y);

    % MonitorTag: condition y > 10 (equivalent to legacy Threshold
    % 'press_hi' with Direction='upper', Value=10, machine=1 everywhere).
    es = EventStore('');
    mon = MonitorTag('press_hi', st, @(x, y) y > 10, 'EventStore', es);

    % ===== Golden assertion 1: violations exist =====
    % (was: s.countViolations() > 0)
    [~, my] = mon.getXY();
    assert(any(my == 1), 'golden: violations detected');

    % ===== Golden assertion 2: event detection (2 events, matching timing + peaks) =====
    % (was: events = detectEventsFromSensor(s) -> 2 events)
    events = es.getEvents();
    assert(numel(events) == 2, 'golden: two events detected');
    assert(events(1).StartTime == 4,  'golden: event1 start');
    assert(events(1).EndTime   == 7,  'golden: event1 end');
    % Peak values from raw sensor data within event windows
    [sx, sy] = st.getXY();
    mask1 = sx >= events(1).StartTime & sx <= events(1).EndTime;
    assert(max(sy(mask1)) == 16, 'golden: event1 peak');
    assert(events(2).StartTime == 13, 'golden: event2 start');
    mask2 = sx >= events(2).StartTime & sx <= events(2).EndTime;
    assert(max(sy(mask2)) == 22, 'golden: event2 peak');

    % ===== Golden assertion 3: debounced detection =====
    % MinDuration=3: event1 duration=3 (7-4) >= 3 kept; event2 duration=2 (15-13) < 3 filtered.
    % (was: det = EventDetector('MinDuration', 3); detectEventsFromSensor -> 1 event)
    es2 = EventStore('');
    monLong = MonitorTag('press_hi_debounce', st, @(x, y) y > 10, ...
        'MinDuration', 3, 'EventStore', es2);
    monLong.getXY();  % trigger computation + event emission
    eventsLong = es2.getEvents();
    assert(numel(eventsLong) == 1, 'golden: debounce keeps only longer event');
    assert(eventsLong(1).StartTime == 4, 'golden: debounce kept first event');

    % ===== Golden assertion 4: CompositeTag AND aggregation =====
    % Legacy: CompositeThreshold AND(alarm=15>10, ok=50<80) -> 'alarm'.
    % Tag API: CompositeTag AND returns 1 when ALL children are 1.
    % At t=4, Y(4)=12: mon (y>10) is 1, mon2 (y>5) is 1.  AND(1,1) = 1.
    mon2 = MonitorTag('press_lo', st, @(x, y) y > 5);
    comp = CompositeTag('pump_a_health', 'and');
    comp.addChild(mon);
    comp.addChild(mon2);
    status = comp.valueAt(4);
    assert(status == 1, ...
        sprintf('golden: AND mode both active -> alarm (got %g)', status));

    % ===== Golden assertion 5: FastSense addTag wiring =====
    % (was: fp.addSensor(s) -> 1 line)
    fp = FastSense();
    fp.addTag(st);
    assert(numel(fp.Lines) == 1, 'golden: one line after addTag');

    TagRegistry.clear();
    EventBinding.clear();
    fprintf('    All 9 golden_integration tests passed.\n');
end

function add_golden_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root);
    install();
end
