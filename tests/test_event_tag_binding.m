function test_event_tag_binding()
%TEST_EVENT_TAG_BINDING Integration tests for Event.TagKeys + EventStore.eventsForTag.

    add_event_tag_binding_path();

    % testEventDefaultProperties
    EventBinding.clear();
    ev = Event(1, 2, 'sens', 'thr', 10, 'upper');
    assert(iscell(ev.TagKeys), 'defaults: TagKeys is cell');
    assert(isempty(ev.TagKeys), 'defaults: TagKeys empty');
    assert(ev.Severity == 1, 'defaults: Severity is 1');
    assert(strcmp(ev.Category, ''), 'defaults: Category empty');
    assert(strcmp(ev.Id, ''), 'defaults: Id empty');

    % testEventTagKeysSetable
    ev = Event(1, 2, 'sens', 'thr', 10, 'upper');
    ev.TagKeys = {'sensor_a', 'monitor_b'};
    assert(numel(ev.TagKeys) == 2, 'setTagKeys: two keys');

    % testEventSeveritySetable
    ev = Event(1, 2, 'sens', 'thr', 10, 'upper');
    ev.Severity = 3;
    assert(ev.Severity == 3, 'setSeverity: alarm level');

    % testEventCategorySetable
    ev = Event(1, 2, 'sens', 'thr', 10, 'upper');
    ev.Category = 'alarm';
    assert(strcmp(ev.Category, 'alarm'), 'setCategory: alarm');

    % testEventStoreAutoId
    EventBinding.clear();
    store = EventStore('');
    ev1 = Event(1, 2, 'sens', 'thr', 10, 'upper');
    ev2 = Event(3, 4, 'sens', 'thr', 10, 'upper');
    store.append(ev1);
    store.append(ev2);
    assert(~isempty(ev1.Id), 'autoId: ev1 has Id');
    assert(~isempty(ev2.Id), 'autoId: ev2 has Id');
    assert(~strcmp(ev1.Id, ev2.Id), 'autoId: unique Ids');
    assert(strcmp(ev1.Id, 'evt_1'), 'autoId: ev1 is evt_1');
    assert(strcmp(ev2.Id, 'evt_2'), 'autoId: ev2 is evt_2');

    % testEventsForTagViaEventBinding
    EventBinding.clear();
    store = EventStore('');
    ev1 = Event(1, 2, 'sens_a', 'thr_x', 10, 'upper');
    ev2 = Event(3, 4, 'sens_b', 'thr_y', 20, 'lower');
    store.append(ev1);
    store.append(ev2);
    ev1.TagKeys = {'tag_alpha'};
    ev2.TagKeys = {'tag_alpha', 'tag_beta'};
    EventBinding.attach(ev1.Id, 'tag_alpha');
    EventBinding.attach(ev2.Id, 'tag_alpha');
    EventBinding.attach(ev2.Id, 'tag_beta');
    result = store.getEventsForTag('tag_alpha');
    assert(numel(result) == 2, 'eventsForTag: two for tag_alpha');
    result_b = store.getEventsForTag('tag_beta');
    assert(numel(result_b) == 1, 'eventsForTag: one for tag_beta');

    % testBackwardCompatCarrierFallback
    EventBinding.clear();
    store = EventStore('');
    ev = Event(1, 2, 'sensor_key', 'threshold_label', 10, 'upper');
    store.append(ev);
    % Query using carrier field — should still find via SensorName/ThresholdLabel
    result = store.getEventsForTag('sensor_key');
    assert(numel(result) == 1, 'carrier: found via SensorName');
    result2 = store.getEventsForTag('threshold_label');
    assert(numel(result2) == 1, 'carrier: found via ThresholdLabel');

    % testManyToMany
    EventBinding.clear();
    store = EventStore('');
    ev1 = Event(1, 2, 's', 't', 10, 'upper');
    ev2 = Event(3, 4, 's', 't', 10, 'upper');
    store.append(ev1);
    store.append(ev2);
    EventBinding.attach(ev1.Id, 'tag_x');
    EventBinding.attach(ev1.Id, 'tag_y');
    EventBinding.attach(ev2.Id, 'tag_x');
    % tag_x -> ev1, ev2; tag_y -> ev1; ev1 -> tag_x, tag_y; ev2 -> tag_x
    result_x = store.getEventsForTag('tag_x');
    assert(numel(result_x) == 2, 'manyToMany: tag_x has 2 events');
    result_y = store.getEventsForTag('tag_y');
    assert(numel(result_y) == 1, 'manyToMany: tag_y has 1 event');
    keys1 = EventBinding.getTagKeysForEvent(ev1.Id);
    assert(numel(keys1) == 2, 'manyToMany: ev1 has 2 tags');
    keys2 = EventBinding.getTagKeysForEvent(ev2.Id);
    assert(numel(keys2) == 1, 'manyToMany: ev2 has 1 tag');

    % testPitfall4NoTagHandleProperties
    ev = Event(1, 2, 's', 't', 10, 'upper');
    props = fieldnames(ev);
    for i = 1:numel(props)
        val = ev.(props{i});
        assert(~isa(val, 'Tag'), sprintf('pitfall4: %s must not be Tag', props{i}));
    end

    % testConstructorBackwardCompat
    ev = Event(10, 20, 'temp', 'warning high', 80, 'upper');
    assert(ev.StartTime == 10, 'compat: constructor works');
    assert(strcmp(ev.SensorName, 'temp'), 'compat: SensorName set');
    assert(strcmp(ev.ThresholdLabel, 'warning high'), 'compat: ThresholdLabel set');

    % testMonitorTagRecomputeEmitsTagKeys
    EventBinding.clear();
    st = SensorTag('press_a', 'X', 1:10, 'Y', [0 0 5 8 9 8 5 0 0 0]);
    es = EventStore('');
    m = MonitorTag('press_hi', st, @(x, y) y > 4, 'EventStore', es);
    [~, ~] = m.getXY();  % triggers recompute -> fireEventsOnRisingEdges_
    assert(es.numEvents() >= 1, 'monRecompute: at least one event');
    ev = es.getEvents();
    ev1 = ev(1);
    assert(~isempty(ev1.TagKeys), 'monRecompute: TagKeys populated');
    assert(iscell(ev1.TagKeys), 'monRecompute: TagKeys is cell');
    assert(any(strcmp('press_hi', ev1.TagKeys)), 'monRecompute: has monitor key');
    assert(any(strcmp('press_a', ev1.TagKeys)), 'monRecompute: has parent key');
    assert(~isempty(ev1.Id), 'monRecompute: Id assigned');
    % Verify EventBinding has the entries
    boundKeys = EventBinding.getTagKeysForEvent(ev1.Id);
    assert(any(strcmp('press_hi', boundKeys)), 'monRecompute: EventBinding has monitor key');
    assert(any(strcmp('press_a', boundKeys)), 'monRecompute: EventBinding has parent key');
    % Verify eventsForTag returns them
    result = es.getEventsForTag('press_hi');
    assert(numel(result) >= 1, 'monRecompute: eventsForTag finds monitor key');
    result2 = es.getEventsForTag('press_a');
    assert(numel(result2) >= 1, 'monRecompute: eventsForTag finds parent key');

    % testMonitorTagStreamingEmitsTagKeys
    EventBinding.clear();
    st2 = SensorTag('press_b', 'X', 1:5, 'Y', [0 0 5 8 0]);
    es2 = EventStore('');
    m2 = MonitorTag('press_hi2', st2, @(x, y) y > 4, 'EventStore', es2);
    [~, ~] = m2.getXY();  % initial recompute
    nBefore = es2.numEvents();
    % Append new data that crosses threshold and closes
    st2.updateData([1:5, 6:10], [0 0 5 8 0, 0 0 7 9 0]);
    m2.appendData(6:10, [0 0 7 9 0]);
    nAfter = es2.numEvents();
    assert(nAfter > nBefore, 'monStreaming: new event from appendData');
    allEvts = es2.getEvents();
    lastEv = allEvts(end);
    assert(~isempty(lastEv.TagKeys), 'monStreaming: TagKeys populated');
    assert(any(strcmp('press_hi2', lastEv.TagKeys)), 'monStreaming: has monitor key');
    assert(any(strcmp('press_b', lastEv.TagKeys)), 'monStreaming: has parent key');
    assert(~isempty(lastEv.Id), 'monStreaming: Id assigned');
    boundKeys2 = EventBinding.getTagKeysForEvent(lastEv.Id);
    assert(any(strcmp('press_hi2', boundKeys2)), 'monStreaming: EventBinding has monitor key');

    % testLegacyCarrierStillPopulated
    EventBinding.clear();
    st3 = SensorTag('sens_c', 'X', 1:10, 'Y', [0 0 5 8 9 8 5 0 0 0]);
    es3 = EventStore('');
    m3 = MonitorTag('thr_c', st3, @(x, y) y > 4, 'EventStore', es3);
    [~, ~] = m3.getXY();
    ev3 = es3.getEvents();
    assert(strcmp(ev3(1).SensorName, 'sens_c'), 'legacy: SensorName still set');
    assert(strcmp(ev3(1).ThresholdLabel, 'thr_c'), 'legacy: ThresholdLabel still set');

    fprintf('    All 13 event_tag_binding tests passed.\n');
end

function add_event_tag_binding_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
