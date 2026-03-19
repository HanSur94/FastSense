function sensors = loadModuleData(registry, moduleStruct)
%LOADMODULEDATA Match module struct fields to registered sensors and assign X/Y.
%   sensors = loadModuleData(registry, moduleStruct) takes an
%   ExternalSensorRegistry and a module struct loaded from the external
%   system. The struct must contain a .doc field where each sub-field has
%   .name and .datum properties. The .datum value names the shared
%   datenum field. Each struct field whose name matches a registered
%   sensor key gets its data assigned as sensor.Y, with the shared
%   datenum as sensor.X.
%
%   Returns a 1xN cell array of filled Sensor handles (empty 1x0 if no
%   matches). Output order follows fieldnames(moduleStruct).
%
%   Repeated calls overwrite sensor.X and sensor.Y in-place (handle
%   semantics).
%
%   See also ExternalSensorRegistry, Sensor.

    narginchk(2, 2);

    % --- Extract datenum field name from doc metadata ---
    datenumField = extractDatenumField(moduleStruct, 'loadModuleData');

    % --- Extract shared time vector ---
    X = moduleStruct.(datenumField);

    % --- Match struct fields against registry ---
    fields = fieldnames(moduleStruct);
    registeredKeys = registry.keys();

    if isempty(registeredKeys)
        sensors = cell(1, 0);
        return;
    end

    isMatch = ismember(fields, registeredKeys);

    % Exclude doc and datenum field
    exclude = strcmp(fields, 'doc') | strcmp(fields, datenumField);
    isMatch = isMatch & ~exclude;

    matchedFields = fields(isMatch);
    nMatched = numel(matchedFields);

    % --- Assign X/Y to each matched sensor ---
    sensors = cell(1, nMatched);
    for i = 1:nMatched
        s = registry.get(matchedFields{i});
        s.X = X;
        s.Y = moduleStruct.(matchedFields{i});
        sensors{i} = s;
    end
end
