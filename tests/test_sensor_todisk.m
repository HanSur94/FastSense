function test_sensor_todisk()
%TEST_SENSOR_TODISK Tests for Sensor.toDisk() / toMemory() / isOnDisk().
%   Covers: disk round-trip, resolve with disk data, addSensor passthrough,
%   large sensor performance, idempotent toDisk, error on empty data.

    addpath(fullfile(fileparts(mfilename('fullpath')), '..'));
    install();

    fprintf('  --- Sensor.toDisk() tests ---\n');

    %% 1. Basic toDisk / isOnDisk / toMemory
    s = Sensor('pressure', 'Name', 'Chamber Pressure');
    s.X = linspace(0, 100, 100000);
    s.Y = 40 + 20*sin(2*pi*s.X/30) + 5*randn(1, 100000);

    assert(~s.isOnDisk(), 'should start in memory');
    assert(numel(s.X) == 100000, 'X should have data');

    s.toDisk();
    assert(s.isOnDisk(), 'should be on disk after toDisk');
    assert(isempty(s.X), 'X should be empty after toDisk');
    assert(isempty(s.Y), 'Y should be empty after toDisk');
    assert(s.DataStore.NumPoints == 100000, 'DataStore should have 100K pts');
    fprintf('    toDisk / isOnDisk: PASS\n');

    %% 2. toMemory round-trip
    s.toMemory();
    assert(~s.isOnDisk(), 'should be in memory after toMemory');
    assert(numel(s.X) == 100000, 'X should be restored');
    assert(numel(s.Y) == 100000, 'Y should be restored');
    assert(isempty(s.DataStore), 'DataStore should be cleared');
    fprintf('    toMemory round-trip: PASS\n');

    %% 3. resolve() with disk-backed data
    s2 = Sensor('temp', 'Name', 'Temperature');
    s2.X = linspace(0, 100, 50000);
    s2.Y = 40 + 20*sin(2*pi*s2.X/30) + 5*randn(1, 50000);

    sc = StateChannel('machine');
    sc.X = [0, 25, 50, 75];
    sc.Y = [0, 1, 2, 1];
    s2.addStateChannel(sc);
    t_hh_running = Threshold('hh_running', 'Name', 'HH (running)', 'Direction', 'upper');
    t_hh_running.addCondition(struct('machine', 1), 55);
    s2.addThreshold(t_hh_running);

    s2.resolve();
    nThMem = numel(s2.ResolvedThresholds);

    % Re-create with same structure, move to disk, resolve
    s2.X = linspace(0, 100, 50000);
    s2.Y = 40 + 20*sin(2*pi*s2.X/30) + 5*randn(1, 50000);
    s2.toDisk();
    s2.resolve();
    nThDisk = numel(s2.ResolvedThresholds);
    nViolDisk = numel(s2.ResolvedViolations);

    assert(nThDisk == nThMem, 'threshold count should match');
    assert(nViolDisk > 0, 'should have violations');
    fprintf('    resolve with disk data: PASS\n');

    %% 4. addSensor with disk-backed sensor
    fp = FastSense();
    fp.addSensor(s2, 'ShowThresholds', true);
    fp.render();
    assert(numel(fp.Lines) >= 1, 'should have at least 1 line');
    assert(~isempty(fp.Lines(1).DataStore), 'line should have DataStore');
    close(fp.hFigure);
    fprintf('    addSensor disk-backed: PASS\n');

    %% 5. addSensor with no thresholds (no resolve)
    s3 = Sensor('flow', 'Name', 'Gas Flow');
    s3.X = linspace(0, 100, 10000);
    s3.Y = rand(1, 10000);
    s3.toDisk();
    fp2 = FastSense();
    fp2.addSensor(s3);
    fp2.render();
    assert(numel(fp2.Lines) == 1, 'should have 1 line');
    close(fp2.hFigure);
    s3.DataStore.cleanup();
    fprintf('    addSensor no thresholds: PASS\n');

    %% 6. Double toDisk is idempotent
    s4 = Sensor('test');
    s4.X = 1:100;
    s4.Y = rand(1, 100);
    s4.toDisk();
    ds1 = s4.DataStore;
    s4.toDisk();
    assert(strcmp(s4.DataStore.DbPath, ds1.DbPath), 'DataStore should not change');
    s4.DataStore.cleanup();
    fprintf('    idempotent toDisk: PASS\n');

    %% 7. toDisk with no data should error
    s5 = Sensor('empty');
    threw = false;
    try
        s5.toDisk();
    catch
        threw = true;
    end
    assert(threw, 'should throw on empty data');
    fprintf('    toDisk empty error: PASS\n');

    %% 8. DataStore metadata preserved
    s6 = Sensor('meta', 'Name', 'With Metadata');
    s6.X = linspace(0, 50, 20000);
    s6.Y = sin(s6.X) + randn(1, 20000) * 0.1;
    s6.toDisk();
    assert(abs(s6.DataStore.XMin - s6.DataStore.PyramidX(1)) < 1, ...
        'PyramidX should start near XMin');
    assert(s6.DataStore.NumPoints == 20000, 'NumPoints should match');
    s6.DataStore.cleanup();
    fprintf('    DataStore metadata: PASS\n');

    fprintf('\n    All 8 Sensor.toDisk() tests passed.\n');
end
