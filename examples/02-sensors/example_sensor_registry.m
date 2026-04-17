%% TagRegistry — Predefined Sensor Catalog
% Demonstrates:
%   - TagRegistry.list()        — print all available sensor keys
%   - TagRegistry.get(key)      — retrieve a single sensor by key
%   - TagRegistry.getMultiple() — retrieve several sensors at once
%   - TagRegistry.register()    — add a custom sensor at runtime
%   - TagRegistry.unregister()  — remove a sensor from the catalog
%   - TagRegistry.printTable()  — detailed tabular view
%   - TagRegistry.viewer()      — interactive GUI viewer
%   - Adding data + thresholds to registry sensors, then plotting

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. List all sensors in the catalog
fprintf('=== All registered sensors ===');
TagRegistry.list();

%% 2. Retrieve a single sensor by key
s = TagRegistry.get('pressure');
fprintf('Retrieved sensor: key="%s", name="%s", ID=%d\n', s.Key, s.Name, s.ID);

% Populate with synthetic data
t = linspace(0, 80, 15000);
s.updateData(t, 45 + 18*sin(2*pi*t/20) + 4*randn(1, numel(t)));

% Add state channel and state-dependent thresholds
sc = StateTag('machine', 'X', [0 20 40 60], 'Y', [0  1  2  1]);


%% 3. Retrieve multiple sensors at once
sensors = TagRegistry.getMultiple({'pressure', 'temperature'});
fprintf('\nRetrieved %d sensors via getMultiple():\n', numel(sensors));
for i = 1:numel(sensors)
    fprintf('  [%d] key="%s", name="%s"\n', i, sensors{i}.Key, sensors{i}.Name);
end

%% 4. register / unregister — add and remove custom sensors at runtime
customSensor = SensorTag('my_custom_ph', 'Name', 'pH Sensor', 'ID', 999, 'Units', 'pH', 'X', linspace(0, 60, 5000), 'Y', 7.0 + 0.5*sin(2*pi*customSensor.X/15) + 0.1*randn(1, numel(customSensor.X)));


TagRegistry.register('my_custom_ph', customSensor);
fprintf('\nTagRegistry.register(): added custom sensor "my_custom_ph".\n');

%% 5. printTable — detailed tabular view of all sensors
TagRegistry.printTable();

%% 6. viewer — interactive GUI with uitable
TagRegistry.viewer();
fprintf('TagRegistry.viewer() opened.\n');

% Cleanup: unregister the custom sensor to avoid polluting the global
% registry. In a real workflow you would keep it registered.
TagRegistry.unregister('my_custom_ph');
fprintf('TagRegistry.unregister(): removed "my_custom_ph".\n');

%% 7. Plot the pressure sensor with FastSense
fp = FastSense();
fp.addTag(s, 'ShowThresholds', true);
fp.render();
title(sprintf('%s (from TagRegistry)', s.Name));
xlabel('Time [s]');
ylabel('Pressure [mbar]');
