function test_tag_manual_event()
    %TEST_TAG_MANUAL_EVENT Tests for Tag.addManualEvent + eventsAttached.
    add_tag_manual_event_path();

    nPassed = 0;
    nFailed = 0;

    % --- Test 1: addManualEvent creates event with correct Category ---
    try
        EventBinding.clear();
        es = EventStore('');
        st = SensorTag('temp_a', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        st.EventStore = es;
        st.addManualEvent(10, 20, 'test_label', 'test_message');
        events = es.getEvents();
        assert(numel(events) == 1, 'Expected 1 event, got %d', numel(events));
        assert(strcmp(events(1).Category, 'manual_annotation'), ...
            'Expected Category=manual_annotation, got %s', events(1).Category);
        assert(~isempty(events(1).TagKeys), 'TagKeys should not be empty');
        assert(any(strcmp('temp_a', events(1).TagKeys)), ...
            'TagKeys should contain temp_a');
        nPassed = nPassed + 1;
        fprintf('    PASS: addManualEvent creates event with Category=manual_annotation\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: addManualEvent creates event with Category=manual_annotation: %s\n', e.message);
    end

    % --- Test 2: eventsAttached returns event via EventBinding query ---
    try
        EventBinding.clear();
        es = EventStore('');
        st = SensorTag('press_b', 'X', 1:50, 'Y', rand(1, 50));
        st.EventStore = es;
        st.addManualEvent(5, 15, 'annotation_1', '');
        attached = st.eventsAttached();
        assert(numel(attached) == 1, 'Expected 1 attached event, got %d', numel(attached));
        assert(strcmp(attached(1).Category, 'manual_annotation'), ...
            'Attached event should have Category=manual_annotation');
        nPassed = nPassed + 1;
        fprintf('    PASS: eventsAttached returns event via EventBinding query\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: eventsAttached returns event via EventBinding query: %s\n', e.message);
    end

    % --- Test 3: addManualEvent without EventStore throws Tag:noEventStore ---
    try
        EventBinding.clear();
        st = SensorTag('no_es', 'X', 1:10, 'Y', ones(1, 10));
        threw = false;
        try
            st.addManualEvent(1, 5, 'lbl', 'msg');
        catch err
            threw = strcmp(err.identifier, 'Tag:noEventStore');
        end
        assert(threw, 'Expected Tag:noEventStore error');
        nPassed = nPassed + 1;
        fprintf('    PASS: addManualEvent without EventStore throws Tag:noEventStore\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: addManualEvent without EventStore throws Tag:noEventStore: %s\n', e.message);
    end

    % --- Test 4: eventsAttached with no EventStore returns [] ---
    try
        EventBinding.clear();
        st = SensorTag('empty_es', 'X', 1:10, 'Y', ones(1, 10));
        attached = st.eventsAttached();
        assert(isempty(attached), 'Expected empty, got %d events', numel(attached));
        nPassed = nPassed + 1;
        fprintf('    PASS: eventsAttached with no EventStore returns []\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: eventsAttached with no EventStore returns []: %s\n', e.message);
    end

    % --- Test 5: MonitorTag inherits EventStore from Tag ---
    try
        EventBinding.clear();
        parent = SensorTag('parent_s', 'X', 1:100, 'Y', sin((1:100)/10)*30 + 40);
        es = EventStore('');
        m = MonitorTag('mon_a', parent, @(x, y) y > 50, 'EventStore', es);
        assert(~isempty(m.EventStore), 'MonitorTag should have EventStore from constructor');
        assert(isa(m.EventStore, 'EventStore'), 'MonitorTag.EventStore should be EventStore');
        nPassed = nPassed + 1;
        fprintf('    PASS: MonitorTag inherits EventStore from Tag\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: MonitorTag inherits EventStore from Tag: %s\n', e.message);
    end

    % --- Test 6: EventBinding entry created by addManualEvent ---
    try
        EventBinding.clear();
        es = EventStore('');
        st = SensorTag('bind_check', 'X', 1:20, 'Y', ones(1, 20));
        st.EventStore = es;
        st.addManualEvent(3, 7, 'ev_label', '');
        events = es.getEvents();
        keys = EventBinding.getTagKeysForEvent(events(1).Id);
        assert(any(strcmp('bind_check', keys)), ...
            'EventBinding should contain tag key bind_check');
        nPassed = nPassed + 1;
        fprintf('    PASS: EventBinding entry created by addManualEvent\n');
    catch e
        nFailed = nFailed + 1;
        fprintf('    FAIL: EventBinding entry created by addManualEvent: %s\n', e.message);
    end

    fprintf('    %d/%d tests passed.\n', nPassed, nPassed + nFailed);
    if nFailed > 0
        error('test_tag_manual_event:failed', '%d tests failed.', nFailed);
    end
end

function add_tag_manual_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    rootDir = fileparts(thisDir);
    cwd = pwd;
    cd(rootDir);
    install();
    cd(cwd);
end
