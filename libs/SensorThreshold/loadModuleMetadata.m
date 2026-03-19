function sensors = loadModuleMetadata(metadataStruct, sensors)
%LOADMODULEMETADATA Attach state channels from metadata to sensors.
%   sensors = loadModuleMetadata(metadataStruct, sensors) reads discrete
%   state signals from metadataStruct, compresses them from dense to
%   sparse transitions, and attaches StateChannel objects to each sensor
%   whose ThresholdRules reference matching state keys.
%
%   metadataStruct must have the same format as module data: fields +
%   .doc with per-field .name/.datum entries. The .datum value names the
%   shared datenum field. State signals can be numeric arrays or cell
%   arrays of char.
%
%   ThresholdRules must be attached to sensors before calling this
%   function. Sensors with no rules are skipped. Rules with empty
%   conditions (unconditional) contribute no state keys. State keys not
%   found in the metadata are skipped silently.
%
%   Each sensor receives its own StateChannel instance (no shared
%   handles). Compressed data is cached so each field is processed once.
%
%   Repeated calls add additional StateChannels without clearing existing
%   ones. Caller is responsible for avoiding duplicates.
%
%   See also loadModuleData, StateChannel, ThresholdRule, Sensor.

    narginchk(2, 2);

    % --- Extract datenum field name from doc metadata ---
    datenumField = extractDatenumField(metadataStruct, 'loadModuleMetadata');

    % --- Early exit for empty sensors ---
    if isempty(sensors)
        return;
    end

    % --- Extract timestamps ---
    X = metadataStruct.(datenumField);

    % --- Struct-based cache for compressed transitions (Octave-safe) ---
    cache = struct();

    % --- Attach state channels to each sensor ---
    for i = 1:numel(sensors)
        s = sensors{i};

        % Skip sensors with no threshold rules
        if isempty(s.ThresholdRules)
            continue;
        end

        % Collect unique state keys from all rule conditions
        neededKeys = {};
        for r = 1:numel(s.ThresholdRules)
            rule = s.ThresholdRules{r};
            condFields = fieldnames(rule.Condition);
            neededKeys = [neededKeys; condFields]; %#ok<AGROW>
        end
        neededKeys = unique(neededKeys);

        % Attach StateChannels for keys found in metadata
        for k = 1:numel(neededKeys)
            key = neededKeys{k};

            % Skip keys not in metadata (exclude doc and datenum)
            if ~isfield(metadataStruct, key) || ...
                    strcmp(key, 'doc') || strcmp(key, datenumField)
                continue;
            end

            % Compress on first access, cache for reuse
            if ~isfield(cache, key)
                cache.(key) = compressTransitions(X, metadataStruct.(key));
            end
            cached = cache.(key);

            % Create new StateChannel instance per sensor
            sc = StateChannel(key);
            sc.X = cached.X;
            sc.Y = cached.Y;
            s.addStateChannel(sc);
        end
    end
end

function result = compressTransitions(X, Y_dense)
%COMPRESSTRANSITIONS Compress dense state signal to sparse transitions.
%   result = compressTransitions(X, Y_dense) returns struct with fields
%   X and Y containing only the transition points (plus the first point).
%   Handles both numeric arrays and cell arrays of char.

    if iscell(Y_dense)
        cmp = ~strcmp(Y_dense(1:end-1), Y_dense(2:end));
        changes = [true, reshape(cmp, 1, [])];
    else
        changes = [true, reshape(diff(Y_dense) ~= 0, 1, [])];
    end

    % Ensure row orientation (1xN) per StateChannel contract
    result.X = reshape(X(changes), 1, []);
    result.Y = reshape(Y_dense(changes), 1, []);
end
