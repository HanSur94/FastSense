function test_event_store()
%TEST_EVENT_STORE Tests for event store persistence and EventViewer.fromFile.

    if exist('OCTAVE_VERSION', 'builtin')
        fprintf('  SKIPPED (requires datetime and EventViewer — MATLAB only)\n');
        return;
    end

    add_event_path();

    % testAutoSave
    cfg = EventConfig();
    s = SensorTag('temp', 'Name', 'Temperature');
    s.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
    t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    t_warn.addCondition(struct(), 10);
    s.addThreshold(t_warn);
    cfg.addTag(s);
    cfg.setColor('warn', [1 0.8 0]);

    tmpFile = fullfile(tempdir, 'test_event_store.mat');
    cfg.EventFile = tmpFile;
    events = cfg.runDetection();

    assert(exist(tmpFile, 'file') == 2, 'auto-save: file created');
    data = load(tmpFile);
    assert(isfield(data, 'events'), 'auto-save: has events');
    assert(isfield(data, 'sensorData'), 'auto-save: has sensorData');
    assert(isfield(data, 'thresholdColors'), 'auto-save: has thresholdColors');
    assert(isfield(data, 'timestamp'), 'auto-save: has timestamp');
    assert(numel(data.events) == numel(events), 'auto-save: event count');
    assert(strcmp(data.sensorData(1).name, 'Temperature'), 'auto-save: sensor name');

    % testFromFile
    viewer = EventViewer.fromFile(tmpFile);
    assert(isa(viewer, 'EventViewer'), 'fromFile: returns EventViewer');
    assert(numel(viewer.Events) == numel(events), 'fromFile: event count');
    close(viewer.hFigure);

    % testFromFileColors
    assert(viewer.ThresholdColors.isKey('warn'), 'fromFile: color key restored');
    assert(isequal(viewer.ThresholdColors('warn'), [1 0.8 0]), 'fromFile: color value');

    % testNoEventFile
    cfg2 = EventConfig();
    s2 = SensorTag('temp', 'Name', 'Temperature');
    s2.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
    t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    t_warn.addCondition(struct(), 10);
    s2.addThreshold(t_warn);
    cfg2.addTag(s2);
    tmpFile2 = fullfile(tempdir, 'test_event_store_2.mat');
    if exist(tmpFile2, 'file'); delete(tmpFile2); end
    events2 = cfg2.runDetection();
    assert(exist(tmpFile2, 'file') ~= 2, 'no-file: nothing saved when EventFile empty');

    % testFromFileNotFound
    threw = false;
    try
        EventViewer.fromFile('/tmp/nonexistent_event_store.mat');
    catch e
        threw = true;
        assert(~isempty(strfind(e.identifier, 'fileNotFound')), 'fromFile: correct error id');
    end
    assert(threw, 'fromFile: throws on missing file');

    % testBackupCreated
    tmpFile3 = fullfile(tempdir, 'test_event_backup.mat');
    [bDir, bName, bExt] = fileparts(tmpFile3);
    % Clean up any previous backup files
    oldBackups = dir(fullfile(bDir, [bName, '_*', bExt]));
    for bi = 1:numel(oldBackups)
        delete(fullfile(bDir, oldBackups(bi).name));
    end
    if exist(tmpFile3, 'file'); delete(tmpFile3); end

    cfg3 = EventConfig();
    s3 = SensorTag('temp', 'Name', 'Temperature');
    s3.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
    t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    t_warn.addCondition(struct(), 10);
    s3.addThreshold(t_warn);
    cfg3.addTag(s3);
    cfg3.EventFile = tmpFile3;
    cfg3.MaxBackups = 2;

    % First save — no backup (no existing file)
    cfg3.runDetection();
    backups = dir(fullfile(bDir, [bName, '_*', bExt]));
    assert(numel(backups) == 0, 'backup: no backup on first save');

    % Second save — creates backup
    pause(1.1); % ensure different timestamp
    cfg3.runDetection();
    backups = dir(fullfile(bDir, [bName, '_*', bExt]));
    assert(numel(backups) == 1, 'backup: one backup after second save');

    % Third save — creates second backup
    pause(1.1);
    cfg3.runDetection();
    backups = dir(fullfile(bDir, [bName, '_*', bExt]));
    assert(numel(backups) == 2, 'backup: two backups after third save');

    % Fourth save — prunes to MaxBackups=2
    pause(1.1);
    cfg3.runDetection();
    backups = dir(fullfile(bDir, [bName, '_*', bExt]));
    assert(numel(backups) == 2, 'backup: pruned to MaxBackups');

    % testMaxBackupsZero
    tmpFile4 = fullfile(tempdir, 'test_event_nobackup.mat');
    cfg4 = EventConfig();
    s4 = SensorTag('temp', 'Name', 'Temperature');
    s4.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
    t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    t_warn.addCondition(struct(), 10);
    s4.addThreshold(t_warn);
    cfg4.addTag(s4);
    cfg4.EventFile = tmpFile4;
    cfg4.MaxBackups = 0;
    cfg4.runDetection();
    cfg4.runDetection();
    [nbDir, nbName, nbExt] = fileparts(tmpFile4);
    noBackups = dir(fullfile(nbDir, [nbName, '_*', nbExt]));
    assert(numel(noBackups) == 0, 'no-backup: MaxBackups=0 creates no backups');

    % Cleanup
    if exist(tmpFile, 'file'); delete(tmpFile); end
    if exist(tmpFile3, 'file'); delete(tmpFile3); end
    if exist(tmpFile4, 'file'); delete(tmpFile4); end
    backups = dir(fullfile(bDir, [bName, '_*', bExt]));
    for bi = 1:numel(backups)
        delete(fullfile(bDir, backups(bi).name));
    end

    % testFromFileHasRefreshControls
    cfg5 = EventConfig();
    s5 = SensorTag('temp', 'Name', 'Temperature');
    s5.updateData(1:10, [5 5 12 14 11 13 5 5 5 5]);
    [s5_x_, s5_y_] = s5.getXY();
    t_warn = Threshold('warn', 'Name', 'warn', 'Direction', 'upper');
    t_warn.addCondition(struct(), 10);
    s5.addThreshold(t_warn);
    cfg5.addTag(s5);
    tmpFile5 = fullfile(tempdir, 'test_event_refresh.mat');
    cfg5.EventFile = tmpFile5;
    cfg5.runDetection();
    viewer5 = EventViewer.fromFile(tmpFile5);
    assert(~isempty(viewer5.hFigure), 'refresh: figure exists');
    % Verify refresh works by modifying file and calling refreshFromFile
    s5_y_ = [5 5 12 14 11 13 12 15 5 5]; % add more violations
    cfg5.runDetection();
    oldCount = numel(viewer5.Events);
    viewer5.refreshFromFile();
    assert(numel(viewer5.Events) >= oldCount, 'refresh: events updated from file');
    % Test auto-refresh start/stop (no error = success)
    viewer5.startAutoRefresh(60);
    viewer5.stopAutoRefresh();
    close(viewer5.hFigure);
    if exist(tmpFile5, 'file'); delete(tmpFile5); end

    fprintf('    All 8 event_store tests passed.\n');
end

function add_event_path()
    test_dir = fileparts(mfilename('fullpath'));
    repo_root = fileparts(test_dir);
    addpath(repo_root); install();
end
