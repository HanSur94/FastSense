%% SensorRegistry — Predefined Sensor Catalog
% Demonstrates:
%   - SensorRegistry.list()        — print all available sensor keys
%   - SensorRegistry.get(key)      — retrieve a single sensor by key
%   - SensorRegistry.getMultiple() — retrieve several sensors at once
%   - SensorRegistry.register()    — add a custom sensor at runtime
%   - SensorRegistry.unregister()  — remove a sensor from the catalog
%   - SensorRegistry.printTable()  — detailed tabular view
%   - SensorRegistry.viewer()      — interactive GUI viewer
%   - Adding data + thresholds to registry sensors, then plotting

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. List all sensors in the catalog
fprintf('=== All registered sensors ===');
SensorRegistry.list();

%% 2. Retrieve a single sensor by key
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

tHhIdle = Threshold('hh_idle', 'Name', 'HH (idle)', ...
    'Direction', 'upper', 'Color', [0.9 0.4 0.1], 'LineStyle', '--');
tHhIdle.addCondition(struct('machine', 0), 75);
s.addThreshold(tHhIdle);

tHhRunning = Threshold('hh_running', 'Name', 'HH (running)', ...
    'Direction', 'upper', 'Color', [0.9 0.1 0.1], 'LineStyle', '--');
tHhRunning.addCondition(struct('machine', 1), 62);
s.addThreshold(tHhRunning);

tHhEvacuated = Threshold('hh_evacuated', 'Name', 'HH (evacuated)', ...
    'Direction', 'upper', 'Color', [1 0 0], 'LineStyle', '-');
tHhEvacuated.addCondition(struct('machine', 2), 52);
s.addThreshold(tHhEvacuated);

s.resolve();

%% 3. Retrieve multiple sensors at once
sensors = SensorRegistry.getMultiple({'pressure', 'temperature'});
fprintf('\nRetrieved %d sensors via getMultiple():\n', numel(sensors));
for i = 1:numel(sensors)
    fprintf('  [%d] key="%s", name="%s"\n', i, sensors{i}.Key, sensors{i}.Name);
end

%% 4. register / unregister — add and remove custom sensors at runtime
customSensor = Sensor('my_custom_ph', 'Name', 'pH Sensor', 'ID', 999);
customSensor.Units = 'pH';
customSensor.X = linspace(0, 60, 5000);
customSensor.Y = 7.0 + 0.5*sin(2*pi*customSensor.X/15) + 0.1*randn(1, numel(customSensor.X));
tHighPh = Threshold('high_ph', 'Name', 'High pH', 'Direction', 'upper');
tHighPh.addCondition(struct(), 7.8);
customSensor.addThreshold(tHighPh);

tLowPh = Threshold('low_ph', 'Name', 'Low pH', 'Direction', 'lower');
tLowPh.addCondition(struct(), 6.2);
customSensor.addThreshold(tLowPh);
customSensor.resolve();

SensorRegistry.register('my_custom_ph', customSensor);
fprintf('\nSensorRegistry.register(): added custom sensor "my_custom_ph".\n');

%% 5. printTable — detailed tabular view of all sensors
SensorRegistry.printTable();

%% 6. viewer — interactive GUI with uitable
SensorRegistry.viewer();
fprintf('SensorRegistry.viewer() opened.\n');

% Cleanup: unregister the custom sensor to avoid polluting the global
% registry. In a real workflow you would keep it registered.
SensorRegistry.unregister('my_custom_ph');
fprintf('SensorRegistry.unregister(): removed "my_custom_ph".\n');

%% 7. Plot the pressure sensor with FastSense
fp = FastSense();
fp.addSensor(s, 'ShowThresholds', true);
fp.render();
title(sprintf('%s (from SensorRegistry)', s.Name));
xlabel('Time [s]');
ylabel('Pressure [mbar]');
