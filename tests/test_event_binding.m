function test_event_binding()
%TEST_EVENT_BINDING Unit tests for EventBinding singleton registry.

    add_event_binding_path();

    % testAttachAndGetTagKeys
    EventBinding.clear();
    EventBinding.attach('evt_1', 'sensor_a');
    keys = EventBinding.getTagKeysForEvent('evt_1');
    assert(iscell(keys), 'attach: returns cell');
    assert(numel(keys) == 1, 'attach: one key');
    assert(strcmp(keys{1}, 'sensor_a'), 'attach: correct key');

    % testAttachMultipleTagsToOneEvent
    EventBinding.clear();
    EventBinding.attach('evt_1', 'sensor_a');
    EventBinding.attach('evt_1', 'monitor_b');
    keys = EventBinding.getTagKeysForEvent('evt_1');
    assert(numel(keys) == 2, 'multiTag: two keys');
    assert(any(strcmp('sensor_a', keys)), 'multiTag: has sensor_a');
    assert(any(strcmp('monitor_b', keys)), 'multiTag: has monitor_b');

    % testAttachIdempotent
    EventBinding.clear();
    EventBinding.attach('evt_1', 'sensor_a');
    EventBinding.attach('evt_1', 'sensor_a');
    keys = EventBinding.getTagKeysForEvent('evt_1');
    assert(numel(keys) == 1, 'idempotent: still one key');

    % testGetTagKeysForUnknownEvent
    EventBinding.clear();
    keys = EventBinding.getTagKeysForEvent('evt_999');
    assert(iscell(keys), 'unknown: returns cell');
    assert(isempty(keys), 'unknown: empty cell');

    % testGetEventsForTag
    EventBinding.clear();
    store = EventStore('');
    ev1 = Event(1, 2, 'sens', 'thr', 10, 'upper');
    ev2 = Event(3, 4, 'sens', 'thr', 10, 'upper');
    store.append(ev1);
    store.append(ev2);
    EventBinding.attach(ev1.Id, 'tag_a');
    EventBinding.attach(ev2.Id, 'tag_a');
    EventBinding.attach(ev1.Id, 'tag_b');
    result = EventBinding.getEventsForTag('tag_a', store);
    assert(numel(result) == 2, 'getEventsForTag: two events for tag_a');
    result_b = EventBinding.getEventsForTag('tag_b', store);
    assert(numel(result_b) == 1, 'getEventsForTag: one event for tag_b');

    % testClearResetsAll
    EventBinding.clear();
    EventBinding.attach('evt_1', 'sensor_a');
    EventBinding.clear();
    keys = EventBinding.getTagKeysForEvent('evt_1');
    assert(isempty(keys), 'clear: resets all bindings');

    % testEmptyIdGuard
    EventBinding.clear();
    threw = false;
    try
        EventBinding.attach('', 'sensor_a');
    catch e
        threw = true;
        assert(~isempty(strfind(e.identifier, 'emptyId')), 'emptyId: correct error id');
    end
    assert(threw, 'emptyId: should throw on empty eventId');

    fprintf('    All 7 event_binding tests passed.\n');
end

function add_event_binding_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
