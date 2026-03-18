function test_event_store_rw()
    add_event_path();
    test_constructor();
    test_append_and_save();
    test_atomic_write();
    test_load_static();
    test_load_unchanged();
    test_backup_rotation();
    test_metadata();
    fprintf('test_event_store_rw: ALL PASSED\n');
end

function add_event_path()
    thisDir = fileparts(mfilename('fullpath'));
    repoRoot = fileparts(thisDir);
    addpath(repoRoot);
    addpath(fullfile(repoRoot, 'libs', 'EventDetection'));
    addpath(fullfile(repoRoot, 'libs', 'SensorThreshold'));
    install();
end

function test_constructor()
    f = [tempname '.mat'];
    store = EventStore(f);
    assert(strcmp(store.FilePath, f), 'filepath');
    assert(store.MaxBackups == 5, 'default_backups');
    fprintf('  PASS: test_constructor\n');
end

function test_append_and_save()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev1 = Event(now-1, now-0.5, 'sensorA', 'HH', 100, 'upper');
    store.append(ev1);
    store.save();
    assert(isfile(f), 'file_created');
    data = load(f);
    assert(numel(data.events) == 1, 'one_event');
    % Append more
    ev2 = Event(now-0.3, now-0.1, 'sensorB', 'LL', 10, 'lower');
    store.append(ev2);
    store.save();
    data = load(f);
    assert(numel(data.events) == 2, 'two_events');
    delete(f);
    fprintf('  PASS: test_append_and_save\n');
end

function test_atomic_write()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
    store.append(ev);
    store.save();
    % File should exist and be readable
    data = load(f);
    assert(isfield(data, 'events'), 'has_events');
    assert(isfield(data, 'lastUpdated'), 'has_timestamp');
    delete(f);
    fprintf('  PASS: test_atomic_write\n');
end

function test_load_static()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
    store.append(ev);
    store.save();
    [events, meta] = EventStore.loadFile(f);
    assert(numel(events) == 1, 'loaded_one');
    assert(isfield(meta, 'lastUpdated'), 'meta_timestamp');
    delete(f);
    fprintf('  PASS: test_load_static\n');
end

function test_load_unchanged()
    f = [tempname '.mat'];
    store = EventStore(f);
    ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
    store.append(ev);
    store.save();
    [~, ~] = EventStore.loadFile(f);
    [events, meta, changed] = EventStore.loadFile(f);
    assert(~changed, 'unchanged');
    delete(f);
    fprintf('  PASS: test_load_unchanged\n');
end

function test_backup_rotation()
    f = [tempname '.mat'];
    store = EventStore(f, 'MaxBackups', 2);
    for i = 1:4
        ev = Event(now+i, now+i+0.01, 'x', 'H', 50, 'upper');
        store.append(ev);
        store.save();
        pause(0.1);
    end
    [fdir, fname] = fileparts(f);
    backups = dir(fullfile(fdir, [fname '_backup_*.mat']));
    assert(numel(backups) <= 2, 'max_2_backups');
    delete(f);
    for b = 1:numel(backups)
        delete(fullfile(fdir, backups(b).name));
    end
    fprintf('  PASS: test_backup_rotation\n');
end

function test_metadata()
    f = [tempname '.mat'];
    store = EventStore(f);
    store.PipelineConfig = struct('sensors', {{'a','b'}});
    ev = Event(now, now+0.01, 'x', 'H', 50, 'upper');
    store.append(ev);
    store.save();
    data = load(f);
    assert(isfield(data, 'pipelineConfig'), 'has_config');
    assert(isequal(data.pipelineConfig.sensors, {'a','b'}), 'config_matches');
    delete(f);
    fprintf('  PASS: test_metadata\n');
end
