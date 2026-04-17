%% TagRegistry — Predefined Tag Catalog
% Demonstrates:
%   - TagRegistry.list()        — print all available tag keys
%   - TagRegistry.get(key)      — retrieve a single tag by key
%   - TagRegistry.getMultiple() — retrieve several tags at once
%   - TagRegistry.register()    — add a custom tag at runtime
%   - TagRegistry.unregister()  — remove a tag from the catalog
%   - TagRegistry.printTable()  — detailed tabular view
%   - TagRegistry.viewer()      — interactive GUI viewer
%   - Adding data to registry tags, then plotting

projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
run(fullfile(projectRoot, 'install.m'));

%% 1. List all tags in the catalog
fprintf('=== All registered tags ===');
TagRegistry.list();

%% 2. Retrieve a single tag by key
s = TagRegistry.get('pressure');
fprintf('Retrieved tag: key="%s", name="%s"\n', s.Key, s.Name);

% Populate with synthetic data
t = linspace(0, 80, 15000);
s.updateData(t, 45 + 18*sin(2*pi*t/20) + 4*randn(1, numel(t)));

%% 3. Retrieve multiple tags at once
tags = TagRegistry.getMultiple({'pressure', 'temperature'});
fprintf('\nRetrieved %d tags via getMultiple():\n', numel(tags));
for i = 1:numel(tags)
    fprintf('  [%d] key="%s", name="%s"\n', i, tags{i}.Key, tags{i}.Name);
end

%% 4. register / unregister — add and remove custom tags at runtime
xPh = linspace(0, 60, 5000);
yPh = 7.0 + 0.5*sin(2*pi*xPh/15) + 0.1*randn(1, numel(xPh));
customTag = SensorTag('my_custom_ph', 'Name', 'pH Sensor', 'ID', 999, ...
    'X', xPh, 'Y', yPh);
customTag.Units = 'pH';

TagRegistry.register('my_custom_ph', customTag);
fprintf('\nTagRegistry.register(): added custom tag "my_custom_ph".\n');

%% 5. printTable — detailed tabular view of all tags
TagRegistry.printTable();

%% 6. viewer — interactive GUI with uitable
TagRegistry.viewer();
fprintf('TagRegistry.viewer() opened.\n');

% Cleanup: unregister the custom tag to avoid polluting the global
% registry. In a real workflow you would keep it registered.
TagRegistry.unregister('my_custom_ph');
fprintf('TagRegistry.unregister(): removed "my_custom_ph".\n');

%% 7. Plot the pressure tag with FastSense
fp = FastSense();
fp.addTag(s);
fp.render();
title(sprintf('%s (from TagRegistry)', s.Name));
xlabel('Time [s]');
ylabel('Pressure [mbar]');
