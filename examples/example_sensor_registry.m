%% SensorRegistry — Predefined Sensor Catalog
% Demonstrates:
%   - SensorRegistry.list()        — print all available sensor keys
%   - SensorRegistry.get(key)      — retrieve a single sensor by key
%   - SensorRegistry.getMultiple() — retrieve several sensors at once
%   - Adding data + thresholds to registry sensors, then plotting

projectRoot = fileparts(fileparts(mfilename('fullpath')));
run(fullfile(projectRoot, 'setup.m'));

% --- List all sensors in the catalog ---
fprintf('=== All registered sensors ===');
SensorRegistry.list();

% --- Retrieve a single sensor by key ---
s = SensorRegistry.get('pressure');
fprintf('Retrieved sensor: key="%s", name="%s", ID=%d\n', s.Key, s.Name, s.ID);

% Populate with synthetic data
t = linspace(0, 80, 15000);
s.X = t;
s.Y = 45 + 18*sin(2*pi*t/20) + 4*randn(1, numel(t));

% Add state channel and state-dependent thresholds
sc = StateChannel('machine');
sc.X = [0 20 40 60];
sc.Y = [0  1  2  1];
s.addStateChannel(sc);

s.addThresholdRule(struct('machine', 0), 75, ...
    'Direction', 'upper', 'Label', 'HH (idle)', ...
    'Color', [0.9 0.4 0.1], 'LineStyle', '--');
s.addThresholdRule(struct('machine', 1), 62, ...
    'Direction', 'upper', 'Label', 'HH (running)', ...
    'Color', [0.9 0.1 0.1], 'LineStyle', '--');
s.addThresholdRule(struct('machine', 2), 52, ...
    'Direction', 'upper', 'Label', 'HH (evacuated)', ...
    'Color', [1 0 0], 'LineStyle', '-');

s.resolve();

% --- Retrieve multiple sensors at once ---
sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
fprintf('\nRetrieved %d sensors via getMultiple():\n', numel(sensors));
for i = 1:numel(sensors)
    fprintf('  [%d] key="%s", name="%s"\n', i, sensors{i}.Key, sensors{i}.Name);
end

% --- Plot the pressure sensor with FastSense ---
fp = FastSense();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(sprintf('%s (from SensorRegistry)', s.Name));
xlabel('Time [s]');
ylabel('Pressure [mbar]');
