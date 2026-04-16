%% Sensor.toDisk() — Disk-backed sensor workflow
% Demonstrates how to build sensor data in memory, move it to disk via
% toDisk(), and then use it for threshold resolution and plotting without
% keeping the raw data in RAM.
%
% This is useful when working with large sensor datasets (millions of
% points) that would otherwise consume too much memory.

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. Basic toDisk workflow
% Build sensor data normally, then call toDisk() to offload to SQLite.

fprintf('=== 1. Basic toDisk workflow ===\n');

s = Sensor('temperature', 'Name', 'Chamber Temperature', 'ID', 201);
s.X = linspace(0, 200, 2e6);
s.Y = 50 + 8*sin(2*pi*s.X/60) + 3*randn(1, 2e6);

fprintf('  Before toDisk: %.1f MB in memory\n', numel(s.X) * 16 / 1e6);

s.toDisk();

fprintf('  After toDisk:  X is empty=%d, Y is empty=%d, isOnDisk=%d\n', ...
    isempty(s.X), isempty(s.Y), s.isOnDisk());
fprintf('  DataStore: %d points on disk\n', s.DataStore.NumPoints);

%% 2. resolve() works transparently with disk data
% Threshold rules and state channels work the same way — resolve() reads
% from the DataStore automatically.

fprintf('\n=== 2. Disk-backed resolve ===\n');

sc = StateChannel('machine');
sc.X = [0 50 100 150];
sc.Y = [0 1 2 1];  % idle -> running -> evacuated -> running
s.addStateChannel(sc);

tHhIdle = Threshold('hh_idle', 'Name', 'HH (idle)', ...
    'Direction', 'upper', 'Color', [0.8 0 0], 'LineStyle', '--');
tHhIdle.addCondition(struct('machine', 0), 65);
s.addThreshold(tHhIdle);

tHhRunning = Threshold('hh_running', 'Name', 'HH (running)', ...
    'Direction', 'upper', 'Color', [1 0.3 0], 'LineStyle', '--');
tHhRunning.addCondition(struct('machine', 1), 58);
s.addThreshold(tHhRunning);

tHhEvacuated = Threshold('hh_evacuated', 'Name', 'HH (evacuated)', ...
    'Direction', 'upper', 'Color', [1 0 0], 'LineStyle', '-');
tHhEvacuated.addCondition(struct('machine', 2), 52);
s.addThreshold(tHhEvacuated);

tic;
s.resolve();
fprintf('  resolve() on 2M disk-backed points: %.3f s\n', toc);
fprintf('  Thresholds: %d, Violations: %d\n', ...
    numel(s.ResolvedThresholds), numel(s.ResolvedViolations));

%% 3. Plot the disk-backed sensor
% addSensor passes the DataStore directly to FastSense — no copying.

fprintf('\n=== 3. Plot disk-backed sensor ===\n');

fp = FastSense();
fp.addSensor(s, 'ShowThresholds', true);
tic;
fp.render();
fprintf('  Rendered in %.3f s\n', toc);
title(fp.hAxes, 'Disk-backed Sensor — 2M Points with Dynamic Thresholds');

%% 4. toMemory round-trip
% You can read data back into memory if needed (e.g., for export or
% further processing).

fprintf('\n=== 4. toMemory round-trip ===\n');

s2 = Sensor('pressure', 'Name', 'Pressure Sensor');
s2.X = linspace(0, 100, 500000);
s2.Y = 40 + 20*sin(2*pi*s2.X/30) + 5*randn(1, 500000);

s2.toDisk();
fprintf('  On disk: X empty=%d, NumPoints=%d\n', isempty(s2.X), s2.DataStore.NumPoints);

s2.toMemory();
fprintf('  Back in memory: numel(X)=%d, isOnDisk=%d\n', numel(s2.X), s2.isOnDisk());

%% 5. Large-scale sensor with extra columns
% Combine toDisk with addColumn to attach metadata (labels, flags,
% categories) without holding everything in memory.

fprintf('\n=== 5. Large sensor with metadata columns ===\n');

s3 = Sensor('flow', 'Name', 'Gas Flow Rate');
n = 5e6;
s3.X = linspace(0, 1000, n);
s3.Y = 50 + 15*sin(2*pi*s3.X/20) + 3*randn(1, n);

tic;
s3.toDisk();
fprintf('  toDisk (%dM points): %.3f s\n', n/1e6, toc);

% Add a categorical status column
catData.codes = uint32(mod(0:n-1, 3) + 1);
catData.categories = {'nominal', 'warning', 'alarm'};
s3.DataStore.addColumn('status', catData);

% Add a logical flag column
flags = s3.DataStore.PyramidY > 60;  % flag from pyramid (approximate)
% For exact flags we'd read from disk, but pyramid is good for demo
fprintf('  Added status column + flag column to DataStore\n');
fprintf('  Columns: %s\n', strjoin(s3.DataStore.listColumns(), ', '));

% Query a range
slice = s3.DataStore.getColumnSlice('status', 1, 6);
labels = FastSenseDataStore.toCategorical(slice);
fprintf('  First 6 status labels: ');
if iscell(labels)
    fprintf('%s\n', strjoin(labels, ', '));
else
    fprintf('%s\n', strjoin(cellstr(labels), ', '));
end

% Plot it
fp2 = FastSense();
fp2.addSensor(s3);
tic;
fp2.render();
fprintf('  Rendered %dM disk-backed points in %.3f s\n', n/1e6, toc);
title(fp2.hAxes, sprintf('Disk-backed Sensor — %dM Points', n/1e6));

%% 6. Multiple disk-backed sensors in a dashboard
% Each sensor manages its own DataStore independently.

fprintf('\n=== 6. Multi-sensor dashboard (all disk-backed) ===\n');

sensors = {};
names = {'Temperature', 'Pressure', 'Flow Rate', 'Vibration'};
nPts = 1e6;

for i = 1:4
    si = Sensor(lower(names{i}), 'Name', names{i});
    si.X = linspace(0, 200, nPts);
    si.Y = 30 + 10*i + 15*sin(2*pi*si.X/(20+10*i)) + 4*randn(1, nPts);
    tHh = Threshold('hh', 'Name', 'HH', 'Direction', 'upper');
    tHh.addCondition(struct(), 30 + 10*i + 12);
    si.addThreshold(tHh);
    si.toDisk();
    si.resolve();
    sensors{i} = si;
end

fpf = FastSenseGrid(2, 2);
for i = 1:4
    fpf.tile(i).addSensor(sensors{i}, 'ShowThresholds', true);
end
tic;
fpf.render();
fprintf('  4 sensors x %dM pts each, all disk-backed, rendered in %.3f s\n', ...
    nPts/1e6, toc);

fprintf('\nDone! All figures are interactive — zoom and pan to explore.\n');
